package funkin.play.cutscene;

import funkin.modding.IScriptedClass;
import funkin.modding.events.ScriptEventDispatcher;
import funkin.modding.events.ScriptEvent;
#if mobile
import funkin.util.TouchUtil;
import funkin.util.HapticUtil;
#end
import funkin.ui.FullScreenScaleMode;
import funkin.audio.FunkinSound;
import funkin.data.song.SongRegistry;
import funkin.data.song.SongData.SongMusicData;
import flixel.group.FlxGroup;
import flixel.text.FlxText;
import flixel.util.FlxSignal;
import flixel.util.FlxTimer;
import flixel.util.FlxColor;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;

/**
 * Cutscene handler.
 * Assumes you are in `PlayState`
 */
@:nullSafety
class Cutscene extends FlxGroup implements IScriptedClass implements IBPMSyncedScriptedClass implements IEventHandler
{
  /**
   * Timer Manager the Cutscene.
   */
  public var cutsceneTimerManager:FlxTimerManager;

  /**
   * Conductor for `cutsceneMusic`, if applicable.
   */
  public var cutsceneConductor:Null<Conductor> = null;

  /**
   * Cutscene Music, if applicable.
   */
  public var cutsceneMusic:Null<FunkinSound> = null;

  /**
   * Signal to call when the cutscene is finished.
   * This is used internally, but can be used externally if needed.
   */
  public var onFinish:FlxSignal;

  /**
   * Internal, the text telling the user that they can skip.
   */
  var skipText:FlxText;

  /**
   * The stage that skipping is currently at.
   * The value increases each time the determined Skip button is pressed.
   */
  var skippingStage(default, set):CutsceneSkippingStage = WAITING;

  /**
   * Constructor for the `Cutscene` object.
   * @param skippingEnabled If enabled, the "Press [BUTTON] to Skip" functionality is enabled.
   */
  public function new(?skippingEnabled:Bool = false)
  {
    super();

    cutsceneTimerManager = new FlxTimerManager();

    onFinish = new FlxSignal();

    skipText = new FlxText(936 * FullScreenScaleMode.wideScale.x, 618 * FullScreenScaleMode.wideScale.y, 0, '', 20);

    #if mobile
    skipText.text = 'Skip [Pause Button]';
    skipText.x -= 136;
    #else
    skipText.text = 'Skip [ ' + PlayerSettings.player1.controls.getDialogueNameFromToken("CUTSCENE_ADVANCE", true) + ' ]';
    #end

    skipText.setFormat(Paths.font('vcr.ttf'), 40, FlxColor.WHITE, RIGHT, OUTLINE, FlxColor.BLACK);
    skipText.scrollFactor.set();
    skipText.borderSize = 2;

    skippingStage = skippingEnabled == true ? WAITING : DISABLED;

    add(cutsceneTimerManager);
    add(skipText);
  }

  /**
   * A function for checking if the cutscene should play or not.
   * @return If true, the cutscene will play.
   */
  public function shouldPlayCutscene():Bool
  {
    return false;
  }

  override public function update(elapsed:Float):Void
  {
    if (skippingStage > DISABLED)
    {
      // The usual skip keybind.
      var tryingToSkip:Bool = PlayerSettings.player1.controls.CUTSCENE_ADVANCE;

      // If on mobile, the pause button can also be used.
      #if mobile
      if (TouchUtil.pressAction(PlayState.instance.pauseButton)) tryingToSkip = true;
      #end

      // If on Android, the Back button can also be used.
      #if android
      if (FlxG.android.justReleased.BACK) tryingToSkip = true;
      #end

      if (tryingToSkip) skippingStage++;
    }

    if (cutsceneConductor != null)
    {
      cutsceneConductor.update(cutsceneMusic?.time);
    }

    super.update(elapsed);

    var event:ScriptEvent = new UpdateScriptEvent(elapsed);
    dispatchEvent(event);
  }

  public function startCutscene():Void
  {
    // Create everything.
    var event:ScriptEvent = new ScriptEvent(CREATE);
    dispatchEvent(event);

    // (Re)start the music, in case of a lag spike.
    if (cutsceneMusic != null) cutsceneMusic.play(true);
  }

  public function setupCutsceneMusic(key:String, ?variation:Null<String> = null):Void
  {
    var songMusicData:Null<SongMusicData> = SongRegistry.instance.parseMusicData(key);

    if (songMusicData != null)
    {
      cutsceneConductor = new Conductor();
      cutsceneConductor.mapTimeChanges(songMusicData.timeChanges);

      cutsceneConductor.onStepHit.add(() -> {
        var event:ScriptEvent = new SongTimeScriptEvent(SONG_STEP_HIT, cutsceneConductor?.currentBeat ?? 0, cutsceneConductor?.currentStep ?? 0);
        dispatchEvent(event);
      });

      cutsceneConductor.onBeatHit.add(() -> {
        var event:ScriptEvent = new SongTimeScriptEvent(SONG_BEAT_HIT, cutsceneConductor?.currentBeat ?? 0, cutsceneConductor?.currentStep ?? 0);
        dispatchEvent(event);
      });
    }

    var musicPath:String = '$key/${variation ?? key}';
    cutsceneMusic = FunkinSound.load(Paths.music(musicPath), true);
  }

  function addTimer(duration:Float, callback:Void->Void):FlxTimer
  {
    var timer:FlxTimer = new FlxTimer(cutsceneTimerManager);
    timer.start(duration, (_) -> {
      callback();
    });
    return timer;
  }

  public function onSkipCutscene():Void
  {
    active = false;

    if (cutsceneMusic != null) cutsceneMusic.fadeOut(0.5, 0);
    camera?.fade(0xFF000000, 0.5, false, () -> {
      finish();
      camera?.fade(0xFF000000, 0.5, true, null, true);
    }, true);
  }

  public function finish():Void
  {
    if (cutsceneMusic != null)
    {
      cutsceneMusic.stop();
    }

    cutsceneTimerManager.clear();

    onFinish.dispatch();
    destroy();
  }

  var skipTextTween:Null<FlxTween> = null;

  function set_skippingStage(value:CutsceneSkippingStage):CutsceneSkippingStage
  {
    // Tried to move up a skipping stage while skipping is disabled, cancel the request.
    if (value > WAITING && skippingStage == DISABLED) return skippingStage;

    // Tried to move up a skipping stage while the skip text alpha tween is happening, cancel the request.
    // This will be ignored if we are going back a stage.
    if (skipTextTween != null && value > skippingStage) return skippingStage;

    switch (value)
    {
      case DISABLED, WAITING:
        // Cancel the skip text tween, if it is in effect.
        skipTextTween?.cancel();
        skipTextTween = null;

        // Hide the skip text.
        skipText.alpha = 0;
      case CONFIRM:
        // Show skip text to confirm the skip.
        trace('cant skip yet!');
        skipTextTween = FlxTween.tween(skipText, {alpha: 1}, 0.5,
          {
            ease: FlxEase.quadOut,
            onComplete: _ -> {
              skipTextTween = null;
              trace('can skip!');
            }
          });
      case SKIPPED:
        onSkipCutscene();
        trace('skipped');

        // Disable any more skipping.
        skippingStage = -1;
        return skippingStage;
    }
    return skippingStage = value;
  }

  public function onScriptEvent(event:ScriptEvent):Void {}

  public function onCreate(event:ScriptEvent):Void {}

  public function onDestroy(event:ScriptEvent):Void {}

  public function onUpdate(event:UpdateScriptEvent):Void {}

  public function onStepHit(event:SongTimeScriptEvent):Void {}

  public function onBeatHit(event:SongTimeScriptEvent):Void {}

  public function dispatchEvent(event:ScriptEvent):Void
  {
    ScriptEventDispatcher.callEvent(this, event);
  }
}

/**
 * State machine for Cutscene Skipping
 * @see `Cutscene.skippingStage`
 */
enum abstract CutsceneSkippingStage(Int) from Int to Int
{
  /**
   * Skipping is disabled for this cutscene.
   */
  var DISABLED = -1;

  /**
   * User hasn't tried to skip yet.
   */
  var WAITING = 0;

  /**
   * User has tried to skip, and we are now showing the skip button.
   */
  var CONFIRM = 1;

  /**
   * Successfully skipped.
   */
  var SKIPPED = 2;

  // Helper functions to make comparing cleaner.
  @:op(A == B)
  public function op_equals(other:Null<CutsceneSkippingStage>):Bool
  {
    var thisInt:Null<Int> = abstract;
    var otherInt:Null<Int> = cast other;

    return thisInt == otherInt;
  }

  @:op(A != B)
  public function op_notEquals(other:Null<CutsceneSkippingStage>):Bool
  {
    var thisInt:Null<Int> = abstract;
    var otherInt:Null<Int> = cast other;

    return thisInt != otherInt;
  }

  @:op(A > B)
  public function op_greaterThan(other:Null<CutsceneSkippingStage>):Bool
  {
    var thisInt:Null<Int> = abstract;
    var otherInt:Null<Int> = cast other;

    return thisInt > otherInt;
  }

  @:op(A < B)
  public function op_lessThan(other:Null<CutsceneSkippingStage>):Bool
  {
    var thisInt:Null<Int> = abstract;
    var otherInt:Null<Int> = cast other;

    return thisInt < otherInt;
  }

  @:op(A >= B)
  public function op_greaterThanOrEquals(other:Null<CutsceneSkippingStage>):Bool
  {
    var thisInt:Null<Int> = abstract;
    var otherInt:Null<Int> = cast other;

    return thisInt >= otherInt;
  }

  @:op(A <= B)
  public function op_lessThanOrEquals(other:Null<CutsceneSkippingStage>):Bool
  {
    var thisInt:Null<Int> = abstract;
    var otherInt:Null<Int> = cast other;

    return thisInt <= otherInt;
  }
}

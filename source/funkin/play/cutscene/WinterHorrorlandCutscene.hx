package funkin.play.cutscene;

import flixel.FlxSprite;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import funkin.audio.FunkinSound;
import funkin.util.HapticUtil;

class WinterHorrorlandCutscene extends Cutscene
{
  static final TWEEN_DURATION:Float = 2.0;

  public function new()
  {
    super(true);
  }

  override public function onCreate(event):Void
  {
    PlayState.instance.camHUD.visible = false;

    var blackScreen:FlxSprite = new FlxSprite(0, 0).makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
    this.add(blackScreen);

    this.addTimer(0.1, function() {
      trace('Playing horrorland cutscene...');
      this.remove(blackScreen);

      // Force set the camera position and zoom.
      PlayState.instance.cameraFollowPoint.setPosition(400, -2050);
      PlayState.instance.resetCamera();
      FlxG.camera.zoom = 2.5;

      // Play the Sound effect.
      HapticUtil.vibrate(0.1, 0.5, 1, 1);
      FunkinSound.playOnce(Paths.sound('Lights_Turn_On'), function() {
        // Fade in the HUD.
        trace('SFX done...');
        PlayState.instance.camHUD.visible = true;
        PlayState.instance.camHUD.alpha = 0.0; // Use alpha rather than visible to let us fade it in.
        FlxTween.tween(PlayState.instance.camHUD, {alpha: 1.0}, TWEEN_DURATION, {ease: FlxEase.quadInOut});

        // Start the countdown.
        trace('Zoom out done...');
        trace('Begin countdown (ends cutscene)');
        this.finish();
      });
    });
  }
}

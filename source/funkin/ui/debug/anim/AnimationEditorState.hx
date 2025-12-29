package funkin.ui.debug.anim;

#if FEATURE_ANIMATION_EDITOR
import funkin.graphics.FunkinCamera;
import flixel.addons.display.FlxGridOverlay;
import flixel.addons.display.FlxBackdrop;
import funkin.audio.FunkinSound;
import haxe.ui.backend.flixel.UIState;
import funkin.input.Cursor;
import funkin.util.MouseUtil;
import flixel.math.FlxMath;
import funkin.util.WindowUtil;
import funkin.ui.mainmenu.MainMenuState;
import haxe.ui.focus.FocusManager;
import funkin.ui.debug.anim.components.AnimationListSelect;
import funkin.data.character.CharacterData.CharacterDataParser;
import funkin.play.character.BaseCharacter;

using funkin.ui.debug.anim.handlers.AnimationEditorDialogHandler;

/**
 * The Animation Editor!!!
 *
 * @author TechnikTil
 */
@:build(haxe.ui.ComponentBuilder.build("assets/exclude/data/ui/animation-editor/main-view.xml"))
class AnimationEditorState extends UIState
{
  /**
   * The camera that contains most HaxeUI elements.
   */
  public var gameCamera:FunkinCamera;

  /**
   * The camera that contains most HaxeUI elements.
   */
  public var uiCamera:FunkinCamera;

  /**
   * The current offset mode.
   */
  public var offsetMode:AnimationOffsetMode = LOCAL;

  /**
   * The character thats currently being edited.
   */
  public var character:Null<BaseCharacter>;

  /**
   * The sprite that contains the optional Onion Skin displayed.
   */
  public var onionSkin:Null<OnionSkin>;

  /**
   * Whether the user is focused on an input in the Haxe UI, and inputs are being fed into it.
   * If the user clicks off the input, focus will leave.
   */
  var isHaxeUIFocused(get, never):Bool;

  function get_isHaxeUIFocused():Bool
  {
    return FocusManager.instance.focus != null;
  }

  /**
   * If theres a dialog currently open, meaning that background interaction should be disabled.
   */
  public var isHaxeUIDialogOpen:Bool = false;

  /**
   * If control is currently pressed.
   * "COMMAND" is usually used more for Macs, so this variable is made.
   */
  public var controlPressed(get, never):Bool;

  function get_controlPressed():Bool
  {
    return #if mac FlxG.keys.pressed.WINDOWS #else FlxG.keys.pressed.CONTROL #end;
  }

  /**
   * If the character has been edited in some way.
   */
  public var dirty(default, set):Bool = false;

  var bg:FlxBackdrop;

  override public function create():Void
  {
    bg = new FlxBackdrop(FlxGridOverlay.createGrid(10, 10, FlxG.width, FlxG.height, true, 0xffe7e6e6, 0xffd9d5d5));
    bg.zIndex = 100;
    bg.antialiasing = false;
    add(bg);

    setupCameras();

    updateWindowTitle();
    super.create();

    root.scrollFactor.set();
    root.zIndex = 1000;
    root.cameras = [uiCamera];
    root.width = uiCamera.width;
    root.height = uiCamera.height;

    Cursor.show();
    FunkinSound.playMusic('chartEditorLoop',
      {
        startingVolume: 0.0,
        overrideExisting: true,
        restartTrack: true
      });
    FlxG.sound.music.fadeIn(10, 0, 1);

    setupUIListeners();
    this.openWelcomeDialog();
    refresh();
  }

  function setupCameras():Void
  {
    gameCamera = new FunkinCamera();
    gameCamera.scroll.set(-(FlxG.width / 2), -(FlxG.height / 2));

    uiCamera = new FunkinCamera();
    uiCamera.bgColor.alpha = 0;

    FlxG.cameras.reset(gameCamera);
    FlxG.cameras.add(uiCamera, false);
  }

  function setupUIListeners():Void
  {
    menubarItemOpenChar.onClick = _ -> this.openWelcomeDialog();
    menubarItemExit.onClick = _ -> quit();
    bottomBarAnimText.onClick = _ -> openAnimSelect();
  }

  /**
   * Loads a character to edit.
   * @param charId The ID of the character.
   */
  public function loadCharacter(charId:String):Void
  {
    if (character != null)
    {
      character.destroy();
      remove(character);
    }

    character = CharacterDataParser.fetchCharacter(charId);
    character.resetCharacter(true);
    character.setPosition(-character.characterOrigin.x, -character.characterOrigin.y);
    character.debug = true;
    character.zIndex = 300;
    add(character);

    dirty = false;

    refresh();
  }

  /**
   * Updates (and creates) an onion skin to the current frame shown.
   */
  public function updateOnionSkin():Void
  {
    if (onionSkin == null)
    {
      onionSkin = new OnionSkin();
      onionSkin.zIndex = 200;
      add(onionSkin);
      refresh();
    }

    onionSkin.updateOnionSkin(character);
  }

  override public function update(elapsed:Float):Void
  {
    handleInputs();
    updateOffsetText();

    super.update(elapsed);
    if (gameCamera.zoom < 0.15) gameCamera.zoom = 0.15;
  }

  /**
   * Handle all the inputs for this editor.
   */
  public function handleInputs():Void
  {
    if (isHaxeUIFocused || isHaxeUIDialogOpen) return;

    // CTRL + Q = Quit to Menu
    if (controlPressed && FlxG.keys.justPressed.Q) quit();

    // F = Toggle Onion Skin
    if (FlxG.keys.justPressed.F)
    {
      if (onionSkin != null) onionSkin.visible = !onionSkin.visible;
      if (onionSkin?.visible ?? true) updateOnionSkin();
    }

    // G = Flip Character
    if (FlxG.keys.justPressed.G)
    {
      character.flipX = !character.flipX;
    }

    handleAnimationInputs();

    // Camera Movement with your mouse.
    MouseUtil.mouseCamDrag();
    MouseUtil.mouseWheelZoom();
  }

  public function handleAnimationInputs():Void
  {
    if (character == null) return;

    // ASWD = Play Character Animations
    // Optional SHIFT for miss animations
    var animButtons:Array<Bool> = [
      FlxG.keys.justPressed.A,
      FlxG.keys.justPressed.S,
      FlxG.keys.justPressed.W,
      FlxG.keys.justPressed.D
    ];
    var miss:Bool = FlxG.keys.pressed.SHIFT;
    for (i => button in animButtons)
    {
      if (!button) continue;
      character.playSingAnimation(i, miss);
    }

    // Q, E = Change index in Animation List.
    if (FlxG.keys.justPressed.Q || FlxG.keys.justPressed.E)
    {
      var animations:Array<String> = character.animation?.getNameList() ?? [];
      var index:Int = animations.indexOf(character.getCurrentAnimation());
      index += (FlxG.keys.justPressed.Q ? -1 : 1);
      index = FlxMath.wrap(index, 0, animations.length - 1);

      character.playAnimation(animations[index], true);
    }
  }

  /**
   * Updates any info displayed at the bottom of the editor.
   */
  public function updateOffsetText():Void
  {
    if (character != null)
    {
      bottomBarAnimText.text = character.getCurrentAnimation();
      bottomBarOffsetText.text = '[${getOffsetArray().join(', ')}]';
    }

    bottomBarModeText.text = switch (offsetMode)
    {
      case LOCAL:
        "Local";
      case GLOBAL:
        "Global";
    }
  }

  /**
   * Gets the array containing the current offsets.
   * This is great for editing.
   * @return The array mentioned above.
   */
  public function getOffsetArray():Null<Array<Float>>
  {
    if (character == null) return null;

    @:privateAccess
    {
      return switch (offsetMode)
      {
        case LOCAL:
          character.animOffsets;
        case GLOBAL:
          character.globalOffsets;
      }
    }
  }

  /**
   * Opens the animation name select.
   */
  public function openAnimSelect():Void
  {
    var animSelectDialog:AnimationListSelect = new AnimationListSelect(this);
    animSelectDialog.x = 16;
    animSelectDialog.y = FlxG.height - bottomBar.height - animSelectDialog.height - 10;
    animSelectDialog.show();
  }

  /**
   * Quits the editor.
   * @param exitPrompt If a prompt should be shown before closing.
   */
  public function quit(?exitPrompt:Bool = true):Void
  {
    if (exitPrompt && dirty)
    {
      this.openLeaveConfirmationDialog();
      return;
    }

    FlxG.switchState(() -> new MainMenuState());
    resetWindowTitle();
  }

  /**
   * Updates the Window Title.
   */
  public function updateWindowTitle():Void
  {
    var extra:String = '';

    if (character != null)
    {
      extra = ' - ${character.characterName}';
      if (dirty) extra += '*';
    }

    WindowUtil.setWindowTitle('Friday Night Funkin\' Animation Editor' + extra);
  }

  function resetWindowTitle():Void
  {
    WindowUtil.setWindowTitle('Friday Night Funkin\'');
  }

  function set_dirty(value:Bool):Bool
  {
    dirty = value;
    updateWindowTitle();
    return value;
  }
}

/**
 * Animation Editor Offset Modes.
 */
enum AnimationOffsetMode
{
  LOCAL;
  GLOBAL;
}
#end

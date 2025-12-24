package funkin.ui.debug.anim;

#if FEATURE_ANIMATION_EDITOR
import funkin.graphics.FunkinCamera;
import flixel.addons.display.FlxGridOverlay;
import flixel.addons.display.FlxBackdrop;
import funkin.audio.FunkinSound;
import haxe.ui.backend.flixel.UIState;
import haxe.ui.containers.dialogs.Dialog;
import funkin.input.Cursor;
import funkin.util.MouseUtil;
import funkin.ui.mainmenu.MainMenuState;
import haxe.ui.containers.dialogs.MessageBox;
import haxe.ui.containers.dialogs.Dialogs;
import funkin.ui.debug.anim.components.AnimationEditorWelcomeDialog;
import funkin.data.character.CharacterData.CharacterDataParser;
import funkin.play.character.BaseCharacter;

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
   * The character thats currently being edited.
   */
  public var character:Null<BaseCharacter>;

  /**
   * The sprite that contains the optional Onion Skin displayed.
   */
  public var onionSkin:Null<OnionSkin>;

  /**
   * If a dialog is currently open.
   */
  public var inputsAllowed:Bool = false;

  var bg:FlxBackdrop;

  override public function create():Void
  {
    bg = new FlxBackdrop(FlxGridOverlay.createGrid(10, 10, FlxG.width, FlxG.height, true, 0xffe7e6e6, 0xffd9d5d5));
    bg.zIndex = 100;
    bg.antialiasing = false;
    add(bg);

    setupCameras();

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
    openDialog(WELCOME);
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
    menubarItemOpenChar.onClick = _ -> openDialog(WELCOME);
    menubarItemExit.onClick = _ -> quit(true);
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

    super.update(elapsed);
    if (gameCamera.zoom < 0.15) gameCamera.zoom = 0.15;
  }

  /**
   * Handle all the inputs for this editor.
   */
  public function handleInputs():Void
  {
    if (!inputsAllowed) return;

    // "COMMAND" is usually used more for Macs.
    var control:Bool = #if mac FlxG.keys.pressed.WINDOWS #else FlxG.keys.pressed.CONTROL #end;

    // CTRL + Q = Quit to Menu
    if (control && FlxG.keys.justPressed.Q) quit(true);

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
      trace('Played ${i} (${miss ? 'miss' : 'sing'}) animation on character.');
    }

    // Camera Movement with your mouse.
    MouseUtil.mouseCamDrag();
    MouseUtil.mouseWheelZoom();
  }

  /**
   * Opens a dialog.
   * @param name The dialog to open.
   * @param closeable If the dialog should be closable.
   */
  public function openDialog(name:AnimationEditorDialog, closeable:Bool = false):Void
  {
    var dialog:Dialog = switch (name)
    {
      case WELCOME:
        new AnimationEditorWelcomeDialog(this);
    }

    dialog.showDialog();
    inputsAllowed = false;
    dialog.closable = closeable;
    dialog.onDialogClosed = (_) -> {
      inputsAllowed = true;
    };
  }

  var dirty:Bool = true;

  /**
   * Quits the editor.
   * @param exitPrompt If a prompt should be shown before closing.
   */
  public function quit(?exitPrompt:Bool = false):Void
  {
    if (exitPrompt && dirty)
    {
      var dialog:Dialog = Dialogs.messageBox("You are about to leave the editor without saving.\n\nAre you sure?", "Leave Editor", MessageBoxType.TYPE_YESNO,
        true, function(button:DialogButton) {
          inputsAllowed = true;
          if (button == DialogButton.YES) quit(false);
      });
      inputsAllowed = false;
      dialog.destroyOnClose = true;
      return;
    }

    FlxG.switchState(() -> new MainMenuState());
  }
}

/**
 * Animation Editor Dialogs
 */
enum AnimationEditorDialog
{
  WELCOME;
}
#end

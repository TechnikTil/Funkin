package funkin.ui.debug.character.components;

#if FEATURE_CHARACTER_EDITOR
import haxe.ui.containers.ListView;
import haxe.ui.core.Screen;
import haxe.ui.events.MouseEvent;
import haxe.ui.events.FocusEvent;

/**
 * Tiny selection window for animations.
 */
@:build(haxe.ui.macros.ComponentMacros.build("assets/exclude/data/ui/character-editor/dialogs/anim-list-select.xml"))
class AnimationListSelect extends ListView
{
  var charState:CharacterEditorState;

  /**
   * Called when closing the window.
   */
  public var onClose:Null<Void->Void>;

  public function new(state:CharacterEditorState)
  {
    super();

    if (state.character == null)
    {
      hide();
      return;
    }

    var names:Array<String> = state.character.animation?.getNameList() ?? [];

    for (name in names)
      this.dataSource.add({text: name});

    this.selectedIndex = names.indexOf(state.character.getCurrentAnimation());

    this.registerEvent(MouseEvent.CLICK, (e:MouseEvent) -> {
      state.character.playAnimation(names[this.selectedIndex], true);
      hide();
    });

    this.registerEvent(FocusEvent.FOCUS_OUT, (e:FocusEvent) -> {
      hide();
    });
  }

  override public function hide():Void
  {
    super.hide();
    Screen.instance.removeComponent(this, true);
  }

  override public function show():Void
  {
    super.show();
    Screen.instance.addComponent(this);
  }
}
#end

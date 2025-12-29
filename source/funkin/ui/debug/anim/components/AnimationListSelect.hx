package funkin.ui.debug.anim.components;

#if FEATURE_ANIMATION_EDITOR
import haxe.ui.containers.ListView;
import haxe.ui.core.Screen;
import haxe.ui.events.MouseEvent;
import haxe.ui.events.FocusEvent;

/**
 * Tiny selection window for animations.
 */
@:build(haxe.ui.macros.ComponentMacros.build("assets/exclude/data/ui/animation-editor/dialogs/anim-list-select.xml"))
class AnimationListSelect extends ListView
{
  var animState:AnimationEditorState;

  /**
   * Called when closing the window.
   */
  public var onClose:Null<Void->Void>;

  public function new(state:AnimationEditorState)
  {
    super();
    animState = state;

    if (animState.character == null)
    {
      hide();
      return;
    }

    var names:Array<String> = animState.character.animation?.getNameList() ?? [];

    for (name in names)
      this.dataSource.add({text: name});

    this.selectedIndex = names.indexOf(animState.character.getCurrentAnimation());

    this.registerEvent(MouseEvent.CLICK, (e:MouseEvent) -> {
      animState.character.playAnimation(names[this.selectedIndex], true);
      hide();
    });

    this.registerEvent(FocusEvent.FOCUS_OUT, (e:FocusEvent) -> {
      hide();
    });

    this.focus = true;
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

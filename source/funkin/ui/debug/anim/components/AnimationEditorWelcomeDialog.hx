package funkin.ui.debug.anim.components;

#if FEATURE_ANIMATION_EDITOR
import haxe.ui.containers.dialogs.Dialog;
import haxe.ui.components.Link;
import funkin.data.character.CharacterData;
import funkin.data.character.CharacterData.CharacterDataParser;

/**
 * The dialog shown when opening the editor.
 * Gives the user a nice interface for selecting the character to edit.
 */
@:build(haxe.ui.macros.ComponentMacros.build("assets/exclude/data/ui/animation-editor/dialogs/welcome.xml"))
class AnimationEditorWelcomeDialog extends Dialog
{
  public function new(state:AnimationEditorState)
  {
    super();

    var characterIds:Array<String> = CharacterDataParser.listCharacterIds();
    characterIds.sort(funkin.util.SortUtil.alphabetically);

    for (charId in characterIds)
    {
      var charData:Null<CharacterData> = CharacterDataParser.fetchCharacterData(charId);
      if (charData == null) continue;

      var link:Link = new Link();
      link.percentWidth = 100;
      link.text = charData.name;
      link.onClick = (_) -> {
        state.loadCharacter(charId);
        hide();
      };

      characters.addComponent(link);
    }

    this.destroyOnClose = true;
  }
}
#end

package funkin.ui.debug.character.components;

#if FEATURE_CHARACTER_EDITOR
import haxe.ui.containers.dialogs.Dialog;
import haxe.ui.components.Link;
import funkin.data.character.CharacterData;
import funkin.data.character.CharacterData.CharacterDataParser;

/**
 * The dialog shown when opening the editor.
 * Gives the user a nice interface for selecting the character to edit.
 */
@:build(haxe.ui.macros.ComponentMacros.build("assets/exclude/data/ui/character-editor/dialogs/welcome.xml"))
class CharacterEditorWelcomeDialog extends Dialog
{
  public function new(state:CharacterEditorState)
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

      splashTemplateContainer.addComponent(link);
    }

    this.destroyOnClose = true;
  }
}
#end

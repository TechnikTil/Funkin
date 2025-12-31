package funkin.ui.debug.character.handlers;

#if FEATURE_CHARACTER_EDITOR
import haxe.ui.containers.dialogs.Dialog;
import funkin.ui.debug.character.components.CharacterEditorWelcomeDialog;
import haxe.ui.containers.dialogs.Dialogs;
import haxe.ui.events.UIEvent;
import haxe.ui.containers.dialogs.MessageBox;

/**
 * Handles dialogs for the Character Editor.
 */
class CharacterEditorDialogHandler
{
  /**
   * Builds and opens a dialog letting the user select which character to edit.
   * @param state The current character editor state.
   * @param closable If the dialog is closable.
   * @return The dialog that was opened.
   */
  public static function openWelcomeDialog(state:CharacterEditorState, ?closeable:Bool = false):Dialog
  {
    var dialog:CharacterEditorWelcomeDialog = new CharacterEditorWelcomeDialog(state);
    dialog.showDialog();
    dialog.closable = closeable;

    state.isHaxeUIDialogOpen = true;

    dialog.onDialogClosed = function(event:UIEvent) {
      state.isHaxeUIDialogOpen = false;
    };

    return dialog;
  }

  /**
   * Builds and opens a dialog where the user can confirm to leave the character editor if they have unsaved changes.
   * @param state The current character editor state.
   * @return The dialog that was opened.
   */
  public static function openLeaveConfirmationDialog(state:CharacterEditorState):Dialog
  {
    var dialog:Dialog = Dialogs.messageBox("You are about to leave the editor without saving.\n\nAre you sure?", "Leave Editor", MessageBoxType.TYPE_YESNO,
      true, function(button:DialogButton) {
        if (button == DialogButton.YES) state.quit(false);
        state.isHaxeUIDialogOpen = false;
    });

    dialog.destroyOnClose = true;
    state.isHaxeUIDialogOpen = true;

    dialog.onDialogClosed = function(event:UIEvent) {
      state.isHaxeUIDialogOpen = false;
    };

    return dialog;
  }
}
#end

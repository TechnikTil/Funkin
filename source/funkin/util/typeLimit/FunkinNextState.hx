package funkin.util.typeLimit;

import flixel.util.typeLimit.NextState;
import flixel.FlxState;

/**
 * A helper for HaxeFlixel's `NextState` that adds support for scripted class names.
 */
abstract FunkinNextState(Dynamic)
{
  /**
   * Constructs a `FunkinNextState` from a state.
   * @param state The state.
   * @return `FunkinNextState`
   */
  @:from @:deprecated('Use `MyState.new` or `()->new MyState()` instead of `new MyState()`.')
  public static function fromState(state:FlxState):FunkinNextState
  {
    return cast state;
  }

  /**
   * Constructs a `FunkinNextState` from a function.
   * @param func The function.
   * @return `FunkinNextState`
   */
  @:from
  public static function fromMaker(func:() -> FlxState):FunkinNextState
  {
    return cast func;
  }

  /**
   * Constructs a `FunkinNextState` from a scripted class name.
   * @param clsName The scripted class name.
   * @return `FunkinNextState`
   */
  @:from
  public static function fromScriptedClass(clsName:String):FunkinNextState
  {
    return cast clsName;
  }

  /**
   * Converts this back to a `NextState`.
   * @return The `NextState`.
   */
  @:to
  public function toNextState():NextState
  {
    if (Std.isOfType(this, String))
    {
      var clsName:String = cast this;
      var createScriptClass:Void->FlxState = () ->
      {
        if (funkin.ui.MusicBeatSubState.listScriptClasses().contains(clsName))
        {
          // This scripted class is a `MusicBeatSubState`, lets construct it.
          return funkin.ui.MusicBeatSubState.scriptInit(clsName);
        }
        else if (funkin.ui.MusicBeatState.listScriptClasses().contains(clsName))
        {
          // This scripted class is a `MusicBeatState`, lets construct it.
          return funkin.ui.MusicBeatState.scriptInit(clsName);
        }
        else if (flixel.FlxSubState.listScriptClasses().contains(clsName))
        {
          // This scripted class is a `FlxSubState`, lets construct it.
          return flixel.FlxSubState.scriptInit(clsName);
        }
        else if (FlxState.listScriptClasses().contains(clsName))
        {
          // This scripted class is a `FlxState`, lets construct it.
          return FlxState.scriptInit(clsName);
        }
        else
        {
          // We can't find a proper way to construct the scripted class.
          // Lets send the user to the main menu as a fail safe.
          return new funkin.ui.mainmenu.MainMenuState();
        }
      };

      return NextState.fromMaker(createScriptClass);
    }
    else
    {
      return cast this;
    }
  }
}

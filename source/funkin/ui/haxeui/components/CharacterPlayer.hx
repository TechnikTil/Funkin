package funkin.ui.haxeui.components;

import flixel.FlxSprite;
import haxe.ui.containers.Box;
import haxe.ui.core.Component;
import haxe.ui.geom.Size;
import haxe.ui.layouts.DefaultLayout;
import funkin.play.character.BaseCharacter;
import funkin.play.character.CharacterData.CharacterDataParser;

@:composite(Layout)
class CharacterPlayer extends Box
{
  public var character:Null<BaseCharacter>;

  public function new(?char:String)
  {
    super();
    if (char == null)
    {
      loadCharacter('bf');
      return;
    }

    loadCharacter(char);
  }

  public var charId(get, set):String;

  function get_charId():String
  {
    return character?.characterId ?? '';
  }

  function set_charId(value:String):String
  {
    loadCharacter(value);
    return value;
  }

  public var charName(get, never):String;

  function get_charName():String
  {
    return character?.characterName ?? "Unknown";
  }

  /**
   * Loads a character by ID.
   * @param id The ID of the character to load.
   */
  public function loadCharacter(id:String):Void
  {
    if (id == null) return;

    if (character != null)
    {
      remove(character);
      character.destroy();
    }

    character = CharacterDataParser.fetchCharacter(id, false); // debug so stuff wont break
    if (character == null) return;

    character.resetCharacter(true);
    character.flipX = character.getDataFlipX();

    if (characterType != null) character.characterType = characterType;
    if (flip) character.flipX = !character.flipX;
    if (targetScale != 1.0) character.setScale(character.getBaseScale() * targetScale);

    add(character);
    invalidateComponentLayout();
  }

  private override function repositionChildren()
  {
    super.repositionChildren();
    if (character != null)
    {
      character.x = this.screenX;
      character.y = this.screenY;
    }
  }

  /**
   * The character type (such as BF, Dad, GF, etc).
   */
  public var characterType(default, set):CharacterType;

  function set_characterType(value:CharacterType):CharacterType
  {
    if (character != null) character.characterType = value;
    return characterType = value;
  }

  public var flip(default, set):Bool;

  function set_flip(value:Bool):Bool
  {
    if (value == flip) return value;

    if (character != null)
    {
      character.flipX = !character.flipX;
    }

    return flip = value;
  }

  public var targetScale(default, set):Float = 1.0;

  function set_targetScale(value:Float):Float
  {
    if (value == targetScale) return value;

    if (character != null)
    {
      character.setScale(character.getBaseScale() * value);
    }

    return targetScale = value;
  }
}

@:access(funkin.ui.haxeui.components.CharacterPlayer)
private class Layout extends DefaultLayout
{
  public override function resizeChildren()
  {
    super.resizeChildren();

    var wrapper = cast(_component, CharacterPlayer);
    var sprite = wrapper.character;
    if (sprite == null)
    {
      return super.resizeChildren();
    }

    // sprite.origin.set(0, 0);
    // sprite.setGraphicSize(Std.int(innerWidth), Std.int(innerHeight));
  }

  public override function calcAutoSize(exclusions:Array<Component> = null):Size
  {
    var wrapper = cast(_component, CharacterPlayer);
    var sprite = wrapper.character;
    if (sprite == null)
    {
      return super.calcAutoSize(exclusions);
    }
    var size = new Size();
    size.width = sprite.width + paddingLeft + paddingRight;
    size.height = sprite.height + paddingTop + paddingBottom;
    return size;
  }
}

package funkin.ui.debug.anim;

import funkin.graphics.FunkinSprite;
import funkin.play.character.BaseCharacter;
import flixel.math.FlxPoint;

class OnionSkin extends FunkinSprite
{
  var charOffset:FlxPoint;

  public function new()
  {
    charOffset = FlxPoint.get();
    super();

    alpha = 0.6;
  }

  /**
   * Update the onion skin showing.
   * @param character Character to base it off of.
   */
  public function updateOnionSkin(character:BaseCharacter):Void
  {
    this.graphic?.destroy();

    var framePixels:openfl.display.BitmapData = character.updateFramePixels();
    this.pixels = framePixels;
    character.framePixels = null;
    character.dirty = true;

    this.setPosition(character.x, character.y);

    var animOffsets:Array<Float> = character.animationOffsets.get(character.getCurrentAnimation()) ?? [0, 0];
    charOffset.x = animOffsets[0] - character.globalOffsets[0];
    charOffset.y = animOffsets[1] - character.globalOffsets[1];

    this.antialiasing = character.antialiasing;
    this.scale.set(character.scale.x, character.scale.y);
    this.offset.set(character.offset.x, character.offset.y);
  }

  override function getScreenPosition(?result:FlxPoint, ?camera:flixel.FlxCamera):FlxPoint
  {
    var output:FlxPoint = super.getScreenPosition(result, camera);
    output.x -= charOffset.x * this.scale.x;
    output.y -= charOffset.y * this.scale.y;
    return output;
  }
}

package funkin.audio.visualize;

import flixel.FlxSprite;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.group.FlxSpriteGroup.FlxTypedSpriteGroup;
import flixel.sound.FlxSound;
import funkin.audio.visualize.VisualizerBase;

using Lambda;

class ABotVis extends FlxTypedSpriteGroup<FlxSprite>
{
  var vis:VisualizerBase;

  var volumes:Array<Float> = [];

  public var snd:FlxSound;

  public function new(snd:FlxSound)
  {
    super();

    this.snd = snd;

    vis = new VisualizerBase(snd, 7, 5);

    var visFrms:FlxAtlasFrames = Paths.getSparrowAtlas('aBotViz');

    // these are the differences in X position, from left to right
    var positionX:Array<Float> = [0, 59, 56, 66, 54, 52, 51];
    var positionY:Array<Float> = [0, -8, -3.5, -0.4, 0.5, 4.7, 7];

    for (lol in 1...8)
    {
      // pushes initial value
      volumes.push(0.0);
      var sum = function(num:Float, total:Float) return total += num;
      var posX:Float = positionX.slice(0, lol).fold(sum, 0);
      var posY:Float = positionY.slice(0, lol).fold(sum, 0);

      var viz:FlxSprite = new FlxSprite(posX, posY);
      viz.frames = visFrms;
      add(viz);

      var visStr = 'viz';
      viz.animation.addByPrefix('VIZ', visStr + lol, 0);
      viz.animation.play('VIZ', false, false, 6);
    }
  }

  public function initAnalyzer()
  {
    vis.snd = snd;
    vis.initAnalyzer(40);
  }

  override function draw()
  {
    if (vis.ready)
    {
      vis.updateFFT(drawFFT);
    }

    super.draw();
  }

  function drawFFT(i:Int, frame:Int):Void
  {
    group.members[i].animation.curAnim.curFrame = frame;
  }
}

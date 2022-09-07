package funkin.play.stage;

import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxPoint;
import flixel.system.FlxAssets.FlxShader;
import flixel.util.FlxSort;
import funkin.modding.IScriptedClass;
import funkin.modding.events.ScriptEvent;
import funkin.modding.events.ScriptEventDispatcher;
import funkin.play.character.BaseCharacter;
import funkin.play.stage.StageData.StageDataCharacter;
import funkin.play.stage.StageData.StageDataParser;
import funkin.util.SortUtil;
import funkin.util.assets.FlxAnimationUtil;

/**
 * A Stage is a group of objects rendered in the PlayState.
 * 
 * A Stage is comprised of one or more props, each of which is a FlxSprite.
 */
class Stage extends FlxSpriteGroup implements IPlayStateScriptedClass
{
	public final stageId:String;
	public final stageName:String;

	final _data:StageData;

	public var camZoom:Float = 1.0;

	var namedProps:Map<String, FlxSprite> = new Map<String, FlxSprite>();
	var characters:Map<String, BaseCharacter> = new Map<String, BaseCharacter>();
	var boppers:Array<Bopper> = new Array<Bopper>();

	/**
	 * The Stage elements get initialized at the beginning of the game.
	 * They're used to cache the data needed to build the stage,
	 * then accessed and fleshed out when the stage needs to be built.
	 * 
	 * @param stageId 
	 */
	public function new(stageId:String)
	{
		super();

		this.stageId = stageId;
		_data = StageDataParser.parseStageData(this.stageId);
		if (_data == null)
		{
			throw 'Could not find stage data for stageId: $stageId';
		}
		else
		{
			this.stageName = _data.name;
		}
	}

	/**
	 * Called when the player is moving into the PlayState where the song will be played.
	 */
	public function onCreate(event:ScriptEvent):Void
	{
		buildStage();
		this.refresh();

		debugIconGroup = new FlxSpriteGroup();
		debugIconGroup.visible = false;
		debugIconGroup.zIndex = 1000000;
		add(debugIconGroup);
	}

	public function resetStage():Void
	{
		// Reset positions of characters.
		if (getBoyfriend() != null)
		{
			getBoyfriend().resetCharacter(false);
		}
		else
		{
			trace('STAGE RESET: No boyfriend found.');
		}
		if (getGirlfriend() != null)
		{
			getGirlfriend().resetCharacter(false);
		}
		if (getDad() != null)
		{
			getDad().resetCharacter(false);
		}

		// Reset positions of named props.
		for (dataProp in _data.props)
		{
			// Fetch the prop.
			var prop:FlxSprite = getNamedProp(dataProp.name);

			if (prop != null)
			{
				// Reset the position.
				prop.x = dataProp.position[0];
				prop.y = dataProp.position[1];
				prop.zIndex = dataProp.zIndex;
			}
		}

		// We can assume unnamed props are not moving.
	}

	/**
	 * The default stage construction routine. Called when the stage is going to be played in.
	 * Instantiates each prop and adds it to the stage, while setting its parameters.
	 */
	function buildStage()
	{
		trace('Building stage for display: ${this.stageId}');

		this.camZoom = _data.cameraZoom;

		this.debugIconGroup = new FlxSpriteGroup();

		for (dataProp in _data.props)
		{
			trace('  Placing prop: ${dataProp.name} (${dataProp.assetPath})');

			var isAnimated = dataProp.animations.length > 0;

			var propSprite:FlxSprite;
			if (dataProp.danceEvery != 0)
			{
				propSprite = new Bopper(dataProp.danceEvery);
			}
			else
			{
				propSprite = new FlxSprite();
			}

			if (isAnimated)
			{
				// Initalize sprite frames.
				switch (dataProp.animType)
				{
					case "packer":
						propSprite.frames = Paths.getPackerAtlas(dataProp.assetPath);
					default: // "sparrow"
						propSprite.frames = Paths.getSparrowAtlas(dataProp.assetPath);
				}
			}
			else
			{
				// Initalize static sprite.
				propSprite.loadGraphic(Paths.image(dataProp.assetPath));

				// Disables calls to update() for a performance boost.
				propSprite.active = false;
			}

			if (propSprite.frames == null || propSprite.frames.numFrames == 0)
			{
				trace('    ERROR: Could not build texture for prop.');
				continue;
			}

			if (Std.isOfType(dataProp.scale, Array))
			{
				propSprite.scale.set(dataProp.scale[0], dataProp.scale[1]);
			}
			else
			{
				propSprite.scale.set(dataProp.scale);
			}
			propSprite.updateHitbox();

			propSprite.x = dataProp.position[0];
			propSprite.y = dataProp.position[1];

			propSprite.alpha = dataProp.alpha;

			// If pixel, disable antialiasing.
			propSprite.antialiasing = !dataProp.isPixel;

			propSprite.scrollFactor.x = dataProp.scroll[0];
			propSprite.scrollFactor.y = dataProp.scroll[1];

			propSprite.zIndex = dataProp.zIndex;

			switch (dataProp.animType)
			{
				case "packer":
					for (propAnim in dataProp.animations)
					{
						propSprite.animation.add(propAnim.name, propAnim.frameIndices);

						if (Std.isOfType(propSprite, Bopper))
						{
							cast(propSprite, Bopper).setAnimationOffsets(propAnim.name, propAnim.offsets[0], propAnim.offsets[1]);
						}
					}
				default: // "sparrow"
					FlxAnimationUtil.addAtlasAnimations(propSprite, dataProp.animations);
					if (Std.isOfType(propSprite, Bopper))
					{
						for (propAnim in dataProp.animations)
						{
							cast(propSprite, Bopper).setAnimationOffsets(propAnim.name, propAnim.offsets[0], propAnim.offsets[1]);
						}
					}
			}

			if (Std.isOfType(propSprite, Bopper))
			{
				for (propAnim in dataProp.animations)
				{
					cast(propSprite, Bopper).setAnimationOffsets(propAnim.name, propAnim.offsets[0], propAnim.offsets[1]);
				}
				cast(propSprite, Bopper).originalPosition.x = dataProp.position[0];
				cast(propSprite, Bopper).originalPosition.y = dataProp.position[1];
			}

			if (dataProp.startingAnimation != null)
			{
				propSprite.animation.play(dataProp.startingAnimation);
			}

			if (Std.isOfType(propSprite, Bopper))
			{
				addBopper(cast propSprite, dataProp.name);
			}
			else
			{
				addProp(propSprite, dataProp.name);
			}
			trace('    Prop placed.');
		}
	}

	/**
	 * Add a sprite to the stage.
	 * @param prop The sprite to add.
	 * @param name (Optional) A unique name for the sprite.
	 *   You can call `getNamedProp(name)` to retrieve it later.
	 */
	public function addProp(prop:FlxSprite, ?name:String = null)
	{
		if (name != null)
		{
			namedProps.set(name, prop);
		}
		this.add(prop);
	}

	/**
	 * Add a sprite to the stage which animates to the beat of the song.
	 */
	public function addBopper(bopper:Bopper, ?name:String = null)
	{
		boppers.push(bopper);
		this.addProp(bopper, name);
	}

	/**
	 * Refreshes the stage, by redoing the render order of all props.
	 * It does this based on the `zIndex` of each prop.
	 */
	public function refresh()
	{
		sort(SortUtil.byZIndex, FlxSort.ASCENDING);
	}

	public function setShader(shader:FlxShader)
	{
		forEachAlive(function(prop:FlxSprite)
		{
			prop.shader = shader;
		});
	}

	/**
	 * Adjusts the position and other properties of the soon-to-be child of this sprite group.
	 * Private helper to avoid duplicate code in `add()` and `insert()`.
	 *
	 * @param	Sprite	The sprite or sprite group that is about to be added or inserted into the group.
	 */
	override function preAdd(Sprite:FlxSprite):Void
	{
		var sprite:FlxSprite = cast Sprite;
		sprite.x += x;
		sprite.y += y;
		sprite.alpha *= alpha;
		// Don't override scroll factors.
		// sprite.scrollFactor.copyFrom(scrollFactor);
		sprite.cameras = _cameras; // _cameras instead of cameras because get_cameras() will not return null

		if (clipRect != null)
			clipRectTransform(sprite, clipRect);
	}

	var debugIconGroup:FlxSpriteGroup;

	/**
	 * Used by the PlayState to add a character to the stage.
	 */
	public function addCharacter(character:BaseCharacter, charType:CharacterType)
	{
		if (character == null)
			return;

		#if debug
		// Temporary marker that shows where the character's location is relative to.
		// Should display at the stage position of the character (before any offsets).
		// TODO: Make this a toggle? It's useful to turn on from time to time.
		var debugIcon:FlxSprite = new FlxSprite(0, 0);
		var debugIcon2:FlxSprite = new FlxSprite(0, 0);
		debugIcon.makeGraphic(8, 8, 0xffff00ff);
		debugIcon2.makeGraphic(8, 8, 0xff00ffff);
		debugIcon.visible = true;
		debugIcon2.visible = true;
		debugIcon.zIndex = 1000000;
		debugIcon2.zIndex = 1000000;
		#end

		// Apply position and z-index.
		var charData:StageDataCharacter = null;
		switch (charType)
		{
			case BF:
				this.characters.set("bf", character);
				charData = _data.characters.bf;
				character.flipX = !character.getDataFlipX();
				character.initHealthIcon(false);
			case GF:
				this.characters.set("gf", character);
				charData = _data.characters.gf;
				character.flipX = character.getDataFlipX();
			case DAD:
				this.characters.set("dad", character);
				charData = _data.characters.dad;
				character.flipX = character.getDataFlipX();
				character.initHealthIcon(true);
			default:
				this.characters.set(character.characterId, character);
		}

		// Reset the character before adding it to the stage.
		// This ensures positioning is based on the idle animation.
		character.resetCharacter(true);

		if (charData != null)
		{
			character.zIndex = charData.zIndex;

			// Start with the per-stage character position.
			// Subtracting the origin ensures characters are positioned relative to their feet.
			// Subtracting the global offset allows positioning on a per-character basis.
			character.x = charData.position[0] - character.characterOrigin.x + character.globalOffsets[0];
			character.y = charData.position[1] - character.characterOrigin.y + character.globalOffsets[1];

			character.originalPosition.x = character.x;
			character.originalPosition.y = character.y;

			character.cameraFocusPoint.x += charData.cameraOffsets[0];
			character.cameraFocusPoint.y += charData.cameraOffsets[1];

			#if debug
			// Draw the debug icon at the character's feet.
			if (charType == BF || charType == DAD)
			{
				debugIcon.x = charData.position[0];
				debugIcon.y = charData.position[1];
				debugIcon2.x = character.x;
				debugIcon2.y = character.y;
			}
			#end
		}

		// Add the character to the scene.
		this.add(character);

		#if debug
		debugIconGroup.add(debugIcon);
		debugIconGroup.add(debugIcon2);
		#end
	}

	public inline function getGirlfriendPosition():FlxPoint
	{
		return new FlxPoint(_data.characters.gf.position[0], _data.characters.gf.position[1]);
	}

	public inline function getBoyfriendPosition():FlxPoint
	{
		return new FlxPoint(_data.characters.bf.position[0], _data.characters.bf.position[1]);
	}

	public inline function getDadPosition():FlxPoint
	{
		return new FlxPoint(_data.characters.dad.position[0], _data.characters.dad.position[1]);
	}

	/**
	 * Retrieves a given character from the stage.
	 */
	public function getCharacter(id:String):BaseCharacter
	{
		return this.characters.get(id);
	}

	/**
	 * Retrieve the Boyfriend character.
	 * @param pop If true, the character will be removed from the stage as well.
	 */
	public function getBoyfriend(?pop:Bool = false):BaseCharacter
	{
		if (pop)
		{
			var boyfriend:BaseCharacter = getCharacter("bf");

			// Remove the character from the stage.
			this.remove(boyfriend);
			this.characters.remove("bf");

			return boyfriend;
		}
		else
		{
			return getCharacter('bf');
		}
	}

	public function getGirlfriend():BaseCharacter
	{
		return getCharacter('gf');
	}

	public function getDad():BaseCharacter
	{
		return getCharacter('dad');
	}

	/**
	 * Retrieve a specific prop by the name assigned in the JSON file.
	 * @param name The name of the prop to retrieve.
	 * @return The corresponding FlxSprite.
	 */
	public function getNamedProp(name:String):FlxSprite
	{
		return this.namedProps.get(name);
	}

	/**
	 * Retrieve a list of all the asset paths required to load the stage.
	 * Override this in a scripted class to ensure that all necessary assets are loaded!
	 * 
	 * @return An array of file names.
	 */
	public function fetchAssetPaths():Array<String>
	{
		var result:Array<String> = [];
		for (dataProp in _data.props)
		{
			result.push(Paths.image(dataProp.assetPath));
		}
		return result;
	}

	/**
	 * Dispatch an event to all the characters in the stage.
	 * @param event The script event to dispatch.
	 */
	public function dispatchToCharacters(event:ScriptEvent):Void
	{
		for (characterId in characters.keys())
		{
			dispatchToCharacter(characterId, event);
		}
	}

	/**
	 * Dispatch an event to a specific character.
	 * @param characterId The ID of the character to dispatch to.
	 * @param event The script event to dispatch.
	 */
	public function dispatchToCharacter(characterId:String, event:ScriptEvent):Void
	{
		var character:BaseCharacter = getCharacter(characterId);
		if (character != null)
		{
			ScriptEventDispatcher.callEvent(character, event);
		}
	}

	/**
	 * onDestroy gets called when the player is leaving the PlayState,
	 * and is used to clean up any objects that need to be destroyed.
	 */
	public function onDestroy(event:ScriptEvent):Void
	{
		// Make sure to call kill() when returning a stage to cache,
		// and destroy() only when performing a hard cache refresh.
		kill();

		for (prop in this.namedProps)
		{
			if (prop != null)
			{
				remove(prop);
				prop.kill();
				prop.destroy();
			}
		}
		namedProps.clear();

		for (char in this.characters)
		{
			if (char != null)
			{
				remove(char);
				char.kill();
				char.destroy();
			}
		}
		characters.clear();

		for (bopper in boppers)
		{
			if (bopper != null)
			{
				remove(bopper);
				bopper.kill();
				bopper.destroy();
			}
		}
		boppers = [];

		for (sprite in this.group)
		{
			if (sprite != null)
			{
				sprite.kill();
				sprite.destroy();
				remove(sprite);
			}
		}
		group.clear();
		if (debugIconGroup != null && debugIconGroup.group != null)
		{
			debugIconGroup.kill();
		}
		else
		{
			debugIconGroup = null;
		}
	}

	/**
	 * A function that gets called once per step in the song.
	 * @param curStep The current step number.
	 */
	public function onStepHit(event:SongTimeScriptEvent):Void
	{
	}

	/**
	 * A function that gets called once per beat in the song (once every four steps).
	 * @param curStep The current beat number.
	 */
	public function onBeatHit(event:SongTimeScriptEvent):Void
	{
		// Override me in your scripted stage to perform custom behavior!
		// Make sure to call super.onBeatHit(curBeat) if you want to keep the boppers dancing.

		for (bopper in boppers)
		{
			ScriptEventDispatcher.callEvent(bopper, event);
		}
	}

	public function onUpdate(event:UpdateScriptEvent)
	{
		if (FlxG.keys.justPressed.F3)
		{
			debugIconGroup.visible = !debugIconGroup.visible;
		}
	}

	public function onScriptEvent(event:ScriptEvent)
	{
	}

	public function onPause(event:PauseScriptEvent)
	{
	}

	public function onResume(event:ScriptEvent)
	{
	}

	public function onSongStart(event:ScriptEvent)
	{
	}

	public function onSongEnd(event:ScriptEvent)
	{
	}

	public function onGameOver(event:ScriptEvent)
	{
	}

	public function onCountdownStart(event:CountdownScriptEvent)
	{
	}

	public function onCountdownStep(event:CountdownScriptEvent)
	{
	}

	public function onCountdownEnd(event:CountdownScriptEvent)
	{
	}

	public function onNoteHit(event:NoteScriptEvent)
	{
	}

	public function onNoteMiss(event:NoteScriptEvent)
	{
	}

	public function onNoteGhostMiss(event:GhostMissNoteScriptEvent)
	{
	}

	public function onSongLoaded(event:SongLoadScriptEvent)
	{
	}

	public function onSongRetry(event:ScriptEvent)
	{
	}
}

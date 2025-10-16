package funkin.ui.debug.mods;

import flixel.FlxG;
import funkin.audio.FunkinSound;
import funkin.input.Cursor;
import funkin.modding.PolymodHandler;
import funkin.save.Save;
import funkin.ui.debug.mods.components.ModInfoWindow;
import funkin.ui.debug.mods.components.ModButton;
import haxe.ui.backend.flixel.UISubState;
import haxe.ui.events.UIEvent;
import haxe.ui.components.Button;
import haxe.ui.containers.VBox;
import funkin.util.FileUtil;
import haxe.ui.containers.windows.WindowManager;
import haxe.ui.tooltips.ToolTipManager;
import polymod.util.DependencyUtil;
import polymod.Polymod.ModMetadata;
import thx.semver.VersionRule;

using StringTools;

@:build(haxe.ui.ComponentBuilder.build("modmenu_assets/data/ui/mod-select/main-view.xml"))
class ModsSelectState extends UISubState
{
  /**
   * The path that the mod list pulls from.
   */
  public static final MOD_LIST_PATH:String = "mods.json";

  /**
   * If new mods should be enabled by default.
   */
  public static final NEW_MOD_ENABLE_DEFAULT:Bool = true;

  var modListLoadedBox:VBox;
  var modListUnloadedBox:VBox;
  var modListLoadAll:Button;
  var modListUnloadAll:Button;
  var modListApplyButton:Button;
  var modListExitButton:Button;

  var prevPersistentDraw:Bool;
  var prevPersistentUpdate:Bool;

  /**
   * A list for all enabled mods. The main point of this list is to provide priorities of enabled mods without focusing on dependencies.
   * Polymod handles sorting by dependencies internally upon loading mods.
   */
  var changeableModList:Array<String> = [];

  override public function create()
  {
    super.create();

    prevPersistentDraw = FlxG.state.persistentDraw;
    prevPersistentUpdate = FlxG.state.persistentUpdate;

    FlxG.state.persistentDraw = false;
    FlxG.state.persistentUpdate = false;

    Cursor.show();
    WindowManager.instance.reset();

    changeableModList = PolymodHandler.getEnabledModIds().copy();
    reloadModOrder();

    modListLoadAll.onClick = function(_) {
      changeableModList = PolymodHandler.getAllModIds().copy();
      reloadModOrder();
    }

    modListUnloadAll.onClick = function(_) {
      changeableModList = [];
      reloadModOrder();
    }

    modListLoadedBox.registerEvent(UIEvent.COMPONENT_ADDED, function(_) {
      modListApplyButton.disabled = false;
    });
    modListUnloadedBox.registerEvent(UIEvent.COMPONENT_ADDED, function(_) {
      modListApplyButton.disabled = false;
    });

    modListApplyButton.onClick = function(_) save();
    modListExitButton.onClick = function(_) close();
  }

  // This should also account for the mod order and put dependencies on the bottom.
  function reloadModOrder()
  {
    modListUnloadedBox.removeAllComponents();
    modListLoadedBox.removeAllComponents();

    var allMods:Array<ModMetadata> = listAllModsOrdered();

    for (mod in allMods)
    {
      var isLoaded:Bool = changeableModList.contains(mod.id);
      var button = new ModButton(mod);
      button.tooltip = "Click to Enable/Disable.\nRight Click to View Info.";
      if (isLoaded) button.tooltip += "\nShift+Click to Move Upwards.\nCtrl+Click to Move Downwards.";

      button.onRightClick = function(_) {
        // Do not refresh if there is no change in the mods.
        if (windowContainer.childComponents.length > 0)
        {
          var firstComp = windowContainer.childComponents[0];
          if (Std.isOfType(firstComp, ModInfoWindow))
          {
            var modWindow:ModInfoWindow = cast firstComp;
            if (mod.id == modWindow.linkedMod.id) return;
          }
        }

        cleanupBeforeSwitch();
        button.styleNames = "modBoxSelected";
        var infoWindow = new ModInfoWindow(this, mod);
        windowContainer.addComponent(infoWindow);
      }

      button.onClick = function(_) {
        if (isLoaded)
        {
          var modIndex:Int = changeableModList.indexOf(mod.id);
          if (FlxG.keys.pressed.SHIFT) modIndex++;
          else if (FlxG.keys.pressed.CONTROL) modIndex--;

          var prevIndex:Int = changeableModList.indexOf(mod.id);
          changeableModList.remove(mod.id);

          if (prevIndex != modIndex)
          {
            // The priority of the mod has been changed.
            modIndex = Std.int(flixel.math.FlxMath.bound(modIndex, 0, changeableModList.length - 1));
            changeableModList.insert(modIndex, mod.id);
          }
          else
          {
            // Go through a list of all mods. If a mod depends on this mod to works and this mod's version satisfies the mod's version rule, remove it from the list.
            for (childMod in allMods)
            {
              if (childMod.dependencies.exists(mod.id)
                && childMod.dependencies[mod.id].isSatisfiedBy(mod.modVersion)
                && changeableModList.contains(childMod.id)) changeableModList.remove(childMod.id);
            }
          }
        }
        else
        {
          changeableModList.push(mod.id);

          // Go through a list of all mods. If a mod is a dependency of this mod and it's version satisfies this mod's version rule, add it to the list.
          for (childMod in allMods)
          {
            if (mod.dependencies.exists(childMod.id)
              && mod.dependencies[childMod.id].isSatisfiedBy(childMod.modVersion)
              && !changeableModList.contains(childMod.id)) changeableModList.push(childMod.id);
          }
        }

        reloadModOrder();
      }

      if (isLoaded) modListLoadedBox.addComponent(button);
      else
        modListUnloadedBox.addComponent(button);
    }

    // Check if there is a window present and apply a different style to the corresponding button.
    if (windowContainer.childComponents.length > 0 && Std.isOfType(windowContainer.childComponents[0], ModInfoWindow))
    {
      var modWindow:ModInfoWindow = cast windowContainer.childComponents[0];
      for (button in modListUnloadedBox.childComponents.concat(modListLoadedBox.childComponents))
      {
        if (!Std.isOfType(button, ModButton)) continue;
        var realButton:ModButton = cast button;

        if (realButton.linkedMod.id == modWindow.linkedMod.id && realButton.linkedMod.modVersion == modWindow.linkedMod.modVersion)
        {
          realButton.styleNames = "modBoxSelected";
          colorButtonLabels(realButton.linkedMod.dependencies.keys().array(), realButton.linkedMod.optionalDependencies.keys().array());
          break;
        }
      }
    }
  }

  /**
   * Order the mods so that the enabled mods are first.
   */
  function listAllModsOrdered()
  {
    var allMods:Array<ModMetadata> = PolymodHandler.getAllMods().copy();
    var finishedList:Array<ModMetadata> = [];

    for (modId in changeableModList)
    {
      for (mod in allMods)
      {
        if (mod.id == modId)
        {
          finishedList.push(mod);
          allMods.remove(mod);
          break;
        }
      }
    }

    // Order the enabled mods by dependencies.
    finishedList = DependencyUtil.sortByDependencies(finishedList);

    // Add the remainding mods.
    finishedList = finishedList.concat(allMods);

    // Reverse the list so that the first mods go down.
    finishedList.reverse();

    return finishedList;
  }

  /**
   * A clean-up of the menu to do before selecting another mod.
   */
  function cleanupBeforeSwitch()
  {
    for (window in WindowManager.instance.windows)
      WindowManager.instance.closeWindow(window);

    for (button in modListUnloadedBox.childComponents.concat(modListLoadedBox.childComponents))
    {
      if (Std.isOfType(button, ModButton))
      {
        var realButton:ModButton = cast button;
        realButton.styleNames = "modBox";
      }
    }

    windowContainer.removeAllComponents();
  }

  /**
   * Color the buttons based on the provided arrays of required and optional mod ids.
   */
  function colorButtonLabels(?required:Array<String>, ?optional:Array<String>)
  {
    if (required == null) required = [];
    if (optional == null) optional = [];

    for (button in modListUnloadedBox.childComponents.concat(modListLoadedBox.childComponents))
    {
      if (Std.isOfType(button, ModButton))
      {
        var realButton:ModButton = cast button;
        if (optional.contains(realButton.id) && !required.contains(realButton.id)) realButton.modButtonLabel.styleString = "color: 0xffff00;"
        else if (!optional.contains(realButton.id) && required.contains(realButton.id)) realButton.modButtonLabel.styleString = "color: 0xff8c00;";
        else
          realButton.modButtonLabel.styleString = "color: $normal-text-color;";
      }
    }
  }

  override public function close()
  {
    FlxG.state.persistentDraw = prevPersistentDraw;
    FlxG.state.persistentUpdate = prevPersistentUpdate;

    FlxG.sound.music.fadeOut(0.5, 0, function(tw) {
      FunkinSound.playMusic('freakyMenu',
        {
          startingVolume: 0,
          overrideExisting: true,
          restartTrack: true,
          persist: true
        });
      FlxG.sound.music.fadeIn(0.5, 1);
    });

    Cursor.hide();
    WindowManager.instance.reset();
    ToolTipManager.instance.reset();

    super.close();
  }

  /**
   * Load the selected mods.
   */
  function save()
  {
    trace("[MODMENU] Loading Mods: " + changeableModList);

    var modList:Array<ModListEntry> = [];
    for (modID in changeableModList)
      modList.push(new ModListEntry(modID, true));

    for (modID in PolymodHandler.getAllModIds())
    {
      if (!changeableModList.contains(modID)) modList.push(new ModListEntry(modID, false));
    }

    writeModsList(modList);
    PolymodHandler.forceReloadAssets();
    modListApplyButton.disabled = true;
  }

  override public function update(elapsed:Float)
  {
    super.update(elapsed);

    if (FlxG.mouse.justPressed || FlxG.mouse.justPressedRight)
    {
      FunkinSound.playOnce(Paths.sound("chartingSounds/ClickDown"));
    }

    if (FlxG.mouse.justReleased || FlxG.mouse.justReleasedRight)
    {
      FunkinSound.playOnce(Paths.sound("chartingSounds/ClickUp"));
    }

    if (controls.BACK) close();
    if (controls.ACCEPT) save();
  }

  /**
   * Reads the mods list, and adds new mods if they exist.
   * @return The
   */
  public static function getModsList():Array<ModListEntry>
  {
    var allMods:Array<ModMetadata> = PolymodHandler.getAllMods();
    var toReturn:Array<ModListEntry> = [];

    if (!FileUtil.fileExists(MOD_LIST_PATH))
    {
      // Compatability to other mod menus. (+ the original)
      for (mod in allMods)
      {
        toReturn.push(new ModListEntry(mod.id, Save.instance.enabledModIds.contains(mod.id)));
      }

      writeModsList(toReturn);
      return toReturn;
    }

    var parser = new json2object.JsonParser<Array<ModListEntry>>();
    parser.ignoreUnknownVariables = true;
    trace('[MODMENU] Parsing mod list...');

    var contents:String = FileUtil.readStringFromPath(MOD_LIST_PATH);
    parser.fromJson(contents, haxe.io.Path.withoutExtension(MOD_LIST_PATH));

    if (parser.errors.length > 0)
    {
      trace('[MODMENU] Failed to parse mod list!');
      for (error in parser.errors)
        funkin.data.DataError.printError(error);
    }
    else
    {
      toReturn = parser.value;
    }

    var originalLength:Int = toReturn.length;
    var modListIds:Array<String> = modsListToIdList(toReturn, false);

    for (mod in allMods)
    {
      if (!modListIds.contains(mod.id))
      {
        toReturn.push(new ModListEntry(mod.id, NEW_MOD_ENABLE_DEFAULT));
      }
    }

    if (toReturn.length != originalLength)
    {
      writeModsList(toReturn);
    }

    trace(toReturn);

    return toReturn;
  }

  /**
   * Writes the mod list.
   * @param list The mod list to write.
   * @param pretty If this should be formatted pretty or not.
   */
  public static function writeModsList(list:Array<ModListEntry>, ?pretty:Bool = true):Void
  {
    // That errors. Cool!
    var writer = new json2object.JsonWriter<Array<ModListEntry>>();
    var content:String = writer.write(list, pretty ? '  ' : null);

    FileUtil.writeStringToPath(MOD_LIST_PATH, content, Force);

    // Compatability to other mod menus. (+ the original)
    var enabledModIds:Array<String> = [];
    for (entry in list)
    {
      if (entry.enabled)
      {
        enabledModIds.push(entry.modID);
      }
    }
    Save.instance.enabledModIds = enabledModIds;
  }

  /**
   * Converts a mod list into an ID list.
   * @param list The mod list. If `null`, a mods list will be searched for.
   * @param onlyEnabled If the list should only return enabled mods.
   * @return The ID List.
   */
  public static function modsListToIdList(?list:Null<Array<ModListEntry>>, ?onlyEnabled:Bool = true):Array<String>
  {
    if (list == null) list = ModsSelectState.getModsList();
    var toReturn:Array<String> = [];

    for (mod in list)
    {
      if (onlyEnabled ? mod.enabled : true) toReturn.push(mod.modID);
    }

    return toReturn;
  }
}

/**
 * Entry for the mod list.
 */
class ModListEntry
{
  /**
   * The internal ID of the mod.
   * This is used to get further mod data.
   */
  public var modID(default, set):String;

  /**
   * If the mod is enabled or not.
   */
  @:default(true)
  @:optional
  public var enabled:Bool;

  /**
   * The Polymod Metadata.
   * Heavily linked to `modID`.
   */
  @:jignored
  public var metadata(get, never):ModMetadata;

  /**
   * Creates the mod list entry item.
   * @param modID The internal ID of the mod.
   * @param enabled If the mod should be enabled or not.
   */
  public function new(modID:String, enabled:Bool)
  {
    _metadata = null;

    this.modID = modID;
    this.enabled = enabled;
  }

  /**
   * Clones this entry.
   * @return Cloned entry.
   */
  public function clone():ModListEntry
  {
    var result:ModListEntry = new ModListEntry(this.modID, this.enabled);
    result._metadata = this.metadata;
    return result;
  }

  public function toString():String
  {
    return 'ModListEntry(${this.modID}, is ${this.enabled ? 'enabled' : 'disabled'})';
  }

  /**
   * Internal, metadata cache.
   */
  @:jignored
  var _metadata:ModMetadata;

  function set_modID(value:String):String
  {
    this._metadata = null;
    this.modID = value;
    return value;
  }

  function get_metadata():ModMetadata
  {
    if (this._metadata == null)
    {
      var mods:Array<ModMetadata> = PolymodHandler.getAllMods();
      for (mod in mods)
      {
        if (mod.id == modID)
        {
          this._metadata = mod;
          break;
        }
      }
    }

    return this._metadata;
  }
}

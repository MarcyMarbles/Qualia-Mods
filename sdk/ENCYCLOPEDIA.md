# QualiaMods Encyclopedia

Everything about QualiaMods in one place. If something isn't covered here, check the source or ask.

## How it works

The game ships with a basic `ModLoader` that loads `.pck` files from `mods/`. QualiaMods is delivered as `_000_qualiamods.pck` (the `_000_` prefix makes it load first). It hijacks the ModLoader node via `set_script()` from a modified `ref.gd` and replaces it with the full framework.

Boot sequence:
1. Vanilla ModLoader loads all .pck files
2. `Ref._ready()` loads `qualiamods.gd` and hot-swaps the ModLoader script
3. QualiaMods scans for mods, reads their metadata, sorts by dependencies, initializes them
4. Game hooks get connected, mods receive `_game_ready()`

Your mod doesn't need to care about any of this. Just implement the lifecycle methods and use the API.

## Making a compatible mod

Add these two files inside your .pck:

```
res://mods/yourmod/
  mod.cfg
  mod_main.gd
```

Without them the mod is "resource-only" - it loads fine but QualiaMods can't give it lifecycle calls or show it properly in the menu.

## mod.cfg

```ini
[mod]
name = "My Mod"
version = "1.0.0"
author = "My Name"
description = "Smthing"
game_version = "2.8.5"
load_order = 10               # lower loads first
config_editable = true         # let users tweak config in the mods menu

[dependencies]
some_library = true            # requires some_library.pck

[config]
my_toggle = true               # shows as a checkbox
my_slider = 1.5                # shows as a spinbox
my_text = "default"            # shows as a text field
```

Users can override config values by placing `mods/yourmod.cfg` next to the .pck. Those values get merged on top of your defaults.

## Lifecycle

All optional. Implement what you need in `mod_main.gd`.

**`_init_mod(config: Dictionary)`** - First thing that gets called. You get the merged config here. Good place to subscribe to hooks. DO NOT ACCESS `Ref`, the game tree isn't ready.

**`_game_ready()`** - Game tree is up. `Ref.player`, `Ref.world` etc. work now. Do your injections and setup here.

**`_on_config_changed(new_config: Dictionary)`** - User changed something in the Mods Menu. Apply it if you can.

**`_on_mod_message(sender_id: String, data: Dictionary)`** - Another mod sent you something.

**`_mod_cleanup()`** - Game is shutting down. Save what you need to save.

## Hooks

```gdscript
# subscribe
ModLoader.add_hook(ModLoader.Hooks.GAME_PLAYABLE, _my_callback)

# unsubscribe
ModLoader.remove_hook(ModLoader.Hooks.GAME_PLAYABLE, _my_callback)

# fire your own (other mods can subscribe to it)
ModLoader.emit_hook("mymod_did_something", [some_data])
```

Built-in hooks:

| Hook | When it fires |
|---|---|
| `game_playable` | Player can move around |
| `world_loaded` | World finished loading |
| `all_loaded` | Everything's loaded |
| `new_game_loaded` | Fresh world created |
| `game_quit` | Game is closing |
| `mods_all_ready` | All mods done initializing |
| `items_pre_load` | Right before items get scanned |
| `items_post_load` | Not wired yet, sorry |
| `scene_injected` | After a node injection succeeds (args: parent_path, node) |
| `config_changed` | Config saved in mods menu (args: mod_id, new_config) |

Hooks fire in the order mods subscribed. No priority system for now.

## API

### Injecting stuff into the game

```gdscript
# add a node somewhere in the tree
ModLoader.inject_node("Main/UI", my_label)

# same but from a PackedScene
var instance = ModLoader.inject_scene("Main/UI", my_scene)

# swap out an existing node (keeps position in tree)
ModLoader.replace_node("Main/UI/SomeWidget", my_replacement)

# safe getter that returns null instead of crashing
var node = ModLoader.get_game_node("Main/Player")
```

If the parent doesn't exist yet when you call `inject_node`, it gets queued and processed when the tree is ready.

### Items

```gdscript
# register a folder of .tres items for ItemMap to pick up
ModLoader.register_items("res://mods/mymod/items/")

# or hot-load a single item
ModLoader.register_item_resource("res://mods/mymod/items/cool_sword.tres")
```

`register_item_resource` can inject directly into ItemMap if items are already loaded, or queue it for later.

### Method patching

You can wrap methods on game objects. Your wrapper gets the original method as a callable, so you can modify args, skip the call, or do whatever.

```gdscript
ModLoader.wrap_method(Ref.player, "take_damage", func(original, amount):
    ModLoader.log_mod("mymod", "Halving damage: %d -> %d" % [amount, amount / 2])
    original.call(amount / 2)
)
```

To undo it:
```gdscript
ModLoader.unwrap_method(Ref.player, "take_damage", my_wrapper)
```

Keep in mind this is callable-chain wrapping, not bytecode patching. You can intercept and redirect calls, but you can't edit what happens inside the original method. The original still runs unless your wrapper deliberately doesn't call it.

### UI helpers

```gdscript
# add a tab to the in-game menu (the one you open with E)
ModLoader.add_game_menu_tab("my tab", my_panel)

# add a button to the main menu
ModLoader.add_main_menu_button("some button", func(): print("hey"))
```

### Settings Tab (v1.1.0+)

Add a custom tab to the game's Settings Menu with proper sliders, toggles, and dropdowns that match the game's native look. Values auto-save and auto-load when a save prefix is set.

```gdscript
func _game_ready() -> void:
    var tab = ModLoader.add_settings_tab("My Settings")
    tab.set_save_prefix("mymod_")  # auto-persistence

    # Controls — each returns the native Godot control for extra customization
    tab.add_slider("amount", "my_amount", 0.0, 1.0, 0.05, 0.5)   # HSlider
    tab.add_toggle("feature", "my_feature", false)                  # CheckButton
    tab.add_option("mode", "my_mode", ["off", "low", "high"], 0)   # OptionButton
    tab.add_spinbox("count", "my_count", 0, 100, 1, 10)            # SpinBox
    tab.add_color("tint", "my_color", Color.WHITE)                  # ColorPickerButton
    tab.add_text_input("name", "my_name", "default")                # LineEdit

    # Visual elements (no key, not saved)
    tab.add_header("section title")     # dimmed label
    tab.add_separator()                 # horizontal line
    tab.add_label("info text here")     # auto-wrapping text
    tab.add_spacer(8.0)                 # vertical gap
    tab.add_custom(my_control)          # any Control node

    # Load saved values, connect to save
    tab.load_values()
    tab.saved.connect(_on_settings_saved)

func _on_settings_saved(values: Dictionary) -> void:
    # values = {"my_amount": 0.7, "my_feature": true, "my_mode": 2, ...}
    _apply(values)
```

**Reading/writing values at any time:**

```gdscript
tab.get_value("my_amount")              # current control value
tab.set_value("my_amount", 0.8)         # update control
tab.set_values({"a": 1, "b": true})     # bulk set (great for presets)
tab.get_all_values()                     # Dictionary of everything
tab.get_container()                      # raw VBoxContainer for full control
```

**How persistence works:**

When `set_save_prefix("mymod_")` is set:
- On Settings Menu **save** → all values written to `settings_file` as `mymod_amount`, `mymod_feature`, etc.
- On Settings Menu **open** → values loaded from `settings_file` back into controls.
- First launch uses the `default_value` you passed to `add_slider`/`add_toggle`/etc.

**Cleanup:**

```gdscript
tab.remove()  # removes the tab from Settings Menu
```

### Talking to other mods

```gdscript
# send to a specific mod (it needs _on_mod_message)
ModLoader.send_message("other_mod", "my_mod", {"action": "sync"})

# broadcast to everyone
ModLoader.broadcast_message("my_mod", {"event": "explosion", "pos": Vector3(1,2,3)})
```

### Resources

Generic resource registration if you need to share paths between mods:

```gdscript
ModLoader.register_resource("recipes", "res://mods/mymod/recipes/")
var all_recipes = ModLoader.get_registered_resources("recipes")
```

### Info and logging

```gdscript
ModLoader.log_mod("mymod", "something happened")       # prints [mymod] something happened
ModLoader.is_mod_loaded("other_mod")                    # true/false
ModLoader.get_config("other_mod", "some_key", default)  # read another mod's config
ModLoader.get_load_order()                               # ["mod_a", "mod_b", ...]
var info = ModLoader.get_mod("mymod")                    # ModInfo object
```

### Signals

`ModLoader.mods_initialized` - all mods are done with `_init_mod`
`ModLoader.mod_loaded(mod_id)` - individual mod finished loading

## Mods Menu

Press F10 (you can change this in `mods/qualiamods.cfg`) or hit the "mods" button in the main menu.

You can see all loaded mods, toggle them on/off (needs restart), check their info and dependencies, and edit their config values if the mod allows it. Saving config calls `_on_config_changed()` immediately, no restart needed for that.

```ini
# mods/qualiamods.cfg
[config]
key_menu = F10
```

## Dependencies

If your mod needs another mod to work, declare it:

```ini
[dependencies]
library_mod = true
```

QualiaMods checks that `library_mod.pck` exists and is enabled. If not, your mod gets disabled with a warning in the log. Circular dependencies are detected too.

Load order: dependencies first (topological sort), then `load_order` field, then alphabetical.

## Ref cheat sheet

`Ref` is the game's autoload with references to all the important nodes. Only use these in `_game_ready()` or later.

**World:** `Ref.main`, `Ref.world`, `Ref.weather`, `Ref.entity_spawner`, `Ref.sun`, `Ref.sky`, `Ref.environment`

**Player:** `Ref.player`, `Ref.player_camera`, `Ref.player_inventory`, `Ref.player_hotbar`, `Ref.player_fuser`, `Ref.player_equipment`

**Managers:** `Ref.save_file_manager`, `Ref.audio_manager`, `Ref.plot_manager`, `Ref.boss_manager`, `Ref.discovery_manager`, `Ref.shader_loader`

**UI:** `Ref.ui`, `Ref.trans`, `Ref.game_menu`, `Ref.settings_menu`, `Ref.world_edit_menu`, `Ref.dither_filter`

For fog stuff: `Ref.environment.environment.volumetric_fog_enabled` / `.default_volumetric_fog_density`

For transitions: `await Ref.trans.open()` / `await Ref.trans.close()`

For save data: `Ref.save_file_manager.settings_file.set_data(key, value)` (global) or `Ref.save_file_manager.loaded_file_register.set_data(key, value)` (per-world). Use a prefix like `mod_yourmod_` to avoid clashing with other mods.

## Known limitations

- No hot-reload. Toggling a mod off in the menu writes to a config file, actual unload happens on restart.
- Method patching is callable-chain only. Can't touch method internals.
- No sandboxing. Mods run as regular GDScript with full access. A broken mod will break things.
- Game updates might break stuff. If Lucy changes node paths or ref.gd, QualiaMods needs updating.
- No auto-updater. You download new versions manually.
- Two mods replacing the same node or patching the same method can conflict. No detection for this yet.
- If a mod writes garbage into save data, disabling the mod won't clean that up.

## FAQ

**Do I need QualiaMods to make mods?**
No. The game's built-in loader works fine on its own. QualiaMods is optional.

**What if QualiaMods isn't installed but my mod has mod.cfg?**
Nothing happens. Those files just sit in the PCK unused. But if your `mod_main.gd` calls `ModLoader.add_hook()` etc., that will error because vanilla ModLoader doesn't have those methods.

**Can I support both with and without QualiaMods?**
Yeah, check before calling:
```gdscript
var ml = get_node_or_null("/root/ModLoader")
if ml and ml.has_method("add_hook"):
    ml.add_hook("game_playable", _on_ready)
else:
    await get_tree().create_timer(1.0).timeout
    _on_ready()
```

**Can I disable a mod without deleting it?**
Yes, toggle it in the Mods Menu. Takes effect after restart.

**When can I use Ref?**
In `_game_ready()` and any time after. Not in `_init_mod()`.

**Can two mods add stuff to the same menu?**
Yes, they add independently.

**Can two mods patch the same method?**
They can, wraps stack. But order depends on load order and it might get weird. No conflict detection yet.

**Where are logs?**
`%APPDATA%/lucid blocks/logs/` on Windows. Mod output shows as `[mod_id] message`.

**What Godot version?**
4.6, Double Precision, Forward Plus. Same as the game.

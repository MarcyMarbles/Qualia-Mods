# QualiaMods — Quickstart Guide

Create your first mod for Lucid Blocks in 5 minutes.

## Prerequisites

- Godot 4.6 stable (double precision) — [compile instructions](https://docs.godotengine.org/en/stable/contributing/development/compiling/)
- Lucid Blocks opened in the Godot editor
- QualiaMods `.pck` installed in the game's `mods/` folder

## 1. Create mod folder

```
mods/
  mymod/
    mod.cfg
    mod_main.gd
```

Create a folder inside `res://mods/` with your mod's ID (lowercase, underscores ok).

## 2. Write mod.cfg

```ini
[mod]
name = "My First Mod"
version = "1.0.0"
author = "Your Name"
description = "My first QualiaMods mod!"
game_version = "2.8.7"

[config]
; Add default config values here (optional)
; my_option = true
```

## 3. Write mod_main.gd

```gdscript
extends "res://mods/qualiamods/mod_base.gd"

func _setup() -> void:
    log("Hello world!")

func _on_game_playable() -> void:
    log("Player position: %s" % Ref.player.global_position)
```

That's it. No `const MOD_ID`, no manual hook subscriptions, no boilerplate.

### What happens automatically:
- `mod_id` is detected from your folder name (`"mymod"`)
- `config` dict is pre-filled from mod.cfg `[config]` section
- `_on_game_playable()` auto-subscribes to the `game_playable` hook

## 4. Pack your mod

```bash
godot --headless --script res://sdk/pack_mod.gd -- mymod
```

This creates `mymod.pck` — share it with others!

## 5. Test

Drop the `.pck` into the game's `mods/` folder and launch the game.
Press **F10** to open the Mods Menu and verify your mod appears.

---

## Recipes

### Listen to game events

Just define `_on_<hook_name>()` methods — they auto-subscribe:

```gdscript
func _on_world_loaded() -> void:
    log("World loaded!")

func _on_game_quit() -> void:
    log("Goodbye!")
```

Available hooks: `world_loaded`, `game_playable`, `game_quit`, `all_loaded`,
`new_game_loaded`, `items_pre_load`, `items_post_load`, `mods_all_ready`.

### Read config values

```ini
# mod.cfg
[config]
speed_multiplier = 1.5
enable_particles = true
```

```gdscript
func _setup() -> void:
    var speed = get_cfg("speed_multiplier", 1.0)
    var particles = get_cfg("enable_particles", false)
```

### Add a settings tab

```gdscript
func _game_ready() -> void:
    var tab = settings_tab("my mod")
    tab.add_slider("speed", "speed_multiplier", 0.1, 5.0, 0.1, 1.0)
    tab.add_toggle("particles", "enable_particles", false)
    tab.load_values()
    tab.saved.connect(func(values): config.merge(values, true))
```

### Modify game behavior

```gdscript
func _game_ready() -> void:
    # Half all damage taken by the player
    ModLoader.wrap_method(Ref.player, "take_damage", func(original, amount):
        original.call(amount * 0.5)
    )
```

### Add items

Place `.tres` item resources in your mod folder, then register the path:

```gdscript
func _setup() -> void:
    ModLoader.register_items("res://mods/%s/items" % mod_id)
```

### Inject UI elements

```gdscript
func _game_ready() -> void:
    var label = Label.new()
    label.text = "Hello from my mod!"
    ModLoader.inject_node("Main/UI", label)
```

### Access game objects

Use `Ref.*` for common game objects:

```gdscript
Ref.player          # Player node
Ref.world           # LucidBlocksWorld
Ref.weather         # Weather system
Ref.settings_menu   # Settings Menu
Ref.game_menu       # In-game menu
Ref.player_inventory
Ref.player_hotbar
```

---

## ModBase vs raw Node

You can still `extend Node` and use the low-level API (`_init_mod`, `ModLoader.add_hook`, etc.).
ModBase is a convenience layer — it doesn't limit what you can do.

| Feature | Raw Node | ModBase |
|---------|----------|---------|
| mod_id | `const MOD_ID := "..."` | Auto-detected |
| Config | `var config; func _init_mod(cfg): config = cfg` | Pre-populated |
| Hooks | `ModLoader.add_hook(Hooks.X, method)` | Name method `_on_x()` |
| Logging | `ModLoader.log_mod(MOD_ID, msg)` | `log(msg)` |
| Settings | 6+ lines of setup | `settings_tab("name")` |
| Cleanup | Manual `remove_hook` calls | Automatic |

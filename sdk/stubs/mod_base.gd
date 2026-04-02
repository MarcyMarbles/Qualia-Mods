extends Node
## ModBase (QualiaMods) — Stub for editor autocompletion.
## Do NOT include this file in your .pck — it is only for development.
## At runtime, the real ModBase is loaded from the QualiaMods .pck.
##
## Extend this in your mod_main.gd instead of raw Node:
##   extends "res://mods/qualiamods/mod_base.gd"
##
## Or if using the stub path for editor support:
##   extends "res://sdk/stubs/mod_base.gd"  # dev only — change before packing


## Auto-detected from folder name (e.g. "fogcontrol" from res://mods/fogcontrol/).
var mod_id: String

## Merged config from mod.cfg [config] + user overrides.
var config: Dictionary


# ── Override these in your mod ───────────────────────────────────

## Called after config and auto-hooks are wired. Use instead of _init_mod().
func _setup() -> void: pass

## Called when the game scene tree is ready. Ref.* references are valid.
func _game_ready() -> void: pass

## Called when user saves new config in Mods Menu.
func _config_changed() -> void: pass

## Called on mod unload. Clean up your nodes/connections here.
func _cleanup() -> void: pass


# ── Auto-hook convention ─────────────────────────────────────────
# Define any of these methods and they auto-subscribe to the hook:
#
#   func _on_world_loaded() -> void: pass
#   func _on_game_playable() -> void: pass
#   func _on_game_quit() -> void: pass
#   func _on_all_loaded() -> void: pass
#   func _on_new_game_loaded() -> void: pass
#   func _on_items_pre_load() -> void: pass
#   func _on_items_post_load() -> void: pass
#   func _on_scene_injected() -> void: pass
#   func _on_config_changed() -> void: pass
#   func _on_mods_all_ready() -> void: pass


# ── Convenience methods ──────────────────────────────────────────

## Print a log line prefixed with [mod_id].
func log(message: String) -> void: pass

## Read a config value with a default fallback.
func get_cfg(key: String, default = null): return default

## Create a settings tab in the Settings Menu.
## Returns a SettingsTab builder (add_slider, add_toggle, etc.).
## Auto-sets save prefix to "<mod_id>_".
func settings_tab(tab_name: String) -> RefCounted: return null

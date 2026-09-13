extends Node

## ModBase — extend this instead of raw Node to get auto-wiring.
##
## Features:
##   - mod_id auto-detected from your folder name (no const needed)
##   - config dict pre-populated from mod.cfg [config] + user overrides
##   - methods named _on_<hook> auto-subscribe to ModLoader hooks
##   - convenience: log_info(), get_cfg(), settings_tab()
##
## Lifecycle (override what you need):
##   _early_setup()     — called BEFORE game autoloads run (synchronous, no await)
##   _setup()           — called after config + hooks are wired
##   _game_ready()      — scene tree ready, Ref.* valid
##   _config_changed()  — user changed config in Mods Menu
##   _cleanup()         — mod unloading
##
## Minimal mod:
##   extends "res://mods/qualiamods/mod_base.gd"
##
##   func _on_game_playable() -> void:
##       log_info("Hello from %s!" % mod_id)

## Auto-detected from folder name. Read-only for subclasses.
var mod_id: String

## Merged config from mod.cfg [config] + user overrides.
var config: Dictionary

## Hook methods that were auto-wired (for cleanup).
var _auto_hooks: Dictionary = {}  # hook_name -> Callable


# ── Framework entry points (do not override) ─────────────────────

## Called by ModLoader. Sets up everything, then calls _setup().
func _init_mod(cfg: Dictionary) -> void:
	config = cfg
	mod_id = _detect_mod_id()
	_auto_wire_hooks()
	_setup()


## Called by ModLoader when game tree is ready.
## Override _game_ready() in your mod — this base version is a no-op
## so subclasses don't need to call super.
# (framework calls _game_ready directly — subclasses just override it)


## Called by ModLoader when user changes config.
func _on_config_changed(new_config: Dictionary) -> void:
	config = new_config
	_config_changed()


## Called by ModLoader on unload.
func _mod_cleanup() -> void:
	_cleanup()
	_remove_auto_hooks()


# ── Override these in your mod ───────────────────────────────────

## Called BEFORE game autoloads (ItemMap, etc.) run.
## Runs synchronously during bootstrap — no await allowed.
## The node is already in the tree: get_tree() works.
## Use for early interception (e.g. node_added signals).
func _early_setup() -> void:
	pass


## Called after config and hooks are wired. Use instead of _init_mod().
func _setup() -> void:
	pass


## Called when user saves new config in Mods Menu.
func _config_changed() -> void:
	pass


## Called on mod unload. Clean up your nodes/connections here.
func _cleanup() -> void:
	pass


# ── Convenience methods ──────────────────────────────────────────

## Print a log line prefixed with [mod_id].
func log_info(message: String) -> void:
	ModLoader.log_mod(mod_id, message)


## Read a config value with a default fallback.
func get_cfg(key: String, default = null):
	return config.get(key, default)


## Create a settings tab in the Settings Menu.
## Returns a SettingsTab builder (add_slider, add_toggle, etc.).
## Automatically sets save prefix to "<mod_id>_".
func settings_tab(tab_name: String) -> RefCounted:
	var tab = ModLoader.add_settings_tab(tab_name)
	if tab:
		tab.set_save_prefix(mod_id + "_")
	return tab


# ── Internal ─────────────────────────────────────────────────────

func _detect_mod_id() -> String:
	var path: String = get_script().resource_path
	# path looks like "res://mods/<mod_id>/mod_main.gd"
	var parts := path.split("/")
	for i in range(parts.size() - 1):
		if parts[i] == "mods" and i + 1 < parts.size():
			return parts[i + 1]
	# fallback: folder containing the script
	return path.get_base_dir().get_file()


func _auto_wire_hooks() -> void:
	# All hook constants from ModLoader.Hooks
	var hook_names: Array[String] = [
		"world_loaded",
		"game_playable",
		"game_quit",
		"all_loaded",
		"new_game_loaded",
		"items_pre_load",
		"items_post_load",
		"scene_injected",
		"config_changed",
		"mods_all_ready",
	]

	for hook_name in hook_names:
		var method_name := "_on_" + hook_name
		if has_method(method_name):
			var callable := Callable(self, method_name)
			ModLoader.add_hook(hook_name, callable)
			_auto_hooks[hook_name] = callable

	if not _auto_hooks.is_empty():
		ModLoader.log_mod(mod_id, "Auto-wired %d hook(s): %s" % [
			_auto_hooks.size(),
			", ".join(_auto_hooks.keys())
		])


func _remove_auto_hooks() -> void:
	for hook_name in _auto_hooks:
		ModLoader.remove_hook(hook_name, _auto_hooks[hook_name])
	_auto_hooks.clear()

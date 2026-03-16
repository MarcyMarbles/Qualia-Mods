extends Node
## ModLoader (QualiaMods) - Stub for editor autocompletion.
## Do NOT include this file in your .pck - it is only for development.
## At runtime, the real ModLoader is available as a global singleton.


class Hooks:
	## Game lifecycle
	const WORLD_LOADED := "world_loaded"        ## World finished loading
	const GAME_PLAYABLE := "game_playable"      ## Player can move/interact
	const GAME_QUIT := "game_quit"              ## Game is quitting
	const ALL_LOADED := "all_loaded"            ## All resources loaded
	const NEW_GAME_LOADED := "new_game_loaded"  ## New world created
	## Item system
	const ITEMS_PRE_LOAD := "items_pre_load"    ## Before ItemMap scans items
	const ITEMS_POST_LOAD := "items_post_load"  ## After ItemMap finishes
	## Scene tree
	const SCENE_INJECTED := "scene_injected"    ## After inject_node succeeds
	## Config
	const CONFIG_CHANGED := "config_changed"    ## User changed mod config in Mods Menu
	## Mod lifecycle
	const MODS_ALL_READY := "mods_all_ready"    ## All mods initialized + _game_ready() called


class ModInfo:
	var id: String              ## e.g. "fogcontrol"
	var name: String            ## Display name from mod.cfg
	var version: String         ## e.g. "1.0.0"
	var author: String
	var description: String
	var game_version: String    ## Target game version
	var dependencies: Dictionary  ## { "other_mod_id": true }
	var load_order: int         ## Lower = loads earlier
	var config: Dictionary      ## Merged default + user override config
	var instance: Node          ## The mod_main.gd node (or null for resource-only)
	var enabled: bool
	var pck_path: String        ## Absolute path to .pck on disk


## Emitted after all mods have been initialized.
signal mods_initialized
## Emitted after each individual mod is loaded.
signal mod_loaded(mod_id: String)


# ── Hooks ─────────────────────────────────────────────────────────

## Subscribe to a named hook. The callable is invoked when emit_hook fires.
func add_hook(hook_name: String, callable: Callable) -> void: pass

## Unsubscribe from a hook.
func remove_hook(hook_name: String, callable: Callable) -> void: pass

## Fire a hook, calling all subscribers with the given args array.
func emit_hook(hook_name: String, args: Array = []) -> void: pass


# ── Info ──────────────────────────────────────────────────────────

## Returns ModInfo for a loaded mod, or null.
func get_mod(mod_id: String) -> ModInfo: return null

## Read a config value for a mod.
func get_config(mod_id: String, key: String, default = null): return default

## Check if a mod is loaded and enabled.
func is_mod_loaded(mod_id: String) -> bool: return false

## Returns mod IDs in resolved load order.
func get_load_order() -> Array[String]: return []

## Print a log line prefixed with [mod_id].
func log_mod(mod_id: String, message: String) -> void: pass


# ── Scene injection ───────────────────────────────────────────────

## Add a node into the scene tree at parent_path.
## Returns true if injected immediately, false if queued (parent not ready yet).
func inject_node(parent_path: String, node: Node, index: int = -1) -> bool: return false

## Instantiate a PackedScene and inject it. Returns the new instance.
func inject_scene(parent_path: String, scene: PackedScene, index: int = -1) -> Node: return null

## Replace an existing node, preserving its tree position.
func replace_node(target_path: String, new_node: Node) -> Node: return null

## Safe get_node_or_null from root.
func get_game_node(path: String) -> Node: return null


# ── Item system ───────────────────────────────────────────────────

## Register a directory of .tres items for ItemMap to scan.
func register_item_path(path: String) -> void: pass

## Convenience: register_item_path + register_resource("items", path).
func register_items(path: String) -> void: pass

## Hot-load a single Item .tres into ItemMap. Returns false on failure.
func register_item_resource(item_path: String) -> bool: return false

## Get all item paths registered by mods.
func get_mod_item_paths() -> Array[String]: return []


# ── Resources ─────────────────────────────────────────────────────

## Register a resource path under a named category (e.g. "items", "recipes").
func register_resource(category: String, path: String) -> void: pass

## Get all registered paths for a category.
func get_registered_resources(category: String) -> Array: return []


# ── Method patching ───────────────────────────────────────────────

## Wrap an existing method on target.
## The wrapper callable receives (original: Callable, ...args).
## Example:
##   ModLoader.wrap_method(Ref.player, "take_damage", func(original, amount):
##       original.call(amount * 0.5)  # half damage
##   )
func wrap_method(target: Object, method_name: String, wrapper: Callable) -> bool: return false

## Remove a previously added wrapper.
func unwrap_method(target: Object, method_name: String, wrapper: Callable) -> void: pass

## Call a method through the full wrapper chain.
func call_patched(target: Object, method_name: String, args: Array = []): pass


# ── UI injection ──────────────────────────────────────────────────

## Add a tab to GameMenu's TabContainer. Returns the container.
func add_game_menu_tab(tab_name: String, content: Control) -> Control: return null

## Add a button to the MainMenu after a named button. Returns the Button.
func add_main_menu_button(text: String, callback: Callable, after_button: String = "SettingsButton") -> Button: return null


# ── Inter-mod messaging ──────────────────────────────────────────

## Send data to a specific mod. Target must implement _on_mod_message.
func send_message(target_mod_id: String, sender_mod_id: String, data: Dictionary) -> bool: return false

## Broadcast data to all loaded mods that implement _on_mod_message.
func broadcast_message(sender_mod_id: String, data: Dictionary) -> void: pass

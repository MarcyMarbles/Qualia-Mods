extends Node

# replaces the basic ModLoader via set_script() in ref.gd
# PCK loading (phase 1) is already done by the vanilla loader,
# this handles everything after: discovery, deps, init, hooks, UI


# hook name constants so we don't typo string literals everywhere
class Hooks:
	const WORLD_LOADED := "world_loaded"
	const GAME_PLAYABLE := "game_playable"
	const GAME_QUIT := "game_quit"
	const ALL_LOADED := "all_loaded"
	const NEW_GAME_LOADED := "new_game_loaded"
	const ITEMS_PRE_LOAD := "items_pre_load"
	const ITEMS_POST_LOAD := "items_post_load"
	const SCENE_INJECTED := "scene_injected"
	const CONFIG_CHANGED := "config_changed"
	const MODS_ALL_READY := "mods_all_ready"


class ModInfo:
	var id: String
	var name: String
	var version: String
	var author: String
	var description: String
	var game_version: String
	var dependencies: Dictionary
	var load_order: int
	var config: Dictionary
	var instance: Node
	var enabled: bool
	var pck_path: String


var mods: Dictionary = {}
var _load_order: Array[String] = []
var _item_paths: Array[String] = []
var _hooks: Dictionary = {}
var _method_patches: Dictionary = {}  # "id.method" -> patch info
var _scene_injections: Array[Dictionary] = []  # queued until tree is ready
var _registered_resources: Dictionary = {}  # "items" / "recipes" / etc -> paths
var _mods_dir_path: String
var _bootstrapped: bool = false
var _mods_menu: Control = null
var _key_menu: int = KEY_F10

signal mods_initialized
signal mod_loaded(mod_id: String)


# called from ref.gd right after set_script()
func _bootstrap() -> void:
	if _bootstrapped:
		return
	_bootstrapped = true

	_mods_dir_path = OS.get_executable_path().get_base_dir().path_join("mods")
	_load_self_config()
	print("[QualiaMods] v1.0.0 — Phase 2 starting")
	print("[QualiaMods] Game version: ", ProjectSettings.get_setting("application/config/version"))
	print("[QualiaMods] Mods dir: %s" % _mods_dir_path)

	_scan_loaded_mods()

	if mods.is_empty():
		print("[QualiaMods] No mods found.")
		return

	_discover_mods()
	_resolve_load_order()
	_initialize_mods()
	_connect_game_hooks.call_deferred()
	mods_initialized.emit()


func _load_self_config() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(_mods_dir_path.path_join("qualiamods.cfg")) == OK:
		var key_str: String = cfg.get_value("config", "key_menu", "F10")
		_key_menu = _key_from_name(key_str)
		print("[QualiaMods] Config loaded (menu key: %s)" % key_str)


static func _key_from_name(n: String) -> int:
	match n:
		"F1": return KEY_F1
		"F2": return KEY_F2
		"F3": return KEY_F3
		"F4": return KEY_F4
		"F5": return KEY_F5
		"F6": return KEY_F6
		"F7": return KEY_F7
		"F8": return KEY_F8
		"F9": return KEY_F9
		"F10": return KEY_F10
		"F11": return KEY_F11
		"F12": return KEY_F12
	return KEY_F10


# find .pck files in the mods folder and register them
func _scan_loaded_mods() -> void:
	var dir := DirAccess.open(_mods_dir_path)
	if not dir:
		return

	var disabled_cfg := ConfigFile.new()
	disabled_cfg.load(_mods_dir_path.path_join("disabled_mods.cfg"))

	dir.list_dir_begin()
	var file := dir.get_next()
	while file != "":
		if file.ends_with(".pck"):
			var mod_id := file.get_basename()

			# don't register ourselves
			if mod_id.begins_with("_000_qualiamods"):
				file = dir.get_next()
				continue

			var is_disabled: bool = disabled_cfg.get_value("disabled", mod_id, false)
			var info := ModInfo.new()
			info.id = mod_id
			info.pck_path = _mods_dir_path.path_join(file)
			info.enabled = not is_disabled
			info.name = mod_id
			info.version = "?"
			info.author = "?"
			info.load_order = 0
			info.config = {}
			info.dependencies = {}
			mods[mod_id] = info

			if is_disabled:
				print("[QualiaMods] Found disabled: %s" % mod_id)
			else:
				print("[QualiaMods] Found: %s" % mod_id)
		file = dir.get_next()


# read mod.cfg for each mod — name, version, deps, config, etc.
func _discover_mods() -> void:
	for mod_id in mods:
		var info: ModInfo = mods[mod_id]
		if not info.enabled:
			continue

		var cfg_path := "res://mods/%s/mod.cfg" % mod_id
		var cfg := ConfigFile.new()
		if cfg.load(cfg_path) != OK:
			print("[QualiaMods] '%s' has no mod.cfg, using defaults" % mod_id)
			continue

		info.name = cfg.get_value("mod", "name", mod_id)
		info.version = cfg.get_value("mod", "version", "1.0.0")
		info.author = cfg.get_value("mod", "author", "Unknown")
		info.description = cfg.get_value("mod", "description", "")
		info.game_version = cfg.get_value("mod", "game_version", "")
		info.load_order = cfg.get_value("mod", "load_order", 0)

		info.dependencies = {}
		if cfg.has_section("dependencies"):
			for key in cfg.get_section_keys("dependencies"):
				info.dependencies[key] = cfg.get_value("dependencies", key)

		info.config = {}
		if cfg.has_section("config"):
			for key in cfg.get_section_keys("config"):
				info.config[key] = cfg.get_value("config", key)

		# per-mod config overrides from <mod_id>.cfg next to the pck
		var override_path := _mods_dir_path.path_join("%s.cfg" % mod_id)
		var override_cfg := ConfigFile.new()
		if override_cfg.load(override_path) == OK:
			if override_cfg.has_section("config"):
				for key in override_cfg.get_section_keys("config"):
					info.config[key] = override_cfg.get_value("config", key)
			print("[QualiaMods] Applied config overrides for '%s'" % mod_id)

		print("[QualiaMods] Discovered: %s v%s by %s" % [info.name, info.version, info.author])


# topo sort by deps, then by load_order field
func _resolve_load_order() -> void:
	for mod_id in mods:
		var info: ModInfo = mods[mod_id]
		if not info.enabled:
			continue
		for dep_id in info.dependencies:
			if dep_id not in mods:
				printerr("[QualiaMods] '%s' requires missing mod '%s' — disabled" % [mod_id, dep_id])
				info.enabled = false
			elif not mods[dep_id].enabled:
				printerr("[QualiaMods] '%s' requires disabled mod '%s' — disabled" % [mod_id, dep_id])
				info.enabled = false

	var sorted: Array[String] = []
	var visited: Dictionary = {}
	var visiting: Dictionary = {}

	var ids: Array = mods.keys()
	ids.sort_custom(func(a, b): return mods[a].load_order < mods[b].load_order)

	for mod_id in ids:
		if not visited.has(mod_id):
			_topo_sort(mod_id, sorted, visited, visiting)

	_load_order = sorted


func _topo_sort(mod_id: String, sorted: Array[String], visited: Dictionary, visiting: Dictionary) -> void:
	if visiting.has(mod_id):
		printerr("[QualiaMods] Circular dependency: '%s'" % mod_id)
		return
	if visited.has(mod_id):
		return

	visiting[mod_id] = true
	if mods.has(mod_id):
		for dep_id in mods[mod_id].dependencies:
			if mods.has(dep_id):
				_topo_sort(dep_id, sorted, visited, visiting)
	visiting.erase(mod_id)
	visited[mod_id] = true
	sorted.append(mod_id)


# load mod_main.gd for each mod, add to tree, call _init_mod
func _initialize_mods() -> void:
	for mod_id in _load_order:
		var info: ModInfo = mods[mod_id]
		if not info.enabled:
			print("[QualiaMods] Skipping disabled: %s" % mod_id)
			continue

		var script_path := "res://mods/%s/mod_main.gd" % mod_id
		if not FileAccess.file_exists(script_path):
			print("[QualiaMods] '%s' — resource-only (no mod_main.gd)" % mod_id)
			mod_loaded.emit(mod_id)
			continue

		var script := load(script_path)
		if not script:
			printerr("[QualiaMods] Failed to load: %s" % script_path)
			continue

		var instance: Node = script.new()
		instance.name = "Mod_%s" % mod_id
		info.instance = instance
		add_child(instance)

		if instance.has_method("_init_mod"):
			instance._init_mod(info.config)

		print("[QualiaMods] Initialized: %s v%s" % [info.name, info.version])
		mod_loaded.emit(mod_id)

	print("[QualiaMods] Done. %d mod(s) in load order." % _load_order.size())


# wire up signals from Main node to our hook system
func _connect_game_hooks() -> void:
	await get_tree().process_frame

	var main_node := get_tree().get_root().get_node_or_null("Main")
	if not main_node:
		printerr("[QualiaMods] Main node not found — hooks disabled")
		return

	if main_node.has_signal("world_loaded"):
		main_node.world_loaded.connect(func(): emit_hook("world_loaded"))
	if main_node.has_signal("game_playable"):
		main_node.game_playable.connect(func(): emit_hook("game_playable"))
	if main_node.has_signal("game_quit"):
		main_node.game_quit.connect(func(): emit_hook("game_quit"))
	if main_node.has_signal("all_loaded"):
		main_node.all_loaded.connect(func(): emit_hook("all_loaded"))
	if main_node.has_signal("new_game_loaded"):
		main_node.new_game_loaded.connect(func(): emit_hook("new_game_loaded"))

	print("[QualiaMods] Game hooks connected.")

	_inject_mods_button.call_deferred()

	# let mods know the game is ready
	for mod_id in _load_order:
		var info: ModInfo = mods[mod_id]
		if info.instance and info.instance.has_method("_game_ready"):
			info.instance._game_ready()

	# flush anything that was queued before the tree was ready
	_process_scene_injections()

	emit_hook(Hooks.MODS_ALL_READY)


# shove a "mods" button into the main menu next to settings
func _inject_mods_button() -> void:
	var main_menu = get_tree().get_root().get_node_or_null("Main/UI/MainMenu")
	if not main_menu:
		print("[QualiaMods] MainMenu not found, skipping button injection")
		return

	var settings_btn = main_menu.get_node_or_null("%SettingsButton")
	if not settings_btn:
		print("[QualiaMods] SettingsButton not found, skipping button injection")
		return

	var btn_container = settings_btn.get_parent()

	var mods_btn := Button.new()
	mods_btn.text = "mods"
	mods_btn.name = "ModsButton"

	# match the look of existing buttons
	mods_btn.size_flags_horizontal = settings_btn.size_flags_horizontal
	mods_btn.custom_minimum_size = settings_btn.custom_minimum_size

	# click sounds
	var sound_script = load("res://main/ui/theme/sound_button.gd")
	if sound_script:
		mods_btn.set_script(sound_script)

	var settings_idx: int = settings_btn.get_index()
	btn_container.add_child(mods_btn)
	btn_container.move_child(mods_btn, settings_idx + 1)

	mods_btn.pressed.connect(_on_mods_button_pressed)
	print("[QualiaMods] Mods button injected into main menu.")


func _on_mods_button_pressed() -> void:
	var main_menu = get_tree().get_root().get_node_or_null("Main/UI/MainMenu")
	if main_menu and main_menu.has_method("deactivate"):
		main_menu.deactivate()

	await Ref.trans.open()

	_ensure_mods_menu()
	_mods_menu.open()
	if main_menu:
		main_menu.visible = false

	await Ref.trans.close()
	_mods_menu.activate()


func _ensure_mods_menu() -> void:
	if _mods_menu:
		return

	var scene: PackedScene = load("res://main/ui/menu/mods_menu/mods_menu.tscn")
	if scene:
		_mods_menu = scene.instantiate()
	else:
		var menu_script = load("res://main/ui/menu/mods_menu/mods_menu.gd")
		if menu_script:
			_mods_menu = menu_script.new()
		else:
			printerr("[QualiaMods] Could not load mods menu")
			return

	_mods_menu.name = "ModsMenu"

	var ui_layer = get_tree().get_root().get_node_or_null("Main/UI")
	if ui_layer:
		ui_layer.add_child(_mods_menu)
	else:
		get_tree().get_root().add_child(_mods_menu)

	_mods_menu.close()

	if _mods_menu.has_signal("exited"):
		_mods_menu.exited.connect(_on_mods_menu_exited)


func _on_mods_menu_exited() -> void:
	_mods_menu.deactivate()

	await Ref.trans.open()

	_mods_menu.close()
	var main_menu = get_tree().get_root().get_node_or_null("Main/UI/MainMenu")
	if main_menu:
		main_menu.visible = true

	await Ref.trans.close()

	if main_menu and main_menu.has_method("activate"):
		main_menu.activate()


# quick toggle for the mods menu (F10 by default)
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == _key_menu:
			_ensure_mods_menu()
			if _mods_menu.visible:
				_mods_menu.close()
				_mods_menu.deactivate()
			else:
				_mods_menu.open()
				_mods_menu.activate()
			get_viewport().set_input_as_handled()


func get_mod(mod_id: String) -> ModInfo:
	return mods.get(mod_id)


func get_config(mod_id: String, key: String, default = null):
	if mod_id in mods and key in mods[mod_id].config:
		return mods[mod_id].config[key]
	return default


func register_item_path(path: String) -> void:
	_item_paths.append(path)
	print("[QualiaMods] Registered item path: %s" % path)


func get_mod_item_paths() -> Array[String]:
	return _item_paths


func add_hook(hook_name: String, callable: Callable) -> void:
	if hook_name not in _hooks:
		_hooks[hook_name] = []
	_hooks[hook_name].append(callable)


func remove_hook(hook_name: String, callable: Callable) -> void:
	if hook_name in _hooks:
		_hooks[hook_name].erase(callable)


func emit_hook(hook_name: String, args: Array = []) -> void:
	if hook_name not in _hooks:
		return
	for callable in _hooks[hook_name]:
		if callable.is_valid():
			callable.callv(args)


func log_mod(mod_id: String, message: String) -> void:
	print("[%s] %s" % [mod_id, message])


func get_load_order() -> Array[String]:
	return _load_order


func is_mod_loaded(mod_id: String) -> bool:
	return mod_id in mods and mods[mod_id].enabled


# add a node to the tree, or queue it if the parent isn't there yet
func inject_node(parent_path: String, node: Node, index: int = -1) -> bool:
	var parent := get_tree().get_root().get_node_or_null(parent_path)
	if parent:
		parent.add_child(node)
		if index >= 0:
			parent.move_child(node, index)
		emit_hook(Hooks.SCENE_INJECTED, [parent_path, node])
		return true

	_scene_injections.append({
		"parent_path": parent_path,
		"node": node,
		"index": index,
	})
	return false


func inject_scene(parent_path: String, scene: PackedScene, index: int = -1) -> Node:
	var instance := scene.instantiate()
	inject_node(parent_path, instance, index)
	return instance


# swap out a node but keep its position in the tree
func replace_node(target_path: String, new_node: Node) -> Node:
	var target := get_tree().get_root().get_node_or_null(target_path)
	if not target:
		printerr("[QualiaMods] replace_node: target '%s' not found" % target_path)
		return null

	var parent := target.get_parent()
	var idx := target.get_index()
	new_node.name = target.name
	parent.remove_child(target)
	target.queue_free()
	parent.add_child(new_node)
	parent.move_child(new_node, idx)
	return new_node


func get_game_node(path: String) -> Node:
	return get_tree().get_root().get_node_or_null(path)


func _process_scene_injections() -> void:
	var remaining: Array[Dictionary] = []
	for injection in _scene_injections:
		var parent := get_tree().get_root().get_node_or_null(injection["parent_path"])
		if parent:
			parent.add_child(injection["node"])
			if injection["index"] >= 0:
				parent.move_child(injection["node"], injection["index"])
			emit_hook(Hooks.SCENE_INJECTED, [injection["parent_path"], injection["node"]])
		else:
			printerr("[QualiaMods] Queued injection failed: parent '%s' not found" % injection["parent_path"])
			remaining.append(injection)
	_scene_injections = remaining


# wrap a method on any object — wrapper gets (original, ...args)
# example:
#   ModLoader.wrap_method(Ref.player, "take_damage", func(original, amount):
#       original.call(amount * 0.5)  # half damage
#   )
func wrap_method(target: Object, method_name: String, wrapper: Callable) -> bool:
	if not target.has_method(method_name):
		printerr("[QualiaMods] wrap_method: '%s' has no method '%s'" % [target, method_name])
		return false

	var key := "%s.%s" % [target.get_instance_id(), method_name]

	if key not in _method_patches:
		_method_patches[key] = {
			"target": target,
			"method": method_name,
			"original_script": target.get_script(),
			"wrappers": [],
		}

	_method_patches[key]["wrappers"].append(wrapper)
	_rebuild_method_chain(key)
	return true


func unwrap_method(target: Object, method_name: String, wrapper: Callable) -> void:
	var key := "%s.%s" % [target.get_instance_id(), method_name]
	if key in _method_patches:
		_method_patches[key]["wrappers"].erase(wrapper)
		if _method_patches[key]["wrappers"].is_empty():
			_method_patches.erase(key)


func _rebuild_method_chain(key: String) -> void:
	var patch = _method_patches[key]
	var hook_name := "_patch_%s" % key
	if hook_name in _hooks:
		_hooks[hook_name] = []
	for wrapper in patch["wrappers"]:
		add_hook(hook_name, wrapper)


# call a method through the wrapper chain (use instead of direct calls)
func call_patched(target: Object, method_name: String, args: Array = []):
	var key := "%s.%s" % [target.get_instance_id(), method_name]
	if key not in _method_patches:
		return target.callv(method_name, args)

	var patch = _method_patches[key]
	var original := Callable(target, method_name)
	var current_callable := original
	for wrapper in patch["wrappers"]:
		var prev := current_callable
		current_callable = func():
			return wrapper.callv([prev] + args)

	return current_callable.call()


# register a resource path under a category (items, recipes, etc.)
func register_resource(category: String, path: String) -> void:
	if category not in _registered_resources:
		_registered_resources[category] = []
	_registered_resources[category].append(path)
	log_mod("QualiaMods", "Registered %s resource: %s" % [category, path])


func get_registered_resources(category: String) -> Array:
	if category not in _registered_resources:
		return []
	return _registered_resources[category]


func register_items(path: String) -> void:
	register_item_path(path)
	register_resource("items", path)


# load a single item .tres and inject it into ItemMap (or queue if not ready)
func register_item_resource(item_path: String) -> bool:
	var resource := ResourceLoader.load(item_path)
	if not resource or not resource is Item:
		printerr("[QualiaMods] register_item_resource: '%s' is not a valid Item" % item_path)
		return false

	var item_map := get_node_or_null("/root/ItemMap")
	if item_map and item_map.all_items_loaded:
		# already loaded — inject directly
		var item: Item = resource
		if item.id in item_map.id_to_resource:
			printerr("[QualiaMods] register_item_resource: ID %d already exists" % item.id)
			return false
		item_map.id_to_resource[item.id] = item
		item_map.all_item_ids.append(item.id)
		item_map.all_item_ids.sort()
		# preload associated scenes
		item.held_item_scene = ResourceLoader.load(item.held_item_path)
		if item is Block and item.living_block_path != "":
			item.living_block_scene = ResourceLoader.load(item.living_block_path)
		if item is Spawner and item.entity_path != "":
			item.entity_scene = ResourceLoader.load(item.entity_path)
		return true

	# not loaded yet, queue it
	register_resource("items_single", item_path)
	return true


# add a tab to the in-game menu
func add_game_menu_tab(tab_name: String, content: Control) -> Control:
	var game_menu := get_game_node("Main/UI/GameMenu")
	if not game_menu:
		printerr("[QualiaMods] add_game_menu_tab: GameMenu not found")
		return null

	var tab_container: TabContainer = null
	for child in game_menu.get_children():
		if child is TabContainer:
			tab_container = child
			break

	if not tab_container:
		content.name = tab_name
		game_menu.add_child(content)
		return content

	content.name = tab_name
	tab_container.add_child(content)
	return content


func add_main_menu_button(text: String, callback: Callable, after_button: String = "SettingsButton") -> Button:
	var main_menu := get_game_node("Main/UI/MainMenu")
	if not main_menu:
		printerr("[QualiaMods] add_main_menu_button: MainMenu not found")
		return null

	var anchor_btn := main_menu.get_node_or_null("%" + after_button)
	if not anchor_btn:
		printerr("[QualiaMods] add_main_menu_button: '%s' not found" % after_button)
		return null

	var btn := Button.new()
	btn.text = text
	btn.size_flags_horizontal = anchor_btn.size_flags_horizontal
	btn.custom_minimum_size = anchor_btn.custom_minimum_size

	var sound_script = load("res://main/ui/theme/sound_button.gd")
	if sound_script:
		btn.set_script(sound_script)

	var container := anchor_btn.get_parent()
	var idx: int = anchor_btn.get_index()
	container.add_child(btn)
	container.move_child(btn, idx + 1)

	btn.pressed.connect(callback)
	return btn


# mod-to-mod messaging — target must have _on_mod_message()
func send_message(target_mod_id: String, sender_mod_id: String, data: Dictionary) -> bool:
	if target_mod_id not in mods:
		return false
	var info: ModInfo = mods[target_mod_id]
	if not info.instance or not info.instance.has_method("_on_mod_message"):
		return false
	info.instance._on_mod_message(sender_mod_id, data)
	return true


func broadcast_message(sender_mod_id: String, data: Dictionary) -> void:
	for mod_id in _load_order:
		if mod_id == sender_mod_id:
			continue
		var info: ModInfo = mods[mod_id]
		if info.enabled and info.instance and info.instance.has_method("_on_mod_message"):
			info.instance._on_mod_message(sender_mod_id, data)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE or what == NOTIFICATION_EXIT_TREE:
		for mod_id in _load_order:
			var info: ModInfo = mods[mod_id]
			if info.instance and info.instance.has_method("_mod_cleanup"):
				info.instance._mod_cleanup()

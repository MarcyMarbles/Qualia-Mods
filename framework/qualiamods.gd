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
	var config_hints: Dictionary  # { "key": { "min": float, "max": float, "step": float } }
	var instance: Node
	var enabled: bool
	var pck_path: String


## Settings UI builder — returned by add_settings_tab().
## Build controls with add_slider/add_toggle/add_option/etc.
## Auto-saves to settings_file when save_prefix is set.
## Emits saved(values) when the Settings Menu save button is pressed.
class SettingsTab extends RefCounted:
	signal saved(values: Dictionary)

	var _vbox: VBoxContainer
	var _scroll: ScrollContainer
	var _controls: Dictionary = {}      # key -> Control
	var _defaults: Dictionary = {}      # key -> default value
	var _save_prefix: String = ""
	var _settings_menu: Control  # SettingsMenu

	func _setup(tab_container: TabContainer, tab_name: String, sm: Control) -> void:
		_settings_menu = sm

		_scroll = ScrollContainer.new()
		_scroll.name = tab_name
		_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		tab_container.add_child(_scroll)

		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 4)
		margin.add_theme_constant_override("margin_right", 4)
		margin.add_theme_constant_override("margin_top", 4)
		margin.add_theme_constant_override("margin_bottom", 4)
		_scroll.add_child(margin)

		_vbox = VBoxContainer.new()
		_vbox.add_theme_constant_override("separation", 2)
		_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		margin.add_child(_vbox)

		sm.saved.connect(_on_saved)
		sm.visibility_changed.connect(_on_visible)


	## Add a horizontal slider with label. Returns the HSlider.
	func add_slider(label: String, key: String, min_v: float, max_v: float,
			step_v: float, default_value: float = 0.0) -> HSlider:
		_defaults[key] = default_value
		var row := _make_row(label)
		var slider := HSlider.new()
		slider.min_value = min_v
		slider.max_value = max_v
		slider.step = step_v
		slider.value = default_value
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.scrollable = false
		row.add_child(slider)
		_controls[key] = slider
		return slider


	## Add a spin box with label. Returns the SpinBox.
	func add_spinbox(label: String, key: String, min_v: float, max_v: float,
			step_v: float, default_value: float = 0.0) -> SpinBox:
		_defaults[key] = default_value
		var row := _make_row(label)
		var spinbox := SpinBox.new()
		spinbox.min_value = min_v
		spinbox.max_value = max_v
		spinbox.step = step_v
		spinbox.value = default_value
		spinbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spinbox.get_line_edit().context_menu_enabled = false
		row.add_child(spinbox)
		_controls[key] = spinbox
		return spinbox


	## Add a toggle (CheckButton) with label. Returns the CheckButton.
	func add_toggle(label: String, key: String, default_value: bool = false) -> CheckButton:
		_defaults[key] = default_value
		var row := _make_row(label)
		var btn := CheckButton.new()
		btn.button_pressed = default_value
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(btn)
		_controls[key] = btn
		return btn


	## Add a dropdown selector with label. items is Array[String]. Returns OptionButton.
	func add_option(label: String, key: String, items: Array,
			default_index: int = 0) -> OptionButton:
		_defaults[key] = default_index
		var row := _make_row(label)
		var opt := OptionButton.new()
		for i in items.size():
			opt.add_item(str(items[i]), i)
		opt.selected = default_index
		opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(opt)
		_controls[key] = opt
		return opt


	## Add a color picker with label. Returns ColorPickerButton.
	func add_color(label: String, key: String,
			default_value: Color = Color.WHITE) -> ColorPickerButton:
		_defaults[key] = default_value
		var row := _make_row(label)
		var picker := ColorPickerButton.new()
		picker.color = default_value
		picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(picker)
		_controls[key] = picker
		return picker


	## Add a text input with label. Returns LineEdit.
	func add_text_input(label: String, key: String,
			default_value: String = "") -> LineEdit:
		_defaults[key] = default_value
		var row := _make_row(label)
		var line := LineEdit.new()
		line.text = default_value
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(line)
		_controls[key] = line
		return line


	## Add a section header label (dimmed).
	func add_header(text: String) -> Label:
		var label := Label.new()
		label.text = text
		label.modulate = Color(1, 1, 1, 0.6)
		_vbox.add_child(label)
		return label


	## Add an info label (full-width, auto-wrapping).
	func add_label(text: String) -> Label:
		var label := Label.new()
		label.text = text
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_vbox.add_child(label)
		return label


	## Add a horizontal separator line.
	func add_separator() -> HSeparator:
		var sep := HSeparator.new()
		_vbox.add_child(sep)
		return sep


	## Add vertical spacing.
	func add_spacer(height: float = 4.0) -> Control:
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(0, height)
		_vbox.add_child(spacer)
		return spacer


	## Add a custom control to the layout (not tracked by key).
	func add_custom(control: Control) -> void:
		_vbox.add_child(control)


	## Get the raw VBoxContainer for fully custom layouts.
	func get_container() -> VBoxContainer:
		return _vbox


	## Get current value of a control by key.
	func get_value(key: String) -> Variant:
		if key not in _controls:
			return _defaults.get(key)
		var ctrl = _controls[key]
		if ctrl is CheckButton:
			return ctrl.button_pressed
		if ctrl is HSlider or ctrl is SpinBox:
			return ctrl.value
		if ctrl is OptionButton:
			return ctrl.selected
		if ctrl is ColorPickerButton:
			return ctrl.color
		if ctrl is LineEdit:
			return ctrl.text
		return null


	## Set value of a control by key.
	func set_value(key: String, value: Variant) -> void:
		if key not in _controls:
			return
		var ctrl = _controls[key]
		if ctrl is CheckButton:
			ctrl.button_pressed = value
		elif ctrl is HSlider or ctrl is SpinBox:
			ctrl.value = value
		elif ctrl is OptionButton:
			if value is int:
				ctrl.selected = value
			elif value is String:
				for i in ctrl.item_count:
					if ctrl.get_item_text(i) == str(value):
						ctrl.selected = i
						break
		elif ctrl is ColorPickerButton:
			ctrl.color = value
		elif ctrl is LineEdit:
			ctrl.text = str(value)


	## Bulk-set multiple values.
	func set_values(values: Dictionary) -> void:
		for key in values:
			set_value(key, values[key])


	## Get all control values as a Dictionary.
	func get_all_values() -> Dictionary:
		var result: Dictionary = {}
		for key in _controls:
			result[key] = get_value(key)
		return result


	## Set the save-file key prefix for auto-persistence.
	## When set, values auto-save on Settings save and auto-load on open.
	func set_save_prefix(prefix: String) -> void:
		_save_prefix = prefix


	## Manually load values from save file (uses save_prefix + key).
	func load_values() -> void:
		if _save_prefix == "" or not Ref.save_file_manager:
			return
		for key in _defaults:
			var saved = Ref.save_file_manager.settings_file.get_data(
				_save_prefix + key, null)
			if saved != null:
				set_value(key, saved)


	## Remove this tab from the Settings Menu.
	func remove() -> void:
		if _scroll and is_instance_valid(_scroll):
			_scroll.queue_free()


	func _save_values() -> void:
		if _save_prefix == "" or not Ref.save_file_manager:
			return
		for key in _controls:
			Ref.save_file_manager.settings_file.set_data(
				_save_prefix + key, get_value(key))


	func _on_saved() -> void:
		if _save_prefix != "":
			_save_values()
		saved.emit(get_all_values())


	func _on_visible() -> void:
		if not _settings_menu or not _settings_menu.visible:
			return
		load_values()


	func _make_row(label_text: String) -> HBoxContainer:
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 14)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_vbox.add_child(row)
		var label := Label.new()
		label.text = label_text
		label.custom_minimum_size = Vector2(86, 0)
		label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		row.add_child(label)
		return row


var mods: Dictionary = {}
var _load_order: Array[String] = []
var _item_paths: Array[String] = []
var _hooks: Dictionary = {}
var _method_patches: Dictionary = {}  # "id.method" -> patch info
var _scene_injections: Array[Dictionary] = []  # queued until tree is ready
var _registered_resources: Dictionary = {}  # "items" / "recipes" / etc -> paths
var _settings_tabs: Array = []  # prevent GC on SettingsTab refs
var _mods_dir_path: String
var _bootstrapped: bool = false
var _mods_menu: Control = null
var _key_menu: int = KEY_F10
var i18n: Node = null  # i18n_manager instance

signal mods_initialized
signal mod_loaded(mod_id: String)


# called from ref.gd right after set_script()
func _bootstrap() -> void:
	if _bootstrapped:
		return
	_bootstrapped = true

	_mods_dir_path = OS.get_executable_path().get_base_dir().path_join("mods")
	_load_self_config()
	print("[QualiaMods] v1.3.0 — Phase 2 starting")
	print("[QualiaMods] Game version: ", ProjectSettings.get_setting("application/config/version"))
	print("[QualiaMods] Mods dir: %s" % _mods_dir_path)

	_scan_loaded_mods()
	_init_i18n()

	if mods.is_empty():
		print("[QualiaMods] No mods found.")
		_deferred_inject_language.call_deferred()
		return

	_discover_mods()
	_resolve_load_order()
	_load_mod_translations()
	_create_loading_screen()
	await RenderingServer.frame_post_draw
	await _initialize_mods_async()
	_finalize_loading_screen()
	_connect_game_hooks.call_deferred()
	mods_initialized.emit()


func _init_i18n() -> void:
	var i18n_script = load("res://mods/qualiamods/i18n/i18n_manager.gd")
	if not i18n_script:
		print("[QualiaMods] i18n module not found, skipping")
		return

	i18n = i18n_script.new()
	i18n.name = "I18nManager"
	add_child(i18n)

	# global translations from <game_dir>/lang/*.cfg — always available
	i18n.load_global_translations()
	i18n.apply_saved_locale()
	i18n.patch_tree.call_deferred()
	print("[QualiaMods] i18n initialized (global)")


func _load_mod_translations() -> void:
	if not i18n:
		return
	i18n.load_mod_translations(_load_order)
	print("[QualiaMods] i18n mod translations loaded (%d mods)" % _load_order.size())


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


# find .pck files in the mods folder (and subfolders) and register them
func _scan_loaded_mods() -> void:
	var disabled_cfg := ConfigFile.new()
	disabled_cfg.load(_mods_dir_path.path_join("disabled_mods.cfg"))
	_scan_dir_recursive(_mods_dir_path, disabled_cfg)


func _scan_dir_recursive(path: String, disabled_cfg: ConfigFile) -> void:
	var dir := DirAccess.open(path)
	if not dir:
		return

	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var full_path := path.path_join(entry)
		if dir.current_is_dir() and not entry.begins_with("."):
			_scan_dir_recursive(full_path, disabled_cfg)
		elif entry.ends_with(".pck"):
			var mod_id := entry.get_basename()

			# don't register ourselves
			if mod_id.begins_with("_000_qualiamods"):
				entry = dir.get_next()
				continue

			# load .pck from subfolders (vanilla loader only scans root)
			if path != _mods_dir_path:
				ProjectSettings.load_resource_pack(full_path)
				print("[QualiaMods] Loaded .pck from subfolder: %s" % full_path)

			var is_disabled: bool = disabled_cfg.get_value("disabled", mod_id, false)
			var info := ModInfo.new()
			info.id = mod_id
			info.pck_path = full_path
			info.enabled = not is_disabled
			info.name = mod_id
			info.version = "?"
			info.author = "?"
			info.load_order = 0
			info.config = {}
			info.config_hints = {}
			info.dependencies = {}
			mods[mod_id] = info

			if is_disabled:
				print("[QualiaMods] Found disabled: %s" % mod_id)
			else:
				print("[QualiaMods] Found: %s" % mod_id)
		entry = dir.get_next()


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

		# parse config hints (min/max/step) for numeric values
		info.config_hints = {}
		for hint_section in ["config_min", "config_max", "config_step"]:
			if cfg.has_section(hint_section):
				var hint_type: String = hint_section.trim_prefix("config_")
				for key in cfg.get_section_keys(hint_section):
					if key not in info.config_hints:
						info.config_hints[key] = {}
					info.config_hints[key][hint_type] = cfg.get_value(hint_section, key)

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


# ── Loading screen ────────────────────────────────────────────────

var _loading_layer: CanvasLayer
var _loading_progress_bar: ProgressBar
var _loading_status_label: Label
var _loading_mod_list: VBoxContainer


func _create_loading_screen() -> void:
	_replace_splash_content()

	_loading_layer = CanvasLayer.new()
	_loading_layer.layer = 128
	_loading_layer.process_mode = Node.PROCESS_MODE_ALWAYS

	var game_theme: Theme = load("res://main/ui/theme/theme.tres")

	var bg_rect := ColorRect.new()
	bg_rect.color = Color(0, 0, 0, 1)
	bg_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if game_theme:
		bg_rect.theme = game_theme
	_loading_layer.add_child(bg_rect)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(160, 0)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	bg_rect.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "loading mods"
	title.add_theme_font_size_override("font_size", 10)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var enabled_count := 0
	for id in mods:
		if mods[id].enabled:
			enabled_count += 1

	vbox.add_child(HSeparator.new())

	_loading_mod_list = VBoxContainer.new()
	_loading_mod_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_loading_mod_list.add_theme_constant_override("separation", 1)
	vbox.add_child(_loading_mod_list)

	for mod_id in _load_order:
		var info: ModInfo = mods[mod_id]
		if not info.enabled:
			continue
		var row := HBoxContainer.new()
		row.name = "row_%s" % mod_id
		row.add_theme_constant_override("separation", 4)

		var status_icon := Label.new()
		status_icon.name = "status"
		status_icon.text = ".."
		status_icon.custom_minimum_size = Vector2(14, 0)
		status_icon.modulate = Color(1, 1, 1, 0.3)
		row.add_child(status_icon)

		var name_label := Label.new()
		name_label.text = "%s" % info.name.to_lower()
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.modulate = Color(1, 1, 1, 0.3)
		row.add_child(name_label)

		_loading_mod_list.add_child(row)

	vbox.add_child(HSeparator.new())

	_loading_progress_bar = ProgressBar.new()
	_loading_progress_bar.min_value = 0
	_loading_progress_bar.max_value = enabled_count
	_loading_progress_bar.value = 0
	_loading_progress_bar.custom_minimum_size = Vector2(0, 8)
	_loading_progress_bar.show_percentage = false
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.031, 0.031, 0.039, 1.0)
	bar_bg.anti_aliasing = false
	_loading_progress_bar.add_theme_stylebox_override("background", bar_bg)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.208, 0.208, 0.231, 1.0)
	bar_fill.anti_aliasing = false
	_loading_progress_bar.add_theme_stylebox_override("fill", bar_fill)
	vbox.add_child(_loading_progress_bar)

	_loading_status_label = Label.new()
	_loading_status_label.text = "scanning..."
	_loading_status_label.modulate = Color(1, 1, 1, 0.4)
	vbox.add_child(_loading_status_label)

	add_child(_loading_layer)
	print("[QualiaMods] Loading screen created")


func _replace_splash_content() -> void:
	var splash_layer := get_tree().get_root().get_node_or_null("Main/SplashLayer")
	if not splash_layer:
		print("[QualiaMods] SplashLayer not found, skipping replacement")
		return

	var splash_img := splash_layer.get_node_or_null("Splash")
	if splash_img:
		splash_img.visible = false

	var game_theme: Theme = load("res://main/ui/theme/theme.tres")

	var container := CenterContainer.new()
	container.name = "QualiaModsSplash"
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if game_theme:
		container.theme = game_theme
	splash_layer.add_child(container)

	var label := Label.new()
	label.text = "loading..."
	label.add_theme_font_size_override("font_size", 10)
	label.modulate = Color(1, 1, 1, 0.4)
	container.add_child(label)

	print("[QualiaMods] SplashLayer content replaced")


func _update_loading_progress(mod_id: String, status: String, done: bool) -> void:
	_loading_status_label.text = status.to_lower()

	var row = _loading_mod_list.get_node_or_null("row_%s" % mod_id)
	if row:
		var status_label: Label = row.get_node("status")
		var name_label: Label = row.get_children()[1]
		if done:
			status_label.text = "ok"
			status_label.modulate = Color(1, 1, 1, 0.7)
			name_label.modulate = Color(1, 1, 1, 0.7)
		else:
			status_label.text = ">>"
			status_label.modulate = Color(1, 1, 1, 0.5)
			name_label.modulate = Color(1, 1, 1, 0.5)

	if done:
		_loading_progress_bar.value += 1


func _finalize_loading_screen() -> void:
	if not _loading_layer:
		return
	_loading_status_label.text = "done"
	get_tree().create_timer(1.0).timeout.connect(func():
		if _loading_layer and is_instance_valid(_loading_layer):
			_loading_layer.queue_free()
			_loading_layer = null
			print("[QualiaMods] Loading screen overlay removed")
	)


# load mod_main.gd for each mod, add to tree, call _init_mod
func _initialize_mods_async() -> void:
	for mod_id in _load_order:
		var info: ModInfo = mods[mod_id]
		if not info.enabled:
			print("[QualiaMods] Skipping disabled: %s" % mod_id)
			continue

		_update_loading_progress(mod_id, "Loading %s..." % info.name, false)
		await RenderingServer.frame_post_draw

		var script_path := "res://mods/%s/mod_main.gd" % mod_id
		if not FileAccess.file_exists(script_path):
			print("[QualiaMods] '%s' — resource-only (no mod_main.gd)" % mod_id)
			_update_loading_progress(mod_id, "%s (resource-only)" % info.name, true)
			mod_loaded.emit(mod_id)
			await RenderingServer.frame_post_draw
			continue

		var script := load(script_path)
		if not script:
			printerr("[QualiaMods] Failed to load: %s" % script_path)
			await RenderingServer.frame_post_draw
			continue

		var instance: Node = script.new()
		instance.name = "Mod_%s" % mod_id
		info.instance = instance
		add_child(instance)

		if instance.has_method("_init_mod"):
			instance._init_mod(info.config)

		print("[QualiaMods] Initialized: %s v%s" % [info.name, info.version])
		_update_loading_progress(mod_id, "%s v%s" % [info.name, info.version], true)
		mod_loaded.emit(mod_id)
		await RenderingServer.frame_post_draw

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
	_inject_language_selector.call_deferred()

	# let mods know the game is ready
	for mod_id in _load_order:
		var info: ModInfo = mods[mod_id]
		if info.instance and info.instance.has_method("_game_ready"):
			info.instance._game_ready()

	# flush anything that was queued before the tree was ready
	_process_scene_injections()

	emit_hook(Hooks.MODS_ALL_READY)


# inject mods + language buttons in a single row after settings
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
	var sound_script = load("res://main/ui/theme/sound_button.gd")

	# row container for mods + language
	var row := HBoxContainer.new()
	row.name = "QualiaModsRow"
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 2)

	var mods_btn := Button.new()
	mods_btn.text = "mods"
	mods_btn.name = "ModsButton"
	mods_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if sound_script:
		mods_btn.set_script(sound_script)
	mods_btn.pressed.connect(_on_mods_button_pressed)
	row.add_child(mods_btn)

	var settings_idx: int = settings_btn.get_index()
	btn_container.add_child(row)
	btn_container.move_child(row, settings_idx + 1)

	print("[QualiaMods] Mods button injected into main menu.")


var _lang_menu: Control = null


func _deferred_inject_language() -> void:
	await get_tree().process_frame
	_inject_language_selector()


func _inject_language_selector() -> void:
	if not i18n or i18n.available_locales.size() < 2:
		print("[QualiaMods] Less than 2 locales, skipping language selector")
		return

	var main_menu = get_tree().get_root().get_node_or_null("Main/UI/MainMenu")
	if not main_menu:
		return

	var row = main_menu.find_child("QualiaModsRow", true, false)
	if not row:
		# no mods loaded — create standalone row for the language button
		var settings_btn = main_menu.get_node_or_null("%SettingsButton")
		if not settings_btn:
			return
		row = HBoxContainer.new()
		row.name = "QualiaModsRow"
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 2)
		var idx: int = settings_btn.get_index()
		settings_btn.get_parent().add_child(row)
		settings_btn.get_parent().move_child(row, idx + 1)

	var sound_script = load("res://main/ui/theme/sound_button.gd")

	var lang_btn := Button.new()
	lang_btn.name = "LanguageButton"
	lang_btn.text = "Language" if mods.is_empty() else "lang"
	lang_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if sound_script:
		lang_btn.set_script(sound_script)

	lang_btn.pressed.connect(_on_lang_button_pressed)
	row.add_child(lang_btn)

	print("[QualiaMods] Language button injected (%d locales)" % i18n.available_locales.size())


func _on_lang_button_pressed() -> void:
	var main_menu = get_tree().get_root().get_node_or_null("Main/UI/MainMenu")
	if main_menu and main_menu.has_method("deactivate"):
		main_menu.deactivate()

	await Ref.trans.open()

	_ensure_lang_menu()
	_lang_menu.open()
	if main_menu:
		main_menu.visible = false

	await Ref.trans.close()
	_lang_menu.activate()


func _ensure_lang_menu() -> void:
	if _lang_menu:
		return

	var menu_script = load("res://mods/qualiamods/i18n/language_menu.gd")
	if not menu_script:
		printerr("[QualiaMods] Could not load language menu")
		return

	_lang_menu = menu_script.new()
	_lang_menu.name = "LanguageMenu"

	var ui_layer = get_tree().get_root().get_node_or_null("Main/UI")
	if ui_layer:
		ui_layer.add_child(_lang_menu)
	else:
		get_tree().get_root().add_child(_lang_menu)

	_lang_menu.close()

	if _lang_menu.has_signal("exited"):
		_lang_menu.exited.connect(_on_lang_menu_exited)


func _on_lang_menu_exited() -> void:
	_lang_menu.deactivate()

	await Ref.trans.open()

	_lang_menu.close()
	var main_menu = get_tree().get_root().get_node_or_null("Main/UI/MainMenu")
	if main_menu:
		main_menu.visible = true

	await Ref.trans.close()

	if main_menu and main_menu.has_method("activate"):
		main_menu.activate()


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


## Add a new tab to the Settings Menu. Returns a SettingsTab builder.
## Use the returned object to add sliders, toggles, dropdowns, etc.
## Example:
##   var tab = ModLoader.add_settings_tab("My Tab")
##   tab.set_save_prefix("mymod_")
##   tab.add_toggle("feature", "my_feature", false)
##   tab.add_slider("amount", "my_amount", 0.0, 1.0, 0.05, 0.5)
##   tab.load_values()
##   tab.saved.connect(_on_my_settings_saved)
func add_settings_tab(tab_name: String) -> SettingsTab:
	var sm = Ref.settings_menu
	if not sm:
		printerr("[QualiaMods] add_settings_tab: SettingsMenu not found")
		return null

	var tab_container = sm.get_node_or_null("%TabContainer")
	if not tab_container:
		printerr("[QualiaMods] add_settings_tab: TabContainer not found")
		return null

	var tab := SettingsTab.new()
	tab._setup(tab_container, tab_name, sm)
	_settings_tabs.append(tab)
	print("[QualiaMods] Settings tab '%s' added" % tab_name)
	return tab


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


# ── i18n public API ───────────────────────────────────────────────

## Set the active locale (e.g. "ru", "ja", "en").
func set_locale(locale: String) -> void:
	if i18n:
		i18n.set_locale(locale)


## Get the current locale code.
func get_locale() -> String:
	if i18n:
		return i18n.get_locale()
	return "en"


## Get all available locales loaded from mod translations.
func get_available_locales() -> Array[String]:
	if i18n:
		return i18n.get_available_locales()
	return []


## Load a single .cfg translation file at runtime.
func load_translation(cfg_path: String) -> void:
	if not i18n:
		printerr("[QualiaMods] i18n not initialized")
		return
	i18n.load_translation_file(cfg_path)


## Re-scan <game_dir>/lang/ for new translation files.
func reload_translations() -> void:
	if not i18n:
		printerr("[QualiaMods] i18n not initialized")
		return
	i18n.load_global_translations()
	i18n.load_mod_translations(_load_order)


## Get display name for a locale (e.g. "ru" -> "Русский").
func get_locale_display_name(locale: String) -> String:
	if i18n:
		return i18n.get_locale_display_name(locale)
	return locale


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE or what == NOTIFICATION_EXIT_TREE:
		for mod_id in _load_order:
			var info: ModInfo = mods[mod_id]
			if info.instance and info.instance.has_method("_mod_cleanup"):
				info.instance._mod_cleanup()

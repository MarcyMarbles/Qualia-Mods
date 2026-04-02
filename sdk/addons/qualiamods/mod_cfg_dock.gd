@tool
extends Control

const TYPE_NAMES := ["string", "int", "float", "bool"]
const REQUIRED_MOD_KEYS := ["name", "version", "author"]

var _current_path: String = ""
var _cfg: ConfigFile
var _scroll: ScrollContainer
var _content: VBoxContainer
var _title_label: Label
var _path_label: Label
var _status_label: Label
var _no_file_label: Label
var _validation_panel: PanelContainer
var _validation_label: RichTextLabel
var _sync_timer: Timer
var _updating: bool = false
var _last_modified_time: int = -1
var _config_data: Dictionary = {}
var _config_order: PackedStringArray = []
var _bound_code_edit: CodeEdit
var _ignore_editor_text_change: bool = false


func _ready() -> void:
	name = "CFG Editor"
	custom_minimum_size = Vector2(320, 0)

	var root_vbox := VBoxContainer.new()
	root_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_vbox.add_theme_constant_override("separation", 6)
	add_child(root_vbox)

	_title_label = Label.new()
	_title_label.text = "CFG Editor"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root_vbox.add_child(_title_label)

	_path_label = Label.new()
	_path_label.text = "No mod.cfg selected"
	_path_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_path_label.modulate = Color(1, 1, 1, 0.55)
	_path_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root_vbox.add_child(_path_label)

	_status_label = Label.new()
	_status_label.text = ""
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.modulate = Color(0.7, 0.9, 1.0, 0.8)
	root_vbox.add_child(_status_label)

	_validation_panel = PanelContainer.new()
	_validation_panel.visible = false
	root_vbox.add_child(_validation_panel)

	_validation_label = RichTextLabel.new()
	_validation_label.fit_content = true
	_validation_label.bbcode_enabled = true
	_validation_label.scroll_active = false
	_validation_label.custom_minimum_size = Vector2(0, 48)
	_validation_panel.add_child(_validation_label)

	root_vbox.add_child(HSeparator.new())

	_no_file_label = Label.new()
	_no_file_label.text = "Select a mod.cfg in FileSystem or Script Editor"
	_no_file_label.modulate = Color(1, 1, 1, 0.5)
	_no_file_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_no_file_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root_vbox.add_child(_no_file_label)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.visible = false
	root_vbox.add_child(_scroll)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 6)
	_scroll.add_child(_content)

	_sync_timer = Timer.new()
	_sync_timer.one_shot = true
	_sync_timer.wait_time = 0.3
	_sync_timer.timeout.connect(_sync_from_editor_buffer)
	add_child(_sync_timer)

func load_cfg(path: String, force: bool = false) -> void:
	if not path.ends_with(".cfg"):
		return
	var disk_mtime := _get_modified_time(path)
	if not force and path == _current_path and disk_mtime == _last_modified_time:
		return

	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	if not cfg.has_section("mod"):
		return

	_current_path = path
	_cfg = cfg
	_last_modified_time = _get_modified_time(path)
	_title_label.text = path.get_file()
	_path_label.text = path
	_status_label.text = ""
	_no_file_label.visible = false
	_scroll.visible = true
	_rebuild_ui()
	_bind_current_code_edit()


func _rebuild_ui() -> void:
	for child in _content.get_children():
		child.queue_free()

	await get_tree().process_frame

	_refresh_validation()

	_add_section_header("mod")
	_add_string_field("mod", "api_version", "API Version")
	_add_string_field("mod", "name", "Name")
	_add_string_field("mod", "version", "Version")
	_add_string_field("mod", "author", "Author")
	_add_text_field("mod", "description", "Description")
	_add_string_field("mod", "game_version", "Game Version")
	_add_int_field("mod", "load_order", "Load Order", -1000, 10000)
	_add_bool_field("mod", "config_editable", "Config Editable")

	_content.add_child(HSeparator.new())

	_add_section_header("dependencies")
	_build_dependencies_ui()

	_content.add_child(HSeparator.new())

	_add_section_header("config")
	_build_config_ui()


func _add_section_header(text: String) -> void:
	var label := Label.new()
	label.text = "[%s]" % text
	label.add_theme_font_size_override("font_size", 13)
	label.modulate = Color(1, 1, 1, 0.72)
	_content.add_child(label)


func _add_string_field(section: String, key: String, label_text: String) -> void:
	var row := _make_row(label_text)
	var edit := LineEdit.new()
	edit.text = str(_cfg.get_value(section, key, ""))
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.text_changed.connect(func(new_text: String) -> void:
		_set_and_save(section, key, new_text)
	)
	row.add_child(edit)


func _add_text_field(section: String, key: String, label_text: String) -> void:
	var label := Label.new()
	label.text = label_text
	_content.add_child(label)

	var edit := TextEdit.new()
	edit.text = str(_cfg.get_value(section, key, ""))
	edit.custom_minimum_size = Vector2(0, 72)
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.text_changed.connect(func() -> void:
		_set_and_save(section, key, edit.text)
	)
	_content.add_child(edit)


func _add_int_field(section: String, key: String, label_text: String, min_value: float, max_value: float) -> void:
	var row := _make_row(label_text)
	var spin := SpinBox.new()
	spin.min_value = min_value
	spin.max_value = max_value
	spin.step = 1
	spin.rounded = true
	spin.value = float(_cfg.get_value(section, key, 0))
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin.value_changed.connect(func(val: float) -> void:
		_set_and_save(section, key, int(val))
	)
	row.add_child(spin)


func _add_bool_field(section: String, key: String, label_text: String) -> void:
	var row := _make_row(label_text)
	var toggle := CheckButton.new()
	toggle.button_pressed = bool(_cfg.get_value(section, key, false))
	toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toggle.toggled.connect(func(pressed: bool) -> void:
		_set_and_save(section, key, pressed)
	)
	row.add_child(toggle)


func _build_dependencies_ui() -> void:
	var deps_box := VBoxContainer.new()
	deps_box.name = "DependenciesBox"
	deps_box.add_theme_constant_override("separation", 4)
	_content.add_child(deps_box)

	if _cfg.has_section("dependencies"):
		for key in _cfg.get_section_keys("dependencies"):
			_add_dep_row(deps_box, key)

	var add_row := HBoxContainer.new()
	add_row.add_theme_constant_override("separation", 4)
	_content.add_child(add_row)

	var add_edit := LineEdit.new()
	add_edit.placeholder_text = "new dependency id"
	add_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_row.add_child(add_edit)

	var add_btn := Button.new()
	add_btn.text = "+ dependency"
	add_btn.pressed.connect(func() -> void:
		var dep_id := add_edit.text.strip_edges()
		if dep_id == "":
			return
		_add_dep_row(deps_box, dep_id)
		add_edit.clear()
		_save_dependencies(deps_box)
	)
	add_row.add_child(add_btn)


func _add_dep_row(parent: VBoxContainer, dep_id: String) -> void:
	for existing in parent.get_children():
		if not existing is HBoxContainer:
			continue
		var existing_edit := existing.get_child(0) as LineEdit
		if existing_edit and existing_edit.text.strip_edges() == dep_id and dep_id != "":
			return

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)

	var edit := LineEdit.new()
	edit.text = dep_id
	edit.placeholder_text = "mod_id"
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.text_changed.connect(func(_new_text: String) -> void:
		_save_dependencies(parent)
	)
	row.add_child(edit)

	var del_btn := Button.new()
	del_btn.text = "x"
	del_btn.custom_minimum_size = Vector2(24, 0)
	del_btn.pressed.connect(func() -> void:
		row.queue_free()
		_save_dependencies.call_deferred(parent)
	)
	row.add_child(del_btn)


func _save_dependencies(deps_box: VBoxContainer) -> void:
	if _updating:
		return

	_updating = true
	if _cfg.has_section("dependencies"):
		for key in _cfg.get_section_keys("dependencies"):
			_cfg.erase_section_key("dependencies", key)

	for row in deps_box.get_children():
		if not row is HBoxContainer:
			continue
		var edit := row.get_child(0) as LineEdit
		if edit == null:
			continue
		var dep_id := edit.text.strip_edges()
		if dep_id != "":
			_cfg.set_value("dependencies", dep_id, true)

	_save_cfg("Dependencies updated")
	_updating = false


func _build_config_ui() -> void:
	_config_data.clear()
	_config_order.clear()

	var cfg_box := VBoxContainer.new()
	cfg_box.name = "ConfigBox"
	cfg_box.add_theme_constant_override("separation", 4)
	_content.add_child(cfg_box)

	if _cfg.has_section("config"):
		for key in _cfg.get_section_keys("config"):
			var value = _cfg.get_value("config", key)
			var entry: Dictionary = {
				"type": _detect_type(value),
				"value": value,
			}
			if _cfg.has_section_key("config_min", key):
				entry["min"] = _cfg.get_value("config_min", key)
			if _cfg.has_section_key("config_max", key):
				entry["max"] = _cfg.get_value("config_max", key)
			if _cfg.has_section_key("config_step", key):
				entry["step"] = _cfg.get_value("config_step", key)
			_config_data[key] = entry
			_config_order.append(key)
			_add_config_row(cfg_box, key)

	var add_row := HBoxContainer.new()
	add_row.add_theme_constant_override("separation", 4)
	_content.add_child(add_row)

	var key_edit := LineEdit.new()
	key_edit.placeholder_text = "key"
	key_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_row.add_child(key_edit)

	var type_opt := OptionButton.new()
	for type_name in TYPE_NAMES:
		type_opt.add_item(type_name)
	add_row.add_child(type_opt)

	var add_btn := Button.new()
	add_btn.text = "+ add"
	add_btn.pressed.connect(func() -> void:
		var key := key_edit.text.strip_edges()
		if key == "" or _config_data.has(key):
			return
		_config_data[key] = _make_default_config_entry(type_opt.selected)
		_config_order.append(key)
		_flush_config("Added config key")
		_add_config_row(cfg_box, key)
		key_edit.clear()
	)
	add_row.add_child(add_btn)


func _detect_type(value) -> int:
	if value is bool:
		return 3
	if value is int:
		return 1
	if value is float:
		return 2
	return 0


func _make_default_config_entry(type_idx: int) -> Dictionary:
	match type_idx:
		1:
			return {"type": 1, "value": 0, "min": 0.0, "max": 100.0, "step": 1.0}
		2:
			return {"type": 2, "value": 0.0, "min": 0.0, "max": 1.0, "step": 0.1}
		3:
			return {"type": 3, "value": false}
		_:
			return {"type": 0, "value": ""}


func _add_config_row(parent: VBoxContainer, key: String) -> void:
	if not _config_data.has(key):
		return
	if _find_config_row(parent, key):
		return

	var entry: Dictionary = _config_data[key]
	var row := HBoxContainer.new()
	row.name = "config_%s" % key
	row.set_meta("config_key", key)
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)

	var key_label := Label.new()
	key_label.text = key
	key_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(key_label)

	var type_opt := OptionButton.new()
	for type_name in TYPE_NAMES:
		type_opt.add_item(type_name)
	type_opt.selected = int(entry.get("type", 0))
	type_opt.disabled = true
	row.add_child(type_opt)

	var edit_btn := Button.new()
	edit_btn.text = "#"
	edit_btn.tooltip_text = "Edit value and hints"
	edit_btn.custom_minimum_size = Vector2(24, 0)
	edit_btn.pressed.connect(func() -> void:
		_show_config_edit_dialog(parent, key, int(entry.get("type", 0)))
	)
	row.add_child(edit_btn)

	var del_btn := Button.new()
	del_btn.text = "x"
	del_btn.custom_minimum_size = Vector2(24, 0)
	del_btn.pressed.connect(func() -> void:
		_config_data.erase(key)
		var key_index := _config_order.find(key)
		if key_index >= 0:
			_config_order.remove_at(key_index)
		row.queue_free()
		_flush_config("Removed config key")
	)
	row.add_child(del_btn)


func _show_config_edit_dialog(cfg_box: VBoxContainer, existing_key: String, existing_type: int) -> void:
	var is_new: bool = existing_key == ""
	var entry: Dictionary = _config_data.get(existing_key, {})

	var dialog := AcceptDialog.new()
	dialog.title = "Edit Config" if not is_new else "New Config"
	dialog.ok_button_text = "Apply"
	dialog.min_size = Vector2i(320, 0)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	dialog.add_child(vbox)

	var key_edit := _make_labeled_field(vbox, "Key", existing_key)
	key_edit.editable = is_new

	var type_row := HBoxContainer.new()
	type_row.add_theme_constant_override("separation", 4)
	vbox.add_child(type_row)

	var type_label := Label.new()
	type_label.text = "Type"
	type_label.custom_minimum_size = Vector2(64, 0)
	type_row.add_child(type_label)

	var type_opt := OptionButton.new()
	type_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for type_name in TYPE_NAMES:
		type_opt.add_item(type_name)
	type_opt.selected = existing_type if existing_type >= 0 else 0
	type_row.add_child(type_opt)

	var value_label := Label.new()
	value_label.text = "Value"
	vbox.add_child(value_label)

	var string_edit := LineEdit.new()
	string_edit.text = str(entry.get("value", ""))
	string_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(string_edit)

	var int_spin := SpinBox.new()
	int_spin.rounded = true
	int_spin.step = 1
	int_spin.value = float(entry.get("value", 0))
	int_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(int_spin)

	var float_spin := SpinBox.new()
	float_spin.step = 0.1
	float_spin.value = float(entry.get("value", 0.0))
	float_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(float_spin)

	var bool_check := CheckBox.new()
	bool_check.text = "Enabled"
	bool_check.button_pressed = bool(entry.get("value", false))
	vbox.add_child(bool_check)

	vbox.add_child(HSeparator.new())

	var hints_label := Label.new()
	hints_label.text = "Numeric hints"
	hints_label.modulate = Color(1, 1, 1, 0.65)
	vbox.add_child(hints_label)

	var min_edit := _make_labeled_field(vbox, "Min", str(entry.get("min", "")))
	var max_edit := _make_labeled_field(vbox, "Max", str(entry.get("max", "")))
	var step_edit := _make_labeled_field(vbox, "Step", str(entry.get("step", "")))

	var update_visibility := func() -> void:
		var type_idx: int = type_opt.selected
		string_edit.visible = type_idx == 0
		int_spin.visible = type_idx == 1
		float_spin.visible = type_idx == 2
		bool_check.visible = type_idx == 3

		var is_numeric := type_idx == 1 or type_idx == 2
		hints_label.visible = is_numeric
		min_edit.get_parent().visible = is_numeric
		max_edit.get_parent().visible = is_numeric
		step_edit.get_parent().visible = is_numeric

	type_opt.item_selected.connect(func(_idx: int) -> void:
		update_visibility.call()
	)
	update_visibility.call()

	dialog.confirmed.connect(func() -> void:
		var key := key_edit.text.strip_edges()
		if key == "":
			return
		if is_new and _config_data.has(key):
			return

		var type_idx: int = type_opt.selected
		var updated: Dictionary = {"type": type_idx}
		match type_idx:
			1:
				updated["value"] = int(int_spin.value)
			2:
				updated["value"] = float(float_spin.value)
			3:
				updated["value"] = bool_check.button_pressed
			_:
				updated["value"] = string_edit.text

		if type_idx == 1 or type_idx == 2:
			_apply_numeric_hint(updated, "min", min_edit.text)
			_apply_numeric_hint(updated, "max", max_edit.text)
			_apply_numeric_hint(updated, "step", step_edit.text)

		if not is_new and key != existing_key:
			if _config_data.has(key):
				return
			var existing_index := _config_order.find(existing_key)
			if existing_index >= 0:
				_config_order[existing_index] = key
			_config_data.erase(existing_key)
		elif is_new:
			_config_order.append(key)

		_config_data[key] = updated
		_flush_config("Config updated", true)

		_rebuild_ui.call_deferred()
		dialog.queue_free()
	)

	dialog.canceled.connect(func() -> void:
		dialog.queue_free()
	)

	EditorInterface.get_base_control().add_child(dialog)
	dialog.popup_centered()


func _apply_numeric_hint(entry: Dictionary, field_name: String, text: String) -> void:
	var value := text.strip_edges()
	if value == "":
		entry.erase(field_name)
	elif value.is_valid_float():
		entry[field_name] = float(value)


func _find_config_row(parent: VBoxContainer, key: String) -> HBoxContainer:
	for child in parent.get_children():
		if child is HBoxContainer and child.has_meta("config_key") and child.get_meta("config_key") == key:
			return child as HBoxContainer
	return null


func _make_labeled_field(parent: VBoxContainer, label_text: String, value: String) -> LineEdit:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(64, 0)
	row.add_child(label)

	var edit := LineEdit.new()
	edit.text = value
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(edit)
	return edit


func _make_row(label_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	_content.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(96, 0)
	row.add_child(label)
	return row


func _set_config_value(key: String, value, status_text: String) -> void:
	if not _config_data.has(key):
		return
	var entry: Dictionary = _config_data[key]
	entry["value"] = value
	_config_data[key] = entry
	_flush_config(status_text)


func _flush_config(status_text: String = "Saved", refresh_open_tab: bool = false) -> void:
	for section in ["config", "config_min", "config_max", "config_step"]:
		if _cfg.has_section(section):
			for key in _cfg.get_section_keys(section):
				_cfg.erase_section_key(section, key)

	for key in _config_order:
		if not _config_data.has(key):
			continue
		var entry: Dictionary = _config_data[key]
		_cfg.set_value("config", key, entry["value"])
		if entry.has("min"):
			_cfg.set_value("config_min", key, entry["min"])
		if entry.has("max"):
			_cfg.set_value("config_max", key, entry["max"])
		if entry.has("step"):
			_cfg.set_value("config_step", key, entry["step"])

	_save_cfg(status_text, refresh_open_tab)


func _set_and_save(section: String, key: String, value) -> void:
	if _updating:
		return
	_cfg.set_value(section, key, value)
	_save_cfg("Saved %s/%s" % [section, key])


func _save_cfg(status_text: String, refresh_open_tab: bool = false) -> void:
	if _current_path == "":
		return

	_cfg.save(_current_path)
	_last_modified_time = _get_modified_time(_current_path)
	_status_label.text = status_text
	_refresh_validation()
	_notify_editor(refresh_open_tab)


func _reload_from_disk(status_text: String) -> void:
	var cfg := ConfigFile.new()
	if cfg.load(_current_path) != OK:
		return
	if not cfg.has_section("mod"):
		return

	_cfg = cfg
	_last_modified_time = _get_modified_time(_current_path)
	_status_label.text = status_text
	_rebuild_ui()
	_bind_current_code_edit()
	if EditorInterface.get_current_path() == _current_path:
		_refresh_open_cfg_tab.call_deferred()


func _refresh_validation() -> void:
	var issues := _validate_cfg()
	if issues.is_empty():
		_validation_panel.visible = false
		_validation_label.clear()
		return

	_validation_panel.visible = true
	_validation_label.clear()
	_validation_label.append_text("[color=#ffb86b]Validation[/color]\n")
	for issue in issues:
		_validation_label.append_text("- %s\n" % issue)


func _validate_cfg() -> PackedStringArray:
	var issues := PackedStringArray()
	if _cfg == null:
		return issues

	if not _cfg.has_section("mod"):
		issues.append("Missing [mod] section.")
		return issues

	for key in REQUIRED_MOD_KEYS:
		var value := str(_cfg.get_value("mod", key, "")).strip_edges()
		if value == "":
			issues.append("[mod] %s should not be empty." % key)

	if not _cfg.has_section_key("mod", "api_version"):
		issues.append("[mod] api_version is recommended for public QualiaMods compatibility.")
	elif not (_cfg.get_value("mod", "api_version") is String):
		issues.append("[mod] api_version should be a string like 1.0.")

	var version := str(_cfg.get_value("mod", "version", "")).strip_edges()
	if version != "" and not version.contains("."):
		issues.append("[mod] version should usually look like semantic versioning, e.g. 1.0.0.")

	var load_order = _cfg.get_value("mod", "load_order", 0)
	if not (load_order is int):
		issues.append("[mod] load_order should be an integer.")

	if _cfg.has_section_key("mod", "config_editable") and not (_cfg.get_value("mod", "config_editable") is bool):
		issues.append("[mod] config_editable should be true or false.")

	if _cfg.has_section("dependencies"):
		for dep_id in _cfg.get_section_keys("dependencies"):
			if not _is_valid_identifier(dep_id):
				issues.append("[dependencies] '%s' should use a-z, 0-9 or _." % dep_id)

	if _cfg.has_section("config"):
		for config_key in _cfg.get_section_keys("config"):
			if not _is_valid_identifier(config_key):
				issues.append("[config] key '%s' should use a-z, 0-9 or _." % config_key)

			var value = _cfg.get_value("config", config_key)
			if _cfg.has_section_key("config_min", config_key) and not (value is int or value is float):
				issues.append("[config_min] '%s' is set, but [config] value is not numeric." % config_key)
			if _cfg.has_section_key("config_max", config_key) and not (value is int or value is float):
				issues.append("[config_max] '%s' is set, but [config] value is not numeric." % config_key)
			if _cfg.has_section_key("config_step", config_key) and not (value is int or value is float):
				issues.append("[config_step] '%s' is set, but [config] value is not numeric." % config_key)

	return issues


func _is_valid_identifier(text: String) -> bool:
	if text == "":
		return false
	for i in text.length():
		var c := text.substr(i, 1)
		var is_lower := c >= "a" and c <= "z"
		var is_digit := c >= "0" and c <= "9"
		if not is_lower and not is_digit and c != "_":
			return false
	return true


func _notify_editor(refresh_open_tab: bool = false) -> void:
	if not Engine.is_editor_hint():
		return
	EditorInterface.get_resource_filesystem().update_file(_current_path)
	EditorInterface.get_resource_filesystem().scan()
	if refresh_open_tab:
		_refresh_open_cfg_tab.call_deferred()

func _bind_current_code_edit() -> void:
	var next_code_edit := _get_current_cfg_code_edit()
	if next_code_edit == _bound_code_edit:
		return

	if _bound_code_edit and _bound_code_edit.text_changed.is_connected(_on_bound_code_edit_text_changed):
		_bound_code_edit.text_changed.disconnect(_on_bound_code_edit_text_changed)

	_bound_code_edit = next_code_edit
	if _bound_code_edit and not _bound_code_edit.text_changed.is_connected(_on_bound_code_edit_text_changed):
		_bound_code_edit.text_changed.connect(_on_bound_code_edit_text_changed)


func _get_current_cfg_code_edit() -> CodeEdit:
	if EditorInterface.get_current_path() != _current_path:
		return null

	var script_editor := EditorInterface.get_script_editor()
	if not script_editor:
		return null

	var current_editor := script_editor.get_current_editor()
	if not current_editor:
		return null

	return _find_code_edit(current_editor)


func _on_bound_code_edit_text_changed() -> void:
	if _ignore_editor_text_change:
		return
	_sync_timer.start()


func _sync_from_editor_buffer() -> void:
	if _ignore_editor_text_change or _bound_code_edit == null:
		return
	if _has_incomplete_bareword(_bound_code_edit.text):
		return

	var parsed_cfg := ConfigFile.new()
	if parsed_cfg.parse(_bound_code_edit.text) != OK:
		return
	if not parsed_cfg.has_section("mod"):
		return

	_cfg = parsed_cfg
	_status_label.text = "Previewing unsaved editor changes"
	_refresh_validation()
	_rebuild_ui()


func _has_incomplete_bareword(text: String) -> bool:
	var lines := text.split("\n")
	for raw_line in lines:
		var line := raw_line.strip_edges()
		if line == "" or line.begins_with(";") or line.begins_with("#") or line.begins_with("["):
			continue
		var eq_index := line.find("=")
		if eq_index == -1:
			continue
		var value := line.substr(eq_index + 1).strip_edges()
		if value == "":
			return true
		if value.begins_with("\"") or value.begins_with("'"):
			continue
		if value.is_valid_int() or value.is_valid_float():
			continue
		if value in ["true", "false", "null", "inf", "-inf", "nan"]:
			continue
		var bareword := true
		for i in value.length():
			var c := value.substr(i, 1)
			var is_lower := c >= "a" and c <= "z"
			var is_upper := c >= "A" and c <= "Z"
			var is_digit := c >= "0" and c <= "9"
			if not is_lower and not is_upper and not is_digit and c != "_" and c != "." and c != "-":
				bareword = false
				break
		if bareword:
			return true
	return false


func _refresh_open_cfg_tab() -> void:
	if EditorInterface.get_current_path() != _current_path:
		return

	var code_edit := _get_current_cfg_code_edit()
	if not code_edit:
		return

	var file := FileAccess.open(_current_path, FileAccess.READ)
	if file == null:
		return

	var disk_text := file.get_as_text()
	if code_edit.text == disk_text:
		return

	var caret_line := code_edit.get_caret_line()
	var caret_column := code_edit.get_caret_column()
	_ignore_editor_text_change = true
	code_edit.text = disk_text
	if code_edit.has_method("tag_saved_version"):
		code_edit.tag_saved_version()
	code_edit.set_caret_line(min(caret_line, max(code_edit.get_line_count() - 1, 0)))
	code_edit.set_caret_column(caret_column)
	_ignore_editor_text_change = false


func _find_code_edit(node: Node) -> CodeEdit:
	if node is CodeEdit:
		return node as CodeEdit

	for child in node.get_children():
		var found := _find_code_edit(child)
		if found:
			return found

	return null


func _get_modified_time(path: String) -> int:
	if path == "":
		return -1
	return int(FileAccess.get_modified_time(path))

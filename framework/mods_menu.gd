class_name ModsMenu extends Menu


signal config_changed

var mod_entries: Dictionary = {}
var selected_mod_id: String = ""


func _ready() -> void:
	%BackButton.pressed.connect(emit_signal.bind("exited"))
	%SaveConfigButton.pressed.connect(_on_save_config)
	%SaveConfigButton.visible = false
	_build_mod_list()


func open() -> void:
	super.open()
	_build_mod_list()


func _build_mod_list() -> void:
	for child in %ModList.get_children():
		child.queue_free()
	mod_entries.clear()
	selected_mod_id = ""
	%DetailPanel.visible = false
	%NoModsLabel.visible = ModLoader.mods.is_empty()

	for mod_id in ModLoader.get_load_order():
		var info = ModLoader.mods[mod_id]
		_add_mod_entry(mod_id, info)

	# Also show disabled mods that failed dependency checks
	for mod_id in ModLoader.mods:
		if mod_id not in mod_entries:
			_add_mod_entry(mod_id, ModLoader.mods[mod_id])


func _add_mod_entry(mod_id: String, info) -> void:
	var hbox := HBoxContainer.new()
	hbox.set_meta("mod_id", mod_id)

	var toggle := CheckButton.new()
	toggle.button_pressed = info.enabled and not _is_mod_disabled_by_user(mod_id)
	toggle.toggled.connect(_on_mod_toggled.bind(mod_id))
	toggle.custom_minimum_size = Vector2(24, 0)
	hbox.add_child(toggle)

	var label := Button.new()
	label.text = "%s v%s" % [info.name, info.version]
	label.flat = true
	label.alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.pressed.connect(_on_mod_selected.bind(mod_id))
	hbox.add_child(label)

	if not info.enabled:
		label.modulate = Color(1, 0.6, 0.6, 0.7)

	%ModList.add_child(hbox)
	mod_entries[mod_id] = hbox


func _on_mod_selected(mod_id: String) -> void:
	selected_mod_id = mod_id
	var info = ModLoader.mods[mod_id]

	%ModName.text = info.name
	%ModVersion.text = "v%s" % info.version
	%ModAuthor.text = "by %s" % info.author
	%ModDescription.text = info.description if info.description != "" else "no description"

	var deps_text := ""
	if info.dependencies.size() > 0:
		for dep_id in info.dependencies:
			var dep_status := "[ok]" if ModLoader.is_mod_loaded(dep_id) else "[missing]"
			deps_text += "%s %s\n" % [dep_id, dep_status]
	else:
		deps_text = "none"
	%ModDependencies.text = deps_text

	# Build config editor
	_build_config_editor(mod_id, info)

	%DetailPanel.visible = true
	%SaveConfigButton.visible = info.config.size() > 0 and _is_config_editable(mod_id)


func _is_config_editable(mod_id: String) -> bool:
	var cfg_path := "res://mods/%s/mod.cfg" % mod_id
	var cfg := ConfigFile.new()
	if cfg.load(cfg_path) != OK:
		return false
	return cfg.get_value("mod", "config_editable", true)


func _build_config_editor(mod_id: String, info) -> void:
	for child in %ConfigList.get_children():
		child.queue_free()

	if info.config.size() == 0:
		var label := Label.new()
		label.text = "no config"
		label.modulate = Color(1, 1, 1, 0.5)
		%ConfigList.add_child(label)
		return

	var editable := _is_config_editable(mod_id)

	for key in info.config:
		var value = info.config[key]
		var row := HBoxContainer.new()
		row.set_meta("config_key", key)

		var name_label := Label.new()
		name_label.text = key
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.custom_minimum_size = Vector2(60, 0)
		row.add_child(name_label)

		if value is bool:
			var btn := CheckButton.new()
			btn.button_pressed = value
			btn.disabled = not editable
			btn.set_meta("config_control", true)
			row.add_child(btn)
		elif value is float or value is int:
			var spinbox := SpinBox.new()
			spinbox.editable = editable
			spinbox.custom_minimum_size = Vector2(50, 0)
			if value is float:
				spinbox.step = 0.1
				spinbox.rounded = false
			# apply config hints (min/max/step) from mod.cfg
			var hints: Dictionary = info.config_hints.get(key, {})
			if hints.has("min"):
				spinbox.min_value = hints["min"]
			if hints.has("max"):
				spinbox.max_value = hints["max"]
			else:
				spinbox.max_value = 10000
			if hints.has("step"):
				spinbox.step = hints["step"]
			spinbox.value = value
			spinbox.set_meta("config_control", true)
			row.add_child(spinbox)
		else:
			var line_edit := LineEdit.new()
			line_edit.text = str(value)
			line_edit.editable = editable
			line_edit.custom_minimum_size = Vector2(80, 0)
			line_edit.set_meta("config_control", true)
			row.add_child(line_edit)

		%ConfigList.add_child(row)


func _on_save_config() -> void:
	get_viewport().gui_release_focus()
	if selected_mod_id == "":
		return

	var info = ModLoader.mods[selected_mod_id]
	var new_config: Dictionary = {}

	for row in %ConfigList.get_children():
		if not row.has_meta("config_key"):
			continue
		var key: String = row.get_meta("config_key")
		for child in row.get_children():
			if child.has_meta("config_control"):
				if child is CheckButton:
					new_config[key] = child.button_pressed
				elif child is SpinBox:
					new_config[key] = child.value
				elif child is LineEdit:
					# Try to preserve original type
					var original = info.config.get(key)
					if original is int:
						new_config[key] = int(child.text)
					elif original is float:
						new_config[key] = float(child.text)
					else:
						new_config[key] = child.text

	# Write override file next to the PCK
	var override_path: String = String(ModLoader._mods_dir_path).path_join("%s.cfg" % selected_mod_id)
	var cfg := ConfigFile.new()

	# Preserve existing non-config sections
	cfg.load(override_path)

	for key in new_config:
		cfg.set_value("config", key, new_config[key])

	cfg.save(override_path)

	# Update in-memory config
	for key in new_config:
		info.config[key] = new_config[key]

	# Notify the mod if it has a config change handler
	if info.instance and info.instance.has_method("_on_config_changed"):
		info.instance._on_config_changed(new_config)

	ModLoader.emit_hook("config_changed", [selected_mod_id, new_config])
	config_changed.emit()

	if %SoundBoard:
		%SoundBoard.play_accept_sound()


func _on_mod_toggled(enabled: bool, mod_id: String) -> void:
	_set_mod_disabled_by_user(mod_id, not enabled)

	if %SoundBoard:
		%SoundBoard.play_select_sound()


func _is_mod_disabled_by_user(mod_id: String) -> bool:
	var disabled_path: String = String(ModLoader._mods_dir_path).path_join("disabled_mods.cfg")
	var cfg := ConfigFile.new()
	if cfg.load(disabled_path) != OK:
		return false
	return cfg.get_value("disabled", mod_id, false)


func _set_mod_disabled_by_user(mod_id: String, disabled: bool) -> void:
	var disabled_path: String = String(ModLoader._mods_dir_path).path_join("disabled_mods.cfg")
	var cfg := ConfigFile.new()
	cfg.load(disabled_path)
	if disabled:
		cfg.set_value("disabled", mod_id, true)
	else:
		if cfg.has_section_key("disabled", mod_id):
			cfg.set_value("disabled", mod_id, false)
	cfg.save(disabled_path)

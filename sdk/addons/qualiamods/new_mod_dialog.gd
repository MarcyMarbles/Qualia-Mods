@tool
extends AcceptDialog

signal mod_created(mod_id: String)

var _id_edit: LineEdit
var _name_edit: LineEdit
var _author_edit: LineEdit
var _version_edit: LineEdit
var _description_edit: TextEdit
var _game_version_edit: LineEdit
var _load_order_spin: SpinBox
var _lang_check: CheckButton
var _error_label: Label


func _init() -> void:
	title = "New QualiaMod"
	ok_button_text = "Create"
	min_size = Vector2i(400, 0)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	add_child(vbox)

	_id_edit = _add_field(vbox, "Mod ID", "mymod")
	_name_edit = _add_field(vbox, "Display Name", "My Mod")
	_author_edit = _add_field(vbox, "Author", "")
	_version_edit = _add_field(vbox, "Version", "1.0.0")
	_game_version_edit = _add_field(vbox, "Game Version", "")

	# description
	var desc_label := Label.new()
	desc_label.text = "Description"
	vbox.add_child(desc_label)
	_description_edit = TextEdit.new()
	_description_edit.custom_minimum_size = Vector2(0, 60)
	_description_edit.placeholder_text = "What does your mod do?"
	vbox.add_child(_description_edit)

	# load order
	var order_row := HBoxContainer.new()
	vbox.add_child(order_row)
	var order_label := Label.new()
	order_label.text = "Load Order"
	order_label.custom_minimum_size = Vector2(120, 0)
	order_row.add_child(order_label)
	_load_order_spin = SpinBox.new()
	_load_order_spin.min_value = -100
	_load_order_spin.max_value = 1000
	_load_order_spin.value = 0
	_load_order_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	order_row.add_child(_load_order_spin)

	# lang checkbox
	var lang_row := HBoxContainer.new()
	vbox.add_child(lang_row)
	var lang_label := Label.new()
	lang_label.text = "Include lang/ folder"
	lang_label.custom_minimum_size = Vector2(120, 0)
	lang_row.add_child(lang_label)
	_lang_check = CheckButton.new()
	_lang_check.button_pressed = false
	lang_row.add_child(_lang_check)

	# error label
	_error_label = Label.new()
	_error_label.add_theme_color_override("font_color", Color.RED)
	_error_label.visible = false
	vbox.add_child(_error_label)

	confirmed.connect(_on_confirmed)


func _add_field(parent: VBoxContainer, label_text: String, placeholder: String) -> LineEdit:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(120, 0)
	row.add_child(label)
	var edit := LineEdit.new()
	edit.placeholder_text = placeholder
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(edit)
	return edit


func _on_confirmed() -> void:
	var mod_id := _id_edit.text.strip_edges().to_lower().replace(" ", "_")
	if mod_id == "":
		_show_error("Mod ID cannot be empty")
		return

	# validate mod_id characters
	for c in mod_id:
		if not (c >= "a" and c <= "z") and not (c >= "0" and c <= "9") and c != "_":
			_show_error("Mod ID can only contain a-z, 0-9, _")
			return

	var mod_dir := "res://mods/%s" % mod_id
	if DirAccess.dir_exists_absolute(mod_dir):
		_show_error("Directory already exists: mods/%s" % mod_id)
		return

	# create directory
	DirAccess.make_dir_recursive_absolute(mod_dir)

	# generate mod.cfg
	var cfg := ConfigFile.new()
	cfg.set_value("mod", "api_version", "1.0")
	cfg.set_value("mod", "name", _name_edit.text if _name_edit.text != "" else mod_id)
	cfg.set_value("mod", "version", _version_edit.text if _version_edit.text != "" else "1.0.0")
	cfg.set_value("mod", "author", _author_edit.text if _author_edit.text != "" else "Unknown")
	cfg.set_value("mod", "description", _description_edit.text)
	cfg.set_value("mod", "game_version", _game_version_edit.text)
	cfg.set_value("mod", "load_order", int(_load_order_spin.value))
	cfg.save(mod_dir.path_join("mod.cfg"))

	# generate mod_main.gd
	var script_content := MOD_MAIN_TEMPLATE.replace("{{MOD_ID}}", mod_id)
	var f := FileAccess.open(mod_dir.path_join("mod_main.gd"), FileAccess.WRITE)
	if f:
		f.store_string(script_content)
		f.close()

	# optional lang/ folder
	if _lang_check.button_pressed:
		DirAccess.make_dir_recursive_absolute(mod_dir.path_join("lang"))
		var lang_cfg := ConfigFile.new()
		lang_cfg.set_value("meta", "displayName", "")
		lang_cfg.set_value("meta", "locale", "")
		lang_cfg.save(mod_dir.path_join("lang/template.cfg"))

	_error_label.visible = false
	mod_created.emit(mod_id)
	print("[QualiaMods Plugin] Scaffolded mod: %s at %s" % [mod_id, mod_dir])


func _show_error(msg: String) -> void:
	_error_label.text = msg
	_error_label.visible = true
	# re-show the dialog since confirmed closes it
	popup_centered()


const MOD_MAIN_TEMPLATE := \
"""extends Node

const MOD_ID := "{{MOD_ID}}"

var config: Dictionary


func _init_mod(cfg: Dictionary) -> void:
	config = cfg
	ModLoader.log_mod(MOD_ID, "Initialized")


func _game_ready() -> void:
	pass


func _on_config_changed(new_config: Dictionary) -> void:
	config = new_config


func _mod_cleanup() -> void:
	pass
"""

@tool
extends AcceptDialog

## Pack Mod dialog — select a mod from res://mods/ and pack it into .pck.

var _mod_list: ItemList
var _output_label: Label
var _mods: Array[String] = []


func _init() -> void:
	title = "Pack Mod"
	ok_button_text = "Pack"
	min_size = Vector2i(350, 300)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	add_child(vbox)

	var hint := Label.new()
	hint.text = "Select a mod to pack into .pck:"
	vbox.add_child(hint)

	_mod_list = ItemList.new()
	_mod_list.custom_minimum_size = Vector2(0, 180)
	_mod_list.auto_height = false
	vbox.add_child(_mod_list)

	_output_label = Label.new()
	_output_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_output_label.modulate = Color(1, 1, 1, 0.7)
	vbox.add_child(_output_label)

	confirmed.connect(_on_confirmed)
	about_to_popup.connect(_refresh_mod_list)


func _refresh_mod_list() -> void:
	_mod_list.clear()
	_mods.clear()
	_output_label.text = ""

	var dir := DirAccess.open("res://mods")
	if not dir:
		_output_label.text = "res://mods/ not found"
		return

	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir() and not entry.begins_with(".") \
				and not entry.begins_with("_") and entry != "qualiamods":
			if FileAccess.file_exists("res://mods/%s/mod.cfg" % entry):
				_mods.append(entry)
				_mod_list.add_item(entry)
		entry = dir.get_next()

	if _mods.is_empty():
		_output_label.text = "No mods found in res://mods/"


func _on_confirmed() -> void:
	var selected := _mod_list.get_selected_items()
	if selected.is_empty():
		_output_label.text = "Select a mod first"
		popup_centered()
		return

	var mod_id: String = _mods[selected[0]]
	_pack_mod(mod_id)


func _pack_mod(mod_id: String) -> void:
	var mod_dir := "res://mods/%s" % mod_id
	var files: Array[String] = []
	_scan_dir(mod_dir, files)

	if files.is_empty():
		_show_result("No files found in %s" % mod_dir, true)
		return

	var output_path := ProjectSettings.globalize_path("res://").path_join("%s.pck" % mod_id)

	var packer := PCKPacker.new()
	var err := packer.pck_start(output_path)
	if err != OK:
		_show_result("Failed to start packer: %s" % error_string(err), true)
		return

	var remap_count := 0
	var gd_count := 0

	for file_path in files:
		err = packer.add_file(file_path, file_path)
		if err != OK:
			_show_result("Failed to add %s: %s" % [file_path, error_string(err)], true)
			return

		# .gd files need .remap overrides
		if file_path.ends_with(".gd"):
			gd_count += 1
			var remap_content := '[remap]\n\npath="%s"\ntype="GDScript"\n' % file_path
			var tmp := "user://temp_remap_%d.txt" % gd_count
			var f := FileAccess.open(tmp, FileAccess.WRITE)
			if f:
				f.store_string(remap_content)
				f.close()
				err = packer.add_file(file_path + ".remap", tmp)
				if err == OK:
					remap_count += 1
				DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))

	err = packer.flush()
	if err != OK:
		_show_result("Flush failed: %s" % error_string(err), true)
		return

	_show_result("Packed %s → %s\n%d files + %d remaps" % [
		mod_id, output_path, files.size(), remap_count
	], false)


func _show_result(message: String, is_error: bool) -> void:
	if is_error:
		printerr("[QualiaMods Pack] %s" % message)
	else:
		print("[QualiaMods Pack] %s" % message)

	var dialog := AcceptDialog.new()
	dialog.title = "Pack Error" if is_error else "Pack Complete"
	dialog.dialog_text = message
	EditorInterface.get_base_control().add_child(dialog)
	dialog.popup_centered()


func _scan_dir(path: String, result: Array[String]) -> void:
	var dir := DirAccess.open(path)
	if not dir:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry.begins_with("."):
			entry = dir.get_next()
			continue
		var full_path := path.path_join(entry)
		if dir.current_is_dir():
			_scan_dir(full_path, result)
		elif not entry.ends_with(".uid") and not entry.ends_with(".import"):
			result.append(full_path)
		entry = dir.get_next()

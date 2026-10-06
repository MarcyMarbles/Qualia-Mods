@tool
extends AcceptDialog

const FILTER_HL := Color(1, 0.85, 0.4)

var _tree: Tree
var _search_edit: LineEdit
var _name_edit: LineEdit
var _output_label: Label
var _dir_paths: Dictionary = {}
var _last_item: TreeItem
var _updating: bool = false


func _init() -> void:
	title = "Pack Mod"
	ok_button_text = "Pack"
	min_size = Vector2i(480, 600)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	add_child(vbox)

	var hint := Label.new()
	hint.text = "Check the files/folders to pack:"
	vbox.add_child(hint)

	_search_edit = LineEdit.new()
	_search_edit.placeholder_text = "Filter files..."
	_search_edit.clear_button_enabled = true
	_search_edit.text_changed.connect(_apply_filter)
	vbox.add_child(_search_edit)

	_tree = Tree.new()
	_tree.columns = 1
	_tree.hide_root = true
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.item_edited.connect(_on_item_edited)
	vbox.add_child(_tree)

	var row := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = "Output name:"
	row.add_child(name_label)
	_name_edit = LineEdit.new()
	_name_edit.text = "mod"
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_name_edit)
	vbox.add_child(row)

	_output_label = Label.new()
	_output_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_output_label.modulate = Color(1, 1, 1, 0.7)
	vbox.add_child(_output_label)

	confirmed.connect(_on_confirmed)
	about_to_popup.connect(_refresh_tree)


func _refresh_tree() -> void:
	_tree.clear()
	_dir_paths.clear()
	_last_item = null
	_output_label.text = ""
	var root := _tree.create_item()
	_add_dir(root, "res://")
	_apply_filter(_search_edit.text)
	_sync_output()


func _add_dir(parent: TreeItem, dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if not dir:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not entry.begins_with("."):
			var res_path := dir_path.path_join(entry)
			if dir.current_is_dir():
				_add_dir(_make_item(parent, entry, res_path, true), res_path)
			elif not entry.ends_with(".uid"):
				_make_item(parent, entry, res_path, false)
		entry = dir.get_next()


func _apply_filter(query: String) -> void:
	var q := query.to_lower().strip_edges()
	var root := _tree.get_root()
	if root == null:
		return
	var child := root.get_first_child()
	while child:
		if q == "":
			_show_subtree(child)
		else:
			_filter_item(child, q)
		child = child.get_next()
	if q == "" and _last_item != null and is_instance_valid(_last_item):
		_reveal(_last_item)


func _filter_item(item: TreeItem, q: String) -> bool:
	if item.get_text(0).to_lower().contains(q):
		_show_subtree(item)
		item.set_custom_color(0, FILTER_HL)
		return true
	var child_match := false
	var child := item.get_first_child()
	while child:
		if _filter_item(child, q):
			child_match = true
		child = child.get_next()
	item.visible = child_match
	item.clear_custom_color(0)
	if child_match and _dir_paths.has(item.get_metadata(0)):
		item.collapsed = false
	return child_match


func _show_subtree(item: TreeItem) -> void:
	item.visible = true
	item.clear_custom_color(0)
	var child := item.get_first_child()
	while child:
		_show_subtree(child)
		child = child.get_next()


func _reveal(item: TreeItem) -> void:
	var parent := item.get_parent()
	while parent:
		parent.collapsed = false
		parent = parent.get_parent()
	item.visible = true
	_tree.scroll_to_item(item)


func _make_item(parent: TreeItem, name: String, res_path: String, is_dir: bool) -> TreeItem:
	var item := _tree.create_item(parent)
	item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
	item.set_text(0, name)
	item.set_metadata(0, res_path)
	item.set_editable(0, true)
	item.set_checked(0, false)
	if is_dir:
		item.collapsed = true
		_dir_paths[res_path] = true
	return item


func _on_item_edited() -> void:
	if _updating:
		return
	var item := _tree.get_edited()
	if item == null:
		return
	_last_item = item
	_updating = true
	item.set_indeterminate(0, false)
	item.propagate_check(0, false)
	_update_ancestors(item.get_parent())
	_updating = false
	_sync_output()


func _update_ancestors(item: TreeItem) -> void:
	while item:
		if item.get_first_child() != null:
			var checked := 0
			var total := 0
			var child := item.get_first_child()
			while child:
				total += 1
				if child.is_checked(0) and not child.is_indeterminate(0):
					checked += 1
				child = child.get_next()
			item.set_checked(0, checked == total)
			item.set_indeterminate(0, checked > 0 and checked < total)
		item = item.get_parent()


func _on_confirmed() -> void:
	var files := _collect_selected()
	if files.is_empty():
		_output_label.text = "Select at least one file"
		popup_centered()
		return

	var ids := _mod_ids_in(files)
	if ids.size() > 1:
		_output_label.text = "Select a single mod — found: %s" % ", ".join(ids)
		popup_centered()
		return

	var pck_name: String = ids[0] if ids.size() == 1 else _name_edit.text.strip_edges()
	if pck_name == "":
		pck_name = "mod"
	_pack_files(pck_name, files)


func _collect_selected() -> Array[String]:
	var files: Array[String] = []
	var seen: Dictionary = {}
	var root := _tree.get_root()
	if root:
		var child := root.get_first_child()
		while child:
			_gather(child, files, seen)
			child = child.get_next()
	return files


func _mod_ids_in(files: Array[String]) -> Array[String]:
	var ids: Array[String] = []
	for file_path in files:
		var parts := file_path.trim_prefix("res://").split("/")
		if parts.size() >= 2 and parts[0] == "mods" and parts[1] != "qualiamods":
			if not ids.has(parts[1]):
				ids.append(parts[1])
	return ids


func _sync_output() -> void:
	var ids := _mod_ids_in(_collect_selected())
	if ids.size() == 1:
		_name_edit.text = ids[0]
		_name_edit.editable = false
		_name_edit.tooltip_text = "Taken from the selected mod folder"
	else:
		_name_edit.editable = true
		_name_edit.tooltip_text = ""


func _gather(item: TreeItem, files: Array[String], seen: Dictionary) -> void:
	if item.is_checked(0):
		_add_subtree(item, files, seen)
		return
	var child := item.get_first_child()
	while child:
		_gather(child, files, seen)
		child = child.get_next()


func _add_subtree(item: TreeItem, files: Array[String], seen: Dictionary) -> void:
	if item.get_first_child() == null:
		var path: String = str(item.get_metadata(0))
		if path != "" and not seen.has(path):
			seen[path] = true
			files.append(path)
		return
	var child := item.get_first_child()
	while child:
		_add_subtree(child, files, seen)
		child = child.get_next()


func _pack_files(name: String, files: Array[String]) -> void:
	var output_path := ProjectSettings.globalize_path("res://").path_join("%s.pck" % name)

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

		var remap := ""
		if file_path.ends_with(".gd"):
			remap = '[remap]\n\npath="%s"\ntype="GDScript"\n' % file_path
		elif file_path.ends_with(".tscn") or file_path.ends_with(".tres"):
			remap = '[remap]\n\npath="%s"\n' % file_path
		if remap != "":
			gd_count += 1
			var tmp := "user://temp_remap_%d.txt" % gd_count
			var f := FileAccess.open(tmp, FileAccess.WRITE)
			if f:
				f.store_string(remap)
				f.close()
				err = packer.add_file(file_path + ".remap", tmp)
				if err == OK:
					remap_count += 1
				DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
		elif file_path.ends_with(".import"):
			_pack_import(packer, file_path)

	err = packer.flush()
	if err != OK:
		_show_result("Flush failed: %s" % error_string(err), true)
		return

	_show_result("Packed %d files + %d remaps → %s" % [files.size(), remap_count, output_path], false)


func _pack_import(packer: PCKPacker, import_path: String) -> void:
	var cfg := ConfigFile.new()
	if cfg.load(import_path) != OK:
		return
	var deps: Array = cfg.get_value("deps", "dest_files", [])
	var primary := str(cfg.get_value("remap", "path", ""))
	if primary != "" and not deps.has(primary):
		deps.append(primary)
	for dep in deps:
		var path := str(dep)
		if path != "" and FileAccess.file_exists(path):
			packer.add_file(path, path)


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

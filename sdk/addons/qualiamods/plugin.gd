@tool
extends EditorPlugin

var _new_mod_button: Button
var _new_mod_dialog: AcceptDialog
var _cfg_dock: Control
var _poll_timer: float = 0.0
var _last_selected: String = ""


func _enter_tree() -> void:
	# toolbar button
	_new_mod_button = Button.new()
	_new_mod_button.text = "New Mod"
	_new_mod_button.pressed.connect(_on_new_mod_pressed)
	add_control_to_container(CONTAINER_TOOLBAR, _new_mod_button)

	# cfg editor dock (right side, tabbed with Inspector/Node/History area)
	_cfg_dock = preload("res://addons/qualiamods/mod_cfg_dock.gd").new()
	_cfg_dock.name = "CFG Editor"
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _cfg_dock)

	set_process(true)
	print("[QualiaMods Plugin] Loaded")


func _exit_tree() -> void:
	if _new_mod_button:
		remove_control_from_container(CONTAINER_TOOLBAR, _new_mod_button)
		_new_mod_button.queue_free()
		_new_mod_button = null

	if _new_mod_dialog and is_instance_valid(_new_mod_dialog):
		_new_mod_dialog.queue_free()
		_new_mod_dialog = null

	if _cfg_dock:
		remove_control_from_docks(_cfg_dock)
		_cfg_dock.queue_free()
		_cfg_dock = null


func _process(delta: float) -> void:
	_poll_timer += delta
	if _poll_timer < 0.5:
		return
	_poll_timer = 0.0

	# check if a .cfg file is selected
	var path: String = EditorInterface.get_current_path()
	if path != _last_selected and path.ends_with(".cfg"):
		_last_selected = path
		if _cfg_dock:
			_cfg_dock.load_cfg(path)


func _on_new_mod_pressed() -> void:
	if not _new_mod_dialog or not is_instance_valid(_new_mod_dialog):
		_new_mod_dialog = preload("res://addons/qualiamods/new_mod_dialog.gd").new()
		_new_mod_dialog.mod_created.connect(_on_mod_created)
		EditorInterface.get_base_control().add_child(_new_mod_dialog)
	_new_mod_dialog.popup_centered()


func _on_mod_created(mod_id: String) -> void:
	EditorInterface.get_resource_filesystem().scan()
	print("[QualiaMods Plugin] Created mod: %s" % mod_id)

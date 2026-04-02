@tool
extends EditorPlugin

var _new_mod_button: Button
var _pack_button: Button
var _hooks_button: Button
var _setup_button: Button
var _new_mod_dialog: AcceptDialog
var _pack_dialog: AcceptDialog
var _hooks_dialog: AcceptDialog
var _cfg_dock: Control
var _installer: Node
var _poll_timer: float = 0.0
var _last_selected: String = ""


func _enter_tree() -> void:
	if _is_framework_installed():
		_show_mod_tools()
	else:
		_show_setup_button()

	set_process(true)
	print("[QualiaMods Plugin] Loaded")


func _exit_tree() -> void:
	for btn in [_new_mod_button, _pack_button, _hooks_button, _setup_button]:
		if btn:
			remove_control_from_container(CONTAINER_TOOLBAR, btn)
			btn.queue_free()
	_new_mod_button = null
	_pack_button = null
	_hooks_button = null
	_setup_button = null

	for dlg in [_new_mod_dialog, _pack_dialog, _hooks_dialog]:
		if dlg and is_instance_valid(dlg):
			dlg.queue_free()
	_new_mod_dialog = null
	_pack_dialog = null
	_hooks_dialog = null

	if _cfg_dock:
		remove_control_from_docks(_cfg_dock)
		_cfg_dock.queue_free()
		_cfg_dock = null

	if _installer and is_instance_valid(_installer):
		_installer.queue_free()
		_installer = null


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


# ── Framework detection ──────────────────────────────────────────

func _is_framework_installed() -> bool:
	return FileAccess.file_exists("res://mods/qualiamods/qualiamods.gd")


# ── Setup mode (framework not installed) ─────────────────────────

func _show_setup_button() -> void:
	_setup_button = Button.new()
	_setup_button.text = "Setup QualiaMods"
	_setup_button.tooltip_text = "Download and install QualiaMods framework into this project"
	_setup_button.pressed.connect(_on_setup_pressed)
	add_control_to_container(CONTAINER_TOOLBAR, _setup_button)


func _on_setup_pressed() -> void:
	_setup_button.disabled = true
	_setup_button.text = "Installing..."

	var installer_script = load("res://addons/qualiamods/installer.gd")
	_installer = installer_script.new()
	add_child(_installer)

	_installer.install_progress.connect(func(step: String):
		_setup_button.text = step
	)
	_installer.install_finished.connect(_on_install_finished)
	_installer.start_install()


func _on_install_finished(success: bool, message: String) -> void:
	if _installer:
		_installer.queue_free()
		_installer = null

	if success:
		print("[QualiaMods Plugin] %s" % message)
		if _setup_button:
			remove_control_from_container(CONTAINER_TOOLBAR, _setup_button)
			_setup_button.queue_free()
			_setup_button = null
		_show_mod_tools()

		var dialog := AcceptDialog.new()
		dialog.title = "QualiaMods Installed"
		dialog.dialog_text = message + "\n\nPlease reload the project (Project → Reload Current Project)."
		EditorInterface.get_base_control().add_child(dialog)
		dialog.popup_centered()
	else:
		printerr("[QualiaMods Plugin] Install failed: %s" % message)
		_setup_button.text = "Setup QualiaMods (retry)"
		_setup_button.disabled = false


# ── Mod tools mode (framework installed) ─────────────────────────

func _show_mod_tools() -> void:
	# New Mod button
	_new_mod_button = Button.new()
	_new_mod_button.text = "New Mod"
	_new_mod_button.tooltip_text = "Create a new mod from template"
	_new_mod_button.pressed.connect(_on_new_mod_pressed)
	add_control_to_container(CONTAINER_TOOLBAR, _new_mod_button)

	# Pack Mod button
	_pack_button = Button.new()
	_pack_button.text = "Pack Mod"
	_pack_button.tooltip_text = "Pack a mod into .pck for distribution"
	_pack_button.pressed.connect(_on_pack_pressed)
	add_control_to_container(CONTAINER_TOOLBAR, _pack_button)

	# Hooks Browser button
	_hooks_button = Button.new()
	_hooks_button.text = "Hooks"
	_hooks_button.tooltip_text = "Browse available hooks and insert into your script"
	_hooks_button.pressed.connect(_on_hooks_pressed)
	add_control_to_container(CONTAINER_TOOLBAR, _hooks_button)

	# CFG editor dock
	_cfg_dock = preload("res://addons/qualiamods/mod_cfg_dock.gd").new()
	_cfg_dock.name = "CFG Editor"
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _cfg_dock)


func _on_new_mod_pressed() -> void:
	if not _new_mod_dialog or not is_instance_valid(_new_mod_dialog):
		_new_mod_dialog = preload("res://addons/qualiamods/new_mod_dialog.gd").new()
		_new_mod_dialog.mod_created.connect(_on_mod_created)
		EditorInterface.get_base_control().add_child(_new_mod_dialog)
	_new_mod_dialog.popup_centered()


func _on_mod_created(mod_id: String) -> void:
	EditorInterface.get_resource_filesystem().scan()
	print("[QualiaMods Plugin] Created mod: %s" % mod_id)


func _on_pack_pressed() -> void:
	if not _pack_dialog or not is_instance_valid(_pack_dialog):
		_pack_dialog = preload("res://addons/qualiamods/pack_dialog.gd").new()
		EditorInterface.get_base_control().add_child(_pack_dialog)
	_pack_dialog.popup_centered()


func _on_hooks_pressed() -> void:
	if not _hooks_dialog or not is_instance_valid(_hooks_dialog):
		_hooks_dialog = preload("res://addons/qualiamods/hooks_dialog.gd").new()
		EditorInterface.get_base_control().add_child(_hooks_dialog)
	_hooks_dialog.popup_centered()

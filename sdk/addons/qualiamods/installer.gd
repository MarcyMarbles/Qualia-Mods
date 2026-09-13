@tool
extends Node

## Downloads QualiaMods framework files from GitHub and installs them
## into the game project. Called from the editor plugin.

signal install_finished(success: bool, message: String)
signal install_progress(step: String)

const REPO_BASE := "https://raw.githubusercontent.com/MarcyMarbles/Qualia-Mods/dev-experience"

# source path in repo → target path in project
const FRAMEWORK_FILES: Dictionary = {
	"framework/qualiamods.gd":
		"res://mods/qualiamods/qualiamods.gd",
	"sdk/template/mod_base.gd":
		"res://mods/qualiamods/mod_base.gd",
	"framework/ref.gd":
		"res://main/autoload/ref.gd",
	"framework/mods_menu.gd":
		"res://main/ui/menu/mods_menu/mods_menu.gd",
	"framework/mods_menu.tscn":
		"res://main/ui/menu/mods_menu/mods_menu.tscn",
	"framework/i18n/i18n_manager.gd":
		"res://mods/qualiamods/i18n/i18n_manager.gd",
	"framework/i18n/translation_loader.gd":
		"res://mods/qualiamods/i18n/translation_loader.gd",
	"framework/i18n/language_menu.gd":
		"res://mods/qualiamods/i18n/language_menu.gd",
}

# files that replace existing game files — back up originals
const BACKUP_FILES: Array[String] = [
	"res://main/autoload/ref.gd",
]

var _http: HTTPRequest
var _queue: Array[Dictionary] = []  # [{source, target}]
var _errors: Array[String] = []
var _total: int = 0


func start_install() -> void:
	_errors.clear()
	_queue.clear()

	# build download queue
	for source in FRAMEWORK_FILES:
		_queue.append({
			"source": source,
			"target": FRAMEWORK_FILES[source],
		})
	_total = _queue.size()

	# ensure directories exist
	_ensure_dirs()

	# backup original files
	_backup_originals()

	# start downloading
	_http = HTTPRequest.new()
	_http.timeout = 15.0
	add_child(_http)

	_download_next()


func is_installed() -> bool:
	return FileAccess.file_exists("res://mods/qualiamods/qualiamods.gd")


func _ensure_dirs() -> void:
	var dirs: Array[String] = [
		"res://mods",
		"res://mods/qualiamods",
		"res://mods/qualiamods/i18n",
		"res://main/ui/menu/mods_menu",
	]
	for dir_path in dirs:
		if not DirAccess.dir_exists_absolute(dir_path):
			DirAccess.make_dir_recursive_absolute(dir_path)


func _backup_originals() -> void:
	for file_path in BACKUP_FILES:
		var backup_path := file_path + ".backup"
		if FileAccess.file_exists(file_path) and not FileAccess.file_exists(backup_path):
			var content := FileAccess.get_file_as_bytes(file_path)
			var f := FileAccess.open(backup_path, FileAccess.WRITE)
			if f:
				f.store_buffer(content)
				f.close()
				print("[QualiaMods Installer] Backed up: %s" % file_path)


func _download_next() -> void:
	if _queue.is_empty():
		_finish()
		return

	var item: Dictionary = _queue.pop_front()
	var url := "%s/%s" % [REPO_BASE, item["source"]]
	var target: String = item["target"]
	var step_num := _total - _queue.size()

	install_progress.emit("(%d/%d) %s" % [step_num, _total, item["source"].get_file()])
	print("[QualiaMods Installer] Downloading: %s" % url)

	_http.request_completed.connect(
		_on_download_complete.bind(target), CONNECT_ONE_SHOT
	)
	var err := _http.request(url)
	if err != OK:
		_errors.append("HTTP request failed for %s: %s" % [item["source"], error_string(err)])
		_download_next()


func _on_download_complete(result: int, code: int, _headers: PackedStringArray,
		body: PackedByteArray, target_path: String) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_errors.append("Failed to download → %s (HTTP %d)" % [target_path, code])
		_download_next()
		return

	var f := FileAccess.open(target_path, FileAccess.WRITE)
	if not f:
		_errors.append("Cannot write: %s" % target_path)
		_download_next()
		return

	f.store_buffer(body)
	f.close()
	print("[QualiaMods Installer] Installed: %s" % target_path)

	_download_next()


func _finish() -> void:
	if _http:
		_http.queue_free()
		_http = null

	if _errors.is_empty():
		install_finished.emit(true, "Framework installed! %d files. Reload project to apply." % _total)
	else:
		install_finished.emit(false, "%d error(s):\n%s" % [_errors.size(), "\n".join(_errors)])

	EditorInterface.get_resource_filesystem().scan()

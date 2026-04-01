extends SceneTree

## Packs QualiaMods into .pck from the game project context.
##
## For .gd files: packs source + creates .gd.remap override so the game
## loads our .gd instead of its compiled .gdc.
##
## For imported resources (.tscn, .png, .ttf, .tres, etc.): reads the
## .import file to find the compiled path in .godot/imported/ and packs
## both the .import file and the compiled resource.
##
## Run from the game project:
##   godot --headless --script res://pack_qualiamods.gd

# Files to pack explicitly
const MOD_FILES: Array[String] = [
	"res://main/autoload/ref.gd",
	"res://mods/qualiamods/qualiamods.gd",
	"res://mods/qualiamods/i18n/i18n_manager.gd",
	"res://mods/qualiamods/i18n/translation_loader.gd",
	"res://mods/qualiamods/i18n/language_menu.gd",
	"res://main/ui/menu/mods_menu/mods_menu.gd",
	"res://main/ui/menu/mods_menu/mods_menu.tscn",
]

# Directories to scan recursively for additional resources (fonts, textures, themes, etc.)
const SCAN_DIRS: Array[String] = [
	"res://mods/qualiamods/i18n",
]

# Extensions that need .gd.remap override
const GD_REMAP_TEMPLATE: String = '[remap]\n\npath="%s"\ntype="GDScript"\n'

var _packed_files: Dictionary = {}  # track what's already packed
var _file_count: int = 0
var _remap_count: int = 0
var _import_count: int = 0


func _init() -> void:
	var output_path: String = ProjectSettings.globalize_path("res://_000_qualiamods.pck")
	print("[PackQM] Output: %s" % output_path)

	var packer := PCKPacker.new()
	var err := packer.pck_start(output_path)
	if err != OK:
		printerr("[PackQM] Failed to start: %s" % error_string(err))
		quit(1)
		return

	# 1. Pack explicit file list
	for file_path in MOD_FILES:
		_pack_file(packer, file_path)

	# 2. Scan directories for extra resources
	for dir_path in SCAN_DIRS:
		_scan_dir(packer, dir_path)

	err = packer.flush()
	if err != OK:
		printerr("[PackQM] Flush failed")
		quit(1)
		return

	print("[PackQM] Done! %d files, %d remaps, %d imported resources" % [_file_count, _remap_count, _import_count])
	quit(0)


func _pack_file(packer: PCKPacker, file_path: String) -> void:
	if file_path in _packed_files:
		return
	_packed_files[file_path] = true

	var err := packer.add_file(file_path, file_path)
	if err != OK:
		printerr("[PackQM] FAIL %s: %s" % [file_path, error_string(err)])
		return
	_file_count += 1
	print("[PackQM] + %s" % file_path)

	if file_path.ends_with(".gd"):
		# .gd files: create remap override to prevent game from using .gdc
		_create_gd_remap(packer, file_path)
	else:
		# non-.gd files: check for .import and pack compiled resource
		_pack_imported_resource(packer, file_path)


func _create_gd_remap(packer: PCKPacker, gd_path: String) -> void:
	var remap_path := gd_path + ".remap"
	if remap_path in _packed_files:
		return
	_packed_files[remap_path] = true

	var remap_content := GD_REMAP_TEMPLATE % gd_path
	var tmp := "user://temp_remap.txt"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if not f:
		printerr("[PackQM] Could not create temp remap file")
		return
	f.store_string(remap_content)
	f.close()

	var err := packer.add_file(remap_path, tmp)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
	if err == OK:
		_remap_count += 1
		print("[PackQM] + %s (remap override)" % remap_path)
	else:
		printerr("[PackQM] FAIL remap %s" % remap_path)


func _pack_imported_resource(packer: PCKPacker, file_path: String) -> void:
	var import_path := file_path + ".import"

	if not FileAccess.file_exists(import_path):
		return

	# Pack the .import file itself
	if import_path not in _packed_files:
		_packed_files[import_path] = true
		var err := packer.add_file(import_path, import_path)
		if err == OK:
			print("[PackQM] + %s (.import)" % import_path)
		else:
			printerr("[PackQM] FAIL %s" % import_path)
			return

	# Parse .import to find compiled resource path
	var cfg := ConfigFile.new()
	if cfg.load(import_path) != OK:
		printerr("[PackQM] Failed to parse: %s" % import_path)
		return

	# Single compiled path
	var compiled_path: String = cfg.get_value("remap", "path", "")
	if compiled_path != "":
		_pack_compiled(packer, compiled_path)

	# Some imports have multiple dest files (e.g. textures with mipmaps)
	var dest_files = cfg.get_value("deps", "dest_files", [])
	for dest in dest_files:
		_pack_compiled(packer, str(dest))


func _pack_compiled(packer: PCKPacker, compiled_path: String) -> void:
	if compiled_path == "" or compiled_path in _packed_files:
		return
	if not FileAccess.file_exists(compiled_path):
		printerr("[PackQM] Compiled resource not found: %s" % compiled_path)
		return
	_packed_files[compiled_path] = true
	var err := packer.add_file(compiled_path, compiled_path)
	if err == OK:
		_import_count += 1
		print("[PackQM] + %s (compiled)" % compiled_path)
	else:
		printerr("[PackQM] FAIL compiled %s" % compiled_path)


func _scan_dir(packer: PCKPacker, dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if not dir:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var full_path := dir_path.path_join(entry)
		if dir.current_is_dir() and not entry.begins_with("."):
			_scan_dir(packer, full_path)
		elif not entry.ends_with(".import") and not entry.begins_with("."):
			# Skip .gd files already in MOD_FILES, and .uid files
			if not entry.ends_with(".uid"):
				_pack_file(packer, full_path)
		entry = dir.get_next()

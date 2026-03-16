extends SceneTree

## Universal mod packer - builds a .pck from any mod directory.
##
## Usage:
##   godot --headless --script res://sdk/pack_mod.gd -- <mod_id>
##
## Example:
##   godot --headless --script res://sdk/pack_mod.gd -- fogcontrol
##
## What it does:
##   1. Reads res://mods/<mod_id>/mod.cfg for the mod name
##   2. Recursively collects all files in res://mods/<mod_id>/
##   3. For each .gd file, generates a .gd.remap override
##      (so the game loads .gd source instead of compiled .gdc)
##   4. Outputs <mod_id>.pck next to the project root


const REMAP_TEMPLATE: String = '[remap]\n\npath="%s"\ntype="GDScript"\n'


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("[PackMod] Usage: godot --headless --script res://sdk/pack_mod.gd -- <mod_id>")
		printerr("[PackMod] Example: godot --headless --script res://sdk/pack_mod.gd -- fogcontrol")
		quit(1)
		return

	var mod_id: String = args[0].strip_edges()
	var mod_dir := "res://mods/%s" % mod_id

	if not DirAccess.dir_exists_absolute(mod_dir):
		printerr("[PackMod] Directory not found: %s" % mod_dir)
		quit(1)
		return

	# Collect all files recursively
	var files: Array[String] = []
	_scan_dir(mod_dir, files)

	if files.is_empty():
		printerr("[PackMod] No files found in %s" % mod_dir)
		quit(1)
		return

	# Output path
	var output_path := ProjectSettings.globalize_path("res://%s.pck" % mod_id)
	print("[PackMod] Packing '%s' -> %s" % [mod_id, output_path])

	var packer := PCKPacker.new()
	var err := packer.pck_start(output_path)
	if err != OK:
		printerr("[PackMod] Failed to start packer: %s" % error_string(err))
		quit(1)
		return

	var gd_count := 0
	var remap_count := 0

	for file_path in files:
		err = packer.add_file(file_path, file_path)
		if err != OK:
			printerr("[PackMod] FAIL %s: %s" % [file_path, error_string(err)])
			quit(1)
			return
		print("[PackMod] + %s" % file_path)

		# Generate .gd.remap for GDScript files
		if file_path.ends_with(".gd"):
			gd_count += 1
			var remap_path := file_path + ".remap"
			var remap_content := REMAP_TEMPLATE % file_path
			var remap_temp := "user://temp_remap_%d.txt" % gd_count
			var f := FileAccess.open(remap_temp, FileAccess.WRITE)
			if f:
				f.store_string(remap_content)
				f.close()
				err = packer.add_file(remap_path, remap_temp)
				if err == OK:
					print("[PackMod] + %s (remap)" % remap_path)
					remap_count += 1
				else:
					printerr("[PackMod] FAIL remap %s" % remap_path)
				DirAccess.remove_absolute(ProjectSettings.globalize_path(remap_temp))

	err = packer.flush()
	if err != OK:
		printerr("[PackMod] Flush failed: %s" % error_string(err))
		quit(1)
		return

	print("[PackMod] Done! %d files + %d remaps -> %s" % [files.size(), remap_count, output_path])
	quit(0)


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
		else:
			# Skip .uid files and .import files - they are editor-only
			if not entry.ends_with(".uid") and not entry.ends_with(".import"):
				result.append(full_path)
		entry = dir.get_next()

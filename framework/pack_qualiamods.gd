extends SceneTree

## Packs QualiaMods into .pck from the game project context.
## Includes .gd source files AND override .gd.remap files
## to prevent the game's remap from redirecting to old .gdc.
## Run from the game project:
##   godot --headless --script res://pack_qualiamods.gd

const MOD_FILES: Array[String] = [
	"res://main/autoload/ref.gd",
	"res://mods/qualiamods/qualiamods.gd",
	"res://main/ui/menu/mods_menu/mods_menu.gd",
	"res://main/ui/menu/mods_menu/mods_menu.tscn",
]

# Remap content that points back to .gd (source) instead of .gdc
const REMAP_TEMPLATE: String = '[remap]\n\npath="%s"\ntype="GDScript"\n'

func _init() -> void:
	# Output next to this project
	var output_path: String = ProjectSettings.globalize_path("res://_000_qualiamods.pck")
	print("[PackQM] Output: %s" % output_path)

	var packer := PCKPacker.new()
	var err := packer.pck_start(output_path)
	if err != OK:
		printerr("[PackQM] Failed to start: %s" % error_string(err))
		quit(1)
		return

	for file_path in MOD_FILES:
		# 1. Add the .gd source file
		err = packer.add_file(file_path, file_path)
		if err != OK:
			printerr("[PackQM] FAIL %s: %s" % [file_path, error_string(err)])
			quit(1)
			return
		print("[PackQM] + %s" % file_path)

		# 2. Create a .gd.remap that points to our .gd source
		#    This overrides the game's remap that would redirect to .gdc
		#    (only for .gd files, not .tscn)
		if not file_path.ends_with(".gd"):
			continue
		var remap_path := file_path + ".remap"
		var remap_content := REMAP_TEMPLATE % file_path
		var remap_temp := "user://temp_remap.txt"
		var f := FileAccess.open(remap_temp, FileAccess.WRITE)
		if f:
			f.store_string(remap_content)
			f.close()
			err = packer.add_file(remap_path, remap_temp)
			if err == OK:
				print("[PackQM] + %s (remap override)" % remap_path)
			else:
				printerr("[PackQM] FAIL remap %s" % remap_path)
			DirAccess.remove_absolute(ProjectSettings.globalize_path(remap_temp))
		else:
			printerr("[PackQM] Could not create temp remap file")

	err = packer.flush()
	if err != OK:
		printerr("[PackQM] Flush failed")
		quit(1)
		return

	print("[PackQM] Done! Packed %d files + %d remaps" % [MOD_FILES.size(), MOD_FILES.size()])
	quit(0)

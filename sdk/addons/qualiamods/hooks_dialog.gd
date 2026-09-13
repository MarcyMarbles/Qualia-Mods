@tool
extends AcceptDialog

## Hooks Browser — view available hooks and insert handler methods.

const HOOKS: Array[Dictionary] = [
	{
		"name": "world_loaded",
		"phase": "Game Lifecycle",
		"desc": "World finished loading. Terrain, entities, and structures are ready.",
	},
	{
		"name": "game_playable",
		"phase": "Game Lifecycle",
		"desc": "Player can move and interact. Safe to access Ref.player, modify gameplay.",
	},
	{
		"name": "game_quit",
		"phase": "Game Lifecycle",
		"desc": "Game is quitting. Last chance to save state or clean up.",
	},
	{
		"name": "all_loaded",
		"phase": "Game Lifecycle",
		"desc": "All resources (scenes, textures, etc.) finished loading.",
	},
	{
		"name": "new_game_loaded",
		"phase": "Game Lifecycle",
		"desc": "A new world was created (not loaded from save).",
	},
	{
		"name": "items_pre_load",
		"phase": "Item System",
		"desc": "Before ItemMap scans items. Register custom item paths here.",
	},
	{
		"name": "items_post_load",
		"phase": "Item System",
		"desc": "After ItemMap finishes loading all items. Safe to query items.",
	},
	{
		"name": "scene_injected",
		"phase": "Scene Tree",
		"desc": "Fired after inject_node() succeeds. Args: [parent_path, node].",
	},
	{
		"name": "config_changed",
		"phase": "Config",
		"desc": "User changed mod config in Mods Menu. Prefer _config_changed() override.",
	},
	{
		"name": "mods_all_ready",
		"phase": "Mod Lifecycle",
		"desc": "All mods initialized and _game_ready() called. Safe for inter-mod work.",
	},
]

var _hook_list: ItemList
var _desc_label: RichTextLabel
var _insert_btn: Button
var _current_phase: String = ""


func _init() -> void:
	title = "Hooks Browser"
	ok_button_text = "Close"
	min_size = Vector2i(480, 380)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(vbox)

	var hint := Label.new()
	hint.text = "Available hooks — select one to see details:"
	vbox.add_child(hint)

	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.dragger_visibility = SplitContainer.DRAGGER_VISIBLE
	vbox.add_child(split)

	_hook_list = ItemList.new()
	_hook_list.custom_minimum_size = Vector2(190, 0)
	_hook_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_hook_list.item_selected.connect(_on_hook_selected)
	split.add_child(_hook_list)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 4)
	split.add_child(right)

	_desc_label = RichTextLabel.new()
	_desc_label.bbcode_enabled = true
	_desc_label.fit_content = false
	_desc_label.scroll_following = true
	_desc_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(_desc_label)

	_insert_btn = Button.new()
	_insert_btn.text = "Insert into current script"
	_insert_btn.pressed.connect(_on_insert_pressed)
	_insert_btn.disabled = true
	right.add_child(_insert_btn)

	about_to_popup.connect(_populate)


func _populate() -> void:
	_hook_list.clear()
	_desc_label.text = ""
	_insert_btn.disabled = true

	var last_phase := ""
	for i in HOOKS.size():
		var hook: Dictionary = HOOKS[i]
		if hook["phase"] != last_phase:
			last_phase = hook["phase"]
			_hook_list.add_item("— %s —" % last_phase)
			_hook_list.set_item_disabled(_hook_list.item_count - 1, true)
			_hook_list.set_item_selectable(_hook_list.item_count - 1, false)

		_hook_list.add_item("  _on_%s" % hook["name"])
		_hook_list.set_item_metadata(_hook_list.item_count - 1, i)


func _on_hook_selected(idx: int) -> void:
	var meta = _hook_list.get_item_metadata(idx)
	if meta == null:
		return

	var hook: Dictionary = HOOKS[meta]
	_desc_label.text = ""
	_desc_label.append_text("[b]_on_%s()[/b]\n\n" % hook["name"])
	_desc_label.append_text("[color=gray]Phase:[/color] %s\n\n" % hook["phase"])
	_desc_label.append_text("%s\n\n" % hook["desc"])
	_desc_label.append_text("[color=gray]With ModBase, just define this method — it auto-subscribes.[/color]\n\n")
	_desc_label.append_text("[code]func _on_%s() -> void:\n    pass[/code]" % hook["name"])

	_insert_btn.disabled = false


func _on_insert_pressed() -> void:
	var selected := _hook_list.get_selected_items()
	if selected.is_empty():
		return

	var meta = _hook_list.get_item_metadata(selected[0])
	if meta == null:
		return

	var hook: Dictionary = HOOKS[meta]
	var snippet := "\n\nfunc _on_%s() -> void:\n\tpass\n" % hook["name"]

	var script_editor := EditorInterface.get_script_editor()
	if not script_editor:
		printerr("[QualiaMods] Script editor not available")
		return

	var current := script_editor.get_current_editor()
	if not current:
		printerr("[QualiaMods] No script open")
		return

	var code_edit: CodeEdit = current.get_base_editor()
	if not code_edit:
		printerr("[QualiaMods] Cannot access code editor")
		return

	# insert at the end of the file
	var line_count := code_edit.get_line_count()
	var last_line := code_edit.get_line(line_count - 1)
	code_edit.set_line(line_count - 1, last_line + snippet)

	# move cursor to the pass line
	code_edit.set_caret_line(line_count + 2)
	code_edit.set_caret_column(1)

	print("[QualiaMods] Inserted _on_%s() hook" % hook["name"])

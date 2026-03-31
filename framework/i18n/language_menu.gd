extends Control

## Language selection screen.
## Built in code — no .tscn needed.

signal exited

var _lang_buttons: Dictionary = {}  # locale -> Button
var _current_locale: String = ""


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var game_theme: Theme = load("res://main/ui/theme/theme.tres")

	# background
	var bg_tex := load("res://main/ui/backgrounds/wallpaper_home.jpg")
	var bg_mat := load("res://main/ui/backgrounds/background.tres")

	var bg := TextureRect.new()
	bg.modulate = Color(0.6, 0.65, 0.72, 1)
	if bg_mat:
		bg.material = bg_mat
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if bg_tex:
		bg.texture = bg_tex
	bg.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	if game_theme:
		bg.theme = game_theme
	add_child(bg)

	# margin
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 6)
	if game_theme:
		margin.theme = game_theme
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	# header
	var header := HBoxContainer.new()
	vbox.add_child(header)

	var title := Label.new()
	title.text = "language"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var back_btn := Button.new()
	back_btn.text = "back"
	var sound_script = load("res://main/ui/theme/sound_button.gd")
	if sound_script:
		back_btn.set_script(sound_script)
	back_btn.pressed.connect(func(): exited.emit())
	header.add_child(back_btn)

	# center the list
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(center)

	var list_panel := PanelContainer.new()
	list_panel.custom_minimum_size = Vector2(140, 0)
	center.add_child(list_panel)

	var list_margin := MarginContainer.new()
	list_margin.add_theme_constant_override("margin_left", 6)
	list_margin.add_theme_constant_override("margin_right", 6)
	list_margin.add_theme_constant_override("margin_top", 4)
	list_margin.add_theme_constant_override("margin_bottom", 4)
	list_panel.add_child(list_margin)

	var list_vbox := VBoxContainer.new()
	list_vbox.add_theme_constant_override("separation", 2)
	list_margin.add_child(list_vbox)

	_build_language_list(list_vbox, sound_script)

	# footer hint
	var hint := Label.new()
	hint.text = "restart may be needed for full effect"
	hint.modulate = Color(1, 1, 1, 0.4)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hint)


func _build_language_list(container: VBoxContainer, sound_script) -> void:
	_current_locale = ModLoader.get_locale()
	var locales: Array[String] = ModLoader.get_available_locales()

	for locale in locales:
		var display_name: String = ModLoader.get_locale_display_name(locale)

		var btn := Button.new()
		btn.text = display_name
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if sound_script:
			btn.set_script(sound_script)
		btn.pressed.connect(_on_locale_selected.bind(locale))

		if locale == _current_locale:
			btn.modulate = Color(1, 1, 1, 1)
		else:
			btn.modulate = Color(1, 1, 1, 0.6)

		container.add_child(btn)
		_lang_buttons[locale] = btn


func _on_locale_selected(locale: String) -> void:
	_current_locale = locale
	ModLoader.set_locale(locale)

	# update button highlights
	for l in _lang_buttons:
		if l == locale:
			_lang_buttons[l].modulate = Color(1, 1, 1, 1)
		else:
			_lang_buttons[l].modulate = Color(1, 1, 1, 0.6)


func open() -> void:
	visible = true
	process_mode = Node.PROCESS_MODE_ALWAYS


func close() -> void:
	visible = false


func activate() -> void:
	if has_method("set_process_input"):
		set_process_input(true)


func deactivate() -> void:
	if has_method("set_process_input"):
		set_process_input(false)

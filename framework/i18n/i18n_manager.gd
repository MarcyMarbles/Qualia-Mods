extends Node

## Manages runtime i18n for the game.
##
## Since the game hardcodes all strings (no tr() calls),
## we manually walk the scene tree and replace .text properties.
## For buttons with hover text changes, we connect to mouse signals
## and re-translate after the game's handler runs.

const TranslationLoader := preload("res://mods/qualiamods/i18n/translation_loader.gd")

var locale_names: Dictionary = {}
var available_locales: Array[String] = []

# locale -> { lowercase_key -> translated_string }
var _translations: Dictionary = {}

# track connected buttons to avoid double-connecting
var _connected_buttons: Dictionary = {}  # instance_id -> true

# original english text: instance_id -> { prop -> original_text }
var _originals: Dictionary = {}

var _current_locale: String = ""
var _game_dir: String
var _config_path: String


func _ready() -> void:
	_game_dir = OS.get_executable_path().get_base_dir()
	_config_path = _game_dir.path_join("lang").path_join("settings.cfg")
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)


func load_global_translations() -> void:
	var lang_dir := _game_dir.path_join("lang")
	_ensure_english_cfg(lang_dir)
	_scan_lang_dir(lang_dir, "global")


func _ensure_english_cfg(lang_dir: String) -> void:
	if not DirAccess.dir_exists_absolute(lang_dir):
		DirAccess.make_dir_recursive_absolute(lang_dir)

	var en_path := lang_dir.path_join("english.cfg")
	if FileAccess.file_exists(en_path):
		return

	var cfg := ConfigFile.new()
	cfg.set_value("meta", "displayName", "English")
	cfg.set_value("meta", "locale", "en")
	cfg.save(en_path)
	print("[i18n] Created default english.cfg")


func load_mod_translations(mod_ids: Array) -> void:
	for mod_id in mod_ids:
		_scan_lang_dir("res://mods/%s/lang" % mod_id, mod_id)


func _scan_lang_dir(lang_dir: String, source: String) -> void:
	if not DirAccess.dir_exists_absolute(lang_dir):
		return
	var dir := DirAccess.open(lang_dir)
	if not dir:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry.ends_with(".cfg") and entry != "settings.cfg":
			var data := TranslationLoader.load_cfg(lang_dir.path_join(entry))
			if data:
				_register_translation(data, source)
		entry = dir.get_next()
	available_locales.sort()
	print("[i18n] Available locales: %s" % str(available_locales))


func load_translation_file(path: String) -> void:
	var data := TranslationLoader.load_cfg(path)
	if data:
		_register_translation(data)


func _register_translation(data, source: String = "") -> void:
	var locale: String = data.translation_dict["__locale__"]
	if locale not in _translations:
		_translations[locale] = {}
	for key in data.translation_dict:
		if key != "__locale__":
			_translations[locale][key] = data.translation_dict[key]
	locale_names[locale] = data.display_name
	if locale not in available_locales:
		available_locales.append(locale)
	var src := " [%s]" % source if source != "" else ""
	print("[i18n] Registered: %s (%s)%s — %d strings" % [data.display_name, locale, src, data.translation_dict.size() - 1])


func set_locale(locale: String) -> void:
	_current_locale = locale
	_save_locale(locale)
	_retranslate_tree()
	print("[i18n] Locale set to: %s (%s)" % [locale, locale_names.get(locale, "?")])


func get_locale() -> String:
	return _current_locale if _current_locale != "" else "en"


func get_available_locales() -> Array[String]:
	return available_locales


func get_locale_display_name(locale: String) -> String:
	return locale_names.get(locale, locale)


func apply_saved_locale() -> void:
	var saved := _load_saved_locale()
	if saved != "" and saved in available_locales:
		_current_locale = saved
		print("[i18n] Restored saved locale: %s" % saved)


func patch_tree() -> void:
	_retranslate_tree()
	print("[i18n] Tree patched")


func _retranslate_tree() -> void:
	if _current_locale == "" or _current_locale == "en":
		_restore_originals()
		return
	if _current_locale not in _translations:
		return
	_retranslate_recursive(get_tree().get_root())


func _restore_originals() -> void:
	for id in _originals.keys():
		var node := instance_from_id(id)
		if not is_instance_valid(node):
			_originals.erase(id)
			continue
		var props: Dictionary = _originals[id]
		for prop in props:
			node.set(prop, props[prop])
	_originals.clear()


func _retranslate_recursive(node: Node) -> void:
	if node is Button:
		_try_translate_prop(node, "text")
		_hook_button_signals(node)
	elif node is Label or node is RichTextLabel:
		_try_translate_prop(node, "text")
	elif node is LineEdit:
		_try_translate_prop(node, "text")
		_try_translate_prop(node, "placeholder_text")

	for child in node.get_children():
		_retranslate_recursive(child)


func _try_translate_prop(node: Object, prop: String) -> void:
	var current: String = node.get(prop)
	if current == "":
		return
	var id: int = node.get_instance_id()
	var lookup := current.to_lower().strip_edges()
	var dict: Dictionary = _translations[_current_locale]
	if lookup in dict and dict[lookup] != current:
		# save original text before first translation
		if id not in _originals:
			_originals[id] = {}
		if prop not in _originals[id]:
			_originals[id][prop] = current
		node.set(prop, dict[lookup])


## Connect to button hover signals to catch dynamic text changes.
func _hook_button_signals(button: Button) -> void:
	var id := button.get_instance_id()
	if id in _connected_buttons:
		return
	_connected_buttons[id] = true

	# re-translate after the game's signal handler sets new text
	if not button.mouse_entered.is_connected(_on_button_hover):
		button.mouse_entered.connect(_on_button_hover.bind(button))
	if not button.mouse_exited.is_connected(_on_button_hover):
		button.mouse_exited.connect(_on_button_hover.bind(button))
	if not button.pressed.is_connected(_on_button_hover):
		button.pressed.connect(_on_button_hover.bind(button))
	if not button.visibility_changed.is_connected(_on_button_hover):
		button.visibility_changed.connect(_on_button_hover.bind(button))


func _on_button_hover(button: Button) -> void:
	# defer so the game's handler sets text first, then we translate
	_translate_button_deferred.call_deferred(button)


func _translate_button_deferred(button: Button) -> void:
	if not is_instance_valid(button):
		return
	if _current_locale == "" or _current_locale == "en":
		return
	if _current_locale not in _translations:
		return
	_try_translate_prop(button, "text")


func _on_node_added(node: Node) -> void:
	if _current_locale == "" or _current_locale == "en":
		return
	if _current_locale not in _translations:
		return
	if node is Button:
		_translate_and_hook_button.call_deferred(node)
	elif node is Label or node is RichTextLabel:
		_translate_new_node.call_deferred(node, "text")
	elif node is LineEdit:
		_translate_new_node.call_deferred(node, "text")


func _translate_and_hook_button(button: Button) -> void:
	if not is_instance_valid(button):
		return
	_try_translate_prop(button, "text")
	_hook_button_signals(button)


func _translate_new_node(node: Node, prop: String) -> void:
	if not is_instance_valid(node):
		return
	_try_translate_prop(node, prop)


func _save_locale(locale: String) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("i18n", "locale", locale)
	if cfg.save(_config_path) != OK:
		printerr("[i18n] Failed to save locale to: %s" % _config_path)


func _load_saved_locale() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(_config_path) != OK:
		return ""
	return cfg.get_value("i18n", "locale", "")

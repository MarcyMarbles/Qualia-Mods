extends RefCounted

## Loads .cfg translation files into a simple Dictionary.
##
## Format:
##   [meta]
##   displayName = "Русский"
##   locale = "ru"
##
##   [strings]
##   play = "играть"
##   settings = "настройки"


class TranslationData:
	var display_name: String
	var translation_dict: Dictionary  # { lowercase_key -> value, "__locale__" -> locale }
	var file_path: String
	var font_path: String = ""        # absolute path to .ttf/.otf, empty = use game default
	var font_size: int = 0            # 0 = use game default


static func load_cfg(path: String) -> TranslationData:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		printerr("[i18n] Failed to load: %s" % path)
		return null

	if not cfg.has_section("meta"):
		printerr("[i18n] Missing [meta] section in: %s" % path)
		return null

	var display_name: String = cfg.get_value("meta", "displayName", "")
	var locale: String = cfg.get_value("meta", "locale", "")

	if display_name == "":
		printerr("[i18n] Missing displayName in: %s" % path)
		return null

	if locale == "":
		locale = _guess_locale(display_name, path)
		print("[i18n] No locale in %s, guessed: %s" % [path, locale])

	var dict: Dictionary = {"__locale__": locale}

	if cfg.has_section("strings"):
		for key in cfg.get_section_keys("strings"):
			var value = cfg.get_value("strings", key, "")
			if value != "":
				dict[key.to_lower().strip_edges()] = str(value)

	var data := TranslationData.new()
	data.display_name = display_name
	data.translation_dict = dict
	data.file_path = path

	# font settings from [meta]
	var font_file: String = cfg.get_value("meta", "font", "")
	if font_file != "":
		var cfg_dir := path.get_base_dir()
		var abs_font := cfg_dir.path_join(font_file)
		if FileAccess.file_exists(abs_font):
			data.font_path = abs_font
		else:
			printerr("[i18n] Font not found: %s (referenced in %s)" % [abs_font, path])

	data.font_size = cfg.get_value("meta", "fontSize", 0)

	print("[i18n] Loaded '%s' (%s) — %d strings from %s" % [display_name, locale, dict.size() - 1, path])
	return data


static func _guess_locale(display_name: String, path: String) -> String:
	var name_lower := display_name.to_lower()
	var known := {
		"russian": "ru", "русский": "ru",
		"english": "en",
		"japanese": "ja", "日本語": "ja",
		"chinese": "zh", "中文": "zh",
		"korean": "ko", "한국어": "ko",
		"french": "fr", "français": "fr",
		"german": "de", "deutsch": "de",
		"spanish": "es", "español": "es",
		"portuguese": "pt", "português": "pt",
		"italian": "it", "italiano": "it",
		"polish": "pl", "polski": "pl",
		"turkish": "tr", "türkçe": "tr",
		"ukrainian": "uk", "українська": "uk",
		"arabic": "ar", "العربية": "ar",
		"thai": "th", "ไทย": "th",
		"vietnamese": "vi", "tiếng việt": "vi",
		"indonesian": "id",
		"dutch": "nl", "nederlands": "nl",
		"czech": "cs", "čeština": "cs",
		"romanian": "ro", "română": "ro",
		"hungarian": "hu", "magyar": "hu",
		"swedish": "sv", "svenska": "sv",
		"finnish": "fi", "suomi": "fi",
		"danish": "da", "dansk": "da",
		"norwegian": "no", "norsk": "no",
	}

	if name_lower in known:
		return known[name_lower]

	var file_stem: String = path.get_file().get_basename()
	if file_stem.length() == 2:
		return file_stem

	return "en"

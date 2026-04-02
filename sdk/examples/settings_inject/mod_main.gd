extends "res://mods/qualiamods/mod_base.gd"

## Settings example — adds a toggle to the Settings Menu.
## Uses ModBase's settings_tab() for declarative UI building.
##
## Пример настроек — добавляет переключатель в меню настроек.
## Использует settings_tab() из ModBase для декларативного UI.


func _game_ready() -> void:
	var tab = settings_tab("my mod")
	tab.add_toggle("my feature", "my_feature", get_cfg("my_feature", true))
	tab.load_values()
	tab.saved.connect(_on_settings_saved)

	log("Settings tab injected")


func _on_settings_saved(values: Dictionary) -> void:
	config.merge(values, true)
	log("Settings saved: my_feature=%s" % values.get("my_feature"))

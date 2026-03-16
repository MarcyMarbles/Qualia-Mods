extends Node

## Settings Inject Example - demonstrates injecting a custom control into the Settings Menu.
## Pattern: find an existing control via % (unique name), get its container,
## insert your Control next to it.
##
## Пример инжекта в настройки - показывает как вставить свой элемент в меню настроек.
## Паттерн: находим существующий элемент через % (unique name), берём его контейнер,
## вставляем свой Control рядом.

const MOD_ID := "settings_inject"

var config: Dictionary
var feature_btn: CheckButton


func _init_mod(cfg: Dictionary) -> void:
	config = cfg
	ModLoader.log_mod(MOD_ID, "Initialized (my_feature=%s)" % config.get("my_feature", true))


func _game_ready() -> void:
	_inject_settings_toggle()


func _on_config_changed(new_config: Dictionary) -> void:
	config = new_config
	ModLoader.log_mod(MOD_ID, "Config changed: my_feature=%s" % config.get("my_feature", true))


## Inject a CheckButton into Settings Menu next to FogQuality.
## Вставляем CheckButton в Settings Menu рядом с FogQuality.
func _inject_settings_toggle() -> void:
	var settings: Node = Ref.settings_menu
	if not settings:
		return

	# Find an anchor element - any existing control with a unique name
	# Находим якорный элемент - любой существующий контрол с unique name
	var anchor: Control = settings.get_node_or_null("%FogQuality")
	if not anchor:
		ModLoader.log_mod(MOD_ID, "Anchor node not found, skipping injection")
		return

	# Navigate to the parent container and calculate insertion index
	# Переходим к родительскому контейнеру и вычисляем индекс вставки
	var container: Control = anchor.get_parent().get_parent()
	var insert_idx: int = anchor.get_parent().get_index() + 1

	# Build a row: Label + CheckButton
	# Создаём строку: Label + CheckButton
	var row := HBoxContainer.new()
	row.name = "MyFeatureRow"
	row.custom_minimum_size = Vector2(0, 14)

	var label := Label.new()
	label.text = "my feature"
	label.custom_minimum_size = Vector2(86, 0)
	row.add_child(label)

	feature_btn = CheckButton.new()
	feature_btn.button_pressed = config.get("my_feature", true)
	feature_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(feature_btn)

	container.add_child(row)
	container.move_child(row, insert_idx)

	# Persist when the user clicks "save" in settings
	# Сохраняем при нажатии кнопки "save" в настройках
	settings.saved.connect(func():
		config["my_feature"] = feature_btn.button_pressed
		Ref.save_file_manager.settings_file.set_data("mod_my_feature", feature_btn.button_pressed)
		ModLoader.log_mod(MOD_ID, "Saved my_feature=%s" % feature_btn.button_pressed)
	)

	# Restore value when settings menu opens
	# Восстанавливаем при открытии настроек
	settings.visibility_changed.connect(func():
		if settings.visible and feature_btn:
			feature_btn.button_pressed = Ref.save_file_manager.settings_file.get_data(
				"mod_my_feature", config.get("my_feature", true)
			)
	)

	ModLoader.log_mod(MOD_ID, "Settings toggle injected")

extends "res://mods/qualiamods/mod_base.gd"

## mod_main.gd — Mod entry point.
## Extend ModBase for auto-wiring: mod_id, config, and hooks
## are set up for you. Just override what you need.
##
## mod_main.gd — Точка входа мода.
## Наследуйся от ModBase для авто-подключения: mod_id, config и хуки
## настраиваются автоматически. Просто переопредели что нужно.


## Called after config and hooks are wired.
## Вызывается после настройки конфига и хуков.
func _setup() -> void:
	# Subscribe to hooks by defining methods like:
	#   func _on_game_playable() -> void:
	#   func _on_world_loaded() -> void:
	# They auto-subscribe — no manual add_hook() needed.
	#
	# Подписка на хуки через определение методов:
	#   func _on_game_playable() -> void:
	#   func _on_world_loaded() -> void:
	# Они подписываются автоматически — add_hook() не нужен.

	log_info("Initialized")


## Called when the game scene tree is ready.
## Safe to access Ref.player, Ref.world, etc.
##
## Вызывается когда дерево сцен игры готово.
## Здесь безопасно обращаться к Ref.player, Ref.world и т.д.
func _game_ready() -> void:
	pass


## User changed config in Mods Menu and pressed "save".
## Пользователь изменил конфиг в Mods Menu и нажал "save".
func _config_changed() -> void:
	pass


## Mod is being unloaded (game exit / reload).
## Мод выгружается (выход из игры / перезагрузка).
func _cleanup() -> void:
	pass

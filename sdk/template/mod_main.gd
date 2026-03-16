extends Node

## mod_main.gd - Mod entry point.
## This script becomes a child node of ModLoader when loaded.
## Rename MOD_ID and implement the lifecycle methods you need.
##
## mod_main.gd - Точка входа мода.
## Этот скрипт становится дочерней нодой ModLoader при загрузке.
## Переименуй MOD_ID и реализуй нужные lifecycle-методы.

const MOD_ID := "mymod"

var config: Dictionary


## Called first. config contains values from mod.cfg [config]
## merged with user overrides from mods/<mod_id>.cfg.
##
## Вызывается первым. config содержит значения из mod.cfg [config]
## с учётом пользовательских оверрайдов из mods/<mod_id>.cfg.
func _init_mod(cfg: Dictionary) -> void:
	config = cfg

	# Subscribe to hooks / Подписка на хуки:
	# ModLoader.add_hook(ModLoader.Hooks.GAME_PLAYABLE, _on_game_playable)
	# ModLoader.add_hook(ModLoader.Hooks.WORLD_LOADED, _on_world_loaded)

	ModLoader.log_mod(MOD_ID, "Initialized")


## Called when the game scene tree is ready.
## Safe to access Ref.player, Ref.world, etc.
##
## Вызывается когда дерево сцен игры готово.
## Здесь безопасно обращаться к Ref.player, Ref.world и т.д.
func _game_ready() -> void:
	pass


## User changed config in Mods Menu and pressed "save".
## Пользователь изменил конфиг в Mods Menu и нажал "save".
func _on_config_changed(new_config: Dictionary) -> void:
	config = new_config


## Message from another mod (via ModLoader.send_message / broadcast_message).
## Сообщение от другого мода (через ModLoader.send_message / broadcast_message).
func _on_mod_message(sender_id: String, data: Dictionary) -> void:
	pass


## Mod is being unloaded (game exit / reload).
## Мод выгружается (выход из игры / перезагрузка).
func _mod_cleanup() -> void:
	pass

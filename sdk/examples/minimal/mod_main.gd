extends Node

## Minimal example - the simplest possible mod.
## Subscribes to the GAME_PLAYABLE hook and logs a message.
##
## Минимальный пример - самый простой мод.
## Подписывается на хук GAME_PLAYABLE и выводит сообщение в лог.

const MOD_ID := "minimal"


func _init_mod(_cfg: Dictionary) -> void:
	# Subscribe to the hook that fires when the player can move
	# Подписка на хук, который срабатывает когда игрок может двигаться
	ModLoader.add_hook(ModLoader.Hooks.GAME_PLAYABLE, _on_game_playable)
	ModLoader.log_mod(MOD_ID, "Hello from minimal mod!")


func _game_ready() -> void:
	# Scene tree is ready - Ref references are valid now
	# Дерево сцен готово - ссылки Ref теперь валидны
	ModLoader.log_mod(MOD_ID, "Game tree is ready, player: %s" % Ref.player)


func _on_game_playable() -> void:
	# Player can now interact with the world
	# Игрок теперь может взаимодействовать с миром
	ModLoader.log_mod(MOD_ID, "Game is playable! Player position: %s" % Ref.player.global_position)

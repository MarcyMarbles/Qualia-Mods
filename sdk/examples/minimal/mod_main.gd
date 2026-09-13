extends "res://mods/qualiamods/mod_base.gd"

## Minimal example — the simplest possible mod.
## Just define _on_<hook> methods and they auto-subscribe.
##
## Минимальный пример — самый простой мод.
## Просто определи методы _on_<hook> и они подпишутся автоматически.


func _setup() -> void:
	log_info("Hello from minimal mod!")


func _game_ready() -> void:
	log_info("Game tree is ready, player: %s" % Ref.player)


func _on_game_playable() -> void:
	log_info("Game is playable! Player position: %s" % Ref.player.global_position)

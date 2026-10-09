class_name CombatInputDispatcher
extends Node

## Despachador de entradas de combate y atajos de depuración.
## Extraído de MainGame para modularidad y separación de responsabilidades.

var main_game: Node2D = null
var ingame_debug_modal: CanvasLayer = null

func setup(p_main_game: Node2D) -> void:
	main_game = p_main_game

func toggle_ingame_debug() -> void:
	if not DebugManager.is_debug_enabled() or not is_instance_valid(main_game):
		return
	if not ingame_debug_modal:
		var scene := load("res://scenes/ui/debug/ingame_debug_modal.tscn") as PackedScene
		if scene:
			ingame_debug_modal = scene.instantiate() as CanvasLayer
			main_game.add_child(ingame_debug_modal)
			if ingame_debug_modal.has_method("setup"):
				ingame_debug_modal.setup(main_game)

	if ingame_debug_modal:
		if ingame_debug_modal.is_open:
			ingame_debug_modal.close()
		else:
			ingame_debug_modal.open()

func handle_input(event: InputEvent) -> void:
	if not is_instance_valid(main_game):
		return

	# Durante secuencias cinemáticas o diálogos, consumir ESC para evitar desincronizar pausa
	if main_game.has_method("is_cinematic_or_death_active") and main_game.is_cinematic_or_death_active():
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			main_game.get_viewport().set_input_as_handled()
			return

	if DebugManager.is_debug_enabled() and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1:
			main_game.get_viewport().set_input_as_handled()
			toggle_ingame_debug()
			return

		# Hotkeys de depuración para combate
		match event.keycode:
			KEY_B:
				if main_game.get("current_boss") == null and main_game.has_method("_spawn_wave_boss"):
					main_game._spawn_wave_boss()
			KEY_R:
				if main_game.has_method("spawn_next_rival_pilot"):
					main_game.spawn_next_rival_pilot()
			KEY_P:
				if main_game.has_method("jump_to_wave_16"):
					main_game.jump_to_wave_16("pacifist")
			KEY_K:
				if main_game.has_method("jump_to_wave_16"):
					main_game.jump_to_wave_16("slayer")
			KEY_N:
				if main_game.has_method("jump_to_wave_16"):
					main_game.jump_to_wave_16("neutral")
			KEY_T:
				if main_game.has_method("trigger_boss_transmission"):
					main_game.trigger_boss_transmission("CENTINELA TITÁN", "¡Alerta de distorsión! Tus armas no perforarán nuestro núcleo planetario. Prepárate para el impacto.")

class_name CombatEndRunController
extends RefCounted

## CombatEndRunController.gd
## Controlador modular del ciclo de fin de partida (Game Over, Victoria, Modo Endless,
## reinicio de run y retorno al Hub 3D). Desacopla la lógica de finalización de MainGame.

const CombatTelemetryRecorderScript = preload("res://scenes/combat/systems/combat_telemetry_recorder.gd")
const GameOverModalScene: PackedScene = preload("res://scenes/ui/game_over/game_over_modal.tscn")

var main_game: Node2D = null
var game_over_modal: GameOverModal = null


func setup(p_main_game: Node2D, p_existing_modal: GameOverModal = null) -> void:
	main_game = p_main_game
	game_over_modal = p_existing_modal


func on_player_died() -> void:
	if not main_game:
		return

	# Limpiar niveles y arcanas pendientes
	if "level_up_modal" in main_game and main_game.level_up_modal and main_game.level_up_modal.has_method("clear_pending_levels"):
		main_game.level_up_modal.clear_pending_levels()
	if "arcana_modal" in main_game and main_game.arcana_modal and main_game.arcana_modal.has_method("clear_pending_arcanas"):
		main_game.arcana_modal.clear_pending_arcanas()
	
	if "_pending_arcana_picks" in main_game:
		main_game._pending_arcana_picks = 0
	if "_pending_satellite_credits" in main_game:
		main_game._pending_satellite_credits = -1
	if "_pending_satellite_index" in main_game:
		main_game._pending_satellite_index = -1

	# Pausar la generación de nuevos enemigos
	if "enemy_spawner" in main_game and main_game.enemy_spawner and main_game.enemy_spawner.has_method("set_spawning_paused"):
		main_game.enemy_spawner.set_spawning_paused(true)

	var game_over_data: Dictionary = CombatTelemetryRecorderScript.build_end_of_run_data(main_game, false)
	main_game.get_tree().create_timer(1.0, true, false, true).timeout.connect(func():
		show_game_over_screen(game_over_data)
	)


func show_game_over_screen(data: Dictionary) -> void:
	if not main_game:
		return

	if not game_over_modal:
		game_over_modal = GameOverModalScene.instantiate() as GameOverModal
		main_game.add_child(game_over_modal)
		if "game_over_modal" in main_game:
			main_game.game_over_modal = game_over_modal

	if not game_over_modal.restart_requested.is_connected(handle_game_over_restart):
		game_over_modal.restart_requested.connect(handle_game_over_restart)
	if not game_over_modal.hub_requested.is_connected(handle_game_over_hub):
		game_over_modal.hub_requested.connect(handle_game_over_hub)
	if not game_over_modal.endless_requested.is_connected(handle_game_over_endless):
		game_over_modal.endless_requested.connect(handle_game_over_endless)

	PauseArbitrator.acquire_pause(&"game_over")
	game_over_modal.show_game_over(data)


func handle_game_over_endless() -> void:
	if not main_game:
		return

	if "is_endless_mode" in main_game:
		main_game.is_endless_mode = true
	PauseArbitrator.release_pause(&"game_over")
	Engine.time_scale = 1.0
	
	if main_game.has_method("save_current_run_state"):
		main_game.save_current_run_state()

	if "hud" in main_game and main_game.hud and main_game.hud.has_method("show_tactical_alert"):
		main_game.hud.show_tactical_alert(
			"MODO SIN FIN // ENDLESS DESBLOQUEADO",
			"Las fuerzas del abismo escalan sin límite. ¡Sobrevive cuanto puedas!",
			Color(0.2, 1.0, 0.75, 1.0)
		)

	# Reanudar la siguiente oleada de combate sin límite
	if "current_wave" in main_game:
		main_game.current_wave += 1
		if "wave_timer" in main_game and "WAVE_DURATION" in main_game:
			main_game.wave_timer = main_game.WAVE_DURATION
		if "wave_satellites_spawned" in main_game:
			main_game.wave_satellites_spawned = 0
		if "enemy_spawner" in main_game and main_game.enemy_spawner and main_game.enemy_spawner.has_method("set_wave"):
			main_game.enemy_spawner.set_wave(main_game.current_wave)
		if "_wave_encounter_checked_for_wave" in main_game:
			main_game._wave_encounter_checked_for_wave = main_game.current_wave
		if "_wave_encounter_pending" in main_game:
			main_game._wave_encounter_pending = false
		if main_game.has_method("save_current_run_state"):
			main_game.save_current_run_state()
		if main_game.has_method("_spawn_next_satellite_for_wave"):
			main_game._spawn_next_satellite_for_wave()
		if "chest_director" in main_game and main_game.chest_director:
			var player_ref: Node = main_game.get("player")
			var green_cards: int = 0
			if player_ref and "inventory" in player_ref and player_ref.inventory:
				green_cards = player_ref.inventory.get_item_count(&"credit_card_green")
			main_game.chest_director.on_new_wave(main_game.current_wave, green_cards)
		if main_game.has_method("_spawn_wave_chests"):
			main_game._spawn_wave_chests()
		if "space_object_spawner" in main_game and main_game.space_object_spawner and main_game.space_object_spawner.has_method("notify_wave_started"):
			main_game.space_object_spawner.notify_wave_started(main_game.current_wave)


func handle_game_over_restart() -> void:
	if not main_game:
		return
	if "is_exiting_run" in main_game:
		main_game.is_exiting_run = true
	SaveManager.clear_active_run()
	PauseArbitrator.force_unpause_all()
	Engine.time_scale = 1.0
	main_game.get_tree().reload_current_scene()


func handle_game_over_hub() -> void:
	if not main_game:
		return
	if "is_exiting_run" in main_game:
		main_game.is_exiting_run = true
	SaveManager.clear_active_run()
	PauseArbitrator.force_unpause_all()
	Engine.time_scale = 1.0
	SaveManager.set_game_speed(1.0)
	
	var st: Node = main_game.get_node_or_null("/root/SceneTransition")
	if st and st.has_method("change_scene_to_file"):
		st.change_scene_to_file("res://scenes/ui/hub/hub_world.tscn")
	else:
		main_game.get_tree().change_scene_to_file("res://scenes/ui/hub/hub_world.tscn")

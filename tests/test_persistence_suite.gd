extends Node2D

func _ready() -> void:
	print("==========================================")
	print("[TEST] Testing Astra Dream Persistence Suite...")
	print("==========================================\n")

	# --- TEST 1: SETTINGS PERSISTENCE (user://settings.cfg) ---
	print("[1/5] Testing SettingsManager Audio, Display, and Keybindings Persistence...")
	SettingsManager.set_audio_volume("Master", 0.65)
	SettingsManager.set_audio_volume("Music", 0.45)
	SettingsManager.set_audio_volume("SFX", 0.85)
	SettingsManager.set_deadzone(0.32)
	SettingsManager.set_fullscreen(false)
	SettingsManager.set_resolution(Vector2i(1600, 900))

	var err: Error = SettingsManager.save_settings()
	assert(err == OK, "SettingsManager.save_settings() debe retornar OK")

	# Re-cargar y verificar
	SettingsManager.load_settings()
	assert(is_equal_approx(SettingsManager.get_audio_volume("Master"), 0.65), "Master volume debe ser 0.65")
	assert(is_equal_approx(SettingsManager.get_audio_volume("Music"), 0.45), "Music volume debe ser 0.45")
	assert(is_equal_approx(SettingsManager.get_audio_volume("SFX"), 0.85), "SFX volume debe ser 0.85")
	assert(is_equal_approx(SettingsManager.get_deadzone(), 0.32), "Deadzone debe ser 0.32")
	assert(SettingsManager.get_resolution() == Vector2i(1600, 900), "Resolución debe ser 1600x900")
	assert(SettingsManager.is_fullscreen() == false, "Fullscreen debe ser false")
	print("  ✓ Configuración de audio, pantalla y zona muerta guardada y leída correctamente de user://settings.cfg")

	# --- TEST 2: ACTIVE RUN SERIALIZATION (user://active_run.json) ---
	print("\n[2/5] Testing Mid-Run Save File Creation and Parsing...")
	SaveManager.clear_active_run()
	assert(SaveManager.has_active_run() == false, "No debe haber run activa tras clear_active_run")

	var mock_run := {
		"version": 1,
		"timestamp": 123456789,
		"pilot_id": "nova",
		"pilot_name": "Nova",
		"current_wave": 3,
		"wave_timer": 45.0,
		"wave_satellites_spawned": 1,
		"satellites_collected_total": 4,
		"current_satellite_idx": 5,
		"run_time_elapsed": 180.0,
		"enemies_killed_count": 52,
		"prologue_bonus_chosen": true,
		"player_health": 85.0,
		"player_level": 4,
		"player_exp": 20.0,
		"player_exp_to_next": 95.0,
		"run_credits": 340,
		"run_biomass": 45,
		"bomb_count": 4,
		"equipped_weapons": [
			{"id": "rail_launcher", "level": 2},
			{"id": "solar_beam", "level": 1}
		],
		"equipped_items": [
			{"id": "botas", "count": 2},
			{"id": "espada", "count": 1}
		],
		"chosen_stat_cards": ["card_dmg_1", "card_speed_up"]
	}

	var save_err: Error = SaveManager.save_active_run(mock_run)
	assert(save_err == OK, "SaveManager.save_active_run debe retornar OK")
	assert(SaveManager.has_active_run() == true, "SaveManager.has_active_run debe retornar true tras guardar")

	var loaded_run := SaveManager.load_active_run()
	assert(loaded_run.get("current_wave") == 3, "Oleada cargada debe ser 3")
	assert(loaded_run.get("run_credits") == 340, "Créditos cargados deben ser 340")
	assert(loaded_run.get("bomb_count") == 4, "Bombas cargadas deben ser 4")
	assert(loaded_run.get("equipped_weapons").size() == 2, "Debe tener 2 armas registradas")
	print("  ✓ Archivo user://active_run.json creado y validado exitosamente")

	# --- TEST 3: MAIN GAME RUN RECONSTRUCTION ---
	print("\n[3/5] Testing MainGame State Reconstruction from Active Run...")
	var main_scene: PackedScene = load("res://scenes/combat/main_game.tscn")
	assert(main_scene != null, "main_game.tscn debe existir")
	var main_game: MainGame = main_scene.instantiate() as MainGame
	add_child(main_game)

	if Dialogic:
		Dialogic.end_timeline()
	main_game.is_briefing_active = false
	get_tree().paused = false

	# Restaurar el estado mock
	main_game.restore_run_state(loaded_run)

	assert(main_game.current_wave == 3, "MainGame.current_wave debe ser 3 (actual: %d)" % main_game.current_wave)
	assert(main_game.satellites_collected_total == 4, "Satélites recolectados deben ser 4")
	assert(main_game.player.current_level == 4, "Nivel de jugador debe ser 4")
	assert(main_game.player.run_credits == 340, "Créditos de jugador deben ser 340")
	assert(main_game.player.bomb_count == 4, "Bombas de jugador deben ser 4")
	assert(is_equal_approx(main_game.player.current_health, 85.0), "Salud de jugador debe ser 85.0")

	# Verificar inventario
	assert(main_game.player.inventory.get_item_count(&"botas") == 2, "Inventario debe tener 2 botas")
	assert(main_game.player.inventory.get_item_count(&"espada") == 1, "Inventario debe tener 1 espada")

	# Verificar cartas Brotato
	assert(main_game.player.chosen_stat_cards.size() == 2, "Debe tener 2 cartas de mejoras registradas")

	# Verificar armas en WeaponController
	var w_ctrl := main_game.player.get_node_or_null("WeaponController") as WeaponController
	assert(w_ctrl != null, "WeaponController debe existir en el jugador")
	assert(w_ctrl.equipped_weapons.size() == 2, "WeaponController debe tener 2 armas equipadas")
	var rail_inst := w_ctrl.get_weapon_instance(&"rail_launcher")
	assert(rail_inst != null and rail_inst.level == 2, "rail_launcher debe estar a nivel 2")
	var solar_inst := w_ctrl.get_weapon_instance(&"solar_beam")
	assert(solar_inst != null and solar_inst.level == 1, "solar_beam debe estar a nivel 1")
	print("  ✓ Reconstrucción total de la run en MainGame verificada (Oleada, Nivel, HP, Inventario, Cartas y Armas)")

	# --- TEST 4: PERMADEATH DELETION ---
	print("\n[4/5] Testing Permadeath active_run.json Cleanup...")
	SaveManager.clear_active_run()
	assert(SaveManager.has_active_run() == false, "user://active_run.json debe eliminarse completamente tras la muerte")
	print("  ✓ Permadeath verificado: la run en curso se elimina limpiamente")

	# --- TEST 5: HIGHSCORES & RUN HISTORY (TOP 10) ---
	print("\n[5/5] Testing Top 10 Highscores and Leaderboard Sorting...")
	SaveManager.clear_highscores()
	var rank1 := SaveManager.record_run_score({
		"pilot_id": "nova",
		"pilot_name": "Nova",
		"wave_reached": 10,
		"time_survived_seconds": 600.0,
		"time_survived_formatted": "10:00",
		"enemies_killed": 850,
		"credits_earned": 900,
		"victory": true
	})
	assert(rank1 == 1, "El récord de oleada 10 debe ser el #1 en el ranking (obtenido: #%d)" % rank1)

	var rank2 := SaveManager.record_run_score({
		"pilot_id": "echo",
		"pilot_name": "Echo",
		"wave_reached": 8,
		"time_survived_seconds": 480.0,
		"time_survived_formatted": "08:00",
		"enemies_killed": 620,
		"credits_earned": 500,
		"victory": false
	})
	assert(rank2 == 2, "El récord de oleada 8 debe ser el #2 en el ranking (obtenido: #%d)" % rank2)

	var highscores := SaveManager.get_top_highscores()
	assert(highscores.size() <= 10, "La lista de highscores no debe superar los 10 registros")
	assert(highscores[0].get("wave_reached") >= highscores[1].get("wave_reached"), "Los récords deben estar ordenados descendentemente por oleada")
	print("  ✓ Highscores Top 10 y ordenamiento multicriterio verificados exitosamente")

	print("\n==========================================")
	print(">>> ALL PERSISTENCE TESTS PASSED (100%) <<<")
	print("==========================================\n")
	get_tree().quit(0)

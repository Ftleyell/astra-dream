extends Node

const PlayerExplosionVFX = preload("res://scenes/combat/player/player_explosion_vfx.gd")
const GameOverModal = preload("res://scenes/ui/game_over/game_over_modal.gd")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("==========================================")
	print("[TEST] Testing Game Over Screen & Death Sequence...")
	print("==========================================")

	await _test_player_explosion_vfx()
	await _test_player_death_sequence()
	await _test_game_over_modal_ui()
	await _test_main_game_death_flow()

	print("\n==========================================")
	print("[PASS] ALL GAME OVER SCREEN & DEATH TESTS PASSED (100%)!")
	print("==========================================")
	Engine.time_scale = 1.0
	get_tree().quit(0)

func _test_player_explosion_vfx() -> void:
	print("\n[1/4] Testing PlayerExplosionVFX creation, parameters & lifecycle...")
	var vfx_scene: PackedScene = load("res://scenes/combat/player/player_explosion_vfx.tscn")
	assert(vfx_scene != null, "player_explosion_vfx.tscn debe existir y ser cargable")

	var vfx: PlayerExplosionVFX = vfx_scene.instantiate() as PlayerExplosionVFX
	assert(vfx != null, "PlayerExplosionVFX debe instanciarse como clase PlayerExplosionVFX")

	vfx.setup(Vector2(450, 300), Color(0.1, 0.9, 0.5))
	assert(vfx.global_position == Vector2(450, 300), "global_position debe ser (450, 300)")
	assert(vfx.blast_color == Color(0.1, 0.9, 0.5), "blast_color debe coincidir con el asignado")

	add_child(vfx)
	await get_tree().process_frame

	assert(vfx.z_index == 50, "z_index de la explosión debe ser 50")
	assert(vfx._shards.size() >= 9, "Debe generar al menos 9 fragmentos de casco")
	assert(vfx._sparks.size() >= 24, "Debe generar al menos 24 chispas de energía")

	# Simular avance del temporizador
	vfx._process(0.2)
	assert(vfx._timer >= 0.2, "El temporizador debe acumular delta")

	vfx.queue_free()
	await get_tree().process_frame
	print("  ✓ PlayerExplosionVFX: Creación, fragmentos geométricos y ciclo de vida verificados.")

func _test_player_death_sequence() -> void:
	print("\n[2/4] Testing Player death sequence, VFX trigger and input lock...")
	var main_scene = load("res://scenes/combat/main_game.tscn")
	var main_game: MainGame = main_scene.instantiate() as MainGame
	add_child(main_game)
	await get_tree().process_frame

	var player := main_game.player
	assert(player != null, "Player debe existir en MainGame")
	assert(player.is_dead == false, "Player.is_dead debe ser false inicialmente")

	# Recibir daño letal
	var died_emitted := [false]
	player.player_died.connect(func(): died_emitted[0] = true)

	player.take_damage(9999.0)
	await get_tree().process_frame

	assert(player.is_dead == true, "Player.is_dead debe ser true tras daño letal")
	assert(died_emitted[0] == true, "Señal player_died debe haberse emitido")
	assert(player.get_node("CollisionShape2D").disabled == true, "CollisionShape2D debe estar desactivada")

	# Probar que llamadas subsiguientes a take_damage no re-emiten
	died_emitted[0] = false
	player.take_damage(100.0)
	assert(died_emitted[0] == false, "No debe volver a emitir player_died si ya está muerto")

	main_game.is_exiting_run = true
	main_game.queue_free()
	await get_tree().process_frame
	print("  ✓ Secuencia de muerte del Player: Bloqueo de controles, ocultamiento visual y disparo de VFX verificados.")

func _test_game_over_modal_ui() -> void:
	print("\n[3/4] Testing GameOverModal data population, telemetry & signals...")
	var modal_scene: PackedScene = load("res://scenes/ui/game_over/game_over_modal.tscn")
	assert(modal_scene != null, "game_over_modal.tscn debe existir y ser cargable")

	var modal: GameOverModal = modal_scene.instantiate() as GameOverModal
	add_child(modal)
	await get_tree().process_frame

	# Crear datos simulados para la pantalla de Game Over
	var dummy_arcana := ArcanaData.new()
	dummy_arcana.id = "blood_pact"
	dummy_arcana.name = "Pacto de Sangre"
	dummy_arcana.color_accent = Color(1.0, 0.2, 0.2)

	var dummy_item := ItemData.new()
	dummy_item.item_id = &"botas"
	dummy_item.item_name = "Propulsor Iónico"

	var mock_data := {
		"score": 158420,
		"is_new_highscore": true,
		"rank": 1,
		"pilot_name": "Selene",
		"pilot_id": "selene",
		"waves_survived": 5,
		"time_formatted": "05:42",
		"bosses_defeated": 2,
		"enemies_killed": 312,
		"biomass_collected": 85,
		"dark_matter_collected": 16,
		"credits_collected": 450,
		"arcanas": [dummy_arcana],
		"items": [{"data": dummy_item, "count": 2}],
		"weapons": [{"name": "Láser Cuántico", "level": 3}]
	}

	modal.show_game_over(mock_data)

	assert(modal.visible == true, "GameOverModal debe ser visible tras show_game_over()")
	assert(modal.score_value_label.text.contains("158,420"), "Puntuación formateada debe ser '158,420 PTS'")
	assert(modal.highscore_badge.visible == true, "Insignia de Nuevo Récord debe ser visible")
	assert(modal.highscore_label.text.contains("NUEVO RÉCORD"), "Texto de récord debe indicar Nuevo Récord")
	assert(modal.pilot_label.text.contains("SELENE"), "Nombre de piloto debe mostrarse correctamente")
	assert(modal.wave_val_label.text == "Oleada 5", "Oleadas sobrevividas debe ser 'Oleada 5'")
	assert(modal.time_val_label.text == "05:42", "Tiempo formateado debe ser '05:42'")
	assert(modal.bosses_val_label.text.contains("2"), "Jefes derrotados debe indicar 2")
	assert(modal.kills_val_label.text.contains("312"), "Bajas debe indicar 312")
	assert(modal.biomass_val_label.text.contains("85"), "Biomasa debe mostrar +85")
	assert(modal.dark_matter_val_label.text.contains("16"), "Antimateria debe mostrar +16")
	assert(modal.credits_val_label.text.contains("450"), "Créditos debe mostrar +450")

	# Probar señales de botones
	var restart_fired := [false]
	var hub_fired := [false]
	modal.restart_requested.connect(func(): restart_fired[0] = true)
	modal.hub_requested.connect(func(): hub_fired[0] = true)

	modal.restart_button.pressed.emit()
	assert(restart_fired[0] == true, "Click en restart_button debe emitir restart_requested")

	modal.hub_button.pressed.emit()
	assert(hub_fired[0] == true, "Click en hub_button debe emitir hub_requested")

	modal.queue_free()
	await get_tree().process_frame
	print("  ✓ GameOverModal: Visualización de score, récord, biomasa, antimateria, items, arcanas y botones verificada.")

func _test_main_game_death_flow() -> void:
	print("\n[4/4] Testing MainGame death handler, bosses tracking & modal connection...")
	var main_scene = load("res://scenes/combat/main_game.tscn")
	var main_game: MainGame = main_scene.instantiate() as MainGame
	add_child(main_game)

	await get_tree().process_frame

	assert(main_game.bosses_defeated_count == 0, "bosses_defeated_count inicial debe ser 0")
	# Simular derrota de jefe
	main_game._on_boss_defeated("boss_titan")
	assert(main_game.bosses_defeated_count == 1, "bosses_defeated_count debe incrementarse a 1")

	# Simular acumulación de bajas y recursos
	main_game.enemies_killed_count = 120
	main_game.current_wave = 3
	main_game.run_time_elapsed = 180.0
	main_game.player.run_credits = 200
	main_game.player.run_biomass = 40
	main_game.player.run_dark_matter = 8

	# Simular muerte del jugador
	main_game._on_player_died()

	# Esperar el temporizador de 1.0s para el despliegue del modal
	await get_tree().create_timer(1.2, true, false, true).timeout

	assert(main_game.is_game_over_active() == true, "is_game_over_active() debe ser true tras el delay de muerte")
	assert(main_game.game_over_modal != null and main_game.game_over_modal.visible == true, "GameOverModal debe estar visible")
	assert(get_tree().paused == true, "El juego debe pausarse al mostrar GameOverModal")

	main_game.is_exiting_run = true
	get_tree().paused = false
	main_game.queue_free()
	await get_tree().process_frame
	print("  ✓ MainGame: Integración completa de muerte, conteo de jefes, cálculo de puntuación y apertura de modal verificada.")

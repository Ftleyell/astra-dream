extends Node

func _ready() -> void:
	print("==========================================")
	print("[TEST] Testing GameSpeed Controls & Satellite 10k Despawn...")
	print("==========================================")

	_test_save_manager_gamespeed()
	await _test_loadout_gamespeed_buttons()
	await _test_satellite_10k_despawn()

	print("\n==========================================")
	print("[PASS] ALL GAMESPEED & SATELLITE DESPAWN TESTS PASSED (100%)!")
	print("==========================================")
	Engine.time_scale = 1.0
	get_tree().quit(0)

func _test_save_manager_gamespeed() -> void:
	print("\n[1/3] Testing SaveManager GameSpeed persistence...")
	SaveManager.set_game_speed(1.0)
	assert(is_equal_approx(SaveManager.get_game_speed(), 1.0), "Debe persistir velocidad 1.0")
	assert(is_equal_approx(Engine.time_scale, 1.0), "Engine.time_scale debe ser 1.0")

	SaveManager.set_game_speed(2.0)
	assert(is_equal_approx(SaveManager.get_game_speed(), 2.0), "Debe persistir velocidad 2.0")
	assert(is_equal_approx(Engine.time_scale, 2.0), "Engine.time_scale debe ser 2.0")

	SaveManager.set_game_speed(4.0)
	assert(is_equal_approx(SaveManager.get_game_speed(), 4.0), "Debe persistir velocidad 4.0")
	assert(is_equal_approx(Engine.time_scale, 4.0), "Engine.time_scale debe ser 4.0")

	# Revertir a 1.0 para el resto de pruebas
	SaveManager.set_game_speed(1.0)
	print("  ✓ SaveManager: Get/Set y persistencia de 1x, 2x y 4x verificada.")

func _test_loadout_gamespeed_buttons() -> void:
	print("\n[2/3] Testing Deployment Menu GameSpeed Radio Buttons (1x, 2x, 4x)...")
	var deploy_scene = load("res://scenes/ui/character_select/character_select.tscn")
	var deploy: CharacterSelectUI = deploy_scene.instantiate() as CharacterSelectUI
	add_child(deploy)

	await get_tree().process_frame

	assert(deploy.speed_1x_btn != null, "Botón 1x debe existir en el Menú de Despliegue (CharacterSelect)")
	assert(deploy.speed_2x_btn != null, "Botón 2x debe existir en el Menú de Despliegue (CharacterSelect)")
	assert(deploy.speed_4x_btn != null, "Botón 4x debe existir en el Menú de Despliegue (CharacterSelect)")

	# Inicialmente en 1x
	assert(deploy.speed_1x_btn.text.contains("●"), "Botón 1x debe estar activo por defecto")
	assert(deploy.speed_2x_btn.text.contains("○"), "Botón 2x debe estar inactivo")
	assert(deploy.speed_4x_btn.text.contains("○"), "Botón 4x debe estar inactivo")

	# Click en botón 2x
	deploy.speed_2x_btn.emit_signal("pressed")
	assert(is_equal_approx(SaveManager.get_game_speed(), 2.0), "Debe cambiar a 2x tras click")
	assert(deploy.speed_1x_btn.text.contains("○"), "Botón 1x debe quedar inactivo")
	assert(deploy.speed_2x_btn.text.contains("●"), "Botón 2x debe ser el único activo")
	assert(deploy.speed_4x_btn.text.contains("○"), "Botón 4x debe quedar inactivo")

	# Click en botón 4x
	deploy.speed_4x_btn.emit_signal("pressed")
	assert(is_equal_approx(SaveManager.get_game_speed(), 4.0), "Debe cambiar a 4x tras click")
	assert(deploy.speed_1x_btn.text.contains("○"), "Botón 1x debe estar inactivo")
	assert(deploy.speed_2x_btn.text.contains("○"), "Botón 2x debe estar inactivo")
	assert(deploy.speed_4x_btn.text.contains("●"), "Botón 4x debe ser el único activo")

	# Click en botón 1x
	deploy.speed_1x_btn.emit_signal("pressed")
	assert(is_equal_approx(SaveManager.get_game_speed(), 1.0), "Debe volver a 1x")
	assert(deploy.speed_1x_btn.text.contains("●"), "Botón 1x activo")
	assert(deploy.speed_2x_btn.text.contains("○"), "Botón 2x inactivo")
	assert(deploy.speed_4x_btn.text.contains("○"), "Botón 4x inactivo")

	deploy.queue_free()
	await get_tree().process_frame
	print("  ✓ Deployment Menu (CharacterSelect): Comportamiento radio-button de 3 botones (1x, 2x, 4x) verificado.")

func _test_satellite_10k_despawn() -> void:
	print("\n[3/3] Testing Satellite 10k Despawn System in MainGame...")
	var main_game_scene = load("res://scenes/combat/main_game.tscn")
	var main_game: MainGame = main_game_scene.instantiate() as MainGame
	add_child(main_game)

	var timer = get_tree().create_timer(0.3)
	await timer.timeout

	assert(main_game.current_satellite != null, "Debe existir un satélite en curso")
	var sat = main_game.current_satellite

	# Posicionar satélite en (0, 0)
	sat.global_position = Vector2.ZERO

	# Jugador a 5,000 unidades de distancia: NO debe desespawnear
	main_game.player.global_position = Vector2(5000.0, 0.0)
	main_game._check_satellite_despawn()
	assert(main_game.current_satellite != null, "A 5k px el satélite debe permanecer activo")

	# Jugador a 10,001 unidades de distancia (> 10k px): DEBE desespawnear
	main_game.player.global_position = Vector2(10050.0, 0.0)
	var prev_spawned: int = main_game.wave_satellites_spawned
	main_game._check_satellite_despawn()

	assert(main_game.current_satellite == null or main_game.current_satellite.is_queued_for_deletion(), "El satélite a más de 10k de distancia debe haber desespawneado")
	assert(main_game.wave_satellites_spawned < prev_spawned, "wave_satellites_spawned debe haberse liberado para re-generar el satélite adelante")

	print("  ✓ MainGame: Satélite desespawneado exitosamente al superar 10k px de distancia.")
	main_game.is_exiting_run = true
	main_game.queue_free()
	await get_tree().process_frame

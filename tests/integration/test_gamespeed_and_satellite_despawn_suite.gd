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
	assert(deploy.speed_1x_btn.text.contains("[ 1.0x ]"), "Botón 1x debe estar activo por defecto")
	assert(not deploy.speed_2x_btn.text.contains("["), "Botón 2x debe estar inactivo")
	assert(not deploy.speed_4x_btn.text.contains("["), "Botón 4x debe estar inactivo")

	# Click en botón 2x
	deploy.speed_2x_btn.emit_signal("pressed")
	assert(is_equal_approx(SaveManager.get_game_speed(), 2.0), "Debe cambiar a 2x tras click")
	assert(not deploy.speed_1x_btn.text.contains("["), "Botón 1x debe quedar inactivo")
	assert(deploy.speed_2x_btn.text.contains("[ 2.0x ]"), "Botón 2x debe ser el único activo")
	assert(not deploy.speed_4x_btn.text.contains("["), "Botón 4x debe quedar inactivo")

	# Click en botón 4x
	deploy.speed_4x_btn.emit_signal("pressed")
	assert(is_equal_approx(SaveManager.get_game_speed(), 4.0), "Debe cambiar a 4x tras click")
	assert(not deploy.speed_1x_btn.text.contains("["), "Botón 1x debe estar inactivo")
	assert(not deploy.speed_2x_btn.text.contains("["), "Botón 2x debe estar inactivo")
	assert(deploy.speed_4x_btn.text.contains("[ 4.0x ]"), "Botón 4x debe ser el único activo")

	# Click en botón 1x
	deploy.speed_1x_btn.emit_signal("pressed")
	assert(is_equal_approx(SaveManager.get_game_speed(), 1.0), "Debe volver a 1x")
	assert(deploy.speed_1x_btn.text.contains("[ 1.0x ]"), "Botón 1x activo")
	assert(not deploy.speed_2x_btn.text.contains("["), "Botón 2x inactivo")
	assert(not deploy.speed_4x_btn.text.contains("["), "Botón 4x inactivo")

	deploy.queue_free()
	await get_tree().process_frame

	# Verificar que al entrar al Hub la velocidad siempre se resetea a 1x (incluso si venía en 4x)
	SaveManager.set_game_speed(4.0)
	assert(is_equal_approx(SaveManager.get_game_speed(), 4.0), "Velocidad previa configurada en 4x")
	assert(is_equal_approx(Engine.time_scale, 4.0), "Engine.time_scale en 4.0 antes del Hub")
	var hub_scene = load("res://scenes/ui/hub/hub_world.tscn")
	var hub = hub_scene.instantiate()
	add_child(hub)
	await get_tree().process_frame
	assert(is_equal_approx(SaveManager.get_game_speed(), 1.0), "SaveManager debe restablecer la velocidad a 1x al inicializar el Hub")
	assert(is_equal_approx(Engine.time_scale, 1.0), "Engine.time_scale debe restablecerse a 1.0 al inicializar el Hub")
	hub.queue_free()
	await get_tree().process_frame

	print("  ✓ Deployment Menu (CharacterSelect) y HubWorld: Radio buttons y reseteo forzoso a 1x en el Hub verificados.")

func _test_satellite_10k_despawn() -> void:
	print("\n[3/3] Testing Satellite Persistence & Odometer System in MainGame...")
	var main_game_scene = load("res://scenes/combat/main_game.tscn")
	var main_game: MainGame = main_game_scene.instantiate() as MainGame
	add_child(main_game)

	var timer = get_tree().create_timer(0.3)
	await timer.timeout

	# Generar satélite inicial si no existe
	if main_game.satellite_coordinator and main_game.current_satellite == null:
		main_game.satellite_coordinator.spawn_next_satellite_ahead()

	assert(main_game.current_satellite != null, "Debe existir un satélite en curso")
	var sat = main_game.current_satellite

	# Posicionar satélite en (0, 0)
	sat.global_position = Vector2.ZERO

	# Jugador a 5,000 unidades de distancia: NO debe desespawnear
	main_game.player.global_position = Vector2(5000.0, 0.0)
	main_game._check_satellite_despawn()
	assert(main_game.current_satellite != null, "A 5k px el satélite debe permanecer activo")

	# Jugador a 10,001 unidades de distancia (> 10k px): según nuevo balance, TAMPOCO desespawnea por distancia
	main_game.player.global_position = Vector2(10050.0, 0.0)
	main_game._check_satellite_despawn()
	assert(main_game.current_satellite != null and is_instance_valid(main_game.current_satellite), "El satélite NO debe desespawnear por distancia; permanece en el mundo")

	print("  ✓ MainGame: Satélite persistente verificado (no sufre despawn prematuro por alejamiento).")
	main_game.is_exiting_run = true
	main_game.queue_free()
	await get_tree().process_frame


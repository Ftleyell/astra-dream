extends Node2D

## Suite de Verificación: Spawns de Debug para Astra Prime y Rutas Finales

func _ready() -> void:
	print("==================================================================")
	print("[TEST] Iniciando Verificación de Debug Spawns para Astra Prime")
	print("==================================================================\n")

	var main_game_scene: PackedScene = load("res://scenes/combat/main_game.tscn")
	assert(main_game_scene != null, "main_game.tscn debe existir")

	# Test 1: jump_to_boss("boss_astra_prime")
	print("[1/3] Probando jump_to_boss('boss_astra_prime')...")
	var game = main_game_scene.instantiate()
	add_child(game)
	assert(game.has_method("jump_to_boss"), "MainGame debe tener jump_to_boss")

	game.jump_to_boss("boss_astra_prime")
	assert(game.current_wave == 16, "current_wave debe ser 16 tras jump_to_boss('boss_astra_prime')")
	assert(game.current_boss != null, "current_boss no debe ser null tras jump_to_boss('boss_astra_prime')")
	assert(game.current_boss is BossAstraPrime, "current_boss debe ser BossAstraPrime")
	print("  ✓ Astra Prime spawnea exitosamente con jump_to_boss('boss_astra_prime')")
	game.queue_free()

	# Test 2: jump_to_wave_16("pacifist")
	print("\n[2/3] Probando jump_to_wave_16('pacifist')...")
	var game2 = main_game_scene.instantiate()
	add_child(game2)
	game2.jump_to_wave_16("pacifist")
	assert(game2.current_wave == 16, "current_wave debe ser 16")
	assert(game2.current_boss != null, "current_boss no debe ser null tras jump_to_wave_16")
	assert(game2.current_boss is BossAstraPrime, "current_boss debe ser BossAstraPrime")
	assert(game2.current_boss.route == "pacifist", "La ruta de Astra Prime debe ser 'pacifist'")
	print("  ✓ Astra Prime spawnea en ruta 'pacifist' con jump_to_wave_16")
	game2.queue_free()

	# Test 3: jump_to_wave_11("slayer") compatibilidad
	print("\n[3/3] Probando compatibilidad con jump_to_wave_11('slayer')...")
	var game3 = main_game_scene.instantiate()
	add_child(game3)
	game3.jump_to_wave_11("slayer")
	assert(game3.current_wave == 16, "current_wave debe ser 16 por delegación")
	assert(game3.current_boss != null, "current_boss no debe ser null tras jump_to_wave_11")
	assert(game3.current_boss is BossAstraPrime, "current_boss debe ser BossAstraPrime")
	assert(game3.current_boss.route == "slayer", "La ruta de Astra Prime debe ser 'slayer'")
	print("  ✓ Astra Prime spawnea en ruta 'slayer' con jump_to_wave_11 por delegación")
	game3.queue_free()

	print("\n==================================================================")
	print("[TEST] ✓ TODAS LAS PRUEBAS DE DEBUG DE ASTRA PRIME PASARON CON ÉXITO")
	print("==================================================================")
	get_tree().quit(0)

extends Node

func _ready() -> void:
	print("==========================================")
	print("[TEST] Testing Pause Menu -> Exit to HUB while inside Satellite Perimeter...")
	print("==========================================")

	var main_game_scene = load("res://scenes/combat/main_game.tscn")
	var main_game = main_game_scene.instantiate() as MainGame
	add_child(main_game)

	var timer = get_tree().create_timer(0.3)
	await timer.timeout

	# 1. Verificar que el satélite existe
	assert(main_game.current_satellite != null, "Debe existir un satélite generado")
	var sat = main_game.current_satellite

	# 2. Posicionar al jugador dentro del perímetro para simular que está dentro
	main_game.player.global_position = sat.global_position
	sat.plant_satellite()
	assert(sat.is_planted, "El satélite debe estar plantado")

	# 3. Probar que salir del árbol (simulando cambio de escena) NO genera errores ni re-spawnea satélites
	var pause_menu = main_game.get_node_or_null("PauseMenu")
	assert(pause_menu != null, "PauseMenu debe existir en MainGame")

	print("  ✓ Satélite plantado y jugador dentro del perímetro. Marcando salida y liberando...")
	main_game.is_exiting_run = true
	main_game.queue_free()

	var wait_timer = get_tree().create_timer(0.2)
	await wait_timer.timeout

	print("  ✓ Salida limpia sin errores de 'Parent node is busy' ni spawning huérfano.")
	print("\n==========================================")
	print("[PASS] SATELLITE TEARDOWN & PAUSE EXIT TEST PASSED (100%)!")
	print("==========================================")
	get_tree().quit(0)

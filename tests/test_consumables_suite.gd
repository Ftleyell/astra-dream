extends Node2D

func _ready() -> void:
	print("==========================================")
	print("[TEST] Testing Field Consumables (Heal, Magnet, Bomb)...")
	print("==========================================\n")

	# 1. Instanciar MainGame
	var main_scene: PackedScene = load("res://scenes/combat/main_game.tscn")
	assert(main_scene != null, "main_game.tscn debe existir")
	var main_game: MainGame = main_scene.instantiate() as MainGame
	add_child(main_game)

	if Dialogic:
		Dialogic.end_timeline()
	main_game.is_briefing_active = false
	get_tree().paused = false

	var player := main_game.player
	var stats := player.stats
	var bullet_server := main_game.bullet_server
	assert(player != null and stats != null and bullet_server != null, "Subsistemas de juego requeridos deben existir")

	var consumable_scene: PackedScene = load("res://scenes/combat/pickups/field_consumable.tscn")
	assert(consumable_scene != null, "field_consumable.tscn debe existir")
	var consumable_script = preload("res://scenes/combat/pickups/field_consumable.gd")

	# --- TEST 1: CÁPSULA DE CURACIÓN (HEAL) ---
	print("[1/5] Testing Heal Consumable (+25 HP)...")
	var max_hp: float = stats.get_stat(&"max_health")
	player.set_physics_process(false)
	player.current_health = 40.0

	var heal_item = consumable_scene.instantiate()
	main_game.add_child(heal_item)
	heal_item.setup(consumable_script.ConsumableType.HEAL, player.global_position)
	heal_item.collect(player)
	assert(is_equal_approx(player.current_health, 65.0), "Curación de 25 HP sobre 40 HP debe resultar en 65 HP (actual: %s)" % player.current_health)
	print("  ✓ Curación plana verificada: 40.0 -> %0.1f HP (+25.0)" % player.current_health)

	# Probar límite superior con max_health
	player.current_health = max_hp - 10.0
	var heal_cap_item = consumable_scene.instantiate()
	main_game.add_child(heal_cap_item)
	heal_cap_item.setup(consumable_script.ConsumableType.HEAL, player.global_position)
	heal_cap_item.collect(player)
	assert(is_equal_approx(player.current_health, max_hp), "Curación debe respetar el tope estricto de max_health (actual: %s)" % player.current_health)
	print("  ✓ Curación respeta estrictamente max_health (%0.1f HP)" % player.current_health)

	# --- TEST 2: IMÁN GLOBAL (MAGNET) ---
	print("\n[2/5] Testing Global Magnet Consumable...")
	var blob_scene: PackedScene = load("res://scenes/combat/pickups/exp_blob.tscn")
	var distant_blob: ExpBlob = blob_scene.instantiate() as ExpBlob
	main_game.add_child(distant_blob)
	distant_blob.global_position = Vector2(800.0, 800.0) # Muy lejos de la nave

	var magnet_item = consumable_scene.instantiate()
	main_game.add_child(magnet_item)
	magnet_item.setup(consumable_script.ConsumableType.MAGNET, player.global_position)
	magnet_item.collect(player)

	# Verificar que el orbe lejano fue atraído hacia el jugador
	distant_blob._handle_player_magnet(0.05)
	assert(distant_blob.global_position.distance_to(player.global_position) < Vector2(800, 800).distance_to(player.global_position), "El orbe lejano DEBE ser succionado tras activar el imán global")
	print("  ✓ Imán Global verificado: todos los orbes del mapa son succionados hacia la nave")

	# --- TEST 3: BOMBA - ALMACENAMIENTO EN RESERVA (< 5) ---
	print("\n[3/5] Testing Bomb Consumable - Storage in Reserve (<5)...")
	player.bomb_count = 2
	var bomb_item = consumable_scene.instantiate()
	main_game.add_child(bomb_item)
	bomb_item.setup(consumable_script.ConsumableType.BOMB, player.global_position)
	bomb_item.collect(player)
	assert(player.bomb_count == 3, "Con 2 bombas, recoger una debe elevar el stock a 3 (actual: %d)" % player.bomb_count)
	print("  ✓ Bomba guardada en reserva: Stock 2 -> %d" % player.bomb_count)

	# --- TEST 4: BOMBA - DETONACIÓN INMEDIATA AL TOPE (== 5) ---
	print("\n[4/5] Testing Bomb Consumable - Max Capacity Immediate Wipe (==5)...")
	player.bomb_count = 5
	# Generar ráfaga de balas en pantalla
	bullet_server.fire_radial_ring(Vector2(200, 200), 24, 150.0)
	assert(bullet_server.active_count > 0, "Debe haber balas hostiles en pantalla para la prueba")
	var prev_bullets: int = bullet_server.active_count
	print("  • Balas hostiles activas en pantalla: %d" % prev_bullets)

	var bomb_wipe_item = consumable_scene.instantiate()
	main_game.add_child(bomb_wipe_item)
	bomb_wipe_item.setup(consumable_script.ConsumableType.BOMB, player.global_position)
	bomb_wipe_item.collect(player)
	assert(player.bomb_count == 5, "El stock no debe exceder 5")
	assert(bullet_server.active_count == 0, "Al tope de bombas, recoger una debe detonar screen-wipe inmediato (0 balas)")
	print("  ✓ Al tope (5 bombas): Detonación automática ejecutada, %d balas destruidas instantáneamente" % prev_bullets)

	# --- TEST 5: INMUNIDAD AL IMÁN REGULAR Y PARPADEO ---
	print("\n[5/5] Testing Static Ground Placement & Warning Blink...")
	var static_item = consumable_scene.instantiate()
	main_game.add_child(static_item)
	var spawn_spot := player.global_position + Vector2(150.0, 0.0)
	static_item.setup(consumable_script.ConsumableType.HEAL, spawn_spot)

	# Simular 10 frames de física: NO debe moverse hacia el jugador
	for i in range(10):
		static_item._physics_process(0.016)
	assert(static_item.global_position.is_equal_approx(spawn_spot), "El consumible de campo debe ser estático y no verse atraído por el imán regular")
	print("  ✓ Consumible permanece estático en el suelo (no succionado por magnetismo)")

	# Probar parpadeo en los últimos 8 segundos (> 37s)
	static_item.current_lifetime = 38.0
	static_item._physics_process(0.016)
	assert(static_item.modulate.a < 1.0, "En los últimos 8s debe parpadear para advertir de su expiración")
	print("  ✓ Secuencia de parpadeo de advertencia activa antes de desaparecer")

	print("\n==========================================")
	print(">>> ALL FIELD CONSUMABLES TESTS PASSED (100%) <<<")
	print("==========================================\n")
	get_tree().quit(0)

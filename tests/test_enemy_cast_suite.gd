extends Node2D

func _ready() -> void:
	print("==========================================")
	print("[TEST] Testing 4 Basic Enemies Cast & High Density Spawner...")
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
	var bullet_server := main_game.bullet_server
	var spawner := main_game.enemy_spawner
	assert(player != null and bullet_server != null and spawner != null, "Subsistemas deben existir")

	# --- TEST 1: VERIFICACIÓN DE STATS DE LOS 4 ENEMIGOS ---
	print("[1/5] Verifying 4 Enemy Archetypes & Stats...")

	var drone_scene: PackedScene = load("res://scenes/combat/enemies/enemy_drone.tscn")
	var kamikaze_scene: PackedScene = load("res://scenes/combat/enemies/enemy_kamikaze.tscn")
	var tank_scene: PackedScene = load("res://scenes/combat/enemies/enemy_tank.tscn")
	var shooter_scene: PackedScene = load("res://scenes/combat/enemies/enemy_shooter.tscn")

	assert(drone_scene != null, "drone_scene debe existir")
	assert(kamikaze_scene != null, "kamikaze_scene debe existir")
	assert(tank_scene != null, "tank_scene debe existir")
	assert(shooter_scene != null, "shooter_scene debe existir")

	var drone = drone_scene.instantiate()
	var kamikaze = kamikaze_scene.instantiate()
	var tank = tank_scene.instantiate()
	var shooter = shooter_scene.instantiate()

	main_game.add_child(drone)
	main_game.add_child(kamikaze)
	main_game.add_child(tank)
	main_game.add_child(shooter)

	# Stats Drone
	assert(drone.max_health == 30.0, "Drone max_health debe ser 30.0")
	assert(drone.move_speed == 160.0, "Drone move_speed debe ser 160.0")
	assert(drone.contact_damage == 10.0, "Drone contact_damage debe ser 10.0")
	assert(drone.exp_reward == 15.0 and drone.credits_reward == 1, "Drone rewards correctos")
	print("  ✓ Drone Enjambre verificado: HP 30, Vel 160, Daño 10, Recompensa 1C/15XP")

	# Stats Kamikaze
	assert(kamikaze.max_health == 20.0, "Kamikaze max_health debe ser 20.0")
	assert(kamikaze.move_speed == 220.0, "Kamikaze move_speed debe ser 220.0")
	assert(kamikaze.contact_damage == 18.0, "Kamikaze contact_damage debe ser 18.0")
	assert(kamikaze.exp_reward == 20.0 and kamikaze.credits_reward == 2, "Kamikaze rewards correctos")
	print("  ✓ Kamikaze Asalto verificado: HP 20, Vel 220, Daño 18, Recompensa 2C/20XP")

	# Stats Tanque
	assert(tank.max_health == 180.0, "Tanque max_health debe ser 180.0")
	assert(tank.move_speed == 85.0, "Tanque move_speed debe ser 85.0")
	assert(tank.contact_damage == 25.0, "Tanque contact_damage debe ser 25.0")
	assert(tank.exp_reward == 75.0 and tank.credits_reward == 8, "Tanque rewards correctos")
	print("  ✓ Crucero Tanque verificado: HP 180, Vel 85, Daño 25, Recompensa 8C/75XP")

	# Stats Artillero
	assert(shooter.max_health == 45.0, "Shooter max_health debe ser 45.0")
	assert(shooter.move_speed == 130.0, "Shooter move_speed debe ser 130.0")
	assert(shooter.contact_damage == 12.0, "Shooter contact_damage debe ser 12.0")
	assert(shooter.exp_reward == 40.0 and shooter.credits_reward == 4, "Shooter rewards correctos")
	print("  ✓ Artillero Danmaku verificado: HP 45, Vel 130, Daño 12, Recompensa 4C/40XP")

	# --- TEST 2: COMPORTAMIENTO DE SOBRECARGA KAMIKAZE ---
	print("\n[2/5] Testing Kamikaze Overcharge Dive Behavior...")
	player.global_position = Vector2.ZERO
	kamikaze.global_position = Vector2(200.0, 0.0) # Dentro de DIVE_DISTANCE (260px)
	assert(not kamikaze.is_diving, "Inicialmente is_diving debe ser falso")
	kamikaze._physics_process(0.016)
	assert(kamikaze.is_diving, "A 200px del jugador, Kamikaze DEBE entrar en modo embestida (is_diving = true)")
	assert(is_equal_approx(kamikaze.velocity.length(), 360.0), "Velocidad de embestida debe ser 360 px/s (actual: %s)" % kamikaze.velocity.length())
	print("  ✓ Embestida de Kamikaze activada a 360 px/s")

	# --- TEST 3: COMPORTAMIENTO DE DISPARO DANMAKU DEL ARTILLERO ---
	print("\n[3/5] Testing Shooter Danmaku Salvo...")
	bullet_server.bomb_clear_all()
	shooter.global_position = Vector2(450.0, 0.0)
	shooter.shoot_timer = 0.01
	shooter._physics_process(0.02)
	assert(bullet_server.active_count == 3, "El Artillero debe haber disparado una salva de 3 proyectiles (actual: %d)" % bullet_server.active_count)
	print("  ✓ Artillero Danmaku dispara salva de 3 proyectiles dirigidos en abanico")
	bullet_server.bomb_clear_all()

	# --- TEST 4: COMPORTAMIENTO DEL TANQUE (ABSORCIÓN Y DAÑO) ---
	print("\n[4/5] Testing Tank Damage Absorption & Defeat Rewards...")
	var initial_credits: int = player.run_credits
	tank.take_damage(50.0)
	assert(tank.current_health == 130.0, "Tras 50 de daño el tanque debe tener 130 HP")
	print("  ✓ Tanque absorbe 50.0 de daño y permanece en combate con 130.0 HP")
	tank.take_damage(130.0)
	assert(tank.is_dying, "Tanque debe morir al llegar a 0 HP")
	assert(player.run_credits == initial_credits + 8, "Derrotar al tanque debe otorgar +8 Créditos")
	print("  ✓ Muerte del Tanque otorga +8 Créditos al jugador")

	# --- TEST 5: SPAWNER DE ALTA DENSIDAD Y CLÚSTERES ---
	print("\n[5/5] Testing High Density Enemy Spawner Limits & Swarm Rush...")
	spawner.set_wave(1)
	assert(spawner.max_enemies == 80, "Oleada 1 debe tener tope de 80 enemigos (actual: %d)" % spawner.max_enemies)

	spawner.set_wave(2)
	assert(spawner.max_enemies == 120, "Oleada 2 debe tener tope de 120 enemigos (actual: %d)" % spawner.max_enemies)

	spawner.set_wave(3)
	assert(spawner.max_enemies == 160, "Oleada 3 debe tener tope de 160 enemigos (actual: %d)" % spawner.max_enemies)

	spawner.set_wave(5)
	assert(spawner.max_enemies == 250, "Oleada 5 debe tener tope de 250 enemigos (actual: %d)" % spawner.max_enemies)
	print("  ✓ Escalamiento de densidad de enemigos por oleada: 80 -> 120 -> 160 -> 250+")

	# Probar evento de enjambre súbito (Swarm Rush)
	var prev_enemy_count := get_tree().get_nodes_in_group("enemies").size()
	spawner._trigger_swarm_rush()
	var new_enemy_count := get_tree().get_nodes_in_group("enemies").size()
	assert(new_enemy_count >= prev_enemy_count + 10, "Swarm rush debe generar un lote masivo de drones simultáneos")
	print("  ✓ Evento de Enjambre Repentino (Swarm Rush) genera +%d drones coordinados" % (new_enemy_count - prev_enemy_count))

	print("\n==========================================")
	print(">>> ALL 4 ENEMIES & HIGH DENSITY TESTS PASSED (100%) <<<")
	print("==========================================\n")
	get_tree().quit(0)

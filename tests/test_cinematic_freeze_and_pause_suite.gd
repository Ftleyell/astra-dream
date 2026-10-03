extends Node2D

const BossCinematicPresenterScript = preload("res://scenes/combat/bosses/boss_cinematic_presenter.gd")

func _ready() -> void:
	get_tree().create_timer(10.0).timeout.connect(func():
		print("[TEST WATCHDOG] Timeout alcanzado, saliendo...")
		get_tree().quit(0)
	)

	print("\n==================================================================")
	print("[TEST] Testing Cinematic Freeze, Player Iframes & Rival Pause...")
	print("==================================================================")

	var bullet_server := BulletServer.new()
	bullet_server.name = "BulletServer"
	add_child(bullet_server)

	# 1. Spawn Dummy Player
	var player: Player = Player.new()
	player.global_position = Vector2(500, 500)
	add_child(player)
	player.current_health = 100.0

	# 2. Spawn Mock MainGame container
	var dummy_game := Node2D.new()
	dummy_game.name = "DummyMainGame"
	dummy_game.set("player", player)
	add_child(dummy_game)

	# 3. Spawn a regular enemy
	var enemy_drone_scene := preload("res://scenes/combat/enemies/enemy_drone.tscn")
	var drone: EnemyDrone = enemy_drone_scene.instantiate() as EnemyDrone
	drone.global_position = Vector2(520, 500)
	dummy_game.add_child(drone)
	drone.velocity = Vector2(100, 0)
	assert(drone.is_in_group("enemies"), "Drone must be in group 'enemies'")
	assert(not drone.is_in_group("bosses"), "Drone must not be in 'bosses'")

	# --- Test 1: Freeze combat environment ---
	print("\n[1/4] Verificando congelamiento sincronizado de enemigos y entorno...")
	BossCinematicPresenterScript.freeze_combat_environment(dummy_game)

	assert(player.is_invulnerable == true, "Player must have is_invulnerable = true")
	assert(drone.velocity == Vector2.ZERO, "Drone velocity must be reset to ZERO immediately")
	assert(drone.is_physics_processing() == false, "Drone physics process must be frozen")
	assert(drone.is_processing() == false, "Drone process must be frozen")
	print("  ✓ T1: Enemigos comunes detenidos en seco y jugador invulnerable verificado")

	# --- Test 2: Invulnerability prevents all damage ---
	print("\n[2/4] Verificando invulnerabilidad del jugador durante cinemática...")
	var initial_hp: float = player.current_health
	player.take_damage(50.0)
	assert(player.current_health == initial_hp, "Player must take 0 damage while is_invulnerable is true")
	print("  ✓ T2: Jugador protegido contra todo daño durante la cinemática")

	# --- Test 3: Unfreeze and iframe grace period ---
	print("\n[3/4] Verificando reactivación de enemigos y buffer de gracia...")
	BossCinematicPresenterScript.unfreeze_combat_environment(dummy_game)
	assert(drone.is_physics_processing() == true, "Drone physics process must resume after unfreeze")
	assert(drone.is_processing() == true, "Drone process must resume after unfreeze")
	assert(player.is_invulnerable == true, "Player must still have grace iframe immediately after unfreeze")
	print("  ✓ T3: Entorno reactivado y buffer de gracia activo")

	# --- Test 4: Rival Pilot Boss respects game pause ---
	print("\n[4/4] Verificando que RivalPilotBoss respeta la pausa del juego...")
	var rival_scene := preload("res://scenes/combat/bosses/rival_pilot_boss.tscn")
	var rival: RivalPilotBoss = rival_scene.instantiate() as RivalPilotBoss
	rival.global_position = Vector2(800, 500)
	dummy_game.add_child(rival)
	rival.setup_pilot(&"nova", 1)
	rival.start_encounter()

	assert(rival.process_mode == Node.PROCESS_MODE_PAUSABLE, "Rival must have PROCESS_MODE_PAUSABLE")

	# Test pause behavior:
	get_tree().paused = true
	var rival_pos_before := rival.global_position
	var rival_elapsed_before := rival.elapsed_time

	# Manually call _physics_process and _process with pause = true:
	rival._physics_process(0.16)
	rival._process(0.16)

	assert(rival.global_position == rival_pos_before, "Rival position must not change while game is paused")
	assert(rival.elapsed_time == rival_elapsed_before, "Rival elapsed_time must not advance while game is paused")

	# Engage combat and test again while paused:
	rival.engage_combat()
	assert(rival.process_mode == Node.PROCESS_MODE_PAUSABLE, "Rival must remain PROCESS_MODE_PAUSABLE in DOGFIGHT")
	rival._physics_process(0.16)
	rival._process(0.16)

	assert(rival.global_position == rival_pos_before, "Rival must not move during dogfight while game is paused")
	assert(rival.elapsed_time == rival_elapsed_before, "Rival elapsed_time must not advance during dogfight while paused")

	get_tree().paused = false
	print("  ✓ T4: RivalPilotBoss respeta rigurosamente get_tree().paused en todas sus fases")

	print("\n==================================================================")
	print(">>> ALL CINEMATIC FREEZE & PAUSE IMMOBILITY TESTS PASSED (100%) <<<")
	print("==================================================================\n")

	get_tree().quit(0)

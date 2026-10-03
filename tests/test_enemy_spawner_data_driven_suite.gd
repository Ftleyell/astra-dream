extends Node

var total_tests: int = 0
var passed_tests: int = 0

func _ready() -> void:
	print("\n==================================================================")
	print("[TEST] INITIATING DATA-DRIVEN ENEMY SPAWNER VERIFICATION")
	print("==================================================================")

	_test_1_wave_spawn_config_picking()
	_test_2_wave_schedule_config_lookup()
	_test_3_spawner_wave_calibration()
	_test_4_scene_selection_data_driven()
	_test_5_enemy_node_pool_recycling()

	print("\n==================================================================")
	print("  TOTAL VERIFIED TEST SUITES: %d/%d PASSED" % [passed_tests, total_tests])
	if passed_tests == total_tests:
		print("[PASS] 100% SUITE COMPLIANCE — DATA-DRIVEN ENEMY SPAWNER VERIFIED!")
	else:
		printerr("[FAIL] Data-Driven Enemy Spawner Verification Failed!")
	print("==================================================================\n")

	await get_tree().create_timer(0.2).timeout
	get_tree().quit(0 if passed_tests == total_tests else 1)

func _test_1_wave_spawn_config_picking() -> void:
	total_tests += 1
	print("\n--- TEST 1: WaveSpawnConfig Weighted Enemy Selection ---")
	var cfg := WaveSpawnConfig.new()
	cfg.drone_weight = 100.0
	cfg.kamikaze_weight = 0.0
	cfg.micro_flock_weight = 0.0
	cfg.shooter_weight = 0.0
	cfg.tank_weight = 0.0
	cfg.splitter_weight = 0.0

	for i in range(10):
		var picked := cfg.pick_enemy_type()
		assert(picked == &"drone", "With 100% drone weight, must pick drone")

	cfg.drone_weight = 0.0
	cfg.tank_weight = 100.0
	for i in range(10):
		var picked_tank := cfg.pick_enemy_type()
		assert(picked_tank == &"tank", "With 100% tank weight, must pick tank")

	passed_tests += 1
	print("  ✓ T1: WaveSpawnConfig weighted random selection verified")

func _test_2_wave_schedule_config_lookup() -> void:
	total_tests += 1
	print("\n--- TEST 2: WaveScheduleConfig Lookup & Fallback ---")
	var sched := load("res://data/balance/default_wave_schedule.tres") as WaveScheduleConfig
	assert(sched != null, "default_wave_schedule.tres must exist")

	var w1 := sched.get_config_for_wave(1)
	assert(w1 != null and w1.wave_number == 1, "Wave 1 config must be found")
	assert(w1.max_enemies == 50, "Wave 1 max_enemies must be 50")
	assert(w1.base_spawn_interval == 1.2, "Wave 1 base_spawn_interval must be 1.2")

	var w2 := sched.get_config_for_wave(2)
	assert(w2 != null and w2.wave_number == 2, "Wave 2 config must be found")
	assert(w2.max_enemies == 65, "Wave 2 max_enemies must be 65")

	# Oleada no explícita usa fallback
	var w99 := sched.get_config_for_wave(99)
	assert(w99 != null, "Fallback config must be returned for unlisted wave")
	assert(w99.max_enemies == 80, "Fallback max_enemies must be 80")

	passed_tests += 1
	print("  ✓ T2: WaveScheduleConfig lookup and fallback behavior verified")

func _test_3_spawner_wave_calibration() -> void:
	total_tests += 1
	print("\n--- TEST 3: EnemySpawner Calibration via set_wave ---")
	var spawner := EnemySpawner.new()
	add_child(spawner)

	spawner.set_wave(1)
	assert(spawner.max_enemies == 50, "Wave 1 spawner max_enemies must be 50, got %d" % spawner.max_enemies)
	assert(spawner.base_spawn_interval == 1.2, "Wave 1 interval must be 1.2")
	assert(spawner.current_wave_config != null and spawner.current_wave_config.wave_number == 1)

	spawner.set_wave(3)
	assert(spawner.max_enemies == 75, "Wave 3 spawner max_enemies must be 75, got %d" % spawner.max_enemies)
	assert(spawner.base_spawn_interval == 0.85, "Wave 3 interval must be 0.85")

	spawner.set_wave(16)
	assert(spawner.max_enemies == 80, "Wave 16 spawner max_enemies must be 80, got %d" % spawner.max_enemies)

	spawner.queue_free()
	passed_tests += 1
	print("  ✓ T3: EnemySpawner set_wave data-driven calibration verified")

func _test_4_scene_selection_data_driven() -> void:
	total_tests += 1
	print("\n--- TEST 4: EnemySpawner Scene Selection ---")
	var spawner := EnemySpawner.new()
	add_child(spawner)

	spawner.set_wave(1)
	for i in range(20):
		var scene: PackedScene = spawner.call("_select_enemy_scene")
		assert(scene != null, "Selected enemy scene must not be null")
		# En wave 1 solo hay drones, kamikazes y micro flocks
		assert(scene == spawner.drone_scene or scene == spawner.kamikaze_scene or scene == spawner.micro_flock_scene,
			"Wave 1 must only produce drones, kamikazes or micro flocks")

	spawner.queue_free()
	passed_tests += 1
	print("  ✓ T4: Data-driven enemy scene selection verified across repeated iterations")

func _test_5_enemy_node_pool_recycling() -> void:
	total_tests += 1
	print("\n--- TEST 5: EnemyNodePool Zero-Allocation Recycling ---")
	var spawner := EnemySpawner.new()
	add_child(spawner)

	assert(spawner.enemy_pool != null, "EnemySpawner must have enemy_pool initialized")

	var dummy_pos1 := Vector2(100.0, 200.0)
	var e1: Node2D = spawner.call("_spawn_enemy_at", spawner.drone_scene, dummy_pos1)
	assert(e1 != null, "Spawned enemy 1 must not be null")
	assert(e1.global_position == dummy_pos1, "Spawned enemy 1 position must match")
	assert(e1.is_in_group("enemies"), "Enemy 1 must be in enemies group")

	var id1 := e1.get_instance_id()

	# Reciclar e1
	spawner.enemy_pool.call("recycle_enemy", e1)
	assert(not e1.visible, "Recycled enemy must be invisible")
	assert(e1.process_mode == Node.PROCESS_MODE_DISABLED, "Recycled enemy must be process disabled")
	assert(not e1.is_in_group("enemies"), "Recycled enemy must be removed from enemies group")

	# Re-adquirir enemigo de la misma escena
	var dummy_pos2 := Vector2(300.0, 400.0)
	var e2: Node2D = spawner.call("_spawn_enemy_at", spawner.drone_scene, dummy_pos2)
	assert(e2 != null, "Re-acquired enemy must not be null")
	assert(e2.get_instance_id() == id1, "Re-acquired enemy must reuse previous instance ID (Zero-Allocation)")
	assert(e2.global_position == dummy_pos2, "Re-acquired enemy position must be updated")
	assert(e2.visible, "Re-acquired enemy must be visible")
	assert(e2.process_mode == Node.PROCESS_MODE_PAUSABLE, "Re-acquired enemy must be process pausable")
	assert(e2.is_in_group("enemies"), "Re-acquired enemy must be re-added to enemies group")

	spawner.enemy_pool.call("clear_all")
	spawner.queue_free()
	passed_tests += 1
	print("  ✓ T5: Zero-Allocation EnemyNodePool recycling verified (instance reuse 100%)")

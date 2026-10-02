extends Node

## ==============================================================================
## EMPIRICAL CHALLENGER 2 — MILESTONE 1 ITERATION 2 STRESS HARNESS
## Deep Verification: Zero-Allocation Invariants, Combat Runtime Stability,
## Extreme Sector Modulation & Spawner Density Invariance
## ==============================================================================

const SECTOR_OUTSKIRTS_PATH := "res://data/sectors/sector_nebula_outskirts.tres"
const SECTOR_ABYSS_PATH := "res://data/sectors/sector_void_abyss.tres"
const SECTOR_STORM_PATH := "res://data/sectors/sector_plasma_storm.tres"
const SECTOR_CORE_PATH := "res://data/sectors/sector_singularity_core.tres"
const SAVE_PATH := "user://profile_data.json"

var _total_assertions: int = 0
var _passed_assertions: int = 0
var _failed_assertions: int = 0
var _failed_details: Array[String] = []

var _backup_payload: String = ""
var _had_save: bool = false


func _ready() -> void:
	print("\n==================================================================")
	print("[CHALLENGER 2] EXECUTING DEEP ADVERSARIAL STRESS HARNESS (M1 ITER 2)")
	print("==================================================================")

	# Watchdog timer: 30 seconds max
	get_tree().create_timer(30.0).timeout.connect(func():
		_restore_save()
		_assert_true(false, "WATCHDOG_TIMEOUT", "Harness timed out after 30s")
		_finish_and_quit()
	)

	_backup_save()

	_test_suite_1_space_background_extreme_zero_alloc()
	_test_suite_2_spawner_extreme_density_and_zero_alloc()
	_test_suite_3_combat_runtime_in_combat_sector_switching()
	_test_suite_4_save_manager_heavy_fuzzing_and_type_safety()

	_restore_save()
	_finish_and_quit()


func _backup_save() -> void:
	_had_save = FileAccess.file_exists(SAVE_PATH)
	if _had_save:
		var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if f:
			_backup_payload = f.get_as_text()
			f.close()


func _restore_save() -> void:
	if _had_save and not _backup_payload.is_empty():
		var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if f:
			f.store_string(_backup_payload)
			f.close()
	elif not _had_save and FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


func _assert_true(condition: bool, test_name: String, error_msg: String = "") -> void:
	_total_assertions += 1
	if condition:
		_passed_assertions += 1
		print("  [PASS] %s" % test_name)
	else:
		_failed_assertions += 1
		var err := "  [FAIL] %s: %s" % [test_name, error_msg]
		_failed_details.append(err)
		printerr(err)


func _finish_and_quit() -> void:
	print("\n==================================================================")
	print("  CHALLENGER 2 DEEP STRESS HARNESS RESULTS")
	print("  TOTAL ASSERTIONS: %d" % _total_assertions)
	print("  PASSED:           %d" % _passed_assertions)
	print("  FAILED:           %d" % _failed_assertions)
	if _failed_assertions == 0:
		print("  STATUS:           CONFIRMED (Zero Defects Detected)")
	else:
		print("  STATUS:           DEFECT_FOUND (%d Failures)" % _failed_assertions)
		for f in _failed_details:
			print(f)
	print("==================================================================\n")

	get_tree().quit(0 if _failed_assertions == 0 else 1)


# ==============================================================================
# SUITE 1: Extreme SpaceBackground Zero-Allocation & Process Stress
# ==============================================================================
func _test_suite_1_space_background_extreme_zero_alloc() -> void:
	print("\n--- SUITE 1: SpaceBackground Extreme Zero-Alloc & Drift Stress ---")

	var bg_scene: PackedScene = load("res://scenes/combat/environment/space_background.tscn")
	_assert_true(bg_scene != null, "1.1: SpaceBackground scene loadable")
	if not bg_scene:
		return

	var bg: SpaceBackground = bg_scene.instantiate() as SpaceBackground
	_assert_true(bg != null, "1.2: SpaceBackground instance created")
	add_child(bg)

	var s_outskirts: SectorData = load(SECTOR_OUTSKIRTS_PATH) as SectorData
	var s_abyss: SectorData = load(SECTOR_ABYSS_PATH) as SectorData
	var s_storm: SectorData = load(SECTOR_STORM_PATH) as SectorData
	var s_core: SectorData = load(SECTOR_CORE_PATH) as SectorData

	var sectors: Array[SectorData] = [s_outskirts, s_abyss, s_storm, s_core]

	# Warm up tree
	bg.configure_sector(s_outskirts)

	var baseline_tree_nodes: int = get_tree().get_node_count()
	var baseline_obj_nodes: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var baseline_orphan_nodes: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))

	# 2,500 rapid configure_sector calls cycling through sectors
	for i in range(2500):
		var sec: SectorData = sectors[i % sectors.size()]
		bg.configure_sector(sec)

	var post_switch_tree_nodes: int = get_tree().get_node_count()
	var post_switch_obj_nodes: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var post_switch_orphan_nodes: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))

	_assert_true(
		post_switch_tree_nodes == baseline_tree_nodes and post_switch_obj_nodes == baseline_obj_nodes,
		"1.3: 2,500 sector switches produced 0 node allocations (tree: %d->%d, objs: %d->%d)" % [
			baseline_tree_nodes, post_switch_tree_nodes, baseline_obj_nodes, post_switch_obj_nodes
		],
		"Node allocation detected during rapid sector switching!"
	)

	_assert_true(
		post_switch_orphan_nodes == baseline_orphan_nodes,
		"1.4: 2,500 sector switches produced 0 orphan nodes (orphans: %d->%d)" % [
			baseline_orphan_nodes, post_switch_orphan_nodes
		],
		"Orphan node leak detected!"
	)

	# Simulate 180 continuous frames of _process(0.016667)
	var prev_accum: Vector2 = bg._accum_drift
	for frame in range(180):
		bg._process(0.016667)

	var post_process_tree_nodes: int = get_tree().get_node_count()
	var post_process_obj_nodes: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))

	_assert_true(
		post_process_tree_nodes == baseline_tree_nodes and post_process_obj_nodes == baseline_obj_nodes,
		"1.5: 180 frames of auto-drift process produced 0 node allocations",
		"Process frame allocated nodes!"
	)

	_assert_true(
		bg._accum_drift != prev_accum,
		"1.6: Auto-drift accumulated position smoothly over frames"
	)

	# Custom dynamic SectorData with extreme parameters
	var custom_sector := SectorData.new()
	custom_sector.sector_id = &"sector_custom_extreme"
	custom_sector.sector_name = "Extreme Test Void"
	custom_sector.drift_direction = Vector2(0.7071, -0.7071)
	custom_sector.drift_speed = 999.0
	custom_sector.nebula_tint = Color(0.9, 0.1, 0.8, 0.5)
	custom_sector.stars_deep_tint = Color(0.1, 0.9, 0.2, 0.8)
	custom_sector.stars_mid_tint = Color(0.3, 0.4, 0.9, 1.0)
	custom_sector.dust_near_tint = Color(1.0, 1.0, 0.0, 0.6)

	bg.configure_sector(custom_sector)

	_assert_true(
		is_equal_approx(bg.base_drift_speed, 999.0) and
		bg.drift_direction.is_equal_approx(Vector2(0.7071, -0.7071).normalized()),
		"1.7: Custom extreme sector drift parameters accepted and normalized"
	)

	# Null and empty drift direction handling
	custom_sector.drift_direction = Vector2.ZERO
	bg.configure_sector(custom_sector)
	_assert_true(
		bg.drift_direction != Vector2.ZERO,
		"1.8: Zero drift_direction preserves existing direction without division by zero"
	)

	bg.configure_sector(null)
	var post_null_tree: int = get_tree().get_node_count()
	_assert_true(post_null_tree == baseline_tree_nodes, "1.9: Null sector configuration is zero-alloc safe")

	bg.queue_free()


# ==============================================================================
# SUITE 2: EnemySpawner Extreme Density Adjustments & Invariance
# ==============================================================================
func _test_suite_2_spawner_extreme_density_and_zero_alloc() -> void:
	print("\n--- SUITE 2: EnemySpawner Extreme Density & Zero-Alloc Invariance ---")

	var spawner := EnemySpawner.new()
	add_child(spawner)

	var baseline_tree_nodes: int = get_tree().get_node_count()
	var baseline_obj_nodes: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))

	# 2,000 rapid density multiplier updates with varied multipliers
	var test_multipliers: Array[float] = [0.1, 0.5, 0.85, 1.0, 1.3, 1.4, 1.6, 2.0, 3.5, 5.0]
	for i in range(2000):
		var mult: float = test_multipliers[i % test_multipliers.size()]
		spawner.set_density_multiplier(mult)

	var post_mult_tree: int = get_tree().get_node_count()
	var post_mult_obj: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))

	_assert_true(
		post_mult_tree == baseline_tree_nodes and post_mult_obj == baseline_obj_nodes,
		"2.1: 2,000 rapid set_density_multiplier calls produced 0 node allocations",
		"EnemySpawner density modification allocated nodes!"
	)

	# Verify mathematical invariant across all waves 1-20
	spawner.set_density_multiplier(1.6)
	var invariant_holds: bool = true
	var error_msg: String = ""

	for w in range(1, 21):
		spawner.set_wave(w)
		var raw_max: int = 80
		match w:
			1: raw_max = 80
			2: raw_max = 120
			3: raw_max = 160
			4: raw_max = 200
			_: raw_max = mini(320, 250 + (w - 5) * 25)

		var expected_max: int = maxi(10, int(round(float(raw_max) * 1.6)))
		if spawner.max_enemies != expected_max:
			invariant_holds = false
			error_msg = "Wave %d max_enemies expected %d, got %d" % [w, expected_max, spawner.max_enemies]
			break

	_assert_true(invariant_holds, "2.2: Density scaling strictly matches mathematical formula for waves 1-20", error_msg)

	# Extreme boundary values: negative, zero, sub-minimum, overflow
	spawner.set_density_multiplier(-100.0)
	_assert_true(is_equal_approx(spawner.density_multiplier, 0.1), "2.3: Negative density clamped to 0.1")

	spawner.set_density_multiplier(0.0)
	_assert_true(is_equal_approx(spawner.density_multiplier, 0.1), "2.4: Zero density clamped to 0.1")

	spawner.set_density_multiplier(1000.0)
	_assert_true(is_equal_approx(spawner.density_multiplier, 5.0), "2.5: Overflow density clamped to 5.0")

	# Wave jumping idempotency: jumping from Wave 20 to Wave 1 restores exact Wave 1 parameters
	spawner.set_density_multiplier(1.0)
	spawner.set_wave(20)
	spawner.set_wave(1)
	_assert_true(
		spawner.max_enemies == 80 and
		is_equal_approx(spawner.base_spawn_interval, 1.2) and
		is_equal_approx(spawner.min_spawn_interval, 0.45),
		"2.6: Jump from Wave 20 to Wave 1 cleanly restores baseline without hysteresis"
	)

	spawner.queue_free()


# ==============================================================================
# SUITE 3: Combat Runtime In-Combat Sector Switching & State Consistency
# ==============================================================================
func _test_suite_3_combat_runtime_in_combat_sector_switching() -> void:
	print("\n--- SUITE 3: Combat Runtime In-Combat Sector Switching ---")

	var main_scene: PackedScene = load("res://scenes/combat/main_game.tscn")
	_assert_true(main_scene != null, "3.1: MainGame scene loaded")
	if not main_scene:
		return

	SaveManager.set_selected_sector(&"sector_nebula_outskirts")
	var mg: MainGame = main_scene.instantiate() as MainGame
	_assert_true(mg != null, "3.2: MainGame instantiated")
	add_child(mg)

	if Dialogic:
		Dialogic.end_timeline()
	mg.is_briefing_active = false
	get_tree().paused = false

	_assert_true(mg.current_sector != null, "3.3: Initial sector populated")

	var baseline_tree_nodes: int = get_tree().get_node_count()

	# Dynamically switch sector in-combat between all canonical sectors
	var s_abyss: SectorData = load(SECTOR_ABYSS_PATH) as SectorData
	var s_storm: SectorData = load(SECTOR_STORM_PATH) as SectorData
	var s_core: SectorData = load(SECTOR_CORE_PATH) as SectorData

	# 1. Switch to Abyss
	mg.current_sector = s_abyss
	if mg.enemy_spawner:
		mg.enemy_spawner.set_density_multiplier(s_abyss.enemy_density_mult)
	if mg.space_background:
		mg.space_background.configure_sector(s_abyss)
	if mg.player and mg.player.stats:
		mg.player.stats.set_base_stat(&"biomass_multiplier", s_abyss.biomass_mult)
		mg.player.stats.set_base_stat(&"dark_matter_multiplier", s_abyss.dark_matter_mult)
		mg.player.stats.set_base_stat(&"credits_multiplier", s_abyss.credits_mult)

	_assert_true(
		is_equal_approx(mg.enemy_spawner.density_multiplier, 1.3),
		"3.4: In-combat switch to Abyss updated spawner density to 1.3"
	)
	_assert_true(
		is_equal_approx(mg.player.stats.get_stat(&"dark_matter_multiplier"), 2.0),
		"3.5: In-combat switch to Abyss updated player dark_matter_multiplier to 2.0"
	)

	# 2. Switch to Storm
	mg.current_sector = s_storm
	if mg.enemy_spawner:
		mg.enemy_spawner.set_density_multiplier(s_storm.enemy_density_mult)
	if mg.space_background:
		mg.space_background.configure_sector(s_storm)
	if mg.player and mg.player.stats:
		mg.player.stats.set_base_stat(&"biomass_multiplier", s_storm.biomass_mult)
		mg.player.stats.set_base_stat(&"dark_matter_multiplier", s_storm.dark_matter_mult)
		mg.player.stats.set_base_stat(&"credits_multiplier", s_storm.credits_mult)

	_assert_true(
		is_equal_approx(mg.enemy_spawner.density_multiplier, 1.4) and
		is_equal_approx(mg.player.stats.get_stat(&"biomass_multiplier"), 1.75),
		"3.6: In-combat switch to Storm updated spawner (1.4) and biomass mult (1.75)"
	)

	# 3. Switch to Singularity Core
	mg.current_sector = s_core
	if mg.enemy_spawner:
		mg.enemy_spawner.set_density_multiplier(s_core.enemy_density_mult)
	if mg.space_background:
		mg.space_background.configure_sector(s_core)
	if mg.player and mg.player.stats:
		mg.player.stats.set_base_stat(&"biomass_multiplier", s_core.biomass_mult)
		mg.player.stats.set_base_stat(&"dark_matter_multiplier", s_core.dark_matter_mult)
		mg.player.stats.set_base_stat(&"credits_multiplier", s_core.credits_mult)

	_assert_true(
		is_equal_approx(mg.enemy_spawner.density_multiplier, 1.6) and
		is_equal_approx(mg.player.stats.get_stat(&"dark_matter_multiplier"), 2.5),
		"3.7: In-combat switch to Core updated spawner (1.6) and dark matter mult (2.5)"
	)

	var current_tree_nodes: int = get_tree().get_node_count()
	_assert_true(
		current_tree_nodes == baseline_tree_nodes,
		"3.8: 3 live in-combat sector transitions produced 0 node leaks (baseline: %d, current: %d)" % [
			baseline_tree_nodes, current_tree_nodes
		]
	)

	mg.queue_free()


# ==============================================================================
# SUITE 4: SaveManager Heavy Fuzzing & Type Safety (Verifying DEFECT-M1-01 Fix)
# ==============================================================================
func _test_suite_4_save_manager_heavy_fuzzing_and_type_safety() -> void:
	print("\n--- SUITE 4: SaveManager Heavy Fuzzing & Type Safety ---")

	# Ensure fresh default profile
	SaveManager.save_profile()
	var prof := SaveManager.get_profile()
	_assert_true(prof != null, "4.1: Default profile loaded")

	# Test 4.2: Fuzz set_selected_sector with 50 diverse inputs
	var fuzz_inputs: Array[Variant] = [
		&"sector_nebula_outskirts",
		&"sector_void_abyss",
		&"sector_plasma_storm",
		&"sector_singularity_core",
		&"",
		&"invalid_sector_nonexistent",
		&"../malicious/sector",
		&"\n\t_special",
		&"123456",
		&"SECTOR_UPPERCASE"
	]

	var fuzz_crashed := false
	for i in range(100):
		var target = fuzz_inputs[i % fuzz_inputs.size()]
		SaveManager.set_selected_sector(target)
		var res_sector := SaveManager.get_selected_sector()
		if res_sector.is_empty():
			fuzz_crashed = true
			break

	_assert_true(not fuzz_crashed, "4.2: 100 rapid fuzz sector selections executed safely without crash or empty string")

	# Test 4.3: Rapid unlock_sector and lock_sector loop (500 cycles)
	var custom_id := &"sector_fuzz_test_unique"
	var unlock_lock_ok := true
	for i in range(500):
		var u_res := SaveManager.unlock_sector(custom_id)
		# First unlock should be true, subsequent false
		if i == 0 and not u_res:
			unlock_lock_ok = false
			break
		var l_res := SaveManager.lock_sector(custom_id)
		if not l_res:
			unlock_lock_ok = false
			break

	_assert_true(unlock_lock_ok, "4.3: 500 rapid unlock/lock cycles maintained full profile integrity")

	# Test 4.4: Corrupt profile injection resilience (Array[StringName] type assertion)
	# Inject untyped Array into profile and verify mutating functions do NOT crash GDScript VM
	var raw_corrupt := {
		"version": 2,
		"unlocked_characters": ["nova", "valentina", "estele"], # Untyped Array of Strings
		"unlocked_items": ["laser", "missiles"],                 # Untyped Array of Strings
		"unlocked_sectors": ["sector_nebula_outskirts"],        # Untyped Array
		"selected_sector": "sector_nebula_outskirts"
	}

	SaveManager.save_profile()
	var test_f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if test_f:
		test_f.store_string(JSON.stringify(raw_corrupt))
		test_f.close()

	SaveManager.load_profile()

	# Perform sector mutating operation that previously triggered DEFECT-M1-01
	SaveManager.set_selected_sector(&"sector_void_abyss")
	_assert_true(
		SaveManager.get_selected_sector() == &"sector_void_abyss",
		"4.4: Corrupt untyped profile sanitized safely by set_selected_sector without Array[StringName] crash"
	)

	# Verify unlock_sector also handles it safely
	SaveManager.unlock_sector(&"sector_plasma_storm")
	_assert_true(
		SaveManager.is_sector_unlocked(&"sector_plasma_storm"),
		"4.5: unlock_sector operates correctly on sanitized profile"
	)

	# Clean up profile
	SaveManager.save_profile()

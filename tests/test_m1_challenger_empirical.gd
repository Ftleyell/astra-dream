extends Node

## ==============================================================================
## EMPIRICAL CHALLENGER 2: Milestone 1 Verification Suite
## Focus: SpaceBackground Zero-Alloc, EnemySpawner Density Compounding,
##        MainGame Mid-Run Save/Restore Null-Safety
## ==============================================================================

const SECTOR_OUTSKIRTS_PATH := "res://data/sectors/sector_nebula_outskirts.tres"
const SECTOR_ABYSS_PATH := "res://data/sectors/sector_void_abyss.tres"
const SECTOR_STORM_PATH := "res://data/sectors/sector_plasma_storm.tres"
const SECTOR_CORE_PATH := "res://data/sectors/sector_singularity_core.tres"

var _passed_count: int = 0
var _failed_count: int = 0
var _test_log: Array[String] = []

func _ready() -> void:
	# Watchdog timeout to prevent hang
	get_tree().create_timer(30.0).timeout.connect(func():
		_log_fail("WATCHDOG", "Test suite execution timed out after 30 seconds!")
		_finish_and_quit()
	)

	print("\n==================================================================")
	print("[CHALLENGER 2] STARTING EMPIRICAL VERIFICATION FOR MILESTONE 1")
	print("==================================================================")

	# Clean initial state
	SaveManager.is_resuming_run = false
	SaveManager.clear_active_run()

	_run_suite_1_space_background_zero_alloc()
	_run_suite_2_enemy_spawner_non_compounding_density()
	_run_suite_3_main_game_save_restore_null_safety()

	_finish_and_quit()


func _finish_and_quit() -> void:
	print("\n==================================================================")
	print("  CHALLENGER 2 EMPIRICAL VERIFICATION SUMMARY")
	print("  TOTAL TESTS:  %d" % (_passed_count + _failed_count))
	print("  PASSED:       %d" % _passed_count)
	print("  FAILED:       %d" % _failed_count)
	if _failed_count == 0:
		print("  STATUS:       [PASS] ALL EMPIRICAL CHALLENGES CONFIRMED!")
	else:
		print("  STATUS:       [DEFECT_FOUND] %d EMPIRICAL CHALLENGES FAILED!" % _failed_count)
	print("==================================================================\n")

	get_tree().quit(0 if _failed_count == 0 else 1)


func _assert_true(condition: bool, test_name: String, error_msg: String) -> void:
	if condition:
		_passed_count += 1
		print("  ✓ %s" % test_name)
	else:
		_failed_count += 1
		_log_fail(test_name, error_msg)


func _log_fail(test_name: String, error_msg: String) -> void:
	var msg := "  ✗ [FAIL] %s: %s" % [test_name, error_msg]
	printerr(msg)
	_test_log.append(msg)


# ==============================================================================
# SUITE 1: SpaceBackground Zero-Allocation & Zero-Free Empirical Verification
# ==============================================================================
func _run_suite_1_space_background_zero_alloc() -> void:
	print("\n--- SUITE 1: SpaceBackground Zero-Allocation / Zero-Free Verification ---")

	var bg_scene: PackedScene = load("res://scenes/combat/environment/space_background.tscn")
	_assert_true(bg_scene != null, "S1.1: SpaceBackground scene loadable", "Could not load space_background.tscn")
	if not bg_scene:
		return

	var bg: SpaceBackground = bg_scene.instantiate() as SpaceBackground
	_assert_true(bg != null, "S1.2: SpaceBackground instantiated", "Instance is null")
	add_child(bg)

	var s_outskirts: SectorData = load(SECTOR_OUTSKIRTS_PATH) as SectorData
	var s_abyss: SectorData = load(SECTOR_ABYSS_PATH) as SectorData
	var s_storm: SectorData = load(SECTOR_STORM_PATH) as SectorData
	var s_core: SectorData = load(SECTOR_CORE_PATH) as SectorData

	_assert_true(s_outskirts != null and s_abyss != null and s_storm != null and s_core != null,
		"S1.3: All 4 canonical sector resources loaded", "Failed loading one or more SectorData .tres files")

	# Baseline node count
	var baseline_tree_nodes: int = get_tree().get_node_count()
	var baseline_obj_nodes: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))

	# Test 1.4: Single sector configuration retains exact node count
	bg.configure_sector(s_outskirts)
	var nodes_after_outskirts: int = get_tree().get_node_count()
	var obj_after_outskirts: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	_assert_true(nodes_after_outskirts == baseline_tree_nodes and obj_after_outskirts == baseline_obj_nodes,
		"S1.4: configure_sector(s_outskirts) delta is 0 nodes (tree=%d->%d, obj=%d->%d)" % [
			baseline_tree_nodes, nodes_after_outskirts, baseline_obj_nodes, obj_after_outskirts
		],
		"Node allocation detected during configure_sector: tree delta=%d, obj delta=%d" % [
			nodes_after_outskirts - baseline_tree_nodes, obj_after_outskirts - baseline_obj_nodes
		])

	# Test 1.5: Verify visual modulations applied in-place without node recreation
	var neb_sprite: Sprite2D = bg.get_node_or_null("ParallaxNebula/NebulaSprite") as Sprite2D
	var deep_sprite: Sprite2D = bg.get_node_or_null("ParallaxDeepStars/DeepStarsSprite") as Sprite2D
	var mid_sprite: Sprite2D = bg.get_node_or_null("ParallaxMidStars/MidStarsSprite") as Sprite2D
	var dust_sprite: Sprite2D = bg.get_node_or_null("ParallaxNearDust/NearDustSprite") as Sprite2D

	_assert_true(neb_sprite != null and deep_sprite != null and mid_sprite != null and dust_sprite != null,
		"S1.5: Parallax layer sprites found and cached", "Parallax sprites missing")

	bg.configure_sector(s_abyss)
	_assert_true(
		neb_sprite.modulate == s_abyss.nebula_tint and
		deep_sprite.modulate == s_abyss.stars_deep_tint and
		mid_sprite.modulate == s_abyss.stars_mid_tint and
		dust_sprite.modulate == s_abyss.dust_near_tint,
		"S1.6: Void Abyss in-place sprite modulate values applied correctly",
		"Modulate does not match Void Abyss tints")

	# Test 1.7: 1,000-iteration rapid combat weather/sector switching stress test
	var sectors: Array[SectorData] = [s_outskirts, s_abyss, s_storm, s_core]
	var pre_stress_nodes: int = get_tree().get_node_count()
	var pre_stress_objs: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))

	for i in range(1000):
		var target_sec: SectorData = sectors[i % sectors.size()]
		bg.configure_sector(target_sec)

	var post_stress_nodes: int = get_tree().get_node_count()
	var post_stress_objs: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))

	_assert_true(post_stress_nodes == pre_stress_nodes and post_stress_objs == pre_stress_objs,
		"S1.7: 1,000 Rapid sector switches produced ZERO node allocations/frees (nodes=%d->%d, objs=%d->%d)" % [
			pre_stress_nodes, post_stress_nodes, pre_stress_objs, post_stress_objs
		],
		"Node leak or allocation during rapid sector switching! Delta nodes: %d, Delta objs: %d" % [
			post_stress_nodes - pre_stress_nodes, post_stress_objs - pre_stress_objs
		])

	# Test 1.8: Null sector handling is zero-alloc and null-safe
	bg.configure_sector(null)
	var post_null_nodes: int = get_tree().get_node_count()
	_assert_true(post_null_nodes == pre_stress_nodes,
		"S1.8: configure_sector(null) safely ignored without allocations",
		"configure_sector(null) altered node count")

	# Test 1.9: Dynamic drift speed and direction update
	bg.configure_sector(s_core)
	_assert_true(
		is_equal_approx(bg.base_drift_speed, s_core.drift_speed) and
		bg.drift_direction.is_equal_approx(s_core.drift_direction.normalized()),
		"S1.9: Dynamic drift speed (%f) and normalized direction (%s) applied" % [bg.base_drift_speed, str(bg.drift_direction)],
		"Drift parameters do not match Singularity Core")

	# Clean up
	bg.queue_free()


# ==============================================================================
# SUITE 2: EnemySpawner Non-Compounding Density Across Waves 1-10
# ==============================================================================
func _run_suite_2_enemy_spawner_non_compounding_density() -> void:
	print("\n--- SUITE 2: EnemySpawner Non-Compounding Density Verification ---")

	var spawner: EnemySpawner = EnemySpawner.new()
	add_child(spawner)

	# Raw baseline parameters matching EnemySpawner._apply_wave_parameters
	var raw_table: Dictionary = {
		1: {"max": 80, "base_int": 1.2, "min_int": 0.45},
		2: {"max": 120, "base_int": 1.0, "min_int": 0.38},
		3: {"max": 160, "base_int": 0.85, "min_int": 0.32},
		4: {"max": 200, "base_int": 0.75, "min_int": 0.28},
		5: {"max": 250, "base_int": 0.70, "min_int": 0.25},
		6: {"max": 275, "base_int": 0.65, "min_int": 0.25},
		7: {"max": 300, "base_int": 0.60, "min_int": 0.25},
		8: {"max": 320, "base_int": 0.55, "min_int": 0.25},
		9: {"max": 320, "base_int": 0.50, "min_int": 0.25},
		10: {"max": 320, "base_int": 0.50, "min_int": 0.25},
	}

	# Test 2.1: Verify sequential wave progression across waves 1 to 10 for each canonical sector density
	var test_multipliers: Array[float] = [1.0, 1.3, 1.4, 1.6, 2.0, 0.5]

	for mult in test_multipliers:
		spawner.set_density_multiplier(mult)
		_assert_true(is_equal_approx(spawner.density_multiplier, mult),
			"S2.1: set_density_multiplier(%.2f) accurately set" % mult,
			"spawner.density_multiplier not equal to set value")

		var compounding_detected: bool = false
		var failure_detail: String = ""

		for wave in range(1, 11):
			spawner.set_wave(wave)

			var raw: Dictionary = raw_table[wave]
			var expected_max: int = maxi(10, int(round(float(raw["max"]) * mult)))
			var expected_base_int: float = maxf(0.2, float(raw["base_int"]) / mult)
			var expected_min_int: float = maxf(0.1, float(raw["min_int"]) / mult)

			if spawner.max_enemies != expected_max:
				compounding_detected = true
				failure_detail = "Wave %d (mult=%.2f): max_enemies expected %d but got %d" % [
					wave, mult, expected_max, spawner.max_enemies
				]
				break

			if not is_equal_approx(spawner.base_spawn_interval, expected_base_int):
				compounding_detected = true
				failure_detail = "Wave %d (mult=%.2f): base_spawn_interval expected %.4f but got %.4f" % [
					wave, mult, expected_base_int, spawner.base_spawn_interval
				]
				break

			if not is_equal_approx(spawner.min_spawn_interval, expected_min_int):
				compounding_detected = true
				failure_detail = "Wave %d (mult=%.2f): min_spawn_interval expected %.4f but got %.4f" % [
					wave, mult, expected_min_int, spawner.min_spawn_interval
				]
				break

		_assert_true(not compounding_detected,
			"S2.2: Sequential Waves 1-10 with mult=%.2f: Non-compounding verified" % mult,
			failure_detail)

	# Test 2.3: Invariant check — Sequential progression vs Direct jump
	var seq_spawner: EnemySpawner = EnemySpawner.new()
	var direct_spawner: EnemySpawner = EnemySpawner.new()
	add_child(seq_spawner)
	add_child(direct_spawner)

	var high_mult: float = 1.6 # Singularity Core
	seq_spawner.set_density_multiplier(high_mult)
	direct_spawner.set_density_multiplier(high_mult)

	for w in range(1, 11):
		seq_spawner.set_wave(w)

	direct_spawner.set_wave(10)

	_assert_true(
		seq_spawner.max_enemies == direct_spawner.max_enemies and
		is_equal_approx(seq_spawner.base_spawn_interval, direct_spawner.base_spawn_interval) and
		is_equal_approx(seq_spawner.min_spawn_interval, direct_spawner.min_spawn_interval),
		"S2.3: Sequential 10-wave progression matches Direct Wave 10 jump exactly (max=%d vs %d)" % [
			seq_spawner.max_enemies, direct_spawner.max_enemies
		],
		"Compounding detected: Sequential Wave 10 max_enemies=%d, Direct Wave 10 max_enemies=%d" % [
			seq_spawner.max_enemies, direct_spawner.max_enemies
		])

	# Test 2.4: Arbitrary / Chaotic Wave Jumps (1 -> 7 -> 3 -> 10 -> 2 -> 8)
	var chaotic_waves: Array[int] = [1, 7, 3, 10, 2, 8]
	var chaotic_ok := true
	for cw in chaotic_waves:
		spawner.set_wave(cw)
		var expected_m: int = maxi(10, int(round(float(raw_table[cw]["max"]) * spawner.density_multiplier)))
		if spawner.max_enemies != expected_m:
			chaotic_ok = false
			break
	_assert_true(chaotic_ok, "S2.4: Chaotic non-linear wave jumps maintain exact non-compounding formula",
		"Chaotic wave jumping corrupted spawner density")

	# Test 2.5: Clamping of density multiplier boundary values [0.1, 5.0]
	spawner.set_density_multiplier(0.0001)
	_assert_true(is_equal_approx(spawner.density_multiplier, 0.1),
		"S2.5: Underflow density clamped to 0.1 (got %.3f)" % spawner.density_multiplier,
		"Underflow density not clamped to 0.1")

	spawner.set_density_multiplier(999.0)
	_assert_true(is_equal_approx(spawner.density_multiplier, 5.0),
		"S2.6: Overflow density clamped to 5.0 (got %.3f)" % spawner.density_multiplier,
		"Overflow density not clamped to 5.0")

	# Test 2.7: Reverse wave order (Wave 10 down to Wave 1)
	spawner.set_density_multiplier(1.3)
	for w in range(10, 0, -1):
		spawner.set_wave(w)
		var exp_m: int = maxi(10, int(round(float(raw_table[w]["max"]) * 1.3)))
		if spawner.max_enemies != exp_m:
			_assert_true(false, "S2.7: Reverse wave %d failed" % w, "Expected %d got %d" % [exp_m, spawner.max_enemies])
			break
	_assert_true(spawner.current_wave == 1 and spawner.max_enemies == maxi(10, int(round(80.0 * 1.3))),
		"S2.7: Reverse Wave 10->1 transitions cleanly without hysteresis",
		"Reverse wave transition failed")

	seq_spawner.queue_free()
	direct_spawner.queue_free()
	spawner.queue_free()


# ==============================================================================
# SUITE 3: MainGame Mid-Run Save/Restore State Stability & Null Safety
# ==============================================================================
func _run_suite_3_main_game_save_restore_null_safety() -> void:
	print("\n--- SUITE 3: MainGame Mid-Run Save/Restore State Stability & Null Safety ---")

	var main_scene: PackedScene = load("res://scenes/combat/main_game.tscn")
	_assert_true(main_scene != null, "S3.1: MainGame scene loaded", "Cannot load scenes/combat/main_game.tscn")
	if not main_scene:
		return

	# Test 3.2: Initialize MainGame with default sector
	SaveManager.set_selected_sector(&"sector_nebula_outskirts")
	var mg: MainGame = main_scene.instantiate() as MainGame
	_assert_true(mg != null, "S3.2: MainGame instantiated successfully", "MainGame instantiation returned null")
	add_child(mg)

	# Bypass prologue dialogic timeline if active
	if Dialogic:
		Dialogic.end_timeline()
	mg.is_briefing_active = false
	get_tree().paused = false

	_assert_true(mg.current_sector != null,
		"S3.3: MainGame._initialize_sector() populated current_sector",
		"current_sector is null after _ready()")

	_assert_true(mg.current_sector.sector_id == &"sector_nebula_outskirts",
		"S3.4: current_sector matches selected sector (sector_nebula_outskirts)",
		"current_sector.sector_id is %s" % (mg.current_sector.sector_id if mg.current_sector else "null"))

	# Test 3.5: get_current_run_state contains valid selected_sector
	var state_dict: Dictionary = mg.get_current_run_state()
	_assert_true(state_dict.has("selected_sector") and state_dict["selected_sector"] == &"sector_nebula_outskirts",
		"S3.5: get_current_run_state() serializes selected_sector correctly",
		"Missing or mismatched selected_sector in state: %s" % str(state_dict.get("selected_sector", "MISSING")))

	# Test 3.6: Mid-Run Restore across all 4 canonical sectors against ground-truth resources
	var sector_paths: Array[String] = [
		SECTOR_OUTSKIRTS_PATH,
		SECTOR_ABYSS_PATH,
		SECTOR_STORM_PATH,
		SECTOR_CORE_PATH
	]

	for sec_path in sector_paths:
		var sec_res: SectorData = load(sec_path) as SectorData
		_assert_true(sec_res != null, "S3.6a: Sector resource loaded from %s" % sec_path, "Could not load sector resource")

		var mock_save: Dictionary = state_dict.duplicate(true)
		mock_save["selected_sector"] = sec_res.sector_id
		mock_save["current_wave"] = 3
		mock_save["player_health"] = 75.0
		mock_save["run_credits"] = 500
		mock_save["run_biomass"] = 120
		mock_save["run_dark_matter"] = 80

		# Restore state
		mg.restore_run_state(mock_save)

		_assert_true(mg.current_sector != null and mg.current_sector.sector_id == sec_res.sector_id,
			"S3.6b: Restored sector %s correctly" % sec_res.sector_id,
			"Sector restore mismatch or null")

		_assert_true(mg.enemy_spawner != null and is_equal_approx(mg.enemy_spawner.density_multiplier, sec_res.enemy_density_mult),
			"S3.6c: EnemySpawner density matches restored sector (expected=%.2f, actual=%.2f)" % [
				sec_res.enemy_density_mult, mg.enemy_spawner.density_multiplier if mg.enemy_spawner else -1.0
			],
			"Spawner density multiplier mismatch")

		_assert_true(is_equal_approx(mg.player.stats.get_stat(&"biomass_multiplier"), sec_res.biomass_mult),
			"S3.6d: Player biomass_multiplier restored (expected=%.2f, actual=%.2f)" % [
				sec_res.biomass_mult, mg.player.stats.get_stat(&"biomass_multiplier")
			],
			"biomass_multiplier mismatch on player stats")

		_assert_true(is_equal_approx(mg.player.stats.get_stat(&"dark_matter_multiplier"), sec_res.dark_matter_mult),
			"S3.6e: Player dark_matter_multiplier restored (expected=%.2f, actual=%.2f)" % [
				sec_res.dark_matter_mult, mg.player.stats.get_stat(&"dark_matter_multiplier")
			],
			"dark_matter_multiplier mismatch on player stats")

		_assert_true(is_equal_approx(mg.player.stats.get_stat(&"credits_multiplier"), sec_res.credits_mult),
			"S3.6f: Player credits_multiplier restored (expected=%.2f, actual=%.2f)" % [
				sec_res.credits_mult, mg.player.stats.get_stat(&"credits_multiplier")
			],
			"credits_multiplier mismatch on player stats")

	# Test 3.7: Legacy save restore (without "selected_sector" key) — Must NOT throw null reference
	var legacy_save: Dictionary = state_dict.duplicate(true)
	legacy_save.erase("selected_sector")
	legacy_save["current_wave"] = 2
	mg.restore_run_state(legacy_save)

	_assert_true(mg.current_sector != null,
		"S3.7: Legacy save without 'selected_sector' restores safely without null reference",
		"current_sector became null after legacy restore")

	# Test 3.8: Corrupt / Unknown sector ID in mid-run save — Must fallback gracefully
	var corrupt_save: Dictionary = state_dict.duplicate(true)
	corrupt_save["selected_sector"] = "unknown_alien_sector_9999_corrupt"
	mg.restore_run_state(corrupt_save)

	_assert_true(mg.current_sector != null and mg.current_sector.sector_id == &"sector_nebula_outskirts",
		"S3.8: Corrupt sector ID recovers safely to Outskirts fallback (%s)" % (mg.current_sector.sector_id if mg.current_sector else "null"),
		"Corrupt sector failed to fallback or caused crash")

	# Test 3.9: End-to-end Mid-Run Save and Fresh Resume Cycle
	# 1. Prepare and save an active run in Singularity Core
	var core_res: SectorData = load(SECTOR_CORE_PATH) as SectorData
	SaveManager.set_selected_sector(&"sector_singularity_core")
	mg.current_sector = core_res
	mg.current_wave = 5
	mg.player.current_health = 60.0
	mg.player.run_credits = 420
	mg.player.run_biomass = 250
	mg.player.run_dark_matter = 180
	var saved_state := mg.get_current_run_state()
	SaveManager.save_active_run(saved_state)

	_assert_true(SaveManager.has_active_run(),
		"S3.9a: Active run file created and confirmed by SaveManager",
		"SaveManager.has_active_run() returned false")

	# 2. Free old MainGame
	mg.queue_free()

	# 3. Instantiate fresh MainGame simulating full game restart with is_resuming_run = true
	SaveManager.is_resuming_run = true
	var mg_resumed: MainGame = main_scene.instantiate() as MainGame
	add_child(mg_resumed)

	if Dialogic:
		Dialogic.end_timeline()
	mg_resumed.is_briefing_active = false
	get_tree().paused = false

	_assert_true(mg_resumed.current_sector != null and mg_resumed.current_sector.sector_id == &"sector_singularity_core",
		"S3.9b: Fresh MainGame boot resumed into sector_singularity_core",
		"Resumed current_sector mismatch: %s" % (mg_resumed.current_sector.sector_id if mg_resumed.current_sector else "null"))

	_assert_true(mg_resumed.current_wave == 5,
		"S3.9c: Resumed wave equals 5 (actual: %d)" % mg_resumed.current_wave,
		"Wave not restored")

	_assert_true(is_equal_approx(mg_resumed.enemy_spawner.density_multiplier, core_res.enemy_density_mult),
		"S3.9d: Resumed spawner density equals %.2f (actual: %.2f)" % [core_res.enemy_density_mult, mg_resumed.enemy_spawner.density_multiplier],
		"Spawner density mismatch after resume")

	_assert_true(is_equal_approx(mg_resumed.player.stats.get_stat(&"dark_matter_multiplier"), core_res.dark_matter_mult),
		"S3.9e: Resumed player dark_matter_multiplier equals %.2f (actual: %.2f)" % [
			core_res.dark_matter_mult, mg_resumed.player.stats.get_stat(&"dark_matter_multiplier")
		],
		"Player loot multiplier mismatch after resume")

	# Clean up active run and resumed scene
	SaveManager.clear_active_run()
	mg_resumed.queue_free()

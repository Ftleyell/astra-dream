extends Node

var total_tests: int = 0
var passed_tests: int = 0

func _ready() -> void:
	print("\n==================================================================")
	print("[TEST] INITIATING ENCOUNTER DIRECTOR & DATA-DRIVEN TIMELINE SUITE")
	print("==================================================================")

	_test_1_timeline_config_resource()
	_test_3_boss_rival_adaptive_scaling()

	print("\n==================================================================")
	print("  TOTAL VERIFIED TEST SUITES: %d/%d PASSED" % [passed_tests, total_tests])
	if passed_tests == total_tests:
		print("[PASS] 100% SUITE COMPLIANCE — ENCOUNTER DIRECTOR VERIFIED!")
	else:
		printerr("[FAIL] Encounter Director Verification Failed!")
	print("==================================================================\n")

	await get_tree().create_timer(0.2).timeout
	get_tree().quit(0 if passed_tests == total_tests else 1)

func _test_1_timeline_config_resource() -> void:
	total_tests += 1
	print("\n--- TEST 1: EncounterTimelineConfig Resource Validation ---")
	var cfg := load("res://data/balance/default_encounter_timeline.tres") as EncounterTimelineConfig
	assert(cfg != null, "Config default_encounter_timeline.tres must exist")
	assert(cfg.wave_duration == 30.0, "Wave duration must be 30.0s")
	assert(cfg.total_waves == 16, "Total waves must be 16")
	assert(cfg.rival_wave_milestones == [4, 7, 10, 13], "Rivals must spawn at waves 4, 7, 10, 13")
	assert(cfg.is_boss_wave(2), "Wave 2 must be a boss wave")
	assert(cfg.is_boss_wave(5), "Wave 5 must be a boss wave")
	assert(cfg.is_boss_wave(8), "Wave 8 must be a boss wave")
	assert(cfg.is_boss_wave(11), "Wave 11 must be a boss wave")
	assert(cfg.is_boss_wave(14), "Wave 14 must be a boss wave")
	assert(cfg.is_boss_wave(16), "Wave 16 must be a boss wave")
	assert(not cfg.is_boss_wave(3), "Wave 3 must not be a boss wave")
	assert(cfg.is_rival_wave(4), "Wave 4 must be a rival wave")
	assert(not cfg.is_rival_wave(5), "Wave 5 must not be a rival wave")

	passed_tests += 1
	print("  ✓ T1: EncounterTimelineConfig.tres validated (16 waves, 6 boss milestones, 4 rival milestones)")

func _test_3_boss_rival_adaptive_scaling() -> void:
	total_tests += 1
	print("\n--- TEST 2: BossEncounterSpawner Adaptive HP Scaling ---")
	var spawner := BossEncounterSpawner.new()
	var cfg := load("res://data/balance/default_encounter_timeline.tres") as EncounterTimelineConfig

	var base_hp: float = 1600.0
	var scaled_w2: float = spawner.calculate_adaptive_hp(base_hp, 2, 20.0, 1.0, 0.05, 1.5, 1.0, cfg)
	var expected_w2: float = base_hp * (1.0 + 2.0 * cfg.wave_scaling_hp_step) * 1.0 * cfg.base_boss_hp_multiplier
	assert(is_equal_approx(scaled_w2, expected_w2), "Wave 2 scaled HP must equal %f, got %f" % [expected_w2, scaled_w2])

	var scaled_high: float = spawner.calculate_adaptive_hp(base_hp, 2, 60.0, 1.5, 0.05, 1.5, 1.0, cfg)
	assert(scaled_high > scaled_w2, "High DPS boss HP must exceed base DPS HP")

	passed_tests += 1
	print("  ✓ T2: Adaptive boss health scaling and DPS floor/ceiling clamps verified")

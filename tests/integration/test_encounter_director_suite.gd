extends Node

var total_tests: int = 0
var passed_tests: int = 0

func _ready() -> void:
	print("\n==================================================================")
	print("[TEST] INITIATING ENCOUNTER DIRECTOR & DATA-DRIVEN TIMELINE SUITE")
	print("==================================================================")

	_test_1_timeline_config_resource()
	_test_2_wave_director_progression()
	_test_3_boss_rival_adaptive_scaling()
	_test_4_satellite_director_and_positioning()
	_test_5_encounter_director_orchestration()

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

func _test_2_wave_director_progression() -> void:
	total_tests += 1
	print("\n--- TEST 2: WaveDirector Progression and Timing ---")
	var wd := WaveDirector.new()
	var cfg := load("res://data/balance/default_encounter_timeline.tres") as EncounterTimelineConfig
	wd.initialize(cfg)

	assert(wd.current_wave == 1, "Initial wave must be 1")
	assert(wd.is_pre_round, "Must start in pre-round")
	assert(wd.pre_round_timer == 30.0, "Pre-round timer must match config")

	# Simular avance del pre-round
	wd.update_wave_timeline(30.1, false)
	assert(not wd.is_pre_round, "Pre-round must finish after 30s")
	assert(wd.current_wave == 1, "Wave must still be 1 after pre-round ends")
	assert(wd.wave_timer == 30.0, "Wave timer must reset to 30.0")

	# Simular avance de oleada 1 a oleada 2
	wd.update_wave_timeline(30.1, false)
	assert(wd.current_wave == 2, "Wave must advance to 2")
	assert(wd.wave_timer == 30.0, "Wave timer must be 30.0")

	# Salto manual
	wd.set_wave(16)
	assert(wd.current_wave == 16, "Manual jump to wave 16 must succeed")

	wd.queue_free()
	passed_tests += 1
	print("  ✓ T2: WaveDirector progression, pre-round transition and manual set_wave verified")

func _test_3_boss_rival_adaptive_scaling() -> void:
	total_tests += 1
	print("\n--- TEST 3: BossRivalDirector Adaptive HP Scaling ---")
	var brd := BossRivalDirector.new()
	var cfg := load("res://data/balance/default_encounter_timeline.tres") as EncounterTimelineConfig
	brd.initialize(cfg)

	var base_hp: float = 1600.0
	# Jugador con DPS estándar: 20 dmg, 1.0 spd -> p_dps_factor = 1.0
	var scaled_w2: float = brd.calculate_adaptive_hp(base_hp, 2, 20.0, 1.0)
	var expected_w2: float = base_hp * (1.0 + 2.0 * 0.08) * 1.0 # 1600 * 1.16 = 1856.0
	assert(is_equal_approx(scaled_w2, expected_w2), "Wave 2 scaled HP must equal %f, got %f" % [expected_w2, scaled_w2])

	# Jugador con alto DPS: 60 dmg, 1.5 spd -> 4.5 clamped to 2.5
	var scaled_high: float = brd.calculate_adaptive_hp(base_hp, 2, 60.0, 1.5)
	var expected_high: float = base_hp * (1.0 + 2.0 * 0.08) * 2.5 # 1600 * 1.16 * 2.5 = 4640.0
	assert(is_equal_approx(scaled_high, expected_high), "High DPS boss HP must be clamped to ceiling")

	# Jugador con bajo DPS: 10 dmg, 0.5 spd -> 0.25 clamped to floor 0.85
	var scaled_low: float = brd.calculate_adaptive_hp(base_hp, 2, 10.0, 0.5)
	var expected_low: float = base_hp * (1.0 + 2.0 * 0.08) * 0.85
	assert(is_equal_approx(scaled_low, expected_low), "Low DPS boss HP must be clamped to floor")

	brd.queue_free()
	passed_tests += 1
	print("  ✓ T3: Adaptive boss health scaling and DPS floor/ceiling clamps verified")

func _test_4_satellite_director_and_positioning() -> void:
	total_tests += 1
	print("\n--- TEST 4: SatelliteDirector Positioning and Despawn ---")
	var sd := SatelliteDirector.new()
	var cfg := load("res://data/balance/default_encounter_timeline.tres") as EncounterTimelineConfig
	sd.initialize(cfg)

	var p_pos := Vector2(1000.0, 1000.0)
	var p_vel := Vector2(300.0, 0.0)
	var sat_pos := sd.calculate_satellite_spawn_position(p_pos, p_vel)

	var dist := p_pos.distance_to(sat_pos)
	assert(dist >= 600.0 and dist <= 1100.0, "Satellite distance must be within [600, 1100], got %f" % dist)
	assert(sd.can_spawn_satellite_for_wave(), "Must be able to spawn initial satellite for wave")

	sd.wave_satellites_spawned = 1
	assert(not sd.can_spawn_satellite_for_wave(), "Cannot spawn exceeding max_satellites_per_wave")

	sd.queue_free()
	passed_tests += 1
	print("  ✓ T4: Satellite spawn positioning ahead of velocity vector and wave limits verified")

func _test_5_encounter_director_orchestration() -> void:
	total_tests += 1
	print("\n--- TEST 5: EncounterDirector Master Orchestration ---")
	var ed := EncounterDirector.new()
	add_child(ed)
	ed.initialize()

	assert(ed.wave_director != null, "WaveDirector child must be present")
	assert(ed.boss_rival_director != null, "BossRivalDirector child must be present")
	assert(ed.satellite_director != null, "SatelliteDirector child must be present")

	var notified_wave := [0]
	ed.wave_changed.connect(func(w: int) -> void: notified_wave[0] = w)

	ed.jump_to_wave(11)
	assert(ed.wave_director.current_wave == 11, "Wave director wave must be 11")
	assert(notified_wave[0] == 11, "wave_changed signal must be emitted with wave 11")

	ed.queue_free()
	passed_tests += 1
	print("  ✓ T5: EncounterDirector master coordinator and signal routing verified")

extends Node

## ==============================================================================
## EMPIRICAL CHALLENGER 2: Milestone 2 Verification Suite
## Focus: StellarRewardChest Drop, Currency Dispensation, SaveManager Accounting,
##        Debounce Safeguards, Permadeath Precedence & Zero-Allocation Compliance
## ==============================================================================

const CHEST_SCENE_PATH := "res://scenes/combat/pickups/stellar_reward_chest.tscn"
const MAIN_GAME_SCENE_PATH := "res://scenes/combat/main_game.tscn"

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
	print("[CHALLENGER 2] STARTING EMPIRICAL VERIFICATION FOR MILESTONE 2")
	print("==================================================================")

	# Clean initial state
	SaveManager.is_resuming_run = false
	SaveManager.clear_active_run()

	await _run_suite_1_rival_defeat_and_drop_location()
	await _run_suite_2_currency_dispensation_and_save_manager()
	await _run_suite_3_debounce_safeguard_stress()
	await _run_suite_4_permadeath_and_player_caching()
	await _run_suite_5_zero_allocation_compliance()

	_finish_and_quit()


func _finish_and_quit() -> void:
	print("\n==================================================================")
	print("  CHALLENGER 2 EMPIRICAL VERIFICATION SUMMARY (MILESTONE 2)")
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


func _log_fail(test_name: String, reason: String) -> void:
	var msg := "  ✗ [FAIL] %s: %s" % [test_name, reason]
	_test_log.append(msg)
	push_error(msg)
	print(msg)


func _create_test_player(bserver: BulletServer) -> Player:
	var p: Player = Player.new()
	var roster := CharacterData.load_roster()
	p.character_data = roster.get(&"nova") if roster.has(&"nova") else null
	p.bullet_server = bserver

	var vp := Polygon2D.new()
	vp.name = "VisualPlaceholder"
	p.add_child(vp)

	var hb := Polygon2D.new()
	hb.name = "HitboxCore"
	p.add_child(hb)

	var wc := WeaponController.new()
	wc.name = "WeaponController"
	wc.player = p
	p.add_child(wc)

	add_child(p)
	p.add_to_group("player")
	p.current_health = 100.0
	p.is_dead = false
	return p


# ==============================================================================
# SUITE 1: Rival Defeat -> StellarRewardChest Spawn Contract & Location Invariant
# ==============================================================================

func _run_suite_1_rival_defeat_and_drop_location() -> void:
	print("\n--- SUITE 1: Rival Defeat Drop Contract & Location Invariant ---")

	# S1.1: Chest scene exists and is loadable
	var exists := ResourceLoader.exists(CHEST_SCENE_PATH)
	_assert_true(exists, "S1.1: StellarRewardChest scene exists on disk", "Path %s not found" % CHEST_SCENE_PATH)
	if not exists:
		return

	var chest_scene := load(CHEST_SCENE_PATH) as PackedScene
	_assert_true(chest_scene != null, "S1.2: StellarRewardChest scene loaded successfully", "Failed to load PackedScene")
	if not chest_scene:
		return

	# S1.3: Chest instantiation and typed contract
	var chest_inst = chest_scene.instantiate()
	_assert_true(chest_inst is Area2D, "S1.3: StellarRewardChest root is Area2D", "Expected Area2D, got %s" % chest_inst.get_class())
	_assert_true(chest_inst.has_method("setup"), "S1.4: StellarRewardChest implements setup()", "Missing setup() method")
	_assert_true(chest_inst.has_signal("collected"), "S1.5: StellarRewardChest implements collected signal", "Missing collected signal")

	add_child(chest_inst)
	_assert_true(chest_inst.is_in_group("pickups"), "S1.6: StellarRewardChest belongs to 'pickups' group", "Not in 'pickups' group")
	_assert_true(chest_inst.is_in_group("stellar_chests"), "S1.7: StellarRewardChest belongs to 'stellar_chests' group", "Not in 'stellar_chests' group")
	chest_inst.queue_free()

	# S1.8: MainGame integration & rival defeat location invariant
	var mg_scene := load(MAIN_GAME_SCENE_PATH) as PackedScene
	if not mg_scene:
		_log_fail("S1.8", "Failed to load MainGame scene")
		return

	var mg = mg_scene.instantiate()
	add_child(mg)
	await get_tree().process_frame

	# Mock rival pilot
	var mock_rival := Node2D.new()
	mock_rival.name = "MockRival"
	var target_rival_pos := Vector2(840.0, 620.0)
	mock_rival.global_position = target_rival_pos
	mock_rival.set("pilot_name", "Kira")
	mg.add_child(mock_rival)
	mg.set("current_rival", mock_rival)

	# Defeat rival
	var dummy_weapon: WeaponData = null
	mg._on_rival_defeated(&"kira", dummy_weapon)

	_assert_true(mg.get("current_rival") == null, "S1.8: current_rival is reset to null upon defeat", "current_rival not nulled")

	# Allow call_deferred(_spawn_stellar_reward_chest) to execute
	await get_tree().process_frame

	var found_chest: StellarRewardChest = null
	for child in mg.get_children():
		if child is StellarRewardChest:
			found_chest = child
			break

	_assert_true(found_chest != null, "S1.9: StellarRewardChest was spawned in MainGame after rival defeat", "No StellarRewardChest found in MainGame children")
	if found_chest:
		# Chest initial velocity adds a slight offset (50-110px impulse), so position should be near target_rival_pos
		var dist_to_target := found_chest.global_position.distance_to(target_rival_pos)
		_assert_true(dist_to_target <= 150.0, "S1.10: StellarRewardChest spawned at rival position invariant (dist=%.1f <= 150)" % dist_to_target,
			"Chest spawned too far from rival: expected ~%s, got %s (dist=%.1f)" % [target_rival_pos, found_chest.global_position, dist_to_target])

		# Check sector metadata passed
		var expected_bio := int(found_chest.reward_biomass)
		var expected_dm := int(found_chest.reward_dark_matter)
		var expected_anti := int(found_chest.reward_antimatter)
		_assert_true(expected_bio > 0 and expected_dm > 0 and expected_anti > 0,
			"S1.11: StellarRewardChest configured positive rewards (bio=%d, dm=%d, anti=%d)" % [expected_bio, expected_dm, expected_anti],
			"Invalid reward configuration")

	mg.queue_free()
	await get_tree().process_frame


# ==============================================================================
# SUITE 2: Meta-Currency Dispensation & SaveManager Accounting
# ==============================================================================

func _run_suite_2_currency_dispensation_and_save_manager() -> void:
	print("\n--- SUITE 2: Meta-Currency Dispensation & SaveManager Accounting ---")

	var chest_scene := load(CHEST_SCENE_PATH) as PackedScene
	var bserver := BulletServer.new()
	add_child(bserver)

	# Test 2.1: Direct collection without player (SaveManager fallback)
	var pre_bio := SaveManager.get_biomass()
	var pre_dm := SaveManager.get_dark_matter()
	var pre_anti := SaveManager.get_antimatter()

	var chest_no_player = chest_scene.instantiate() as StellarRewardChest
	chest_no_player.setup(Vector2.ZERO, 150, 50, 10)
	add_child(chest_no_player)

	var signal_tracker := [false]
	chest_no_player.collected.connect(func(_b, _d, _a):
		signal_tracker[0] = true
	)

	# Direct collect call
	chest_no_player._collect()

	# EMPIRICAL CHECK: Does _is_player_dead() treat null player as dead, preventing SaveManager fallback?
	_assert_true(signal_tracker[0], "S2.1: Standalone/fallback chest collection dispenses when player==null",
		"DEFECT DETECTED: StellarRewardChest._collect() refused collection when player==null because _is_player_dead() returned true for null player, preventing SaveManager fallback!")

	if signal_tracker[0]:
		_assert_true(SaveManager.get_biomass() == pre_bio + 150, "S2.2: SaveManager biomass incremented by exactly 150", "Got %d, expected %d" % [SaveManager.get_biomass(), pre_bio + 150])
		_assert_true(SaveManager.get_dark_matter() == pre_dm + 50, "S2.3: SaveManager dark matter incremented by exactly 50", "Got %d, expected %d" % [SaveManager.get_dark_matter(), pre_dm + 50])
		_assert_true(SaveManager.get_antimatter() == pre_anti + 10, "S2.4: SaveManager antimatter incremented by exactly 10", "Got %d, expected %d" % [SaveManager.get_antimatter(), pre_anti + 10])

	chest_no_player.queue_free()

	# Test 2.2: Collection WITH active Player instance (live combat simulation)
	var p_inst := _create_test_player(bserver)
	await get_tree().process_frame

	# Record SaveManager currency baselines
	pre_bio = SaveManager.get_biomass()
	pre_dm = SaveManager.get_dark_matter()
	pre_anti = SaveManager.get_antimatter()

	var chest_with_player = chest_scene.instantiate() as StellarRewardChest
	chest_with_player.setup(Vector2(2000, 2000), 150, 50, 10)
	chest_with_player.player = p_inst
	add_child(chest_with_player)

	signal_tracker[0] = false
	chest_with_player.collected.connect(func(_b, _d, _a):
		signal_tracker[0] = true
	)

	chest_with_player._collect()

	_assert_true(signal_tracker[0], "S2.5: Chest collected with live Player", "Signal collected not emitted")

	var delta_bio := SaveManager.get_biomass() - pre_bio
	var delta_dm := SaveManager.get_dark_matter() - pre_dm
	var delta_anti := SaveManager.get_antimatter() - pre_anti

	_assert_true(delta_bio == 150, "S2.6: Player received full BioMasa (+150)", "Actual delta_bio=%d" % delta_bio)
	_assert_true(delta_dm == 50, "S2.7: Player received full Dark Matter (+50)", "Actual delta_dm=%d" % delta_dm)

	# EMPIRICAL ORACLE: Antimatter Accounting
	# If antimatter_multiplier is missing in CharacterStats._base_stats, get_stat(&"antimatter_multiplier") returns 0.0,
	# causing effective = int(round(10 * maxf(0.1, 0.0))) = 1 instead of 10!
	_assert_true(delta_anti == 10, "S2.8: Player received full Antimatter (+10)",
		"DEFECT DETECTED: Antimatter received is %d (expected 10)! CharacterStats missing 'antimatter_multiplier' base stat caused a 90%% penalty!" % delta_anti)

	chest_with_player.queue_free()
	p_inst.queue_free()
	bserver.queue_free()
	await get_tree().process_frame


# ==============================================================================
# SUITE 3: Debounce Safeguard & Multi-Body / Concurrent Overlap Stress
# ==============================================================================

func _run_suite_3_debounce_safeguard_stress() -> void:
	print("\n--- SUITE 3: Debounce Safeguard & Multi-Body Stress ---")

	var chest_scene := load(CHEST_SCENE_PATH) as PackedScene
	var bserver := BulletServer.new()
	add_child(bserver)
	var p_inst := _create_test_player(bserver)
	await get_tree().process_frame

	# Test 3.1: 100 Rapid sequential _collect() calls on same chest
	var chest = chest_scene.instantiate() as StellarRewardChest
	chest.setup(Vector2(2000, 2000), 100, 50, 5)
	chest.player = p_inst
	add_child(chest)

	var emit_tracker := [0]
	chest.collected.connect(func(_b, _d, _a):
		emit_tracker[0] += 1
	)

	var bio_before := SaveManager.get_biomass()
	for i in range(100):
		chest._collect()

	_assert_true(emit_tracker[0] == 1, "S3.1: Sequential 100x _collect() emitted exactly 1 collected signal (actual=%d)" % emit_tracker[0],
		"Debounce failed! Signal emitted %d times" % emit_tracker[0])
	_assert_true(SaveManager.get_biomass() == bio_before + 100, "S3.2: BioMasa credited exactly once under 100x sequential spam",
		"Debounce failed! Expected biomass %d, got %d" % [bio_before + 100, SaveManager.get_biomass()])
	chest.queue_free()

	# Test 3.2: Multi-body collision spam from 10 distinct bodies in same physics frame
	var chest2 = chest_scene.instantiate() as StellarRewardChest
	chest2.setup(Vector2(2000, 2000), 100, 50, 5)
	chest2.player = p_inst
	add_child(chest2)

	var emit_tracker2 := [0]
	chest2.collected.connect(func(_b, _d, _a):
		emit_tracker2[0] += 1
	)

	bio_before = SaveManager.get_biomass()

	var dummy_bodies: Array[Node2D] = []
	for i in range(10):
		var b := CharacterBody2D.new()
		b.add_to_group("player")
		add_child(b)
		dummy_bodies.append(b)

	# Trigger _on_body_entered from all 10 bodies concurrently
	for b in dummy_bodies:
		chest2._on_body_entered(b)

	_assert_true(emit_tracker2[0] == 1, "S3.3: 10 Concurrent bodies triggered exactly 1 collection (actual=%d)" % emit_tracker2[0],
		"Debounce failed under multi-body collision! Emitted %d times" % emit_tracker2[0])
	_assert_true(SaveManager.get_biomass() == bio_before + 100, "S3.4: Currency awarded exactly once across 10 concurrent bodies",
		"Expected biomass %d, got %d" % [bio_before + 100, SaveManager.get_biomass()])

	for b in dummy_bodies:
		b.queue_free()
	chest2.queue_free()

	# Test 3.3: Mixed area_entered and body_entered concurrent interleaving
	var chest3 = chest_scene.instantiate() as StellarRewardChest
	chest3.setup(Vector2(2000, 2000), 100, 50, 5)
	chest3.player = p_inst
	add_child(chest3)

	var emit_tracker3 := [0]
	chest3.collected.connect(func(_b, _d, _a):
		emit_tracker3[0] += 1
	)

	bio_before = SaveManager.get_biomass()
	var dummy_area := Area2D.new()
	dummy_area.add_to_group("player")
	add_child(dummy_area)

	for i in range(20):
		chest3._on_body_entered(p_inst)
		chest3._on_area_entered(dummy_area)
		chest3._collect()

	_assert_true(emit_tracker3[0] == 1, "S3.5: Interleaved 60 body/area/direct calls triggered exactly 1 collection",
		"Debounce failed! Emitted %d times" % emit_tracker3[0])
	_assert_true(SaveManager.get_biomass() == bio_before + 100, "S3.6: Currency credited exactly once under mixed attack",
		"Expected %d, got %d" % [bio_before + 100, SaveManager.get_biomass()])

	dummy_area.queue_free()
	chest3.queue_free()
	p_inst.queue_free()
	bserver.queue_free()
	await get_tree().process_frame


# ==============================================================================
# SUITE 4: Permadeath Precedence & Player Caching Invariants
# ==============================================================================

func _run_suite_4_permadeath_and_player_caching() -> void:
	print("\n--- SUITE 4: Permadeath Precedence & Player Caching ---")

	var chest_scene := load(CHEST_SCENE_PATH) as PackedScene
	var bserver := BulletServer.new()
	add_child(bserver)
	var p_inst := _create_test_player(bserver)
	await get_tree().process_frame

	# Case 4.1: Player dead (is_dead = true)
	p_inst.is_dead = true
	p_inst.current_health = 0.0

	var chest = chest_scene.instantiate() as StellarRewardChest
	chest.setup(Vector2(2000, 2000), 150, 50, 10)
	chest.player = p_inst
	add_child(chest)

	var bio_before := SaveManager.get_biomass()
	var signal_tracker := [false]
	chest.collected.connect(func(_b, _d, _a): signal_tracker[0] = true)

	chest._collect()

	_assert_true(not signal_tracker[0], "S4.1: Permadeath precedence: signal NOT emitted when is_dead=true",
		"Chest was collected despite player being dead!")
	_assert_true(not chest.is_collected, "S4.2: is_collected remains false when collection rejected by permadeath",
		"is_collected was locked to true after dead player contact!")
	_assert_true(SaveManager.get_biomass() == bio_before, "S4.3: SaveManager biomass unchanged on dead player contact",
		"Biomass was awarded to dead player!")

	# Case 4.2: Resurrect player and collect
	p_inst.is_dead = false
	p_inst.current_health = 100.0

	chest._collect()

	_assert_true(signal_tracker[0], "S4.4: Chest collected successfully once player is alive",
		"Chest failed to collect after player revived")
	_assert_true(chest.is_collected, "S4.5: is_collected is now true after valid collection",
		"is_collected still false")
	chest.queue_free()

	# Case 4.3: Player caching race condition
	# When a chest is freshly instantiated, if _on_body_entered(p_inst) is triggered BEFORE _physics_process ticks:
	var fresh_chest = chest_scene.instantiate() as StellarRewardChest
	fresh_chest.setup(Vector2(2000, 2000), 100, 50, 10)
	add_child(fresh_chest)
	# fresh_chest.player is null here!
	var fresh_tracker := [false]
	fresh_chest.collected.connect(func(_b, _d, _a): fresh_tracker[0] = true)

	# Trigger body entered with player
	fresh_chest._on_body_entered(p_inst)

	_assert_true(fresh_tracker[0], "S4.6: Fresh chest collects immediately on body_entered before physics tick",
		"DEFECT DETECTED: Fresh chest ignored body_entered because chest.player was uninitialized null, triggering _is_player_dead() false positive!")

	fresh_chest.queue_free()
	p_inst.queue_free()
	bserver.queue_free()
	await get_tree().process_frame


# ==============================================================================
# SUITE 5: Zero-Allocation & BulletServer Compliance
# ==============================================================================

func _run_suite_5_zero_allocation_compliance() -> void:
	print("\n--- SUITE 5: Zero-Allocation & BulletServer Compliance ---")

	var bserver := BulletServer.new()
	add_child(bserver)
	var initial_bullet_count: int = bserver.get_active_bullet_count()

	var chest_scene := load(CHEST_SCENE_PATH) as PackedScene
	var p_inst := _create_test_player(bserver)
	p_inst.global_position = Vector2(500, 500)
	await get_tree().process_frame

	# Spawn 20 chests simultaneously
	var chests: Array[StellarRewardChest] = []
	for i in range(20):
		var c = chest_scene.instantiate() as StellarRewardChest
		c.setup(Vector2(500 + i * 2, 500 + i * 2), 10, 5, 1)
		c.player = p_inst
		add_child(c)
		chests.append(c)

	var bullet_count_after_spawns: int = bserver.get_active_bullet_count()
	_assert_true(bullet_count_after_spawns == initial_bullet_count,
		"S5.1: 20 Chest spawns produced exactly 0 bullet allocations (delta=%d)" % (bullet_count_after_spawns - initial_bullet_count),
		"BulletServer pool allocated bullets during chest spawn!")

	# Simulate 10 frames of physics movement and magnetism
	for frame in range(10):
		for c in chests:
			if is_instance_valid(c):
				c._physics_process(0.016)

	var bullet_count_after_physics: int = bserver.get_active_bullet_count()
	_assert_true(bullet_count_after_physics == initial_bullet_count,
		"S5.2: Physics and magnet drift produced 0 bullet allocations",
		"BulletServer pool modified during chest physics")

	# Collect all chests
	for c in chests:
		if is_instance_valid(c):
			c._collect()

	var bullet_count_after_collect: int = bserver.get_active_bullet_count()
	_assert_true(bullet_count_after_collect == initial_bullet_count,
		"S5.3: Collection and tween despawn produced 0 bullet allocations",
		"BulletServer pool modified during chest collection")

	for c in chests:
		if is_instance_valid(c):
			c.queue_free()
	p_inst.queue_free()
	bserver.queue_free()
	await get_tree().process_frame

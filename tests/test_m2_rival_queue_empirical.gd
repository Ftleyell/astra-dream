extends Node

## ==============================================================================
## EMPIRICAL CHALLENGER TEST SUITE: MILESTONE 2 (RIVAL INVASIONS & QUEUE PRIORITY)
## Adversarial stress testing for Sector Rival Scheduling, Mirror Match Avoidance,
## Dynamic Warning Siren/Banner, and Stellar Meta-Progression Reward Chests.
## ==============================================================================

const SECTOR_OUTSKIRTS_PATH := "res://data/sectors/sector_nebula_outskirts.tres"
const SECTOR_ABYSS_PATH := "res://data/sectors/sector_void_abyss.tres"
const SECTOR_STORM_PATH := "res://data/sectors/sector_plasma_storm.tres"
const SECTOR_CORE_PATH := "res://data/sectors/sector_singularity_core.tres"
const MAIN_GAME_PATH := "res://scenes/combat/main_game.tscn"
const CHEST_SCENE_PATH := "res://scenes/combat/pickups/stellar_reward_chest.tscn"

var tests_passed: int = 0
var tests_failed: int = 0
var failure_log: Array[String] = []

func _ready() -> void:
	# Watchdog timer to prevent hang
	get_tree().create_timer(30.0).timeout.connect(func():
		printerr("[TIMEOUT] Empirical Challenger Test Suite timed out after 30 seconds!")
		get_tree().quit(1)
	)

	print("\n==================================================================")
	print("[EMPIRICAL CHALLENGER] Starting Milestone 2 Rival Queue & Invasions Suite")
	print("==================================================================\n")

	_run_section_1_sector_canonical_integrity()
	_run_section_2_get_assigned_rival_unit_tests()
	_run_section_3_full_32_case_matrix_live_maingame()
	_run_section_4_adversarial_and_boundary_cases()
	await _run_section_5_spawn_and_defeat_encounter_pipeline()
	_run_section_6_save_resume_queue_serialization()

	print("\n==================================================================")
	print("  TOTAL EMPIRICAL TESTS EXECUTED: %d" % (tests_passed + tests_failed))
	print("  TESTS PASSED:                   %d" % tests_passed)
	print("  TESTS FAILED:                   %d" % tests_failed)
	if tests_failed == 0:
		print("[PASS] 100% EMPIRICAL CONFIRMATION — ALL M2 SPECIFICATIONS VERIFIED!")
	else:
		print("[FAIL] DEFECTS DETECTED (%d failures):" % tests_failed)
		for f in failure_log:
			print("    - " + f)
	print("==================================================================\n")

	get_tree().quit(0 if tests_failed == 0 else 1)


func _assert_true(condition: bool, test_name: String, error_msg: String = "") -> void:
	if condition:
		tests_passed += 1
		print("  ✓ " + test_name)
	else:
		tests_failed += 1
		var err := "[FAIL] %s: %s" % [test_name, error_msg]
		printerr("  ✗ " + err)
		failure_log.append(err)


# ==============================================================================
# SECTION 1: SECTOR CANONICAL DATA INTEGRITY
# ==============================================================================
func _run_section_1_sector_canonical_integrity() -> void:
	print("\n--- SECTION 1: Sector Canonical Data Integrity ---")

	var sector_configs := [
		{"path": SECTOR_OUTSKIRTS_PATH, "id": &"sector_nebula_outskirts", "rival": &"nova", "secondary": &"valentina"},
		{"path": SECTOR_ABYSS_PATH, "id": &"sector_void_abyss", "rival": &"nyx", "secondary": &"selene"},
		{"path": SECTOR_STORM_PATH, "id": &"sector_plasma_storm", "rival": &"roxy", "secondary": &"kira"},
		{"path": SECTOR_CORE_PATH, "id": &"sector_singularity_core", "rival": &"estele", "secondary": &"echo"},
	]

	for cfg in sector_configs:
		var s: SectorData = load(cfg["path"]) as SectorData
		_assert_true(s != null, "S1.1: Load sector from %s" % cfg["path"], "Resource is null or not SectorData")
		if not s:
			continue

		_assert_true(s.sector_id == cfg["id"], "S1.2: Sector %s ID match" % cfg["id"], "Expected %s, got %s" % [cfg["id"], s.sector_id])
		_assert_true(s.rival_pilot_id == cfg["rival"], "S1.3: Sector %s primary rival is %s" % [cfg["id"], cfg["rival"]], "Expected %s, got %s" % [cfg["rival"], s.rival_pilot_id])
		_assert_true(s.secondary_rival_pilot_id == cfg["secondary"], "S1.4: Sector %s secondary rival is %s" % [cfg["id"], cfg["secondary"]], "Expected %s, got %s" % [cfg["secondary"], s.secondary_rival_pilot_id])
		_assert_true(s.rival_pilot_id != s.secondary_rival_pilot_id, "S1.5: Sector %s primary and secondary rivals are distinct" % cfg["id"], "Primary equals secondary rival!")
		_assert_true(s.reward_biomass > 0, "S1.6: Sector %s reward_biomass > 0 (%d)" % [cfg["id"], s.reward_biomass], "reward_biomass is not positive")
		_assert_true(s.reward_dark_matter > 0, "S1.7: Sector %s reward_dark_matter > 0 (%d)" % [cfg["id"], s.reward_dark_matter], "reward_dark_matter is not positive")
		_assert_true(s.reward_antimatter > 0, "S1.8: Sector %s reward_antimatter > 0 (%d)" % [cfg["id"], s.reward_antimatter], "reward_antimatter is not positive")


# ==============================================================================
# SECTION 2: SECTORDATA.GET_ASSIGNED_RIVAL() UNIT & CONTRACT TESTS
# ==============================================================================
func _run_section_2_get_assigned_rival_unit_tests() -> void:
	print("\n--- SECTION 2: SectorData.get_assigned_rival() Contract ---")

	var s_outskirts: SectorData = load(SECTOR_OUTSKIRTS_PATH)
	var s_abyss: SectorData = load(SECTOR_ABYSS_PATH)
	var s_storm: SectorData = load(SECTOR_STORM_PATH)
	var s_core: SectorData = load(SECTOR_CORE_PATH)

	# Outskirts: rival=nova, secondary=valentina
	_assert_true(s_outskirts.get_assigned_rival(&"kira") == &"nova", "S2.1: Non-mirror returns primary rival (Outskirts + Kira -> Nova)", "Got %s" % s_outskirts.get_assigned_rival(&"kira"))
	_assert_true(s_outskirts.get_assigned_rival(&"nova") == &"valentina", "S2.2: Mirror match returns secondary rival (Outskirts + Nova -> Valentina)", "Got %s" % s_outskirts.get_assigned_rival(&"nova"))

	# Abyss: rival=nyx, secondary=selene
	_assert_true(s_abyss.get_assigned_rival(&"nova") == &"nyx", "S2.3: Non-mirror returns primary rival (Abyss + Nova -> Nyx)", "Got %s" % s_abyss.get_assigned_rival(&"nova"))
	_assert_true(s_abyss.get_assigned_rival(&"nyx") == &"selene", "S2.4: Mirror match returns secondary rival (Abyss + Nyx -> Selene)", "Got %s" % s_abyss.get_assigned_rival(&"nyx"))

	# Storm: rival=roxy, secondary=kira
	_assert_true(s_storm.get_assigned_rival(&"selene") == &"roxy", "S2.5: Non-mirror returns primary rival (Storm + Selene -> Roxy)", "Got %s" % s_storm.get_assigned_rival(&"selene"))
	_assert_true(s_storm.get_assigned_rival(&"roxy") == &"kira", "S2.6: Mirror match returns secondary rival (Storm + Roxy -> Kira)", "Got %s" % s_storm.get_assigned_rival(&"roxy"))

	# Core: rival=estele, secondary=echo
	_assert_true(s_core.get_assigned_rival(&"roxy") == &"estele", "S2.7: Non-mirror returns primary rival (Core + Roxy -> Estele)", "Got %s" % s_core.get_assigned_rival(&"roxy"))
	_assert_true(s_core.get_assigned_rival(&"estele") == &"echo", "S2.8: Mirror match returns secondary rival (Core + Estele -> Echo)", "Got %s" % s_core.get_assigned_rival(&"estele"))

	# Fallback safety when secondary_rival_pilot_id is empty
	var custom_sector := SectorData.new()
	custom_sector.rival_pilot_id = &"echo"
	custom_sector.secondary_rival_pilot_id = &""
	_assert_true(custom_sector.get_assigned_rival(&"echo") == &"nyx", "S2.9: Empty secondary fallback defaults safely to Nyx", "Got %s" % custom_sector.get_assigned_rival(&"echo"))


# ==============================================================================
# SECTION 3: FULL 32-CASE COMBINATORIAL MATRIX ON LIVE MAINGAME INSTANCE
# 4 Sectors x 8 Playable Pilots = 32 distinct runtime combinations
# ==============================================================================
func _run_section_3_full_32_case_matrix_live_maingame() -> void:
	print("\n--- SECTION 3: Full 32-Case Matrix on Live MainGame Instance ---")

	var main_scene: PackedScene = load(MAIN_GAME_PATH)
	_assert_true(main_scene != null, "S3.0: MainGame scene loaded", "Cannot load %s" % MAIN_GAME_PATH)
	if not main_scene:
		return

	var mg: MainGame = main_scene.instantiate() as MainGame
	add_child(mg)

	if Dialogic:
		Dialogic.end_timeline()
	mg.is_briefing_active = false
	get_tree().paused = false

	var all_sectors: Array[Dictionary] = [
		{"id": &"sector_nebula_outskirts", "rival": &"nova", "secondary": &"valentina"},
		{"id": &"sector_void_abyss", "rival": &"nyx", "secondary": &"selene"},
		{"id": &"sector_plasma_storm", "rival": &"roxy", "secondary": &"kira"},
		{"id": &"sector_singularity_core", "rival": &"estele", "secondary": &"echo"},
	]

	var all_pilots: Array[StringName] = [&"nova", &"valentina", &"kira", &"selene", &"roxy", &"echo", &"nyx", &"estele"]

	var matrix_passes := 0
	var matrix_total := all_sectors.size() * all_pilots.size()

	for sec_info in all_sectors:
		var sec_id: StringName = sec_info["id"]
		var assigned_rival: StringName = sec_info["rival"]
		var secondary_rival: StringName = sec_info["secondary"]

		for pilot in all_pilots:
			# Configure SaveManager selection
			SaveManager.set_selected_sector(sec_id)
			SaveManager.set_selected_character(pilot)

			# Also update player node if present on MainGame
			if mg.player and mg.player.character_data:
				mg.player.character_data.character_id = pilot

			# Execute initialization & queue setup on MainGame
			mg._initialize_sector()
			mg._setup_rival_queue()

			var q: Array[StringName] = mg.rival_queue

			# 1. Queue size must be 5
			var size_ok: bool = (q.size() == 5)

			# 2. All 5 pilots in queue must be unique (no duplicate bosses)
			var unique_dict: Dictionary = {}
			for pid in q:
				unique_dict[pid] = true
			var unique_ok: bool = (unique_dict.size() == q.size())

			# 3. Player pilot must never be in rival queue
			var player_excluded: bool = not q.has(pilot)

			# 4. Check index 0 priority vs mirror fallback
			var index_0_ok: bool = false
			var expected_index_0: StringName = &""
			if pilot == assigned_rival:
				expected_index_0 = secondary_rival
				index_0_ok = (q.size() > 0 and q[0] == secondary_rival)
			else:
				expected_index_0 = assigned_rival
				index_0_ok = (q.size() > 0 and q[0] == assigned_rival)

			if size_ok and unique_ok and player_excluded and index_0_ok:
				matrix_passes += 1
			else:
				var err_detail := "Sector: %s, Player: %s | Queue: %s | Expected [0]: %s (got %s) | SizeOK: %s, UniqueOK: %s, PlayerExcluded: %s" % [
					sec_id, pilot, str(q), expected_index_0, (q[0] if q.size() > 0 else "EMPTY"), size_ok, unique_ok, player_excluded
				]
				_assert_true(false, "S3 Matrix Case [%s x %s]" % [sec_id, pilot], err_detail)

	_assert_true(matrix_passes == matrix_total,
		"S3.1: Complete 32-Case Matrix (4 sectors x 8 pilots) validated 100%% in live MainGame (%d/%d)" % [matrix_passes, matrix_total],
		"Only %d of %d matrix combinations succeeded" % [matrix_passes, matrix_total]
	)

	mg.queue_free()


# ==============================================================================
# SECTION 4: ADVERSARIAL STRESS TESTS & MALFORMED INPUT RECOVERY
# ==============================================================================
func _run_section_4_adversarial_and_boundary_cases() -> void:
	print("\n--- SECTION 4: Adversarial Stress Tests & Malformed Inputs ---")

	var main_scene: PackedScene = load(MAIN_GAME_PATH)
	var mg: MainGame = main_scene.instantiate() as MainGame
	add_child(mg)
	if Dialogic:
		Dialogic.end_timeline()
	mg.is_briefing_active = false
	get_tree().paused = false

	# Test 4.1: current_sector is null
	mg.current_sector = null
	SaveManager.set_selected_character(&"nova")
	if mg.player and mg.player.character_data:
		mg.player.character_data.character_id = &"nova"
	mg._setup_rival_queue()
	_assert_true(mg.rival_queue.size() == 5, "S4.1a: Null current_sector safely produces 5 rivals", "Size is %d" % mg.rival_queue.size())
	_assert_true(not mg.rival_queue.has(&"nova"), "S4.1b: Null current_sector never includes player nova", "Queue contains nova: %s" % str(mg.rival_queue))
	var u_dict_41: Dictionary = {}
	for p in mg.rival_queue:
		u_dict_41[p] = true
	_assert_true(u_dict_41.size() == 5, "S4.1c: Null current_sector has no duplicate bosses", "Duplicates found in %s" % str(mg.rival_queue))

	# Test 4.2: Player pilot is unknown/modded ID (e.g. &"alien_invader")
	SaveManager.set_selected_sector(&"sector_void_abyss")
	mg._initialize_sector()
	if mg.player and mg.player.character_data:
		mg.player.character_data.character_id = &"alien_invader"
	SaveManager.set_selected_character(&"alien_invader")
	mg._setup_rival_queue()
	_assert_true(mg.rival_queue.size() == 5, "S4.2a: Unknown player pilot produces 5 rivals", "Size: %d" % mg.rival_queue.size())
	_assert_true(mg.rival_queue[0] == &"nyx", "S4.2b: Sector Void Abyss assigned rival (nyx) remains index 0", "Got %s" % mg.rival_queue[0])
	_assert_true(not mg.rival_queue.has(&"alien_invader"), "S4.2c: Player alien_invader not in queue", "Queue: %s" % str(mg.rival_queue))

	# Test 4.3: Sector has invalid/alien rival_pilot_id
	var alien_sector := SectorData.new()
	alien_sector.sector_id = &"sector_martian_colony"
	alien_sector.rival_pilot_id = &"martian_warlord"
	alien_sector.secondary_rival_pilot_id = &"venus_empress"
	mg.current_sector = alien_sector
	if mg.player and mg.player.character_data:
		mg.player.character_data.character_id = &"nova"
	mg._setup_rival_queue()
	_assert_true(mg.rival_queue.size() == 5, "S4.3a: Custom alien sector produces 5 rivals", "Size: %d" % mg.rival_queue.size())
	_assert_true(mg.rival_queue[0] == &"martian_warlord", "S4.3b: Alien rival placed at index 0", "Got %s" % mg.rival_queue[0])
	_assert_true(not mg.rival_queue.has(&"nova"), "S4.3c: Player nova excluded from alien queue", "Queue: %s" % str(mg.rival_queue))

	# Test 4.4: Pathological double mirror match trap (primary == secondary == player_pid)
	var trap_sector := SectorData.new()
	trap_sector.sector_id = &"sector_trap"
	trap_sector.rival_pilot_id = &"kira"
	trap_sector.secondary_rival_pilot_id = &"kira"
	mg.current_sector = trap_sector
	if mg.player and mg.player.character_data:
		mg.player.character_data.character_id = &"kira"
	mg._setup_rival_queue()
	_assert_true(mg.rival_queue.size() == 5, "S4.4a: Pathological trap sector produces 5 rivals", "Size: %d" % mg.rival_queue.size())
	_assert_true(mg.rival_queue[0] != &"kira", "S4.4b: Secondary mirror trap cleanly averted; index 0 is not player (%s)" % mg.rival_queue[0], "Index 0 is kira!")
	_assert_true(not mg.rival_queue.has(&"kira"), "S4.4c: Player kira completely absent from trap queue", "Queue: %s" % str(mg.rival_queue))

	# Test 4.5: Precedence order (player.character_data vs SaveManager fallback)
	# Case 1: player.character_data is set to echo, SaveManager has nova
	SaveManager.set_selected_sector(&"sector_singularity_core")
	mg._initialize_sector() # rival=estele, secondary=echo
	SaveManager.set_selected_character(&"nova")
	if mg.player and mg.player.character_data:
		mg.player.character_data.character_id = &"echo"
	mg._setup_rival_queue()
	# Because player is echo, sector rival is estele (not mirror). So index 0 is estele.
	# But echo (the player) must NOT be anywhere in the queue!
	_assert_true(mg.rival_queue[0] == &"estele", "S4.5a: player.character_data precedence keeps Estele at [0]", "Got %s" % mg.rival_queue[0])
	_assert_true(not mg.rival_queue.has(&"echo"), "S4.5b: player.character_data echo excluded from queue", "Queue has echo: %s" % str(mg.rival_queue))

	# Case 2: player.character_data is empty string, falls back to SaveManager
	if mg.player and mg.player.character_data:
		mg.player.character_data.character_id = &""
	SaveManager.set_selected_character(&"estele")
	mg._setup_rival_queue()
	# Mirror match with estele -> index 0 must be echo!
	_assert_true(mg.rival_queue[0] == &"echo", "S4.5c: SaveManager fallback activates and triggers mirror swap to echo", "Got %s" % mg.rival_queue[0])
	_assert_true(not mg.rival_queue.has(&"estele"), "S4.5d: Player estele excluded via SaveManager fallback", "Queue: %s" % str(mg.rival_queue))

	mg.queue_free()


# ==============================================================================
# SECTION 5: SPAWN & DEFEAT ENCOUNTER PIPELINE (RIVAL BOSS + CHEST)
# ==============================================================================
func _run_section_5_spawn_and_defeat_encounter_pipeline() -> void:
	print("\n--- SECTION 5: Spawn & Defeat Encounter Pipeline ---")

	var main_scene: PackedScene = load(MAIN_GAME_PATH)
	var mg: MainGame = main_scene.instantiate() as MainGame
	add_child(mg)
	if Dialogic:
		Dialogic.end_timeline()
	mg.is_briefing_active = false
	get_tree().paused = false

	# Setup sector void abyss with player nova
	SaveManager.set_selected_sector(&"sector_void_abyss")
	SaveManager.set_selected_character(&"nova")
	if mg.player and mg.player.character_data:
		mg.player.character_data.character_id = &"nova"
	mg._initialize_sector()
	mg._setup_rival_queue()

	var expected_first_rival: StringName = mg.rival_queue[0]
	_assert_true(expected_first_rival == &"nyx", "S5.1: Expected first rival in Void Abyss is Nyx", "Got %s" % expected_first_rival)

	# Trigger rival pilot spawn
	mg._spawn_rival_pilot()
	_assert_true(mg.current_rival != null, "S5.2: Rival pilot spawned and stored in mg.current_rival", "current_rival is null")

	if mg.current_rival:
		var r_pilot_id = mg.current_rival.get("pilot_id")
		_assert_true(r_pilot_id == expected_first_rival, "S5.3: Spawned rival matches queue[0] (%s)" % expected_first_rival, "Spawned %s instead" % r_pilot_id)

		# Verify warning banner activated
		if mg.crisis_banner:
			var is_active = mg.crisis_banner.get("is_active")
			_assert_true(is_active == true, "S5.4: CrisisAlertBanner activated upon rival spawn", "Banner not active")

		# Record spawn position
		var boss_pos: Vector2 = mg.current_rival.global_position

		# Now simulate rival defeat
		mg._on_rival_defeated(r_pilot_id, null)
		_assert_true(mg.current_rival == null, "S5.5: current_rival reset to null after defeat", "current_rival not null")
		_assert_true(mg.rivals_killed.has(r_pilot_id), "S5.6: Defeated rival added to rivals_killed list", "rivals_killed missing %s" % r_pilot_id)

		# Wait one frame for call_deferred add_child to execute
		await get_tree().process_frame

		# Check that StellarRewardChest was spawned in the tree
		var chests = get_tree().get_nodes_in_group("stellar_chests")
		_assert_true(chests.size() > 0, "S5.7: StellarRewardChest instantiated and added to tree", "No stellar_chests found in group")

		if chests.size() > 0:
			var chest: StellarRewardChest = chests[-1] as StellarRewardChest
			_assert_true(chest != null, "S5.8: Chest node is StellarRewardChest instance", "Chest is not StellarRewardChest")
			if chest:
				_assert_true(chest.reward_biomass == mg.current_sector.reward_biomass,
					"S5.9: Chest reward_biomass (%d) matches Void Abyss (%d)" % [chest.reward_biomass, mg.current_sector.reward_biomass],
					"Mismatch biomass")
				_assert_true(chest.reward_dark_matter == mg.current_sector.reward_dark_matter,
					"S5.10: Chest reward_dark_matter (%d) matches Void Abyss (%d)" % [chest.reward_dark_matter, mg.current_sector.reward_dark_matter],
					"Mismatch dark matter")
				_assert_true(chest.reward_antimatter == mg.current_sector.reward_antimatter,
					"S5.11: Chest reward_antimatter (%d) matches Void Abyss (%d)" % [chest.reward_antimatter, mg.current_sector.reward_antimatter],
					"Mismatch antimatter")

				# Permadeath check: When player is dead, collect must be rejected
				var initial_biomass := SaveManager.get_biomass()
				mg.player.is_dead = true
				chest._collect()
				_assert_true(SaveManager.get_biomass() == initial_biomass, "S5.12: Permadeath prevents chest collection at 0 HP / dead", "Biomass increased while dead!")
				_assert_true(chest.is_collected == false, "S5.13: Chest remains uncollected when dead player triggers area", "is_collected set to true!")

				# Revive player and collect
				mg.player.is_dead = false
				mg.player.current_health = 100.0
				chest.player = mg.player
				chest._collect()
				_assert_true(chest.is_collected == true, "S5.14: Chest collected successfully for alive player", "Chest not collected")

				# Double-collection debounce check
				var bio_after_first := SaveManager.get_biomass()
				chest._collect() # Second immediate call
				_assert_true(SaveManager.get_biomass() == bio_after_first, "S5.15: Debounce prevents rapid double-pickup exploitation", "Biomass increased on second collect!")

				chest.queue_free()

	mg.queue_free()


# ==============================================================================
# SECTION 6: SAVE & RESUME QUEUE SERIALIZATION
# ==============================================================================
func _run_section_6_save_resume_queue_serialization() -> void:
	print("\n--- SECTION 6: Save & Resume Queue Serialization ---")

	var main_scene: PackedScene = load(MAIN_GAME_PATH)
	var mg: MainGame = main_scene.instantiate() as MainGame
	add_child(mg)
	if Dialogic:
		Dialogic.end_timeline()
	mg.is_briefing_active = false
	get_tree().paused = false

	# Setup custom state
	SaveManager.set_selected_sector(&"sector_plasma_storm")
	SaveManager.set_selected_character(&"kira")
	if mg.player and mg.player.character_data:
		mg.player.character_data.character_id = &"kira"
	mg._initialize_sector()
	mg._setup_rival_queue()

	var original_queue := mg.rival_queue.duplicate()
	_assert_true(original_queue.size() == 5, "S6.1: Initial queue populated with 5 entries", "Size is %d" % original_queue.size())
	_assert_true(original_queue[0] == &"roxy", "S6.2: Initial queue index 0 is roxy", "Got %s" % original_queue[0])

	# Test serialization via get_current_run_state()
	var state := mg.get_current_run_state()
	_assert_true(state.has("rival_queue"), "S6.3: Run state dictionary contains 'rival_queue' key", "Missing rival_queue in state")
	var serialized_queue: Array = state.get("rival_queue", [])
	_assert_true(serialized_queue.size() == 5, "S6.4: Serialized rival_queue has 5 elements", "Size is %d" % serialized_queue.size())
	_assert_true(StringName(serialized_queue[0]) == &"roxy", "S6.5: Serialized queue preserves roxy at [0]", "Got %s" % serialized_queue[0])

	# Modify queue and restore from state
	mg.rival_queue.clear()
	_assert_true(mg.rival_queue.is_empty(), "S6.6: Rival queue cleared manually", "Queue not empty")

	mg.restore_run_state(state)
	_assert_true(mg.rival_queue.size() == 5, "S6.7: Restored rival_queue has 5 elements", "Size is %d" % mg.rival_queue.size())
	_assert_true(mg.rival_queue == original_queue, "S6.8: Restored rival_queue exactly matches original queue array", "Mismatch: %s vs %s" % [str(mg.rival_queue), str(original_queue)])

	mg.queue_free()

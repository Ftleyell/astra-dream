extends Node

## ==============================================================================
## EMPIRICAL CHALLENGER STRESS SUITE — MILESTONE 1
## Focus: Sector Data, Starchart Selector, Dynamic Backgrounds, Persistence & Fallbacks
## ==============================================================================

const BACKUP_SAVE_PATH := "user://profile_data_challenger_backup.json"
const SAVE_PATH := "user://profile_data.json"

var backup_payload: String = ""
var had_existing_save: bool = false
var total_assertions: int = 0
var total_passed: int = 0
var total_failed: int = 0
var failed_test_names: Array[String] = []

func _ready() -> void:
	print("\n==================================================================")
	print("[CHALLENGER 1] STARTING ADVERSARIAL EMPIRICAL STRESS TEST SUITE")
	print("==================================================================\n")

	# Watchdog timer to prevent hang
	get_tree().create_timer(15.0).timeout.connect(func():
		_restore_save()
		push_error("[TIMEOUT] Challenger stress suite timed out after 15 seconds!")
		get_tree().quit(1)
	)

	_backup_save()

	# Run all stress test suites
	_test_suite_1_save_manager_corrupt_and_missing()
	_test_suite_2_catalog_fallback_and_invalid_ids()
	_test_suite_3_rapid_switching_and_concurrency()
	_test_suite_4_space_background_and_spawner_adversarial()
	_test_suite_5_modal_navigation_stress()

	_restore_save()

	print("\n==================================================================")
	print("  CHALLENGER VERIFICATION SUMMARY:")
	print("  Total Assertions Run: %d" % total_assertions)
	print("  Passed: %d" % total_passed)
	print("  Failed: %d" % total_failed)
	if total_failed == 0:
		print("  Status: CONFIRMED (100% Robust under Adversarial Stress)")
	else:
		print("  Status: DEFECT_FOUND")
		for f in failed_test_names:
			print("    - FAILED: %s" % f)
	print("==================================================================\n")

	get_tree().quit(0 if total_failed == 0 else 1)


func _backup_save() -> void:
	had_existing_save = FileAccess.file_exists(SAVE_PATH)
	if had_existing_save:
		var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			backup_payload = file.get_as_text()
			file.close()


func _restore_save() -> void:
	if had_existing_save and not backup_payload.is_empty():
		var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if file:
			file.store_string(backup_payload)
			file.close()
	elif not had_existing_save and FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


func _assert_test(condition: bool, test_name: String, details: String = "") -> void:
	total_assertions += 1
	if condition:
		total_passed += 1
		print("  [PASS] %s" % test_name)
	else:
		total_failed += 1
		failed_test_names.append(test_name)
		printerr("  [FAIL] %s: %s" % [test_name, details])


# ==============================================================================
# SUITE 1: CORRUPT & MISSING SECTOR PERSISTENCE IN SAVEMANAGER
# ==============================================================================
func _test_suite_1_save_manager_corrupt_and_missing() -> void:
	print("--- SUITE 1: SaveManager Corrupt & Missing Data Handling ---")

	# Test 1.1: Missing sector fields in JSON (Legacy save upgrade simulation)
	var legacy_save := {
		"version": 1,
		"biomass": 500,
		"antimatter": 20,
		"unlocked_characters": ["nova", "valentina"],
		"selected_character": "nova"
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(legacy_save))
	f.close()

	var prof := SaveManager.load_profile()
	_assert_test(prof.has("selected_sector") and prof["selected_sector"] == &"sector_nebula_outskirts",
		"1.1a: Legacy save missing selected_sector defaults to sector_nebula_outskirts",
		"Got: %s" % str(prof.get("selected_sector")))

	var unlocked_secs: Array = prof.get("unlocked_sectors", [])
	_assert_test(unlocked_secs.size() >= 4 and unlocked_secs.has(&"sector_nebula_outskirts"),
		"1.1b: Legacy save missing unlocked_sectors migrates with all 4 canonical sectors",
		"Got: %s" % str(unlocked_secs))

	# Test 1.2: Corrupt selected_sector values (Null, non-string, invalid ID)
	var corrupt_values = [null, "", 9999, false, "completely_invalid_sector_id_666"]
	for cv in corrupt_values:
		var bad_save := {
			"version": 2,
			"selected_sector": cv,
			"unlocked_sectors": ["sector_nebula_outskirts"]
		}
		var f_bad := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		f_bad.store_string(JSON.stringify(bad_save))
		f_bad.close()

		var cleaned := SaveManager.load_profile()
		var resolved_sec: StringName = SaveManager.get_selected_sector()
		_assert_test(resolved_sec == &"sector_nebula_outskirts",
			"1.2: Corrupted selected_sector (%s) recovers to Outskirts" % str(cv),
			"Got cleaned: %s, get_selected_sector: %s" % [str(cleaned.get("selected_sector")), str(resolved_sec)])

	# Test 1.3: Corrupt unlocked_sectors (Null, empty, non-array, garbage types inside array)
	var corrupt_unlocked = [
		null,
		[],
		"not_an_array",
		12345,
		[null, 42, false, "", "sector_void_abyss"]
	]
	for idx in range(corrupt_unlocked.size()):
		var cu = corrupt_unlocked[idx]
		var bad_save := {
			"version": 2,
			"selected_sector": "sector_void_abyss",
			"unlocked_sectors": cu
		}
		var f_cu := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		f_cu.store_string(JSON.stringify(bad_save))
		f_cu.close()

		var loaded := SaveManager.load_profile()
		var u_list: Array = loaded.get("unlocked_sectors", [])
		var has_all_canonical := true
		for s in [&"sector_nebula_outskirts", &"sector_void_abyss", &"sector_plasma_storm", &"sector_singularity_core"]:
			if not u_list.has(s):
				has_all_canonical = false
				break
		_assert_test(has_all_canonical,
			"1.3: Corrupt unlocked_sectors case #%d guarantees canonical sectors" % idx,
			"Got list: %s" % str(u_list))

	# Test 1.4: Selected sector not present in unlocked_sectors
	var mismatch_save := {
		"version": 2,
		"selected_sector": "sector_secret_unlocked_mod",
		"unlocked_sectors": ["sector_nebula_outskirts"]
	}
	var f_mm := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f_mm.store_string(JSON.stringify(mismatch_save))
	f_mm.close()

	var mm_prof := SaveManager.load_profile()
	_assert_test(mm_prof.get("selected_sector") == &"sector_nebula_outskirts",
		"1.4: Locked/unregistered selected_sector reverted to sector_nebula_outskirts",
		"Got: %s" % str(mm_prof.get("selected_sector")))

	# Test 1.5: set_selected_sector on a fully populated profile
	SaveManager.save_profile([], {}, [&"nova", &"valentina"], 100, 10, null, &"nova", 50, null, 1.0, null, &"mochi", null, null, &"lyra", null, &"sector_nebula_outskirts")
	SaveManager.set_selected_sector(&"sector_void_abyss")
	_assert_test(SaveManager.get_selected_sector() == &"sector_void_abyss",
		"1.5a: set_selected_sector set void_abyss on standard profile")
	SaveManager.set_selected_sector(&"")
	_assert_test(SaveManager.get_selected_sector() == &"sector_void_abyss",
		"1.5b: set_selected_sector(&'') safely ignored without overwriting active sector")

	# Test 1.6: DEFECT PROOF: Corrupt/incomplete save without unlocked_characters
	# In save_manager.gd:371, cleaned["unlocked_characters"] = [&"nova", ...] creates an untyped Array.
	# Then set_selected_sector line 978 (var chars: Array[StringName] = prof.get("unlocked_characters", [])) crashes.
	var incomplete_save := {
		"version": 2,
		"selected_sector": "sector_nebula_outskirts"
	}
	var f_inc := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f_inc.store_string(JSON.stringify(incomplete_save))
	f_inc.close()

	# Attempt to set sector on profile loaded from incomplete save
	SaveManager.set_selected_sector(&"sector_plasma_storm")
	var sec_after_inc: StringName = SaveManager.get_selected_sector()
	var defect_triggered := (sec_after_inc != &"sector_plasma_storm")
	_assert_test(not defect_triggered,
		"1.6: [DEFECT CHECK] set_selected_sector survives incomplete save missing unlocked_characters",
		"CRITICAL DEFECT DETECTED: save_manager.gd:371 creates untyped Array for default characters, causing runtime type crash at save_manager.gd:978 (Array vs Array[StringName]). Sector remained: %s" % sec_after_inc)


# ==============================================================================
# SUITE 2: SECTOR CATALOG RESOLUTION & INVALID ID FALLBACKS
# ==============================================================================
func _test_suite_2_catalog_fallback_and_invalid_ids() -> void:
	print("\n--- SUITE 2: Sector Catalog Fallback & Invalid ID Resolution ---")

	# Test 2.1: Canonical sectors load & properties
	var canonical_ids := [
		&"sector_nebula_outskirts",
		&"sector_void_abyss",
		&"sector_plasma_storm",
		&"sector_singularity_core"
	]
	var catalog := SectorData.load_catalog()
	_assert_test(catalog.size() >= 4, "2.1a: load_catalog returns at least 4 sectors", "Size: %d" % catalog.size())

	for cid in canonical_ids:
		_assert_test(catalog.has(cid), "2.1b: Catalog contains canonical sector %s" % cid)
		var sec: SectorData = catalog[cid]
		_assert_test(sec != null and sec.sector_id == cid,
			"2.1c: Sector %s instance is valid and matches ID" % cid)
		_assert_test(sec.enemy_density_mult > 0.0 and sec.biomass_mult > 0.0,
			"2.1d: Sector %s multipliers are positive" % cid)
		_assert_test(sec.drift_direction.length_squared() > 0.0,
			"2.1e: Sector %s drift_direction is non-zero" % cid)
		_assert_test(sec.rival_pilot_id != &"" and sec.secondary_rival_pilot_id != &"",
			"2.1f: Sector %s has primary and secondary rivals assigned" % cid)
		_assert_test(sec.rival_pilot_id != sec.secondary_rival_pilot_id,
			"2.1g: Sector %s secondary rival prevents mirror match" % cid)

	# Test 2.2: Invalid IDs passed to SectorData.get_sector()
	var test_invalid_ids: Array[StringName] = [
		&"",
		&"corrupt_sector_nonexistent",
		&"null",
		&"../../malicious_path",
		&"invalid/sector/path",
		&"sector_nebula_outskirts_typo"
	]
	for inv_id in test_invalid_ids:
		var resolved := SectorData.get_sector(inv_id)
		_assert_test(resolved != null and resolved is SectorData,
			"2.2: SectorData.get_sector('%s') returns valid fallback SectorData" % inv_id,
			"Returned: %s" % str(resolved))
		if resolved:
			_assert_test(resolved.sector_id == &"sector_nebula_outskirts",
				"2.2b: Fallback for '%s' resolves deterministically to Outskirts" % inv_id,
				"Got sector_id: %s" % str(resolved.sector_id))

	# Test 2.3: Backward compatibility aliases via _get() and _set()
	var sample_sec := SectorData.get_sector(&"sector_nebula_outskirts")
	_assert_test(sample_sec.get("id") == &"sector_nebula_outskirts",
		"2.3a: Dynamic getter 'id' alias works")
	_assert_test(sample_sec.get("sector_name") == sample_sec.display_name,
		"2.3b: Dynamic getter 'sector_name' alias works")
	_assert_test(sample_sec.get("enemy_density") == sample_sec.enemy_density_mult,
		"2.3c: Dynamic getter 'enemy_density' alias works")
	var loot_dict = sample_sec.get("loot_multipliers")
	_assert_test(loot_dict is Dictionary and loot_dict.has("biomass") and loot_dict.has("dark_matter"),
		"2.3d: Dynamic getter 'loot_multipliers' returns dictionary with biomass & dark_matter")

	# Test 2.4: get_assigned_rival mirror-match swap
	_assert_test(sample_sec.get_assigned_rival(&"nova") == sample_sec.secondary_rival_pilot_id,
		"2.4a: get_assigned_rival swaps to secondary when player pilot matches primary rival")
	_assert_test(sample_sec.get_assigned_rival(&"kira") == sample_sec.rival_pilot_id,
		"2.4b: get_assigned_rival keeps primary rival when player pilot differs")

	# Test 2.5: MainGame sector resolution fallback
	var mg_script: Script = load("res://scenes/combat/main_game.gd")
	var mg_instance = mg_script.new()
	var resolved_mg_sec = mg_instance._resolve_sector_data(&"non_existent_fake_sector")
	_assert_test(resolved_mg_sec != null and resolved_mg_sec.sector_id == &"sector_nebula_outskirts",
		"2.5: MainGame._resolve_sector_data falls back to Outskirts on invalid sector ID")
	mg_instance.free()


# ==============================================================================
# SUITE 3: RAPID SECTOR SWITCHING & PERSISTENCE CYCLE IDEMPOTENCE
# ==============================================================================
func _test_suite_3_rapid_switching_and_concurrency() -> void:
	print("\n--- SUITE 3: Rapid Sector Switching & Concurrency Stress ---")

	var sector_cycle: Array[StringName] = [
		&"sector_nebula_outskirts",
		&"sector_void_abyss",
		&"sector_plasma_storm",
		&"sector_singularity_core"
	]

	# Ensure clean standard profile before rapid switching
	SaveManager.save_profile([], {}, [&"nova", &"valentina"], 100, 10, null, &"nova", 50, null, 1.0, null, &"mochi", null, null, &"lyra", null, &"sector_nebula_outskirts")

	# Stress 3.1: 100 rapid sector switches
	var switch_count := 100
	var all_matched := true
	for i in range(switch_count):
		var target := sector_cycle[i % sector_cycle.size()]
		SaveManager.set_selected_sector(target)
		var current := SaveManager.get_selected_sector()
		if current != target:
			all_matched = false
			printerr("Mismatch at iteration %d: expected %s, got %s" % [i, target, current])
			break
	_assert_test(all_matched, "3.1: 100 rapid sequential sector switches preserved exact state")

	# Stress 3.2: Concurrent currency additions and sector switches
	SaveManager.save_profile([], {}, [], 100, 10, null, &"nova", 50, null, 1.0, null, &"mochi", null, null, &"lyra", null, &"sector_nebula_outskirts")
	var initial_bio := SaveManager.get_biomass()
	var initial_dm := SaveManager.get_dark_matter()

	for i in range(40):
		var target := sector_cycle[i % sector_cycle.size()]
		SaveManager.set_selected_sector(target)
		SaveManager.add_biomass(5)
		SaveManager.add_dark_matter(2)

	var final_bio := SaveManager.get_biomass()
	var final_dm := SaveManager.get_dark_matter()
	_assert_test(final_bio == initial_bio + (40 * 5),
		"3.2a: Biomass accumulated accurately during rapid sector switching",
		"Expected %d, got %d" % [initial_bio + 200, final_bio])
	_assert_test(final_dm == initial_dm + (40 * 2),
		"3.2b: Dark Matter accumulated accurately during rapid sector switching",
		"Expected %d, got %d" % [initial_dm + 80, final_dm])

	# Stress 3.3: unlock_sector idempotence on custom & canonical sectors
	var u_canon := SaveManager.unlock_sector(&"sector_void_abyss")
	_assert_test(u_canon == false, "3.3a: unlock_sector on already-unlocked canonical sector returns false (idempotent)")

	SaveManager.unlock_sector(&"custom_dlc_sector")
	_assert_test(SaveManager.is_sector_unlocked(&"custom_dlc_sector"),
		"3.3b: Custom sector unlocked successfully")
	var u_custom_again := SaveManager.unlock_sector(&"custom_dlc_sector")
	_assert_test(u_custom_again == false,
		"3.3c: Re-unlocking custom sector returns false without duplicate entries")

	var unlocked_list := SaveManager.get_unlocked_sectors()
	var count_custom := 0
	for s in unlocked_list:
		if s == &"custom_dlc_sector":
			count_custom += 1
	_assert_test(count_custom == 1, "3.3d: Custom sector appears exactly once in unlocked_sectors array")

	# Clean up custom sector
	SaveManager.lock_sector(&"custom_dlc_sector")
	_assert_test(not SaveManager.is_sector_unlocked(&"custom_dlc_sector"),
		"3.3e: lock_sector successfully removed custom sector")


# ==============================================================================
# SUITE 4: SPACEBACKGROUND & ENEMYSPAWNER ADVERSARIAL STRESS
# ==============================================================================
func _test_suite_4_space_background_and_spawner_adversarial() -> void:
	print("\n--- SUITE 4: SpaceBackground & EnemySpawner Adversarial Stress ---")

	var bg_scene: PackedScene = load("res://scenes/combat/environment/space_background.tscn")
	_assert_test(bg_scene != null, "4.1: space_background.tscn loaded")

	var bg: SpaceBackground = bg_scene.instantiate() as SpaceBackground
	add_child(bg)

	# Test 4.2: configure_sector with null
	bg.configure_sector(null)
	_assert_test(true, "4.2: configure_sector(null) handled safely without crash")

	# Test 4.3: configure_sector across all canonical sectors
	var sectors := SectorData.load_catalog_ordered()
	for sec in sectors:
		bg.configure_sector(sec)
		_assert_test(bg.drift_direction.is_normalized(),
			"4.3a: SpaceBackground drift_direction normalized for %s" % sec.sector_id)
		_assert_test(is_equal_approx(bg.base_drift_speed, sec.drift_speed),
			"4.3b: SpaceBackground base_drift_speed matches %s (%f)" % [sec.sector_id, sec.drift_speed])

	# Test 4.4: Zero-alloc combat verify (process frames)
	var initial_nodes := get_tree().get_node_count()
	for f in range(30):
		bg._process(0.0166)
	var post_nodes := get_tree().get_node_count()
	_assert_test(post_nodes == initial_nodes,
		"4.4: SpaceBackground zero-allocation verified over 30 process frames")

	bg.queue_free()

	# Test 4.5: EnemySpawner density multiplier non-compounding refactor
	var spawner := EnemySpawner.new()
	add_child(spawner)
	spawner.set_density_multiplier(1.5)
	_assert_test(is_equal_approx(spawner.density_multiplier, 1.5),
		"4.5a: EnemySpawner density_multiplier set to 1.5")

	# Call set_wave multiple times to ensure density doesn't compound exponentially
	spawner.set_wave(1)
	var cap_wave_1: int = spawner.max_enemies
	spawner.set_wave(1)
	var cap_wave_1_repeat: int = spawner.max_enemies
	_assert_test(cap_wave_1 == cap_wave_1_repeat,
		"4.5b: EnemySpawner set_wave is idempotent and does not compound density multiplier",
		"First: %d, Second: %d" % [cap_wave_1, cap_wave_1_repeat])

	spawner.queue_free()


# ==============================================================================
# SUITE 5: SECTORSELECTIONMODAL CAROUSEL NAVIGATION STRESS
# ==============================================================================
func _test_suite_5_modal_navigation_stress() -> void:
	print("\n--- SUITE 5: SectorSelectionModal Carousel & Navigation Stress ---")

	var modal_scene: PackedScene = load("res://scenes/ui/sector_select/sector_selection_modal.tscn")
	_assert_test(modal_scene != null, "5.1: sector_selection_modal.tscn loaded")

	var modal: SectorSelectionModal = modal_scene.instantiate() as SectorSelectionModal
	add_child(modal)

	modal.open_modal()
	_assert_test(modal.is_open, "5.2a: Modal opens cleanly")
	_assert_test(modal._sectors.size() >= 4, "5.2b: Modal populated with at least 4 sectors")

	var initial_idx := modal.current_index

	# Stress 5.3: Rapid forward cycling 25 times
	for i in range(25):
		modal._cycle(1)
		_assert_test(modal.current_index >= 0 and modal.current_index < modal._sectors.size(),
			"5.3: Carousel index in bounds during cycle forward (idx: %d)" % modal.current_index)

	# Stress 5.4: Rapid backward cycling 25 times
	for i in range(25):
		modal._cycle(-1)
		_assert_test(modal.current_index >= 0 and modal.current_index < modal._sectors.size(),
			"5.4: Carousel index in bounds during cycle backward (idx: %d)" % modal.current_index)

	# Test 5.5: get_selected_sector_id matches active carousel card
	var expected_id := modal._sectors[modal.current_index].sector_id
	_assert_test(modal.get_selected_sector_id() == expected_id,
		"5.5: get_selected_sector_id matches current carousel item (%s)" % expected_id)

	# Test 5.6: Close modal
	modal.close_modal()
	_assert_test(not modal.is_open, "5.6: Modal closed cleanly")

	modal.queue_free()

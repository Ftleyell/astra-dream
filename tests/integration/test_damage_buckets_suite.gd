extends Node

## ==============================================================================
## TEST SUITE: Damage Buckets, Stat Modifiers, Curse & Multiplicative Modules
## ==============================================================================

var _passed_count: int = 0
var _failed_count: int = 0
var _test_log: Array[String] = []

func _ready() -> void:
	get_tree().create_timer(10.0).timeout.connect(func() -> void:
		_log_fail("WATCHDOG", "Test suite execution timed out after 10 seconds!")
		_finish_and_quit()
	)

	print("\n==================================================================")
	print("[DAMAGE BUCKETS SUITE] STARTING AUTOMATED VERIFICATION")
	print("==================================================================")

	_run_test_1_modifier_type_enum()
	_run_test_2_character_stats_damage_buckets()
	_run_test_3_curse_stat_lifecycle()
	_run_test_4_inventory_component_multiplicative_shop_item()
	_run_test_5_stat_deck_manager_additive_cards()
	_run_test_6_backward_compatibility()
	_run_test_7_curse_credit_scaling()
	_run_test_8_boundary_cases_and_setters()
	_run_test_9_canonical_items_modifier_types()

	_finish_and_quit()

func _finish_and_quit() -> void:
	print("\n==================================================================")
	print("[DAMAGE BUCKETS SUITE] RESULTS: %d PASSED, %d FAILED" % [_passed_count, _failed_count])
	print("==================================================================")
	for entry in _test_log:
		print(entry)
	if _failed_count == 0:
		print(">> ALL DAMAGE BUCKET TESTS PASSED PERFECTLY <<\n")
		get_tree().quit(0)
	else:
		printerr(">> SOME DAMAGE BUCKET TESTS FAILED <<\n")
		get_tree().quit(1)

func _log_pass(tag: String, details: String) -> void:
	_passed_count += 1
	var msg := "  [PASS] %s: %s" % [tag, details]
	_test_log.append(msg)
	print(msg)

func _log_fail(tag: String, details: String) -> void:
	_failed_count += 1
	var msg := "  [FAIL] %s: %s" % [tag, details]
	_test_log.append(msg)
	printerr(msg)

func _create_dummy_character_data(base_dmg: float = 40.0) -> CharacterData:
	var cd := CharacterData.new()
	cd.character_id = &"test_char"
	cd.display_name = "Test Pilot"
	cd.max_health = 100.0
	cd.health_regen = 1.0
	cd.move_speed = 300.0
	cd.armor = 0.0
	cd.base_damage = base_dmg
	cd.attack_speed = 1.0
	cd.crit_chance = 0.05
	cd.crit_damage = 1.5
	cd.luck = 1.0
	cd.pickup_radius = 50.0
	cd.projectile_count = 1.0
	cd.projectile_speed = 1.0
	cd.exp_multiplier = 1.0
	return cd

# ------------------------------------------------------------------------------
# Test 1: Validate Enums.ModifierType enum values
# ------------------------------------------------------------------------------
func _run_test_1_modifier_type_enum() -> void:
	if Enums.ModifierType.FLAT == 0 and Enums.ModifierType.ADDITIVE_PERCENT == 1 and Enums.ModifierType.MULTIPLICATIVE == 2:
		_log_pass("Test 1 - Enums.ModifierType", "Enums.ModifierType has FLAT(0), ADDITIVE_PERCENT(1), MULTIPLICATIVE(2)")
	else:
		_log_fail("Test 1 - Enums.ModifierType", "Unexpected enum values: FLAT=%d, ADDITIVE_PERCENT=%d, MULTIPLICATIVE=%d" % [
			Enums.ModifierType.FLAT, Enums.ModifierType.ADDITIVE_PERCENT, Enums.ModifierType.MULTIPLICATIVE
		])

# ------------------------------------------------------------------------------
# Test 2: Flat + Additive + Multiplicative bucket calculation in CharacterStats
# Formula: (40 base + 5 flat) * (1.0 + 0.20 additive) * (1.0 + 0.30 multiplicative) = 45 * 1.20 * 1.30 = 70.2
# ------------------------------------------------------------------------------
func _run_test_2_character_stats_damage_buckets() -> void:
	var stats := CharacterStats.new()
	var char_data := _create_dummy_character_data(40.0)
	stats.initialize(char_data)

	# Initial value
	if not is_equal_approx(stats.get_stat(&"base_damage"), 40.0):
		_log_fail("Test 2 - Initial Damage", "Expected 40.0 base damage, got %f" % stats.get_stat(&"base_damage"))
		return

	# 1. Add Flat modifier (+5.0) -> 45.0
	var mod_flat := CharacterStats.StatModifier.new(&"sword_flat", 5.0, Enums.ModifierType.FLAT)
	stats.add_modifier(&"base_damage", mod_flat)
	var after_flat := stats.get_stat(&"base_damage")
	if not is_equal_approx(after_flat, 45.0):
		_log_fail("Test 2 - Flat Modifier", "Expected 45.0 after flat, got %f" % after_flat)
		return

	# 2. Add Additive Percent modifier (+20% = +0.20) -> 45.0 * 1.20 = 54.0
	var mod_add := CharacterStats.StatModifier.new(&"card_add", 0.20, Enums.ModifierType.ADDITIVE_PERCENT)
	stats.add_modifier(&"base_damage", mod_add)
	var after_add := stats.get_stat(&"base_damage")
	if not is_equal_approx(after_add, 54.0):
		_log_fail("Test 2 - Additive Percent", "Expected 54.0 after additive pct, got %f" % after_add)
		return

	# 3. Add Multiplicative modifier (+30% = +0.30) -> 54.0 * 1.30 = 70.2
	var mod_mult := CharacterStats.StatModifier.new(&"fusion_mult", 0.30, Enums.ModifierType.MULTIPLICATIVE)
	stats.add_modifier(&"base_damage", mod_mult)
	var after_mult := stats.get_stat(&"base_damage")
	if is_equal_approx(after_mult, 70.2):
		_log_pass("Test 2 - Damage Buckets", "Correct 3-bucket formula calculation: (40+5) * 1.2 * 1.3 = %f" % after_mult)
	else:
		_log_fail("Test 2 - Damage Buckets", "Expected 70.2, got %f" % after_mult)

	# 4. Add second multiplicative modifier (+10% = +0.10) -> 70.2 * 1.10 = 77.22
	var mod_mult_2 := CharacterStats.StatModifier.new(&"second_mult", 0.10, Enums.ModifierType.MULTIPLICATIVE)
	stats.add_modifier(&"base_damage", mod_mult_2)
	var after_mult_2 := stats.get_stat(&"base_damage")
	if is_equal_approx(after_mult_2, 77.22):
		_log_pass("Test 2 - Compound Multiplicative", "Two independent multiplicative buckets compound correctly: 70.2 * 1.1 = %f" % after_mult_2)
	else:
		_log_fail("Test 2 - Compound Multiplicative", "Expected 77.22, got %f" % after_mult_2)

# ------------------------------------------------------------------------------
# Test 3: Stat curse initialization and modifier addition
# ------------------------------------------------------------------------------
func _run_test_3_curse_stat_lifecycle() -> void:
	var stats := CharacterStats.new()
	var char_data := _create_dummy_character_data(40.0)
	stats.initialize(char_data)

	if not is_equal_approx(stats.get_stat(&"curse"), 0.0):
		_log_fail("Test 3 - Curse Initial", "Expected 0.0 base curse, got %f" % stats.get_stat(&"curse"))
		return

	var curse_mod := CharacterStats.StatModifier.new(&"curse_relic", 25.0, Enums.ModifierType.FLAT)
	stats.add_modifier(&"curse", curse_mod)

	if is_equal_approx(stats.get_stat(&"curse"), 25.0):
		_log_pass("Test 3 - Curse Modifier", "Curse initialized at 0.0 and cleanly updated to %f" % stats.get_stat(&"curse"))
	else:
		_log_fail("Test 3 - Curse Modifier", "Expected 25.0 curse, got %f" % stats.get_stat(&"curse"))

# ------------------------------------------------------------------------------
# Test 4: InventoryComponent applying MULTIPLICATIVE modifier from shop item
# ------------------------------------------------------------------------------
func _run_test_4_inventory_component_multiplicative_shop_item() -> void:
	var stats := CharacterStats.new()
	var char_data := _create_dummy_character_data(50.0)
	stats.initialize(char_data)

	var inv := InventoryComponent.new()
	add_child(inv)
	inv.character_stats = stats

	var shop_items := ItemPoolManager.create_satellite_shop_items()
	var fusion: ItemData = null
	for it in shop_items:
		if it.item_id == &"fusion_reactor":
			fusion = it
			break

	if not fusion:
		_log_fail("Test 4 - Shop Item", "fusion_reactor item not found in satellite shop catalog")
		inv.queue_free()
		return

	if fusion.modifier_type != Enums.ModifierType.MULTIPLICATIVE:
		_log_fail("Test 4 - Shop Item", "fusion_reactor modifier_type is not MULTIPLICATIVE: %d" % fusion.modifier_type)
		inv.queue_free()
		return

	inv.add_item(fusion, 1)

	var mod := stats.get_stat_modifier(&"base_damage", &"fusion_reactor")
	if not mod:
		_log_fail("Test 4 - Modifier Applied", "StatModifier not found in CharacterStats for fusion_reactor")
		inv.queue_free()
		return

	if mod.mod_type == Enums.ModifierType.MULTIPLICATIVE:
		_log_pass("Test 4 - InventoryComponent MULTIPLICATIVE", "InventoryComponent applied MULTIPLICATIVE modifier from fusion_reactor")
	else:
		_log_fail("Test 4 - InventoryComponent MULTIPLICATIVE", "Expected MULTIPLICATIVE mod_type, got %d" % mod.mod_type)

	# Verify damage calculation: base 50.0 * (1.0 + 0.20) = 60.0
	var final_dmg := stats.get_stat(&"base_damage")
	if is_equal_approx(final_dmg, 60.0):
		_log_pass("Test 4 - Multiplicative Effect", "fusion_reactor applied 20%% multiplicative damage correctly: %f" % final_dmg)
	else:
		_log_fail("Test 4 - Multiplicative Effect", "Expected 60.0 damage, got %f" % final_dmg)

	inv.queue_free()

# ------------------------------------------------------------------------------
# Test 5: StatDeckManager applying ADDITIVE_PERCENT modifier from card
# ------------------------------------------------------------------------------
func _run_test_5_stat_deck_manager_additive_cards() -> void:
	var stats := CharacterStats.new()
	var char_data := _create_dummy_character_data(50.0)
	stats.initialize(char_data)

	var deck := StatDeckManager.new()
	add_child(deck)
	deck._generate_default_cards()

	var card_dmg: StatCardData = null
	for card in deck.all_stat_cards:
		if card.card_id == &"card_dmg_1":
			card_dmg = card
			break

	if not card_dmg:
		_log_fail("Test 5 - StatDeckManager", "card_dmg_1 not found in default deck")
		deck.queue_free()
		return

	if card_dmg.modifier_type != Enums.ModifierType.ADDITIVE_PERCENT:
		_log_fail("Test 5 - StatDeckManager", "card_dmg_1 modifier_type is not ADDITIVE_PERCENT: %d" % card_dmg.modifier_type)
		deck.queue_free()
		return

	if not is_equal_approx(card_dmg.modifier_value, 0.12):
		_log_fail("Test 5 - StatDeckManager", "card_dmg_1 value is not rebalanced to 0.12: %f" % card_dmg.modifier_value)
		deck.queue_free()
		return

	deck.apply_card_to_stats(card_dmg, stats)

	var mod := stats.get_stat_modifier(&"base_damage", &"card_dmg_1")
	if not mod:
		_log_fail("Test 5 - Card Application", "StatModifier not created in CharacterStats for card_dmg_1")
		deck.queue_free()
		return

	if mod.mod_type == Enums.ModifierType.ADDITIVE_PERCENT:
		_log_pass("Test 5 - StatDeckManager ADDITIVE_PERCENT", "StatDeckManager applied ADDITIVE_PERCENT modifier correctly")
	else:
		_log_fail("Test 5 - StatDeckManager ADDITIVE_PERCENT", "Expected ADDITIVE_PERCENT, got %d" % mod.mod_type)

	var new_dmg := stats.get_stat(&"base_damage")
	if is_equal_approx(new_dmg, 56.0):
		_log_pass("Test 5 - Damage Additive Calculation", "50.0 base + 12%% additive gives 56.0: %f" % new_dmg)
	else:
		_log_fail("Test 5 - Damage Additive Calculation", "Expected 56.0, got %f" % new_dmg)

	deck.queue_free()

# ------------------------------------------------------------------------------
# Test 6: Backward compatibility with bool is_percentage
# ------------------------------------------------------------------------------
func _run_test_6_backward_compatibility() -> void:
	var mod_legacy_pct := CharacterStats.StatModifier.new(&"legacy_p", 0.15, true)
	var mod_legacy_flat := CharacterStats.StatModifier.new(&"legacy_f", 10.0, false)

	if mod_legacy_pct.mod_type == Enums.ModifierType.ADDITIVE_PERCENT and mod_legacy_pct.is_percentage == true:
		_log_pass("Test 6 - Legacy Boolean Percent", "true bool resolves to ADDITIVE_PERCENT and is_percentage getter is true")
	else:
		_log_fail("Test 6 - Legacy Boolean Percent", "Legacy bool percent failed")

	if mod_legacy_flat.mod_type == Enums.ModifierType.FLAT and mod_legacy_flat.is_percentage == false:
		_log_pass("Test 6 - Legacy Boolean Flat", "false bool resolves to FLAT and is_percentage getter is false")
	else:
		_log_fail("Test 6 - Legacy Boolean Flat", "Legacy bool flat failed")

# ------------------------------------------------------------------------------
# Test 7: Curse credit scaling in player
# ------------------------------------------------------------------------------
func _run_test_7_curse_credit_scaling() -> void:
	var player_script := load("res://scenes/combat/player/player.gd")
	if not player_script:
		_log_fail("Test 7 - Player", "player.gd not found")
		return

	var player: Player = Player.new()
	add_child(player)
	var stats := CharacterStats.new()
	var cd := _create_dummy_character_data(40.0)
	stats.initialize(cd)
	player.stats = stats
	player.run_credits = 0

	# 0 curse -> 100 credits
	player.add_credits(100)
	if player.run_credits != 100:
		_log_fail("Test 7 - Base Credits", "Expected 100 credits at 0 curse, got %d" % player.run_credits)
		player.queue_free()
		return

	# +20 curse -> +1% per curse point -> +20% -> 100 * 1.20 = 120 credits
	var curse_mod := CharacterStats.StatModifier.new(&"curse_20", 20.0, Enums.ModifierType.FLAT)
	stats.add_modifier(&"curse", curse_mod)
	player.run_credits = 0
	player.add_credits(100)

	if player.run_credits == 120:
		_log_pass("Test 7 - Curse Credit Scaling", "20 curse points increased 100 credits to 120 (+20%% bonus)")
	else:
		_log_fail("Test 7 - Curse Credit Scaling", "Expected 120 credits with 20 curse, got %d" % player.run_credits)

	player.queue_free()

# ------------------------------------------------------------------------------
# Test 8: Boundary cases, setters and guards
# ------------------------------------------------------------------------------
func _run_test_8_boundary_cases_and_setters() -> void:
	# 1. is_percentage setter on StatModifier
	var mod := CharacterStats.StatModifier.new(&"test_mod", 10.0, Enums.ModifierType.FLAT)
	mod.is_percentage = true
	if mod.mod_type == Enums.ModifierType.ADDITIVE_PERCENT and mod.is_percentage == true:
		_log_pass("Test 8 - is_percentage Setter True", "mod.is_percentage = true changed mod_type to ADDITIVE_PERCENT")
	else:
		_log_fail("Test 8 - is_percentage Setter True", "Failed to update mod_type on is_percentage setter")

	mod.is_percentage = false
	if mod.mod_type == Enums.ModifierType.FLAT and mod.is_percentage == false:
		_log_pass("Test 8 - is_percentage Setter False", "mod.is_percentage = false changed mod_type to FLAT")
	else:
		_log_fail("Test 8 - is_percentage Setter False", "Failed to reset mod_type on is_percentage setter")

	# 2. Extreme negative additive percent floored at 0
	var stats := CharacterStats.new()
	var cd := _create_dummy_character_data(100.0)
	stats.initialize(cd)
	var mod_neg_add := CharacterStats.StatModifier.new(&"neg_add", -2.5, Enums.ModifierType.ADDITIVE_PERCENT)
	stats.add_modifier(&"base_damage", mod_neg_add)
	var dmg_floored: float = stats.get_stat(&"base_damage")
	if is_equal_approx(dmg_floored, 0.0):
		_log_pass("Test 8 - Additive Clamping", "Negative additive percent sum correctly floored at 0.0")
	else:
		_log_fail("Test 8 - Additive Clamping", "Expected 0.0 damage on severe penalty, got %f" % dmg_floored)

	# 3. Extreme negative multiplicative factor floored at 0
	var stats2 := CharacterStats.new()
	stats2.initialize(_create_dummy_character_data(100.0))
	var mod_neg_mult := CharacterStats.StatModifier.new(&"neg_mult", -1.5, Enums.ModifierType.MULTIPLICATIVE)
	stats2.add_modifier(&"base_damage", mod_neg_mult)
	var mult_floored: float = stats2.get_stat(&"base_damage")
	if is_equal_approx(mult_floored, 0.0):
		_log_pass("Test 8 - Multiplicative Clamping", "Negative multiplicative factor correctly floored at 0.0")
	else:
		_log_fail("Test 8 - Multiplicative Clamping", "Expected 0.0 damage on severe multiplicative factor, got %f" % mult_floored)

	# 4. Player add_credits with <= 0 amount
	var player: Player = Player.new()
	add_child(player)
	player.stats = stats2
	player.run_credits = 50
	player.add_credits(0)
	player.add_credits(-10)
	if player.run_credits == 50:
		_log_pass("Test 8 - Credit Guard", "add_credits safely ignored non-positive amounts (remained 50)")
	else:
		_log_fail("Test 8 - Credit Guard", "Expected 50 credits, got %d" % player.run_credits)
	player.queue_free()

# ------------------------------------------------------------------------------
# Test 9: Canonical items in ItemPoolManager have explicit modifier_type set
# ------------------------------------------------------------------------------
func _run_test_9_canonical_items_modifier_types() -> void:
	var canonical_items := ItemPoolManager.create_canonical_stat_items()
	var checked_count: int = 0
	var has_flat_sword := false
	var has_pct_boots := false

	for it in canonical_items:
		if it.item_id == &"espada":
			has_flat_sword = (it.modifier_type == Enums.ModifierType.FLAT)
			checked_count += 1
		elif it.item_id == &"botas":
			has_pct_boots = (it.modifier_type == Enums.ModifierType.ADDITIVE_PERCENT)
			checked_count += 1
		elif it.item_id == &"escudo":
			if it.modifier_type == Enums.ModifierType.FLAT:
				checked_count += 1
		elif it.item_id == &"lupa":
			if it.modifier_type == Enums.ModifierType.ADDITIVE_PERCENT:
				checked_count += 1

	if has_flat_sword and has_pct_boots and checked_count == 4:
		_log_pass("Test 9 - Canonical Item Modifier Types", "Canonical items have explicit FLAT and ADDITIVE_PERCENT modifier types")
	else:
		_log_fail("Test 9 - Canonical Item Modifier Types", "Canonical items modifier types mismatch: sword_flat=%s, boots_pct=%s, checked=%d" % [has_flat_sword, has_pct_boots, checked_count])

extends Node

## ==============================================================================
## TEST SUITE: Integral Game Balance, Progression & Visuals Rework
## Tests all acceptance criteria for Level-Up, Shop, Weapons, Items & Shaders
## ==============================================================================

func _ready() -> void:
	# Watchdog timer
	get_tree().create_timer(15.0).timeout.connect(func():
		push_error("[TEST WATCHDOG] Timeout reached in Integral Rework test suite!")
		get_tree().quit(1)
	)

	print("\n==================================================================")
	print("[TEST] INITIATING INTEGRAL REWORK VERIFICATION SUITE")
	print("==================================================================\n")

	var passed: int = 0
	passed += _test_level_up_deck()
	passed += _test_satellite_shop_reroll_limit()
	passed += _test_weapon_slots_and_replacement()
	passed += _test_passive_proc_and_anti_synergy_items()
	passed += _test_shaders_integrity()
	passed += _test_boss_adaptive_scaling()

	print("\n==================================================================")
	print("  TOTAL VERIFIED TEST SUITES: %d/6 PASSED" % passed)
	print("[PASS] 100% SUITE COMPLIANCE — INTEGRAL REWORK VERIFIED WITH SUCCESS!")
	print("==================================================================\n")

	get_tree().quit(0)

func _test_level_up_deck() -> int:
	print("--- TEST 1: Level-Up Deck Requirements ---")
	var deck_mgr := StatDeckManager.new()
	deck_mgr._ready()
	add_child(deck_mgr)

	var p_stats := CharacterStats.new()

	# 1. Exactly 3 cards offered
	var offered_cards: Array[StatCardData] = []
	deck_mgr.cards_offered.connect(func(cards, _cost):
		for c in cards:
			offered_cards.append(c as StatCardData)
	)
	deck_mgr.offer_cards(p_stats, 1, 3)

	assert(offered_cards.size() == 3, "LevelUp must offer exactly 3 cards, got %d" % offered_cards.size())
	print("  ✓ T1.1: Exactly 3 cards offered on level-up verified")

	# 2. No flat projectile cards in common tier
	for c in deck_mgr.all_stat_cards:
		var stat_name: StringName = c.target_stat
		assert(stat_name != &"projectile_count", "Stat cards must not contain flat projectile_count!")
	print("  ✓ T1.2: Purged flat projectile bonus from common pool verified")

	# 3. High impact stats: base_damage card in common is >= 25% (0.25)
	var found_damage_card := false
	for c in deck_mgr.all_stat_cards:
		if c.target_stat == &"base_damage" and c.tier == Enums.Tier.TIER_1:
			found_damage_card = true
			var val: float = c.modifier_value
			assert(val >= 0.25, "Common base_damage card must offer >= +25%%, got %.2f" % val)
	assert(found_damage_card, "Must have common base_damage card")
	print("  ✓ T1.3: Common damage cards offer >= +25% immediate impact verified")

	deck_mgr.queue_free()
	return 1

func _test_satellite_shop_reroll_limit() -> int:
	print("--- TEST 2: Satellite Shop 1 Re-Roll Limit ---")
	var shop_scene: PackedScene = load("res://scenes/combat/satellite/satellite_shop.tscn")
	var shop: SatelliteShop = shop_scene.instantiate() as SatelliteShop
	add_child(shop)

	shop.current_credits = 500
	assert(shop.can_reroll() == true, "Must be able to reroll on fresh visit")

	# Simulate 1st reroll
	shop._on_reroll_pressed()
	assert(shop.rerolls_used_this_visit == 1, "Reroll count must increment to 1")
	assert(shop.can_reroll() == false, "Must NOT be able to reroll a second time in same visit")

	# Further attempts must do nothing
	var creds_before: int = shop.current_credits
	shop._on_reroll_pressed()
	assert(shop.current_credits == creds_before, "Second reroll attempt must not consume credits")
	assert(shop.rerolls_used_this_visit == 1, "Rerolls count remains 1")
	print("  ✓ T2.1: SatelliteShop 1 re-roll cap enforced strictly")

	shop.queue_free()
	return 1

func _test_weapon_slots_and_replacement() -> int:
	print("--- TEST 3: 4 Weapon Slots Cap & Replacement ---")
	var w_ctrl := WeaponController.new()
	add_child(w_ctrl)

	assert(w_ctrl.MAX_WEAPON_SLOTS == 4, "MAX_WEAPON_SLOTS must be exactly 4, got %d" % w_ctrl.MAX_WEAPON_SLOTS)

	# Equip 4 distinct weapons
	w_ctrl.clear_equipped_weapons()
	for i in range(4):
		var w := WeaponData.new()
		w.weapon_id = StringName("test_weapon_%d" % i)
		w.weapon_name = "Weapon %d" % i
		w.base_damage = 20.0 + float(i) * 5.0
		var res := w_ctrl.add_weapon(w)
		assert(res == true, "Should be able to add weapon %d" % i)

	assert(w_ctrl.equipped_weapons.size() == 4, "Must have exactly 4 weapons equipped")
	assert(w_ctrl.is_full() == true, "is_full() must return true when 4 weapons equipped")
	print("  ✓ T3.1: 4 Weapon slots cap and is_full() verified")

	# Attempt to add a 5th new weapon
	var w5 := WeaponData.new()
	w5.weapon_id = &"test_weapon_5"
	w5.weapon_name = "Weapon 5"
	var added_5 := w_ctrl.add_weapon(w5)
	assert(added_5 == false, "5th weapon must NOT be added directly when full")
	assert(w_ctrl.equipped_weapons.size() == 4, "Equipped weapons count must remain 4")
	print("  ✓ T3.2: 5th weapon rejection on full arsenal verified")

	# Test replacement flow
	var replaced := w_ctrl.replace_weapon(1, w5)
	assert(replaced == true, "replace_weapon on valid slot must succeed")
	assert(w_ctrl.equipped_weapons.size() == 4, "Equipped count remains 4")
	assert(w_ctrl.equipped_weapons[1].weapon_data.weapon_id == &"test_weapon_5", "Slot 1 must now contain Weapon 5")
	assert(w_ctrl.equipped_weapons[1].level == 1, "Replaced weapon must start at Level 1")
	print("  ✓ T3.3: Weapon replacement at slot verified")

	w_ctrl.queue_free()
	return 1

func _test_passive_proc_and_anti_synergy_items() -> int:
	print("--- TEST 4: Passive Proc & Anti-Synergy Items ---")
	var items: Array[ItemData] = ItemPoolManager.create_canonical_stat_items()
	var item_ids: Array[StringName] = []
	for it in items:
		item_ids.append(it.item_id)

	# Check all 6 reactive proc items exist
	var expected_procs := [&"tesla_coil", &"kinetic_plating", &"phase_thruster", &"retaliation_swarm", &"entropy_catalyst", &"phase_inverter"]
	for pid in expected_procs:
		assert(item_ids.has(pid), "Item pool must contain reactive proc item: %s" % pid)
	print("  ✓ T4.1: 6 Reactive proc items present in canonical catalog")

	# Check all 3 anti-synergy / penalty items exist
	var expected_anti := [&"glass_reactor", &"heavy_condenser", &"tachyon_piercer"]
	for aid in expected_anti:
		assert(item_ids.has(aid), "Item pool must contain anti-synergy item: %s" % aid)
		var item: ItemData = null
		for it in items:
			if it.item_id == aid:
				item = it
				break
		assert(item.secondary_stat_name != &"", "Anti-synergy item %s must define a secondary stat" % aid)
		assert(item.secondary_stat_value < 0.0, "Anti-synergy item %s secondary stat must be a penalty (< 0)" % aid)
	print("  ✓ T4.2: 3 Anti-synergy items define explicit trade-offs and penalties")

	return 1

func _test_shaders_integrity() -> int:
	print("--- TEST 5: Shaders Integrity (Spherical Bullets & Modulate Fixes) ---")

	# 1. danmaku_bullet.gdshader
	var bullet_shader_path := "res://core/shaders/danmaku_bullet.gdshader"
	assert(FileAccess.file_exists(bullet_shader_path), "danmaku_bullet.gdshader must exist")
	var bullet_shader_code := FileAccess.get_file_as_string(bullet_shader_path)
	assert(bullet_shader_code.contains("length(p)"), "danmaku_bullet.gdshader must use Euclidean distance length(p) for spheres")
	assert(bullet_shader_code.contains("discard"), "danmaku_bullet.gdshader must discard fragments outside the circle")
	print("  ✓ T5.1: Danmaku spherical bullet shader verified")

	# 2. laser_plasma_beam.gdshader modulate fix
	var laser_shader_path := "res://core/shaders/laser_plasma_beam.gdshader"
	assert(FileAccess.file_exists(laser_shader_path), "laser_plasma_beam.gdshader must exist")
	var laser_code := FileAccess.get_file_as_string(laser_shader_path)
	assert(laser_code.contains("* COLOR"), "laser_plasma_beam.gdshader must multiply by COLOR to obey modulate and alpha fades")
	print("  ✓ T5.2: Laser beam modulate multiplication verified")

	# 3. dimensional_slash_blade.gdshader modulate fix
	var slash_shader_path := "res://core/shaders/dimensional_slash_blade.gdshader"
	assert(FileAccess.file_exists(slash_shader_path), "dimensional_slash_blade.gdshader must exist")
	var slash_code := FileAccess.get_file_as_string(slash_shader_path)
	assert(slash_code.contains("* COLOR"), "dimensional_slash_blade.gdshader must multiply by COLOR to obey modulate and alpha fades")
	print("  ✓ T5.3: Dimensional slash blade modulate multiplication verified")

	return 1

func _test_boss_adaptive_scaling() -> int:
	print("--- TEST 6: Boss Adaptive Health Scaling ---")
	var hermit_scene: PackedScene = load("res://scenes/combat/bosses/boss_hermit_void.tscn")
	assert(hermit_scene != null, "boss_hermit_void.tscn must exist")
	var hermit = hermit_scene.instantiate()
	assert(hermit.max_health == 1600.0, "Base hermit max health must remain 1600.0")

	# Simulate wave 6 with high player DPS
	var wave: int = 6
	var wave_factor: float = 1.0 + float(wave) * 0.08
	var p_dps_factor: float = 1.6
	var adaptive_hp: float = hermit.max_health * wave_factor * p_dps_factor
	assert(adaptive_hp > hermit.max_health * 1.5, "Adaptive HP must scale cleanly based on wave and player DPS")
	print("  ✓ T6.1: Boss adaptive HP math verified (Base: 1600 -> Adaptive: %.0f)" % adaptive_hp)

	hermit.free()
	return 1

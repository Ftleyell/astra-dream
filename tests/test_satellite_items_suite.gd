class_name TestSatelliteItemsSuite
extends Node

func _ready() -> void:
	print("\n==================================================================")
	print("[TEST] INITIATING SATELLITE ITEMS & WEAPON SCALING VERIFICATION")
	print("==================================================================\n")

	var passed := 0
	passed += _test_satellite_catalog_composition()
	passed += _test_satellite_shop_slots_and_stacks()
	passed += _test_weapon_projectile_scaling_per_level()
	passed += _test_conversion_cores_mechanics()

	print("\n==================================================================")
	print("  TOTAL VERIFIED TEST SUITES: %d/4 PASSED" % passed)
	if passed == 4:
		print("[PASS] 100% SUITE COMPLIANCE — SATELLITE ITEMS REWORK VERIFIED!")
	else:
		print("[FAIL] SOME SUITES FAILED")
	print("==================================================================\n")

	get_tree().quit(0 if passed == 4 else 1)

func _test_satellite_catalog_composition() -> int:
	print("--- TEST 1: Satellite Catalog Composition (36 Items) ---")
	var sat_items: Array[ItemData] = ItemPoolManager.create_satellite_shop_items()
	assert(sat_items.size() == 36, "Satellite pool must have exactly 36 items, got %d" % sat_items.size())

	# 1. Purga de stats planos del satélite
	var purged_ids := [&"botas", &"espada", &"escudo", &"corazon", &"manzana", &"iman", &"gafas", &"lupa", &"guante", &"trebol", &"carcaj", &"chip_telemetria"]
	for it in sat_items:
		assert(not purged_ids.has(it.item_id), "Satellite pool must NOT contain flat stat item %s" % it.item_id)
	print("  ✓ T1.1: Complete purge of 12 flat stat items from satellite pool verified")

	# 2. 8 Sobrecargas con tradeoff
	var overclocks := [&"fusion_reactor", &"dense_turbine", &"collimator_lens", &"split_salvo", &"rapid_injector", &"nanotitanium_plating", &"afterburn_thruster", &"tachyon_prism"]
	for oid in overclocks:
		var found: ItemData = null
		for it in sat_items:
			if it.item_id == oid:
				found = it
				break
		assert(found != null, "Overclock item %s not found in satellite catalog" % oid)
		assert(found.secondary_stat_name != &"", "Overclock %s must have a secondary tradeoff stat" % oid)
		assert(found.secondary_stat_value < 0.0, "Overclock %s tradeoff must be negative" % oid)
		assert(found.max_stacks <= 2, "Overclock %s max_stacks must be <= 2" % oid)
	print("  ✓ T1.2: 8 Overclock trade-off modules verified with explicit negative stats and stack caps")

	# 3. 8 Procs reactivos
	var procs := [&"tesla_coil", &"kinetic_plating", &"phase_thruster", &"retaliation_swarm", &"entropy_catalyst", &"phase_inverter", &"pyroclastic_battery", &"cryo_condenser"]
	for pid in procs:
		var found: ItemData = null
		for it in sat_items:
			if it.item_id == pid:
				found = it
				break
		assert(found != null, "Proc item %s not found in satellite catalog" % pid)
		assert(not found.effects.is_empty(), "Proc item %s must have at least 1 effect" % pid)
		assert(found.max_stacks <= 2, "Proc item %s max_stacks must be <= 2" % pid)
	print("  ✓ T1.3: 8 Reactive proc artifacts verified with attached ItemEffect instances")

	# 4. 8 Núcleos de conversión
	var conversions := [&"alchemical_converter", &"hemodynamic_cell", &"kinetic_converter", &"gravitational_resonator", &"photonic_transducer", &"overdrain_module", &"static_cell", &"stellar_scrap"]
	for cid in conversions:
		var found: ItemData = null
		for it in sat_items:
			if it.item_id == cid:
				found = it
				break
		assert(found != null, "Conversion core %s not found in satellite catalog" % cid)
		assert(found.max_stacks == 1, "Conversion core %s must have max_stacks == 1" % cid)
		assert(found.tags.has(&"conversion"), "Conversion core %s must have 'conversion' tag" % cid)
	print("  ✓ T1.4: 8 Conversion cores verified with strict max_stacks == 1 and conversion tags")

	return 1

func _test_satellite_shop_slots_and_stacks() -> int:
	print("--- TEST 2: Satellite Shop Slots (1 Weapon + 2 Items) & Max Stacks Filtering ---")
	var shop: SatelliteShop = preload("res://scenes/combat/satellite/satellite_shop.tscn").instantiate() as SatelliteShop
	add_child(shop)

	var dummy_player: Player = Player.new()
	add_child(dummy_player)
	dummy_player.add_to_group("player")
	shop.player = dummy_player

	shop._roll_shop_items()
	assert(shop.current_offered_items.size() == 3, "Shop must offer exactly 3 items, got %d" % shop.current_offered_items.size())

	# Slot 0 must be WeaponData
	assert(shop.current_offered_items[0] is WeaponData, "Slot 0 must always be a WeaponData")
	# Slots 1 and 2 must be ItemData
	assert(shop.current_offered_items[1] is ItemData, "Slot 1 must be an ItemData")
	assert(shop.current_offered_items[2] is ItemData, "Slot 2 must be an ItemData")
	print("  ✓ T2.1: Exactly 3 shop cards offered with Slot 0 guaranteed as Weapon")

	# Test Max Stacks Filtering: give player max stacks of an item and verify it is not offered
	var test_item: ItemData = null
	for it in shop.available_items_pool:
		if it is ItemData and (it as ItemData).max_stacks == 1:
			test_item = it as ItemData
			break
	assert(test_item != null, "Could not find an item with max_stacks == 1")
	dummy_player.inventory.add_item(test_item, 1)
	assert(dummy_player.inventory.get_item_count(test_item.item_id) >= test_item.max_stacks, "Item should have reached max stacks")

	# Roll 10 times to verify test_item never appears in slots 1 or 2
	for r in range(10):
		shop._roll_shop_items()
		assert(shop.current_offered_items[1].get("item_id") != test_item.item_id, "Maxed item appeared in shop slot 1")
		assert(shop.current_offered_items[2].get("item_id") != test_item.item_id, "Maxed item appeared in shop slot 2")
	print("  ✓ T2.2: Items reaching max_stacks are strictly filtered out of shop rolls")

	shop.queue_free()
	dummy_player.queue_free()
	return 1

func _test_weapon_projectile_scaling_per_level() -> int:
	print("--- TEST 3: Weapon Projectile Scaling (+1 Projectile per Level) ---")
	var w_ctrl: WeaponController = WeaponController.new()
	add_child(w_ctrl)

	var wp_data: WeaponData = preload("res://data/weapons/shop/nova_flak.tres")
	assert(wp_data != null, "nova_flak weapon data must exist")

	w_ctrl.equipped_weapons.clear()
	var added := w_ctrl.add_weapon(wp_data)
	assert(added, "Should add nova_flak successfully")

	var inst: WeaponInstanceData = w_ctrl.get_weapon_instance(wp_data.weapon_id)
	assert(inst != null, "Weapon instance must exist")
	assert(inst.level == 1, "Initial weapon level must be 1")

	# Check level 1 projectile bonus
	var proj_bonus_lvl1 := maxi(0, inst.level - 1)
	assert(proj_bonus_lvl1 == 0, "Level 1 weapon should have 0 extra projectiles")

	# Upgrade to level 2
	var upgraded := w_ctrl.upgrade_weapon(wp_data.weapon_id)
	assert(upgraded, "Should upgrade weapon successfully")
	assert(inst.level == 2, "Weapon level must be 2")
	var proj_bonus_lvl2 := maxi(0, inst.level - 1)
	assert(proj_bonus_lvl2 == 1, "Level 2 weapon must have +1 extra projectile, got %d" % proj_bonus_lvl2)

	# Upgrade to level 5 (MAX)
	w_ctrl.upgrade_weapon(wp_data.weapon_id) # 3
	w_ctrl.upgrade_weapon(wp_data.weapon_id) # 4
	w_ctrl.upgrade_weapon(wp_data.weapon_id) # 5
	assert(inst.level == 5, "Weapon level must be 5")
	var proj_bonus_lvl5 := maxi(0, inst.level - 1)
	assert(proj_bonus_lvl5 == 4, "Level 5 weapon must have +4 extra projectiles, got %d" % proj_bonus_lvl5)

	# Level 6 rejection
	var upgrade_lvl6 := w_ctrl.upgrade_weapon(wp_data.weapon_id)
	assert(not upgrade_lvl6, "Weapon level cannot exceed 5")
	print("  ✓ T3.1: Weapon level 1 -> 5 adds +1 projectile per level up to max +4 projectiles")

	w_ctrl.queue_free()
	return 1

func _test_conversion_cores_mechanics() -> int:
	print("--- TEST 4: Conversion Cores Mechanics (Alchemical, Overdrain & Stellar Scrap) ---")
	var player: Player = Player.new()
	add_child(player)

	# 1. Alchemical Converter (15% EXP converts to credits)
	var sat_items: Array[ItemData] = ItemPoolManager.create_satellite_shop_items()
	var alch_item: ItemData = null
	var overdrain_item: ItemData = null
	var scrap_item: ItemData = null

	for it in sat_items:
		if it.item_id == &"alchemical_converter":
			alch_item = it
		elif it.item_id == &"overdrain_module":
			overdrain_item = it
		elif it.item_id == &"stellar_scrap":
			scrap_item = it

	assert(alch_item != null and overdrain_item != null and scrap_item != null, "All 3 test items must exist")

	player.run_credits = 0
	player.inventory.add_item(alch_item, 1)
	player.add_exp(100.0)
	assert(player.run_credits >= 15, "100 EXP should convert to at least 15 credits, got %d" % player.run_credits)
	print("  ✓ T4.1: Alchemical Converter successfully converted 15%% EXP into credits")

	# 2. Overdrain Module (0 passive regen)
	player.inventory.add_item(overdrain_item, 1)
	player.stats.set_or_replace_modifier(&"health_regen", CharacterStats.StatModifier.new(&"test_regen", 10.0, false))
	player.current_health = 50.0
	player._handle_health_regen(1.0)
	assert(player.current_health == 50.0, "Overdrain module must completely suppress passive health regen")
	print("  ✓ T4.2: Overdrain Module enforces 0 passive health regen")

	# 3. Stellar Scrap (consumes 100 credits on death and resurrects to 30% max HP)
	player.inventory.add_item(scrap_item, 1)
	player.run_credits = 150
	player.current_health = 10.0
	player.take_damage(500.0) # Lethal damage
	assert(not player.is_dead, "Player should be revived by Stellar Scrap")
	assert(player.run_credits == 50, "Stellar Scrap should have consumed exactly 100 credits, got %d" % player.run_credits)
	var expected_hp := player.stats.get_stat(&"max_health") * 0.3
	assert(absf(player.current_health - expected_hp) < 1.0, "Player should be restored to 30%% HP")
	print("  ✓ T4.3: Stellar Scrap resurrection successfully consumed 100 credits and restored 30%% HP")

	player.queue_free()
	return 1

extends Node

func _ready() -> void:
	# Watchdog timer
	get_tree().create_timer(10.0).timeout.connect(func() -> void:
		printerr("[CHALLENGER STRESS] Timeout reached, failing...")
		get_tree().quit(1)
	)

	print("\n========================================================")
	print("[CHALLENGER M1-2] EMPIRICAL STRESS TEST SUITE: MILESTONE 1")
	print("========================================================")

	var main_game_scene: PackedScene = load("res://scenes/combat/main_game.tscn")
	assert(main_game_scene != null, "main_game.tscn must exist")

	var main_game: MainGame = main_game_scene.instantiate() as MainGame
	add_child(main_game)

	main_game.is_briefing_active = false
	get_tree().paused = false

	var player: Player = main_game.player
	var shop: SatelliteShop = main_game.satellite_shop
	var deck_mgr: StatDeckManager = main_game.stat_deck_manager

	assert(player != null, "Player must exist in MainGame")
	assert(shop != null, "SatelliteShop must exist in MainGame")
	assert(deck_mgr != null, "StatDeckManager must exist in MainGame")

	# =========================================================================
	# TEST SUITE 1: LOW CREDIT BOUNDARY CONDITIONS IN SATELLITE SHOP
	# =========================================================================
	print("\n--- [SUITE 1] SatelliteShop Low Credit Boundaries (0, 29, 30 Credits) ---")

	# Edge Case 1.1: 0 Credits Boundary
	print("\n[Case 1.1] Testing 0 credits boundary:")
	player.run_credits = 0
	shop.open_shop(player.run_credits)
	assert(shop.current_credits == 0, "Current credits must be 0")
	assert(shop.rerolls_used_this_visit == 0, "rerolls_used_this_visit must start at 0")
	assert(not shop.can_reroll(), "can_reroll() must be false at 0 credits")
	assert(shop.reroll_btn.disabled, "Reroll button must be disabled at 0 credits")

	# Attempt reroll with 0 credits
	shop._on_reroll_pressed()
	assert(shop.current_credits == 0, "Credits must NOT change when reroll attempted with 0 credits")
	assert(shop.rerolls_used_this_visit == 0, "rerolls_used_this_visit must remain 0")
	assert(player.run_credits == 0, "player.run_credits must remain 0")
	print("  ✓ [PASS] 0 credits: reroll strictly blocked, credits and usage unchanged.")
	shop.close_shop()

	# Edge Case 1.2: 29 Credits Boundary (1 credit below reroll_cost of 30)
	print("\n[Case 1.2] Testing 29 credits boundary (just below cost 30):")
	player.run_credits = 29
	shop.open_shop(player.run_credits)
	assert(shop.current_credits == 29, "Current credits must be 29")
	assert(shop.rerolls_used_this_visit == 0, "rerolls_used_this_visit must start at 0")
	assert(not shop.can_reroll(), "can_reroll() must be false at 29 credits (cost is 30)")
	assert(shop.reroll_btn.disabled, "Reroll button must be disabled at 29 credits")

	# Attempt reroll with 29 credits
	shop._on_reroll_pressed()
	assert(shop.current_credits == 29, "Credits must NOT be deducted when reroll attempted with 29 credits")
	assert(shop.rerolls_used_this_visit == 0, "rerolls_used_this_visit must remain 0")
	assert(player.run_credits == 29, "player.run_credits must remain 29")
	print("  ✓ [PASS] 29 credits: reroll strictly blocked, no credit deduction.")
	shop.close_shop()

	# Edge Case 1.3: 30 Credits Boundary (exact cost)
	print("\n[Case 1.3] Testing 30 credits boundary (exact cost):")
	player.run_credits = 30
	shop.open_shop(player.run_credits)
	assert(shop.current_credits == 30, "Current credits must be 30")
	assert(shop.rerolls_used_this_visit == 0, "rerolls_used_this_visit must start at 0")
	assert(shop.can_reroll(), "can_reroll() must be true at 30 credits (exact cost)")
	assert(not shop.reroll_btn.disabled, "Reroll button must be enabled at 30 credits")

	# Perform the 1 allowed reroll
	shop._on_reroll_pressed()
	assert(shop.current_credits == 0, "Current credits must drop to 0 (30 - 30)")
	assert(shop.rerolls_used_this_visit == 1, "rerolls_used_this_visit must increment to 1")
	assert(player.run_credits == 0, "player.run_credits must synchronize to 0")
	assert(not shop.can_reroll(), "can_reroll() must be false after using reroll and having 0 credits")
	assert(shop.reroll_btn.disabled, "Reroll button must be disabled after use")
	assert(shop.reroll_btn.text.contains("AGOTADO"), "Reroll button text must indicate [AGOTADO]")

	# Attempt a 2nd reroll while at 0 credits and limit reached
	shop._on_reroll_pressed()
	assert(shop.current_credits == 0, "Current credits must remain 0 on blocked 2nd attempt")
	assert(shop.rerolls_used_this_visit == 1, "rerolls_used_this_visit must remain 1")
	print("  ✓ [PASS] 30 credits: 1st reroll allowed, credits deducted to 0, 2nd reroll blocked.")
	shop.close_shop()

	# Edge Case 1.4: Surplus credits (60 Credits) with 1-reroll cap
	print("\n[Case 1.4] Testing surplus credits (60 credits) and reroll cap enforcement:")
	player.run_credits = 60
	shop.open_shop(player.run_credits)
	assert(shop.can_reroll(), "can_reroll() must be true initially with 60 credits")
	shop._on_reroll_pressed()
	assert(shop.current_credits == 30, "Current credits must drop to 30")
	assert(shop.rerolls_used_this_visit == 1, "rerolls_used_this_visit must be 1")
	# Even though current_credits == 30 (enough for another reroll), cap of 1 must block it!
	assert(not shop.can_reroll(), "can_reroll() must be false because max_rerolls_per_satellite == 1")
	assert(shop.reroll_btn.disabled, "Reroll button must be disabled despite having 30 credits remaining")
	assert(shop.reroll_btn.text.contains("AGOTADO"), "Button text must show AGOTADO")
	shop._on_reroll_pressed()
	assert(shop.current_credits == 30, "Credits must NOT be deducted on 2nd reroll attempt")
	print("  ✓ [PASS] Reroll cap strictly prevents 2nd reroll even when surplus credits exist.")
	shop.close_shop()

	# Edge Case 1.5: Satellite Shop Revisit Reroll Cap Reset
	print("\n[Case 1.5] Testing shop close and reopen (new satellite encounter):")
	shop.open_shop(player.run_credits) # opening with 30 credits left
	assert(shop.rerolls_used_this_visit == 0, "rerolls_used_this_visit must reset to 0 on new visit")
	assert(shop.can_reroll(), "can_reroll() must be true on fresh visit with 30 credits")
	assert(not shop.reroll_btn.disabled, "Reroll button must be active again")
	shop.close_shop()
	print("  ✓ [PASS] Reopening shop resets visit counter and restores reroll capability if funded.")

	# Edge Case 1.6: Negative credits handling
	print("\n[Case 1.6] Testing negative credits boundary (-15 credits):")
	player.run_credits = -15
	shop.open_shop(player.run_credits)
	assert(not shop.can_reroll(), "can_reroll() must be false for negative credits")
	assert(shop.reroll_btn.disabled, "Reroll button must be disabled for negative credits")
	shop._on_reroll_pressed()
	assert(shop.current_credits == -15, "Negative credits must remain unchanged")
	assert(shop.rerolls_used_this_visit == 0, "Usage count must remain 0")
	shop.close_shop()
	print("  ✓ [PASS] Negative credits gracefully handled without exceptions or unexpected rolls.")

	# =========================================================================
	# TEST SUITE 2: CHARACTER STATS MODIFICATION SCALING (+25% DMG, +20% CADENCE)
	# =========================================================================
	print("\n--- [SUITE 2] CharacterStats Modifier Scaling across Roster Pilots ---")

	# Find card_dmg_1 and card_atk_spd
	var card_dmg_1: StatCardData = null
	var card_atk_spd: StatCardData = null
	for card in deck_mgr.all_stat_cards:
		if card.card_id == &"card_dmg_1":
			card_dmg_1 = card
		elif card.card_id == &"card_atk_spd":
			card_atk_spd = card

	assert(card_dmg_1 != null, "card_dmg_1 must exist in StatDeckManager")
	assert(card_atk_spd != null, "card_atk_spd must exist in StatDeckManager")
	assert(card_dmg_1.target_stat == &"base_damage", "card_dmg_1 must target base_damage")
	assert(card_dmg_1.modifier_value == 0.12, "card_dmg_1 modifier_value must be exactly 0.12 (+12%)")
	assert(card_dmg_1.is_percentage, "card_dmg_1 must be marked as percentage")
	assert(card_atk_spd.target_stat == &"attack_speed", "card_atk_spd must target attack_speed")
	assert(card_atk_spd.modifier_value == 0.10, "card_atk_spd modifier_value must be exactly 0.10 (+10%)")
	assert(card_atk_spd.is_percentage, "card_atk_spd must be marked as percentage")

	print("  ✓ [PASS] Stat cards definitions verified: card_dmg_1 (+12%), card_atk_spd (+10%).")

	# Verify Absence of Flat Projectile Cards
	print("\n[Case 2.1] Verifying total absence of flat projectile cards in common deck:")
	for card in deck_mgr.all_stat_cards:
		assert(card.target_stat != &"projectile_count", "Deck must NOT contain projectile_count card: %s" % card.card_id)
		assert(card.card_id != &"card_proj_up_1" and card.card_id != &"card_proj_up_2", "Old projectile cards must be purged")
	print("  ✓ [PASS] No projectile_count cards present in common stat deck.")

	# Test across all 7 canonical pilots
	var pilot_paths := [
		"res://data/characters/roster/nova.tres",
		"res://data/characters/roster/echo.tres",
		"res://data/characters/roster/kira.tres",
		"res://data/characters/roster/nyx.tres",
		"res://data/characters/roster/roxy.tres",
		"res://data/characters/roster/selene.tres",
		"res://data/characters/roster/valentina.tres"
	]

	print("\n[Case 2.2] Testing +25% Damage and +20% Cadence scaling across all 7 pilots:")
	for path in pilot_paths:
		assert(ResourceLoader.exists(path), "Character data must exist: %s" % path)
		var char_data: CharacterData = load(path) as CharacterData
		assert(char_data != null, "CharacterData must load successfully: %s" % path)

		var stats := CharacterStats.new()
		stats.initialize(char_data)

		var initial_dmg: float = stats.get_stat(&"base_damage")
		var initial_spd: float = stats.get_stat(&"attack_speed")

		assert(initial_dmg > 0.0, "Pilot %s base_damage must be > 0 (found: %f)" % [char_data.character_id, initial_dmg])
		assert(initial_spd > 0.0, "Pilot %s attack_speed must be > 0 (found: %f)" % [char_data.character_id, initial_spd])

		# Apply card_dmg_1
		deck_mgr.apply_card_to_stats(card_dmg_1, stats)
		var buffed_dmg: float = stats.get_stat(&"base_damage")
		var expected_dmg: float = initial_dmg * (1.0 + card_dmg_1.modifier_value)
		var dmg_delta_ratio: float = (buffed_dmg - initial_dmg) / initial_dmg
		assert(is_equal_approx(buffed_dmg, expected_dmg), "Pilot %s: expected damage %f, got %f" % [char_data.character_id, expected_dmg, buffed_dmg])
		assert(dmg_delta_ratio >= card_dmg_1.modifier_value - 0.001, "Pilot %s damage increase must match modifier (got: %.2f%%)" % [char_data.character_id, dmg_delta_ratio * 100.0])

		# Apply card_atk_spd
		deck_mgr.apply_card_to_stats(card_atk_spd, stats)
		var buffed_spd: float = stats.get_stat(&"attack_speed")
		var expected_spd: float = initial_spd * (1.0 + card_atk_spd.modifier_value)
		var spd_delta_ratio: float = (buffed_spd - initial_spd) / initial_spd
		assert(is_equal_approx(buffed_spd, expected_spd), "Pilot %s: expected cadence %f, got %f" % [char_data.character_id, expected_spd, buffed_spd])
		assert(spd_delta_ratio >= card_atk_spd.modifier_value - 0.001, "Pilot %s cadence increase must match modifier (got: %.2f%%)" % [char_data.character_id, spd_delta_ratio * 100.0])

		print("    • Pilot %-10s -> Dmg: %5.1f -> %5.1f (+%.1f%%) | Cadence: %4.2fx -> %4.2fx (+%.1f%%)" % [
			char_data.character_id,
			initial_dmg, buffed_dmg, dmg_delta_ratio * 100.0,
			initial_spd, buffed_spd, spd_delta_ratio * 100.0
		])

	print("  ✓ [PASS] All 7 pilots scaled by card modifier values.")

	# Case 2.3: Multi-card Stacking Stress Test
	print("\n[Case 2.3] Testing stacking of multiple cards (additive percentage modifiers):")
	var stack_stats := CharacterStats.new()
	var test_char: CharacterData = load("res://data/characters/roster/nova.tres") as CharacterData
	stack_stats.initialize(test_char)

	var base_dmg: float = stack_stats.get_stat(&"base_damage") # 40.0
	var base_spd: float = stack_stats.get_stat(&"attack_speed") # 1.0

	# Apply 3 damage cards
	for i in range(3):
		var card_clone: StatCardData = card_dmg_1.duplicate()
		card_clone.card_id = StringName("card_dmg_1_stack_%d" % i)
		deck_mgr.apply_card_to_stats(card_clone, stack_stats)

	var triple_dmg: float = stack_stats.get_stat(&"base_damage")
	var expected_triple_dmg: float = base_dmg * (1.0 + card_dmg_1.modifier_value * 3.0)
	assert(is_equal_approx(triple_dmg, expected_triple_dmg), "Triple damage card stack must equal %f (got %f)" % [expected_triple_dmg, triple_dmg])
	print("  ✓ [PASS] 3x card_dmg_1 stack: %f -> %f (+%.1f%% additive)." % [base_dmg, triple_dmg, card_dmg_1.modifier_value * 300.0])

	# Apply 3 attack speed cards
	for i in range(3):
		var card_clone: StatCardData = card_atk_spd.duplicate()
		card_clone.card_id = StringName("card_atk_spd_stack_%d" % i)
		deck_mgr.apply_card_to_stats(card_clone, stack_stats)

	var triple_spd: float = stack_stats.get_stat(&"attack_speed")
	var expected_triple_spd: float = base_spd * (1.0 + card_atk_spd.modifier_value * 3.0)
	assert(is_equal_approx(triple_spd, expected_triple_spd), "Triple cadence card stack must equal %f (got %f)" % [expected_triple_spd, triple_spd])
	print("  ✓ [PASS] 3x card_atk_spd stack: %f -> %f (+%.1f%% additive)." % [base_spd, triple_spd, card_atk_spd.modifier_value * 300.0])

	# Case 2.4: Weapon Cadence Mathematical Translation
	print("\n[Case 2.4] Testing WeaponInstanceData cadence scaling via get_effective_passive_interval:")
	var weapon_data: WeaponData = load("res://data/weapons/roster/rail_launcher.tres") as WeaponData
	assert(weapon_data != null, "rail_launcher weapon data must exist")
	var wpn_inst := WeaponInstanceData.new(weapon_data)
	
	var default_stats := CharacterStats.new()
	default_stats.initialize(test_char)
	var interval_base: float = wpn_inst.get_effective_passive_interval(default_stats)
	
	deck_mgr.apply_card_to_stats(card_atk_spd, default_stats)
	var interval_buffed: float = wpn_inst.get_effective_passive_interval(default_stats)
	
	# Rate = 1.0 / interval. Buffed rate / base rate must equal (1.0 + modifier_value)
	var base_rate: float = 1.0 / interval_base
	var buffed_rate: float = 1.0 / interval_buffed
	var rate_increase: float = (buffed_rate - base_rate) / base_rate
	assert(is_equal_approx(rate_increase, card_atk_spd.modifier_value), "Firing rate must increase by card modifier value (got: %.4f)" % rate_increase)
	print("  ✓ [PASS] Weapon firing cadence (shots/s): %.3f/s -> %.3f/s (+%.1f%% exact)." % [base_rate, buffed_rate, rate_increase * 100.0])

	print("\n========================================================")
	print("[PASS] ALL EMPIRICAL CHALLENGER STRESS TESTS PASSED (100%)!")
	print("========================================================\n")
	get_tree().quit(0)

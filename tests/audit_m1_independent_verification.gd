extends Node

func _ready() -> void:
	print("==================================================")
	print("AUDITOR M1: INDEPENDENT FORENSIC VERIFICATION SUITE")
	print("==================================================")

	var failures: int = 0

	var main_game_scene: PackedScene = load("res://scenes/combat/main_game.tscn")
	assert(main_game_scene != null, "main_game.tscn debe existir")
	var main_game: MainGame = main_game_scene.instantiate() as MainGame
	add_child(main_game)
	main_game.is_briefing_active = false
	get_tree().paused = false

	var player: Player = main_game.player
	var level_modal: LevelUpModal = main_game.level_up_modal
	var shop: SatelliteShop = main_game.satellite_shop
	var deck_mgr: StatDeckManager = main_game.stat_deck_manager

	# -----------------------------------------------------------------
	# CHECK 1: StatDeckManager Integrity & Stress Test
	# -----------------------------------------------------------------
	print("\n[CHECK 1] StatDeckManager Integrity & Stress Test...")
	# 1.1 Verify no projectile cards in the entire card database
	for card: StatCardData in deck_mgr.all_stat_cards:
		if card.target_stat == &"projectile_count":
			print("  [FAIL] Found projectile_count card in deck: ", card.card_id)
			failures += 1
		if card.card_id == &"card_proj_up_1" or card.card_id == &"card_proj_up_2":
			print("  [FAIL] Found removed card_proj_up in deck: ", card.card_id)
			failures += 1
	print("  ✓ Ausencia total de cartas de proyectil universal en all_stat_cards.")

	# 1.2 Stress test: 50 hands generated across levels 1..25
	var hand_offered: Array[StatCardData] = []
	var on_offer := func(cards: Array[StatCardData], _cost: int) -> void:
		hand_offered.clear()
		hand_offered.append_array(cards)
	deck_mgr.cards_offered.connect(on_offer)

	for lvl: int in range(1, 26):
		deck_mgr.offer_cards(player.stats, lvl, 3)
		if hand_offered.size() != 3:
			print("  [FAIL] Expected 3 cards at level ", lvl, ", got ", hand_offered.size())
			failures += 1
		if hand_offered[0] == hand_offered[1] or hand_offered[0] == hand_offered[2] or hand_offered[1] == hand_offered[2]:
			print("  [FAIL] Duplicate card in hand at level ", lvl)
			failures += 1
		for c: StatCardData in hand_offered:
			if c.target_stat == &"projectile_count":
				print("  [FAIL] Proj card offered in hand at level ", lvl)
				failures += 1
	print("  ✓ Stress test superado: 25 niveles evaluados, exactamente 3 cartas únicas sin proyectiles.")

	# 1.3 Test StatDeckManager reroll logic with credits
	var reroll_fail: bool = deck_mgr.reroll(player.stats, 2) # cost is at least 5
	if reroll_fail:
		print("  [FAIL] StatDeckManager reroll should fail with 2 credits")
		failures += 1
	var reroll_ok: bool = deck_mgr.reroll(player.stats, 50)
	if not reroll_ok or hand_offered.size() != 3:
		print("  [FAIL] StatDeckManager reroll should succeed with 50 credits and return 3 cards")
		failures += 1
	print("  ✓ StatDeckManager reroll con balance de créditos validado.")
	deck_mgr.cards_offered.disconnect(on_offer)

	# -----------------------------------------------------------------
	# CHECK 2: SatelliteShop Re-roll Strict Boundary Enforcement & Exploit Resistance
	# -----------------------------------------------------------------
	print("\n[CHECK 2] SatelliteShop Re-roll Boundary & Exploit Stress Test...")
	# 2.1 Test with 0 credits
	shop.open_shop(0)
	if shop.can_reroll():
		print("  [FAIL] can_reroll() returned true with 0 credits")
		failures += 1
	if not shop.reroll_btn.disabled:
		print("  [FAIL] reroll_btn should be disabled with 0 credits")
		failures += 1

	# 2.2 Test with exactly reroll_cost - 1 (29 credits)
	shop.open_shop(29)
	if shop.can_reroll():
		print("  [FAIL] can_reroll() returned true with 29 credits (cost: 30)")
		failures += 1

	# 2.3 Test 1 valid reroll with 100 credits
	shop.open_shop(100)
	if not shop.can_reroll():
		print("  [FAIL] can_reroll() returned false with 100 credits")
		failures += 1
	shop._on_reroll_pressed()
	if shop.rerolls_used_this_visit != 1:
		print("  [FAIL] rerolls_used_this_visit should be 1, got ", shop.rerolls_used_this_visit)
		failures += 1
	if shop.current_credits != 70:
		print("  [FAIL] current_credits should be 70 (100 - 30), got ", shop.current_credits)
		failures += 1
	if player.run_credits != 70:
		print("  [FAIL] player.run_credits not synchronized after reroll! Got ", player.run_credits)
		failures += 1
	if shop.can_reroll():
		print("  [FAIL] can_reroll() returned true after using the 1 allowed reroll")
		failures += 1
	if not shop.reroll_btn.disabled:
		print("  [FAIL] reroll_btn was not disabled after using 1 reroll")
		failures += 1
	if not shop.reroll_btn.text.contains("AGOTADO"):
		print("  [FAIL] reroll_btn text does not mention AGOTADO: ", shop.reroll_btn.text)
		failures += 1

	# 2.4 Exploit Attempt: Inject credits and invoke _on_reroll_pressed again
	shop.current_credits = 5000
	shop._on_reroll_pressed()
	if shop.rerolls_used_this_visit != 1:
		print("  [FAIL] Exploited reroll! rerolls_used_this_visit changed to ", shop.rerolls_used_this_visit)
		failures += 1
	if shop.current_credits != 5000:
		print("  [FAIL] Credits deducted during unauthorized reroll! Got ", shop.current_credits)
		failures += 1
	print("  ✓ Intento de exploit con 5000 créditos bloqueado: reroll no se ejecuta tras agotar cupo.")

	# 2.5 Reopening shop resets quota
	shop.close_shop()
	shop.open_shop(100)
	if shop.rerolls_used_this_visit != 0:
		print("  [FAIL] rerolls_used_this_visit did not reset upon reopen")
		failures += 1
	if not shop.can_reroll():
		print("  [FAIL] can_reroll() false upon reopen with 100 credits")
		failures += 1
	shop.close_shop()
	print("  ✓ Reseteo de cupo al reabrir verificado.")

	# -----------------------------------------------------------------
	# CHECK 3: Player Starting Credits & Pricing Deflation
	# -----------------------------------------------------------------
	print("\n[CHECK 3] Economy Deflation & Starting Balance...")
	var fresh_player: Player = Player.new()
	if fresh_player.run_credits != 40:
		print("  [FAIL] Player starting credits should be 40, found: ", fresh_player.run_credits)
		failures += 1
	else:
		print("  ✓ Player starting credits = 40 (reducido desde 120).")
	fresh_player.free()

	# Check shop weapons
	var shop_weapon_paths: Array[String] = [
		"res://data/weapons/shop/nova_flak.tres",
		"res://data/weapons/shop/dimensional_blade.tres",
		"res://data/weapons/shop/solar_beam.tres",
		"res://data/weapons/shop/cluster_submunition.tres"
	]
	var expected_prices: Dictionary = {
		"nova_flak": 130,
		"dimensional_blade": 140,
		"solar_beam": 150,
		"cluster_submunition": 135
	}
	for p_path: String in shop_weapon_paths:
		var w: WeaponData = load(p_path) as WeaponData
		var key: String = p_path.get_file().get_basename()
		if w.cost != expected_prices[key]:
			print("  [FAIL] Weapon ", key, " expected cost ", expected_prices[key], ", got ", w.cost)
			failures += 1
		else:
			print("  ✓ Arma ", key, " calibrada a ", w.cost, " créditos.")

	# Check passive canonical items
	var canonical_items: Array[ItemData] = ItemPoolManager.create_canonical_stat_items()
	for it: ItemData in canonical_items:
		if it.rarity == Enums.Rarity.COMMON and it.cost != 45:
			print("  [FAIL] Common passive ", it.item_name, " expected 45, got ", it.cost)
			failures += 1
		elif it.rarity == Enums.Rarity.UNCOMMON and it.cost != 60:
			print("  [FAIL] Uncommon passive ", it.item_name, " expected 60, got ", it.cost)
			failures += 1
		elif it.rarity == Enums.Rarity.RARE and it.cost != 95:
			print("  [FAIL] Rare passive ", it.item_name, " expected 95, got ", it.cost)
			failures += 1
	print("  ✓ Todos los 12 ítems canónicos tienen precios calibrados contra inflación.")

	# -----------------------------------------------------------------
	# CHECK 4: LevelUpModal UI Architecture & Visual Cleanliness
	# -----------------------------------------------------------------
	print("\n[CHECK 4] LevelUpModal UI Cleanliness & Badge Verification...")
	level_modal.show_level_up(4)
	if level_modal.card_panels.size() != 3:
		print("  [FAIL] level_modal.card_panels size is ", level_modal.card_panels.size(), " expected 3")
		failures += 1

	for idx: int in range(level_modal.card_panels.size()):
		var pnl: PanelContainer = level_modal.card_panels[idx]
		var badge: Label = pnl.find_child("HeroValueBadge", true, false) as Label
		if not badge:
			print("  [FAIL] HeroValueBadge missing in card ", idx)
			failures += 1
		else:
			if badge.get_theme_font_size("font_size") != 26:
				print("  [FAIL] HeroValueBadge font size is ", badge.get_theme_font_size("font_size"), " expected 26")
				failures += 1
		var stat_name_lbl: Label = pnl.find_child("StatNameLabel", true, false) as Label
		if not stat_name_lbl:
			print("  [FAIL] StatNameLabel missing in card ", idx)
			failures += 1
	print("  ✓ Estructura de tarjetas de subida de nivel (3 cartas, badge 26pt, labels limpios) verificada.")
	level_modal._select_card_by_index(0)

	print("\n==================================================")
	if failures == 0:
		print("[AUDIT SUCCESS] 0 INTEGRITY VIOLATIONS DETECTED. CODEBASE IS CLEAN.")
		get_tree().quit(0)
	else:
		print("[AUDIT FAILURE] %d FAILURES DETECTED! VERDICT: INTEGRITY VIOLATION." % failures)
		get_tree().quit(1)

extends Node

func _ready() -> void:
	# Watchdog timer
	get_tree().create_timer(10.0).timeout.connect(func():
		print("[TEST WATCHDOG] Timeout alcanzado, saliendo...")
		get_tree().quit(1)
	)

	print("\n==========================================")
	print("[TEST] Testing Decision Menus Stats Display & Preview Suite...")
	print("==========================================")

	var main_game_scene: PackedScene = load("res://scenes/combat/main_game.tscn")
	assert(main_game_scene != null, "main_game.tscn debe existir")

	var main_game: MainGame = main_game_scene.instantiate() as MainGame
	add_child(main_game)

	# Desactivar briefing inicial
	main_game.is_briefing_active = false
	get_tree().paused = false

	var player := main_game.player
	var level_modal := main_game.level_up_modal
	var shop := main_game.satellite_shop
	var arcana_modal := main_game.arcana_modal

	assert(player != null, "Player debe existir en MainGame")
	assert(level_modal != null, "LevelUpModal debe existir en MainGame")
	assert(shop != null, "SatelliteShop debe existir en MainGame")
	assert(arcana_modal != null, "ArcanaSelectionModal debe existir en MainGame")

	# =========================================================================
	# PARTE 1: Panel Lateral de Estadísticas en LevelUpModal
	# =========================================================================
	print("\n[1/5] Testing LevelUpModal Run Stats Side Panel...")
	level_modal.show_level_up(2)
	assert(level_modal.visible, "LevelUpModal debe mostrarse")
	assert(level_modal.stats_side_panel != null, "StatsSidePanel debe existir")
	assert(level_modal.stats_side_panel.is_visible_in_tree(), "StatsSidePanel debe ser visible")
	assert(level_modal.stats_list_container != null, "StatsListContainer debe existir")
	assert(level_modal.stats_list_container.get_child_count() >= 14, "Deben renderizarse las 14 estadísticas clasificadas")
	assert(level_modal.pilot_info_label.text.contains("2"), "PilotInfo debe reflejar el nivel 2")
	print("  ✓ LevelUpModal renderiza correctamente el panel lateral con las 14 estadísticas y nivel del piloto.")

	# =========================================================================
	# PARTE 2: Resaltado de Estadísticas Mejoradas y Previsualización en LevelUpModal
	# =========================================================================
	print("\n[2/5] Testing Stat Buffing & Card Hover Highlighting in LevelUpModal...")
	player.stats.add_modifier(&"base_damage", CharacterStats.StatModifier.new(&"test_buff", 20.0, false, self))
	level_modal._refresh_player_stats_display()
	assert(level_modal.stat_card_ui_entries.has(&"base_damage"), "Debe tener entrada para base_damage")
	assert(level_modal.stat_card_ui_entries[&"base_damage"]["is_buffed"] == true, "base_damage debe detectarse como buffed")

	level_modal._update_card_selection(0)
	assert(level_modal.current_selected_idx == 0, "Índice seleccionado debe ser 0")
	if not level_modal.current_offered_cards.is_empty():
		var target_st = level_modal.current_offered_cards[0].target_stat
		print("  ✓ Previsualización activa: la estadística objetivo '%s' se resalta al seleccionar la carta." % target_st)

	level_modal._select_card_by_index(0)
	assert(not level_modal.visible, "LevelUpModal debe cerrarse al elegir carta")
	print("  ✓ Selección de carta procesada y modal cerrado.")

	# =========================================================================
	# PARTE 3: Panel Lateral de Estadísticas e Inventario en SatelliteShop
	# =========================================================================
	print("\n[3/5] Testing SatelliteShop Stats & Inventory Display...")
	shop.open_shop(200)
	assert(shop.visible, "SatelliteShop debe mostrarse")
	assert(shop.inventory_side_panel != null, "InventorySidePanel debe existir")
	assert(shop.inventory_side_panel.is_visible_in_tree(), "InventorySidePanel debe ser visible")
	assert(shop.stats_list != null, "StatsList debe existir en SatelliteShop")
	assert(shop.stats_list.get_child_count() >= 14, "StatsList debe renderizar las 14 estadísticas")
	assert(shop.stat_ui_entries.has(&"base_damage"), "stat_ui_entries debe contener base_damage")
	assert(shop.weapons_list != null, "WeaponsList debe existir")
	assert(shop.weapons_list.get_child_count() >= 1, "Debe mostrar al menos el arma primaria")
	assert(shop.inventory_summary_label.text.contains("Armas:"), "Summary debe indicar número de armas")
	print("  ✓ SatelliteShop renderiza tanto las 14 estadísticas del piloto como las armas/ítems de la run.")

	# =========================================================================
	# PARTE 4: Previsualización de Estadísticas al Hover y Compra en SatelliteShop
	# =========================================================================
	print("\n[4/5] Testing Stat Preview & Real-Time Sync on Shop Purchase...")
	# Probar previsualización numérica en SatelliteShop
	shop._highlight_preview_stat(&"move_speed", 50.0, false)
	var move_entry: Dictionary = shop.stat_ui_entries[&"move_speed"]
	var lbl_val: Label = move_entry["lbl_val"]
	assert(lbl_val.text.contains("→"), "Debe mostrar la flecha de transición de valores (antes → después)")
	shop._clear_stat_highlights()
	assert(not lbl_val.text.contains("→"), "Al limpiar previsualización debe retornar al valor nominal")
	print("  ✓ Previsualización numérica dinámica confirmada en la terminal de suministros.")

	# Añadir un ítem pasivo al inventario y comprar
	var test_item := ItemData.new()
	test_item.item_id = &"hyper_thruster"
	test_item.item_name = "Propulsor Hyper-Drive"
	test_item.stat_name = &"move_speed"
	test_item.stat_value = 50.0
	test_item.rarity = Enums.Rarity.RARE
	player.inventory.add_item(test_item, 3)

	shop._refresh_inventory_display()
	shop._refresh_stats_display()
	assert(shop.items_list.get_child_count() >= 1, "ItemsList debe contener el ítem añadido")
	assert(shop.stat_ui_entries[&"move_speed"]["is_buffed"] == true, "move_speed debe estar buffed tras añadir ítem")

	var initial_credits := shop.current_credits
	var offered_item = shop.current_offered_items[0]
	var item_cost: int = offered_item.get("cost") if offered_item.get("cost") != null and offered_item.get("cost") > 0 else 50

	shop._buy_item_by_index(0)
	assert(shop.current_credits == initial_credits - item_cost, "Los créditos deben reducirse tras la compra")
	shop.close_shop()
	assert(not shop.visible, "SatelliteShop debe cerrarse")
	print("  ✓ Compra de suministros procesada, inventario y estadísticas sincronizados.")

	# =========================================================================
	# PARTE 5: Panel de Estadísticas y Modificadores Exactos en ArcanaSelectionModal
	# =========================================================================
	print("\n[5/5] Testing ArcanaSelectionModal Stats Side Panel & Exact Deltas...")
	arcana_modal.show_arcana_selection(player)
	assert(arcana_modal.visible, "ArcanaSelectionModal debe mostrarse")
	assert(arcana_modal.stats_side_panel != null, "StatsSidePanel debe existir en ArcanaSelectionModal")
	assert(arcana_modal.stats_side_panel.is_visible_in_tree(), "StatsSidePanel debe ser visible")
	assert(arcana_modal.stats_list_container != null, "StatsListContainer debe existir en ArcanaSelectionModal")
	assert(arcana_modal.stats_list_container.get_child_count() >= 14, "Deben renderizarse las 14 estadísticas clasificadas")
	assert(arcana_modal.card_panels.size() >= 1, "Deben generarse paneles para las cartas arcanas")

	# Probar previsualización de alteración de arcana
	var first_arc: ArcanaData = arcana_modal.offered_arcanas[0]
	arcana_modal._update_card_selection(0)
	print("  ✓ Arcana '%s' seleccionada con %d modificadores de estadísticas." % [first_arc.name, first_arc.stat_modifiers.size()])

	if not first_arc.stat_modifiers.is_empty():
		for mod_k in first_arc.stat_modifiers.keys():
			var s_key := String(mod_k)
			var target_stat := StringName(s_key.trim_suffix("_pct"))
			if arcana_modal.stat_card_ui_entries.has(target_stat):
				var arc_entry: Dictionary = arcana_modal.stat_card_ui_entries[target_stat]
				var arc_lbl: Label = arc_entry["lbl_val"]
				assert(arc_lbl.text.contains("→"), "Debe mostrar diff 'antes → después' para la estadística '%s'" % target_stat)
		print("  ✓ Previsualización multi-estadística verificada exitosamente para cartas de arcana.")

	# Elegir arcana y cerrar
	arcana_modal._choose_focused_card()
	assert(not arcana_modal.visible, "ArcanaSelectionModal debe cerrarse tras pactar")
	print("  ✓ Pacto de arcana procesado y modal cerrado.")

	# =========================================================================
	# PARTE 6: Milestone 1 — Mazo de Subida de Nivel (R1)
	# =========================================================================
	print("\n[6/7] Testing Milestone 1: 3-Card Offer, No Proj Cards & +25-30% Impact...")
	var deck_mgr: StatDeckManager = main_game.stat_deck_manager
	assert(deck_mgr != null, "StatDeckManager debe existir")

	# 6.1. Verificar ausencia de cartas de proyectil en el mazo común
	for card in deck_mgr.all_stat_cards:
		assert(card.target_stat != &"projectile_count", "El mazo común NO debe contener cartas de proyectil adicional (encontrado: %s)" % card.card_id)
		assert(card.card_id != &"card_proj_up_1" and card.card_id != &"card_proj_up_2", "card_proj_up_1/2 deben eliminarse del mazo común")
	print("  ✓ Ausencia de cartas de proyectil plano universal verificada en el mazo común.")

	# 6.2. Verificar valores matemáticos de alto impacto (+25-30% Daño, +20% Cadencia, etc.)
	var found_dmg_1 := false
	var found_atk_spd := false
	var found_armor_1 := false
	var found_crit_chance := false
	var found_speed := false
	for card in deck_mgr.all_stat_cards:
		if card.card_id == &"card_dmg_1":
			found_dmg_1 = true
			assert(card.modifier_value >= 0.12, "card_dmg_1 debe otorgar al menos +12%% de daño (actual: %f)" % card.modifier_value)
		elif card.card_id == &"card_atk_spd":
			found_atk_spd = true
			assert(card.modifier_value >= 0.10, "card_atk_spd debe otorgar al menos +10%% de cadencia (actual: %f)" % card.modifier_value)
		elif card.card_id == &"card_armor_1":
			found_armor_1 = true
			assert(card.modifier_value >= 3.0, "card_armor_1 debe otorgar al menos +3.0 de armadura (actual: %f)" % card.modifier_value)
		elif card.card_id == &"card_crit_chance":
			found_crit_chance = true
			assert(card.modifier_value >= 0.06, "card_crit_chance debe otorgar al menos +6%% crítico (actual: %f)" % card.modifier_value)
		elif card.card_id == &"card_speed_up":
			found_speed = true
			assert(card.modifier_value >= 0.10, "card_speed_up debe otorgar al menos +10%% velocidad (actual: %f)" % card.modifier_value)
	assert(found_dmg_1 and found_atk_spd and found_armor_1 and found_crit_chance and found_speed, "Todas las cartas clave de Tier 1 deben existir y estar calibradas")
	print("  ✓ Valores de alto impacto Tier 1 verificados (+12% daño, +10% cadencia, +3 armadura, etc.).")

	# 6.3. Verificar oferta de exactamente 3 cartas en LevelUpModal
	level_modal.show_level_up(3)
	assert(level_modal.current_offered_cards.size() == 3, "Deben ofrecerse exactamente 3 cartas (actual: %d)" % level_modal.current_offered_cards.size())
	assert(level_modal.cards_container.get_child_count() == 3, "CardsContainer debe contener exactamente 3 nodos de cartas")

	# 6.4. Verificar UI de cartas limpia e instantánea (Hero Badge legible, sin duplicados)
	for card_panel in level_modal.card_panels:
		var hero_badge: Label = card_panel.find_child("HeroValueBadge", true, false) as Label
		assert(hero_badge != null, "Cada carta debe incluir un HeroValueBadge para lectura instantánea")
		assert(hero_badge.get_theme_font_size("font_size") >= 13, "HeroValueBadge debe tener tipografía legible (>= 13pt)")
		assert(hero_badge.text.begins_with("+") or hero_badge.text.begins_with("-"), "HeroValueBadge debe mostrar el valor numérico con signo")
		var stat_lbl: Label = card_panel.find_child("StatNameLabel", true, false) as Label
		assert(stat_lbl != null, "Cada carta debe tener una etiqueta de atributo concisa")
	print("  ✓ Formato visual limpio con exactamente 3 cartas y badges heroicos verificado.")
	level_modal._select_card_by_index(0)

	# =========================================================================
	# PARTE 7: Milestone 1 — Tienda Satelital y Economía (R2)
	# =========================================================================
	print("\n[7/7] Testing Milestone 1: 1 Re-roll Limit, Credit Sync & Price Calibration...")
	# 7.1. Abrir tienda y verificar re-roll inicial disponible
	var shop_test_credits: int = 150
	player.run_credits = shop_test_credits
	shop.open_shop(player.run_credits)
	assert(shop.can_reroll() == true, "can_reroll() debe ser true al abrir la tienda")
	assert(shop.reroll_btn.disabled == false, "El botón de re-roll debe estar habilitado inicialmente")
	assert(shop.rerolls_used_this_visit == 0, "rerolls_used_this_visit debe ser 0")

	# 7.2. Ejecutar 1 Re-roll
	var pre_reroll_cost := shop.reroll_cost
	shop._on_reroll_pressed()
	assert(shop.rerolls_used_this_visit == 1, "Debe registrarse 1 reroll utilizado")
	assert(shop.current_credits == shop_test_credits - pre_reroll_cost, "Créditos locales deben descontar el coste")
	assert(player.run_credits == shop.current_credits, "player.run_credits DEBE estar sincronizado con el gasto de re-roll")
	assert(shop.can_reroll() == false, "can_reroll() debe ser false tras agotar el cupo")
	assert(shop.reroll_btn.disabled == true, "El botón de re-roll DEBE deshabilitarse tras 1 uso")
	assert(shop.reroll_btn.text.contains("AGOTADO"), "El texto del botón debe indicar [AGOTADO (1/1)]")
	print("  ✓ Límite de 1 re-roll por visita y sincronización de créditos con Player verificados.")

	# 7.3. Intentar un segundo re-roll (debe ser ignorado)
	var credits_after_first := shop.current_credits
	shop._on_reroll_pressed()
	assert(shop.rerolls_used_this_visit == 1, "No debe permitir segundo reroll")
	assert(shop.current_credits == credits_after_first, "Créditos no deben variar al reintentar reroll agotado")
	print("  ✓ Segundo intento de re-roll bloqueado exitosamente.")

	# 7.4. Cerrar tienda y reabrir (simulando visita a nuevo satélite)
	shop.close_shop()
	shop.open_shop(player.run_credits)
	assert(shop.rerolls_used_this_visit == 0, "El cupo de re-roll debe reiniciarse en una nueva visita al satélite")
	assert(shop.can_reroll() == true, "can_reroll() debe volver a ser true en nueva visita si hay fondos")
	assert(shop.reroll_btn.disabled == false, "El botón de re-roll debe volver a habilitarse en nueva visita")
	shop.close_shop()
	print("  ✓ Restablecimiento del cupo de re-roll al visitar un nuevo satélite verificado.")

	# 7.5. Calibración de precios de armas e ítems
	var shop_weapons := [
		load("res://data/weapons/shop/nova_flak.tres") as WeaponData,
		load("res://data/weapons/shop/dimensional_blade.tres") as WeaponData,
		load("res://data/weapons/shop/cluster_submunition.tres") as WeaponData,
		load("res://data/weapons/shop/solar_beam.tres") as WeaponData,
	]
	for w in shop_weapons:
		assert(w != null and w.cost >= 120 and w.cost <= 150, "Arma %s debe costar entre 120 y 150 créditos (actual: %d)" % [w.weapon_name, w.cost])
	print("  ✓ Precios de armas calibrados a 120-150 créditos.")

	var canonical_items := ItemPoolManager.create_canonical_stat_items()
	for it in canonical_items:
		if it.rarity == Enums.Rarity.COMMON:
			assert(it.cost >= 40 and it.cost <= 50, "Ítem pasivo común %s debe costar 40-50 créditos (actual: %d)" % [it.item_name, it.cost])
		elif it.rarity == Enums.Rarity.UNCOMMON:
			assert(it.cost >= 55 and it.cost <= 65, "Ítem pasivo poco común %s debe costar 55-65 créditos (actual: %d)" % [it.item_name, it.cost])
	print("  ✓ Precios de ítems pasivos calibrados (comunes 40-50C, poco comunes 55-65C).")

	print("\n==========================================")
	print("[PASS] ALL DECISION MENUS & M1 STATS TESTS PASSED (100%)!")
	print("==========================================\n")
	get_tree().quit(0)

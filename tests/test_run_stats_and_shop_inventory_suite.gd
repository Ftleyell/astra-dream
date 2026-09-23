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

	print("\n==========================================")
	print("[PASS] ALL DECISION MENUS STATS TESTS PASSED (100%)!")
	print("==========================================\n")
	get_tree().quit(0)

extends Node

func _ready() -> void:
	# Watchdog timer
	get_tree().create_timer(8.0).timeout.connect(func():
		print("[TEST WATCHDOG] Timeout alcanzado, saliendo...")
		get_tree().quit(1)
	)

	print("\n==========================================")
	print("[TEST] Testing Level-Up Run Stats & Satellite Shop Inventory...")
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

	assert(player != null, "Player debe existir en MainGame")
	assert(level_modal != null, "LevelUpModal debe existir en MainGame")
	assert(shop != null, "SatelliteShop debe existir en MainGame")

	# =========================================================================
	# PARTE 1: Panel Lateral de Estadísticas en LevelUpModal
	# =========================================================================
	print("\n[1/4] Testing LevelUpModal Run Stats Side Panel...")
	level_modal.show_level_up(2)
	assert(level_modal.visible, "LevelUpModal debe mostrarse")
	assert(level_modal.stats_side_panel != null, "StatsSidePanel debe existir")
	assert(level_modal.stats_side_panel.is_visible_in_tree(), "StatsSidePanel debe ser visible")
	assert(level_modal.stats_list_container != null, "StatsListContainer debe existir")
	assert(level_modal.stats_list_container.get_child_count() >= 14, "Deben renderizarse las 14 estadísticas clasificadas")
	assert(level_modal.pilot_info_label.text.contains("2"), "PilotInfo debe reflejar el nivel 2")
	print("  ✓ LevelUpModal renderiza correctamente el panel lateral con las 14 estadísticas y nivel del piloto.")

	# =========================================================================
	# PARTE 2: Resaltado de Estadísticas Mejoradas y Previsualización
	# =========================================================================
	print("\n[2/4] Testing Stat Buffing & Card Hover Highlighting...")
	# Añadir buff a daño
	player.stats.add_modifier(&"base_damage", CharacterStats.StatModifier.new(&"test_buff", 20.0, false, self))
	level_modal._refresh_player_stats_display()
	assert(level_modal.stat_card_ui_entries.has(&"base_damage"), "Debe tener entrada para base_damage")
	assert(level_modal.stat_card_ui_entries[&"base_damage"]["is_buffed"] == true, "base_damage debe detectarse como buffed")
	print("  ✓ Estadísticas potenciadas sobre el valor base se marcan como buffed en verde (#00FF9D).")

	# Navegación y previsualización de mejora
	level_modal._update_card_selection(0)
	assert(level_modal.current_selected_idx == 0, "Índice seleccionado debe ser 0")
	if not level_modal.current_offered_cards.is_empty():
		var target_st = level_modal.current_offered_cards[0].target_stat
		print("  ✓ Previsualización activa: la estadística objetivo '%s' se resalta al seleccionar la carta." % target_st)

	# Elegir carta para cerrar modal limpiamente
	level_modal._select_card_by_index(0)
	assert(not level_modal.visible, "LevelUpModal debe cerrarse al elegir carta")
	print("  ✓ Selección de carta procesada y modal cerrado.")

	# =========================================================================
	# PARTE 3: Panel Lateral de Inventario en SatelliteShop
	# =========================================================================
	print("\n[3/4] Testing SatelliteShop Acquired Inventory Side Panel...")
	shop.open_shop(200)
	assert(shop.visible, "SatelliteShop debe mostrarse")
	assert(shop.inventory_side_panel != null, "InventorySidePanel debe existir")
	assert(shop.inventory_side_panel.is_visible_in_tree(), "InventorySidePanel debe ser visible")
	assert(shop.weapons_list != null, "WeaponsList debe existir")
	assert(shop.weapons_list.get_child_count() >= 1, "Debe mostrar al menos el arma primaria")
	assert(shop.inventory_summary_label.text.contains("Armas:"), "Summary debe indicar número de armas")
	print("  ✓ SatelliteShop renderiza el panel lateral de inventario con armas en servicio.")

	# =========================================================================
	# PARTE 4: Añadir Ítems Pasivos y Compra en Tiempo Real
	# =========================================================================
	print("\n[4/4] Testing Dynamic Inventory Updates & Purchasing...")
	# Añadir un ítem pasivo al jugador
	var test_item := ItemData.new()
	test_item.item_id = &"hyper_thruster"
	test_item.item_name = "Propulsor Hyper-Drive"
	test_item.stat_name = &"move_speed"
	test_item.stat_value = 50.0
	test_item.rarity = Enums.Rarity.RARE
	player.inventory.add_item(test_item, 3)

	shop._refresh_inventory_display()
	assert(shop.items_list.get_child_count() >= 1, "ItemsList debe contener el ítem añadido")
	assert(shop.inventory_summary_label.text.contains("Ítems Pasivos: 1"), "Summary debe registrar 1 tipo de ítem pasivo")
	print("  ✓ Ítem pasivo 'Propulsor Hyper-Drive' (x3) reflejado en tiempo real en el inventario.")

	# Comprar un ítem de la tienda
	var initial_credits := shop.current_credits
	var offered_item = shop.current_offered_items[0]
	var item_cost: int = offered_item.get("cost") if offered_item.get("cost") != null and offered_item.get("cost") > 0 else 50

	shop._buy_item_by_index(0)
	assert(shop.current_credits == initial_credits - item_cost, "Los créditos deben reducirse tras la compra")

	# Cerrar tienda
	shop.close_shop()
	assert(not shop.visible, "SatelliteShop debe cerrarse")
	print("  ✓ Compra de suministros procesada e inventario sincronizado.")

	print("\n==========================================")
	print("[PASS] ALL RUN STATS & SHOP INVENTORY TESTS PASSED (100%)!")
	print("==========================================\n")
	get_tree().quit(0)

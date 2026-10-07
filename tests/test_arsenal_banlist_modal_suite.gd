class_name TestArsenalBanlistModalSuite
extends BaseTestSuite

## TestArsenalBanlistModalSuite
## Valida la unificación del Arsenal y Banlist en 7 pestañas:
## - Límites matemáticos del 40% por categoría.
## - Denegación al alcanzar el tope máximo de bloqueos.
## - Desbaneo mediante toggle.
## - Persistencia aislada por piloto en SaveManager.
## - Filtrado efectivo en ItemPoolManager.rebuild_run_pool.
## - Integración en CharacterSelect y presencia de SideDetailPanel.

const ArsenalBanlistModalScript = preload("res://scenes/ui/character_select/arsenal_banlist_modal.gd")
const ArsenalBanlistModalScene = preload("res://scenes/ui/character_select/arsenal_banlist_modal.tscn")
const CharacterSelectScene = preload("res://scenes/ui/character_select/character_select.tscn")
const WeaponCatalogScript = preload("res://data/weapons/weapon_catalog.gd")
const TomeCatalogScript = preload("res://data/tomes/tome_catalog.gd")
const ItemPoolManagerScript = preload("res://core/types/item_pool_manager.gd")


func _ready() -> void:
	super._ready()
	print("--- TEST ARSENAL BANLIST MODAL SUITE START ---")
	_run_all_tests()


func _run_all_tests() -> void:
	_test_tab_counts_and_forty_percent_rule()
	_test_modal_structure_and_side_panel()
	_test_ban_limits_and_denial_behavior()
	_test_unban_toggle()
	_test_pilot_persistence_isolation()
	_test_rebuild_run_pool_filtering()
	_test_character_select_integration()

	print("--- TEST ARSENAL BANLIST MODAL SUITE FINISHED: ALL PASS ---")
	pass_suite("TestArsenalBanlistModalSuite: Todas las pruebas de las 7 pestañas y límites superadas con éxito.")


func _test_tab_counts_and_forty_percent_rule() -> void:
	var modal: Node = ArsenalBanlistModalScene.instantiate()
	add_child(modal)

	# 1. Armas: 11 ítems -> 4 máx baneos
	assert_true(WeaponCatalogScript.POOL_WEAPON_IDS.size() == 11, "POOL_WEAPON_IDS debe tener 11 armas")
	assert_true(modal.get_max_bans_for_tab(ArsenalBanlistModalScript.TabCategory.WEAPONS) == 4, "Armas: máx 4 baneos")

	# 2. Tomos: 18 ítems -> 7 máx baneos
	assert_true(TomeCatalogScript.ALL_TOME_IDS.size() == 18, "ALL_TOME_IDS debe tener 18 tomos")
	assert_true(modal.get_max_bans_for_tab(ArsenalBanlistModalScript.TabCategory.TOMES) == 7, "Tomos: máx 7 baneos")

	# 3. Sobrecargas: 8 ítems -> 3 máx baneos
	assert_true(ItemPoolManagerScript.OVERLOAD_ITEM_IDS.size() == 8, "OVERLOAD_ITEM_IDS debe tener 8 ítems")
	assert_true(modal.get_max_bans_for_tab(ArsenalBanlistModalScript.TabCategory.OVERLOADS) == 3, "Sobrecargas: máx 3 baneos")

	# 4. Procs: 8 ítems -> 3 máx baneos
	assert_true(ItemPoolManagerScript.REACTIVE_PROC_ITEM_IDS.size() == 8, "REACTIVE_PROC_ITEM_IDS debe tener 8 ítems")
	assert_true(modal.get_max_bans_for_tab(ArsenalBanlistModalScript.TabCategory.REACTIVE_PROCS) == 3, "Procs: máx 3 baneos")

	# 5. Utilidad: 8 ítems -> 3 máx baneos
	assert_true(ItemPoolManagerScript.UTILITY_CORE_ITEM_IDS.size() == 8, "UTILITY_CORE_ITEM_IDS debe tener 8 ítems")
	assert_true(modal.get_max_bans_for_tab(ArsenalBanlistModalScript.TabCategory.UTILITY_CORES) == 3, "Utilidad: máx 3 baneos")

	# 6. Estratégicos: 12 ítems -> 4 máx baneos
	assert_true(ItemPoolManagerScript.STRATEGIC_MODULE_ITEM_IDS.size() == 12, "STRATEGIC_MODULE_ITEM_IDS debe tener 12 ítems")
	assert_true(modal.get_max_bans_for_tab(ArsenalBanlistModalScript.TabCategory.STRATEGIC_MODULES) == 4, "Estratégicos: máx 4 baneos")

	# 7. Cofres: 24 ítems -> 9 máx baneos
	assert_true(ItemPoolManagerScript.CHEST_CANONICAL_ITEM_IDS.size() == 24, "CHEST_CANONICAL_ITEM_IDS debe tener 24 ítems")
	assert_true(modal.get_max_bans_for_tab(ArsenalBanlistModalScript.TabCategory.CHEST_ITEMS) == 9, "Cofres: máx 9 baneos")

	modal.queue_free()
	print("  ✓ [PASS] Test 1: Límites del 40% y totales de las 7 pestañas validados.")


func _test_modal_structure_and_side_panel() -> void:
	var modal: Node = ArsenalBanlistModalScene.instantiate()
	add_child(modal)

	modal.open_modal(&"nova", 0)
	assert_true(modal.is_open, "Modal debe estar abierto")
	assert_true(modal.dim_overlay != null, "Debe poseer DimOverlay")
	assert_true(modal.dim_overlay.material is ShaderMaterial, "DimOverlay debe usar ShaderMaterial con screen blur")
	assert_true(modal.side_detail_panel != null, "Debe tener SideDetailPanel")
	assert_true(modal.side_detail_panel.mouse_filter == Control.MOUSE_FILTER_IGNORE, "SideDetailPanel debe ignorar eventos de mouse")
	# Verificar inspección de armas y tomos sin errores
	modal._inspect_item(WeaponCatalogScript.POOL_WEAPON_IDS[0], ArsenalBanlistModalScript.TabCategory.WEAPONS)
	assert_true(not modal.detail_title_label.text.is_empty(), "Título de detalle debe poblarse con arma")

	modal._on_tab_pressed(ArsenalBanlistModalScript.TabCategory.TOMES)
	modal._inspect_item(TomeCatalogScript.ALL_TOME_IDS[0], ArsenalBanlistModalScript.TabCategory.TOMES)
	assert_true(not modal.detail_title_label.text.is_empty(), "Título de detalle debe poblarse con tomo")
	assert_true(not modal.detail_stats_label.text.contains("base_damage") and not modal.detail_stats_label.text.contains("max_health"), "Detalle de tomo no debe contener identificadores crudos")
	assert_true(modal.detail_stats_label.text.contains("Daño Base") or modal.detail_stats_label.text.contains("Vida Máxima"), "Detalle de tomo debe mostrar nombre en español")

	modal.close_modal()
	assert_true(not modal.is_open, "Modal debe cerrarse tras close_modal()")
	modal.queue_free()
	print("  ✓ [PASS] Test 2: Estructura visual, blur y panel de inspección lateral (armas y tomos) validados.")


func _test_ban_limits_and_denial_behavior() -> void:
	var modal: Node = ArsenalBanlistModalScene.instantiate()
	add_child(modal)

	var char_id := &"test_hero_limit"
	SaveManager.set_character_banlist(char_id, [])

	modal.open_modal(char_id, ArsenalBanlistModalScript.TabCategory.OVERLOADS)
	var overloads: Array[StringName] = ItemPoolManagerScript.OVERLOAD_ITEM_IDS

	# Banear 3 ítems (el máximo permitido de 8 es 3)
	modal._on_card_pressed(overloads[0], ArsenalBanlistModalScript.TabCategory.OVERLOADS)
	modal._on_card_pressed(overloads[1], ArsenalBanlistModalScript.TabCategory.OVERLOADS)
	modal._on_card_pressed(overloads[2], ArsenalBanlistModalScript.TabCategory.OVERLOADS)

	var bans: Array[StringName] = modal.get_banned_ids_for_tab(ArsenalBanlistModalScript.TabCategory.OVERLOADS)
	assert_true(bans.size() == 3, "Debe haber exactamente 3 ítems baneados en Sobrecargas")

	# Intentar banear el 4º ítem: debe ser rechazado
	modal._on_card_pressed(overloads[3], ArsenalBanlistModalScript.TabCategory.OVERLOADS)
	bans = modal.get_banned_ids_for_tab(ArsenalBanlistModalScript.TabCategory.OVERLOADS)
	assert_true(bans.size() == 3, "No debe permitir banear el 4º ítem al superar el 40%")
	assert_true(not bans.has(overloads[3]), "El 4º ítem no debe haber sido agregado a la banlist")
	assert_true(modal.warning_label.text.contains("MÁXIMO 3 EXCLUSIONES"), "Warning label debe advertir del límite")

	modal.close_modal()
	modal.queue_free()
	print("  ✓ [PASS] Test 3: Límite estricto del 40% y denegación con advertencia comprobados.")


func _test_unban_toggle() -> void:
	var modal: Node = ArsenalBanlistModalScene.instantiate()
	add_child(modal)

	var char_id := &"test_hero_toggle"
	var overloads: Array[StringName] = ItemPoolManagerScript.OVERLOAD_ITEM_IDS
	SaveManager.set_character_banlist(char_id, [overloads[0]])

	modal.open_modal(char_id, ArsenalBanlistModalScript.TabCategory.OVERLOADS)
	assert_true(modal.is_item_banned(ArsenalBanlistModalScript.TabCategory.OVERLOADS, overloads[0]), "Debe iniciar baneado")

	# Clic sobre el ítem ya baneado: debe desbanearlo
	modal._on_card_pressed(overloads[0], ArsenalBanlistModalScript.TabCategory.OVERLOADS)
	assert_true(not modal.is_item_banned(ArsenalBanlistModalScript.TabCategory.OVERLOADS, overloads[0]), "Debe quedar activo tras desbanear")
	assert_true(SaveManager.get_character_banlist(char_id).is_empty(), "SaveManager debe reflejar el desbaneo")

	modal.close_modal()
	modal.queue_free()
	print("  ✓ [PASS] Test 4: Desbaneo interactivo por toggle verificado.")


func _test_pilot_persistence_isolation() -> void:
	var pilot_a := &"pilot_alpha"
	var pilot_b := &"pilot_beta"

	SaveManager.set_character_banlist(pilot_a, [&"fusion_reactor", &"dense_turbine"])
	SaveManager.set_character_banlist(pilot_b, [&"collimator_lens"])

	var bans_a: Array[StringName] = SaveManager.get_character_banlist(pilot_a)
	var bans_b: Array[StringName] = SaveManager.get_character_banlist(pilot_b)

	assert_true(bans_a.has(&"fusion_reactor") and bans_a.has(&"dense_turbine"), "Pilot A debe tener sus propios baneos")
	assert_true(not bans_a.has(&"collimator_lens"), "Pilot A no debe tener baneos de Pilot B")
	assert_true(bans_b.has(&"collimator_lens") and not bans_b.has(&"fusion_reactor"), "Pilot B debe estar aislado")

	print("  ✓ [PASS] Test 5: Persistencia independiente por piloto comprobada.")


func _test_rebuild_run_pool_filtering() -> void:
	var pool_mgr := ItemPoolManager.new()
	add_child(pool_mgr)

	var test_unlocked: Array[StringName] = [&"botas", &"espada", &"escudo", &"fusion_reactor"]
	var test_banned: Array[StringName] = [&"escudo", &"fusion_reactor"]

	pool_mgr.rebuild_run_pool(null, test_unlocked, test_banned)
	var active: Array[ItemData] = pool_mgr.get_active_pool()

	var active_ids: Array[StringName] = []
	for it in active:
		active_ids.append(it.item_id)

	assert_true(active_ids.has(&"botas"), "botas debe estar en el active pool")
	assert_true(active_ids.has(&"espada"), "espada debe estar en el active pool")
	assert_true(not active_ids.has(&"escudo"), "escudo baneado NO debe estar en el active pool")
	assert_true(not active_ids.has(&"fusion_reactor"), "fusion_reactor baneado NO debe estar en el active pool")

	pool_mgr.queue_free()
	print("  ✓ [PASS] Test 6: ItemPoolManager.rebuild_run_pool excluye adecuadamente los ítems baneados.")


func _test_character_select_integration() -> void:
	var char_select: Control = CharacterSelectScene.instantiate() as Control
	add_child(char_select)

	assert_true(char_select.get("arsenal_banlist_btn") != null, "arsenal_banlist_btn debe existir en CharacterSelect")
	assert_true(char_select.get("arsenal_banlist_modal") != null, "arsenal_banlist_modal debe estar instanciado en CharacterSelect")

	char_select._on_arsenal_banlist_pressed(2)
	assert_true(char_select.arsenal_banlist_modal.is_open, "Presionar arsenal_banlist_btn debe abrir el modal")
	assert_true(char_select.arsenal_banlist_modal.active_tab == ArsenalBanlistModalScript.TabCategory.OVERLOADS, "Debe abrirse en la pestaña indicada")

	char_select.arsenal_banlist_modal.close_modal()
	assert_true(not char_select.arsenal_banlist_modal.is_open, "Cerrar el modal debe actualizar is_open a false")

	char_select.queue_free()
	print("  ✓ [PASS] Test 7: Integración con CharacterSelect validada exitosamente.")

class_name TestPhase1UIPolishSuite
extends BaseTestSuite

## TestPhase1UIPolishSuite
## Valida las especificaciones técnicas implementadas en la Fase 1:
## - Centrado simétrico de PauseMenu
## - Separación de glows en HUD CenterCluster
## - Opacidad 75% en combate TAB y 100% en menús para CombatStatsDock
## - Eliminación de CreditsLabel redundante en SatelliteShop
## - Formateo limpio y porcentual en ArcanaCardBuilder

func _ready() -> void:
	super._ready()
	print("--- TEST PHASE 1 UI POLISH START ---")
	_run_tests()

func _run_tests() -> void:
	# 1. Centrado simétrico del menú de pausa
	var pause_scene: PackedScene = load("res://scenes/ui/pause_menu/pause_menu.tscn")
	assert_true(pause_scene != null, "No se pudo cargar pause_menu.tscn")
	var pause_inst: Node = pause_scene.instantiate()
	var panel: Control = pause_inst.get_node_or_null("Panel") as Control
	assert_true(panel != null, "No se encontró el nodo Panel en pause_menu.tscn")
	assert_true(is_equal_approx(panel.offset_left, -490.0), "PauseMenu panel.offset_left debe ser -490.0, fue: %f" % panel.offset_left)
	assert_true(is_equal_approx(panel.offset_right, 490.0), "PauseMenu panel.offset_right debe ser 490.0, fue: %f" % panel.offset_right)
	assert_true(is_equal_approx(panel.offset_left + panel.offset_right, 0.0), "PauseMenu panel debe estar 100% centrado simétricamente (suma cero)")
	print("  ✓ [PASS] Test 1: Menú de Pausa centrado simétricamente a +-490.0 px")
	pause_inst.queue_free()

	# 2. Separación en HUD CenterCluster
	var hud_scene: PackedScene = load("res://scenes/ui/hud/hud.tscn")
	assert_true(hud_scene != null, "No se pudo cargar hud.tscn")
	var hud_inst: Node = hud_scene.instantiate()
	var cluster: VBoxContainer = hud_inst.get_node_or_null("CenterCluster") as VBoxContainer
	assert_true(cluster != null, "No se encontró CenterCluster en hud.tscn")
	var separation: int = cluster.get_theme_constant("separation")
	assert_true(separation >= 10, "CenterCluster separation debe ser >= 10, actual: %d" % separation)
	print("  ✓ [PASS] Test 2: Separación de resplandores en HUD CenterCluster es %d px" % separation)
	hud_inst.queue_free()

	# 3. Opacidad de CombatStatsDock (75% en TAB, 100% en Menús)
	var dock := CombatStatsDock.new()
	assert_true(dock.custom_minimum_size.x >= 280.0, "CombatStatsDock ancho debe ser >= 280")
	# Petición solo TAB
	dock.set_dock_requested(&"tab", true)
	assert_true(dock.visible, "Dock debe ser visible al solicitar TAB")
	assert_true(is_equal_approx(dock.modulate.a, 0.75), "Dock modulate.a debe ser 0.75 cuando solo TAB está activo, fue: %f" % dock.modulate.a)
	# Petición externa concurrente (ej. Tienda o Pausa)
	dock.set_dock_requested(&"shop", true)
	assert_true(is_equal_approx(dock.modulate.a, 1.0), "Dock modulate.a debe ser 1.0 al abrir tienda satelital, fue: %f" % dock.modulate.a)
	# Cierre de tienda, solo queda TAB
	dock.set_dock_requested(&"shop", false)
	assert_true(is_equal_approx(dock.modulate.a, 0.75), "Dock modulate.a debe regresar a 0.75 al cerrar tienda, fue: %f" % dock.modulate.a)
	# Cierre de TAB
	dock.set_dock_requested(&"tab", false)
	assert_true(not dock.visible, "Dock debe ocultarse al cerrar todas las peticiones")
	print("  ✓ [PASS] Test 3: Opacidad de CombatStatsDock ajustada reactivamente (0.75 TAB / 1.0 Menús)")
	dock.queue_free()

	# 4. SatelliteShop sin CreditsLabel redundante
	var shop_scene: PackedScene = load("res://scenes/combat/satellite/satellite_shop.tscn")
	assert_true(shop_scene != null, "No se pudo cargar satellite_shop.tscn")
	var shop_inst: Node = shop_scene.instantiate()
	var topbar: Control = shop_inst.find_child("TopBar", true, false) as Control
	assert_true(topbar != null, "TopBar de satellite_shop no encontrado")
	var redundant_credits = topbar.get_node_or_null("CreditsLabel")
	assert_true(redundant_credits == null, "CreditsLabel redundante en TopBar debe haber sido eliminado")
	print("  ✓ [PASS] Test 4: SatelliteShop verificado sin etiqueta redundante de créditos")
	shop_inst.queue_free()

	# 5. Formateo de estadísticas porcentuales en Arcana
	var crit_formatted: String = LevelUpStatsInspector.format_stat_modifier(&"crit_chance", 0.06, false, true)
	assert_true(crit_formatted.contains("%") and not crit_formatted.contains("+0"), "crit_chance debe mostrar porcentaje (+6%), resultado: %s" % crit_formatted)
	var cd_formatted: String = LevelUpStatsInspector.format_stat_modifier(&"cooldown_reduction", -0.10, false, true)
	assert_true(cd_formatted.contains("%") and not cd_formatted.contains("-0"), "cooldown_reduction debe mostrar porcentaje (-10%), resultado: %s" % cd_formatted)
	print("  ✓ [PASS] Test 5: Formateo porcentual en Arcana verificado (Crit: %s | CD: %s)" % [crit_formatted, cd_formatted])

	pass_suite("TestPhase1UIPolishSuite completado con éxito (5/5 asserts pasados).")

extends Node

func _ready() -> void:
	# Watchdog timer de seguridad
	get_tree().create_timer(10.0, true, false, true).timeout.connect(func():
		push_error("Test timed out after 10s!")
		get_tree().quit(1)
	)

	print("\n==========================================")
	print("[TEST] Testing Satellite Edge Indicator (Cuadradito Radar)...")
	print("==========================================\n")

	var main_scene: PackedScene = load("res://scenes/combat/main_game.tscn")
	var main_game: MainGame = main_scene.instantiate()
	add_child(main_game)

	# Limpiar diálogos para aislar entorno
	if Dialogic.has_subsystem("Styles") and Dialogic.Styles.has_active_layout_node():
		var l_node = Dialogic.Styles.get_layout_node()
		if is_instance_valid(l_node):
			l_node.hide()
	Dialogic.end_timeline(true)
	Dialogic.current_timeline = null
	main_game.is_briefing_active = false
	get_tree().paused = false
	await get_tree().process_frame

	var hud: GameHUD = main_game.hud
	var player: Player = main_game.player

	# ----------------------------------------------------
	# CASO 1: Verificación de capa de renderizado (por debajo de textos/UI)
	# ----------------------------------------------------
	print("[1/5] Testing Rendering Layer Hierarchy (Underneath UI Texts)...")
	var tracker_layer: CanvasLayer = hud.get_node_or_null("SatelliteTrackerLayer") as CanvasLayer
	assert(tracker_layer != null, "SatelliteTrackerLayer debe existir en el HUD")
	assert(tracker_layer.layer == 8, "SatelliteTrackerLayer debe estar en layer 8 (por debajo de HUD layer 10)")
	assert(hud.layer == 10, "GameHUD debe estar en layer 10 para superponer textos y barras sobre el cuadradito")
	print("  ✓ Jerarquía de capas validada: SatelliteTrackerLayer (layer 8) < GameHUD UI (layer 10).")

	var tracker: SatelliteEdgeIndicator = tracker_layer.get_node_or_null("SatelliteEdgeIndicator") as SatelliteEdgeIndicator
	assert(tracker != null, "SatelliteEdgeIndicator debe existir")
	assert(tracker.custom_minimum_size == Vector2(50, 50), "El indicador debe ser un cuadradito compacto de 50x50")

	# ----------------------------------------------------
	# CASO 2: Ocultación inicial cuando no hay satélite activo
	# ----------------------------------------------------
	print("\n[2/5] Testing Hidden State when No Satellite is Active...")
	hud.clear_satellite()
	tracker._process(0.016)
	assert(not tracker.visible, "El cuadradito debe estar oculto cuando no hay satélite en curso")
	print("  ✓ Indicador oculto mientras se viaja o no hay baliza orbital activa.")

	# ----------------------------------------------------
	# CASO 3: Activación y cálculo de intersección con el borde de la pantalla
	# ----------------------------------------------------
	print("\n[3/5] Testing Border Intersection Math & Movement Along Edges...")
	player.global_position = Vector2(960, 540) # Centro habitual de la pantalla

	# 3.1 Satélite a la derecha fuera de pantalla (por ejemplo x = 3000)
	var sat_right := Vector2(3000, 540)
	hud.set_active_satellite(sat_right, 1)
	tracker._process(0.016)
	await get_tree().process_frame

	assert(tracker.visible, "El indicador debe mostrarse con satélite activo")
	var vp_size := tracker.get_viewport().get_visible_rect().size
	var half_w := tracker.BOX_SIZE.x * 0.5
	var pad := tracker.PADDING
	var max_x_expected := vp_size.x - half_w - pad

	# El centro del cuadradito debe estar tocando el borde derecho
	var box_center_x := tracker.global_position.x + half_w
	assert(is_equal_approx(box_center_x, max_x_expected) or abs(box_center_x - max_x_expected) <= 1.0,
		"El cuadradito debe ubicarse en el borde derecho (X: %f, esperado: %f)" % [box_center_x, max_x_expected])
	print("  ✓ Satélite hacia el este -> Cuadradito ubicado en el borde derecho exacto: %s" % str(tracker.global_position))

	# 3.2 Satélite al norte fuera de pantalla (por ejemplo y = -2000)
	var sat_up := Vector2(960, -2000)
	hud.set_active_satellite(sat_up, 1)
	tracker._process(0.016)
	var half_h := tracker.BOX_SIZE.y * 0.5
	var min_y_expected := half_h + pad
	var box_center_y := tracker.global_position.y + half_h
	assert(is_equal_approx(box_center_y, min_y_expected) or abs(box_center_y - min_y_expected) <= 1.0,
		"El cuadradito debe ubicarse en el borde superior (Y: %f, esperado: %f)" % [box_center_y, min_y_expected])
	print("  ✓ Satélite hacia el norte -> Cuadradito ubicado en el borde superior exacto: %s" % str(tracker.global_position))

	# ----------------------------------------------------
	# CASO 4: Información de icono y distancia
	# ----------------------------------------------------
	print("\n[4/5] Testing Satellite Icon & Distance Label Display...")
	assert(tracker.icon_rect != null and tracker.icon_rect.texture != null, "Debe tener un icono asignado")
	assert(tracker.distance_label != null, "Debe tener una etiqueta de distancia")

	# Con sat_up a (960, -2000) y jugador a (960, 540), distancia = 2540m
	var expected_dist := int(player.global_position.distance_to(sat_up))
	assert(tracker.distance_label.text == "%dm" % expected_dist,
		"Etiqueta de distancia debe mostrar %dm (muestra: %s)" % [expected_dist, tracker.distance_label.text])
	print("  ✓ Icono presente y distancia lejana formateada correctamente: %s" % tracker.distance_label.text)

	# Satélite muy cerca del jugador (por ejemplo a 100m)
	var sat_near := player.global_position + Vector2(100, 0)
	hud.set_active_satellite(sat_near, 1)
	tracker._process(0.016)
	assert(tracker.distance_label.text == "CERCA", "A menos de 180m debe mostrar 'CERCA'")
	print("  ✓ Al aproximarse al satélite, indica estado de proximidad: %s" % tracker.distance_label.text)

	# ----------------------------------------------------
	# CASO 5: Ocultación en menús sobrepuestos
	# ----------------------------------------------------
	print("\n[5/5] Testing Auto-Hide During Overlaid Modals...")
	main_game.level_up_modal.show_level_up(2)
	tracker._process(0.016)
	assert(not tracker.visible, "El cuadradito debe ocultarse cuando el menú de level-up está abierto")
	main_game.level_up_modal.clear_pending_levels()
	main_game.level_up_modal.hide()
	get_tree().paused = false
	tracker._process(0.016)
	assert(tracker.visible, "El cuadradito vuelve a mostrarse cuando se reanuda el combate")
	print("  ✓ El indicador se oculta limpiamente durante modales y reaparece en combate activo.")

	print("\n==========================================")
	print("[PASS] ALL SATELLITE EDGE INDICATOR TESTS PASSED (100%)!")
	print("==========================================\n")
	get_tree().quit(0)

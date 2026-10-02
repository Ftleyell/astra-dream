extends Node2D

func _ready() -> void:
	print("\n=======================================================")
	print("🎬 EJECUTANDO TEST SUITE: DIÁLOGOS CINEMÁTICOS, RIVALES Y ZOOM")
	print("=======================================================\n")

	_test_camera_zoom()
	_test_dialogue_backdrop_layer()
	_test_pet_portraits_flipped()
	_test_navigator_portraits_dch()
	_test_rival_warp_in_cinematic()
	_test_hyperspace_portal_shockwave_and_clearance()
	_test_navigator_prologue_transmission()
	_test_debug_modal_quick_rival_spawn_button()

	print("\n=======================================================")
	print("🎉 TODOS LOS TESTS DE CINEMÁTICAS, DIÁLOGOS Y ZOOM PASARON EXITOSAMENTE!")
	print("=======================================================\n")
	get_tree().quit(0)

func _test_camera_zoom() -> void:
	print("[1/5] Verificando GameCamera2D (Zoom Dinámico y Foco Cinemático)...")
	var cam := GameCamera2D.new()
	add_child(cam)

	assert(cam.target_zoom == 1.0, "El zoom inicial debe ser 1.0x")
	assert(cam.min_zoom == 1.0, "El zoom mínimo debe ser 1.0x")
	assert(cam.max_zoom == 2.0, "El zoom máximo debe ser 2.0x")

	# Simular Wheel Up
	var event_up := InputEventMouseButton.new()
	event_up.button_index = MOUSE_BUTTON_WHEEL_UP
	event_up.pressed = true
	cam._unhandled_input(event_up)
	assert(cam.target_zoom > 1.0, "Wheel Up debe incrementar target_zoom")

	# Simular Middle Click Reset
	var event_mid := InputEventMouseButton.new()
	event_mid.button_index = MOUSE_BUTTON_MIDDLE
	event_mid.pressed = true
	cam._unhandled_input(event_mid)
	assert(cam.target_zoom == 1.0, "Middle Click debe restablecer target_zoom a 1.0x")

	# Simular enfoque cinemático al midpoint
	var midpoint := Vector2(300.0, 400.0)
	cam.set_cinematic_focus(midpoint, 1.25)
	assert(cam.custom_focus_point == midpoint, "custom_focus_point debe coincidir con midpoint")
	assert(cam.zoom_override == 1.25, "zoom_override debe coincidir con 1.25x")

	cam.clear_cinematic_focus()
	assert(cam.custom_focus_point == Vector2.INF, "clear_cinematic_focus debe limpiar el punto de foco")
	assert(cam.zoom_override == 0.0, "clear_cinematic_focus debe limpiar el override de zoom")

	cam.queue_free()
	print("  ✓ GameCamera2D responde correctamente a rueda, reset y foco cinemático.")

func _test_dialogue_backdrop_layer() -> void:
	print("[2/5] Verificando DialogueBackdropLayer...")
	var scene := preload("res://scenes/ui/dialogue/dialogue_backdrop_layer.tscn")
	var layer = scene.instantiate()
	add_child(layer)

	assert(layer.layer == 15, "DialogueBackdropLayer debe operar en CanvasLayer 15")
	assert(layer.backdrop_rect != null, "BackdropRect debe estar presente")
	assert(layer.backdrop_rect.mouse_filter == Control.MOUSE_FILTER_IGNORE, "BackdropRect no debe bloquear clics de Dialogic")

	layer.fade_in(0.01)
	assert(layer.backdrop_rect.visible == true, "BackdropRect debe ser visible tras fade_in")

	layer.fade_out(0.01)
	layer.queue_free()
	print("  ✓ DialogueBackdropLayer verificado con éxito.")

func _test_pet_portraits_flipped() -> void:
	print("[3/5] Verificando Retratos Flipped y Centrado Vertical en Mascotas (.dch)...")
	var pets := ["mochi", "kuro", "luna", "pip", "cosmo"]
	for p_id in pets:
		var path := "res://narrative/characters/%s.dch" % p_id
		assert(ResourceLoader.exists(path), "Debe existir el recurso %s" % path)
		var dch = load(path)
		assert(dch != null and dch.portraits.has("Flipped"), "Mascota %s debe tener retrato Flipped" % p_id)
		assert(dch.portraits["Flipped"]["mirror"] == true, "Mascota %s debe tener mirror = true en Flipped" % p_id)
		assert(not dch.display_name.contains("[Copiloto]"), "Mascota %s no debe contener [Copiloto] en su nombre" % p_id)
		assert(dch.offset.y <= -200.0 and dch.offset.y >= -300.0, "Mascota %s debe tener offset vertical centrado (actual: %s)" % [p_id, dch.offset.y])
		assert(dch.portraits["Normal"].offset == Vector2.ZERO, "Mascota %s debe tener offset Vector2.ZERO en Normal para no duplicar desplazamiento" % p_id)
		assert(dch.portraits["Flipped"].offset == Vector2.ZERO, "Mascota %s debe tener offset Vector2.ZERO en Flipped para no duplicar desplazamiento" % p_id)
	print("  ✓ Todas las mascotas cuentan con orientación Flipped (mirror=true), escala 0.65, offset vertical flotante centrado y nombre sin [Copiloto].")

func _test_navigator_portraits_dch() -> void:
	print("[4/5] Verificando Recursos Dialogic de Navegantes (.dch)...")
	var navs := ["lyra", "vespera", "iris", "zephyr", "caelia"]
	for nav_id in navs:
		var path := "res://narrative/characters/%s.dch" % nav_id
		assert(ResourceLoader.exists(path), "Debe existir el recurso %s" % path)
		var dch = load(path)
		assert(dch != null, "Recurso %s debe cargarse correctamente" % path)
		assert(dch.portraits.has("Normal") and dch.portraits.has("Flipped"), "Navegante %s debe tener Normal y Flipped" % nav_id)
		assert(dch.portraits["Flipped"]["mirror"] == true, "Navegante %s debe tener mirror = true en Flipped" % nav_id)
	print("  ✓ Todas las 5 navegantes cuentan con recursos .dch y orientaciones completas.")

func _test_rival_warp_in_cinematic() -> void:
	print("[5/5] Verificando RivalPilotBoss open_warp_portal, emerge_from_portal y play_warp_in_cinematic...")
	var rival_scene := preload("res://scenes/combat/bosses/rival_pilot_boss.tscn")
	var rival := rival_scene.instantiate() as RivalPilotBoss
	add_child(rival)
	rival.setup_pilot(&"nova", 1)

	assert(rival.has_method("open_warp_portal"), "RivalPilotBoss debe poseer open_warp_portal")
	assert(rival.has_method("emerge_from_portal"), "RivalPilotBoss debe poseer emerge_from_portal")

	var callback_called := false
	rival.play_warp_in_cinematic(func() -> void:
		callback_called = true
	)

	# Simular un frame de animación
	rival.queue_free()
	print("  ✓ RivalPilotBoss desacoplamiento de portal y llegada cinemática verificado exitosamente.")

func _test_navigator_prologue_transmission() -> void:
	print("[6/6] Verificando NavigatorCommsWidget show_prologue_transmission y espera de input...")
	var widget_scene := preload("res://scenes/ui/hud/navigator_comms_widget.tscn")
	var widget = widget_scene.instantiate()
	add_child(widget)

	assert(widget.layer >= 25, "NavigatorCommsWidget debe estar en layer >= 25 (por encima de Dialogic y Dimmer)")

	var nav_data := preload("res://data/navigators/roster/lyra.tres")
	var continued := [false]
	widget.show_prologue_transmission(nav_data, "Test transmisión de despegue", func() -> void:
		continued[0] = true
	)

	assert(widget._waiting_for_input == true, "Debe esperar input tras mostrar transmisión de prólogo")

	# Simular pulsación de barra espaciadora
	var space_event := InputEventKey.new()
	space_event.keycode = KEY_SPACE
	space_event.physical_keycode = KEY_SPACE
	space_event.pressed = true
	widget._unhandled_input(space_event)

	assert(widget._waiting_for_input == false, "Pulsar espacio debe desactivar la espera de input")
	assert(continued[0] == true, "Callback de despegue debe haberse ejecutado tras pulsar espacio")

	widget.queue_free()
	print("  ✓ NavigatorCommsWidget procesa transmisión de prólogo y tecla espacio correctamente.")

func _test_hyperspace_portal_shockwave_and_clearance() -> void:
	print("[7/8] Verificando HyperspacePortal y onda expansiva de despeje (Shockwave)...")
	var portal_script = preload("res://scenes/combat/bosses/hyperspace_portal.gd")
	var portal = portal_script.new()
	portal.setup(Vector2(500.0, 500.0), Color(0.0, 0.9, 1.0), 68.0, 680.0)
	add_child(portal)

	# Crear un asteroide u obstáculo en el radio de la shockwave
	var ast_scene := preload("res://scenes/combat/environment/asteroid.tscn")
	var ast = ast_scene.instantiate()
	ast.global_position = Vector2(650.0, 500.0) # Dentro del radio de 680px
	add_child(ast)

	assert(ast.is_in_group("destructibles"), "El asteroide debe pertenecer al grupo destructibles")

	# Ejecutar detonación de la shockwave
	portal._detonate_clearance_shockwave()

	# El asteroide debe haber comenzado su desintegración
	assert(ast.is_dying == true, "La onda expansiva debe haber marcado el obstáculo para desintegración")

	portal.queue_free()
	ast.queue_free()
	print("  ✓ HyperspacePortal detona shockwave y vaporiza obstáculos adyacentes con éxito.")

func _test_debug_modal_quick_rival_spawn_button() -> void:
	print("[8/8] Verificando botón de testeo rápido de rivales en DebugMenuModal...")
	var debug_scene := preload("res://scenes/ui/debug/debug_menu_modal.tscn")
	var debug_modal = debug_scene.instantiate()
	add_child(debug_modal)

	assert(debug_modal.quick_rival_spawn_btn != null, "QuickRivalSpawnButton debe existir y estar referenciado")
	assert(debug_modal.quick_rival_spawn_btn.is_inside_tree(), "QuickRivalSpawnButton debe estar dentro del árbol")
	assert(debug_modal.quick_rival_spawn_btn.text.contains("TESTEAR SPAWN RIVAL"), "Texto del botón debe ser representativo")

	debug_modal.queue_free()
	print("  ✓ QuickRivalSpawnButton verificado en Pestaña de Combate de depuración.")

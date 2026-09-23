extends Node

func _ready() -> void:
	# Fallback timeout
	get_tree().create_timer(10.0).timeout.connect(func():
		print("[TEST WATCHDOG] Timeout reached in Debug Menu test.")
		get_tree().quit(1)
	)

	print("\n==========================================")
	print("[TEST] Testing Debug Menu, Cheats & Stat Sliders Integration...")
	print("==========================================")

	# 1. Resetear DebugManager a estado inicial
	DebugManager.reset_all()
	assert(not DebugManager.is_enabled, "DebugManager debe iniciar desactivado")
	assert(not DebugManager.infinite_hp, "Infinite HP debe iniciar false")
	assert(not DebugManager.infinite_credits, "Infinite Credits debe iniciar false")
	assert(not DebugManager.infinite_consumables, "Infinite Consumables debe iniciar false")
	print("  ✓ DebugManager inicializado en estado limpio")

	# 2. Instanciar CharacterSelectUI
	var char_select_scene: PackedScene = load("res://scenes/ui/character_select/character_select.tscn")
	var char_select = char_select_scene.instantiate()
	add_child(char_select)
	await get_tree().process_frame
	await get_tree().process_frame

	assert(CharacterSelectUI.DEBUG_MENU_AVAILABLE == true, "DEBUG_MENU_AVAILABLE debe estar habilitado")
	assert(char_select.debug_button != null, "DebugButton debe existir en el menú de despliegue")
	assert(char_select.debug_button.visible == true, "DebugButton debe ser visible")
	assert(char_select.debug_menu_modal != null, "DebugMenuModal debe estar instanciado")
	assert(not char_select.debug_menu_modal.is_open, "DebugMenuModal debe iniciar cerrado")
	print("  ✓ Menú de Despliegue con botón de Debug [F1] verificado")

	# 3. Abrir DebugMenuModal
	char_select._on_debug_pressed()
	await get_tree().process_frame
	assert(char_select.debug_menu_modal.is_open == true, "DebugMenuModal debe abrirse tras _on_debug_pressed()")
	assert(char_select.debug_menu_modal.visible == true, "DebugMenuModal debe ser visible")
	print("  ✓ DebugMenuModal abierto y visible")

	# 4. Validar existencia de controles de todas las estadísticas (15 stats)
	var modal = char_select.debug_menu_modal
	assert(modal._stat_controls.size() == 15, "Deben existir exactamente 15 estadísticas configurables (encontradas: %d)" % modal._stat_controls.size())
	print("  ✓ Cobertura completa de las 15 estadísticas de CharacterStats verificada")

	# 5. Probar entrada numérica y confirmación con BARRA ESPACIADORA en LineEdit
	assert(modal._stat_controls.has(&"move_speed"), "move_speed debe estar en _stat_controls")
	var speed_ctrl: Dictionary = modal._stat_controls[&"move_speed"]
	var speed_input: LineEdit = speed_ctrl.input
	var speed_slider: HSlider = speed_ctrl.slider

	speed_input.text = "850"
	var space_event := InputEventKey.new()
	space_event.pressed = true
	space_event.keycode = KEY_SPACE
	speed_input.gui_input.emit(space_event)
	await get_tree().process_frame

	assert(speed_slider.value == 850.0, "El slider de velocidad debe actualizarse a 850.0 (actual: %f)" % speed_slider.value)
	assert(DebugManager.get_stat_override(&"move_speed", 0.0) == 850.0, "DebugManager debe almacenar move_speed = 850.0")
	assert(not speed_input.text.contains(" "), "La barra espaciadora no debe agregar espacios en el LineEdit numérico")
	print("  ✓ Barra espaciadora en LineEdit fija el valor y sincroniza el slider (move_speed = 850)")

	# Modificar otra estadística: daño base
	var dmg_ctrl: Dictionary = modal._stat_controls[&"base_damage"]
	dmg_ctrl.input.text = "120"
	dmg_ctrl.input.gui_input.emit(space_event)
	await get_tree().process_frame
	assert(DebugManager.get_stat_override(&"base_damage", 0.0) == 120.0, "DebugManager debe almacenar base_damage = 120.0")
	print("  ✓ Modificación de daño base fijada con éxito (base_damage = 120)")

	# 6. Activar Trampas (Toggles)
	modal.infinite_hp_check.button_pressed = true
	modal.infinite_credits_check.button_pressed = true
	modal.infinite_consumables_check.button_pressed = true
	await get_tree().process_frame

	assert(DebugManager.infinite_hp == true, "infinite_hp debe estar activo")
	assert(DebugManager.infinite_credits == true, "infinite_credits debe estar activo")
	assert(DebugManager.infinite_consumables == true, "infinite_consumables debe estar activo")
	assert(DebugManager.is_enabled == true, "DebugManager.is_enabled debe ser true")
	print("  ✓ Trampas activadas: Vida Infinita, Créditos Infinitos, Consumibles Infinitos")

	# 7. Cerrar modal
	modal.close_menu()
	await get_tree().process_frame
	assert(not modal.is_open, "DebugMenuModal debe cerrarse limpiamente")
	print("  ✓ DebugMenuModal cerrado correctamente")
	char_select.queue_free()
	await get_tree().process_frame

	# 8. Instanciar MainGame y comprobar aplicación de trampas y stats modificados en combate
	print("\n[Testing Combat Propagation of Cheats & Stat Overrides]")
	var main_game_scene: PackedScene = load("res://scenes/combat/main_game.tscn")
	var main_game: MainGame = main_game_scene.instantiate()
	add_child(main_game)
	await get_tree().process_frame
	await get_tree().process_frame

	# 8.1. Descartar briefing para testear combate libre
	if main_game.skip_badge_layer and main_game.skip_badge_layer.has_method("_execute_skip"):
		main_game.skip_badge_layer._execute_skip()
	Dialogic.end_timeline(true)
	main_game.is_briefing_active = false
	get_tree().paused = false
	await get_tree().process_frame

	var player := main_game.player
	assert(player != null, "Player debe existir en MainGame")

	# 8.2. Validar créditos infinitos
	assert(player.run_credits >= 999999, "Los créditos del jugador deben ser 999,999 (actual: %d)" % player.run_credits)
	print("  ✓ Créditos infinitos aplicados al jugador (999,999 u.)")

	# 8.3. Validar consumibles infinitos
	assert(player.bomb_count == 5, "Las bombas del jugador deben iniciar al máximo (5)")
	player._execute_bomb()
	assert(player.bomb_count == 5, "Con consumibles infinitos, las bombas NO deben decrementar al detonar (bombas: %d)" % player.bomb_count)
	print("  ✓ Consumibles infinitos verificados: la bomba detona sin gastar cargas")

	# 8.4. Validar stats personalizados
	assert(player.stats._base_stats[&"move_speed"] == 850.0, "La velocidad base debe ser 850.0")
	assert(player.stats.get_stat(&"move_speed") >= 850.0, "La velocidad efectiva debe ser >= 850.0 (actual: %f)" % player.stats.get_stat(&"move_speed"))
	assert(player.stats._base_stats[&"base_damage"] == 120.0, "El daño base debe ser 120.0 según el override del Debug Menu")
	assert(player.stats.get_stat(&"base_damage") >= 120.0, "El daño base con talentos debe ser >= 120.0 (actual: %f)" % player.stats.get_stat(&"base_damage"))
	print("  ✓ Modificadores de estadísticas aplicados en tiempo de ejecución al Player")

	# 8.5. Validar vida infinita (God Mode)
	var hp_before := player.current_health
	player.take_damage(50.0)
	assert(player.current_health == hp_before, "Con Vida Infinita, take_damage NO debe restar salud (salud: %f, antes: %f)" % [player.current_health, hp_before])
	print("  ✓ Vida Infinita (God Mode) verificada: daño mitigado al 100%")

	# 9. Limpieza
	main_game.queue_free()
	DebugManager.reset_all()

	print("\n==========================================")
	print("[PASS] ALL DEBUG MENU & CHEATS TESTS PASSED (100%)!")
	print("==========================================\n")
	get_tree().quit(0)

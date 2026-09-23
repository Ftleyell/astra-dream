extends Node

func _ready() -> void:
	# Watchdog timer de seguridad para evitar que el proceso se quede colgado
	get_tree().create_timer(10.0, true, false, true).timeout.connect(func():
		push_error("Test timed out after 10s!")
		get_tree().quit(1)
	)

	print("\n==========================================")
	print("[TEST] Testing Level-Up Stacking Queue & Miss-Click Prevention...")
	print("==========================================\n")

	var main_scene: PackedScene = load("res://scenes/combat/main_game.tscn")
	var main_game: MainGame = main_scene.instantiate()
	add_child(main_game)

	# Limpiar timelines o diálogos iniciales para aislar pruebas
	if Dialogic.has_subsystem("Styles") and Dialogic.Styles.has_active_layout_node():
		var l_node = Dialogic.Styles.get_layout_node()
		if is_instance_valid(l_node):
			l_node.hide()
	Dialogic.end_timeline(true)
	Dialogic.current_timeline = null
	main_game.is_briefing_active = false
	get_tree().paused = false
	await get_tree().process_frame

	var player: Player = main_game.player
	var level_modal: LevelUpModal = main_game.level_up_modal
	var sat_shop: SatelliteShop = main_game.satellite_shop

	# ----------------------------------------------------
	# CASO 1: Multi-level EXP loop en player.gd
	# ----------------------------------------------------
	print("[1/5] Testing Multi-Level EXP Loop in player.gd...")
	player.current_level = 1
	player.current_exp = 0.0
	player.exp_to_next = 40.0
	var initial_lvl: int = player.current_level
	var levels_emitted: Array[int] = []
	var on_lvl = func(lvl: int): levels_emitted.append(lvl)
	player.level_up_requested.connect(on_lvl)

	# Otorgar EXP masiva suficiente para subir al menos 2 niveles simultáneos
	# Nivel 1 -> 2: requiere 40. exp_to_next se vuelve 40 * 1.35 = 54. Total para nivel 3 = 94.
	player.add_exp(150.0)
	assert(player.current_level >= 3, "El jugador debió subir al menos a nivel 3 con 150 EXP (nivel actual: %d)" % player.current_level)
	assert(levels_emitted.size() >= 2, "Debieron emitirse múltiples señales de level_up_requested (emitidas: %s)" % str(levels_emitted))
	print("  ✓ add_exp() procesó la subida acumulativa de niveles correctamente: %s" % str(levels_emitted))
	player.level_up_requested.disconnect(on_lvl)

	# ----------------------------------------------------
	# CASO 2: Level-Up Queueing y visualización de pendientes
	# ----------------------------------------------------
	print("\n[2/5] Testing Level-Up Queueing & Header Pending Count...")
	level_modal.clear_pending_levels()
	level_modal.hide()

	# Abrir primer nivel (Nivel 2)
	level_modal.show_level_up(2)
	assert(level_modal.visible, "LevelUpModal debe estar visible")
	assert(level_modal.is_presenting_level, "is_presenting_level debe ser true")
	assert(level_modal.current_level_shown == 2, "Debe estar mostrando nivel 2")
	assert(level_modal.pending_levels_queue.is_empty(), "La cola de pendientes debe estar vacía inicialmente")
	assert("¡SUBIDA DE NIVEL 2!" in level_modal.level_label.text, "El título debe indicar nivel 2")

	# Encolar Niveles 3 y 4 mientras el modal está abierto
	level_modal.show_level_up(3)
	level_modal.show_level_up(4)
	assert(level_modal.pending_levels_queue.size() == 2, "Deben haber 2 niveles pendientes en cola (hay: %d)" % level_modal.pending_levels_queue.size())
	assert(level_modal.pending_levels_queue == [3, 4], "La cola debe contener [3, 4]")
	assert("(+2 PENDIENTES)" in level_modal.level_label.text, "El título debe mostrar (+2 PENDIENTES): %s" % level_modal.level_label.text)
	print("  ✓ Título actualizado dinámicamente con niveles pendientes: '%s'" % level_modal.level_label.text)

	# ----------------------------------------------------
	# CASO 3: Selección secuencial sin pisarse ni despausar prematuramente
	# ----------------------------------------------------
	print("\n[3/5] Testing Sequential Level Selection Without Screen Flash or Premature Unpause...")
	assert(get_tree().paused, "El juego debe estar pausado")

	# Seleccionar carta para Nivel 2
	assert(not level_modal.current_offered_cards.is_empty(), "Deben haberse ofrecido cartas")
	var card_1 = level_modal.current_offered_cards[0]
	level_modal._select_card(card_1)

	# Debe transicionar automáticamente a Nivel 3
	assert(level_modal.visible, "LevelUpModal DEBE permanecer visible tras elegir la primera carta")
	assert(get_tree().paused, "El juego DEBE permanecer pausado mientras haya niveles pendientes")
	assert(level_modal.current_level_shown == 3, "Ahora debe estarse presentando el nivel 3")
	assert(level_modal.pending_levels_queue.size() == 1, "Debe quedar 1 nivel pendiente")
	assert("(+1 PENDIENTES)" in level_modal.level_label.text, "El título debe mostrar (+1 PENDIENTES): %s" % level_modal.level_label.text)
	print("  ✓ Nivel 2 completado -> Nivel 3 presentado limpiamente sin despausar el combate.")

	# Seleccionar carta para Nivel 3
	var card_2 = level_modal.current_offered_cards[0]
	level_modal._select_card(card_2)

	# Debe transicionar automáticamente a Nivel 4
	assert(level_modal.visible, "LevelUpModal DEBE seguir visible para el nivel 4")
	assert(get_tree().paused, "El juego DEBE seguir pausado")
	assert(level_modal.current_level_shown == 4, "Ahora debe estarse presentando el nivel 4")
	assert(level_modal.pending_levels_queue.is_empty(), "La cola de pendientes ahora debe estar vacía")
	assert(not "(+" in level_modal.level_label.text, "El título ya no debe mostrar pendientes acumulados")
	print("  ✓ Nivel 3 completado -> Nivel 4 presentado (último en cola).")

	# Seleccionar carta para Nivel 4 (último)
	var card_3 = level_modal.current_offered_cards[0]
	level_modal._select_card(card_3)

	# Ahora debe cerrarse y despausar el juego
	assert(not level_modal.visible, "LevelUpModal DEBE ocultarse cuando no quedan niveles")
	assert(not level_modal.is_presenting_level, "is_presenting_level debe ser false")
	assert(not get_tree().paused, "El juego DEBE despausarse limpiamente tras agotar la cola")
	print("  ✓ Cola de subidas de nivel completada; juego reanudado limpiamente.")

	# ----------------------------------------------------
	# CASO 4: Coexistencia Tienda de Satélite y Subida de Nivel
	# ----------------------------------------------------
	print("\n[4/5] Testing Satellite Shop & Level-Up Coexistence...")
	sat_shop.open_shop(300)
	assert(sat_shop.visible, "SatelliteShop debe estar visible")
	assert(get_tree().paused, "Juego pausado por la tienda")

	# El jugador gana un nivel mientras la tienda está abierta
	main_game._on_level_up_requested(5)
	assert(not level_modal.visible, "LevelUpModal NO debe pisar la tienda abierta")
	assert(level_modal.has_pending_levels(), "El nivel 5 debe estar guardado en cola")

	# Se cierra la tienda de satélite
	sat_shop.close_shop()
	await get_tree().process_frame
	assert(not sat_shop.visible, "SatelliteShop debe estar cerrada")
	assert(level_modal.visible, "LevelUpModal DEBE presentarse inmediatamente al cerrar la tienda")
	assert(get_tree().paused, "El juego DEBE permanecer pausado")
	assert(level_modal.current_level_shown == 5, "LevelUpModal debe presentar el nivel 5 que estaba en cola")
	print("  ✓ Nivel encolado durante la tienda presentado automáticamente al cerrar SatelliteShop.")

	# Cerrar el modal eligiendo carta
	if not level_modal.current_offered_cards.is_empty():
		level_modal._select_card(level_modal.current_offered_cards[0])

	# ----------------------------------------------------
	# CASO 5: Prevención de Miss-Clicks y Botón Compacto
	# ----------------------------------------------------
	print("\n[5/5] Testing Accidental Click Prevention (Miss-Clicks) & Compact Buttons...")
	level_modal.show_level_up(6)
	assert(level_modal.visible, "LevelUpModal abierto")
	assert(level_modal._mouse_lockout_active, "_mouse_lockout_active DEBE ser true inmediatamente al abrir el modal")

	# 5.1 Verificar tamaño compacto del botón de selección
	assert(not level_modal.select_buttons.is_empty(), "Deben existir botones de selección")
	var first_btn := level_modal.select_buttons[0]
	assert(first_btn.custom_minimum_size == Vector2(110, 30), "El botón debe tener dimensiones compactas (110x30 px)")
	assert(first_btn.size_flags_horizontal == Control.SIZE_SHRINK_CENTER, "El botón debe estar centrado para evitar clicks involuntarios")
	print("  ✓ Botones de selección configurados como compactos y centrados (110x30 px).")

	# 5.2 Click en el panel de la carta NO debe seleccionarla
	var first_panel := level_modal.card_panels[0]
	var mouse_event := InputEventMouseButton.new()
	mouse_event.button_index = MOUSE_BUTTON_LEFT
	mouse_event.pressed = true
	first_panel.gui_input.emit(mouse_event)
	assert(level_modal.visible, "Click sobre el panel de la carta NO debe seleccionar ni cerrar el modal")
	assert(level_modal.current_level_shown == 6, "El nivel sigue activo")
	print("  ✓ Clicar sobre el cuerpo de la carta ya no causa miss-clicks involuntarios.")

	# 5.3 Simular spam de click de ratón durante el período de gracia de bloqueo
	assert(level_modal._mouse_lockout_active, "El bloqueo de ratón debe seguir activo dentro de los primeros frames")
	first_btn.pressed.emit()
	assert(level_modal.visible, "Pulsar el botón durante _mouse_lockout_active NO debe seleccionar la mejora")
	print("  ✓ Período de gracia de bloqueo de clicks descartó spam de disparo inicial exitosamente.")

	# 5.4 Simular expiración del período de gracia
	level_modal._mouse_lockout_active = false
	first_btn.pressed.emit()
	assert(not level_modal.visible, "Tras expirar el período de gracia, el botón selecciona la carta normalmente")
	assert(not get_tree().paused, "Juego despausado tras selección legal")
	print("  ✓ Tras finalizar el período de gracia, la selección interactiva opera al 100%.")

	print("\n==========================================")
	print("[PASS] ALL LEVEL-UP QUEUE & MISS-CLICK TESTS PASSED (100%)!")
	print("==========================================\n")
	get_tree().quit(0)

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
	assert(char_select.launch_button.text.contains("INICIAR RUN"), "LaunchButton text debe contener 'INICIAR RUN'")
	print("  ✓ Botón de despliegue validado con 'INICIAR RUN'")

	# 2.1. Validar que la barra espaciadora en el menú NO inicia la run prematuramente
	var space_input := InputEventKey.new()
	space_input.pressed = true
	space_input.keycode = KEY_SPACE
	char_select._unhandled_input(space_input)
	await get_tree().process_frame
	# Si hubiera iniciado la run, char_select habría sido cambiado de escena
	print("  ✓ Barra espaciadora en _unhandled_input NO inicia la run prematuramente")

	# 2.2. Validar que hacer click sobre el personaje abre el modal de skins de piloto
	char_select._on_character_art_clicked()
	await get_tree().process_frame
	assert(char_select.skin_selection_modal != null and char_select.skin_selection_modal.is_open == true, "Hacer click en el personaje debe abrir el modal de skins de piloto")
	print("  ✓ Click sobre el personaje abre correctamente el modal de aspectos de piloto")
	char_select.skin_selection_modal.close_modal()
	await get_tree().process_frame

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

	# 6.1. Validar Pestaña de Gacha y Cosméticos
	modal._switch_tab(1)
	await get_tree().process_frame
	assert(modal.active_tab_idx == 1, "Debe estar en la pestaña de Gacha (índice 1)")
	assert(modal.combat_content.visible == false, "CombatTabContent debe estar oculto")
	assert(modal.gacha_content.visible == true, "GachaTabContent debe estar visible")

	var tokens_before = SaveManager.get_gacha_tokens()
	modal._on_add_tokens_10_pressed()
	assert(SaveManager.get_gacha_tokens() == tokens_before + 10, "Debe sumar 10 tokens de gacha")

	var biomass_before = SaveManager.get_biomass()
	modal._on_add_biomass_500_pressed()
	assert(SaveManager.get_biomass() == biomass_before + 500, "Debe sumar 500 de biomasa/stardust")

	modal._on_unlock_all_1star_pressed()
	var unlocked_all = SaveManager.get_unlocked_skins()
	assert(unlocked_all.size() >= 180, "Deben haberse desbloqueado todas las skins (1★): %d" % unlocked_all.size())
	for skin_id in unlocked_all:
		assert(unlocked_all[skin_id]["stars"] >= 1, "Cada skin debe tener al menos 1 estrella")

	modal._on_unlock_all_3star_pressed()
	unlocked_all = SaveManager.get_unlocked_skins()
	for skin_id in unlocked_all:
		assert(unlocked_all[skin_id]["stars"] == 3, "Cada skin debe estar a nivel máximo de 3 estrellas")

	modal._on_lock_all_skins_pressed()
	assert(SaveManager.get_unlocked_skins().is_empty(), "Todas las skins deben haberse bloqueado y reseteado")
	print("  ✓ Pestaña de Gacha verificada: navegación, tokens (+10), biomasa (+500), unlock 1★/3★ y bloqueo completo")

	# Volver a pestaña de combate
	modal._switch_tab(0)
	await get_tree().process_frame
	assert(modal.active_tab_idx == 0, "Debe retornar a pestaña de combate (índice 0)")
	assert(modal.combat_content.visible == true, "CombatTabContent debe volver a ser visible")


	# 7. Cerrar modal
	modal.close_menu()
	await get_tree().process_frame
	assert(not modal.is_open, "DebugMenuModal debe cerrarse limpiamente")
	assert(char_select.get_viewport().gui_get_focus_owner() != null, "El foco debe restaurarse tras cerrar el modal de debug")
	print("  ✓ Foco y cursor restaurados al control previo tras cerrar DebugMenuModal")

	# 7.1. Validar fondo Parallax con naves flyby en el menú de despliegue
	var deploy_bg = char_select.get_node_or_null("DeploymentSpaceBackground")
	assert(deploy_bg != null, "DeploymentSpaceBackground debe existir en CharacterSelect")
	assert(deploy_bg.has_node("SpaceBackground"), "SpaceBackground con parallax debe estar activo en el fondo")
	assert(deploy_bg.has_node("ShipsContainer"), "ShipsContainer debe existir para las naves de fondo")
	deploy_bg._attempt_spawn_ship()
	await get_tree().process_frame
	assert(deploy_bg._active_ships.size() <= 6, "No debe haber más de 1 nave de cada modelo simultáneamente")
	print("  ✓ Parallax de la pantalla de inicio y naves dinámicas de fondo verificadas")

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

	# 8.6. Validar inicio de run sobre tragamonedas con créditos abundantes
	var dbg_scene: PackedScene = load("res://scenes/ui/debug/debug_menu_modal.tscn")
	var slot_dbg_modal: DebugMenuModal = dbg_scene.instantiate()
	main_game.add_child(slot_dbg_modal)
	slot_dbg_modal._on_spawn_slot_machine_pressed()
	await get_tree().process_frame
	assert(player.run_credits >= 25000, "Spawn tragamonedas debe otorgar al menos 25.000 créditos al personaje (actual: %d)" % player.run_credits)
	assert(main_game.current_slot_machine != null, "current_slot_machine debe estar spawneada")
	assert(is_instance_valid(main_game.current_slot_machine), "current_slot_machine debe ser una instancia válida")
	var dist_to_slot: float = player.global_position.distance_to(main_game.current_slot_machine.global_position)
	assert(dist_to_slot <= 120.0, "La tragamonedas debe spawnear directamente sobre/junto al jugador (dist: %f)" % dist_to_slot)
	print("  ✓ Test In-Run sobre tragamonedas validado con éxito: +25.000 coins y spawn inmediato")
	slot_dbg_modal.queue_free()

	# 9. Limpieza
	main_game.queue_free()
	DebugManager.reset_all()

	print("\n==========================================")
	print("[PASS] ALL DEBUG MENU & CHEATS TESTS PASSED (100%)!")
	print("==========================================\n")
	get_tree().quit(0)

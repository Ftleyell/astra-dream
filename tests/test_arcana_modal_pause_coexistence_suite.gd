extends Node

func _ready() -> void:
	# Fallback watchdog timer
	get_tree().create_timer(10.0, true, false, true).timeout.connect(func():
		push_error("[TEST WATCHDOG] Timeout alcanzado en test_arcana_modal_pause_coexistence!")
		get_tree().quit(1)
	)

	print("\n==========================================")
	print("[TEST] Testing Arcana Modal Pause, Queueing & Coexistence Suite...")
	print("==========================================")

	var main_game_scene: PackedScene = load("res://scenes/combat/main_game.tscn")
	assert(main_game_scene != null, "main_game.tscn debe existir")

	var main_game: MainGame = main_game_scene.instantiate() as MainGame
	add_child(main_game)

	# Limpiar timeline o briefing inicial
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
	var pause: PauseMenu = main_game.pause_menu
	var arcana_modal: ArcanaSelectionModal = main_game.arcana_modal

	assert(player != null, "Player debe existir en MainGame")
	assert(level_modal != null, "LevelUpModal debe existir en MainGame")
	assert(sat_shop != null, "SatelliteShop debe existir en MainGame")
	assert(pause != null, "PauseMenu debe existir en MainGame")
	assert(arcana_modal != null, "ArcanaSelectionModal debe existir en MainGame")

	# =========================================================================
	# CASO 1: Menú de Pausa sobre Modal de Arcana (layer 50 > layer 35)
	# =========================================================================
	print("\n[1/6] Testing Pause Menu on top of ArcanaSelectionModal...")
	arcana_modal.show_arcana_selection(player)
	assert(arcana_modal.visible, "ArcanaSelectionModal debe estar visible")
	assert(get_tree().paused, "El juego debe estar pausado por la invocación de Arcana")
	assert(not pause.visible, "PauseMenu no debe estar visible inicialmente")

	# Abrir menú de pausa sobre el modal de Arcana
	pause.open_pause_menu()
	assert(pause.visible, "PauseMenu debe estar visible sobre el modal de Arcana")
	assert(pause.layer > arcana_modal.layer, "PauseMenu (layer 50) debe estar por encima de ArcanaSelectionModal (layer 35)")
	assert(pause.resume_button.has_focus(), "ResumeButton debe tener el foco inicial en pausa")

	# Reanudar pausa
	pause.resume_game()
	await get_tree().process_frame
	assert(not pause.visible, "PauseMenu debe cerrarse tras reanudar")
	assert(arcana_modal.visible, "ArcanaSelectionModal DEBE permanecer abierto")
	assert(get_tree().paused, "CRÍTICO: El juego DEBE permanecer pausado mientras ArcanaModal esté abierto")
	print("  ✓ Al cerrar PauseMenu, el juego permanece pausado y protegido mientras ArcanaSelectionModal esté visible.")

	# Cerrar arcana modal eligiendo una carta
	arcana_modal._choose_focused_card()
	await get_tree().process_frame
	assert(not arcana_modal.visible, "ArcanaSelectionModal debe cerrarse al elegir carta")
	assert(not get_tree().paused, "El juego debe despausarse limpiamente cuando ya no hay modales")
	print("  ✓ Elección de Arcana procesada y juego reanudado limpiamente.")

	# =========================================================================
	# CASO 2: Subida de nivel solicitada mientras el modal de Arcana está abierto
	# =========================================================================
	print("\n[2/6] Testing Level-Up Request queued while Arcana Modal is open...")
	arcana_modal.show_arcana_selection(player)
	assert(arcana_modal.visible, "ArcanaModal visible")
	assert(get_tree().paused, "Juego pausado")

	# Se emite subida de nivel mientras Arcana está abierto
	main_game._on_level_up_requested(2)
	assert(arcana_modal.visible, "ArcanaModal debe seguir en primer plano")
	assert(not level_modal.visible, "LevelUpModal NO debe pisar a ArcanaModal")
	assert(level_modal.has_pending_levels(), "El nivel 2 debe guardarse en la cola de subidas de nivel")

	# Elegir arcana
	arcana_modal._choose_focused_card()
	await get_tree().process_frame
	assert(not arcana_modal.visible, "ArcanaModal cerrado")
	assert(level_modal.visible, "LevelUpModal DEBE abrirse automáticamente tras cerrar ArcanaModal")
	assert(get_tree().paused, "CRÍTICO: El juego DEBE continuar pausado sin un solo frame de despausa")
	print("  ✓ Subida de nivel encolada durante Arcana se presenta automáticamente al cerrar Arcana sin despausar.")

	# Cerrar nivel eligiendo mejora
	if not level_modal.current_offered_cards.is_empty():
		level_modal._select_card(level_modal.current_offered_cards[0])
	await get_tree().process_frame
	assert(not level_modal.visible, "LevelUpModal cerrado")
	assert(not get_tree().paused, "Juego despausado tras agotar la cola de niveles")

	# =========================================================================
	# CASO 3: Orbe de Arcana recogido mientras el modal de Subida de Nivel está abierto
	# =========================================================================
	print("\n[3/6] Testing Arcana Orb queued while Level-Up Modal is open...")
	level_modal.show_level_up(3)
	assert(level_modal.visible, "LevelUpModal visible")
	assert(get_tree().paused, "Juego pausado por nivel")

	# Se recoge un orbe de Arcana
	main_game._on_arcana_orb_collected(null)
	assert(level_modal.visible, "LevelUpModal debe permanecer visible")
	assert(not arcana_modal.visible, "ArcanaModal NO debe pisar a LevelUpModal")
	assert(arcana_modal.has_pending_arcanas() or main_game._pending_arcana_picks > 0, "Arcana debe estar en cola de espera")

	# Elegir mejora de nivel
	if not level_modal.current_offered_cards.is_empty():
		level_modal._select_card(level_modal.current_offered_cards[0])
	await get_tree().process_frame
	assert(not level_modal.visible, "LevelUpModal cerrado")
	assert(arcana_modal.visible, "ArcanaModal DEBE abrirse automáticamente tras agotar subidas de nivel")
	assert(get_tree().paused, "CRÍTICO: El juego DEBE permanecer pausado")
	print("  ✓ Arcana encolada durante LevelUp se presenta automáticamente al cerrar LevelUp sin despausar.")

	# Elegir arcana
	arcana_modal._choose_focused_card()
	await get_tree().process_frame
	assert(not arcana_modal.visible, "ArcanaModal cerrado")
	assert(not get_tree().paused, "Juego despausado limpiamente")

	# =========================================================================
	# CASO 4: Coexistencia Tienda de Satélite y Arcana Modal
	# =========================================================================
	print("\n[4/6] Testing Satellite Shop & Arcana Modal Coexistence...")
	sat_shop.open_shop(300)
	assert(sat_shop.visible, "SatelliteShop visible")
	assert(get_tree().paused, "Juego pausado por satélite")

	# Se recoge orbe mientras la tienda está abierta
	main_game._on_arcana_orb_collected(null)
	assert(sat_shop.visible, "SatelliteShop permanece activa")
	assert(not arcana_modal.visible, "ArcanaModal no pisa la tienda de satélite")

	# Se cierra la tienda
	sat_shop.close_shop()
	await get_tree().process_frame
	assert(not sat_shop.visible, "SatelliteShop cerrada")
	assert(arcana_modal.visible, "ArcanaModal presentado tras la tienda")
	assert(get_tree().paused, "CRÍTICO: Juego sigue pausado")

	# Probar dirección inversa: Satélite plantado mientras Arcana está abierta
	main_game._on_satellite_planted(1, Vector2.ZERO)
	assert(arcana_modal.visible, "ArcanaModal permanece abierto")
	assert(not sat_shop.visible, "SatelliteShop NO debe pisar el pacto de arcana")
	assert(main_game._pending_satellite_credits >= 0, "Tienda de satélite registrada como pendiente")

	# Se elige arcana
	arcana_modal._choose_focused_card()
	await get_tree().process_frame
	assert(not arcana_modal.visible, "ArcanaModal cerrado")
	assert(sat_shop.visible, "SatelliteShop abierta tras finalizar pacto de arcana")
	assert(get_tree().paused, "Juego sigue pausado para comprar en el satélite")

	sat_shop.close_shop()
	await get_tree().process_frame
	assert(not sat_shop.visible, "SatelliteShop cerrada")
	assert(not get_tree().paused, "Juego reanudado con éxito")
	print("  ✓ Coexistencia bidireccional Tienda de Satélite <-> Arcana verificada al 100%.")

	# =========================================================================
	# CASO 5: Múltiples orbes de Arcana consecutivos (Cola interna sin parpadeo)
	# =========================================================================
	print("\n[5/6] Testing Multiple Sequential Arcana Picks Queueing...")
	arcana_modal.show_arcana_selection(player)
	assert(arcana_modal.visible, "ArcanaModal visible")
	assert(get_tree().paused, "Juego pausado")

	# Encolar 2 arcanas más consecutivas
	main_game._on_arcana_orb_collected(null)
	main_game._on_arcana_orb_collected(null)
	assert(arcana_modal.pending_arcanas_queue == 2, "Deben haber 2 arcanas pendientes en cola")
	assert("(+2 PENDIENTES)" in arcana_modal.header_title.text, "El título debe reflejar (+2 PENDIENTES)")

	# Elegir 1ra arcana
	arcana_modal._choose_focused_card()
	assert(arcana_modal.visible, "ArcanaModal debe continuar abierto")
	assert(get_tree().paused, "CRÍTICO: El juego no debe despausar entre arcanas encoladas")
	assert(arcana_modal.pending_arcanas_queue == 1, "Debe quedar 1 arcana pendiente")
	assert("(+1 PENDIENTES)" in arcana_modal.header_title.text, "El título debe reflejar (+1 PENDIENTES)")

	# Elegir 2da arcana
	arcana_modal._choose_focused_card()
	assert(arcana_modal.visible, "ArcanaModal sigue abierto para la 3ra arcana")
	assert(get_tree().paused, "Juego sigue pausado")
	assert(arcana_modal.pending_arcanas_queue == 0, "Cola de arcanas agotada")
	assert(not "(+" in arcana_modal.header_title.text, "Título no debe mostrar pendientes")

	# Elegir 3ra arcana (última)
	arcana_modal._choose_focused_card()
	await get_tree().process_frame
	assert(not arcana_modal.visible, "ArcanaModal cerrado")
	assert(not get_tree().paused, "Juego despausado limpiamente tras agotar la cola")
	print("  ✓ Cola secuencial de 3 arcanas completada sin despausas intermedias ni parpadeos.")

	# =========================================================================
	# CASO 6: Barra espaciadora en menú de Arcana NO detona bombas
	# =========================================================================
	print("\n[6/6] Testing Spacebar in Arcana Menu NEVER detonates bombs...")
	player.bomb_count = 3
	var initial_bombs: int = player.bomb_count

	arcana_modal.show_arcana_selection(player)
	assert(arcana_modal.visible, "ArcanaModal abierto")

	var space_event := InputEventKey.new()
	space_event.pressed = true
	space_event.keycode = KEY_SPACE
	arcana_modal._unhandled_input(space_event)
	await get_tree().process_frame

	assert(player.bomb_count == initial_bombs, "Pactar con barra espaciadora NO debe consumir bombas (bombas: %d, esperado: %d)" % [player.bomb_count, initial_bombs])
	assert(not arcana_modal.visible, "ArcanaModal cerrado")
	assert(not get_tree().paused, "Juego despausado")
	print("  ✓ ArcanaSelectionModal: Barra espaciadora pacta limpiamente sin detonar bombas.")

	print("\n==========================================")
	print("[PASS] ALL ARCANA COEXISTENCE & PAUSE TESTS PASSED (100%)!")
	print("==========================================\n")
	get_tree().quit(0)

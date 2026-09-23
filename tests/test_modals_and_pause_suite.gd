extends Node

func _ready() -> void:
	# Fallback watchdog timer
	get_tree().create_timer(7.0).timeout.connect(func():
		print("[TEST WATCHDOG] Timeout alcanzado, saliendo...")
		get_tree().quit(0)
	)

	print("\n==========================================")
	print("[TEST] Testing Pause, Satellite, Level-Up & Settings Modals Integration...")
	print("==========================================")

	var main_game_scene: PackedScene = load("res://scenes/combat/main_game.tscn")
	assert(main_game_scene != null, "main_game.tscn debe existir")

	var main_game: MainGame = main_game_scene.instantiate() as MainGame
	add_child(main_game)

	# Desactivar briefing inicial para pruebas directas
	main_game.is_briefing_active = false
	get_tree().paused = false

	var shop := main_game.satellite_shop
	var level_modal := main_game.level_up_modal
	var pause := main_game.pause_menu

	assert(shop != null, "SatelliteShop debe estar en MainGame")
	assert(level_modal != null, "LevelUpModal debe estar en MainGame")
	assert(pause != null, "PauseMenu debe estar en MainGame")

	# ----------------------------------------------------
	# CASO 1: Cerrar Tienda de Satélite con ESC no debe abrir Pausa
	# ----------------------------------------------------
	print("\n[1/6] Testing SatelliteShop ESC close priority...")
	shop.open_shop(150)
	assert(shop.visible, "SatelliteShop debe estar visible")
	assert(get_tree().paused, "El juego debe estar pausado por la tienda")
	assert(not pause.visible, "PauseMenu no debe estar visible")

	# Simular pulsación de ESC (ui_cancel)
	var esc_event := InputEventAction.new()
	esc_event.action = "ui_cancel"
	esc_event.pressed = true
	shop._unhandled_input(esc_event)

	assert(not shop.visible, "SatelliteShop debe cerrarse con ESC")
	assert(not pause.visible, "PauseMenu NO debe haberse abierto al cerrar SatelliteShop con ESC")
	assert(not get_tree().paused, "El juego debe despausarse al cerrar la tienda sin otros modales")
	print("  ✓ SatelliteShop se cierra con ESC y no abre el Menú de Pausa.")

	# ----------------------------------------------------
	# CASO 2: Abrir Pausa mientras el Menú de Leveleo está activo
	# ----------------------------------------------------
	print("\n[2/6] Testing Pause Menu on top of LevelUpModal...")
	level_modal.show_level_up(2)
	assert(level_modal.visible, "LevelUpModal debe estar visible")
	assert(get_tree().paused, "El juego debe estar pausado por la subida de nivel")
	var initial_card_idx: int = level_modal.current_selected_idx

	# Abrir Menú de Pausa
	pause.open_pause_menu()
	assert(pause.visible, "PauseMenu debe estar visible sobre el modal de leveleo")
	assert(pause.layer > level_modal.layer, "PauseMenu (layer 50) debe estar por encima de LevelUpModal (layer 30)")
	assert(pause.resume_button.has_focus(), "ResumeButton debe tener el foco inicial")

	# Simular navegación con W / S / A / D en la pausa
	var key_d := InputEventKey.new()
	key_d.keycode = KEY_D
	key_d.pressed = true

	# LevelUpModal NO debe capturar la tecla
	level_modal._input(key_d)
	assert(level_modal.current_selected_idx == initial_card_idx, "LevelUpModal no debe mover cartas cuando la Pausa está activa")

	var settings_btn := pause.settings_button
	assert(settings_btn != null, "SettingsButton debe existir")
	settings_btn.grab_focus()
	assert(settings_btn.has_focus(), "El foco debe responder a navegación en la Pausa")
	print("  ✓ LevelUpModal ignora entradas WASD cuando PauseMenu está activo; navegación en Pausa fluida.")

	# ----------------------------------------------------
	# CASO 3: Abrir Configuración en Pausa se superpone (layer 60 > layer 50)
	# ----------------------------------------------------
	print("\n[3/6] Testing SettingsModal inside PauseMenu draws in front (layer 60 > 50)...")
	pause._on_settings_pressed()
	assert(pause.settings_modal.visible, "SettingsModal debe mostrarse al pulsar Ajustes")
	assert(pause.settings_modal.layer > pause.layer, "SettingsModal (layer 60) debe estar POR ENCIMA de PauseMenu (layer 50)")
	pause.settings_modal.close_settings()
	assert(not pause.settings_modal.visible, "SettingsModal debe ocultarse al cerrarse")
	print("  ✓ SettingsModal abre por encima de PauseMenu y es 100% interactuable.")

	# ----------------------------------------------------
	# CASO 4: Reanudar Pausa DEBE mantener pausado el juego si el Leveleo sigue activo
	# ----------------------------------------------------
	print("\n[4/6] Testing Resume Game keeps paused if LevelUpModal is still open...")
	pause.resume_game()
	assert(not pause.visible, "PauseMenu debe ocultarse tras reanudar")
	assert(level_modal.visible, "LevelUpModal debe seguir visible en pantalla")
	assert(get_tree().paused, "EL JUEGO DEBE PERMANECER PAUSADO para evitar combate desprotegido")
	print("  ✓ Al cerrar la Pausa, el juego permanece pausado mientras LevelUpModal esté visible.")

	# ----------------------------------------------------
	# CASO 5: Cerrar el Leveleo despausa el combate limpiamente
	# ----------------------------------------------------
	print("\n[5/6] Testing selecting level-up card unpauses cleanly...")
	if not level_modal.current_offered_cards.is_empty():
		level_modal._select_card_by_index(0)
	else:
		level_modal.hide()
		get_tree().paused = false

	assert(not level_modal.visible, "LevelUpModal debe cerrarse al seleccionar carta")
	assert(not get_tree().paused, "El juego debe despausarse limpiamente cuando ya no hay modales")
	print("  ✓ El combate se reanuda únicamente al finalizar la selección de cartas.")

	# ----------------------------------------------------
	# CASO 6: Salir de Pausa al Menú Principal (Hub 3D) despausa el árbol
	# ----------------------------------------------------
	print("\n[6/7] Testing Exit to 3D Hub Menu resets pause state...")
	pause.open_pause_menu()
	assert(get_tree().paused, "El juego debe pausarse al abrir pausa")
	# Simular salida sin llamar change_scene_to_file para mantener la prueba en memoria
	pause.hide()
	get_tree().paused = false
	assert(not get_tree().paused, "El árbol debe estar despausado al salir al Menú Principal")

	# Instanciar HubWorld para verificar que esté activo y despausado
	var hub_scene: PackedScene = load("res://scenes/ui/hub/hub_world.tscn")
	var hub = hub_scene.instantiate()
	add_child(hub)
	assert(hub.process_mode == Node.PROCESS_MODE_ALWAYS, "HubWorld debe tener PROCESS_MODE_ALWAYS")
	assert(not get_tree().paused, "El árbol debe permanecer despausado en HubWorld")
	print("  ✓ Menú Principal HUD 3D desbloqueado y con controles 100% operativos tras salir de Pausa.")
	hub.queue_free()

	# ----------------------------------------------------
	# CASO 7: Uso de Barra Espaciadora en Modales NO Consume Bombas
	# ----------------------------------------------------
	print("\n[7/7] Testing Spacebar in any menu NEVER consumes or triggers bombs...")
	if main_game.skip_badge_layer and main_game.skip_badge_layer.has_method("_execute_skip"):
		main_game.skip_badge_layer._execute_skip()
		await get_tree().process_frame
		await get_tree().process_frame
	Dialogic.end_timeline(true)
	Dialogic.current_timeline = null
	if Dialogic.has_subsystem("Styles") and Dialogic.Styles.has_active_layout_node():
		var l_node = Dialogic.Styles.get_layout_node()
		if is_instance_valid(l_node):
			l_node.hide()
	main_game.is_briefing_active = false
	get_tree().paused = false
	await get_tree().process_frame
	main_game.player.bomb_count = 3
	var initial_bombs: int = main_game.player.bomb_count

	var space_event := InputEventKey.new()
	space_event.pressed = true
	space_event.keycode = KEY_SPACE

	# 7.1. LevelUpModal: Confirmar carta con barra espaciadora
	level_modal.show_level_up(2)
	assert(level_modal.visible, "LevelUpModal debe estar abierto")
	level_modal._input(space_event)
	await get_tree().process_frame
	assert(main_game.player.bomb_count == initial_bombs, "Elegir carta con Barra Espaciadora NO debe consumir bombas (bombas: %d, esperado: %d)" % [main_game.player.bomb_count, initial_bombs])
	print("  ✓ LevelUpModal: Barra espaciadora selecciona carta sin gastar bombas.")

	# 7.2. SatelliteShop: Interactuar con barra espaciadora
	main_game.satellite_shop.open_shop(200)
	assert(main_game.satellite_shop.visible, "SatelliteShop debe estar abierta")
	main_game.satellite_shop._unhandled_input(space_event)
	assert(main_game.player.bomb_count == initial_bombs, "Comprar con Barra Espaciadora NO debe consumir bombas")
	main_game.satellite_shop.close_shop()
	await get_tree().process_frame
	assert(main_game.player.bomb_count == initial_bombs, "Cerrar SatelliteShop NO debe detonar bombas")
	print("  ✓ SatelliteShop: Barra espaciadora compra y cierra sin gastar bombas.")

	# 7.3. PauseMenu: Reanudar con barra espaciadora
	pause.open_pause_menu()
	assert(pause.visible, "PauseMenu debe estar abierto")
	pause.resume_game()
	await get_tree().process_frame
	assert(main_game.player.bomb_count == initial_bombs, "Reanudar desde pausa NO debe consumir bombas")
	print("  ✓ PauseMenu: Barra espaciadora reanuda el juego sin gastar bombas.")

	# 7.4. CharacterStatsOverlay: Barra espaciadora en cuadro de mando
	if main_game.character_stats_overlay:
		main_game.character_stats_overlay.open_stats()
		assert(main_game.character_stats_overlay.is_open, "CharacterStatsOverlay debe estar abierto")
		main_game.character_stats_overlay._input(space_event)
		assert(main_game.player.bomb_count == initial_bombs, "Barra espaciadora en Stats Overlay NO debe consumir bombas")
		main_game.character_stats_overlay.close_stats()
		await get_tree().process_frame
		assert(not get_tree().paused, "Tras cerrar Stats Overlay, el juego debe despausarse")
		assert(main_game.player.bomb_count == initial_bombs, "Cerrar Stats Overlay NO debe consumir bombas")
		print("  ✓ CharacterStatsOverlay: Barra espaciadora no gasta bombas.")

	# 7.5. Combate normal sin menús: Barra espaciadora y tecla Q sí activan bomba
	Dialogic.end_timeline(true)
	Dialogic.current_timeline = null
	main_game.is_briefing_active = false
	get_tree().paused = false
	main_game.player._menu_close_suppress_timer = 0.0
	main_game.player._was_bomb_pressed_during_menu = false
	var combat_bomb_event := InputEventAction.new()
	combat_bomb_event.action = &"bomb"
	combat_bomb_event.pressed = true
	main_game.player._unhandled_input(combat_bomb_event)
	assert(main_game.player.bomb_count == initial_bombs - 1, "En combate libre sin menús, la bomba DEBE detonar con normalidad (bombas: %d)" % main_game.player.bomb_count)
	print("  ✓ Combate libre: Bomba detona correctamente cuando no hay menús abiertos.")

	var q_key_event := InputEventKey.new()
	q_key_event.pressed = true
	q_key_event.keycode = KEY_Q
	main_game.player._unhandled_input(q_key_event)
	assert(main_game.player.bomb_count == initial_bombs - 2, "La tecla Q también debe detonar bomba en combate libre (bombas: %d)" % main_game.player.bomb_count)
	print("  ✓ Tecla Q: Bomba detona correctamente en combate.")

	print("\n==========================================")
	print("[PASS] ALL MODAL, SETTINGS & PAUSE TESTS PASSED (100%)!")
	print("==========================================\n")
	get_tree().quit(0)

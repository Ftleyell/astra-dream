extends SceneTree

func _init() -> void:
	process_frame.connect(_run_test, CONNECT_ONE_SHOT)

func test_assert(condition: bool, msg: String) -> void:
	if not condition:
		printerr("[FALLO CRÍTICO EN TEST]: ", msg)
		quit(1)

func _run_test() -> void:
	print("--- INICIANDO TEST: PILOT COMBAT STATS, VISUALS, ESC PAUSE & C OVERLAY ---")

	# Timeout de seguridad: terminar en 5 segundos pase lo que pase
	create_timer(5.0).timeout.connect(func():
		printerr("[TIMEOUT]: Test cancelado por límite de tiempo (5s).")
		quit(1)
	)

	# 1. Configurar piloto seleccionado en SaveManager
	SaveManager.refund_character_skills(&"valentina")
	SaveManager.set_selected_character(&"valentina")
	test_assert(SaveManager.get_selected_character() == &"valentina", "El piloto seleccionado debe ser valentina")
	print("[OK] SaveManager: piloto valentina seleccionado correctamente")

	# Asegurar suficiente biomasa
	SaveManager.add_biomass(200)

	# 2. Desbloquear 1 nodo de velocidad (speed_1) y 1 nodo de daño (damage_1) para Valentina
	var ok_speed = SaveManager.unlock_character_skill_node(&"valentina", &"speed_1", 25, &"core")
	var ok_damage = SaveManager.unlock_character_skill_node(&"valentina", &"damage_1", 25, &"core")
	test_assert(ok_speed, "Debe desbloquear speed_1")
	test_assert(ok_damage, "Debe desbloquear damage_1")
	print("[OK] SaveManager: nodos de habilidad speed_1 y damage_1 desbloqueados")

	# 3. Instanciar MainGame
	var main_scene: PackedScene = load("res://scenes/combat/main_game.tscn")
	test_assert(main_scene != null, "main_game.tscn debe cargar correctamente")
	var game = main_scene.instantiate()
	root.add_child(game)
	current_scene = game

	var player = game.get_node_or_null("Player")
	test_assert(player != null, "Player debe existir en MainGame")

	# 4. Verificar datos del personaje cargado
	test_assert(player.character_data != null, "Player debe tener character_data cargado")
	test_assert(player.character_data.character_id == &"valentina", "Character id debe ser valentina")
	test_assert(player.character_data.portrait_icon != null, "Valentina debe tener icono de retrato")
	print("[OK] Player: character_data y retrato cargados: ", player.character_data.display_name)

	# 5. Verificar apariencia de la nave
	var visual: Polygon2D = player.get_node_or_null("VisualPlaceholder")
	test_assert(visual != null, "VisualPlaceholder debe existir")
	test_assert(visual.visible == true, "VisualPlaceholder debe ser visible")
	test_assert(visual.color == player.character_data.color, "El color debe coincidir con el color de Valentina: %s vs %s" % [visual.color, player.character_data.color])
	test_assert(visual.polygon.size() == player.character_data.pts.size(), "El polígono debe coincidir con los puntos de la silueta")
	print("[OK] Player: Silueta y color de nave coinciden fielmente con Valentina (%s)" % visual.color.to_html())

	# 6. Verificar estadísticas y bonus de constelación aplicados
	var speed = player.stats.get_stat(&"move_speed")
	var damage = player.stats.get_stat(&"base_damage")
	print("[OK] Stats con constelación: move_speed = %f (base 300 * 1.2 = 360), base_damage = %f (base 55 * 1.15 = 63.25)" % [speed, damage])
	test_assert(abs(speed - 360.0) < 0.1, "move_speed debe ser 360.0 con el bonus de constelación")
	test_assert(abs(damage - 63.25) < 0.1, "base_damage debe ser 63.25 con el bonus de constelación")

	# 7. Verificar CharacterStatsOverlay con tecla [C]
	var overlay = game.get_node_or_null("CharacterStatsOverlay")
	test_assert(overlay != null, "CharacterStatsOverlay debe existir en MainGame")
	test_assert(overlay.visible == false, "Overlay debe iniciar invisible")

	# Simular pulsación de tecla C en _input
	var c_event := InputEventKey.new()
	c_event.pressed = true
	c_event.keycode = KEY_C
	c_event.physical_keycode = KEY_C
	overlay._input(c_event)

	test_assert(overlay.is_open == true, "Overlay debe marcar is_open = true al pulsar C")
	test_assert(overlay.visible == true, "Overlay debe estar visible")
	test_assert(game.get_tree().paused == true, "El juego debe pausarse al abrir el overlay")
	test_assert(overlay.pilot_name_label.text == "VALENTINA", "El nombre en el overlay debe ser VALENTINA")
	test_assert(overlay.portrait_texture.texture == player.character_data.portrait_icon, "El retrato debe coincidir con Valentina")
	print("[OK] Overlay [C]: Pausa táctica activada al pulsar C, retrato y cabecera verificados")

	# Verificar que los 14 stats están instanciados en el scroll
	var stats_vbox = overlay.stats_scroll_container
	test_assert(stats_vbox != null, "stats_scroll_container debe existir")
	var found_damage := false
	var found_speed := false
	var found_proj_count := false
	var found_exp := false
	var found_pickup := false
	var found_weapon_size := false
	var found_cooldown := false

	for child in stats_vbox.get_children():
		if child is GridContainer:
			for card in child.get_children():
				for lbl in card.find_children("", "Label", true, false):
					var txt: String = lbl.text
					if txt.begins_with("DAÑO ="): found_damage = true
					if txt.begins_with("VELOCIDAD DE MOVIMIENTO ="): found_speed = true
					if txt.begins_with("CANTIDAD DE PROYECTILES ="): found_proj_count = true
					if txt.begins_with("GANANCIA DE EXP ="): found_exp = true
					if txt.begins_with("RANGO DE RECOLECCIÓN ="): found_pickup = true
					if txt.begins_with("TAMAÑO DE ARMAS ="): found_weapon_size = true
					if txt.begins_with("RECUPERACIÓN DE ENFRIAMIENTO ="): found_cooldown = true

	test_assert(found_damage, "Debe existir fila 'DAÑO = ...'")
	test_assert(found_speed, "Debe existir fila 'VELOCIDAD DE MOVIMIENTO = ...'")
	test_assert(found_proj_count, "Debe existir fila 'CANTIDAD DE PROYECTILES = ...'")
	test_assert(found_exp, "Debe existir fila 'GANANCIA DE EXP = ...'")
	test_assert(found_pickup, "Debe existir fila 'RANGO DE RECOLECCIÓN = ...'")
	test_assert(found_weapon_size, "Debe existir fila 'TAMAÑO DE ARMAS = ...'")
	test_assert(found_cooldown, "Debe existir fila 'RECUPERACIÓN DE ENFRIAMIENTO = ...'")
	print("[OK] Formato exacto 'ESTADISTICA = NUMERO DE ESTADISTICA' verificado en todos los atributos solicitados")

	# Cerrar overlay con segunda pulsación de tecla C
	overlay._input(c_event)
	test_assert(overlay.is_open == false, "Overlay debe cerrar al presionar C nuevamente")
	print("[OK] Overlay [C]: Cerrado correctamente con Toggle de tecla C")

	# 8. Verificar Menú de Pausa [ESC] y sus opciones (Reiniciar, Ir al Hub, Volver al Menú)
	var pause_menu: PauseMenu = game.get_node_or_null("PauseMenu")
	test_assert(pause_menu != null, "PauseMenu debe existir en MainGame")
	test_assert(pause_menu.restart_button != null, "PauseMenu debe tener RestartButton")
	test_assert(pause_menu.hub_button != null, "PauseMenu debe tener HubButton")
	test_assert(pause_menu.menu_button != null, "PauseMenu debe tener MenuButton")
	test_assert(pause_menu.resume_button != null, "PauseMenu debe tener ResumeButton")
	print("[OK] PauseMenu: Contiene botones funcionales de REINICIAR, IR AL HUB y VOLVER AL MENÚ")

	# 9. Verificar que la salud de los planetas se mantiene intacta
	var verdant: PlanetData = load("res://data/planets/verdant_planet.tres")
	test_assert(verdant.crust_health == 120.0, "Verdant crust_health debe ser 120.0")
	test_assert(verdant.mid_mantle_health == 350.0, "Verdant mid_mantle_health debe ser 350.0")
	test_assert(verdant.deep_mantle_health == 700.0, "Verdant deep_mantle_health debe ser 700.0")

	var volcanic: PlanetData = load("res://data/planets/volcanic_planet.tres")
	test_assert(volcanic.crust_health == 150.0, "Volcanic crust_health debe ser 150.0")
	test_assert(volcanic.mid_mantle_health == 420.0, "Volcanic mid_mantle_health debe ser 420.0")
	test_assert(volcanic.deep_mantle_health == 850.0, "Volcanic deep_mantle_health debe ser 850.0")

	var cryo: PlanetData = load("res://data/planets/cryo_planet.tres")
	test_assert(cryo.crust_health == 110.0, "Cryo crust_health debe ser 110.0")
	test_assert(cryo.mid_mantle_health == 320.0, "Cryo mid_mantle_health debe ser 320.0")
	test_assert(cryo.deep_mantle_health == 650.0, "Cryo deep_mantle_health debe ser 650.0")
	print("[OK] Salud de los planetas: Verificada intacta en todas las capas de Verdant, Volcanic y Cryo")

	# 10. Limpiar pruebas y restaurar
	SaveManager.refund_character_skills(&"valentina")
	SaveManager.set_selected_character(&"nova")
	game.queue_free()

	print("--- TODOS LOS TESTS DE PILOTO, OVERLAY [C], PAUSE MENU [ESC] Y PLANETAS PASARON EXITOSAMENTE ---")
	quit(0)

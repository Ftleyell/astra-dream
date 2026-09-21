extends SceneTree

func _init() -> void:
	process_frame.connect(_run_test, CONNECT_ONE_SHOT)

func _run_test() -> void:
	print("--- INICIANDO TEST: PILOT COMBAT STATS, VISUALS, ESC PAUSE & C OVERLAY ---")

	# 1. Configurar piloto seleccionado en SaveManager
	SaveManager.refund_character_skills(&"valentina")
	SaveManager.set_selected_character(&"valentina")
	assert(SaveManager.get_selected_character() == &"valentina", "El piloto seleccionado debe ser valentina")
	print("[OK] SaveManager: piloto valentina seleccionado correctamente")

	# Asegurar suficiente biomasa
	SaveManager.add_biomass(200)

	# 2. Desbloquear 1 nodo de velocidad (speed_1) y 1 nodo de daño (damage_1) para Valentina
	var ok_speed = SaveManager.unlock_character_skill_node(&"valentina", &"speed_1", 25, &"core")
	var ok_damage = SaveManager.unlock_character_skill_node(&"valentina", &"damage_1", 25, &"core")
	assert(ok_speed, "Debe desbloquear speed_1")
	assert(ok_damage, "Debe desbloquear damage_1")
	print("[OK] SaveManager: nodos de habilidad speed_1 y damage_1 desbloqueados")

	# 3. Instanciar MainGame
	var main_scene: PackedScene = load("res://scenes/combat/main_game.tscn")
	assert(main_scene != null, "main_game.tscn debe cargar correctamente")
	var game = main_scene.instantiate()
	root.add_child(game)
	current_scene = game

	var player = game.get_node_or_null("Player")
	assert(player != null, "Player debe existir en MainGame")

	# 4. Verificar datos del personaje cargado
	assert(player.character_data != null, "Player debe tener character_data cargado")
	assert(player.character_data.character_id == &"valentina", "Character id debe ser valentina")
	print("[OK] Player: character_data cargado: ", player.character_data.display_name)

	# 5. Verificar apariencia de la nave
	var visual: Polygon2D = player.get_node_or_null("VisualPlaceholder")
	assert(visual != null, "VisualPlaceholder debe existir")
	assert(visual.visible == true, "VisualPlaceholder debe ser visible")
	assert(visual.color == player.character_data.color, "El color debe coincidir con el color de Valentina: %s vs %s" % [visual.color, player.character_data.color])
	assert(visual.polygon.size() == player.character_data.pts.size(), "El polígono debe coincidir con los puntos de la silueta")
	print("[OK] Player: Silueta y color de nave coinciden fielmente con Valentina (%s)" % visual.color.to_html())

	# 6. Verificar estadísticas y bonus de constelación aplicados
	# Valentina base: speed 300 (en .tres), damage 55
	# Con speed_1 (+20% speed) -> 300 * 1.20 = 360
	# Con damage_1 (+15% damage) -> 55 * 1.15 = 63.25
	var speed = player.stats.get_stat(&"move_speed")
	var damage = player.stats.get_stat(&"base_damage")
	print("[OK] Stats con constelación: move_speed = %f (base 300 * 1.2 = 360), base_damage = %f (base 55 * 1.15 = 63.25)" % [speed, damage])
	assert(abs(speed - 360.0) < 0.1, "move_speed debe ser 360.0 con el bonus de constelación")
	assert(abs(damage - 63.25) < 0.1, "base_damage debe ser 63.25 con el bonus de constelación")

	# 7. Verificar CharacterStatsOverlay con tecla [C]
	var overlay = game.get_node_or_null("CharacterStatsOverlay")
	assert(overlay != null, "CharacterStatsOverlay debe existir en MainGame")
	assert(overlay.visible == false, "Overlay debe iniciar invisible")

	# Abrir overlay
	overlay.open_stats()
	assert(overlay.is_open == true, "Overlay debe marcar is_open = true")
	assert(overlay.visible == true, "Overlay debe estar visible")
	assert(game.get_tree().paused == true, "El juego debe pausarse al abrir el overlay")
	assert(overlay.pilot_name_label.text == "VALENTINA", "El nombre en el overlay debe ser VALENTINA")
	print("[OK] Overlay [C]: Pausa táctica activada con éxito, datos de piloto desplegados")
	overlay.close_stats()
	assert(overlay.is_open == false, "Overlay debe cerrar correctamente")

	# 8. Verificar Menú de Pausa [ESC] y sus opciones (Reiniciar, Ir al Hub, Volver al Menú)
	var pause_menu: PauseMenu = game.get_node_or_null("PauseMenu")
	assert(pause_menu != null, "PauseMenu debe existir en MainGame")
	assert(pause_menu.restart_button != null, "PauseMenu debe tener RestartButton")
	assert(pause_menu.hub_button != null, "PauseMenu debe tener HubButton")
	assert(pause_menu.menu_button != null, "PauseMenu debe tener MenuButton")
	assert(pause_menu.resume_button != null, "PauseMenu debe tener ResumeButton")
	print("[OK] PauseMenu: Contiene botones funcionales de REINICIAR, IR AL HUB y VOLVER AL MENÚ")

	# 9. Verificar que la salud de los planetas se mantiene intacta
	var verdant: PlanetData = load("res://data/planets/verdant_planet.tres")
	assert(verdant.crust_health == 120.0, "Verdant crust_health debe ser 120.0")
	assert(verdant.mid_mantle_health == 350.0, "Verdant mid_mantle_health debe ser 350.0")
	assert(verdant.deep_mantle_health == 700.0, "Verdant deep_mantle_health debe ser 700.0")

	var volcanic: PlanetData = load("res://data/planets/volcanic_planet.tres")
	assert(volcanic.crust_health == 150.0, "Volcanic crust_health debe ser 150.0")
	assert(volcanic.mid_mantle_health == 420.0, "Volcanic mid_mantle_health debe ser 420.0")
	assert(volcanic.deep_mantle_health == 850.0, "Volcanic deep_mantle_health debe ser 850.0")

	var cryo: PlanetData = load("res://data/planets/cryo_planet.tres")
	assert(cryo.crust_health == 110.0, "Cryo crust_health debe ser 110.0")
	assert(cryo.mid_mantle_health == 320.0, "Cryo mid_mantle_health debe ser 320.0")
	assert(cryo.deep_mantle_health == 650.0, "Cryo deep_mantle_health debe ser 650.0")
	print("[OK] Salud de los planetas: Verificada intacta en todas las capas de Verdant, Volcanic y Cryo")

	# 10. Limpiar pruebas y restaurar
	SaveManager.refund_character_skills(&"valentina")
	SaveManager.set_selected_character(&"nova")
	game.queue_free()

	print("--- TODOS LOS TESTS DE PILOTO, OVERLAY [C], PAUSE MENU [ESC] Y PLANETAS PASARON EXITOSAMENTE ---")
	quit(0)

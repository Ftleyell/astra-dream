extends Node

func _ready() -> void:
	# Watchdog timer
	get_tree().create_timer(8.0).timeout.connect(func():
		print("[TEST WATCHDOG] Timeout alcanzado, saliendo...")
		get_tree().quit(1)
	)

	print("\n==========================================")
	print("[TEST] Testing Title Screen & 3D Hub as Main Menu...")
	print("==========================================")

	# ----------------------------------------------------
	# CASO 1: Comprobar configuración de project.godot
	# ----------------------------------------------------
	print("\n[1/4] Testing main_scene in ProjectSettings...")
	var main_scene_setting: String = str(ProjectSettings.get_setting("application/run/main_scene"))
	assert(main_scene_setting == "res://scenes/ui/title_screen/title_screen.tscn", "main_scene debe ser title_screen.tscn")
	print("  ✓ application/run/main_scene está configurado correctamente hacia 'title_screen.tscn'.")

	# ----------------------------------------------------
	# CASO 2: Instanciación y comportamiento de TitleScreen
	# ----------------------------------------------------
	print("\n[2/4] Testing TitleScreen UI & Any-Key Transition...")
	var title_scene: PackedScene = load("res://scenes/ui/title_screen/title_screen.tscn")
	assert(title_scene != null, "title_screen.tscn debe cargarse")
	var title_screen: Control = title_scene.instantiate()
	add_child(title_screen)

	var title_lbl: Label = title_screen.get_node_or_null("CenterContainer/VBoxContainer/TitleLabel") as Label
	var prompt_lbl: Label = title_screen.get_node_or_null("CenterContainer/VBoxContainer/PromptLabel") as Label
	assert(title_lbl != null, "TitleLabel debe existir")
	assert(title_lbl.text.contains("ASTRA : DREAM"), "Debe mostrar título ASTRA : DREAM")
	assert(prompt_lbl != null, "PromptLabel debe existir")
	assert(prompt_lbl.text.contains("TOCA CUALQUIER TECLA"), "Debe mostrar prompt para continuar")

	# Simular pulsación de tecla
	var key_ev := InputEventKey.new()
	key_ev.pressed = true
	key_ev.keycode = KEY_SPACE
	title_screen._unhandled_input(key_ev)
	assert(title_screen.get("_is_transitioning") == true, "Debe activar transición al recibir input")
	print("  ✓ TitleScreen responde a cualquier entrada e inicia la transición con fade.")
	title_screen.queue_free()

	# ----------------------------------------------------
	# CASO 3: Geometría 3D, Parallax y Estaciones del HubWorld
	# ----------------------------------------------------
	print("\n[3/4] Testing 3D Hub Room, Parallax & Interactive Terminals...")
	var hub_scene: PackedScene = load("res://scenes/ui/hub/hub_world.tscn")
	assert(hub_scene != null, "hub_world.tscn debe cargarse")
	var hub_world: HubWorld = hub_scene.instantiate() as HubWorld
	add_child(hub_world)

	# Verificar geometría de la sala
	assert(hub_world.has_node("HangarRoom/Floor"), "Debe tener suelo")
	assert(hub_world.has_node("HangarRoom/Ceiling"), "Debe tener techo")
	assert(hub_world.has_node("HangarRoom/LeftWall"), "Debe tener pared izquierda")
	assert(hub_world.has_node("HangarRoom/RightWall"), "Debe tener pared derecha")
	assert(hub_world.has_node("HangarRoom/BackWall"), "Debe tener pared trasera")
	assert(hub_world.has_node("HangarRoom/FrontRailing"), "Debe tener ventanal/barandilla frontal")

	# Verificar Parallax Espacial
	assert(hub_world.parallax_deep != null, "Debe tener capa profunda de Parallax")
	assert(hub_world.parallax_mid != null, "Debe tener capa media de Parallax")
	assert(hub_world.parallax_near != null, "Debe tener capa cercana de Parallax")

	# Verificar Terminales
	assert(hub_world.mission_interactable != null, "Debe tener interactuable de Misión")
	assert(hub_world.highscores_interactable != null, "Debe tener interactuable de Récords")
	print("  ✓ Hangar 3D verificado: Geometría completa de la sala, 3 capas de parallax espacial y terminales interactivas.")

	# ----------------------------------------------------
	# CASO 4: Atajos de HUD en esquina y modales interactivos
	# ----------------------------------------------------
	print("\n[4/4] Testing Corner HUD Badges, SettingsModal & HighScoresModal...")
	assert(hub_world.btn_settings != null, "Botón de Ajustes debe existir")
	assert(hub_world.btn_quit != null, "Botón de Salir debe existir")
	assert(hub_world.btn_settings.text.contains("[ESC]"), "Botón de Ajustes debe indicar hotkey [ESC]")
	assert(hub_world.btn_quit.text.contains("[Q]"), "Botón de Salir debe indicar hotkey [Q]")

	# Probar apertura de Settings
	hub_world._open_settings()
	assert(hub_world.settings_modal != null and hub_world.settings_modal.visible, "SettingsModal debe estar visible")
	assert(hub_world.player_controller.is_movement_locked, "El movimiento 3D debe bloquearse mientras Ajustes está abierto")
	hub_world.settings_modal.closed.emit()
	assert(not hub_world.player_controller.is_movement_locked, "El movimiento 3D debe restaurarse al cerrar Ajustes")

	# Probar apertura de HighScores
	hub_world._on_highscores_terminal_interacted(hub_world.highscores_interactable, hub_world.player_controller)
	assert(hub_world.highscores_modal != null and hub_world.highscores_modal.visible, "HighscoresModal debe estar visible")
	assert(hub_world.player_controller.is_movement_locked, "El movimiento 3D debe bloquearse mientras Highscores está abierto")
	hub_world.highscores_modal.closed.emit()
	assert(not hub_world.player_controller.is_movement_locked, "El movimiento 3D debe restaurarse al cerrar Highscores")
	print("  ✓ Modales de Ajustes y Récords integrados con control de movimiento en el Hub 3D.")

	print("\n==========================================")
	print("[PASS] ALL TITLE SCREEN & 3D HUB TESTS PASSED (100%)!")
	print("==========================================\n")
	get_tree().quit(0)

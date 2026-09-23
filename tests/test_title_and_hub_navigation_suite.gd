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

	# Verificar Terminales y Assets Placeholders de Máquinas
	assert(hub_world.mission_interactable != null, "Debe tener interactuable de Misión")
	assert(hub_world.highscores_interactable != null, "Debe tener interactuable de Récords")
	assert(hub_world.has_node("Terminals/MissionTerminal/ConsoleDesk"), "MissionTerminal debe tener consola física")
	assert(hub_world.has_node("Terminals/MissionTerminal/HoloCore"), "MissionTerminal debe tener núcleo holográfico")
	assert(hub_world.has_node("Terminals/HighScoresTerminal/ArcadeBody"), "HighScoresTerminal debe tener mueble arcade")
	assert(hub_world.has_node("Terminals/HighScoresTerminal/ScreenMesh"), "HighScoresTerminal debe tener pantalla arcade")
	assert(hub_world.has_node("Terminals/HighScoresTerminal/TrophyHolo"), "HighScoresTerminal debe tener trofeo holográfico")

	# Verificar test de profundidad (no_depth_test = false) para evitar que floten sobre paredes
	assert(not hub_world.mission_interactable.label_3d.no_depth_test, "Prompt de misión debe respetar profundidad (no_depth_test = false)")
	assert(not hub_world.highscores_interactable.label_3d.no_depth_test, "Prompt de récords debe respetar profundidad (no_depth_test = false)")

	# Verificar limitación de cámara para no atravesar la pared trasera
	hub_world.player_controller.global_position = Vector3(0, 0, 16.0)
	hub_world.player_controller._update_camera(1.0)
	assert(hub_world.player_controller.camera.global_position.z <= 13.0, "La cámara no debe atravesar la pared trasera ni salirse del hangar")

	# Verificar configuración Full Body en el PlayerController y en las heroínas
	assert(is_equal_approx(hub_world.player_controller.visual_sprite.pixel_size, 0.0013), "Player visual_sprite debe tener pixel_size 0.0013 para Full Body")
	assert(hub_world.player_controller.visual_sprite.offset.y == 800, "Player visual_sprite debe tener offset Y=800 para anclaje a suelo")
	assert(hub_world.player_controller.visual_sprite.texture.resource_path.contains("fullbody"), "Player visual_sprite debe cargar textura fullbody")
	var cutout_selene: Sprite3D = hub_world.get_node_or_null("RosterCutouts/Cutout_Selene")
	assert(cutout_selene != null and cutout_selene.texture.resource_path.contains("flipped"), "Heroínas del lado derecho deben usar textura fullbody invertida (flipped)")

	# Verificar texturas asignadas en Parallax y superficies
	var mat_p0 = hub_world.parallax_deep.mesh.material as StandardMaterial3D
	assert(mat_p0 != null and mat_p0.albedo_texture != null, "Parallax Capa 0 debe tener textura asignada")
	assert(mat_p0.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA, "Parallax Capa 0 debe tener transparencia alfa activa para eliminar la caja negra")

	# Verificar paredes modulares de Kenney Modular Space Kit
	assert(hub_world.has_node("HangarRoom/LeftWall_Seg0"), "HangarRoom debe tener paredes modulares izquierdas")
	assert(hub_world.has_node("HangarRoom/RightWall_Seg0"), "HangarRoom debe tener paredes modulares derechas")
	assert(hub_world.has_node("HangarRoom/BackWall_L1"), "HangarRoom debe tener paredes modulares traseras")
	assert(hub_world.has_node("HangarRoom/KenneyGate"), "HangarRoom debe tener compuerta modular trasera")
	assert(not hub_world.has_node("HangarRoom/KenneyPinball"), "Las máquinas de arcade no deben estar en esquinas aleatorias")

	# Verificar máquinas arcade de Kenney en las terminales (en su lugar correspondiente)
	assert(hub_world.has_node("Terminals/MissionTerminal/KenneyArcadeMission"), "MissionTerminal debe tener mueble arcade de Kenney")
	assert(hub_world.has_node("Terminals/HighScoresTerminal/KenneyArcade"), "HighScoresTerminal debe tener mueble arcade de Kenney")

	var floor_mesh := hub_world.get_node("HangarRoom/Floor/MeshInstance3D") as MeshInstance3D
	var mat_floor = floor_mesh.mesh.material as StandardMaterial3D
	assert(mat_floor != null and mat_floor.albedo_texture != null and mat_floor.emission_texture != null, "Suelo del Hangar debe tener textura de albedo y emisión asignada")
	print("  ✓ Hangar 3D verificado: Geometría de sala, paredes modulares Kenney, 3 capas de parallax transparentes, máquinas arcade y avatares Full Body.")

	# ----------------------------------------------------
	# CASO 4: Atajos de HUD en esquina y modales interactivos
	# ----------------------------------------------------
	print("\n[4/4] Testing Corner HUD Badges, SettingsModal, HighScoresModal & Pilot Skill Tree...")
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

	# Probar apertura del Árbol de Habilidades al interactuar con una piloto
	var inter_nova = hub_world.get_node_or_null("RosterCutouts/Interactable_Nova")
	assert(inter_nova != null, "Interactuable de Nova debe existir")
	hub_world._on_interactable_triggered(inter_nova, hub_world.player_controller)
	assert(hub_world.skill_tree_modal != null and hub_world.skill_tree_modal.visible, "SkillTreeModal debe abrirse al hablar con la piloto")
	assert(hub_world.player_controller.is_movement_locked, "El movimiento 3D debe bloquearse al abrir el Árbol de Habilidades")
	assert(hub_world.skill_tree_modal.hex_nodes.size() == 13, "El Árbol de Habilidades debe tener los 13 nodos hexagonales generados y visibles")
	# Probar cierre y desbloqueo inmediato del movimiento
	hub_world.skill_tree_modal.close_modal()
	assert(not hub_world.player_controller.is_movement_locked, "El movimiento 3D debe restaurarse INMEDIATAMENTE al cerrar el Árbol de Habilidades")
	print("  ✓ Modales de Ajustes, Récords y Árbol de Talentos (13 nodos) con control de movimiento fluido en el Hub 3D.")

	print("\n==========================================")
	print("[PASS] ALL TITLE SCREEN & 3D HUB TESTS PASSED (100%)!")
	print("==========================================\n")
	get_tree().quit(0)

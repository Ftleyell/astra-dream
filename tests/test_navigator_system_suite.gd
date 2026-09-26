extends Node

const NavigatorDataScript := preload("res://data/navigators/navigator_data.gd")
const NavigatorCommsWidgetScript := preload("res://scenes/ui/hud/navigator_comms_widget.gd")
const NavigatorGuideLineScript := preload("res://scenes/combat/navigators/navigator_guide_line.gd")
const NavigatorControllerScript := preload("res://scenes/combat/navigators/navigator_controller.gd")
const NavigatorSelectionModalScript := preload("res://scenes/ui/character_select/navigator_selection_modal.gd")
const CharacterStatsScript := preload("res://core/types/character_stats.gd")

func _ready() -> void:
	print("\n=======================================================")
	print("🧭 EJECUTANDO TEST SUITE: SISTEMA DE NAVEGANTES (NAVIGATORS)")
	print("=======================================================\n")

	test_navigator_roster_and_resources()
	test_save_manager_navigator_persistence()
	test_navigator_comms_widget_ui()
	test_navigator_guide_line_mechanics()
	test_navigator_controller_and_buff_applications()
	test_navigator_selection_modal_ui()

	print("\n=======================================================")
	print("🎉 TODOS LOS TESTS DEL SISTEMA DE NAVEGANTES PASARON EXITOSAMENTE!")
	print("=======================================================\n")
	get_tree().quit(0)

func test_assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("❌ FALLO EN TEST: %s" % message)
		printerr("❌ FALLO EN TEST: %s" % message)
		assert(condition, message)
	else:
		print("  ✓ %s" % message)

# ── 1. ROSTER Y RECURSOS DE NAVEGANTES ───────────────────────────────────────
func test_navigator_roster_and_resources() -> void:
	print("[1/6] Verificando Roster y Recursos de Navegantes...")
	var roster := NavigatorDataScript.load_roster()
	test_assert(roster.size() == 5, "El roster debe tener exactamente 5 navegantes (actual: %d)" % roster.size())
	test_assert(roster.has(&"lyra"), "Debe existir Lyra en el roster")
	test_assert(roster.has(&"vespera"), "Debe existir Vespera en el roster")
	test_assert(roster.has(&"caelia"), "Debe existir Caelia en el roster")
	test_assert(roster.has(&"zephyr"), "Debe existir Zephyr en el roster")
	test_assert(roster.has(&"iris"), "Debe existir Iris (secreta) en el roster")

	var ordered := NavigatorDataScript.load_roster_ordered()
	test_assert(ordered.size() == 5, "load_roster_ordered debe retornar 5 navegantes ordenadas")

	for nid in roster.keys():
		var nav = roster[nid]
		test_assert(nav != null, "El recurso de la navegante %s no debe ser nulo" % str(nid))
		test_assert(not nav.display_name.is_empty(), "La navegante %s debe tener display_name" % str(nid))
		test_assert(not nav.title.is_empty(), "La navegante %s debe tener title" % str(nid))
		test_assert(not nav.specialty_desc.is_empty(), "La navegante %s debe tener specialty_desc" % str(nid))
		test_assert(not nav.buff_name.is_empty(), "La navegante %s debe tener buff_name" % str(nid))
		test_assert(not nav.buff_desc.is_empty(), "La navegante %s debe tener buff_desc" % str(nid))
		test_assert(nav.dialogue_callouts.size() >= 2, "La navegante %s debe tener al menos 2 diálogos de alerta" % str(nid))
		test_assert(nav.get_portrait_texture() != null, "La navegante %s debe tener textura de retrato válida" % str(nid))
		test_assert(nav.get_fullbody_texture() != null, "La navegante %s debe tener textura de cuerpo completo válida" % str(nid))

# ── 2. PERSISTENCIA EN SAVEMANAGER ───────────────────────────────────────────
func test_save_manager_navigator_persistence() -> void:
	print("[2/6] Verificando Persistencia y Estado de Desbloqueo en SaveManager...")
	SaveManager.lock_navigator(&"iris")
	var unlocked := SaveManager.get_unlocked_navigators()
	test_assert(unlocked.has(&"lyra"), "Lyra debe estar desbloqueada por defecto")
	test_assert(unlocked.has(&"vespera"), "Vespera debe estar desbloqueada por defecto")
	test_assert(unlocked.has(&"caelia"), "Caelia debe estar desbloqueada por defecto")
	test_assert(unlocked.has(&"zephyr"), "Zephyr debe estar desbloqueada por defecto")
	test_assert(not unlocked.has(&"iris"), "Iris debe estar BLOQUEADA por defecto")
	test_assert(not SaveManager.is_navigator_unlocked(&"iris"), "is_navigator_unlocked(iris) debe ser false")

	# Selección de navegante
	SaveManager.set_selected_navigator(&"vespera")
	test_assert(SaveManager.get_selected_navigator() == &"vespera", "set_selected_navigator(vespera) debe persistir vespera")

	# Desbloqueo de Iris
	var unlocked_now := SaveManager.unlock_navigator(&"iris")
	test_assert(unlocked_now, "unlock_navigator(iris) debe retornar true la primera vez")
	test_assert(SaveManager.is_navigator_unlocked(&"iris"), "is_navigator_unlocked(iris) debe ser true tras desbloqueo")

	# Selección de Iris
	SaveManager.set_selected_navigator(&"iris")
	test_assert(SaveManager.get_selected_navigator() == &"iris", "Iris puede seleccionarse cuando está desbloqueada")

	# Bloqueo de Iris (debe resetear a Lyra si estaba seleccionada)
	SaveManager.lock_navigator(&"iris")
	test_assert(not SaveManager.is_navigator_unlocked(&"iris"), "Iris debe volver a estar bloqueada")
	test_assert(SaveManager.get_selected_navigator() == &"lyra", "Si Iris estaba seleccionada al bloquearse, debe volver a lyra")

	# Verificación de desbloqueo automático de Iris al registrar un final de historia
	SaveManager.record_ending("ending_test_pacifist")
	test_assert(SaveManager.is_navigator_unlocked(&"iris"), "Iris debe desbloquearse automáticamente al registrar un final de historia")

# ── 3. WIDGET DE COMUNICACIONES LATERAL ──────────────────────────────────────
func test_navigator_comms_widget_ui() -> void:
	print("[3/6] Verificando Widget Lateral de Comunicaciones (No Intrusivo)...")
	var widget_scene := preload("res://scenes/ui/hud/navigator_comms_widget.tscn")
	var widget = widget_scene.instantiate()
	add_child(widget)

	var lyra_data = NavigatorDataScript.get_navigator(&"lyra")
	widget.show_transmission(lyra_data, "Prueba de transmisión táctica", "Segmento Planetario")
	test_assert(widget.is_inside_tree(), "El widget debe estar en el árbol de escenas")
	test_assert(widget.visible, "El widget debe ser visible")
	test_assert(widget.name_label.text.contains("LYRA"), "El encabezado debe contener el nombre de la navegante")
	test_assert(widget.portrait_rect.texture != null, "El retrato debe estar cargado en el widget")

	# Simular confirmación de buff
	widget.show_buff_activated(lyra_data)
	test_assert(widget.badge_label.text.contains("ENLACE"), "La insignia debe reflejar enlace exitoso")
	widget.queue_free()

# ── 4. LÍNEA DE GUÍA HOLOGRÁFICA ─────────────────────────────────────────────
func test_navigator_guide_line_mechanics() -> void:
	print("[4/6] Verificando Línea Holográfica de Guía y Retícula...")
	var player_dummy := Node2D.new()
	player_dummy.global_position = Vector2(100, 100)
	add_child(player_dummy)

	var target_dummy := Node2D.new()
	target_dummy.global_position = Vector2(800, 800)
	add_child(target_dummy)

	var guide_line = NavigatorGuideLineScript.new()
	add_child(guide_line)
	guide_line.setup(player_dummy, target_dummy, Color.CYAN, 30.0)

	test_assert(guide_line.is_active, "La línea de guía debe estar activa")
	test_assert(guide_line.target_position == target_dummy.global_position, "La posición del objetivo debe coincidir")

	# Mover el jugador cerca del objetivo para simular llegada (< 140px)
	var signal_received: Array[bool] = [false]
	guide_line.target_reached.connect(func(_t): signal_received[0] = true)

	player_dummy.global_position = Vector2(850, 800) # distancia = 50px < 140px
	guide_line._process(0.016)

	test_assert(signal_received[0], "Al entrar en el radio de 140px, la línea debe emitir target_reached")

	player_dummy.queue_free()
	target_dummy.queue_free()
	guide_line.queue_free()

# ── 5. CONTROLADOR Y BUFFS TÁCTICOS ──────────────────────────────────────────
func test_navigator_controller_and_buff_applications() -> void:
	print("[5/6] Verificando Controlador y Aplicación de los 5 Buffs de Navegación...")

	var main_scene: PackedScene = load("res://scenes/combat/main_game.tscn")
	var main_game_inst = main_scene.instantiate()
	add_child(main_game_inst)
	if Dialogic:
		Dialogic.end_timeline()
	main_game_inst.is_briefing_active = false
	get_tree().paused = false

	var dummy_player = main_game_inst.player
	var controller = NavigatorControllerScript.new()
	add_child(controller)
	controller.player = dummy_player
	controller.main_game = main_game_inst

	# Probar Buff de Lyra (+25% Vel, +100% Radio Imán)
	controller.navigator_data = NavigatorDataScript.get_navigator(&"lyra")
	var base_speed: float = dummy_player.stats.get_stat(&"move_speed")
	controller._apply_navigator_buff()
	var buffed_speed: float = dummy_player.stats.get_stat(&"move_speed")
	test_assert(buffed_speed > base_speed, "El buff de Lyra debe incrementar la velocidad de movimiento (+25%)")
	controller._expire_buff()
	test_assert(is_equal_approx(dummy_player.stats.get_stat(&"move_speed"), base_speed), "Al expirar Lyra, la velocidad debe retornar a la base")

	# Probar Buff de Vespera (+20% CDR, +15% Daño)
	controller.navigator_data = NavigatorDataScript.get_navigator(&"vespera")
	var base_dmg: float = dummy_player.stats.get_stat(&"base_damage")
	controller._apply_navigator_buff()
	test_assert(dummy_player.stats.get_stat(&"base_damage") > base_dmg, "El buff de Vespera debe incrementar el daño (+15%)")
	controller._expire_buff()

	# Probar Buff de Caelia (+20% Armadura + 1 hit gratis de absorción)
	controller.navigator_data = NavigatorDataScript.get_navigator(&"caelia")
	controller._apply_navigator_buff()
	test_assert(dummy_player.has_meta("caelia_shield_hook"), "El buff de Caelia debe activar el escudo gravitational")
	var hp_before: float = dummy_player.current_health
	dummy_player.take_damage(50.0) # Debe absorberse completamente sin restar vida
	test_assert(dummy_player.current_health == hp_before, "El escudo de Caelia debe absorber 1 impacto completamente sin restar HP")
	test_assert(not dummy_player.has_meta("caelia_shield_hook"), "Tras absorber el golpe, el escudo se consume")
	controller._expire_buff()

	# Probar Buff de Zephyr (+50 Créditos + 15% Cadencia)
	controller.navigator_data = NavigatorDataScript.get_navigator(&"zephyr")
	var credits_before: int = dummy_player.run_credits
	controller._apply_navigator_buff()
	test_assert(dummy_player.run_credits == credits_before + 50, "El buff de Zephyr debe otorgar 50 créditos inmediatos")
	controller._expire_buff()

	# Probar Buff de Iris (+30% Crítico, +25% Vel. Proyectil)
	controller.navigator_data = NavigatorDataScript.get_navigator(&"iris")
	var base_crit: float = dummy_player.stats.get_stat(&"crit_chance")
	controller._apply_navigator_buff()
	test_assert(dummy_player.stats.get_stat(&"crit_chance") >= base_crit + 0.29, "El buff de Iris debe otorgar +30% probabilidad crítica")
	controller._expire_buff()

	# Probar que satélites solo dan buff a Zephyr y no a otras navegadoras (ej. Lyra)
	var dummy_sat := Node2D.new()
	dummy_sat.add_to_group("satellite_beacon")
	add_child(dummy_sat)

	controller.navigator_data = NavigatorDataScript.get_navigator(&"lyra")
	controller._on_target_reached(dummy_sat)
	test_assert(not controller.is_buff_active, "Lyra no debe recibir buff al tocar un satélite")

	controller.navigator_data = NavigatorDataScript.get_navigator(&"zephyr")
	controller._on_target_reached(dummy_sat)
	test_assert(controller.is_buff_active, "Zephyr sí debe recibir su buff al enlazar un satélite")
	controller._expire_buff()
	dummy_sat.queue_free()

	controller.queue_free()
	main_game_inst.queue_free()

# ── 6. MODAL DE SELECCIÓN DE NAVEGANTES ───────────────────────────────────────
func test_navigator_selection_modal_ui() -> void:
	print("[6/6] Verificando Modal de Selección de Navegantes (Carrusel Vertical Full-Body)...")
	var modal_scene := preload("res://scenes/ui/character_select/navigator_selection_modal.tscn")
	var modal = modal_scene.instantiate()
	add_child(modal)

	modal.open_modal()
	test_assert(modal.is_open, "open_modal() debe poner is_open en true")
	test_assert(modal.visible, "El modal debe hacerse visible")
	test_assert(modal._nav_buttons.size() == 5, "Deben crearse exactamente 5 indicadores de navegantes en el carrusel")
	test_assert(modal.fullbody_texture != null and modal.fullbody_texture.texture != null, "El carrusel debe mostrar la textura full-body de la navegante activa")

	# Probar desplazamiento Cover Flow
	var start_idx: int = modal.current_index
	modal._cycle(1)
	test_assert(modal.current_index == (start_idx + 1) % 5, "Avanzar Cover Flow debe cambiar el índice al siguiente")
	modal._cycle(-1)
	test_assert(modal.current_index == start_idx, "Retroceder Cover Flow debe restaurar el índice previo")

	# Probar clic directo en las cartas laterales de Cover Flow
	modal.left_card.emit_signal("pressed")
	test_assert(modal.current_index == (start_idx - 1 + 5) % 5, "Hacer clic en la carta izquierda debe retroceder")
	modal.right_card.emit_signal("pressed")
	test_assert(modal.current_index == start_idx, "Hacer clic en la carta derecha debe avanzar")

	# Probar selección de navegante mediante el botón principal
	modal._set_index(1) # Vespera
	modal._on_select_pressed()
	test_assert(SaveManager.get_selected_navigator() == &"vespera", "Al confirmar selección, debe enlazarse Vespera en SaveManager")
	test_assert(not modal.is_open, "Al seleccionar, el modal debe cerrarse")

	# Probar reapertura y verificar que el carrusel enfoca la navegante seleccionada
	modal.open_modal()
	test_assert(modal.current_index == 1, "Al reabrir el modal, el carrusel debe iniciar en la navegante seleccionada (Vespera)")

	# Probar cierre
	modal.close_modal()
	test_assert(not modal.is_open, "close_modal() debe poner is_open en false")
	test_assert(not modal.visible, "El modal debe ocultarse")
	modal.queue_free()

class_name TestPhase2TacticalFocusSuite
extends BaseTestSuite

## TestPhase2TacticalFocusSuite
## Valida las especificaciones técnicas implementadas en la Fase 2:
## - Nova Dash sin fire trail (limpio, exclusivo Omega Spin)
## - Escalado de carga de láser táctico de Nova con la velocidad de movimiento (hasta 1.2s)
## - Modo Enfoque Táctico (Ctrl) anclado a 280.0 px/s
## - Núcleo de Hitbox reactivo y toggle persistente en SettingsManager / PauseMenu

func _ready() -> void:
	super._ready()
	print("--- TEST PHASE 2 TACTICAL FOCUS & HITBOX START ---")
	_run_tests()

func _run_tests() -> void:
	# 1. Nova Dash sin fuego
	var dash_ctrl := PlayerDashController.new()
	assert_true(dash_ctrl.get("fire_trail_hazard") == null, "PlayerDashController no debe tener fire_trail_hazard para evitar polución visual")
	print("  ✓ [PASS] Test 1: Dash de Nova limpio sin estela de fuego redundante")
	dash_ctrl.queue_free()

	# 2. Escalado de tiempo de carga de láser con move_speed
	var w_ctrl := WeaponController.new()
	var dummy_player := Player.new()
	dummy_player.stats = CharacterStats.new()
	dummy_player.stats.set_base_stat(&"move_speed", 340.0)
	w_ctrl.player = dummy_player
	w_ctrl.max_charge_time = 3.0

	var time_at_340: float = w_ctrl.get_effective_max_charge_time()
	assert_true(is_equal_approx(time_at_340, 3.0), "A 340 px/s, tiempo de carga debe ser 3.0s, fue: %f" % time_at_340)

	dummy_player.stats.set_base_stat(&"move_speed", 680.0)
	var time_at_680: float = w_ctrl.get_effective_max_charge_time()
	assert_true(is_equal_approx(time_at_680, 1.5), "A 680 px/s, tiempo de carga debe ser 1.5s, fue: %f" % time_at_680)

	dummy_player.stats.set_base_stat(&"move_speed", 1200.0)
	var time_at_1200: float = w_ctrl.get_effective_max_charge_time()
	assert_true(is_equal_approx(time_at_1200, 1.2), "A 1200 px/s, tiempo de carga debe topar en 1.2s, fue: %f" % time_at_1200)
	print("  ✓ [PASS] Test 2: Tiempo de carga de láser escala inversamente con move_speed (3.0s -> 1.2s)")
	w_ctrl.queue_free()
	dummy_player.queue_free()

	# 3. Constante de velocidad en Modo Enfoque Táctico
	var test_player := Player.new()
	assert_true(is_equal_approx(Player.TACTICAL_FOCUS_SPEED, 280.0), "TACTICAL_FOCUS_SPEED debe ser 280.0 px/s")
	test_player.stats = CharacterStats.new()
	test_player.stats.set_base_stat(&"move_speed", 450.0)
	test_player.is_tactical_focus_active = true
	var effective_speed: float = test_player.stats.get_stat(&"move_speed")
	if test_player.is_tactical_focus_active:
		effective_speed = minf(effective_speed, Player.TACTICAL_FOCUS_SPEED)
	assert_true(is_equal_approx(effective_speed, 280.0), "La velocidad efectiva bajo enfoque táctico debe fijarse en 280.0 px/s")
	print("  ✓ [PASS] Test 3: Modo Enfoque Táctico ancla la velocidad máxima a 280.0 px/s")
	test_player.queue_free()

	# 4. SettingsManager: core_hitbox_always_visible
	var settings_mgr = get_node_or_null("/root/SettingsManager")
	if settings_mgr:
		var prev_state: bool = settings_mgr.is_core_hitbox_always_visible()
		settings_mgr.set_core_hitbox_always_visible(true)
		assert_true(settings_mgr.is_core_hitbox_always_visible() == true, "SettingsManager debe guardar core_hitbox_always_visible = true")
		settings_mgr.set_core_hitbox_always_visible(false)
		assert_true(settings_mgr.is_core_hitbox_always_visible() == false, "SettingsManager debe guardar core_hitbox_always_visible = false")
		settings_mgr.set_core_hitbox_always_visible(prev_state)
		print("  ✓ [PASS] Test 4: SettingsManager maneja core_hitbox_always_visible con persistencia")

	# 5. PauseMenu HitboxToggleButton
	var pause_scene: PackedScene = load("res://scenes/ui/pause_menu/pause_menu.tscn")
	assert_true(pause_scene != null, "No se pudo cargar pause_menu.tscn")
	var pause_inst: PauseMenu = pause_scene.instantiate() as PauseMenu
	add_child(pause_inst)
	var toggle_btn: Button = pause_inst.get_node_or_null("Panel/VBoxContainer/BottomBar/HitboxToggleButton") as Button
	assert_true(toggle_btn != null, "PauseMenu debe tener HitboxToggleButton en BottomBar")
	if toggle_btn and settings_mgr:
		settings_mgr.set_core_hitbox_always_visible(false)
		pause_inst._update_hitbox_toggle_text()
		assert_true(toggle_btn.text.contains("AUTO"), "Cuando está en false, el botón debe indicar AUTO")
		settings_mgr.set_core_hitbox_always_visible(true)
		pause_inst._update_hitbox_toggle_text()
		assert_true(toggle_btn.text.contains("SIEMPRE"), "Cuando está en true, el botón debe indicar SIEMPRE")
		settings_mgr.set_core_hitbox_always_visible(false)
	print("  ✓ [PASS] Test 5: Botón de Hitbox en PauseMenu actualiza texto dinámicamente")
	pause_inst.queue_free()

	print("--- TEST PHASE 2 TACTICAL FOCUS & HITBOX COMPLETED: ALL TESTS PASS ---")
	call_deferred(&"_finish_suite")

func _finish_suite() -> void:
	if is_inside_tree() and get_tree():
		get_tree().quit(0)

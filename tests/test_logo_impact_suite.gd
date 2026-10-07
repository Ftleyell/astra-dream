class_name TestLogoImpactSuite
extends BaseTestSuite

## TestLogoImpactSuite
## Valida el controlador de impacto de logotipo estilo 32-bits y su shader.

func _ready() -> void:
	super._ready()
	_run_tests()


func _run_tests() -> void:
	print("\n[TEST] Ejecutando verificación de LogoImpactController y mega_man_logo_vfx...")

	# 1. Configuración Data-Driven
	var cfg: TitleImpactConfig = load("res://scenes/ui/title_screen/default_title_impact_config.tres")
	assert_true(cfg != null, "default_title_impact_config.tres debe cargar correctamente")
	assert_true(cfg.drop_duration > 0.0, "drop_duration debe ser positivo")
	assert_true(cfg.hitstop_duration > 0.0, "hitstop_duration debe ser positivo")

	# Usar duraciones aceleradas para el test unitario
	var test_cfg: TitleImpactConfig = cfg.duplicate() as TitleImpactConfig
	test_cfg.drop_duration = 0.05
	test_cfg.hitstop_duration = 0.02
	test_cfg.squash_duration = 0.02
	test_cfg.stretch_duration = 0.02
	test_cfg.bounce_duration = 0.02
	test_cfg.flash_duration = 0.02
	test_cfg.glitch_duration = 0.02
	test_cfg.panel_reveal_delay = 0.01
	test_cfg.panel_reveal_duration = 0.02
	test_cfg.afterimage_count = 1
	test_cfg.afterimage_fade_time = 0.02

	# 2. Configurar jerarquía en árbol
	var root_control: Control = Control.new()
	root_control.size = Vector2(1280, 720)
	add_child(root_control)

	var vfx_anchor: Control = Control.new()
	vfx_anchor.size = Vector2(400, 200)
	root_control.add_child(vfx_anchor)

	var logo_rect: TextureRect = TextureRect.new()
	logo_rect.size = Vector2(400, 200)
	vfx_anchor.add_child(logo_rect)

	var ghost_container: Control = Control.new()
	root_control.add_child(ghost_container)

	var secondary_panel: Control = Control.new()
	secondary_panel.size = Vector2(300, 400)
	root_control.add_child(secondary_panel)

	var controller: LogoImpactController = LogoImpactController.new()
	controller.config = test_cfg
	controller.logo_target = logo_rect
	controller.vfx_anchor = vfx_anchor
	controller.ghost_container = ghost_container
	controller.secondary_panel = secondary_panel
	add_child(controller)

	# 3. Comprobar que shader se haya inicializado
	assert_true(logo_rect.material is ShaderMaterial, "logo_target debe tener un ShaderMaterial asignado")
	var mat: ShaderMaterial = logo_rect.material as ShaderMaterial
	assert_true(mat.shader != null, "El shader asignado no debe ser nulo")

	# 4. Escuchar señales de impacto y finalización
	var signal_state: Dictionary = {"impact": false, "completed": false}

	controller.impact_landed.connect(func() -> void:
		signal_state["impact"] = true
	)
	controller.sequence_completed.connect(func() -> void:
		signal_state["completed"] = true
	)

	# 5. Ejecutar secuencia
	controller.play_sequence()

	# Esperar a que la secuencia culmine
	var max_wait_ms: int = 2500
	var start_ticks: int = Time.get_ticks_msec()
	while not signal_state["completed"] and (Time.get_ticks_msec() - start_ticks) < max_wait_ms:
		await get_tree().process_frame

	assert_true(signal_state["impact"], "La señal impact_landed debió haberse emitido")
	assert_true(signal_state["completed"], "La señal sequence_completed debió haberse emitido")
	assert_true(mat.get_shader_parameter("shine_active") == true, "shine_active debe ser true en reposo activo")
	assert_true(secondary_panel.modulate.a > 0.9, "secondary_panel debe haberse revelado al final de la cascada")

	pass_suite("LogoImpactController y shader ejecutaron la secuencia cinemática exitosamente.")

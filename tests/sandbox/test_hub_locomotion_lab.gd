extends BaseTestSuite
## Suite aislada de verificación para HubLocomotionLab (cámaras, circuitos, phase scrub, ripple 3D y limpieza time_scale).

const LabScene: PackedScene = preload("res://sandbox/hub_art_lab/hub_locomotion_lab/hub_locomotion_lab.tscn")
const LabScript = preload("res://sandbox/hub_art_lab/hub_locomotion_lab/hub_locomotion_lab.gd")
const GroundedConfigScript = preload("res://data/pilots/schemas/pilot_grounded_locomotion_config.gd")


func _ready() -> void:
	timeout_seconds = 18.0
	super._ready()
	await _run_tests()


func _cleanup_and_quit(exit_code: int) -> void:
	Engine.time_scale = 1.0
	await super._cleanup_and_quit(exit_code)


func _run_tests() -> void:
	var lab: LabScript = LabScene.instantiate() as LabScript
	assert_true(lab != null, "HubLocomotionLab debe instanciar correctamente")
	add_child(lab)
	await get_tree().process_frame
	await get_tree().process_frame

	assert_true(lab.player != null and lab.player.rig_avatar != null, "HubLocomotionLab debe instanciar HubArtLabPlayer y HubRigAvatar3D reales")
	assert_true(lab.camera != null and lab.hud != null, "HubLocomotionLab debe crear Camera3D y HubLocomotionLabHud")
	assert_true(lab.player.rig_avatar.is_grounded_mode(), "El jugador en el Lab debe iniciar en modo grounded")

	# Cambio de cámaras 1..4 y actualización de pitch
	lab.set_camera_mode(LabScript.CamMode.SIDE_PROFILE)
	await get_tree().process_frame
	assert_true(lab.camera.fov < 25.0, "Cámara SIDE_PROFILE debe aplicar FOV 24°")

	lab.set_camera_mode(LabScript.CamMode.HUB_REAL)
	await get_tree().process_frame

	# Scrub manual de fase debe posicionar el gait exactamente en el ángulo solicitado
	lab.set_scrub_enabled(true)
	lab._on_scrub_deg_changed(110.0)
	await get_tree().process_frame
	var rig: PlanarCombatRig = lab.player.rig_avatar.get_rig()
	var tel: Dictionary = rig.get_grounded_telemetry()
	assert_true(bool(tel.get("scrub_enabled", false)), "Scrub manual debe reflejarse en telemetría")
	assert_true(absf(rad_to_deg(float(tel.get("phase", 0.0))) - 110.0) < 1.0, "La fase en scrub debe corresponder a 110°")
	assert_true(float(tel.get("pelvis_lift_norm", 0.0)) > 0.70, "A 110° de fase Astral Glide-Hop debe estar elevado en arco (>0.70)")

	# Disparar ripple 3D manual debe spawnear AstralBounceRipple en la escena
	lab.trigger_test_ripple()
	await get_tree().process_frame
	assert_true(lab.get_node_or_null("AstralBounceRipple") != null, "trigger_test_ripple debe instanciar AstralBounceRipple bajo el jugador")

	# Alternar estilos y slow-mo, y verificar restauración de Engine.time_scale al salir
	lab.set_gait_style(GroundedConfigScript.GaitStyle.WALK_STRIDE)
	assert_true(lab.player.rig_avatar.get_grounded_config().gait_style == GroundedConfigScript.GaitStyle.WALK_STRIDE, "Debe cambiar dinámicamente a WALK_STRIDE")
	lab.set_gait_style(GroundedConfigScript.GaitStyle.ASTRAL_GLIDE_HOP)
	lab.set_slowmo_index(2)
	assert_true(Engine.time_scale < 0.5, "Slow-Mo índice 2 debe ajustar Engine.time_scale a 0.25")

	lab.queue_free()
	await get_tree().process_frame
	assert_true(is_equal_approx(Engine.time_scale, 1.0), "Al destruir HubLocomotionLab Engine.time_scale debe restaurarse a 1.0")

	pass_suite("HubLocomotionLab 3D verificado: cámaras, scrub de fase, ripple 3D astral, gait styles y limpieza de time_scale.")

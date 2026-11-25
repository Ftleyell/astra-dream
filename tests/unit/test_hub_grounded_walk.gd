extends BaseTestSuite
## Suite de verificación para Locomoción Grounded AAA del Hub 3D (Valentina v2):
## 1. Carga data-driven de PilotGroundedLocomotionConfig desde valentina_v2_profile.tres.
## 2. Modo por defecto ZERO_G_FLIGHT en PlanarCombatRig (combate intacto) y cambio limpio a GROUNDED_HUB.
## 3. Stride-Lock real (sin avance de fase con desplazamiento 0, 2 pisadas exactas por zancada).
## 4. Erradicación de flotación Zero-G en HubRigAvatar3D y restauración con Alas 3D en Espejo.
## 5. Evaluación anatómica en las 8 vistas nativas (sin flips ni hiperextensión de rodilla en 'e').
## 6. Pivote brusco 180° en HubGroundedMotor3D y registro de SFX 'hub_footstep' en AudioManager.

const PlanarRigScript = preload("res://scenes/pilots/rig/planar_combat_rig.gd")
const GroundedConfigScript = preload("res://data/pilots/schemas/pilot_grounded_locomotion_config.gd")
const GroundedEvaluatorScript = preload("res://scenes/pilots/rig/planar_rig_grounded_evaluator.gd")
const BasePoseEvaluatorScript = preload("res://scenes/pilots/rig/planar_rig_base_pose_evaluator.gd")
const HubWorldScene: PackedScene = preload("res://scenes/ui/hub/hub_world.tscn")
const HubRigAvatar3DScript = preload("res://scenes/ui/hub/components/hub_rig_avatar_3d.gd")
const HubGroundedMotor3DScript = preload("res://scenes/ui/hub/components/hub_grounded_motor_3d.gd")

const PROFILE_PATH: String = "res://data/pilots/valentina_v2/valentina_v2_profile.tres"


func _ready() -> void:
	timeout_seconds = 15.0
	super._ready()
	await _run_tests()


func _run_tests() -> void:
	_test_grounded_config_and_profile()
	_test_stride_lock_and_footsteps()
	_test_8dir_anatomical_rig_application()
	await _test_hub_avatar_grounded_and_showcase_switch()
	_test_motor_pivot_and_audio_sfx()
	pass_suite("Locomoción Grounded AAA Hub 3D verificada: Stride-Lock, 8-dir anatómico, cero flotación y pivote.")


func _test_grounded_config_and_profile() -> void:
	var profile: PilotRigProfile = ResourceLoader.load(PROFILE_PATH) as PilotRigProfile
	assert_true(profile != null, "Debe cargar valentina_v2_profile.tres")
	assert_true(profile.grounded_locomotion_config is GroundedConfigScript, "El perfil debe referenciar valentina_v2_grounded_locomotion.tres")
	var cfg: GroundedConfigScript = profile.grounded_locomotion_config as GroundedConfigScript
	cfg.ensure_initialized()
	for fam: String in GroundedConfigScript.FAMILY_ORDER:
		assert_true(cfg.standing_families.has(fam), "standing_families debe incluir familia '%s'" % fam)
		assert_true(cfg.family_multipliers.has(fam), "family_multipliers debe incluir familia '%s'" % fam)


func _test_stride_lock_and_footsteps() -> void:
	var cfg: GroundedConfigScript = ResourceLoader.load("res://data/pilots/valentina_v2/valentina_v2_grounded_locomotion.tres") as GroundedConfigScript
	assert_true(cfg != null, "Debe cargar valentina_v2_grounded_locomotion.tres")
	var eval := GroundedEvaluatorScript.new()

	# Con desplazamiento 0.0 (ej. bloqueado contra pared), gait_phase NO debe avanzar
	var phase_before: float = eval.gait_phase
	for _i: int in range(10):
		eval.step_gait(0.016, 1.0, 0.0, cfg)
	assert_true(is_equal_approx(eval.gait_phase, phase_before), "Con world_displacement_m = 0.0 la fase no debe avanzar (Stride-Lock)")
	assert_true(eval.consume_step_event().is_empty(), "No deben emitirse pisadas sin desplazamiento real")

	# Al recorrer exactamente stride_length_m, debe completar 1 ciclo (2 pisadas: 1 left, 1 right)
	var steps_seen: Array[StringName] = []
	var chunks: int = 20
	var chunk_dist: float = cfg.stride_length_m / float(chunks)
	for _j: int in range(chunks):
		eval.step_gait(0.016, 1.0, chunk_dist, cfg)
		var ev: Dictionary = eval.consume_step_event()
		if not ev.is_empty():
			steps_seen.append(ev.get("foot", &"") as StringName)
	assert_true(steps_seen.size() == 2, "Un ciclo stride_length_m debe emitir exactamente 2 eventos de pisada (got %d)" % steps_seen.size())
	assert_true(steps_seen.has(&"left") and steps_seen.has(&"right"), "Las pisadas deben alternar entre 'left' y 'right'")


func _test_8dir_anatomical_rig_application() -> void:
	var profile: PilotRigProfile = ResourceLoader.load(PROFILE_PATH) as PilotRigProfile
	var rig: PlanarCombatRig = PlanarRigScript.new()
	rig.pilot_profile = profile
	add_child(rig)

	assert_true(rig.get_locomotion_mode() == PlanarCombatRig.LocomotionMode.ZERO_G_FLIGHT, "PlanarCombatRig debe iniciar en ZERO_G_FLIGHT por defecto")
	rig.set_locomotion_mode(PlanarCombatRig.LocomotionMode.GROUNDED_HUB)
	assert_true(rig.get_locomotion_mode() == PlanarCombatRig.LocomotionMode.GROUNDED_HUB, "PlanarCombatRig debe cambiar limpiamente a GROUNDED_HUB")

	var cfg: GroundedConfigScript = profile.grounded_locomotion_config as GroundedConfigScript
	var base_eval := BasePoseEvaluatorScript.new()
	var g_eval := GroundedEvaluatorScript.new()

	var dirs: Array[Array] = [
		[Vector2(0.0, 1.0), "s"],
		[Vector2(1.0, 1.0), "se"],
		[Vector2(1.0, 0.0), "e"],
		[Vector2(1.0, -1.0), "ne"],
		[Vector2(0.0, -1.0), "n"],
		[Vector2(-1.0, -1.0), "nw"],
		[Vector2(-1.0, 0.0), "w"],
		[Vector2(-1.0, 1.0), "sw"],
	]

	for item: Array in dirs:
		var dv: Vector2 = item[0] as Vector2
		var vk: String = str(item[1])
		rig.set_locomotion_state(dv, 1.0, dv, true)
		assert_true(rig.get_active_view_key() == vk, "Vista activa debe ser '%s'" % vk)
		assert_true(not rig.is_body_flipped(), "body_flip_x debe mantenerse false en '%s'" % vk)
		g_eval.apply_to_rig(rig, base_eval, cfg, BasePoseEvaluatorScript.PoseLayerMode.COMBINED_BONES_AND_25D, 1.0, false, null, {}, null, 1.2, 1.0)

	# Verificar piernas rectas y paralelas (||) en reposo Grounded para s, n, se, sw, ne, nw (sin forma de V)
	var views_dict: Dictionary = rig.get_views()
	var dir_by_view: Dictionary = {
		"s": Vector2(0.0, 1.0),
		"n": Vector2(0.0, -1.0),
		"se": Vector2(1.0, 1.0),
		"sw": Vector2(-1.0, 1.0),
		"ne": Vector2(1.0, -1.0),
		"nw": Vector2(-1.0, -1.0),
	}
	for p_vk: String in ["s", "n", "se", "sw", "ne", "nw"]:
		var dv_p: Vector2 = dir_by_view[p_vk] as Vector2
		rig.set_locomotion_state(dv_p, 0.0, dv_p, true)
		g_eval.apply_to_rig(rig, base_eval, cfg, BasePoseEvaluatorScript.PoseLayerMode.COMBINED_BONES_AND_25D, 1.0, false, null, {}, null, 0.0, 0.0)
		var vd_p: Dictionary = views_dict.get(p_vk, {}) as Dictionary
		var bones_p: Dictionary = vd_p.get("bones", {}) as Dictionary
		var th_r: Bone2D = bones_p.get("Thigh_R", null) as Bone2D
		var th_l: Bone2D = bones_p.get("Thigh_L", null) as Bone2D
		var an_r: Bone2D = bones_p.get("Ankle_R", null) as Bone2D
		var an_l: Bone2D = bones_p.get("Ankle_L", null) as Bone2D
		assert_true(th_r != null and th_l != null and an_r != null and an_l != null, "Deben existir huesos de piernas en '%s'" % p_vk)
		var hip_sep_x: float = absf(th_r.global_position.x - th_l.global_position.x)
		var ankle_sep_x: float = absf(an_r.global_position.x - an_l.global_position.x)
		var v_diff: float = absf(ankle_sep_x - hip_sep_x)
		assert_true(v_diff <= 18.0, "En vista '%s' los tobillos deben quedar paralelos bajo caderas (hip=%.1f, ankle=%.1f, diff=%.1f)" % [p_vk, hip_sep_x, ankle_sep_x, v_diff])
		var hip_sign: float = signf(th_r.global_position.x - th_l.global_position.x)
		var ankle_sign: float = signf(an_r.global_position.x - an_l.global_position.x)
		assert_true(hip_sign == ankle_sign, "En vista '%s' las piernas no deben cruzarse" % p_vk)

	# Verificar que en vista "e" ninguna rodilla hiperextienda hacia adelante (knee_delta >= 0)
	rig.set_locomotion_state(Vector2.RIGHT, 1.0, Vector2.RIGHT, true)
	var vd_e: Dictionary = rig.get_views().get("e", {}) as Dictionary
	var bones_e: Dictionary = vd_e.get("bones", {}) as Dictionary
	var rest_e: Dictionary = vd_e.get("rest_rots", {}) as Dictionary
	for ph_sample: float in [0.0, PI * 0.25, PI * 0.7, PI * 1.25, PI * 1.75]:
		g_eval.apply_to_rig(rig, base_eval, cfg, BasePoseEvaluatorScript.PoseLayerMode.COMBINED_BONES_AND_25D, 1.0, false, null, {}, null, ph_sample, 1.0)
		for sfx: String in ["L", "R"]:
			var kb: Bone2D = bones_e.get("Knee_" + sfx, null) as Bone2D
			var k_rest: float = float(rest_e.get("Knee_" + sfx, 0.0))
			assert_true(kb != null and (kb.rotation - k_rest) >= -0.001, "En vista 'e' fase %.2f Knee_%s no debe hiperextender en negativo" % [ph_sample, sfx])

	rig.queue_free()


func _test_hub_avatar_grounded_and_showcase_switch() -> void:
	var hub: HubWorld = HubWorldScene.instantiate() as HubWorld
	add_child(hub)
	await get_tree().process_frame
	await get_tree().process_frame

	var pc: HubPlayerController3D = hub.player_controller as HubPlayerController3D
	var avatar: HubRigAvatar3DScript = pc.rig_avatar
	var rig: PlanarCombatRig = avatar.get_rig()
	var spr: Sprite3D = avatar.get_sprite_3d()

	assert_true(avatar.is_grounded_mode(), "HubRigAvatar3D debe iniciar en modo grounded")
	assert_true(rig.get_locomotion_mode() == PlanarCombatRig.LocomotionMode.GROUNDED_HUB, "El rig del Hub debe iniciar en GROUNDED_HUB")
	assert_true(spr.position.y <= 0.08, "En Idle Grounded AvatarSprite3D debe estar pegado al suelo (y=%.3f <= 0.08)" % spr.position.y)
	assert_true(avatar.get_hover_factor() < 0.05, "En Idle Grounded _hover_factor debe ser ~0")

	# Al activar Alas 3D en Espejo de Skins vuelve a ZERO_G_FLIGHT; al desactivar vuelve a GROUNDED_HUB
	avatar.set_loadout_showcase_enabled(true, false)
	assert_true(not avatar.is_grounded_mode(), "Con Alas 3D activas debe salir de modo grounded")
	assert_true(rig.get_locomotion_mode() == PlanarCombatRig.LocomotionMode.ZERO_G_FLIGHT, "Con Alas 3D activas el rig debe pasar a ZERO_G_FLIGHT")

	avatar.set_loadout_showcase_enabled(false, false)
	assert_true(avatar.is_grounded_mode(), "Al apagar Alas 3D debe volver a modo grounded")
	assert_true(rig.get_locomotion_mode() == PlanarCombatRig.LocomotionMode.GROUNDED_HUB, "Al apagar Alas 3D el rig debe volver a GROUNDED_HUB")

	hub.queue_free()


func _test_motor_pivot_and_audio_sfx() -> void:
	var audio_mgr: Node = get_node_or_null("/root/AudioManager")
	assert_true(audio_mgr != null, "Autoload AudioManager debe existir")
	if audio_mgr != null:
		var streams: Dictionary = audio_mgr.get("sfx_streams") as Dictionary
		assert_true(streams.has("hub_footstep") and streams["hub_footstep"] != null, "AudioManager debe registrar 'hub_footstep'")

	var motor := HubGroundedMotor3DScript.new()
	var body := CharacterBody3D.new()
	add_child(body)

	var pivot_events: Array[float] = []
	motor.pivot_triggered.connect(func(s: float) -> void: pivot_events.append(s))

	# Acelerar hacia +X
	for _i: int in range(15):
		motor.step_velocity(body, Vector3.RIGHT, 0.016, null)
	assert_true(body.velocity.x > 3.5, "El motor debe acelerar hacia +X")

	# Invertir 180° hacia -X -> debe disparar pivote y frenar con fuerza
	var res: Dictionary = motor.step_velocity(body, Vector3.LEFT, 0.016, null)
	assert_true(bool(res.get("did_pivot", false)), "Un giro de 180° en velocidad debe disparar did_pivot")
	assert_true(pivot_events.size() == 1, "Debe emitirse pivot_triggered exactamente 1 vez")

	body.queue_free()

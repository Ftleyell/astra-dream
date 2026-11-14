extends BaseTestSuite

const PlanarCombatRigScript = preload("res://sandbox/pilot_rig_lab/proto/planar_combat_rig.gd")
const HudBuilderScript = preload("res://sandbox/pilot_rig_lab/proto/planar_lab_hud_builder.gd")
const ValentinaProfilePath: String = "res://sandbox/pilot_rig_lab/pilots/valentina/valentina_profile.tres"

func _ready() -> void:
	super._ready()
	_run_test()

func _run_test() -> void:
	# 1. Verificar carga data-driven de PilotRigProfile + presets .tres
	var scanned_profiles: Array[PilotRigProfile] = HudBuilderScript.scan_pilot_profiles()
	assert_true(scanned_profiles.size() >= 1, "Expected at least 1 PilotRigProfile scanned from pilots/*/*.tres")
	var profile: PilotRigProfile = ResourceLoader.load(ValentinaProfilePath) as PilotRigProfile
	assert_true(profile != null, "Expected valentina_profile.tres to load via ResourceLoader")
	assert_true(profile.skins.size() == 10, "Expected 10 PilotSkinPreset resources in valentina_profile.tres")
	assert_true(profile.hair_presets.size() == 10, "Expected 10 PilotHairPreset resources in valentina_profile.tres")
	assert_true(profile.style_profiles.size() == 9, "Expected 9 RigStyleProfile resources in valentina_profile.tres")
	assert_true(profile.skins[0].is_base_skin == true, "Skin 0 must have explicit is_base_skin == true")
	assert_true(profile.skins[3].is_base_skin == false, "Non-base skin must have is_base_skin == false")
	assert_true(profile.hair_presets[1].follow_skin_hair == true, "Hair preset 1 must have follow_skin_hair == true")

	# 2. Instanciar PlanarCombatRig con el perfil .tres
	var planar := PlanarCombatRigScript.new()
	planar.pilot_profile = profile
	add_child(planar)

	assert_true(planar.get_transition_style() == 4, "Default transition style must be WHIP_SNAP_AFTERIMAGE (4)")
	planar.set_transition_style(0)
	assert_true(planar.get_transition_style() == 4, "Legacy transition style 0 must clamp to snappy mode 4")

	var views: Dictionary = planar.get_views()
	assert_true(views.size() == 2 and views.has("s") and views.has("n") and not views.has("e"), "PlanarCombatRig must load exactly 2 views S and N")
	var root_s: Node2D = (views["s"] as Dictionary)["root"] as Node2D
	var root_n: Node2D = (views["n"] as Dictionary)["root"] as Node2D
	assert_true(root_s != null and not (root_s is CanvasGroup), "Body view S must be degraded to Node2D (no nested CanvasGroup)")
	assert_true(root_n != null and not (root_n is CanvasGroup), "Body view N must be degraded to Node2D (no nested CanvasGroup)")
	var unified_cg: CanvasGroup = planar.get_unified_canvas_group()
	assert_true(unified_cg != null and unified_cg.get_child_count() == 3, "Unified CanvasGroup must wrap HeadUnder -> BodyPivot -> HeadOver")
	assert_true(unified_cg.get_child(0).name == "DecoupledHeadUnderMount" and (unified_cg.get_child(0) as Node2D).z_index == 0, "HeadUnder must be child 0 with z_index 0")
	assert_true(unified_cg.get_child(1).name == "BodyPivot" and (unified_cg.get_child(1) as Node2D).z_index == 0, "BodyPivot must be child 1 with z_index 0")
	assert_true(unified_cg.get_child(2).name == "DecoupledHeadMount" and (unified_cg.get_child(2) as Node2D).z_index == 0, "HeadOver must be child 2 with z_index 0")
	var bp_init: Node2D = unified_cg.get_child(1) as Node2D
	assert_true(bp_init.get_child_count() == 3 and bp_init.get_child(bp_init.get_child_count() - 1).name == "HeadContactShadow", "HeadContactShadow must be last child of BodyPivot")
	assert_true((bp_init.get_child(bp_init.get_child_count() - 1) as Node2D).z_index == 0, "HeadContactShadow must use z_index 0 inside BodyPivot")

	var meshes_s: Node2D = root_s.get_node("Meshes") as Node2D
	var s_names: Array[String] = []
	for child_s: Node in meshes_s.get_children():
		assert_true((child_s as CanvasItem).z_index == 0, "Every Polygon2D in view S Meshes must have z_index 0")
		s_names.append(child_s.name)
	assert_true(s_names == ["Part_arm_l", "Part_leg_l", "Part_leg_r", "Part_arm_r", "Part_body_core", "Part_arm_r_over"], "View S Meshes must follow ascending z_orders with Part_arm_r_over last (got %s)" % str(s_names))

	var meshes_n: Node2D = root_n.get_node("Meshes") as Node2D
	var n_names: Array[String] = []
	for child_n: Node in meshes_n.get_children():
		assert_true((child_n as CanvasItem).z_index == 0, "Every Polygon2D in view N Meshes must have z_index 0")
		n_names.append(child_n.name)
	assert_true(n_names == ["Part_arm_r", "Part_leg_r", "Part_leg_l", "Part_body_core", "Part_arm_l"], "View N Meshes must follow ascending z_orders (got %s)" % str(n_names))

	assert_true(planar.get_node_or_null("VFXBehindLayer/ProceduralEnergyWings") != null, "ProceduralEnergyWings must live outside UnifiedCharacterGroup")
	assert_true(planar.get_node_or_null("VFXBehindLayer/BootThrusters") != null, "BootThrusters must live outside UnifiedCharacterGroup")
	assert_true(planar.get_pass2_material() != null, "Unified CanvasGroup must have Pasada 2 ShaderMaterial")
	var init_p2: ShaderMaterial = planar.get_pass2_material()
	assert_true(bool(init_p2.get_shader_parameter("enable_outer_outline")) == true, "Pass 2 must initialize with unified outer outline enabled")
	assert_true(absf(float(init_p2.get_shader_parameter("outer_outline_width_px")) - 1.45) < 0.01, "Pass 2 must initialize with medium outer_outline_width_px == 1.45")
	assert_true(absf(float(init_p2.get_shader_parameter("outer_outline_strength")) - 1.0) < 0.01, "Pass 2 must initialize with solid outer_outline_strength == 1.0")
	assert_true((init_p2.get_shader_parameter("outer_outline_color") as Color).is_equal_approx(Color(0.0, 0.0, 0.0, 1.0)), "Pass 2 must initialize with pure solid black outer_outline_color")
	assert_true(absf(float(init_p2.get_shader_parameter("outer_outline_tint_mix"))) < 0.001, "Pass 2 must initialize with outer_outline_tint_mix == 0.0 for solid black outline")
	assert_true(bool((views["s"] as Dictionary).get("is_parts_5", false)), "Body view S must be built from parts_5")

	# 3. Aplicar StyleProfile, SkinPreset, HairPreset y hit_flash
	var lit_col_before: Color = init_p2.get_shader_parameter("outer_outline_lit_color") as Color
	planar.apply_style_profile(profile.style_profiles[2])
	planar.apply_skin_preset(profile.skins[3])
	var lit_col_after: Color = init_p2.get_shader_parameter("outer_outline_lit_color") as Color
	assert_true(not lit_col_before.is_equal_approx(lit_col_after), "Changing PilotSkinPreset must update Pass 2 outer_outline_lit_color")
	var core_mat: ShaderMaterial = (views["s"] as Dictionary).get("body_core_mat", null) as ShaderMaterial
	assert_true(core_mat != null, "Expected body_core_mat on view S")
	assert_true(bool(core_mat.get_shader_parameter("enable_shader_recolor")) == true, "Shader recolor must activate on non-base skin")
	assert_true(int(core_mat.get_shader_parameter("pipeline_style_mode")) == 2, "Pipeline style mode must be 2")

	planar.apply_skin_preset(profile.skins[0])
	assert_true(bool(core_mat.get_shader_parameter("enable_shader_recolor")) == false, "Shader recolor must be off on base skin")

	planar.trigger_hit_flash(1.0)
	assert_true(absf(float(core_mat.get_shader_parameter("hit_flash")) - 1.0) < 0.01, "hit_flash must propagate to shader")
	planar._process(0.1)
	assert_true(float(core_mat.get_shader_parameter("hit_flash")) < 0.99, "hit_flash must decay over _process")
	planar.set_hit_flash(0.0)

	# 4. Estabilidad realista de cuello en vista N
	planar.set_locomotion_state(Vector2.UP, 0.75, Vector2(-0.92, -0.38), true)
	assert_true(planar.get_active_view_key() == "n", "Flying UP aiming diagonal-left must keep torso N")
	assert_true(planar.is_body_flipped() == false, "Flying UP aiming diagonal-left must NOT flip body horizontally")
	assert_true(planar.get_active_head_key() == "head_back_l", "Aiming diagonal-left on N should select head_back_l")

	planar.set_locomotion_state(Vector2.UP, 0.75, Vector2(0.95, 0.30), true)
	assert_true(planar.get_active_view_key() == "n", "Flying UP aiming slightly down-right must hold torso N")
	assert_true(planar.is_body_flipped() == false, "Flying UP aiming slightly down-right must NOT flip body horizontally")
	assert_true(planar.get_active_head_key() == "head_side_r", "Aiming down-right on N clamped neck cone should select head_side_r")

	# Anti-Exorcist Hybrid Backpedal
	planar.set_locomotion_state(Vector2.UP, 0.9, Vector2.DOWN, true)
	assert_true(planar.get_active_view_key() == "s", "Backpedal aiming hard DOWN must switch torso to S")
	assert_true(planar.get_active_head_key() == "head_front", "Backpedal aiming DOWN must keep head_front")

	# Anti-Nuca en torso frontal S
	planar.set_locomotion_state(Vector2.DOWN, 0.70, Vector2(-0.85, -0.52), true)
	assert_true(planar.get_active_view_key() == "s", "Moving DOWN aiming up-left must keep torso S")
	assert_true(planar.get_active_head_key() == "head_side_l", "Torso S aiming up-left must select profile head_side_l")

	planar.set_locomotion_state(Vector2.DOWN, 0.70, Vector2(0.85, -0.52), true)
	assert_true(planar.get_active_view_key() == "s", "Moving DOWN aiming up-right must keep torso S")
	assert_true(planar.get_active_head_key() == "head_side_r", "Torso S aiming up-right must select profile head_side_r")

	# 5. Máquina de estados PlanarRigAnimator
	planar.set_locomotion_state(Vector2.ZERO, 0.0, Vector2.DOWN, false)
	for _i: int in range(10):
		planar._process(0.05)
	assert_true(planar.get_active_anim_state_name() == "IDLE_HOVER", "Idle speed must resolve to IDLE_HOVER")

	planar.set_locomotion_state(Vector2.RIGHT, 0.85, Vector2.RIGHT, false)
	for _j: int in range(10):
		planar._process(0.05)
	assert_true(planar.get_active_anim_state_name() == "FLIGHT_STRAFE", "Horizontal flight must resolve to FLIGHT_STRAFE")

	planar.set_locomotion_state(Vector2.DOWN, 0.90, Vector2.DOWN, false)
	for _k: int in range(10):
		planar._process(0.05)
	assert_true(planar.get_active_anim_state_name() == "DESCEND", "Downward flight must resolve to DESCEND")

	planar.set_locomotion_state(Vector2.UP, 1.35, Vector2.UP, false)
	for _m: int in range(10):
		planar._process(0.05)
	assert_true(planar.get_active_anim_state_name() == "DASH_BOOST", "Boost speed > 1.05 must resolve to DASH_BOOST")

	# 6. Inspección estática y sanitización
	planar.set_static_inspection(true, "n", "head_back_r")
	var bp: Node2D = planar.get_body_pivot()
	assert_true(bp.scale.is_equal_approx(Vector2.ONE), "Static inspection must reset BodyPivot scale to ONE")
	assert_true(absf(bp.rotation) < 0.001, "Static inspection must reset BodyPivot rotation to 0")
	assert_true(planar.get_active_view_key() == "n", "Static inspection must switch active body view to 'n'")
	assert_true(planar.get_active_head_key() == "head_back_r", "Static inspection must switch active head to 'head_back_r'")

	planar.set_static_inspection(true, "s", "head_back")
	assert_true(not planar.get_active_head_key().begins_with("head_back"), "Front body 's' must never allow head_back*")
	planar.set_static_inspection(true, "n", "head_front")
	assert_true(planar.get_active_head_key() != "head_front", "Back body 'n' must never allow head_front")
	planar.set_static_inspection(false)

	# 7. Los 3 modos snappy (4, 5, 6) desacoplan Pass 1 vs Pass 2, sincronizan cuerpo+cabeza y whiplash
	var p2_mat_snap: ShaderMaterial = planar.get_pass2_material()
	for style_id: int in [4, 5, 6]:
		planar.set_transition_style(style_id)
		planar.set_locomotion_state(Vector2.DOWN, 0.75, Vector2.DOWN, true)
		planar.set_locomotion_state(Vector2.UP, 0.75, Vector2(-0.9, -0.3), false)
		var saw_snap: bool = false
		var saw_fx: bool = false
		for _step: int in range(15):
			planar._process(0.016)
			if planar.is_snap_active():
				if not saw_snap:
					saw_snap = true
					var ha: Node2D = planar.get_head_anchor()
					var snap_xy: Vector2 = planar.get_snap_scale_xy()
					assert_true(absf(ha.scale.x - snap_xy.x) < 0.001, "Style %d must propagate snap scale to _head_anchor" % style_id)
					assert_true(absf(bp.scale.x - snap_xy.x) < 0.06, "Style %d must keep _body_pivot scale synced with snap_scale_xy" % style_id)
					assert_true(planar.is_whiplash_active(), "Style %d must activate limb whiplash on body change" % style_id)
					assert_true(bool(core_mat.get_shader_parameter("enable_secondary_jiggle")), "body_core must enable secondary jiggle mask")
				var mat_s: ShaderMaterial = ((views["s"] as Dictionary).get("materials", []) as Array)[0] as ShaderMaterial
				var p1_mode: int = int(mat_s.get_shader_parameter("transition_fx_mode"))
				var p2_smear: float = float(p2_mat_snap.get_shader_parameter("smear_strength"))
				var p2_holo: float = float(p2_mat_snap.get_shader_parameter("holo_sweep_strength"))
				if style_id == 4:
					if p1_mode == 0 and p2_smear > 0.01:
						saw_fx = true
				elif style_id == 5:
					if p1_mode == 2 and p2_smear <= 0.001:
						saw_fx = true
				else:
					if p1_mode == 3 and p2_smear <= 0.001 and p2_holo <= 0.001:
						saw_fx = true
		assert_true(saw_snap, "Style %d must activate unified snap transition" % style_id)
		assert_true(saw_fx, "Style %d must apply decoupled Pass 1 / Pass 2 shader FX" % style_id)
		for _t: int in range(10):
			planar._process(0.02)
		assert_true(not planar.is_snap_active(), "Style %d must finish cleanly within ~200ms" % style_id)
		assert_true(not planar.is_whiplash_active(), "Style %d limb whiplash must settle cleanly within ~200ms" % style_id)

	# 8. Cambio solo de cabeza activa micro-snap en cabeza pero NO dispara snap_active ni whiplash
	planar.set_transition_style(4)
	planar.set_locomotion_state(Vector2.DOWN, 0.75, Vector2.DOWN, true)
	planar.set_locomotion_state(Vector2.DOWN, 0.75, Vector2(0.95, 0.1), false)
	var saw_head_micro: bool = false
	for _h_step: int in range(10):
		planar._process(0.016)
		assert_true(not planar.is_snap_active(), "Head-only aim change must NOT activate snap_active")
		assert_true(not planar.is_whiplash_active(), "Head-only aim change must NOT activate whiplash_active")
		if planar.is_head_micro_snap_active():
			saw_head_micro = true
	assert_true(saw_head_micro, "Head-only aim change must trigger subtle head micro-snap")
	assert_true(planar.get_active_head_key() == "head_side_r", "Head-only aim change must switch to head_side_r cleanly")

	# 9. Cobertura de cabezas 8 direcciones
	var head_sprites: Dictionary = (planar.get_head_data()).get("sprites", {}) as Dictionary
	assert_true(head_sprites.has("head_front_l") and head_sprites.has("head_front_r"), "8-dir heads must load head_front_l and head_front_r")
	planar.set_locomotion_state(Vector2.DOWN, 0.75, Vector2(-0.55, 0.83), true)
	assert_true(planar.get_active_head_key() == "head_front_l", "Aiming down-left on S must select head_front_l")
	planar.set_locomotion_state(Vector2.DOWN, 0.75, Vector2(0.55, 0.83), true)
	assert_true(planar.get_active_head_key() == "head_front_r", "Aiming down-right on S must select head_front_r")
	planar.set_locomotion_state(Vector2.UP, 0.75, Vector2.UP, true)
	assert_true(planar.get_active_head_key() == "head_back", "Aiming straight UP on N must select head_back")
	planar.set_locomotion_state(Vector2.UP, 0.75, Vector2.RIGHT, true)
	assert_true(planar.get_active_head_key() == "head_side_r", "Aiming straight RIGHT on N must select head_side_r")
	planar.set_locomotion_state(Vector2.UP, 0.75, Vector2.LEFT, true)
	assert_true(planar.get_active_head_key() == "head_side_l", "Aiming straight LEFT on N must select head_side_l")
	planar.set_locomotion_state(Vector2.DOWN, 0.75, Vector2.RIGHT, true)
	assert_true(planar.get_active_head_key() == "head_side_r", "Aiming straight RIGHT on S must select head_side_r")
	planar.set_locomotion_state(Vector2.DOWN, 0.75, Vector2.LEFT, true)
	assert_true(planar.get_active_head_key() == "head_side_l", "Aiming straight LEFT on S must select head_side_l")

	# 10. Física secundaria 2D (drag de vuelo + cabello reactivo al frenar)
	planar.set_locomotion_state(Vector2.ZERO, 0.0, Vector2.DOWN, true)
	planar.set_locomotion_state(Vector2.RIGHT, 1.0, Vector2.DOWN, false)
	for _d_step: int in range(12):
		planar._process(0.016)
	assert_true(planar.get_secondary_jiggle_pos_l().x < -1.0, "Accelerating RIGHT must produce negative-X secondary drag")
	planar.set_locomotion_state(Vector2.ZERO, 0.0, Vector2.DOWN, false)
	for _b_step: int in range(4):
		planar._process(0.016)
	assert_true(planar.get_hair_jiggle_pos().length() > 1.0, "Hair must reactively kick on braking")

	# 11. Hair presets (original vs follow_skin vs override) y recarga de perfil en runtime
	planar.apply_hair_preset(profile.hair_presets[2], profile.skins[0].hair_color)
	assert_true(bool(core_mat.get_shader_parameter("enable_hair_recolor")) == true, "Override hair preset must enable hair recolor")
	planar.apply_hair_preset(profile.hair_presets[0], profile.skins[0].hair_color)
	assert_true(bool(core_mat.get_shader_parameter("enable_hair_recolor")) == false, "Original hair preset must disable hair recolor")

	planar.load_pilot_profile(profile)
	assert_true(planar.get_child_count() == 2, "load_pilot_profile must cleanly replace children (VFXBehindLayer + UnifiedCharacterGroup) without stale nodes")

	# 12. Doble Reloj (q_time a 15/12/60 FPS, Skeleton2D fluido a 60+ FPS, Head Follow-Through)
	assert_true(absf(planar.get_stepped_fps() - 15.0) < 0.01, "Default stepped_fps must be 15.0")
	var q0: float = planar.get_q_time()
	planar.set_locomotion_state(Vector2.RIGHT, 0.85, Vector2.RIGHT, true)
	var shoulder_s: Bone2D = ((planar.get_views()["s"] as Dictionary)["bones"] as Dictionary)["Shoulder_R"] as Bone2D
	var rot_before: float = shoulder_s.rotation
	planar._process(0.016)
	planar._process(0.016)
	assert_true(absf(planar.get_q_time() - q0) < 0.0001, "q_time must hold between 15 FPS ticks (< 66.7ms)")
	assert_true(absf(shoulder_s.rotation - rot_before) > 0.0001, "Skeleton2D must animate fluidly at 60+ FPS even when q_time is 15 FPS")
	planar._process(0.040)
	assert_true(planar.get_q_time() > q0 + 0.05, "q_time must advance on 15 FPS tick")

	planar.set_stepped_fps(60.0)
	var q_60: float = planar.get_q_time()
	planar._process(0.016)
	assert_true(planar.get_q_time() > q_60 + 0.01, "60 FPS mode must advance q_time every frame")

	planar.set_stepped_fps(12.0)
	var q_12: float = planar.get_q_time()
	planar._process(0.040)
	assert_true(absf(planar.get_q_time() - q_12) < 0.0001, "12 FPS mode must hold q_time at 40ms (< 83.3ms)")
	planar._process(0.050)
	assert_true(planar.get_q_time() > q_12 + 0.05, "12 FPS mode must advance q_time after 90ms")
	planar.set_stepped_fps(15.0)

	# Head snap sync (default head_snap_lag_sec == 0.0) & follow-through opt-in
	planar.set_locomotion_state(Vector2(0.25, 0.97), 0.75, Vector2(0.0, 1.0), true)
	assert_true(planar.get_active_view_key() == "s" and planar.get_active_head_key() == "head_front", "Precondition: S + head_front")
	planar.set_locomotion_state(Vector2(0.25, -0.97), 0.75, Vector2(0.0, -1.0), false)
	for _sync_step: int in range(10):
		planar._process(0.016)
	assert_true(not planar.is_head_follow_through_pending(), "Default head_snap_lag_sec == 0.0 must keep head synced with body")
	assert_true(planar.get_active_view_key() == "n" and planar.get_active_head_key() == "head_back", "Synced turn S -> N must settle to head_back")

	var orig_lag: float = profile.anim_config.head_snap_lag_sec
	profile.anim_config.head_snap_lag_sec = 0.042
	planar.set_locomotion_state(Vector2(0.25, 0.97), 0.75, Vector2(0.0, 1.0), true)
	for _rst_step: int in range(10):
		planar._process(0.016)
	planar.set_locomotion_state(Vector2(0.25, -0.97), 0.75, Vector2(0.0, -1.0), false)
	var saw_follow_through_pending: bool = false
	for _ft_step: int in range(25):
		planar._process(0.016)
		if planar.is_head_follow_through_pending():
			saw_follow_through_pending = true
			assert_true(planar.get_active_view_key() == "n", "Body must already be N when follow-through is pending")
			assert_true(planar.get_active_head_key() != "head_back", "Head must lag behind body target during follow-through")
			break
	assert_true(saw_follow_through_pending, "Body turn S -> N with lag > 0 must trigger head follow-through pending state")
	for _ft_settle: int in range(20):
		planar._process(0.025)
	assert_true(not planar.is_head_follow_through_pending(), "Head follow-through must clear after lag window")
	assert_true(planar.get_active_head_key() == "head_back", "Head must settle to head_back after follow-through")
	profile.anim_config.head_snap_lag_sec = orig_lag

	# 13. Pasada 2: Impact Frames (2 fases) + Hit-Stop local (sin Engine.time_scale) + Outline
	planar.trigger_impact_frame(55.0, 6.0)
	assert_true(planar.is_hit_stop_active(), "trigger_impact_frame must activate local hit-stop")
	assert_true(planar.get_impact_frame_phase() == 1, "Impact frame must start in phase 1 (B/W directo)")
	assert_true(absf(Engine.time_scale - 1.0) < 0.001, "Local hit-stop must NEVER mutate Engine.time_scale")
	planar._process(0.030)
	assert_true(planar.get_impact_frame_phase() == 2, "Impact frame must transition to phase 2 (invertido + rayos)")
	assert_true(planar.get_unified_canvas_group().position.length() > 0.1, "Local hit-stop must apply orthogonal shake")
	planar._process(0.030)
	assert_true(not planar.is_hit_stop_active() and planar.get_impact_frame_phase() == 0, "Local hit-stop must finish cleanly after ~55ms")
	assert_true(planar.get_unified_canvas_group().position.is_equal_approx(Vector2.ZERO), "UnifiedCharacterGroup position must reset to ZERO after hit-stop")

	planar.set_outer_outline_params(true, 3.5, 0.85)
	var p2_mat: ShaderMaterial = planar.get_pass2_material()
	assert_true(absf(float(p2_mat.get_shader_parameter("outer_outline_width_px")) - 3.5) < 0.01, "Pass 2 outer_outline_width_px must update")
	assert_true(absf(float(p2_mat.get_shader_parameter("outer_outline_strength")) - 0.85) < 0.01, "Pass 2 outer_outline_strength must update")

	# Verificar que impact_center_uv sigue a global_position y que set_static_inspection limpia hit-stop activo
	planar.position = Vector2(320.0, 180.0)
	planar.trigger_impact_frame(55.0, 6.0)
	var center_uv: Vector2 = p2_mat.get_shader_parameter("impact_center_uv") as Vector2
	assert_true(not center_uv.is_equal_approx(Vector2(0.5, 0.5)), "impact_center_uv must track rig viewport position")
	planar.set_static_inspection(true, "s", "head_front")
	assert_true(not planar.is_hit_stop_active() and planar.get_impact_frame_phase() == 0, "set_static_inspection must cancel active hit-stop")
	assert_true(planar.get_unified_canvas_group().position.is_equal_approx(Vector2.ZERO), "set_static_inspection must reset UnifiedCharacterGroup shake offset")
	planar.set_static_inspection(false)
	planar.position = Vector2.ZERO

	# 14. Resortes amortiguados de 2do orden (overshoot controlado + convergencia)
	var sp_x: float = 0.0
	var sp_v: float = 0.0
	var saw_overshoot: bool = false
	for _sp_i: int in range(40):
		var res: Vector2 = PlanarRigAnimator.step_spring(sp_x, sp_v, 1.0, 18.0, 0.55, 0.016)
		sp_x = res.x
		sp_v = res.y
		if sp_x > 1.02:
			saw_overshoot = true
	assert_true(saw_overshoot, "Underdamped 2nd-order spring (zeta=0.55) must produce organic overshoot > 1.0")
	assert_true(absf(sp_x - 1.0) < 0.05, "2nd-order spring must converge near target after settling")

	# 15. Límites asimétricos por vista S vs N (Wrist_L en vista N no recortado a medio ciclo)
	var cfg: PlanarRigAnimConfig = planar.get_anim_config()
	assert_true(cfg != null, "PlanarCombatRig must expose loaded PlanarRigAnimConfig")
	planar.set_locomotion_state(Vector2.UP, 0.85, Vector2.UP, true)
	var wrist_l_n: Bone2D = ((views["n"] as Dictionary)["bones"] as Dictionary)["Wrist_L"] as Bone2D
	var wrist_l_rest_n: float = float(((views["n"] as Dictionary)["rest_rots"] as Dictionary).get("Wrist_L", 0.0))
	var saw_neg_wrist: bool = false
	var saw_pos_wrist: bool = false
	for _w_i: int in range(60):
		planar._process(0.03)
		var wd: float = wrist_l_n.rotation - wrist_l_rest_n
		assert_true(wd >= cfg.n_wrist_l_limits.x - 0.001 and wd <= cfg.n_wrist_l_limits.y + 0.001, "Wrist_L in view N must respect n_wrist_l_limits")
		if wd < -0.01:
			saw_neg_wrist = true
		if wd > 0.01:
			saw_pos_wrist = true
	assert_true(saw_neg_wrist and saw_pos_wrist, "Wrist_L in view N must swing across both negative and positive cycle (no maxf(0, -rot) clip)")

	# 16. Capas aditivas de combate y locomoción (dash_burst, attack_recoil, hit_react, launch, air_brake)
	planar.set_locomotion_state(Vector2.ZERO, 0.0, Vector2.DOWN, true)
	planar.set_locomotion_state(Vector2.RIGHT, 0.90, Vector2.RIGHT, false)
	planar._process(0.016)
	assert_true(planar.is_launch_active(), "Sudden takeoff (0 -> 0.90) must trigger Launch additive layer")

	for _ab_wait: int in range(10):
		planar._process(0.02)
	planar.set_locomotion_state(Vector2.LEFT, 0.95, Vector2.RIGHT, false)
	planar._process(0.016)
	assert_true(planar.is_air_brake_active(), "Sudden 180-deg reversal must trigger Air-Brake additive layer")

	planar.trigger_dash_burst(Vector2.RIGHT)
	assert_true(planar.is_dash_burst_active(), "trigger_dash_burst must activate dash burst layer")
	planar._process(0.016)
	planar.trigger_attack_recoil(Vector2.RIGHT, 1.0)
	assert_true(planar.is_attack_recoil_active(), "trigger_attack_recoil must activate attack recoil layer")
	planar.trigger_hit_react(Vector2.LEFT, 1.0)
	assert_true(planar.is_hit_react_active(), "trigger_hit_react must activate hit react layer")
	assert_true(planar.get_hit_flash() > 0.2, "trigger_hit_react must trigger hit_flash")
	for _ev_settle: int in range(25):
		planar._process(0.02)
	assert_true(not planar.is_dash_burst_active() and not planar.is_attack_recoil_active() and not planar.is_hit_react_active(), "All additive combat layers must settle cleanly")

	# 17. Cabeza viva: seguimiento real de Neck + micro-resorte 2D
	planar.set_locomotion_state(Vector2.DOWN, 0.0, Vector2.RIGHT, true)
	planar._process(0.016)
	var ha_alive: Node2D = planar.get_head_anchor()
	planar.trigger_attack_recoil(Vector2.RIGHT, 1.2)
	var saw_head_lag: bool = false
	var saw_neck_rot: bool = false
	for _hd_i: int in range(10):
		planar._process(0.016)
		if planar.get_head_spring_offset().length() > 0.05:
			saw_head_lag = true
		if absf(ha_alive.rotation) > 0.005:
			saw_neck_rot = true
	assert_true(saw_head_lag, "Head 2D micro-spring must react to impulses")
	assert_true(saw_neck_rot, "Head anchor rotation must track Neck bone + recoil even when stationary")

	# Steady constant-velocity flight must not pin head_spring_offset at head_max_lag_px
	planar.set_locomotion_state(Vector2.RIGHT, 1.0, Vector2.RIGHT, true)
	for _steady_i: int in range(60):
		planar.position += Vector2(220.0, 0.0) * 0.016
		planar._process(0.016)
	assert_true(planar.get_head_spring_offset().length() < 0.75, "Head 2D micro-spring must settle near ZERO during steady constant-velocity flight")

	# 18. Mejoras Bloque 1-3: part_rig_rect real, continuidad Modo 6, siluetas reales, sombra cuello, zoom_scale, contrapposto e inercia lateral
	var head_front_spr: Sprite2D = (planar.get_head_data().get("sprites", {}) as Dictionary).get("head_front", null) as Sprite2D
	assert_true(head_front_spr != null and head_front_spr.material is ShaderMaterial, "head_front must have ShaderMaterial")
	var h_rect: Vector4 = (head_front_spr.material as ShaderMaterial).get_shader_parameter("part_rig_rect") as Vector4
	assert_true(h_rect.y > -0.45, "Head part_rig_rect.y must use real neck_anchor - rig_origin (~-0.37, not hardcoded -0.51)")

	var trans_ctrl := PlanarRigTransitionController.new()
	var c_before: Dictionary = trans_ctrl.compute_snap_curve(6, 0.4499)
	var c_after: Dictionary = trans_ctrl.compute_snap_curve(6, 0.4501)
	assert_true(absf((c_before["scale"] as Vector2).y - (c_after["scale"] as Vector2).y) < 0.01, "Mode 6 sy must be continuous across t=0.45")

	var shadow_spr: Sprite2D = planar.get_head_contact_shadow()
	assert_true(shadow_spr != null and shadow_spr.z_index == 0, "HeadContactShadow must exist inside BodyPivot with z_index 0")
	planar.set_normal_depth_options(true, Vector2(1.0, 0.0), 0.9, 1.2)
	planar._process(0.016)
	var sh_pos_r: Vector2 = shadow_spr.position
	planar.set_normal_depth_options(true, Vector2(-1.0, 0.0), 0.9, 1.2)
	planar._process(0.016)
	assert_true(sh_pos_r.distance_to(shadow_spr.position) > 2.0, "HeadContactShadow must shift opposite to light_dir_2d")

	planar.set_zoom_scale(0.65)
	assert_true(absf(float(p2_mat.get_shader_parameter("zoom_scale")) - 0.65) < 0.01, "Pass 2 zoom_scale must update")
	var p2_light: Vector2 = p2_mat.get_shader_parameter("light_dir_2d") as Vector2
	assert_true(p2_light.x < -0.5, "Pass 2 light_dir_2d must sync with set_normal_depth_options")

	# Siluetas reales (Sandevistan trail capped <= 5)
	planar.enable_afterimage = true
	planar.set_locomotion_state(Vector2.RIGHT, 1.35, Vector2.RIGHT, true)
	for _g_i: int in range(16):
		planar._process(0.04)
	assert_true(planar.get_active_ghost_count() > 0 and planar.get_active_ghost_count() <= 5, "Real silhouette ghosts must spawn and stay capped <= 5")

	# Micro-inercia lateral en BodyPivot.position.x durante banking
	assert_true(absf(planar.get_body_pivot().position.x) > 0.5, "BodyPivot.position.x must exhibit lateral banking inertia during horizontal flight")

	# Contrapposto en IDLE_HOVER (asimetría real de rodillas y pelvis)
	planar.set_locomotion_state(Vector2.DOWN, 0.0, Vector2.DOWN, true)
	for _idle_i: int in range(45):
		planar._process(0.02)
	var s_bones: Dictionary = (planar.get_views()["s"] as Dictionary)["bones"] as Dictionary
	var s_rest: Dictionary = (planar.get_views()["s"] as Dictionary)["rest_rots"] as Dictionary
	var kr_delta: float = (s_bones["Knee_R"] as Bone2D).rotation - float(s_rest.get("Knee_R", 0.0))
	var kl_delta: float = (s_bones["Knee_L"] as Bone2D).rotation - float(s_rest.get("Knee_L", 0.0))
	var pel_delta: float = (s_bones["Pelvis"] as Bone2D).rotation - float(s_rest.get("Pelvis", 0.0))
	assert_true(absf(kr_delta - kl_delta) > 0.05, "IDLE_HOVER must apply real contrapposto asymmetry between Knee_R and Knee_L")
	assert_true(absf(pel_delta) > 0.01, "IDLE_HOVER must apply subtle Pelvis contrapposto tilt")

	# Diferenciación simétrica de hombros en vista N (ambos brazos abren silueta hacia afuera)
	planar.set_locomotion_state(Vector2.UP, 0.40, Vector2.UP, true)
	for _nv_i: int in range(30):
		planar._process(0.02)
	var n_bones: Dictionary = (views["n"] as Dictionary)["bones"] as Dictionary
	var n_rest: Dictionary = (views["n"] as Dictionary)["rest_rots"] as Dictionary
	var sh_r_n: float = (n_bones["Shoulder_R"] as Bone2D).rotation - float(n_rest.get("Shoulder_R", 0.0))
	var sh_l_n: float = (n_bones["Shoulder_L"] as Bone2D).rotation - float(n_rest.get("Shoulder_L", 0.0))
	assert_true(sh_r_n > 0.05 and sh_l_n < -0.05, "View N must open both Shoulder_R (>0) and Shoulder_L (<0) outward symmetrically")

	# Tracking sutil del brazo delantero hacia _aim_dir en BACKPEDAL_FOCUS respetando s_shoulder_r_limits
	planar.set_locomotion_state(Vector2.RIGHT, 0.75, Vector2(-0.97, -0.24).normalized(), true)
	for _bp_up: int in range(25):
		planar._process(0.02)
	var sh_r_aim_up: float = (s_bones["Shoulder_R"] as Bone2D).rotation - float(s_rest.get("Shoulder_R", 0.0))
	planar.set_locomotion_state(Vector2.RIGHT, 0.75, Vector2(-0.70, 0.71).normalized(), true)
	for _bp_dn: int in range(25):
		planar._process(0.02)
	var sh_r_aim_dn: float = (s_bones["Shoulder_R"] as Bone2D).rotation - float(s_rest.get("Shoulder_R", 0.0))
	assert_true(sh_r_aim_up > sh_r_aim_dn + 0.04, "BACKPEDAL_FOCUS must track front Shoulder_R toward aim_dir.y")
	assert_true(sh_r_aim_up <= cfg.s_shoulder_r_limits.y + 0.001 and sh_r_aim_dn >= cfg.s_shoulder_r_limits.x - 0.001, "Front arm tracking must respect s_shoulder_r_limits")

	# 19. Blindaje de Outline, Mipmaps Selectivos, Alineación s/leg_r y Sincronía hair_jiggle HeadUnder
	var s_polys: Dictionary = (planar.get_views()["s"] as Dictionary).get("polys", {}) as Dictionary
	var leg_r_poly: Polygon2D = s_polys.get("leg_r", null) as Polygon2D
	assert_true(leg_r_poly != null and leg_r_poly.texture != null, "Expected s/leg_r Polygon2D and color texture")
	var leg_r_mat: ShaderMaterial = leg_r_poly.material as ShaderMaterial
	var leg_r_id_tex: Texture2D = leg_r_mat.get_shader_parameter("id_mask_tex") as Texture2D
	var leg_r_nd_tex: Texture2D = leg_r_mat.get_shader_parameter("normal_depth_tex") as Texture2D
	assert_true(leg_r_poly.texture.get_size() == Vector2(270.0, 731.0), "s/leg_r color texture must be 270x731")
	assert_true(leg_r_id_tex != null and leg_r_id_tex.get_size() == Vector2(270.0, 731.0), "s/leg_r_id_mask must match 270x731 after [8:739] crop")
	assert_true(leg_r_nd_tex != null and leg_r_nd_tex.get_size() == Vector2(270.0, 731.0), "s/leg_r_normal_depth must match 270x731 after [8:739] crop")
	assert_true(leg_r_poly.texture.get_image().has_mipmaps(), "Body color texture must have mipmaps generated")
	assert_true(leg_r_id_tex.get_image().has_mipmaps(), "Body id_mask texture must have mipmaps generated")
	assert_true(leg_r_nd_tex.get_image().has_mipmaps(), "Body normal_depth texture must have mipmaps generated")

	var hf_mat: ShaderMaterial = head_front_spr.material as ShaderMaterial
	var hf_sdf_tex: Texture2D = hf_mat.get_shader_parameter("head_outline_sdf_tex") as Texture2D
	assert_true(head_front_spr.texture.get_image().has_mipmaps(), "Head color texture must have mipmaps generated")
	assert_true(hf_sdf_tex != null and not hf_sdf_tex.get_image().has_mipmaps(), "Head _outline_sdf texture must NOT generate mipmaps")

	planar.set_locomotion_state(Vector2.RIGHT, 1.25, Vector2.DOWN, false)
	for _hj_i: int in range(6):
		planar._process(0.016)
	var hu_mats: Array = planar.get_head_under_data().get("materials", []) as Array
	assert_true(not hu_mats.is_empty(), "Expected _head_under_data materials")
	var hu_mat: ShaderMaterial = hu_mats[0] as ShaderMaterial
	var h_over_jiggle: Vector2 = hf_mat.get_shader_parameter("secondary_jiggle_l_px") as Vector2
	var h_under_jiggle: Vector2 = hu_mat.get_shader_parameter("secondary_jiggle_l_px") as Vector2
	assert_true(bool(hu_mat.get_shader_parameter("enable_secondary_jiggle")), "_head_under_data must enable secondary_jiggle")
	assert_true(h_over_jiggle.is_equal_approx(h_under_jiggle) and h_under_jiggle.length() > 0.1, "_head_under_data must sync hair_jiggle offset with _head_data")

	var s_arm_l_poly: Polygon2D = s_polys.get("arm_l", null) as Polygon2D
	var n_polys: Dictionary = (views["n"] as Dictionary).get("polys", {}) as Dictionary
	var n_arm_r_poly: Polygon2D = n_polys.get("arm_r", null) as Polygon2D
	assert_true(s_arm_l_poly != null and n_arm_r_poly != null, "Expected back arm Polygon2D nodes (s/arm_l and n/arm_r)")
	var s_arm_l_img: Image = s_arm_l_poly.texture.get_image()
	var n_arm_r_img: Image = n_arm_r_poly.texture.get_image()
	var s_arm_l_luma: float = _sample_opaque_luma(s_arm_l_img, 0, 0, s_arm_l_img.get_width() / 2, s_arm_l_img.get_height() / 2)
	var n_arm_r_luma: float = _sample_opaque_luma(n_arm_r_img, n_arm_r_img.get_width() / 2, 0, n_arm_r_img.get_width(), n_arm_r_img.get_height() / 2)
	assert_true(s_arm_l_luma > 0.08, "s/arm_l upper-inner overlap zone must not be pure black ink (luma=%.3f)" % s_arm_l_luma)
	assert_true(n_arm_r_luma > 0.08, "n/arm_r upper-inner overlap zone must not be pure black ink (luma=%.3f)" % n_arm_r_luma)
	var s_arm_l_lower_luma: float = _sample_opaque_luma(s_arm_l_img, 0, s_arm_l_img.get_height() / 2, s_arm_l_img.get_width(), s_arm_l_img.get_height())
	var n_arm_r_lower_luma: float = _sample_opaque_luma(n_arm_r_img, 0, n_arm_r_img.get_height() / 2, n_arm_r_img.get_width(), n_arm_r_img.get_height())
	assert_true(s_arm_l_lower_luma > 0.14, "s/arm_l visible forearm/hand must maintain suit tone without thick black crush (luma=%.3f)" % s_arm_l_lower_luma)
	assert_true(n_arm_r_lower_luma > 0.14, "n/arm_r visible forearm/hand must maintain suit tone without thick black crush (luma=%.3f)" % n_arm_r_lower_luma)

	pass_suite("PlanarCombatRig + 60fps Fluid Springs + View Limits + Additive Events + Alive Head verified.")


func _sample_opaque_luma(img: Image, x0: int, y0: int, x1: int, y1: int) -> float:
	var sum_luma: float = 0.0
	var count: int = 0
	for y: int in range(y0, y1, 4):
		for x: int in range(x0, x1, 4):
			var c: Color = img.get_pixel(x, y)
			if c.a >= 0.5:
				sum_luma += 0.299 * c.r + 0.587 * c.g + 0.114 * c.b
				count += 1
	return (sum_luma / float(count)) if count > 0 else 0.0

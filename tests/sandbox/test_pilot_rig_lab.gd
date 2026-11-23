extends BaseTestSuite

const PlanarCombatRigScript = preload("res://scenes/pilots/rig/planar_combat_rig.gd")
const HudBuilderScript = preload("res://sandbox/pilot_rig_lab/proto/planar_lab_hud_builder.gd")
const RigCalibrationStoreScript = preload("res://sandbox/pilot_rig_lab/calibrator/rig_calibration_store.gd")
const BasePoseConfigScript = preload("res://data/pilots/schemas/pilot_base_pose_config.gd")
const IdleAnimConfigScript = preload("res://data/pilots/schemas/pilot_idle_anim_config.gd")
const LocomotionAnimConfigScript = preload("res://data/pilots/schemas/pilot_locomotion_anim_config.gd")
const KitingAnimConfigScript = preload("res://data/pilots/schemas/pilot_kiting_anim_config.gd")
const TurnAnimConfigScript = preload("res://data/pilots/schemas/pilot_turn_anim_config.gd")
const JigglePhysicsConfigScript = preload("res://data/pilots/schemas/pilot_jiggle_physics_config.gd")
const BasePoseEvaluatorScript = preload("res://scenes/pilots/rig/planar_rig_base_pose_evaluator.gd")
const KitingEvaluatorScript = preload("res://scenes/pilots/rig/planar_rig_kiting_evaluator.gd")
const ValentinaV2ProfilePath: String = "res://data/pilots/valentina_v2/valentina_v2_profile.tres"
const ValentinaV2BasePosePath: String = "res://data/pilots/valentina_v2/valentina_v2_base_pose.tres"
const ValentinaV2IdleAnimPath: String = "res://data/pilots/valentina_v2/valentina_v2_idle_anim.tres"
const ValentinaV2LocomotionPath: String = "res://data/pilots/valentina_v2/valentina_v2_locomotion_anim.tres"
const ValentinaV2KitingPath: String = "res://data/pilots/valentina_v2/valentina_v2_kiting_anim.tres"
const ValentinaV2TurnAnimPath: String = "res://data/pilots/valentina_v2/valentina_v2_turn_anim.tres"
const ValentinaV2JigglePath: String = "res://data/pilots/valentina_v2/valentina_v2_jiggle_physics.tres"


func _ready() -> void:
	super._ready()
	_run_test()


func _run_test() -> void:
	var profile: PilotRigProfile = _test_profile_and_metrics()
	var planar: PlanarCombatRig = _test_rig_hierarchy_and_8dir(profile)
	var init_p2: ShaderMaterial = _test_materials_pass2_and_impact(planar, profile)
	_test_masks_and_profile_geometry(planar)
	_test_8dir_routing_and_backpedal(planar)
	_test_head_combo_transforms(planar)
	_test_orientation_transitions(planar, init_p2)
	_test_purged_subsystems(planar)
	_test_native_live_animations(profile)
	_test_lab_scene_and_matrix()
	_test_calibrator_scene_and_store()
	_test_shader_lab_scene()
	_test_base_pose_config_and_evaluator(planar)
	_test_kiting_360_system(profile, planar)
	_test_forward_flight_parallel_legs(planar)
	pass_suite("Valentina v2 (8-Dir) purged rig + pure direction routing + masks + Lab HUD + Calibrator + ShaderLab + BasePose + Kiting 360 verified.")


func _test_profile_and_metrics() -> PilotRigProfile:
	var scanned_profiles: Array[PilotRigProfile] = HudBuilderScript.scan_pilot_profiles()
	assert_true(scanned_profiles.size() == 1 and scanned_profiles[0].pilot_id == "valentina_v2", "Expected ONLY valentina_v2 in pilots/*/*.tres (got %d)" % scanned_profiles.size())

	var profile: PilotRigProfile = ResourceLoader.load(ValentinaV2ProfilePath) as PilotRigProfile
	assert_true(profile != null, "Expected valentina_v2_profile.tres to load via ResourceLoader")
	assert_true(profile.skins.size() == 10, "Expected 10 PilotSkinPreset resources in valentina_v2_profile.tres")
	assert_true(profile.hair_presets.size() == 10, "Expected 10 PilotHairPreset resources in valentina_v2_profile.tres")
	assert_true(profile.style_profiles.size() == 3, "Expected 3 RigStyleProfile resources (00_original + 01_valentina_definitive + 02_valentina_razor_sharp) in valentina_v2_profile.tres")
	assert_true(profile.style_profiles[0].id == "00_original" and profile.style_profiles[0].stylize_enabled == false, "Style 0 must be clean 00_original baseline")
	assert_true(profile.style_profiles[1].id == "01_valentina_definitive" and profile.style_profiles[1].stylize_enabled == true, "Style 1 must be 01_valentina_definitive")
	assert_true(profile.style_profiles[2].id == "02_valentina_razor_sharp" and profile.style_profiles[2].stylize_enabled == true, "Style 2 must be 02_valentina_razor_sharp")
	assert_true(profile.style_profiles[2].albedo_lod_bias < -0.4 and profile.style_profiles[2].cas_sharpen_strength > 0.3 and profile.style_profiles[2].ign_jitter_strength <= 0.01, "Style 2 must configure razor-sharp LOD bias, CAS sharpen, and zero IGN jitter")
	assert_true(profile.skins[0].is_base_skin == true, "Skin 0 must have explicit is_base_skin == true")
	assert_true(profile.skins[3].is_base_skin == false, "Non-base skin must have is_base_skin == false")
	assert_true(profile.hair_presets[1].follow_skin_hair == true, "Hair preset 1 must have follow_skin_hair == true")
	assert_true(profile.anim_config != null and profile.anim_config.resource_path.ends_with("valentina_v2_anim_config.tres"), "Valentina v2 must use valentina_v2_anim_config.tres")
	assert_true(absf(profile.head_outline_width_px - 4.0) < 0.05, "Valentina v2 calibrated head_outline_width_px must be ~4.0 px")

	var metrics_file := FileAccess.open("res://assets/pilots/valentina_v2/planar/body_metrics.json", FileAccess.READ)
	assert_true(metrics_file != null, "Expected Valentina v2 body_metrics.json to exist")
	var metrics_json: Variant = JSON.parse_string(metrics_file.get_as_text())
	assert_true(metrics_json is Dictionary, "Expected valid body_metrics.json dictionary")
	var m_dict: Dictionary = metrics_json as Dictionary
	var crown_chin_du: float = float(m_dict.get("head_crown_to_chin_du", 0.0))
	var combat_px_h: float = float(m_dict.get("mounted_total_h_du", 0.0)) * profile.display_scale
	assert_true(crown_chin_du >= 65.0 and crown_chin_du <= 71.0, "Valentina v2 head crown-to-chin must measure ~66-70 du (got %.2f)" % crown_chin_du)
	assert_true(combat_px_h >= 152.0 and combat_px_h <= 164.0, "Valentina v2 scaled height at zoom 1.0 must stay in ~155-160 px range (got %.1f px)" % combat_px_h)
	return profile


func _test_rig_hierarchy_and_8dir(profile: PilotRigProfile) -> PlanarCombatRig:
	var planar := PlanarCombatRigScript.new()
	planar.pilot_profile = profile
	add_child(planar)

	assert_true(absf(planar.display_scale - profile.display_scale) < 0.0001, "build_rig() must sync display_scale from assigned pilot_profile")
	assert_true(absf(planar.scale.x - profile.display_scale) < 0.0001, "build_rig() must apply synced display_scale to node scale")
	assert_true(planar.has_8dir_body(), "Valentina v2 must activate 8-dir body routing")

	var v2_keys: Array[String] = planar.get_available_view_keys()
	assert_true(v2_keys == ["s", "se", "e", "ne", "n", "nw", "w", "sw"], "Valentina v2 must load all 8 directional body views (got %s)" % str(v2_keys))
	var views: Dictionary = planar.get_views()
	for vk: String in v2_keys:
		var vd: Dictionary = views[vk] as Dictionary
		assert_true((vd["bones"] as Dictionary).size() >= 18, "View '%s' must bind all 18 rig bones (incl. Pauldron_R/L)" % vk)
		var v_root: Node2D = vd["root"] as Node2D
		assert_true(v_root != null and not (v_root is CanvasGroup), "Body view '%s' must be Node2D (no nested CanvasGroup)" % vk)
		var v_meshes: Node2D = v_root.get_node("Meshes") as Node2D
		for m_child: Node in v_meshes.get_children():
			assert_true((m_child as CanvasItem).z_index == 0, "Every Polygon2D in '%s/Meshes' must have z_index 0" % vk)
		var v_polys: Dictionary = vd.get("polys", {}) as Dictionary
		for pk: String in v_polys.keys():
			var poly: Polygon2D = v_polys[pk] as Polygon2D
			var seen_bones: Dictionary = {}
			for bi: int in range(poly.get_bone_count()):
				var b_path: String = str(poly.get_bone_path(bi))
				assert_true(not seen_bones.has(b_path), "Polygon2D '%s/%s' must NOT contain duplicate bone registration '%s'" % [vk, pk, b_path])
				seen_bones[b_path] = true

	var unified_cg: CanvasGroup = planar.get_unified_canvas_group()
	assert_true(unified_cg != null and unified_cg.get_child_count() == 3, "Unified CanvasGroup must wrap HeadUnder -> BodyPivot -> HeadOver")
	assert_true(unified_cg.use_mipmaps == true, "UnifiedCharacterGroup must enable use_mipmaps = true")
	assert_true(is_equal_approx(unified_cg.fit_margin, 64.0) and is_equal_approx(unified_cg.clear_margin, 64.0), "UnifiedCharacterGroup must preserve fit_margin = 64.0 and clear_margin = 64.0")
	assert_true(unified_cg.get_child(0).name == "DecoupledHeadUnderMount" and (unified_cg.get_child(0) as Node2D).z_index == 0, "HeadUnder must be child 0 with z_index 0")
	assert_true(unified_cg.get_child(1).name == "BodyPivot" and (unified_cg.get_child(1) as Node2D).z_index == 0, "BodyPivot must be child 1 with z_index 0")
	assert_true(unified_cg.get_child(2).name == "DecoupledHeadMount" and (unified_cg.get_child(2) as Node2D).z_index == 0, "HeadOver must be child 2 with z_index 0")
	var bp_init: Node2D = unified_cg.get_child(1) as Node2D
	assert_true(bp_init.get_child_count() == 9 and bp_init.get_child(bp_init.get_child_count() - 1).name == "HeadContactShadow", "HeadContactShadow must be last child of BodyPivot after 8 body views")
	assert_true((bp_init.get_child(bp_init.get_child_count() - 1) as Node2D).z_index == 0, "HeadContactShadow must use z_index 0 inside BodyPivot")

	var e_v2_meshes: Node2D = ((views["e"] as Dictionary)["root"] as Node2D).get_node("Meshes") as Node2D
	var e_names: Array[String] = []
	for c_e: Node in e_v2_meshes.get_children():
		e_names.append(c_e.name)
	assert_true(e_names.find("Part_leg_r") > e_names.find("Part_body_core"), "E Meshes must place leg_r above body_core (got %s)" % str(e_names))
	var w_v2_meshes: Node2D = ((views["w"] as Dictionary)["root"] as Node2D).get_node("Meshes") as Node2D
	var w_names: Array[String] = []
	for c_w: Node in w_v2_meshes.get_children():
		w_names.append(c_w.name)
	assert_true(w_names.find("Part_leg_l") > w_names.find("Part_body_core"), "W Meshes must place leg_l above body_core (got %s)" % str(w_names))
	return planar


func _test_materials_pass2_and_impact(planar: PlanarCombatRig, profile: PilotRigProfile) -> ShaderMaterial:
	var views: Dictionary = planar.get_views()
	var init_p2: ShaderMaterial = planar.get_pass2_material()
	assert_true(init_p2 != null, "Unified CanvasGroup must have Pasada 2 ShaderMaterial")
	assert_true(bool(init_p2.get_shader_parameter("enable_outer_outline")) == true, "Pass 2 must initialize with unified outer outline enabled")
	assert_true(absf(float(init_p2.get_shader_parameter("outer_outline_width_px")) - 0.65) < 0.01, "Pass 2 must initialize with outer_outline_width_px == 0.65")
	assert_true(absf(float(init_p2.get_shader_parameter("outer_outline_strength")) - 0.0) < 0.01, "Pass 2 must initialize with outer_outline_strength == 0.0")
	assert_true((init_p2.get_shader_parameter("outer_outline_color") as Color).is_equal_approx(Color(0.0, 0.0, 0.0, 1.0)), "Pass 2 must initialize with pure solid black outer_outline_color")

	var lit_col_before: Color = init_p2.get_shader_parameter("outer_outline_lit_color") as Color
	var ctr_col_before: Color = init_p2.get_shader_parameter("rim_counter_color") as Color
	planar.apply_style_profile(profile.style_profiles[1])
	planar.apply_skin_preset(profile.skins[3])
	var lit_col_after: Color = init_p2.get_shader_parameter("outer_outline_lit_color") as Color
	var ctr_col_after: Color = init_p2.get_shader_parameter("rim_counter_color") as Color
	assert_true(not lit_col_before.is_equal_approx(lit_col_after), "Changing PilotSkinPreset must update Pass 2 outer_outline_lit_color")
	assert_true(not ctr_col_before.is_equal_approx(ctr_col_after) and ctr_col_after.is_equal_approx(profile.skins[3].accent_color), "Changing PilotSkinPreset must update Pass 2 rim_counter_color when counter_rim_use_skin_accent is true")
	assert_true(bool(init_p2.get_shader_parameter("enable_outer_outline")) == true, "Definitive style must enable Pass 2 outer outline")
	assert_true(float(init_p2.get_shader_parameter("outer_outline_strength")) > 0.5, "Definitive style must activate outer_outline_strength > 0.5")
	assert_true(float(init_p2.get_shader_parameter("outer_outline_tint_mix")) > 0.5, "apply_style_profile must unlock outer_outline_tint_mix > 0.5")
	assert_true(float(init_p2.get_shader_parameter("silhouette_rim_strength")) > 0.2, "Definitive style must activate Pass 2 silhouette_rim_strength")
	assert_true(float(init_p2.get_shader_parameter("hdr_light_wrap_strength")) > 0.2, "Definitive style must activate Pass 2 hdr_light_wrap_strength")
	assert_true(float(init_p2.get_shader_parameter("outer_outline_width_px")) >= 0.70 and float(init_p2.get_shader_parameter("outer_outline_width_px")) <= 0.85, "Definitive style must configure fine ~0.78 px outer outline")
	assert_true(float(init_p2.get_shader_parameter("outline_crispness")) >= 0.40 and float(init_p2.get_shader_parameter("ign_jitter_strength")) <= 0.01, "Definitive style must disable IGN jitter and set crisp AA band")
	assert_true(float(init_p2.get_shader_parameter("cas_sharpen_strength")) >= 0.25 and float(init_p2.get_shader_parameter("hdr_threshold")) >= 1.15, "Definitive style must configure CAS sharpen and focused HDR threshold")

	var core_mat: ShaderMaterial = (views["s"] as Dictionary).get("body_core_mat", null) as ShaderMaterial
	assert_true(core_mat != null, "Expected body_core_mat on view S")
	assert_true(float(core_mat.get_shader_parameter("albedo_lod_bias_offset")) < -0.4, "Definitive style must configure negative albedo_lod_bias_offset")
	assert_true(bool(core_mat.get_shader_parameter("enable_shader_recolor")) == true, "Shader recolor must activate on non-base skin")
	assert_true(bool(core_mat.get_shader_parameter("stylize_enabled")) == true, "Definitive style must enable stylize_enabled on Pass 1")
	assert_true(float(core_mat.get_shader_parameter("cel_strength")) > 0.5, "Definitive style must set cel_strength > 0.5")
	assert_true(float(core_mat.get_shader_parameter("armor_spec_strength")) > 0.5, "Definitive style must set armor_spec_strength > 0.5")
	assert_true(float(core_mat.get_shader_parameter("hair_angel_ring_strength")) > 0.5, "Definitive style must set hair_angel_ring_strength > 0.5")
	assert_true(float(core_mat.get_shader_parameter("normal_rim_strength")) > 0.3, "Definitive style must set normal_rim_strength > 0.3")
	assert_true(float(core_mat.get_shader_parameter("ink_color_tint_mix")) > 0.5, "Definitive style must set ink_color_tint_mix > 0.5")
	var se_core_mat: ShaderMaterial = (views["se"] as Dictionary).get("body_core_mat", null) as ShaderMaterial
	assert_true(se_core_mat != null and bool(se_core_mat.get_shader_parameter("enable_shader_recolor")), "Valentina v2 'se' view must activate shader recolor on non-base skin")

	planar.apply_style_profile(profile.style_profiles[0])
	assert_true(bool(core_mat.get_shader_parameter("stylize_enabled")) == false, "Applying 00_original must disable stylize_enabled")
	assert_true(bool(init_p2.get_shader_parameter("enable_outer_outline")) == false, "Applying 00_original must disable Pass 2 enable_outer_outline")
	planar.apply_style_profile(profile.style_profiles[1])

	planar.apply_skin_preset(profile.skins[0])
	assert_true(bool(core_mat.get_shader_parameter("enable_shader_recolor")) == false, "Shader recolor must be off on base skin")

	planar.apply_hair_preset(profile.hair_presets[2], profile.skins[0].hair_color)
	assert_true(bool(core_mat.get_shader_parameter("enable_hair_recolor")) == true, "Override hair preset must enable hair recolor")
	planar.apply_hair_preset(profile.hair_presets[0], profile.skins[0].hair_color)
	assert_true(bool(core_mat.get_shader_parameter("enable_hair_recolor")) == false, "Original hair preset must disable hair recolor")

	planar.trigger_hit_flash(1.0)
	assert_true(absf(float(core_mat.get_shader_parameter("hit_flash")) - 1.0) < 0.01, "hit_flash must propagate to shader")
	planar._process(0.1)
	assert_true(float(core_mat.get_shader_parameter("hit_flash")) < 0.99, "hit_flash must decay over _process")
	planar.set_hit_flash(0.0)

	planar.trigger_impact_frame(55.0, 6.0)
	assert_true(planar.is_hit_stop_active() and planar.get_impact_frame_phase() == 1, "Impact frame must start in phase 1")
	assert_true(absf(Engine.time_scale - 1.0) < 0.001, "Local hit-stop must NEVER mutate Engine.time_scale")
	planar._process(0.030)
	assert_true(planar.get_impact_frame_phase() == 2, "Impact frame must transition to phase 2")
	planar._process(0.030)
	assert_true(not planar.is_hit_stop_active() and planar.get_impact_frame_phase() == 0, "Local hit-stop must finish cleanly")
	assert_true(planar.get_unified_canvas_group().position.is_equal_approx(Vector2.ZERO), "UnifiedCharacterGroup position must reset to ZERO")
	return init_p2


func _test_masks_and_profile_geometry(planar: PlanarCombatRig) -> void:
	var views: Dictionary = planar.get_views()
	var core_mat: ShaderMaterial = (views["s"] as Dictionary).get("body_core_mat", null) as ShaderMaterial
	var e_core_mat: ShaderMaterial = (views["e"] as Dictionary).get("body_core_mat", null) as ShaderMaterial
	var w_core_mat: ShaderMaterial = (views["w"] as Dictionary).get("body_core_mat", null) as ShaderMaterial
	assert_true(float(w_core_mat.get_shader_parameter("neck_seam_u")) > 0.52, "Native W neck_seam_u must follow real neck_anchor")
	assert_true(float(e_core_mat.get_shader_parameter("neck_seam_u")) < 0.45, "Native E neck_seam_u must follow real neck_anchor")
	assert_true(absf(float(core_mat.get_shader_parameter("neck_seam_u")) - float(w_core_mat.get_shader_parameter("neck_seam_u"))) > 0.04, "Dynamic neck_seam_u must vary cleanly across views")
	assert_true(bool(core_mat.get_shader_parameter("has_pauldron_mask")) == true and core_mat.get_shader_parameter("pauldron_mask_tex") != null, "body_core must connect body_core_pauldron_mask.png")
	assert_true(e_core_mat.get_shader_parameter("secondary_jiggle_mask_tex") != null and bool(e_core_mat.get_shader_parameter("enable_secondary_jiggle")), "Native E torso must connect secondary_jiggle_mask_tex")
	assert_true(w_core_mat.get_shader_parameter("secondary_jiggle_mask_tex") != null and bool(w_core_mat.get_shader_parameter("enable_secondary_jiggle")), "Native W torso must connect secondary_jiggle_mask_tex")
	_assert_dual_ew_secondary_mask(e_core_mat, "E")
	_assert_dual_ew_secondary_mask(w_core_mat, "W")

	var head_mats: Array = planar.get_head_data().get("materials", []) as Array
	assert_true(not head_mats.is_empty(), "Valentina v2 must build decoupled head materials")
	var hf_mat: ShaderMaterial = head_mats[0] as ShaderMaterial
	assert_true(bool(hf_mat.get_shader_parameter("has_outline_sdf")) == true, "Decoupled heads must connect *_outline_sdf.png")
	assert_true(is_equal_approx(float(hf_mat.get_shader_parameter("sdf_pad_px")), 32.0) and is_equal_approx(float(hf_mat.get_shader_parameter("head_outline_width_px")), 4.0), "Head SDF uniforms must match divisor=32 and width_px=4")
	var hu_mats: Array = planar.get_head_under_data().get("materials", []) as Array
	assert_true(not hu_mats.is_empty(), "Expected _head_under_data materials")
	var head_sprites_map: Dictionary = planar.get_head_data().get("sprites", {}) as Dictionary
	var hs_spr: Sprite2D = head_sprites_map.get("head_side", null) as Sprite2D
	assert_true(hs_spr != null and hs_spr.material is ShaderMaterial, "Expected head_side Sprite2D with ShaderMaterial")
	var hs_mat: ShaderMaterial = hs_spr.material as ShaderMaterial
	assert_true(bool(hs_mat.get_shader_parameter("has_ink_sdf")) and bool(hs_mat.get_shader_parameter("has_ilm_mask")) and hs_mat.get_shader_parameter("id_mask_tex") != null, "head_side must connect id_mask, ilm_mask, and ink_sdf")
	var s_polys_base: Dictionary = (views["s"] as Dictionary)["polys"] as Dictionary
	var s_leg_r_mat: ShaderMaterial = (s_polys_base["leg_r"] as Polygon2D).material as ShaderMaterial
	var s_leg_r_st_mat: ShaderMaterial = (s_polys_base["leg_r_stocking"] as Polygon2D).material as ShaderMaterial
	assert_true(bool(s_leg_r_mat.get_shader_parameter("enable_hip_cast_shadow")) and bool(s_leg_r_mat.get_shader_parameter("enable_stocking_pinch")), "PlanarRigMeshBuilder must wire hip_cast_shadow and stocking_pinch on base rig leg_r")
	assert_true(bool(s_leg_r_st_mat.get_shader_parameter("enable_hip_cast_shadow")) and bool(s_leg_r_st_mat.get_shader_parameter("enable_stocking_pinch")), "PlanarRigMeshBuilder must wire hip_cast_shadow and stocking_pinch on leg_r_stocking")

	var e_leg_l_mat: ShaderMaterial = ((views["e"] as Dictionary)["polys"] as Dictionary)["leg_l"].material as ShaderMaterial
	var e_leg_l_id_img: Image = (e_leg_l_mat.get_shader_parameter("id_mask_tex") as Texture2D).get_image()
	assert_true(_count_mask_channel_px(e_leg_l_id_img, 1) > 1000, "e/leg_l_id_mask must preserve green armor channel on shin")
	assert_true(_count_mask_channel_px(e_leg_l_id_img, 0) > 100, "e/leg_l_id_mask must preserve crimson accent trim")
	var n_bc_mat: ShaderMaterial = (views["n"] as Dictionary).get("body_core_mat", null) as ShaderMaterial
	var n_bc_id_img: Image = (n_bc_mat.get_shader_parameter("id_mask_tex") as Texture2D).get_image()
	assert_true(_count_mask_channel_px(n_bc_id_img, 2) > _count_mask_channel_px(n_bc_id_img, 1), "n/body_core_id_mask must classify back glute leotard as Suit (B) rather than Armor (G)")
	var s_pau_r_mat: ShaderMaterial = (s_polys_base["pauldron_r"] as Polygon2D).material as ShaderMaterial
	var s_pau_r_id_img: Image = (s_pau_r_mat.get_shader_parameter("id_mask_tex") as Texture2D).get_image()
	assert_true(_count_mask_channel_px(s_pau_r_id_img, 0) == 0, "pauldron_r_id_mask must not contain false crimson accent pixels")

	var e_bones: Dictionary = (views["e"] as Dictionary)["bones"] as Dictionary
	assert_true((e_bones["Shoulder_R"] as Bone2D).position.distance_to((e_bones["Shoulder_L"] as Bone2D).position) > 1.5, "Native E rear arm bones must have own pivots")
	var e_polys: Dictionary = (views["e"] as Dictionary)["polys"] as Dictionary
	var e_arm_r_luma: float = _sample_opaque_luma((e_polys["arm_r"] as Polygon2D).texture.get_image(), 0, 0, (e_polys["arm_r"] as Polygon2D).texture.get_width(), (e_polys["arm_r"] as Polygon2D).texture.get_height())
	var e_arm_l_luma: float = _sample_opaque_luma((e_polys["arm_l"] as Polygon2D).texture.get_image(), 0, 0, (e_polys["arm_l"] as Polygon2D).texture.get_width(), (e_polys["arm_l"] as Polygon2D).texture.get_height())
	assert_true(e_arm_l_luma < e_arm_r_luma * 0.92, "Native E rear arm_l must be depth-darkened vs front arm_r")
	assert_true((e_polys["pauldron_l"] as Polygon2D).texture.get_size() == Vector2(12.0, 12.0), "e/pauldron_l residual fragment must be 12x12 placeholder")

	for prof_case: Dictionary in [
		{"vk": "e", "arm": "arm_r", "pau": "pauldron_r", "sh": "Shoulder_R", "pau_b": "Pauldron_R", "ang": -39.0},
		{"vk": "w", "arm": "arm_l", "pau": "pauldron_l", "sh": "Shoulder_L", "pau_b": "Pauldron_L", "ang": 39.0},
	]:
		_assert_zero_upper_arm_peek(views, prof_case)

	var hm_file := FileAccess.open("res://assets/pilots/valentina_v2/planar/heads/heads_metadata.json", FileAccess.READ)
	assert_true(hm_file != null, "Expected valentina_v2 heads_metadata.json")
	var hm_dict: Dictionary = JSON.parse_string(hm_file.get_as_text()) as Dictionary
	var hm_outlines: Dictionary = hm_dict.get("part_outlines", {}) as Dictionary
	var hf_outline_cfg: Dictionary = hm_outlines.get("head_front", {}) as Dictionary
	assert_true(not bool(hf_outline_cfg.get("enabled", false)), "Residual Pass 1 part_outlines.head_front must be disabled in heads_metadata.json")
	var has_head_overrides: bool = FileAccess.file_exists("res://assets/pilots/valentina_v2/planar/manual_calibration_overrides.json")
	for pair: Array in [["head_front_r", "head_front_l"], ["head_side_r", "head_side_l"], ["head_back_r", "head_back_l"]]:
		var off_r: Array = (hm_dict[str(pair[0])] as Dictionary)["sprite_offset"] as Array
		var off_l: Array = (hm_dict[str(pair[1])] as Dictionary)["sprite_offset"] as Array
		if has_head_overrides:
			assert_true(float(off_r[0]) > float(off_l[0]), "Calibrated head horizontal sprite_offset must keep %s right of %s" % [pair[0], pair[1]])
		else:
			assert_true(absf(float(off_r[0]) + float(off_l[0])) < 1.0, "Head horizontal sprite_offset must remain symmetric for %s/%s" % [pair[0], pair[1]])

	for bvk: String in ["n", "ne", "nw"]:
		var b_polys: Dictionary = (views[bvk] as Dictionary)["polys"] as Dictionary
		var bc_img: Image = (b_polys["body_core"] as Polygon2D).texture.get_image()
		var bw: int = bc_img.get_width()
		var bh: int = bc_img.get_height()
		var y_probe: int = int(round(float(bh) * 0.84))
		var opaque_runs: int = 0
		var in_run: bool = false
		for xp: int in range(int(float(bw) * 0.28), int(float(bw) * 0.72), 4):
			var a_v: float = bc_img.get_pixel(xp, y_probe).a
			if a_v >= 0.5 and not in_run:
				opaque_runs += 1
				in_run = true
			elif a_v < 0.25 and in_run:
				in_run = false
		assert_true(opaque_runs == 1, "Back view '%s' glute band must be single continuous span (runs=%d)" % [bvk, opaque_runs])


func _assert_zero_upper_arm_peek(views: Dictionary, prof_case: Dictionary) -> void:
	var p_vk: String = str(prof_case["vk"])
	var p_meta_f := FileAccess.open("res://assets/pilots/valentina_v2/planar/%s/parts_5/parts_5_meta.json" % p_vk, FileAccess.READ)
	assert_true(p_meta_f != null, "Expected %s parts_5_meta.json" % p_vk)
	var p_meta: Dictionary = JSON.parse_string(p_meta_f.get_as_text()) as Dictionary
	var ts_p: float = float(p_meta.get("tex_scale", 3.0))
	var p_rects: Dictionary = p_meta["rects"] as Dictionary
	var arm_r_arr: Array = p_rects[str(prof_case["arm"])] as Array
	var pau_r_arr: Array = p_rects[str(prof_case["pau"])] as Array
	var bc_r_arr: Array = p_rects["body_core"] as Array
	var arm_rect_pos := Vector2(float(arm_r_arr[0]), float(arm_r_arr[1]))
	var pau_rect_pos := Vector2(float(pau_r_arr[0]), float(pau_r_arr[1]))
	var bc_rect_pos := Vector2(float(bc_r_arr[0]), float(bc_r_arr[1]))
	var sh_pos := Vector2.ZERO
	var pau_pos := Vector2.ZERO
	for b_entry: Variant in (p_meta["bones"] as Array):
		var bd: Dictionary = b_entry as Dictionary
		if str(bd.get("name", "")) == str(prof_case["sh"]):
			var bp: Array = bd["pos"] as Array
			sh_pos = Vector2(float(bp[0]), float(bp[1]))
		elif str(bd.get("name", "")) == str(prof_case["pau_b"]):
			var pp_arr: Array = bd["pos"] as Array
			pau_pos = Vector2(float(pp_arr[0]), float(pp_arr[1]))
	var p_polys: Dictionary = (views[p_vk] as Dictionary)["polys"] as Dictionary
	var a_img: Image = (p_polys[str(prof_case["arm"])] as Polygon2D).texture.get_image()
	var p_img: Image = (p_polys[str(prof_case["pau"])] as Polygon2D).texture.get_image()
	var bc_p_img: Image = (p_polys["body_core"] as Polygon2D).texture.get_image()
	var ang_rad: float = deg_to_rad(float(prof_case["ang"]))
	var upper_peek_count: int = 0
	for py: int in range(a_img.get_height()):
		var du_y: float = arm_rect_pos.y + (float(py) + 0.5) / ts_p
		if du_y > sh_pos.y:
			continue
		for px: int in range(a_img.get_width()):
			if a_img.get_pixel(px, py).a < 0.05:
				continue
			var du_pt := Vector2(arm_rect_pos.x + (float(px) + 0.5) / ts_p, du_y)
			var rot_pt: Vector2 = sh_pos + (du_pt - sh_pos).rotated(ang_rad)
			if rot_pt.y > sh_pos.y + 4.0:
				continue
			var bc_px: Vector2 = (rot_pt - bc_rect_pos) * ts_p
			if bc_px.x >= 0.0 and bc_px.y >= 0.0 and bc_px.x < float(bc_p_img.get_width()) and bc_px.y < float(bc_p_img.get_height()) and bc_p_img.get_pixel(int(bc_px.x), int(bc_px.y)).a >= 0.25:
				continue
			var covered_pau_both: bool = true
			for p_eff: float in [0.0, 0.23 * ang_rad]:
				var inv_pau_pt: Vector2 = pau_pos + (rot_pt - pau_pos).rotated(-p_eff)
				var p_px: Vector2 = (inv_pau_pt - pau_rect_pos) * ts_p
				if not (p_px.x >= 0.0 and p_px.y >= 0.0 and p_px.x < float(p_img.get_width()) and p_px.y < float(p_img.get_height()) and p_img.get_pixel(int(p_px.x), int(p_px.y)).a >= 0.25):
					covered_pau_both = false
					break
			if not covered_pau_both:
				upper_peek_count += 1
	assert_true(upper_peek_count == 0, "Profile '%s' at %.0f deg must have zero %s upper-rim peek over %s (peek=%d)" % [p_vk.to_upper(), float(prof_case["ang"]), str(prof_case["arm"]), str(prof_case["pau"]), upper_peek_count])

	# Verify upper deltoid contour at rest has no bitten notch (single continuous span per populated row near shoulder)
	var span_rows: int = 0
	var top_opaque_du: float = INF
	for py_r: int in range(a_img.get_height()):
		var du_yr: float = arm_rect_pos.y + (float(py_r) + 0.5) / ts_p
		if du_yr < sh_pos.y - 8.0 or du_yr > sh_pos.y + 16.0:
			continue
		var runs_r: int = 0
		var in_r: bool = false
		for px_r: int in range(a_img.get_width()):
			var av_r: float = a_img.get_pixel(px_r, py_r).a
			if av_r >= 0.25 and not in_r:
				runs_r += 1
				in_r = true
			elif av_r < 0.10 and in_r:
				in_r = false
		if runs_r > 0:
			span_rows += 1
			top_opaque_du = minf(top_opaque_du, du_yr)
			assert_true(runs_r == 1, "Profile '%s/%s' deltoid row y=%.1f du must be single unbroken span (runs=%d)" % [p_vk, str(prof_case["arm"]), du_yr, runs_r])
	assert_true(span_rows >= int(18.0 * ts_p) and top_opaque_du <= sh_pos.y - 5.0, "Profile '%s/%s' deltoid cap must cover shoulder cleanly without excessive trim (rows=%d top=%.1f sh=%.1f)" % [p_vk, str(prof_case["arm"]), span_rows, top_opaque_du, sh_pos.y])
	var pau_w: float = float(pau_r_arr[2])
	var pau_h: float = float(pau_r_arr[3])
	assert_true(pau_w >= 40.0 and pau_w <= 50.0 and pau_h >= 44.0 and pau_h <= 52.0, "Profile '%s/%s' pauldron must have proportional non-stretched size (got %.1fx%.1f)" % [p_vk, str(prof_case["pau"]), pau_w, pau_h])


func _test_8dir_routing_and_backpedal(planar: PlanarCombatRig) -> void:
	var dir_cases: Array[Dictionary] = [
		{"dir": Vector2.DOWN, "view": "s", "head": "head_front"},
		{"dir": Vector2(1.0, 1.0).normalized(), "view": "se", "head": "head_front_r"},
		{"dir": Vector2.RIGHT, "view": "e", "head": "head_side_r"},
		{"dir": Vector2(1.0, -1.0).normalized(), "view": "ne", "head": "head_back_r"},
		{"dir": Vector2.UP, "view": "n", "head": "head_back"},
		{"dir": Vector2(-1.0, -1.0).normalized(), "view": "nw", "head": "head_back_l"},
		{"dir": Vector2.LEFT, "view": "w", "head": "head_side_l"},
		{"dir": Vector2(-1.0, 1.0).normalized(), "view": "sw", "head": "head_front_l"},
	]
	for dc: Dictionary in dir_cases:
		var dvec: Vector2 = dc["dir"] as Vector2
		planar.set_locomotion_state(dvec, 0.85, dvec, true)
		planar._process(0.016)
		assert_true(planar.get_active_view_key() == str(dc["view"]), "8-dir move %s must select native view '%s'" % [str(dvec), str(dc["view"])])
		assert_true(planar.is_body_flipped() == false, "Native 8-dir view '%s' must NEVER flip horizontally" % str(dc["view"]))
		assert_true(planar.get_active_head_key() == str(dc["head"]), "8-dir aligned aim must select head '%s'" % str(dc["head"]))

	planar.set_locomotion_state(Vector2(1.0, -1.0).normalized(), 0.9, Vector2(-1.0, 1.0).normalized(), false)
	for _nesw_i: int in range(18):
		planar._process(0.02)
	assert_true(planar.get_active_view_key() == "sw" and planar.get_active_head_key() == "head_front_l", "Moving NE aiming SW must settle to SW + head_front_l backpedal")

	planar.set_locomotion_state(Vector2.DOWN, 0.85, Vector2(0.707, 0.707).normalized(), true)
	assert_true(planar.get_active_view_key() == "s" and planar.get_active_head_key() == "head_front_r", "Moving S aiming SE (45 deg) must keep body S + head_front_r")
	planar.set_locomotion_state(Vector2.DOWN, 0.85, Vector2(0.866, 0.5).normalized(), false)
	for _mid_i: int in range(25):
		planar._process(0.02)
	assert_true(planar.get_active_view_key() == "se" and planar.get_active_head_key() == "head_front_r", "Crossing 8-dir threshold must step smoothly through diagonal SE")
	planar.set_locomotion_state(Vector2.DOWN, 0.85, Vector2.RIGHT, false)
	for _thr_i: int in range(25):
		planar._process(0.02)
	assert_true(planar.get_active_view_key() == "e" and planar.get_active_head_key() == "head_side_r", "Continuing past SE must turn body posture cleanly to E + head_side_r")
	planar.set_locomotion_state(Vector2.DOWN, 0.85, Vector2(0.94, 0.34).normalized(), false)
	for _hys_i: int in range(15):
		planar._process(0.02)
	assert_true(planar.get_active_view_key() == "e", "8-dir threshold hysteresis must hold turned body posture E at ~70 deg")
	planar.set_locomotion_state(Vector2.DOWN, 0.85, Vector2(0.42, 0.907).normalized(), false)
	for _ret_i: int in range(25):
		planar._process(0.02)
	assert_true(planar.get_active_view_key() == "s", "Returning inside comfortable neck cone must restore flight posture S")

	var bad_head_combos: Array[Array] = [
		["s", "head_side_r"], ["s", "head_side_l"], ["s", "head_back"],
		["se", "head_back_r"], ["se", "head_front_l"],
		["e", "head_front"], ["e", "head_back"], ["e", "head_back_r"],
		["ne", "head_front_r"], ["ne", "head_back_l"], ["ne", "head_side_r"],
		["n", "head_side_r"], ["n", "head_side_l"], ["n", "head_front"],
		["nw", "head_front_l"], ["nw", "head_back_r"], ["nw", "head_side_l"],
		["w", "head_front"], ["w", "head_back"], ["w", "head_back_l"],
		["sw", "head_back_l"], ["sw", "head_front_r"],
	]
	for pair_b: Array in bad_head_combos:
		planar.set_static_inspection(true, str(pair_b[0]), str(pair_b[1]))
		assert_true(planar.get_active_head_key() != str(pair_b[1]), "8-dir static inspection must block mismatched combo %s + %s" % [pair_b[0], pair_b[1]])
	planar.set_static_inspection(false)

	var hcs: CanvasItem = planar.get_head_contact_shadow()
	planar.set_static_inspection(true, "s", "head_front")
	planar._process(0.016)
	assert_true(hcs != null and hcs.visible, "Front view S must keep HeadContactShadow visible under collar")
	planar.set_static_inspection(true, "nw", "head_back_l")
	planar._process(0.016)
	assert_true(not hcs.visible, "Back view NW must hide HeadContactShadow")
	planar.set_static_inspection(false)


func _test_head_combo_transforms(planar: PlanarCombatRig) -> void:
	var h_data: Dictionary = planar.get_head_data()
	var h_under: Dictionary = planar.get_head_under_data()
	var meta: Dictionary = h_data.get("meta", {}) as Dictionary
	var combos: Dictionary = meta.get("combo_transforms", {}) as Dictionary
	var allowed_map: Dictionary = PlanarRigViewRouter.ALLOWED_HEADS_BY_BODY_8DIR
	assert_true(combos.size() == allowed_map.size(), "combo_transforms must cover all 8 body views")

	var base_scales: Dictionary = h_data.get("base_scales", {}) as Dictionary
	var sprites: Dictionary = h_data.get("sprites", {}) as Dictionary
	var under_sprites: Dictionary = h_under.get("sprites", {}) as Dictionary
	var combo_count: int = 0
	for v_key: String in allowed_map.keys():
		var allowed_heads: Array = allowed_map[v_key] as Array
		assert_true(combos.has(v_key), "combo_transforms must include view '%s'" % v_key)
		var v_combos: Dictionary = combos.get(v_key, {}) as Dictionary
		assert_true(v_combos.size() == allowed_heads.size(), "View '%s' combo_transforms must match exact allowed head count (%d)" % [v_key, allowed_heads.size()])
		for h_key_var: Variant in allowed_heads:
			var h_key: String = str(h_key_var)
			assert_true(v_combos.has(h_key), "Missing combo_transforms entry for %s + %s" % [v_key, h_key])
			var tf: Dictionary = v_combos[h_key] as Dictionary
			var off_arr: Array = tf.get("sprite_offset", []) as Array
			var s_val: float = float(tf.get("scale", 1.0))
			assert_true(off_arr.size() == 2 and s_val > 0.5 and s_val < 1.5, "Invalid combo transform for %s + %s" % [v_key, h_key])

			planar.set_static_inspection(true, v_key, h_key)
			planar._process(0.016)
			var spr: Sprite2D = sprites.get(h_key, null) as Sprite2D
			var u_spr: Sprite2D = under_sprites.get(h_key, null) as Sprite2D
			var b_scale: Vector2 = base_scales.get(h_key, Vector2.ONE) as Vector2
			var exp_pos := Vector2(float(off_arr[0]), float(off_arr[1]))
			var exp_scale: Vector2 = b_scale * s_val
			assert_true(spr != null and spr.position.distance_to(exp_pos) < 0.01, "Main head sprite offset mismatch for %s + %s" % [v_key, h_key])
			assert_true(spr != null and spr.scale.distance_to(exp_scale) < 0.001, "Main head sprite scale mismatch for %s + %s" % [v_key, h_key])
			assert_true(u_spr != null and u_spr.position.distance_to(exp_pos) < 0.01, "Under head sprite offset mismatch for %s + %s" % [v_key, h_key])
			assert_true(u_spr != null and u_spr.scale.distance_to(exp_scale) < 0.001, "Under head sprite scale mismatch for %s + %s" % [v_key, h_key])
			combo_count += 1
	assert_true(combo_count == 20, "Expected exactly 20 anatomically valid body+head combinations (got %d)" % combo_count)
	planar.set_static_inspection(false)


func _test_orientation_transitions(planar: PlanarCombatRig, init_p2: ShaderMaterial) -> void:
	var views: Dictionary = planar.get_views()
	var bp: Node2D = planar.get_body_pivot()
	for style_id: int in [4, 5, 6]:
		planar.set_transition_style(style_id)
		planar.set_locomotion_state(Vector2.DOWN, 0.75, Vector2.DOWN, true)
		planar.set_locomotion_state(Vector2.UP, 0.75, Vector2.UP, false)
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
					assert_true(absf(bp.scale.x - snap_xy.x) < 0.001, "Style %d must keep _body_pivot scale synced with snap_scale_xy" % style_id)
				var mat_s: ShaderMaterial = ((views["s"] as Dictionary).get("materials", []) as Array)[0] as ShaderMaterial
				var p1_mode: int = int(mat_s.get_shader_parameter("transition_fx_mode"))
				var p2_smear: float = float(init_p2.get_shader_parameter("smear_strength"))
				var p2_holo: float = float(init_p2.get_shader_parameter("holo_sweep_strength"))
				if style_id == 4 and p1_mode == 0 and p2_smear > 0.01:
					saw_fx = true
				elif style_id == 5 and p1_mode == 2 and p2_smear <= 0.001:
					saw_fx = true
				elif style_id == 6 and p1_mode == 3 and p2_smear <= 0.001 and p2_holo <= 0.001:
					saw_fx = true
		assert_true(saw_snap, "Style %d must activate body orientation snap transition" % style_id)
		assert_true(saw_fx, "Style %d must apply Pass 1 / Pass 2 orientation transition FX" % style_id)
		for _t: int in range(12):
			planar._process(0.02)
		assert_true(not planar.is_snap_active(), "Style %d must settle cleanly within ~200ms" % style_id)

	planar.set_transition_style(4)
	planar.set_locomotion_state(Vector2.DOWN, 0.75, Vector2.DOWN, true)
	planar.set_locomotion_state(Vector2.DOWN, 0.75, Vector2(0.707, 0.707).normalized(), false)
	var saw_head_micro: bool = false
	for _hm: int in range(10):
		planar._process(0.016)
		assert_true(not planar.is_snap_active(), "Head-only change must NOT trigger body snap_active")
		if planar.is_head_micro_snap_active():
			saw_head_micro = true
	assert_true(saw_head_micro, "Head-only aim change must trigger subtle head micro-snap")


func _test_purged_subsystems(planar: PlanarCombatRig) -> void:
	planar.set_live_animations_enabled(false)
	var views: Dictionary = planar.get_views()
	var bp: Node2D = planar.get_body_pivot()
	planar.enable_afterimage = true
	var test_flows: Array[Dictionary] = [
		{"mv": Vector2.DOWN, "spd": 0.0, "aim": Vector2.DOWN},
		{"mv": Vector2.RIGHT, "spd": 0.90, "aim": Vector2.RIGHT},
		{"mv": Vector2.LEFT, "spd": 1.35, "aim": Vector2.LEFT},
		{"mv": Vector2.UP, "spd": 0.95, "aim": Vector2.UP},
		{"mv": Vector2(1.0, 1.0).normalized(), "spd": 0.85, "aim": Vector2(-1.0, -1.0).normalized()},
	]
	for tf: Dictionary in test_flows:
		planar.set_locomotion_state(tf["mv"] as Vector2, float(tf["spd"]), tf["aim"] as Vector2, false)
		planar.trigger_dash_burst(tf["mv"] as Vector2)
		planar.trigger_attack_recoil(tf["aim"] as Vector2, 1.0)
		planar.trigger_hit_react(-(tf["aim"] as Vector2), 1.0)
		for _pf: int in range(25):
			planar._process(0.02)

		assert_true(bp.position.is_equal_approx(Vector2.ZERO), "Purged rig must keep BodyPivot.position == ZERO")
		assert_true(absf(bp.rotation) < 0.0001, "Purged rig must keep BodyPivot.rotation == 0.0")
		assert_true(bp.scale.is_equal_approx(Vector2.ONE), "Purged rig must settle BodyPivot.scale == ONE after transition")
		assert_true(not planar.is_whiplash_active(), "Purged rig must keep whiplash_active == false")
		assert_true(planar.get_head_spring_offset().is_equal_approx(Vector2.ZERO), "Purged rig must keep head spring offset == ZERO")
		assert_true(absf(planar.get_head_anchor().rotation) < 0.0001 and planar.get_head_anchor().scale.is_equal_approx(Vector2.ONE), "Purged rig must keep settled head anchor rotation=0 and scale=ONE")

		var cur_vk: String = planar.get_active_view_key()
		var cur_vd: Dictionary = views[cur_vk] as Dictionary
		var cur_bones: Dictionary = cur_vd["bones"] as Dictionary
		var cur_rest_rots: Dictionary = cur_vd["rest_rots"] as Dictionary
		var cur_rest_pos: Dictionary = cur_vd["rest_pos"] as Dictionary
		for b_k: String in cur_bones.keys():
			var b_node: Bone2D = cur_bones[b_k] as Bone2D
			assert_true(absf(b_node.rotation - float(cur_rest_rots.get(b_k, 0.0))) < 0.0001, "Purged rig bone '%s/%s' must stay strictly at rest rotation" % [cur_vk, b_k])
			assert_true(b_node.scale.is_equal_approx(Vector2.ONE), "Purged rig bone '%s/%s' scale must stay ONE" % [cur_vk, b_k])
			assert_true(b_node.position.is_equal_approx(cur_rest_pos[b_k] as Vector2), "Purged rig bone '%s/%s' position must stay at rest_pos" % [cur_vk, b_k])

		var cur_polys: Dictionary = cur_vd["polys"] as Dictionary
		for pk: String in cur_polys.keys():
			var poly: Polygon2D = cur_polys[pk] as Polygon2D
			assert_true(poly.position.is_equal_approx(Vector2.ZERO), "Purged rig poly '%s/%s' position must stay ZERO" % [cur_vk, pk])
			var pmat: ShaderMaterial = poly.material as ShaderMaterial
			assert_true(int(pmat.get_shader_parameter("persp_mode")) == 0, "Purged rig '%s/%s' must keep persp_mode == 0" % [cur_vk, pk])
			assert_true((pmat.get_shader_parameter("bone_chain_angles") as Vector2).is_equal_approx(Vector2.ZERO), "Purged rig must keep bone_chain_angles == ZERO")
			assert_true((pmat.get_shader_parameter("banking_tilt_2d") as Vector2).is_equal_approx(Vector2.ZERO), "Purged rig must keep banking_tilt_2d == ZERO")
			var jg: Variant = pmat.get_shader_parameter("secondary_jiggle_l_px")
			assert_true(jg == null or (jg as Vector2).is_equal_approx(Vector2.ZERO), "Purged rig must keep secondary_jiggle_l_px == ZERO")

	var e_polys: Dictionary = (views["e"] as Dictionary)["polys"] as Dictionary
	planar.set_locomotion_state(Vector2.RIGHT, 0.85, Vector2.RIGHT, true)
	planar._process(0.016)
	var e_leg_r_mat: ShaderMaterial = (e_polys["leg_r"] as Polygon2D).material as ShaderMaterial
	var e_leg_l_mat: ShaderMaterial = (e_polys["leg_l"] as Polygon2D).material as ShaderMaterial
	assert_true(float(e_leg_r_mat.get_shader_parameter("leg_depth_phase")) > 0.4 and float(e_leg_l_mat.get_shader_parameter("leg_depth_phase")) < -0.4, "Static E leg_depth_phase must separate front leg_r vs rear leg_l")


func _test_native_live_animations(profile: PilotRigProfile) -> void:
	assert_true(profile.base_pose_config != null and profile.idle_anim_config != null and profile.locomotion_anim_config != null, "valentina_v2_profile.tres must bind base_pose, idle_anim, and locomotion_anim configs")
	assert_true(profile.turn_anim_config != null and profile.jiggle_physics_config != null and profile.face_anim_config != null, "valentina_v2_profile.tres must bind turn_anim, jiggle_physics, and face_anim configs")

	var live_rig: PlanarCombatRig = PlanarCombatRigScript.new()
	live_rig.pilot_profile = profile
	add_child(live_rig)
	assert_true(live_rig.is_live_animations_enabled(), "Fresh PlanarCombatRig must enable native live animations by default")

	# 1. Vuelo hacia adelante + Turbo
	live_rig.set_turbo_active(true)
	live_rig.set_locomotion_state(Vector2.RIGHT, 1.0, Vector2.RIGHT, true)
	for _i: int in range(20):
		live_rig._process(0.02)
	assert_true(live_rig.is_face_live_enabled(), "Standalone PlanarCombatRig must activate face live automatically on first step")
	var fwd_w: Dictionary = live_rig.get_live_loco_weights()
	assert_true(float(fwd_w.get("fwd", 0.0)) > 0.5, "Standalone PlanarCombatRig must drive forward locomotion weight natively (got %.2f)" % float(fwd_w.get("fwd", 0.0)))

	# 2. Reversa / Backpedal (movimiento opuesto a la mira)
	live_rig.set_turbo_active(false)
	live_rig.set_locomotion_state(Vector2.LEFT, 0.95, Vector2.RIGHT, false)
	for _j: int in range(25):
		live_rig._process(0.02)
	assert_true(live_rig.is_backpedaling(), "Moving opposite to aim must activate backpedaling on PlanarCombatRig")
	var rev_w: Dictionary = live_rig.get_live_loco_weights()
	assert_true(float(rev_w.get("rev", 0.0)) > 0.35, "Backpedaling must drive native reverse locomotion weight (got %.2f)" % float(rev_w.get("rev", 0.0)))

	# 3. Reacciones aditivas de combate (Dash, Recoil, Hit-React, Air-Brake)
	live_rig.trigger_dash_burst(Vector2.RIGHT)
	assert_true(live_rig.is_dash_burst_active() and live_rig.get_active_additive_summary().contains("DASH"), "trigger_dash_burst must activate native DASH additive state")
	live_rig.trigger_attack_recoil(Vector2.RIGHT, 1.0)
	assert_true(live_rig.is_attack_recoil_active() and live_rig.get_active_additive_summary().contains("RECOIL"), "trigger_attack_recoil must activate native RECOIL additive state")
	live_rig.trigger_hit_react(Vector2.LEFT, 1.0)
	assert_true(live_rig.is_hit_react_active() and live_rig.get_active_additive_summary().contains("HIT"), "trigger_hit_react must activate native HIT additive state")
	live_rig.trigger_air_brake(1.0)
	assert_true(live_rig.is_air_brake_active() and live_rig.get_active_additive_summary().contains("AIR_BRAKE"), "trigger_air_brake must activate native AIR_BRAKE additive state")

	live_rig._process(0.016)
	assert_true(live_rig.get_body_pivot().position.length() > 0.2, "Active combat impulses must apply additive displacement to BodyPivot")

	for _k: int in range(25):
		live_rig._process(0.02)
	assert_true(live_rig.get_active_additive_summary() == "NONE", "Combat additive impulses must settle cleanly back to NONE")
	assert_true(live_rig.get_body_pivot().position.is_equal_approx(Vector2.ZERO), "BodyPivot additive position must settle back to ZERO")
	live_rig.queue_free()


func _test_lab_scene_and_matrix() -> void:
	var lab_scene: PackedScene = ResourceLoader.load("res://sandbox/pilot_rig_lab/proto/planar_combat_rig_proto.tscn") as PackedScene
	assert_true(lab_scene != null, "Expected planar_combat_rig_proto.tscn to load cleanly")
	var lab_inst: Node = lab_scene.instantiate()
	add_child(lab_inst)

	var lab_vp: SubViewport = lab_inst.get_node_or_null("SupersampledWorldViewport") as SubViewport
	assert_true(lab_vp != null and lab_vp.use_hdr_2d == true, "Combat Lab must render inside SupersampledWorldViewport with use_hdr_2d = true")
	var lab_display: TextureRect = lab_inst.get("_world_display") as TextureRect
	assert_true(lab_display != null and lab_display.material != null, "Combat Lab must attach SSAA downsample shader at 2x")

	var lab_rig: PlanarCombatRig = lab_inst.get("_rig") as PlanarCombatRig
	assert_true(lab_rig != null and lab_rig.pilot_profile != null and (lab_rig.pilot_profile as PilotRigProfile).pilot_id == "valentina_v2", "Lab showcase must load Valentina v2 (8-Dir)")
	assert_true(lab_rig.get_parent() == lab_vp, "Combat Lab rig must be mounted inside SupersampledWorldViewport")

	var lab_star: Node2D = lab_inst.get("_star") as Node2D
	assert_true(lab_star != null and lab_star.get_parent() == lab_vp, "Combat Lab must instantiate OrbitLightStar inside SupersampledWorldViewport")

	# Verificar HUD depurado: solo secciones 1 (estilos/skins), 3 (8-dir/transición) y 4 (inspección/escena sin estática)
	var lab_hud: Dictionary = lab_inst.get("_hud_refs") as Dictionary
	assert_true(lab_hud.get("profile_opt", null) is OptionButton and (lab_hud["profile_opt"] as OptionButton).item_count >= 3, "Combat Lab HUD must keep Menu 1 style selector")
	assert_true(lab_hud.get("skin_opt", null) is OptionButton and (lab_hud["skin_opt"] as OptionButton).item_count == 10, "Combat Lab HUD must keep Menu 1 skin selector")
	assert_true(lab_hud.get("transition_opt", null) is OptionButton and lab_hud.get("auto_demo_chk", null) is CheckBox, "Combat Lab HUD must keep Menu 3 transition & auto-orbit controls")
	var manual_chk: CheckBox = lab_hud.get("manual_control_chk", null) as CheckBox
	var auto_chk: CheckBox = lab_hud.get("auto_demo_chk", null) as CheckBox
	assert_true(manual_chk != null and manual_chk.button_pressed == false, "Combat Lab HUD must expose manual_control_chk disabled while auto-orbit is active")
	manual_chk.button_pressed = true
	assert_true(bool(lab_inst.get("_auto_demo")) == false and auto_chk.button_pressed == false, "Enabling manual_control_chk must switch Combat Lab to manual WASD mode and untoggle auto_demo_chk")
	manual_chk.button_pressed = false
	assert_true(bool(lab_inst.get("_auto_demo")) == true and auto_chk.button_pressed == true, "Disabling manual_control_chk must restore auto-orbit mode and auto_demo_chk")
	assert_true(lab_hud.get("pose_mode_opt", null) is OptionButton and lab_hud.get("reload_pose_btn", null) is Button, "Combat Lab HUD must expose pose_mode_opt and reload_pose_btn in Menu 3")
	assert_true(lab_hud.get("idle_anim_chk", null) is CheckBox and (lab_hud["idle_anim_chk"] as CheckBox).button_pressed == true, "Combat Lab HUD must expose idle_anim_chk enabled by default")
	assert_true(lab_hud.get("loco_anim_chk", null) is CheckBox and (lab_hud["loco_anim_chk"] as CheckBox).button_pressed == true, "Combat Lab HUD must expose loco_anim_chk enabled by default")
	assert_true(lab_hud.get("kiting_anim_chk", null) is CheckBox and (lab_hud["kiting_anim_chk"] as CheckBox).button_pressed == true, "Combat Lab HUD must expose kiting_anim_chk enabled by default")
	assert_true(lab_hud.get("turn_anim_chk", null) is CheckBox and (lab_hud["turn_anim_chk"] as CheckBox).button_pressed == true, "Combat Lab HUD must expose turn_anim_chk enabled by default")
	assert_true(lab_hud.get("jiggle_anim_chk", null) is CheckBox and (lab_hud["jiggle_anim_chk"] as CheckBox).button_pressed == true, "Combat Lab HUD must expose jiggle_anim_chk enabled by default")
	assert_true(lab_hud.get("face_anim_chk", null) is CheckBox and (lab_hud["face_anim_chk"] as CheckBox).button_pressed == true, "Combat Lab HUD must expose face_anim_chk enabled by default")
	assert_true(lab_hud.get("face_personality_opt", null) is OptionButton and (lab_hud["face_personality_opt"] as OptionButton).item_count == 3, "Combat Lab HUD must expose 3-profile face_personality_opt selector")
	assert_true(lab_hud.get("face_comms_btn", null) is Button, "Combat Lab HUD must expose face_comms_btn")
	assert_true(lab_rig.is_face_live_enabled(), "Combat Lab must activate Valentina live face by default")
	lab_inst.call("_on_face_anim_toggled", false)
	assert_true(not lab_rig.is_face_live_enabled(), "Combat Lab face_anim_chk toggle must cleanly disable live face")
	lab_inst.call("_on_face_anim_toggled", true)
	assert_true(lab_rig.is_face_live_enabled(), "Combat Lab face_anim_chk toggle must cleanly re-enable live face")
	var glance_zero: float = float(lab_inst.call("compute_auto_glance_angle", 1.2))
	var glance_peak: float = float(lab_inst.call("compute_auto_glance_angle", 3.1))
	assert_true(absf(glance_zero) < 0.001 and absf(glance_peak) > 0.25, "Combat Lab auto orbit must trigger tactical lateral head glance only during post-brake pause")
	assert_true(lab_inst.process_priority == 10, "Combat Lab controller must update after PlanarCombatRig (process_priority == 10)")
	var drive_cruise: float = float(lab_inst.call("compute_auto_orbit_drive", 1.2))
	var drive_brake_rest: float = float(lab_inst.call("compute_auto_orbit_drive", 2.9))
	assert_true(drive_cruise > 0.95 and drive_brake_rest < 0.01, "Combat Lab auto orbit must alternate cruise drive (>0.95) and periodic brake stops (<0.01)")
	assert_true(lab_hud.get("debug_opt", null) is OptionButton and lab_hud.get("zoom_opt", null) is OptionButton, "Combat Lab HUD must keep Menu 4 debug & zoom controls")
	assert_true(not lab_hud.has("pilot_opt") and not lab_hud.has("light_slider") and not lab_hud.has("normal_chk") and not lab_hud.has("hdr_slider"), "Combat Lab HUD must remove Menu 0 and Menu 2 adjustment controls")
	assert_true(not lab_hud.has("static_inspect_chk") and not lab_hud.has("static_body_opt") and not lab_hud.has("static_head_opt"), "Combat Lab HUD must remove static inspection from Menu 4")

	# Verificar fidelidad al Shader Lab (estilo razor-sharp, hip_cast_shadow, stocking_pinch, inward outline off)
	var lab_views: Dictionary = lab_rig.get_views()
	var lab_s_core_mat: ShaderMaterial = (lab_views["s"] as Dictionary).get("body_core_mat", null) as ShaderMaterial
	assert_true(bool(lab_s_core_mat.get_shader_parameter("stylize_enabled")) == true, "Combat Lab must start with active shader style")
	assert_true(float(lab_s_core_mat.get_shader_parameter("albedo_lod_bias_offset")) < -0.4, "Combat Lab must match ShaderLab razor-sharp albedo_lod_bias_offset")
	assert_true(bool(lab_s_core_mat.get_shader_parameter("enable_inward_outline")) == false, "Combat Lab must disable enable_inward_outline like ShaderLab")
	assert_true(float(lab_rig.get_pass2_material().get_shader_parameter("cas_sharpen_strength")) > 0.3, "Combat Lab Pass 2 must apply CAS sharpen like ShaderLab")
	var lab_se_leg_r: ShaderMaterial = (((lab_views["se"] as Dictionary)["polys"] as Dictionary)["leg_r"] as Polygon2D).material as ShaderMaterial
	assert_true(bool(lab_se_leg_r.get_shader_parameter("enable_hip_cast_shadow")) == true and bool(lab_se_leg_r.get_shader_parameter("enable_stocking_pinch")) == true, "Combat Lab must apply calibrated hip_cast_shadow and stocking_pinch on legs")

	# Verificar luz dinámica de la estrella (cambio de color + dirección) y órbita con mira fija en la estrella
	var rim_before: Color = lab_s_core_mat.get_shader_parameter("rim_key_color") as Color
	var light_dir_before: Vector2 = lab_s_core_mat.get_shader_parameter("light_dir_2d") as Vector2
	for _step: int in range(60):
		lab_star._process(0.05)
		lab_inst._process(0.05)
	var rim_after: Color = lab_s_core_mat.get_shader_parameter("rim_key_color") as Color
	var light_dir_after: Vector2 = lab_s_core_mat.get_shader_parameter("light_dir_2d") as Vector2
	assert_true(not rim_before.is_equal_approx(rim_after), "Star light color must cycle dynamically on rig shader rim_key_color")
	assert_true(light_dir_before.distance_to(light_dir_after) > 0.15, "Orbiting the star must rotate light_dir_2d dynamically around the rig")
	var aim_world_after: Vector2 = lab_inst.get("_aim_world") as Vector2
	assert_true(aim_world_after.distance_to(lab_star.global_position) < 0.01, "Auto-orbit must keep aim locked onto the star")

	lab_rig.position = Vector2(320.0, 180.0)
	lab_rig.rotation = 0.18
	lab_rig.set_locomotion_state(Vector2.RIGHT, 0.85, Vector2.RIGHT, true)
	lab_rig._process(0.016)
	var bp_node: Node2D = lab_rig.get_body_pivot()
	var s_poly: Polygon2D = ((lab_views["s"] as Dictionary)["polys"] as Dictionary)["body_core"] as Polygon2D
	var inv_bp_xf: Transform2D = lab_s_core_mat.get_shader_parameter("inv_body_pivot_matrix") as Transform2D
	var sample_v: Vector2 = s_poly.polygon[0]
	var shader_rig_pos: Vector2 = (inv_bp_xf * s_poly.get_global_transform()) * sample_v
	var expected_rig_pos: Vector2 = bp_node.to_local(s_poly.to_global(sample_v))
	assert_true(shader_rig_pos.distance_to(expected_rig_pos) < 0.01, "inv_body_pivot_matrix * MODEL_MATRIX must match BodyPivot local frame (err=%.4f)" % shader_rig_pos.distance_to(expected_rig_pos))

	lab_inst.queue_free()


func _test_calibrator_scene_and_store() -> void:
	var store := RigCalibrationStoreScript.new()
	assert_true(store.load_from_root(), "RigCalibrationStore must load Valentina v2 JSONs cleanly")
	var orig_arm_r: Rect2 = store.get_part_rect_rel("s", "arm_r", false)
	assert_true(orig_arm_r.size != Vector2.ZERO, "Store must parse s/arm_r rect")

	store.push_undo_snapshot()
	store.set_part_pos_rel("s", "arm_r", orig_arm_r.position + Vector2(3.5, -2.0))
	assert_true(store.get_part_rect_rel("s", "arm_r", false).position.distance_to(orig_arm_r.position + Vector2(3.5, -2.0)) < 0.01, "set_part_pos_rel must update relative position")
	assert_true(store.undo() and store.get_part_rect_rel("s", "arm_r", false).position.distance_to(orig_arm_r.position) < 0.01, "undo() must restore previous part position")
	assert_true(store.redo() and store.get_part_rect_rel("s", "arm_r", false).position.distance_to(orig_arm_r.position + Vector2(3.5, -2.0)) < 0.01, "redo() must reapply part position")

	var head_disp: Vector2 = store.get_head_disp_size("head_front")
	store.set_head_sprite_offset("head_front", Vector2(4.25, -21.5))
	var head_np: Vector2 = store.get_head_neck_pivot_px("head_front")
	assert_true(absf(head_np.x - (head_disp.x * 0.5 - 4.25)) < 0.01, "set_head_sprite_offset must keep neck_pivot_px.x synced with PlanarRigMeshBuilder")

	assert_true(store.has_head_combo("se", "head_front_r"), "Store must expose combo_transforms for se + head_front_r")
	var orig_se_off: Vector2 = store.get_head_combo_offset("se", "head_front_r", false)
	var orig_se_scale: float = store.get_head_combo_scale("se", "head_front_r", false)
	store.push_undo_snapshot()
	store.set_head_combo_offset("se", "head_front_r", orig_se_off + Vector2(2.5, -1.5))
	store.set_head_combo_scale("se", "head_front_r", 1.18)
	assert_true(store.get_head_combo_offset("se", "head_front_r", false).distance_to(orig_se_off + Vector2(2.5, -1.5)) < 0.01, "set_head_combo_offset must update combo_transforms offset")
	assert_true(absf(store.get_head_combo_scale("se", "head_front_r", false) - 1.18) < 0.002, "set_head_combo_scale must update combo_transforms scale")
	assert_true(store.undo() and store.get_head_combo_offset("se", "head_front_r", false).distance_to(orig_se_off) < 0.01 and absf(store.get_head_combo_scale("se", "head_front_r", false) - orig_se_scale) < 0.002, "undo() must restore combo_transforms offset and scale")
	assert_true(store.redo() and absf(store.get_head_combo_scale("se", "head_front_r", false) - 1.18) < 0.002, "redo() must reapply combo_transforms scale")

	assert_true(store.mirror_view_to_partner("se") == "sw", "mirror_view_to_partner('se') must mirror to 'sw'")
	var se_arm_r: Rect2 = store.get_part_rect_rel("se", "arm_r", false)
	var sw_arm_l: Rect2 = store.get_part_rect_rel("sw", "arm_l", false)
	assert_true(absf((se_arm_r.position.x + sw_arm_l.position.x + sw_arm_l.size.x)) < 0.01, "Mirrored sw/arm_l X must reflect se/arm_r around rig_origin")
	var se_c_off: Vector2 = store.get_head_combo_offset("se", "head_front_r", false)
	var sw_c_off: Vector2 = store.get_head_combo_offset("sw", "head_front_l", false)
	assert_true(absf(se_c_off.x + sw_c_off.x) < 0.01 and absf(se_c_off.y - sw_c_off.y) < 0.01, "mirror_view_to_partner must mirror combo_transforms head offset X")
	assert_true(absf(store.get_head_combo_scale("sw", "head_front_l", false) - 1.18) < 0.002, "mirror_view_to_partner must mirror combo_transforms head scale")

	var cal_scene: PackedScene = ResourceLoader.load("res://sandbox/pilot_rig_lab/calibrator/rig_calibrator.tscn") as PackedScene
	assert_true(cal_scene != null, "Expected rig_calibrator.tscn to load cleanly")
	var cal_inst: Node = cal_scene.instantiate()
	add_child(cal_inst)
	var cal_rig: PlanarCombatRig = cal_inst.get("_rig") as PlanarCombatRig
	assert_true(cal_rig != null and cal_rig.calibration_manual_pose == true, "Calibrator must activate calibration_manual_pose on its PlanarCombatRig")
	var cal_hud: Dictionary = cal_inst.get("_hud_refs") as Dictionary
	var cal_view_opt: OptionButton = cal_hud.get("view_opt", null) as OptionButton
	var cal_head_opt: OptionButton = cal_hud.get("head_opt", null) as OptionButton
	assert_true(cal_view_opt != null and cal_view_opt.item_count == 8, "Calibrator HUD must list all 8 directional views")
	assert_true(cal_head_opt != null, "Calibrator HUD must expose head_opt")

	var cal_store: RigCalibrationStore = cal_inst.get("_store") as RigCalibrationStore
	for v_key: String in RigCalibrationStoreScript.VIEW_ORDER:
		cal_inst.call("_switch_view_and_head", v_key, "head_back")
		var expected_heads: Array[String] = RigCalibrationStoreScript.get_allowed_heads_for_view(v_key)
		assert_true(cal_head_opt.item_count == expected_heads.size(), "Calibrator head_opt for '%s' must list only the %d compatible heads" % [v_key, expected_heads.size()])
		for hi: int in range(expected_heads.size()):
			assert_true(cal_head_opt.get_item_text(hi) == expected_heads[hi], "Calibrator head_opt[%d] for '%s' must match '%s'" % [hi, v_key, expected_heads[hi]])
		assert_true(expected_heads.has(str(cal_inst.get("_active_head"))), "Calibrator must sanitize incompatible head for view '%s'" % v_key)

	var se_front_before: Vector2 = cal_store.get_head_combo_offset("se", "head_front", false)
	var se_front_scale_before: float = cal_store.get_head_combo_scale("se", "head_front", false)
	var sw_front_before: Vector2 = cal_store.get_head_combo_offset("sw", "head_front", false)
	var base_front_before: Vector2 = cal_store.get_head_sprite_offset("head_front", false)
	cal_inst.call("_switch_view_and_head", "s", "head_front")
	cal_inst.call("_select_target", "head", "head_front")
	cal_inst.call("_set_selected_pos_rel", Vector2(4.0, -16.0))
	(cal_hud["head_scale_spin"] as SpinBox).value = 1.20
	cal_rig._process(0.016)
	var cal_head_spr: Sprite2D = (cal_rig.get_head_data()["sprites"] as Dictionary)["head_front"] as Sprite2D
	var cal_under_spr: Sprite2D = (cal_rig.get_head_under_data()["sprites"] as Dictionary)["head_front"] as Sprite2D
	var cal_base_sc: Vector2 = (cal_rig.get_head_data()["base_scales"] as Dictionary)["head_front"] as Vector2
	assert_true(cal_head_spr.position.distance_to(Vector2(4.0, -16.0)) < 0.02, "Calibrator head combo offset must persist across PlanarCombatRig._process()")
	assert_true(cal_head_spr.scale.distance_to(cal_base_sc * 1.20) < 0.002, "Calibrator head combo scale must persist across PlanarCombatRig._process()")
	assert_true(cal_under_spr.position.distance_to(Vector2(4.0, -16.0)) < 0.02 and cal_under_spr.scale.distance_to(cal_base_sc * 1.20) < 0.002, "Calibrator must keep Pass 1 neck pass synced with Pass 2 head pass")
	assert_true(cal_store.get_head_combo_offset("se", "head_front", false).distance_to(se_front_before) < 0.001, "Adjusting head_front on 's' must not modify 'se' head_front offset")
	assert_true(absf(cal_store.get_head_combo_scale("se", "head_front", false) - se_front_scale_before) < 0.001, "Adjusting head_front on 's' must not modify 'se' head_front scale")
	assert_true(cal_store.get_head_combo_offset("sw", "head_front", false).distance_to(sw_front_before) < 0.001, "Adjusting head_front on 's' must not modify 'sw' head_front offset")
	assert_true(cal_store.get_head_sprite_offset("head_front", false).distance_to(base_front_before) < 0.001, "Adjusting head_front on 's' must not mutate global head_front sprite_offset")

	var s_bc_mat: ShaderMaterial = (cal_rig.get_views()["s"] as Dictionary)["body_core_mat"] as ShaderMaterial
	var neck_u_before: float = float(s_bc_mat.get_shader_parameter("neck_seam_u"))
	cal_inst.call("_select_target", "neck_anchor", "neck_anchor")
	cal_inst.call("_set_selected_pos_rel", cal_store.get_neck_anchor_rel("s", false) + Vector2(12.0, 0.0))
	var neck_u_after: float = float(s_bc_mat.get_shader_parameter("neck_seam_u"))
	assert_true(neck_u_after > neck_u_before + 0.05, "Moving neck_anchor in Calibrator must update body_core neck_seam_u live")

	cal_inst.call("_toggle_layer_vis", "head_under")
	assert_true(cal_under_spr.visible == false and cal_head_spr.visible == true, "Toggling head_under layer must hide Pass 1 neck pass without hiding Pass 2 head")
	cal_inst.call("_toggle_layer_vis", "head_under")
	assert_true(cal_under_spr.visible == true, "Re-toggling head_under layer must restore Pass 1 neck pass")

	cal_inst.call("_toggle_layer_solo", "arm_r")
	var s_polys: Dictionary = (cal_rig.get_views()["s"] as Dictionary)["polys"] as Dictionary
	assert_true((s_polys["arm_r"] as Polygon2D).visible == true and (s_polys["body_core"] as Polygon2D).visible == false, "Solo mode must isolate selected piece and hide others")
	cal_inst.call("_toggle_layer_solo", "arm_r")
	assert_true((s_polys["body_core"] as Polygon2D).visible == true, "Toggling solo off must restore previous visibility")

	# Verificar ajuste fino de outline por pieza (borde transparente + outline externo) y sincronización a shader
	cal_inst.call("_select_target", "part", "leg_r")
	(cal_hud["po_erode_spin"] as SpinBox).value = 1.45
	(cal_hud["po_out_spin"] as SpinBox).value = 1.15
	var s_leg_r_mat: ShaderMaterial = (s_polys["leg_r"] as Polygon2D).material as ShaderMaterial
	var s_leg_r_st_mat: ShaderMaterial = (s_polys["leg_r_stocking"] as Polygon2D).material as ShaderMaterial
	assert_true(bool(s_leg_r_mat.get_shader_parameter("enable_part_edge_outline")) == true, "Adjusting po_erode_spin/po_out_spin must auto-enable per-piece outline")
	assert_true(absf(float(s_leg_r_mat.get_shader_parameter("part_edge_erode_du")) - 1.45) < 0.01, "Per-piece erode_du must propagate to leg_r ShaderMaterial")
	assert_true(absf(float(s_leg_r_mat.get_shader_parameter("part_edge_outline_du")) - 1.15) < 0.01, "Per-piece outline_du must propagate to leg_r ShaderMaterial")
	assert_true(absf(float(s_leg_r_st_mat.get_shader_parameter("part_edge_erode_du")) - 1.45) < 0.01 and absf(float(s_leg_r_st_mat.get_shader_parameter("part_edge_outline_du")) - 1.15) < 0.01, "Per-piece outline must stay synced on leg_r_stocking overlay")
	cal_store.copy_part_outline_to_view("s", "leg_r")
	cal_inst.call("_refresh_live_and_inspector")
	assert_true(absf(float(((s_polys["arm_r"] as Polygon2D).material as ShaderMaterial).get_shader_parameter("part_edge_outline_du")) - 1.15) < 0.01, "copy_part_outline_to_view must propagate outline to all parts in active view")
	cal_store.set_part_outline("se", "arm_r", true, 1.8, 0.9, Color(0.02, 0.02, 0.04, 1.0), false, false)
	cal_store.mirror_view_to_partner("se")
	var sw_arm_l_po: Dictionary = cal_store.get_part_outline("sw", "arm_l", false)
	assert_true(bool(sw_arm_l_po["enabled"]) and absf(float(sw_arm_l_po["erode_du"]) - 1.8) < 0.01 and absf(float(sw_arm_l_po["outline_du"]) - 0.9) < 0.01, "mirror_view_to_partner must mirror part_outlines across R<->L")

	cal_inst.call("_select_target", "head", "head_front")
	(cal_hud["po_erode_spin"] as SpinBox).value = 0.85
	(cal_hud["po_out_spin"] as SpinBox).value = 1.05
	var cal_head_mat: ShaderMaterial = cal_head_spr.material as ShaderMaterial
	var cal_under_mat: ShaderMaterial = cal_under_spr.material as ShaderMaterial
	assert_true(bool(cal_head_mat.get_shader_parameter("enable_part_edge_outline")) and absf(float(cal_head_mat.get_shader_parameter("part_edge_erode_du")) - 0.85) < 0.01 and absf(float(cal_head_mat.get_shader_parameter("part_edge_outline_du")) - 1.05) < 0.01, "Head outline must propagate to Pass 2 head ShaderMaterial")
	assert_true(bool(cal_under_mat.get_shader_parameter("enable_part_edge_outline")) and absf(float(cal_under_mat.get_shader_parameter("part_edge_erode_du")) - 0.85) < 0.01 and absf(float(cal_under_mat.get_shader_parameter("part_edge_outline_du")) - 1.05) < 0.01, "Head outline must stay synced on Pass 1 neck ShaderMaterial")

	cal_inst.call("_step_part_z", "leg_r", 10)
	var s_meshes: Node2D = ((cal_rig.get_views()["s"] as Dictionary)["root"] as Node2D).get_node("Meshes") as Node2D
	for mc: Node in s_meshes.get_children():
		assert_true((mc as CanvasItem).z_index == 0, "Calibrator Z-order reorder must preserve z_index == 0 inside CanvasGroup")

	cal_inst.queue_free()


func _test_shader_lab_scene() -> void:
	var sl_scene: PackedScene = ResourceLoader.load("res://sandbox/pilot_rig_lab/shader_lab/planar_shader_lab.tscn") as PackedScene
	assert_true(sl_scene != null, "Expected planar_shader_lab.tscn to load cleanly")
	var sl_inst: Node2D = sl_scene.instantiate() as Node2D
	assert_true(sl_inst != null, "Expected planar_shader_lab.tscn to instantiate as Node2D")
	add_child(sl_inst)

	var world_vp: SubViewport = sl_inst.get_node_or_null("SupersampledWorldViewport") as SubViewport
	assert_true(world_vp != null, "ShaderLab must instantiate SupersampledWorldViewport for SSAA rendering")
	assert_true(world_vp.use_hdr_2d == true, "SupersampledWorldViewport must enable use_hdr_2d = true")
	var world_display: TextureRect = sl_inst.get("_world_display") as TextureRect
	assert_true(world_display != null and world_display.material != null, "ShaderLab WorldDisplayRect must attach SSAA downsample shader at 2x")
	var base_rig: PlanarCombatRig = world_vp.get_node_or_null("BaselineRig") as PlanarCombatRig
	var sh_rig: PlanarCombatRig = world_vp.get_node_or_null("ShaderRig") as PlanarCombatRig
	assert_true(base_rig != null and sh_rig != null, "ShaderLab must instantiate both BaselineRig and ShaderRig for A/B comparison")
	assert_true(world_vp.get_node_or_null("ShaderLabBackdrop") != null, "ShaderLab must instantiate ShaderLabBackdrop")
	var sl_hud: Node = sl_inst.get_node_or_null("ShaderLabHud")
	assert_true(sl_hud != null, "ShaderLab must instantiate ShaderLabHud")

	var base_core_mat: ShaderMaterial = (base_rig.get_views()["s"] as Dictionary)["body_core_mat"] as ShaderMaterial
	var sh_core_mat: ShaderMaterial = (sh_rig.get_views()["s"] as Dictionary)["body_core_mat"] as ShaderMaterial
	assert_true(bool(base_core_mat.get_shader_parameter("stylize_enabled")) == false, "ShaderLab BaselineRig must start with stylize_enabled == false")
	assert_true(bool(sh_core_mat.get_shader_parameter("stylize_enabled")) == true, "ShaderLab ShaderRig must start with active style (stylize_enabled == true)")
	assert_true(bool(sh_rig.get_pass2_material().get_shader_parameter("enable_outer_outline")) == true, "ShaderLab ShaderRig Pass 2 must start with enable_outer_outline == true")
	assert_true(float(sh_core_mat.get_shader_parameter("albedo_lod_bias_offset")) < -0.4, "ShaderLab default razor-sharp style must apply negative albedo_lod_bias_offset")
	assert_true(float(sh_rig.get_pass2_material().get_shader_parameter("cas_sharpen_strength")) > 0.3, "ShaderLab default razor-sharp style must apply cas_sharpen_strength")

	var vp_size_2x: Vector2i = world_vp.size
	sl_inst.call("_set_supersampling", 1.0)
	var vp_size_1x: Vector2i = world_vp.size
	assert_true(vp_size_2x.x > vp_size_1x.x and vp_size_2x.y > vp_size_1x.y, "SupersampledWorldViewport must scale resolution between 2x and 1x")
	assert_true(world_display.material == null, "ShaderLab WorldDisplayRect must bypass SSAA shader at 1.0x native")
	sl_inst.call("_set_supersampling", 2.0)
	assert_true(world_display.material != null, "ShaderLab WorldDisplayRect must restore SSAA downsample shader at 2.0x")

	var exported_prof: RigStyleProfile = sl_hud.call("export_current_style_profile", "test_export", "Test Export") as RigStyleProfile
	assert_true(exported_prof != null and exported_prof.stylize_enabled == true, "ShaderLabHud export_current_style_profile must preserve stylize_enabled")
	assert_true(exported_prof.cel_strength > 0.5 and exported_prof.shadow_tint.b > exported_prof.shadow_tint.r and exported_prof.outer_outline_width_px > 0.5, "ShaderLabHud export_current_style_profile must preserve cel_strength, indigo shadow_tint, and outer_outline_width_px")
	assert_true(exported_prof.albedo_lod_bias < -0.4 and exported_prof.cas_sharpen_strength > 0.3, "ShaderLabHud export_current_style_profile must preserve sharpness parameters")

	sl_inst.call("_select_view", "se")
	assert_true(base_rig.get_active_view_key() == "se" and sh_rig.get_active_view_key() == "se", "ShaderLab view switch must sync both BaselineRig and ShaderRig to 'se'")
	sl_inst.call("_apply_style_index", 1)
	var se_polys_sh: Dictionary = (sh_rig.get_views()["se"] as Dictionary)["polys"] as Dictionary
	var leg_r_mat: ShaderMaterial = (se_polys_sh["leg_r"] as Polygon2D).material as ShaderMaterial
	assert_true(bool(leg_r_mat.get_shader_parameter("enable_hip_cast_shadow")) == true, "ShaderLab must apply calibrated hip cast shadow on legs")
	assert_true(bool(leg_r_mat.get_shader_parameter("enable_stocking_pinch")) == true, "ShaderLab must apply calibrated stocking pinch on legs")
	sl_inst.queue_free()


func _test_base_pose_config_and_evaluator(test_rig: PlanarCombatRig) -> void:
	var pose_cfg: BasePoseConfigScript = ResourceLoader.load(ValentinaV2BasePosePath) as BasePoseConfigScript
	assert_true(pose_cfg != null, "Expected valentina_v2_base_pose.tres to load as PilotBasePoseConfig")
	pose_cfg.ensure_initialized()
	for fam: String in BasePoseConfigScript.FAMILY_ORDER:
		assert_true(pose_cfg.families.has(fam) and (pose_cfg.families[fam] as Dictionary).size() > 10, "PilotBasePoseConfig must contain calibrated family '%s'" % fam)

	test_rig.set_static_inspection(true, "e", "head_side_r")
	test_rig.calibration_manual_pose = true

	var evaluator := BasePoseEvaluatorScript.new()
	var views: Dictionary = test_rig.get_views()
	var e_vd: Dictionary = views["e"] as Dictionary
	var e_bones: Dictionary = e_vd["bones"] as Dictionary
	var e_rest: Dictionary = e_vd["rest_rots"] as Dictionary
	var e_polys: Dictionary = e_vd["polys"] as Dictionary
	var e_chest: Bone2D = e_bones["Chest"] as Bone2D
	var e_thigh_l: Bone2D = e_bones["Thigh_L"] as Bone2D
	var e_sh_r: Bone2D = e_bones["Shoulder_R"] as Bone2D
	var e_pau_r: Bone2D = e_bones["Pauldron_R"] as Bone2D
	var e_core_mat: ShaderMaterial = (e_polys["body_core"] as Polygon2D).material as ShaderMaterial
	var e_leg_r_mat: ShaderMaterial = (e_polys["leg_r"] as Polygon2D).material as ShaderMaterial

	evaluator.apply_pose_to_rig_view(test_rig, "e", pose_cfg, BasePoseEvaluatorScript.PoseLayerMode.BONES_ONLY, 1.0, false, 0.0)
	var e_chest_delta: float = e_chest.rotation - float(e_rest["Chest"])
	var e_thigh_l_delta: float = e_thigh_l.rotation - float(e_rest["Thigh_L"])
	var e_sh_r_delta: float = e_sh_r.rotation - float(e_rest["Shoulder_R"])
	var e_pau_r_delta: float = e_pau_r.rotation - float(e_rest["Pauldron_R"])
	var exp_follow: float = pose_cfg.get_param("e", "pauldron_follow_ratio")
	assert_true(absf(e_chest_delta) > 0.01 and absf(e_thigh_l_delta) > 0.05, "BONES_ONLY must apply tactical Zero-G bone offsets on E view")
	assert_true(absf(e_pau_r_delta - e_sh_r_delta * exp_follow) < 0.001, "Pauldron_R must track Shoulder_R at configured pauldron_follow_ratio")
	assert_true(int(e_core_mat.get_shader_parameter("persp_mode")) == 0 and int(e_leg_r_mat.get_shader_parameter("persp_mode")) == 0, "BONES_ONLY must keep shader persp_mode == 0")

	evaluator.apply_pose_to_rig_view(test_rig, "w", pose_cfg, BasePoseEvaluatorScript.PoseLayerMode.BONES_ONLY, 1.0, false, 0.0)
	var w_vd: Dictionary = views["w"] as Dictionary
	var w_thigh_r: Bone2D = (w_vd["bones"] as Dictionary)["Thigh_R"] as Bone2D
	var w_thigh_r_delta: float = w_thigh_r.rotation - float((w_vd["rest_rots"] as Dictionary)["Thigh_R"])
	assert_true(absf(e_thigh_l_delta + w_thigh_r_delta) < 0.001, "W lead leg Thigh_R must mirror E lead leg Thigh_L")

	evaluator.apply_pose_to_rig_view(test_rig, "e", pose_cfg, BasePoseEvaluatorScript.PoseLayerMode.SHADER_25D_ONLY, 1.0, false, 0.0)
	assert_true(absf(e_chest.rotation - float(e_rest["Chest"])) < 0.0001 and absf(e_thigh_l.rotation - float(e_rest["Thigh_L"])) < 0.0001, "SHADER_25D_ONLY must reset bones to rest_rots")
	assert_true(int(e_core_mat.get_shader_parameter("persp_mode")) == 2 and int(e_leg_r_mat.get_shader_parameter("persp_mode")) == 1, "SHADER_25D_ONLY must enable torso/limb 2.5D shader modes")
	assert_true(bool(e_leg_r_mat.get_shader_parameter("use_persp_zone_mask")) == true, "SHADER_25D_ONLY must bind leg persp_zone_mask")

	evaluator.apply_pose_to_rig_view(test_rig, "e", pose_cfg, BasePoseEvaluatorScript.PoseLayerMode.COMBINED_BONES_AND_25D, 1.0, false, 0.0)
	var e_neck: Bone2D = e_bones["Neck"] as Bone2D
	assert_true(absf(e_chest.rotation - float(e_rest["Chest"])) > 0.01 and int(e_leg_r_mat.get_shader_parameter("persp_mode")) == 1, "COMBINED mode must activate both Skeleton2D pose and 2.5D shader")
	assert_true(test_rig.get_head_anchor().global_position.distance_to(e_neck.global_position) < 0.01, "sync_head_to_active_neck must keep DecoupledHeadMount anchored to posed Neck bone")

	evaluator.apply_pose_to_rig_view(test_rig, "e", pose_cfg, BasePoseEvaluatorScript.PoseLayerMode.DEFAULT_RIG_REST, 1.0, false, 0.0)
	assert_true(absf(e_chest.rotation - float(e_rest["Chest"])) < 0.0001 and int(e_core_mat.get_shader_parameter("persp_mode")) == 0, "DEFAULT_RIG_REST must cleanly restore rest pose and persp_mode == 0")
	assert_true(float(e_leg_r_mat.get_shader_parameter("leg_depth_phase")) > 0.4, "DEFAULT_RIG_REST must preserve static E leg_depth_phase")

	var idle_cfg: IdleAnimConfigScript = ResourceLoader.load(ValentinaV2IdleAnimPath) as IdleAnimConfigScript
	assert_true(idle_cfg != null, "Expected valentina_v2_idle_anim.tres to load as PilotIdleAnimConfig")
	idle_cfg.ensure_initialized()
	for fam: String in IdleAnimConfigScript.FAMILY_ORDER:
		assert_true(idle_cfg.family_multipliers.has(fam) and (idle_cfg.family_multipliers[fam] as Dictionary).size() >= 5, "PilotIdleAnimConfig must contain family_multipliers for '%s'" % fam)

	var e_pelvis: Bone2D = e_bones["Pelvis"] as Bone2D
	var e_rest_pos: Dictionary = e_vd["rest_pos"] as Dictionary
	var pelvis_rest: Vector2 = e_rest_pos["Pelvis"] as Vector2
	evaluator.apply_pose_to_rig_view(test_rig, "e", pose_cfg, BasePoseEvaluatorScript.PoseLayerMode.COMBINED_BONES_AND_25D, 1.0, true, 0.85, idle_cfg)
	assert_true(e_pelvis.position.distance_to(pelvis_rest) > 0.4, "Idle Zero-G must drive Figure-8 drift on Pelvis.position")
	assert_true(absf(test_rig.get_head_anchor().rotation) > 0.001, "Idle Zero-G Gyro-Lock must apply subtle counter-inertia rotation on DecoupledHeadMount")
	var bc_sec: Vector2 = e_core_mat.get_shader_parameter("secondary_jiggle_l_px") as Vector2
	assert_true(bc_sec.length() > 0.05, "Idle Zero-G Layer 3 must drive body_core secondary_jiggle_l_px")
	var h_over_mat: ShaderMaterial = (test_rig.get_head_data().get("materials", []) as Array)[0] as ShaderMaterial
	var h_under_mat: ShaderMaterial = (test_rig.get_head_under_data().get("materials", []) as Array)[0] as ShaderMaterial
	assert_true(bool(h_over_mat.get_shader_parameter("enable_secondary_jiggle")) == true and bool(h_under_mat.get_shader_parameter("enable_secondary_jiggle")) == true, "Idle Layer 3 must keep Pass 1 and Pass 2 hair jiggle enabled in sync")
	assert_true((h_over_mat.get_shader_parameter("secondary_jiggle_l_px") as Vector2).distance_to(h_under_mat.get_shader_parameter("secondary_jiggle_l_px") as Vector2) < 0.001, "Pass 1 and Pass 2 hair jiggle offsets must match exactly")

	evaluator.apply_pose_to_rig_view(test_rig, "e", pose_cfg, BasePoseEvaluatorScript.PoseLayerMode.COMBINED_BONES_AND_25D, 1.0, false, 0.0, idle_cfg)
	assert_true((e_core_mat.get_shader_parameter("secondary_jiggle_l_px") as Vector2).is_equal_approx(Vector2.ZERO), "Disabling Idle must reset body_core secondary_jiggle_l_px to ZERO")
	assert_true(bool(h_over_mat.get_shader_parameter("enable_secondary_jiggle")) == false and bool(h_under_mat.get_shader_parameter("enable_secondary_jiggle")) == false, "Disabling Idle must disable hair secondary jiggle on both head passes")

	var loco_cfg: LocomotionAnimConfigScript = ResourceLoader.load(ValentinaV2LocomotionPath) as LocomotionAnimConfigScript
	assert_true(loco_cfg != null, "Expected valentina_v2_locomotion_anim.tres to load as PilotLocomotionAnimConfig")
	loco_cfg.ensure_initialized()
	for fam: String in LocomotionAnimConfigScript.FAMILY_ORDER:
		assert_true(loco_cfg.families.has(fam) and (loco_cfg.families[fam] as Dictionary).size() >= 84, "PilotLocomotionAnimConfig must contain all 84 keys for family '%s'" % fam)

	evaluator.apply_pose_to_rig_view(test_rig, "e", pose_cfg, BasePoseEvaluatorScript.PoseLayerMode.COMBINED_BONES_AND_25D, 1.0, false, 0.0, idle_cfg)
	var base_chest_rot_e: float = e_chest.rotation
	var base_thigh_l_rot_e: float = e_thigh_l.rotation

	evaluator.apply_pose_to_rig_view(test_rig, "e", pose_cfg, BasePoseEvaluatorScript.PoseLayerMode.COMBINED_BONES_AND_25D, 1.0, false, 0.0, idle_cfg, loco_cfg, {"fwd": 1.0, "brk": 0.0, "rev": 0.0})
	assert_true(e_chest.rotation > base_chest_rot_e + 0.04, "Forward cruise (fwd=1.0) on E must lean Chest forward")
	var fwd_hair_jiggle: Vector2 = h_over_mat.get_shader_parameter("secondary_jiggle_l_px") as Vector2
	assert_true(bool(h_over_mat.get_shader_parameter("enable_secondary_jiggle")) == true and fwd_hair_jiggle.x < -1.0, "Forward cruise on E must drag hair backward (x < 0)")

	evaluator.apply_pose_to_rig_view(test_rig, "e", pose_cfg, BasePoseEvaluatorScript.PoseLayerMode.COMBINED_BONES_AND_25D, 1.0, false, 0.0, idle_cfg, loco_cfg, {"fwd": 0.0, "brk": 1.0, "rev": 0.0})
	assert_true(e_chest.rotation < base_chest_rot_e - 0.04 and e_thigh_l.rotation < base_thigh_l_rot_e - 0.08, "Brake counter-pitch (brk=1.0) on E must pitch Chest back and swing lead thigh forward")
	var brk_hair_jiggle: Vector2 = h_over_mat.get_shader_parameter("secondary_jiggle_l_px") as Vector2
	assert_true(brk_hair_jiggle.x > 1.0, "Brake counter-pitch on E must throw hair forward by inertia (x > 0)")

	evaluator.reset_live_locomotion_state()
	var live_w: Dictionary = {}
	for _step: int in range(25):
		live_w = evaluator.step_live_locomotion_weights(0.02, 1.0, false, loco_cfg)
	assert_true(float(live_w["fwd"]) > 0.80 and float(live_w["brk"]) < 0.05, "Sustained cruise speed must build fwd weight without brake spike")
	live_w = evaluator.step_live_locomotion_weights(0.02, 0.0, false, loco_cfg)
	assert_true(float(live_w["brk"]) > 0.40, "Sudden stop from cruise must trigger smooth brake counter-pitch weight")
	for _decay: int in range(50):
		live_w = evaluator.step_live_locomotion_weights(0.02, 0.0, false, loco_cfg)
	assert_true(float(live_w["brk"]) < 0.05 and float(live_w["fwd"]) < 0.01, "Live brake weight must decay smoothly back to Idle")

	evaluator.reset_live_locomotion_state()
	for _cruise_step: int in range(25):
		evaluator.step_live_locomotion_weights(0.02, 1.0, false, loco_cfg)
	for decel_i: int in range(1, 16):
		var decel_spd: float = maxf(0.0, 1.0 - float(decel_i) / 15.0)
		live_w = evaluator.step_live_locomotion_weights(0.025, decel_spd, false, loco_cfg)
	assert_true(float(live_w["brk"]) > 0.45 and float(live_w["fwd"]) < 0.25, "Gradual 15-step deceleration must peak smooth brake (>0.45) while retiring forward lean (<0.25)")

	var turn_cfg: TurnAnimConfigScript = ResourceLoader.load(ValentinaV2TurnAnimPath) as TurnAnimConfigScript
	assert_true(turn_cfg != null, "Expected valentina_v2_turn_anim.tres to load as PilotTurnAnimConfig")
	turn_cfg.ensure_initialized()
	for fam: String in TurnAnimConfigScript.FAMILY_ORDER:
		assert_true(turn_cfg.family_multipliers.has(fam), "PilotTurnAnimConfig must contain family_multipliers for '%s'" % fam)

	test_rig.set_static_inspection(true, "s", "head_front")
	var s_vd: Dictionary = views["s"] as Dictionary
	var s_bones: Dictionary = s_vd["bones"] as Dictionary
	var s_rest_pos: Dictionary = s_vd["rest_pos"] as Dictionary
	var s_pelvis: Bone2D = s_bones["Pelvis"] as Bone2D
	var s_chest: Bone2D = s_bones["Chest"] as Bone2D
	var s_pelvis_rest: Vector2 = s_rest_pos["Pelvis"] as Vector2
	var s_core_mat: ShaderMaterial = ((s_vd["polys"] as Dictionary)["body_core"] as Polygon2D).material as ShaderMaterial

	evaluator.apply_pose_to_rig_view(test_rig, "s", pose_cfg, BasePoseEvaluatorScript.PoseLayerMode.COMBINED_BONES_AND_25D, 1.0, false, 0.0, idle_cfg)
	var base_yaw_s: float = float((s_core_mat.get_shader_parameter("persp_params_c") as Vector4).x)
	var base_chest_rot_s: float = s_chest.rotation

	var pre_turn_st: Dictionary = {"body_active": true, "body_t": 0.25, "body_swap_pt": 0.34, "body_turn_dir": 1.0, "body_turn_mag": 1.0, "head_active": false}
	evaluator.apply_pose_to_rig_view(test_rig, "s", pose_cfg, BasePoseEvaluatorScript.PoseLayerMode.COMBINED_BONES_AND_25D, 1.0, false, 0.0, idle_cfg, null, {}, turn_cfg, pre_turn_st)
	var pre_yaw_s: float = float((s_core_mat.get_shader_parameter("persp_params_c") as Vector4).x)
	assert_true(pre_yaw_s > base_yaw_s + 0.05, "Pre-cut body turn (t=0.25, dir=+1) must pre-rotate 2.5D torso_yaw in turn direction")
	assert_true(test_rig.get_head_anchor().rotation > 0.01, "Pre-cut body turn must anticipate DecoupledHeadMount rotation")

	var post_turn_st: Dictionary = {"body_active": true, "body_t": 0.55, "body_swap_pt": 0.34, "body_turn_dir": 1.0, "body_turn_mag": 1.0, "head_active": false}
	evaluator.apply_pose_to_rig_view(test_rig, "s", pose_cfg, BasePoseEvaluatorScript.PoseLayerMode.COMBINED_BONES_AND_25D, 1.0, false, 0.0, idle_cfg, null, {}, turn_cfg, post_turn_st)
	assert_true(s_pelvis.position.x > s_pelvis_rest.x + 0.8, "Post-cut body turn (t=0.55) must drive lateral pelvis whip overshoot")
	var post_hair_jg: Vector2 = h_over_mat.get_shader_parameter("secondary_jiggle_l_px") as Vector2
	assert_true(bool(h_over_mat.get_shader_parameter("enable_secondary_jiggle")) == true and post_hair_jg.length() > 0.5, "Post-cut body turn must drive hair cascade whip on head shaders")

	var head_whip_st: Dictionary = {"body_active": false, "head_active": true, "head_t": 0.35, "head_turn_dir": 1.0}
	evaluator.apply_pose_to_rig_view(test_rig, "s", pose_cfg, BasePoseEvaluatorScript.PoseLayerMode.COMBINED_BONES_AND_25D, 1.0, false, 0.0, idle_cfg, null, {}, turn_cfg, head_whip_st)
	assert_true(test_rig.get_head_anchor().rotation > 0.02, "Head-only cervical whip (t=0.35) must apply overshoot on DecoupledHeadMount")
	assert_true(s_chest.rotation > base_chest_rot_s + 0.008, "Head-only cervical whip must apply sympathetic reaction on Chest")
	var hw_over_jg: Vector2 = h_over_mat.get_shader_parameter("secondary_jiggle_l_px") as Vector2
	var hw_under_jg: Vector2 = h_under_mat.get_shader_parameter("secondary_jiggle_l_px") as Vector2
	assert_true(hw_over_jg.length() > 0.15 and hw_over_jg.distance_to(hw_under_jg) < 0.001, "Head-only cervical whip must sync hair jiggle across Pass 1 and Pass 2")

	var jiggle_cfg: JigglePhysicsConfigScript = ResourceLoader.load(ValentinaV2JigglePath) as JigglePhysicsConfigScript
	assert_true(jiggle_cfg != null, "Expected valentina_v2_jiggle_physics.tres to load as PilotJigglePhysicsConfig")
	jiggle_cfg.ensure_initialized()
	assert_true(jiggle_cfg.bust_max_clamp_px >= 6.0 and jiggle_cfg.bust_max_clamp_px <= 9.0, "3x texture scale must calibrate bust_max_clamp_px cleanly (got %.2f)" % jiggle_cfg.bust_max_clamp_px)
	assert_true(jiggle_cfg.glute_max_clamp_px >= 5.0 and jiggle_cfg.glute_max_clamp_px <= 7.5, "3x texture scale must calibrate glute_max_clamp_px cleanly (got %.2f)" % jiggle_cfg.glute_max_clamp_px)
	assert_true(jiggle_cfg.normal_light_strength <= 0.03, "normal_light_strength must remain gentle to prevent cel-band flicker (got %.3f)" % jiggle_cfg.normal_light_strength)
	for fam: String in JigglePhysicsConfigScript.FAMILY_ORDER:
		assert_true(jiggle_cfg.family_multipliers.has(fam), "PilotJigglePhysicsConfig must contain family_multipliers for '%s'" % fam)

	var s_core_poly: Polygon2D = ((views["s"] as Dictionary)["polys"] as Dictionary)["body_core"] as Polygon2D
	var e_core_poly: Polygon2D = ((views["e"] as Dictionary)["polys"] as Dictionary)["body_core"] as Polygon2D
	var n_core_poly: Polygon2D = ((views["n"] as Dictionary)["polys"] as Dictionary)["body_core"] as Polygon2D
	_assert_secondary_mask_bleeds_safely(s_core_poly, "s")
	_assert_secondary_mask_bleeds_safely(e_core_poly, "e")
	_assert_secondary_mask_bleeds_safely(n_core_poly, "n")

	var s_leg_r_mat: ShaderMaterial = ((views["s"] as Dictionary)["polys"] as Dictionary)["leg_r"].material as ShaderMaterial
	evaluator.apply_pose_to_rig_view(test_rig, "s", pose_cfg, BasePoseEvaluatorScript.PoseLayerMode.COMBINED_BONES_AND_25D, 1.0, true, 0.85, idle_cfg, null, {}, null, {}, jiggle_cfg)
	assert_true((s_leg_r_mat.get_shader_parameter("hip_cast_pelvis_delta") as Vector2).is_equal_approx(Vector2.ZERO), "Hip cast shadow must remain static (hip_cast_pelvis_delta == ZERO) during live animations")
	assert_true(s_leg_r_mat.shader.code.contains("vec2 rest_rig_pos = (part_rig_rect.xy + UV * part_rig_rect.zw) * 490.0;"), "Hip cast shadow in pilot_rig_stylizer.gdshader must sample static rest-pose UV space")

	evaluator.reset_jiggle_physics_state()
	evaluator.trigger_jiggle_impulse(Vector2(20.0, 52.0), Vector2(16.0, -40.0), 1.0)
	for _js: int in range(3):
		evaluator.step_live_jiggle_physics(0.025, {}, {}, jiggle_cfg)

	evaluator.apply_pose_to_rig_view(test_rig, "s", pose_cfg, BasePoseEvaluatorScript.PoseLayerMode.COMBINED_BONES_AND_25D, 1.0, false, 0.0, idle_cfg, null, {}, null, {}, jiggle_cfg)
	var s_jl: Vector2 = s_core_mat.get_shader_parameter("secondary_jiggle_l_px") as Vector2
	var s_jr: Vector2 = s_core_mat.get_shader_parameter("secondary_jiggle_r_px") as Vector2
	assert_true(s_jl.length() > 0.20 and s_jl.length() <= jiggle_cfg.bust_max_clamp_px + 0.001, "Front S bust jiggle must bounce visibly within soft clamp")
	assert_true(not s_jl.is_equal_approx(s_jr), "Front S bust L/R jiggle must preserve subtle asymmetric phase")
	assert_true(float(s_core_mat.get_shader_parameter("secondary_jiggle_normal_strength")) > 0.0, "Jiggle physics must activate subtle 2.5D normal micro-tilt on body_core")

	var n_core_mat: ShaderMaterial = ((views["n"] as Dictionary)["polys"] as Dictionary)["body_core"].material as ShaderMaterial
	evaluator.apply_pose_to_rig_view(test_rig, "n", pose_cfg, BasePoseEvaluatorScript.PoseLayerMode.COMBINED_BONES_AND_25D, 1.0, false, 0.0, idle_cfg, null, {}, null, {}, jiggle_cfg)
	var n_jl: Vector2 = n_core_mat.get_shader_parameter("secondary_jiggle_l_px") as Vector2
	var n_jr: Vector2 = n_core_mat.get_shader_parameter("secondary_jiggle_r_px") as Vector2
	assert_true(n_jl.length() > 0.15 and n_jl.length() <= jiggle_cfg.glute_max_clamp_px + 0.001, "Back N glute jiggle must bounce visibly within soft clamp")
	assert_true(not n_jl.is_equal_approx(n_jr), "Back N glute L/R jiggle must preserve subtle asymmetric phase")

	evaluator.apply_pose_to_rig_view(test_rig, "e", pose_cfg, BasePoseEvaluatorScript.PoseLayerMode.COMBINED_BONES_AND_25D, 1.0, false, 0.0, idle_cfg, null, {}, null, {}, jiggle_cfg)
	var e_jl: Vector2 = e_core_mat.get_shader_parameter("secondary_jiggle_l_px") as Vector2
	var e_jr: Vector2 = e_core_mat.get_shader_parameter("secondary_jiggle_r_px") as Vector2
	assert_true(e_jl.distance_to(e_jr) > 0.4 and e_jl.y > 0.0 and e_jr.y < 0.0, "Profile E must drive bust (L/R_mask) independently from glute (R/G_mask)")
	assert_true(float(e_core_mat.get_shader_parameter("secondary_jiggle_normal_strength")) > 0.0, "Profile E must enable secondary_jiggle_normal_strength")

	test_rig.calibration_manual_pose = false
	test_rig.set_static_inspection(false)

	var anim_scene: PackedScene = ResourceLoader.load("res://sandbox/pilot_rig_lab/proto/planar_anim_test.tscn") as PackedScene
	assert_true(anim_scene != null, "Expected planar_anim_test.tscn to load cleanly")
	var anim_inst: Node2D = anim_scene.instantiate() as Node2D
	assert_true(anim_inst != null, "Expected planar_anim_test.tscn to instantiate as Node2D")
	add_child(anim_inst)
	var entries: Array = anim_inst.get("_rig_entries") as Array
	assert_true(entries.size() == 8, "Pose Lab compass must instantiate all 8 directional rigs (got %d)" % entries.size())
	assert_true(anim_inst.get("_idle_cfg") != null and anim_inst.get("_loco_cfg") != null and anim_inst.get("_kiting_cfg") != null and anim_inst.get("_turn_cfg") != null and anim_inst.get("_jiggle_cfg") != null and bool(anim_inst.get("_micro_hover_enabled")) == true, "Pose Lab must load idle, locomotion, kiting, turn, and jiggle .tres configs")
	assert_true(bool(anim_inst.get("_face_live_enabled")) == true and (entries[0]["rig"] as PlanarCombatRig).is_face_live_enabled(), "Pose Lab compass must initialize live face rig enabled on all 8 compass rigs")
	var lab_hud_obj: Variant = anim_inst.get("_hud")
	assert_true(lab_hud_obj != null and int(lab_hud_obj.call("get_active_tab")) == 5 and bool(anim_inst.get("_kiting_preview_enabled")) == true, "Pose Lab must start on Kiting 360 tab (5) with preview active")
	for k_mode: int in range(5):
		anim_inst.call("_on_kiting_mode_changed", k_mode)
		assert_true(int(anim_inst.get("_kiting_preview_mode")) == k_mode, "Pose Lab must switch cleanly to Kiting preview mode %d" % k_mode)
	anim_inst.call("_on_kiting_mode_changed", 0)
	lab_hud_obj.call("set_active_tab", 0)
	assert_true(int(lab_hud_obj.call("get_active_tab")) == 0 and bool(anim_inst.get("_loco_preview_enabled")) == false and bool(anim_inst.get("_turn_preview_enabled")) == false and bool(anim_inst.get("_jiggle_preview_enabled")) == false and bool(anim_inst.get("_kiting_preview_enabled")) == false, "Switching to Pose Base tab (0) must disable flight, turn, jiggle, and kiting previews")
	lab_hud_obj.call("set_active_tab", 2)
	assert_true(int(lab_hud_obj.call("get_active_tab")) == 2 and bool(anim_inst.get("_loco_preview_enabled")) == true and bool(anim_inst.get("_turn_preview_enabled")) == false, "Switching to Flight/Brake tab (2) must activate flight preview")
	lab_hud_obj.call("set_active_tab", 3)
	assert_true(int(lab_hud_obj.call("get_active_tab")) == 3 and bool(anim_inst.get("_turn_preview_enabled")) == true and bool(anim_inst.get("_jiggle_preview_enabled")) == false, "Switching to Snappy Turns tab (3) must activate turn preview")
	anim_inst.call("_trigger_turn_step_now")
	assert_true(not ((entries[0] as Dictionary).get("turn_state", {}) as Dictionary).is_empty(), "Triggering turn step in Pose Lab must populate turn_state on compass entries")
	lab_hud_obj.call("set_active_tab", 4)
	assert_true(int(lab_hud_obj.call("get_active_tab")) == 4 and bool(anim_inst.get("_jiggle_preview_enabled")) == true and bool(anim_inst.get("_kiting_preview_enabled")) == false, "Switching to Jiggle tab (4) must activate jiggle preview")
	assert_true(bool(anim_inst.call("_is_jiggle_turn_choreo_active")) and bool(anim_inst.call("_is_jiggle_loco_choreo_active")), "Jiggle tab Mode 0 must run combined turn and locomotion choreography")
	anim_inst.set("_turn_step_counter", 0)
	(entries[0] as Dictionary)["turn_state"] = {}
	for _jt: int in range(8):
		anim_inst.call("_process", 0.05)
	assert_true(not ((entries[0] as Dictionary).get("turn_state", {}) as Dictionary).is_empty(), "Jiggle tab Mode 0 must actively trigger 8-dir turns during live choreography")
	anim_inst.call("_on_slowmo_changed", 2)
	assert_true(absf(float(anim_inst.get("_time_scale")) - 0.25) < 0.001, "Slow-Mo preset index 2 must set 0.25x _time_scale")
	anim_inst.call("_on_slowmo_changed", 0)
	assert_true(absf(float(anim_inst.get("_time_scale")) - 1.0) < 0.001, "Slow-Mo preset index 0 must restore 1.00x _time_scale")
	anim_inst.call("_trigger_jiggle_impulse_now")
	assert_true((anim_inst.get("_evaluator") as BasePoseEvaluatorScript).get("_bust_vel_l").length() > 1.0, "Triggering jiggle impulse in Pose Lab must excite 2D bust springs")
	anim_inst.call("_on_idle_cadence_changed", 1)
	assert_true(int((anim_inst.get("_idle_cfg") as IdleAnimConfigScript).cadence_mode) == 1, "Pose Lab must update Idle cadence mode")
	anim_inst.call("_on_idle_layer_toggled", "enable_secondary_layer", false)
	assert_true((anim_inst.get("_idle_cfg") as IdleAnimConfigScript).enable_secondary_layer == false, "Pose Lab must toggle Idle layers independently")
	anim_inst.call("_on_family_selected", "e")
	assert_true(str(anim_inst.get("_selected_family")) == "e", "Pose Lab must switch active family cleanly")
	anim_inst.call("_toggle_ab_pose")
	assert_true(int(anim_inst.get("_layer_mode")) == BasePoseEvaluatorScript.PoseLayerMode.DEFAULT_RIG_REST, "Tab A/B toggle must switch to DEFAULT_RIG_REST")
	anim_inst.call("_toggle_ab_pose")
	assert_true(int(anim_inst.get("_layer_mode")) == BasePoseEvaluatorScript.PoseLayerMode.COMBINED_BONES_AND_25D, "Tab A/B toggle must return to COMBINED_BONES_AND_25D")
	anim_inst.queue_free()


func _test_kiting_360_system(profile: PilotRigProfile, test_rig: PlanarCombatRig) -> void:
	assert_true(ResourceLoader.exists(ValentinaV2KitingPath), "Missing valentina_v2_kiting_anim.tres")
	var k_res: Resource = ResourceLoader.load(ValentinaV2KitingPath)
	assert_true(k_res is KitingAnimConfigScript, "Expected PilotKitingAnimConfig in valentina_v2_kiting_anim.tres")
	assert_true(profile.kiting_anim_config is KitingAnimConfigScript, "valentina_v2_profile.tres must link kiting_anim_config")
	var k_cfg: KitingAnimConfigScript = (k_res as KitingAnimConfigScript).duplicate(true) as KitingAnimConfigScript
	k_cfg.ensure_initialized()
	for fam_key: String in ["s", "se", "e", "ne", "n"]:
		var f_dict: Dictionary = k_cfg.get_family_dict(fam_key)
		for pfx: String in KitingAnimConfigScript.PHASE_PREFIXES:
			assert_true(f_dict.has(pfx + "pelvis_shift_x") and f_dict.has(pfx + "knee_lead_rot") and f_dict.has(pfx + "torso_trap"), "Kiting family '%s' missing phase '%s' keys" % [fam_key, pfx])

	var pose_cfg: BasePoseConfigScript = (ResourceLoader.load(ValentinaV2BasePosePath) as BasePoseConfigScript).duplicate(true) as BasePoseConfigScript
	var evaluator := BasePoseEvaluatorScript.new()
	evaluator.ensure_assets_loaded()
	var k_eval := KitingEvaluatorScript.new()

	# 1. Vuelo puro hacia adelante -> pesos de kiting cercanos a 0
	var w_fwd: Dictionary = {}
	for _f: int in range(15):
		w_fwd = k_eval.step_live_weights(0.02, 1.0, Vector2.RIGHT, Vector2.RIGHT, "e", false, k_cfg)
	assert_true(float(w_fwd.get("kiting_total", 1.0)) < 0.05, "Straight forward flight must produce near-zero kiting weights (got %.3f)" % float(w_fwd.get("kiting_total", 1.0)))

	# 2. Reversa 180° en perfil 'e' -> Hover-Slide reclinado sin doblar rodillas hacia atrás
	k_eval.reset_state()
	var w_rev: Dictionary = {}
	for _r: int in range(30):
		w_rev = k_eval.step_live_weights(0.02, 1.0, Vector2.LEFT, Vector2.RIGHT, "e", true, k_cfg)
	assert_true(float(w_rev.get("rev", 0.0)) > 0.7, "Reverse 180 flight must drive rev > 0.7 (got %.3f)" % float(w_rev.get("rev", 0.0)))

	test_rig.calibration_manual_pose = true
	test_rig.set_static_inspection(true, "e", "head_side_r")
	var e_views: Dictionary = test_rig.get_views()
	var e_bones: Dictionary = (e_views["e"] as Dictionary)["bones"] as Dictionary
	var e_rest: Dictionary = (e_views["e"] as Dictionary)["rest_rots"] as Dictionary
	evaluator.apply_pose_to_rig_view(test_rig, "e", pose_cfg, BasePoseEvaluatorScript.PoseLayerMode.COMBINED_BONES_AND_25D, 1.0, false, 0.0)
	var base_chest_e: float = (e_bones["Chest"] as Bone2D).rotation
	evaluator.apply_pose_to_rig_view(test_rig, "e", pose_cfg, BasePoseEvaluatorScript.PoseLayerMode.COMBINED_BONES_AND_25D, 1.0, false, 0.0, null, null, {}, null, {}, null, k_cfg, w_rev)
	var rev_chest_e: float = (e_bones["Chest"] as Bone2D).rotation
	var rev_knee_l: float = (e_bones["Knee_L"] as Bone2D).rotation - float(e_rest.get("Knee_L", 0.0))
	var rev_knee_r: float = (e_bones["Knee_R"] as Bone2D).rotation - float(e_rest.get("Knee_R", 0.0))
	assert_true(rev_chest_e < base_chest_e - 0.04, "Hover-Slide reverse in 'e' must recline Chest backward relative to base pose")
	assert_true(rev_knee_l >= 0.0 and rev_knee_r >= 0.0, "Hover-Slide reverse knees in 'e' must stay >= 0.0 (L=%.3f, R=%.3f)" % [rev_knee_l, rev_knee_r])

	# 3. Simetría de Strafe Lateral e ↔ w (hacia cámara +Y = str_near; hacia fondo -Y = str_far)
	var eval_e := KitingEvaluatorScript.new()
	var eval_w := KitingEvaluatorScript.new()
	var w_e_near: Dictionary = {}
	var w_w_near: Dictionary = {}
	for _sn: int in range(30):
		w_e_near = eval_e.step_live_weights(0.02, 1.0, Vector2.DOWN, Vector2.RIGHT, "e", true, k_cfg)
		w_w_near = eval_w.step_live_weights(0.02, 1.0, Vector2.DOWN, Vector2.LEFT, "w", true, k_cfg)
	assert_true(float(w_e_near.get("str_near", 0.0)) > 0.7 and float(w_w_near.get("str_near", 0.0)) > 0.7, "Moving +Y while facing E or W must drive mirrored str_near > 0.7")

	eval_e.reset_state()
	eval_w.reset_state()
	var w_e_far: Dictionary = {}
	var w_w_far: Dictionary = {}
	for _sf: int in range(30):
		w_e_far = eval_e.step_live_weights(0.02, 1.0, Vector2.UP, Vector2.RIGHT, "e", true, k_cfg)
		w_w_far = eval_w.step_live_weights(0.02, 1.0, Vector2.UP, Vector2.LEFT, "w", true, k_cfg)
	assert_true(float(w_e_far.get("str_far", 0.0)) > 0.7 and float(w_w_far.get("str_far", 0.0)) > 0.7, "Moving -Y while facing E or W must drive mirrored str_far > 0.7")

	# 4. Antisimetría lateral en vista frontal 's' (-X vs +X invierten Pelvis.position.x y Chest.rotation)
	test_rig.set_static_inspection(true, "s", "head_front")
	var s_bones: Dictionary = (e_views["s"] as Dictionary)["bones"] as Dictionary
	var s_rest_pos: Vector2 = ((e_views["s"] as Dictionary)["rest_pos"] as Dictionary)["Pelvis"] as Vector2
	var w_s_left := KitingEvaluatorScript.compute_preview_weights(KitingAnimConfigScript.PreviewMode.STRAFE_NEAR_R, 0.0)
	var w_s_right := KitingEvaluatorScript.compute_preview_weights(KitingAnimConfigScript.PreviewMode.STRAFE_FAR_L, 0.0)
	evaluator.apply_pose_to_rig_view(test_rig, "s", pose_cfg, BasePoseEvaluatorScript.PoseLayerMode.COMBINED_BONES_AND_25D, 1.0, false, 0.0, null, null, {}, null, {}, null, k_cfg, w_s_left)
	var pelv_dx_l: float = (s_bones["Pelvis"] as Bone2D).position.x - s_rest_pos.x
	var chest_s_l: float = (s_bones["Chest"] as Bone2D).rotation
	evaluator.apply_pose_to_rig_view(test_rig, "s", pose_cfg, BasePoseEvaluatorScript.PoseLayerMode.COMBINED_BONES_AND_25D, 1.0, false, 0.0, null, null, {}, null, {}, null, k_cfg, w_s_right)
	var pelv_dx_r: float = (s_bones["Pelvis"] as Bone2D).position.x - s_rest_pos.x
	var chest_s_r: float = (s_bones["Chest"] as Bone2D).rotation
	assert_true(pelv_dx_l < -1.5 and pelv_dx_r > 1.5 and chest_s_l * chest_s_r < 0.0, "Front 's' lateral strafe must drive antisymmetric Pelvis X shift and Chest bank")

	# 5. Freno de Reversa (al frenar desde kiting activo dispara rbrk > 0.4 y luego decae)
	var w_rbrk_peak: Dictionary = k_eval.step_live_weights(0.02, 0.0, Vector2.ZERO, Vector2.RIGHT, "e", true, k_cfg)
	assert_true(float(w_rbrk_peak.get("rbrk", 0.0)) > 0.4, "Stopping from sustained reverse flight must trigger reverse brake rbrk > 0.4 (got %.3f)" % float(w_rbrk_peak.get("rbrk", 0.0)))
	var w_rbrk_settle: Dictionary = w_rbrk_peak
	for _d: int in range(30):
		w_rbrk_settle = k_eval.step_live_weights(0.03, 0.0, Vector2.ZERO, Vector2.RIGHT, "e", false, k_cfg)
	assert_true(float(w_rbrk_settle.get("rbrk", 1.0)) < 0.15, "Reverse brake weight must decay smoothly toward 0.0 (got %.3f)" % float(w_rbrk_settle.get("rbrk", 1.0)))

	# 6. Telemetría live en PlanarCombatRig (strafe lateral y reversa)
	test_rig.calibration_manual_pose = false
	test_rig.set_static_inspection(false)
	var combat_rig: PlanarCombatRig = PlanarCombatRigScript.new()
	combat_rig.pilot_profile = profile
	add_child(combat_rig)
	combat_rig.set_locomotion_state(Vector2.DOWN, 1.0, Vector2.RIGHT, true)
	for _c: int in range(25):
		combat_rig._process(0.02)
	var kw_live: Dictionary = combat_rig.get_live_kiting_weights()
	assert_true(float(kw_live.get("str_near", 0.0)) > 0.6 and "STRAFE" in combat_rig.get_loco_state_tag(), "Live PlanarCombatRig lateral strafe must expose str_near > 0.6 and STRAFE tag (got '%s')" % combat_rig.get_loco_state_tag())
	combat_rig.set_kiting_anim_enabled(false)
	assert_true(combat_rig.get_live_kiting_weights().is_empty(), "set_kiting_anim_enabled(false) must clear live kiting weights")
	combat_rig.queue_free()


func _test_forward_flight_parallel_legs(test_rig: PlanarCombatRig) -> void:
	var pose_cfg: BasePoseConfigScript = (ResourceLoader.load(ValentinaV2BasePosePath) as BasePoseConfigScript).duplicate(true) as BasePoseConfigScript
	var idle_cfg: IdleAnimConfigScript = (ResourceLoader.load(ValentinaV2IdleAnimPath) as IdleAnimConfigScript).duplicate(true) as IdleAnimConfigScript
	var loco_cfg: LocomotionAnimConfigScript = (ResourceLoader.load(ValentinaV2LocomotionPath) as LocomotionAnimConfigScript).duplicate(true) as LocomotionAnimConfigScript
	assert_true(loco_cfg != null and loco_cfg.fwd_leg_sync_blend >= 0.7, "valentina_v2_locomotion_anim.tres must enable fwd_leg_sync_blend >= 0.7 (got %.2f)" % (loco_cfg.fwd_leg_sync_blend if loco_cfg != null else -1.0))

	var evaluator := BasePoseEvaluatorScript.new()
	evaluator.ensure_assets_loaded()
	var views: Dictionary = test_rig.get_views()
	var fwd_weights: Dictionary = {"fwd": 1.0, "brk": 0.0, "rev": 0.0}
	var brk_weights: Dictionary = {"fwd": 0.0, "brk": 1.0, "rev": 0.0}

	var inv_rig_scale: float = 1.0 / maxf(test_rig.scale.x, 0.001)
	test_rig.calibration_manual_pose = true

	# 1. Paralelismo real en espacio de mundo en las 8 vistas (compensando A-pose del rest pose)
	var all_8_views: Array[Array] = [
		["s", "head_front"], ["se", "head_front_r"], ["e", "head_side_r"], ["ne", "head_back_r"],
		["n", "head_back"], ["nw", "head_back_l"], ["w", "head_side"], ["sw", "head_front_l"],
	]
	for vc: Array in all_8_views:
		var v_key: String = str(vc[0])
		var h_key: String = str(vc[1])
		test_rig.set_static_inspection(true, v_key, h_key)
		var vd: Dictionary = views[v_key] as Dictionary
		var bones: Dictionary = vd["bones"] as Dictionary
		evaluator.apply_pose_to_rig_view(test_rig, v_key, pose_cfg, BasePoseEvaluatorScript.PoseLayerMode.COMBINED_BONES_AND_25D, 1.0, false, 0.0, idle_cfg, loco_cfg, fwd_weights)
		var th_l_vec: Vector2 = ((bones["Knee_L"] as Bone2D).global_position - (bones["Thigh_L"] as Bone2D).global_position) * inv_rig_scale
		var th_r_vec: Vector2 = ((bones["Knee_R"] as Bone2D).global_position - (bones["Thigh_R"] as Bone2D).global_position) * inv_rig_scale
		var sh_l_vec: Vector2 = ((bones["Ankle_L"] as Bone2D).global_position - (bones["Knee_L"] as Bone2D).global_position) * inv_rig_scale
		var sh_r_vec: Vector2 = ((bones["Ankle_R"] as Bone2D).global_position - (bones["Knee_R"] as Bone2D).global_position) * inv_rig_scale
		var th_diff: float = absf(th_l_vec.angle_to(th_r_vec))
		var sh_diff: float = absf(sh_l_vec.angle_to(sh_r_vec))
		assert_true(th_diff < 0.08, "Forward flight '%s' world-space thighs must be parallel (< 0.08 rad, got %.3f)" % [v_key, th_diff])
		assert_true(sh_diff < 0.08, "Forward flight '%s' world-space shins must be parallel (< 0.08 rad, got %.3f)" % [v_key, sh_diff])
		if v_key == "e":
			assert_true(th_l_vec.x < -10.0 and th_r_vec.x < -10.0, "Forward flight 'e' thighs must sweep backward (dx_L=%.1f, dx_R=%.1f)" % [th_l_vec.x, th_r_vec.x])
		elif v_key == "w":
			assert_true(th_l_vec.x > 10.0 and th_r_vec.x > 10.0, "Forward flight 'w' thighs must sweep backward (dx_L=%.1f, dx_R=%.1f)" % [th_l_vec.x, th_r_vec.x])
		elif v_key == "s" or v_key == "n":
			var th_l_vert: float = absf(th_l_vec.angle_to(Vector2.DOWN))
			var th_r_vert: float = absf(th_r_vec.angle_to(Vector2.DOWN))
			var sh_l_vert: float = absf(sh_l_vec.angle_to(Vector2.DOWN))
			var sh_r_vert: float = absf(sh_r_vec.angle_to(Vector2.DOWN))
			assert_true(th_l_vert < 0.06 and th_r_vert < 0.06, "Forward flight '%s' thighs must be vertical without A-pose (L=%.3f, R=%.3f)" % [v_key, th_l_vert, th_r_vert])
			assert_true(sh_l_vert < 0.06 and sh_r_vert < 0.06, "Forward flight '%s' shins must be vertical without A-pose (L=%.3f, R=%.3f)" % [v_key, sh_l_vert, sh_r_vert])

	# 2. Sincronización de Idle en vuelo 'fwd' (e en t=0.0 y t=0.8) + no-regresión de freno 'brk'
	test_rig.set_static_inspection(true, "e", "head_side_r")
	var evd: Dictionary = views["e"] as Dictionary
	var ebones: Dictionary = evd["bones"] as Dictionary
	for sample_t: float in [0.0, 0.8]:
		evaluator.apply_pose_to_rig_view(test_rig, "e", pose_cfg, BasePoseEvaluatorScript.PoseLayerMode.COMBINED_BONES_AND_25D, 1.0, true, sample_t, idle_cfg, loco_cfg, fwd_weights)
		var ith_l: Vector2 = (ebones["Knee_L"] as Bone2D).global_position - (ebones["Thigh_L"] as Bone2D).global_position
		var ith_r: Vector2 = (ebones["Knee_R"] as Bone2D).global_position - (ebones["Thigh_R"] as Bone2D).global_position
		var idiff: float = absf(ith_l.angle_to(ith_r))
		assert_true(idiff < 0.08, "Idle + Forward cruise at t=%.1f on 'e' must keep world-space thighs parallel (diff=%.3f)" % [sample_t, idiff])

	evaluator.apply_pose_to_rig_view(test_rig, "e", pose_cfg, BasePoseEvaluatorScript.PoseLayerMode.COMBINED_BONES_AND_25D, 1.0, false, 0.0, idle_cfg)
	var base_chest_e: float = (ebones["Chest"] as Bone2D).rotation
	var base_thigh_l_e: float = (ebones["Thigh_L"] as Bone2D).rotation
	evaluator.apply_pose_to_rig_view(test_rig, "e", pose_cfg, BasePoseEvaluatorScript.PoseLayerMode.COMBINED_BONES_AND_25D, 1.0, false, 0.0, idle_cfg, loco_cfg, brk_weights)
	assert_true((ebones["Chest"] as Bone2D).rotation < base_chest_e - 0.04 and (ebones["Thigh_L"] as Bone2D).rotation < base_thigh_l_e - 0.08, "Brake counter-pitch (brk=1.0) must remain unaffected")

	test_rig.calibration_manual_pose = false
	test_rig.set_static_inspection(false)


func _assert_dual_ew_secondary_mask(mat: ShaderMaterial, view_label: String) -> void:
	var tex: Texture2D = mat.get_shader_parameter("secondary_jiggle_mask_tex") as Texture2D
	assert_true(tex != null, "Expected secondary_jiggle_mask_tex on profile %s" % view_label)
	var img: Image = tex.get_image()
	var w: int = img.get_width()
	var h: int = img.get_height()
	var sum_ry: float = 0.0
	var sum_rw: float = 0.0
	var sum_gy: float = 0.0
	var sum_gw: float = 0.0
	for y: int in range(0, h, 3):
		var yn: float = float(y) / maxf(float(h), 1.0)
		for x: int in range(0, w, 3):
			var c: Color = img.get_pixel(x, y)
			if c.r > 0.08:
				sum_ry += yn * c.r
				sum_rw += c.r
			if c.g > 0.08:
				sum_gy += yn * c.g
				sum_gw += c.g
	assert_true(sum_rw > 5.0 and sum_gw > 5.0, "Profile %s dual secondary mask must populate both R (bust) and G (glute)" % view_label)
	var mean_ry: float = sum_ry / maxf(sum_rw, 0.001)
	var mean_gy: float = sum_gy / maxf(sum_gw, 0.001)
	assert_true(mean_ry < 0.50 and mean_gy > 0.56, "Profile %s must keep R in upper bust (<0.50, got %.3f) and G in lower glute (>0.56, got %.3f)" % [view_label, mean_ry, mean_gy])


func _assert_secondary_mask_bleeds_safely(poly: Polygon2D, view_label: String) -> void:
	assert_true(poly != null and poly.texture != null and poly.material is ShaderMaterial, "Expected body_core Polygon2D on '%s'" % view_label)
	var mat: ShaderMaterial = poly.material as ShaderMaterial
	var mask_tex: Texture2D = mat.get_shader_parameter("secondary_jiggle_mask_tex") as Texture2D
	assert_true(mask_tex != null, "Expected secondary_jiggle_mask_tex on '%s'" % view_label)
	var bc_img: Image = poly.texture.get_image()
	var m_img: Image = mask_tex.get_image()
	var w: int = m_img.get_width()
	var h: int = m_img.get_height()
	var pad_weighted: int = 0
	var max_border: float = 0.0
	for y: int in range(0, h, 2):
		for x: int in range(0, w, 2):
			var mc: Color = m_img.get_pixel(x, y)
			var mw: float = maxf(mc.r, mc.g)
			if y <= 2 or y >= h - 3 or x <= 2 or x >= w - 3:
				max_border = maxf(max_border, mw)
			elif mw > 0.25 and x < bc_img.get_width() and y < bc_img.get_height():
				if bc_img.get_pixel(x, y).a < 0.25:
					pad_weighted += 1
	assert_true(pad_weighted > 20, "Secondary mask '%s' must extend outward into transparent contour padding (got %d samples)" % [view_label, pad_weighted])
	assert_true(max_border <= 0.01, "Secondary mask '%s' must keep outer border perimeter zeroed to avoid UV clamp smear (got %.3f)" % [view_label, max_border])


func _count_mask_channel_px(img: Image, ch: int) -> int:
	var count: int = 0
	var w: int = img.get_width()
	var h: int = img.get_height()
	for y: int in range(0, h, 2):
		for x: int in range(0, w, 2):
			var c: Color = img.get_pixel(x, y)
			var val: float = c.r if ch == 0 else (c.g if ch == 1 else (c.b if ch == 2 else c.a))
			if val > 0.5:
				count += 1
	return count * 4


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

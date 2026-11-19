extends BaseTestSuite

const PlanarCombatRigScript = preload("res://sandbox/pilot_rig_lab/proto/planar_combat_rig.gd")
const HudBuilderScript = preload("res://sandbox/pilot_rig_lab/proto/planar_lab_hud_builder.gd")
const RigCalibrationStoreScript = preload("res://sandbox/pilot_rig_lab/calibrator/rig_calibration_store.gd")
const ValentinaV2ProfilePath: String = "res://sandbox/pilot_rig_lab/pilots/valentina_v2/valentina_v2_profile.tres"


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
	_test_lab_scene_and_matrix()
	_test_calibrator_scene_and_store()
	pass_suite("Valentina v2 (8-Dir) purged rig + pure direction routing + masks + Lab HUD + Calibrator verified.")


func _test_profile_and_metrics() -> PilotRigProfile:
	var scanned_profiles: Array[PilotRigProfile] = HudBuilderScript.scan_pilot_profiles()
	assert_true(scanned_profiles.size() == 1 and scanned_profiles[0].pilot_id == "valentina_v2", "Expected ONLY valentina_v2 in pilots/*/*.tres (got %d)" % scanned_profiles.size())

	var profile: PilotRigProfile = ResourceLoader.load(ValentinaV2ProfilePath) as PilotRigProfile
	assert_true(profile != null, "Expected valentina_v2_profile.tres to load via ResourceLoader")
	assert_true(profile.skins.size() == 10, "Expected 10 PilotSkinPreset resources in valentina_v2_profile.tres")
	assert_true(profile.hair_presets.size() == 10, "Expected 10 PilotHairPreset resources in valentina_v2_profile.tres")
	assert_true(profile.style_profiles.size() == 9, "Expected 9 RigStyleProfile resources in valentina_v2_profile.tres")
	assert_true(profile.skins[0].is_base_skin == true, "Skin 0 must have explicit is_base_skin == true")
	assert_true(profile.skins[3].is_base_skin == false, "Non-base skin must have is_base_skin == false")
	assert_true(profile.hair_presets[1].follow_skin_hair == true, "Hair preset 1 must have follow_skin_hair == true")
	assert_true(profile.anim_config != null and profile.anim_config.resource_path.ends_with("valentina_v2_anim_config.tres"), "Valentina v2 must use valentina_v2_anim_config.tres")
	assert_true(absf(profile.head_outline_width_px - 4.0) < 0.05, "Valentina v2 calibrated head_outline_width_px must be ~4.0 px")

	var metrics_file := FileAccess.open("res://sandbox/pilot_rig_lab/combat_assets/valentina_v2_planar/body_metrics.json", FileAccess.READ)
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
	planar.apply_style_profile(profile.style_profiles[2])
	planar.apply_skin_preset(profile.skins[3])
	var lit_col_after: Color = init_p2.get_shader_parameter("outer_outline_lit_color") as Color
	assert_true(not lit_col_before.is_equal_approx(lit_col_after), "Changing PilotSkinPreset must update Pass 2 outer_outline_lit_color")
	assert_true(float(init_p2.get_shader_parameter("outer_outline_tint_mix")) > 0.1, "apply_style_profile must unlock outer_outline_tint_mix > 0")

	var core_mat: ShaderMaterial = (views["s"] as Dictionary).get("body_core_mat", null) as ShaderMaterial
	assert_true(core_mat != null, "Expected body_core_mat on view S")
	assert_true(bool(core_mat.get_shader_parameter("enable_shader_recolor")) == true, "Shader recolor must activate on non-base skin")
	assert_true(int(core_mat.get_shader_parameter("pipeline_style_mode")) == 2, "Pipeline style mode must be 2")
	var se_core_mat: ShaderMaterial = (views["se"] as Dictionary).get("body_core_mat", null) as ShaderMaterial
	assert_true(se_core_mat != null and bool(se_core_mat.get_shader_parameter("enable_shader_recolor")), "Valentina v2 'se' view must activate shader recolor on non-base skin")

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

	var head_mats: Array = planar.get_head_data().get("materials", []) as Array
	assert_true(not head_mats.is_empty(), "Valentina v2 must build decoupled head materials")
	var hf_mat: ShaderMaterial = head_mats[0] as ShaderMaterial
	assert_true(bool(hf_mat.get_shader_parameter("has_outline_sdf")) == true, "Decoupled heads must connect *_outline_sdf.png")
	assert_true(is_equal_approx(float(hf_mat.get_shader_parameter("sdf_pad_px")), 32.0) and is_equal_approx(float(hf_mat.get_shader_parameter("head_outline_width_px")), 4.0), "Head SDF uniforms must match divisor=32 and width_px=4")
	var hu_mats: Array = planar.get_head_under_data().get("materials", []) as Array
	assert_true(not hu_mats.is_empty(), "Expected _head_under_data materials")

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

	var hm_file := FileAccess.open("res://sandbox/pilot_rig_lab/combat_assets/valentina_v2_planar/heads/heads_metadata.json", FileAccess.READ)
	assert_true(hm_file != null, "Expected valentina_v2 heads_metadata.json")
	var hm_dict: Dictionary = JSON.parse_string(hm_file.get_as_text()) as Dictionary
	var has_head_overrides: bool = FileAccess.file_exists("res://sandbox/pilot_rig_lab/combat_assets/valentina_v2_planar/manual_calibration_overrides.json")
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
	var p_meta_f := FileAccess.open("res://sandbox/pilot_rig_lab/combat_assets/valentina_v2_planar/%s/parts_5/parts_5_meta.json" % p_vk, FileAccess.READ)
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


func _test_lab_scene_and_matrix() -> void:
	var lab_scene: PackedScene = ResourceLoader.load("res://sandbox/pilot_rig_lab/proto/planar_combat_rig_proto.tscn") as PackedScene
	assert_true(lab_scene != null, "Expected planar_combat_rig_proto.tscn to load cleanly")
	var lab_inst: Node = lab_scene.instantiate()
	add_child(lab_inst)
	var lab_rig: PlanarCombatRig = lab_inst.get("_rig") as PlanarCombatRig
	assert_true(lab_rig != null and lab_rig.pilot_profile != null and (lab_rig.pilot_profile as PilotRigProfile).pilot_id == "valentina_v2", "Lab showcase must load Valentina v2 (8-Dir)")
	var lab_hud: Dictionary = lab_inst.get("_hud_refs") as Dictionary
	var lab_body_opt: OptionButton = lab_hud.get("static_body_opt", null) as OptionButton
	assert_true(lab_body_opt != null and lab_body_opt.item_count == 8, "Lab HUD static body selector must expose all 8 directional views")

	lab_rig.position = Vector2(320.0, 180.0)
	lab_rig.rotation = 0.18
	lab_rig.set_locomotion_state(Vector2.RIGHT, 0.85, Vector2.RIGHT, true)
	lab_rig._process(0.016)
	var lab_views: Dictionary = lab_rig.get_views()
	var lab_s_core_mat: ShaderMaterial = (lab_views["s"] as Dictionary).get("body_core_mat", null) as ShaderMaterial
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

	cal_inst.call("_step_part_z", "leg_r", 10)
	var s_meshes: Node2D = ((cal_rig.get_views()["s"] as Dictionary)["root"] as Node2D).get_node("Meshes") as Node2D
	for mc: Node in s_meshes.get_children():
		assert_true((mc as CanvasItem).z_index == 0, "Calibrator Z-order reorder must preserve z_index == 0 inside CanvasGroup")

	cal_inst.queue_free()


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

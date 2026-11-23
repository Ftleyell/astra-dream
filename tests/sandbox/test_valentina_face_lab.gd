extends BaseTestSuite

const FaceConfigScript = preload("res://data/pilots/schemas/pilot_face_anim_config.gd")
const FaceRigScript = preload("res://sandbox/pilot_rig_lab/face_lab/valentina_face_rig.gd")
const FaceAnimatorScript = preload("res://scenes/pilots/rig/valentina_face_animator.gd")
const PlanarCombatRigScript = preload("res://scenes/pilots/rig/planar_combat_rig.gd")
const FaceLabScenePath: String = "res://sandbox/pilot_rig_lab/face_lab/valentina_face_lab.tscn"
const FaceAnimTresPath: String = "res://data/pilots/valentina_v2/valentina_v2_face_anim.tres"


func _ready() -> void:
	super._ready()
	_run_tests()


func _run_tests() -> void:
	var cfg: FaceConfigScript = _test_face_config_resource()
	_test_face_rig_hierarchy_and_masks()
	_test_face_animator_behaviors(cfg)
	_test_face_lab_scene_integration()
	_test_combat_face_controller()
	pass_suite("Valentina v2 Face Rig Lab (masks, shader uniforms, 3-zone hair, animator, combat face controller, scene & HUD) verified.")


func _test_face_config_resource() -> FaceConfigScript:
	assert_true(ResourceLoader.exists(FaceAnimTresPath), "Missing valentina_v2_face_anim.tres")
	var res: Resource = ResourceLoader.load(FaceAnimTresPath)
	assert_true(res is FaceConfigScript, "valentina_v2_face_anim.tres must load as PilotFaceAnimConfig")
	var cfg: FaceConfigScript = (res as FaceConfigScript).duplicate(true) as FaceConfigScript
	assert_true(cfg.enable_eyes_live and cfg.enable_neck_weld and cfg.enable_face_parallax and cfg.enable_hair_3zone and cfg.enable_monocle_hud, "All live face features must be enabled by default in .tres")

	for pid: int in range(6):
		var t: Dictionary = FaceConfigScript.get_preset_targets(pid)
		assert_true(t.has("squint") and t.has("brow_y") and t.has("mouth_open") and t.has("mouth_smile") and t.has("iris_scale"), "Preset %d missing keys" % pid)

	cfg.eye_look_max_px = 3.9
	cfg.eye_highlight_strength = 1.2
	cfg.reset_to_defaults()
	assert_true(absf(cfg.eye_look_max_px - float(FaceConfigScript.FLOAT_DEFAULTS["eye_look_max_px"])) < 0.001, "reset_to_defaults must restore eye_look_max_px")
	assert_true(absf(cfg.eye_highlight_strength - float(FaceConfigScript.FLOAT_DEFAULTS["eye_highlight_strength"])) < 0.001, "reset_to_defaults must restore eye_highlight_strength")
	return cfg


func _test_face_rig_hierarchy_and_masks() -> void:
	var rig := FaceRigScript.new()
	add_child(rig)
	assert_true(rig.has_face_live_textures(), "All 8 canonical heads must bind _face_live_mask, _hair_jiggle_mask, and _normal_depth in both passes")
	assert_true(rig.has_eye_live2d_textures(), "All 4 uncovered-eye heads must bind _eye_iris and _eye_closed Live2D assets in both passes")

	var ucg: CanvasGroup = rig.get_node_or_null("UnifiedCharacterGroup") as CanvasGroup
	assert_true(ucg != null and ucg.z_index == 0, "UnifiedCharacterGroup must exist with z_index == 0")
	for child_name: String in ["HeadUnderMount", "TorsoRefMount", "HeadOverMount"]:
		var ch: Node2D = ucg.get_node_or_null(child_name) as Node2D
		assert_true(ch != null and ch.z_index == 0, "UnifiedCharacterGroup child %s must maintain z_index == 0" % child_name)

	var h_under: Node2D = ucg.get_node("HeadUnderMount") as Node2D
	var t_mount: Node2D = ucg.get_node("TorsoRefMount") as Node2D
	var h_over: Node2D = ucg.get_node("HeadOverMount") as Node2D
	assert_true(h_under.get_index() < t_mount.get_index() and t_mount.get_index() < h_over.get_index(), "Draw order must be HeadUnder < TorsoRef < HeadOver")

	for hk: String in FaceRigScript.CANONICAL_HEADS:
		rig.set_active_head(hk)
		assert_true(rig.get_active_head_key() == hk, "Expected active head %s" % hk)
		var mats: Array[ShaderMaterial] = rig.get_head_materials(hk)
		assert_true(mats.size() == 2, "Expected 2 shader materials (Pass 1 & 2) on %s" % hk)
		for mat: ShaderMaterial in mats:
			var np_uv: Vector2 = mat.get_shader_parameter("neck_pivot_uv") as Vector2
			assert_true(np_uv.x > 0.1 and np_uv.x < 0.9 and np_uv.y > 0.3 and np_uv.y < 0.95, "Invalid neck_pivot_uv on %s" % hk)

	# Standardized Deep Amethyst verification across base head textures & metadata (for both static & live rigs)
	var heads_dir: String = "res://assets/pilots/valentina_v2/planar/heads"
	var eye_meta: Dictionary = rig.MeshBuilderScript.load_json_dict("%s/eye_live2d_meta.json" % heads_dir)
	var std_heads: Array[String] = ["head_front", "head_front_r", "head_front_l", "head_side_r", "head_side"]
	for hk: String in std_heads:
		var entry: Dictionary = eye_meta.get(hk, {}) as Dictionary
		assert_true(str(entry.get("eye_palette", "")) == "deep_amethyst", "eye_live2d_meta.json must declare eye_palette == 'deep_amethyst' on %s" % hk)
		var head_img: Image = Image.load_from_file(ProjectSettings.globalize_path("%s/%s.png" % [heads_dir, hk]))
		var flm_img: Image = Image.load_from_file(ProjectSettings.globalize_path("%s/%s_face_live_mask.png" % [heads_dir, hk]))
		assert_true(head_img != null and flm_img != null and head_img.get_size() == flm_img.get_size(), "Missing or mismatched base/mask images for %s" % hk)
		var violet_px_count: int = 0
		var w: int = head_img.get_width()
		var h: int = head_img.get_height()
		for py_i: int in range(h):
			for px_i: int in range(w):
				if flm_img.get_pixel(px_i, py_i).g > 0.5:
					var c: Color = head_img.get_pixel(px_i, py_i)
					if c.b > c.g + 0.08 and c.r > c.g + 0.02:
						violet_px_count += 1
		assert_true(violet_px_count >= 10, "Base head %s must have baked Deep Amethyst pixels inside open eye socket (got %d)" % [hk, violet_px_count])

	rig.queue_free()


func _test_face_animator_behaviors(cfg: FaceConfigScript) -> void:
	var anim := FaceAnimatorScript.new()

	# 1. Blink impulse and decay
	anim.trigger_blink(false)
	var peak_blink: float = 0.0
	for _i: int in range(6):
		var st_b: Dictionary = anim.step(0.016, cfg, Vector2.ZERO, "head_front", false)
		peak_blink = maxf(peak_blink, float(st_b["blink"]))
	assert_true(peak_blink > 0.65, "trigger_blink should reach peak > 0.65 (got %.3f)" % peak_blink)
	for _i: int in range(16):
		anim.step(0.016, cfg, Vector2.ZERO, "head_front", false)
	var post_b: Dictionary = anim.step(0.016, cfg, Vector2.ZERO, "head_front", false)
	assert_true(float(post_b["blink"]) <= 0.01, "Blink should return cleanly to 0.0 after duration")

	# 2. Eye-tracking toward cursor bounded by eye_look_max_px
	cfg.gaze_mode = FaceConfigScript.GazeMode.FOLLOW_CURSOR
	var st_gaze: Dictionary = {}
	for _i: int in range(25):
		st_gaze = anim.step(0.02, cfg, Vector2(1.0, -0.5), "head_front", false)
	var look_v: Vector2 = st_gaze["eye_look_px"] as Vector2
	assert_true(look_v.x > 1.0 and look_v.y < -0.3, "Iris gaze should track right-up cursor (got %s)" % look_v)
	assert_true(look_v.length() <= cfg.eye_look_max_px * 1.4, "Iris gaze must stay bounded")

	# 3. Expressions + Pupil Dilation + Comms lip-sync + Back head guard
	cfg.expression_preset = FaceConfigScript.ExpressionPreset.ALERT_SURPRISE
	var st_alert: Dictionary = {}
	for _i: int in range(25):
		st_alert = anim.step(0.02, cfg, Vector2.ZERO, "head_front", false)
	assert_true(float(st_alert["brow_offset_px"]) > 1.2 and float(st_alert["mouth_open"]) > 0.25, "ALERT_SURPRISE must raise brows and open mouth")
	assert_true(float(st_alert["iris_scale"]) < 0.92, "ALERT_SURPRISE must contract iris_scale below 0.92 (got %.3f)" % float(st_alert["iris_scale"]))
	assert_true(float(st_alert["eye_highlight_strength"]) > 0.5 and float(st_alert["eye_lid_shadow_strength"]) > 0.5, "Uncovered eye heads must pass eye lighting strengths")
	assert_true(float(st_alert["eye_far_clarity"]) > 0.5 and float(st_alert["eye_combat_glow"]) > 0.25, "Uncovered eye heads must pass distance clarity and combat glow channels")

	cfg.expression_preset = FaceConfigScript.ExpressionPreset.CONFIDENT_SMIRK
	var st_smirk: Dictionary = {}
	for _i: int in range(25):
		st_smirk = anim.step(0.02, cfg, Vector2.ZERO, "head_front", false)
	assert_true(float(st_smirk["mouth_smile"]) > 0.45, "CONFIDENT_SMIRK must drive positive mouth_smile")
	assert_true(float(st_smirk["iris_scale"]) > 1.02, "CONFIDENT_SMIRK must gently dilate iris_scale above 1.02 (got %.3f)" % float(st_smirk["iris_scale"]))

	cfg.expression_preset = FaceConfigScript.ExpressionPreset.COMMS_TALKING
	var m_min: float = 1.0
	var m_max: float = 0.0
	for _i: int in range(30):
		var st_talk: Dictionary = anim.step(0.02, cfg, Vector2.ZERO, "head_front", false)
		var mo: float = float(st_talk["mouth_open"])
		m_min = minf(m_min, mo)
		m_max = maxf(m_max, mo)
	assert_true(m_max - m_min > 0.15, "COMMS_TALKING must modulate mouth_open dynamically")

	var st_back: Dictionary = anim.step(0.02, cfg, Vector2(1.0, 0.0), "head_back", false)
	assert_true(absf(float(st_back["blink"])) < 0.001 and absf(float(st_back["mouth_open"])) < 0.001, "Back views must suppress face feature channels")
	assert_true(absf(float(st_back["iris_scale"]) - 1.0) < 0.001 and absf(float(st_back["eye_highlight_strength"])) < 0.001, "Back views must keep neutral iris_scale and zero eye highlight")
	assert_true(absf(float(st_back["eye_far_clarity"])) < 0.001 and absf(float(st_back["eye_combat_glow"])) < 0.001, "Back views must zero eye distance clarity and combat glow")

	# 4. 3-zone hair whip & monocle reactivity + A/B static reset
	anim.trigger_whip(1.0)
	var st_whip: Dictionary = anim.step(0.02, cfg, Vector2(0.8, 0.1), "head_front", false)
	var hb: Vector2 = st_whip["hair_bangs_px"] as Vector2
	var hs: Vector2 = st_whip["hair_sides_px"] as Vector2
	var hbk: Vector2 = st_whip["hair_back_px"] as Vector2
	assert_true(hb.length() > 0.2 and hs.length() > 0.3 and hbk.length() > 0.4, "trigger_whip must excite all 3 hair springs")
	assert_true(hbk.length() <= cfg.hair_max_clamp_px + 0.01, "Hair spring must respect hair_max_clamp_px")
	assert_true(float(st_whip["monocle_activity"]) > 0.2, "trigger_whip must spike monocle_activity")

	var st_ab: Dictionary = anim.step(0.02, cfg, Vector2(1.0, 1.0), "head_front", true)
	assert_true(not bool(st_ab["enable_face_live"]) and (st_ab["hair_bangs_px"] as Vector2) == Vector2.ZERO, "A/B static mode must return clean neutral state")
	assert_true(absf(float(st_ab["iris_scale"]) - 1.0) < 0.001 and absf(float(st_ab["eye_highlight_strength"])) < 0.001, "A/B static mode must neutralize iris_scale and eye highlight")
	assert_true(absf(float(st_ab["eye_far_clarity"])) < 0.001 and absf(float(st_ab["eye_combat_glow"])) < 0.001, "A/B static mode must zero eye distance clarity and combat glow")


func _test_face_lab_scene_integration() -> void:
	assert_true(ResourceLoader.exists(FaceLabScenePath), "Missing valentina_face_lab.tscn")
	var packed: PackedScene = ResourceLoader.load(FaceLabScenePath) as PackedScene
	assert_true(packed != null, "Failed to load valentina_face_lab.tscn")
	var lab: Node2D = packed.instantiate() as Node2D
	add_child(lab)

	var hero: FaceRigScript = lab.call("get_hero_rig") as FaceRigScript
	var gallery: Array = lab.call("get_gallery_rigs") as Array
	assert_true(hero != null and gallery.size() == 8, "Face Lab must instantiate 1 Hero rig and 8 Gallery rigs")

	lab.call("set_hero_head", "head_side_r")
	assert_true(hero.get_active_head_key() == "head_side_r", "Hero head must update to head_side_r")

	lab.call("set_view_mode", 1)
	assert_true((lab.get_node("Gallery8DirStage") as Node2D).visible, "View mode 1 must show Gallery8DirStage")
	lab.call("set_view_mode", 0)
	assert_true((lab.get_node("HeroStage") as Node2D).visible, "View mode 0 must show HeroStage")

	lab.call("set_show_torso_ref", false)
	lab.call("set_show_torso_ref", true)

	for dbg_id: int in [7, 8, 0]:
		lab.call("set_debug_view_mode", dbg_id)
		for mat: ShaderMaterial in hero.get_head_materials("head_side_r"):
			assert_true(int(mat.get_shader_parameter("debug_view_mode")) == dbg_id, "debug_view_mode must propagate to head materials")

	lab.queue_free()


func _test_combat_face_controller() -> void:
	var rig: PlanarCombatRig = PlanarCombatRigScript.new()
	add_child(rig)
	assert_true(not rig.is_face_live_enabled(), "Standalone PlanarCombatRig must keep enable_face_live == false by default")

	var hd: Dictionary = rig.get_head_data()
	var hud: Dictionary = rig.get_head_under_data()
	var h_over_sprites: Dictionary = hd.get("sprites", {}) as Dictionary
	var h_under_sprites: Dictionary = hud.get("sprites", {}) as Dictionary
	for hk: String in FaceRigScript.EYE_LIVE2D_HEADS:
		var m_over: ShaderMaterial = (h_over_sprites[hk] as Sprite2D).material as ShaderMaterial
		var m_under: ShaderMaterial = (h_under_sprites[hk] as Sprite2D).material as ShaderMaterial
		assert_true(bool(m_over.get_shader_parameter("has_eye_live2d_assets")) and m_over.get_shader_parameter("face_live_mask_tex") != null, "PlanarRigMeshBuilder must bind face_live_mask and Live2D eye assets on %s Pass 2" % hk)
		assert_true(bool(m_under.get_shader_parameter("has_eye_live2d_assets")) and m_under.get_shader_parameter("eye_iris_tex") != null and m_under.get_shader_parameter("eye_closed_tex") != null, "PlanarRigMeshBuilder must bind eye textures on %s Pass 1" % hk)
		assert_true(not bool(m_over.get_shader_parameter("enable_face_live")), "enable_face_live uniform must start disabled when rig.enable_face_live == false")

	rig.set_face_live_enabled(true)
	assert_true(rig.is_face_live_enabled(), "set_face_live_enabled(true) must activate live combat face")
	var f_cfg: FaceConfigScript = rig.get_face_controller().get_config()
	assert_true(f_cfg.personality_profile == FaceConfigScript.PersonalityProfile.STOIC_TACTICAL, "Default combat personality must be STOIC_TACTICAL")

	# 1. Stoic Idle (serious resting mouth, enable_face_live == true in Pass 1 & Pass 2)
	var st_idle: Dictionary = {}
	for _i: int in range(25):
		st_idle = rig.step_face_live(0.02, {"head_key": "head_front", "aim_dir": Vector2.DOWN, "vel_norm": Vector2.ZERO, "speed_norm": 0.0})
	assert_true(rig.get_face_mood_tag() == "IDLE", "Zero speed/events must resolve IDLE mood tag")
	assert_true(float(st_idle["mouth_smile"]) <= 0.02, "STOIC_TACTICAL Idle must keep serious expression without grin (got %.3f)" % float(st_idle["mouth_smile"]))
	var idle_glow: float = float(st_idle["eye_combat_glow"])
	var hf_over_mat: ShaderMaterial = (h_over_sprites["head_front"] as Sprite2D).material as ShaderMaterial
	var hf_under_mat: ShaderMaterial = (h_under_sprites["head_front"] as Sprite2D).material as ShaderMaterial
	assert_true(bool(hf_over_mat.get_shader_parameter("enable_face_live")) and bool(hf_under_mat.get_shader_parameter("enable_face_live")), "step_face_live must activate Pass 1 and Pass 2 head shader materials")

	# 2. Aim-Lead & FOCUS + BACKPEDAL + Velocity Drag 3-zone hair physics + Combat Eye Clarity
	var st_straight: Dictionary = {}
	for _i: int in range(25):
		st_straight = rig.step_face_live(0.02, {"head_key": "head_front", "aim_dir": Vector2.DOWN, "vel_norm": Vector2(1.1, 0.0), "speed_norm": 0.9})
	assert_true(rig.get_face_mood_tag() == "FOCUS", "Cruise flight must resolve FOCUS mood tag")
	assert_true(float(st_straight["squint"]) <= 0.18, "Polished FOCUS squint must stay <= 0.18 to keep amethyst eye open (got %.3f)" % float(st_straight["squint"]))
	assert_true(float(st_straight["iris_scale"]) >= 0.90 and float(st_straight["iris_scale"]) <= 0.95, "Stoic FOCUS iris_scale must sit in [0.90, 0.95] (got %.3f)" % float(st_straight["iris_scale"]))
	assert_true(float(st_straight["eye_far_clarity"]) > 0.5 and float(hf_over_mat.get_shader_parameter("face_eye_far_clarity")) > 0.5, "Combat FOCUS must propagate eye distance clarity > 0.5")
	assert_true(float(st_straight["eye_combat_glow"]) > idle_glow, "Combat FOCUS must elevate tactical iris micro-glow above IDLE (%.3f vs %.3f)" % [float(st_straight["eye_combat_glow"]), idle_glow])
	assert_true(absf((st_straight["eye_look_px"] as Vector2).x) < 0.5, "Straight-ahead aim along head_front must keep centered horizontal gaze")
	assert_true((st_straight["hair_back_px"] as Vector2).x < -0.5, "Rightward flight velocity must trail 3-zone rear hair leftward")

	var st_bp: Dictionary = {}
	for _i: int in range(25):
		st_bp = rig.step_face_live(0.02, {"head_key": "head_front", "aim_dir": Vector2.DOWN, "vel_norm": Vector2(0.0, -0.9), "speed_norm": 0.9, "is_backpedaling": true})
	assert_true(rig.get_face_mood_tag() == "BACKPEDAL", "Backpedaling flight must resolve BACKPEDAL mood tag")
	assert_true(float(st_bp["squint"]) <= 0.20, "Polished BACKPEDAL squint must stay <= 0.20 (got %.3f)" % float(st_bp["squint"]))
	assert_true(float(st_bp["iris_scale"]) >= 0.91, "Stoic BACKPEDAL iris_scale must stay >= 0.91 (got %.3f)" % float(st_bp["iris_scale"]))
	assert_true(ResourceLoader.load("res://sandbox/pilot_rig_lab/shader_lab/ssaa_downsample.gdshader") is Shader, "ssaa_downsample.gdshader must load cleanly as Shader")

	rig.trigger_attack_recoil(Vector2.DOWN, 1.2)
	var st_fire: Dictionary = rig.step_face_live(0.02, {"head_key": "head_front", "aim_dir": Vector2.DOWN, "vel_norm": Vector2(0.8, 0.0), "speed_norm": 0.8})
	assert_true(rig.get_face_mood_tag() == "FIRE" and float(st_fire["eye_combat_glow"]) > idle_glow, "FIRE mood must elevate tactical iris micro-glow above IDLE")

	var st_lead_r: Dictionary = {}
	for _i: int in range(25):
		st_lead_r = rig.step_face_live(0.02, {"head_key": "head_front", "aim_dir": Vector2(0.75, 0.66).normalized(), "vel_norm": Vector2(1.0, 0.0), "speed_norm": 0.9})
	assert_true((st_lead_r["eye_look_px"] as Vector2).x > 1.2, "Aiming right of head_front must drive positive Aim-Lead eye_look_px.x (got %.3f)" % (st_lead_r["eye_look_px"] as Vector2).x)

	# 3. Comms overlay + Hit Wince priority override
	rig.trigger_comms_talk(2.0)
	var c_min: float = 1.0
	var c_max: float = 0.0
	var st_comms: Dictionary = {}
	for _i: int in range(25):
		st_comms = rig.step_face_live(0.02, {"head_key": "head_front", "aim_dir": Vector2(0.75, 0.66).normalized(), "vel_norm": Vector2(0.8, 0.0), "speed_norm": 0.8})
		var mo: float = float(st_comms["mouth_open"])
		c_min = minf(c_min, mo)
		c_max = maxf(c_max, mo)
	assert_true(c_max - c_min > 0.15 and "COMMS" in rig.get_face_mood_tag(), "trigger_comms_talk must overlay lip-sync modulation during combat")
	assert_true((st_comms["eye_look_px"] as Vector2).x > 1.2, "Comms overlay must preserve Aim-Lead eye tracking")

	rig.trigger_hit_react(Vector2.RIGHT, 1.0)
	var st_hit: Dictionary = rig.step_face_live(0.016, {"head_key": "head_front", "aim_dir": Vector2.DOWN, "vel_norm": Vector2.ZERO, "speed_norm": 0.0})
	assert_true(rig.get_face_mood_tag() == "HIT_WINCE" and float(st_hit["blink"]) >= 0.95, "trigger_hit_react must override Comms with HIT_WINCE and snap initial eye closure to >= 0.95")

	# 4. Blink-on-Turn
	for _settle: int in range(30):
		rig.step_face_live(0.02, {"head_key": "head_front", "aim_dir": Vector2.DOWN, "vel_norm": Vector2.ZERO, "speed_norm": 0.0, "turn_state": {"head_active": false}})
	var peak_turn_blink: float = 0.0
	for _tb: int in range(4):
		var st_turn: Dictionary = rig.step_face_live(0.02, {"head_key": "head_front", "aim_dir": Vector2.DOWN, "vel_norm": Vector2.ZERO, "speed_norm": 0.0, "turn_state": {"head_active": true, "head_turn_dir": 1.0}})
		peak_turn_blink = maxf(peak_turn_blink, float(st_turn["blink"]))
	assert_true(peak_turn_blink > 0.45, "Rising turn edge must fire Blink-on-Turn (peak=%.3f)" % peak_turn_blink)

	# 5. Clean disable restore
	rig.set_face_live_enabled(false)
	assert_true(not bool(hf_over_mat.get_shader_parameter("enable_face_live")), "set_face_live_enabled(false) must clear enable_face_live on head materials")
	assert_true((hf_over_mat.get_shader_parameter("secondary_jiggle_l_px") as Vector2).is_equal_approx(Vector2.ZERO), "set_face_live_enabled(false) must clear hair jiggle uniforms")
	assert_true(absf(float(hf_over_mat.get_shader_parameter("face_eye_far_clarity"))) < 0.001 and absf(float(hf_over_mat.get_shader_parameter("face_eye_combat_glow"))) < 0.001, "set_face_live_enabled(false) must clear eye clarity and combat glow uniforms")

	rig.queue_free()

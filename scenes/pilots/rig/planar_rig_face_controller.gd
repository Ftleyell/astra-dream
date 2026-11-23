class_name PlanarRigFaceController
extends RefCounted
## Controlador modular del rig facial vivo y personalidad de combate para PlanarCombatRig.
## Integra eye-tracking Aim-Lead, Blink-on-Turn, física real de cabello 3-zonas,
## soldadura cervical, parallax 2.5D y eventos reactivos (Hit, Fire, Dash/Brake, Comms).

const FaceConfigScript = preload("res://data/pilots/schemas/pilot_face_anim_config.gd")
const FaceAnimatorScript = preload("res://scenes/pilots/rig/valentina_face_animator.gd")
const ViewRouterScript = preload("res://scenes/pilots/rig/planar_rig_view_router.gd")

const DEFAULT_FACE_CFG_PATH: String = "res://data/pilots/valentina_v2/valentina_v2_face_anim.tres"

var _animator: FaceAnimatorScript = null
var _cfg: FaceConfigScript = null

var _hit_timer: float = 0.0
var _fire_timer: float = 0.0
var _dash_timer: float = 0.0
var _comms_timer: float = 0.0
var _turn_blink_cd: float = 0.0

var _prev_head_key: String = ""
var _prev_body_turn_active: bool = false
var _prev_head_turn_active: bool = false
var _prev_brk_w: float = 0.0

var _last_mood_tag: String = "IDLE"
var _last_state: Dictionary = {}
var _overfocus_boost: float = 0.0


func _init(cfg: FaceConfigScript = null) -> void:
	_animator = FaceAnimatorScript.new()
	set_config(cfg)


## Asigna o recarga desde disco la configuración de personalidad/expresión facial.
func set_config(cfg: FaceConfigScript = null) -> void:
	if cfg != null:
		_cfg = cfg
		return
	if ResourceLoader.exists(DEFAULT_FACE_CFG_PATH):
		var loaded: Resource = ResourceLoader.load(DEFAULT_FACE_CFG_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
		if loaded is FaceConfigScript:
			_cfg = (loaded as FaceConfigScript).duplicate(true) as FaceConfigScript
			return
	_cfg = FaceConfigScript.new()


func get_config() -> FaceConfigScript:
	if _cfg == null:
		set_config(null)
	return _cfg


func set_personality_profile(profile_id: int) -> void:
	var c: FaceConfigScript = get_config()
	c.personality_profile = clampi(profile_id, 0, FaceConfigScript.PERSONALITY_LABELS.size() - 1)


func reset() -> void:
	_hit_timer = 0.0
	_fire_timer = 0.0
	_dash_timer = 0.0
	_comms_timer = 0.0
	_turn_blink_cd = 0.0
	_prev_head_key = ""
	_prev_body_turn_active = false
	_prev_head_turn_active = false
	_prev_brk_w = 0.0
	_last_mood_tag = "IDLE"
	_last_state.clear()
	_overfocus_boost = 0.0
	if _animator != null:
		_animator.reset()


func set_overfocus_boost(amount: float) -> void:
	_overfocus_boost = clampf(amount, 0.0, 1.5)


func get_overfocus_boost() -> float:
	return _overfocus_boost


func trigger_hit_react(hit_dir: Vector2 = Vector2.ZERO, strength: float = 1.0) -> void:
	var c: FaceConfigScript = get_config()
	var s: float = clampf(strength, 0.5, 1.6)
	_hit_timer = maxf(_hit_timer, c.combat_hit_wince_sec * s)
	if _animator != null and c.enable_combat_hair_physics:
		var push_x: float = -signf(hit_dir.x) if absf(hit_dir.x) > 0.1 else 1.0
		var push_y: float = clampf(-hit_dir.y, -1.0, 1.0)
		_animator.inject_hair_impulse(
			Vector2(push_x * 78.0, -22.0 + push_y * 26.0) * s,
			Vector2(push_x * 112.0, 20.0 + push_y * 32.0) * s,
			Vector2(push_x * 135.0, 28.0 + push_y * 36.0) * s,
			1.5
		)


func trigger_attack_recoil(aim_dir: Vector2 = Vector2.ZERO, strength: float = 1.0) -> void:
	var c: FaceConfigScript = get_config()
	var s: float = clampf(strength, 0.5, 1.5)
	_fire_timer = maxf(_fire_timer, c.combat_fire_flinch_sec * s)
	if _animator != null and c.enable_combat_hair_physics:
		var back_v: Vector2 = (-aim_dir.normalized() if aim_dir.length_squared() > 0.01 else Vector2(-0.6, 0.2)) * (64.0 * s)
		_animator.inject_hair_impulse(back_v * 0.65, back_v * 0.95, back_v * 1.25, 1.25)


func trigger_dash_burst(dir: Vector2 = Vector2.ZERO) -> void:
	var c: FaceConfigScript = get_config()
	_dash_timer = maxf(_dash_timer, c.combat_dash_react_sec)
	if _animator != null and c.enable_combat_hair_physics:
		var drag_v: Vector2 = (-dir.normalized() if dir.length_squared() > 0.01 else Vector2(-1.0, 0.15)) * c.combat_hair_turn_whip_impulse
		_animator.inject_hair_impulse(drag_v * 0.72, drag_v * 1.05, drag_v * 1.38, 1.0)


func trigger_comms_talk(duration_sec: float = -1.0) -> void:
	if is_equal_approx(duration_sec, 0.0):
		_comms_timer = 0.0
		return
	var c: FaceConfigScript = get_config()
	_comms_timer = duration_sec if duration_sec > 0.0 else c.combat_comms_default_sec


func trigger_blink(fast: bool = false) -> void:
	if _animator == null:
		return
	if fast:
		_animator.trigger_fast_blink(get_config().combat_turn_blink_dur_sec)
	else:
		_animator.trigger_blink(false)


func get_mood_tag() -> String:
	return _last_mood_tag


func get_last_state() -> Dictionary:
	return _last_state


## Evalúa la personalidad facial y aplica uniformes únicamente a materiales de cabeza (Pass 1 y Pass 2).
func step_and_apply(
	delta: float,
	ctx: Dictionary,
	head_data: Dictionary,
	head_under_data: Dictionary
) -> Dictionary:
	var c: FaceConfigScript = get_config()
	var dt: float = clampf(delta, 0.0, 0.06)

	_hit_timer = maxf(0.0, _hit_timer - dt)
	_fire_timer = maxf(0.0, _fire_timer - dt)
	_dash_timer = maxf(0.0, _dash_timer - dt)
	_comms_timer = maxf(0.0, _comms_timer - dt)
	_turn_blink_cd = maxf(0.0, _turn_blink_cd - dt)

	var head_key: String = str(ctx.get("head_key", "head_front"))
	var aim_dir: Vector2 = ctx.get("aim_dir", Vector2.DOWN) as Vector2
	var vel_norm: Vector2 = ctx.get("vel_norm", Vector2.ZERO) as Vector2
	var speed_norm: float = maxf(float(ctx.get("speed_norm", vel_norm.length())), 0.0)
	var is_turbo: bool = bool(ctx.get("is_turbo", false))
	var is_backpedal: bool = bool(ctx.get("is_backpedaling", false))
	var loco_w: Dictionary = ctx.get("loco_weights", {}) as Dictionary
	var turn_st: Dictionary = ctx.get("turn_state", {}) as Dictionary
	var w_brk: float = float(loco_w.get("brk", 0.0))

	_process_turn_and_brake_edges(c, head_key, turn_st, vel_norm, w_brk)

	var aim_lead: Vector2 = _compute_aim_lead(c, head_key, aim_dir, speed_norm)
	var mood_res: Dictionary = _resolve_mood_override(c, speed_norm, is_turbo, is_backpedal, w_brk)
	_last_mood_tag = str(mood_res.get("tag", "IDLE"))
	var expr_override: Dictionary = mood_res.get("expr", {}) as Dictionary

	var ext_hair_force: Vector2 = _compute_external_hair_force(c, vel_norm, w_brk)

	var eval_dt: float = maxf(dt, 0.0005)
	var state: Dictionary = _animator.step(eval_dt, c, aim_lead, head_key, false, ext_hair_force, expr_override)
	_last_state = state

	var head_rot_rad: float = float(ctx.get("head_rot_rad", 0.0))
	var head_off_du: Vector2 = ctx.get("head_offset_du", Vector2.ZERO) as Vector2
	var sync_q_time: bool = bool(ctx.get("sync_q_time", false))

	_apply_state_to_head_dicts(head_data, head_under_data, head_key, state, c, head_rot_rad, head_off_du, sync_q_time)
	return state


## Limpia uniformes faciales opt-in en materiales de cabeza al desactivar el módulo en runtime.
func clear_on_head_materials(head_data: Dictionary, head_under_data: Dictionary) -> void:
	for h_dict: Dictionary in [head_data, head_under_data]:
		if h_dict.is_empty():
			continue
		for m_v: Variant in (h_dict.get("materials", []) as Array):
			var mat: ShaderMaterial = m_v as ShaderMaterial
			if mat == null:
				continue
			mat.set_shader_parameter("enable_face_live", false)
			mat.set_shader_parameter("face_neck_rot_rad", 0.0)
			mat.set_shader_parameter("face_neck_shift_px", Vector2.ZERO)
			mat.set_shader_parameter("face_eye_look_px", Vector2.ZERO)
			mat.set_shader_parameter("face_blink", 0.0)
			mat.set_shader_parameter("face_squint", 0.0)
			mat.set_shader_parameter("face_iris_scale", 1.0)
			mat.set_shader_parameter("face_eye_highlight_strength", 0.0)
			mat.set_shader_parameter("face_eye_lid_shadow_strength", 0.0)
			mat.set_shader_parameter("face_eye_far_clarity", 0.0)
			mat.set_shader_parameter("face_eye_combat_glow", 0.0)
			mat.set_shader_parameter("face_brow_offset_px", 0.0)
			mat.set_shader_parameter("face_brow_tilt", 0.0)
			mat.set_shader_parameter("face_mouth_open", 0.0)
			mat.set_shader_parameter("face_mouth_smile", 0.0)
			mat.set_shader_parameter("banking_tilt_2d", Vector2.ZERO)
			mat.set_shader_parameter("depth_parallax_px", 0.0)
			mat.set_shader_parameter("enable_secondary_jiggle", false)
			mat.set_shader_parameter("secondary_jiggle_l_px", Vector2.ZERO)
			mat.set_shader_parameter("secondary_jiggle_r_px", Vector2.ZERO)
			mat.set_shader_parameter("secondary_jiggle_b_px", Vector2.ZERO)
			mat.set_shader_parameter("secondary_jiggle_normal_strength", 0.0)
			mat.set_shader_parameter("face_monocle_hud_strength", 0.0)
			mat.set_shader_parameter("face_monocle_activity", 0.0)


func _process_turn_and_brake_edges(
	c: FaceConfigScript,
	head_key: String,
	turn_st: Dictionary,
	vel_norm: Vector2,
	w_brk: float
) -> void:
	var body_turn_on: bool = bool(turn_st.get("body_active", false))
	var head_turn_on: bool = bool(turn_st.get("head_active", false))
	var head_swapped: bool = (not _prev_head_key.is_empty()) and (head_key != _prev_head_key)
	var turn_started: bool = (body_turn_on and not _prev_body_turn_active) or (head_turn_on and not _prev_head_turn_active) or head_swapped

	if turn_started:
		if c.enable_blink_on_turn and _turn_blink_cd <= 0.0 and FaceAnimatorScript.FACE_VISIBLE_HEADS.has(head_key):
			_animator.trigger_fast_blink(c.combat_turn_blink_dur_sec)
			_turn_blink_cd = c.combat_turn_blink_cooldown_sec
		if c.enable_combat_hair_physics:
			var t_dir: float = float(turn_st.get("head_turn_dir", turn_st.get("body_turn_dir", 0.0)))
			if absf(t_dir) < 0.05 and head_swapped:
				var from_v: Vector2 = ViewRouterScript.HEAD_DIR_VECTORS.get(_prev_head_key, Vector2.DOWN) as Vector2
				var to_v: Vector2 = ViewRouterScript.HEAD_DIR_VECTORS.get(head_key, Vector2.DOWN) as Vector2
				t_dir = signf(to_v.x - from_v.x) if absf(to_v.x - from_v.x) > 0.05 else 1.0
			if absf(t_dir) < 0.05:
				t_dir = 1.0
			var imp: float = c.combat_hair_turn_whip_impulse
			_animator.inject_hair_impulse(
				Vector2(-t_dir * imp * 0.58, -10.0),
				Vector2(-t_dir * imp * 0.95, 10.0),
				Vector2(-t_dir * imp * 1.32, 16.0),
				0.72
			)

	if c.enable_combat_hair_physics and w_brk > c.combat_brake_thresh and _prev_brk_w <= c.combat_brake_thresh:
		var fwd_dir: Vector2 = vel_norm.normalized() if vel_norm.length_squared() > 0.01 else Vector2(0.0, -0.45)
		var surge: Vector2 = fwd_dir * (c.combat_hair_brake_overshoot_px * 18.0)
		_animator.inject_hair_impulse(surge * 0.65, surge * 0.95, surge * 1.30, 0.55)

	_prev_head_key = head_key
	_prev_body_turn_active = body_turn_on
	_prev_head_turn_active = head_turn_on
	_prev_brk_w = w_brk


func _compute_aim_lead(
	c: FaceConfigScript,
	head_key: String,
	aim_dir: Vector2,
	speed_norm: float
) -> Vector2:
	if not c.enable_combat_aim_lead:
		return Vector2.ZERO
	var head_fwd: Vector2 = ViewRouterScript.HEAD_DIR_VECTORS.get(head_key, Vector2.DOWN) as Vector2
	var aim_n: Vector2 = aim_dir.normalized() if aim_dir.length_squared() > 0.001 else head_fwd
	var delta_aim: Vector2 = aim_n - head_fwd
	var lead := Vector2(
		clampf(delta_aim.x * c.combat_aim_lead_gain, -1.0, 1.0),
		clampf(delta_aim.y * c.combat_aim_lead_gain, -1.0, 1.0)
	)
	if speed_norm < 0.15 and delta_aim.length() < 0.12:
		var scan_x: float = sin(float(_animator._time) * 1.15) * 0.16
		var scan_y: float = cos(float(_animator._time) * 0.85) * 0.08
		lead = Vector2(clampf(lead.x + scan_x, -1.0, 1.0), clampf(lead.y + scan_y, -1.0, 1.0))
	return lead


func _resolve_mood_override(
	c: FaceConfigScript,
	speed_norm: float,
	is_turbo: bool,
	is_backpedal: bool,
	w_brk: float
) -> Dictionary:
	var mood_key: String = "IDLE"
	if _hit_timer > 0.0:
		mood_key = "HIT_WINCE"
	elif _fire_timer > 0.0:
		mood_key = "FIRE"
	elif _dash_timer > 0.0 or w_brk > c.combat_brake_thresh:
		mood_key = "BRAKE_DASH"
	elif is_backpedal and speed_norm > 0.15:
		mood_key = "BACKPEDAL"
	elif is_turbo or speed_norm >= c.combat_focus_speed_thresh:
		mood_key = "FOCUS"
	elif _comms_timer > 0.0:
		mood_key = "COMMS"

	var expr: Dictionary = FaceConfigScript.get_combat_mood_targets(c.personality_profile, mood_key)
	var tag: String = mood_key
	if _overfocus_boost > 0.01:
		expr["monocle_floor"] = maxf(float(expr.get("monocle_floor", 0.0)), clampf(_overfocus_boost * 1.25, 0.0, 1.5))
		expr["iris_glow"] = maxf(float(expr.get("iris_glow", 0.28)), clampf(0.90 + _overfocus_boost * 0.55, 0.0, 1.5))
		if mood_key == "IDLE" or mood_key == "BACKPEDAL":
			tag = "OVERFOCUS"
	if _hit_timer > 0.0 and _hit_timer > c.combat_hit_wince_sec * 0.55:
		expr["blink_floor"] = 1.0
	if _comms_timer > 0.0 and _hit_timer <= 0.0:
		expr["comms_active"] = true
		expr["monocle_floor"] = maxf(float(expr.get("monocle_floor", 0.0)), 0.80)
		if mood_key != "COMMS":
			tag = "%s+COMMS" % mood_key
	return {"tag": tag, "expr": expr}


func _compute_external_hair_force(c: FaceConfigScript, vel_norm: Vector2, w_brk: float) -> Vector2:
	if not c.enable_combat_hair_physics:
		return Vector2.ZERO
	var clamped_v: Vector2 = vel_norm.limit_length(1.5)
	var force: Vector2 = -clamped_v * c.combat_hair_vel_drag_px
	if w_brk > 0.12:
		var fwd_dir: Vector2 = clamped_v.normalized() if clamped_v.length_squared() > 0.01 else Vector2(0.0, -0.42)
		force += fwd_dir * (w_brk * c.combat_hair_brake_overshoot_px)
	return force


func _apply_state_to_head_dicts(
	head_data: Dictionary,
	head_under_data: Dictionary,
	head_key: String,
	state: Dictionary,
	c: FaceConfigScript,
	head_rot_rad: float,
	head_off_du: Vector2,
	sync_q_time: bool
) -> void:
	var tilt_2d: Vector2 = (state.get("banking_tilt_2d", Vector2.ZERO) as Vector2) * c.combat_parallax_gain
	var eye_look: Vector2 = state.get("eye_look_px", Vector2.ZERO) as Vector2
	var blink_v: float = float(state.get("blink", 0.0))
	var squint_v: float = float(state.get("squint", 0.0))
	var iris_scale_v: float = float(state.get("iris_scale", 1.0))
	var eye_spec_v: float = float(state.get("eye_highlight_strength", 0.0))
	var eye_lid_sh_v: float = float(state.get("eye_lid_shadow_strength", 0.0))
	var eye_far_v: float = float(state.get("eye_far_clarity", 0.0))
	var eye_glow_v: float = float(state.get("eye_combat_glow", 0.0))
	var brow_y: float = float(state.get("brow_offset_px", 0.0))
	var brow_t: float = float(state.get("brow_tilt", 0.0))
	var mouth_o: float = float(state.get("mouth_open", 0.0))
	var mouth_s: float = float(state.get("mouth_smile", 0.0))
	var weld_str: float = float(state.get("neck_weld_strength", 0.0))
	var chin_sh: float = float(state.get("chin_shadow_strength", 0.0))
	var parallax_px: float = float(state.get("depth_parallax_px", 0.0))
	var parallax_piv: float = float(state.get("face_parallax_pivot", 0.60))
	var hair_on: bool = bool(state.get("enable_hair_3zone", false))
	var h_bangs: Vector2 = state.get("hair_bangs_px", Vector2.ZERO) as Vector2
	var h_sides: Vector2 = state.get("hair_sides_px", Vector2.ZERO) as Vector2
	var h_back: Vector2 = state.get("hair_back_px", Vector2.ZERO) as Vector2
	var h_norm_str: float = float(state.get("hair_normal_light_strength", 0.0))
	var hud_str: float = float(state.get("monocle_hud_strength", 0.0))
	var hud_act: float = float(state.get("monocle_activity", 0.0))
	var q_t: float = float(state.get("q_time", 0.0))

	for h_dict: Dictionary in [head_data, head_under_data]:
		if h_dict.is_empty():
			continue
		var sprites: Dictionary = h_dict.get("sprites", {}) as Dictionary
		var spr: Sprite2D = sprites.get(head_key, null) as Sprite2D
		if spr == null or not (spr.material is ShaderMaterial):
			continue
		var mat: ShaderMaterial = spr.material as ShaderMaterial
		var tpd_map: Dictionary = h_dict.get("tex_per_du", {}) as Dictionary
		var tex_per_du: Vector2 = tpd_map.get(head_key, Vector2(3.45, 3.45)) as Vector2
		var shift_px := Vector2(head_off_du.x * tex_per_du.x, head_off_du.y * tex_per_du.y)

		mat.set_shader_parameter("enable_face_live", true)
		mat.set_shader_parameter("face_neck_weld_strength", weld_str)
		mat.set_shader_parameter("face_neck_rot_rad", head_rot_rad)
		mat.set_shader_parameter("face_neck_shift_px", shift_px)
		mat.set_shader_parameter("face_eye_look_px", eye_look)
		mat.set_shader_parameter("face_blink", blink_v)
		mat.set_shader_parameter("face_squint", squint_v)
		mat.set_shader_parameter("face_iris_scale", iris_scale_v)
		mat.set_shader_parameter("face_eye_highlight_strength", eye_spec_v)
		mat.set_shader_parameter("face_eye_lid_shadow_strength", eye_lid_sh_v)
		mat.set_shader_parameter("face_eye_far_clarity", eye_far_v)
		mat.set_shader_parameter("face_eye_combat_glow", eye_glow_v)
		mat.set_shader_parameter("face_brow_offset_px", brow_y)
		mat.set_shader_parameter("face_brow_tilt", brow_t)
		mat.set_shader_parameter("face_mouth_open", mouth_o)
		mat.set_shader_parameter("face_mouth_smile", mouth_s)
		mat.set_shader_parameter("face_chin_shadow_strength", chin_sh)
		mat.set_shader_parameter("banking_tilt_2d", tilt_2d)
		mat.set_shader_parameter("depth_parallax_px", parallax_px)
		mat.set_shader_parameter("face_parallax_pivot", parallax_piv)
		mat.set_shader_parameter("enable_secondary_jiggle", hair_on)
		mat.set_shader_parameter("secondary_jiggle_l_px", h_bangs)
		mat.set_shader_parameter("secondary_jiggle_r_px", h_sides)
		mat.set_shader_parameter("secondary_jiggle_b_px", h_back)
		mat.set_shader_parameter("secondary_jiggle_normal_strength", h_norm_str)
		mat.set_shader_parameter("face_monocle_hud_strength", hud_str)
		mat.set_shader_parameter("face_monocle_activity", hud_act)
		if sync_q_time:
			mat.set_shader_parameter("q_time", q_t)

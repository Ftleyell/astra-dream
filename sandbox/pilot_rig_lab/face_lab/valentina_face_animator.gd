class_name ValentinaFaceAnimator
extends RefCounted
## Evaluador procedural del rig facial vivo de Valentina v2.
## Gestiona parpadeo orgánico, eye-tracking/sacadas, presets de expresión + lip-sync,
## cabeceo/soldadura cervical, parallax 2.5D Live2D, 3 resortes de cabello y reactividad del monóculo.

const FaceConfigScript = preload("res://sandbox/pilot_rig_lab/data/pilot_face_anim_config.gd")

const FACE_VISIBLE_HEADS: Array[String] = [
	"head_front",
	"head_front_r",
	"head_front_l",
	"head_side_r",
	"head_side_l",
]
const PROFILE_HEADS: Array[String] = ["head_side_r", "head_side_l"]

var _time: float = 0.0
var _blink_timer: float = 1.6
var _blink_elapsed: float = -1.0
var _active_blink_dur: float = -1.0
var _pending_double_blink: bool = false
var _blink_cycle_idx: int = 0

var _eye_look: Vector2 = Vector2.ZERO
var _prev_eye_look: Vector2 = Vector2.ZERO
var _saccade_timer: float = 0.55
var _saccade_target: Vector2 = Vector2.ZERO
var _saccade_idx: int = 0

var _cur_squint: float = 0.0
var _cur_brow_y: float = 0.0
var _cur_brow_tilt: float = 0.0
var _cur_mouth_open: float = 0.0
var _cur_mouth_smile: float = 0.0
var _cur_iris_scale: float = 1.0
var _cur_eye_glow: float = 0.28

var _prev_head_tilt_vec: Vector2 = Vector2.ZERO
var _bangs_pos: Vector2 = Vector2.ZERO
var _bangs_vel: Vector2 = Vector2.ZERO
var _sides_pos: Vector2 = Vector2.ZERO
var _sides_vel: Vector2 = Vector2.ZERO
var _back_pos: Vector2 = Vector2.ZERO
var _back_vel: Vector2 = Vector2.ZERO

var _monocle_activity: float = 0.0


static func soft_clamp_vec2(v: Vector2, max_r: float) -> Vector2:
	if max_r <= 0.0001:
		return Vector2.ZERO
	var l: float = v.length()
	if l <= 0.0001:
		return v
	return v * (tanh(l / max_r) * max_r / l)


func reset() -> void:
	_time = 0.0
	_blink_timer = 1.6
	_blink_elapsed = -1.0
	_active_blink_dur = -1.0
	_pending_double_blink = false
	_blink_cycle_idx = 0
	_eye_look = Vector2.ZERO
	_prev_eye_look = Vector2.ZERO
	_saccade_timer = 0.55
	_saccade_target = Vector2.ZERO
	_saccade_idx = 0
	_cur_squint = 0.0
	_cur_brow_y = 0.0
	_cur_brow_tilt = 0.0
	_cur_mouth_open = 0.0
	_cur_mouth_smile = 0.0
	_cur_iris_scale = 1.0
	_cur_eye_glow = 0.28
	_prev_head_tilt_vec = Vector2.ZERO
	_bangs_pos = Vector2.ZERO
	_bangs_vel = Vector2.ZERO
	_sides_pos = Vector2.ZERO
	_sides_vel = Vector2.ZERO
	_back_pos = Vector2.ZERO
	_back_vel = Vector2.ZERO
	_monocle_activity = 0.0


func trigger_blink(double_blink: bool = false) -> void:
	_blink_elapsed = 0.0
	_active_blink_dur = -1.0
	_pending_double_blink = double_blink


func trigger_fast_blink(duration_sec: float) -> void:
	if _blink_elapsed < 0.0:
		_blink_elapsed = 0.0
		_pending_double_blink = false
		_active_blink_dur = maxf(duration_sec, 0.06)


func inject_hair_impulse(
	bangs_imp: Vector2,
	sides_imp: Vector2,
	back_imp: Vector2,
	monocle_boost: float = 0.0
) -> void:
	_bangs_vel += bangs_imp
	_sides_vel += sides_imp
	_back_vel += back_imp
	_monocle_activity = maxf(_monocle_activity, monocle_boost)


func trigger_whip(dir_x: float = 1.0) -> void:
	var sgn: float = 1.0 if dir_x >= 0.0 else -1.0
	inject_hair_impulse(Vector2(sgn * 62.0, -24.0), Vector2(sgn * 88.0, 18.0), Vector2(sgn * 105.0, 26.0), 1.0)


func step(
	delta: float,
	cfg: FaceConfigScript,
	cursor_norm: Vector2,
	head_key: String,
	ab_static: bool = false,
	external_hair_force: Vector2 = Vector2.ZERO,
	expr_override: Dictionary = {}
) -> Dictionary:
	if ab_static or cfg == null:
		return _neutral_state()

	var dt: float = clampf(delta, 0.0005, 0.06)
	_time += dt

	var has_face: bool = FACE_VISIBLE_HEADS.has(head_key)
	var is_profile: bool = PROFILE_HEADS.has(head_key)
	var clamped_cursor := Vector2(clampf(cursor_norm.x, -1.0, 1.0), clampf(cursor_norm.y, -1.0, 1.0))

	# 1. Parpadeo orgánico
	var blink_val: float = _step_blink(dt, cfg) if (has_face and cfg.enable_eyes_live) else 0.0
	if has_face and cfg.enable_eyes_live and not expr_override.is_empty():
		blink_val = maxf(blink_val, clampf(float(expr_override.get("blink_floor", 0.0)), 0.0, 1.0))

	# 2. Eye-tracking / micro-sacadas
	var eye_target: Vector2 = _compute_eye_target(dt, cfg, clamped_cursor, has_face, is_profile)
	var eye_blend: float = 1.0 - exp(-maxf(cfg.eye_smooth_rate, 1.0) * dt)
	_eye_look = _eye_look.lerp(eye_target, eye_blend)
	var eye_delta: float = (_eye_look - _prev_eye_look).length() / maxf(dt, 0.001)
	_prev_eye_look = _eye_look

	# 3. Expresiones faciales + lip-sync comms
	var preset_t: Dictionary = expr_override if not expr_override.is_empty() else FaceConfigScript.get_preset_targets(cfg.expression_preset)
	var tgt_squint: float = clampf(float(preset_t.get("squint", 0.0)) + cfg.squint_amount, 0.0, 1.0)
	var tgt_brow_y: float = clampf(float(preset_t.get("brow_y", 0.0)) + cfg.brow_lift_px, -3.5, 3.5)
	var tgt_brow_tilt: float = clampf(float(preset_t.get("brow_tilt", 0.0)) + cfg.brow_furrow, -0.10, 0.10)
	var tgt_mouth_open: float = clampf(float(preset_t.get("mouth_open", 0.0)) + cfg.mouth_open, 0.0, 1.0)
	var tgt_mouth_smile: float = clampf(float(preset_t.get("mouth_smile", 0.0)) + cfg.mouth_smile, -1.0, 1.0)

	var comms_active: bool = bool(expr_override.get("comms_active", false)) if not expr_override.is_empty() else (cfg.expression_preset == FaceConfigScript.ExpressionPreset.COMMS_TALKING)
	if comms_active:
		var w_talk: float = TAU * maxf(cfg.comms_talk_speed_hz, 0.5)
		var syl: float = 0.5 + 0.5 * sin(_time * w_talk) * (0.62 + 0.38 * sin(_time * w_talk * 1.618 + 0.8))
		tgt_mouth_open = clampf(maxf(tgt_mouth_open * 0.35, syl * cfg.comms_talk_amp) + cfg.mouth_open, 0.0, 1.0)
		tgt_brow_y += sin(_time * 2.7) * 0.45

	if not has_face:
		tgt_squint = 0.0
		tgt_brow_y = 0.0
		tgt_brow_tilt = 0.0
		tgt_mouth_open = 0.0
		tgt_mouth_smile = 0.0

	var base_iris_scale: float = float(preset_t.get("iris_scale", 1.0)) if cfg.enable_pupil_dilation else 1.0
	var tgt_iris_scale: float = clampf(base_iris_scale + cfg.iris_scale_offset, 0.72, 1.25) if (has_face and cfg.enable_eyes_live) else 1.0
	var tgt_eye_glow: float = clampf(float(preset_t.get("iris_glow", 0.28)), 0.0, 1.5) if (has_face and cfg.enable_eyes_live) else 0.0

	var expr_blend: float = 1.0 - exp(-maxf(cfg.expression_blend_rate, 1.0) * dt)
	_cur_squint = lerpf(_cur_squint, tgt_squint, expr_blend)
	_cur_brow_y = lerpf(_cur_brow_y, tgt_brow_y, expr_blend)
	_cur_brow_tilt = lerpf(_cur_brow_tilt, tgt_brow_tilt, expr_blend)
	_cur_mouth_open = lerpf(_cur_mouth_open, tgt_mouth_open, expr_blend)
	_cur_mouth_smile = lerpf(_cur_mouth_smile, tgt_mouth_smile, expr_blend)
	_cur_iris_scale = lerpf(_cur_iris_scale, tgt_iris_scale, expr_blend)
	_cur_eye_glow = lerpf(_cur_eye_glow, tgt_eye_glow, expr_blend)
	var iris_pulse: float = sin(_time * 1.9) * 0.012 if (has_face and cfg.enable_eyes_live and cfg.enable_pupil_dilation) else 0.0
	var out_iris_scale: float = clampf(_cur_iris_scale + iris_pulse, 0.70, 1.30) if (has_face and cfg.enable_eyes_live) else 1.0

	# 4. Soldadura cervical y cabeceo respiratorio + seguimiento suave del cursor
	var nod_y: float = sin(_time * cfg.neck_idle_freq_rad) * cfg.neck_idle_nod_px
	var sway_x: float = sin(_time * cfg.neck_idle_freq_rad * 0.5) * (cfg.neck_idle_nod_px * 0.35)
	var head_shift_du := Vector2(sway_x + clamped_cursor.x * 1.15, nod_y + clamped_cursor.y * 0.75)
	var tilt_rad: float = clamped_cursor.x * deg_to_rad(cfg.cursor_head_tilt_deg) + sin(_time * cfg.neck_idle_freq_rad * 0.5 + 0.4) * 0.022
	var neck_weld: float = cfg.neck_weld_strength if cfg.enable_neck_weld else 0.0

	# 5. Parallax 2.5D Live2D (cabeza + monóculo + flequillo)
	var idle_tilt := Vector2(sin(_time * 1.15) * 0.14, cos(_time * 0.92) * 0.10)
	var banking_tilt: Vector2 = (clamped_cursor * cfg.face_parallax_cursor_gain + idle_tilt) if cfg.enable_face_parallax else Vector2.ZERO
	var parallax_px: float = cfg.face_parallax_px if cfg.enable_face_parallax else 0.0

	# 6. Cabello 3 Zonas (R=Flequillo, G=Laterales, B=Puntas/Nuca)
	var cur_tilt_vec := Vector2(tilt_rad, nod_y * 0.05)
	var d_tilt: Vector2 = (cur_tilt_vec - _prev_head_tilt_vec) / maxf(dt, 0.001)
	_prev_head_tilt_vec = cur_tilt_vec

	if cfg.enable_hair_3zone:
		var wind_dir := Vector2(sin(_time * 1.45) + 0.45 * sin(_time * 3.1), cos(_time * 1.15) * 0.35)
		var wind_base: Vector2 = wind_dir * cfg.hair_wind_strength
		var drag: Vector2 = -d_tilt * 14.0

		var t_bangs: Vector2 = wind_base * (cfg.hair_bangs_amp_px * 0.55) + drag * 0.45 + external_hair_force * 0.65
		var t_sides: Vector2 = Vector2(wind_base.x * 1.15, sin(_time * 2.2 + 0.9) * 0.55) * (cfg.hair_sides_amp_px * 0.55) + drag * 0.75 + external_hair_force
		var t_back: Vector2 = Vector2(wind_base.x * 1.35, cos(_time * 1.85 + 1.7) * 0.65) * (cfg.hair_back_amp_px * 0.55) + drag * 0.95 + external_hair_force * 1.30

		var res_b: Dictionary = _step_spring(_bangs_pos, _bangs_vel, t_bangs, cfg.hair_bangs_freq_hz, cfg.hair_bangs_damping, dt)
		_bangs_pos = soft_clamp_vec2(res_b["pos"] as Vector2, cfg.hair_max_clamp_px)
		_bangs_vel = res_b["vel"] as Vector2

		var res_s: Dictionary = _step_spring(_sides_pos, _sides_vel, t_sides, cfg.hair_sides_freq_hz, cfg.hair_sides_damping, dt)
		_sides_pos = soft_clamp_vec2(res_s["pos"] as Vector2, cfg.hair_max_clamp_px)
		_sides_vel = res_s["vel"] as Vector2

		var res_bk: Dictionary = _step_spring(_back_pos, _back_vel, t_back, cfg.hair_back_freq_hz, cfg.hair_back_damping, dt)
		_back_pos = soft_clamp_vec2(res_bk["pos"] as Vector2, cfg.hair_max_clamp_px)
		_back_vel = res_bk["vel"] as Vector2
	else:
		_bangs_pos = Vector2.ZERO
		_bangs_vel = Vector2.ZERO
		_sides_pos = Vector2.ZERO
		_sides_vel = Vector2.ZERO
		_back_pos = Vector2.ZERO
		_back_vel = Vector2.ZERO

	# 7. Monóculo táctico reactivo
	var target_act: float = clampf(eye_delta * 0.08 * cfg.monocle_gaze_reactivity, 0.0, 1.2)
	var monocle_floor: float = float(expr_override.get("monocle_floor", 0.0)) if not expr_override.is_empty() else 0.0
	_monocle_activity = clampf(maxf(maxf(_monocle_activity * exp(-2.6 * dt), target_act), monocle_floor), 0.0, 1.5)

	return {
		"enable_face_live": true,
		"eye_look_px": _eye_look if has_face else Vector2.ZERO,
		"blink": blink_val if has_face else 0.0,
		"squint": _cur_squint if has_face else 0.0,
		"iris_scale": out_iris_scale,
		"eye_highlight_strength": cfg.eye_highlight_strength if (has_face and cfg.enable_eyes_live) else 0.0,
		"eye_lid_shadow_strength": cfg.eye_lid_shadow_strength if (has_face and cfg.enable_eyes_live) else 0.0,
		"eye_far_clarity": cfg.eye_far_clarity if (has_face and cfg.enable_eyes_live) else 0.0,
		"eye_combat_glow": (_cur_eye_glow * cfg.eye_combat_glow_strength) if (has_face and cfg.enable_eyes_live) else 0.0,
		"brow_offset_px": _cur_brow_y if has_face else 0.0,
		"brow_tilt": _cur_brow_tilt if has_face else 0.0,
		"mouth_open": _cur_mouth_open if has_face else 0.0,
		"mouth_smile": _cur_mouth_smile if has_face else 0.0,
		"neck_weld_strength": neck_weld,
		"head_rot_rad": tilt_rad,
		"head_shift_du": head_shift_du,
		"chin_shadow_strength": cfg.chin_shadow_strength,
		"banking_tilt_2d": banking_tilt,
		"depth_parallax_px": parallax_px,
		"face_parallax_pivot": cfg.face_parallax_pivot,
		"enable_hair_3zone": cfg.enable_hair_3zone,
		"hair_bangs_px": _bangs_pos,
		"hair_sides_px": _sides_pos,
		"hair_back_px": _back_pos,
		"hair_normal_light_strength": cfg.hair_normal_light_strength if cfg.enable_hair_3zone else 0.0,
		"monocle_hud_strength": cfg.monocle_hud_strength if cfg.enable_monocle_hud else 0.0,
		"monocle_activity": _monocle_activity if cfg.enable_monocle_hud else 0.0,
		"q_time": _time,
	}


func _step_blink(dt: float, cfg: FaceConfigScript) -> float:
	var dur: float = maxf(_active_blink_dur if _active_blink_dur > 0.0 else cfg.blink_duration_sec, 0.06)
	if _blink_elapsed >= 0.0:
		_blink_elapsed += dt
		if _blink_elapsed >= dur:
			_blink_elapsed = -1.0
			_active_blink_dur = -1.0
			if _pending_double_blink:
				_pending_double_blink = false
				_blink_timer = 0.08
			return 0.0
		var u: float = clampf(_blink_elapsed / dur, 0.0, 1.0)
		return pow(sin(PI * u), 0.72)

	_blink_timer -= dt
	if _blink_timer <= 0.0:
		_blink_cycle_idx += 1
		_blink_elapsed = 0.0
		var pseudo_r: float = float((_blink_cycle_idx * 7 + 3) % 10) * 0.1
		_pending_double_blink = pseudo_r < cfg.double_blink_chance
		var jitter: float = 0.78 + 0.44 * float((_blink_cycle_idx * 3 + 1) % 10) * 0.1
		_blink_timer = maxf(cfg.blink_interval_sec * jitter, 0.65)
	return 0.0


func _compute_eye_target(
	dt: float,
	cfg: FaceConfigScript,
	cursor_norm: Vector2,
	has_face: bool,
	is_profile: bool
) -> Vector2:
	if not has_face or not cfg.enable_eyes_live:
		return Vector2.ZERO
	var amp_x: float = cfg.eye_look_max_px * (0.65 if is_profile else 1.0)
	var amp_y: float = cfg.eye_look_max_px * 0.72

	if cfg.gaze_mode == FaceConfigScript.GazeMode.CENTER_LOCK:
		return Vector2.ZERO

	if cfg.gaze_mode == FaceConfigScript.GazeMode.AUTO_SACCADES:
		_saccade_timer -= dt * maxf(cfg.eye_saccade_speed, 0.25)
		if _saccade_timer <= 0.0:
			_saccade_idx += 1
			var ax: float = sin(float(_saccade_idx) * 2.399963) * 0.85
			var ay: float = cos(float(_saccade_idx) * 1.713) * 0.55
			_saccade_target = Vector2(ax * amp_x, ay * amp_y)
			_saccade_timer = 0.65 + 0.55 * float((_saccade_idx * 5) % 4) * 0.25
		return _saccade_target

	# FOLLOW_CURSOR + micro-deriva orgánica sutil para evitar mirada robótica
	var micro := Vector2(sin(_time * 2.9) * 0.18, cos(_time * 2.1) * 0.12)
	return Vector2(cursor_norm.x * amp_x, cursor_norm.y * amp_y) + micro


func _step_spring(
	pos: Vector2,
	vel: Vector2,
	target: Vector2,
	freq_hz: float,
	damping_ratio: float,
	dt: float
) -> Dictionary:
	var omega: float = TAU * clampf(freq_hz, 0.4, 8.0)
	var damp: float = 2.0 * clampf(damping_ratio, 0.08, 1.5) * omega
	var accel: Vector2 = (target - pos) * (omega * omega) - vel * damp
	var next_vel: Vector2 = vel + accel * dt
	var next_pos: Vector2 = pos + next_vel * dt
	return {"pos": next_pos, "vel": next_vel}


func _neutral_state() -> Dictionary:
	return {
		"enable_face_live": false,
		"eye_look_px": Vector2.ZERO,
		"blink": 0.0,
		"squint": 0.0,
		"iris_scale": 1.0,
		"eye_highlight_strength": 0.0,
		"eye_lid_shadow_strength": 0.0,
		"eye_far_clarity": 0.0,
		"eye_combat_glow": 0.0,
		"brow_offset_px": 0.0,
		"brow_tilt": 0.0,
		"mouth_open": 0.0,
		"mouth_smile": 0.0,
		"neck_weld_strength": 0.0,
		"head_rot_rad": 0.0,
		"head_shift_du": Vector2.ZERO,
		"chin_shadow_strength": 0.0,
		"banking_tilt_2d": Vector2.ZERO,
		"depth_parallax_px": 0.0,
		"face_parallax_pivot": 0.60,
		"enable_hair_3zone": false,
		"hair_bangs_px": Vector2.ZERO,
		"hair_sides_px": Vector2.ZERO,
		"hair_back_px": Vector2.ZERO,
		"hair_normal_light_strength": 0.0,
		"monocle_hud_strength": 0.0,
		"monocle_activity": 0.0,
		"q_time": _time,
	}

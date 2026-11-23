class_name PlanarRigKitingEvaluator
extends RefCounted
## Evaluador modular de Kiting 360° Zero-G ("Hover-Slide"): Reversa 180°, Freno de Reversa y Strafe Lateral.
## Descompone la velocidad en el marco de orientación del personaje manteniendo simetría exacta L ↔ R.

const KitingConfigScript = preload("res://data/pilots/schemas/pilot_kiting_anim_config.gd")
const IdleConfigScript = preload("res://data/pilots/schemas/pilot_idle_anim_config.gd")
const ViewRouterScript = preload("res://scenes/pilots/rig/planar_rig_view_router.gd")

var _live_rev_w: float = 0.0
var _live_rbrk_w: float = 0.0
var _live_str_near_w: float = 0.0
var _live_str_far_w: float = 0.0
var _live_lat_signed: float = 0.0
var _kiting_momentum: float = 0.0
var _prev_kiting_speed: float = 0.0


func reset_state() -> void:
	_live_rev_w = 0.0
	_live_rbrk_w = 0.0
	_live_str_near_w = 0.0
	_live_str_far_w = 0.0
	_live_lat_signed = 0.0
	_kiting_momentum = 0.0
	_prev_kiting_speed = 0.0


func step_live_weights(
	delta: float,
	speed_norm: float,
	move_dir: Vector2,
	aim_dir: Vector2,
	view_key: String,
	is_backpedaling: bool,
	cfg: KitingConfigScript
) -> Dictionary:
	if cfg == null:
		return {"rev": 0.0, "rbrk": 0.0, "str_near": 0.0, "str_far": 0.0, "lat_signed": 0.0, "kiting_total": 0.0}

	var dt: float = maxf(delta, 0.004)
	var face_dir: Vector2 = aim_dir.normalized() if aim_dir.length_squared() > 0.001 else ViewRouterScript.get_body_dir_vector(view_key)
	var move_n: Vector2 = move_dir.normalized() if move_dir.length_squared() > 0.001 else Vector2.ZERO

	var dot_fwd: float = face_dir.dot(move_n) if move_n.length_squared() > 0.001 else 1.0
	var lat_raw: float = (face_dir.x * move_n.y - face_dir.y * move_n.x) if move_n.length_squared() > 0.001 else 0.0
	var mirror_sign: float = -1.0 if view_key in ["sw", "w", "nw"] else 1.0
	var lat_canonical: float = lat_raw * mirror_sign

	var k_blend: float = 1.0 - exp(-cfg.blend_rate * dt)
	var brk_enter: float = 1.0 - exp(-cfg.rev_brake_enter_rate * dt)
	var brk_decay: float = 1.0 - exp(-cfg.rev_brake_decay_rate * dt)

	if speed_norm > 0.08 and move_n.length_squared() > 0.001:
		var rev_factor: float = clampf((cfg.reverse_enter_dot_max - dot_fwd) / maxf(1.0 + cfg.reverse_enter_dot_max, 0.2), 0.0, 1.0)
		var off_axis_gate: float = 1.0 if is_backpedaling else clampf((cfg.strafe_enter_dot_max - dot_fwd) / maxf(cfg.strafe_enter_dot_max - 0.25, 0.1), 0.0, 1.0)
		var eff_spd: float = clampf(speed_norm, 0.0, 1.25)
		var t_rev: float = eff_spd * rev_factor
		var t_str_near: float = eff_spd * maxf(lat_canonical, 0.0) * off_axis_gate
		var t_str_far: float = eff_spd * maxf(-lat_canonical, 0.0) * off_axis_gate
		var kiting_spd: float = clampf(eff_spd * maxf(rev_factor, absf(lat_canonical) * off_axis_gate), 0.0, 1.35)
		var kiting_decel: float = maxf(0.0, (_prev_kiting_speed - kiting_spd) / dt)
		_prev_kiting_speed = kiting_spd

		if kiting_decel > 0.42 and _kiting_momentum > 0.20:
			var rbrk_target: float = clampf(_kiting_momentum * cfg.rev_brake_sensitivity, 0.0, 1.0)
			_live_rbrk_w = clampf(maxf(lerpf(_live_rbrk_w, rbrk_target, brk_enter), _live_rbrk_w + kiting_decel * cfg.rev_brake_sensitivity * dt), 0.0, 1.0)
			_live_rev_w = lerpf(_live_rev_w, t_rev * 0.35, brk_enter)
			_live_str_near_w = lerpf(_live_str_near_w, t_str_near * 0.35, brk_enter)
			_live_str_far_w = lerpf(_live_str_far_w, t_str_far * 0.35, brk_enter)
		else:
			_live_rev_w = lerpf(_live_rev_w, t_rev, k_blend)
			_live_str_near_w = lerpf(_live_str_near_w, t_str_near, k_blend)
			_live_str_far_w = lerpf(_live_str_far_w, t_str_far, k_blend)
			_kiting_momentum = maxf(_kiting_momentum * (1.0 - brk_decay * 0.45), maxf(_live_rev_w, maxf(_live_str_near_w, _live_str_far_w)))
			_live_rbrk_w = lerpf(_live_rbrk_w, 0.0, brk_enter if kiting_spd > 0.35 else brk_decay)
		_live_lat_signed = lerpf(_live_lat_signed, lat_canonical * off_axis_gate, k_blend)
	else:
		if _kiting_momentum > 0.14:
			_live_rbrk_w = clampf(maxf(_live_rbrk_w, _kiting_momentum * cfg.rev_brake_sensitivity), 0.0, 1.0)
		_kiting_momentum = 0.0
		_prev_kiting_speed = 0.0
		_live_rev_w = lerpf(_live_rev_w, 0.0, brk_enter)
		_live_str_near_w = lerpf(_live_str_near_w, 0.0, brk_enter)
		_live_str_far_w = lerpf(_live_str_far_w, 0.0, brk_enter)
		_live_lat_signed = lerpf(_live_lat_signed, 0.0, brk_enter)
		_live_rbrk_w = lerpf(_live_rbrk_w, 0.0, brk_decay)

	var total: float = clampf(_live_rev_w + _live_rbrk_w + _live_str_near_w + _live_str_far_w, 0.0, 1.35)
	return {
		"rev": _live_rev_w,
		"rbrk": _live_rbrk_w,
		"str_near": _live_str_near_w,
		"str_far": _live_str_far_w,
		"lat_signed": _live_lat_signed,
		"kiting_total": total,
	}


static func compute_preview_weights(preview_mode: int, anim_time: float, cycle_dur: float = 6.4) -> Dictionary:
	match preview_mode:
		KitingConfigScript.PreviewMode.REVERSE_180:
			return {"rev": 1.0, "rbrk": 0.0, "str_near": 0.0, "str_far": 0.0, "lat_signed": 0.0, "kiting_total": 1.0}
		KitingConfigScript.PreviewMode.STRAFE_NEAR_R:
			return {"rev": 0.0, "rbrk": 0.0, "str_near": 1.0, "str_far": 0.0, "lat_signed": 1.0, "kiting_total": 1.0}
		KitingConfigScript.PreviewMode.STRAFE_FAR_L:
			return {"rev": 0.0, "rbrk": 0.0, "str_near": 0.0, "str_far": 1.0, "lat_signed": -1.0, "kiting_total": 1.0}
		KitingConfigScript.PreviewMode.REVERSE_BRAKE:
			return {"rev": 0.0, "rbrk": 1.0, "str_near": 0.0, "str_far": 0.0, "lat_signed": 0.0, "kiting_total": 1.0}
		_:
			var dur: float = maxf(cycle_dur, 1.5)
			var u: float = fposmod(anim_time, dur) / dur
			var rev_w: float = smoothstep(0.05, 0.14, u) * (1.0 - smoothstep(0.27, 0.35, u))
			var rbrk_w: float = smoothstep(0.28, 0.34, u) * (1.0 - smoothstep(0.42, 0.50, u))
			var sn_w: float = smoothstep(0.50, 0.58, u) * (1.0 - smoothstep(0.70, 0.77, u))
			var sf_w: float = smoothstep(0.76, 0.83, u) * (1.0 - smoothstep(0.93, 0.99, u))
			var total: float = clampf(rev_w + rbrk_w + sn_w + sf_w, 0.0, 1.35)
			return {"rev": rev_w, "rbrk": rbrk_w, "str_near": sn_w, "str_far": sf_w, "lat_signed": sn_w - sf_w, "kiting_total": total}


static func merge_kiting_into_motion(
	motion: Dictionary,
	_view_key: String,
	fam: String,
	mirror_sign: float,
	pose_scale: float,
	idle_cfg: IdleConfigScript,
	kiting_cfg: KitingConfigScript,
	kiting_weights: Dictionary,
	anim_time: float
) -> void:
	if kiting_cfg == null or kiting_weights.is_empty():
		return
	kiting_cfg.ensure_initialized()
	var k_fam: Dictionary = kiting_cfg.get_family_dict(fam)
	if k_fam.is_empty():
		return

	var base_scale: float = kiting_cfg.master_intensity * pose_scale
	var w_rev: float = float(kiting_weights.get("rev", 0.0)) * base_scale
	var w_rbrk: float = float(kiting_weights.get("rbrk", 0.0)) * base_scale
	var w_near: float = float(kiting_weights.get("str_near", 0.0)) * base_scale
	var w_far: float = float(kiting_weights.get("str_far", 0.0)) * base_scale
	if w_rev + w_rbrk + w_near + w_far <= 0.0001:
		return

	var allow_skel: bool = idle_cfg == null or idle_cfg.enable_skeleton_layer
	var allow_25d: bool = idle_cfg == null or idle_cfg.enable_25d_layer
	var allow_sec: bool = idle_cfg == null or idle_cfg.enable_secondary_layer
	var is_front_back: bool = (fam == "s" or fam == "n")

	if allow_skel:
		motion["skel_active"] = true
	if allow_25d:
		motion["persp_active"] = true
	if allow_sec:
		motion["sec_active"] = true

	var phases: Array[Array] = [
		["rev_", w_rev, false],
		["rbrk_", w_rbrk, false],
		["str_near_", w_near, true],
		["str_far_", w_far, true],
	]
	for p_item: Array in phases:
		var pfx: String = str(p_item[0])
		var w: float = float(p_item[1])
		var is_strafe: bool = bool(p_item[2])
		if w <= 0.0001:
			continue

		if allow_skel:
			var p_off := Vector2(float(k_fam.get(pfx + "pelvis_shift_x", 0.0)) * mirror_sign, float(k_fam.get(pfx + "pelvis_shift_y", 0.0))) * w
			motion["pelvis_offset"] = (motion["pelvis_offset"] as Vector2) + p_off
			motion["pelvis_rot"] = float(motion["pelvis_rot"]) + float(k_fam.get(pfx + "pelvis_rot", 0.0)) * mirror_sign * w
			motion["waist_rot"] = float(motion["waist_rot"]) + float(k_fam.get(pfx + "waist_rot", 0.0)) * mirror_sign * w
			motion["chest_rot"] = float(motion["chest_rot"]) + float(k_fam.get(pfx + "chest_rot", 0.0)) * mirror_sign * w
			motion["neck_rot"] = float(motion["neck_rot"]) + float(k_fam.get(pfx + "neck_rot", 0.0)) * mirror_sign * w

			var h_lag_val: float = float(k_fam.get(pfx + "head_lag_px", 0.0))
			var h_lag_vec := Vector2.ZERO
			if is_front_back:
				h_lag_vec = Vector2(h_lag_val, 0.0) if is_strafe else Vector2(0.0, h_lag_val)
			else:
				h_lag_vec = Vector2(h_lag_val * mirror_sign, 0.0)
			motion["head_offset"] = (motion["head_offset"] as Vector2) + h_lag_vec * w
			motion["head_rot"] = float(motion["head_rot"]) + float(k_fam.get(pfx + "head_rot", 0.0)) * mirror_sign * w

			for role: String in ["lead", "trail"]:
				var d_arm: Dictionary = motion["arm_" + role] as Dictionary
				d_arm["sh"] = float(d_arm["sh"]) + float(k_fam.get("%sshoulder_%s_rot" % [pfx, role], 0.0)) * mirror_sign * w
				d_arm["el"] = float(d_arm["el"]) + float(k_fam.get("%selbow_%s_rot" % [pfx, role], 0.0)) * mirror_sign * w
				d_arm["wr"] = float(d_arm["wr"]) + float(k_fam.get("%swrist_%s_rot" % [pfx, role], 0.0)) * mirror_sign * w

				var d_leg: Dictionary = motion["leg_" + role] as Dictionary
				d_leg["th"] = float(d_leg["th"]) + float(k_fam.get("%sthigh_%s_rot" % [pfx, role], 0.0)) * mirror_sign * w
				d_leg["kn"] = float(d_leg["kn"]) + float(k_fam.get("%sknee_%s_rot" % [pfx, role], 0.0)) * mirror_sign * w
				d_leg["an"] = float(d_leg["an"]) + float(k_fam.get("%sankle_%s_rot" % [pfx, role], 0.0)) * mirror_sign * w

		if allow_25d:
			motion["torso_trap"] = float(motion["torso_trap"]) + float(k_fam.get(pfx + "torso_trap", 0.0)) * w
			motion["torso_yaw"] = float(motion["torso_yaw"]) + float(k_fam.get(pfx + "torso_yaw", 0.0)) * mirror_sign * w
			var d_lead: Dictionary = motion["leg_lead"] as Dictionary
			var d_trail: Dictionary = motion["leg_trail"] as Dictionary
			d_lead["phi_s"] = float(d_lead["phi_s"]) + float(k_fam.get(pfx + "leg_lead_phi_shin", 0.0)) * w
			d_lead["dist"] = float(d_lead["dist"]) + float(k_fam.get(pfx + "leg_lead_distal_amp", 0.0)) * w
			d_trail["phi_s"] = float(d_trail["phi_s"]) + float(k_fam.get(pfx + "leg_trail_phi_shin", 0.0)) * w
			d_trail["dist"] = float(d_trail["dist"]) + float(k_fam.get(pfx + "leg_trail_distal_amp", 0.0)) * w

		if allow_sec:
			var h_dx: float = float(k_fam.get(pfx + "hair_drag_x_px", 0.0)) * mirror_sign
			var h_dy: float = float(k_fam.get(pfx + "hair_drag_y_px", 0.0))
			var h_drag := Vector2(h_dx, h_dy) * w
			motion["hair_jiggle_l"] = (motion["hair_jiggle_l"] as Vector2) + h_drag
			motion["hair_jiggle_r"] = (motion["hair_jiggle_r"] as Vector2) + h_drag

			var t_drag := Vector2(h_dx * 0.28, float(k_fam.get(pfx + "torso_sec_drag_y_px", 0.0))) * w
			motion["torso_jiggle_l"] = (motion["torso_jiggle_l"] as Vector2) + t_drag
			motion["torso_jiggle_r"] = (motion["torso_jiggle_r"] as Vector2) + t_drag

	# Micro-onda Zero-G de equilibrio distal durante Hover-Slide sostenido.
	var slide_w: float = clampf(w_rev + w_near + w_far, 0.0, 1.2)
	if slide_w > 0.05 and kiting_cfg.hover_slide_micro_amp > 0.001:
		var w_osc: float = sin(anim_time * TAU * maxf(kiting_cfg.hover_slide_micro_hz, 0.3))
		var amp: float = kiting_cfg.hover_slide_micro_amp * slide_w
		if allow_skel:
			var arm_l: Dictionary = motion["arm_lead"] as Dictionary
			var arm_t: Dictionary = motion["arm_trail"] as Dictionary
			var leg_l: Dictionary = motion["leg_lead"] as Dictionary
			var leg_t: Dictionary = motion["leg_trail"] as Dictionary
			arm_l["wr"] = float(arm_l["wr"]) + 0.030 * w_osc * amp * mirror_sign
			arm_t["wr"] = float(arm_t["wr"]) - 0.030 * w_osc * amp * mirror_sign
			leg_l["an"] = float(leg_l["an"]) + 0.035 * w_osc * amp * mirror_sign
			leg_t["an"] = float(leg_t["an"]) - 0.035 * w_osc * amp * mirror_sign
		if allow_25d:
			var leg_l2: Dictionary = motion["leg_lead"] as Dictionary
			var leg_t2: Dictionary = motion["leg_trail"] as Dictionary
			leg_l2["phi_s"] = float(leg_l2["phi_s"]) + 0.025 * w_osc * amp
			leg_t2["phi_s"] = float(leg_t2["phi_s"]) - 0.025 * w_osc * amp


static func format_state_tag(weights: Dictionary) -> String:
	if weights.is_empty():
		return ""
	var w_rev: float = float(weights.get("rev", 0.0))
	var w_rbrk: float = float(weights.get("rbrk", 0.0))
	var w_near: float = float(weights.get("str_near", 0.0))
	var w_far: float = float(weights.get("str_far", 0.0))
	if w_rbrk > 0.18 and w_rbrk >= maxf(w_rev, maxf(w_near, w_far)):
		return "FRENO REV %.2f" % w_rbrk
	if w_rev > 0.25 and maxf(w_near, w_far) > 0.25:
		return "KITING DIAG %.2f" % maxf(w_rev, maxf(w_near, w_far))
	if w_rev > 0.18 and w_rev >= maxf(w_near, w_far):
		return "REVERSA %.2f" % w_rev
	if w_near > 0.18 and w_near >= w_far:
		return "STRAFE DER %.2f" % w_near
	if w_far > 0.18:
		return "STRAFE IZQ %.2f" % w_far
	return ""

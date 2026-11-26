class_name PlanarRigGroundedEvaluator
extends RefCounted
## Evaluador de locomoción Grounded AAA para el Hub 3D (Valentina v2 8-Dir).
## Implementa:
## - Pose de pie relajada (cero levitación Zero-G) con respiración y micro-balanceo de peso.
## - Ciclo de caminata/trote de 4 fases (Contacto -> Compresión -> Impulso -> Paso) con Stride-Lock real.
## - Arranque con inclinación (Start-Up), frenado con apoyo (Stop-Plant) y pivote limpio.
## - Emisión de eventos de pisada por pie para SFX, VFX y física de jiggle/cabello.

const BasePoseConfigScript = preload("res://data/pilots/schemas/pilot_base_pose_config.gd")
const GroundedConfigScript = preload("res://data/pilots/schemas/pilot_grounded_locomotion_config.gd")
const BasePoseEvaluatorScript = preload("res://scenes/pilots/rig/planar_rig_base_pose_evaluator.gd")
const TurnAnimConfigScript = preload("res://data/pilots/schemas/pilot_turn_anim_config.gd")
const JigglePhysicsConfigScript = preload("res://data/pilots/schemas/pilot_jiggle_physics_config.gd")

const HOP_BOOT_PIVOT_Y_RIG_PX: float = 225.0

var gait_phase: float = 0.0
var idle_time: float = 0.0
var walk_blend: float = 0.0
var start_weight: float = 0.0
var stop_weight: float = 0.0
var pivot_weight: float = 0.0
var pivot_dir: float = 1.0
var pelvis_lift_norm: float = 0.0
var step_count: int = 0

var _prev_speed_norm: float = 0.0
var _was_moving: bool = false
var _pending_step_foot: StringName = &""
var _pending_step_strength: float = 0.0


func reset_state() -> void:
	gait_phase = 0.0
	idle_time = 0.0
	walk_blend = 0.0
	start_weight = 0.0
	stop_weight = 0.0
	pivot_weight = 0.0
	pivot_dir = 1.0
	pelvis_lift_norm = 0.0
	step_count = 0
	_prev_speed_norm = 0.0
	_was_moving = false
	_pending_step_foot = &""
	_pending_step_strength = 0.0


func trigger_pivot(turn_sign: float = 1.0) -> void:
	pivot_weight = 1.0
	pivot_dir = 1.0 if turn_sign >= 0.0 else -1.0


func consume_step_event() -> Dictionary:
	if _pending_step_foot.is_empty():
		return {}
	var ev: Dictionary = {
		"foot": _pending_step_foot,
		"strength": _pending_step_strength,
	}
	_pending_step_foot = &""
	_pending_step_strength = 0.0
	return ev


static func is_hop_gait(cfg: GroundedConfigScript) -> bool:
	return cfg != null and (
		cfg.gait_style == GroundedConfigScript.GaitStyle.MOON_HOP
		or cfg.gait_style == GroundedConfigScript.GaitStyle.ASTRAL_GLIDE_HOP
	)


static func get_active_stride_length_m(cfg: GroundedConfigScript) -> float:
	if cfg == null:
		return 2.05
	if cfg.gait_style == GroundedConfigScript.GaitStyle.ASTRAL_GLIDE_HOP:
		return maxf(cfg.glide_stride_length_m, 0.40)
	return maxf(cfg.stride_length_m, 0.40)


static func sample_astral_glide_curves(
	phase: float,
	contact_duty: float,
	hang_power: float = 0.72,
	peak_shift: float = 0.44
) -> Dictionary:
	var duty: float = clampf(contact_duty, 0.05, 0.50)
	var ph_tau: float = fposmod(phase, TAU)
	var hop_u: float = fposmod(phase, PI) / PI
	var lead_side: float = 1.0 if ph_tau < PI else -1.0

	var air_wave: float = 0.0
	var crouch_wave: float = 0.0
	var push_wave: float = 0.0
	var launch_wave: float = 0.0
	var glide_wave: float = 0.0
	var reach_wave: float = 0.0
	var flight_u: float = 0.0
	var subphase: StringName = &"REBOUND"

	if hop_u < duty:
		var contact_u: float = hop_u / duty
		crouch_wave = sin(contact_u * PI)
		push_wave = smoothstep(0.42, 1.0, contact_u) * sin(contact_u * PI)
		subphase = &"REBOUND"
	else:
		flight_u = clampf((hop_u - duty) / maxf(1.0 - duty, 0.05), 0.0, 1.0)
		var shift_c: float = clampf(peak_shift, 0.25, 0.65)
		var p_exp: float = log(0.5) / log(shift_c)
		var u_w: float = pow(flight_u, p_exp)
		var para: float = clampf(4.0 * u_w * (1.0 - u_w), 0.0, 1.0)
		air_wave = pow(para, clampf(hang_power, 0.45, 1.35))
		if flight_u < 0.34:
			var launch_u: float = clampf(flight_u / 0.34, 0.0, 1.0)
			launch_wave = sin(launch_u * PI)
		glide_wave = sin(flight_u * PI) * air_wave
		reach_wave = smoothstep(0.60, 0.92, flight_u) * (1.0 - 0.30 * smoothstep(0.92, 1.0, flight_u))
		if flight_u < 0.25:
			subphase = &"LAUNCH"
		elif flight_u > 0.74:
			subphase = &"REACH"
		else:
			subphase = &"GLIDE"

	return {
		"hop_u": hop_u,
		"air_wave": air_wave,
		"crouch_wave": crouch_wave,
		"push_wave": push_wave,
		"launch_wave": launch_wave,
		"glide_wave": glide_wave,
		"reach_wave": reach_wave,
		"flight_u": flight_u,
		"lead_side": lead_side,
		"subphase": subphase,
	}


func step_gait(
	delta: float,
	speed_norm: float,
	world_displacement_m: float,
	cfg: GroundedConfigScript
) -> Dictionary:
	var dt: float = clampf(delta, 0.0, 0.08)
	var spd: float = clampf(speed_norm, 0.0, 1.35)
	idle_time += dt

	var min_spd: float = cfg.min_walk_speed_norm if cfg != null else 0.06
	var in_rate: float = cfg.walk_blend_in_rate if cfg != null else 12.0
	var out_rate: float = cfg.walk_blend_out_rate if cfg != null else 10.0
	var is_moving: bool = spd >= min_spd
	var target_blend: float = clampf(spd, 0.0, 1.2) if is_moving else 0.0
	var blend_rate: float = in_rate if target_blend >= walk_blend else out_rate
	walk_blend = lerpf(walk_blend, target_blend, 1.0 - exp(-blend_rate * dt))
	if not is_moving and walk_blend < 0.005:
		walk_blend = 0.0

	# Arranque (Start-Up) y Frenado (Stop-Plant)
	if is_moving and not _was_moving:
		start_weight = 1.0
		stop_weight = 0.0
	elif not is_moving and _was_moving and _prev_speed_norm > 0.30:
		stop_weight = clampf(_prev_speed_norm, 0.35, 1.0)
	_was_moving = is_moving
	_prev_speed_norm = lerpf(_prev_speed_norm, spd, 1.0 - exp(-10.0 * dt))

	var start_dur: float = maxf(cfg.start_lean_duration_sec if cfg != null else 0.24, 0.05)
	var stop_dur: float = maxf(cfg.stop_plant_duration_sec if cfg != null else 0.28, 0.05)
	var pivot_dur: float = maxf(cfg.pivot_duration_sec if cfg != null else 0.26, 0.05)
	start_weight = maxf(0.0, start_weight - dt / start_dur)
	stop_weight = maxf(0.0, stop_weight - dt / stop_dur)
	pivot_weight = maxf(0.0, pivot_weight - dt / pivot_dur)

	# Stride-Lock: avance de fase atado a distancia real recorrida en metros
	var stride_m: float = get_active_stride_length_m(cfg)
	var eff_disp_m: float = world_displacement_m
	if eff_disp_m < 0.0:
		var fallback_spd_m: float = (cfg.hub_move_speed if cfg != null else 6.8) * spd
		eff_disp_m = fallback_spd_m * dt

	var phase_step: float = (eff_disp_m / stride_m) * TAU
	var prev_phase: float = gait_phase
	var next_phase: float = prev_phase + phase_step

	var is_hop: bool = is_hop_gait(cfg)
	if walk_blend > 0.14 and phase_step > 0.0001:
		var half_prev: int = int(floor(prev_phase / PI))
		var half_next: int = int(floor(next_phase / PI))
		if half_next > half_prev:
			step_count += 1
			_pending_step_foot = &"right" if (half_next % 2) == 0 else &"left"
			_pending_step_strength = clampf(maxf(spd, walk_blend), 0.35, 1.15)
	elif not is_moving and walk_blend > 0.01:
		# Al detenerse, asienta suavemente hacia el contacto más cercano (0 o PI)
		var nearest_half: float = roundf(gait_phase / PI) * PI
		var settle_rate: float = 9.0 if is_hop else 5.0
		next_phase = lerpf(gait_phase, nearest_half, 1.0 - exp(-settle_rate * dt))

	gait_phase = fposmod(next_phase, TAU)

	# Altura normalizada de la pelvis en el ciclo (0 en contacto/aterrizaje, 1 en ápice/impulso)
	var lift_wave: float = 0.0
	if cfg != null and cfg.gait_style == GroundedConfigScript.GaitStyle.ASTRAL_GLIDE_HOP:
		var g_curves: Dictionary = sample_astral_glide_curves(gait_phase, cfg.glide_contact_duty, cfg.glide_arc_hang_power, cfg.glide_arc_peak_shift)
		lift_wave = float(g_curves["air_wave"])
	elif is_hop:
		var curves: Dictionary = sample_moon_hop_curves(gait_phase, cfg.hop_contact_duty)
		lift_wave = float(curves["air_wave"])
	else:
		lift_wave = 0.5 - 0.5 * cos(gait_phase * 2.0 - 0.45)
	pelvis_lift_norm = clampf(lift_wave * walk_blend, 0.0, 1.0)

	return {
		"walk_blend": walk_blend,
		"gait_phase": gait_phase,
		"pelvis_lift_norm": pelvis_lift_norm,
		"step_foot": _pending_step_foot,
		"step_strength": _pending_step_strength,
		"start_weight": start_weight,
		"stop_weight": stop_weight,
		"pivot_weight": pivot_weight,
	}


func evaluate_motion_for_view(
	view_key: String,
	cfg: GroundedConfigScript,
	pose_scale: float = 1.0,
	forced_phase: float = -1.0,
	forced_walk_blend: float = -1.0
) -> Dictionary:
	var fam: String = BasePoseConfigScript.canonical_family_for_view(view_key)
	var is_mirrored_left: bool = view_key in ["sw", "w", "nw"]
	var mirror_sign: float = -1.0 if is_mirrored_left else 1.0
	var back_sign: float = -1.0 if view_key == "n" else 1.0
	var z_sign: float = -1.0 if view_key in ["n", "ne", "nw"] else 1.0

	var phase: float = gait_phase if forced_phase < 0.0 else fposmod(forced_phase, TAU)
	var wb: float = clampf(walk_blend if forced_walk_blend < 0.0 else forced_walk_blend, 0.0, 1.25)
	var wb_smooth: float = smoothstep(0.0, 1.0, clampf(wb, 0.0, 1.0)) * maxf(1.0, wb)
	var idle_w: float = clampf(1.0 - wb_smooth, 0.0, 1.0)
	var m_int: float = (cfg.master_intensity if cfg != null else 1.0) * pose_scale

	var mul_stride: float = cfg.get_family_mul(fam, "bone_stride_scale") if cfg != null else 1.0
	var mul_25d: float = cfg.get_family_mul(fam, "persp_25d_scale") if cfg != null else 1.0
	var mul_arms: float = cfg.get_family_mul(fam, "arm_swing_scale") if cfg != null else 1.0
	var mul_bounce: float = cfg.get_family_mul(fam, "pelvis_bounce_scale") if cfg != null else 1.0
	var mul_twist: float = cfg.get_family_mul(fam, "torso_twist_scale") if cfg != null else 1.0

	var motion: Dictionary = {
		"skel_active": true,
		"persp_active": true,
		"sec_active": true,
		"pelvis_offset": Vector2.ZERO,
		"pelvis_rot": 0.0,
		"waist_rot": 0.0,
		"chest_rot": 0.0,
		"neck_rot": 0.0,
		"head_offset": Vector2.ZERO,
		"head_rot": 0.0,
		"arm_lead": {"sh": 0.0, "el": 0.0, "wr": 0.0, "phi1": 0.0, "phi2": 0.0},
		"arm_trail": {"sh": 0.0, "el": 0.0, "wr": 0.0, "phi1": 0.0, "phi2": 0.0},
		"leg_lead": {"th": 0.0, "kn": 0.0, "an": 0.0, "phi_t": 0.0, "phi_s": 0.0, "dist": 0.0, "depth": 0.0},
		"leg_trail": {"th": 0.0, "kn": 0.0, "an": 0.0, "phi_t": 0.0, "phi_s": 0.0, "dist": 0.0, "depth": 0.0},
		"torso_trap": 0.0,
		"torso_yaw": 0.0,
		"torso_jiggle_l": Vector2.ZERO,
		"torso_jiggle_r": Vector2.ZERO,
		"_idle_torso_jiggle_l": Vector2.ZERO,
		"_idle_torso_jiggle_r": Vector2.ZERO,
		"sec_normal_strength": 0.0,
		"hair_jiggle_l": Vector2.ZERO,
		"hair_jiggle_r": Vector2.ZERO,
	}

	# 1. Capa Idle Grounded (botas al suelo: respiración y micro cambio de peso sin levitación)
	var breath_hz: float = cfg.idle_breath_hz if cfg != null else 0.34
	var shift_hz: float = cfg.idle_weight_shift_hz if cfg != null else 0.17
	var ph_b: float = idle_time * TAU * breath_hz
	var ph_s: float = idle_time * TAU * shift_hz
	var breath: float = sin(ph_b)
	var w_shift: float = sin(ph_s)

	var idle_pelvis_x: float = w_shift * 0.85 * mirror_sign * idle_w * m_int
	var idle_pelvis_rot: float = w_shift * 0.012 * mirror_sign * idle_w * m_int
	var idle_chest_rot: float = breath * 0.014 * idle_w * m_int
	var idle_neck_rot: float = -breath * 0.011 * idle_w * m_int
	var idle_arm_breath: float = sin(ph_b - 0.45) * 0.016 * idle_w * m_int

	if cfg != null and cfg.gait_style == GroundedConfigScript.GaitStyle.ASTRAL_GLIDE_HOP:
		return _evaluate_astral_glide_hop_motion(
			fam, mirror_sign, back_sign, z_sign, phase, wb_smooth, idle_w, m_int,
			mul_stride, mul_25d, mul_arms, mul_bounce, mul_twist, cfg,
			idle_pelvis_x, idle_pelvis_rot, idle_chest_rot, idle_neck_rot, idle_arm_breath,
			breath, w_shift, motion
		)

	if cfg != null and cfg.gait_style == GroundedConfigScript.GaitStyle.MOON_HOP:
		return _evaluate_moon_hop_motion(
			fam, mirror_sign, back_sign, z_sign, phase, wb_smooth, idle_w, m_int,
			mul_stride, mul_25d, mul_arms, mul_bounce, mul_twist, cfg,
			idle_pelvis_x, idle_pelvis_rot, idle_chest_rot, idle_neck_rot, idle_arm_breath,
			breath, w_shift, motion
		)

	# 2. Capa Ciclo de Marcha 4 Fases (phase=0 -> contacto lead, phase=PI -> contacto trail)
	var leg_lead_d: Dictionary = _eval_leg_cycle(phase, fam, mirror_sign, z_sign, mul_stride, mul_25d, cfg)
	var leg_trail_d: Dictionary = _eval_leg_cycle(phase + PI, fam, mirror_sign, z_sign, mul_stride, mul_25d, cfg)

	# Rebote vertical C^∞ suave con leve asimetría armónica (sin quiebres en los extremos)
	var bounce_down: float = cfg.pelvis_bounce_down_px if cfg != null else 2.6
	var bounce_up: float = cfg.pelvis_bounce_up_px if cfg != null else -2.0
	var mid_b: float = 0.5 * (bounce_down + bounce_up)
	var amp_b: float = 0.5 * (bounce_down - bounce_up)
	var pelvis_y_walk: float = (mid_b + amp_b * (cos(phase * 2.0 - 0.35) + 0.14 * sin(phase * 4.0 - 0.70))) * mul_bounce

	# Balanceo lateral hacia la pierna que pisa (phase=0 -> apoya lead)
	var step_side: float = cos(phase)
	var sway_x: float = (cfg.pelvis_sway_x_px if cfg != null else 1.4) * step_side * mirror_sign
	var pelvis_roll: float = (cfg.pelvis_roll_rad if cfg != null else 0.022) * sin(phase) * mirror_sign

	# Contrapposto de torso y forward lean atlético con envolventes suaves
	var lean_waist: float = (cfg.forward_lean_waist_rad if cfg != null else 0.030)
	var lean_chest: float = (cfg.forward_lean_chest_rad if cfg != null else 0.036)
	var start_lean: float = sin(start_weight * PI) * 0.032
	var stop_absorb_y: float = sin(stop_weight * PI) * 1.8
	var stop_lean: float = sin(stop_weight * PI) * 0.025
	var pivot_twist: float = sin(pivot_weight * PI) * pivot_dir * 0.055 * mirror_sign

	# En vista frontal S, forward lean se traduce en ligero trapecio y compresión; en E/SE/NE inclina torso en Z
	var dir_lean_proj: float = 0.20 if (fam == "s" or fam == "n") else (0.70 if (fam == "se" or fam == "ne") else 1.0)
	var lean_sign: float = -1.0 if fam == "n" else 1.0

	var waist_rot_walk: float = ((cfg.waist_counter_rad if cfg != null else -0.018) * step_side * mul_twist + (lean_waist + start_lean + stop_lean) * dir_lean_proj * lean_sign) * mirror_sign
	var chest_rot_walk: float = ((cfg.chest_counter_rad if cfg != null else -0.016) * step_side * mul_twist + (lean_chest + start_lean + stop_lean) * dir_lean_proj * lean_sign) * mirror_sign
	var torso_pitch_eff: float = waist_rot_walk + chest_rot_walk
	var neck_stab: float = cfg.neck_stabilize_ratio if cfg != null else 0.88
	var neck_rot_walk: float = -torso_pitch_eff * neck_stab

	var head_lag_y: float = -pelvis_y_walk * ((cfg.head_bob_lag_px if cfg != null else 0.9) / maxf(absf(bounce_down), 1.0)) * 0.45
	var head_rot_walk: float = (cfg.head_counter_rot_rad if cfg != null else 0.010) * sin(phase * 2.0 - 0.65) * mirror_sign

	var torso_yaw_walk: float = ((cfg.torso_yaw_stride if cfg != null else 0.028) * step_side * mul_twist * mirror_sign) + pivot_twist
	var torso_trap_walk: float = (cfg.torso_trap_lean if cfg != null else -0.018) * (0.45 if fam == "e" else 1.0) * z_sign

	# Brazos en contrafase exacta (PI) respecto a su pierna ipsilateral
	var arm_lead_d: Dictionary = _eval_arm_cycle(phase + PI, fam, 1.0, mirror_sign, back_sign, z_sign, mul_arms, mul_25d, cfg)
	var arm_trail_d: Dictionary = _eval_arm_cycle(phase, fam, -1.0, mirror_sign, back_sign, z_sign, mul_arms, mul_25d, cfg)

	# Combinar Idle + Walk por walk_blend suavizado (curva S)
	var w_mul: float = wb_smooth * m_int
	motion["pelvis_offset"] = Vector2(idle_pelvis_x + sway_x * w_mul, pelvis_y_walk * w_mul + stop_absorb_y * m_int)
	motion["pelvis_rot"] = idle_pelvis_rot + (pelvis_roll * w_mul)
	motion["waist_rot"] = waist_rot_walk * w_mul + pivot_twist * 0.45
	motion["chest_rot"] = idle_chest_rot + chest_rot_walk * w_mul + pivot_twist * 0.65
	motion["neck_rot"] = idle_neck_rot + neck_rot_walk * w_mul
	motion["head_offset"] = Vector2(0.0, head_lag_y * w_mul + stop_absorb_y * 0.25 * m_int)
	motion["head_rot"] = head_rot_walk * w_mul - pivot_twist * 0.35
	motion["torso_yaw"] = torso_yaw_walk * w_mul + w_shift * 0.008 * mirror_sign * idle_w * m_int
	motion["torso_trap"] = torso_trap_walk * w_mul + breath * 0.008 * idle_w * m_int

	var m_leg_lead: Dictionary = motion["leg_lead"] as Dictionary
	var m_leg_trail: Dictionary = motion["leg_trail"] as Dictionary
	for k: String in ["th", "kn", "an", "phi_t", "phi_s", "dist", "depth"]:
		var stop_kn: float = (stop_weight * 0.14 * mirror_sign * mul_stride) if k == "kn" else 0.0
		var stop_phi_s: float = (-stop_weight * 0.14 * z_sign * mul_25d) if k == "phi_s" else 0.0
		m_leg_lead[k] = float(leg_lead_d[k]) * w_mul + (stop_kn + stop_phi_s) * m_int
		m_leg_trail[k] = float(leg_trail_d[k]) * w_mul + (stop_kn + stop_phi_s) * m_int

	var m_arm_lead: Dictionary = motion["arm_lead"] as Dictionary
	var m_arm_trail: Dictionary = motion["arm_trail"] as Dictionary
	for k_a: String in ["sh", "el", "wr", "phi1", "phi2"]:
		var idle_a: float = idle_arm_breath * mirror_sign * (1.0 if k_a == "sh" else 0.6)
		m_arm_lead[k_a] = float(arm_lead_d[k_a]) * w_mul + (idle_a if k_a in ["sh", "el"] else 0.0)
		m_arm_trail[k_a] = float(arm_trail_d[k_a]) * w_mul - (idle_a if k_a in ["sh", "el"] else 0.0)

	# Arrastre secundario en cabello y pecho sincronizado al rebote de pisada
	var hair_bounce: float = (cfg.step_hair_bounce_px if cfg != null else 2.6) * sin(phase * 2.0 - 0.75) * w_mul
	var hair_drag_x: float = (-1.6 * mirror_sign * w_mul) + (-pivot_twist * 18.0)
	motion["hair_jiggle_l"] = Vector2(hair_drag_x, hair_bounce)
	motion["hair_jiggle_r"] = Vector2(hair_drag_x, hair_bounce * 0.92)
	var torso_sec_y: float = -pelvis_y_walk * 0.22 * w_mul
	motion["torso_jiggle_l"] = Vector2(-0.35 * mirror_sign * w_mul, torso_sec_y)
	motion["torso_jiggle_r"] = Vector2(-0.35 * mirror_sign * w_mul, torso_sec_y * 0.9)

	return motion


static func sample_moon_hop_curves(phase: float, contact_duty: float) -> Dictionary:
	var duty: float = clampf(contact_duty, 0.05, 0.55)
	var hop_u: float = fposmod(phase, PI) / PI
	var air_wave: float = 0.0
	var crouch_wave: float = 0.0
	var takeoff_wave: float = 0.0
	var flight_u: float = 0.0
	if hop_u < duty:
		var contact_u: float = hop_u / duty
		crouch_wave = sin(contact_u * PI)
	else:
		flight_u = clampf((hop_u - duty) / maxf(1.0 - duty, 0.05), 0.0, 1.0)
		air_wave = clampf(4.0 * flight_u * (1.0 - flight_u), 0.0, 1.0)
		if flight_u < 0.30:
			var launch_u: float = clampf(flight_u / 0.30, 0.0, 1.0)
			takeoff_wave = sin(launch_u * PI)
	return {
		"hop_u": hop_u,
		"air_wave": air_wave,
		"crouch_wave": crouch_wave,
		"takeoff_wave": takeoff_wave,
		"flight_u": flight_u,
	}


func get_hop_canvas_scale(
	cfg: GroundedConfigScript,
	pose_scale: float = 1.0,
	forced_phase: float = -1.0,
	forced_walk_blend: float = -1.0
) -> Vector2:
	if not is_hop_gait(cfg):
		return Vector2.ONE
	var phase: float = gait_phase if forced_phase < 0.0 else fposmod(forced_phase, TAU)
	var wb: float = clampf(walk_blend if forced_walk_blend < 0.0 else forced_walk_blend, 0.0, 1.25)
	var wb_smooth: float = smoothstep(0.0, 1.0, clampf(wb, 0.0, 1.0)) * maxf(1.0, wb)
	var m_int: float = cfg.master_intensity * pose_scale
	var w: float = clampf(wb_smooth * m_int, 0.0, 1.2)
	var squash: float = 0.0
	var stretch: float = 0.0
	if cfg.gait_style == GroundedConfigScript.GaitStyle.ASTRAL_GLIDE_HOP:
		var g_curves: Dictionary = sample_astral_glide_curves(phase, cfg.glide_contact_duty, cfg.glide_arc_hang_power, cfg.glide_arc_peak_shift)
		squash = cfg.glide_squash_amount * float(g_curves["crouch_wave"])
		stretch = cfg.glide_stretch_amount * clampf(float(g_curves["launch_wave"]) + float(g_curves["push_wave"]) * 0.35, 0.0, 1.15)
	else:
		var curves: Dictionary = sample_moon_hop_curves(phase, cfg.hop_contact_duty)
		squash = cfg.hop_squash_amount * float(curves["crouch_wave"])
		stretch = cfg.hop_stretch_amount * float(curves["takeoff_wave"])
	var sy_delta: float = (-squash + stretch) * w
	var sx_delta: float = (squash * 0.78 - stretch * 0.65) * w
	return Vector2(clampf(1.0 + sx_delta, 0.88, 1.12), clampf(1.0 + sy_delta, 0.88, 1.12))


func get_hop_canvas_offset_y(
	cfg: GroundedConfigScript,
	pose_scale: float = 1.0,
	forced_phase: float = -1.0,
	forced_walk_blend: float = -1.0
) -> float:
	if not is_hop_gait(cfg):
		return 0.0
	var phase: float = gait_phase if forced_phase < 0.0 else fposmod(forced_phase, TAU)
	var wb: float = clampf(walk_blend if forced_walk_blend < 0.0 else forced_walk_blend, 0.0, 1.25)
	var wb_smooth: float = smoothstep(0.0, 1.0, clampf(wb, 0.0, 1.0)) * maxf(1.0, wb)
	var m_int: float = cfg.master_intensity * pose_scale
	var sc: Vector2 = get_hop_canvas_scale(cfg, pose_scale, forced_phase, forced_walk_blend)
	var air_wave: float = 0.0
	var arc_h: float = 0.0
	if cfg.gait_style == GroundedConfigScript.GaitStyle.ASTRAL_GLIDE_HOP:
		var g_curves: Dictionary = sample_astral_glide_curves(phase, cfg.glide_contact_duty, cfg.glide_arc_hang_power, cfg.glide_arc_peak_shift)
		air_wave = float(g_curves["air_wave"])
		arc_h = cfg.glide_arc_height_rig_px
	else:
		var curves: Dictionary = sample_moon_hop_curves(phase, cfg.hop_contact_duty)
		air_wave = float(curves["air_wave"])
		arc_h = cfg.hop_arc_height_rig_px
	var arc_lift_y: float = -arc_h * air_wave * wb_smooth * m_int
	var pivot_pin_y: float = (1.0 - sc.y) * HOP_BOOT_PIVOT_Y_RIG_PX
	return arc_lift_y + pivot_pin_y


func _evaluate_astral_glide_hop_motion(
	fam: String,
	mirror_sign: float,
	back_sign: float,
	z_sign: float,
	phase: float,
	wb_smooth: float,
	idle_w: float,
	m_int: float,
	mul_stride: float,
	mul_25d: float,
	mul_arms: float,
	mul_bounce: float,
	mul_twist: float,
	cfg: GroundedConfigScript,
	idle_pelvis_x: float,
	idle_pelvis_rot: float,
	idle_chest_rot: float,
	idle_neck_rot: float,
	idle_arm_breath: float,
	breath: float,
	w_shift: float,
	motion: Dictionary
) -> Dictionary:
	var curves: Dictionary = sample_astral_glide_curves(phase, cfg.glide_contact_duty, cfg.glide_arc_hang_power, cfg.glide_arc_peak_shift)
	var lag_curves: Dictionary = sample_astral_glide_curves(phase - 0.28, cfg.glide_contact_duty, cfg.glide_arc_hang_power, cfg.glide_arc_peak_shift)
	var hop_u: float = float(curves["hop_u"])
	var air_wave: float = float(curves["air_wave"])
	var crouch_wave: float = float(curves["crouch_wave"])
	var launch_wave: float = float(curves["launch_wave"])
	var glide_wave: float = float(curves["glide_wave"])
	var reach_wave: float = float(curves["reach_wave"])
	var flight_u: float = float(curves["flight_u"])
	var lead_side: float = float(curves["lead_side"])
	var lag_air: float = float(lag_curves["air_wave"])
	var lag_glide: float = float(lag_curves["glide_wave"])

	var w_mul: float = wb_smooth * m_int
	var stop_absorb_y: float = sin(stop_weight * PI) * 1.6

	# Pelvis y torso: deslizamiento grácil alternando costado L/R y leve inclinación aerodinámica
	var is_frontal: bool = (fam == "s" or fam == "n")
	var pelvis_y_glide: float = (cfg.glide_crouch_dip_rig_px * crouch_wave - 3.2 * air_wave) * maxf(mul_bounce, 0.85)
	var sway_x: float = (2.60 if is_frontal else 1.45) * lead_side * air_wave * mirror_sign
	var pelvis_roll: float = cfg.glide_torso_bank_rad * (1.65 if is_frontal else 1.0) * lead_side * air_wave * mirror_sign

	var dir_lean_proj: float = 0.24 if is_frontal else (0.74 if (fam == "se" or fam == "ne") else 1.0)
	var lean_sign: float = -1.0 if fam == "n" else 1.0
	var lean_amt: float = cfg.glide_forward_lean_rad * (0.35 + 0.65 * glide_wave + 0.30 * launch_wave) + sin(start_weight * PI) * 0.022
	var crouch_pitch: float = 0.016 * crouch_wave
	var pivot_twist: float = sin(pivot_weight * PI) * pivot_dir * 0.048 * mirror_sign
	var front_bank: float = (0.018 * lead_side * glide_wave * mul_twist) if is_frontal else (0.009 * lead_side * glide_wave * mul_twist)

	var waist_rot_glide: float = ((lean_amt * 0.50 + crouch_pitch) * dir_lean_proj * lean_sign + front_bank * 0.55) * mirror_sign
	var chest_rot_glide: float = ((lean_amt * 0.62 + crouch_pitch) * dir_lean_proj * lean_sign + front_bank * 0.70) * mirror_sign
	var neck_stab: float = cfg.neck_stabilize_ratio
	var neck_rot_glide: float = -(waist_rot_glide + chest_rot_glide) * neck_stab
	var head_lag_y: float = -pelvis_y_glide * 0.14
	var head_rot_glide: float = (-0.014 * air_wave * dir_lean_proj * lean_sign - front_bank * 0.35) * mirror_sign

	var torso_yaw_glide: float = 0.024 * lead_side * glide_wave * mul_twist * mirror_sign + pivot_twist
	var torso_trap_glide: float = -0.014 * (0.45 if fam == "e" else 1.0) * z_sign * air_wave

	motion["pelvis_offset"] = Vector2(idle_pelvis_x + sway_x * w_mul, pelvis_y_glide * w_mul + stop_absorb_y * m_int)
	motion["pelvis_rot"] = idle_pelvis_rot + pelvis_roll * w_mul
	motion["waist_rot"] = waist_rot_glide * w_mul + pivot_twist * 0.40
	motion["chest_rot"] = idle_chest_rot + chest_rot_glide * w_mul + pivot_twist * 0.55
	motion["neck_rot"] = idle_neck_rot + neck_rot_glide * w_mul
	motion["head_offset"] = Vector2(0.0, head_lag_y * w_mul + stop_absorb_y * 0.22 * m_int)
	motion["head_rot"] = head_rot_glide * w_mul - pivot_twist * 0.30
	motion["torso_yaw"] = torso_yaw_glide * w_mul + w_shift * 0.008 * mirror_sign * idle_w * m_int
	motion["torso_trap"] = torso_trap_glide * w_mul + breath * 0.008 * idle_w * m_int

	# Piernas Jeté Grácil alternando líder/trasera en cada arco (cero V-legs, rodilla >= 0 en 'e')
	var kn_fam_atten: float = 0.35 if fam == "ne" else (0.50 if fam == "se" else 1.0)
	var an_fam_atten: float = 0.20 if (fam == "se" or fam == "ne") else (0.45 if is_frontal else 1.0)
	var bone_mul: float = 1.0 if fam == "e" else (0.44 if fam == "se" else (0.34 if fam == "ne" else 0.0))
	var boost_25d: float = 2.55 if is_frontal else (1.05 if fam == "se" else (0.90 if fam == "ne" else 0.35))

	var p_thigh: float = cfg.leg_25d_phi_thigh_amp * 0.96 * boost_25d
	var p_shin: float = cfg.leg_25d_phi_shin_amp * 0.98 * boost_25d
	var p_dist: float = cfg.leg_25d_distal_amp * 0.90 * boost_25d
	var p_depth: float = cfg.glide_25d_leg_depth_amp * boost_25d
	var eff_25d: float = mul_25d
	var eff_stride: float = maxf(mul_stride, 0.85)

	var lead_is_front: bool = lead_side >= 0.0
	var front_leg: Dictionary
	var back_leg: Dictionary
	if is_frontal:
		# En N y S, la pierna frontal realiza un poise/pase grácil (rodilla adelantada/arriba en 2.5D + sutil flexión ósea)
		# y la trasera se alarga limpia hacia atrás con z_sign consistente en phi_t/phi_s/dist.
		var front_out_sign: float = 1.0 if ((fam == "s" and lead_is_front) or (fam == "n" and not lead_is_front)) else -1.0
		var back_out_sign: float = -front_out_sign
		var front_pose: float = 0.95 * glide_wave + 0.45 * launch_wave + 0.30 * reach_wave
		var back_pose: float = 0.95 * launch_wave + 0.85 * glide_wave + 0.20 * reach_wave
		front_leg = {
			"th": front_out_sign * 0.115 * front_pose * eff_25d,
			"kn": -front_out_sign * 0.185 * front_pose * eff_25d,
			"an": front_out_sign * 0.085 * front_pose * eff_25d,
			"phi_t": (1.42 * glide_wave + 0.65 * launch_wave + 0.50 * reach_wave - 0.32 * crouch_wave) * p_thigh * z_sign * eff_25d,
			"phi_s": (-1.45 * glide_wave - 0.65 * launch_wave - 0.48 * crouch_wave) * p_shin * z_sign * eff_25d,
			"dist": (-1.05 * glide_wave + 0.30 * reach_wave - 0.24 * crouch_wave) * p_dist * z_sign * eff_25d,
			"depth": (0.95 * glide_wave + 0.42 * reach_wave) * p_depth * z_sign * eff_25d,
		}
		back_leg = {
			"th": -back_out_sign * 0.065 * back_pose * eff_25d,
			"kn": back_out_sign * 0.080 * glide_wave * eff_25d,
			"an": -back_out_sign * 0.055 * back_pose * eff_25d,
			"phi_t": (-0.90 * glide_wave - 0.70 * launch_wave - 0.28 * crouch_wave) * p_thigh * z_sign * eff_25d,
			"phi_s": (-0.50 * glide_wave - 0.28 * launch_wave - 0.38 * crouch_wave) * p_shin * z_sign * eff_25d,
			"dist": (-0.75 * glide_wave - 0.45 * launch_wave - 0.20 * crouch_wave) * p_dist * z_sign * eff_25d,
			"depth": -(0.95 * glide_wave + 0.45 * launch_wave) * p_depth * z_sign * eff_25d,
		}
	else:
		# En vistas 3/4 (ne/se) las dos piernas en standing_families tienen signos de rodilla/tobillo adaptados al plano 3/4.
		var kn_bone_sign: float = -1.0 if (fam == "ne" and not lead_is_front) else 1.0
		var kn_back_sign: float = -1.0 if (fam == "ne" and lead_is_front) else 1.0
		front_leg = {
			"th": (-cfg.glide_lead_thigh_fwd_rad * (0.85 * glide_wave + 0.55 * reach_wave + 0.35 * launch_wave) - 0.06 * crouch_wave) * mirror_sign * bone_mul * eff_stride,
			"kn": maxf(0.0, cfg.glide_lead_knee_poise_rad * (0.95 * glide_wave + 0.35 * launch_wave) + cfg.glide_rebound_knee_rad * (crouch_wave + 0.30 * reach_wave)) * mirror_sign * bone_mul * kn_fam_atten * kn_bone_sign,
			"an": (cfg.glide_ankle_point_rad * (0.75 * glide_wave + 0.50 * launch_wave) + cfg.glide_ankle_reach_rad * reach_wave - 0.06 * crouch_wave) * mirror_sign * bone_mul * an_fam_atten,
			"phi_t": (0.85 * glide_wave + 0.45 * reach_wave - 0.32 * crouch_wave) * p_thigh * z_sign * eff_25d,
			"phi_s": (-0.95 * glide_wave - 0.40 * launch_wave - 0.48 * crouch_wave) * p_shin * z_sign * eff_25d,
			"dist": (-0.65 * glide_wave + 0.25 * reach_wave - 0.22 * crouch_wave) * p_dist * z_sign * eff_25d,
			"depth": 0.0 if fam == "e" else ((0.75 * glide_wave + 0.35 * reach_wave) * p_depth * z_sign * eff_25d),
		}
		back_leg = {
			"th": (cfg.glide_trail_thigh_back_rad * (1.10 * launch_wave + 0.92 * glide_wave + 0.20 * reach_wave) - 0.04 * crouch_wave) * mirror_sign * bone_mul * eff_stride,
			"kn": maxf(0.0, cfg.glide_trail_knee_sweep_rad * (0.45 * launch_wave + 0.95 * glide_wave + 0.35 * reach_wave) + cfg.glide_rebound_knee_rad * crouch_wave) * mirror_sign * bone_mul * kn_fam_atten * kn_back_sign,
			"an": (cfg.glide_ankle_point_rad * 1.10 * (launch_wave + glide_wave) - 0.05 * crouch_wave) * mirror_sign * bone_mul * an_fam_atten,
			"phi_t": (-0.80 * glide_wave - 0.65 * launch_wave - 0.28 * crouch_wave) * p_thigh * z_sign * eff_25d,
			"phi_s": (-0.65 * glide_wave - 0.35 * launch_wave - 0.42 * crouch_wave) * p_shin * z_sign * eff_25d,
			"dist": (-0.78 * glide_wave - 0.42 * launch_wave - 0.20 * crouch_wave) * p_dist * z_sign * eff_25d,
			"depth": 0.0 if fam == "e" else (-(0.75 * glide_wave + 0.45 * launch_wave) * p_depth * z_sign * eff_25d),
		}

	var leg_lead_d: Dictionary = front_leg if lead_is_front else back_leg
	var leg_trail_d: Dictionary = back_leg if lead_is_front else front_leg

	var m_leg_lead: Dictionary = motion["leg_lead"] as Dictionary
	var m_leg_trail: Dictionary = motion["leg_trail"] as Dictionary
	for k: String in ["th", "kn", "an", "phi_t", "phi_s", "dist", "depth"]:
		var stop_kn: float = (stop_weight * 0.12 * mirror_sign * bone_mul) if k == "kn" else 0.0
		var stop_phi_s: float = (-stop_weight * 0.12 * z_sign * eff_25d) if k == "phi_s" else 0.0
		m_leg_lead[k] = float(leg_lead_d[k]) * w_mul + (stop_kn + stop_phi_s) * m_int
		m_leg_trail[k] = float(leg_trail_d[k]) * w_mul + (stop_kn + stop_phi_s) * m_int

	# Brazos flotantes compactos y elegantes cerca del cuerpo (coherentes en las 8 direcciones)
	var arm_flt: float = cfg.glide_arm_grace_rad
	var elbow_soft: float = cfg.glide_arm_elbow_soft_rad
	var m_arm_lead: Dictionary = motion["arm_lead"] as Dictionary
	var m_arm_trail: Dictionary = motion["arm_trail"] as Dictionary
	for role_pair: Array in [[m_arm_lead, 1.0], [m_arm_trail, -1.0]]:
		var m_arm: Dictionary = role_pair[0] as Dictionary
		var r_sign: float = float(role_pair[1])
		var sh_val: float
		var el_val: float
		var wr_val: float
		if is_frontal:
			var bank_arm: float = 1.0 + 0.26 * lead_side * r_sign
			sh_val = (arm_flt * (0.80 * lag_air + 0.20 * crouch_wave) * r_sign * bank_arm) * mirror_sign * back_sign * mul_arms
			el_val = (-elbow_soft * 0.55 - 0.14 * lag_glide) * r_sign * mirror_sign * back_sign * mul_arms
			wr_val = (-0.10 * lag_air * r_sign) * mirror_sign * back_sign * mul_arms
		elif fam == "e":
			var contra_e: float = -lead_side * r_sign
			sh_val = (-0.055 * lag_air + arm_flt * 0.42 * lag_glide * contra_e) * mirror_sign * back_sign * mul_arms
			el_val = (-elbow_soft * (0.85 + 0.35 * lag_air) - 0.08 * lag_glide * contra_e) * mirror_sign * back_sign * mul_arms
			wr_val = (0.06 * cos(hop_u * PI) * contra_e) * mirror_sign * back_sign * mul_arms
		else:
			var contra_sign: float = -lead_side * r_sign
			sh_val = (arm_flt * (0.22 * lag_air + 0.48 * lag_glide * contra_sign)) * mirror_sign * back_sign * mul_arms
			el_val = (-elbow_soft * (0.65 + 0.35 * lag_air)) * mirror_sign * back_sign * mul_arms
			wr_val = (0.08 * cos(hop_u * PI) * contra_sign) * mirror_sign * back_sign * mul_arms
		m_arm["sh"] = sh_val * w_mul + idle_arm_breath * mirror_sign * r_sign
		m_arm["el"] = el_val * w_mul + idle_arm_breath * mirror_sign * 0.6 * r_sign
		m_arm["wr"] = wr_val * w_mul
		m_arm["phi1"] = (0.08 * lag_air * z_sign * mul_25d) * w_mul
		m_arm["phi2"] = (-0.11 * lag_air * z_sign * mul_25d) * w_mul

	# Cabello balístico y reacción secundaria suave
	var hair_float_y: float = 0.0
	if air_wave > 0.01:
		hair_float_y = cfg.glide_hair_trail_px * cos(flight_u * PI) * w_mul
	elif crouch_wave > 0.01:
		hair_float_y = cfg.glide_hair_trail_px * 0.45 * crouch_wave * w_mul
	var hair_drag_x: float = (-2.4 * air_wave * mirror_sign * w_mul) + (-pivot_twist * 14.0)
	motion["hair_jiggle_l"] = Vector2(hair_drag_x, hair_float_y)
	motion["hair_jiggle_r"] = Vector2(hair_drag_x, hair_float_y * 0.92)
	var torso_sec_y: float = (-pelvis_y_glide * 0.12 + (-2.0 * cos(flight_u * PI) if air_wave > 0.01 else 0.0)) * w_mul
	motion["torso_jiggle_l"] = Vector2(-0.28 * mirror_sign * w_mul, torso_sec_y)
	motion["torso_jiggle_r"] = Vector2(-0.28 * mirror_sign * w_mul, torso_sec_y * 0.9)

	return motion


func _evaluate_moon_hop_motion(
	fam: String,
	mirror_sign: float,
	back_sign: float,
	z_sign: float,
	phase: float,
	wb_smooth: float,
	idle_w: float,
	m_int: float,
	mul_stride: float,
	mul_25d: float,
	mul_arms: float,
	mul_bounce: float,
	mul_twist: float,
	cfg: GroundedConfigScript,
	idle_pelvis_x: float,
	idle_pelvis_rot: float,
	idle_chest_rot: float,
	idle_neck_rot: float,
	idle_arm_breath: float,
	breath: float,
	w_shift: float,
	motion: Dictionary
) -> Dictionary:
	var curves: Dictionary = sample_moon_hop_curves(phase, cfg.hop_contact_duty)
	var lag_curves: Dictionary = sample_moon_hop_curves(phase - 0.24, cfg.hop_contact_duty)
	var hop_u: float = float(curves["hop_u"])
	var air_wave: float = float(curves["air_wave"])
	var crouch_wave: float = float(curves["crouch_wave"])
	var flight_u: float = float(curves["flight_u"])
	var air_lag: float = float(lag_curves["air_wave"])
	var alt_apex: float = sin(phase)

	var w_mul: float = wb_smooth * m_int
	var stop_absorb_y: float = sin(stop_weight * PI) * 1.4

	# Pelvis: amortiguación sutil en contacto y micro-elevación orgánica (el arco principal vive en UnifiedCharacterGroup)
	var pelvis_y_hop: float = (cfg.hop_crouch_dip_rig_px * crouch_wave - 3.5 * air_wave) * maxf(mul_bounce, 0.85)
	var sway_x: float = 0.8 * alt_apex * mirror_sign
	var pelvis_roll: float = 0.016 * alt_apex * air_wave * mirror_sign

	var dir_lean_proj: float = 0.22 if (fam == "s" or fam == "n") else (0.72 if (fam == "se" or fam == "ne") else 1.0)
	var lean_sign: float = -1.0 if fam == "n" else 1.0
	var lean_amt: float = cfg.hop_forward_lean_rad * (0.45 + 0.55 * air_wave) + sin(start_weight * PI) * 0.018
	var crouch_pitch: float = 0.018 * crouch_wave
	var pivot_twist: float = sin(pivot_weight * PI) * pivot_dir * 0.045 * mirror_sign

	var waist_rot_hop: float = ((lean_amt * 0.52 + crouch_pitch) * dir_lean_proj * lean_sign + 0.008 * alt_apex * mul_twist) * mirror_sign
	var chest_rot_hop: float = ((lean_amt * 0.62 + crouch_pitch) * dir_lean_proj * lean_sign + 0.006 * alt_apex * mul_twist) * mirror_sign
	var neck_stab: float = cfg.neck_stabilize_ratio
	var neck_rot_hop: float = -(waist_rot_hop + chest_rot_hop) * neck_stab
	var head_lag_y: float = -pelvis_y_hop * 0.10
	var head_rot_hop: float = -0.012 * air_wave * dir_lean_proj * lean_sign * mirror_sign

	var torso_yaw_hop: float = 0.014 * alt_apex * mul_twist * mirror_sign + pivot_twist
	var torso_trap_hop: float = -0.010 * (0.45 if fam == "e" else 1.0) * z_sign * air_wave

	motion["pelvis_offset"] = Vector2(idle_pelvis_x + sway_x * w_mul, pelvis_y_hop * w_mul + stop_absorb_y * m_int)
	motion["pelvis_rot"] = idle_pelvis_rot + pelvis_roll * w_mul
	motion["waist_rot"] = waist_rot_hop * w_mul + pivot_twist * 0.40
	motion["chest_rot"] = idle_chest_rot + chest_rot_hop * w_mul + pivot_twist * 0.55
	motion["neck_rot"] = idle_neck_rot + neck_rot_hop * w_mul
	motion["head_offset"] = Vector2(0.0, head_lag_y * w_mul + stop_absorb_y * 0.20 * m_int)
	motion["head_rot"] = head_rot_hop * w_mul - pivot_twist * 0.30
	motion["torso_yaw"] = torso_yaw_hop * w_mul + w_shift * 0.008 * mirror_sign * idle_w * m_int
	motion["torso_trap"] = torso_trap_hop * w_mul + breath * 0.008 * idle_w * m_int

	# Piernas recogidas en aire + amortiguación de rodillas en contacto en todas las vistas (sin tijereteo ni V)
	var asym: float = clampf(cfg.hop_leg_asym_ratio, 0.0, 0.7)
	var lead_air: float = air_wave * (1.0 - 0.5 * asym * (1.0 - alt_apex))
	var trail_air: float = air_wave * (1.0 - 0.5 * asym * (1.0 + alt_apex))
	var kn_fam_atten: float = 0.55 if (fam == "se" or fam == "ne") else 1.0
	var hop_leg_bone_mul: float = 1.0 if fam == "e" else (0.65 if (fam == "se" or fam == "ne") else 0.0)
	var hop_25d_boost: float = 1.38 if (fam == "s" or fam == "n") else 1.0

	var p_thigh: float = cfg.leg_25d_phi_thigh_amp * 0.78 * hop_25d_boost
	var p_shin: float = cfg.leg_25d_phi_shin_amp * 0.85 * hop_25d_boost
	var p_dist: float = cfg.leg_25d_distal_amp * 0.78 * hop_25d_boost
	var eff_25d: float = mul_25d

	var leg_lead_d: Dictionary = {
		"th": (-cfg.hop_leg_tuck_thigh_rad * 0.55 * lead_air - 0.05 * crouch_wave) * mirror_sign * hop_leg_bone_mul,
		"kn": maxf(0.0, cfg.hop_leg_tuck_knee_rad * lead_air + cfg.hop_leg_crouch_knee_rad * crouch_wave) * mirror_sign * hop_leg_bone_mul * kn_fam_atten,
		"an": (cfg.hop_ankle_point_rad * lead_air - 0.06 * crouch_wave) * mirror_sign * hop_leg_bone_mul,
		"phi_t": (-lead_air * 0.60 - crouch_wave * 0.35) * p_thigh * z_sign * eff_25d,
		"phi_s": (-lead_air * 0.90 - crouch_wave * 0.45) * p_shin * z_sign * eff_25d,
		"dist": (-lead_air - crouch_wave * 0.30) * p_dist * eff_25d,
		"depth": 0.0 if fam == "e" else (-lead_air * 0.08 * z_sign * eff_25d),
	}
	var leg_trail_d: Dictionary = {
		"th": (cfg.hop_leg_tuck_thigh_rad * 0.90 * trail_air - 0.04 * crouch_wave) * mirror_sign * hop_leg_bone_mul,
		"kn": maxf(0.0, cfg.hop_leg_tuck_knee_rad * 0.85 * trail_air + cfg.hop_leg_crouch_knee_rad * crouch_wave) * mirror_sign * hop_leg_bone_mul * kn_fam_atten,
		"an": (cfg.hop_ankle_point_rad * 1.10 * trail_air - 0.06 * crouch_wave) * mirror_sign * hop_leg_bone_mul,
		"phi_t": (trail_air * 0.45 - crouch_wave * 0.30) * p_thigh * z_sign * eff_25d,
		"phi_s": (-trail_air * 0.80 - crouch_wave * 0.40) * p_shin * z_sign * eff_25d,
		"dist": (-trail_air * 0.90 - crouch_wave * 0.25) * p_dist * eff_25d,
		"depth": 0.0 if fam == "e" else (trail_air * 0.06 * z_sign * eff_25d),
	}

	var m_leg_lead: Dictionary = motion["leg_lead"] as Dictionary
	var m_leg_trail: Dictionary = motion["leg_trail"] as Dictionary
	for k: String in ["th", "kn", "an", "phi_t", "phi_s", "dist", "depth"]:
		var stop_kn: float = (stop_weight * 0.10 * mirror_sign * hop_leg_bone_mul) if k == "kn" else 0.0
		var stop_phi_s: float = (-stop_weight * 0.10 * z_sign * eff_25d) if k == "phi_s" else 0.0
		m_leg_lead[k] = float(leg_lead_d[k]) * w_mul + (stop_kn + stop_phi_s) * m_int
		m_leg_trail[k] = float(leg_trail_d[k]) * w_mul + (stop_kn + stop_phi_s) * m_int

	# Brazos ligeros en flotación de equilibrio
	var arm_flt: float = cfg.hop_arm_float_rad
	var is_frontal: bool = (fam == "s" or fam == "n")
	var m_arm_lead: Dictionary = motion["arm_lead"] as Dictionary
	var m_arm_trail: Dictionary = motion["arm_trail"] as Dictionary
	for role_pair: Array in [[m_arm_lead, 1.0], [m_arm_trail, -1.0]]:
		var m_arm: Dictionary = role_pair[0] as Dictionary
		var r_sign: float = float(role_pair[1])
		var sh_val: float
		var el_val: float
		var wr_val: float
		if is_frontal:
			sh_val = (arm_flt * 0.85 * air_lag * r_sign) * mirror_sign * back_sign * mul_arms
			el_val = (-0.10 - 0.12 * air_lag) * r_sign * mirror_sign * back_sign * mul_arms
			wr_val = (-0.08 * air_lag * r_sign) * mirror_sign * back_sign * mul_arms
		else:
			var alt_a: float = 1.0 + 0.22 * alt_apex * r_sign
			sh_val = (arm_flt * air_lag * alt_a) * mirror_sign * back_sign * mul_arms
			el_val = (-0.14 * air_lag) * mirror_sign * back_sign * mul_arms
			wr_val = (0.09 * cos(hop_u * PI)) * mirror_sign * back_sign * mul_arms
		m_arm["sh"] = sh_val * w_mul + idle_arm_breath * mirror_sign * r_sign
		m_arm["el"] = el_val * w_mul + idle_arm_breath * mirror_sign * 0.6 * r_sign
		m_arm["wr"] = wr_val * w_mul
		m_arm["phi1"] = (0.06 * air_lag * z_sign * mul_25d) * w_mul
		m_arm["phi2"] = (-0.08 * air_lag * z_sign * mul_25d) * w_mul

	# Arrastre del cabello guiado por velocidad balística del salto lunar y asentamiento al aterrizar
	var hair_float_y: float = 0.0
	if air_wave > 0.01:
		hair_float_y = cfg.hop_hair_float_px * cos(flight_u * PI) * w_mul
	elif crouch_wave > 0.01:
		hair_float_y = cfg.hop_hair_float_px * 0.45 * crouch_wave * w_mul
	var hair_drag_x: float = (-2.0 * air_wave * mirror_sign * w_mul) + (-pivot_twist * 14.0)
	motion["hair_jiggle_l"] = Vector2(hair_drag_x, hair_float_y)
	motion["hair_jiggle_r"] = Vector2(hair_drag_x, hair_float_y * 0.92)
	var torso_sec_y: float = (-pelvis_y_hop * 0.10 + (-2.2 * cos(flight_u * PI) if air_wave > 0.01 else 0.0)) * w_mul
	motion["torso_jiggle_l"] = Vector2(-0.25 * mirror_sign * w_mul, torso_sec_y)
	motion["torso_jiggle_r"] = Vector2(-0.25 * mirror_sign * w_mul, torso_sec_y * 0.9)

	return motion


func _eval_leg_cycle(
	phase_raw: float,
	fam: String,
	mirror_sign: float,
	z_sign: float,
	mul_stride: float,
	mul_25d: float,
	cfg: GroundedConfigScript
) -> Dictionary:
	var ph: float = fposmod(phase_raw, TAU)
	# Curva C^∞ de muslo: continua y fluida sin quiebres de derivada
	var fwd_amp: float = cfg.thigh_swing_fwd_rad if cfg != null else 0.25
	var back_amp: float = cfg.thigh_swing_back_rad if cfg != null else 0.21
	var swing_cos: float = cos(ph)
	var mid_th: float = 0.5 * (fwd_amp + back_amp)
	var bias_th: float = 0.5 * (fwd_amp - back_amp)
	var thigh_base: float = -(mid_th * swing_cos + bias_th * 0.5) - 0.10 * mid_th * sin(ph * 2.0)
	var th: float = thigh_base * mirror_sign * mul_stride

	# Curva de rodilla (siempre >= 0 en vista "e") con campanas anchas y fluidas:
	var kn_contact: float = cfg.knee_contact_bend_rad if cfg != null else 0.06
	var kn_down: float = cfg.knee_down_absorb_rad if cfg != null else 0.14
	var kn_pass: float = cfg.knee_pass_bend_rad if cfg != null else 0.38
	var down_bell: float = exp(-0.5 * pow(wrapf(ph - PI * 0.24, -PI, PI) / 0.65, 2.0))
	var pass_bell: float = exp(-0.5 * pow(wrapf(ph - PI * 1.28, -PI, PI) / 0.78, 2.0))
	var kn_mag: float = maxf(0.0, kn_contact * 0.45 + kn_down * down_bell + kn_pass * pass_bell)
	# En S/N no rotamos la rodilla lateralmente tanto; en diagonales 3/4 atenuamos para evitar pose en V
	var kn_fam_atten: float = 0.45 if (fam == "se" or fam == "ne") else 1.0
	var kn: float = kn_mag * mirror_sign * mul_stride * kn_fam_atten

	# Curva de tobillo fluida: dorsiflexión en contacto, empuje plantar suave en push-off
	var an_strike: float = cfg.ankle_strike_rad if cfg != null else -0.08
	var an_push: float = cfg.ankle_push_rad if cfg != null else 0.14
	var strike_bell: float = exp(-0.5 * pow(wrapf(ph, -PI, PI) / 0.55, 2.0))
	var push_bell: float = exp(-0.5 * pow(wrapf(ph - PI * 0.72, -PI, PI) / 0.65, 2.0))
	var an: float = (an_strike * strike_bell + an_push * push_bell) * mirror_sign * mul_stride

	# Escorzo 2.5D real para S/N/SE/NE (en E/W se mantiene sutil para no deformar perfil)
	var p_thigh: float = cfg.leg_25d_phi_thigh_amp if cfg != null else 0.20
	var p_shin: float = cfg.leg_25d_phi_shin_amp if cfg != null else 0.24
	var p_dist: float = cfg.leg_25d_distal_amp if cfg != null else 0.12
	var p_depth: float = cfg.leg_25d_depth_amp if cfg != null else 0.16

	var phi_t: float = swing_cos * p_thigh * z_sign * mul_25d
	var phi_s: float = (-swing_cos * 0.45 * p_shin - pass_bell * p_shin * 0.85) * z_sign * mul_25d
	var dist: float = (-pass_bell * p_dist + strike_bell * p_dist * 0.35) * mul_25d
	var depth: float = swing_cos * p_depth * z_sign * mul_25d
	if fam == "e":
		depth = 0.0

	return {
		"th": th,
		"kn": kn,
		"an": an,
		"phi_t": phi_t,
		"phi_s": phi_s,
		"dist": dist,
		"depth": depth,
	}


func _eval_arm_cycle(
	phase_raw: float,
	fam: String,
	role_sign: float,
	mirror_sign: float,
	back_sign: float,
	z_sign: float,
	mul_arms: float,
	mul_25d: float,
	cfg: GroundedConfigScript
) -> Dictionary:
	var ph: float = fposmod(phase_raw, TAU)
	var swing_cos: float = cos(ph)
	var sh_cos: float = cos(ph - 0.15)
	var sh_fwd: float = cfg.arm_shoulder_fwd_rad if cfg != null else 0.18
	var sh_back: float = cfg.arm_shoulder_back_rad if cfg != null else 0.15
	var mid_sh: float = 0.5 * (sh_fwd + sh_back)
	var bias_sh: float = 0.5 * (sh_fwd - sh_back)
	var sh_base: float = -(mid_sh * sh_cos + bias_sh * 0.5)
	var sh: float = sh_base * mirror_sign * back_sign * mul_arms

	# Codo con retardo de cadena orgánico (ph - 0.35) y simetría bilateral en S/N
	var el_base: float = cfg.arm_elbow_base_rad if cfg != null else -0.20
	var el_sw: float = cfg.arm_elbow_swing_rad if cfg != null else 0.14
	var fwd_01: float = 0.5 + 0.5 * cos(ph - 0.35)
	var el_sym: float = role_sign if (fam == "s" or fam == "n") else 1.0
	var el: float = (el_base * 0.55 - el_sw * fwd_01) * mirror_sign * back_sign * mul_arms * el_sym

	var wr_lag: float = cfg.arm_wrist_lag_rad if cfg != null else 0.08
	var wr: float = -sin(ph - 0.70) * wr_lag * mirror_sign * back_sign * mul_arms * el_sym

	var a_p1: float = cfg.arm_25d_phi1_amp if cfg != null else 0.14
	var a_p2: float = cfg.arm_25d_phi2_amp if cfg != null else 0.16
	var phi1: float = swing_cos * a_p1 * z_sign * mul_25d
	var phi2: float = (-0.5 - 0.5 * cos(ph - 0.30)) * a_p2 * z_sign * mul_25d

	return {
		"sh": sh,
		"el": el,
		"wr": wr,
		"phi1": phi1,
		"phi2": phi2,
	}


func apply_to_rig(
	rig: PlanarCombatRig,
	base_evaluator: BasePoseEvaluatorScript,
	cfg: GroundedConfigScript,
	layer_mode: int,
	pose_scale: float = 1.0,
	all_views: bool = false,
	turn_cfg: TurnAnimConfigScript = null,
	turn_state: Dictionary = {},
	jiggle_cfg: JigglePhysicsConfigScript = null,
	forced_phase: float = -1.0,
	forced_walk_blend: float = -1.0
) -> void:
	if rig == null or base_evaluator == null:
		return
	if cfg != null:
		cfg.ensure_initialized()

	if all_views:
		var views: Dictionary = rig.get_views()
		for v_key: String in views.keys():
			var fam: String = BasePoseConfigScript.canonical_family_for_view(v_key)
			var fam_dict: Dictionary = cfg.get_standing_family(fam) if cfg != null else {}
			var motion: Dictionary = evaluate_motion_for_view(v_key, cfg, pose_scale, forced_phase, forced_walk_blend)
			base_evaluator.apply_composed_pose_to_view(
				rig, v_key, fam_dict, motion, layer_mode, pose_scale,
				turn_cfg, turn_state, jiggle_cfg, false, idle_time, null
			)
	else:
		var active_vk: String = rig.get_active_view_key()
		var fam_act: String = BasePoseConfigScript.canonical_family_for_view(active_vk)
		var fam_dict_act: Dictionary = cfg.get_standing_family(fam_act) if cfg != null else {}
		var motion_act: Dictionary = evaluate_motion_for_view(active_vk, cfg, pose_scale, forced_phase, forced_walk_blend)
		base_evaluator.apply_composed_pose_to_view(
			rig, active_vk, fam_dict_act, motion_act, layer_mode, pose_scale,
			turn_cfg, turn_state, jiggle_cfg, false, idle_time, null
		)

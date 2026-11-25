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
	var stride_m: float = maxf(cfg.stride_length_m if cfg != null else 2.05, 0.40)
	var eff_disp_m: float = world_displacement_m
	if eff_disp_m < 0.0:
		var fallback_spd_m: float = (cfg.hub_move_speed if cfg != null else 6.8) * spd
		eff_disp_m = fallback_spd_m * dt

	var phase_step: float = (eff_disp_m / stride_m) * TAU
	var prev_phase: float = gait_phase
	var next_phase: float = prev_phase + phase_step

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
		next_phase = lerpf(gait_phase, nearest_half, 1.0 - exp(-5.0 * dt))

	gait_phase = fposmod(next_phase, TAU)

	# Altura normalizada de la pelvis en el ciclo (0 en contacto/absorción, 1 en passing/impulso)
	var lift_wave: float = 0.5 - 0.5 * cos(gait_phase * 2.0 - 0.45)
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

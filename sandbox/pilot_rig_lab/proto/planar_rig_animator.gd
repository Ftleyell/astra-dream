class_name PlanarRigAnimator
extends RefCounted
## Máquina de estados de animación procedural expresiva sobre Skeleton2D + piezas con underlap.
## Combina estados (Idle/Hover, Strafe, Ascend, Descend, Backpedal/Focus, Dash)
## con amortiguación suave por articulación y foreshortening 2.5D sutil.

const AnimConfigScript = preload("res://sandbox/pilot_rig_lab/proto/planar_rig_anim_config.gd")

enum AnimState {
	IDLE_HOVER,
	FLIGHT_STRAFE,
	ASCEND,
	DESCEND,
	BACKPEDAL_FOCUS,
	DASH_BOOST,
}

const ANIM_BONES: Array[String] = [
	"Pelvis", "Waist", "Chest", "Neck",
	"Shoulder_R", "Elbow_R", "Wrist_R",
	"Shoulder_L", "Elbow_L", "Wrist_L",
	"Thigh_R", "Knee_R", "Ankle_R",
	"Thigh_L", "Knee_L", "Ankle_L",
]

var config: AnimConfigScript = null
var _active_state: AnimState = AnimState.IDLE_HOVER
var _current_offsets: Dictionary = {}
var _offset_vels: Dictionary = {}
var _current_scale: Vector2 = Vector2.ONE
var _scale_vel: Vector2 = Vector2.ZERO
var _bank_vel: float = 0.0
var _hover_x: float = 0.0
var _hover_x_vel: float = 0.0
var _hover_y: float = 0.0
var _hover_vel: float = 0.0
var _whiplash_torso: float = 0.0
var _whiplash_limb_lead: float = 0.0
var _whiplash_limb_trail: float = 0.0

# Capas aditivas de locomoción y combate
var _launch_timer: float = 0.0
var _launch_duration: float = 0.18
var _launch_dir_x: float = 0.0

var _air_brake_timer: float = 0.0
var _air_brake_duration: float = 0.24
var _air_brake_dir_x: float = 0.0

var _dash_burst_timer: float = 0.0
var _dash_burst_duration: float = 0.22
var _dash_burst_dir_x: float = 0.0

var _attack_recoil_timer: float = 0.0
var _attack_recoil_duration: float = 0.16
var _attack_recoil_strength: float = 1.0
var _attack_recoil_dir_x: float = 1.0

var _hit_react_timer: float = 0.0
var _hit_react_duration: float = 0.24
var _hit_react_strength: float = 1.0
var _hit_react_dir_x: float = 1.0


static func step_spring(x: float, v: float, target: float, freq: float, zeta: float, dt: float) -> Vector2:
	if dt <= 0.0:
		return Vector2(x, v)
	var steps: int = maxi(1, int(ceil(dt / 0.012)))
	var h: float = dt / float(steps)
	var w: float = maxf(freq, 0.1)
	var k: float = w * w
	var d: float = 2.0 * maxf(zeta, 0.05) * w
	var pos: float = x
	var vel: float = v
	for _i: int in range(steps):
		var acc: float = (target - pos) * k - vel * d
		vel += acc * h
		pos += vel * h
	return Vector2(pos, vel)


func _init(anim_config: AnimConfigScript = null) -> void:
	config = anim_config if anim_config != null else AnimConfigScript.new()
	reset()


func reset() -> void:
	_active_state = AnimState.IDLE_HOVER
	_current_scale = Vector2.ONE
	_scale_vel = Vector2.ZERO
	_bank_vel = 0.0
	_hover_x = 0.0
	_hover_x_vel = 0.0
	_hover_y = 0.0
	_hover_vel = 0.0
	_whiplash_torso = 0.0
	_whiplash_limb_lead = 0.0
	_whiplash_limb_trail = 0.0
	_launch_timer = 0.0
	_air_brake_timer = 0.0
	_dash_burst_timer = 0.0
	_attack_recoil_timer = 0.0
	_hit_react_timer = 0.0
	for b_name: String in ANIM_BONES:
		_current_offsets[b_name] = 0.0
		_offset_vels[b_name] = 0.0


func set_whiplash_offsets(torso: float, limb_lead: float, limb_trail: float) -> void:
	_whiplash_torso = clampf(torso, -1.5, 1.5)
	_whiplash_limb_lead = clampf(limb_lead, -1.5, 1.5)
	_whiplash_limb_trail = clampf(limb_trail, -1.5, 1.5)


func reset_view_materials(_views: Dictionary) -> void:
	pass


func get_active_state() -> AnimState:
	return _active_state


func get_active_state_name() -> String:
	match _active_state:
		AnimState.IDLE_HOVER:
			return "IDLE_HOVER"
		AnimState.FLIGHT_STRAFE:
			return "FLIGHT_STRAFE"
		AnimState.ASCEND:
			return "ASCEND"
		AnimState.DESCEND:
			return "DESCEND"
		AnimState.BACKPEDAL_FOCUS:
			return "BACKPEDAL_FOCUS"
		AnimState.DASH_BOOST:
			return "DASH_BOOST"
	return "IDLE_HOVER"


func get_foreshorten_scale() -> Vector2:
	return _current_scale


func get_rotated_neck_rel(neck_rel: Vector2, _waist_piv: Vector2, body_flip_x: bool) -> Vector2:
	return Vector2(-neck_rel.x if body_flip_x else neck_rel.x, neck_rel.y)


func trigger_launch(dir: Vector2) -> void:
	var cfg: AnimConfigScript = config if config != null else AnimConfigScript.new()
	_launch_duration = maxf(cfg.launch_duration_sec, 0.05)
	_launch_timer = _launch_duration
	_launch_dir_x = dir.x if absf(dir.x) > 0.05 else 1.0


func trigger_air_brake(dir: Vector2) -> void:
	var cfg: AnimConfigScript = config if config != null else AnimConfigScript.new()
	_air_brake_duration = maxf(cfg.air_brake_duration_sec, 0.05)
	_air_brake_timer = _air_brake_duration
	_air_brake_dir_x = dir.x if absf(dir.x) > 0.05 else 1.0


func trigger_dash_burst(dir: Vector2) -> void:
	var cfg: AnimConfigScript = config if config != null else AnimConfigScript.new()
	_dash_burst_duration = maxf(cfg.dash_burst_duration_sec, 0.05)
	_dash_burst_timer = _dash_burst_duration
	_dash_burst_dir_x = dir.x if absf(dir.x) > 0.05 else 1.0


func trigger_attack_recoil(aim_dir: Vector2, strength: float = 1.0) -> void:
	var cfg: AnimConfigScript = config if config != null else AnimConfigScript.new()
	_attack_recoil_duration = maxf(cfg.attack_recoil_duration_sec, 0.05)
	_attack_recoil_timer = _attack_recoil_duration
	_attack_recoil_strength = clampf(strength, 0.1, 2.0)
	_attack_recoil_dir_x = -1.0 if aim_dir.x < -0.05 else 1.0


func trigger_hit_react(hit_dir: Vector2, strength: float = 1.0) -> void:
	var cfg: AnimConfigScript = config if config != null else AnimConfigScript.new()
	_hit_react_duration = maxf(cfg.hit_react_duration_sec, 0.05)
	_hit_react_timer = _hit_react_duration
	_hit_react_strength = clampf(strength, 0.1, 2.0)
	_hit_react_dir_x = -1.0 if hit_dir.x < -0.05 else 1.0


func is_launch_active() -> bool:
	return _launch_timer > 0.0


func is_air_brake_active() -> bool:
	return _air_brake_timer > 0.0


func is_dash_burst_active() -> bool:
	return _dash_burst_timer > 0.0


func is_attack_recoil_active() -> bool:
	return _attack_recoil_timer > 0.0


func is_hit_react_active() -> bool:
	return _hit_react_timer > 0.0


func get_active_additive_summary() -> String:
	var parts: Array[String] = []
	if _launch_timer > 0.0:
		parts.append("LAUNCH")
	if _air_brake_timer > 0.0:
		parts.append("BRAKE")
	if _dash_burst_timer > 0.0:
		parts.append("DASH")
	if _attack_recoil_timer > 0.0:
		parts.append("RECOIL")
	if _hit_react_timer > 0.0:
		parts.append("HIT")
	return "+".join(parts) if not parts.is_empty() else "NONE"


func get_bone_limit_for_view(v_key: String, b_name: String) -> Vector2:
	var cfg: AnimConfigScript = config if config != null else AnimConfigScript.new()
	return _get_bone_limits(v_key, b_name, cfg)


func _get_bone_limits(v_key: String, b_name: String, cfg: AnimConfigScript) -> Vector2:
	if v_key == "n":
		match b_name:
			"Shoulder_R": return cfg.n_shoulder_r_limits
			"Shoulder_L": return cfg.n_shoulder_l_limits
			"Elbow_R": return cfg.n_elbow_r_limits
			"Elbow_L": return cfg.n_elbow_l_limits
			"Wrist_R": return cfg.n_wrist_r_limits
			"Wrist_L": return cfg.n_wrist_l_limits
			"Thigh_R", "Thigh_L": return cfg.n_thigh_limits
			"Knee_R", "Knee_L": return cfg.n_knee_limits
			"Ankle_R", "Ankle_L": return cfg.n_ankle_limits
	else:
		match b_name:
			"Shoulder_R": return cfg.s_shoulder_r_limits
			"Shoulder_L": return cfg.s_shoulder_l_limits
			"Elbow_R": return cfg.s_elbow_r_limits
			"Elbow_L": return cfg.s_elbow_l_limits
			"Wrist_R": return cfg.s_wrist_r_limits
			"Wrist_L": return cfg.s_wrist_l_limits
			"Thigh_R", "Thigh_L": return cfg.s_thigh_limits
			"Knee_R", "Knee_L": return cfg.s_knee_limits
			"Ankle_R", "Ankle_L": return cfg.s_ankle_limits
	return Vector2(-0.55, 0.55)


func _eval_asymmetric_breath(phase: float, asymmetry: float) -> float:
	var s: float = sin(phase)
	var skew: float = sin(phase * 2.0) * asymmetry * 0.25
	return clampf(s + skew, -1.15, 1.15)


func _eval_punch_envelope(timer: float, duration: float) -> float:
	if timer <= 0.0 or duration <= 0.0:
		return 0.0
	var p: float = clampf(1.0 - (timer / duration), 0.0, 1.0)
	# Fast attack (0..0.22), smooth damped settle (0.22..1.0)
	if p < 0.22:
		return sin((p / 0.22) * PI * 0.5)
	var u: float = (p - 0.22) / 0.78
	return (1.0 - u) * exp(-2.2 * u)


func update_and_apply(
	delta: float,
	body_pivot: Node2D,
	views: Dictionary,
	flight_phase: float,
	smooth_move_dir: Vector2,
	smooth_speed: float,
	is_backpedaling: bool,
	body_flip_x: bool,
	turn_bone_kick: float,
	shoulder_look_twist: float,
	active_view_key: String = "s",
	smooth_aim_dir: Vector2 = Vector2.RIGHT
) -> void:
	if body_pivot == null:
		return

	var cfg: AnimConfigScript = config if config != null else AnimConfigScript.new()
	_launch_timer = maxf(0.0, _launch_timer - delta)
	_air_brake_timer = maxf(0.0, _air_brake_timer - delta)
	_dash_burst_timer = maxf(0.0, _dash_burst_timer - delta)
	_attack_recoil_timer = maxf(0.0, _attack_recoil_timer - delta)
	_hit_react_timer = maxf(0.0, _hit_react_timer - delta)

	var launch_w: float = _eval_punch_envelope(_launch_timer, _launch_duration)
	var brake_w: float = _eval_punch_envelope(_air_brake_timer, _air_brake_duration)
	var dash_burst_w: float = _eval_punch_envelope(_dash_burst_timer, _dash_burst_duration)
	var recoil_w: float = _eval_punch_envelope(_attack_recoil_timer, _attack_recoil_duration) * _attack_recoil_strength
	var hit_w: float = _eval_punch_envelope(_hit_react_timer, _hit_react_duration) * _hit_react_strength

	var is_dashing: bool = smooth_speed > 1.05 or dash_burst_w > 0.15
	var move_weight: float = clampf(smooth_speed, 0.0, 1.0)
	var dash_w: float = maxf(
		clampf((smooth_speed - 1.0) * 2.2, 0.0, 1.0) if smooth_speed > 1.05 else 0.0,
		dash_burst_w
	)
	var back_w: float = move_weight if is_backpedaling else 0.0
	var up_w: float = clampf(-smooth_move_dir.y, 0.0, 1.0) * move_weight
	var down_w: float = clampf(smooth_move_dir.y, 0.0, 1.0) * move_weight
	var strafe_w: float = clampf(absf(smooth_move_dir.x), 0.0, 1.0) * move_weight
	var idle_w: float = clampf(1.0 - move_weight, 0.0, 1.0)

	_active_state = _resolve_dominant_state(
		is_dashing, is_backpedaling, move_weight, up_w, down_w, strafe_w
	)

	var lean_sign: float = -1.0 if body_flip_x else 1.0
	var additive_bank: float = (
		_launch_dir_x * cfg.launch_lean_rad * 0.45 * launch_w
		+ _air_brake_dir_x * cfg.air_brake_lean_rad * 0.65 * brake_w
		- _hit_react_dir_x * cfg.hit_react_crunch_rad * 0.35 * hit_w
	)
	var bank_target: float = clampf(
		smooth_move_dir.x * cfg.max_bank_rad * (0.25 + 0.75 * clampf(smooth_speed, 0.0, 1.25)) + additive_bank,
		-cfg.max_bank_rad * 1.35,
		cfg.max_bank_rad * 1.35
	)
	var bank_res: Vector2 = step_spring(body_pivot.rotation, _bank_vel, bank_target, cfg.bank_stiffness, cfg.bank_damping, delta)
	body_pivot.rotation = bank_res.x
	_bank_vel = bank_res.y

	var target_hover_x: float = -smooth_move_dir.x * cfg.bank_lateral_inertia_px * clampf(smooth_speed, 0.0, 1.25)
	var hover_x_res: Vector2 = step_spring(_hover_x, _hover_x_vel, target_hover_x, cfg.bank_stiffness, cfg.bank_damping, delta)
	_hover_x = hover_x_res.x
	_hover_x_vel = hover_x_res.y
	body_pivot.position.x = _hover_x

	var breath: float = _eval_asymmetric_breath(flight_phase * 0.75, cfg.breath_asymmetry)
	var micro_pulse: float = _eval_asymmetric_breath(flight_phase * 1.5, cfg.breath_asymmetry * 0.5)
	var bob_amp: float = lerpf(cfg.hover_bob_idle_px, cfg.hover_bob_move_px, move_weight) * (1.0 - 0.55 * dash_w)
	var target_bob_y: float = breath * bob_amp - down_w * cfg.descend_drop_px + up_w * cfg.ascend_lift_px + hit_w * 4.0
	var hover_res: Vector2 = step_spring(_hover_y, _hover_vel, target_bob_y, cfg.hover_stiffness, cfg.hover_damping, delta)
	_hover_y = hover_res.x
	_hover_vel = hover_res.y
	body_pivot.position.y = _hover_y

	var target_scale: Vector2 = Vector2.ONE
	target_scale = target_scale.lerp(cfg.ascend_scale, up_w * (1.0 - dash_w))
	target_scale = target_scale.lerp(cfg.descend_scale, down_w * (1.0 - dash_w))
	target_scale = target_scale.lerp(cfg.dash_scale, dash_w)
	if launch_w > 0.001:
		target_scale = target_scale.lerp(cfg.launch_scale, clampf(launch_w, 0.0, 1.0))
	if brake_w > 0.001:
		target_scale = target_scale.lerp(cfg.air_brake_scale, clampf(brake_w, 0.0, 1.0))
	if dash_burst_w > 0.001:
		target_scale = target_scale.lerp(cfg.dash_burst_scale, clampf(dash_burst_w, 0.0, 1.0))
	if recoil_w > 0.001:
		target_scale = target_scale.lerp(cfg.attack_recoil_scale, clampf(recoil_w, 0.0, 1.0))
	if hit_w > 0.001:
		target_scale = target_scale.lerp(cfg.hit_react_scale, clampf(hit_w, 0.0, 1.0))

	var sx_res: Vector2 = step_spring(_current_scale.x, _scale_vel.x, target_scale.x, cfg.scale_stiffness, cfg.scale_damping, delta)
	var sy_res: Vector2 = step_spring(_current_scale.y, _scale_vel.y, target_scale.y, cfg.scale_stiffness, cfg.scale_damping, delta)
	_current_scale = Vector2(sx_res.x, sy_res.x)
	_scale_vel = Vector2(sx_res.y, sy_res.y)

	var lat_input: float = clampf(smooth_move_dir.x * lean_sign * clampf(smooth_speed, 0.0, 1.2), -1.2, 1.2)
	var kick: float = turn_bone_kick * lean_sign
	var look_twist: float = shoulder_look_twist * lean_sign
	var back_mul: float = -0.65 if is_backpedaling else 1.0
	var thrust_kick: float = micro_pulse * (0.04 + 0.14 * move_weight) * back_mul

	# Overlapping action: torso lidera, brazos/cabeza/piernas siguen con desfase real
	var head_breath: float = _eval_asymmetric_breath(flight_phase * 0.75 - cfg.phase_lag_head, cfg.breath_asymmetry)
	var arm_sway: float = _eval_asymmetric_breath(flight_phase * 0.95 - cfg.phase_lag_arms, cfg.breath_asymmetry * 0.4)
	var wrist_wave: float = _eval_asymmetric_breath(flight_phase * 0.95 - cfg.phase_lag_wrists, cfg.breath_asymmetry * 0.3)
	var leg_float: float = _eval_asymmetric_breath(flight_phase * 0.85 - cfg.phase_lag_legs, cfg.breath_asymmetry * 0.4)
	var ankle_wave: float = _eval_asymmetric_breath(flight_phase * 0.85 - cfg.phase_lag_ankles, cfg.breath_asymmetry * 0.3)

	var n_view_w: float = 1.0 if active_view_key == "n" else 0.0
	var targets: Dictionary = {}
	var torso_add: float = (
		cfg.launch_lean_rad * launch_w * 0.5
		+ cfg.air_brake_lean_rad * brake_w * 0.55
		+ cfg.attack_recoil_chest_rad * recoil_w * 0.45
		+ cfg.hit_react_crunch_rad * hit_w * 0.65
	)
	targets["Pelvis"] = lat_input * (cfg.strafe_waist_lean * 0.45) + kick * (cfg.turn_kick_waist_mul * 0.55) + torso_add * 0.4 + cfg.idle_pelvis_tilt_rad * idle_w
	targets["Waist"] = lat_input * cfg.strafe_waist_lean + kick * cfg.turn_kick_waist_mul + breath * 0.024 - down_w * 0.03 + torso_add * 0.75 + cfg.idle_waist_counter_rad * idle_w
	targets["Chest"] = (
		lat_input * cfg.strafe_chest_lean
		+ kick * cfg.turn_kick_chest_mul
		+ look_twist * cfg.aim_twist_chest_mul
		+ breath * 0.028
		+ down_w * 0.035
		+ cfg.idle_chest_counter_rad * idle_w
		+ cfg.n_view_chest_lean * n_view_w
		+ cfg.attack_recoil_chest_rad * recoil_w
		+ cfg.hit_react_crunch_rad * hit_w
		+ cfg.air_brake_lean_rad * brake_w * 0.6
		+ cfg.launch_lean_rad * launch_w * 0.55
	)
	targets["Neck"] = (
		lat_input * cfg.strafe_neck_counter
		+ kick * cfg.turn_kick_neck_mul
		+ look_twist * cfg.aim_twist_neck_mul
		+ head_breath * 0.02
		- cfg.hit_react_crunch_rad * hit_w * 0.65
		- cfg.attack_recoil_chest_rad * recoil_w * 0.45
	)

	# Brazos: 100% conectados a PlanarRigAnimConfig + capas aditivas
	var sh_base: float = (
		cfg.idle_shoulder_flare * idle_w
		+ cfg.strafe_shoulder_sweep * strafe_w * 0.55
		+ cfg.descend_arm_flare * down_w
		+ cfg.backpedal_arm_tuck * back_w
		+ cfg.dash_arm_sweep * dash_w
		+ cfg.air_brake_arm_flare * brake_w
		+ cfg.dash_burst_arm_sweep * dash_burst_w * 0.55
		+ cfg.hit_react_arm_flinch * hit_w
	)
	var arm_calm: float = 1.0 - 0.55 * back_w
	var sh_asym: float = lat_input * (cfg.strafe_shoulder_sweep * 0.30) + kick * 0.05 + arm_sway * (cfg.idle_shoulder_flare * 0.40) * arm_calm
	var recoil_arm: float = cfg.attack_recoil_arm_kick * recoil_w
	var aim_arm_w: float = maxf(back_w, clampf(recoil_w, 0.0, 1.0))
	var aim_arm_track: float = clampf(-smooth_aim_dir.y, -1.0, 1.0) * cfg.aim_arm_track_strength * aim_arm_w
	targets["Shoulder_R"] = sh_base * 1.05 + sh_asym + breath * 0.020 - recoil_arm * 0.65 + cfg.n_view_shoulder_open * n_view_w + aim_arm_track
	targets["Shoulder_L"] = -sh_base * 0.85 + sh_asym - breath * 0.018 + recoil_arm * 0.30 - cfg.n_view_shoulder_open * n_view_w

	var el_base: float = (
		cfg.idle_elbow_bend * idle_w
		+ cfg.descend_elbow_bend * down_w
		+ cfg.backpedal_elbow_bend * back_w
		+ cfg.dash_elbow_bend * dash_w
		+ cfg.air_brake_arm_flare * 0.45 * brake_w
		+ cfg.hit_react_arm_flinch * 0.45 * hit_w
	)
	var el_swing: float = arm_sway * (cfg.idle_elbow_bend * 0.38 * idle_w + 0.035 * move_weight) * arm_calm
	targets["Elbow_R"] = el_base * 1.10 + lat_input * 0.035 + el_swing - recoil_arm * 0.75 + cfg.n_view_elbow_open * n_view_w + aim_arm_track * 0.85
	targets["Elbow_L"] = -el_base * 0.82 + lat_input * 0.030 - el_swing * 0.85 + recoil_arm * 0.35 - cfg.n_view_elbow_open * n_view_w

	var wr_amp: float = (cfg.idle_wrist_float * idle_w + 0.04 * move_weight) * arm_calm
	targets["Wrist_R"] = wrist_wave * wr_amp + lat_input * 0.035 + down_w * 0.035 - up_w * 0.03 - recoil_arm * 0.45
	targets["Wrist_L"] = -wrist_wave * (wr_amp * 0.85) + lat_input * 0.03 - down_w * 0.03 + up_w * 0.025 + hit_w * 0.10

	# Piernas: 100% conectadas a PlanarRigAnimConfig + capas aditivas
	var th_swing: float = leg_float * (cfg.idle_thigh_asym * 0.65 * idle_w + cfg.strafe_thigh_swing * 0.35 * strafe_w)
	targets["Thigh_R"] = (
		-cfg.idle_thigh_asym * idle_w
		+ th_swing
		+ thrust_kick * 0.14
		- lat_input * (cfg.strafe_thigh_swing * 0.45)
		- down_w * cfg.descend_thigh_tuck
		+ up_w * (-cfg.ascend_thigh_trail)
		+ dash_w * cfg.dash_thigh_sweep
		- brake_w * cfg.air_brake_knee_brace * 0.55
		- launch_w * cfg.launch_lean_rad * 0.45
		+ hit_w * 0.14
		+ kick * 0.07
	)
	targets["Thigh_L"] = (
		cfg.idle_thigh_asym * idle_w
		- th_swing
		- thrust_kick * 0.14
		- lat_input * (cfg.strafe_thigh_swing * 0.40)
		+ down_w * (cfg.descend_thigh_tuck * 0.75)
		- up_w * (-cfg.ascend_thigh_trail)
		- dash_w * (cfg.dash_thigh_sweep * 0.85)
		+ brake_w * cfg.air_brake_knee_brace * 0.45
		+ launch_w * cfg.launch_lean_rad * 0.35
		- hit_w * 0.10
		- kick * 0.07
	)
	targets["Knee_R"] = (
		(cfg.idle_knee_asym + cfg.idle_knee_asym_diff * 0.5) * idle_w
		+ maxf(0.0, -thrust_kick) * cfg.strafe_knee_trail
		+ down_w * cfg.descend_knee_tuck
		+ back_w * cfg.backpedal_knee_brace
		+ dash_w * cfg.dash_knee_sweep
		+ brake_w * cfg.air_brake_knee_brace
		+ hit_w * 0.20
		+ leg_float * 0.05
	)
	targets["Knee_L"] = (
		(cfg.idle_knee_asym - cfg.idle_knee_asym_diff * 0.5) * idle_w
		+ maxf(0.0, thrust_kick) * cfg.strafe_knee_trail
		+ down_w * (cfg.descend_knee_tuck * 0.82)
		+ back_w * (cfg.backpedal_knee_brace * 0.88)
		+ dash_w * (cfg.dash_knee_sweep * 0.85)
		+ brake_w * (cfg.air_brake_knee_brace * 0.85)
		+ hit_w * 0.16
		- leg_float * 0.05
	)
	targets["Ankle_R"] = (
		cfg.idle_ankle_point * 0.85 * idle_w
		+ ankle_wave * (cfg.idle_ankle_point * 0.75 * idle_w + 0.10 * move_weight)
		+ up_w * cfg.ascend_ankle_point
		+ down_w * cfg.descend_ankle_tuck
		+ dash_w * 0.14
		- brake_w * 0.12
	)
	targets["Ankle_L"] = (
		cfg.idle_ankle_point * 1.25 * idle_w
		- ankle_wave * (cfg.idle_ankle_point * 0.75 * idle_w + 0.10 * move_weight)
		+ up_w * (cfg.ascend_ankle_point * 1.05)
		+ down_w * cfg.descend_ankle_tuck
		+ dash_w * 0.14
		- brake_w * 0.12
	)

	var whiplash_add: Dictionary = _build_whiplash_bone_offsets(lean_sign)
	for b_name: String in ANIM_BONES:
		var cur: float = float(_current_offsets.get(b_name, 0.0))
		var vel: float = float(_offset_vels.get(b_name, 0.0))
		var tgt: float = float(targets.get(b_name, 0.0))
		var sp_res: Vector2 = step_spring(cur, vel, tgt, cfg.joint_stiffness, cfg.joint_damping, delta)
		_current_offsets[b_name] = sp_res.x
		_offset_vels[b_name] = sp_res.y

	for v_key: String in views.keys():
		var vd: Dictionary = views[v_key] as Dictionary
		if not (vd["root"] as Node2D).visible:
			continue
		var bones: Dictionary = vd["bones"] as Dictionary
		var rest_rots: Dictionary = vd["rest_rots"] as Dictionary
		for b_name: String in ANIM_BONES:
			if bones.has(b_name):
				var bone: Bone2D = bones[b_name] as Bone2D
				var rot_delta: float = float(_current_offsets[b_name]) + float(whiplash_add.get(b_name, 0.0))
				var lim: Vector2 = _get_bone_limits(v_key, b_name, cfg)
				rot_delta = clampf(rot_delta, lim.x, lim.y)
				bone.rotation = float(rest_rots.get(b_name, 0.0)) + rot_delta


func _build_whiplash_bone_offsets(lean_sign: float) -> Dictionary:
	if absf(_whiplash_torso) < 0.001 and absf(_whiplash_limb_lead) < 0.001 and absf(_whiplash_limb_trail) < 0.001:
		return {}
	var tw: float = _whiplash_torso * lean_sign
	var lw: float = _whiplash_limb_lead * lean_sign
	var rw: float = _whiplash_limb_trail * lean_sign
	return {
		"Waist": clampf(tw * 0.08, -0.14, 0.14),
		"Chest": clampf(tw * 0.11, -0.18, 0.18),
		"Neck": clampf(-tw * 0.06, -0.12, 0.12),
		"Shoulder_R": clampf(lw * 0.14, -0.18, 0.18),
		"Elbow_R": clampf(lw * 0.12, -0.16, 0.16),
		"Wrist_R": clampf(lw * 0.06, -0.09, 0.09),
		"Shoulder_L": clampf(rw * 0.13, -0.18, 0.18),
		"Elbow_L": clampf(rw * 0.12, -0.16, 0.16),
		"Wrist_L": clampf(rw * 0.06, -0.09, 0.09),
		"Thigh_R": clampf(-lw * 0.14, -0.22, 0.22),
		"Knee_R": clampf(absf(lw) * 0.15, 0.0, 0.22),
		"Ankle_R": clampf(lw * 0.12, -0.18, 0.18),
		"Thigh_L": clampf(-rw * 0.12, -0.22, 0.22),
		"Knee_L": clampf(absf(rw) * 0.14, 0.0, 0.22),
		"Ankle_L": clampf(rw * 0.12, -0.18, 0.18),
	}


func _resolve_dominant_state(
	is_dashing: bool,
	is_backpedaling: bool,
	move_weight: float,
	up_w: float,
	down_w: float,
	strafe_w: float
) -> AnimState:
	if is_dashing:
		return AnimState.DASH_BOOST
	if move_weight < 0.15:
		return AnimState.IDLE_HOVER
	if is_backpedaling:
		return AnimState.BACKPEDAL_FOCUS
	if down_w > strafe_w and down_w > up_w and down_w > 0.25:
		return AnimState.DESCEND
	if up_w > strafe_w and up_w > down_w and up_w > 0.25:
		return AnimState.ASCEND
	return AnimState.FLIGHT_STRAFE

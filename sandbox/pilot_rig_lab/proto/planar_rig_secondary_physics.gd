class_name PlanarRigSecondaryPhysics
extends RefCounted
## Física secundaria 2D para PlanarCombatRig:
## - Whiplash de extremidades/torso en giros rápidos (anticipo + latigazo elástico).
## - Resortes 2D de inercia/drag para busto y cabello reactivo.

const AnimConfigScript = preload("res://sandbox/pilot_rig_lab/proto/planar_rig_anim_config.gd")

var whiplash_active: bool = false
var whiplash_t: float = 1.0
var whiplash_dir: float = 1.0
var whiplash_wing_kick: float = 0.0

var jiggle_active: bool = false
var jiggle_t: float = 1.0
var jiggle_dir: float = 1.0
var jiggle_pos_l: Vector2 = Vector2.ZERO
var jiggle_vel_l: Vector2 = Vector2.ZERO
var jiggle_pos_r: Vector2 = Vector2.ZERO
var jiggle_vel_r: Vector2 = Vector2.ZERO
var hair_jiggle_pos: Vector2 = Vector2.ZERO
var hair_jiggle_vel: Vector2 = Vector2.ZERO
var _prev_hair_aim_dir: Vector2 = Vector2.DOWN
var _prev_jiggle_vel_world: Vector2 = Vector2.ZERO


func reset(smooth_aim_dir: Vector2) -> void:
	whiplash_active = false
	whiplash_t = 1.0
	whiplash_wing_kick = 0.0
	jiggle_active = false
	jiggle_t = 1.0
	jiggle_pos_l = Vector2.ZERO
	jiggle_vel_l = Vector2.ZERO
	jiggle_pos_r = Vector2.ZERO
	jiggle_vel_r = Vector2.ZERO
	hair_jiggle_pos = Vector2.ZERO
	hair_jiggle_vel = Vector2.ZERO
	_prev_hair_aim_dir = smooth_aim_dir
	_prev_jiggle_vel_world = Vector2.ZERO


func trigger_snap_impulse(turn_dir: float) -> void:
	whiplash_active = true
	whiplash_t = 0.0
	whiplash_dir = turn_dir
	jiggle_active = true
	jiggle_t = 0.0
	jiggle_dir = turn_dir


func trigger_impulse(kick_vel: Vector2, hair_kick_vel: Vector2 = Vector2.ZERO) -> void:
	jiggle_vel_l += kick_vel
	jiggle_vel_r += kick_vel * 0.94
	hair_jiggle_vel += hair_kick_vel if hair_kick_vel != Vector2.ZERO else kick_vel * 1.15


func _eval_whiplash_sample(t: float) -> float:
	var split_t: float = 0.24
	if t <= 0.0 or t >= 1.0:
		return 0.0
	if t < split_t:
		var p: float = t / split_t
		return sin(p * PI * 0.5) * 0.68
	var u: float = (t - split_t) / (1.0 - split_t)
	return -cos(u * PI * 2.25) * exp(-3.3 * u) * (1.0 - u)


func update(
	delta: float,
	static_inspect: bool,
	animator: PlanarRigAnimator,
	views: Dictionary,
	head_data: Dictionary,
	flight_phase: float,
	move_dir: Vector2,
	speed_norm: float,
	smooth_move_dir: Vector2,
	smooth_speed: float,
	smooth_aim_dir: Vector2,
	body_flip_x: bool,
	head_flip_x: bool,
	head_under_data: Dictionary = {}
) -> void:
	var cfg: AnimConfigScript = animator.config if (animator != null and animator.config != null) else AnimConfigScript.new()
	_apply_secondary_jiggle(
		delta, static_inspect, cfg, views, head_data, flight_phase,
		move_dir, speed_norm, smooth_move_dir, smooth_speed,
		smooth_aim_dir, body_flip_x, head_flip_x, head_under_data
	)
	if not whiplash_active or animator == null:
		whiplash_wing_kick = 0.0
		if animator != null:
			animator.set_whiplash_offsets(0.0, 0.0, 0.0)
		return
	whiplash_t += delta / maxf(cfg.whiplash_duration_sec, 0.05)
	if whiplash_t >= 1.0:
		whiplash_t = 1.0
		whiplash_active = false
		whiplash_wing_kick = 0.0
		animator.set_whiplash_offsets(0.0, 0.0, 0.0)
		return
	var torso_k: float = _eval_whiplash_sample(whiplash_t) * 0.85 * whiplash_dir
	var lead_k: float = _eval_whiplash_sample(clampf(whiplash_t - 0.03, 0.0, 1.0)) * 1.05 * whiplash_dir
	var trail_k: float = _eval_whiplash_sample(clampf(whiplash_t - 0.11, 0.0, 1.0)) * 1.15 * whiplash_dir
	whiplash_wing_kick = trail_k
	animator.set_whiplash_offsets(torso_k, lead_k, trail_k)


func _apply_secondary_jiggle(
	delta: float,
	static_inspect: bool,
	cfg: AnimConfigScript,
	views: Dictionary,
	head_data: Dictionary,
	flight_phase: float,
	move_dir: Vector2,
	speed_norm: float,
	smooth_move_dir: Vector2,
	smooth_speed: float,
	smooth_aim_dir: Vector2,
	body_flip_x: bool,
	head_flip_x: bool,
	head_under_data: Dictionary = {}
) -> void:
	var flip_s: float = -1.0 if body_flip_x else 1.0
	if static_inspect:
		jiggle_pos_l = Vector2.ZERO
		jiggle_vel_l = Vector2.ZERO
		jiggle_pos_r = Vector2.ZERO
		jiggle_vel_r = Vector2.ZERO
		hair_jiggle_pos = Vector2.ZERO
		hair_jiggle_vel = Vector2.ZERO
	elif delta > 0.0:
		var vel_world: Vector2 = smooth_move_dir * smooth_speed
		var desired_vel: Vector2 = move_dir * speed_norm
		var accel_step: Vector2 = desired_vel - _prev_jiggle_vel_world
		var is_braking: bool = desired_vel.length() + 0.08 < _prev_jiggle_vel_world.length()
		_prev_jiggle_vel_world = desired_vel
		var aim_step: Vector2 = smooth_aim_dir - _prev_hair_aim_dir
		_prev_hair_aim_dir = smooth_aim_dir

		if accel_step.length() > 0.22:
			var kick: Vector2 = -accel_step * 62.0
			jiggle_vel_l += kick
			jiggle_vel_r += kick * 0.94
			if is_braking or accel_step.length() > 0.45:
				hair_jiggle_vel += -accel_step * 78.0
		if aim_step.length() > 0.03:
			hair_jiggle_vel += -aim_step * 52.0
		if jiggle_active and jiggle_t < 0.05:
			var turn_kick := Vector2(-jiggle_dir * 85.0, 38.0)
			jiggle_vel_l += turn_kick
			jiggle_vel_r += turn_kick * 0.92
			hair_jiggle_vel += Vector2(-jiggle_dir * 95.0, 38.0)
			jiggle_active = false

		var target_drag: Vector2 = -vel_world * 4.5
		var max_px: float = maxf(cfg.secondary_jiggle_max_px, 1.0)
		var stiff_l: float = cfg.secondary_jiggle_stiffness * 0.90
		var stiff_r: float = cfg.secondary_jiggle_stiffness * 0.82
		var damp_l: float = cfg.secondary_jiggle_damping * 1.08
		var damp_r: float = cfg.secondary_jiggle_damping * 1.02
		var hair_stiff: float = cfg.secondary_jiggle_stiffness
		var hair_damp: float = cfg.secondary_jiggle_damping

		var steps: int = maxi(1, int(ceil(delta / 0.012)))
		var h: float = delta / float(steps)
		for _i: int in range(steps):
			var acc_l: Vector2 = (target_drag - jiggle_pos_l) * stiff_l - jiggle_vel_l * damp_l
			var acc_r: Vector2 = (target_drag - jiggle_pos_r) * stiff_r - jiggle_vel_r * damp_r
			jiggle_vel_l += acc_l * h
			jiggle_vel_r += acc_r * h
			jiggle_pos_l = (jiggle_pos_l + jiggle_vel_l * h).limit_length(max_px)
			jiggle_pos_r = (jiggle_pos_r + jiggle_vel_r * h).limit_length(max_px)

			var hair_acc: Vector2 = -hair_jiggle_pos * hair_stiff - hair_jiggle_vel * hair_damp
			hair_jiggle_vel += hair_acc * h
			hair_jiggle_pos = (hair_jiggle_pos + hair_jiggle_vel * h).limit_length(max_px)

	var breath_bust_y: float = sin(flight_phase * 0.75 - 0.5) * 4.2
	for v_key: String in views.keys():
		var vd: Dictionary = views[v_key] as Dictionary
		var core_mat: ShaderMaterial = vd.get("body_core_mat", null) as ShaderMaterial
		if core_mat != null:
			var base_y: float = breath_bust_y if v_key == "s" else 0.0
			var off_l := Vector2(jiggle_pos_l.x * flip_s, base_y + jiggle_pos_l.y)
			var off_r := Vector2(jiggle_pos_r.x * flip_s, base_y + jiggle_pos_r.y)
			if static_inspect:
				off_l = Vector2.ZERO
				off_r = Vector2.ZERO
			core_mat.set_shader_parameter("secondary_jiggle_l_px", off_l)
			core_mat.set_shader_parameter("secondary_jiggle_r_px", off_r)

	var hair_off := Vector2(hair_jiggle_pos.x * (-1.0 if head_flip_x else 1.0), hair_jiggle_pos.y)
	if static_inspect:
		hair_off = Vector2.ZERO
	for h_dict: Dictionary in [head_data, head_under_data]:
		if h_dict.is_empty():
			continue
		var h_mats: Array = h_dict.get("materials", []) as Array
		for h_mat: ShaderMaterial in h_mats:
			h_mat.set_shader_parameter("enable_secondary_jiggle", true)
			h_mat.set_shader_parameter("secondary_jiggle_l_px", hair_off)

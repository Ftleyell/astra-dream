class_name PlanarRigSecondaryPhysics
extends RefCounted
## Física secundaria 2D para PlanarCombatRig:
## - Whiplash de extremidades/torso en giros rápidos (anticipo + latigazo elástico).
## - Resortes 2D de inercia/drag para busto y cabello reactivo.

const AnimConfigScript = preload("res://scenes/pilots/rig/planar_rig_anim_config.gd")

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


func trigger_snap_impulse(_turn_dir: float) -> void:
	pass


func trigger_impulse(_kick_vel: Vector2, _hair_kick_vel: Vector2 = Vector2.ZERO) -> void:
	pass


func update(
	_delta: float,
	_static_inspect: bool,
	animator: PlanarRigAnimator,
	views: Dictionary,
	head_data: Dictionary,
	_flight_phase: float,
	_move_dir: Vector2,
	_speed_norm: float,
	_smooth_move_dir: Vector2,
	_smooth_speed: float,
	smooth_aim_dir: Vector2,
	_body_flip_x: bool,
	_head_flip_x: bool,
	head_under_data: Dictionary = {},
	_flush_body_jiggle: bool = true,
	_flush_hair_jiggle: bool = true
) -> void:
	reset(smooth_aim_dir)
	if animator != null:
		animator.set_whiplash_offsets(0.0, 0.0, 0.0)
	for v_key: String in views.keys():
		var vd: Dictionary = views[v_key] as Dictionary
		var core_mat: ShaderMaterial = vd.get("body_core_mat", null) as ShaderMaterial
		if core_mat != null:
			core_mat.set_shader_parameter("secondary_jiggle_l_px", Vector2.ZERO)
			core_mat.set_shader_parameter("secondary_jiggle_r_px", Vector2.ZERO)
	for h_dict: Dictionary in [head_data, head_under_data]:
		if h_dict.is_empty():
			continue
		for mat: ShaderMaterial in (h_dict.get("materials", []) as Array):
			mat.set_shader_parameter("enable_secondary_jiggle", false)
			mat.set_shader_parameter("secondary_jiggle_l_px", Vector2.ZERO)
			mat.set_shader_parameter("secondary_jiggle_r_px", Vector2.ZERO)

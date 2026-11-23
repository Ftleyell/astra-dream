class_name PlanarRigPerspectiveController
extends RefCounted
## Controlador modular de Falsa Perspectiva 2.5D Post-Skinning (15 FPS Sakuga).
## Mantiene Bone2D.scale = Vector2.ONE estricto y sincroniza extremidades (incl. _stocking),
## body_core, hombreras (Pauldron_R/L) y cabeza desacoplada con 1-tick stagger.

const PerspConfigScript = preload("res://scenes/pilots/rig/rig_perspective_config.gd")

var config: PerspConfigScript = null

var _sakuga_tick: int = 0
var _last_burst_state: String = ""
var _torso_trapezoid: float = 0.0
var _prev_torso_trapezoid: float = 0.0
var _distal_amp: float = 0.0
var _toe_heel_bias: float = 0.0
var _yaw_twist: float = 0.0
var _rim_sweep_dir: float = 0.0
var _whip_pauldron_shift_x: float = 0.0
var _head_stagger_scale: float = 1.0
var _whip_head_bounce: float = 1.0

var _limb_params: Dictionary = {
	"leg_r": {"phi1": 0.0, "phi2": 0.0, "depth": 0.0},
	"leg_l": {"phi1": 0.0, "phi2": 0.0, "depth": 0.0},
	"arm_r": {"phi1": 0.0, "phi2": 0.0, "depth": 0.0},
	"arm_l": {"phi1": 0.0, "phi2": 0.0, "depth": 0.0},
}


func _init(persp_config: PerspConfigScript = null) -> void:
	config = persp_config if persp_config != null else PerspConfigScript.new()
	reset()


func set_config(persp_config: PerspConfigScript) -> void:
	config = persp_config if persp_config != null else PerspConfigScript.new()


func reset() -> void:
	_sakuga_tick = 0
	_last_burst_state = ""
	_torso_trapezoid = 0.0
	_prev_torso_trapezoid = 0.0
	_distal_amp = 0.0
	_toe_heel_bias = 0.0
	_yaw_twist = 0.0
	_rim_sweep_dir = 0.0
	_whip_pauldron_shift_x = 0.0
	_head_stagger_scale = 1.0
	_whip_head_bounce = 1.0
	for k: String in _limb_params.keys():
		_limb_params[k] = {"phi1": 0.0, "phi2": 0.0, "depth": 0.0}


static func resolve_state_name(
	anim_state_name: String,
	is_dash_burst: bool,
	is_air_brake: bool,
	is_attack_recoil: bool,
	is_hit_react: bool
) -> String:
	if is_hit_react:
		return "HIT"
	if is_attack_recoil:
		return "ATTACK_RECOIL"
	if is_dash_burst or anim_state_name == "Dash" or anim_state_name == "DASH_BOOST":
		return "DASH"
	if is_air_brake or anim_state_name == "Backpedal" or anim_state_name == "BACKPEDAL_FOCUS":
		return "AIR_BRAKE"
	if anim_state_name in ["FLIGHT_STRAFE", "ASCEND", "DESCEND"]:
		return anim_state_name
	return "IDLE_HOVER"


func update_pose_tick(
	_state_name: String,
	_view_key: String,
	_snap_active: bool,
	_transition_style: int,
	_snap_swapped: bool,
	_snap_t: float,
	_snap_turn_dir: float,
	_flush_body_latch: bool,
	_flush_head_latch: bool,
	_body_flip_x: bool = false
) -> void:
	reset()


func get_head_stagger_scale() -> Vector2:
	return Vector2.ONE


func get_neck_arch_offset() -> Vector2:
	return Vector2.ZERO


func get_sakuga_tick() -> int:
	return 0


func get_torso_trapezoid() -> float:
	return 0.0


func get_yaw_twist() -> float:
	return 0.0


func get_rim_sweep_dir() -> float:
	return 0.0


func get_limb_params(_part_name: String) -> Dictionary:
	return {"phi1": 0.0, "phi2": 0.0, "depth": 0.0}


func apply_to_view(vd: Dictionary, view_key: String, _static_inspect: bool) -> void:
	if vd.is_empty():
		return
	var cfg: PerspConfigScript = config if config != null else PerspConfigScript.new()
	var bones: Dictionary = vd.get("bones", {}) as Dictionary
	var rest_pos: Dictionary = vd.get("rest_pos", {}) as Dictionary
	var polys: Dictionary = vd.get("polys", {}) as Dictionary

	# Regla estricta: Bone2D.scale siempre Vector2.ONE
	for b_val: Variant in bones.values():
		var b: Bone2D = b_val as Bone2D
		if b != null:
			b.scale = Vector2.ONE

	for p_bone_name: String in ["Pauldron_R", "Pauldron_L"]:
		if bones.has(p_bone_name) and rest_pos.has(p_bone_name):
			(bones[p_bone_name] as Bone2D).position = rest_pos[p_bone_name] as Vector2

	for p_key: String in polys.keys():
		var poly: Polygon2D = polys[p_key] as Polygon2D
		if poly == null:
			continue
		poly.position = Vector2.ZERO
		if not (poly.material is ShaderMaterial):
			continue
		var mat: ShaderMaterial = poly.material as ShaderMaterial
		mat.set_shader_parameter("persp_mode", 0)
		mat.set_shader_parameter("bone_chain_angles", Vector2.ZERO)
		mat.set_shader_parameter("joint_flexion", 0.0)
		var depth_phase: float = 0.0
		if view_key == "e":
			if p_key.begins_with("leg_r"):
				depth_phase = cfg.ew_front_depth_weight
			elif p_key.begins_with("leg_l"):
				depth_phase = cfg.ew_back_depth_weight
		elif view_key == "w":
			if p_key.begins_with("leg_l"):
				depth_phase = cfg.ew_front_depth_weight
			elif p_key.begins_with("leg_r"):
				depth_phase = cfg.ew_back_depth_weight
		mat.set_shader_parameter("leg_depth_phase", depth_phase)

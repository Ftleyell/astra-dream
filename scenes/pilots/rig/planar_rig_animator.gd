class_name PlanarRigAnimator
extends RefCounted
## Máquina de estados de animación procedural expresiva sobre Skeleton2D + piezas con underlap.
## Combina estados (Idle/Hover, Strafe, Ascend, Descend, Backpedal/Focus, Dash)
## con amortiguación suave por articulación y foreshortening 2.5D sutil.

const AnimConfigScript = preload("res://scenes/pilots/rig/planar_rig_anim_config.gd")

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
var _bank_rot: float = 0.0
var _bank_vel: float = 0.0
var _hover_x: float = 0.0
var _hover_x_vel: float = 0.0
var _hover_y: float = 0.0
var _hover_vel: float = 0.0
var _whiplash_torso: float = 0.0
var _whiplash_limb_lead: float = 0.0
var _whiplash_limb_trail: float = 0.0
var _prev_canon_mirror_x: bool = false
var _prev_active_view_key: String = ""
var _view_switch_damp_timer: float = 0.0
var _cached_whiplash_add: Dictionary = {}

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
	_bank_rot = 0.0
	_bank_vel = 0.0
	_hover_x = 0.0
	_hover_x_vel = 0.0
	_hover_y = 0.0
	_hover_vel = 0.0
	_whiplash_torso = 0.0
	_whiplash_limb_lead = 0.0
	_whiplash_limb_trail = 0.0
	_prev_canon_mirror_x = false
	_prev_active_view_key = ""
	_view_switch_damp_timer = 0.0
	_cached_whiplash_add.clear()
	_launch_timer = 0.0
	_air_brake_timer = 0.0
	_dash_burst_timer = 0.0
	_attack_recoil_timer = 0.0
	_hit_react_timer = 0.0
	for b_name: String in ANIM_BONES:
		_current_offsets[b_name] = 0.0
		_offset_vels[b_name] = 0.0


func get_latest_bank_rot() -> float:
	return _bank_rot


func get_current_scale() -> Vector2:
	return _current_scale


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


func trigger_launch(_dir: Vector2) -> void:
	pass


func trigger_air_brake(_dir: Vector2) -> void:
	pass


func trigger_dash_burst(_dir: Vector2) -> void:
	pass


func trigger_attack_recoil(_aim_dir: Vector2, _strength: float = 1.0) -> void:
	pass


func trigger_hit_react(_hit_dir: Vector2, _strength: float = 1.0) -> void:
	pass


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


static func is_back_view(v_key: String) -> bool:
	return v_key in ["n", "ne", "nw"]


static func is_left_native_view(v_key: String) -> bool:
	return v_key in ["w", "nw", "sw"]


static func _mirror_bone_name(b_name: String) -> String:
	if b_name.ends_with("_R"):
		return b_name.substr(0, b_name.length() - 2) + "_L"
	if b_name.ends_with("_L"):
		return b_name.substr(0, b_name.length() - 2) + "_R"
	return b_name


static func _mirror_bone_dict_x(src: Dictionary) -> Dictionary:
	var mirrored: Dictionary = {}
	for b_name: Variant in src.keys():
		var k: String = str(b_name)
		var dst_k: String = _mirror_bone_name(k)
		mirrored[dst_k] = -float(src[k])
	return mirrored


func get_bone_limit_for_view(v_key: String, b_name: String) -> Vector2:
	var cfg: AnimConfigScript = config if config != null else AnimConfigScript.new()
	return _get_bone_limits(v_key, b_name, cfg)


static func _get_canonical_family(v_key: String) -> String:
	match v_key:
		"se", "sw":
			return "se"
		"e", "w":
			return "e"
		"ne", "nw":
			return "ne"
		"n":
			return "n"
		_:
			return "s"


static func _get_view_family_weights(v_key: String) -> Dictionary:
	var fam: String = _get_canonical_family(v_key)
	return {
		"s": 1.0 if fam == "s" else 0.0,
		"se": 1.0 if fam == "se" else 0.0,
		"e": 1.0 if fam == "e" else 0.0,
		"ne": 1.0 if fam == "ne" else 0.0,
		"n": 1.0 if fam == "n" else 0.0,
	}


func _handle_view_swap_remapping(active_view_key: String, mirror_native_x: bool, cfg: AnimConfigScript) -> void:
	if _prev_active_view_key != "" and active_view_key != _prev_active_view_key:
		if _prev_canon_mirror_x != mirror_native_x:
			_current_offsets = _mirror_bone_dict_x(_current_offsets)
			_offset_vels = _mirror_bone_dict_x(_offset_vels)
		_view_switch_damp_timer = maxf(_view_switch_damp_timer, cfg.view_switch_damp_sec)
	_prev_active_view_key = active_view_key
	_prev_canon_mirror_x = mirror_native_x


func _get_bone_limits(v_key: String, b_name: String, cfg: AnimConfigScript) -> Vector2:
	var mirror_x: bool = is_left_native_view(v_key)
	var lookup_bone: String = _mirror_bone_name(b_name) if mirror_x else b_name
	var fam: String = _get_canonical_family(v_key)
	var base_lim := Vector2(-0.175, 0.175)
	match lookup_bone:
		"Pelvis":
			return Vector2(-0.12, 0.12)
		"Waist", "Chest":
			return Vector2(-0.175, 0.175)
		"Neck":
			return Vector2(-0.28, 0.28)
	match fam:
		"n":
			match lookup_bone:
				"Shoulder_R": base_lim = cfg.n_shoulder_r_limits
				"Shoulder_L": base_lim = cfg.n_shoulder_l_limits
				"Elbow_R": base_lim = cfg.n_elbow_r_limits
				"Elbow_L": base_lim = cfg.n_elbow_l_limits
				"Wrist_R": base_lim = cfg.n_wrist_r_limits
				"Wrist_L": base_lim = cfg.n_wrist_l_limits
				"Thigh_R", "Thigh_L": base_lim = cfg.n_thigh_limits
				"Knee_R", "Knee_L": base_lim = cfg.n_knee_limits
				"Ankle_R", "Ankle_L": base_lim = cfg.n_ankle_limits
		"ne":
			match lookup_bone:
				"Shoulder_R": base_lim = cfg.ne_shoulder_r_limits
				"Shoulder_L": base_lim = cfg.ne_shoulder_l_limits
				"Elbow_R": base_lim = cfg.ne_elbow_r_limits
				"Elbow_L": base_lim = cfg.ne_elbow_l_limits
				"Wrist_R": base_lim = cfg.ne_wrist_r_limits
				"Wrist_L": base_lim = cfg.ne_wrist_l_limits
				"Thigh_R", "Thigh_L": base_lim = cfg.ne_thigh_limits
				"Knee_R", "Knee_L": base_lim = cfg.ne_knee_limits
				"Ankle_R", "Ankle_L": base_lim = cfg.ne_ankle_limits
		"e":
			match lookup_bone:
				"Shoulder_R": base_lim = cfg.e_shoulder_r_limits
				"Shoulder_L": base_lim = cfg.e_shoulder_l_limits
				"Elbow_R": base_lim = cfg.e_elbow_r_limits
				"Elbow_L": base_lim = cfg.e_elbow_l_limits
				"Wrist_R": base_lim = cfg.e_wrist_r_limits
				"Wrist_L": base_lim = cfg.e_wrist_l_limits
				"Thigh_R", "Thigh_L": base_lim = cfg.e_thigh_limits
				"Knee_R", "Knee_L": base_lim = cfg.e_knee_limits
				"Ankle_R", "Ankle_L": base_lim = cfg.e_ankle_limits
		"se":
			match lookup_bone:
				"Shoulder_R": base_lim = cfg.se_shoulder_r_limits
				"Shoulder_L": base_lim = cfg.se_shoulder_l_limits
				"Elbow_R": base_lim = cfg.se_elbow_r_limits
				"Elbow_L": base_lim = cfg.se_elbow_l_limits
				"Wrist_R": base_lim = cfg.se_wrist_r_limits
				"Wrist_L": base_lim = cfg.se_wrist_l_limits
				"Thigh_R", "Thigh_L": base_lim = cfg.se_thigh_limits
				"Knee_R", "Knee_L": base_lim = cfg.se_knee_limits
				"Ankle_R", "Ankle_L": base_lim = cfg.se_ankle_limits
		_:
			match lookup_bone:
				"Shoulder_R": base_lim = cfg.s_shoulder_r_limits
				"Shoulder_L": base_lim = cfg.s_shoulder_l_limits
				"Elbow_R": base_lim = cfg.s_elbow_r_limits
				"Elbow_L": base_lim = cfg.s_elbow_l_limits
				"Wrist_R": base_lim = cfg.s_wrist_r_limits
				"Wrist_L": base_lim = cfg.s_wrist_l_limits
				"Thigh_R", "Thigh_L": base_lim = cfg.s_thigh_limits
				"Knee_R", "Knee_L": base_lim = cfg.s_knee_limits
				"Ankle_R", "Ankle_L": base_lim = cfg.s_ankle_limits
	return Vector2(-base_lim.y, -base_lim.x) if mirror_x else base_lim


func update_and_apply(
	_delta: float,
	body_pivot: Node2D,
	views: Dictionary,
	_flight_phase: float,
	_smooth_move_dir: Vector2,
	_smooth_speed: float,
	_is_backpedaling: bool,
	_body_flip_x: bool,
	_turn_bone_kick: float,
	_shoulder_look_twist: float,
	active_view_key: String = "s",
	_smooth_aim_dir: Vector2 = Vector2.RIGHT,
	_torso_forward: Vector2 = Vector2.DOWN,
	apply_bones_immediately: bool = true
) -> void:
	if body_pivot == null:
		return
	_active_state = AnimState.IDLE_HOVER
	_bank_rot = 0.0
	_bank_vel = 0.0
	_hover_x = 0.0
	_hover_x_vel = 0.0
	_hover_y = 0.0
	_hover_vel = 0.0
	_current_scale = Vector2.ONE
	_scale_vel = Vector2.ZERO
	body_pivot.position = Vector2.ZERO
	body_pivot.rotation = 0.0
	body_pivot.scale = Vector2.ONE
	if apply_bones_immediately:
		apply_latched_pose(views, active_view_key)


func apply_latched_pose(views: Dictionary, active_view_key: String = "") -> void:
	for v_key: String in views.keys():
		if not active_view_key.is_empty() and v_key != active_view_key:
			continue
		var vd: Dictionary = views[v_key] as Dictionary
		if active_view_key.is_empty() and not (vd["root"] as Node2D).visible:
			continue
		var bones: Dictionary = vd["bones"] as Dictionary
		var rest_rots: Dictionary = vd["rest_rots"] as Dictionary
		for b_name: String in ANIM_BONES:
			if bones.has(b_name):
				var bone: Bone2D = bones[b_name] as Bone2D
				bone.rotation = float(rest_rots.get(b_name, 0.0))
		for side_suffix: String in ["R", "L"]:
			var p_name: String = "Pauldron_%s" % side_suffix
			if bones.has(p_name):
				var p_bone: Bone2D = bones[p_name] as Bone2D
				p_bone.scale = Vector2.ONE
				p_bone.rotation = float(rest_rots.get(p_name, 0.0))

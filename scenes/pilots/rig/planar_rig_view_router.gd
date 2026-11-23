class_name PlanarRigViewRouter
extends RefCounted
## Enrutador de vistas planares 8-Dir nativo (Valentina v2) y cabezas desacopladas (8 direcciones).
## Implementa límites anatómicos de cuello (±65°), histéresis de giro y modo backpedal anti-exorcista.

const DIRECTION_ORDER_8: Array[String] = ["s", "se", "e", "ne", "n", "nw", "w", "sw"]
const BODY_DIR_VECTORS: Dictionary = {
	"e": Vector2(1.0, 0.0),
	"se": Vector2(0.70710678, 0.70710678),
	"s": Vector2(0.0, 1.0),
	"sw": Vector2(-0.70710678, 0.70710678),
	"w": Vector2(-1.0, 0.0),
	"nw": Vector2(-0.70710678, -0.70710678),
	"n": Vector2(0.0, -1.0),
	"ne": Vector2(0.70710678, -0.70710678),
}
const DEFAULT_HEAD_BY_BODY: Dictionary = {
	"s": "head_front",
	"se": "head_front_r",
	"e": "head_side_r",
	"ne": "head_back_r",
	"n": "head_back",
	"nw": "head_back_l",
	"w": "head_side_l",
	"sw": "head_front_l",
}
const HEAD_DIR_VECTORS: Dictionary = {
	"head_side_r": Vector2(1.0, 0.0),
	"head_front_r": Vector2(0.7313537, 0.6819984),
	"head_front": Vector2(0.0, 1.0),
	"head_front_l": Vector2(-0.7313537, 0.6819984),
	"head_side_l": Vector2(-1.0, 0.0),
	"head_back_l": Vector2(-0.7313537, -0.6819984),
	"head_back": Vector2(0.0, -1.0),
	"head_back_r": Vector2(0.7313537, -0.6819984),
}
const NECK_CONE_MIN_DOT_8DIR: float = 0.45
const MAX_NECK_DEG_8DIR: float = 65.0
const BACKPEDAL_ENTER_DOT_8DIR: float = 0.56 # ~55.9 deg: permite +-45 deg en vuelo y al cruzar pasa por la diagonal intermedia (45 deg) sin saltar 90 deg
const BACKPEDAL_EXIT_DOT_8DIR: float = 0.68 # ~47.2 deg: histeresis limpia (~9 deg) para volver a la postura de vuelo
const ALLOWED_HEADS_BY_BODY_8DIR: Dictionary = {
	"s": ["head_front", "head_front_r", "head_front_l"],
	"se": ["head_front_r", "head_front", "head_side_r"],
	"e": ["head_side_r", "head_front_r"],
	"ne": ["head_back_r", "head_back"],
	"n": ["head_back", "head_back_r", "head_back_l"],
	"nw": ["head_back_l", "head_back"],
	"w": ["head_side_l", "head_front_l"],
	"sw": ["head_front_l", "head_front", "head_side_l"],
}
const BODY_HALF_WIDTH_8: float = PI / 8.0

var has_8dir_body: bool = true
var _available_views: Array[String] = []

var active_view_key: String = "s"
var target_view_key: String = "s"
var body_flip_x: bool = false
var target_body_flip_x: bool = false

var active_head_key: String = "head_front"
var target_head_key: String = "head_front"
var head_flip_x: bool = false
var target_head_flip_x: bool = false

var is_backpedaling: bool = false
var shoulder_look_twist: float = 0.0


func set_available_views(view_keys: Array) -> void:
	_available_views.clear()
	for k: Variant in view_keys:
		_available_views.append(str(k))
	var has_all_8: bool = true
	for req: String in DIRECTION_ORDER_8:
		if not _available_views.has(req):
			has_all_8 = false
			break
	has_8dir_body = has_all_8


static func get_body_dir_vector(view_key: String) -> Vector2:
	return BODY_DIR_VECTORS.get(view_key, Vector2.DOWN) as Vector2


static func get_default_head_for_body(body_view: String) -> String:
	return str(DEFAULT_HEAD_BY_BODY.get(body_view, "head_front"))


func reset_to(view_key: String, b_flip: bool, head_key: String, h_flip: bool) -> void:
	active_view_key = view_key
	target_view_key = view_key
	body_flip_x = b_flip
	target_body_flip_x = b_flip
	active_head_key = head_key
	target_head_key = head_key
	head_flip_x = h_flip
	target_head_flip_x = h_flip
	is_backpedaling = false
	shoulder_look_twist = 0.0


static func is_head_allowed_for_body_8dir(body_view: String, head_key: String) -> bool:
	var allowed: Array = ALLOWED_HEADS_BY_BODY_8DIR.get(body_view, []) as Array
	if not allowed.is_empty():
		return allowed.has(head_key)
	var torso_fwd: Vector2 = get_body_dir_vector(body_view)
	var req_dir: Vector2 = HEAD_DIR_VECTORS.get(head_key, torso_fwd) as Vector2
	return HEAD_DIR_VECTORS.has(head_key) and torso_fwd.dot(req_dir) >= NECK_CONE_MIN_DOT_8DIR - 0.01


func sanitize_head_for_body(body_view: String, body_flip: bool, head_key: String, aim_x: float = 0.0) -> String:
	if is_head_allowed_for_body_8dir(body_view, head_key):
		return head_key

	var torso_fwd: Vector2 = get_body_dir_vector(body_view)
	var req_dir: Vector2 = HEAD_DIR_VECTORS.get(head_key, torso_fwd) as Vector2
	var best_key: String = get_default_head_for_body(body_view)
	var best_score: float = -INF
	var tie_dir: float = -1.0 if aim_x < -0.01 else (1.0 if aim_x > 0.01 else (-1.0 if body_flip else 1.0))
	for h_k: String in HEAD_DIR_VECTORS.keys():
		if not is_head_allowed_for_body_8dir(body_view, h_k):
			continue
		var h_dir: Vector2 = HEAD_DIR_VECTORS[h_k] as Vector2
		var align_score: float = h_dir.dot(req_dir) + 0.02 * h_dir.dot(torso_fwd) + 0.005 * signf(h_dir.x) * tie_dir
		if align_score > best_score:
			best_score = align_score
			best_key = h_k
	return best_key


func get_torso_forward(torso_view: String, _torso_flip: bool = false) -> Vector2:
	return get_body_dir_vector(torso_view)


func clamp_aim_to_neck_cone(torso_view: String, torso_flip: bool, raw_aim: Vector2) -> Vector2:
	var torso_forward: Vector2 = get_torso_forward(torso_view, torso_flip)
	var aim_n: Vector2 = raw_aim.normalized() if raw_aim.length_squared() > 0.0001 else torso_forward
	var signed_ang: float = torso_forward.angle_to(aim_n)
	var max_neck_rad: float = deg_to_rad(MAX_NECK_DEG_8DIR)
	shoulder_look_twist = clampf(sin(signed_ang) * 0.14, -0.14, 0.14)
	if absf(signed_ang) > max_neck_rad:
		return torso_forward.rotated(clampf(signed_ang, -max_neck_rad, max_neck_rad)).normalized()
	return aim_n


func _pick_angular_candidate(target_ang: float, candidates: Array[Dictionary], current_key: String, hys_norm: float) -> String:
	var best_key: String = current_key
	var best_score: float = INF
	for cand: Dictionary in candidates:
		var c_key: String = str(cand["key"])
		var c_ang: float = float(cand["ang"])
		var c_hw: float = float(cand["hw"])
		var score: float = absf(wrapf(target_ang - c_ang, -PI, PI)) / maxf(c_hw, 0.001)
		if c_key == current_key:
			score -= hys_norm
		if score < best_score:
			best_score = score
			best_key = c_key
	return best_key


func resolve_orientation(smooth_move_dir: Vector2, smooth_speed: float, smooth_aim_dir: Vector2, head_sprites: Dictionary, snap_instant: bool = false) -> void:
	var aim_dot: float = smooth_move_dir.dot(smooth_aim_dir)
	if smooth_speed < 0.15:
		is_backpedaling = false
	elif snap_instant:
		is_backpedaling = (aim_dot < BACKPEDAL_ENTER_DOT_8DIR)
	elif not is_backpedaling and aim_dot < BACKPEDAL_ENTER_DOT_8DIR:
		is_backpedaling = true
	elif is_backpedaling and aim_dot > BACKPEDAL_EXIT_DOT_8DIR:
		is_backpedaling = false

	var body_face: Vector2 = smooth_aim_dir if (is_backpedaling or smooth_speed < 0.15) else smooth_move_dir
	target_body_flip_x = false
	var body_candidates: Array[Dictionary] = []
	for dir_key: String in DIRECTION_ORDER_8:
		var d_vec: Vector2 = BODY_DIR_VECTORS[dir_key] as Vector2
		body_candidates.append({"key": dir_key, "ang": d_vec.angle(), "hw": BODY_HALF_WIDTH_8})
	target_view_key = _pick_angular_candidate(body_face.angle(), body_candidates, target_view_key, 0.0 if snap_instant else 0.20)

	var neck_aim: Vector2 = clamp_aim_to_neck_cone(target_view_key, target_body_flip_x, smooth_aim_dir)
	target_head_flip_x = false
	var aim_ang: float = atan2(neck_aim.y, neck_aim.x)
	var hys_norm: float = 0.0 if snap_instant else 0.22
	var side_hw: float = deg_to_rad(18.0)
	var diag_hw: float = deg_to_rad(25.0)
	var card_hw: float = deg_to_rad(22.0)
	var full_pool: Array[Dictionary] = [
		{"key": "head_side_r", "ang": 0.0, "hw": side_hw},
		{"key": "head_side_l", "ang": PI, "hw": side_hw},
		{"key": "head_front", "ang": PI * 0.5, "hw": card_hw},
		{"key": "head_front_r", "ang": deg_to_rad(43.0), "hw": diag_hw},
		{"key": "head_front_l", "ang": deg_to_rad(137.0), "hw": diag_hw},
		{"key": "head_back", "ang": -PI * 0.5, "hw": card_hw},
		{"key": "head_back_r", "ang": deg_to_rad(-43.0), "hw": diag_hw},
		{"key": "head_back_l", "ang": deg_to_rad(-137.0), "hw": diag_hw},
	]
	var candidates: Array[Dictionary] = []
	for c_entry: Dictionary in full_pool:
		var c_k: String = str(c_entry["key"])
		if not head_sprites.has(c_k):
			continue
		if is_head_allowed_for_body_8dir(target_view_key, c_k):
			candidates.append(c_entry)

	var best_key: String = _pick_angular_candidate(aim_ang, candidates, target_head_key, hys_norm)
	target_head_key = sanitize_head_for_body(target_view_key, target_body_flip_x, best_key, neck_aim.x)

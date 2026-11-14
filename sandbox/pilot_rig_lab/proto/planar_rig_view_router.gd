class_name PlanarRigViewRouter
extends RefCounted
## Enrutador de vistas planares (S/N + Flip-H) y cabezas desacopladas (8 direcciones).
## Implementa límites anatómicos de cuello (±110°), histéresis de giro y modo híbrido anti-exorcista.

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


func sanitize_head_for_body(body_view: String, body_flip: bool, head_key: String, aim_x: float = 0.0) -> String:
	var fallback_side: String = "head_side_l" if (aim_x < 0.0 or (is_zero_approx(aim_x) and body_flip)) else "head_side_r"
	if body_view == "s":
		if head_key.begins_with("head_back"):
			return fallback_side
		return head_key
	if head_key.begins_with("head_front"):
		return fallback_side
	return head_key


func clamp_aim_to_neck_cone(torso_view: String, torso_flip: bool, raw_aim: Vector2) -> Vector2:
	var face_x: float = -0.34 if torso_flip else 0.34
	var torso_forward := Vector2(face_x, -0.94 if torso_view == "n" else 0.94).normalized()
	var signed_ang: float = torso_forward.angle_to(raw_aim.normalized())
	var max_neck_rad: float = deg_to_rad(110.0)
	shoulder_look_twist = clampf(sin(signed_ang) * 0.14, -0.14, 0.14)
	if absf(signed_ang) > max_neck_rad:
		return torso_forward.rotated(clampf(signed_ang, -max_neck_rad, max_neck_rad)).normalized()
	return raw_aim.normalized()


func resolve_orientation(smooth_move_dir: Vector2, smooth_speed: float, smooth_aim_dir: Vector2, head_sprites: Dictionary, snap_instant: bool = false) -> void:
	var aim_dot: float = smooth_move_dir.dot(smooth_aim_dir)
	if smooth_speed < 0.15:
		is_backpedaling = false
	elif snap_instant:
		is_backpedaling = (aim_dot < -0.58)
	elif not is_backpedaling and aim_dot < -0.58:
		is_backpedaling = true
	elif is_backpedaling and aim_dot > -0.34:
		is_backpedaling = false

	var body_face: Vector2 = smooth_aim_dir if (is_backpedaling or smooth_speed < 0.15) else smooth_move_dir
	var ay_b: float = body_face.y
	var ax_b: float = body_face.x

	if target_view_key == "s" and ay_b < -0.26:
		target_view_key = "n"
	elif target_view_key == "n" and ay_b > 0.26:
		target_view_key = "s"

	var flip_deadzone: float = 0.36
	if target_body_flip_x and ax_b > flip_deadzone:
		target_body_flip_x = false
	elif not target_body_flip_x and ax_b < -flip_deadzone:
		target_body_flip_x = true

	var neck_aim: Vector2 = clamp_aim_to_neck_cone(target_view_key, target_body_flip_x, smooth_aim_dir)
	var ay_h: float = neck_aim.y
	var ax_h: float = neck_aim.x

	var has_asym_fronts: bool = head_sprites.has("head_front_l") and head_sprites.has("head_front_r")
	var has_asym_sides: bool = head_sprites.has("head_side_l") and head_sprites.has("head_side_r")
	var has_asym_backs: bool = head_sprites.has("head_back_l") and head_sprites.has("head_back_r")

	if has_asym_sides:
		target_head_flip_x = false
		var aim_ang: float = atan2(ay_h, ax_h)
		var hys_norm: float = 0.22
		var side_hw: float = deg_to_rad(18.0)
		var diag_hw: float = deg_to_rad(25.0)
		var card_hw: float = deg_to_rad(22.0)
		var candidates: Array[Dictionary] = [
			{"key": "head_side_r", "ang": 0.0, "hw": side_hw},
			{"key": "head_side_l", "ang": PI, "hw": side_hw},
		]
		if target_view_key == "s":
			candidates.append({"key": "head_front", "ang": PI * 0.5, "hw": card_hw})
			if has_asym_fronts:
				candidates.append({"key": "head_front_r", "ang": deg_to_rad(43.0), "hw": diag_hw})
				candidates.append({"key": "head_front_l", "ang": deg_to_rad(137.0), "hw": diag_hw})
		else:
			candidates.append({"key": "head_back", "ang": -PI * 0.5, "hw": card_hw})
			if has_asym_backs:
				candidates.append({"key": "head_back_r", "ang": deg_to_rad(-43.0), "hw": diag_hw})
				candidates.append({"key": "head_back_l", "ang": deg_to_rad(-137.0), "hw": diag_hw})

		var best_key: String = target_head_key
		var best_score: float = INF
		for cand: Dictionary in candidates:
			var c_key: String = str(cand["key"])
			var c_ang: float = float(cand["ang"])
			var c_hw: float = float(cand["hw"])
			var score: float = absf(wrapf(aim_ang - c_ang, -PI, PI)) / c_hw
			if c_key == target_head_key:
				score -= hys_norm
			if score < best_score:
				best_score = score
				best_key = c_key
		target_head_key = sanitize_head_for_body(target_view_key, target_body_flip_x, best_key, ax_h)
		return

	var desired_head: String = target_head_key
	if target_head_key == "head_front":
		if ay_h < 0.42 or absf(ax_h) > 0.74:
			desired_head = "head_side"
	elif target_head_key == "head_back":
		if ay_h > -0.44 or absf(ax_h) > 0.72:
			desired_head = "head_side"
	else:
		if ay_h > 0.62 and absf(ax_h) < 0.56:
			desired_head = "head_front"
		elif ay_h < -0.64 and absf(ax_h) < 0.54:
			desired_head = "head_back"

	if target_view_key == "n" and desired_head == "head_front":
		desired_head = "head_side"
	elif target_view_key == "s" and desired_head == "head_back":
		desired_head = "head_side"
	target_head_key = desired_head

	var h_deadzone: float = 0.24
	if target_head_flip_x and ax_h > h_deadzone:
		target_head_flip_x = false
	elif not target_head_flip_x and ax_h < -h_deadzone:
		target_head_flip_x = true

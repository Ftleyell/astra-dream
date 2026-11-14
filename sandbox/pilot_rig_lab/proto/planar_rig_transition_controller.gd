class_name PlanarRigTransitionController
extends RefCounted
## Controlador de transiciones snappy de alta velocidad (modos 4..6)
## para cambios de vista S <-> N y Flip-H en PlanarCombatRig.

enum TransitionStyle {
	WHIP_SNAP_AFTERIMAGE = 4,
	MICRO_FLASH_SNAP = 5,
	HOLO_SNAP_FAST = 6,
}

var transition_style: int = TransitionStyle.WHIP_SNAP_AFTERIMAGE

var snap_active: bool = false
var snap_t: float = 1.0
var snap_swapped: bool = true
var snap_turn_dir: float = 1.0
var snap_scale_xy: Vector2 = Vector2.ONE
var snap_from_view: String = "s"
var snap_to_view: String = "s"
var snap_from_flip: bool = false
var snap_to_flip: bool = false
var snap_from_head: String = "head_front"
var snap_to_head: String = "head_front"
var snap_from_head_flip: bool = false
var snap_to_head_flip: bool = false

var head_micro_snap_t: float = 1.0
var head_micro_snap_active: bool = false
var head_micro_snap_scale: Vector2 = Vector2.ONE
var head_micro_turn_dir: float = 0.0


func set_style(style_idx: int) -> void:
	transition_style = clampi(style_idx, TransitionStyle.WHIP_SNAP_AFTERIMAGE, TransitionStyle.HOLO_SNAP_FAST)


func reset() -> void:
	snap_active = false
	snap_t = 1.0
	snap_swapped = true
	snap_scale_xy = Vector2.ONE
	head_micro_snap_t = 1.0
	head_micro_snap_active = false
	head_micro_snap_scale = Vector2.ONE
	head_micro_turn_dir = 0.0


func compute_snap_curve(style: int, t: float) -> Dictionary:
	var sx: float = 1.0
	var sy: float = 1.0
	var pass1_fx_mode: int = 0
	var pass1_fx_str: float = 0.0
	var pass2_smear_str: float = 0.0
	var holo_pos: float = -1.0
	if style == TransitionStyle.WHIP_SNAP_AFTERIMAGE:
		# Modo 4: Smear direccional en Pasada 2 + afterimage real, sin flash blanco invasivo en Pasada 1
		pass1_fx_mode = 0
		pass1_fx_str = 0.0
		pass2_smear_str = pow(sin(t * PI), 0.55)
		if t < 0.35:
			var p: float = t / 0.35
			sx = lerpf(1.0, 0.72, p * p)
			sy = lerpf(1.0, 1.09, p)
		elif t < 0.65:
			var p2: float = (t - 0.35) / 0.30
			sx = lerpf(0.72, 1.10, p2)
			sy = lerpf(1.09, 0.95, p2)
		else:
			var p3: float = (t - 0.65) / 0.35
			sx = lerpf(1.10, 1.0, p3)
			sy = lerpf(0.95, 1.0, p3)
	elif style == TransitionStyle.MICRO_FLASH_SNAP:
		# Modo 5: Flash limpio en Pasada 1, sin smear en Pasada 2
		pass1_fx_mode = 2
		pass1_fx_str = pow(1.0 - t, 1.25)
		pass2_smear_str = 0.0
		if t < 0.18:
			sx = 0.82
			sy = 1.08
		elif t < 0.55:
			var p_m: float = (t - 0.18) / 0.37
			sx = lerpf(0.82, 1.10, p_m)
			sy = lerpf(1.08, 0.96, p_m)
		else:
			var p_m2: float = (t - 0.55) / 0.45
			sx = lerpf(1.10, 1.0, p_m2)
			sy = lerpf(0.96, 1.0, p_m2)
	else:
		# Modo 6: Holo-Sweep unificado en Pasada 1, continuidad exacta de sy en t = 0.45
		pass1_fx_mode = 3
		pass1_fx_str = sin(t * PI)
		pass2_smear_str = 0.0
		holo_pos = t
		if t < 0.45:
			var p_h: float = t / 0.45
			sx = lerpf(1.0, 0.78, p_h)
			sy = lerpf(1.0, 1.05, p_h)
		else:
			var p_h2: float = (t - 0.45) / 0.55
			sx = lerpf(0.78, 1.0, p_h2) + 0.08 * sin(p_h2 * PI)
			sy = lerpf(1.05, 1.0, p_h2)
	return {
		"scale": Vector2(maxf(sx, 0.25), sy),
		"fx_mode": pass1_fx_mode,
		"fx_str": pass1_fx_str,
		"pass2_smear_str": pass2_smear_str,
		"holo_pos": holo_pos,
	}


func update(delta: float, router: PlanarRigViewRouter, defer_head_to_clock: bool = false) -> Dictionary:
	var body_changed: bool = (router.active_view_key != router.target_view_key or router.body_flip_x != router.target_body_flip_x)
	var head_changed: bool = (router.active_head_key != router.target_head_key or router.head_flip_x != router.target_head_flip_x)
	var events: Dictionary = {
		"started_snap": false,
		"body_swapped": false,
		"spawn_afterimage": false,
		"turn_bone_kick": 0.0,
		"head_micro_snap": false,
		"head_turn_dir": 0.0,
	}

	if head_micro_snap_active:
		head_micro_snap_t += delta / 0.075
		if head_micro_snap_t >= 1.0:
			head_micro_snap_t = 1.0
			head_micro_snap_active = false
			head_micro_snap_scale = Vector2.ONE
		else:
			var hs: float = sin(head_micro_snap_t * PI)
			head_micro_snap_scale = Vector2(1.0 - 0.11 * hs, 1.0 + 0.07 * hs)

	if not snap_active:
		if body_changed:
			snap_active = true
			snap_t = 0.0
			snap_swapped = false
			snap_from_view = router.active_view_key
			snap_to_view = router.target_view_key
			snap_from_flip = router.body_flip_x
			snap_to_flip = router.target_body_flip_x
			snap_from_head = router.active_head_key
			snap_to_head = router.target_head_key
			snap_from_head_flip = router.head_flip_x
			snap_to_head_flip = router.target_head_flip_x
			snap_turn_dir = (-1.0 if snap_to_flip else 1.0) if (snap_to_flip != snap_from_flip) else (-1.0 if snap_to_view == "n" else 1.0)
			events["started_snap"] = true
		elif head_changed:
			head_micro_snap_active = true
			head_micro_snap_t = 0.0
			head_micro_snap_scale = Vector2(0.89, 1.07)
			head_micro_turn_dir = (-1.0 if router.target_head_flip_x else 1.0) if (router.target_head_flip_x != router.head_flip_x) else (-1.0 if router.target_head_key.ends_with("_l") else 1.0)
			events["head_micro_snap"] = true
			events["head_turn_dir"] = head_micro_turn_dir
	else:
		snap_to_view = router.target_view_key
		snap_to_flip = router.target_body_flip_x
		snap_to_head = router.target_head_key
		snap_to_head_flip = router.target_head_flip_x
		var dur: float = 0.115 if transition_style == TransitionStyle.WHIP_SNAP_AFTERIMAGE else (0.095 if transition_style == TransitionStyle.MICRO_FLASH_SNAP else 0.110)
		var swap_pt: float = 0.35 if transition_style == TransitionStyle.WHIP_SNAP_AFTERIMAGE else (0.18 if transition_style == TransitionStyle.MICRO_FLASH_SNAP else 0.45)
		snap_t += delta / dur
		if not snap_swapped and snap_t >= swap_pt:
			snap_swapped = true
			if transition_style == TransitionStyle.WHIP_SNAP_AFTERIMAGE:
				events["spawn_afterimage"] = true
			router.active_view_key = snap_to_view
			router.body_flip_x = snap_to_flip
			events["body_swapped"] = true
			if not defer_head_to_clock:
				router.active_head_key = snap_to_head
				router.head_flip_x = snap_to_head_flip
			events["turn_bone_kick"] = snap_turn_dir * 0.28
		if snap_t >= 1.0:
			snap_t = 1.0
			snap_active = false
			router.active_view_key = router.target_view_key
			router.body_flip_x = router.target_body_flip_x
			if not defer_head_to_clock:
				router.active_head_key = router.target_head_key
				router.head_flip_x = router.target_head_flip_x

	if not defer_head_to_clock and not snap_active and head_changed:
		router.active_head_key = router.target_head_key
		router.head_flip_x = router.target_head_flip_x

	return events


func apply_visual_state(
	body_pivot: Node2D,
	views: Dictionary,
	foreshorten_scale: Vector2,
	router: PlanarRigViewRouter,
	head_data: Dictionary,
	head_under_data: Dictionary
) -> void:
	if body_pivot == null:
		return
	var b_curve: Dictionary = compute_snap_curve(transition_style, snap_t) if snap_active else {"scale": Vector2.ONE, "fx_mode": 0, "fx_str": 0.0, "holo_pos": -1.0}
	snap_scale_xy = b_curve["scale"] as Vector2
	var b_fx_mode: int = int(b_curve["fx_mode"])
	var b_fx_str: float = float(b_curve["fx_str"])
	var b_holo_pos: float = float(b_curve["holo_pos"])
	var b_holo_dir: Vector2 = Vector2(snap_turn_dir * 0.92, 0.38).normalized()

	body_pivot.scale = Vector2(snap_scale_xy.x * foreshorten_scale.x, snap_scale_xy.y * foreshorten_scale.y)

	var is_body_holo_split: bool = (transition_style == TransitionStyle.HOLO_SNAP_FAST and snap_active and snap_from_view != snap_to_view)
	for v_key: String in views.keys():
		var vd: Dictionary = views[v_key] as Dictionary
		var v_root: Node2D = vd["root"] as Node2D
		v_root.self_modulate = Color(1.0, 1.0, 1.0, 1.0)
		var view_vis: bool = (v_key == router.active_view_key)
		var view_flip: bool = router.body_flip_x
		var keep_side: float = 0.0
		if is_body_holo_split:
			if v_key == snap_from_view:
				view_vis = true
				view_flip = snap_from_flip
				keep_side = 1.0
			elif v_key == snap_to_view:
				view_vis = true
				view_flip = snap_to_flip
				keep_side = -1.0
			else:
				view_vis = false
		var flip_s: float = -1.0 if view_flip else 1.0
		v_root.visible = view_vis
		v_root.scale.x = flip_s
		for mat: ShaderMaterial in (vd["materials"] as Array):
			mat.set_shader_parameter("normal_flip_x", flip_s)
			mat.set_shader_parameter("transition_fx_mode", b_fx_mode if snap_active else 0)
			mat.set_shader_parameter("transition_fx_strength", b_fx_str)
			mat.set_shader_parameter("transition_turn_dir", snap_turn_dir)
			mat.set_shader_parameter("holo_sweep_dir", b_holo_dir)
			mat.set_shader_parameter("holo_sweep_pos", b_holo_pos)
			mat.set_shader_parameter("holo_keep_side", keep_side)

	var is_head_holo_split: bool = (transition_style == TransitionStyle.HOLO_SNAP_FAST and snap_active and (snap_from_head != snap_to_head or snap_from_head_flip != snap_to_head_flip))
	for h_dict: Dictionary in [head_data, head_under_data]:
		if h_dict.is_empty():
			continue
		var sprites: Dictionary = h_dict.get("sprites", {}) as Dictionary
		for h_key: String in sprites.keys():
			var spr: Sprite2D = sprites[h_key] as Sprite2D
			spr.modulate.a = 1.0
			var h_vis: bool = (h_key == router.active_head_key)
			var h_keep: float = 0.0
			var h_flip: bool = router.head_flip_x
			if is_head_holo_split:
				if snap_from_head != snap_to_head:
					if h_key == snap_from_head:
						h_vis = true
						h_keep = 1.0
						h_flip = snap_from_head_flip
					elif h_key == snap_to_head:
						h_vis = true
						h_keep = -1.0
						h_flip = snap_to_head_flip
					else:
						h_vis = false
				elif h_key == snap_to_head:
					h_vis = true
					h_keep = 0.0
					h_flip = snap_to_head_flip if snap_swapped else snap_from_head_flip
			spr.visible = h_vis
			var smat: ShaderMaterial = spr.material as ShaderMaterial
			if smat != null:
				smat.set_shader_parameter("normal_flip_x", -1.0 if h_flip else 1.0)
				smat.set_shader_parameter("transition_fx_mode", b_fx_mode if snap_active else 0)
				smat.set_shader_parameter("transition_fx_strength", b_fx_str)
				smat.set_shader_parameter("transition_turn_dir", snap_turn_dir)
				smat.set_shader_parameter("holo_sweep_dir", b_holo_dir)
				smat.set_shader_parameter("holo_sweep_pos", b_holo_pos)
				smat.set_shader_parameter("holo_keep_side", h_keep)


func is_head_holo_split_active() -> bool:
	return transition_style == TransitionStyle.HOLO_SNAP_FAST and snap_active and (snap_from_head != snap_to_head or snap_from_head_flip != snap_to_head_flip)


func get_pass2_fx_params() -> Dictionary:
	if not snap_active:
		return {
			"smear_strength": 0.0,
			"smear_dir": Vector2(snap_turn_dir, 0.0),
			"holo_pos": -1.0,
			"holo_strength": 0.0,
			"holo_dir": Vector2(0.22, 0.92),
		}
	var b_curve: Dictionary = compute_snap_curve(transition_style, snap_t)
	var pass2_smear: float = float(b_curve.get("pass2_smear_str", 0.0))
	var holo_dir: Vector2 = Vector2(snap_turn_dir * 0.92, 0.38).normalized()
	return {
		"smear_strength": pass2_smear,
		"smear_dir": Vector2(snap_turn_dir, 0.0),
		"holo_pos": -1.0,
		"holo_strength": 0.0,
		"holo_dir": holo_dir,
	}

class_name PetOrbit3DController
extends Node2D

## Controlador modular de órbita 3D elíptica inclinada alrededor de un nodo ancla.
## Gestiona profundidad Z real (detrás/delante del jugador), fetch demo y escalas.

const RigScene: PackedScene = preload("res://scenes/pets/rig/pet_bubble_rig_25d.tscn")

enum LabMode {
	ORBIT_3D,
	CLOSEUP_HERO,
	FETCH_DEMO,
	INGAME_SCALE,
}

@export var anchor_node: Node2D
@export var fetch_target_node: Node2D
@export var show_orbit_guide: bool = true

var _configs: Array[PetBubbleVisualConfig] = []
var _rigs: Array[PetBubbleRig25D] = []
var _mode: LabMode = LabMode.ORBIT_3D
var _orbit_angle: float = 0.0
var _tilt_deg_override: float = 22.0
var _scale_mult: float = 1.0
var _sun_dir_3d: Vector3 = Vector3(-0.48, 0.68, 0.55).normalized()

# Estado compartido de runtime HUD
var _opacity_mult: float = 1.0
var _spin_mult: float = 1.0
var _fresnel_mult: float = 1.0
var _normal_strength_override: float = -1.0
var _edge_tex_opacity_override: float = -1.0
var _bubble_bump_override: float = -1.0
var _show_back: bool = true
var _show_pet: bool = true
var _show_front: bool = true
var _show_particles: bool = true
var _debug_mode: int = 0
var _auto_gestures_enabled: bool = true

# Estado Fetch Demo
var _fetch_progress: float = 0.0
var _fetch_returning: bool = false
var _fetch_origin: Vector2 = Vector2.ZERO
var _last_positions: Array[Vector2] = []


func set_pets(p_configs: Array[PetBubbleVisualConfig]) -> void:
	_configs = p_configs.duplicate()
	for r: PetBubbleRig25D in _rigs:
		if is_instance_valid(r):
			r.queue_free()
	_rigs.clear()
	_last_positions.clear()

	for cfg: PetBubbleVisualConfig in _configs:
		var rig: PetBubbleRig25D = RigScene.instantiate() as PetBubbleRig25D
		add_child(rig)
		rig.apply_config(cfg)
		_rigs.append(rig)
		_last_positions.append(rig.global_position)

	_apply_rig_settings()
	step_orbit(0.016)


func set_mode(p_mode: LabMode) -> void:
	_mode = p_mode
	_fetch_progress = 0.0
	_fetch_returning = false
	if not _rigs.is_empty():
		_fetch_origin = _rigs[0].global_position
	_apply_rig_settings()
	queue_redraw()


func get_mode() -> LabMode:
	return _mode


func get_rigs() -> Array[PetBubbleRig25D]:
	return _rigs


func set_sun_direction(dir_3d: Vector3) -> void:
	if dir_3d.length_squared() > 0.0001:
		_sun_dir_3d = dir_3d.normalized()


func set_orbit_tilt_deg(deg: float) -> void:
	_tilt_deg_override = clampf(deg, -65.0, 65.0)
	queue_redraw()


func set_scale_multiplier(mult: float) -> void:
	_scale_mult = clampf(mult, 0.3, 2.5)
	_apply_rig_settings()


func set_runtime_overrides(
	opacity_mult: float,
	spin_mult: float,
	fresnel_mult: float,
	normal_strength: float,
	edge_tex_opacity: float = -1.0,
	bubble_bump: float = -1.0
) -> void:
	_opacity_mult = opacity_mult
	_spin_mult = spin_mult
	_fresnel_mult = fresnel_mult
	_normal_strength_override = normal_strength
	_edge_tex_opacity_override = edge_tex_opacity
	_bubble_bump_override = bubble_bump
	_apply_rig_settings()


func set_layer_visibility(show_back: bool, show_pet: bool, show_front: bool, show_particles: bool) -> void:
	_show_back = show_back
	_show_pet = show_pet
	_show_front = show_front
	_show_particles = show_particles
	_apply_rig_settings()


func set_pet_debug_mode(mode: int) -> void:
	_debug_mode = mode
	_apply_rig_settings()


func set_auto_gestures_enabled(enabled: bool) -> void:
	_auto_gestures_enabled = enabled
	_apply_rig_settings()


func trigger_emote_all(kind: StringName) -> void:
	for r: PetBubbleRig25D in _rigs:
		if is_instance_valid(r):
			r.trigger_emote(kind)


func _apply_rig_settings() -> void:
	var target_diam: float = 152.0
	match _mode:
		LabMode.CLOSEUP_HERO:
			target_diam = 320.0
		LabMode.INGAME_SCALE:
			target_diam = 64.0
		_:
			target_diam = 148.0 * _scale_mult

	for r: PetBubbleRig25D in _rigs:
		if not is_instance_valid(r):
			continue
		r.set_bubble_diameter_px(target_diam)
		r.set_runtime_overrides(_opacity_mult, _spin_mult, _fresnel_mult, _normal_strength_override, _edge_tex_opacity_override, _bubble_bump_override)
		r.set_layer_visibility(_show_back, _show_pet, _show_front, _show_particles)
		r.set_pet_debug_mode(_debug_mode)
		r.set_auto_gestures_enabled(_auto_gestures_enabled)


func _process(delta: float) -> void:
	step_orbit(delta)


func step_orbit(delta: float) -> void:
	if _rigs.is_empty():
		return

	var center: Vector2 = anchor_node.global_position if is_instance_valid(anchor_node) else global_position
	var anchor_z: int = anchor_node.z_index if is_instance_valid(anchor_node) else 10
	var count: int = _rigs.size()

	var base_speed: float = _configs[0].orbit_speed if not _configs.is_empty() else 1.45
	_orbit_angle = wrapf(_orbit_angle + base_speed * delta, 0.0, TAU)

	var tilt_rad: float = deg_to_rad(_tilt_deg_override)
	var cos_tilt: float = cos(tilt_rad)
	var sin_tilt: float = sin(tilt_rad)

	for i: int in range(count):
		var rig: PetBubbleRig25D = _rigs[i]
		var cfg: PetBubbleVisualConfig = _configs[i]
		if not is_instance_valid(rig):
			continue

		rig.set_sun_direction(_sun_dir_3d)
		var prev_pos: Vector2 = _last_positions[i]
		var target_pos: Vector2 = center
		var depth_val: float = 1.0
		var scale_factor: float = 1.0

		if _mode == LabMode.CLOSEUP_HERO:
			var spacing: float = 210.0 if count > 1 else 0.0
			var offset_x: float = (float(i) - float(count - 1) * 0.5) * spacing
			target_pos = center + Vector2(offset_x, 0.0)
			depth_val = 1.0
			rig.z_index = anchor_z + 10
		elif _mode == LabMode.FETCH_DEMO and i == 0 and is_instance_valid(fetch_target_node):
			var orbit_pt: Vector2 = _compute_orbit_offset(_orbit_angle, cfg, cos_tilt, sin_tilt) + center
			if not _fetch_returning:
				_fetch_progress = minf(1.0, _fetch_progress + delta * 1.45)
				var ease_t: float = 1.0 - pow(1.0 - _fetch_progress, 2.0)
				target_pos = orbit_pt.lerp(fetch_target_node.global_position, ease_t)
				if _fetch_progress >= 1.0:
					_fetch_returning = true
					rig.trigger_emote(&"bounce")
			else:
				_fetch_progress = maxf(0.0, _fetch_progress - delta * 1.35)
				target_pos = orbit_pt.lerp(fetch_target_node.global_position, _fetch_progress)
				if _fetch_progress <= 0.0:
					_fetch_returning = false
					rig.trigger_emote(&"dash")
			depth_val = 0.9
			rig.z_index = anchor_z + 6
		else:
			var theta: float = _orbit_angle + (TAU * float(i) / float(maxi(1, count)))
			var rx: float = cfg.orbit_radius_x * (1.28 if count > 1 else 1.0)
			var ry: float = cfg.orbit_radius_y * (1.25 if count > 1 else 1.0)
			if _mode == LabMode.INGAME_SCALE:
				rx *= 0.65
				ry *= 0.65

			var px: float = cos(theta) * rx
			var py_flat: float = sin(theta) * ry
			var py: float = py_flat * cos_tilt + px * sin_tilt * 0.28
			depth_val = sin(theta)

			target_pos = center + Vector2(px, py)
			var t_depth: float = (depth_val + 1.0) * 0.5
			scale_factor = lerpf(cfg.back_scale, cfg.front_scale, t_depth)
			rig.z_index = (anchor_z + 5) if depth_val >= 0.0 else (anchor_z - 5)

		rig.global_position = target_pos
		rig.scale = Vector2(scale_factor, scale_factor)
		rig.set_orbit_depth(depth_val)

		var vel: Vector2 = (target_pos - prev_pos) / maxf(delta, 0.001)
		rig.set_velocity_hint(vel)
		_last_positions[i] = target_pos

	queue_redraw()


func _compute_orbit_offset(theta: float, cfg: PetBubbleVisualConfig, cos_tilt: float, sin_tilt: float) -> Vector2:
	var px: float = cos(theta) * cfg.orbit_radius_x
	var py_flat: float = sin(theta) * cfg.orbit_radius_y
	var py: float = py_flat * cos_tilt + px * sin_tilt * 0.28
	return Vector2(px, py)


func _draw() -> void:
	if not show_orbit_guide or _configs.is_empty():
		return
	if _mode == LabMode.CLOSEUP_HERO:
		return

	var center: Vector2 = to_local(anchor_node.global_position) if is_instance_valid(anchor_node) else Vector2.ZERO
	var cfg: PetBubbleVisualConfig = _configs[0]
	var count: int = _rigs.size()
	var rx: float = cfg.orbit_radius_x * (1.28 if count > 1 else 1.0)
	var ry: float = cfg.orbit_radius_y * (1.25 if count > 1 else 1.0)
	if _mode == LabMode.INGAME_SCALE:
		rx *= 0.65
		ry *= 0.65

	var tilt_rad: float = deg_to_rad(_tilt_deg_override)
	var cos_tilt: float = cos(tilt_rad)
	var sin_tilt: float = sin(tilt_rad)
	var segs: int = 64

	for s: int in range(segs):
		var a0: float = TAU * float(s) / float(segs)
		var a1: float = TAU * float(s + 1) / float(segs)
		var p0 := center + Vector2(cos(a0) * rx, sin(a0) * ry * cos_tilt + cos(a0) * rx * sin_tilt * 0.28)
		var p1 := center + Vector2(cos(a1) * rx, sin(a1) * ry * cos_tilt + cos(a1) * rx * sin_tilt * 0.28)
		var is_front: bool = sin((a0 + a1) * 0.5) >= 0.0
		if not is_front and s % 2 == 1:
			continue
		var col: Color = cfg.rim_color
		col.a = 0.42 if is_front else 0.16
		draw_line(p0, p1, col, 1.8 if is_front else 1.2, true)

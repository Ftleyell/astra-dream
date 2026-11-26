class_name PetBubble3D
extends Node3D

## Renderizador 3D nativo de burbuja esférica real (SphereMesh doble capa rotatoria)
## con mascota 2D cel-shaded normal-mapped suspendida en el centro para el Hub 3D.

const SphereSpatialShader: Shader = preload("res://scenes/pets/shaders/pet_bubble_sphere_spatial_3d.gdshader")
const PetSpatialShader: Shader = preload("res://scenes/pets/shaders/pet_sprite_cel_spatial_3d.gdshader")

const CUTE_GESTURES: Array[StringName] = [&"roll_360", &"wiggle", &"hop", &"curious_tilt"]

var _pet_id: StringName = &"mochi"
var _config: PetBubbleVisualConfig = null
var _radius_m: float = 0.42
var _active_skin_id: String = ""
var _active_skin_stars: int = 1
var _low_quality_mode: bool = false

var _sphere_pivot: Node3D = null
var _back_sphere: MeshInstance3D = null
var _front_sphere: MeshInstance3D = null
var _pet_quad: MeshInstance3D = null

var _back_mat: ShaderMaterial = null
var _front_mat: ShaderMaterial = null
var _pet_mat: ShaderMaterial = null

var _velocity_hint_3d: Vector3 = Vector3.ZERO
var _float_time: float = 0.0
var _sun_dir_3d: Vector3 = Vector3(-0.48, 0.68, 0.55).normalized()

var _auto_gestures_enabled: bool = true
var _active_gesture: StringName = &""
var _gesture_timer: float = 0.0
var _gesture_duration: float = 0.8
var _gesture_sign: float = 1.0
var _next_gesture_timer: float = 2.8

var _squash_vec: Vector2 = Vector2.ONE
var _squash_vel: Vector2 = Vector2.ZERO
var _planar_spin_angle: float = 0.0
var _facing_dir: float = 1.0
var _facing_scale_x: float = 1.0
var _flip_active: bool = false
var _flip_progress: float = 0.0
var _flip_start_scale_x: float = 1.0
var _flip_target_dir: float = 1.0
var _flip_flash_strength: float = 0.0


func _ready() -> void:
	_ensure_nodes()
	_sync_quality_from_settings()


func _sync_quality_from_settings() -> void:
	var sm: Node = get_node_or_null("/root/SettingsManager")
	if sm != null and "space_background_quality" in sm:
		set_low_quality_mode(int(sm.get("space_background_quality")) == 0)


func set_low_quality_mode(enabled: bool) -> void:
	_low_quality_mode = enabled
	for mat: ShaderMaterial in [_back_mat, _front_mat]:
		if mat != null:
			mat.set_shader_parameter("low_quality_mode", _low_quality_mode)


func _ensure_nodes() -> void:
	if _sphere_pivot != null:
		return

	_sphere_pivot = Node3D.new()
	_sphere_pivot.name = "SpherePivot"
	add_child(_sphere_pivot)

	_back_mat = ShaderMaterial.new()
	_back_mat.shader = SphereSpatialShader
	_back_mat.render_priority = 1
	_back_mat.set_shader_parameter("is_front_shell", false)
	_back_mat.set_shader_parameter("low_quality_mode", _low_quality_mode)

	_front_mat = ShaderMaterial.new()
	_front_mat.shader = SphereSpatialShader
	_front_mat.render_priority = 3
	_front_mat.set_shader_parameter("is_front_shell", true)
	_front_mat.set_shader_parameter("low_quality_mode", _low_quality_mode)

	_pet_mat = ShaderMaterial.new()
	_pet_mat.shader = PetSpatialShader
	_pet_mat.render_priority = 2

	_back_sphere = MeshInstance3D.new()
	_back_sphere.name = "BackSphere"
	_back_sphere.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_back_sphere.material_override = _back_mat
	_sphere_pivot.add_child(_back_sphere)

	_front_sphere = MeshInstance3D.new()
	_front_sphere.name = "FrontSphere"
	_front_sphere.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_front_sphere.material_override = _front_mat
	_sphere_pivot.add_child(_front_sphere)

	_pet_quad = MeshInstance3D.new()
	_pet_quad.name = "PetQuad"
	_pet_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_pet_quad.material_override = _pet_mat
	add_child(_pet_quad)

	_rebuild_meshes()


func _rebuild_meshes() -> void:
	if _back_sphere != null:
		var back_m := SphereMesh.new()
		back_m.radius = _radius_m * 0.985
		back_m.height = _radius_m * 1.97
		back_m.radial_segments = 32
		back_m.rings = 16
		_back_sphere.mesh = back_m

	if _front_sphere != null:
		var front_m := SphereMesh.new()
		front_m.radius = _radius_m
		front_m.height = _radius_m * 2.0
		front_m.radial_segments = 32
		front_m.rings = 16
		_front_sphere.mesh = front_m

	if _pet_quad != null:
		var pet_fill: float = _config.pet_scale if _config != null else 0.78
		var side: float = _radius_m * 2.0 * (pet_fill + 0.04)
		var qm := QuadMesh.new()
		qm.size = Vector2(side, side)
		_pet_quad.mesh = qm


func setup_pet(pet_id: StringName, radius_m: float = 0.42) -> void:
	_pet_id = pet_id
	_radius_m = maxf(0.12, radius_m)
	_ensure_nodes()
	_sync_quality_from_settings()

	_config = PetBubbleRegistry.get_config(pet_id)
	_rebuild_meshes()

	if _config != null:
		_auto_gestures_enabled = _config.auto_gestures_enabled
		_next_gesture_timer = randf_range(_config.gesture_interval_min, _config.gesture_interval_max)

		var pid: String = String(_config.pet_id).to_lower()
		var base_dir: String = "res://assets/pets/bubble_v2/%s" % pid
		var albedo_tex: Texture2D = PetBubbleRig25D._load_tex_safe(_config.albedo_texture, "%s/pet_%s_albedo.png" % [base_dir, pid])
		var normal_tex: Texture2D = PetBubbleRig25D._load_tex_safe(_config.normal_texture, "%s/pet_%s_normal.png" % [base_dir, pid])
		var bubble_tex: Texture2D = PetBubbleRig25D._load_tex_safe(_config.bubble_texture, "%s/pet_%s_bubble_tex.png" % [base_dir, pid])

		for mat: ShaderMaterial in [_back_mat, _front_mat]:
			if mat == null:
				continue
			mat.set_shader_parameter("bubble_tex", bubble_tex)
			mat.set_shader_parameter("theme_color", _config.theme_color)
			mat.set_shader_parameter("rim_color", _config.rim_color)
			mat.set_shader_parameter("inner_glow_color", _config.inner_glow_color)
			mat.set_shader_parameter("edge_texture_opacity", _config.edge_texture_opacity)
			mat.set_shader_parameter("texture_strength", _config.texture_strength)
			mat.set_shader_parameter("glass_refraction", _config.glass_refraction)
			mat.set_shader_parameter("bubble_bump_strength", _config.bubble_bump_strength)
			mat.set_shader_parameter("caustic_strength", _config.caustic_strength)
			mat.set_shader_parameter("rim_bevel_darkness", _config.rim_bevel_darkness)
			mat.set_shader_parameter("fresnel_power", _config.fresnel_power)
			mat.set_shader_parameter("fresnel_strength", _config.fresnel_strength)
			mat.set_shader_parameter("iridescence_strength", _config.iridescence_strength)
			mat.set_shader_parameter("specular_strength", _config.specular_strength)
			mat.set_shader_parameter("sun_dir_3d", _sun_dir_3d)
		if _back_mat != null:
			_back_mat.set_shader_parameter("shell_opacity", _config.back_opacity)
		if _front_mat != null:
			_front_mat.set_shader_parameter("shell_opacity", _config.front_opacity)

		if _pet_mat != null:
			_pet_mat.set_shader_parameter("albedo_tex", albedo_tex)
			_pet_mat.set_shader_parameter("normal_map", normal_tex)
			_pet_mat.set_shader_parameter("normal_strength", _config.pet_normal_strength)
			_pet_mat.set_shader_parameter("shadow_tint", _config.pet_shadow_tint)
			_pet_mat.set_shader_parameter("rim_color", _config.rim_color)
			_pet_mat.set_shader_parameter("rim_strength", _config.pet_rim_strength)
			_pet_mat.set_shader_parameter("wobble_strength", _config.wobble_strength)
			_pet_mat.set_shader_parameter("sun_dir_3d", _sun_dir_3d)

	apply_skin_by_id(_active_skin_id, _active_skin_stars)


func apply_skin_by_id(skin_id: String, stars: int = 1) -> void:
	_active_skin_id = skin_id
	_active_skin_stars = clampi(stars, 1, 3)
	_ensure_nodes()

	var style: Dictionary = PetBubbleRegistry.resolve_skin_style(skin_id, _active_skin_stars)
	var is_active: bool = bool(style.get("active", false))

	var theme_col: Color = style.get("theme_color", _config.theme_color if _config != null else Color.CYAN) as Color
	var rim_col: Color = style.get("rim_color", _config.rim_color if _config != null else Color.WHITE) as Color
	var inner_col: Color = style.get("inner_glow_color", _config.inner_glow_color if _config != null else Color.CYAN) as Color
	var grade_col: Color = style.get("grade_color", Color.WHITE) as Color
	var grade_str: float = float(style.get("grade_strength", 0.0)) if is_active else 0.0
	var star_boost: float = float(style.get("star_boost", 0.0)) if is_active else 0.0
	var tint_str: float = float(style.get("tint_strength", 0.0)) if is_active else 0.0

	for mat: ShaderMaterial in [_back_mat, _front_mat]:
		if mat == null:
			continue
		mat.set_shader_parameter("theme_color", theme_col)
		mat.set_shader_parameter("rim_color", rim_col)
		mat.set_shader_parameter("inner_glow_color", inner_col)
		mat.set_shader_parameter("skin_tint_color", rim_col)
		mat.set_shader_parameter("skin_tint_strength", tint_str)
		mat.set_shader_parameter("skin_star_boost", star_boost)

	if _pet_mat != null:
		_pet_mat.set_shader_parameter("rim_color", rim_col)
		_pet_mat.set_shader_parameter("skin_grade_color", grade_col)
		_pet_mat.set_shader_parameter("skin_grade_strength", grade_str)
		_pet_mat.set_shader_parameter("skin_star_boost", star_boost)


func set_velocity_hint_3d(vel: Vector3) -> void:
	_velocity_hint_3d = vel


func set_sun_direction(dir_3d: Vector3) -> void:
	if dir_3d.length_squared() > 0.0001:
		_sun_dir_3d = dir_3d.normalized()
		for mat: ShaderMaterial in [_back_mat, _front_mat, _pet_mat]:
			if mat != null:
				mat.set_shader_parameter("sun_dir_3d", _sun_dir_3d)


func trigger_emote(kind: StringName = &"hop") -> void:
	match kind:
		&"bounce", &"hop":
			_start_gesture(&"hop", 0.68)
		&"roll_360":
			_start_gesture(&"roll_360", 0.78)
		&"wiggle":
			_start_gesture(&"wiggle", 0.72)
		&"curious_tilt":
			_start_gesture(&"curious_tilt", 1.15)
		&"flip":
			_facing_dir = -_facing_dir
			_flip_active = true
			_flip_progress = 0.0
			_flip_start_scale_x = _facing_scale_x
			_flip_target_dir = _facing_dir
			_squash_vec = Vector2(0.84, 1.18)


func _start_gesture(kind: StringName, duration: float) -> void:
	_active_gesture = kind
	_gesture_timer = 0.0
	_gesture_duration = maxf(0.2, duration)
	_gesture_sign = 1.0 if randf() >= 0.5 else -1.0


func get_pet_id() -> StringName:
	return _pet_id


func get_active_skin_id() -> String:
	return _active_skin_id


func get_sphere_pivot() -> Node3D:
	return _sphere_pivot


func get_active_gesture() -> StringName:
	return _active_gesture


func _process(delta: float) -> void:
	step_animation(delta)


func step_animation(delta: float) -> void:
	_float_time += delta

	# Rotación 3D real de la malla esférica + torque proporcional a velocidad
	if _sphere_pivot != null:
		var spin_cfg: Vector3 = _config.bubble_spin_speed if _config != null else Vector3(0.22, 0.65, 0.12)
		var torque := Vector3(-_velocity_hint_3d.z * 0.45, _velocity_hint_3d.x * 0.55, 0.0)
		_sphere_pivot.rotation += (spin_cfg + torque) * delta

	if _flip_active:
		var flip_dur: float = maxf(0.08, _config.flip_duration if _config != null else 0.22)
		_flip_progress = minf(1.0, _flip_progress + delta / flip_dur)
		var smooth_t: float = _flip_progress * _flip_progress * (3.0 - 2.0 * _flip_progress)
		_facing_scale_x = lerpf(_flip_start_scale_x, _flip_target_dir, smooth_t)
		_flip_flash_strength = pow(sin(_flip_progress * PI), 1.35) * (_config.flip_flash_intensity if _config != null else 1.15)
		if _flip_progress >= 1.0:
			_flip_active = false
			_facing_scale_x = _flip_target_dir
			_flip_flash_strength = 0.0
			_squash_vec = Vector2(1.16, 0.88)
	else:
		_facing_scale_x = lerpf(_facing_scale_x, _facing_dir, minf(1.0, delta * 12.0))
		_flip_flash_strength = maxf(0.0, _flip_flash_strength - delta * 6.0)

	if _active_gesture.is_empty() and _auto_gestures_enabled:
		_next_gesture_timer -= delta
		if _next_gesture_timer <= 0.0:
			var pick: StringName = CUTE_GESTURES[randi() % CUTE_GESTURES.size()]
			trigger_emote(pick)
			var min_i: float = _config.gesture_interval_min if _config != null else 2.6
			var max_i: float = _config.gesture_interval_max if _config != null else 5.2
			_next_gesture_timer = randf_range(min_i, max_i)

	var gesture_offset_y: float = 0.0
	var gesture_rot: float = 0.0
	var gesture_scale := Vector2.ONE
	if not _active_gesture.is_empty():
		_gesture_timer += delta
		var t: float = clampf(_gesture_timer / _gesture_duration, 0.0, 1.0)
		match _active_gesture:
			&"roll_360":
				var ease_t: float = t * t * (3.0 - 2.0 * t)
				gesture_rot = _gesture_sign * TAU * ease_t
				var pop: float = sin(t * PI) * 0.10
				gesture_scale = Vector2(1.0 + pop, 1.0 - pop * 0.6)
			&"wiggle":
				var decay: float = 1.0 - t
				gesture_rot = sin(t * TAU * 3.0) * 0.34 * decay * _gesture_sign
				var stretch: float = absf(sin(t * TAU * 1.5)) * 0.12 * decay
				gesture_scale = Vector2(1.0 - stretch * 0.6, 1.0 + stretch)
			&"hop":
				if t < 0.22:
					var st: float = t / 0.22
					gesture_scale = Vector2(1.0 + 0.18 * st, 1.0 - 0.16 * st)
					gesture_offset_y = -0.025 * st
				else:
					var jt: float = (t - 0.22) / 0.78
					var arc: float = sin(jt * PI)
					gesture_offset_y = 0.065 * arc
					gesture_rot = _gesture_sign * 0.22 * arc
					gesture_scale = Vector2(1.0 - 0.08 * arc, 1.0 + 0.12 * arc)
			&"curious_tilt":
				var hold: float = sin(t * PI)
				gesture_rot = _gesture_sign * 0.42 * pow(hold, 0.65)
				gesture_scale = Vector2(1.0 + 0.04 * hold, 1.0 + 0.04 * hold)

		if t >= 1.0:
			if _active_gesture == &"roll_360" or _active_gesture == &"hop":
				_squash_vec = Vector2(1.16, 0.86)
			_active_gesture = &""

	var target_planar_tilt: float = clampf(-_velocity_hint_3d.x * 0.06, -0.28, 0.28)
	_planar_spin_angle = lerpf(_planar_spin_angle, target_planar_tilt, minf(1.0, delta * 7.5))

	var spring_force: Vector2 = (Vector2.ONE - _squash_vec) * 140.0
	_squash_vel = (_squash_vel + spring_force * delta) * exp(-delta * 12.0)
	_squash_vec += _squash_vel * delta

	var bob_spd: float = _config.bob_speed if _config != null else 3.2
	var idle_bob: float = sin(_float_time * bob_spd) * 0.024
	var idle_sway: float = sin(_float_time * (bob_spd * 0.65)) * 0.10

	if _pet_quad != null:
		_pet_quad.position = Vector3(0.0, idle_bob + gesture_offset_y, 0.0)

	if _pet_mat != null:
		_pet_mat.set_shader_parameter("planar_roll_rad", idle_sway + _planar_spin_angle + gesture_rot)
		_pet_mat.set_shader_parameter("squash_xy", _squash_vec * gesture_scale)
		_pet_mat.set_shader_parameter("flip_x_scale", _facing_scale_x)
		_pet_mat.set_shader_parameter("flip_flash", _flip_flash_strength)
		_pet_mat.set_shader_parameter("wobble_time", _float_time)

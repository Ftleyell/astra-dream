class_name PetBubbleRig25D
extends Node2D

## Rig modular de producción para una mascota 2D con normal map dentro de una
## burbuja esférica 3D de doble capa, skins 100% por shader y gestos en Zero-G.

const SphereShader: Shader = preload("res://scenes/pets/shaders/pet_bubble_sphere_3d.gdshader")
const PetCelShader: Shader = preload("res://scenes/pets/shaders/pet_sprite_cel_normal.gdshader")
const FlipGlintShader: Shader = preload("res://scenes/pets/shaders/pet_flip_glint.gdshader")

const CUTE_GESTURES: Array[StringName] = [&"roll_360", &"wiggle", &"hop", &"curious_tilt"]

@export var config: PetBubbleVisualConfig
@export var base_diameter_px: float = 160.0

@onready var back_shell: ColorRect = $BackShell
@onready var inner_particles: CPUParticles2D = $InnerParticles
@onready var pet_pivot: Node2D = $PetPivot
@onready var pet_sprite: Sprite2D = $PetPivot/PetSprite
@onready var flip_glint: ColorRect = get_node_or_null("FlipGlint") as ColorRect
@onready var front_shell: ColorRect = $FrontShell

var _back_mat: ShaderMaterial = null
var _front_mat: ShaderMaterial = null
var _pet_mat: ShaderMaterial = null
var _glint_mat: ShaderMaterial = null

var _rot_3d: Vector3 = Vector3.ZERO
var _sun_dir_3d: Vector3 = Vector3(-0.48, 0.68, 0.55).normalized()
var _orbit_depth: float = 1.0
var _velocity_hint: Vector2 = Vector2.ZERO
var _pet_lag_offset: Vector2 = Vector2.ZERO
var _float_time: float = 0.0
var _squash_vec: Vector2 = Vector2.ONE
var _squash_vel: Vector2 = Vector2.ZERO

# Estado de giro 2.5D (escaso y ocultado por destello)
var _facing_dir: float = 1.0
var _facing_scale_x: float = 1.0
var _flip_active: bool = false
var _flip_progress: float = 0.0
var _flip_start_scale_x: float = 1.0
var _flip_target_dir: float = 1.0
var _flip_cooldown_timer: float = 0.0
var _opposite_vel_hold: float = 0.0
var _flip_flash_strength: float = 0.0
var _flip_count: int = 0
var _flip_spin_kick: float = 0.0
var _glint_spin_angle: float = 0.0

# Estado de gestos simpáticos y giros planos 2D
var _auto_gestures_enabled: bool = true
var _active_gesture: StringName = &""
var _gesture_timer: float = 0.0
var _gesture_duration: float = 0.8
var _gesture_sign: float = 1.0
var _next_gesture_timer: float = 2.8
var _planar_spin_angle: float = 0.0

# Skins 100% por shader & calidad GPU
var _active_skin_id: String = ""
var _active_skin_stars: int = 1
var _is_locked_dim: bool = false
var _low_quality_mode: bool = false

# Overrides en tiempo real
var _opacity_mult: float = 1.0
var _spin_mult: float = 1.0
var _fresnel_mult: float = 1.0
var _normal_strength_override: float = -1.0
var _edge_texture_opacity_override: float = -1.0
var _bubble_bump_strength_override: float = -1.0
var _debug_mode: int = 0


func _ready() -> void:
	_ensure_materials()
	_sync_quality_from_settings()
	_update_shell_geometry(base_diameter_px)
	if config != null:
		apply_config(config)


func _sync_quality_from_settings() -> void:
	var sm: Node = get_node_or_null("/root/SettingsManager")
	if sm != null:
		if "space_background_quality" in sm:
			set_low_quality_mode(int(sm.get("space_background_quality")) == 0)
		if sm.has_signal("settings_changed"):
			var cb := Callable(self, "_on_settings_changed")
			if not sm.is_connected("settings_changed", cb):
				sm.connect("settings_changed", cb)


func _on_settings_changed() -> void:
	var sm: Node = get_node_or_null("/root/SettingsManager")
	if sm != null and "space_background_quality" in sm:
		set_low_quality_mode(int(sm.get("space_background_quality")) == 0)


func set_low_quality_mode(enabled: bool) -> void:
	_low_quality_mode = enabled
	for mat: ShaderMaterial in [_back_mat, _front_mat]:
		if mat != null:
			mat.set_shader_parameter("low_quality_mode", _low_quality_mode)


func _ensure_materials() -> void:
	if _back_mat == null and back_shell != null:
		_back_mat = ShaderMaterial.new()
		_back_mat.shader = SphereShader
		_back_mat.set_shader_parameter("is_front_shell", false)
		_back_mat.set_shader_parameter("low_quality_mode", _low_quality_mode)
		back_shell.material = _back_mat

	if _front_mat == null and front_shell != null:
		_front_mat = ShaderMaterial.new()
		_front_mat.shader = SphereShader
		_front_mat.set_shader_parameter("is_front_shell", true)
		_front_mat.set_shader_parameter("low_quality_mode", _low_quality_mode)
		front_shell.material = _front_mat

	if _pet_mat == null and pet_sprite != null:
		_pet_mat = ShaderMaterial.new()
		_pet_mat.shader = PetCelShader
		pet_sprite.material = _pet_mat

	if _glint_mat == null and flip_glint != null:
		_glint_mat = ShaderMaterial.new()
		_glint_mat.shader = FlipGlintShader
		_glint_mat.set_shader_parameter("flash_progress", 0.0)
		flip_glint.material = _glint_mat


static func _load_tex_safe(tex: Texture2D, fallback_res_path: String) -> Texture2D:
	if tex != null:
		return tex
	if ResourceLoader.exists(fallback_res_path):
		var loaded: Resource = ResourceLoader.load(fallback_res_path)
		if loaded is Texture2D:
			return loaded as Texture2D
	var abs_path: String = ProjectSettings.globalize_path(fallback_res_path)
	if FileAccess.file_exists(abs_path):
		var img := Image.load_from_file(abs_path)
		if img != null and not img.is_empty():
			return ImageTexture.create_from_image(img)
	return null


func apply_config(p_config: PetBubbleVisualConfig) -> void:
	config = p_config
	if config == null:
		return
	_ensure_materials()

	_auto_gestures_enabled = config.auto_gestures_enabled
	_next_gesture_timer = randf_range(config.gesture_interval_min, config.gesture_interval_max)

	var pid: String = String(config.pet_id).to_lower()
	var base_dir: String = "res://assets/pets/bubble_v2/%s" % pid
	var albedo_tex: Texture2D = _load_tex_safe(config.albedo_texture, "%s/pet_%s_albedo.png" % [base_dir, pid])
	var normal_tex: Texture2D = _load_tex_safe(config.normal_texture, "%s/pet_%s_normal.png" % [base_dir, pid])
	var bubble_tex: Texture2D = _load_tex_safe(config.bubble_texture, "%s/pet_%s_bubble_tex.png" % [base_dir, pid])

	if pet_sprite != null:
		pet_sprite.texture = albedo_tex
	_update_shell_geometry(base_diameter_px)

	for mat: ShaderMaterial in [_back_mat, _front_mat]:
		if mat == null:
			continue
		mat.set_shader_parameter("bubble_tex", bubble_tex)
		mat.set_shader_parameter("theme_color", config.theme_color)
		mat.set_shader_parameter("rim_color", config.rim_color)
		mat.set_shader_parameter("inner_glow_color", config.inner_glow_color)
		mat.set_shader_parameter("texture_strength", config.texture_strength)
		mat.set_shader_parameter("glass_refraction", config.glass_refraction)
		mat.set_shader_parameter("caustic_strength", config.caustic_strength)
		mat.set_shader_parameter("rim_bevel_darkness", config.rim_bevel_darkness)
		mat.set_shader_parameter("fresnel_power", config.fresnel_power)
		mat.set_shader_parameter("iridescence_strength", config.iridescence_strength)
		mat.set_shader_parameter("specular_strength", config.specular_strength)

	if _pet_mat != null:
		_pet_mat.set_shader_parameter("normal_map", normal_tex)
		_pet_mat.set_shader_parameter("shadow_tint", config.pet_shadow_tint)
		_pet_mat.set_shader_parameter("rim_color", config.rim_color)
		_pet_mat.set_shader_parameter("rim_strength", config.pet_rim_strength)
		_pet_mat.set_shader_parameter("wobble_strength", config.wobble_strength)

	if _glint_mat != null:
		_glint_mat.set_shader_parameter("rim_color", config.rim_color)
		_glint_mat.set_shader_parameter("flash_intensity", config.flip_flash_intensity)

	if inner_particles != null:
		inner_particles.color = config.rim_color

	apply_skin_by_id(_active_skin_id, _active_skin_stars, _is_locked_dim)
	_sync_dynamic_uniforms()


func apply_skin_by_id(skin_id: String, stars: int = 1, is_locked: bool = false) -> void:
	_active_skin_id = skin_id
	_active_skin_stars = clampi(stars, 1, 3)
	_is_locked_dim = is_locked
	_ensure_materials()

	var style: Dictionary = PetBubbleRegistry.resolve_skin_style(skin_id, _active_skin_stars)
	var is_active: bool = bool(style.get("active", false))

	var theme_col: Color = style.get("theme_color", config.theme_color if config != null else Color.CYAN) as Color
	var rim_col: Color = style.get("rim_color", config.rim_color if config != null else Color.WHITE) as Color
	var inner_col: Color = style.get("inner_glow_color", config.inner_glow_color if config != null else Color.CYAN) as Color
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
		_pet_mat.set_shader_parameter("locked_dim", 0.72 if is_locked else 0.0)

	if _glint_mat != null:
		_glint_mat.set_shader_parameter("rim_color", rim_col)

	if inner_particles != null:
		inner_particles.color = rim_col
		inner_particles.amount = 14 + (int(_active_skin_stars) * 2 if is_active else 0)


func _update_shell_geometry(diameter_px: float) -> void:
	var half: float = diameter_px * 0.5
	var rect_size := Vector2(diameter_px, diameter_px)
	var rect_pos := Vector2(-half, -half)

	if back_shell != null:
		back_shell.position = rect_pos
		back_shell.size = rect_size
	if front_shell != null:
		front_shell.position = rect_pos
		front_shell.size = rect_size
	if flip_glint != null:
		var glint_size: float = diameter_px * 1.15
		var glint_half: float = glint_size * 0.5
		flip_glint.position = Vector2(-glint_half, -glint_half)
		flip_glint.size = Vector2(glint_size, glint_size)

	if inner_particles != null:
		inner_particles.emission_sphere_radius = diameter_px * 0.34
		var p_scale: float = clampf(diameter_px / 140.0, 0.42, 1.45)
		inner_particles.scale_amount_min = 1.6 * p_scale
		inner_particles.scale_amount_max = 3.4 * p_scale

	if pet_sprite != null and pet_sprite.texture != null:
		var tex_max: float = float(maxi(pet_sprite.texture.get_width(), pet_sprite.texture.get_height()))
		var pet_fill: float = config.pet_scale if config != null else 0.78
		var s: float = (diameter_px * pet_fill) / maxf(1.0, tex_max)
		pet_sprite.scale = Vector2(s, s)


func set_bubble_diameter_px(diameter_px: float) -> void:
	base_diameter_px = maxf(24.0, diameter_px)
	_update_shell_geometry(base_diameter_px)


func set_sun_direction(dir_3d: Vector3) -> void:
	if dir_3d.length_squared() > 0.0001:
		_sun_dir_3d = dir_3d.normalized()


func set_orbit_depth(depth: float) -> void:
	_orbit_depth = clampf(depth, -1.0, 1.0)


func get_orbit_depth() -> float:
	return _orbit_depth


func set_velocity_hint(vel_px_per_sec: Vector2) -> void:
	_velocity_hint = vel_px_per_sec


func set_facing_direction(dir_sign: float) -> void:
	var target: float = 1.0 if dir_sign >= 0.0 else -1.0
	if not is_equal_approx(target, _facing_dir):
		flip_facing()


func flip_facing() -> void:
	_facing_dir = -_facing_dir
	_flip_active = true
	_flip_progress = 0.0
	_flip_start_scale_x = _facing_scale_x
	_flip_target_dir = _facing_dir
	_flip_cooldown_timer = config.auto_flip_cooldown if config != null else 2.8
	_flip_spin_kick = -_facing_dir * 0.30
	_glint_spin_angle = randf_range(-0.4, 0.4)
	_flip_count += 1
	_squash_vec = Vector2(0.84, 1.18)


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
		&"dash":
			_squash_vec = Vector2(1.28, 0.76)
			_rot_3d.y += 1.15
			_start_gesture(&"roll_360", 0.62)
		&"flip":
			flip_facing()


func _start_gesture(kind: StringName, duration: float) -> void:
	_active_gesture = kind
	_gesture_timer = 0.0
	_gesture_duration = maxf(0.2, duration)
	_gesture_sign = 1.0 if randf() >= 0.5 else -1.0


func set_auto_gestures_enabled(enabled: bool) -> void:
	_auto_gestures_enabled = enabled


func get_flip_flash_strength() -> float:
	return _flip_flash_strength


func get_active_gesture() -> StringName:
	return _active_gesture


func get_flip_count() -> int:
	return _flip_count


func get_active_skin_id() -> String:
	return _active_skin_id


func set_runtime_overrides(
	opacity_mult: float,
	spin_mult: float,
	fresnel_mult: float,
	normal_strength: float,
	edge_tex_opacity: float = -1.0,
	bubble_bump: float = -1.0
) -> void:
	_opacity_mult = clampf(opacity_mult, 0.0, 2.5)
	_spin_mult = clampf(spin_mult, 0.0, 4.0)
	_fresnel_mult = clampf(fresnel_mult, 0.0, 2.5)
	_normal_strength_override = normal_strength
	_edge_texture_opacity_override = edge_tex_opacity
	_bubble_bump_strength_override = bubble_bump


func set_layer_visibility(show_back: bool, show_pet: bool, show_front: bool, show_particles: bool) -> void:
	if back_shell != null:
		back_shell.visible = show_back
	if pet_pivot != null:
		pet_pivot.visible = show_pet
	if front_shell != null:
		front_shell.visible = show_front
	if inner_particles != null:
		inner_particles.visible = show_particles


func set_pet_debug_mode(mode: int) -> void:
	_debug_mode = clampi(mode, 0, 3)


func _process(delta: float) -> void:
	step_animation(delta)


func step_animation(delta: float) -> void:
	_float_time += delta
	_flip_cooldown_timer = maxf(0.0, _flip_cooldown_timer - delta)

	var flip_threshold: float = config.auto_flip_speed_threshold if config != null else 320.0
	var vel_x: float = _velocity_hint.x
	var wants_opposite: bool = absf(vel_x) > flip_threshold and ((vel_x > 0.0 and _facing_dir < 0.0) or (vel_x < 0.0 and _facing_dir > 0.0))
	if wants_opposite and _flip_cooldown_timer <= 0.0 and not _flip_active:
		_opposite_vel_hold += delta
		if _opposite_vel_hold >= 0.14:
			_opposite_vel_hold = 0.0
			flip_facing()
	else:
		_opposite_vel_hold = 0.0

	var glint_prog: float = 0.0
	if _flip_active:
		var flip_dur: float = maxf(0.08, config.flip_duration if config != null else 0.22)
		_flip_progress = minf(1.0, _flip_progress + delta / flip_dur)
		var smooth_t: float = _flip_progress * _flip_progress * (3.0 - 2.0 * _flip_progress)
		_facing_scale_x = lerpf(_flip_start_scale_x, _flip_target_dir, smooth_t)
		var peak: float = pow(sin(_flip_progress * PI), 1.35)
		var flash_int: float = config.flip_flash_intensity if config != null else 1.15
		_flip_flash_strength = peak * flash_int
		glint_prog = _flip_progress
		_flip_spin_kick = lerpf(_flip_spin_kick, 0.0, minf(1.0, delta * 9.0))
		if _flip_progress >= 1.0:
			_flip_active = false
			_facing_scale_x = _flip_target_dir
			_flip_flash_strength = 0.0
			_flip_spin_kick = 0.0
			_squash_vec = Vector2(1.16, 0.88)
	else:
		_facing_scale_x = lerpf(_facing_scale_x, _facing_dir, minf(1.0, delta * 12.0))
		_flip_flash_strength = maxf(0.0, _flip_flash_strength - delta * 6.0)

	if _active_gesture.is_empty() and _auto_gestures_enabled:
		_next_gesture_timer -= delta
		if _next_gesture_timer <= 0.0:
			var pick: StringName = CUTE_GESTURES[randi() % CUTE_GESTURES.size()]
			trigger_emote(pick)
			var min_i: float = config.gesture_interval_min if config != null else 2.6
			var max_i: float = config.gesture_interval_max if config != null else 5.2
			_next_gesture_timer = randf_range(min_i, max_i)

	var gesture_offset := Vector2.ZERO
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
					gesture_offset.y = 6.0 * st
				else:
					var jt: float = (t - 0.22) / 0.78
					var arc: float = sin(jt * PI)
					gesture_offset.y = -15.0 * arc
					gesture_rot = _gesture_sign * 0.22 * arc
					gesture_scale = Vector2(1.0 - 0.08 * arc, 1.0 + 0.12 * arc)
			&"curious_tilt":
				var hold: float = sin(t * PI)
				gesture_rot = _gesture_sign * 0.42 * pow(hold, 0.65)
				gesture_offset.x = _gesture_sign * 4.0 * hold
				gesture_scale = Vector2(1.0 + 0.04 * hold, 1.0 + 0.04 * hold)

		if t >= 1.0:
			if _active_gesture == &"roll_360" or _active_gesture == &"hop":
				_squash_vec = Vector2(1.16, 0.86)
			_active_gesture = &""

	var spin_cfg: Vector3 = config.bubble_spin_speed if config != null else Vector3(0.22, 0.65, 0.12)
	var vel_torque := Vector3(-_velocity_hint.y * 0.0022, _velocity_hint.x * 0.0025, 0.0)
	_rot_3d += (spin_cfg * _spin_mult + vel_torque) * delta

	var roll_bias: float = config.planar_roll_bias if config != null else 0.45
	var target_planar_tilt: float = clampf(_velocity_hint.x * 0.0014 * roll_bias, -0.32, 0.32)
	_planar_spin_angle = lerpf(_planar_spin_angle, target_planar_tilt, minf(1.0, delta * 7.5))

	var max_lag: float = config.max_lag_px if config != null else 10.0
	var stiff: float = config.lag_stiffness if config != null else 10.5
	var target_lag: Vector2 = (-_velocity_hint * 0.032).limit_length(max_lag)
	_pet_lag_offset = _pet_lag_offset.lerp(target_lag, minf(1.0, delta * stiff))

	var spring_force: Vector2 = (Vector2.ONE - _squash_vec) * 140.0
	_squash_vel = (_squash_vel + spring_force * delta) * exp(-delta * 12.0)
	_squash_vec += _squash_vel * delta

	var bob_amp: float = config.bob_amplitude if config != null else 4.5
	var bob_spd: float = config.bob_speed if config != null else 3.2
	if pet_pivot != null:
		var bob_y: float = sin(_float_time * bob_spd) * bob_amp
		var idle_sway: float = sin(_float_time * (bob_spd * 0.65)) * 0.11
		pet_pivot.position = _pet_lag_offset + Vector2(0.0, bob_y) + gesture_offset
		pet_pivot.rotation = idle_sway + _planar_spin_angle + gesture_rot + _flip_spin_kick
		pet_pivot.scale = Vector2(_facing_scale_x * _squash_vec.x * gesture_scale.x, _squash_vec.y * gesture_scale.y)

	_sync_dynamic_uniforms(glint_prog)


func _sync_dynamic_uniforms(glint_prog: float = 0.0) -> void:
	var front_op: float = (config.front_opacity if config != null else 0.34) * _opacity_mult
	var back_op: float = (config.back_opacity if config != null else 0.30) * _opacity_mult
	var fresnel_str: float = (config.fresnel_strength if config != null else 1.05) * _fresnel_mult
	var norm_str: float = _normal_strength_override if _normal_strength_override >= 0.0 else (config.pet_normal_strength if config != null else 1.0)
	var edge_op: float = _edge_texture_opacity_override if _edge_texture_opacity_override >= 0.0 else (config.edge_texture_opacity if config != null else 0.78)
	var bump_str: float = _bubble_bump_strength_override if _bubble_bump_strength_override >= 0.0 else (config.bubble_bump_strength if config != null else 0.30)

	if _back_mat != null:
		_back_mat.set_shader_parameter("rot_x", _rot_3d.x)
		_back_mat.set_shader_parameter("rot_y", _rot_3d.y)
		_back_mat.set_shader_parameter("rot_z", _rot_3d.z)
		_back_mat.set_shader_parameter("shell_opacity", clampf(back_op, 0.0, 1.0))
		_back_mat.set_shader_parameter("edge_texture_opacity", clampf(edge_op, 0.0, 1.0))
		_back_mat.set_shader_parameter("bubble_bump_strength", clampf(bump_str, 0.0, 1.0))
		_back_mat.set_shader_parameter("fresnel_strength", fresnel_str)
		_back_mat.set_shader_parameter("sun_dir_3d", _sun_dir_3d)
		_back_mat.set_shader_parameter("orbit_depth", _orbit_depth)

	if _front_mat != null:
		_front_mat.set_shader_parameter("rot_x", _rot_3d.x)
		_front_mat.set_shader_parameter("rot_y", _rot_3d.y)
		_front_mat.set_shader_parameter("rot_z", _rot_3d.z)
		_front_mat.set_shader_parameter("shell_opacity", clampf(front_op, 0.0, 1.0))
		_front_mat.set_shader_parameter("edge_texture_opacity", clampf(edge_op, 0.0, 1.0))
		_front_mat.set_shader_parameter("bubble_bump_strength", clampf(bump_str, 0.0, 1.0))
		_front_mat.set_shader_parameter("fresnel_strength", fresnel_str)
		_front_mat.set_shader_parameter("sun_dir_3d", _sun_dir_3d)
		_front_mat.set_shader_parameter("orbit_depth", _orbit_depth)

	if _pet_mat != null:
		_pet_mat.set_shader_parameter("sun_dir_3d", _sun_dir_3d)
		_pet_mat.set_shader_parameter("normal_strength", norm_str)
		_pet_mat.set_shader_parameter("flip_x_sign", 1.0 if _facing_scale_x >= 0.0 else -1.0)
		_pet_mat.set_shader_parameter("wobble_time", _float_time)
		_pet_mat.set_shader_parameter("orbit_depth", _orbit_depth)
		_pet_mat.set_shader_parameter("flip_flash", _flip_flash_strength)
		_pet_mat.set_shader_parameter("debug_mode", _debug_mode)

	if _glint_mat != null:
		_glint_mat.set_shader_parameter("flash_progress", glint_prog)
		_glint_mat.set_shader_parameter("spin_angle", _glint_spin_angle)

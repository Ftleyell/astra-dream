class_name HubArtLabPlayer
extends CharacterBody3D

## Controlador híbrido Caminata en Plataforma ↔ Vuelo Zero-G 8-Dir para Estación Astral Flotante.
## - Alinea el sprite 1:1 con cámara Telefoto (-46°, aspect 1.0).
## - Consulta HubFloatingLayoutConfig.is_point_on_platform() para alternar automáticamente
##   entre caminata GROUNDED_HUB (alas plegadas + sombra) y vuelo espacial (SERAPH_BLOOM + alas 3D).

signal traversal_state_changed(is_flying: bool)

const HubRigAvatar3DScript = preload("res://scenes/ui/hub/components/hub_rig_avatar_3d.gd")
const DioramaConfigScript = preload("res://scenes/ui/hub/resources/hub_diorama_config.gd")
const DEFAULT_DIORAMA_CONFIG: DioramaConfigScript = preload("res://data/hub/default_hub_diorama_config.tres")
const LayoutConfigScript = preload("res://scenes/ui/hub/astral_station/resources/hub_floating_layout_config.gd")
const DEFAULT_LAYOUT_CONFIG: LayoutConfigScript = preload("res://data/hub/default_astral_floating_layout.tres")
const SILHOUETTE_SHADOW_SHADER: Shader = preload("res://shaders/character_silhouette_shadow.gdshader")
const CONTACT_SHADOW_SHADER: Shader = preload("res://scenes/ui/hub/astral_station/shaders/hub_contact_shadow_3d.gdshader")
const HubGroundedMotor3DScript = preload("res://scenes/ui/hub/components/hub_grounded_motor_3d.gd")

const FLIGHT_ACCEL: float = 18.0
const FLIGHT_FRICTION: float = 9.0
const SHADOW_ALPHA: float = 0.38
const DEFAULT_LIGHT_DIR := Vector3(-0.353553, -0.707107, -0.612372)

@export var move_speed: float = 6.2
@export var is_movement_locked: bool = false
@export var layout_config: LayoutConfigScript = DEFAULT_LAYOUT_CONFIG

var is_pose_override_active: bool = false
var is_flying_in_space: bool = false
var is_closeup_shadow_suppressed: bool = false
var rig_avatar: HubRigAvatar3DScript = null
var shadow_sprite: Sprite3D = null

var _shadow_mat: ShaderMaterial = null
var _contact_shadow_mesh: MeshInstance3D = null
var _contact_shadow_mat: ShaderMaterial = null
var _facing_dir_2d: Vector2 = Vector2.DOWN
var _directional_light: DirectionalLight3D = null
var _visibility_alpha: float = 1.0
var _shadow_proj_scale: Vector3 = Vector3.ONE
var _grounded_motor: HubGroundedMotor3DScript = null

var _on_platform_raw: bool = true
var _pending_flight_target: bool = false
var _hysteresis_timer: float = 0.0
var _shadow_platform_blend: float = 1.0
var _forced_flight_override: bool = false


func setup(p_move_speed: float, p_light: DirectionalLight3D = null, p_layout: LayoutConfigScript = null) -> void:
	move_speed = p_move_speed
	_directional_light = p_light
	if p_layout != null:
		layout_config = p_layout
	_ensure_setup()


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	floor_max_angle = deg_to_rad(50.0)
	floor_snap_length = 0.35
	floor_constant_speed = true
	floor_stop_on_slope = true
	floor_block_on_wall = true
	_ensure_setup()


func _ensure_setup() -> void:
	if layout_config == null:
		layout_config = DEFAULT_LAYOUT_CONFIG
	if get_node_or_null("CollisionShape3D") == null:
		var col := CollisionShape3D.new()
		col.name = "CollisionShape3D"
		var cap := CapsuleShape3D.new()
		cap.radius = 0.38
		cap.height = 1.40
		col.shape = cap
		col.position = Vector3(0.0, 0.70, 0.0)
		add_child(col)

	if rig_avatar == null:
		rig_avatar = get_node_or_null("HubRigAvatar3D") as HubRigAvatar3DScript
	if rig_avatar == null:
		rig_avatar = HubRigAvatar3DScript.new() as HubRigAvatar3DScript
		rig_avatar.name = "HubRigAvatar3D"
		var hd_cfg: DioramaConfigScript = DEFAULT_DIORAMA_CONFIG.duplicate(true) as DioramaConfigScript
		hd_cfg.viewport_size = 1280
		hd_cfg.rig_camera_zoom = 2.12
		hd_cfg.rig_camera_center_offset = Vector2(0.0, -24.0)
		var default_zoom: float = maxf(DEFAULT_DIORAMA_CONFIG.rig_camera_zoom, 0.1)
		var zoom_ratio: float = hd_cfg.rig_camera_zoom / default_zoom
		var visual_scale_boost: float = 1.14
		hd_cfg.avatar_pixel_size = (DEFAULT_DIORAMA_CONFIG.avatar_pixel_size / zoom_ratio) * visual_scale_boost
		var feet_world_y: float = DEFAULT_DIORAMA_CONFIG.rig_camera_center_offset.y + (DEFAULT_DIORAMA_CONFIG.avatar_feet_offset_px / default_zoom)
		hd_cfg.avatar_feet_offset_px = (feet_world_y - hd_cfg.rig_camera_center_offset.y) * hd_cfg.rig_camera_zoom
		hd_cfg.avatar_hover_height = layout_config.flight_hover_y
		hd_cfg.avatar_idle_bob_amp = 0.012
		hd_cfg.avatar_idle_bob_hz = 0.85
		hd_cfg.avatar_tilt_deg = -46.0
		hd_cfg.avatar_aspect_y_comp = 1.0
		rig_avatar.diorama_config = hd_cfg
		add_child(rig_avatar)
		var profile: PilotRigProfile = ResourceLoader.load(DEFAULT_DIORAMA_CONFIG.default_profile_path) as PilotRigProfile
		if profile != null:
			rig_avatar.load_pilot_profile(profile)
	if rig_avatar != null:
		rig_avatar.set_3d_scene_lighting_enabled(true)
		if _grounded_motor == null:
			_grounded_motor = HubGroundedMotor3DScript.new()
		if not rig_avatar.footstep_triggered.is_connected(_on_footstep_triggered):
			rig_avatar.footstep_triggered.connect(_on_footstep_triggered)

	if shadow_sprite == null:
		_setup_shadow()
	_update_shadow_projection()

	var light_dir: Vector3 = _get_light_direction()
	var light_2d_raw := Vector2(-light_dir.x, light_dir.y)
	var light_2d: Vector2 = light_2d_raw.normalized() if light_2d_raw.length_squared() > 0.0001 else DEFAULT_DIORAMA_CONFIG.hub_light_dir_2d
	rig_avatar.set_light_dir_2d(light_2d)
	rig_avatar.set_motion_state(_facing_dir_2d, 0.0, _facing_dir_2d, true)
	evaluate_platform_traversal(0.0, true)


func _setup_shadow() -> void:
	if rig_avatar == null:
		return
	var visual_sprite: Sprite3D = rig_avatar.get_sprite_3d()
	if visual_sprite == null:
		return
	shadow_sprite = Sprite3D.new()
	shadow_sprite.name = "PlayerShadow"
	shadow_sprite.axis = Vector3.AXIS_Y
	shadow_sprite.shaded = false
	shadow_sprite.pixel_size = visual_sprite.pixel_size
	shadow_sprite.offset = visual_sprite.offset
	shadow_sprite.position = Vector3(0.0, 0.035, 0.0)
	shadow_sprite.render_priority = 1
	shadow_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	_shadow_mat = ShaderMaterial.new()
	_shadow_mat.shader = SILHOUETTE_SHADOW_SHADER
	_shadow_mat.render_priority = 1
	_shadow_mat.set_shader_parameter("shadow_color", Color(0.0, 0.0, 0.0, SHADOW_ALPHA))
	_shadow_mat.set_shader_parameter("texture_albedo", rig_avatar.get_viewport_texture())
	shadow_sprite.texture = rig_avatar.get_viewport_texture()
	shadow_sprite.material_override = _shadow_mat
	add_child(shadow_sprite)

	_contact_shadow_mat = ShaderMaterial.new()
	_contact_shadow_mat.shader = CONTACT_SHADOW_SHADER
	_contact_shadow_mat.render_priority = 2
	var cs_plane := PlaneMesh.new()
	cs_plane.size = Vector2(1.18, 0.86)
	_contact_shadow_mesh = MeshInstance3D.new()
	_contact_shadow_mesh.name = "PlayerContactShadow"
	_contact_shadow_mesh.mesh = cs_plane
	_contact_shadow_mesh.position = Vector3(0.0, 0.024, 0.04)
	_contact_shadow_mesh.material_override = _contact_shadow_mat
	_contact_shadow_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_contact_shadow_mesh)
	_update_shadow_projection()


func _get_light_direction() -> Vector3:
	if _directional_light != null and is_instance_valid(_directional_light):
		return -_directional_light.global_transform.basis.z.normalized()
	return DEFAULT_LIGHT_DIR.normalized()


func _update_shadow_projection() -> void:
	if shadow_sprite == null or rig_avatar == null:
		return
	var light_dir: Vector3 = _get_light_direction()
	var ground_proj := Vector3(light_dir.x, 0.0, light_dir.z)
	var ground_dist: float = ground_proj.length()
	var ground_norm: Vector3 = (ground_proj / ground_dist) if ground_dist > 0.001 else Vector3(0.0, 0.0, -1.0)
	shadow_sprite.rotation = Vector3(0.0, atan2(-ground_norm.x, -ground_norm.z), 0.0)
	var pitch_ratio: float = ground_dist / maxf(absf(light_dir.y), 0.001)
	_shadow_proj_scale = Vector3(0.95, 1.0, clampf(pitch_ratio * 0.75, 0.5, 1.1))
	shadow_sprite.scale = _shadow_proj_scale


func evaluate_platform_traversal(delta: float, instant: bool = false) -> void:
	if layout_config == null:
		return
	var xz := Vector2(global_position.x, global_position.z)
	_on_platform_raw = false if _forced_flight_override else layout_config.is_point_on_platform(xz)
	var want_fly: bool = not _on_platform_raw

	if instant:
		_pending_flight_target = want_fly
		_hysteresis_timer = 0.0
		_shadow_platform_blend = 0.0 if (want_fly or is_closeup_shadow_suppressed) else 1.0
		_apply_flight_state(want_fly, true)
		if rig_avatar != null and _grounded_motor != null:
			var scale_amp: float = rig_avatar.get_grounded_config().hub_shadow_contact_scale_amp if rig_avatar.get_grounded_config() != null else 0.08
			var sh_vis_inst: float = 0.0 if is_closeup_shadow_suppressed else (_visibility_alpha * _shadow_platform_blend)
			_grounded_motor.update_shadows(shadow_sprite, _shadow_mat, _shadow_proj_scale, _contact_shadow_mesh, _contact_shadow_mat, rig_avatar.get_hover_factor(), 1.0, SHADOW_ALPHA, SHADOW_ALPHA * 0.72, sh_vis_inst, scale_amp)
		return

	if want_fly != _pending_flight_target:
		_pending_flight_target = want_fly
		_hysteresis_timer = 0.0
	elif want_fly != is_flying_in_space:
		_hysteresis_timer += delta
		if _hysteresis_timer >= layout_config.traversal_hysteresis_sec:
			_apply_flight_state(want_fly, false)


func set_forced_space_flight(forced: bool) -> void:
	_forced_flight_override = forced
	if forced:
		_apply_flight_state(true, false)
	else:
		evaluate_platform_traversal(0.0, true)


func _apply_flight_state(flying: bool, instant: bool) -> void:
	var changed: bool = (is_flying_in_space != flying) or instant
	is_flying_in_space = flying
	if rig_avatar != null:
		rig_avatar.set_flight_traversal_state(flying, instant)
	if changed:
		traversal_state_changed.emit(flying)


func face_front_idle(snap_instant: bool = true) -> void:
	_facing_dir_2d = Vector2.DOWN
	velocity.x = 0.0
	velocity.z = 0.0
	if rig_avatar != null:
		rig_avatar.set_motion_state(Vector2.DOWN, 0.0, Vector2.DOWN, snap_instant)


func face_north_idle(snap_instant: bool = true) -> void:
	_facing_dir_2d = Vector2.UP
	velocity.x = 0.0
	velocity.z = 0.0
	if rig_avatar != null:
		rig_avatar.set_motion_state(Vector2.UP, 0.0, Vector2.UP, snap_instant)


func set_pose_override(move_dir: Vector2, speed_norm: float, aim_dir: Vector2, snap_instant: bool = false) -> void:
	if aim_dir.length_squared() > 0.002:
		_facing_dir_2d = aim_dir.normalized()
	if rig_avatar != null:
		rig_avatar.set_motion_state(move_dir, speed_norm, aim_dir, snap_instant)


func set_visibility_fade(alpha: float) -> void:
	_visibility_alpha = clampf(alpha, 0.0, 1.0)
	if rig_avatar != null:
		rig_avatar.set_sprite_opacity(_visibility_alpha)


func set_closeup_shadow_suppressed(suppressed: bool) -> void:
	is_closeup_shadow_suppressed = suppressed
	if shadow_sprite != null:
		shadow_sprite.visible = not suppressed


func _on_footstep_triggered(foot: StringName, strength: float) -> void:
	if is_flying_in_space:
		return
	if _grounded_motor != null:
		_grounded_motor.on_footstep(self, foot, strength, rig_avatar)


func _physics_process(delta: float) -> void:
	if _grounded_motor == null:
		_grounded_motor = HubGroundedMotor3DScript.new()

	evaluate_platform_traversal(delta, false)
	var on_capsule_pad: bool = (not is_flying_in_space) and (Vector2(global_position.x, global_position.z).distance_squared_to(layout_config.capsule_pad_xz) <= layout_config.capsule_pad_radius * layout_config.capsule_pad_radius)
	var target_hover_y: float = layout_config.flight_hover_y if is_flying_in_space else (layout_config.capsule_pad_hover_y if on_capsule_pad else layout_config.platform_hover_y)
	global_position.y = lerpf(global_position.y, target_hover_y, clampf(10.0 * delta, 0.0, 1.0))
	velocity.y = 0.0

	_shadow_platform_blend = lerpf(_shadow_platform_blend, 0.0 if (is_flying_in_space or is_closeup_shadow_suppressed) else 1.0, clampf(10.0 * delta, 0.0, 1.0))
	var eff_shadow_vis: float = 0.0 if is_closeup_shadow_suppressed else (_visibility_alpha * _shadow_platform_blend)
	var scale_amp: float = rig_avatar.get_grounded_config().hub_shadow_contact_scale_amp if (rig_avatar != null and rig_avatar.get_grounded_config() != null) else 0.08

	if is_movement_locked:
		if not is_flying_in_space:
			_grounded_motor.step_velocity(self, Vector3.ZERO, delta, rig_avatar)
		else:
			velocity.x = move_toward(velocity.x, 0.0, FLIGHT_FRICTION * delta)
			velocity.z = move_toward(velocity.z, 0.0, FLIGHT_FRICTION * delta)
		if rig_avatar != null and not is_pose_override_active:
			rig_avatar.set_motion_state(_facing_dir_2d, 0.0, _facing_dir_2d, false)
		var prev_locked: Vector3 = global_position
		move_and_slide()
		if not is_flying_in_space:
			_grounded_motor.commit_stride_displacement(prev_locked, global_position, rig_avatar)
		if rig_avatar != null:
			_grounded_motor.update_shadows(shadow_sprite, _shadow_mat, _shadow_proj_scale, _contact_shadow_mesh, _contact_shadow_mat, rig_avatar.get_hover_factor(), delta, SHADOW_ALPHA, SHADOW_ALPHA * 0.72, eff_shadow_vis, scale_amp)
		return

	var raw_x: float = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	var raw_z: float = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	var raw_vec := Vector3(raw_x, 0.0, raw_z)
	var input_dir: Vector3 = raw_vec.normalized() if raw_vec.length_squared() > 0.01 else Vector3.ZERO

	var speed_norm: float = 0.0
	if is_flying_in_space:
		var max_spd: float = layout_config.space_flight_speed if layout_config != null else 11.5
		if input_dir.length_squared() > 0.01:
			_facing_dir_2d = Vector2(input_dir.x, input_dir.z).normalized()
			velocity.x = move_toward(velocity.x, input_dir.x * max_spd, FLIGHT_ACCEL * delta)
			velocity.z = move_toward(velocity.z, input_dir.z * max_spd, FLIGHT_ACCEL * delta)
		else:
			velocity.x = move_toward(velocity.x, 0.0, FLIGHT_FRICTION * delta)
			velocity.z = move_toward(velocity.z, 0.0, FLIGHT_FRICTION * delta)
		speed_norm = clampf(Vector2(velocity.x, velocity.z).length() / maxf(max_spd, 0.01), 0.0, 1.25)
	else:
		var motion_res: Dictionary = _grounded_motor.step_velocity(self, input_dir, delta, rig_avatar)
		if input_dir.length_squared() > 0.01:
			_facing_dir_2d = motion_res["facing_dir_2d"] as Vector2
		speed_norm = float(motion_res["speed_norm"])

	if rig_avatar != null:
		rig_avatar.set_motion_state(_facing_dir_2d, speed_norm, _facing_dir_2d, false)

	var prev_pos: Vector3 = global_position
	move_and_slide()
	if not is_flying_in_space:
		_grounded_motor.commit_stride_displacement(prev_pos, global_position, rig_avatar)
	if rig_avatar != null:
		_grounded_motor.update_shadows(shadow_sprite, _shadow_mat, _shadow_proj_scale, _contact_shadow_mesh, _contact_shadow_mat, rig_avatar.get_hover_factor(), delta, SHADOW_ALPHA, SHADOW_ALPHA * 0.72, eff_shadow_vis, scale_amp)

class_name HubArtLabPlayer
extends CharacterBody3D

## Controlador de vuelo Zero-G 8-dir para HubArtLab.
## Monta HubRigAvatar3D (producción) y la sombra de silueta manteniendo el control de cámara
## exclusivamente en HubLabCameraRig.

const HubRigAvatar3DScript = preload("res://scenes/ui/hub/components/hub_rig_avatar_3d.gd")
const DioramaConfigScript = preload("res://scenes/ui/hub/resources/hub_diorama_config.gd")
const DEFAULT_DIORAMA_CONFIG: DioramaConfigScript = preload("res://data/hub/default_hub_diorama_config.tres")
const SILHOUETTE_SHADOW_SHADER: Shader = preload("res://shaders/character_silhouette_shadow.gdshader")

const ACCEL: float = 24.0
const FRICTION: float = 18.0
const GRAVITY: float = 20.0
const MAX_STEP_HEIGHT: float = 0.28
const SHADOW_ALPHA: float = 0.48
const DEFAULT_LIGHT_DIR := Vector3(-0.353553, -0.707107, -0.612372)

@export var move_speed: float = 7.2
@export var is_movement_locked: bool = false

var rig_avatar: HubRigAvatar3DScript = null
var shadow_sprite: Sprite3D = null
var _shadow_mat: ShaderMaterial = null
var _facing_dir_2d: Vector2 = Vector2.DOWN
var _directional_light: DirectionalLight3D = null


func setup(p_move_speed: float, p_light: DirectionalLight3D = null) -> void:
	move_speed = p_move_speed
	_directional_light = p_light
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
	if get_node_or_null("CollisionShape3D") == null:
		var col := CollisionShape3D.new()
		col.name = "CollisionShape3D"
		var cap := CapsuleShape3D.new()
		cap.radius = 0.40
		cap.height = 1.40
		col.shape = cap
		col.position = Vector3(0.0, 0.70, 0.0)
		add_child(col)

	if rig_avatar == null:
		rig_avatar = get_node_or_null("HubRigAvatar3D") as HubRigAvatar3DScript
	if rig_avatar == null:
		rig_avatar = HubRigAvatar3DScript.new() as HubRigAvatar3DScript
		rig_avatar.name = "HubRigAvatar3D"
		rig_avatar.diorama_config = DEFAULT_DIORAMA_CONFIG
		add_child(rig_avatar)
		var profile: PilotRigProfile = ResourceLoader.load(DEFAULT_DIORAMA_CONFIG.default_profile_path) as PilotRigProfile
		if profile != null:
			rig_avatar.load_pilot_profile(profile)

	if shadow_sprite == null:
		_setup_shadow()
	_update_shadow_projection()

	var light_dir: Vector3 = _get_light_direction()
	var light_2d_raw := Vector2(-light_dir.x, light_dir.y)
	var light_2d: Vector2 = light_2d_raw.normalized() if light_2d_raw.length_squared() > 0.0001 else DEFAULT_DIORAMA_CONFIG.hub_light_dir_2d
	rig_avatar.set_light_dir_2d(light_2d)
	rig_avatar.set_motion_state(_facing_dir_2d, 0.0, _facing_dir_2d, true)


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
	shadow_sprite.scale = Vector3(0.95, 1.0, clampf(pitch_ratio * 0.75, 0.5, 1.1))


func face_front_idle(snap_instant: bool = true) -> void:
	_facing_dir_2d = Vector2.DOWN
	velocity.x = 0.0
	velocity.z = 0.0
	if rig_avatar != null:
		rig_avatar.set_motion_state(Vector2.DOWN, 0.0, Vector2.DOWN, snap_instant)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = -0.1

	if is_movement_locked:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
		velocity.z = move_toward(velocity.z, 0.0, FRICTION * delta)
		if rig_avatar != null:
			rig_avatar.set_motion_state(_facing_dir_2d, 0.0, _facing_dir_2d, false)
		move_and_slide()
		return

	var raw_x: float = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	var raw_z: float = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	var raw_vec := Vector3(raw_x, 0.0, raw_z)
	var input_dir: Vector3 = raw_vec.normalized() if raw_vec.length_squared() > 0.01 else Vector3.ZERO

	if input_dir.length_squared() > 0.01:
		var target_vel: Vector3 = input_dir * move_speed
		velocity.x = move_toward(velocity.x, target_vel.x, ACCEL * delta)
		velocity.z = move_toward(velocity.z, target_vel.z, ACCEL * delta)
		_facing_dir_2d = Vector2(input_dir.x, input_dir.z).normalized()
	else:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
		velocity.z = move_toward(velocity.z, 0.0, FRICTION * delta)

	var speed_norm: float = clampf(Vector2(velocity.x, velocity.z).length() / maxf(move_speed, 0.01), 0.0, 1.0)
	if rig_avatar != null:
		rig_avatar.set_motion_state(_facing_dir_2d, speed_norm, _facing_dir_2d, false)

	if is_on_floor():
		_handle_step_climb(delta)

	move_and_slide()


func _handle_step_climb(delta: float) -> void:
	var horiz_vel := Vector3(velocity.x, 0.0, velocity.z)
	if horiz_vel.length_squared() < 0.04:
		return
	var move_vec: Vector3 = horiz_vel.normalized() * (horiz_vel.length() * delta + 0.15)
	if not test_move(global_transform, move_vec):
		return
	var up_vec := Vector3(0.0, MAX_STEP_HEIGHT, 0.0)
	if test_move(global_transform, up_vec):
		return
	var elevated_xform: Transform3D = global_transform.translated(up_vec)
	if test_move(elevated_xform, move_vec):
		return
	if test_move(elevated_xform.translated(move_vec), Vector3(0.0, -MAX_STEP_HEIGHT - 0.05, 0.0)):
		move_and_collide(up_vec)

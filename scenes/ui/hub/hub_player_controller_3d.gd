class_name HubPlayerController3D
extends CharacterBody3D

## HubPlayerController3D.gd
## Controlador del personaje en tercera persona para explorar el Hub en 2.5D Diorama.
## Soporta movimiento directo WASD en 8 direcciones Zero-G usando HubRigAvatar3D,
## cámara fija 2.5D Diorama y detección de interacción con [E].

const HubRigAvatar3DScript = preload("res://scenes/ui/hub/components/hub_rig_avatar_3d.gd")
const HubGroundedMotor3DScript = preload("res://scenes/ui/hub/components/hub_grounded_motor_3d.gd")
const HubCameraController3DScript = preload("res://scenes/ui/hub/components/hub_camera_controller_3d.gd")
const HubDioramaConfigScript = preload("res://scenes/ui/hub/resources/hub_diorama_config.gd")
const DEFAULT_DIORAMA_CONFIG: HubDioramaConfigScript = preload("res://data/hub/default_hub_diorama_config.tres")
const CosmeticsManagerScript = preload("res://core/systems/cosmetics_manager.gd")

@export var move_speed: float = 7.0
@export var acceleration: float = 24.0
@export var friction: float = 18.0
@export var gravity: float = 20.0

@export var active_character_id: StringName = &"valentina"
@export var is_movement_locked: bool = false
@export var diorama_config: HubDioramaConfigScript = DEFAULT_DIORAMA_CONFIG

@export_group("Slope & Step Assist")
@export var max_step_height: float = 0.30 ## Altura máxima de escalón que el jugador sube automáticamente (metros)
@export var slope_max_angle_deg: float = 50.0 ## Ángulo máximo de rampa/slope que puede subir
@export var auto_step_climb: bool = true ## Activa el ascenso automático de pequeños desniveles y escalones

var active_interactable: Area3D = null
var nearby_interactables: Array[Area3D] = []

var rig_avatar: HubRigAvatar3DScript = null
var _grounded_motor: HubGroundedMotor3DScript = null
var visual_sprite: Sprite3D = null
@onready var camera: Camera3D = get_node_or_null("Camera3D") as Camera3D
@onready var collision_shape: CollisionShape3D = get_node_or_null("CollisionShape3D") as CollisionShape3D
var shadow_sprite: Sprite3D = null

var _facing_dir_2d: Vector2 = Vector2.DOWN


func _ready() -> void:
	collision_layer = 2 # Capa de jugador Hub
	collision_mask = 1  # Capa del suelo/planeta

	# Configuración de slopes y desniveles en CharacterBody3D
	floor_max_angle = deg_to_rad(slope_max_angle_deg)
	floor_snap_length = 0.35 # Mantiene al jugador adherido al bajar rampas o escalones
	floor_constant_speed = true # Velocidad constante en pendientes
	floor_stop_on_slope = true
	floor_block_on_wall = true

	_setup_collision()
	_setup_avatar()
	_setup_camera()


func _resolve_diorama_config() -> HubDioramaConfigScript:
	return diorama_config if diorama_config != null else DEFAULT_DIORAMA_CONFIG


func _setup_collision() -> void:
	if not collision_shape:
		collision_shape = get_node_or_null("CollisionShape3D") as CollisionShape3D
	if not collision_shape:
		collision_shape = CollisionShape3D.new()
		collision_shape.name = "CollisionShape3D"
		var cap := CapsuleShape3D.new()
		cap.radius = 0.4
		cap.height = 1.4
		collision_shape.shape = cap
		collision_shape.position = Vector3(0, 0.7, 0)
		add_child(collision_shape)


func _setup_avatar() -> void:
	var cfg: HubDioramaConfigScript = _resolve_diorama_config()
	rig_avatar = get_node_or_null("HubRigAvatar3D") as HubRigAvatar3DScript
	if rig_avatar == null:
		rig_avatar = HubRigAvatar3DScript.new() as HubRigAvatar3DScript
		rig_avatar.name = "HubRigAvatar3D"
		rig_avatar.diorama_config = cfg
		add_child(rig_avatar)
	else:
		rig_avatar.diorama_config = cfg

	var legacy_sprite: Node = get_node_or_null("Sprite3D")
	if legacy_sprite != null:
		remove_child(legacy_sprite)
		legacy_sprite.queue_free()

	if not CharacterData.is_character_playable_rework_ready(active_character_id):
		active_character_id = CharacterData.get_default_playable_character_id()

	var profile: PilotRigProfile = _resolve_pilot_profile(active_character_id)
	rig_avatar.load_pilot_profile(profile)
	refresh_equipped_skin()
	visual_sprite = rig_avatar.get_sprite_3d()

	var light_dir: Vector3 = _get_light_direction()
	var light_2d_raw := Vector2(-light_dir.x, light_dir.y)
	var light_2d: Vector2 = light_2d_raw.normalized() if light_2d_raw.length_squared() > 0.0001 else cfg.hub_light_dir_2d
	rig_avatar.set_light_dir_2d(light_2d)
	rig_avatar.set_motion_state(_facing_dir_2d, 0.0, _facing_dir_2d, true)

	if _grounded_motor == null:
		_grounded_motor = HubGroundedMotor3DScript.new()
	if not rig_avatar.footstep_triggered.is_connected(_on_footstep_triggered):
		rig_avatar.footstep_triggered.connect(_on_footstep_triggered)

	_setup_shadow()


func _resolve_pilot_profile(char_id: StringName) -> PilotRigProfile:
	var roster: Dictionary[StringName, CharacterData] = CharacterData.load_roster()
	var cd: CharacterData = roster.get(char_id, null)
	if cd != null and cd.pilot_rig_profile != null:
		return cd.pilot_rig_profile
	var cfg: HubDioramaConfigScript = _resolve_diorama_config()
	if ResourceLoader.exists(cfg.default_profile_path):
		return ResourceLoader.load(cfg.default_profile_path) as PilotRigProfile
	return null


const SILHOUETTE_SHADOW_SHADER = preload("res://shaders/character_silhouette_shadow.gdshader")
const SHADOW_BASE_ALPHA: float = 0.48
const SHADOW_HOP_ALPHA: float = 0.36
const DEFAULT_LIGHT_DIR := Vector3(-0.353553, -0.707107, -0.612372)

var _directional_light: DirectionalLight3D = null
var _shadow_proj_scale := Vector3(0.95, 1.0, 0.75)
var _current_shadow_alpha: float = SHADOW_BASE_ALPHA
var _shadow_mat: ShaderMaterial = null

func _get_light_direction() -> Vector3:
	if not _directional_light or not is_instance_valid(_directional_light):
		var root := get_tree().current_scene
		if root:
			var light_node := root.get_node_or_null("DirectionalLight3D") as DirectionalLight3D
			if light_node:
				_directional_light = light_node
			else:
				for child in root.get_children():
					if child is DirectionalLight3D:
						_directional_light = child
						break
	if _directional_light and is_instance_valid(_directional_light):
		return -_directional_light.global_transform.basis.z.normalized()
	return DEFAULT_LIGHT_DIR.normalized()


func _setup_shadow() -> void:
	if not shadow_sprite:
		shadow_sprite = get_node_or_null("PlayerShadow") as Sprite3D
	if not shadow_sprite:
		shadow_sprite = Sprite3D.new()
		shadow_sprite.name = "PlayerShadow"
		add_child(shadow_sprite)

	shadow_sprite.axis = Vector3.AXIS_Y
	shadow_sprite.shaded = false
	shadow_sprite.pixel_size = _resolve_diorama_config().avatar_pixel_size
	# Altura a 0.035 para descansar limpia sobre el suelo (top mesh en Y=0.0253)
	shadow_sprite.position = Vector3(0.0, 0.035, 0.0)
	shadow_sprite.render_priority = 1
	shadow_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	if not _shadow_mat:
		_shadow_mat = ShaderMaterial.new()
		_shadow_mat.shader = SILHOUETTE_SHADOW_SHADER
		_shadow_mat.render_priority = 1
		_shadow_mat.set_shader_parameter("shadow_color", Color(0.0, 0.0, 0.0, SHADOW_BASE_ALPHA))
	shadow_sprite.material_override = _shadow_mat
	_sync_shadow_texture()


func _update_shadow_projection() -> void:
	if not shadow_sprite or not visual_sprite:
		return

	# Pivot exacto en los pies (heredado de visual_sprite para que la sombra nazca del contacto)
	shadow_sprite.offset = visual_sprite.offset
	shadow_sprite.pixel_size = visual_sprite.pixel_size

	var light_dir := _get_light_direction()
	var ground_proj := Vector3(light_dir.x, 0.0, light_dir.z)
	var ground_dist := ground_proj.length()
	var ground_norm: Vector3 = (ground_proj / ground_dist) if ground_dist > 0.001 else Vector3(0.0, 0.0, -1.0)

	# Orientar el vector de cabeza (-Z local en Sprite3D AXIS_Y) hacia la proyección del vector de luz
	var phi: float = atan2(-ground_norm.x, -ground_norm.z)
	shadow_sprite.rotation = Vector3(0.0, phi, 0.0)

	# Elongación proporcional al ángulo cenital de la luz (clamp estético para perspectiva diorama)
	var pitch_ratio: float = ground_dist / maxf(absf(light_dir.y), 0.001)
	var shadow_length: float = clampf(pitch_ratio * 0.75, 0.5, 1.1)
	_shadow_proj_scale = Vector3(0.95, 1.0, shadow_length)
	shadow_sprite.scale = _shadow_proj_scale


func _sync_shadow_texture() -> void:
	if not shadow_sprite or not visual_sprite:
		return
	var tex: Texture2D = rig_avatar.get_viewport_texture() if rig_avatar != null else visual_sprite.texture
	shadow_sprite.texture = tex
	shadow_sprite.flip_h = false
	shadow_sprite.pixel_size = visual_sprite.pixel_size
	shadow_sprite.offset = visual_sprite.offset
	if _shadow_mat and tex:
		_shadow_mat.set_shader_parameter("texture_albedo", tex)
	_update_shadow_projection()


func _update_shadow_hop(hop_factor: float, delta: float) -> void:
	if _grounded_motor != null:
		var scale_amp: float = 0.08
		if rig_avatar != null and rig_avatar.get_grounded_config() != null:
			scale_amp = rig_avatar.get_grounded_config().hub_shadow_contact_scale_amp
		_grounded_motor.update_shadows(
			shadow_sprite,
			_shadow_mat,
			_shadow_proj_scale,
			null,
			null,
			hop_factor,
			delta,
			SHADOW_BASE_ALPHA,
			SHADOW_HOP_ALPHA,
			1.0,
			scale_amp
		)
		return
	if not shadow_sprite:
		return
	var scale_mult: float = 1.0 - (hop_factor * 0.12)
	var target_scale := Vector3(_shadow_proj_scale.x * scale_mult, 1.0, _shadow_proj_scale.z * scale_mult)
	shadow_sprite.scale = shadow_sprite.scale.lerp(target_scale, clampf(14.0 * delta, 0.0, 1.0))
	var target_alpha: float = lerpf(SHADOW_BASE_ALPHA, SHADOW_HOP_ALPHA, hop_factor)
	_current_shadow_alpha = lerpf(_current_shadow_alpha, target_alpha, clampf(14.0 * delta, 0.0, 1.0))
	if _shadow_mat:
		_shadow_mat.set_shader_parameter("shadow_color", Color(0.0, 0.0, 0.0, _current_shadow_alpha))


func _on_footstep_triggered(foot: StringName, strength: float) -> void:
	if _grounded_motor != null:
		_grounded_motor.on_footstep(self, foot, strength, rig_avatar)


func _setup_camera() -> void:
	if not camera:
		camera = get_node_or_null("Camera3D") as Camera3D
	if not camera:
		camera = Camera3D.new()
		camera.name = "Camera3D"
		add_child(camera)

	var target_pos: Vector3 = global_position if is_inside_tree() else position
	HubCameraController3DScript.configure_diorama_camera(camera, target_pos, _resolve_diorama_config())


func set_character(char_id: StringName) -> void:
	var resolved_id: StringName = char_id
	if not CharacterData.is_character_playable_rework_ready(resolved_id):
		resolved_id = CharacterData.get_default_playable_character_id()
	active_character_id = resolved_id
	if rig_avatar != null:
		var profile: PilotRigProfile = _resolve_pilot_profile(resolved_id)
		rig_avatar.load_pilot_profile(profile)
		refresh_equipped_skin()
		visual_sprite = rig_avatar.get_sprite_3d()
	_sync_shadow_texture()


func refresh_equipped_skin() -> void:
	if rig_avatar == null:
		return
	var preset: PilotSkinPreset = CosmeticsManagerScript.resolve_pilot_skin_preset(active_character_id, "pilot")
	var stars: int = CosmeticsManagerScript.resolve_equipped_skin_stars("pilot", active_character_id)
	if preset != null:
		rig_avatar.apply_skin_preset(preset, stars)


func set_input_direction_for_test(dir_xz: Vector2, speed_norm: float = 1.0, snap_instant: bool = true) -> void:
	if dir_xz.length_squared() > 0.002:
		_facing_dir_2d = dir_xz.normalized()
	if rig_avatar != null:
		rig_avatar.set_motion_state(_facing_dir_2d, clampf(speed_norm, 0.0, 1.5), _facing_dir_2d, snap_instant)


func _physics_process(delta: float) -> void:
	# Aplicar gravedad
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = -0.1

	if _grounded_motor == null:
		_grounded_motor = HubGroundedMotor3DScript.new()

	if is_movement_locked:
		_grounded_motor.step_velocity(self, Vector3.ZERO, delta, rig_avatar)
		if rig_avatar != null:
			rig_avatar.set_motion_state(_facing_dir_2d, 0.0, _facing_dir_2d, false)
			_update_shadow_hop(rig_avatar.get_hover_factor(), delta)
		var prev_locked_pos: Vector3 = global_position
		move_and_slide()
		_grounded_motor.commit_stride_displacement(prev_locked_pos, global_position, rig_avatar)
		_update_camera(delta)
		return

	# Lectura directa WASD en plano XZ alineada a la cámara fija 2.5D Diorama
	var raw_x: float = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	var raw_z: float = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	var raw_vec := Vector3(raw_x, 0.0, raw_z)
	var input_dir: Vector3 = raw_vec.normalized() if raw_vec.length_squared() > 0.01 else Vector3.ZERO

	var motion_res: Dictionary = _grounded_motor.step_velocity(self, input_dir, delta, rig_avatar)
	if input_dir.length_squared() > 0.01:
		_facing_dir_2d = motion_res["facing_dir_2d"] as Vector2
	var speed_norm: float = float(motion_res["speed_norm"])
	if rig_avatar != null:
		rig_avatar.set_motion_state(_facing_dir_2d, speed_norm, _facing_dir_2d, false)
		_update_shadow_hop(rig_avatar.get_hover_factor(), delta)

	# Asistencia de ascenso automático de pequeños escalones y plataformas bajas
	if auto_step_climb and is_on_floor() and not is_movement_locked:
		_handle_step_climb(delta)

	var prev_pos: Vector3 = global_position
	move_and_slide()
	_grounded_motor.commit_stride_displacement(prev_pos, global_position, rig_avatar)
	_update_camera(delta)
	_check_interactables()


func _handle_step_climb(delta: float) -> void:
	var horiz_vel := Vector3(velocity.x, 0.0, velocity.z)
	if horiz_vel.length_squared() < 0.04:
		return

	# Distancia de avance para evaluar colisión frontal inmediata
	var step_margin: float = 0.15
	var move_vec := horiz_vel.normalized() * (horiz_vel.length() * delta + step_margin)

	# 1. Comprobar si nos bloquea un obstáculo a ras de suelo
	if not test_move(global_transform, move_vec):
		return

	# 2. Comprobar si sobre la cabeza tenemos espacio libre para elevarnos max_step_height
	var up_vec := Vector3(0.0, max_step_height, 0.0)
	if test_move(global_transform, up_vec):
		return

	# 3. Comprobar si desde la posición elevada podemos avanzar hacia adelante
	var elevated_xform := global_transform.translated(up_vec)
	if test_move(elevated_xform, move_vec):
		# El obstáculo es más alto que max_step_height (pared, máquina, rover, etc.)
		return

	# 4. Proyectar hacia abajo desde la posición elevada y avanzada para confirmar piso transitable
	var forward_elevated_xform := elevated_xform.translated(move_vec)
	var down_vec := Vector3(0.0, -max_step_height - 0.05, 0.0)
	var hit_floor := test_move(forward_elevated_xform, down_vec)
	if hit_floor:
		# Hay superficie donde pararse: elevamos el personaje para que move_and_slide() con snap lo asiente
		move_and_collide(up_vec)


func _update_camera(delta: float) -> void:
	if not camera:
		return
	var target_pos: Vector3 = global_position if is_inside_tree() else position
	HubCameraController3DScript.update_diorama_camera(camera, target_pos, delta, _resolve_diorama_config())


func _check_interactables() -> void:
	# Buscar interactuable más cercano
	var closest: Area3D = null
	var min_dist: float = 9999.0
	for node in get_tree().get_nodes_in_group("hub_interactables"):
		if node is Area3D and is_instance_valid(node):
			var radius: float = node.interaction_radius if "interaction_radius" in node else 2.5
			var d := global_position.distance_to(node.global_position)
			if d <= radius and d < min_dist:
				min_dist = d
				closest = node
	active_interactable = closest


func _unhandled_input(event: InputEvent) -> void:
	if is_movement_locked:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E:
			if active_interactable and is_instance_valid(active_interactable):
				active_interactable.trigger_interaction()

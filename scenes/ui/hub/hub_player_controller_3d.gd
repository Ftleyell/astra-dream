class_name HubPlayerController3D
extends CharacterBody3D

## HubPlayerController3D.gd
## Controlador del personaje en tercera persona para explorar el Hub en 3D.
## Soporta movimiento fluido con WASD, cámara orbital de seguimiento de aventura suave,
## animación de balanceo para el recorte 2.5D y detección de interacción con [E].

@export var move_speed: float = 7.0
@export var acceleration: float = 24.0
@export var friction: float = 18.0
@export var gravity: float = 20.0

@export var active_character_id: StringName = &"nova"
@export var is_movement_locked: bool = false

@export_group("Slope & Step Assist")
@export var max_step_height: float = 0.30 ## Altura máxima de escalón que el jugador sube automáticamente (metros)
@export var slope_max_angle_deg: float = 50.0 ## Ángulo máximo de rampa/slope que puede subir
@export var auto_step_climb: bool = true ## Activa el ascenso automático de pequeños desniveles y escalones

var active_interactable: Area3D = null
var nearby_interactables: Array[Area3D] = []

@onready var visual_sprite: Sprite3D = $Sprite3D
@onready var camera: Camera3D = $Camera3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
var shadow_sprite: Sprite3D = null

const SPRITE_BASE_Y: float = 0.04

var _walk_cycle: float = 0.0
var _cam_offset: Vector3 = Vector3(0.0, 3.2, 5.0)


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
	_setup_sprite()
	_setup_camera()


func _setup_collision() -> void:
	if not collision_shape:
		collision_shape = get_node_or_null("CollisionShape3D")
	if not collision_shape:
		collision_shape = CollisionShape3D.new()
		collision_shape.name = "CollisionShape3D"
		var cap := CapsuleShape3D.new()
		cap.radius = 0.4
		cap.height = 1.4
		collision_shape.shape = cap
		collision_shape.position = Vector3(0, 0.7, 0)
		add_child(collision_shape)


func _setup_sprite() -> void:
	if not visual_sprite:
		visual_sprite = get_node_or_null("Sprite3D")
	if not visual_sprite:
		visual_sprite = Sprite3D.new()
		visual_sprite.name = "Sprite3D"
		add_child(visual_sprite)

	visual_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	visual_sprite.shaded = false
	visual_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	visual_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	visual_sprite.pixel_size = 0.0013
	visual_sprite.offset = Vector2(0, 800)
	visual_sprite.position = Vector3(0, SPRITE_BASE_Y, 0)
	visual_sprite.render_priority = 2

	_setup_shadow()
	_update_character_texture()


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
	shadow_sprite.pixel_size = 0.0013
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
	shadow_sprite.texture = visual_sprite.texture
	shadow_sprite.flip_h = visual_sprite.flip_h
	shadow_sprite.pixel_size = visual_sprite.pixel_size
	shadow_sprite.offset = visual_sprite.offset
	if _shadow_mat and visual_sprite.texture:
		_shadow_mat.set_shader_parameter("texture_albedo", visual_sprite.texture)
	_update_shadow_projection()


func _update_shadow_hop(hop_factor: float, delta: float) -> void:
	if not shadow_sprite:
		return
	# Contracción dinámica: al subir la piloto en el saltito, la sombra se contrae ~12%
	var scale_mult: float = 1.0 - (hop_factor * 0.12)
	var target_scale := Vector3(_shadow_proj_scale.x * scale_mult, 1.0, _shadow_proj_scale.z * scale_mult)
	shadow_sprite.scale = shadow_sprite.scale.lerp(target_scale, clampf(14.0 * delta, 0.0, 1.0))

	# Atenuación dinámica: al subir, la sombra se hace sutilmente más tenue
	var target_alpha := lerpf(SHADOW_BASE_ALPHA, SHADOW_HOP_ALPHA, hop_factor)
	_current_shadow_alpha = lerpf(_current_shadow_alpha, target_alpha, clampf(14.0 * delta, 0.0, 1.0))
	if _shadow_mat:
		_shadow_mat.set_shader_parameter("shadow_color", Color(0.0, 0.0, 0.0, _current_shadow_alpha))


func _setup_camera() -> void:
	if not camera:
		camera = get_node_or_null("Camera3D")
	if not camera:
		camera = Camera3D.new()
		camera.name = "Camera3D"
		add_child(camera)

	camera.fov = 85.0
	camera.current = true
	camera.top_level = true # Desacoplar para seguimiento suave sin giros rígidos
	camera.global_position = global_position + _cam_offset
	camera.look_at(global_position + Vector3(0, 1.2, 0), Vector3.UP)


func set_character(char_id: StringName) -> void:
	active_character_id = char_id
	_is_facing_back = false
	_update_character_texture()


const CosmeticsManager = preload("res://core/systems/cosmetics_manager.gd")

var _is_facing_back: bool = false

func _update_character_texture() -> void:
	if not visual_sprite:
		return
	var cid := String(active_character_id).to_lower()
	var slot_key := "pilot:" + cid
	var equipped_skin := SaveManager.get_equipped_skin(slot_key)
	if equipped_skin != "" and SaveManager.is_skin_unlocked(equipped_skin):
		var stars := SaveManager.get_skin_stars(equipped_skin)
		CosmeticsManager.apply_skin_to_sprite3d(visual_sprite, equipped_skin, stars, _is_facing_back, false)
		visual_sprite.pixel_size = 0.0013
		visual_sprite.offset = Vector2(0, 800)
		_sync_shadow_texture()
		return

	# Fallback original (sin skin)
	visual_sprite.material_override = null
	if _is_facing_back:
		var back_path := "res://assets/characters/fullbody/fullbody_%s_back.png" % cid
		if ResourceLoader.exists(back_path):
			visual_sprite.texture = load(back_path)
			visual_sprite.pixel_size = 0.0013
			visual_sprite.offset = Vector2(0, 800)
			_sync_shadow_texture()
			return

	var fullbody_path := "res://assets/characters/fullbody/fullbody_%s.png" % cid
	if ResourceLoader.exists(fullbody_path):
		visual_sprite.texture = load(fullbody_path)
		visual_sprite.pixel_size = 0.0013
		visual_sprite.offset = Vector2(0, 800)
	else:
		var portrait_path := "res://assets/portraits/portrait_%s.png" % cid
		if ResourceLoader.exists(portrait_path):
			visual_sprite.texture = load(portrait_path)
			visual_sprite.pixel_size = 0.005
			visual_sprite.offset = Vector2(0, 256)
	_sync_shadow_texture()


# Orientación y transición de cámara en el Hangar Doble
var _is_in_south_wing: bool = false
var _cam_flip_t: float = 0.0 ## 0.0 = Mirando al Norte (Hangar Original), 1.0 = Mirando al Sur (Hangar Espejado)

func _physics_process(delta: float) -> void:
	# Detección del hangar según posición Z con histeresis alrededor de la compuerta (Z = 16.8)
	if not _is_in_south_wing and global_position.z > 17.6:
		_is_in_south_wing = true
	elif _is_in_south_wing and global_position.z < 16.0:
		_is_in_south_wing = false

	# Interpolación continua de la orientación de cámara (transición suave de 180°)
	var target_flip: float = 1.0 if _is_in_south_wing else 0.0
	_cam_flip_t = move_toward(_cam_flip_t, target_flip, delta * 2.8)

	# Aplicar gravedad
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = -0.1

	if is_movement_locked:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		velocity.z = move_toward(velocity.z, 0.0, friction * delta)
		move_and_slide()
		_update_camera(delta)
		return

	# Lectura de inputs de movimiento adaptados a la perspectiva de la cámara
	# Al voltear la cámara 180°, 'W' (arriba en pantalla) avanza hacia el fondo visual (sur en el ala nueva, norte en la original)
	# y 'D' (derecha en pantalla) mueve a la derecha de la perspectiva del jugador de forma 100% intuitiva.
	var raw_x: float = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	var raw_z: float = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")

	# Detección de orientación frente/espalda respecto a la perspectiva de la cámara
	# raw_z < -0.1 indica avance hacia el fondo (opuesto a la cámara)
	# raw_z > 0.1 indica avance hacia el frente (en dirección a la cámara)
	# Si abs(raw_z) <= 0.1 (movimiento puramente lateral o reposo), se conserva la orientación actual
	if raw_z < -0.1:
		if not _is_facing_back:
			_is_facing_back = true
			_update_character_texture()
	elif raw_z > 0.1:
		if _is_facing_back:
			_is_facing_back = false
			_update_character_texture()

	# Ángulo de vista de cámara en el plano horizontal según _cam_flip_t (0° a 180°)
	var cam_yaw: float = _cam_flip_t * PI
	var input_x: float = raw_x * cos(cam_yaw) - raw_z * sin(cam_yaw)
	var input_z: float = raw_x * sin(cam_yaw) + raw_z * cos(cam_yaw)

	var input_dir := Vector3(input_x, 0.0, input_z).normalized()

	if input_dir.length_squared() > 0.01:
		var target_vel := input_dir * move_speed
		velocity.x = move_toward(velocity.x, target_vel.x, acceleration * delta)
		velocity.z = move_toward(velocity.z, target_vel.z, acceleration * delta)

		if absf(input_x) > 0.1:
			var should_flip: bool = (input_x < 0.0)
			if visual_sprite and visual_sprite.flip_h != should_flip:
				visual_sprite.flip_h = should_flip
				if shadow_sprite:
					shadow_sprite.flip_h = should_flip

		# Animación ligera de balanceo del recorte 2.5D al caminar
		_walk_cycle += delta * 12.0
		var hop_phase: float = absf(sin(_walk_cycle * 2.0))
		if visual_sprite:
			visual_sprite.rotation.z = sin(_walk_cycle) * 0.08
			visual_sprite.position.y = SPRITE_BASE_Y + hop_phase * 0.06
		_update_shadow_hop(hop_phase, delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		velocity.z = move_toward(velocity.z, 0.0, friction * delta)
		if visual_sprite:
			visual_sprite.rotation.z = move_toward(visual_sprite.rotation.z, 0.0, delta * 4.0)
			visual_sprite.position.y = move_toward(visual_sprite.position.y, SPRITE_BASE_Y, delta * 2.0)
		_update_shadow_hop(0.0, delta)

	# Asistencia de ascenso automático de pequeños escalones y plataformas bajas
	if auto_step_climb and is_on_floor() and not is_movement_locked:
		_handle_step_climb(delta)

	move_and_slide()
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

	# Factor de aproximación a los grandes ventanales exteriores:
	# Ventanal Norte (Z = -10.0) y Ventanal Sur espejado (Z = 43.6)
	var prox_north: float = clampf((-global_position.z - 2.0) / 7.5, 0.0, 1.0)
	var prox_south: float = clampf((global_position.z - 33.5) / 7.5, 0.0, 1.0)
	var window_proximity: float = maxf(prox_north, prox_south)

	# 1. Zoom Dinámico: reduce el FOV al acercarse a cualquiera de los ventanales
	var target_fov: float = lerpf(85.0, 68.0, window_proximity)
	camera.fov = lerpf(camera.fov, target_fov, clampf(6.0 * delta, 0.0, 1.0))

	# 2. Desplazamiento dinámico de cámara con inversión orbital de 180°
	# Offset base Norte: (0, 3.2, 5.0) -> mirando hacia Z negativo
	# Offset base Sur: (0, 3.2, -5.0) -> mirando hacia Z positivo
	var cur_dist_z: float = lerpf(5.0, 3.8, window_proximity)
	var cur_offset_y: float = lerpf(3.2, 3.6, window_proximity)

	# Rotación continua del offset alrededor del eje Y entre 0 y PI
	var flip_angle: float = _cam_flip_t * PI
	var offset_x: float = cur_dist_z * sin(flip_angle) * 0.4 # leve arco para evitar atravesar la cabeza
	var offset_z: float = cur_dist_z * cos(flip_angle)

	var target_cam_pos := global_position + Vector3(offset_x, cur_offset_y, offset_z)

	# Limitar cámara dentro de la nave extendida (de Z = -6.5 hasta Z = 40.0 en el ala sur, o Z = 13.0 en el hangar norte)
	var max_z: float = 40.0 if _is_in_south_wing else 13.0
	target_cam_pos.z = clampf(target_cam_pos.z, -6.5, max_z)
	target_cam_pos.x = clampf(target_cam_pos.x, -9.0, 9.0)
	target_cam_pos.y = clampf(target_cam_pos.y, 2.2, 4.8)

	# Suavizado elástico en 3ª persona
	var weight := clampf(7.5 * delta, 0.0, 1.0)
	camera.global_position = camera.global_position.lerp(target_cam_pos, weight)
	camera.global_position.z = clampf(camera.global_position.z, -6.5, max_z)
	camera.global_position.x = clampf(camera.global_position.x, -9.0, 9.0)
	camera.global_position.y = clampf(camera.global_position.y, 2.2, 4.8)

	# 3. Elevación del punto de mira al acercarse a un ventanal panorámico
	var look_y: float = lerpf(1.2, 1.9, window_proximity)
	var look_target := global_position + Vector3(0.0, look_y, 0.0)
	camera.look_at(look_target, Vector3.UP)


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

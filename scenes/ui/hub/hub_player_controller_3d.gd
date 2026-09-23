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

var active_interactable: Area3D = null
var nearby_interactables: Array[Area3D] = []

@onready var visual_sprite: Sprite3D = $Sprite3D
@onready var camera: Camera3D = $Camera3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

var _walk_cycle: float = 0.0
var _cam_offset: Vector3 = Vector3(0.0, 3.2, 5.0)


func _ready() -> void:
	collision_layer = 2 # Capa de jugador Hub
	collision_mask = 1  # Capa del suelo/planeta

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
	visual_sprite.position = Vector3(0, 0, 0)

	_update_character_texture()


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
	_update_character_texture()


func _update_character_texture() -> void:
	if not visual_sprite:
		return
	var cid := String(active_character_id).to_lower()
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


func _physics_process(delta: float) -> void:
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

	# Lectura de inputs de movimiento (compatible con move_left/right/up/down)
	var input_x: float = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	var input_z: float = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")

	var input_dir := Vector3(input_x, 0.0, input_z).normalized()

	if input_dir.length_squared() > 0.01:
		var target_vel := input_dir * move_speed
		velocity.x = move_toward(velocity.x, target_vel.x, acceleration * delta)
		velocity.z = move_toward(velocity.z, target_vel.z, acceleration * delta)

		# Animación ligera de balanceo del recorte 2.5D al caminar
		_walk_cycle += delta * 12.0
		if visual_sprite:
			visual_sprite.rotation.z = sin(_walk_cycle) * 0.08
			visual_sprite.position.y = absf(sin(_walk_cycle * 2.0)) * 0.06
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		velocity.z = move_toward(velocity.z, 0.0, friction * delta)
		if visual_sprite:
			visual_sprite.rotation.z = move_toward(visual_sprite.rotation.z, 0.0, delta * 4.0)
			visual_sprite.position.y = move_toward(visual_sprite.position.y, 0.0, delta * 2.0)

	move_and_slide()
	_update_camera(delta)
	_check_interactables()


func _update_camera(delta: float) -> void:
	if not camera:
		return
	var target_cam_pos := global_position + _cam_offset
	# Limitar cámara dentro de la sala para evitar que atraviese la pared trasera
	target_cam_pos.z = clampf(target_cam_pos.z, -6.5, 12.0)
	target_cam_pos.x = clampf(target_cam_pos.x, -9.0, 9.0)
	target_cam_pos.y = clampf(target_cam_pos.y, 2.2, 4.5)

	# Suavizado orbital elástico en 3ª persona
	var weight := clampf(8.0 * delta, 0.0, 1.0)
	camera.global_position = camera.global_position.lerp(target_cam_pos, weight)
	camera.global_position.z = clampf(camera.global_position.z, -6.5, 12.0)
	camera.global_position.x = clampf(camera.global_position.x, -9.0, 9.0)
	camera.global_position.y = clampf(camera.global_position.y, 2.2, 4.5)
	var look_target := global_position + Vector3(0.0, 1.2, 0.0)
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

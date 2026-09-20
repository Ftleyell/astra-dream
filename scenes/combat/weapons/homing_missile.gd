class_name HomingMissile
extends Node2D

@export var max_speed: float = 480.0
@export var acceleration: float = 650.0
@export var turn_rate: float = 8.0
@export var lifetime: float = 4.5
@export var explosion_radius: float = 65.0

var hit_context: HitContext
var target: Node2D = null
var current_velocity: Vector2 = Vector2.ZERO
var trail_points: Array[Vector2] = []
var max_trail: int = 8

@onready var trail_line: Line2D = $TrailLine
@onready var missile_body: Polygon2D = $MissileBody

func setup(p_origin: Vector2, p_initial_dir: Vector2, p_ctx: HitContext) -> void:
	global_position = p_origin
	current_velocity = p_initial_dir.normalized() * (max_speed * 0.4)
	rotation = current_velocity.angle()
	hit_context = p_ctx

func _ready() -> void:
	_acquire_nearest_target()

func _process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0:
		_explode()
		return

	# Re-adquirir objetivo si el actual es nulo o fue destruido
	if not is_instance_valid(target):
		_acquire_nearest_target()

	if is_instance_valid(target):
		var desired_dir := (target.global_position - global_position).normalized()
		var target_vel := desired_dir * max_speed
		current_velocity = current_velocity.move_toward(target_vel, acceleration * delta)
		# Rotación fluida
		var desired_angle := current_velocity.angle()
		rotation = rotate_toward(rotation, desired_angle, turn_rate * delta)
	else:
		# Si no hay objetivo, acelerar en línea recta
		current_velocity = current_velocity.move_toward(Vector2.from_angle(rotation) * max_speed, acceleration * delta)

	global_position += current_velocity * delta

	# Comprobar proximidad para detonación
	if is_instance_valid(target):
		if global_position.distance_squared_to(target.global_position) <= (explosion_radius * 0.4) * (explosion_radius * 0.4):
			_explode()
			return

	# Actualizar estela (trail)
	_update_trail()

func _update_trail() -> void:
	trail_points.push_front(global_position)
	if trail_points.size() > max_trail:
		trail_points.pop_back()

	trail_line.clear_points()
	for p in trail_points:
		trail_line.add_point(to_local(p))

func _acquire_nearest_target() -> void:
	# Buscar nodos en el grupo "enemies" o "emitters"
	var candidates := get_tree().get_nodes_in_group("enemies")
	if candidates.is_empty():
		candidates = get_tree().get_nodes_in_group("emitters")

	var nearest: Node2D = null
	var min_dist_sq := INF
	for node in candidates:
		if node is Node2D and is_instance_valid(node):
			var d_sq := global_position.distance_squared_to(node.global_position)
			if d_sq < min_dist_sq:
				min_dist_sq = d_sq
				nearest = node
	target = nearest

func _explode() -> void:
	# Daño radial en el área de explosión
	var space := get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	var circle := CircleShape2D.new()
	circle.radius = explosion_radius
	query.shape = circle
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = 2

	var hits := space.intersect_shape(query, 16)
	for hit in hits:
		var col: Node = hit["collider"]
		if col and col.has_method("take_damage"):
			var child_ctx := hit_context.fork_child_hit(hit_context.final_damage, 0.2, &"homing_missile")
			child_ctx.hit_position = global_position
			col.take_damage(child_ctx)

	# Efecto visual de explosión temporal
	var expl := Polygon2D.new()
	var pts: PackedVector2Array = []
	for i in range(12):
		var a := float(i) * TAU / 12.0
		var r := explosion_radius * randf_range(0.8, 1.2)
		pts.append(Vector2(cos(a), sin(a)) * r)
	expl.polygon = pts
	expl.color = Color(1.0, 0.6, 0.2, 0.8)
	expl.global_position = global_position
	get_parent().add_child(expl)

	var tween := expl.create_tween()
	tween.tween_property(expl, "scale", Vector2(1.3, 1.3), 0.2)
	tween.parallel().tween_property(expl, "modulate:a", 0.0, 0.2)
	tween.tween_callback(expl.queue_free)

	queue_free()

class_name HomingMissile
extends Node2D

@export var max_speed: float = 520.0
@export var acceleration: float = 750.0
@export var turn_rate: float = 9.0
@export var lifetime: float = 4.5
@export var explosion_radius: float = 70.0
@export var tracking_range: float = 520.0

var hit_context: HitContext
var target: Node2D = null
var current_velocity: Vector2 = Vector2.ZERO
var trail_points: Array[Vector2] = []
var max_trail: int = 10

@onready var trail_line: Line2D = $TrailLine
@onready var missile_body: Polygon2D = $MissileBody

func setup(p_origin: Vector2, p_initial_dir: Vector2, p_ctx: HitContext, p_target: Node2D = null) -> void:
	global_position = p_origin
	var dir := p_initial_dir.normalized() if p_initial_dir.length_squared() > 0.001 else Vector2.RIGHT
	current_velocity = dir * (max_speed * 0.5)
	rotation = current_velocity.angle()
	hit_context = p_ctx
	if p_target and is_instance_valid(p_target):
		target = p_target
	elif is_inside_tree():
		_acquire_nearest_target()

func _ready() -> void:
	if not target:
		_acquire_nearest_target()

func _process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0:
		_explode()
		return

	if not is_instance_valid(target):
		_acquire_nearest_target()

	if is_instance_valid(target):
		var desired_dir := (target.global_position - global_position).normalized()
		var target_vel := desired_dir * max_speed
		current_velocity = current_velocity.move_toward(target_vel, acceleration * delta)
		var desired_angle := current_velocity.angle()
		rotation = rotate_toward(rotation, desired_angle, turn_rate * delta)
	else:
		current_velocity = current_velocity.move_toward(Vector2.from_angle(rotation) * max_speed, acceleration * delta)

	global_position += current_velocity * delta

	if is_instance_valid(target):
		if global_position.distance_squared_to(target.global_position) <= 24.0 * 24.0:
			_explode()
			return

	_update_trail()

func _update_trail() -> void:
	if not trail_line:
		return
	trail_points.push_front(global_position)
	if trail_points.size() > max_trail:
		trail_points.pop_back()

	trail_line.clear_points()
	for p in trail_points:
		trail_line.add_point(to_local(p))

func _acquire_nearest_target() -> void:
	var candidates: Array[Node] = []
	candidates.append_array(get_tree().get_nodes_in_group("enemies"))
	candidates.append_array(get_tree().get_nodes_in_group("emitters"))

	var nearest: Node2D = null
	var max_dist_sq := tracking_range * tracking_range
	var min_dist_sq := max_dist_sq
	for node in candidates:
		if node is Node2D and is_instance_valid(node) and node != self and not node.get("is_dying"):
			var d_sq := global_position.distance_squared_to(node.global_position)
			if d_sq < min_dist_sq:
				min_dist_sq = d_sq
				nearest = node
	target = nearest

func _explode() -> void:
	var targets: Array[Node] = []
	targets.append_array(get_tree().get_nodes_in_group("enemies"))
	targets.append_array(get_tree().get_nodes_in_group("emitters"))
	targets.append_array(get_tree().get_nodes_in_group("destructibles"))

	var r_sq := explosion_radius * explosion_radius
	for node in targets:
		if node is Node2D and is_instance_valid(node):
			if global_position.distance_squared_to(node.global_position) <= r_sq:
				if node.has_method("take_damage") and hit_context:
					var child_ctx := hit_context.fork_child_hit(hit_context.final_damage, 0.2, &"homing_missile")
					child_ctx.hit_position = global_position
					node.take_damage(child_ctx)

	# Efecto visual de explosión
	var expl := Polygon2D.new()
	var pts: PackedVector2Array = []
	for i in range(12):
		var a := float(i) * TAU / 12.0
		var r := explosion_radius * randf_range(0.8, 1.2)
		pts.append(Vector2(cos(a), sin(a)) * r)
	expl.polygon = pts
	expl.color = Color(1.0, 0.6, 0.15, 0.85)
	expl.global_position = global_position
	var parent_node := get_parent() if is_inside_tree() else null
	if not parent_node and is_inside_tree():
		parent_node = get_tree().current_scene
	if parent_node:
		parent_node.add_child(expl)
		var tween := expl.create_tween()
		tween.tween_property(expl, "scale", Vector2(1.3, 1.3), 0.25)
		tween.parallel().tween_property(expl, "modulate:a", 0.0, 0.25)
		tween.tween_callback(expl.queue_free)

	queue_free()

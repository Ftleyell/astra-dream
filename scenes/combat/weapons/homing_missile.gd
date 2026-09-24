class_name HomingMissile
extends Node2D

## HomingMissile.gd (Rediseñado estilo Picayune Dreams: Proyectil Auto-Aimed en Línea Recta)
## Se apunta al enemigo al momento del lanzamiento, pero vuela en línea recta estricta.
## Puede errar al objetivo si este se desplaza. Si impacta contra cualquier enemigo u obstáculo,
## o si agota su tiempo de vida, detona causando daño de área.

@export var max_speed: float = 680.0
@export var speed: float = 680.0
@export var turn_rate: float = 0.0 # Vuelo recto estricto
@export var lifetime: float = 3.0
@export var impact_radius: float = 24.0
@export var explosion_radius: float = 75.0
@export var tracking_range: float = 520.0

var hit_context: HitContext
var flight_direction: Vector2 = Vector2.RIGHT
var current_velocity: Vector2 = Vector2.ZERO
var target: Node2D = null
var trail_points: Array[Vector2] = []
var max_trail: int = 10
var has_exploded: bool = false

@onready var trail_line: Line2D = $TrailLine
@onready var missile_body: Polygon2D = $MissileBody

func setup(p_origin: Vector2, p_initial_dir: Vector2, p_ctx: HitContext, p_target: Node2D = null) -> void:
	global_position = p_origin
	hit_context = p_ctx
	target = p_target

	# Si se proporcionó un objetivo válido, apuntamos en línea recta hacia él
	if p_target and is_instance_valid(p_target):
		var to_target := (p_target.global_position - p_origin).normalized()
		if to_target.length_squared() > 0.001:
			flight_direction = to_target
		else:
			flight_direction = p_initial_dir.normalized() if p_initial_dir.length_squared() > 0.001 else Vector2.RIGHT
	else:
		flight_direction = p_initial_dir.normalized() if p_initial_dir.length_squared() > 0.001 else Vector2.RIGHT

	current_velocity = flight_direction * speed
	rotation = flight_direction.angle()

func _ready() -> void:
	add_to_group("player_projectiles")
	if flight_direction.length_squared() > 0.001:
		current_velocity = flight_direction * speed
		rotation = flight_direction.angle()

func _process(delta: float) -> void:
	if has_exploded:
		return

	lifetime -= delta
	if lifetime <= 0.0:
		_explode()
		return

	# Vuelo estricto en línea recta (sin corrección de rumbo en vuelo)
	global_position += current_velocity * delta

	# Comprobación de impacto contra cualquier enemigo o emisor en el trayecto
	_check_impact_collision()
	_update_trail()

func _check_impact_collision() -> void:
	var tree := get_tree()
	if not tree:
		return

	var impact_sq := impact_radius * impact_radius
	for node in tree.get_nodes_in_group("enemies") + tree.get_nodes_in_group("emitters"):
		if node is Node2D and is_instance_valid(node) and not node.get("is_dying"):
			if global_position.distance_squared_to((node as Node2D).global_position) <= impact_sq:
				_explode()
				return

func _update_trail() -> void:
	if not trail_line:
		return
	trail_points.push_front(global_position)
	if trail_points.size() > max_trail:
		trail_points.pop_back()

	trail_line.clear_points()
	for p in trail_points:
		trail_line.add_point(to_local(p))

func _explode() -> void:
	if has_exploded:
		return
	has_exploded = true

	var targets: Array[Node] = []
	var tree := get_tree()
	if tree:
		targets.append_array(tree.get_nodes_in_group("enemies"))
		targets.append_array(tree.get_nodes_in_group("emitters"))
		targets.append_array(tree.get_nodes_in_group("destructibles"))

	var r_sq := explosion_radius * explosion_radius
	for node in targets:
		if node is Node2D and is_instance_valid(node) and not node.get("is_dying"):
			if global_position.distance_squared_to((node as Node2D).global_position) <= r_sq:
				if node.has_method("take_damage") and hit_context:
					var child_ctx := hit_context.fork_child_hit(hit_context.final_damage, 0.25, &"auto_aim_missile")
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
		tween.tween_property(expl, "scale", Vector2(1.3, 1.3), 0.22)
		tween.parallel().tween_property(expl, "modulate:a", 0.0, 0.22)
		tween.tween_callback(expl.queue_free)

	queue_free()

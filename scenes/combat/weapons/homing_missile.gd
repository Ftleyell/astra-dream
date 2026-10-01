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
var max_trail: int = 16
var has_exploded: bool = false

@onready var trail_line: Line2D = $TrailLine
@onready var missile_sprite: Sprite2D = get_node_or_null("MissileSprite")

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
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("player_projectiles")
	if flight_direction.length_squared() > 0.001:
		current_velocity = flight_direction * speed
		rotation = flight_direction.angle()

	if trail_line:
		var trail_tex := load("res://assets/sprites/effects/beam_trail_gradient.png") as Texture2D
		if trail_tex:
			trail_line.texture = trail_tex
			trail_line.texture_mode = Line2D.LINE_TEXTURE_STRETCH
		trail_line.begin_cap_mode = Line2D.LINE_CAP_NONE
		trail_line.end_cap_mode = Line2D.LINE_CAP_NONE
		var curve := Curve.new()
		curve.add_point(Vector2(0.0, 1.0))
		curve.add_point(Vector2(0.20, 0.82))
		curve.add_point(Vector2(0.48, 0.42))
		curve.add_point(Vector2(0.78, 0.12))
		curve.add_point(Vector2(1.0, 0.0))
		trail_line.width_curve = curve
		trail_line.width = 8.5
		trail_line.default_color = Color(1.0, 0.7, 0.2, 0.85)

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

	# Efecto visual de explosión suave esferoide y chispas radiales
	var parent_node := get_parent() if is_inside_tree() else null
	if not parent_node and is_inside_tree():
		parent_node = get_tree().current_scene

	var spark_scene: PackedScene = load("res://scenes/combat/weapons/kinetic_impact_vfx.tscn")
	if spark_scene and parent_node:
		var spark = spark_scene.instantiate()
		if spark:
			if spark.has_method("setup"):
				spark.setup(global_position, Color(1.0, 0.55, 0.15), explosion_radius * 0.7)
			parent_node.add_child(spark)

	var shock_scene: PackedScene = load("res://scenes/combat/weapons/shockwave_area.tscn")
	if shock_scene and parent_node:
		var shock := shock_scene.instantiate() as ShockwaveArea
		if shock:
			shock.setup(global_position, hit_context, clampf(explosion_radius / 220.0, 0.35, 1.0))
			parent_node.add_child(shock)

	queue_free()

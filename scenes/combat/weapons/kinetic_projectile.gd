class_name KineticProjectile
extends Node2D

@export var speed: float = 850.0
@export var lifetime: float = 2.5
@export var bounces_max: int = 0
@export var pierces_max: int = 1
@export var radius: float = 6.0
@export var is_boomerang: bool = false
@export var return_to_player: bool = false

var hit_context: HitContext
var velocity: Vector2 = Vector2.ZERO
var bounces_left: int = 0
var pierces_left: int = 1
var player: Node2D = null
var current_age: float = 0.0
var has_started_return: bool = false
var hit_targets: Array[Node2D] = []

@onready var trail_line: Line2D = get_node_or_null("TrailLine")
@onready var visual_poly: Polygon2D = get_node_or_null("VisualPolygon")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("player_projectiles")

func setup(p_origin: Vector2, p_dir: Vector2, p_ctx: HitContext, p_player: Node2D = null, p_speed_mult: float = 1.0, p_size_mult: float = 1.0) -> void:
	global_position = p_origin
	var dir := p_dir.normalized() if p_dir.length_squared() > 0.001 else Vector2.RIGHT
	velocity = dir * (speed * p_speed_mult)
	rotation = velocity.angle()
	hit_context = p_ctx
	player = p_player
	bounces_left = bounces_max
	pierces_left = pierces_max
	if p_size_mult != 1.0:
		scale = Vector2(p_size_mult, p_size_mult)
		radius *= p_size_mult
	add_to_group("player_projectiles")

func _process(delta: float) -> void:
	current_age += delta
	if current_age >= lifetime:
		queue_free()
		return

	if is_boomerang:
		if current_age >= lifetime * 0.4 and not has_started_return:
			has_started_return = true
		if has_started_return and is_instance_valid(player):
			var to_player := (player.global_position - global_position).normalized()
			velocity = velocity.move_toward(to_player * speed, speed * 2.5 * delta)
			rotation += 18.0 * delta
		else:
			rotation += 14.0 * delta
	else:
		rotation = velocity.angle()

	global_position += velocity * delta

	# Comprobación de impactos contra enemigos y destructibles
	_check_collisions()

func _check_collisions() -> void:
	var space_state := get_world_2d().direct_space_state
	if not space_state:
		return

	var r_sq := radius * radius
	var tree := get_tree()
	if not tree:
		return

	var potential_targets: Array[Node] = tree.get_nodes_in_group("enemies") + tree.get_nodes_in_group("destructibles") + tree.get_nodes_in_group("emitters")
	for node in potential_targets:
		if not is_instance_valid(node) or not (node is Node2D):
			continue
		var target := node as Node2D
		if target in hit_targets:
			continue
		var t_radius: float = target.get("obstacle_radius") if "obstacle_radius" in target else 24.0
		var hit_r := radius + t_radius
		if global_position.distance_squared_to(target.global_position) <= hit_r * hit_r:
			hit_targets.append(target)
			_apply_hit(target)
			if pierces_left <= 0:
				queue_free()
				return

func _apply_hit(target: Node2D) -> void:
	if target.has_method("take_damage"):
		var ctx := hit_context
		if not ctx:
			ctx = HitContext.new()
			ctx.final_damage = 25.0
			ctx.raw_damage = 25.0
		ctx.hit_position = global_position
		target.take_damage(ctx)

	pierces_left -= 1
	_spawn_spark_effect()

func _spawn_spark_effect() -> void:
	# Feedback visual breve al impactar
	pass

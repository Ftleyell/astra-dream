class_name PlasmaPellet
extends Node2D

@export var speed: float = 780.0
@export var lifetime: float = 0.85
@export var hit_radius: float = 14.0

var velocity: Vector2 = Vector2.ZERO
var hit_context: HitContext = null
var has_hit: bool = false

var trail_points: Array[Vector2] = []
var max_trail: int = 6

@onready var trail_line: Line2D = get_node_or_null("TrailLine")
@onready var pellet_core: Polygon2D = get_node_or_null("PelletCore")
@onready var pellet_glow: Polygon2D = get_node_or_null("PelletGlow")

func setup(p_origin: Vector2, p_dir: Vector2, p_ctx: HitContext, p_speed: float = 780.0, p_lifetime: float = 0.85) -> void:
	global_position = p_origin
	speed = p_speed
	lifetime = p_lifetime
	hit_context = p_ctx
	var dir := p_dir.normalized() if p_dir.length_squared() > 0.001 else Vector2.RIGHT
	velocity = dir * speed
	rotation = dir.angle()

func _ready() -> void:
	if trail_line:
		trail_line.clear_points()

func _process(delta: float) -> void:
	if has_hit:
		return

	lifetime -= delta
	if lifetime <= 0.0:
		_dissipate()
		return

	global_position += velocity * delta
	_update_trail()
	_check_collisions()

func _update_trail() -> void:
	if not trail_line:
		return

	trail_points.push_front(global_position)
	if trail_points.size() > max_trail:
		trail_points.pop_back()

	trail_line.clear_points()
	for p in trail_points:
		trail_line.add_point(to_local(p))

func _check_collisions() -> void:
	var r_sq := hit_radius * hit_radius
	var targets: Array[Node] = []
	targets.append_array(get_tree().get_nodes_in_group("enemies"))
	targets.append_array(get_tree().get_nodes_in_group("emitters"))

	for node in targets:
		if node is Node2D and is_instance_valid(node):
			var d_sq := global_position.distance_squared_to(node.global_position)
			if d_sq <= r_sq:
				_on_hit_target(node)
				return

func _on_hit_target(target: Node2D) -> void:
	has_hit = true

	if target.has_method("take_damage") and hit_context:
		var pellet_ctx := hit_context.fork_child_hit(
			hit_context.final_damage,
			hit_context.proc_coefficient,
			&"plasma_pellet"
		)
		pellet_ctx.hit_position = global_position
		target.take_damage(pellet_ctx)

		# Notificar procs de inventario si el atacante es Player
		if hit_context.attacker is Player:
			var player := hit_context.attacker as Player
			if player.inventory:
				player.inventory.process_hit_procs(pellet_ctx, player)

	_spawn_impact_burst()
	queue_free()

func _dissipate() -> void:
	has_hit = true
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.08)
	tween.tween_callback(queue_free)

func _spawn_impact_burst() -> void:
	var burst := Polygon2D.new()
	var pts: PackedVector2Array = []
	for i in range(8):
		var a := float(i) * TAU / 8.0
		var r := randf_range(10.0, 20.0)
		pts.append(Vector2(cos(a), sin(a)) * r)

	burst.polygon = pts
	burst.color = Color(0.2, 0.95, 1.0, 0.9)
	burst.global_position = global_position

	var parent_node := get_parent() if is_inside_tree() else null
	if not parent_node and is_inside_tree():
		parent_node = get_tree().current_scene
	if parent_node:
		parent_node.add_child(burst)
		var tween := burst.create_tween()
		tween.tween_property(burst, "scale", Vector2(1.5, 1.5), 0.16)
		tween.parallel().tween_property(burst, "modulate:a", 0.0, 0.16)
		tween.tween_callback(burst.queue_free)

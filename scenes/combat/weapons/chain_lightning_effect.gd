class_name ChainLightningEffect
extends Node2D

@export var max_jumps: int = 4
@export var jump_radius: float = 320.0
@export var duration: float = 0.22

var hit_context: HitContext
var bolt_points: Array[Vector2] = []

var origin_pos: Vector2 = Vector2.ZERO
var target_pos: Vector2 = Vector2.ZERO
var has_generated: bool = false

@onready var line: Line2D = $BoltLine

func setup(p_origin: Vector2, p_target_pos: Vector2, p_ctx: HitContext, p_jumps: int = 4) -> void:
	global_position = Vector2.ZERO
	origin_pos = p_origin
	target_pos = p_target_pos
	hit_context = p_ctx
	max_jumps = p_jumps
	if is_inside_tree():
		_generate_chain()

func _ready() -> void:
	if not has_generated and (origin_pos != Vector2.ZERO or target_pos != Vector2.ZERO):
		_generate_chain()

func _generate_chain() -> void:
	if has_generated:
		return
	has_generated = true

	if not line:
		line = $BoltLine

	bolt_points.clear()
	bolt_points.append(origin_pos)
	bolt_points.append(target_pos)

	var current_pos := target_pos
	var hit_nodes: Array[Node2D] = []

	var tree := get_tree()
	if not tree:
		_draw_bolt()
		return

	# Dañar primer objetivo si existe o buscar el más cercano al cursor o al jugador
	var enemies := tree.get_nodes_in_group("enemies") + tree.get_nodes_in_group("destructibles") + tree.get_nodes_in_group("emitters")
	var initial_target: Node2D = null
	var best_first_d_sq := 320.0 * 320.0

	for node in enemies:
		if is_instance_valid(node) and node is Node2D and not node.get("is_dying"):
			var n2d := node as Node2D
			var d_sq: float = n2d.global_position.distance_squared_to(target_pos)
			if d_sq <= best_first_d_sq:
				best_first_d_sq = d_sq
				initial_target = n2d

	# Si no había nadie cerca del cursor, buscar el más cercano al jugador dentro de rango
	if not initial_target:
		var best_player_d_sq := 520.0 * 520.0
		for node in enemies:
			if is_instance_valid(node) and node is Node2D and not node.get("is_dying"):
				var n2d := node as Node2D
				var d_sq: float = n2d.global_position.distance_squared_to(origin_pos)
				if d_sq <= best_player_d_sq:
					best_player_d_sq = d_sq
					initial_target = n2d

	if initial_target:
		hit_nodes.append(initial_target)
		target_pos = initial_target.global_position
		bolt_points[1] = target_pos
		current_pos = target_pos
		_damage_target(initial_target, 1.0)

	# Encadenamiento subsiguiente
	var jumps_left := max_jumps - 1
	var jump_r_sq := jump_radius * jump_radius

	while jumps_left > 0:
		var best_next: Node2D = null
		var best_d_sq: float = jump_r_sq

		for node in enemies:
			if not is_instance_valid(node) or not (node is Node2D) or node.get("is_dying"):
				continue
			var cand := node as Node2D
			if hit_nodes.has(cand):
				continue
			var d_sq := current_pos.distance_squared_to(cand.global_position)
			if d_sq <= best_d_sq:
				best_d_sq = d_sq
				best_next = cand

		if best_next:
			hit_nodes.append(best_next)
			current_pos = best_next.global_position
			bolt_points.append(current_pos)
			var falloff := 1.0 - (float(max_jumps - jumps_left) * 0.08) # Mantiene daño alto en todos los saltos
			_damage_target(best_next, maxf(0.65, falloff))
			jumps_left -= 1
		else:
			break

	_draw_bolt()

func _damage_target(target: Node2D, multiplier: float) -> void:
	if target.has_method("take_damage"):
		var c := HitContext.new()
		if hit_context:
			c.attacker = hit_context.attacker
			c.raw_damage = hit_context.raw_damage * multiplier
			c.final_damage = hit_context.final_damage * multiplier
			c.is_crit = hit_context.is_crit
			c.proc_coefficient = hit_context.proc_coefficient
		else:
			c.raw_damage = 30.0 * multiplier
			c.final_damage = 30.0 * multiplier
			c.proc_coefficient = 0.5
		c.hit_position = target.global_position
		target.take_damage(c)

func _draw_bolt() -> void:
	var jagged_points: PackedVector2Array = PackedVector2Array()
	for i in range(bolt_points.size() - 1):
		var p1 := bolt_points[i]
		var p2 := bolt_points[i + 1]
		jagged_points.append(p1)
		# Subdivisión con desplazamiento aleatorio estilo rayo eléctrico
		var mid := (p1 + p2) * 0.5
		var norm := (p2 - p1).orthogonal().normalized()
		var jitter := randf_range(-18.0, 18.0)
		jagged_points.append(mid + norm * jitter)
	if not bolt_points.is_empty():
		jagged_points.append(bolt_points.back())

	line.points = jagged_points

	var tw := create_tween()
	tw.tween_property(line, "width", 0.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(queue_free)

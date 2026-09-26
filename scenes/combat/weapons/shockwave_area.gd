class_name ShockwaveArea
extends Node2D

@export var max_radius: float = 220.0
@export var duration: float = 0.35
@export var push_force: float = 450.0

var hit_context: HitContext
var current_time: float = 0.0
var current_radius: float = 0.0
var damaged_nodes: Array[Node2D] = []

@onready var ring_line: Line2D = $RingLine

func setup(p_origin: Vector2, p_ctx: HitContext, p_size_mult: float = 1.0) -> void:
	global_position = p_origin
	hit_context = p_ctx
	max_radius *= p_size_mult
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE

func _process(delta: float) -> void:
	current_time += delta
	var t := current_time / duration
	if t >= 1.0:
		queue_free()
		return

	current_radius = max_radius * sqrt(t)
	_update_ring_visual(t)
	_check_shockwave_hits()

func _update_ring_visual(t: float) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	var segs := 32
	for i in range(segs + 1):
		var angle := float(i) * TAU / float(segs)
		pts.append(Vector2(cos(angle), sin(angle)) * current_radius)
	ring_line.points = pts
	ring_line.width = lerpf(6.0, 1.0, t)
	ring_line.default_color.a = 1.0 - t

func _check_shockwave_hits() -> void:
	var tree := get_tree()
	if not tree:
		return

	var r_sq := current_radius * current_radius
	var targets: Array[Node] = tree.get_nodes_in_group("enemies") + tree.get_nodes_in_group("destructibles") + tree.get_nodes_in_group("emitters")
	for node in targets:
		if not is_instance_valid(node) or not (node is Node2D):
			continue
		var target := node as Node2D
		if damaged_nodes.has(target):
			continue

		var d_sq := global_position.distance_squared_to(target.global_position)
		if d_sq <= r_sq:
			damaged_nodes.append(target)
			if target.has_method("take_damage"):
				var c := hit_context
				if not c:
					c = HitContext.new()
					c.raw_damage = 30.0
					c.final_damage = 30.0
				c.hit_position = target.global_position
				target.take_damage(c)

			# Empuje radial
			var push_dir := (target.global_position - global_position).normalized()
			if push_dir.length_squared() < 0.001:
				push_dir = Vector2.RIGHT
			target.global_position += push_dir * (push_force * (1.0 - (sqrt(d_sq) / max_radius)) * 0.1)

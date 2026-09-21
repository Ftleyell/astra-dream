class_name ScreenLaserBeam
extends Node2D

@export var beam_length: float = 2600.0
@export var beam_width: float = 12.0
@export var duration: float = 0.3

var hit_context: HitContext
var origin_pos: Vector2
var beam_dir: Vector2

@onready var outer_line: Line2D = $OuterLine
@onready var core_line: Line2D = $CoreLine

func setup(p_origin: Vector2, p_dir: Vector2, p_ctx: HitContext) -> void:
	origin_pos = p_origin
	beam_dir = p_dir.normalized() if p_dir.length_squared() > 0.001 else Vector2.RIGHT
	hit_context = p_ctx
	global_position = origin_pos
	_activate_laser()

func _ready() -> void:
	# Si ya se llamó setup, _activate_laser ya configuró los puntos
	if beam_dir.length_squared() > 0.001:
		_activate_laser()

func _activate_laser() -> void:
	if not is_inside_tree():
		return
	if not outer_line or not core_line:
		outer_line = $OuterLine
		core_line = $CoreLine

	var end_local := beam_dir * beam_length

	outer_line.clear_points()
	outer_line.add_point(Vector2.ZERO)
	outer_line.add_point(end_local)
	outer_line.width = beam_width
	outer_line.default_color = Color(0.2, 0.9, 1.0, 0.95)

	core_line.clear_points()
	core_line.add_point(Vector2.ZERO)
	core_line.add_point(end_local)
	core_line.width = beam_width * 0.35
	core_line.default_color = Color(1.0, 1.0, 1.0, 1.0)

	_apply_laser_damage(global_position, global_position + end_local)

	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, duration)
	tween.tween_callback(queue_free)

func _apply_laser_damage(start_point: Vector2, end_point: Vector2) -> void:
	var hit_radius: float = 28.0 # Ancho efectivo de daño
	var hit_radius_sq: float = hit_radius * hit_radius

	# Comprobar todos los enemigos en grupos de combate
	var targets: Array[Node] = []
	targets.append_array(get_tree().get_nodes_in_group("enemies"))
	targets.append_array(get_tree().get_nodes_in_group("emitters"))
	targets.append_array(get_tree().get_nodes_in_group("destructibles"))

	for node in targets:
		if node is Node2D and is_instance_valid(node):
			var dist_sq := _dist_to_segment_sq(node.global_position, start_point, end_point)
			if dist_sq <= hit_radius_sq:
				if node.has_method("take_damage") and hit_context:
					var child_ctx := hit_context.fork_child_hit(hit_context.final_damage, 0.4, &"screen_laser")
					child_ctx.hit_position = node.global_position
					node.take_damage(child_ctx)

func _dist_to_segment_sq(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var ap := p - a
	var len_sq := ab.length_squared()
	if len_sq == 0.0:
		return ap.length_squared()
	var t := clampf(ap.dot(ab) / len_sq, 0.0, 1.0)
	var proj := a + ab * t
	return p.distance_squared_to(proj)

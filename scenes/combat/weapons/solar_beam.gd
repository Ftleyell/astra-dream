class_name SolarBeam
extends Node2D

@export var beam_length: float = 2200.0
@export var beam_width: float = 16.0
@export var duration: float = 0.55
@export var tick_rate: float = 0.08

var hit_context: HitContext
var beam_dir: Vector2 = Vector2.RIGHT
var current_time: float = 0.0
var tick_timer: float = 0.0

@onready var outer_line: Line2D = $OuterLine
@onready var core_line: Line2D = $CoreLine

func setup(p_origin: Vector2, p_dir: Vector2, p_ctx: HitContext, p_width_mult: float = 1.0) -> void:
	global_position = p_origin
	beam_dir = p_dir.normalized() if p_dir.length_squared() > 0.001 else Vector2.RIGHT
	hit_context = p_ctx
	beam_width *= p_width_mult
	_update_beam_visual()
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE

func _process(delta: float) -> void:
	current_time += delta
	if current_time >= duration:
		queue_free()
		return

	# Pulsación de calor visual
	var pulse := sin(current_time * 30.0) * 2.0
	if outer_line and core_line:
		outer_line.width = beam_width + pulse
		core_line.width = (beam_width * 0.4) + pulse * 0.5

	tick_timer += delta
	if tick_timer >= tick_rate:
		tick_timer = 0.0
		_apply_solar_tick()

func _update_beam_visual() -> void:
	if not outer_line or not core_line:
		outer_line = $OuterLine
		core_line = $CoreLine
	var pts := PackedVector2Array([Vector2.ZERO, beam_dir * beam_length])
	outer_line.points = pts
	core_line.points = pts
	outer_line.width = beam_width
	core_line.width = beam_width * 0.4

func _apply_solar_tick() -> void:
	var tree := get_tree()
	if not tree:
		return

	var start_p := global_position
	var end_p := global_position + beam_dir * beam_length
	var targets: Array[Node] = tree.get_nodes_in_group("enemies") + tree.get_nodes_in_group("destructibles")

	for node in targets:
		if is_instance_valid(node) and node is Node2D:
			var target := node as Node2D
			var d := _dist_to_segment(target.global_position, start_p, end_p)
			if d <= beam_width * 1.5 + 20.0:
				if target.has_method("take_damage"):
					var c := HitContext.new()
					if hit_context:
						c.attacker = hit_context.attacker
						c.raw_damage = hit_context.raw_damage * 0.22
						c.final_damage = hit_context.final_damage * 0.22
						c.is_crit = hit_context.is_crit
					else:
						c.raw_damage = 8.0
						c.final_damage = 8.0
					c.proc_coefficient = 0.2
					c.hit_position = target.global_position
					target.take_damage(c)

func _dist_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var ap := p - a
	var len_sq := ab.length_squared()
	if len_sq < 0.0001:
		return p.distance_to(a)
	var t := clampf(ap.dot(ab) / len_sq, 0.0, 1.0)
	var proj := a + t * ab
	return p.distance_to(proj)

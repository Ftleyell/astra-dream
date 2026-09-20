class_name ScreenLaserBeam
extends Node2D

@export var beam_length: float = 2500.0
@export var beam_width: float = 8.0
@export var duration: float = 0.25

var hit_context: HitContext
var origin_pos: Vector2
var beam_dir: Vector2

@onready var outer_line: Line2D = $OuterLine
@onready var core_line: Line2D = $CoreLine

func setup(p_origin: Vector2, p_dir: Vector2, p_ctx: HitContext) -> void:
	origin_pos = p_origin
	beam_dir = p_dir.normalized()
	hit_context = p_ctx
	global_position = origin_pos

func _ready() -> void:
	var end_pos := beam_dir * beam_length

	outer_line.clear_points()
	outer_line.add_point(Vector2.ZERO)
	outer_line.add_point(end_pos)
	outer_line.width = beam_width
	outer_line.default_color = Color(0.2, 0.8, 1.0, 0.9)

	core_line.clear_points()
	core_line.add_point(Vector2.ZERO)
	core_line.add_point(end_pos)
	core_line.width = beam_width * 0.4
	core_line.default_color = Color(1.0, 1.0, 1.0, 1.0)

	_apply_laser_damage(end_pos)

	# Animación de desvanecimiento suave (fade out)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, duration)
	tween.tween_callback(queue_free)

func _apply_laser_damage(end_point_local: Vector2) -> void:
	var global_end := global_position + end_point_local
	var space := get_world_2d().direct_space_state

	# Detección a lo largo del segmento del láser
	var query := PhysicsRayQueryParameters2D.create(global_position, global_end)
	query.collision_mask = 2 # Capa de enemigos / objetivos
	query.collide_with_areas = true
	query.collide_with_bodies = true

	# Impactar a todos los objetivos que cruzan la línea
	var max_penetrations := 12
	var current_start := global_position
	for i in range(max_penetrations):
		query.from = current_start
		var result := space.intersect_ray(query)
		if result.is_empty():
			break

		var collider: Node = result["collider"]
		if collider and collider.has_method("take_damage"):
			var child_ctx := hit_context.fork_child_hit(hit_context.final_damage, 0.3, &"laser_beam")
			child_ctx.hit_position = result["position"]
			collider.take_damage(child_ctx)

		# Avanzar ligeramente pasando el punto de impacto para seguir atravesando
		current_start = result["position"] + beam_dir * 12.0

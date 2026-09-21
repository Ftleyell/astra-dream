class_name ScreenLaserBeam
extends Node2D

## ScreenLaserBeam.gd
## Haz láser de pantalla completa con detección física y geométrica de colisión.
## Al impactar un cuerpo sólido o destructible (capa exterior de un planeta o asteroide):
## 1. Corta la línea visual exactamente en el punto de contacto en la superficie.
## 2. Aplica daño ÚNICAMENTE al segmento exterior impactado (y enemigos en trayectoria frontal).
## 3. Jamás atraviesa el cuerpo ni alcanza capas inferiores o la cara opuesta del planeta.

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
	if beam_dir.length_squared() > 0.001:
		_activate_laser()


func _activate_laser() -> void:
	if not is_inside_tree():
		return
	if not outer_line or not core_line:
		outer_line = $OuterLine
		core_line = $CoreLine

	var max_reach := beam_dir * beam_length
	var solid_hit_pos := global_position + max_reach
	var solid_hit_target: Node2D = null
	var has_solid_hit := false

	# 1. Raycast físico directo contra cuerpos sólidos (PlanetSegment, Asteroids, etc.)
	var space_state := get_world_2d().direct_space_state
	if space_state:
		var query := PhysicsRayQueryParameters2D.create(global_position, global_position + max_reach)
		query.collision_mask = 1 # Capa 1: Sólidos físicos del mundo
		query.collide_with_bodies = true
		query.collide_with_areas = false
		if hit_context and is_instance_valid(hit_context.attacker):
			query.exclude = [hit_context.attacker.get_rid()]

		var res := space_state.intersect_ray(query)
		if res:
			solid_hit_pos = res.position
			has_solid_hit = true
			if res.collider is Node2D:
				solid_hit_target = res.collider as Node2D

	# 2. Respaldo geométrico: verificar si algún objeto destructible está antes en el trayecto
	var current_solid_dist := (solid_hit_pos - global_position).length()
	var destructibles := get_tree().get_nodes_in_group("destructibles")
	for d_node in destructibles:
		if d_node is Node2D and is_instance_valid(d_node) and not d_node.get("is_dying"):
			var to_node := (d_node as Node2D).global_position - global_position
			var proj := to_node.dot(beam_dir)
			if proj > 0.0 and proj < current_solid_dist:
				var perp_sq := (to_node - beam_dir * proj).length_squared()
				# Margen de contacto con el centroide del gajo
				if perp_sq <= 36.0 * 36.0:
					current_solid_dist = proj
					solid_hit_pos = global_position + beam_dir * proj
					solid_hit_target = d_node as Node2D
					has_solid_hit = true

	# 3. El haz visual termina exactamente en el punto de contacto
	var end_local := solid_hit_pos - global_position

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

	# 4. Chispas de impacto en la superficie del planeta
	if has_solid_hit:
		_spawn_impact_fx(solid_hit_pos)

	# 5. Aplicar daño exclusivamente hasta el punto de impacto
	_apply_bounded_damage(global_position, solid_hit_pos, solid_hit_target)

	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, duration)
	tween.tween_callback(queue_free)


func _apply_bounded_damage(start_point: Vector2, hit_point: Vector2, primary_solid_target: Node2D) -> void:
	var hit_radius: float = 28.0
	var hit_radius_sq: float = hit_radius * hit_radius

	# 1. Dañar a los enemigos normales o emisores que se encuentren en la trayectoria frontal antes del impacto
	var enemies: Array[Node] = []
	enemies.append_array(get_tree().get_nodes_in_group("enemies"))
	enemies.append_array(get_tree().get_nodes_in_group("emitters"))

	for node in enemies:
		if node is Node2D and is_instance_valid(node) and not node.get("is_dying"):
			var dist_sq := _dist_to_segment_sq(node.global_position, start_point, hit_point)
			if dist_sq <= hit_radius_sq:
				if node.has_method("take_damage") and hit_context:
					var child_ctx := hit_context.fork_child_hit(hit_context.final_damage, 0.4, &"screen_laser")
					child_ctx.hit_position = node.global_position
					node.take_damage(child_ctx)

	# 2. Dañar ÚNICAMENTE el obstáculo sólido o segmento exterior impactado
	if is_instance_valid(primary_solid_target) and primary_solid_target.has_method("take_damage") and hit_context:
		var child_ctx := hit_context.fork_child_hit(hit_context.final_damage, 0.4, &"screen_laser")
		child_ctx.hit_position = hit_point
		primary_solid_target.take_damage(child_ctx)


func _dist_to_segment_sq(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var ap := p - a
	var len_sq := ab.length_squared()
	if len_sq == 0.0:
		return ap.length_squared()
	var t := clampf(ap.dot(ab) / len_sq, 0.0, 1.0)
	var proj := a + ab * t
	return p.distance_squared_to(proj)


func _spawn_impact_fx(pos: Vector2) -> void:
	var spark := Line2D.new()
	spark.width = 3.5
	spark.default_color = Color(1.0, 0.95, 0.5, 1.0)
	for i in range(6):
		var ang := randf() * TAU
		var l := randf_range(12.0, 28.0)
		spark.add_point(Vector2.ZERO)
		spark.add_point(Vector2(cos(ang), sin(ang)) * l)
	spark.global_position = pos

	var scene_root := get_tree().current_scene
	if scene_root:
		scene_root.add_child(spark)
		var tw := spark.create_tween()
		tw.tween_property(spark, "modulate:a", 0.0, 0.18)
		tw.tween_callback(spark.queue_free)

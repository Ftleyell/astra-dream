class_name Asteroid
extends "res://scenes/combat/environment/destructible_space_object.gd"

## Asteroid.gd
## Asteroide destructible con mecánica clásica de división y recompensas de EXP.
## Hereda de DestructibleSpaceObject.

enum SizeTier {
	LARGE,
	MEDIUM,
	SMALL
}

@export var size_tier: SizeTier = SizeTier.LARGE
@export var fragment_scene: PackedScene

# Parámetros visuales y físicos por nivel
var base_radius: float = 46.0
var base_health: float = 90.0
var base_xp: int = 0

@onready var visual_polygon: Polygon2D = get_node_or_null("VisualPolygon")
@onready var border_line: Line2D = get_node_or_null("BorderLine")
@onready var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D")
@onready var hurtbox_shape: CollisionShape2D = get_node_or_null("HurtboxComponent/CollisionShape2D")


func _ready() -> void:
	add_to_group("asteroids")
	if not fragment_scene:
		fragment_scene = load("res://scenes/combat/environment/asteroid.tscn") as PackedScene

	_configure_tier_stats()
	_generate_procedural_rock_shape()
	super._ready()


## Configura salud, radio y botín según el nivel de tamaño del asteroide
func _configure_tier_stats() -> void:
	match size_tier:
		SizeTier.LARGE:
			tier = 3
			base_radius = randf_range(44.0, 52.0)
			base_health = 90.0
			base_xp = 0 # La recompensa se obtiene al romper los fragmentos
		SizeTier.MEDIUM:
			tier = 2
			base_radius = randf_range(24.0, 30.0)
			base_health = 45.0
			base_xp = 5
		SizeTier.SMALL:
			tier = 1
			base_radius = randf_range(13.0, 17.0)
			base_health = 20.0
			base_xp = 15 # Misma recompensa de EXP que un dron enemigo

	obstacle_radius = base_radius

	if health_component:
		health_component.max_health = base_health
		health_component.current_health = base_health

	if drop_component:
		drop_component.xp_amount = base_xp
		drop_component.drop_chance = 1.0 if base_xp > 0 else 0.0

	# Ajustar forma de colisión y hurtbox
	_update_collision_radii(base_radius)


## Genera un contorno rocoso facetado aleatorio para variedad visual
func _generate_procedural_rock_shape() -> void:
	if not visual_polygon:
		return

	var num_points: int = 12 if size_tier == SizeTier.LARGE else (10 if size_tier == SizeTier.MEDIUM else 8)
	var pts: PackedVector2Array = []
	for i in range(num_points):
		var angle: float = (TAU / float(num_points)) * float(i)
		var r: float = base_radius * randf_range(0.82, 1.18)
		pts.append(Vector2(cos(angle), sin(angle)) * r)

	visual_polygon.polygon = pts

	# Paleta de roca espacial (gris ceniza oscuro con leve tono azulado/ámbar)
	var color_shade: float = randf_range(0.38, 0.48)
	visual_polygon.color = Color(color_shade, color_shade * 0.98, color_shade * 1.05, 1.0)

	if border_line:
		border_line.clear_points()
		for p in pts:
			border_line.add_point(p)
		if pts.size() > 0:
			border_line.add_point(pts[0]) # Cerrar el loop
		border_line.width = 2.0 if size_tier != SizeTier.LARGE else 3.0
		border_line.default_color = visual_polygon.color.lightened(0.3)


func _update_collision_radii(radius: float) -> void:
	if collision_shape and collision_shape.shape is CircleShape2D:
		(collision_shape.shape as CircleShape2D).radius = radius
	if hurtbox_shape and hurtbox_shape.shape is CircleShape2D:
		(hurtbox_shape.shape as CircleShape2D).radius = radius + 2.0


## Sobrescribe la secuencia de muerte con fragmentación en cascada
func _die() -> void:
	if is_dying:
		return
	is_dying = true
	destroyed.emit(self)
	shattered.emit(global_position, tier)

	_unregister_from_bullet_server()

	# Emitir metralla cinemática reactiva con knockback
	var shard_script = preload("res://scenes/combat/environment/shrapnel_shard.gd")
	if shard_script:
		shard_script.spawn_shattered_burst(self, global_position, tier, -1, shard_color)

	_disable_collisions()

	# 1. Spawnear fragmentos si corresponde al tamaño
	_spawn_fragments()

	# 2. Generar drops de EXP (DropComponent) si es fragmento final o contiene XP
	if drop_component and base_xp > 0:
		drop_component.spawn_drops()

	# 3. Efecto visual de desintegración/polvo rocoso
	_play_fracture_effect()


func _spawn_fragments() -> void:
	if not fragment_scene or not is_inside_tree():
		return

	var num_fragments: int = 0
	var next_tier: SizeTier = SizeTier.SMALL

	match size_tier:
		SizeTier.LARGE:
			num_fragments = randi_range(2, 3)
			next_tier = SizeTier.MEDIUM
		SizeTier.MEDIUM:
			num_fragments = 2
			next_tier = SizeTier.SMALL
		SizeTier.SMALL:
			return # Los pequeños se destruyen liberando la gema de EXP directamente

	var container: Node = get_parent()
	if not container:
		container = get_tree().current_scene

	for i in range(num_fragments):
		var frag := fragment_scene.instantiate() as Asteroid
		if not frag:
			continue

		frag.size_tier = next_tier
		frag.global_position = global_position + Vector2(randf_range(-10, 10), randf_range(-10, 10))

		# Vector de dispersión outward
		var spread_angle: float = (TAU / float(num_fragments)) * float(i) + randf_range(-0.3, 0.3)
		var frag_speed: float = randf_range(80.0, 160.0)
		frag.drift_velocity = drift_velocity * 0.4 + Vector2(cos(spread_angle), sin(spread_angle)) * frag_speed
		frag.angular_velocity = randf_range(-3.0, 3.0)

		container.call_deferred("add_child", frag)


func _play_fracture_effect() -> void:
	# Desvanecimiento y dispersión visual mediante Tween
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", scale * 1.3, 0.15)
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	tween.chain().tween_callback(queue_free)

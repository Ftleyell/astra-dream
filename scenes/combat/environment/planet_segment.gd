class_name PlanetSegment
extends CharacterBody2D

## PlanetSegment.gd
## Segmento angular destructible de una capa concéntrica planetaria (corteza o manto).
## Gestiona su propia salud, polígono geométrico, recepción de daño y desprendimiento.

signal segment_destroyed(segment: PlanetSegment)

@export var inner_radius: float = 30.0
@export var outer_radius: float = 55.0
@export var start_angle: float = 0.0
@export var end_angle: float = 1.0
@export var segment_color: Color = Color(0.35, 0.45, 0.28, 1.0)
@export var border_color: Color = Color(0.55, 0.75, 0.45, 1.0)
@export var biomass_reward: int = 2
@export var max_segment_health: float = 60.0

var is_dying: bool = false
var biomass_orb_scene: PackedScene = preload("res://scenes/combat/pickups/biomass_orb.tscn")

@onready var visual_polygon: Polygon2D = get_node_or_null("VisualPolygon")
@onready var border_line: Line2D = get_node_or_null("BorderLine")
@onready var collision_poly: CollisionPolygon2D = get_node_or_null("CollisionPolygon2D")
@onready var hurtbox_poly: CollisionPolygon2D = get_node_or_null("HurtboxComponent/CollisionPolygon2D")
@onready var health_component: HealthComponent = get_node_or_null("HealthComponent")
@onready var hurtbox_component: HurtboxComponent = get_node_or_null("HurtboxComponent")
@onready var hit_flash_component: HitFlashComponent = get_node_or_null("HitFlashComponent")


func _ready() -> void:
	add_to_group("destructibles")
	collision_layer = 0
	collision_mask = 0

	if health_component:
		health_component.max_health = max_segment_health
		health_component.current_health = max_segment_health
		if not health_component.health_depleted.is_connected(_on_health_depleted):
			health_component.health_depleted.connect(_on_health_depleted)

	if hurtbox_component and health_component:
		hurtbox_component.health_component = health_component

	rebuild_geometry()


func setup_segment(r_in: float, r_out: float, a_start: float, a_end: float, col: Color, b_col: Color, hp: float, xp_biomass: int) -> void:
	inner_radius = r_in
	outer_radius = r_out
	start_angle = a_start
	end_angle = a_end
	segment_color = col
	border_color = b_col
	max_segment_health = hp
	biomass_reward = xp_biomass
	if is_inside_tree():
		if health_component:
			health_component.max_health = max_segment_health
			health_component.current_health = max_segment_health
		rebuild_geometry()


## Construye el polígono en forma de cuña/arco concéntrico
func rebuild_geometry() -> void:
	var pts: PackedVector2Array = []
	var steps: int = 5 # Resolución angular por segmento

	# Arco exterior (de start_angle a end_angle)
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var ang := lerpf(start_angle, end_angle, t)
		pts.append(Vector2(cos(ang), sin(ang)) * outer_radius)

	# Arco interior (de end_angle a start_angle)
	for i in range(steps, -1, -1):
		var t := float(i) / float(steps)
		var ang := lerpf(start_angle, end_angle, t)
		pts.append(Vector2(cos(ang), sin(ang)) * inner_radius)

	if visual_polygon:
		visual_polygon.polygon = pts
		visual_polygon.color = segment_color

	if border_line:
		border_line.clear_points()
		for p in pts:
			border_line.add_point(p)
		if pts.size() > 0:
			border_line.add_point(pts[0])
		border_line.default_color = border_color
		border_line.width = 1.8

	if collision_poly:
		collision_poly.polygon = pts
	if hurtbox_poly:
		hurtbox_poly.polygon = pts


## Contrato canónico de daño
func take_damage(ctx: HitContext) -> void:
	if is_dying or not ctx:
		return
	if health_component:
		health_component.take_damage(ctx.final_damage, ctx.is_crit)
	else:
		_die()


func _on_health_depleted() -> void:
	_die()


func _die() -> void:
	if is_dying:
		return
	is_dying = true
	segment_destroyed.emit(self)

	# Desactivar colisiones de inmediato
	if collision_poly:
		collision_poly.set_deferred("disabled", true)
	if hurtbox_component:
		hurtbox_component.set_deferred("monitoring", false)
		hurtbox_component.set_deferred("monitorable", false)

	# 1. Spawnear orbe de BioMasa
	_spawn_biomass()

	# 2. Animación de fractura y desprendimiento radial
	var mid_angle := (start_angle + end_angle) * 0.5
	var outward_dir := Vector2(cos(mid_angle), sin(mid_angle))

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position", position + outward_dir * 35.0, 0.2)
	tween.tween_property(self, "scale", scale * 1.15, 0.2)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.chain().tween_callback(queue_free)


func _spawn_biomass() -> void:
	if not biomass_orb_scene:
		return

	var mid_angle := (start_angle + end_angle) * 0.5
	var mid_radius := (inner_radius + outer_radius) * 0.5
	var spawn_pos := global_position + Vector2(cos(mid_angle), sin(mid_angle)) * mid_radius

	var orb := biomass_orb_scene.instantiate() as BiomassOrb
	if not orb:
		return

	orb.setup(biomass_reward, spawn_pos)
	var container: Node = get_parent()
	if not container or container is Planet:
		container = get_tree().current_scene
	container.add_child(orb)

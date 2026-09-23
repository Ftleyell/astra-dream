class_name ArcaneMonolith
extends "res://scenes/combat/environment/destructible_space_object.gd"


## ArcaneMonolith.gd
## Monolito Arcano-Tecnológico: reliquia antigua flotante con runas pulsantes cian/magenta.
## Salud: 150 HP. Al ser destruido libera el orbe de invocación de Arcana (ArcanaOrb) y esquirlas rúnicas.

@export var pulse_speed: float = 3.5
@export var float_amplitude: float = 8.0

var _time: float = 0.0
var arcana_orb_scene: PackedScene = preload("res://scenes/combat/pickups/arcana_orb.tscn")
var biomass_orb_scene: PackedScene = preload("res://scenes/combat/pickups/biomass_orb.tscn")

@onready var visual_base: Polygon2D = get_node_or_null("VisualBase")
@onready var visual_crystal: Polygon2D = get_node_or_null("FloatingCrystal")
@onready var runes_line: Line2D = get_node_or_null("RunesLine")
@onready var aura_polygon: Polygon2D = get_node_or_null("AuraPolygon")


func _ready() -> void:
	tier = 2
	obstacle_radius = 44.0
	shard_color = Color(0.1, 0.95, 1.0, 1.0)
	add_to_group("monoliths")

	# Deriva inercial lenta y mística
	if drift_velocity == Vector2.ZERO:
		drift_velocity = Vector2(randf_range(-18.0, 18.0), randf_range(-18.0, 18.0))
	angular_velocity = randf_range(-0.15, 0.15)

	if health_component:
		health_component.max_health = 150.0
		health_component.current_health = 150.0

	super._ready()


func _process(delta: float) -> void:
	if is_dying:
		return

	_time += delta * pulse_speed

	# Levitación vertical suave del cristal flotante
	if visual_crystal:
		visual_crystal.position.y = -36.0 + sin(_time) * float_amplitude

	# Pulso cromático de las inscripciones rúnicas (cian <-> magenta)
	var blend := (sin(_time * 1.2) + 1.0) * 0.5
	var rune_color := Color(0.0, 0.9, 1.0).lerp(Color(1.0, 0.1, 0.65), blend)
	if runes_line:
		runes_line.default_color = rune_color
	if aura_polygon:
		aura_polygon.color = Color(rune_color.r, rune_color.g, rune_color.b, 0.18 + sin(_time) * 0.08)


func _die() -> void:
	if is_dying:
		return

	# Instanciar el orbe de Arcana antes de la eliminación del nodo
	_spawn_arcana_orb()
	SaveManager.unlock_or_upgrade_trophy(&"trophy_monolith_master", 1)
	_spawn_biomass_bonus()

	# Invocación de la secuencia base de muerte (shattered signal, esquirlas cinemáticas y knockback)
	super._die()


func _spawn_arcana_orb() -> void:
	if not arcana_orb_scene or not is_inside_tree():
		return
	var orb = arcana_orb_scene.instantiate()
	if not orb:
		return
	orb.global_position = global_position
	var parent_target := get_parent() if get_parent() else get_tree().current_scene
	if parent_target:
		parent_target.add_child(orb)


func _spawn_biomass_bonus() -> void:
	if not biomass_orb_scene or not is_inside_tree():
		return
	var parent_target := get_parent() if get_parent() else get_tree().current_scene
	if not parent_target:
		return
	for i in range(2):
		var bio = biomass_orb_scene.instantiate()
		if bio:
			if bio.has_method("setup"):
				bio.setup(2, global_position + Vector2(randf_range(-15, 15), randf_range(-15, 15)))
			parent_target.add_child(bio)

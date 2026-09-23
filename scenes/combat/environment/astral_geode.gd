class_name AstralGeode
extends "res://scenes/combat/environment/destructible_space_object.gd"

## AstralGeode.gd
## Geoda de Cuarzo Astral: cúmulo de cristal facetado con propiedades prismáticas refractivas.
## Salud: 300 HP. Amplifica los proyectiles aliados que la atraviesan (+50% daño, +50% tamaño, crítico garantizado).
## Al romperse, desata una densa lluvia de esquirlas prismáticas de Tier 3 y abundante BioMasa/EXP.

@export var prism_radius: float = 85.0
@export var amplification_multiplier: float = 1.5

var biomass_orb_scene: PackedScene = preload("res://scenes/combat/pickups/biomass_orb.tscn")
var exp_blob_scene: PackedScene = preload("res://scenes/combat/pickups/exp_blob.tscn")
var _shimmer_time: float = 0.0

@onready var prism_field: Area2D = get_node_or_null("PrismField")
@onready var visual_facets: Node2D = get_node_or_null("VisualFacets")
@onready var aura_poly: Polygon2D = get_node_or_null("AuraPolygon")


func _ready() -> void:
	tier = 3
	obstacle_radius = 50.0
	shard_color = Color(0.9, 0.7, 1.0, 1.0) # Cuarzo prismático iridiscente
	add_to_group("astral_geodes")

	# Deriva inercial lenta
	if drift_velocity == Vector2.ZERO:
		drift_velocity = Vector2(randf_range(-14.0, 14.0), randf_range(-14.0, 14.0))
	angular_velocity = randf_range(-0.25, 0.25)

	if health_component:
		health_component.max_health = 300.0
		health_component.current_health = 300.0

	if prism_field:
		prism_field.area_entered.connect(_on_prism_area_entered)

	super._ready()


func _process(delta: float) -> void:
	if is_dying:
		return

	_shimmer_time += delta * 2.8

	# Shimmer iridiscente del aura y las facetas
	if aura_poly:
		var pulse := (sin(_shimmer_time) + 1.0) * 0.5
		aura_poly.scale = Vector2.ONE * (1.0 + pulse * 0.08)
		aura_poly.color = Color(0.4, 0.8, 1.0, 0.12).lerp(Color(0.85, 0.4, 1.0, 0.22), pulse)

	# Chequeo dinámico por distancia de proyectiles aliados (Node2D como KineticProjectile)
	_scan_passing_projectiles()


func _scan_passing_projectiles() -> void:
	var tree := get_tree()
	if not tree:
		return

	var projectiles := tree.get_nodes_in_group("player_projectiles")
	for proj in projectiles:
		if is_instance_valid(proj) and proj is Node2D:
			_try_amplify_projectile(proj as Node2D)


func _on_prism_area_entered(area: Area2D) -> void:
	var parent_node := area.get_parent()
	if parent_node and parent_node is Node2D:
		_try_amplify_projectile(parent_node as Node2D)


func _try_amplify_projectile(proj: Node2D) -> void:
	if not is_instance_valid(proj) or proj.has_meta("geode_amplified"):
		return

	if global_position.distance_squared_to(proj.global_position) > prism_radius * prism_radius:
		return

	# Marcar para no amplificar múltiples veces el mismo proyectil
	proj.set_meta("geode_amplified", true)

	# Amplificación de daño y crítico
	if "hit_context" in proj and proj.hit_context:
		proj.hit_context.final_damage *= amplification_multiplier
		proj.hit_context.raw_damage *= amplification_multiplier
		proj.hit_context.is_crit = true

	# Amplificación de tamaño y escala visual
	proj.scale *= amplification_multiplier
	if "radius" in proj:
		proj.radius *= amplification_multiplier

	# Tinte prismático iridiscente
	proj.modulate = Color(1.3, 0.8, 1.5, 1.0)

	# SFX de resonancia prismática
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("satellite_plant", 1.4)


func _die() -> void:
	if is_dying:
		return

	_spawn_mineral_rewards()
	super._die()


func _spawn_mineral_rewards() -> void:
	if not is_inside_tree():
		return

	var parent_target := get_parent() if get_parent() else get_tree().current_scene
	if not parent_target:
		return

	# Generar 4 gemas de BioMasa y 4 de EXP
	for i in range(4):
		if biomass_orb_scene:
			var bio := biomass_orb_scene.instantiate() as BiomassOrb
			if bio:
				var offset := Vector2(randf_range(-30, 30), randf_range(-30, 30))
				bio.setup(2, global_position + offset)
				parent_target.call_deferred("add_child", bio)

		if exp_blob_scene:
			var exp_b := exp_blob_scene.instantiate() as Node2D
			if exp_b and exp_b.has_method("setup"):
				var offset := Vector2(randf_range(-35, 35), randf_range(-35, 35))
				exp_b.setup(25.0, global_position + offset)
				parent_target.call_deferred("add_child", exp_b)

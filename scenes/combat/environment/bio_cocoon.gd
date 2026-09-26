class_name BioCocoon
extends "res://scenes/combat/environment/destructible_space_object.gd"

## BioCocoon.gd
## Capullo Biomecánico: colmena orgánica pulsante con ritmo senoidal de advertencia.
## Salud: 180 HP. Engendra esbirros cada 5s mientras sobreviva (máx 3 activos).
## Al destruirse, detona en cadena biológica eliminando a todos los hijos que engendró y soltando BioMasa.

@export var spawn_interval: float = 5.0
@export var max_spawned_minions: int = 3
@export var pulse_rate: float = 3.6

var spawn_timer: float = 2.5
var spawned_minions: Array[Node2D] = []
var minion_scene: PackedScene = preload("res://scenes/combat/enemies/enemy_kamikaze.tscn")
var biomass_orb_scene: PackedScene = preload("res://scenes/combat/pickups/biomass_orb.tscn")
var _anim_time: float = 0.0

@onready var visual_body: Polygon2D = get_node_or_null("VisualBody")
@onready var visual_tendrils: Line2D = get_node_or_null("VisualTendrils")
@onready var core_egg: Polygon2D = get_node_or_null("CoreEgg")


func _ready() -> void:
	tier = 2
	obstacle_radius = 42.0
	shard_color = Color(0.85, 0.15, 0.45, 1.0) # Quitina orgánica violácea/carmesí
	add_to_group("bio_cocoons")
	add_to_group("bio_cocoon")

	# Deriva inercial muy sutil tipo materia viva flotante
	if drift_velocity == Vector2.ZERO:
		drift_velocity = Vector2(randf_range(-12.0, 12.0), randf_range(-12.0, 12.0))
	angular_velocity = randf_range(-0.2, 0.2)

	if health_component:
		health_component.max_health = 180.0
		health_component.current_health = 180.0

	super._ready()


func _process(delta: float) -> void:
	if is_dying:
		return

	_anim_time += delta * pulse_rate

	# Latido senoidal orgánico (Breathing pulse)
	var breath := sin(_anim_time)
	var current_scale := 1.0 + breath * 0.07
	if visual_body:
		visual_body.scale = Vector2(current_scale, current_scale)
		# Tinte fluctuante de advertencia
		var blend := (breath + 1.0) * 0.5
		visual_body.color = Color(0.38, 0.12, 0.42).lerp(Color(0.72, 0.12, 0.25), blend)

	if core_egg:
		var egg_pulse := 1.0 + sin(_anim_time * 1.5) * 0.12
		core_egg.scale = Vector2(egg_pulse, egg_pulse)

	# Lógica periódica de engendrado
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		spawn_timer = spawn_interval
		_try_spawn_minion()


func _try_spawn_minion() -> void:
	if not minion_scene or not is_inside_tree():
		return

	# Limpiar referencias muertas
	for i in range(spawned_minions.size() - 1, -1, -1):
		if not is_instance_valid(spawned_minions[i]):
			spawned_minions.remove_at(i)

	if spawned_minions.size() >= max_spawned_minions:
		return

	var parent_target := get_parent() if get_parent() else get_tree().current_scene
	if not parent_target:
		return

	var minion := minion_scene.instantiate() as CharacterBody2D
	if not minion:
		return

	var angle := randf() * TAU
	var spawn_pos := global_position + Vector2(cos(angle), sin(angle)) * 50.0
	minion.global_position = spawn_pos

	parent_target.call_deferred("add_child", minion)
	spawned_minions.append(minion)


func _die() -> void:
	if is_dying:
		return

	# 1. Cadena Biológica: detonación inmediata de los esbirros engendrados
	_trigger_chain_reaction()

	# 2. Recompensas de BioMasa orgánica
	_spawn_biomass_cluster()

	# 3. Muerte base (shattered, esquirlas cinemáticas y knockback a enemigos)
	super._die()


func _trigger_chain_reaction() -> void:
	for minion in spawned_minions:
		if is_instance_valid(minion) and not (minion.has_method("is_dead") and minion.is_dead()):
			# Provocar muerte o daño crítico inmediato
			if minion.has_method("take_damage"):
				var ctx := HitContext.new()
				ctx.raw_damage = 999.0
				ctx.final_damage = 999.0
				ctx.is_crit = true
				ctx.hit_position = minion.global_position
				minion.take_damage(ctx)
			elif minion.has_method("_die"):
				minion._die()

	spawned_minions.clear()


func _spawn_biomass_cluster() -> void:
	if not biomass_orb_scene or not is_inside_tree():
		return

	var parent_target := get_parent() if get_parent() else get_tree().current_scene
	if not parent_target:
		return

	for i in range(3):
		var bio := biomass_orb_scene.instantiate() as BiomassOrb
		if bio:
			var offset := Vector2(randf_range(-25, 25), randf_range(-25, 25))
			bio.setup(2, global_position + offset)
			parent_target.call_deferred("add_child", bio)

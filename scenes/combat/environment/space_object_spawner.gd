class_name SpaceObjectSpawner
extends Node2D

## SpaceObjectSpawner.gd
## Generador dinámico periódico de macro-objetos espaciales (Monolitos, Cápsulas, Geodas, Capullos).
## Controla la densidad táctica en la arena de combate y proyecta apariciones en la periferia de navegación.

@export var monolith_scene: PackedScene = preload("res://scenes/combat/environment/arcane_monolith.tscn")
@export var supply_pod_scene: PackedScene = preload("res://scenes/combat/environment/supply_pod.tscn")
@export var astral_geode_scene: PackedScene = preload("res://scenes/combat/environment/astral_geode.tscn")
@export var bio_cocoon_scene: PackedScene = preload("res://scenes/combat/environment/bio_cocoon.tscn")

@export var spawn_interval: float = 28.0
@export var initial_delay: float = 6.0
@export var max_active_macro_objects: int = 4
@export var spawn_distance_min: float = 1000.0
@export var spawn_distance_max: float = 1350.0

var player: CharacterBody2D = null
var spawn_timer: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	spawn_timer = initial_delay


func _process(delta: float) -> void:
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		spawn_timer = randf_range(spawn_interval * 0.85, spawn_interval * 1.15)
		_try_spawn_macro_object()


func _try_spawn_macro_object() -> void:
	if not is_inside_tree():
		return

	var tree := get_tree()
	if not tree:
		return

	# Comprobar población total de macro-objetos especiales
	var total_active: int = (
		tree.get_nodes_in_group("monoliths").size() +
		tree.get_nodes_in_group("supply_pods").size() +
		tree.get_nodes_in_group("astral_geodes").size() +
		tree.get_nodes_in_group("bio_cocoons").size()
	)

	if total_active >= max_active_macro_objects:
		return

	_acquire_player()
	var center := player.global_position if is_instance_valid(player) else global_position

	_spawn_single_object(center)


func _spawn_single_object(center: Vector2) -> void:
	# Selección ponderada del tipo de macro-objeto
	var roll := randf()
	var scene_to_spawn: PackedScene = null

	if roll < 0.30:
		scene_to_spawn = supply_pod_scene # 30%
	elif roll < 0.55:
		scene_to_spawn = astral_geode_scene # 25%
	elif roll < 0.80:
		scene_to_spawn = bio_cocoon_scene # 25%
	else:
		scene_to_spawn = monolith_scene # 20% (Reliquia Arcano-Tecnológica)

	if not scene_to_spawn:
		return

	# Cálculo de posición periférica orientada según velocidad del jugador
	var base_angle := randf() * TAU
	if is_instance_valid(player) and player.velocity.length_squared() > 100.0:
		var heading := player.velocity.angle()
		if randf() < 0.65:
			base_angle = heading + randf_range(-PI * 0.4, PI * 0.4)

	var dist := randf_range(spawn_distance_min, spawn_distance_max)
	var spawn_pos := center + Vector2(cos(base_angle), sin(base_angle)) * dist

	var obj := scene_to_spawn.instantiate() as DestructibleSpaceObject
	if not obj:
		return

	obj.global_position = spawn_pos

	var container: Node = get_parent()
	if not container:
		container = get_tree().current_scene
	container.add_child(obj)


func _acquire_player() -> void:
	if not is_instance_valid(player) and is_inside_tree():
		player = get_tree().get_first_node_in_group("player") as CharacterBody2D

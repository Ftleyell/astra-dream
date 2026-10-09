class_name CombatSpaceDebrisManager
extends RefCounted

## CombatSpaceDebrisManager.gd
## Administrador modular de macroestructuras, asteroides y debris del espacio en combate.
## Desacopla la inyección de AsteroidSpawner, PlanetSpawner y SpaceObjectSpawner de MainGame.

const PlanetSpawnerHelperScript = preload("res://scenes/combat/environment/planet_spawner_helper.gd")

var space_object_spawner: SpaceObjectSpawner = null
var asteroid_spawner: AsteroidSpawner = null
var planet_spawner: PlanetSpawner = null


func setup(parent: Node2D) -> void:
	if not parent or not is_instance_valid(parent):
		return

	if not space_object_spawner:
		space_object_spawner = SpaceObjectSpawner.new()
		space_object_spawner.name = "SpaceObjectSpawner"
		parent.add_child(space_object_spawner)


func spawn_environment_actors(parent: Node2D) -> void:
	if not parent or not is_instance_valid(parent):
		return

	if not asteroid_spawner:
		asteroid_spawner = AsteroidSpawner.new()
		asteroid_spawner.name = "AsteroidSpawner"
		parent.add_child(asteroid_spawner)

	if not planet_spawner:
		planet_spawner = PlanetSpawner.new()
		planet_spawner.name = "PlanetSpawner"
		parent.add_child(planet_spawner)

	if not space_object_spawner:
		space_object_spawner = SpaceObjectSpawner.new()
		space_object_spawner.name = "SpaceObjectSpawner"
		parent.add_child(space_object_spawner)


func notify_wave_started(wave_idx: int) -> void:
	if space_object_spawner and space_object_spawner.has_method("notify_wave_started"):
		space_object_spawner.notify_wave_started(wave_idx)


func spawn_debug_planets(parent: Node2D, player: Node2D) -> void:
	PlanetSpawnerHelperScript.spawn_debug_planets(parent, player)

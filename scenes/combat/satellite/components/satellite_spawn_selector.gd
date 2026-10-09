class_name SatelliteSpawnSelector
extends RefCounted

## SatelliteSpawnSelector.gd
## Selector extensible de entidades y balizas orbitales.
## Determina el tipo de estación a generar y su posición de proyección hacia adelante.

const SPAWN_AHEAD_DISTANCE: float = 1100.0

var satellite_scene: PackedScene = preload("res://scenes/combat/satellite/satellite_beacon.tscn")
var transmutation_scene: PackedScene = preload("res://scenes/combat/satellite/transmutation_station.tscn")


func calculate_spawn_position(player_pos: Vector2, player_velocity: Vector2) -> Vector2:
	var move_dir: Vector2 = player_velocity.normalized() if player_velocity.length_squared() > 10.0 else Vector2.UP.rotated(randf_range(-PI, PI))
	if move_dir.length_squared() < 0.001:
		move_dir = Vector2.UP
	return player_pos + move_dir * SPAWN_AHEAD_DISTANCE


func should_spawn_transmutation(total_collected: int) -> bool:
	return total_collected > 0 and (total_collected % 2 == 1)


func instantiate_beacon(index: int, plant_duration: float) -> SatelliteBeacon:
	var beacon := satellite_scene.instantiate() as SatelliteBeacon
	beacon.satellite_index = index
	beacon.plant_duration = plant_duration
	return beacon


func instantiate_transmutation() -> TransmutationStation:
	return transmutation_scene.instantiate() as TransmutationStation

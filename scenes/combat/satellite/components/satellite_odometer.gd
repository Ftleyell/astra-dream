class_name SatelliteOdometer
extends RefCounted

## SatelliteOdometer.gd
## Rastreador de distancia y odómetro espacial para generación de balizas/estaciones.
## Emite required_distance_reached cuando el jugador recorre la distancia configurada.

signal required_distance_reached
signal distance_updated(current_dist: float, target_dist: float)

const BASE_SPAWN_DISTANCE: float = 1200.0
const DISTANCE_INCREMENT_PER_SAT: float = 400.0
const MAX_DELTA_TOLERANCE: float = 2500.0

var distance_traveled: float = 0.0
var last_player_pos: Vector2 = Vector2.ZERO
var has_last_player_pos: bool = false
var total_collected: int = 0


func reset_distance() -> void:
	distance_traveled = 0.0


func set_collected_count(count: int) -> void:
	total_collected = count


func get_required_distance() -> float:
	return BASE_SPAWN_DISTANCE + (float(total_collected) * DISTANCE_INCREMENT_PER_SAT)


func initialize_position(pos: Vector2) -> void:
	last_player_pos = pos
	has_last_player_pos = true


func update(player_pos: Vector2, is_frozen_near_station: bool) -> void:
	var req_dist: float = get_required_distance()

	if is_frozen_near_station:
		distance_traveled = 0.0
		last_player_pos = player_pos
		distance_updated.emit(req_dist, req_dist)
		return

	if not has_last_player_pos:
		last_player_pos = player_pos
		has_last_player_pos = true
	else:
		var delta_dist: float = player_pos.distance_to(last_player_pos)
		if delta_dist < MAX_DELTA_TOLERANCE:
			distance_traveled += delta_dist
		last_player_pos = player_pos

	distance_updated.emit(distance_traveled, req_dist)

	if distance_traveled >= req_dist:
		distance_traveled = 0.0
		required_distance_reached.emit()

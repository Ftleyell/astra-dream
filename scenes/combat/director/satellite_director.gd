class_name SatelliteDirector
extends Node

## Sub-director encargado de la generación, permanencia, plantado y despawn de
## balizas satelitales y máquinas tragaperras en Astra Dream.

signal satellite_spawn_requested(target_pos: Vector2, sat_index: int)
signal satellite_despawn_requested(beacon: Node2D)
signal slot_machine_spawn_requested(target_pos: Vector2)

@export var config: EncounterTimelineConfig = null

const BASE_SPAWN_DISTANCE: float = 600.0
const DISTANCE_INCREMENT_PER_SAT: float = 250.0
const SPAWN_AHEAD_DISTANCE: float = 1100.0
const SATELLITE_DESPAWN_DISTANCE: float = 2400.0

var current_satellite_idx: int = 1
var wave_satellites_spawned: int = 0
var current_satellite: Node2D = null
var slot_machine_spawned_for_wave: int = 0

func initialize(timeline_cfg: EncounterTimelineConfig) -> void:
	config = timeline_cfg
	current_satellite_idx = 1
	wave_satellites_spawned = 0
	current_satellite = null
	slot_machine_spawned_for_wave = 0

func reset_for_new_wave() -> void:
	wave_satellites_spawned = 0

func calculate_satellite_spawn_position(player_pos: Vector2, player_velocity: Vector2) -> Vector2:
	var dir := Vector2.RIGHT.rotated(randf() * TAU)
	if player_velocity.length_squared() > 100.0:
		dir = player_velocity.normalized()
		var lateral_offset := randf_range(-0.5, 0.5)
		dir = dir.rotated(lateral_offset).normalized()

	var dist := BASE_SPAWN_DISTANCE + (float(current_satellite_idx) * DISTANCE_INCREMENT_PER_SAT)
	dist = clampf(dist, 600.0, SPAWN_AHEAD_DISTANCE)
	return player_pos + (dir * dist)

func can_spawn_satellite_for_wave() -> bool:
	var max_sats: int = config.max_satellites_per_wave if config else 1
	return wave_satellites_spawned < max_sats and not is_instance_valid(current_satellite)

func check_satellite_despawn(player_pos: Vector2) -> void:
	if not is_instance_valid(current_satellite):
		current_satellite = null
		return

	if "is_planted" in current_satellite and current_satellite.get("is_planted"):
		return

	var dist := player_pos.distance_to(current_satellite.global_position)
	if dist > SATELLITE_DESPAWN_DISTANCE:
		satellite_despawn_requested.emit(current_satellite)
		current_satellite = null

func evaluate_slot_machine_spawn(wave_num: int, player_pos: Vector2) -> void:
	if slot_machine_spawned_for_wave == wave_num:
		return
	slot_machine_spawned_for_wave = wave_num

	var chance: float = config.slot_machine_chance_per_wave if config else 0.35
	if randf() < chance:
		var offset := Vector2(randf_range(-800.0, 800.0), randf_range(-800.0, 800.0))
		if offset.length() < 400.0:
			offset = offset.normalized() * 500.0
		slot_machine_spawn_requested.emit(player_pos + offset)

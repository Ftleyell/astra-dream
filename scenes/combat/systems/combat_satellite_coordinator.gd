class_name CombatSatelliteCoordinator
extends Node

const MAX_SATELLITES_PER_WAVE: int = 1
const BASE_SPAWN_DISTANCE: float = 600.0
const DISTANCE_INCREMENT_PER_SAT: float = 250.0
const SPAWN_AHEAD_DISTANCE: float = 1100.0
const SATELLITE_DESPAWN_DISTANCE: float = 10000.0

var satellite_scene: PackedScene = preload("res://scenes/combat/satellite/satellite_beacon.tscn")
var transmutation_scene: PackedScene = preload("res://scenes/combat/satellite/transmutation_station.tscn")
var current_satellite: Node2D = null
var current_satellite_idx: int = 1
var wave_satellites_spawned: int = 0
var satellites_collected_total: int = 0
var last_anchor_pos: Vector2 = Vector2.ZERO

var main_game: MainGame = null

func setup(p_main_game: MainGame) -> void:
	main_game = p_main_game
	if main_game and is_instance_valid(main_game.player):
		last_anchor_pos = main_game.player.global_position

func update_satellite_lifecycle() -> void:
	if not main_game or not is_instance_valid(main_game.player):
		return
	
	var req_dist: float = BASE_SPAWN_DISTANCE + (float(satellites_collected_total) * DISTANCE_INCREMENT_PER_SAT)
	var current_dist: float = main_game.player.global_position.distance_to(last_anchor_pos)
	if is_instance_valid(main_game.hud):
		main_game.hud.update_satellite_travel_dist(current_dist, req_dist)

	check_satellite_despawn()

	if current_satellite == null and wave_satellites_spawned < MAX_SATELLITES_PER_WAVE:
		spawn_next_satellite_for_wave()

func check_satellite_despawn() -> void:
	if not main_game or not is_instance_valid(main_game.player):
		return
	if is_instance_valid(current_satellite):
		if main_game.player.global_position.distance_to(current_satellite.global_position) >= SATELLITE_DESPAWN_DISTANCE:
			despawn_current_satellite()

func despawn_current_satellite() -> void:
	if is_instance_valid(current_satellite):
		current_satellite.queue_free()
		current_satellite = null
	if main_game and is_instance_valid(main_game.hud):
		main_game.hud.clear_satellite()
	wave_satellites_spawned = maxi(0, wave_satellites_spawned - 1)

func spawn_next_satellite_for_wave() -> void:
	if not main_game or main_game.is_exiting_run or not main_game.is_inside_tree() or main_game.is_queued_for_deletion():
		return
	if current_satellite != null or wave_satellites_spawned >= MAX_SATELLITES_PER_WAVE:
		return
	if not is_instance_valid(main_game.player) or not main_game.player.is_inside_tree() or main_game.player.is_queued_for_deletion():
		return

	var req_dist: float = BASE_SPAWN_DISTANCE + (float(satellites_collected_total) * DISTANCE_INCREMENT_PER_SAT)
	var spawn_dist: float = maxf(SPAWN_AHEAD_DISTANCE, req_dist)
	var move_dir: Vector2 = main_game.player.velocity.normalized() if main_game.player.velocity.length_squared() > 10.0 else Vector2.UP.rotated(randf_range(-PI, PI))
	if move_dir.length_squared() < 0.001:
		move_dir = Vector2.UP

	var spawn_pos: Vector2 = main_game.player.global_position + move_dir * spawn_dist
	wave_satellites_spawned += 1
	spawn_next_satellite(spawn_pos)

func spawn_next_satellite(target_pos: Vector2) -> void:
	if not main_game or main_game.is_exiting_run or not main_game.is_inside_tree() or main_game.is_queued_for_deletion():
		return
	if current_satellite and is_instance_valid(current_satellite):
		current_satellite.queue_free()

	var is_transmutation: bool = (satellites_collected_total > 0 and satellites_collected_total % 2 == 1)
	if is_transmutation:
		var station := transmutation_scene.instantiate() as TransmutationStation
		station.global_position = target_pos
		current_satellite = station
		main_game.add_child.call_deferred(station)
		station.station_activated.connect(_on_transmutation_activated)
		station.station_depleted.connect(func(): _on_satellite_exited(current_satellite_idx))
	else:
		var beacon := satellite_scene.instantiate() as SatelliteBeacon
		beacon.global_position = target_pos
		beacon.satellite_index = current_satellite_idx
		current_satellite = beacon
		main_game.add_child.call_deferred(beacon)
		beacon.planted.connect(_on_satellite_planted)
		beacon.exited_perimeter.connect(_on_satellite_exited)

	if main_game.hud and is_instance_valid(main_game.hud):
		main_game.hud.set_active_satellite(target_pos, current_satellite_idx)

func _on_transmutation_activated(station: TransmutationStation) -> void:
	if not main_game or main_game.is_exiting_run or not main_game.is_inside_tree() or main_game.is_queued_for_deletion():
		return
	if main_game.has_method("open_transmutation_modal"):
		main_game.open_transmutation_modal(station)

func _on_satellite_planted(index: int, _pos: Vector2) -> void:
	if not main_game or main_game.is_exiting_run or not main_game.is_inside_tree() or main_game.is_queued_for_deletion():
		return
	if main_game.is_arcana_modal_active() or main_game.is_level_up_modal_active() or (main_game.level_up_modal and main_game.level_up_modal.has_pending_levels()) or main_game.is_dialogue_active():
		main_game._pending_satellite_credits = main_game.player.run_credits
		main_game._pending_satellite_index = index
	else:
		main_game.satellite_shop.open_shop(main_game.player.run_credits)

func _on_satellite_exited(_index: int) -> void:
	if not main_game or main_game.is_exiting_run or not main_game.is_inside_tree() or main_game.is_queued_for_deletion():
		return
	current_satellite_idx += 1
	satellites_collected_total += 1
	if is_instance_valid(main_game.player):
		last_anchor_pos = main_game.player.global_position

	if current_satellite and is_instance_valid(current_satellite):
		current_satellite.queue_free()
		current_satellite = null

	if main_game.hud and is_instance_valid(main_game.hud):
		main_game.hud.clear_satellite()
	main_game.save_current_run_state()
	if wave_satellites_spawned < MAX_SATELLITES_PER_WAVE and not main_game.is_exiting_run and main_game.is_inside_tree() and not main_game.is_queued_for_deletion():
		spawn_next_satellite_for_wave()

func reset_wave_satellite_count() -> void:
	wave_satellites_spawned = 0

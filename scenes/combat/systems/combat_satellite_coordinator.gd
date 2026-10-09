class_name CombatSatelliteCoordinator
extends "res://scenes/combat/systems/combat_subsystem.gd"

const BASE_SPAWN_DISTANCE: float = 1200.0
const DISTANCE_INCREMENT_PER_SAT: float = 400.0
const SPAWN_AHEAD_DISTANCE: float = 1100.0

var satellite_scene: PackedScene = preload("res://scenes/combat/satellite/satellite_beacon.tscn")
var transmutation_scene: PackedScene = preload("res://scenes/combat/satellite/transmutation_station.tscn")
var current_satellite: Node2D = null
var current_satellite_idx: int = 1
var satellites_collected_total: int = 0
var distance_traveled_since_last_spawn: float = 0.0
var last_player_pos: Vector2 = Vector2.ZERO
var has_last_player_pos: bool = false

# Compatibilidad con accesores previos
var wave_satellites_spawned: int:
	get: return 1 if is_instance_valid(current_satellite) else 0
	set(_val): pass

var last_anchor_pos: Vector2:
	get: return last_player_pos
	set(val): last_player_pos = val

var main_game: MainGame = null

func setup_subsystem(p_context: CombatContextScript) -> void:
	super.setup_subsystem(p_context)
	if context:
		if context.main_game:
			main_game = context.main_game as MainGame
		if is_instance_valid(context.player):
			last_player_pos = context.player.global_position
			has_last_player_pos = true
		if context.satellite_shop and not context.satellite_shop.shop_closed.is_connected(_on_shop_closed):
			context.satellite_shop.shop_closed.connect(_on_shop_closed)

func setup(p_main_game: MainGame) -> void:
	main_game = p_main_game
	if main_game:
		if is_instance_valid(main_game.player):
			last_player_pos = main_game.player.global_position
			has_last_player_pos = true
		if main_game.satellite_shop and not main_game.satellite_shop.shop_closed.is_connected(_on_shop_closed):
			main_game.satellite_shop.shop_closed.connect(_on_shop_closed)

func on_wave_started(_wave_idx: int) -> void:
	reset_wave_satellite_count()

func _process(_delta: float) -> void:
	if not is_inside_tree() or get_tree().paused:
		return
	update_satellite_lifecycle()

func get_required_distance_for_next_sat() -> float:
	return BASE_SPAWN_DISTANCE + (float(satellites_collected_total) * DISTANCE_INCREMENT_PER_SAT)

func update_satellite_lifecycle() -> void:
	if not main_game or not is_instance_valid(main_game.player):
		return

	# Si ya existe un satélite en el mundo, verificar si el jugador está interactuando o cargándolo
	var is_interacting: bool = false
	if is_instance_valid(current_satellite):
		var p_pos: Vector2 = main_game.player.global_position
		var sat_pos: Vector2 = current_satellite.global_position
		var dist_to_sat: float = p_pos.distance_to(sat_pos)

		var is_near: bool = dist_to_sat < 1200.0
		var has_charge: bool = ("current_charge" in current_satellite and current_satellite.current_charge > 0.0)
		var is_ready_sat: bool = ("is_ready" in current_satellite and current_satellite.is_ready)
		var is_busy: bool = ("is_processing" in current_satellite and current_satellite.is_processing)
		var is_in_perimeter: bool = ("player_inside" in current_satellite and current_satellite.player_inside)
		var is_chest_active: bool = ("active_reward_chest" in current_satellite and is_instance_valid(current_satellite.active_reward_chest))

		if is_near or has_charge or is_ready_sat or is_busy or is_in_perimeter or is_chest_active:
			is_interacting = true

	var req_dist: float = get_required_distance_for_next_sat()

	if is_interacting:
		# Mientras el jugador esté en la zona o cargando, congelar el odómetro en completado y jamás desespawnear
		distance_traveled_since_last_spawn = 0.0
		last_player_pos = main_game.player.global_position
		if is_instance_valid(main_game.hud):
			main_game.hud.update_satellite_travel_dist(req_dist, req_dist)
		return

	# Odómetro continuo de vuelo real
	if not has_last_player_pos:
		last_player_pos = main_game.player.global_position
		has_last_player_pos = true
	else:
		var delta_dist: float = main_game.player.global_position.distance_to(last_player_pos)
		if delta_dist < 2500.0: # Filtrar saltos por teletransporte o cambio de mapa
			distance_traveled_since_last_spawn += delta_dist
		last_player_pos = main_game.player.global_position

	if is_instance_valid(main_game.hud):
		main_game.hud.update_satellite_travel_dist(distance_traveled_since_last_spawn, req_dist)

	# Al alcanzar la meta de distancia, se proyecta un nuevo satélite (o se reubica si fue ignorado lejos)
	if distance_traveled_since_last_spawn >= req_dist:
		distance_traveled_since_last_spawn = 0.0
		spawn_next_satellite_ahead()


func check_satellite_despawn() -> void:
	# El satélite NO desespawnea por distancia mientras el jugador se aleja;
	# permanece activo en el espacio hasta que el odómetro genere el siguiente satélite o se consuma.
	pass

func despawn_current_satellite() -> void:
	if is_instance_valid(current_satellite):
		current_satellite.queue_free()
		current_satellite = null
	if main_game and is_instance_valid(main_game.hud):
		main_game.hud.clear_satellite()

func spawn_next_satellite_for_wave() -> void:
	spawn_next_satellite_ahead()

func spawn_next_satellite_ahead() -> void:
	if not main_game or main_game.is_exiting_run or not main_game.is_inside_tree() or main_game.is_queued_for_deletion():
		return
	if not is_instance_valid(main_game.player) or not main_game.player.is_inside_tree() or main_game.player.is_queued_for_deletion():
		return

	var spawn_dist: float = SPAWN_AHEAD_DISTANCE
	var move_dir: Vector2 = main_game.player.velocity.normalized() if main_game.player.velocity.length_squared() > 10.0 else Vector2.UP.rotated(randf_range(-PI, PI))
	if move_dir.length_squared() < 0.001:
		move_dir = Vector2.UP

	var spawn_pos: Vector2 = main_game.player.global_position + move_dir * spawn_dist
	spawn_next_satellite(spawn_pos)

func spawn_next_satellite(target_pos: Vector2) -> void:
	if not main_game or main_game.is_exiting_run or not main_game.is_inside_tree() or main_game.is_queued_for_deletion():
		return
	if current_satellite and is_instance_valid(current_satellite):
		if current_satellite is TransmutationStation:
			var station := current_satellite as TransmutationStation
			if not station.is_depleted and station.uses_remaining > 0:
				# La forja aún está operativa; no destruirla ni reemplazarla
				return
		current_satellite.queue_free()

	current_satellite_idx += 1

	var is_transmutation: bool = (satellites_collected_total > 0 and satellites_collected_total % 2 == 1)
	if is_transmutation:
		var station := transmutation_scene.instantiate() as TransmutationStation
		current_satellite = station
		main_game.add_child(station)
		station.global_position = target_pos
		station.station_activated.connect(_on_transmutation_activated)
		station.station_depleted.connect(func(): _on_satellite_exited(current_satellite_idx))
	else:
		var beacon := satellite_scene.instantiate() as SatelliteBeacon
		beacon.satellite_index = current_satellite_idx
		beacon.plant_duration = get_plant_duration()
		current_satellite = beacon
		main_game.add_child(beacon)
		beacon.global_position = target_pos
		beacon.planted.connect(_on_satellite_planted)
		beacon.exited_perimeter.connect(_on_satellite_exited)

	if main_game.hud and is_instance_valid(main_game.hud):
		main_game.hud.set_active_satellite(target_pos, current_satellite_idx)

func spawn_specific_satellite(target_pos: Vector2) -> void:
	if not main_game or main_game.is_exiting_run or not main_game.is_inside_tree() or main_game.is_queued_for_deletion():
		return
	if current_satellite and is_instance_valid(current_satellite):
		current_satellite.queue_free()

	current_satellite_idx += 1

	var beacon := satellite_scene.instantiate() as SatelliteBeacon
	beacon.satellite_index = current_satellite_idx
	beacon.plant_duration = get_plant_duration()
	current_satellite = beacon
	main_game.add_child(beacon)
	beacon.global_position = target_pos
	beacon.planted.connect(_on_satellite_planted)
	beacon.exited_perimeter.connect(_on_satellite_exited)

	if main_game.hud and is_instance_valid(main_game.hud):
		main_game.hud.set_active_satellite(target_pos, current_satellite_idx)

func spawn_specific_transmutation(target_pos: Vector2) -> void:
	if not main_game or main_game.is_exiting_run or not main_game.is_inside_tree() or main_game.is_queued_for_deletion():
		return
	if current_satellite and is_instance_valid(current_satellite):
		current_satellite.queue_free()

	current_satellite_idx += 1

	var station := transmutation_scene.instantiate() as TransmutationStation
	current_satellite = station
	main_game.add_child(station)
	station.global_position = target_pos
	station.station_activated.connect(_on_transmutation_activated)
	station.station_depleted.connect(func(): _on_satellite_exited(current_satellite_idx))

	if main_game.hud and is_instance_valid(main_game.hud):
		main_game.hud.set_active_satellite(target_pos, current_satellite_idx)

func get_plant_duration() -> float:
	if main_game and is_instance_valid(main_game.player) and main_game.player.inventory:
		if main_game.player.inventory.has_method("get_item_count") and main_game.player.inventory.get_item_count(&"orbital_relay") > 0:
			return 4.0
	return 6.0

func _on_transmutation_activated(station: TransmutationStation) -> void:
	if not main_game or main_game.is_exiting_run or not main_game.is_inside_tree() or main_game.is_queued_for_deletion():
		return
	satellites_collected_total += 1
	if main_game.has_method("open_transmutation_modal"):
		main_game.open_transmutation_modal(station)

func _on_satellite_planted(index: int, _pos: Vector2) -> void:
	if not main_game or main_game.is_exiting_run or not main_game.is_inside_tree() or main_game.is_queued_for_deletion():
		return
	satellites_collected_total += 1
	if main_game.is_arcana_modal_active() or main_game.is_level_up_modal_active() or (main_game.level_up_modal and main_game.level_up_modal.has_pending_levels()) or main_game.is_dialogue_active():
		main_game._pending_satellite_credits = main_game.player.run_credits
		main_game._pending_satellite_index = index
	else:
		main_game.satellite_shop.open_shop(main_game.player.run_credits, index)

func _on_shop_closed() -> void:
	# Al cerrar la tienda, NO se destruye el satélite ni se borra del mapa.
	# Permanece en el mundo para que el piloto pueda reabrirla con bumpeo.
	# La forja/satélite se reemplaza sólo cuando el odómetro alcanza la meta y spawnea uno nuevo.
	if main_game and is_instance_valid(main_game.player):
		main_game.save_current_run_state()

func _on_satellite_exited(_index: int) -> void:
	# El satélite no se destruye por salir de su perímetro.
	pass

func reset_wave_satellite_count() -> void:
	# Desacoplado de oleadas: no se resetea por wave
	pass

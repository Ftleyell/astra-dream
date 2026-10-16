class_name CombatSatelliteCoordinator
extends "res://scenes/combat/systems/combat_subsystem.gd"

## CombatSatelliteCoordinator.gd
## Coordinador orquestador de estaciones orbitales y balizas de telemetría.
## Delega el tracking de distancia a SatelliteOdometer y la instanciación a SatelliteSpawnSelector.

const SatelliteOdometerClass = preload("res://scenes/combat/satellite/components/satellite_odometer.gd")
const SatelliteSpawnSelectorClass = preload("res://scenes/combat/satellite/components/satellite_spawn_selector.gd")
const OrbitalWorldFollower2DScript = preload("res://scenes/combat/environment/cosmos/core/orbital_world_follower_2d.gd")
const CosmosOrbitSlotScript = preload("res://scenes/combat/environment/cosmos/core/cosmos_orbit_slot.gd")
const CosmosOrbitalSlotTrackerScript = preload("res://scenes/combat/environment/cosmos/core/cosmos_orbital_slot_tracker.gd")

const BASE_SPAWN_DISTANCE: float = 1200.0
const DISTANCE_INCREMENT_PER_SAT: float = 400.0
const ABANDON_RELOCATE_DISTANCE: float = 12000.0
const MIN_ORBIT_SPAWN_DIST: float = 1200.0
const MAX_ORBIT_SPAWN_DIST: float = 3500.0
const TARGET_AHEAD_PROJECTION_DIST: float = 2000.0

var odometer: RefCounted = null
var spawn_selector: RefCounted = null

var current_satellite: Node2D = null
var current_satellite_idx: int = 1
var _pending_satellite_spawn: bool = false
var satellites_collected_total: int = 0:
	set(val):
		satellites_collected_total = val
		if odometer:
			odometer.set_collected_count(val)

# Accesores de retrocompatibilidad
var satellite_scene: PackedScene:
	get: return spawn_selector.satellite_scene if spawn_selector else null
	set(val):
		if spawn_selector: spawn_selector.satellite_scene = val

var transmutation_scene: PackedScene:
	get: return spawn_selector.transmutation_scene if spawn_selector else null
	set(val):
		if spawn_selector: spawn_selector.transmutation_scene = val

var distance_traveled_since_last_spawn: float:
	get: return odometer.distance_traveled if odometer else 0.0
	set(val):
		if odometer: odometer.distance_traveled = val

var last_player_pos: Vector2:
	get: return odometer.last_player_pos if odometer else Vector2.ZERO
	set(val):
		if odometer: odometer.last_player_pos = val

var has_last_player_pos: bool:
	get: return odometer.has_last_player_pos if odometer else false
	set(val):
		if odometer: odometer.has_last_player_pos = val

var wave_satellites_spawned: int:
	get: return 1 if is_instance_valid(current_satellite) else 0
	set(_val): pass

var last_anchor_pos: Vector2:
	get: return last_player_pos
	set(val): last_player_pos = val

var main_game: MainGame = null


func _init() -> void:
	odometer = SatelliteOdometerClass.new()
	spawn_selector = SatelliteSpawnSelectorClass.new()
	odometer.required_distance_reached.connect(spawn_next_satellite_ahead)
	odometer.distance_updated.connect(_on_odometer_distance_updated)


func setup_subsystem(p_context: CombatContextScript) -> void:
	super.setup_subsystem(p_context)
	if context:
		if context.main_game:
			main_game = context.main_game as MainGame
		if is_instance_valid(context.player):
			odometer.initialize_position(context.player.global_position)
		if context.satellite_shop and not context.satellite_shop.shop_closed.is_connected(_on_shop_closed):
			context.satellite_shop.shop_closed.connect(_on_shop_closed)
		call_deferred("_connect_cosmos_streamer")


func setup(p_main_game: MainGame) -> void:
	main_game = p_main_game
	if main_game:
		if is_instance_valid(main_game.player):
			odometer.initialize_position(main_game.player.global_position)
		if main_game.satellite_shop and not main_game.satellite_shop.shop_closed.is_connected(_on_shop_closed):
			main_game.satellite_shop.shop_closed.connect(_on_shop_closed)
		call_deferred("_connect_cosmos_streamer")


func _connect_cosmos_streamer() -> void:
	var host_ctrl: Node = _get_cosmos_controller()
	if host_ctrl != null and host_ctrl.has_signal("solar_system_streamed"):
		if not host_ctrl.solar_system_streamed.is_connected(_on_solar_system_streamed):
			host_ctrl.solar_system_streamed.connect(_on_solar_system_streamed)
		if _pending_satellite_spawn and host_ctrl.has_method("get_active_solar_systems"):
			var active_systems: Dictionary = host_ctrl.call("get_active_solar_systems")
			for cell: Vector2i in active_systems.keys():
				var sys: Node = active_systems[cell]
				var tracker: CosmosOrbitalSlotTrackerScript = host_ctrl.call("get_slot_tracker") if host_ctrl.has_method("get_slot_tracker") else null
				if tracker != null:
					var slots_dict: Dictionary = tracker.get_slots_for_system(sys, cell)
					var is_transmutation: bool = spawn_selector.should_spawn_transmutation(satellites_collected_total)
					var planet_slots: Array = slots_dict.get("planet_slots", [])
					if is_transmutation or not planet_slots.is_empty():
						_on_solar_system_streamed(sys, cell, slots_dict.get("star_slot"), planet_slots)
						break


func _on_solar_system_streamed(_system: Node, _cell: Vector2i, _star_slot: CosmosOrbitSlotScript, planet_slots: Array) -> void:
	if not _pending_satellite_spawn and is_instance_valid(current_satellite):
		return
	var is_transmutation: bool = spawn_selector.should_spawn_transmutation(satellites_collected_total)
	if not is_transmutation and planet_slots.is_empty():
		return

	if main_game and is_instance_valid(main_game.player):
		_try_resolve_pending_satellite_spawn(main_game.player.global_position)


func on_wave_started(_wave_idx: int) -> void:
	reset_wave_satellite_count()


func _process(_delta: float) -> void:
	if not is_inside_tree() or get_tree().paused:
		return
	update_satellite_lifecycle()


func get_required_distance_for_next_sat() -> float:
	return odometer.get_required_distance()


func _is_current_satellite_completed() -> bool:
	if not is_instance_valid(current_satellite):
		return true
	if current_satellite is SatelliteBeacon:
		return (current_satellite as SatelliteBeacon).is_planted
	if current_satellite is TransmutationStation:
		var station: TransmutationStation = current_satellite as TransmutationStation
		return station.is_depleted or station.uses_remaining <= 0
	return false


func _is_player_interacting_with_satellite() -> bool:
	if not is_instance_valid(current_satellite) or not main_game or not is_instance_valid(main_game.player):
		return false

	var p_pos: Vector2 = main_game.player.global_position
	var sat_pos: Vector2 = current_satellite.global_position
	var dist_to_sat: float = p_pos.distance_to(sat_pos)
	var is_in_perimeter: bool = ("player_inside" in current_satellite and current_satellite.player_inside)

	if _is_current_satellite_completed():
		return is_in_perimeter or dist_to_sat < 450.0

	var is_near: bool = dist_to_sat < 1200.0
	var is_charging: bool = current_satellite.has_method("is_station_charging") and current_satellite.is_station_charging()
	var is_busy: bool = current_satellite.has_method("is_station_busy") and current_satellite.is_station_busy()
	var is_ready_sat: bool = current_satellite.has_method("is_station_ready") and current_satellite.is_station_ready()

	# Fallbacks por duck typing defensivo si no implementa los nuevos métodos
	if not current_satellite.has_method("is_station_charging") and "current_charge" in current_satellite:
		is_charging = current_satellite.current_charge > 0.0
	if not current_satellite.has_method("is_station_busy") and "is_processing" in current_satellite:
		is_busy = current_satellite.is_processing or ("active_reward_chest" in current_satellite and is_instance_valid(current_satellite.active_reward_chest))

	return is_near or is_charging or is_ready_sat or is_busy or is_in_perimeter


func update_satellite_lifecycle() -> void:
	if not main_game or not is_instance_valid(main_game.player):
		return

	var p_pos: Vector2 = main_game.player.global_position
	var is_interacting: bool = _is_player_interacting_with_satellite()
	var should_freeze_odometer: bool = is_interacting or _pending_satellite_spawn

	if is_instance_valid(current_satellite):
		var sat_pos: Vector2 = current_satellite.global_position
		var dist_to_sat: float = p_pos.distance_to(sat_pos)
		var is_in_perimeter: bool = ("player_inside" in current_satellite and current_satellite.player_inside)
		var is_charging: bool = current_satellite.has_method("is_station_charging") and current_satellite.is_station_charging()
		var is_busy: bool = current_satellite.has_method("is_station_busy") and current_satellite.is_station_busy()
		if not current_satellite.has_method("is_station_charging") and "current_charge" in current_satellite:
			is_charging = current_satellite.current_charge > 0.0
		if not current_satellite.has_method("is_station_busy") and "is_processing" in current_satellite:
			is_busy = current_satellite.is_processing or ("active_reward_chest" in current_satellite and is_instance_valid(current_satellite.active_reward_chest))

		var follower: Node = current_satellite.get_node_or_null("OrbitalWorldFollower2D")
		if follower != null and "freeze_parallax_drag" in follower:
			follower.freeze_parallax_drag = (dist_to_sat < 450.0 or is_in_perimeter or is_charging or is_busy)

		if not _is_current_satellite_completed() and dist_to_sat < ABANDON_RELOCATE_DISTANCE:
			should_freeze_odometer = true

		if main_game.hud and is_instance_valid(main_game.hud) and main_game.hud.has_method("update_active_satellite_position"):
			var edge_mgr: HUDEdgeTrackerManager = main_game.hud.get("_edge_tracker_mgr") as HUDEdgeTrackerManager
			if edge_mgr and is_instance_valid(edge_mgr.satellite_tracker):
				if edge_mgr.satellite_tracker.has_satellite and edge_mgr.satellite_tracker.satellite_index == current_satellite_idx:
					main_game.hud.update_active_satellite_position(current_satellite.global_position)
			else:
				main_game.hud.update_active_satellite_position(current_satellite.global_position)

	if _pending_satellite_spawn and not is_instance_valid(current_satellite):
		_try_resolve_pending_satellite_spawn(p_pos)

	odometer.update(p_pos, should_freeze_odometer)


func _find_best_orbit_slot(player_pos: Vector2, is_transmutation: bool = false) -> Dictionary:
	var host_ctrl: Node = _get_cosmos_controller()
	if host_ctrl == null:
		return {}

	var cam: Camera2D = main_game.camera if "camera" in main_game else null
	var root_node: CosmosRootNode = host_ctrl.cosmos_root if "cosmos_root" in host_ctrl else null
	var t_global: float = root_node.get_global_time() if (root_node != null and is_instance_valid(root_node)) else 0.0

	# Si es Forja Cuántica, anclar al centro solar exacto (r = 0) más cercano
	if is_transmutation:
		if not host_ctrl.has_method("get_star_center_slots"):
			return {}
		var star_slots: Array = host_ctrl.call("get_star_center_slots", player_pos, 16000.0)
		if star_slots.is_empty():
			return {}

		var candidates: Array[Dictionary] = []
		for slot_obj in star_slots:
			var slot: CosmosOrbitSlotScript = slot_obj as CosmosOrbitSlotScript
			if slot == null:
				continue
			var proj_pos: Vector2 = CosmosOrbitalSlotTrackerScript.project_slot_to_world(slot, t_global, cam)
			var dist: float = player_pos.distance_to(proj_pos)
			candidates.append({
				"slot": slot,
				"pos": proj_pos,
				"score": dist
			})

		if candidates.is_empty():
			return {}

		candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return float(a["score"]) < float(b["score"])
		)

		return {
			"slot": candidates[0]["slot"],
			"pos": candidates[0]["pos"]
		}

	# Si es baliza satelital estándar (no transmutación)
	if not host_ctrl.has_method("get_planet_orbit_slots"):
		return {}

	var player_vel: Vector2 = Vector2.ZERO
	if main_game and is_instance_valid(main_game.player) and "velocity" in main_game.player:
		player_vel = main_game.player.velocity

	var player_dir: Vector2 = player_vel.normalized() if player_vel.length_squared() > 10.0 else Vector2.UP.rotated(randf_range(-PI, PI))
	if player_dir.length_squared() < 0.001:
		player_dir = Vector2.UP

	var target_ahead: Vector2 = player_pos + (player_dir * TARGET_AHEAD_PROJECTION_DIST)
	var slots: Array = host_ctrl.call("get_planet_orbit_slots", player_pos, MAX_ORBIT_SPAWN_DIST + 1500.0)
	if slots.is_empty():
		return {}

	var candidates: Array[Dictionary] = []
	for slot_obj in slots:
		var slot: CosmosOrbitSlotScript = slot_obj as CosmosOrbitSlotScript
		if slot == null:
			continue
		var proj_pos: Vector2 = CosmosOrbitalSlotTrackerScript.project_slot_to_world(slot, t_global, cam)
		var dist: float = player_pos.distance_to(proj_pos)
		if dist >= MIN_ORBIT_SPAWN_DIST and dist <= MAX_ORBIT_SPAWN_DIST:
			candidates.append({
				"slot": slot,
				"pos": proj_pos,
				"score": proj_pos.distance_squared_to(target_ahead)
			})

	if candidates.is_empty():
		return {}

	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["score"]) < float(b["score"])
	)

	return {
		"slot": candidates[0]["slot"],
		"pos": candidates[0]["pos"]
	}


func _try_resolve_pending_satellite_spawn(player_pos: Vector2) -> void:
	var is_transmutation: bool = spawn_selector.should_spawn_transmutation(satellites_collected_total)
	var best: Dictionary = _find_best_orbit_slot(player_pos, is_transmutation)
	if not best.is_empty():
		_pending_satellite_spawn = false
		spawn_next_satellite(best["pos"] as Vector2, best["slot"] as CosmosOrbitSlotScript)


func _on_odometer_distance_updated(current_dist: float, req_dist: float) -> void:
	if main_game and is_instance_valid(main_game.hud):
		main_game.hud.update_satellite_travel_dist(current_dist, req_dist)


func check_satellite_despawn() -> void:
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

	var player_pos: Vector2 = main_game.player.global_position
	var host_ctrl: Node = _get_cosmos_controller()
	var is_transmutation: bool = spawn_selector.should_spawn_transmutation(satellites_collected_total)

	if host_ctrl != null and (host_ctrl.has_method("get_planet_orbit_slots") or host_ctrl.has_method("get_star_center_slots")):
		var best: Dictionary = _find_best_orbit_slot(player_pos, is_transmutation)
		if not best.is_empty():
			_pending_satellite_spawn = false
			spawn_next_satellite(best["pos"] as Vector2, best["slot"] as CosmosOrbitSlotScript)
			return
		else:
			# Si Cosmos Engine está activo en MainGame pero no hay slots en rango razonable, retener (hold) el spawn
			_pending_satellite_spawn = true
			return

	# Fallback cuando no hay Cosmos Engine presente (tests aislados)
	var spawn_pos: Vector2 = spawn_selector.calculate_spawn_position(
		player_pos,
		main_game.player.velocity
	)
	spawn_next_satellite(spawn_pos, null)


func spawn_next_satellite(target_pos: Vector2, bound_slot: CosmosOrbitSlotScript = null) -> void:
	if not main_game or main_game.is_exiting_run or not main_game.is_inside_tree() or main_game.is_queued_for_deletion():
		return

	if current_satellite and is_instance_valid(current_satellite):
		if not _is_current_satellite_completed():
			if is_instance_valid(main_game.player) and main_game.player.global_position.distance_to(current_satellite.global_position) < ABANDON_RELOCATE_DISTANCE:
				return
		current_satellite.queue_free()

	current_satellite_idx += 1

	if spawn_selector.should_spawn_transmutation(satellites_collected_total):
		var station: TransmutationStation = spawn_selector.instantiate_transmutation()
		current_satellite = station
		station.z_index = 10
		station.z_as_relative = false
		main_game.add_child(station)
		station.global_position = target_pos
		station.station_activated.connect(_on_transmutation_activated)
		station.station_depleted.connect(func(): _on_satellite_exited(current_satellite_idx))
		_apply_orbital_binding(station, target_pos, bound_slot)
	else:
		var beacon: SatelliteBeacon = spawn_selector.instantiate_beacon(current_satellite_idx, get_plant_duration())
		current_satellite = beacon
		main_game.add_child(beacon)
		beacon.global_position = target_pos
		beacon.check_orbital_relay(main_game.player)
		beacon.planted.connect(_on_satellite_planted)
		beacon.exited_perimeter.connect(_on_satellite_exited)
		_apply_orbital_binding(beacon, target_pos, bound_slot)

	if main_game.hud and is_instance_valid(main_game.hud):
		main_game.hud.set_active_satellite(target_pos, current_satellite_idx)


func _get_cosmos_controller() -> CosmosHostController:
	if main_game and main_game.environment_host:
		return main_game.environment_host.get_cosmos_controller()
	return null


func _apply_orbital_binding(target_entity: Node2D, candidate_pos: Vector2, bound_slot: CosmosOrbitSlotScript = null) -> void:
	if not main_game or not is_instance_valid(target_entity):
		return

	var host_ctrl: CosmosHostController = _get_cosmos_controller()
	var slot_to_bind: CosmosOrbitSlotScript = bound_slot

	if slot_to_bind == null and host_ctrl != null:
		if target_entity is TransmutationStation:
			var star_slots: Array[CosmosOrbitSlot] = host_ctrl.get_star_center_slots(candidate_pos, 16000.0)
			if not star_slots.is_empty():
				slot_to_bind = star_slots[0]
		else:
			var slots: Array[CosmosOrbitSlot] = host_ctrl.get_planet_orbit_slots(candidate_pos, 7000.0)
			if not slots.is_empty():
				slot_to_bind = slots[0]

	if slot_to_bind != null and host_ctrl != null:
		var follower := OrbitalWorldFollower2DScript.new()
		follower.name = "OrbitalWorldFollower2D"
		target_entity.add_child(follower)
		var cam: Camera2D = main_game.camera if "camera" in main_game else null
		var root_node: CosmosRootNode = host_ctrl.cosmos_root
		follower.setup_orbital_binding(slot_to_bind, cam, root_node)



func _try_bind_orbital_follower(target_entity: Node2D, candidate_pos: Vector2) -> void:
	_apply_orbital_binding(target_entity, candidate_pos, null)


func spawn_specific_satellite(target_pos: Vector2) -> void:
	if not main_game or main_game.is_exiting_run or not main_game.is_inside_tree() or main_game.is_queued_for_deletion():
		return
	if current_satellite and is_instance_valid(current_satellite):
		current_satellite.queue_free()

	current_satellite_idx += 1

	var beacon: SatelliteBeacon = spawn_selector.instantiate_beacon(current_satellite_idx, get_plant_duration())
	current_satellite = beacon
	main_game.add_child(beacon)
	beacon.global_position = target_pos
	beacon.check_orbital_relay(main_game.player)
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

	var station: TransmutationStation = spawn_selector.instantiate_transmutation()
	current_satellite = station
	station.z_index = 10
	station.z_as_relative = false
	main_game.add_child(station)
	station.global_position = target_pos
	station.station_activated.connect(_on_transmutation_activated)
	station.station_depleted.connect(func(): _on_satellite_exited(current_satellite_idx))
	_apply_orbital_binding(station, target_pos, null)

	if main_game.hud and is_instance_valid(main_game.hud):
		main_game.hud.set_active_satellite(target_pos, current_satellite_idx)


func get_plant_duration() -> float:
	var target_player: Node = main_game.player if (main_game and is_instance_valid(main_game.player)) else null
	return SatelliteBeacon.compute_plant_duration(target_player)


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
	var credits: int = main_game.player.run_credits if is_instance_valid(main_game.player) else 0
	if main_game.modal_coordinator:
		main_game.modal_coordinator.queue_satellite_shop(credits, index)
	elif main_game.is_arcana_modal_active() or main_game.is_level_up_modal_active() or (main_game.level_up_modal and main_game.level_up_modal.has_pending_levels()) or main_game.is_dialogue_active():
		main_game._pending_satellite_credits = credits
		main_game._pending_satellite_index = index
	else:
		main_game.satellite_shop.open_shop(credits, index)



func on_item_purchased(item_or_weapon: Resource, cost: int) -> void:
	if not main_game or not is_instance_valid(main_game.player):
		return
	var player = main_game.player
	var hud = main_game.hud
	var debug_mgr = get_node_or_null("/root/DebugManager")
	if debug_mgr and debug_mgr.has_method("is_infinite_credits_active") and debug_mgr.is_infinite_credits_active():
		player.run_credits = 999999
	else:
		var is_free: bool = debug_mgr and debug_mgr.has_method("is_free_shopping_enabled") and debug_mgr.is_free_shopping_enabled()
		if not is_free:
			player.run_credits = maxi(0, player.run_credits - cost)

	if item_or_weapon is WeaponData:
		var w_ctrl := player.get_node_or_null("WeaponController") as WeaponController
		if w_ctrl:
			w_ctrl.add_weapon(item_or_weapon as WeaponData)
	elif item_or_weapon is ItemData and player.inventory:
		player.inventory.add_item(item_or_weapon as ItemData, 1, "TIENDA DE SATÉLITE")
	if is_instance_valid(hud):
		hud.update_credits(player.run_credits)
	if main_game.has_method("save_current_run_state"):
		main_game.save_current_run_state()


func _on_shop_closed() -> void:
	if main_game and is_instance_valid(main_game.player):
		main_game.save_current_run_state()


func _on_satellite_exited(_index: int) -> void:
	pass


func reset_wave_satellite_count() -> void:
	pass

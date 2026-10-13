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
					var planet_slots: Array = slots_dict.get("planet_slots", [])
					if not planet_slots.is_empty():
						_on_solar_system_streamed(sys, cell, null, planet_slots)
						break


func _on_solar_system_streamed(_system: Node, _cell: Vector2i, _star_slot: CosmosOrbitSlotScript, planet_slots: Array) -> void:
	if not _pending_satellite_spawn and is_instance_valid(current_satellite):
		return
	if planet_slots.is_empty():
		return

	var host_ctrl: Node = _get_cosmos_controller()
	var selected_slot: CosmosOrbitSlotScript = planet_slots[0] as CosmosOrbitSlotScript
	var cam: Camera2D = main_game.camera if (main_game and "camera" in main_game) else null
	var root_node: CosmosRootNode = host_ctrl.cosmos_root if (host_ctrl != null and "cosmos_root" in host_ctrl) else null
	var t_global: float = root_node.get_global_time() if (root_node != null and is_instance_valid(root_node)) else 0.0
	var spawn_pos: Vector2 = CosmosOrbitalSlotTrackerScript.project_slot_to_world(selected_slot, t_global, cam)

	_pending_satellite_spawn = false
	spawn_next_satellite(spawn_pos, selected_slot)


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


func _try_resolve_pending_satellite_spawn(player_pos: Vector2) -> void:
	var host_ctrl: Node = _get_cosmos_controller()
	if host_ctrl != null and host_ctrl.has_method("get_planet_orbit_slots"):
		var slots: Array = host_ctrl.call("get_planet_orbit_slots", player_pos, 24000.0)
		if not slots.is_empty():
			var selected_slot: CosmosOrbitSlotScript = slots[0] as CosmosOrbitSlotScript
			var cam: Camera2D = main_game.camera if "camera" in main_game else null
			var t_global: float = 0.0
			var root_node: CosmosRootNode = host_ctrl.cosmos_root if "cosmos_root" in host_ctrl else null
			if root_node != null and is_instance_valid(root_node):
				t_global = root_node.get_global_time()
			var spawn_pos: Vector2 = CosmosOrbitalSlotTrackerScript.project_slot_to_world(selected_slot, t_global, cam)
			_pending_satellite_spawn = false
			spawn_next_satellite(spawn_pos, selected_slot)


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
	var selected_slot: CosmosOrbitSlotScript = null
	var spawn_pos: Vector2 = Vector2.ZERO

	if host_ctrl != null and host_ctrl.has_method("get_planet_orbit_slots"):
		var slots: Array = host_ctrl.call("get_planet_orbit_slots", player_pos, 24000.0)
		if not slots.is_empty():
			selected_slot = slots[0] as CosmosOrbitSlotScript
			var cam: Camera2D = main_game.camera if "camera" in main_game else null
			var t_global: float = 0.0
			var root_node: CosmosRootNode = host_ctrl.cosmos_root if "cosmos_root" in host_ctrl else null
			if root_node != null and is_instance_valid(root_node):
				t_global = root_node.get_global_time()
			spawn_pos = CosmosOrbitalSlotTrackerScript.project_slot_to_world(selected_slot, t_global, cam)
			_pending_satellite_spawn = false
			spawn_next_satellite(spawn_pos, selected_slot)
			return
		else:
			# Si Cosmos Engine está activo en MainGame pero no hay planetas en rango, retener (hold) el spawn
			_pending_satellite_spawn = true
			return

	# Fallback cuando no hay Cosmos Engine presente (tests aislados)
	spawn_pos = spawn_selector.calculate_spawn_position(
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
		beacon.planted.connect(_on_satellite_planted)
		beacon.exited_perimeter.connect(_on_satellite_exited)
		_apply_orbital_binding(beacon, target_pos, bound_slot)

	if main_game.hud and is_instance_valid(main_game.hud):
		main_game.hud.set_active_satellite(target_pos, current_satellite_idx)


func _get_cosmos_controller() -> Node:
	if not main_game:
		return null
	var env_host: Node = main_game.get_node_or_null("SpaceEnvironmentHost")
	if not env_host and main_game.has_node("SpaceBackground"):
		env_host = main_game.get_node("SpaceBackground")

	if env_host != null and env_host.has_method("get_cosmos_controller"):
		return env_host.call("get_cosmos_controller")
	elif env_host != null and env_host.has_method("get_host_controller"):
		return env_host.call("get_host_controller")
	return null


func _apply_orbital_binding(target_entity: Node2D, candidate_pos: Vector2, bound_slot: CosmosOrbitSlotScript = null) -> void:
	if not main_game or not is_instance_valid(target_entity):
		return

	var host_ctrl: Node = _get_cosmos_controller()
	var slot_to_bind: CosmosOrbitSlotScript = bound_slot

	if slot_to_bind == null and host_ctrl != null and host_ctrl.has_method("get_planet_orbit_slots"):
		var slots: Array = host_ctrl.call("get_planet_orbit_slots", candidate_pos, 7000.0)
		if not slots.is_empty():
			slot_to_bind = slots[0] as CosmosOrbitSlotScript

	if slot_to_bind != null and host_ctrl != null:
		var follower := OrbitalWorldFollower2DScript.new()
		follower.name = "OrbitalWorldFollower2D"
		target_entity.add_child(follower)
		var cam: Camera2D = main_game.camera if "camera" in main_game else null
		var root_node: CosmosRootNode = host_ctrl.cosmos_root if "cosmos_root" in host_ctrl else null
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

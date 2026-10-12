class_name PlanetSpawner
extends Node2D

## PlanetSpawner.gd
## Generador dinámico de macro-planetas cada 4000 unidades de exploración del jugador.
## Proyecta la aparición en el vector de avance de la nave espacial.

const SpaceEnvironmentConfigScript = preload("res://core/resources/space_environment_config.gd")
const OrbitalWorldFollower2DScript = preload("res://scenes/combat/environment/cosmos/core/orbital_world_follower_2d.gd")
const CosmosOrbitSlotScript = preload("res://scenes/combat/environment/cosmos/core/cosmos_orbit_slot.gd")
const CosmosOrbitalSlotTrackerScript = preload("res://scenes/combat/environment/cosmos/core/cosmos_orbital_slot_tracker.gd")

@export var env_config: Resource = preload("res://data/environment/default_space_environment_config.tres")
@export var spawn_distance_interval: float = 7000.0
@export var spawn_projection_distance: float = 1800.0
@export var max_active_planets: int = 3
@export var initial_discovery_bonus: bool = true
@export var min_planet_distance: float = 2000.0

var planet_scene: PackedScene = preload("res://scenes/combat/environment/planet.tscn")
var player: CharacterBody2D = null
var accumulated_distance: float = 0.0
var last_player_pos: Vector2 = Vector2.ZERO
var active_planets: Array[Node2D] = []
var spawned_system_cells: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if is_instance_valid(env_config):
		spawn_distance_interval = env_config.planet_spawn_interval
		min_planet_distance = env_config.planet_min_distance
		max_active_planets = env_config.planet_max_active
		spawn_projection_distance = env_config.planet_projection_distance

	_acquire_player()
	if is_instance_valid(player):
		last_player_pos = player.global_position

	call_deferred("_connect_cosmos_streamer")

	# Si se activa initial_discovery_bonus, coloca el primer planeta para testeo rápido
	if initial_discovery_bonus:
		call_deferred("_spawn_initial_test_planet")


func _connect_cosmos_streamer() -> void:
	var host_ctrl: Node = _get_cosmos_controller()
	if host_ctrl != null and host_ctrl.has_signal("solar_system_streamed"):
		if not host_ctrl.solar_system_streamed.is_connected(_on_solar_system_streamed):
			host_ctrl.solar_system_streamed.connect(_on_solar_system_streamed)
		if host_ctrl.has_method("get_active_solar_systems"):
			var active_systems: Dictionary = host_ctrl.call("get_active_solar_systems")
			for cell: Vector2i in active_systems.keys():
				var sys: Node = active_systems[cell]
				var tracker: CosmosOrbitalSlotTracker = host_ctrl.call("get_slot_tracker") if host_ctrl.has_method("get_slot_tracker") else null
				if tracker != null:
					var slots_dict: Dictionary = tracker.get_slots_for_system(sys, cell)
					var star_slot: CosmosOrbitSlotScript = slots_dict.get("star_slot")
					_on_solar_system_streamed(sys, cell, star_slot, [])


func _on_solar_system_streamed(_system: Node, cell: Vector2i, star_slot: CosmosOrbitSlotScript, _planet_slots: Array) -> void:
	if spawned_system_cells.has(cell):
		return
	_prune_active_planets()
	if active_planets.size() >= max_active_planets:
		return
	if star_slot == null:
		return

	var host_ctrl: Node = _get_cosmos_controller()
	var cam: Camera2D = _get_camera()
	var root_node: CosmosRootNode = host_ctrl.cosmos_root if (host_ctrl != null and "cosmos_root" in host_ctrl) else null
	var t_global: float = root_node.get_global_time() if (root_node != null and is_instance_valid(root_node)) else 0.0
	var slot_world_pos: Vector2 = CosmosOrbitalSlotTrackerScript.project_slot_to_world(star_slot, t_global, cam)
	if _is_position_valid_for_planet(slot_world_pos):
		spawned_system_cells[cell] = true
		_instantiate_planet_at(slot_world_pos, star_slot)


func _spawn_initial_test_planet() -> void:
	_acquire_player()
	var center := player.global_position if is_instance_valid(player) else Vector2(960, 540)
	var host_ctrl: Node = _get_cosmos_controller()
	if host_ctrl != null and host_ctrl.has_method("get_star_orbit_slots"):
		var slots: Array = host_ctrl.call("get_star_orbit_slots", center, 24000.0)
		if not slots.is_empty():
			var slot: CosmosOrbitSlotScript = slots[0] as CosmosOrbitSlotScript
			var cam: Camera2D = _get_camera()
			var root_node: CosmosRootNode = host_ctrl.cosmos_root if "cosmos_root" in host_ctrl else null
			var t_global: float = root_node.get_global_time() if (root_node != null and is_instance_valid(root_node)) else 0.0
			var slot_world_pos: Vector2 = CosmosOrbitalSlotTrackerScript.project_slot_to_world(slot, t_global, cam)
			if _is_position_valid_for_planet(slot_world_pos):
				spawned_system_cells[slot.orbit_center_cell] = true
				_instantiate_planet_at(slot_world_pos, slot)
				return
		# Si hay Cosmos Engine presente pero aún no hay estrellas disponibles, esperar al streaming
		return

	var preferred_pos := center + Vector2(1700.0, -400.0)

	if _is_position_valid_for_planet(preferred_pos):
		_instantiate_planet_at(preferred_pos)
		return

	# Si la posición preferida entra en conflicto, buscar en abanico circular despejado
	for i in range(12):
		var angle := (TAU / 12.0) * float(i)
		var test_pos := center + Vector2(cos(angle), sin(angle)) * 1750.0
		if _is_position_valid_for_planet(test_pos):
			_instantiate_planet_at(test_pos)
			return


func _physics_process(_delta: float) -> void:
	_acquire_player()
	if not is_instance_valid(player):
		return

	# Medir distancia recorrida acumulada
	var step := player.global_position.distance_to(last_player_pos)
	if step > 0.01:
		accumulated_distance += step
		last_player_pos = player.global_position

	if accumulated_distance >= spawn_distance_interval:
		var spawned := _spawn_planet_ahead()
		if spawned:
			accumulated_distance -= spawn_distance_interval
		else:
			# Si todos los intentos colisionaron con planetas existentes o se alcanzó el límite,
			# aplazar el reintento hasta avanzar 500 px adicionales
			accumulated_distance = spawn_distance_interval - 500.0

	_cleanup_distant_planets()


func _spawn_planet_ahead() -> bool:
	if not planet_scene or not is_instance_valid(player):
		return false

	_prune_active_planets()

	if active_planets.size() >= max_active_planets:
		return false

	var host_ctrl: Node = _get_cosmos_controller()
	if host_ctrl != null and host_ctrl.has_method("get_star_orbit_slots"):
		var star_slots: Array = host_ctrl.call("get_star_orbit_slots", player.global_position, 24000.0)
		if not star_slots.is_empty():
			var cam: Camera2D = _get_camera()
			var root_node: CosmosRootNode = host_ctrl.cosmos_root if "cosmos_root" in host_ctrl else null
			var t_global: float = root_node.get_global_time() if (root_node != null and is_instance_valid(root_node)) else 0.0

			for slot_obj in star_slots:
				var slot: CosmosOrbitSlotScript = slot_obj as CosmosOrbitSlotScript
				if spawned_system_cells.has(slot.orbit_center_cell):
					continue
				var projected_pos: Vector2 = CosmosOrbitalSlotTrackerScript.project_slot_to_world(slot, t_global, cam)
				if _is_position_valid_for_planet(projected_pos):
					spawned_system_cells[slot.orbit_center_cell] = true
					_instantiate_planet_at(projected_pos, slot)
					return true
		# Cuando Cosmos Engine está activo, los planetas destruibles orbitan estrellas exclusivas
		return false

	# Calcular dirección base de avance del jugador (velocity o rotación)
	var move_dir := player.velocity.normalized()
	if move_dir.length_squared() < 0.01:
		move_dir = Vector2.RIGHT.rotated(player.rotation if player.rotation != 0.0 else randf() * TAU)

	var base_angle := move_dir.angle()

	# Abanico de desviaciones angulares: prioriza cono frontal y expande hacia los flancos y periferia
	var angle_offsets: Array[float] = [
		0.0,
		deg_to_rad(25.0),
		deg_to_rad(-25.0),
		deg_to_rad(50.0),
		deg_to_rad(-50.0),
		deg_to_rad(75.0),
		deg_to_rad(-75.0),
		deg_to_rad(105.0),
		deg_to_rad(-105.0),
		deg_to_rad(135.0),
		deg_to_rad(-135.0),
		PI
	]

	var dist_multipliers: Array[float] = [1.0, 1.25, 1.5]

	for dist_mult in dist_multipliers:
		var current_dist := spawn_projection_distance * dist_mult
		for offset in angle_offsets:
			var test_angle := base_angle + offset + randf_range(-0.05, 0.05)
			var candidate_dir := Vector2(cos(test_angle), sin(test_angle))
			var candidate_pos := player.global_position + (candidate_dir * current_dist)

			if _is_position_valid_for_planet(candidate_pos):
				_instantiate_planet_at(candidate_pos)
				return true

	# Ningún ángulo respetó el margen de 2000px con respecto a otros planetas
	return false


func _is_position_valid_for_planet(pos: Vector2, min_dist: float = -1.0) -> bool:
	var check_dist: float = min_planet_distance if min_dist <= 0.0 else min_dist
	var check_dist_sq: float = check_dist * check_dist

	# Comprobar contra todos los nodos del grupo "planets" en el árbol de escena
	var tree := get_tree()
	if tree:
		var group_planets := tree.get_nodes_in_group("planets")
		for node in group_planets:
			if is_instance_valid(node) and node is Node2D and not node.is_queued_for_deletion():
				if (node as Node2D).global_position.distance_squared_to(pos) < check_dist_sq:
					return false

		var group_satellites := tree.get_nodes_in_group("satellites")
		var min_sat_dist: float = env_config.station_min_distance_to_planet if is_instance_valid(env_config) else 2500.0
		var min_sat_sq: float = min_sat_dist * min_sat_dist
		for sat in group_satellites:
			if is_instance_valid(sat) and sat is Node2D and not sat.is_queued_for_deletion():
				if (sat as Node2D).global_position.distance_squared_to(pos) < min_sat_sq:
					return false

	# Comprobar también la lista de active_planets por si alguno aún no ha entrado al grupo
	for planet in active_planets:
		if is_instance_valid(planet) and not planet.is_queued_for_deletion():
			if planet.global_position.distance_squared_to(pos) < check_dist_sq:
				return false

	return true


func _instantiate_planet_at(pos: Vector2, bound_slot: CosmosOrbitSlotScript = null) -> Planet:
	if not planet_scene:
		return null

	var planet := planet_scene.instantiate() as Planet
	if not planet:
		return null

	planet.global_position = pos
	var container: Node = get_parent()
	if not container:
		container = get_tree().current_scene

	container.add_child(planet)
	active_planets.append(planet)
	_apply_star_orbit_binding(planet, pos, bound_slot)
	return planet


func _get_cosmos_controller() -> Node:
	var tree := get_tree()
	var mg: Node = tree.get_first_node_in_group("main_game") if tree else null
	if not mg:
		return null

	var env_host: Node = mg.get_node_or_null("SpaceEnvironmentHost")
	if not env_host and mg.has_node("SpaceBackground"):
		env_host = mg.get_node("SpaceBackground")

	if env_host != null and env_host.has_method("get_cosmos_controller"):
		return env_host.call("get_cosmos_controller")
	elif env_host != null and env_host.has_method("get_host_controller"):
		return env_host.call("get_host_controller")
	return null


func _get_camera() -> Camera2D:
	var tree := get_tree()
	var mg: Node = tree.get_first_node_in_group("main_game") if tree else null
	if mg and "camera" in mg:
		return mg.camera as Camera2D
	return get_viewport().get_camera_2d() if is_inside_tree() else null


func _apply_star_orbit_binding(planet_node: Planet, candidate_pos: Vector2, bound_slot: CosmosOrbitSlotScript = null) -> void:
	if not is_inside_tree() or not is_instance_valid(planet_node):
		return

	var host_ctrl: Node = _get_cosmos_controller()
	var slot_to_bind: CosmosOrbitSlotScript = bound_slot

	if slot_to_bind == null and host_ctrl != null and host_ctrl.has_method("get_star_orbit_slots"):
		var slots: Array = host_ctrl.call("get_star_orbit_slots", candidate_pos, 9000.0)
		if not slots.is_empty():
			slot_to_bind = slots[0] as CosmosOrbitSlotScript

	if slot_to_bind != null and host_ctrl != null:
		var follower := OrbitalWorldFollower2DScript.new()
		follower.name = "OrbitalWorldFollower2D"
		planet_node.add_child(follower)
		var cam: Camera2D = _get_camera()
		var root_node: CosmosRootNode = host_ctrl.cosmos_root if "cosmos_root" in host_ctrl else null
		follower.setup_orbital_binding(slot_to_bind, cam, root_node)


func _try_bind_star_orbit(planet_node: Planet, candidate_pos: Vector2) -> void:
	_apply_star_orbit_binding(planet_node, candidate_pos, null)


func _prune_active_planets() -> void:
	for i in range(active_planets.size() - 1, -1, -1):
		var planet := active_planets[i]
		if not is_instance_valid(planet) or planet.is_queued_for_deletion():
			active_planets.remove_at(i)


func _cleanup_distant_planets() -> void:
	if not is_instance_valid(player):
		return

	_prune_active_planets()

	const MAX_RETAIN_DIST_SQ: float = 9000.0 * 9000.0

	for planet in active_planets:
		if is_instance_valid(planet) and not planet.is_queued_for_deletion():
			if planet.global_position.distance_squared_to(player.global_position) > MAX_RETAIN_DIST_SQ:
				planet.queue_free()


func _acquire_player() -> void:
	if not is_instance_valid(player) and is_inside_tree():
		player = get_tree().get_first_node_in_group("player") as CharacterBody2D

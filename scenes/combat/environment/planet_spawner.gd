class_name PlanetSpawner
extends Node2D

## PlanetSpawner.gd
## Generador dinámico de macro-planetas cada 4000 unidades de exploración del jugador.
## Proyecta la aparición en el vector de avance de la nave espacial.

@export var spawn_distance_interval: float = 4000.0
@export var spawn_projection_distance: float = 1600.0
@export var max_active_planets: int = 5
@export var initial_discovery_bonus: bool = true
@export var min_planet_distance: float = 2000.0

var planet_scene: PackedScene = preload("res://scenes/combat/environment/planet.tscn")
var player: CharacterBody2D = null
var accumulated_distance: float = 0.0
var last_player_pos: Vector2 = Vector2.ZERO
var active_planets: Array[Node2D] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_acquire_player()
	if is_instance_valid(player):
		last_player_pos = player.global_position

	# Si se activa initial_discovery_bonus, coloca el primer planeta a 1800 px para testeo rápido
	if initial_discovery_bonus:
		call_deferred("_spawn_initial_test_planet")


func _spawn_initial_test_planet() -> void:
	_acquire_player()
	var center := player.global_position if is_instance_valid(player) else Vector2(960, 540)
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

	# Comprobar también la lista de active_planets por si alguno aún no ha entrado al grupo
	for planet in active_planets:
		if is_instance_valid(planet) and not planet.is_queued_for_deletion():
			if planet.global_position.distance_squared_to(pos) < check_dist_sq:
				return false

	return true


func _instantiate_planet_at(pos: Vector2) -> Planet:
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
	return planet


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

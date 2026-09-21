class_name PlanetSpawner
extends Node2D

## PlanetSpawner.gd
## Generador dinámico de macro-planetas cada 4000 unidades de exploración del jugador.
## Proyecta la aparición en el vector de avance de la nave espacial.

@export var spawn_distance_interval: float = 4000.0
@export var spawn_projection_distance: float = 1600.0
@export var max_active_planets: int = 5
@export var initial_discovery_bonus: bool = true

var planet_scene: PackedScene = preload("res://scenes/combat/environment/planet.tscn")
var player: Player = null
var accumulated_distance: float = 0.0
var last_player_pos: Vector2 = Vector2.ZERO
var active_planets: Array[Node2D] = []


func _ready() -> void:
	_acquire_player()
	if is_instance_valid(player):
		last_player_pos = player.global_position

	# Si se activa initial_discovery_bonus, coloca el primer planeta a 1800 px para testeo rápido
	if initial_discovery_bonus:
		call_deferred("_spawn_initial_test_planet")


func _spawn_initial_test_planet() -> void:
	_acquire_player()
	var center := player.global_position if is_instance_valid(player) else Vector2(960, 540)
	var spawn_pos := center + Vector2(1700.0, -400.0)
	_instantiate_planet_at(spawn_pos)


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
		accumulated_distance -= spawn_distance_interval
		_spawn_planet_ahead()

	_cleanup_distant_planets()


func _spawn_planet_ahead() -> void:
	if not planet_scene or not is_instance_valid(player):
		return

	if active_planets.size() >= max_active_planets:
		return

	# Calcular dirección de avance del jugador (velocity o rotación)
	var move_dir := player.velocity.normalized()
	if move_dir.length_squared() < 0.01:
		move_dir = Vector2.RIGHT.rotated(player.rotation if player.rotation != 0.0 else randf() * TAU)

	# Proyectar el punto de spawn adelante fuera de la pantalla
	var lateral_offset := Vector2(-move_dir.y, move_dir.x) * randf_range(-350.0, 350.0)
	var spawn_pos := player.global_position + (move_dir * spawn_projection_distance) + lateral_offset

	_instantiate_planet_at(spawn_pos)


func _instantiate_planet_at(pos: Vector2) -> void:
	if not planet_scene:
		return

	var planet := planet_scene.instantiate() as Planet
	if not planet:
		return

	planet.global_position = pos
	var container: Node = get_parent()
	if not container:
		container = get_tree().current_scene

	container.add_child(planet)
	active_planets.append(planet)


func _cleanup_distant_planets() -> void:
	if not is_instance_valid(player):
		return

	active_planets = active_planets.filter(func(p: Node2D) -> bool: return is_instance_valid(p))
	const MAX_RETAIN_DIST_SQ: float = 9000.0 * 9000.0

	for planet in active_planets:
		if is_instance_valid(planet):
			if planet.global_position.distance_squared_to(player.global_position) > MAX_RETAIN_DIST_SQ:
				planet.queue_free()


func _acquire_player() -> void:
	if not is_instance_valid(player) and is_inside_tree():
		player = get_tree().get_first_node_in_group("player") as Player

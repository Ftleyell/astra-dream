class_name AsteroidSpawner
extends Node2D

## AsteroidSpawner.gd
## Generador periódico autónomo de asteroides en el espacio.
##
## Spawnea periódicamente (~20s) asteroides en la periferia de la cámara/jugador
## con trayectorias de deriva inerciales que cruzan suavemente el sector de combate.

@export var asteroid_scene: PackedScene = preload("res://scenes/combat/environment/asteroid.tscn")
@export var spawn_interval: float = 20.0
@export var initial_spawn_delay: float = 6.0
@export var max_active_asteroids: int = 12
@export var spawn_distance_min: float = 1100.0
@export var spawn_distance_max: float = 1350.0

var player: Player = null
var spawn_timer: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	# Primer spawn a los 6 segundos de iniciar partida para testing dinámico
	spawn_timer = initial_spawn_delay


func _process(delta: float) -> void:
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		spawn_timer = spawn_interval
		_try_spawn_asteroid()


func _try_spawn_asteroid() -> void:
	if not asteroid_scene:
		return

	# Control de población máxima de objetos destructibles
	var active_objects := get_tree().get_nodes_in_group("destructibles")
	if active_objects.size() >= max_active_asteroids:
		return

	_acquire_player()
	var center := player.global_position if is_instance_valid(player) else global_position

	# Elegir un punto periférico fuera del viewport
	var angle := randf() * TAU
	var dist := randf_range(spawn_distance_min, spawn_distance_max)
	var spawn_pos := center + Vector2(cos(angle), sin(angle)) * dist

	# Vector de deriva orientado hacia la vecindad del jugador con dispersión
	var target_offset := Vector2(randf_range(-350.0, 350.0), randf_range(-350.0, 350.0))
	var target_point := center + target_offset
	var drift_dir := (target_point - spawn_pos).normalized()
	var drift_speed := randf_range(35.0, 80.0)

	var asteroid := asteroid_scene.instantiate() as Asteroid
	if not asteroid:
		return

	asteroid.global_position = spawn_pos
	asteroid.drift_velocity = drift_dir * drift_speed
	asteroid.angular_velocity = randf_range(-0.8, 0.8)
	asteroid.size_tier = Asteroid.SizeTier.LARGE

	# Agregar al contenedor de entidades de la escena principal
	var container: Node = get_parent()
	if not container:
		container = get_tree().current_scene
	container.add_child(asteroid)


func _acquire_player() -> void:
	if not is_instance_valid(player) and is_inside_tree():
		player = get_tree().get_first_node_in_group("player") as Player

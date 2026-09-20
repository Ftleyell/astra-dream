class_name EnemySpawner
extends Node2D

@export var drone_scene: PackedScene = preload("res://scenes/combat/enemies/enemy_drone.tscn")
@export var max_enemies: int = 50
@export var base_spawn_interval: float = 2.0
@export var min_spawn_interval: float = 0.5
@export var spawn_radius_min: float = 800.0
@export var spawn_radius_max: float = 1000.0

var player: Player = null
var spawn_timer: float = 0.0
var elapsed_time: float = 0.0

func _ready() -> void:
	# Spawner inicial inmediato: 3 drones de prueba para probar combate al arrancar
	call_deferred("_spawn_initial_batch")

func _spawn_initial_batch() -> void:
	_acquire_player()
	var center := player.global_position if is_instance_valid(player) else global_position
	for i in range(3):
		var angle := (TAU / 3.0) * i
		var pos := center + Vector2(cos(angle), sin(angle)) * 600.0
		_spawn_drone_at(pos)

func _process(delta: float) -> void:
	elapsed_time += delta
	spawn_timer -= delta

	# Escalamiento de dificultad: a los 5 minutos (300s) llega al intervalo mínimo
	var t: float = clampf(elapsed_time / 300.0, 0.0, 1.0)
	var current_interval: float = lerpf(base_spawn_interval, min_spawn_interval, t)

	if spawn_timer <= 0.0:
		spawn_timer = current_interval
		_try_spawn_drone()

func _acquire_player() -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Player

func _try_spawn_drone() -> void:
	var existing_enemies := get_tree().get_nodes_in_group("enemies")
	if existing_enemies.size() >= max_enemies:
		return

	_acquire_player()
	var center := player.global_position if is_instance_valid(player) else global_position

	var angle := randf() * TAU
	var dist := randf_range(spawn_radius_min, spawn_radius_max)
	var spawn_pos := center + Vector2(cos(angle), sin(angle)) * dist

	_spawn_drone_at(spawn_pos)

func _spawn_drone_at(pos: Vector2) -> void:
	if not drone_scene:
		return
	var drone := drone_scene.instantiate() as Node2D
	if not drone:
		return
	drone.global_position = pos
	get_parent().add_child(drone)

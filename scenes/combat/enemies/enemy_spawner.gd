class_name EnemySpawner
extends Node2D

## Spawner de alta densidad para hordas de enemigos en Astra Dream.
## Gestiona la aparición por clústeres/escuadrones (3-8 enemigos por pulso),
## escalamiento progresivo del tope activo (80 a 250+ simultáneos),
## composición ponderada según la oleada activa y eventos de enjambre masivo.

@export var drone_scene: PackedScene = preload("res://scenes/combat/enemies/enemy_drone.tscn")
@export var kamikaze_scene: PackedScene = preload("res://scenes/combat/enemies/enemy_kamikaze.tscn")
@export var tank_scene: PackedScene = preload("res://scenes/combat/enemies/enemy_tank.tscn")
@export var shooter_scene: PackedScene = preload("res://scenes/combat/enemies/enemy_shooter.tscn")
@export var rainbow_scene: PackedScene = preload("res://scenes/combat/enemies/rainbow_enemy.tscn")

@export var max_enemies: int = 80
@export var base_spawn_interval: float = 1.2
@export var min_spawn_interval: float = 0.3
@export var spawn_radius_min: float = 750.0
@export var spawn_radius_max: float = 950.0

var player: Player = null
var spawn_timer: float = 0.0
var elapsed_time: float = 0.0
var is_spawning_paused: bool = false
var current_wave: int = 1
var rainbow_spawn_timer: float = 45.0

# Evento periódico de oleada masiva repentina (Swarm Rush)
var swarm_event_timer: float = 40.0
const SWARM_EVENT_INTERVAL: float = 45.0

signal swarm_rush_triggered(drone_count: int)

func set_spawning_paused(p_paused: bool) -> void:
	is_spawning_paused = p_paused

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	# Spawner inicial inmediato: escuadrón de prueba
	call_deferred("_spawn_initial_batch")

func _spawn_initial_batch() -> void:
	_acquire_player()
	var center := player.global_position if is_instance_valid(player) else global_position
	for i in range(4):
		var angle := (TAU / 4.0) * i
		var pos := center + Vector2(cos(angle), sin(angle)) * 650.0
		_spawn_enemy_at(drone_scene, pos)

func _process(delta: float) -> void:
	if is_spawning_paused:
		return

	elapsed_time += delta
	spawn_timer -= delta
	swarm_event_timer -= delta

	# Escalamiento del intervalo por tiempo en la oleada actual (llega a min_interval en 120s)
	var t: float = clampf(elapsed_time / 120.0, 0.0, 1.0)
	var current_interval: float = lerpf(base_spawn_interval, min_spawn_interval, t)

	if spawn_timer <= 0.0:
		spawn_timer = current_interval
		_try_spawn_cluster()

	# Disparador de Enjambre Repentino
	if swarm_event_timer <= 0.0:
		swarm_event_timer = SWARM_EVENT_INTERVAL
		_trigger_swarm_rush()

	# Disparador de Nave Arcoíris (Loot Goblin)
	rainbow_spawn_timer -= delta
	if rainbow_spawn_timer <= 0.0:
		rainbow_spawn_timer = randf_range(50.0, 75.0)
		_try_spawn_rainbow_enemy()

func _try_spawn_rainbow_enemy() -> void:
	if is_spawning_paused or not rainbow_scene:
		return
	_acquire_player()
	var center := player.global_position if is_instance_valid(player) else global_position
	# Spawn visible en la periferia de pantalla (480-520px)
	var spawn_dist := randf_range(480.0, 520.0)
	var angle := randf() * TAU
	var spawn_pos := center + Vector2(cos(angle), sin(angle)) * spawn_dist
	var enemy: Node2D = _spawn_enemy_at(rainbow_scene, spawn_pos)
	if enemy and enemy.has_method("setup_transverse_flight"):
		enemy.setup_transverse_flight(center, angle)

func set_wave(wave_num: int) -> void:
	current_wave = wave_num
	elapsed_time = 0.0
	spawn_timer = 0.5
	swarm_event_timer = SWARM_EVENT_INTERVAL

	# Escalado de tope de enemigos: 80 en Wave 1, 120 en Wave 2, 160 en Wave 3, 200 en Wave 4, 250+ en Wave 5+
	match wave_num:
		1:
			max_enemies = 80
			base_spawn_interval = 1.2
			min_spawn_interval = 0.45
		2:
			max_enemies = 120
			base_spawn_interval = 1.0
			min_spawn_interval = 0.38
		3:
			max_enemies = 160
			base_spawn_interval = 0.85
			min_spawn_interval = 0.32
		4:
			max_enemies = 200
			base_spawn_interval = 0.75
			min_spawn_interval = 0.28
		_:
			max_enemies = mini(320, 250 + (wave_num - 5) * 25)
			base_spawn_interval = maxf(0.5, 0.7 - float(wave_num - 5) * 0.05)
			min_spawn_interval = 0.25

func _acquire_player() -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Player

func _try_spawn_cluster() -> void:
	var existing_enemies := get_tree().get_nodes_in_group("enemies")
	var active_count := existing_enemies.size()
	if active_count >= max_enemies:
		return

	var available_slots := max_enemies - active_count
	var min_cluster := 3 if current_wave <= 2 else 4
	var max_cluster := 6 if current_wave <= 2 else 8
	var cluster_size := mini(available_slots, randi_range(min_cluster, max_cluster))

	_acquire_player()
	var center := player.global_position if is_instance_valid(player) else global_position

	# Elegir un cuadrante de aproximación aleatorio
	var base_angle := randf() * TAU
	var base_dist := randf_range(spawn_radius_min, spawn_radius_max)
	var cluster_origin := center + Vector2(cos(base_angle), sin(base_angle)) * base_dist

	# Spawner de la manada con formación en abanico
	for i in range(cluster_size):
		var offset_angle := randf_range(-0.4, 0.4)
		var offset_dist := randf_range(-60.0, 60.0)
		var spawn_pos := cluster_origin + Vector2(cos(base_angle + offset_angle), sin(base_angle + offset_angle)) * offset_dist
		var scene_to_spawn := _select_enemy_scene()
		_spawn_enemy_at(scene_to_spawn, spawn_pos)

func _select_enemy_scene() -> PackedScene:
	var roll := randf()
	if current_wave <= 1:
		# Oleada 1: 80% Drones, 20% Kamikazes
		if roll < 0.80:
			return drone_scene
		return kamikaze_scene
	elif current_wave == 2:
		# Oleada 2: 65% Drones, 25% Kamikazes, 10% Artilleros
		if roll < 0.65:
			return drone_scene
		elif roll < 0.90:
			return kamikaze_scene
		return shooter_scene
	else:
		# Oleada 3+: 50% Drones, 25% Kamikazes, 15% Tanques (bloqueo físico), 10% Artilleros (apoyo telegrafiado)
		if roll < 0.50:
			return drone_scene
		elif roll < 0.75:
			return kamikaze_scene
		elif roll < 0.90:
			return tank_scene
		return shooter_scene

func _trigger_swarm_rush() -> void:
	var existing_enemies := get_tree().get_nodes_in_group("enemies")
	var active_count := existing_enemies.size()
	var available_slots := max_enemies - active_count
	if available_slots <= 4:
		return

	var rush_count := mini(available_slots, 16)
	_acquire_player()
	var center := player.global_position if is_instance_valid(player) else global_position

	for i in range(rush_count):
		var angle := (TAU / float(rush_count)) * float(i)
		var spawn_pos := center + Vector2(cos(angle), sin(angle)) * spawn_radius_min
		_spawn_enemy_at(drone_scene, spawn_pos)

	swarm_rush_triggered.emit(rush_count)

func _spawn_enemy_at(scene: PackedScene, pos: Vector2) -> Node2D:
	if not scene:
		return null
	var enemy := scene.instantiate() as Node2D
	if not enemy:
		return null
	enemy.global_position = pos
	var parent_node := get_parent() if is_inside_tree() else null
	if not parent_node and is_inside_tree():
		parent_node = get_tree().current_scene
	if parent_node:
		parent_node.add_child(enemy)
	return enemy

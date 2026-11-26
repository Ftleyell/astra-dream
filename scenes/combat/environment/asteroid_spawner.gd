class_name AsteroidSpawner
extends Node2D

## AsteroidSpawner.gd
## Generador periódico autónomo de asteroides en el espacio.
##
## Spawnea regularmente asteroides en la periferia de la cámara/jugador
## con trayectorias de deriva inerciales que cruzan suavemente el sector de combate.

@export var asteroid_scene: PackedScene = preload("res://scenes/combat/environment/asteroid.tscn")
@export var spawn_interval: float = 6.0
@export var initial_spawn_delay: float = 2.0
@export var max_active_asteroids: int = 14
@export var spawn_distance_min: float = 950.0
@export var spawn_distance_max: float = 1250.0

var player: Player = null
var spawn_timer: float = 0.0


func _get_main_game() -> Node:
	if not is_inside_tree():
		return null
	var p: Node = get_parent()
	if p != null and p.has_method("is_hub_mode_active"):
		return p
	var tree: SceneTree = get_tree()
	return tree.get_first_node_in_group("main_game") if tree != null else null


func _is_blocked_by_hub() -> bool:
	var mg: Node = _get_main_game()
	return mg != null and mg.has_method("is_hub_mode_active") and bool(mg.call("is_hub_mode_active"))


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	spawn_timer = initial_spawn_delay


func _process(delta: float) -> void:
	if _is_blocked_by_hub():
		return
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		spawn_timer = randf_range(spawn_interval * 0.8, spawn_interval * 1.2)
		_try_spawn_asteroid()


func _try_spawn_asteroid() -> void:
	if _is_blocked_by_hub() or not asteroid_scene or not is_inside_tree():
		return

	var tree := get_tree()
	if not tree:
		return

	# Control de población máxima exclusivamente de asteroides (independiente de planetas y nidos)
	var active_asteroids := tree.get_nodes_in_group("asteroids")
	if active_asteroids.size() >= max_active_asteroids:
		return

	_acquire_player()
	var center := player.global_position if is_instance_valid(player) else global_position

	# Spawnea 1 a 2 asteroides según la densidad actual
	var count_to_spawn := 1 if active_asteroids.size() > 6 else randi_range(1, 2)
	for _i in range(count_to_spawn):
		_spawn_single_asteroid(center)


func _spawn_single_asteroid(center: Vector2) -> void:
	var mg: Node = _get_main_game()
	var launch_dir: Vector2 = Vector2.ZERO
	var cone_half: float = deg_to_rad(65.0)
	if mg != null:
		if mg.has_method("get_hub_launch_departure_direction"):
			launch_dir = mg.call("get_hub_launch_departure_direction")
		if mg.has_method("get_hub_launch_forward_cone_half_angle_rad"):
			cone_half = float(mg.call("get_hub_launch_forward_cone_half_angle_rad"))

	var has_vel: bool = is_instance_valid(player) and player.velocity.length_squared() > 100.0
	var vel_angle: float = player.velocity.angle() if has_vel else 0.0
	var has_filter: bool = mg != null and mg.has_method("is_position_allowed_for_combat_spawn")

	var spawn_pos: Vector2 = center
	var found_valid: bool = false
	for _attempt: int in range(12):
		var base_angle: float = randf() * TAU
		if launch_dir.length_squared() > 0.001:
			base_angle = launch_dir.angle() + randf_range(-cone_half, cone_half)
		elif has_vel and randf() < 0.60:
			base_angle = vel_angle + randf_range(-PI * 0.45, PI * 0.45)
		var dist: float = randf_range(spawn_distance_min, spawn_distance_max)
		spawn_pos = center + Vector2(cos(base_angle), sin(base_angle)) * dist
		if not has_filter or bool(mg.call("is_position_allowed_for_combat_spawn", spawn_pos, center, 100.0, true)):
			found_valid = true
			break

	if not found_valid and mg != null and mg.has_method("push_position_outside_hub_exclusion"):
		var fb_dir: Vector2 = launch_dir if launch_dir.length_squared() > 0.001 else (player.velocity.normalized() if has_vel else Vector2.UP)
		spawn_pos = mg.call("push_position_outside_hub_exclusion", center + fb_dir.normalized() * spawn_distance_max, fb_dir, 100.0)

	# Vector de deriva cruzando el sector del jugador
	var target_offset := Vector2(randf_range(-400.0, 400.0), randf_range(-400.0, 400.0))
	var target_point := center + target_offset
	var drift_dir := (target_point - spawn_pos).normalized()
	var drift_speed := randf_range(40.0, 95.0)

	var asteroid := asteroid_scene.instantiate() as Asteroid
	if not asteroid:
		return

	asteroid.global_position = spawn_pos
	asteroid.drift_velocity = drift_dir * drift_speed
	asteroid.angular_velocity = randf_range(-0.8, 0.8)
	asteroid.size_tier = Asteroid.SizeTier.LARGE

	var container: Node = get_parent()
	if not container:
		container = get_tree().current_scene
	container.add_child(asteroid)


func _acquire_player() -> void:
	if not is_instance_valid(player) and is_inside_tree():
		player = get_tree().get_first_node_in_group("player") as Player

class_name WeaponAutoAimCoordinator
extends RefCounted

## WeaponAutoAimCoordinator.gd
## Coordinador modular de adquisición de blancos, auto-apuntado balístico y orientación.
## Maneja prioridades de objetivos, rango de atracción imán, selector manual/automático y rotaciones.


static func get_autoaim_range(player: CharacterBody2D) -> float:
	var base_range: float = 850.0
	var pickup_bonus: float = 0.0
	if player and "stats" in player and player.stats:
		var current_pickup: float = player.stats.get_stat(&"pickup_radius")
		var base_pickup: float = player.character_data.pickup_radius if (player.character_data and player.character_data.pickup_radius > 0.0) else 100.0
		pickup_bonus = maxf(0.0, current_pickup - base_pickup)
	return base_range + pickup_bonus * 1.5


static func find_closest_enemy_in_pickup_radius(origin: Vector2, search_rad: float, tree: SceneTree) -> Node2D:
	if not tree:
		return null
	var rad_sq := search_rad * search_rad
	var nearest: Node2D = null
	var min_dist_sq := rad_sq

	var candidates: Array[Node] = []
	candidates.append_array(tree.get_nodes_in_group("enemies"))
	candidates.append_array(tree.get_nodes_in_group("emitters"))

	for node in candidates:
		if node is Node2D and is_instance_valid(node) and not node.is_queued_for_deletion() and not node.get("is_dying"):
			var d_sq := origin.distance_squared_to((node as Node2D).global_position)
			if d_sq <= min_dist_sq:
				min_dist_sq = d_sq
				nearest = node as Node2D

	return nearest


static func get_passive_aim_info(
	is_manual_aim: bool,
	origin: Vector2,
	mouse_pos: Vector2,
	current_locked_target: Node2D,
	last_known_target_dir: Vector2,
	player: CharacterBody2D,
	current_rotation: float,
	search_rad: float,
	tree: SceneTree
) -> Dictionary:
	if is_manual_aim:
		var dir := (mouse_pos - origin).normalized()
		if dir.length_squared() < 0.001:
			dir = Vector2.UP
		return { "direction": dir, "target": null, "last_known_dir": last_known_target_dir }

	# Modo Automático: enemigo más cercano dentro del radio de pantalla
	var target := current_locked_target if is_instance_valid(current_locked_target) else find_closest_enemy_in_pickup_radius(origin, search_rad, tree)
	if target and is_instance_valid(target):
		var dir := (target.global_position - origin).normalized()
		if dir.length_squared() < 0.001:
			dir = Vector2.UP
		return { "direction": dir, "target": target, "last_known_dir": dir }

	# Fallback cuando no hay enemigos en pantalla
	if last_known_target_dir.length_squared() > 0.001:
		return { "direction": last_known_target_dir, "target": null, "last_known_dir": last_known_target_dir }

	var fallback_dir := Vector2.UP
	if player and "last_facing_direction" in player and player.last_facing_direction.length_squared() > 0.001:
		fallback_dir = player.last_facing_direction.normalized()
	elif current_rotation != 0.0:
		fallback_dir = Vector2.from_angle(current_rotation)

	return { "direction": fallback_dir, "target": null, "last_known_dir": last_known_target_dir }


static func calculate_aim_angle(
	is_manual_aim: bool,
	origin: Vector2,
	mouse_pos: Vector2,
	current_locked_target: Node2D,
	passive_aim_info: Dictionary,
	is_fire_active_pressed: bool
) -> float:
	var target_pos := Vector2.ZERO
	if is_manual_aim:
		target_pos = mouse_pos
	else:
		if current_locked_target and is_instance_valid(current_locked_target):
			target_pos = current_locked_target.global_position
		elif is_fire_active_pressed:
			target_pos = mouse_pos
		else:
			var dir: Vector2 = passive_aim_info.get("direction", Vector2.UP)
			target_pos = origin + dir * 100.0

	return (target_pos - origin).angle()


static func get_candidates_in_range(origin: Vector2, radius: float, tree: SceneTree) -> Array[Node2D]:
	var r_sq := radius * radius
	var candidates: Array[Node2D] = []
	if not tree:
		return candidates

	for node in tree.get_nodes_in_group("enemies") + tree.get_nodes_in_group("emitters"):
		if is_instance_valid(node) and node is Node2D and not node.get("is_dying") and not node.get("is_invulnerable") and not node.get_meta("_is_emerging", false):
			if origin.distance_squared_to((node as Node2D).global_position) <= r_sq:
				candidates.append(node as Node2D)
	candidates.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return origin.distance_squared_to(a.global_position) < origin.distance_squared_to(b.global_position)
	)
	return candidates

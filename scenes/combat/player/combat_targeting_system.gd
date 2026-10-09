class_name CombatTargetingSystem
extends RefCounted

## CombatTargetingSystem.gd
## Manejador desacoplado de adquisición de blancos, auto-apuntado 2D,
## toggle de modo manual/automático y campo de ralentización (stutter field).

const WeaponAutoAimCoordinator = preload("res://scenes/combat/weapons/weapon_auto_aim_coordinator.gd")

signal aim_mode_changed(is_manual: bool)

var is_manual_aim: bool = false
var current_locked_target: Node2D = null
var last_known_target_dir: Vector2 = Vector2.UP
var _stutter_slowed_enemies: Array[Node2D] = []

func toggle_aim_mode() -> bool:
	is_manual_aim = not is_manual_aim
	aim_mode_changed.emit(is_manual_aim)
	var audio_mgr: Node = Engine.get_main_loop().root.get_node_or_null("/root/AudioManager") if Engine.get_main_loop() else null
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("ui_click", 1.6 if is_manual_aim else 1.2, 0.0)
	return is_manual_aim

func get_autoaim_range(player: Player) -> float:
	return WeaponAutoAimCoordinator.get_autoaim_range(player)

func update_locked_target(origin: Vector2, player: Player, tree: SceneTree) -> void:
	if is_manual_aim:
		current_locked_target = null
	else:
		current_locked_target = WeaponAutoAimCoordinator.find_closest_enemy_in_pickup_radius(
			origin,
			get_autoaim_range(player),
			tree
		)

func get_passive_aim_info(origin: Vector2, mouse_pos: Vector2, player: Player, rotation: float, tree: SceneTree) -> Dictionary:
	var info: Dictionary = WeaponAutoAimCoordinator.get_passive_aim_info(
		is_manual_aim,
		origin,
		mouse_pos,
		current_locked_target,
		last_known_target_dir,
		player,
		rotation,
		get_autoaim_range(player),
		tree
	)
	last_known_target_dir = info.get("last_known_dir", last_known_target_dir)
	return info

func calculate_aim_angle(origin: Vector2, mouse_pos: Vector2, player: Player, rotation: float, is_fire_pressed: bool, tree: SceneTree) -> float:
	var p_aim_info := get_passive_aim_info(origin, mouse_pos, player, rotation, tree)
	return WeaponAutoAimCoordinator.calculate_aim_angle(
		is_manual_aim,
		origin,
		mouse_pos,
		current_locked_target,
		p_aim_info,
		is_fire_pressed
	)

func handle_stutter_field(equipped_weapons: Array[WeaponInstanceData], center: Vector2, tree: SceneTree) -> void:
	var is_active: bool = false
	for inst: WeaponInstanceData in equipped_weapons:
		if inst.weapon_data:
			var wid: StringName = inst.weapon_data.weapon_id
			if (wid == &"singularity_pulsar" or wid == &"void_siphon") and inst.active_cooldown > 0.0:
				is_active = true
				break

	if not tree:
		return

	if not is_active:
		clear_stutter_field()
		return

	var enemies: Array[Node] = tree.get_nodes_in_group("enemies")
	var current_slowed: Array[Node2D] = []

	for node: Node in enemies:
		if not is_instance_valid(node) or not (node is Node2D):
			continue
		var enemy: Node2D = node as Node2D
		if center.distance_to(enemy.global_position) <= 140.0:
			current_slowed.append(enemy)
			if not enemy.has_meta("is_stutter_slowed"):
				if "move_speed" in enemy:
					var orig_spd: float = float(enemy.move_speed)
					enemy.set_meta("stutter_orig_speed", orig_spd)
					enemy.move_speed = orig_spd * 0.75
				enemy.set_meta("is_stutter_slowed", true)

	for enemy: Node2D in _stutter_slowed_enemies:
		if is_instance_valid(enemy) and not current_slowed.has(enemy):
			if enemy.has_meta("is_stutter_slowed"):
				if enemy.has_meta("stutter_orig_speed") and "move_speed" in enemy:
					enemy.move_speed = float(enemy.get_meta("stutter_orig_speed"))
					enemy.remove_meta("stutter_orig_speed")
				enemy.remove_meta("is_stutter_slowed")

	_stutter_slowed_enemies = current_slowed

func clear_stutter_field() -> void:
	for enemy: Node2D in _stutter_slowed_enemies:
		if is_instance_valid(enemy):
			if enemy.has_meta("is_stutter_slowed"):
				if enemy.has_meta("stutter_orig_speed") and "move_speed" in enemy:
					enemy.move_speed = float(enemy.get_meta("stutter_orig_speed"))
					enemy.remove_meta("stutter_orig_speed")
				enemy.remove_meta("is_stutter_slowed")
	_stutter_slowed_enemies.clear()

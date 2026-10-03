class_name WeaponController
extends Node2D

## WeaponController.gd
## Controlador maestro de armas, ranuras de equipo y cadencia de disparo en Astra Dream.
## Coordina la capa de disparo activo (armas tácticas y carga de láser) y la capa pasiva automática.
## Delega adquisición de blancos a WeaponAutoAimCoordinator y la instanciación de proyectiles a WeaponProjectileFactory.

const WeaponAutoAimCoordinator = preload("res://scenes/combat/weapons/weapon_auto_aim_coordinator.gd")
const WeaponProjectileFactory = preload("res://scenes/combat/weapons/weapon_projectile_factory.gd")

signal laser_cooldown_updated(current: float, max_val: float)
signal laser_charge_updated(current: float, max_val: float, is_full: bool, is_memorized: bool)
signal laser_charge_ended()
signal weapons_updated(weapons: Array)
signal aim_mode_changed(is_manual: bool)
signal weapon_replaced(slot_index: int, new_inst: WeaponInstanceData)
signal swap_requested(incoming_weapon: WeaponData, on_replaced: Callable, on_cancelled: Callable)

@export var weapon_data: WeaponData
@export var player: Player

const MAX_WEAPON_SLOTS: int = 4

var equipped_weapons: Array[WeaponInstanceData] = []

# Subcontrolador de Proyectiles
var projectile_factory: WeaponProjectileFactory = WeaponProjectileFactory.new()

# Modo de apuntado de la capa pasiva
var is_manual_aim: bool = false
var current_locked_target: Node2D = null

# Carga de la capa activa unificada
var is_charging: bool = false
var charge_timer: float = 0.0
var max_charge_time: float = 3.0
var is_fully_charged: bool = false

# Memoria de carga en pausa (Charge Memory)
var has_charge_memory: bool = false
var memory_charge_timer: float = 0.0
var memory_is_fully_charged: bool = false
var memory_grace_timer: float = 0.0
const MEMORY_GRACE_MAX: float = 6.0

var last_known_target_dir: Vector2 = Vector2.UP

var active_drones: Array[Node2D]:
	get: return projectile_factory.active_drones if projectile_factory else []
	set(val):
		if projectile_factory: projectile_factory.active_drones = val


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if not player and get_parent() is Player:
		player = get_parent() as Player

	if weapon_data:
		add_weapon(weapon_data)
	elif equipped_weapons.is_empty():
		var default_w := WeaponData.new()
		default_w.weapon_id = &"rail_launcher"
		default_w.weapon_name = "Cañón Rail-Launcher Mk.I"
		default_w.base_damage = 40.0
		default_w.base_cooldown = 1.0
		default_w.passive_interval = 1.6
		default_w.passive_search_radius = 520.0
		add_weapon(default_w)


func clear_equipped_weapons() -> void:
	equipped_weapons.clear()
	weapons_updated.emit(equipped_weapons)


## ─── Nova Omega Spin API ────────────────────────────────────────────────────
func is_laser_fully_charged() -> bool:
	return is_fully_charged or memory_is_fully_charged


func consume_laser_charge() -> void:
	is_charging = false
	charge_timer = 0.0
	is_fully_charged = false
	has_charge_memory = false
	memory_charge_timer = 0.0
	memory_is_fully_charged = false
	memory_grace_timer = 0.0
	laser_charge_ended.emit()


## ─── Gestión de Ranuras y Equipamiento ──────────────────────────────────────
func add_weapon(data: WeaponData) -> bool:
	if not data:
		return false

	for inst in equipped_weapons:
		if inst.weapon_data.weapon_id == data.weapon_id:
			return upgrade_weapon(data.weapon_id)

	if equipped_weapons.size() < MAX_WEAPON_SLOTS:
		var new_inst := WeaponInstanceData.new(data, 1)
		equipped_weapons.append(new_inst)
		weapons_updated.emit(equipped_weapons)
		return true

	return false


func is_full() -> bool:
	return equipped_weapons.size() >= MAX_WEAPON_SLOTS


static func calculate_recycle_credits(weapon_level: int) -> int:
	return 35 + maxi(0, weapon_level - 1) * 15


func replace_weapon(slot_index: int, new_weapon_data: WeaponData, preserve_level: bool = true) -> bool:
	if not new_weapon_data or slot_index <= 0 or slot_index >= equipped_weapons.size():
		return false
	var old_inst: WeaponInstanceData = equipped_weapons[slot_index]
	var old_level: int = old_inst.level if old_inst else 1
	var target_level: int = maxi(old_level, 1) if preserve_level else 1

	var recycle_credits: int = calculate_recycle_credits(old_level)
	if is_instance_valid(player) and player.has_method("add_credits"):
		player.add_credits(recycle_credits)

	var new_inst := WeaponInstanceData.new(new_weapon_data, target_level)
	equipped_weapons[slot_index] = new_inst
	weapons_updated.emit(equipped_weapons)
	weapon_replaced.emit(slot_index, new_inst)
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("upgrade_obtained", 1.0, 1.2)
	return true


func upgrade_weapon(weapon_id: StringName) -> bool:
	for inst in equipped_weapons:
		if inst.weapon_data.weapon_id == weapon_id:
			if inst.level < 5:
				inst.level += 1
				weapons_updated.emit(equipped_weapons)
				var audio_mgr := get_node_or_null("/root/AudioManager")
				if audio_mgr and audio_mgr.has_method("play_sfx"):
					audio_mgr.play_sfx("ui_click", 1.8, 4.0)
				return true
			return false
	return false


func get_weapon_instance(weapon_id: StringName) -> WeaponInstanceData:
	for inst in equipped_weapons:
		if inst.weapon_data.weapon_id == weapon_id:
			return inst
	return null


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		if is_charging and charge_timer > 0.05:
			has_charge_memory = true
			memory_charge_timer = charge_timer
			memory_is_fully_charged = is_fully_charged
			memory_grace_timer = MEMORY_GRACE_MAX


func _process(delta: float) -> void:
	if player and (player.is_dead or player.is_movement_suppressed):
		return
	_handle_toggle_input()
	_update_locked_target()
	_handle_aim(delta)
	_handle_active_fire(delta)
	_handle_passive_fire(delta)


func _handle_toggle_input() -> void:
	if Input.is_action_just_pressed("toggle_aim_mode"):
		if player and player.has_method("is_any_menu_or_modal_active") and player.is_any_menu_or_modal_active():
			return
		toggle_aim_mode()


func toggle_aim_mode() -> void:
	is_manual_aim = not is_manual_aim
	aim_mode_changed.emit(is_manual_aim)
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("ui_click", 1.6 if is_manual_aim else 1.2, 0.0)


func _update_locked_target() -> void:
	if is_manual_aim:
		current_locked_target = null
	else:
		current_locked_target = _find_closest_enemy_in_pickup_radius()


func get_autoaim_range() -> float:
	return WeaponAutoAimCoordinator.get_autoaim_range(player)


func _find_closest_enemy_in_pickup_radius() -> Node2D:
	return WeaponAutoAimCoordinator.find_closest_enemy_in_pickup_radius(global_position, get_autoaim_range(), get_tree())


func _get_passive_aim_info() -> Dictionary:
	var info := WeaponAutoAimCoordinator.get_passive_aim_info(
		is_manual_aim,
		global_position,
		get_global_mouse_position(),
		current_locked_target,
		last_known_target_dir,
		player,
		rotation,
		get_autoaim_range(),
		get_tree()
	)
	last_known_target_dir = info.get("last_known_dir", last_known_target_dir)
	return info


func _handle_aim(delta: float = 0.0) -> void:
	if player and player.is_omega_spinning:
		return

	var is_fire_pressed := Input.is_action_pressed("fire_active")
	var target_angle := WeaponAutoAimCoordinator.calculate_aim_angle(
		is_manual_aim,
		global_position,
		get_global_mouse_position(),
		current_locked_target,
		_get_passive_aim_info(),
		is_fire_pressed
	)

	if delta > 0.0:
		rotation = lerp_angle(rotation, target_angle, 20.0 * delta)
	else:
		rotation = target_angle


func _handle_active_fire(delta: float) -> void:
	for inst in equipped_weapons:
		if inst.active_cooldown > 0.0:
			inst.active_cooldown -= delta

	var laser_inst: WeaponInstanceData = null
	for inst in equipped_weapons:
		if inst.weapon_data and inst.weapon_data.active_behavior_type == &"laser":
			laser_inst = inst
			break

	if laser_inst:
		var max_cd := laser_inst.get_effective_cooldown(player.stats if player else null)
		laser_cooldown_updated.emit(maxf(0.0, laser_inst.active_cooldown), max_cd)
	elif not equipped_weapons.is_empty():
		var primary := equipped_weapons[0]
		var max_cd := primary.get_effective_cooldown(player.stats if player else null)
		laser_cooldown_updated.emit(maxf(0.0, primary.active_cooldown), max_cd)

	var aim_dir := (get_global_mouse_position() - global_position).normalized()
	if aim_dir.length_squared() < 0.001:
		aim_dir = Vector2.RIGHT

	# Disparo instantáneo para armas no láser
	if Input.is_action_pressed("fire_active"):
		for inst in equipped_weapons:
			if inst.weapon_data and inst.weapon_data.active_behavior_type != &"laser":
				if inst.active_cooldown <= 0.0:
					_dispatch_weapon_active_fire(inst, aim_dir, false, 0.0)
					inst.active_cooldown = inst.get_effective_cooldown(player.stats if player else null)

	# Mecánica de carga exclusiva para el láser
	if laser_inst:
		if has_charge_memory:
			memory_grace_timer -= delta
			if memory_grace_timer <= 0.0:
				has_charge_memory = false
				laser_charge_ended.emit()
			else:
				laser_charge_updated.emit(memory_charge_timer, max_charge_time, memory_is_fully_charged, true)

		if Input.is_action_pressed("fire_active"):
			if laser_inst.active_cooldown <= 0.0:
				if not is_charging:
					is_charging = true
					charge_timer = 0.0
					is_fully_charged = false

				charge_timer += delta
				if charge_timer >= max_charge_time:
					charge_timer = max_charge_time
					if not is_fully_charged:
						is_fully_charged = true
						var audio_mgr := get_node_or_null("/root/AudioManager")
						if audio_mgr and audio_mgr.has_method("play_sfx"):
							audio_mgr.play_sfx("ui_click", 2.0, -2.0)

				laser_charge_updated.emit(charge_timer, max_charge_time, is_fully_charged, false)
			else:
				if is_charging:
					is_charging = false
					charge_timer = 0.0
					laser_charge_ended.emit()

		elif Input.is_action_just_released("fire_active"):
			var ready_to_fire := false
			var charge_to_use := 0.0
			var full_to_use := false

			if is_charging:
				charge_to_use = charge_timer
				full_to_use = is_fully_charged
				ready_to_fire = true
			elif has_charge_memory:
				charge_to_use = memory_charge_timer
				full_to_use = memory_is_fully_charged
				ready_to_fire = true
			elif laser_inst.active_cooldown <= 0.0:
				ready_to_fire = true

			if ready_to_fire:
				for inst in equipped_weapons:
					if inst.weapon_data and inst.weapon_data.active_behavior_type == &"laser":
						if inst.active_cooldown <= 0.0:
							_dispatch_weapon_active_fire(inst, aim_dir, full_to_use, charge_to_use)
							inst.active_cooldown = inst.get_effective_cooldown(player.stats if player else null)

			is_charging = false
			charge_timer = 0.0
			is_fully_charged = false
			has_charge_memory = false
			laser_charge_ended.emit()
		else:
			if is_charging:
				if charge_timer > 0.05:
					has_charge_memory = true
					memory_charge_timer = charge_timer
					memory_is_fully_charged = is_fully_charged
					memory_grace_timer = MEMORY_GRACE_MAX
				is_charging = false
				charge_timer = 0.0
				is_fully_charged = false
				if not has_charge_memory:
					laser_charge_ended.emit()
	else:
		if is_charging or has_charge_memory:
			is_charging = false
			charge_timer = 0.0
			is_fully_charged = false
			has_charge_memory = false
			laser_charge_ended.emit()


func trigger_instant_salvo() -> void:
	var aim_dir := (get_global_mouse_position() - global_position).normalized()
	if aim_dir.length_squared() < 0.001:
		aim_dir = Vector2.RIGHT
	for inst in equipped_weapons:
		_dispatch_weapon_active_fire(inst, aim_dir, false, 0.0)


func _fire_all_active_weapons(is_focused: bool, charge_amount: float) -> void:
	var aim_dir := (get_global_mouse_position() - global_position).normalized()
	if aim_dir.length_squared() < 0.001:
		aim_dir = Vector2.RIGHT

	for inst in equipped_weapons:
		if inst.active_cooldown <= 0.0:
			_dispatch_weapon_active_fire(inst, aim_dir, is_focused, charge_amount)
			inst.active_cooldown = inst.get_effective_cooldown(player.stats if player else null)


func _dispatch_weapon_active_fire(inst: WeaponInstanceData, aim_dir: Vector2, is_focused: bool, charge_ratio: float) -> void:
	var spawn_parent: Node = get_tree().current_scene if get_tree().current_scene else get_tree().root
	projectile_factory.dispatch_active_fire(
		inst,
		aim_dir,
		is_focused,
		charge_ratio,
		max_charge_time,
		player,
		global_position,
		get_global_mouse_position(),
		spawn_parent
	)


func _handle_passive_fire(delta: float) -> void:
	for inst in equipped_weapons:
		inst.passive_timer -= delta
		if inst.passive_timer <= 0.0:
			inst.passive_timer = inst.get_effective_passive_interval(player.stats if player else null)
			_dispatch_weapon_passive_fire(inst)


func _dispatch_weapon_passive_fire(inst: WeaponInstanceData) -> void:
	var spawn_parent: Node = get_tree().current_scene if get_tree().current_scene else get_tree().root
	projectile_factory.dispatch_passive_fire(
		inst,
		_get_passive_aim_info(),
		is_manual_aim,
		get_global_mouse_position(),
		get_autoaim_range(),
		player,
		global_position,
		self,
		spawn_parent
	)

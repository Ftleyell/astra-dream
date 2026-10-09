class_name WeaponController
extends Node2D

## WeaponController.gd
## Controlador maestro de armas, ranuras de equipo y cadencia de disparo en Astra Dream.
## Coordina la adquisición de blancos (CombatTargetingSystem), cadencia/carga (WeaponCooldownTracker)
## y la instanciación de proyectiles (WeaponProjectileFactory).

const CombatTargetingSystemScript = preload("res://scenes/combat/player/combat_targeting_system.gd")
const WeaponCooldownTrackerScript = preload("res://scenes/combat/player/weapon_cooldown_tracker.gd")
const WeaponProjectileFactoryScript = preload("res://scenes/combat/weapons/weapon_projectile_factory.gd")

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
var projectile_factory: WeaponProjectileFactory = WeaponProjectileFactoryScript.new()
var targeting: CombatTargetingSystemScript = CombatTargetingSystemScript.new()
var cooldown_tracker: WeaponCooldownTrackerScript = WeaponCooldownTrackerScript.new()

var is_manual_aim: bool:
	get: return targeting.is_manual_aim
	set(val): targeting.is_manual_aim = val

var current_locked_target: Node2D:
	get: return targeting.current_locked_target
	set(val): targeting.current_locked_target = val

var is_charging: bool:
	get: return cooldown_tracker.is_charging
	set(val): cooldown_tracker.is_charging = val

var charge_timer: float:
	get: return cooldown_tracker.charge_timer
	set(val): cooldown_tracker.charge_timer = val

var max_charge_time: float:
	get: return cooldown_tracker.max_charge_time
	set(val): cooldown_tracker.max_charge_time = val

var is_fully_charged: bool:
	get: return cooldown_tracker.is_fully_charged
	set(val): cooldown_tracker.is_fully_charged = val

var has_charge_memory: bool:
	get: return cooldown_tracker.has_charge_memory
	set(val): cooldown_tracker.has_charge_memory = val

var memory_charge_timer: float:
	get: return cooldown_tracker.memory_charge_timer
	set(val): cooldown_tracker.memory_charge_timer = val

var memory_is_fully_charged: bool:
	get: return cooldown_tracker.memory_is_fully_charged
	set(val): cooldown_tracker.memory_is_fully_charged = val

var memory_grace_timer: float:
	get: return cooldown_tracker.memory_grace_timer
	set(val): cooldown_tracker.memory_grace_timer = val

var active_drones: Array[Node2D]:
	get: return projectile_factory.active_drones if projectile_factory else []
	set(val):
		if projectile_factory: projectile_factory.active_drones = val

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if not player and get_parent() is Player:
		player = get_parent() as Player

	_bind_subsystems()

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

func _bind_subsystems() -> void:
	targeting.aim_mode_changed.connect(func(manual: bool) -> void: aim_mode_changed.emit(manual))
	cooldown_tracker.laser_cooldown_updated.connect(func(c: float, m: float) -> void: laser_cooldown_updated.emit(c, m))
	cooldown_tracker.laser_charge_updated.connect(func(c: float, m: float, full: bool, mem: bool) -> void: laser_charge_updated.emit(c, m, full, mem))
	cooldown_tracker.laser_charge_ended.connect(func() -> void: laser_charge_ended.emit())
	cooldown_tracker.dispatch_active_requested.connect(_dispatch_weapon_active_fire)
	cooldown_tracker.dispatch_passive_requested.connect(_dispatch_weapon_passive_fire)

func clear_equipped_weapons() -> void:
	equipped_weapons.clear()
	weapons_updated.emit(equipped_weapons)

func is_laser_fully_charged() -> bool:
	return cooldown_tracker.is_laser_fully_charged()

func consume_laser_charge() -> void:
	cooldown_tracker.consume_laser_charge()

func get_effective_max_charge_time() -> float:
	return cooldown_tracker.get_effective_max_charge_time(player)

func add_weapon(data: WeaponData) -> bool:
	if not data:
		return false
	for inst: WeaponInstanceData in equipped_weapons:
		if inst.weapon_data.weapon_id == data.weapon_id:
			return upgrade_weapon(data.weapon_id)

	if equipped_weapons.size() < MAX_WEAPON_SLOTS:
		var new_inst := WeaponInstanceData.new(data, 1)
		equipped_weapons.append(new_inst)
		weapons_updated.emit(equipped_weapons)
		return true
	return false

func equip_weapon(data: WeaponData) -> bool:
	return add_weapon(data)

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
	var audio_mgr: Node = Engine.get_main_loop().root.get_node_or_null("/root/AudioManager") if Engine.get_main_loop() else null
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("upgrade_obtained", 1.0, 1.2)
	return true

func upgrade_weapon(weapon_id: StringName, tier: Enums.Tier = Enums.Tier.TIER_2) -> bool:
	for inst: WeaponInstanceData in equipped_weapons:
		if inst.weapon_data.weapon_id == weapon_id:
			inst.level += 1
			inst.upgrade_tier = tier
			match tier:
				Enums.Tier.TIER_1: inst.tier_damage_multiplier = 0.85
				Enums.Tier.TIER_2: inst.tier_damage_multiplier = 1.00
				Enums.Tier.TIER_3: inst.tier_damage_multiplier = 1.20
				Enums.Tier.TIER_4: inst.tier_damage_multiplier = 1.45
				_: inst.tier_damage_multiplier = 1.00
			weapons_updated.emit(equipped_weapons)
			var audio_mgr: Node = Engine.get_main_loop().root.get_node_or_null("/root/AudioManager") if Engine.get_main_loop() else null
			if audio_mgr and audio_mgr.has_method("play_sfx"):
				audio_mgr.play_sfx("ui_click", 1.8, 4.0)
			return true
	return false

func get_weapon_instance(weapon_id: StringName) -> WeaponInstanceData:
	for inst: WeaponInstanceData in equipped_weapons:
		if inst.weapon_data.weapon_id == weapon_id:
			return inst
	return null

func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		cooldown_tracker.save_charge_memory_on_pause()

func _process(delta: float) -> void:
	if player and (player.is_dead or player.is_movement_suppressed):
		return
	_handle_toggle_input()
	targeting.update_locked_target(global_position, player, get_tree())
	_handle_aim(delta)

	_handle_active_fire(delta)
	_handle_passive_fire(delta)
	targeting.handle_stutter_field(equipped_weapons, global_position, get_tree())

func _handle_active_fire(delta: float) -> void:
	var aim_dir: Vector2 = (get_global_mouse_position() - global_position).normalized()
	if aim_dir.length_squared() < 0.001:
		aim_dir = Vector2.RIGHT
	cooldown_tracker.process_active_fire(equipped_weapons, player, aim_dir, delta)

func _handle_passive_fire(delta: float) -> void:
	cooldown_tracker.process_passive_fire(equipped_weapons, player, delta)

func _handle_toggle_input() -> void:
	if Input.is_action_just_pressed("toggle_aim_mode"):
		if player and player.has_method("is_any_menu_or_modal_active") and player.is_any_menu_or_modal_active():
			return
		toggle_aim_mode()

func toggle_aim_mode() -> void:
	targeting.toggle_aim_mode()

func get_autoaim_range() -> float:
	return targeting.get_autoaim_range(player)

func _handle_aim(delta: float = 0.0) -> void:
	if player and player.is_omega_spinning:
		return
	var is_fire_pressed: bool = Input.is_action_pressed("fire_active")
	var target_angle: float = targeting.calculate_aim_angle(
		global_position,
		get_global_mouse_position(),
		player,
		rotation,
		is_fire_pressed,
		get_tree()
	)
	if delta > 0.0:
		rotation = lerp_angle(rotation, target_angle, 20.0 * delta)
	else:
		rotation = target_angle

func trigger_instant_salvo() -> void:
	var aim_dir: Vector2 = (get_global_mouse_position() - global_position).normalized()
	if aim_dir.length_squared() < 0.001:
		aim_dir = Vector2.RIGHT
	for inst: WeaponInstanceData in equipped_weapons:
		_dispatch_weapon_active_fire(inst, aim_dir, false, 0.0)

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

func _dispatch_weapon_passive_fire(inst: WeaponInstanceData) -> void:
	var spawn_parent: Node = get_tree().current_scene if get_tree().current_scene else get_tree().root
	var p_aim_info: Dictionary = targeting.get_passive_aim_info(global_position, get_global_mouse_position(), player, rotation, get_tree())
	projectile_factory.dispatch_passive_fire(
		inst,
		p_aim_info,
		targeting.is_manual_aim,
		get_global_mouse_position(),
		get_autoaim_range(),
		player,
		global_position,
		self,
		spawn_parent
	)

func _exit_tree() -> void:
	targeting.clear_stutter_field()

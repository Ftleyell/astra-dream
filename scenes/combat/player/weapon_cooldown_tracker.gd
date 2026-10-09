class_name WeaponCooldownTracker
extends RefCounted

## WeaponCooldownTracker.gd
## Manejador desacoplado de tiempos de recarga (cooldowns) activos y pasivos,
## máquina de estados de carga continua de láser y persistencia de carga en pausas.

signal laser_cooldown_updated(current: float, max_val: float)
signal laser_charge_updated(current: float, max_val: float, is_full: bool, is_memorized: bool)
signal laser_charge_ended()
signal dispatch_active_requested(inst: WeaponInstanceData, aim_dir: Vector2, is_focused: bool, charge_ratio: float)
signal dispatch_passive_requested(inst: WeaponInstanceData)

const MEMORY_GRACE_MAX: float = 6.0

var max_charge_time: float = 3.0
var is_charging: bool = false
var charge_timer: float = 0.0
var is_fully_charged: bool = false

var has_charge_memory: bool = false
var memory_charge_timer: float = 0.0
var memory_is_fully_charged: bool = false
var memory_grace_timer: float = 0.0

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

func get_effective_max_charge_time(player: Player) -> float:
	var base_time: float = max_charge_time
	if is_instance_valid(player) and "stats" in player and player.stats:
		var cur_speed: float = float(player.stats.get_stat(&"move_speed"))
		return clampf(base_time * (340.0 / maxf(100.0, cur_speed)), 1.2, base_time)
	return base_time

func save_charge_memory_on_pause() -> void:
	if is_charging and charge_timer > 0.05:
		has_charge_memory = true
		memory_charge_timer = charge_timer
		memory_is_fully_charged = is_fully_charged
		memory_grace_timer = MEMORY_GRACE_MAX

func process_active_fire(equipped_weapons: Array[WeaponInstanceData], player: Player, aim_dir: Vector2, delta: float) -> void:
	for inst: WeaponInstanceData in equipped_weapons:
		if inst.active_cooldown > 0.0:
			inst.active_cooldown -= delta

	var laser_inst: WeaponInstanceData = null
	for inst: WeaponInstanceData in equipped_weapons:
		if inst.weapon_data and inst.weapon_data.active_behavior_type == &"laser":
			laser_inst = inst
			break

	var stats: CharacterStats = player.stats if player else null
	if laser_inst:
		var max_cd: float = laser_inst.get_effective_cooldown(stats)
		laser_cooldown_updated.emit(maxf(0.0, laser_inst.active_cooldown), max_cd)
	elif not equipped_weapons.is_empty():
		var primary: WeaponInstanceData = equipped_weapons[0]
		var max_cd: float = primary.get_effective_cooldown(stats)
		laser_cooldown_updated.emit(maxf(0.0, primary.active_cooldown), max_cd)

	# Disparo instantáneo para armas no láser
	if Input.is_action_pressed("fire_active"):
		for inst: WeaponInstanceData in equipped_weapons:
			if inst.weapon_data and inst.weapon_data.active_behavior_type != &"laser":
				if inst.active_cooldown <= 0.0:
					dispatch_active_requested.emit(inst, aim_dir, false, 0.0)
					inst.active_cooldown = inst.get_effective_cooldown(stats)

	# Mecánica de carga para láser
	if laser_inst:
		var effective_max_charge: float = get_effective_max_charge_time(player)
		if has_charge_memory:
			memory_grace_timer -= delta
			if memory_grace_timer <= 0.0:
				has_charge_memory = false
				laser_charge_ended.emit()
			else:
				laser_charge_updated.emit(memory_charge_timer, effective_max_charge, memory_is_fully_charged, true)

		if Input.is_action_pressed("fire_active"):
			if laser_inst.active_cooldown <= 0.0:
				if not is_charging:
					is_charging = true
					charge_timer = 0.0
					is_fully_charged = false

				charge_timer += delta
				if charge_timer >= effective_max_charge:
					charge_timer = effective_max_charge
					if not is_fully_charged:
						is_fully_charged = true
						var audio_mgr: Node = Engine.get_main_loop().root.get_node_or_null("/root/AudioManager") if Engine.get_main_loop() else null
						if audio_mgr and audio_mgr.has_method("play_sfx"):
							audio_mgr.play_sfx("ui_click", 2.0, -2.0)

				laser_charge_updated.emit(charge_timer, effective_max_charge, is_fully_charged, false)
			else:
				if is_charging:
					is_charging = false
					charge_timer = 0.0
					laser_charge_ended.emit()

		elif Input.is_action_just_released("fire_active"):
			var ready_to_fire: bool = false
			var charge_to_use: float = 0.0
			var full_to_use: bool = false

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
				for inst: WeaponInstanceData in equipped_weapons:
					if inst.weapon_data and inst.weapon_data.active_behavior_type == &"laser":
						if inst.active_cooldown <= 0.0:
							dispatch_active_requested.emit(inst, aim_dir, full_to_use, charge_to_use)
							inst.active_cooldown = inst.get_effective_cooldown(stats)

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

func process_passive_fire(equipped_weapons: Array[WeaponInstanceData], player: Player, delta: float) -> void:
	var stats: CharacterStats = player.stats if player else null
	for inst: WeaponInstanceData in equipped_weapons:
		inst.passive_timer -= delta
		if inst.passive_timer <= 0.0:
			inst.passive_timer = inst.get_effective_passive_interval(stats)
			dispatch_passive_requested.emit(inst)

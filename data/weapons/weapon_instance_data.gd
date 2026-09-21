class_name WeaponInstanceData
extends RefCounted

signal level_changed(new_level: int)

var weapon_data: WeaponData
var level: int = 1:
	set(val):
		level = clampi(val, 1, 5)
		level_changed.emit(level)

var active_cooldown: float = 0.0
var passive_timer: float = 0.1

func _init(p_data: WeaponData, p_level: int = 1) -> void:
	weapon_data = p_data
	level = p_level
	active_cooldown = 0.0
	passive_timer = 0.1

func get_damage_multiplier() -> float:
	return 1.0 + (float(level - 1) * weapon_data.damage_growth_per_level)

func get_cooldown_multiplier() -> float:
	return maxf(0.3, 1.0 - (float(level - 1) * weapon_data.cooldown_reduction_per_level))

func get_passive_interval_multiplier() -> float:
	return maxf(0.3, 1.0 - (float(level - 1) * weapon_data.passive_interval_reduction_per_level))

func get_effective_damage(player_stats: CharacterStats = null) -> float:
	var base := weapon_data.base_damage * get_damage_multiplier()
	if player_stats:
		base += player_stats.get_stat(&"base_damage")
	return base

func get_effective_cooldown(player_stats: CharacterStats = null) -> float:
	var cd := weapon_data.base_cooldown * get_cooldown_multiplier()
	if player_stats:
		var cdr: float = player_stats.get_stat(&"cooldown_reduction")
		cd = maxf(0.05, cd * (1.0 - clampf(cdr, 0.0, 0.8)))
	return cd

func get_effective_passive_interval(player_stats: CharacterStats = null) -> float:
	var interval := weapon_data.passive_interval * get_passive_interval_multiplier()
	if player_stats:
		var atk_speed: float = player_stats.get_stat(&"attack_speed")
		interval = interval / maxf(0.1, atk_speed)
	return interval

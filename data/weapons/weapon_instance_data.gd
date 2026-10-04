class_name WeaponInstanceData
extends RefCounted

signal level_changed(new_level: int)

var weapon_data: WeaponData
var level: int = 1:
	set(val):
		level = maxi(val, 1)
		level_changed.emit(level)

var active_cooldown: float = 0.0
var passive_timer: float = 0.1
var upgrade_tier: Enums.Tier = Enums.Tier.TIER_2
var tier_damage_multiplier: float = 1.0

func _init(p_data: WeaponData = null, p_level: int = 1) -> void:
	weapon_data = p_data
	level = maxi(p_level, 1)
	active_cooldown = 0.0
	passive_timer = 0.1
	upgrade_tier = Enums.Tier.TIER_2
	tier_damage_multiplier = 1.0

func get_damage_multiplier() -> float:
	if not weapon_data:
		return 1.0
	var lvl_diff: float = float(level - 1)
	if lvl_diff <= 0.0:
		return 1.0
	var linear_growth: float = lvl_diff * weapon_data.damage_growth_per_level
	var mult: float = 1.0 + (linear_growth / (1.0 + lvl_diff * 0.05))
	return mult * tier_damage_multiplier

func get_cooldown_multiplier() -> float:
	if not weapon_data:
		return 1.0
	var lvl_diff: float = float(level - 1)
	if lvl_diff <= 0.0:
		return 1.0
	var reduction_factor: float = lvl_diff * weapon_data.cooldown_reduction_per_level
	return maxf(0.15, 1.0 / (1.0 + reduction_factor))

func get_passive_interval_multiplier() -> float:
	if not weapon_data:
		return 1.0
	var lvl_diff: float = float(level - 1)
	if lvl_diff <= 0.0:
		return 1.0
	var reduction_factor: float = lvl_diff * weapon_data.passive_interval_reduction_per_level
	return maxf(0.15, 1.0 / (1.0 + reduction_factor))

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

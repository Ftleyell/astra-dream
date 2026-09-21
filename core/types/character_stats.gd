class_name CharacterStats
extends RefCounted

signal stat_changed(stat_name: StringName, new_value: float)

class StatModifier:
	var id: StringName
	var value: float
	var is_percentage: bool
	var source: Variant

	func _init(p_id: StringName, p_val: float, p_is_pct: bool, p_source: Variant = null) -> void:
		id = p_id
		value = p_val
		is_percentage = p_is_pct
		source = p_source

var _base_stats: Dictionary[StringName, float] = {}
var _modifiers: Dictionary[StringName, Array] = {}
var _cached_values: Dictionary[StringName, float] = {}
var _is_dirty: Dictionary[StringName, bool] = {}

func initialize(char_data: CharacterData) -> void:
	_base_stats = {
		&"max_health": char_data.max_health,
		&"health_regen": char_data.health_regen,
		&"move_speed": char_data.move_speed,
		&"armor": char_data.armor,
		&"base_damage": char_data.base_damage,
		&"attack_speed": char_data.attack_speed,
		&"crit_chance": char_data.crit_chance,
		&"crit_damage": char_data.crit_damage,
		&"luck": char_data.luck,
		&"pickup_radius": char_data.pickup_radius,
		&"projectile_count": char_data.projectile_count if "projectile_count" in char_data else 1.0,
	}
	for key in _base_stats.keys():
		_modifiers[key] = []
		_is_dirty[key] = true

func add_modifier(stat_name: StringName, mod: StatModifier) -> void:
	if not _modifiers.has(stat_name):
		_modifiers[stat_name] = []
		_base_stats[stat_name] = 0.0
	_modifiers[stat_name].append(mod)
	_is_dirty[stat_name] = true
	stat_changed.emit(stat_name, get_stat(stat_name))

func get_stat(stat_name: StringName) -> float:
	if not _base_stats.has(stat_name):
		return 0.0
	if _is_dirty.get(stat_name, false):
		_recalculate_stat(stat_name)
	return _cached_values[stat_name]

func _recalculate_stat(stat_name: StringName) -> void:
	var base_val: float = _base_stats.get(stat_name, 0.0)
	var flat_sum: float = 0.0
	var percent_sum: float = 0.0

	for mod: StatModifier in _modifiers.get(stat_name, []):
		if mod.is_percentage:
			percent_sum += mod.value
		else:
			flat_sum += mod.value

	var final_val: float = (base_val + flat_sum) * maxf(0.0, 1.0 + percent_sum)
	if stat_name == &"projectile_count":
		final_val = maxf(1.0, round(final_val))
	_cached_values[stat_name] = final_val
	_is_dirty[stat_name] = false

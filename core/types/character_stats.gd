class_name CharacterStats
extends RefCounted

signal stat_changed(stat_name: StringName, new_value: float)

class StatModifier:
	var id: StringName
	var value: float
	var mod_type: Enums.ModifierType = Enums.ModifierType.FLAT
	var is_percentage: bool:
		get:
			return mod_type == Enums.ModifierType.ADDITIVE_PERCENT or mod_type == Enums.ModifierType.MULTIPLICATIVE
		set(val):
			mod_type = Enums.ModifierType.ADDITIVE_PERCENT if val else Enums.ModifierType.FLAT
	var source: Variant

	func _init(p_id: StringName, p_val: float, p_type_or_is_pct: Variant = false, p_source: Variant = null) -> void:
		id = p_id
		value = p_val
		source = p_source
		if p_type_or_is_pct is bool:
			mod_type = Enums.ModifierType.ADDITIVE_PERCENT if p_type_or_is_pct else Enums.ModifierType.FLAT
		elif p_type_or_is_pct is int or p_type_or_is_pct is float:
			mod_type = int(p_type_or_is_pct) as Enums.ModifierType
		else:
			mod_type = Enums.ModifierType.FLAT

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
		&"projectile_speed": char_data.projectile_speed if "projectile_speed" in char_data else 1.0,
		&"weapon_size": char_data.weapon_size if "weapon_size" in char_data else 1.0,
		&"cooldown_reduction": char_data.cooldown_reduction if "cooldown_reduction" in char_data else 0.0,
		&"exp_multiplier": char_data.exp_multiplier if "exp_multiplier" in char_data else 1.0,
		&"biomass_multiplier": char_data.biomass_multiplier if "biomass_multiplier" in char_data else 1.0,
		&"credits_multiplier": char_data.credits_multiplier if "credits_multiplier" in char_data else 1.0,
		&"curse": char_data.curse if "curse" in char_data else 0.0,
	}
	for key in _base_stats.keys():
		_modifiers[key] = []
		_is_dirty[key] = true

func set_base_stat(stat_name: StringName, val: float) -> void:
	_base_stats[stat_name] = val
	if not _modifiers.has(stat_name):
		_modifiers[stat_name] = []
	_is_dirty[stat_name] = true
	stat_changed.emit(stat_name, get_stat(stat_name))

func get_base_stat(stat_name: StringName) -> float:
	return _base_stats.get(stat_name, 0.0)

func add_modifier(stat_name: StringName, mod: StatModifier) -> void:
	if not _modifiers.has(stat_name):
		_modifiers[stat_name] = []
		_base_stats[stat_name] = 0.0
	_modifiers[stat_name].append(mod)
	_is_dirty[stat_name] = true
	stat_changed.emit(stat_name, get_stat(stat_name))

func add_stat_bonus(stat_name: StringName, amount: float, p_type_or_is_pct: Variant = false, source: Variant = null) -> void:
	var mod_id: StringName = StringName(str(stat_name) + "_bonus_" + str(Time.get_ticks_usec()))
	add_modifier(stat_name, StatModifier.new(mod_id, amount, p_type_or_is_pct, source))

func set_or_replace_modifier(stat_name: StringName, mod: StatModifier) -> void:
	if not _modifiers.has(stat_name):
		_modifiers[stat_name] = []
		_base_stats[stat_name] = 0.0

	var list: Array = _modifiers[stat_name]
	var replaced := false
	for i in range(list.size()):
		var existing: StatModifier = list[i]
		if existing.id == mod.id:
			list[i] = mod
			replaced = true
			break
	if not replaced:
		list.append(mod)

	_is_dirty[stat_name] = true
	stat_changed.emit(stat_name, get_stat(stat_name))

func remove_modifier(stat_name: StringName, mod_id: StringName) -> void:
	if not _modifiers.has(stat_name):
		return
	var list: Array = _modifiers[stat_name]
	var removed := false
	for i in range(list.size() - 1, -1, -1):
		var existing: StatModifier = list[i]
		if existing.id == mod_id:
			list.remove_at(i)
			removed = true
	if removed:
		_is_dirty[stat_name] = true
		stat_changed.emit(stat_name, get_stat(stat_name))

func clear_modifiers(stat_name: StringName) -> void:
	if _modifiers.has(stat_name):
		_modifiers[stat_name].clear()
		_is_dirty[stat_name] = true
		stat_changed.emit(stat_name, get_stat(stat_name))

func get_stat_modifier(stat_name: StringName, mod_id: StringName) -> StatModifier:
	if not _modifiers.has(stat_name):
		return null
	var list: Array = _modifiers[stat_name]
	for mod in list:
		if (mod as StatModifier).id == mod_id:
			return mod as StatModifier
	return null

func has_modifier(stat_name: StringName, mod_id: StringName) -> bool:
	return get_stat_modifier(stat_name, mod_id) != null

func get_stat(stat_name: StringName) -> float:
	if not _base_stats.has(stat_name):
		return 0.0
	if _is_dirty.get(stat_name, false):
		_recalculate_stat(stat_name)
	return _cached_values[stat_name]

func _recalculate_stat(stat_name: StringName) -> void:
	var base_val: float = _base_stats.get(stat_name, 0.0)
	var flat_sum: float = 0.0
	var add_pct_sum: float = 0.0
	var mult_product: float = 1.0

	for mod: StatModifier in _modifiers.get(stat_name, []):
		match mod.mod_type:
			Enums.ModifierType.FLAT:
				flat_sum += mod.value
			Enums.ModifierType.ADDITIVE_PERCENT:
				add_pct_sum += mod.value
			Enums.ModifierType.MULTIPLICATIVE:
				mult_product *= maxf(0.0, 1.0 + mod.value)

	var final_val: float = (base_val + flat_sum) * maxf(0.0, 1.0 + add_pct_sum) * mult_product
	if stat_name == &"projectile_count":
		final_val = maxf(1.0, round(final_val))
	elif stat_name == &"max_health":
		final_val = maxf(1.0, final_val)
	_cached_values[stat_name] = final_val
	_is_dirty[stat_name] = false

class_name InventoryComponent
extends Node

var character_stats: CharacterStats

# Almacena: item_id -> { "data": ItemData, "count": int }
var _items: Dictionary[StringName, Dictionary] = {}

# Internal Cooldowns dinámicos para mitigar procs en armas de alta frecuencia
var _proc_cooldowns: Dictionary[StringName, float] = {}

const HIGH_FREQ_WEAPON_ICDS: Dictionary[StringName, float] = {
	&"hive_cannon": 0.10,
	&"swarm_missiles": 0.10,
	&"singularity_pulsar": 0.25,
	&"void_siphon": 0.25,
	&"tachyon_beam": 0.15,
	&"solar_beam": 0.15
}

signal item_added(item: ItemData, new_total: int)

func add_item(item: ItemData, count: int = 1) -> void:
	var id: StringName = item.item_id
	if not _items.has(id):
		_items[id] = { "data": item, "count": 0 }

	var current_count: int = _items[id]["count"]
	var new_count: int = mini(current_count + count, item.max_stacks)
	_items[id]["count"] = new_count

	# Aplicar modificador reactivo a CharacterStats si el ítem define estadísticas
	if character_stats and item.stat_name != &"":
		var total_bonus: float = item.stat_value * float(new_count)
		var m_type: Enums.ModifierType = item.get_effective_modifier_type() if item.has_method(&"get_effective_modifier_type") else (item.modifier_type if "modifier_type" in item else (Enums.ModifierType.ADDITIVE_PERCENT if item.is_percentage else Enums.ModifierType.FLAT))
		var mod := CharacterStats.StatModifier.new(item.item_id, total_bonus, m_type, item.item_id)
		character_stats.set_or_replace_modifier(item.stat_name, mod)

	# Aplicar modificador secundario / de penalización (anti-sinergia)
	if character_stats and item.secondary_stat_name != &"":
		var total_penalty: float = item.secondary_stat_value * float(new_count)
		var sec_type: Enums.ModifierType = item.get_effective_secondary_modifier_type() if item.has_method(&"get_effective_secondary_modifier_type") else (item.secondary_modifier_type if "secondary_modifier_type" in item else (Enums.ModifierType.ADDITIVE_PERCENT if item.secondary_is_percentage else Enums.ModifierType.FLAT))
		var p_mod := CharacterStats.StatModifier.new(
			StringName(str(item.item_id) + "_penalty"),
			total_penalty,
			sec_type,
			item.item_id
		)
		character_stats.set_or_replace_modifier(item.secondary_stat_name, p_mod)

	item_added.emit(item, new_count)

func clear_items() -> void:
	if character_stats:
		for id: StringName in _items.keys():
			var item: ItemData = _items[id]["data"]
			if item.stat_name != &"":
				character_stats.remove_modifier(item.stat_name, item.item_id)
			if item.secondary_stat_name != &"":
				character_stats.remove_modifier(item.secondary_stat_name, StringName(str(item.item_id) + "_penalty"))
	_items.clear()

func get_item_count(item_id: StringName) -> int:
	if _items.has(item_id):
		return _items[item_id]["count"]
	return 0

func has_item(item_id: StringName) -> bool:
	return get_item_count(item_id) > 0

func get_all_items() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for key in _items.keys():
		list.append(_items[key])
	return list

func _physics_process(delta: float) -> void:
	tick_proc_cooldowns(delta)

func tick_proc_cooldowns(delta: float) -> void:
	if _proc_cooldowns.is_empty():
		return
	var to_erase: Array[StringName] = []
	for k: StringName in _proc_cooldowns:
		_proc_cooldowns[k] -= delta
		if _proc_cooldowns[k] <= 0.0:
			to_erase.append(k)
	for k: StringName in to_erase:
		_proc_cooldowns.erase(k)

func get_proc_cooldown(id: StringName) -> float:
	return _proc_cooldowns.get(id, 0.0)

func set_proc_cooldown(id: StringName, cd: float) -> void:
	if cd <= 0.0:
		_proc_cooldowns.erase(id)
	else:
		_proc_cooldowns[id] = cd

func is_proc_on_cooldown(id: StringName) -> bool:
	return _proc_cooldowns.get(id, 0.0) > 0.0

func process_hit_procs(context: HitContext, source_entity: Node) -> void:
	for id: StringName in _items.keys():
		if not context.can_proc(id):
			continue
		if _proc_cooldowns.get(id, 0.0) > 0.0:
			continue

		var entry: Dictionary = _items[id]
		var data: ItemData = entry["data"]
		var stacks: int = entry["count"]

		for effect: ItemEffect in data.effects:
			if effect.trigger != Enums.TriggerType.ON_HIT and effect.trigger != Enums.TriggerType.ON_CRIT:
				continue
			if effect.trigger == Enums.TriggerType.ON_CRIT and not context.is_crit:
				continue

			var effective_chance: float = _calculate_chance(effect.base_chance, data.stack_type, stacks, data.hyperbolic_factor)
			effective_chance *= context.proc_coefficient

			if randf() <= effective_chance:
				effect.execute(context, stacks, source_entity)
				var effect_icd: float = effect.internal_cooldown if ("internal_cooldown" in effect and effect.internal_cooldown > 0.0) else 0.0
				var weapon_icd: float = HIGH_FREQ_WEAPON_ICDS.get(context.source_weapon_id, 0.0)
				var icd: float = maxf(effect_icd, weapon_icd)
				if icd > 0.0:
					_proc_cooldowns[id] = icd

func process_dash_procs(source_entity: Node) -> void:
	var context := HitContext.new()
	context.attacker = source_entity
	if source_entity is Node2D:
		context.hit_position = (source_entity as Node2D).global_position
	context.proc_coefficient = 1.0

	for id: StringName in _items.keys():
		if not context.can_proc(id):
			continue

		var entry: Dictionary = _items[id]
		var data: ItemData = entry["data"]
		var stacks: int = entry["count"]

		for effect: ItemEffect in data.effects:
			if effect.trigger != Enums.TriggerType.ON_DASH:
				continue

			var effective_chance: float = _calculate_chance(effect.base_chance, data.stack_type, stacks, data.hyperbolic_factor)
			if randf() <= effective_chance:
				effect.execute(context, stacks, source_entity)

func process_take_damage_procs(incoming_damage: float, source_entity: Node) -> void:
	var context := HitContext.new()
	context.victim = source_entity
	context.raw_damage = incoming_damage
	context.final_damage = incoming_damage
	if source_entity is Node2D:
		context.hit_position = (source_entity as Node2D).global_position
	context.proc_coefficient = 1.0

	for id: StringName in _items.keys():
		if not context.can_proc(id):
			continue

		var entry: Dictionary = _items[id]
		var data: ItemData = entry["data"]
		var stacks: int = entry["count"]

		for effect: ItemEffect in data.effects:
			if effect.trigger != Enums.TriggerType.ON_TAKE_DAMAGE:
				continue

			var effective_chance: float = _calculate_chance(effect.base_chance, data.stack_type, stacks, data.hyperbolic_factor)
			if randf() <= effective_chance:
				effect.execute(context, stacks, source_entity)

func process_kill_procs(target_entity: Node) -> void:
	var context := HitContext.new()
	context.victim = target_entity
	if target_entity is Node2D:
		context.hit_position = (target_entity as Node2D).global_position
	context.proc_coefficient = 1.0

	for id: StringName in _items.keys():
		if not context.can_proc(id):
			continue

		var entry: Dictionary = _items[id]
		var data: ItemData = entry["data"]
		var stacks: int = entry["count"]

		for effect: ItemEffect in data.effects:
			if effect.trigger != Enums.TriggerType.ON_KILL:
				continue

			var effective_chance: float = _calculate_chance(effect.base_chance, data.stack_type, stacks, data.hyperbolic_factor)
			if randf() <= effective_chance:
				effect.execute(context, stacks, target_entity)

func process_chest_opened_procs(source_entity: Node) -> void:
	var context := HitContext.new()
	context.attacker = source_entity
	if source_entity is Node2D:
		context.hit_position = (source_entity as Node2D).global_position
	context.proc_coefficient = 1.0

	for id: StringName in _items.keys():
		var entry: Dictionary = _items[id]
		var data: ItemData = entry["data"]
		var stacks: int = entry["count"]

		for effect: ItemEffect in data.effects:
			if effect.trigger != Enums.TriggerType.ON_CHEST_OPENED:
				continue
			effect.execute(context, stacks, source_entity)

func remove_item_stacks(item_id: StringName, count: int = 1) -> bool:
	if not _items.has(item_id):
		return false
	var current: int = _items[item_id]["count"]
	var item: ItemData = _items[item_id]["data"]
	var new_count: int = current - count

	if new_count <= 0:
		if character_stats and item.stat_name != &"":
			character_stats.remove_modifier(item.stat_name, item.item_id)
		if character_stats and item.secondary_stat_name != &"":
			character_stats.remove_modifier(item.secondary_stat_name, StringName(str(item.item_id) + "_penalty"))
		_items.erase(item_id)
	else:
		_items[item_id]["count"] = new_count
		if character_stats and item.stat_name != &"":
			var total_bonus: float = item.stat_value * float(new_count)
			var m_type: Enums.ModifierType = item.get_effective_modifier_type() if item.has_method(&"get_effective_modifier_type") else (item.modifier_type if "modifier_type" in item else (Enums.ModifierType.ADDITIVE_PERCENT if item.is_percentage else Enums.ModifierType.FLAT))
			var mod := CharacterStats.StatModifier.new(item.item_id, total_bonus, m_type, item.item_id)
			character_stats.set_or_replace_modifier(item.stat_name, mod)
		if character_stats and item.secondary_stat_name != &"":
			var total_penalty: float = item.secondary_stat_value * float(new_count)
			var sec_type: Enums.ModifierType = item.get_effective_secondary_modifier_type() if item.has_method(&"get_effective_secondary_modifier_type") else (item.secondary_modifier_type if "secondary_modifier_type" in item else (Enums.ModifierType.ADDITIVE_PERCENT if item.secondary_is_percentage else Enums.ModifierType.FLAT))
			var p_mod := CharacterStats.StatModifier.new(
				StringName(str(item.item_id) + "_penalty"),
				total_penalty,
				sec_type,
				item.item_id
			)
			character_stats.set_or_replace_modifier(item.secondary_stat_name, p_mod)

	return true

func _calculate_chance(base: float, stack_type: Enums.StackType, stacks: int, factor: float) -> float:
	match stack_type:
		Enums.StackType.LINEAR:
			return clampf(base * float(stacks), 0.0, 1.0)
		Enums.StackType.HYPERBOLIC:
			return 1.0 - (1.0 / (1.0 + factor * float(stacks)))
		Enums.StackType.EXPONENTIAL:
			return 1.0 - pow(1.0 - base, float(stacks))
		Enums.StackType.CAPPED:
			return clampf(base, 0.0, 1.0)
	return base

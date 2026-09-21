class_name InventoryComponent
extends Node

var character_stats: CharacterStats

# Almacena: item_id -> { "data": ItemData, "count": int }
var _items: Dictionary[StringName, Dictionary] = {}

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
		var mod := CharacterStats.StatModifier.new(item.item_id, total_bonus, item.is_percentage, item.item_id)
		character_stats.set_or_replace_modifier(item.stat_name, mod)

	item_added.emit(item, new_count)

func get_item_count(item_id: StringName) -> int:
	if _items.has(item_id):
		return _items[item_id]["count"]
	return 0

func get_all_items() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for key in _items.keys():
		list.append(_items[key])
	return list

func process_hit_procs(context: HitContext, source_entity: Node) -> void:
	for id: StringName in _items.keys():
		if not context.can_proc(id):
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

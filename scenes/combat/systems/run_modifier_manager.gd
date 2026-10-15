class_name RunModifierManager
extends CombatSubsystem

## RunModifierManager.gd
## Subsistema que gestiona los modificadores y efectos activos adquiridos en bifurcaciones de run.
## Monitorea duraciones por oleadas, revierte efectos caducados y acumula modificadores de estadísticas.

var active_modifiers: Array[RunForkOptionData] = []
var modifier_wave_durations: Dictionary = {} # int (instance_id) -> int (remaining_waves)
var _active_effects: Array[RunEffect] = []


func _ready() -> void:
	add_to_group(&"run_modifier_manager")


func setup_subsystem(p_context: CombatContextScript) -> void:
	super.setup_subsystem(p_context)
	if context:
		context.run_modifier_manager = self


func register_fork_choice(option: RunForkOptionData) -> void:
	if not is_instance_valid(option):
		return

	var source_path: String = option.resource_path
	if source_path.is_empty() and option.has_meta(&"source_resource_path"):
		source_path = str(option.get_meta(&"source_resource_path", ""))

	var opt_instance: RunForkOptionData = option.duplicate(false) as RunForkOptionData
	if not source_path.is_empty():
		opt_instance.set_meta(&"source_resource_path", source_path)
	opt_instance.effects = []
	for eff: RunEffect in option.effects:
		if is_instance_valid(eff):
			opt_instance.effects.append(eff.duplicate(true) as RunEffect)

	active_modifiers.append(opt_instance)

	for effect: RunEffect in opt_instance.effects:
		if not is_instance_valid(effect):
			continue

		effect.apply_effect(context)
		_active_effects.append(effect)

		if effect.duration_waves > 0:
			modifier_wave_durations[effect.get_instance_id()] = effect.duration_waves


func on_wave_completed(_wave_idx: int) -> void:
	var effects_to_check: Array[RunEffect] = _active_effects.duplicate()
	for effect: RunEffect in effects_to_check:
		if not is_instance_valid(effect):
			_active_effects.erase(effect)
			continue

		var inst_id: int = effect.get_instance_id()
		if modifier_wave_durations.has(inst_id):
			var remaining: int = int(modifier_wave_durations[inst_id]) - 1
			if remaining <= 0:
				effect.revert_effect(context)
				modifier_wave_durations.erase(inst_id)
				_active_effects.erase(effect)
			else:
				modifier_wave_durations[inst_id] = remaining

	# Limpiar opciones que ya no tienen ningún efecto activo
	for i: int in range(active_modifiers.size() - 1, -1, -1):
		var opt: RunForkOptionData = active_modifiers[i]
		if not is_instance_valid(opt):
			active_modifiers.remove_at(i)
			continue

		var has_active: bool = false
		for eff: RunEffect in opt.effects:
			if _active_effects.has(eff):
				has_active = true
				break

		if not has_active and not opt.effects.is_empty():
			active_modifiers.remove_at(i)


func on_wave_tick(delta: float, _remaining_time: float) -> void:
	for effect: RunEffect in _active_effects:
		if is_instance_valid(effect):
			effect.on_wave_tick(context, delta)


func get_total_float_modifier(stat_key: StringName, default_value: float = 1.0) -> float:
	var accumulated: float = default_value
	for effect: RunEffect in _active_effects:
		if is_instance_valid(effect):
			accumulated = effect.get_modifier_value(stat_key, accumulated)
	return accumulated


func notify_enemy_spawned(enemy: Node2D) -> void:
	if not is_instance_valid(enemy):
		return
	for effect: RunEffect in _active_effects:
		if is_instance_valid(effect):
			effect.on_enemy_spawned(enemy, context)


func serialize_active_modifiers() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for opt: RunForkOptionData in active_modifiers:
		if not is_instance_valid(opt):
			continue

		var eff_durations: Array[int] = []
		for eff: RunEffect in opt.effects:
			if is_instance_valid(eff):
				var rem: int = int(modifier_wave_durations.get(eff.get_instance_id(), eff.duration_waves))
				eff_durations.append(rem)

		var res_path: String = opt.resource_path
		if res_path.is_empty() and opt.has_meta(&"source_resource_path"):
			res_path = str(opt.get_meta(&"source_resource_path", ""))

		result.append({
			"id": String(opt.id),
			"resource_path": res_path,
			"remaining_durations": eff_durations
		})
	return result


func restore_active_modifiers(data: Array) -> void:
	for item: Variant in data:
		if not (item is Dictionary):
			continue
		var dict: Dictionary = item as Dictionary
		var res_path: String = str(dict.get("resource_path", ""))
		var opt: RunForkOptionData = null

		if not res_path.is_empty() and ResourceLoader.exists(res_path):
			var base_res: RunForkOptionData = load(res_path) as RunForkOptionData
			if base_res:
				opt = base_res.duplicate(false) as RunForkOptionData
				opt.set_meta(&"source_resource_path", res_path)
				opt.effects = []
				for eff: RunEffect in base_res.effects:
					if is_instance_valid(eff):
						opt.effects.append(eff.duplicate(true) as RunEffect)

		if not opt:
			continue

		active_modifiers.append(opt)
		var durations: Array = dict.get("remaining_durations", [])

		for i: int in range(opt.effects.size()):
			var eff: RunEffect = opt.effects[i]
			if not is_instance_valid(eff):
				continue

			eff.apply_effect(context)
			_active_effects.append(eff)

			var rem: int = eff.duration_waves
			if i < durations.size():
				rem = int(durations[i])

			if rem > 0:
				modifier_wave_durations[eff.get_instance_id()] = rem

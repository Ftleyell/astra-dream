class_name GenericPropertyRunEffect
extends RunEffect

## GenericPropertyRunEffect.gd
## Modifica de forma genérica cualquier propiedad por clave tipada en un sistema de combate.

enum Operation {
	ADD = 0,
	MULTIPLY = 1,
	SET = 2,
}

@export var system_tag: StringName = &""
@export var property_key: StringName = &""
@export var value: Variant = null
@export var operation: Operation = Operation.SET

const META_BASE_VALUES: StringName = &"_gpre_base_values"
const META_ACTIVE_EFFECTS: StringName = &"_gpre_active_effects"

var _original_value: Variant = null
var _has_original_value: bool = false


func apply_effect(context: CombatContext) -> void:
	if not context:
		return

	var target: Object = _resolve_target(context)
	if not target or not (property_key in target):
		return

	var base_map: Dictionary = {}
	if target.has_meta(META_BASE_VALUES) and target.get_meta(META_BASE_VALUES) is Dictionary:
		base_map = target.get_meta(META_BASE_VALUES) as Dictionary

	var effects_map: Dictionary = {}
	if target.has_meta(META_ACTIVE_EFFECTS) and target.get_meta(META_ACTIVE_EFFECTS) is Dictionary:
		effects_map = target.get_meta(META_ACTIVE_EFFECTS) as Dictionary

	var raw_list: Array = effects_map.get(property_key, [])
	var active_list: Array = []
	for item: Variant in raw_list:
		if is_instance_valid(item) and item is GenericPropertyRunEffect:
			active_list.append(item)

	if active_list.is_empty() or not base_map.has(property_key):
		base_map[property_key] = target.get(property_key)

	_original_value = base_map[property_key]
	_has_original_value = true

	if not active_list.has(self):
		active_list.append(self)

	effects_map[property_key] = active_list
	target.set_meta(META_BASE_VALUES, base_map)
	target.set_meta(META_ACTIVE_EFFECTS, effects_map)

	_recompute_property(target, property_key, base_map[property_key], active_list)


func revert_effect(context: CombatContext) -> void:
	if not _has_original_value or not context:
		return

	_has_original_value = false
	var target: Object = _resolve_target(context)
	if not target or not (property_key in target):
		return

	var base_map: Dictionary = {}
	if target.has_meta(META_BASE_VALUES) and target.get_meta(META_BASE_VALUES) is Dictionary:
		base_map = target.get_meta(META_BASE_VALUES) as Dictionary

	var effects_map: Dictionary = {}
	if target.has_meta(META_ACTIVE_EFFECTS) and target.get_meta(META_ACTIVE_EFFECTS) is Dictionary:
		effects_map = target.get_meta(META_ACTIVE_EFFECTS) as Dictionary

	var raw_list: Array = effects_map.get(property_key, [])
	var active_list: Array = []
	for item: Variant in raw_list:
		if is_instance_valid(item) and item is GenericPropertyRunEffect and item != self:
			active_list.append(item)

	var base_val: Variant = base_map.get(property_key, _original_value)
	if active_list.is_empty():
		target.set(property_key, base_val)
		base_map.erase(property_key)
		effects_map.erase(property_key)
	else:
		effects_map[property_key] = active_list
		_recompute_property(target, property_key, base_val, active_list)

	target.set_meta(META_BASE_VALUES, base_map)
	target.set_meta(META_ACTIVE_EFFECTS, effects_map)


static func _recompute_property(target: Object, prop: StringName, base_val: Variant, active_list: Array) -> void:
	var current_val: Variant = base_val
	for item: Variant in active_list:
		if not is_instance_valid(item) or not (item is GenericPropertyRunEffect):
			continue
		var eff: GenericPropertyRunEffect = item as GenericPropertyRunEffect
		match eff.operation:
			Operation.ADD:
				current_val = current_val + eff.value
			Operation.MULTIPLY:
				current_val = current_val * eff.value
			Operation.SET:
				current_val = eff.value
	target.set(prop, current_val)


func _resolve_target(context: CombatContext) -> Object:
	match system_tag:
		&"player":
			return context.player
		&"enemy_spawner", &"spawner":
			return context.enemy_spawner
		&"bullet_server":
			return context.bullet_server
		&"environment_host":
			return context.environment_host if context.environment_host else (context.main_game.get("environment_host") if context.main_game else null)
		&"satellite_coordinator":
			return context.satellite_coordinator if context.satellite_coordinator else (context.main_game.get("satellite_coordinator") if context.main_game else null)
		&"main_game":
			return context.main_game
		&"hud":
			return context.hud
		_:
			if context and system_tag in context:
				return context.get(system_tag) as Object
			if context and context.main_game and system_tag in context.main_game:
				return context.main_game.get(system_tag) as Object
			return null

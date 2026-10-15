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

var _original_value: Variant = null
var _has_original_value: bool = false


func apply_effect(context: CombatContext) -> void:
	if not context:
		return

	var target: Object = _resolve_target(context)
	if not target or not (property_key in target):
		return

	_original_value = target.get(property_key)
	_has_original_value = true

	match operation:
		Operation.ADD:
			target.set(property_key, target.get(property_key) + value)
		Operation.MULTIPLY:
			target.set(property_key, target.get(property_key) * value)
		Operation.SET:
			target.set(property_key, value)


func revert_effect(context: CombatContext) -> void:
	if not _has_original_value or not context:
		return

	var target: Object = _resolve_target(context)
	if target and property_key in target:
		target.set(property_key, _original_value)

	_has_original_value = false


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

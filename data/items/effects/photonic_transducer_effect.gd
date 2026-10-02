class_name PhotonicTransducerEffect
extends ItemEffect

@export var cooldown: float = 4.0
var _last_salvo_time: float = -999.0

func _init() -> void:
	trigger = Enums.TriggerType.ON_DASH
	base_chance = 1.0
	proc_coefficient = 1.0

func execute(_context: HitContext, _stack_count: int, source_entity: Node) -> void:
	if not source_entity or not is_instance_valid(source_entity):
		return
	var current_time: float = float(Time.get_ticks_msec()) / 1000.0
	if current_time - _last_salvo_time < cooldown:
		return
	_last_salvo_time = current_time

	var weapon_ctrl: Node = null
	if source_entity.has_node("WeaponController"):
		weapon_ctrl = source_entity.get_node("WeaponController")
	elif "weapon_controller" in source_entity and source_entity.weapon_controller != null:
		weapon_ctrl = source_entity.weapon_controller

	if weapon_ctrl and weapon_ctrl.has_method("trigger_instant_salvo"):
		weapon_ctrl.trigger_instant_salvo()

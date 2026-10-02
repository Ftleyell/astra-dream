class_name OverdrainModuleEffect
extends ItemEffect

func _init() -> void:
	trigger = Enums.TriggerType.ON_CRIT
	base_chance = 1.0
	proc_coefficient = 1.0

func execute(context: HitContext, _stack_count: int, source_entity: Node) -> void:
	if not context.is_crit:
		return
	var player_entity: Node = source_entity
	if not is_instance_valid(player_entity):
		return
	if player_entity.has_method("heal"):
		player_entity.heal(1.0)

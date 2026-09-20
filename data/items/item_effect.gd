class_name ItemEffect
extends Resource

@export var trigger: Enums.TriggerType = Enums.TriggerType.ON_HIT
@export_range(0.0, 1.0, 0.01) var base_chance: float = 1.0
@export_range(0.0, 1.0, 0.05) var proc_coefficient: float = 1.0

func execute(context: HitContext, stack_count: int, source_entity: Node) -> void:
	pass

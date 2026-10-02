class_name CryoCondenserEffect
extends ItemEffect

func _init() -> void:
	trigger = Enums.TriggerType.ON_HIT
	base_chance = 0.12
	proc_coefficient = 1.0

func execute(context: HitContext, stack_count: int, source_entity: Node) -> void:
	var victim := context.victim
	if not is_instance_valid(victim) or not (victim is Node2D):
		return
	if victim.has_meta("is_slowed"):
		return
	if "move_speed" in victim:
		var orig_speed: float = float(victim.move_speed)
		var slow_factor: float = clampf(0.30 + float(stack_count - 1) * 0.15, 0.2, 0.7)
		victim.move_speed = orig_speed * (1.0 - slow_factor)
		victim.set_meta("is_slowed", true)
		var orig_mod: Color = victim.modulate
		victim.modulate = Color(0.3, 0.8, 1.8, 1.0)
		var duration: float = 1.5 + float(stack_count - 1) * 0.5
		var tree := victim.get_tree()
		if tree:
			tree.create_timer(duration, false, false, true).timeout.connect(func() -> void:
				if is_instance_valid(victim):
					victim.move_speed = orig_speed
					victim.modulate = orig_mod
					victim.remove_meta("is_slowed")
			)

class_name BiomeChangeRunEffect
extends RunEffect

## BiomeChangeRunEffect.gd
## Efecto de bifurcación que conmuta la región cósmica activa en SpaceEnvironmentHost.

@export var target_region_id: StringName = &"hyperion_forge"
@export var blend_duration: float = 3.0


func apply_effect(context: CombatContext) -> void:
	if not context:
		return
	if context.environment_host and context.environment_host.has_method("change_region"):
		context.environment_host.change_region(target_region_id, blend_duration)
	elif context.main_game and "environment_host" in context.main_game and context.main_game.environment_host:
		if context.main_game.environment_host.has_method("change_region"):
			context.main_game.environment_host.change_region(target_region_id, blend_duration)

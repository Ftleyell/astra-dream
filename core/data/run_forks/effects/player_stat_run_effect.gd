class_name PlayerStatRunEffect
extends RunEffect

## PlayerStatRunEffect.gd
## Aplica bonificaciones planas y/o porcentuales a estadísticas del jugador vía CharacterStats.

@export var stat_key: StringName = &"move_speed"
@export var flat_bonus: float = 0.0
@export var multiplier_bonus: float = 0.0


func apply_effect(context: CombatContext) -> void:
	if not context or not is_instance_valid(context.player):
		return
	if not ("stats" in context.player) or not context.player.stats:
		return

	var stats: CharacterStats = context.player.stats as CharacterStats
	if not is_instance_valid(stats):
		return

	if flat_bonus != 0.0:
		stats.add_modifier(stat_key, CharacterStats.StatModifier.new(_get_flat_mod_id(), flat_bonus, false, self))
	if multiplier_bonus != 0.0:
		stats.add_modifier(stat_key, CharacterStats.StatModifier.new(_get_mult_mod_id(), multiplier_bonus, true, self))


func revert_effect(context: CombatContext) -> void:
	if not context or not is_instance_valid(context.player):
		return
	if not ("stats" in context.player) or not context.player.stats:
		return

	var stats: CharacterStats = context.player.stats as CharacterStats
	if not is_instance_valid(stats):
		return

	stats.remove_modifier(stat_key, _get_flat_mod_id())
	stats.remove_modifier(stat_key, _get_mult_mod_id())


func get_modifier_value(p_stat_key: StringName, base_val: float) -> float:
	if p_stat_key == stat_key:
		return (base_val + flat_bonus) * (1.0 + multiplier_bonus)
	return base_val


func _get_flat_mod_id() -> StringName:
	return StringName("fork_flat_%d_%s" % [get_instance_id(), stat_key])


func _get_mult_mod_id() -> StringName:
	return StringName("fork_mult_%d_%s" % [get_instance_id(), stat_key])

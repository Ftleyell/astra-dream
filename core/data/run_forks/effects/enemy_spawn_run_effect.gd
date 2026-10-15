class_name EnemySpawnRunEffect
extends RunEffect

## EnemySpawnRunEffect.gd
## Modifica spawn rate, vida de enemigos y recompensas de oro/créditos en la run.

@export var spawn_multiplier: float = 1.0
@export var health_multiplier: float = 1.0
@export var gold_multiplier: float = 1.0


func get_modifier_value(stat_key: StringName, base_val: float) -> float:
	match stat_key:
		&"spawn_multiplier", &"enemy_spawn_rate":
			return base_val * spawn_multiplier
		&"health_multiplier", &"enemy_health":
			return base_val * health_multiplier
		&"gold_multiplier", &"enemy_gold":
			return base_val * gold_multiplier
		_:
			return base_val


func on_enemy_spawned(enemy: Node2D, _context: CombatContext) -> void:
	if not is_instance_valid(enemy):
		return

	if health_multiplier != 1.0 and not enemy.has_meta(&"fork_health_applied"):
		enemy.set_meta(&"fork_health_applied", true)
		if "max_health" in enemy:
			enemy.max_health = enemy.max_health * health_multiplier
		if "current_health" in enemy:
			enemy.current_health = enemy.current_health * health_multiplier
		elif "health" in enemy:
			enemy.health = enemy.health * health_multiplier

	if gold_multiplier != 1.0 and not enemy.has_meta(&"fork_gold_applied"):
		enemy.set_meta(&"fork_gold_applied", true)
		if "credits_reward" in enemy:
			enemy.credits_reward = int(round(float(enemy.credits_reward) * gold_multiplier))
		elif "gold_reward" in enemy:
			enemy.gold_reward = int(round(float(enemy.gold_reward) * gold_multiplier))

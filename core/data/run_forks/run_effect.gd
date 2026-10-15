class_name RunEffect
extends Resource

## RunEffect.gd
## Clase base abstracta para efectos polimórficos de bifurcaciones de run (In-Run Decisions).
## Aplica el patrón Command con acceso inyectable a CombatContext.

@export var effect_name: String = ""
## Duración en oleadas (-1 = permanente durante toda la run, > 0 = expira tras N oleadas).
@export var duration_waves: int = -1


func apply_effect(_context: CombatContext) -> void:
	pass


func revert_effect(_context: CombatContext) -> void:
	pass


func on_wave_tick(_context: CombatContext, _delta: float) -> void:
	pass


func on_enemy_spawned(_enemy: Node2D, _context: CombatContext) -> void:
	pass


func get_modifier_value(_stat_key: StringName, base_val: float) -> float:
	return base_val

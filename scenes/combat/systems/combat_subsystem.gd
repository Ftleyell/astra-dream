class_name CombatSubsystem
extends Node

## CombatSubsystem.gd
## Contrato e interfaz base para todos los subsistemas y mecánicas de combate en Astra Dream.
## Permite añadir mecánicas como nodos autónomos 'Plug & Play' sin modificar MainGame.

const CombatContextScript = preload("res://scenes/combat/systems/combat_context.gd")

var context: CombatContextScript = null


func setup_subsystem(p_context: CombatContextScript) -> void:
	context = p_context


func on_wave_started(_wave_idx: int) -> void:
	pass


func on_wave_tick(_delta: float, _remaining_time: float) -> void:
	pass


func on_wave_completed(_wave_idx: int) -> void:
	pass


func on_combat_ended() -> void:
	pass


func is_blocking_combat() -> bool:
	return false

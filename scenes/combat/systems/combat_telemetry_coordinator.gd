class_name CombatTelemetryCoordinator
extends Node

## CombatTelemetryCoordinator.gd
## Coordinador modular de telemetría y métricas activas durante el combate.
## Realiza el seguimiento de tiempo de vuelo, recuento de bajas, jefes derrotados,
## chequeo de desbloqueos por supervivencia (ej. Cosmo) y delega la construcción del
## resumen final en CombatTelemetryRecorder.

signal survival_milestone_reached(seconds: float)

const CombatTelemetryRecorderScript = preload("res://scenes/combat/systems/combat_telemetry_recorder.gd")

var run_time_elapsed: float = 0.0
var enemies_killed_count: int = 0
var bosses_defeated_count: int = 0

var _main_game: Node2D = null
var _hud: CanvasLayer = null

func setup(p_main_game: Node2D, p_hud: CanvasLayer = null) -> void:
	_main_game = p_main_game
	_hud = p_hud

func tick(delta: float) -> void:
	run_time_elapsed += delta
	_check_survival_milestones()

func record_enemy_killed(_enemy_type: String = "") -> void:
	enemies_killed_count += 1

func record_boss_defeated(_boss_id: String = "") -> void:
	bosses_defeated_count += 1

func reset_counters() -> void:
	run_time_elapsed = 0.0
	enemies_killed_count = 0
	bosses_defeated_count = 0

func get_run_metrics() -> Dictionary:
	return {
		"run_time_elapsed": run_time_elapsed,
		"enemies_killed_count": enemies_killed_count,
		"bosses_defeated_count": bosses_defeated_count
	}

func restore_metrics(p_time: float, p_enemies: int, p_bosses: int) -> void:
	run_time_elapsed = p_time
	enemies_killed_count = p_enemies
	bosses_defeated_count = p_bosses

func build_end_of_run_data(is_victory: bool, route: String = "neutral") -> Dictionary:
	if not _main_game:
		return {}
	return CombatTelemetryRecorderScript.build_end_of_run_data(_main_game, is_victory, route)

func _check_survival_milestones() -> void:
	# Chequeo de desbloqueo de Mascota Secreta Cosmo (10 Minutos = 600s de supervivencia)
	if run_time_elapsed >= 600.0 and not SaveManager.is_pet_unlocked(&"cosmo"):
		var newly_unlocked: bool = SaveManager.unlock_pet(&"cosmo")
		if newly_unlocked:
			var target_hud = _hud if is_instance_valid(_hud) else (_main_game.get("hud") if _main_game else null)
			if target_hud and target_hud.has_method("show_character_unlock_banner"):
				target_hud.show_character_unlock_banner(&"cosmo", "¡NUEVA MASCOTA DESBLOQUEADA: COSMO!", "Has sobrevivido 10 minutos. El Gatito Astral se ha unido a tu flota.")
			survival_milestone_reached.emit(600.0)

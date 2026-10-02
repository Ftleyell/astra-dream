class_name BossRivalDirector
extends Node

## Sub-director encargado de la orquestación, escalado adaptativo de vida y despacho
## de encuentros contra Jefes de Dominio, Astra Prime y Pilotos Rivales.

signal boss_spawn_requested(scene: PackedScene, target_pos: Vector2, adaptive_hp: float)
signal rival_spawn_requested(rival_id: StringName, spawn_pos: Vector2)
signal major_encounter_started(encounter_type: String, entity_name: String)
signal major_encounter_ended(encounter_type: String, entity_name: String)

@export var config: EncounterTimelineConfig = null

var current_boss: Node2D = null
var current_rival: Node2D = null

func initialize(timeline_cfg: EncounterTimelineConfig) -> void:
	config = timeline_cfg

func calculate_adaptive_hp(base_hp: float, wave_num: int, p_dmg: float, p_spd: float) -> float:
	var wave_step: float = config.wave_scaling_hp_step if config else 0.08
	var floor_val: float = config.adaptive_dps_floor if config else 0.85
	var ceil_val: float = config.adaptive_dps_ceiling if config else 2.50
	var base_mult: float = config.base_boss_hp_multiplier if config else 1.0

	var wave_factor: float = 1.0 + float(wave_num) * wave_step
	var p_dps_factor: float = clampf((p_dmg / 20.0) * (p_spd / 1.0), floor_val, ceil_val)
	return base_hp * wave_factor * p_dps_factor * base_mult

func should_spawn_boss(wave_num: int) -> bool:
	return config.is_boss_wave(wave_num) if config else false

func should_spawn_rival(wave_num: int) -> bool:
	return config.is_rival_wave(wave_num) if config else false

func get_boss_scene_for_wave(wave_num: int) -> PackedScene:
	return config.get_boss_scene_for_wave(wave_num) if config else null

func has_active_major_encounter() -> bool:
	var boss_valid: bool = is_instance_valid(current_boss) and not current_boss.is_queued_for_deletion()
	var rival_valid: bool = is_instance_valid(current_rival) and not current_rival.is_queued_for_deletion()
	return boss_valid or rival_valid

func clear_encounters() -> void:
	if is_instance_valid(current_boss):
		current_boss.queue_free()
		current_boss = null
	if is_instance_valid(current_rival):
		current_rival.queue_free()
		current_rival = null

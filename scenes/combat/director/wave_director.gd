class_name WaveDirector
extends Node

## Sub-director encargado de la cadencia de oleadas, temporizadores de combate y sincronización de rondas.

signal wave_started(wave_num: int)
signal wave_ended(wave_num: int)
signal wave_time_updated(time_left: float, total_time: float)
signal pre_round_ended()

@export var config: EncounterTimelineConfig = null

var current_wave: int = 1
var is_pre_round: bool = true
var pre_round_timer: float = 30.0
var wave_timer: float = 30.0
var is_wave_paused: bool = false

func initialize(timeline_cfg: EncounterTimelineConfig) -> void:
	config = timeline_cfg
	if config:
		pre_round_timer = config.pre_round_duration
		wave_timer = config.wave_duration
	else:
		pre_round_timer = 30.0
		wave_timer = 30.0
	current_wave = 1
	is_pre_round = true

func update_wave_timeline(delta: float, is_combat_active: bool) -> void:
	if is_wave_paused:
		return

	if is_pre_round:
		pre_round_timer -= delta
		wave_time_updated.emit(pre_round_timer, config.pre_round_duration if config else 30.0)
		if pre_round_timer <= 0.0:
			is_pre_round = false
			pre_round_timer = 0.0
			pre_round_ended.emit()
			start_wave(current_wave)
		return

	if not is_combat_active:
		wave_timer -= delta
		var total_dur: float = config.wave_duration if config else 30.0
		wave_time_updated.emit(wave_timer, total_dur)
		if wave_timer <= 0.0:
			advance_to_next_wave()

func start_wave(wave_num: int) -> void:
	current_wave = wave_num
	wave_timer = config.wave_duration if config else 30.0
	wave_started.emit(current_wave)

func advance_to_next_wave() -> void:
	wave_ended.emit(current_wave)
	current_wave += 1
	var total_w: int = config.total_waves if config else 16
	if current_wave > total_w:
		current_wave = total_w
	start_wave(current_wave)

func set_wave(wave_num: int) -> void:
	is_pre_round = false
	pre_round_timer = 0.0
	current_wave = wave_num
	wave_timer = config.wave_duration if config else 30.0
	wave_started.emit(current_wave)

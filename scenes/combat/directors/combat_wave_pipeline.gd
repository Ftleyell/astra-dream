class_name CombatWavePipeline
extends Node

## CombatWavePipeline.gd
## Pipeline modular y orquestador del ciclo de vida de oleadas en combate.
## Desacopla de MainGame el cronometraje de pre-ronda, avance de oleadas,
## congelamiento ante jefes y notificación a subsistemas registrados.

const CombatContextScript = preload("res://scenes/combat/systems/combat_context.gd")
const CombatSubsystemScript = preload("res://scenes/combat/systems/combat_subsystem.gd")

signal pre_round_started(duration: float)
signal pre_round_ended()
signal wave_started(wave_idx: int)
signal wave_completed(wave_idx: int)
signal wave_completed_drain_requested(wave_idx: int)

const DEFAULT_WAVE_DURATION: float = 30.0
const DEFAULT_PRE_ROUND_DURATION: float = 30.0

var context: CombatContextScript = null
var subsystems: Array[CombatSubsystemScript] = []
var fork_director: Node = null


var is_pre_round: bool = true
var pre_round_timer: float = DEFAULT_PRE_ROUND_DURATION
var wave_timer: float = DEFAULT_WAVE_DURATION
var wave_duration: float = DEFAULT_WAVE_DURATION
var current_wave: int = 1

# Callables para acciones del juego principal
var on_wave_advance_callable: Callable = Callable()
var on_hud_update_callable: Callable = Callable()


func setup_pipeline(
	p_context: CombatContextScript,
	p_on_wave_advance: Callable,
	p_on_hud_update: Callable = Callable()
) -> void:
	context = p_context
	on_wave_advance_callable = p_on_wave_advance
	on_hud_update_callable = p_on_hud_update
	if context:
		wave_duration = context.wave_duration
		wave_timer = wave_duration
		current_wave = context.current_wave
		for sub: CombatSubsystemScript in subsystems:
			if is_instance_valid(sub):
				sub.setup_subsystem(context)


func register_subsystem(subsystem: CombatSubsystemScript) -> void:
	if subsystem and not subsystems.has(subsystem):
		subsystems.append(subsystem)
		if subsystem.has_method("start_wave_drain"):
			_bind_fork_director(subsystem)
		if context:
			subsystem.setup_subsystem(context)


func _bind_fork_director(director: Node) -> void:
	fork_director = director
	if director.has_signal("fork_selection_completed"):
		if not director.fork_selection_completed.is_connected(_on_fork_selection_completed):
			director.fork_selection_completed.connect(_on_fork_selection_completed)


func _on_fork_selection_completed(_chosen_option: Variant) -> void:
	_complete_and_advance_wave()


func _get_fork_director() -> Node:
	if fork_director and is_instance_valid(fork_director):
		return fork_director
	if context and context.fork_director and is_instance_valid(context.fork_director):
		_bind_fork_director(context.fork_director)
		return context.fork_director
	for sub: CombatSubsystemScript in subsystems:
		if is_instance_valid(sub) and sub.has_method("start_wave_drain"):
			_bind_fork_director(sub)
			return sub
	return null



func register_child_subsystems(root_node: Node) -> void:
	if not root_node or not is_instance_valid(root_node):
		return
	for child: Node in root_node.get_children():
		if child is CombatSubsystemScript:
			register_subsystem(child as CombatSubsystemScript)


func unregister_subsystem(subsystem: CombatSubsystemScript) -> void:
	subsystems.erase(subsystem)


func is_subsystem_blocking() -> bool:
	for sub: CombatSubsystemScript in subsystems:
		if is_instance_valid(sub) and sub.is_blocking_combat():
			return true
	return false


func tick(delta: float, is_major_combat_active: bool = false) -> void:
	if is_pre_round:
		_tick_pre_round(delta)
	else:
		_tick_active_wave(delta, is_major_combat_active)


func _tick_pre_round(delta: float) -> void:
	pre_round_timer -= delta
	if on_hud_update_callable.is_valid():
		on_hud_update_callable.call(true, current_wave, pre_round_timer)

	if pre_round_timer <= 0.0:
		is_pre_round = false
		current_wave = 1
		wave_timer = wave_duration
		if context:
			context.current_wave = 1
			context.wave_timer = wave_timer
			context.notify_wave_started(1)
		
		pre_round_ended.emit()
		wave_started.emit(1)
		
		for sub: CombatSubsystemScript in subsystems:
			if is_instance_valid(sub):
				sub.on_wave_started(1)

		if on_wave_advance_callable.is_valid():
			on_wave_advance_callable.call(1)


func _tick_active_wave(delta: float, is_major_combat_active: bool) -> void:
	# El tiempo de oleada se congela si hay un combate mayor (Jefe/Rival) o un subsistema bloqueante
	if not is_major_combat_active and not is_subsystem_blocking():
		wave_timer -= delta
		if context:
			context.wave_timer = wave_timer

		for sub: CombatSubsystemScript in subsystems:
			if is_instance_valid(sub):
				sub.on_wave_tick(delta, wave_timer)

		if wave_timer <= 0.0:
			wave_timer = 0.0
			var director: Node = _get_fork_director()
			if director != null and director.has_method("start_wave_drain"):
				if not director.is_active():
					wave_completed_drain_requested.emit(current_wave)
					director.start_wave_drain()
			else:
				_complete_and_advance_wave()


	if on_hud_update_callable.is_valid():
		on_hud_update_callable.call(false, current_wave, wave_timer)


func _complete_and_advance_wave() -> void:
	wave_completed.emit(current_wave)
	if context:
		context.notify_wave_completed(current_wave)

	for sub: CombatSubsystemScript in subsystems:
		if is_instance_valid(sub):
			sub.on_wave_completed(current_wave)

	current_wave += 1
	wave_timer = wave_duration
	if context:
		context.current_wave = current_wave
		context.wave_timer = wave_timer
		context.notify_wave_started(current_wave)

	wave_started.emit(current_wave)

	for sub: CombatSubsystemScript in subsystems:
		if is_instance_valid(sub):
			sub.on_wave_started(current_wave)

	if on_wave_advance_callable.is_valid():
		on_wave_advance_callable.call(current_wave)


func set_wave_direct(new_wave: int) -> void:
	current_wave = new_wave
	wave_timer = wave_duration
	is_pre_round = false
	if context:
		context.current_wave = current_wave
		context.wave_timer = wave_timer
		context.notify_wave_started(current_wave)

class_name AudioDuckManager
extends Node

@export var music_bus_name: String = "Music"
@export var normal_cutoff: float = 20500.0
@export var ducked_cutoff: float = 900.0
@export var normal_volume_db: float = 0.0
@export var ducked_volume_db: float = -4.0
@export var transition_in_time: float = 0.35
@export var transition_out_time: float = 0.45

var _music_bus_idx: int = -1
var _low_pass_filter: AudioEffectLowPassFilter = null
var _current_tween: Tween = null

func _ready() -> void:
	_music_bus_idx = AudioServer.get_bus_index(music_bus_name)
	if _music_bus_idx == -1:
		# Si no existe el bus Music, crearlo o usar Master como fallback
		_music_bus_idx = 0

	for i in range(AudioServer.get_bus_effect_count(_music_bus_idx)):
		var effect: AudioEffect = AudioServer.get_bus_effect(_music_bus_idx, i)
		if effect is AudioEffectLowPassFilter:
			_low_pass_filter = effect
			break

	if _low_pass_filter == null:
		_low_pass_filter = AudioEffectLowPassFilter.new()
		_low_pass_filter.cutoff_hz = normal_cutoff
		_low_pass_filter.resonance = 0.7
		AudioServer.add_bus_effect(_music_bus_idx, _low_pass_filter)

func duck_music(enable: bool) -> void:
	if _low_pass_filter == null:
		return

	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()

	_current_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	var target_cutoff := ducked_cutoff if enable else normal_cutoff
	var target_vol := ducked_volume_db if enable else normal_volume_db
	var duration := transition_in_time if enable else transition_out_time

	_current_tween.tween_method(
		func(val: float): _low_pass_filter.cutoff_hz = val,
		_low_pass_filter.cutoff_hz,
		target_cutoff,
		duration
	)

	var current_vol: float = AudioServer.get_bus_volume_db(_music_bus_idx)
	_current_tween.tween_method(
		func(val: float): AudioServer.set_bus_volume_db(_music_bus_idx, val),
		current_vol,
		target_vol,
		duration
	)

func reset_immediately() -> void:
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()
	if _low_pass_filter:
		_low_pass_filter.cutoff_hz = normal_cutoff
	AudioServer.set_bus_volume_db(_music_bus_idx, normal_volume_db)

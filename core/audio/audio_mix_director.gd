class_name AudioMixDirector
extends Node
## Director DSP reactivo: modula LowPass en Pausa / Slow-Mo / Tactical Focus
## y aplica ducking temporal sobre SFX_Combat ante eventos críticos.

const NORMAL_CUTOFF_HZ: float = 20500.0
const PAUSE_MUSIC_CUTOFF_HZ: float = 1400.0
const PAUSE_AMBIENCE_CUTOFF_HZ: float = 1800.0
const FOCUS_MUSIC_CUTOFF_HZ: float = 4200.0
const FOCUS_COMBAT_CUTOFF_HZ: float = 2200.0
const FOCUS_COMBAT_ATTENUATION_DB: float = -5.0
const PAUSE_AMBIENCE_ATTENUATION_DB: float = -4.0

var _pause_muffle_active: bool = false
var _tactical_focus_target: float = 0.0
var _current_music_cutoff: float = NORMAL_CUTOFF_HZ
var _current_ambience_cutoff: float = NORMAL_CUTOFF_HZ
var _current_combat_cutoff: float = NORMAL_CUTOFF_HZ
var _current_combat_vol_db: float = 0.0
var _current_ambience_duck_db: float = 0.0

var _duck_peak_db: float = 0.0
var _duck_timer: float = 0.0
var _duck_duration: float = 0.25


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if PauseArbitrator != null and PauseArbitrator.has_signal(&"pause_state_changed"):
		if not PauseArbitrator.pause_state_changed.is_connected(_on_pause_state_changed):
			PauseArbitrator.pause_state_changed.connect(_on_pause_state_changed)
		_pause_muffle_active = PauseArbitrator.is_paused()


func _process(delta: float) -> void:
	var unscaled_delta: float = delta
	if Engine.time_scale > 0.01 and Engine.time_scale < 0.99:
		unscaled_delta = clampf(delta / Engine.time_scale, 0.0, 0.05)

	var slowmo_intensity: float = 0.0
	if Engine.time_scale < 0.85:
		slowmo_intensity = clampf((0.85 - Engine.time_scale) / 0.55, 0.0, 1.0)
	var effective_focus: float = maxf(_tactical_focus_target, slowmo_intensity)

	var target_music_cutoff: float = NORMAL_CUTOFF_HZ
	if _pause_muffle_active:
		target_music_cutoff = PAUSE_MUSIC_CUTOFF_HZ
	elif effective_focus > 0.01:
		target_music_cutoff = lerpf(NORMAL_CUTOFF_HZ, FOCUS_MUSIC_CUTOFF_HZ, effective_focus)

	var target_ambience_cutoff: float = PAUSE_AMBIENCE_CUTOFF_HZ if _pause_muffle_active else NORMAL_CUTOFF_HZ
	var target_ambience_duck: float = PAUSE_AMBIENCE_ATTENUATION_DB if _pause_muffle_active else 0.0

	var target_combat_cutoff: float = lerpf(NORMAL_CUTOFF_HZ, FOCUS_COMBAT_CUTOFF_HZ, effective_focus)
	var transient_duck_db: float = 0.0
	if _duck_timer > 0.0:
		_duck_timer = maxf(0.0, _duck_timer - unscaled_delta)
		var norm_rem: float = _duck_timer / maxf(0.01, _duck_duration)
		transient_duck_db = -_duck_peak_db * norm_rem
	var target_combat_vol_db: float = (FOCUS_COMBAT_ATTENUATION_DB * effective_focus) + transient_duck_db

	var smooth: float = clampf(unscaled_delta * 12.0, 0.0, 1.0)
	_current_music_cutoff = lerpf(_current_music_cutoff, target_music_cutoff, smooth)
	_current_ambience_cutoff = lerpf(_current_ambience_cutoff, target_ambience_cutoff, smooth)
	_current_combat_cutoff = lerpf(_current_combat_cutoff, target_combat_cutoff, smooth)
	_current_ambience_duck_db = lerpf(_current_ambience_duck_db, target_ambience_duck, smooth)

	var duck_attack_smooth: float = clampf(unscaled_delta * (28.0 if target_combat_vol_db < _current_combat_vol_db else 10.0), 0.0, 1.0)
	_current_combat_vol_db = lerpf(_current_combat_vol_db, target_combat_vol_db, duck_attack_smooth)

	_apply_lowpass(&"Music", _current_music_cutoff)
	_apply_lowpass(&"Ambience", _current_ambience_cutoff)
	_apply_lowpass(&"SFX_Combat", _current_combat_cutoff)
	_apply_bus_relative_volume(&"SFX_Combat", _current_combat_vol_db)


func set_pause_muffle(active: bool) -> void:
	_pause_muffle_active = active


func set_tactical_focus(intensity: float) -> void:
	_tactical_focus_target = clampf(intensity, 0.0, 1.0)


func trigger_combat_duck(duck_db: float, duration_sec: float = 0.25) -> void:
	if duck_db <= 0.0:
		return
	_duck_peak_db = maxf(_duck_peak_db * (_duck_timer / maxf(0.01, _duck_duration)), duck_db)
	_duck_duration = maxf(0.05, duration_sec)
	_duck_timer = _duck_duration


func get_current_music_cutoff_hz() -> float:
	return _current_music_cutoff


func get_current_combat_cutoff_hz() -> float:
	return _current_combat_cutoff


func get_current_combat_duck_db() -> float:
	return _current_combat_vol_db


func _on_pause_state_changed(is_paused: bool, _active_reasons: Array[StringName]) -> void:
	set_pause_muffle(is_paused)


func _apply_lowpass(bus_name: StringName, cutoff_hz: float) -> void:
	var bus_idx: int = AudioServer.get_bus_index(String(bus_name))
	if bus_idx < 0:
		return
	var fx_count: int = AudioServer.get_bus_effect_count(bus_idx)
	for i: int in range(fx_count):
		var fx: AudioEffect = AudioServer.get_bus_effect(bus_idx, i)
		if fx is AudioEffectLowPassFilter:
			(fx as AudioEffectLowPassFilter).cutoff_hz = clampf(cutoff_hz, 400.0, 20500.0)
			break


func _apply_bus_relative_volume(bus_name: StringName, db_val: float) -> void:
	var bus_idx: int = AudioServer.get_bus_index(String(bus_name))
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, clampf(db_val, -24.0, 0.0))

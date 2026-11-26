class_name SfxAuditionEngine
extends Node
## Motor aislado de audición para SfxLab: preview directo, A/B con producción,
## simulador de ráfagas de combate, arpegio EXP y cama de música opcional.

signal playhead_updated(ratio: float)
signal playback_event(label: String)
signal tour_step_changed(slot_key: String, step_idx: int, total: int)
signal tour_finished()

const POOL_SIZE: int = 16
const MUSIC_PATHS: Dictionary = {
	"combat": "res://assets/audio/music_combat.wav",
	"menu": "res://assets/audio/music_menu.wav",
}
const EXP_COMBO_STEPS: Array[float] = [
	0.88, 0.94, 1.00, 1.06, 1.12, 1.18, 1.25, 1.32, 1.40, 1.48, 1.56, 1.65
]

var _sfx_pool: Array[AudioStreamPlayer] = []
var _bgm_player: AudioStreamPlayer = null
var _primary_player: AudioStreamPlayer = null
var _primary_duration: float = 0.0

var _burst_active: bool = false
var _burst_streams: Array[AudioStream] = []
var _burst_rate_hz: float = 4.0
var _burst_pitch_base: float = 1.0
var _burst_pitch_jitter: float = 0.08
var _burst_volume_db: float = 0.0
var _burst_use_exp_combo: bool = false
var _burst_accum: float = 0.0
var _burst_last_idx: int = -1
var _burst_combo_step: int = 0

var _tour_active: bool = false
var _tour_steps: Array[Dictionary] = []
var _tour_loader: Callable = Callable()
var _tour_current_stream: AudioStream = null
var _tour_current_layer2: AudioStream = null
var _tour_idx: int = 0
var _tour_rep: int = 0
var _tour_timer: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i: int in range(POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.name = "AuditionVoice_%d" % i
		p.bus = &"SFX"
		add_child(p)
		_sfx_pool.append(p)

	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.name = "AuditionBGM"
	_bgm_player.bus = &"Music"
	_bgm_player.volume_db = -14.0
	add_child(_bgm_player)


func _process(delta: float) -> void:
	var safe_delta: float = minf(delta, 0.05)
	if _primary_player != null:
		if _primary_player.playing and _primary_duration > 0.0:
			var ratio: float = clampf(_primary_player.get_playback_position() / _primary_duration, 0.0, 1.0)
			playhead_updated.emit(ratio)
		else:
			_primary_player = null
			playhead_updated.emit(-1.0)

	if _burst_active and not _burst_streams.is_empty():
		var interval: float = 1.0 / maxf(0.25, _burst_rate_hz)
		_burst_accum += safe_delta
		if _burst_accum >= interval:
			_burst_accum -= interval
			_fire_burst_step()

	if _tour_active:
		_process_tour(safe_delta)


func is_burst_active() -> bool:
	return _burst_active


func stop_sfx_voices() -> void:
	_primary_player = null
	playhead_updated.emit(-1.0)
	for p: AudioStreamPlayer in _sfx_pool:
		p.stop()


func play_stream_once(
	stream: AudioStream,
	pitch_scale: float = 1.0,
	volume_db: float = 0.0,
	track_playhead: bool = true,
	stop_previous: bool = true
) -> AudioStreamPlayer:
	if stream == null:
		return null
	if stop_previous:
		stop_sfx_voices()
	var p: AudioStreamPlayer = _acquire_player()
	p.stream = stream
	p.pitch_scale = clampf(pitch_scale, 0.2, 3.5)
	p.volume_db = clampf(volume_db, -40.0, 12.0)
	p.play()
	if track_playhead:
		_primary_player = p
		_primary_duration = maxf(0.01, stream.get_length())
	return p


func play_production_slot(slot_key: String) -> bool:
	stop_burst()
	stop_tour()
	var am: Node = AudioManager
	if am == null:
		return false
	if am.sfx_streams.has(slot_key):
		var stream: AudioStream = am.sfx_streams[slot_key] as AudioStream
		if stream != null:
			play_stream_once(stream, 1.0, 0.0, true, true)
			playback_event.emit("Prod [A]: %s" % slot_key)
			return true
	return false


func start_burst(
	streams: Array[AudioStream],
	rate_hz: float,
	pitch_base: float,
	pitch_jitter: float,
	volume_db: float,
	use_exp_combo: bool = false
) -> void:
	_burst_streams.clear()
	for s: AudioStream in streams:
		if s != null:
			_burst_streams.append(s)
	if _burst_streams.is_empty():
		_burst_active = false
		return
	_burst_rate_hz = clampf(rate_hz, 0.5, 16.0)
	_burst_pitch_base = clampf(pitch_base, 0.4, 2.2)
	_burst_pitch_jitter = clampf(pitch_jitter, 0.0, 0.4)
	_burst_volume_db = clampf(volume_db, -30.0, 12.0)
	_burst_use_exp_combo = use_exp_combo
	_burst_accum = 1.0 / maxf(0.25, _burst_rate_hz)
	_burst_last_idx = -1
	_burst_combo_step = 0
	_burst_active = true
	playback_event.emit("Burst activo (%.1f/s)" % _burst_rate_hz)


func stop_burst() -> void:
	if _burst_active:
		_burst_active = false
		playback_event.emit("Burst detenido")


func stop_all() -> void:
	_burst_active = false
	stop_tour()
	stop_sfx_voices()
	if _bgm_player != null:
		_bgm_player.stop()


func is_tour_active() -> bool:
	return _tour_active


func start_tour(steps: Array[Dictionary], stream_loader: Callable = Callable()) -> void:
	stop_burst()
	stop_sfx_voices()
	_tour_steps = steps.duplicate()
	_tour_loader = stream_loader
	if _tour_steps.is_empty():
		_tour_active = false
		return
	_tour_idx = 0
	_tour_rep = 0
	_tour_current_stream = null
	_tour_current_layer2 = null
	_tour_timer = 0.05
	_tour_active = true


func stop_tour() -> void:
	if _tour_active:
		_tour_active = false
		_tour_steps.clear()
		_tour_loader = Callable()
		_tour_current_stream = null
		_tour_current_layer2 = null
		stop_sfx_voices()
		tour_finished.emit()


func _process_tour(delta: float) -> void:
	_tour_timer -= delta
	if _tour_timer > 0.0:
		return
	_fire_tour_step()


func _fire_tour_step() -> void:
	if _tour_idx >= _tour_steps.size():
		stop_tour()
		playback_event.emit("Tour del perfil finalizado.")
		return
	var step: Dictionary = _tour_steps[_tour_idx]
	var slot_key: String = str(step.get("slot_key", ""))
	var pitch: float = float(step.get("pitch", 1.0))
	var vol_db: float = float(step.get("volume_db", 0.0))
	var reps: int = maxi(1, int(step.get("repeat_count", 1)))
	var use_combo: bool = bool(step.get("use_exp_combo", false))
	var gap: float = float(step.get("gap_sec", 0.35))

	if _tour_rep == 0:
		stop_sfx_voices()
		tour_step_changed.emit(slot_key, _tour_idx + 1, _tour_steps.size())
		_tour_current_stream = step.get("stream", null) as AudioStream
		_tour_current_layer2 = step.get("layer2", null) as AudioStream
		if _tour_current_stream == null and _tour_loader.is_valid():
			var loaded_v: Variant = _tour_loader.call(step)
			if loaded_v is Dictionary:
				var loaded: Dictionary = loaded_v as Dictionary
				_tour_current_stream = loaded.get("stream", null) as AudioStream
				if _tour_current_layer2 == null:
					_tour_current_layer2 = loaded.get("layer2", null) as AudioStream
		if _tour_current_stream == null:
			_tour_current_stream = step.get("fallback_stream", null) as AudioStream

	if _tour_current_stream != null:
		var p_use: float = pitch
		if use_combo:
			p_use = pitch * EXP_COMBO_STEPS[_tour_rep % EXP_COMBO_STEPS.size()]
		play_stream_once(_tour_current_stream, p_use, vol_db, true, false)
		if _tour_current_layer2 != null and _tour_rep == 0:
			play_stream_once(_tour_current_layer2, pitch, vol_db - 3.0, false, false)

	_tour_rep += 1
	if _tour_rep >= reps:
		var clip_len: float = _tour_current_stream.get_length() if _tour_current_stream != null else 0.4
		_tour_idx += 1
		_tour_rep = 0
		_tour_current_stream = null
		_tour_current_layer2 = null
		_tour_timer = clampf(clip_len, 0.35, 1.25) + gap
	else:
		_tour_timer = 0.14 if use_combo else 0.18


func set_bgm_mode(mode: String) -> void:
	if _bgm_player == null:
		return
	if mode == "off" or not MUSIC_PATHS.has(mode):
		_bgm_player.stop()
		return
	var path: String = str(MUSIC_PATHS[mode])
	if not ResourceLoader.exists(path):
		_bgm_player.stop()
		return
	var stream: AudioStream = load(path) as AudioStream
	if stream == null:
		_bgm_player.stop()
		return
	if stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	_bgm_player.stream = stream
	_bgm_player.play()


func _fire_burst_step() -> void:
	if _burst_streams.is_empty():
		return
	var idx: int = 0
	if _burst_streams.size() > 1:
		idx = randi_range(0, _burst_streams.size() - 1)
		if idx == _burst_last_idx:
			idx = (idx + 1) % _burst_streams.size()
	_burst_last_idx = idx
	var stream: AudioStream = _burst_streams[idx]

	var pitch: float = _burst_pitch_base
	if _burst_use_exp_combo:
		var mult: float = EXP_COMBO_STEPS[_burst_combo_step % EXP_COMBO_STEPS.size()]
		_burst_combo_step += 1
		pitch = _burst_pitch_base * mult * randf_range(0.98, 1.02)
	elif _burst_pitch_jitter > 0.0:
		pitch = _burst_pitch_base * randf_range(1.0 - _burst_pitch_jitter, 1.0 + _burst_pitch_jitter)

	var vol: float = _burst_volume_db + randf_range(-1.2, 0.4)
	play_stream_once(stream, pitch, vol, _burst_streams.size() == 1, false)


func _acquire_player() -> AudioStreamPlayer:
	for p: AudioStreamPlayer in _sfx_pool:
		if not p.playing:
			return p
	var oldest: AudioStreamPlayer = _sfx_pool[0]
	var max_pos: float = -1.0
	for p: AudioStreamPlayer in _sfx_pool:
		var pos: float = p.get_playback_position()
		if pos > max_pos:
			max_pos = pos
			oldest = p
	oldest.stop()
	return oldest

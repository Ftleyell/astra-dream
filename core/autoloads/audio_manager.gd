class_name AudioManagerClass
extends Node

## AudioManager v2 Data-Driven con Modulación Anti-Fatiga, Prioridades de Voz,
## Atenuación por Densidad, Layering de 2 Capas, Panning Sutil, DSP Reactivo y Ambience.

const SfxCueDataScript = preload("res://core/audio/sfx_cue_data.gd")
const SfxCueBankScript = preload("res://core/audio/sfx_cue_bank.gd")
const SfxDensityTrackerScript = preload("res://core/audio/sfx_density_tracker.gd")
const AudioMixDirectorScript = preload("res://core/audio/audio_mix_director.gd")
const AmbienceCrossfadeScript = preload("res://core/audio/ambience_crossfade_controller.gd")

var sfx_streams: Dictionary = {}
var music_player: AudioStreamPlayer = null
var current_music_track: String = ""

var mix_director: AudioMixDirectorScript = null
var ambience_controller: AmbienceCrossfadeScript = null

# Voice pool de reproductores pre-instanciados (2D centrado) y paneables (mundo)
const POOL_SIZE: int = 24
const PAN_POOL_SIZE: int = 12
var _sfx_pool: Array[AudioStreamPlayer] = []
var _pan_pool: Array[AudioStreamPlayer2D] = []
var _active_sfx_map: Dictionary = {}   # player -> sfx_name
var _voice_priorities: Dictionary = {} # player -> int (SfxCueData.Priority)

# Control de tiempo, concurrencia, variantes y densidad por sonido
var _last_played_msec: Dictionary = {} # sfx_name -> msec
var _active_counts: Dictionary = {}    # sfx_name -> int
var _last_variant_idx: Dictionary = {} # sfx_name -> int
var _delayed_layers: Array[Dictionary] = []

var _cue_bank: SfxCueBankScript = null
var _cues_by_id: Dictionary = {}       # String -> SfxCueData
var _density_tracker: SfxDensityTrackerScript = SfxDensityTrackerScript.new()

# Sistema de arpegio musical para EXP (previene fatiga de repetición)
var _exp_combo_count: int = 0
var _last_exp_msec: int = 0
const EXP_COMBO_TIMEOUT_MSEC: int = 420
const EXP_PITCH_STEPS: Array[float] = [
	0.88, 0.94, 1.00, 1.06, 1.12, 1.18, 1.25, 1.32, 1.40, 1.48, 1.56, 1.65
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_init_music_player()
	_init_voice_pool()
	_init_pan_pool()
	_init_subsystems()
	reload_cue_bank()


func _process(delta: float) -> void:
	if _delayed_layers.is_empty():
		return
	var unscaled_delta: float = delta
	if Engine.time_scale > 0.01 and Engine.time_scale < 0.99:
		unscaled_delta = clampf(delta / Engine.time_scale, 0.0, 0.05)

	for i: int in range(_delayed_layers.size() - 1, -1, -1):
		var item: Dictionary = _delayed_layers[i]
		var rem: float = float(item.get("delay", 0.0)) - unscaled_delta
		if rem <= 0.0:
			var stream: AudioStream = item.get("stream", null) as AudioStream
			var bus_name: StringName = item.get("bus", &"SFX_Heroic") as StringName
			var vol_db: float = float(item.get("volume_db", -3.0))
			var pitch: float = float(item.get("pitch", 1.0))
			var prio: int = int(item.get("priority", SfxCueDataScript.Priority.HERO))
			_play_layer_stream(stream, bus_name, vol_db, pitch, prio)
			_delayed_layers.remove_at(i)
		else:
			item["delay"] = rem


func _init_music_player() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.bus = &"Music"
	add_child(music_player)


func _init_voice_pool() -> void:
	for i: int in range(POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.bus = &"SFX"
		player.finished.connect(_on_player_finished.bind(player))
		add_child(player)
		_sfx_pool.append(player)


func _init_pan_pool() -> void:
	for i: int in range(PAN_POOL_SIZE):
		var player := AudioStreamPlayer2D.new()
		player.bus = &"SFX_Combat" if AudioServer.get_bus_index("SFX_Combat") >= 0 else &"SFX"
		player.attenuation = 0.0001
		player.max_distance = 100000.0
		player.panning_strength = 0.35
		player.finished.connect(_on_player_finished.bind(player))
		add_child(player)
		_pan_pool.append(player)


func _init_subsystems() -> void:
	mix_director = AudioMixDirectorScript.new()
	mix_director.name = "AudioMixDirector"
	add_child(mix_director)

	ambience_controller = AmbienceCrossfadeScript.new()
	ambience_controller.name = "AmbienceCrossfadeController"
	add_child(ambience_controller)


func reload_cue_bank() -> void:
	var loaded_bank: SfxCueBankScript = null
	if ResourceLoader.exists(SfxCueBankScript.DEFAULT_BANK_PATH):
		loaded_bank = ResourceLoader.load(
			SfxCueBankScript.DEFAULT_BANK_PATH,
			"",
			ResourceLoader.CACHE_MODE_REPLACE
		) as SfxCueBankScript
	if loaded_bank == null or loaded_bank.cues.is_empty():
		loaded_bank = SfxCueBankScript.create_default_bank()

	_cue_bank = loaded_bank
	_cues_by_id = _cue_bank.build_lookup()
	_refresh_legacy_streams_dict()

	if ambience_controller != null:
		ambience_controller.configure_tracks(_cue_bank.ambience_tracks)


func _refresh_legacy_streams_dict() -> void:
	for key_v: Variant in _cues_by_id.keys():
		var key: String = str(key_v)
		var cue: SfxCueDataScript = _cues_by_id[key] as SfxCueDataScript
		if cue != null and not cue.streams.is_empty() and cue.streams[0] != null:
			sfx_streams[key] = cue.streams[0]

	if not sfx_streams.has("hub_footstep"):
		sfx_streams["hub_footstep"] = _build_synthetic_footstep_wav()
		if _cues_by_id.has("hub_footstep"):
			var foot_cue: SfxCueDataScript = _cues_by_id["hub_footstep"] as SfxCueDataScript
			if foot_cue.streams.is_empty():
				foot_cue.streams.append(sfx_streams["hub_footstep"] as AudioStream)


func _build_synthetic_footstep_wav() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var dur_sec: float = 0.068
	var sample_count: int = int(roundf(float(sample_rate) * dur_sec))
	var pcm := PackedByteArray()
	pcm.resize(sample_count * 2)
	var phase: float = 0.0
	for i: int in range(sample_count):
		var t: float = float(i) / float(sample_rate)
		var env_low: float = exp(-t * 58.0)
		var env_click: float = exp(-t * 145.0)
		var freq: float = lerpf(155.0, 72.0, clampf(t / 0.04, 0.0, 1.0))
		phase += TAU * freq / float(sample_rate)
		var thud: float = sin(phase) * 0.42 * env_low
		var metal: float = sin(TAU * 620.0 * t) * 0.14 * env_click + sin(TAU * 1180.0 * t) * 0.08 * env_click
		var sample_f: float = clampf(thud + metal, -0.95, 0.95)
		var s16: int = int(roundf(sample_f * 32767.0))
		pcm.encode_s16(i * 2, s16)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = pcm
	return wav


func play_sfx(sfx_name: String, pitch_scale: float = 1.0, volume_db: float = 0.0) -> AudioStreamPlayer:
	var resolved: Dictionary = _prepare_sfx_playback(sfx_name, pitch_scale, volume_db)
	if resolved.is_empty():
		return null

	var cue: SfxCueDataScript = resolved.get("cue", null) as SfxCueDataScript
	var stream: AudioStream = resolved.get("stream", null) as AudioStream
	var resolved_key: String = str(resolved.get("key", sfx_name))
	var final_pitch: float = float(resolved.get("pitch", 1.0))
	var final_volume: float = float(resolved.get("volume_db", 0.0))
	var priority: int = int(resolved.get("priority", SfxCueDataScript.Priority.FEEDBACK))
	var bus_name: StringName = resolved.get("bus", &"SFX") as StringName

	var player: AudioStreamPlayer = _get_available_player(priority)
	if player == null:
		return null

	player.bus = _resolve_valid_bus(bus_name)
	player.stream = stream
	player.pitch_scale = final_pitch
	player.volume_db = final_volume
	_active_sfx_map[player] = resolved_key
	_voice_priorities[player] = priority
	_active_counts[resolved_key] = int(_active_counts.get(resolved_key, 0)) + 1
	player.play()

	_trigger_cue_side_effects(cue, final_pitch)
	return player


func play_sfx_at(sfx_name: String, world_pos: Vector2, pitch_scale: float = 1.0, volume_db: float = 0.0) -> Node:
	var resolved_key: String = _cue_bank.resolve_key(sfx_name) if _cue_bank != null else sfx_name
	var cue: SfxCueDataScript = _cues_by_id.get(resolved_key, null) as SfxCueDataScript
	if cue == null or not cue.allow_panning:
		return play_sfx(sfx_name, pitch_scale, volume_db)

	var prepared: Dictionary = _prepare_sfx_playback(sfx_name, pitch_scale, volume_db)
	if prepared.is_empty():
		return null

	var player2d: AudioStreamPlayer2D = _get_available_pan_player(int(prepared.get("priority", SfxCueDataScript.Priority.FEEDBACK)))
	if player2d == null:
		return play_sfx(sfx_name, pitch_scale, volume_db)

	var final_pitch: float = float(prepared.get("pitch", 1.0))
	var priority: int = int(prepared.get("priority", SfxCueDataScript.Priority.FEEDBACK))
	var bus_name: StringName = prepared.get("bus", &"SFX_Combat") as StringName

	player2d.bus = _resolve_valid_bus(bus_name)
	player2d.global_position = world_pos
	player2d.panning_strength = cue.panning_strength
	player2d.stream = prepared.get("stream", null) as AudioStream
	player2d.pitch_scale = final_pitch
	player2d.volume_db = float(prepared.get("volume_db", 0.0))
	_active_sfx_map[player2d] = resolved_key
	_voice_priorities[player2d] = priority
	_active_counts[resolved_key] = int(_active_counts.get(resolved_key, 0)) + 1
	player2d.play()

	_trigger_cue_side_effects(cue, final_pitch)
	return player2d


func _prepare_sfx_playback(sfx_name: String, pitch_scale: float, volume_db: float) -> Dictionary:
	var resolved_key: String = _cue_bank.resolve_key(sfx_name) if _cue_bank != null else sfx_name
	var cue: SfxCueDataScript = _cues_by_id.get(resolved_key, null) as SfxCueDataScript

	# Compatibilidad si algún test o script inyecta directamente en sfx_streams
	var override_stream: AudioStream = sfx_streams.get(sfx_name, null) as AudioStream
	if override_stream == null and resolved_key != sfx_name:
		override_stream = sfx_streams.get(resolved_key, null) as AudioStream

	var stream: AudioStream = null
	if cue != null and not cue.streams.is_empty():
		stream = _pick_variant_stream(resolved_key, cue.streams, override_stream)
	else:
		stream = override_stream

	if stream == null:
		return {}

	var now: int = Time.get_ticks_msec()
	var min_interval: int = cue.min_interval_ms if cue != null else 25
	if _last_played_msec.has(resolved_key):
		if (now - int(_last_played_msec[resolved_key])) < min_interval:
			return {}
	_last_played_msec[resolved_key] = now

	var max_poly: int = cue.max_polyphony if cue != null else 4
	var active_count: int = _count_active_voices(resolved_key)
	_active_counts[resolved_key] = active_count
	if active_count >= max_poly:
		return {}

	var final_pitch: float = pitch_scale
	var final_volume: float = volume_db + (cue.base_volume_db if cue != null else 0.0)

	if cue != null and cue.use_exp_combo:
		if (now - _last_exp_msec) < EXP_COMBO_TIMEOUT_MSEC:
			_exp_combo_count += 1
		else:
			_exp_combo_count = 0
		_last_exp_msec = now

		var step_idx: int = _exp_combo_count % EXP_PITCH_STEPS.size()
		var chord_multiplier: float = EXP_PITCH_STEPS[step_idx]
		var micro_jitter: float = randf_range(0.98, 1.02)
		final_pitch = pitch_scale * chord_multiplier * micro_jitter
	else:
		var p_min: float = cue.pitch_min if cue != null else 0.90
		var p_max: float = cue.pitch_max if cue != null else 1.10
		final_pitch = pitch_scale * randf_range(p_min, p_max)

	var vol_jitter: float = cue.vol_jitter_db if cue != null else 1.0
	if vol_jitter > 0.0:
		final_volume += randf_range(-vol_jitter, vol_jitter * 0.3)

	if cue != null and cue.density_attenuation_db > 0.0:
		final_volume += _density_tracker.record_and_get_attenuation_db(resolved_key, now, cue.density_attenuation_db)

	return {
		"key": resolved_key,
		"cue": cue,
		"stream": stream,
		"pitch": clampf(final_pitch, 0.2, 3.5),
		"volume_db": final_volume,
		"priority": int(cue.priority) if cue != null else SfxCueDataScript.Priority.FEEDBACK,
		"bus": cue.bus_name if cue != null else &"SFX",
	}


func _pick_variant_stream(cue_key: String, variants: Array[AudioStream], override_stream: AudioStream) -> AudioStream:
	if variants.size() == 1:
		return override_stream if override_stream != null else variants[0]
	var last_idx: int = int(_last_variant_idx.get(cue_key, -1))
	var idx: int = randi_range(0, variants.size() - 1)
	if idx == last_idx:
		idx = (idx + 1) % variants.size()
	_last_variant_idx[cue_key] = idx
	return variants[idx]


func _count_active_voices(resolved_key: String) -> int:
	var active_count: int = 0
	for p: AudioStreamPlayer in _sfx_pool:
		if p.playing and _active_sfx_map.get(p) == resolved_key:
			active_count += 1
		elif not p.playing and _active_sfx_map.has(p):
			_release_player_voice(p)
	for p2d: AudioStreamPlayer2D in _pan_pool:
		if p2d.playing and _active_sfx_map.get(p2d) == resolved_key:
			active_count += 1
		elif not p2d.playing and _active_sfx_map.has(p2d):
			_release_player_voice(p2d)
	return active_count


func _trigger_cue_side_effects(cue: SfxCueDataScript, final_pitch: float) -> void:
	if cue == null:
		return
	if cue.duck_combat_db > 0.0 and mix_director != null:
		mix_director.trigger_combat_duck(cue.duck_combat_db, cue.duck_duration_sec)
	if not cue.secondary_layer_streams.is_empty():
		var l_idx: int = randi_range(0, cue.secondary_layer_streams.size() - 1)
		var l_stream: AudioStream = cue.secondary_layer_streams[l_idx]
		if l_stream != null:
			if cue.secondary_layer_delay_sec <= 0.005:
				_play_layer_stream(l_stream, cue.secondary_layer_bus, cue.secondary_layer_volume_db, final_pitch, int(cue.priority))
			else:
				_delayed_layers.append({
					"stream": l_stream,
					"bus": cue.secondary_layer_bus,
					"volume_db": cue.secondary_layer_volume_db,
					"pitch": final_pitch,
					"priority": int(cue.priority),
					"delay": cue.secondary_layer_delay_sec,
				})


func _play_layer_stream(stream: AudioStream, bus_name: StringName, vol_db: float, pitch: float, prio: int) -> void:
	if stream == null:
		return
	var p: AudioStreamPlayer = _get_available_player(prio)
	if p == null:
		return
	p.bus = _resolve_valid_bus(bus_name)
	p.stream = stream
	p.volume_db = vol_db
	p.pitch_scale = clampf(pitch, 0.2, 3.5)
	_active_sfx_map[p] = "__layer__"
	_voice_priorities[p] = prio
	p.play()


func _get_available_player(req_priority: int = SfxCueDataScript.Priority.FEEDBACK) -> AudioStreamPlayer:
	for p: AudioStreamPlayer in _sfx_pool:
		if not p.playing:
			_release_player_voice(p)
			return p

	var victim: AudioStreamPlayer = null
	var lowest_prio: int = 999
	var max_pos: float = -1.0
	for p: AudioStreamPlayer in _sfx_pool:
		var v_prio: int = int(_voice_priorities.get(p, SfxCueDataScript.Priority.FEEDBACK))
		if v_prio > req_priority:
			continue
		var pos: float = p.get_playback_position()
		if v_prio < lowest_prio or (v_prio == lowest_prio and pos > max_pos):
			lowest_prio = v_prio
			max_pos = pos
			victim = p

	if victim == null:
		return null
	_release_player_voice(victim)
	victim.stop()
	return victim


func _get_available_pan_player(req_priority: int) -> AudioStreamPlayer2D:
	for p: AudioStreamPlayer2D in _pan_pool:
		if not p.playing:
			_release_player_voice(p)
			return p

	var victim: AudioStreamPlayer2D = null
	var lowest_prio: int = 999
	var max_pos: float = -1.0
	for p: AudioStreamPlayer2D in _pan_pool:
		var v_prio: int = int(_voice_priorities.get(p, SfxCueDataScript.Priority.FEEDBACK))
		if v_prio > req_priority:
			continue
		var pos: float = p.get_playback_position()
		if v_prio < lowest_prio or (v_prio == lowest_prio and pos > max_pos):
			lowest_prio = v_prio
			max_pos = pos
			victim = p

	if victim == null:
		return null
	_release_player_voice(victim)
	victim.stop()
	return victim


func _on_player_finished(player: Node) -> void:
	_release_player_voice(player)


func _release_player_voice(player: Node) -> void:
	_voice_priorities.erase(player)
	if _active_sfx_map.has(player):
		var sfx_name: String = str(_active_sfx_map[player])
		_active_sfx_map.erase(player)
		if _active_counts.has(sfx_name):
			_active_counts[sfx_name] = maxi(0, int(_active_counts[sfx_name]) - 1)


func _resolve_valid_bus(bus_name: StringName) -> StringName:
	if AudioServer.get_bus_index(String(bus_name)) >= 0:
		return bus_name
	if AudioServer.get_bus_index("SFX") >= 0:
		return &"SFX"
	return &"Master"


func set_ambience(track_id: String, fade_sec: float = 1.8) -> void:
	if ambience_controller != null:
		ambience_controller.transition_to(track_id, fade_sec)


func set_pause_muffle(active: bool) -> void:
	if mix_director != null:
		mix_director.set_pause_muffle(active)


func set_tactical_focus(intensity: float) -> void:
	if mix_director != null:
		mix_director.set_tactical_focus(intensity)


func play_music(track_name: String) -> void:
	if current_music_track == track_name and music_player and music_player.playing:
		return
	var track_path := "res://assets/audio/music_%s.wav" % track_name
	if not ResourceLoader.exists(track_path):
		return
	var stream: AudioStream = load(track_path)
	if not stream:
		return
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	if not music_player:
		_init_music_player()
	if music_player:
		music_player.stream = stream
		music_player.play()
	current_music_track = track_name


func stop_music() -> void:
	if music_player:
		music_player.stop()
	current_music_track = ""

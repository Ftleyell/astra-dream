class_name MumbleSpeechController
extends Node

## Controlador modular de mumble speech (enfoque híbrido data-driven).
## Soporta samples reales en VoiceProfileData.samples o síntesis procedural
## de sílabas con formantes vocálicos en memoria (zero-alloc durante diálogo).

signal blip_played(pitch_scale: float, volume_db: float, is_radio: bool)

const VoiceProfileDataScript = preload("res://data/voices/voice_profile_data.gd")
const RADIO_BUS_NAME: StringName = &"MumbleRadio"
const SAMPLE_RATE: int = 22050
const IGNORED_CHARS: String = " \t\n\r.,;:!?¡¿…—–-\"'()[]{}<>"

# Multiplicadores de formantes (F1, F2) para 5 vocales estilizadas (a, e, i, o, u)
const VOWEL_FORMANT_RATIOS: Array[Vector2] = [
	Vector2(1.00, 1.85), # a
	Vector2(0.82, 2.35), # e
	Vector2(0.68, 2.75), # i
	Vector2(0.88, 1.45), # o
	Vector2(0.70, 1.25), # u
]

var enabled: bool = true
var force_radio: bool = false
var profile: VoiceProfileDataScript = null

var _player: AudioStreamPlayer = null
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _procedural_bank: Array[AudioStreamWAV] = []
var _cached_formant_hz: float = -1.0
var _cached_duration_sec: float = -1.0

var _utterance_text: String = ""
var _utterance_length: int = 0
var _ends_with_question: bool = false
var _ends_with_exclamation: bool = false

var _visible_spoken_chars: int = 0
var _last_blip_msec: int = -10000
var _last_sample_index: int = -1
var _last_pitch_used: float = 1.0
var _last_volume_used: float = 0.0


func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_ensure_player()
	_ensure_radio_bus()


func _get_clean_bus_name() -> StringName:
	if AudioServer.get_bus_index(&"SFX") != -1:
		return &"SFX"
	return &"Master"


func _ensure_player() -> void:
	if is_instance_valid(_player):
		return
	_player = AudioStreamPlayer.new()
	_player.name = "MumbleVoicePlayer"
	_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_player)


func _ensure_radio_bus() -> void:
	var clean_bus: StringName = _get_clean_bus_name()
	var existing_idx: int = AudioServer.get_bus_index(RADIO_BUS_NAME)
	if existing_idx != -1:
		AudioServer.set_bus_send(existing_idx, String(clean_bus))
		return

	var bus_idx: int = AudioServer.bus_count
	AudioServer.add_bus(bus_idx)
	AudioServer.set_bus_name(bus_idx, String(RADIO_BUS_NAME))
	AudioServer.set_bus_send(bus_idx, String(clean_bus))

	var bandpass: AudioEffectBandPassFilter = AudioEffectBandPassFilter.new()
	bandpass.cutoff_hz = 1450.0
	bandpass.resonance = 0.72
	AudioServer.add_bus_effect(bus_idx, bandpass)

	var distortion: AudioEffectDistortion = AudioEffectDistortion.new()
	distortion.mode = AudioEffectDistortion.MODE_OVERDRIVE
	distortion.drive = 0.18
	distortion.post_gain = 1.5
	AudioServer.add_bus_effect(bus_idx, distortion)


func set_profile(new_profile: VoiceProfileDataScript) -> void:
	profile = new_profile
	_last_sample_index = -1
	if profile != null and profile.samples.is_empty():
		_rebuild_procedural_bank_if_needed()


func invalidate_procedural_cache() -> void:
	_cached_formant_hz = -1.0
	_cached_duration_sec = -1.0
	if profile != null and profile.samples.is_empty():
		_rebuild_procedural_bank_if_needed()


func begin_utterance(full_text: String) -> void:
	_utterance_text = full_text.strip_edges()
	_utterance_length = _utterance_text.length()
	_ends_with_question = _utterance_text.ends_with("?")
	_ends_with_exclamation = _utterance_text.ends_with("!")
	_visible_spoken_chars = 0
	_last_blip_msec = -10000
	if profile != null and profile.samples.is_empty():
		_rebuild_procedural_bank_if_needed()


func stop() -> void:
	if is_instance_valid(_player):
		_player.stop()


func get_last_pitch_used() -> float:
	return _last_pitch_used


func get_last_volume_used() -> float:
	return _last_volume_used


func get_procedural_bank_size() -> int:
	return _procedural_bank.size()


## Llamar al revelar cada carácter visible del diálogo.
## Devuelve true si se disparó una sílaba de audio.
func on_character_revealed(char_text: String, char_index: int, now_msec: int = -1) -> bool:
	if not enabled or profile == null or char_text.is_empty():
		return false

	var ch: String = char_text.substr(0, 1)
	if IGNORED_CHARS.contains(ch):
		return false

	_visible_spoken_chars += 1
	var cadence: int = maxi(1, profile.chars_per_blip)
	if (_visible_spoken_chars - 1) % cadence != 0:
		return false

	var current_msec: int = now_msec if now_msec >= 0 else Time.get_ticks_msec()
	if current_msec - _last_blip_msec < profile.min_interval_ms:
		return false

	_last_blip_msec = current_msec
	_trigger_blip(ch, char_index)
	return true


func _trigger_blip(ch: String, char_index: int) -> void:
	_ensure_player()
	var stream: AudioStream = _pick_stream(ch)
	if stream == null:
		return

	var pitch: float = profile.base_pitch + _rng.randf_range(-profile.pitch_variance, profile.pitch_variance)
	var vol_db: float = profile.volume_db + _rng.randf_range(-profile.volume_jitter_db, profile.volume_jitter_db)

	# Micro-entonación contextual
	if _utterance_length > 0:
		var progress: float = clampf(float(char_index) / float(maxi(1, _utterance_length - 1)), 0.0, 1.0)
		if _ends_with_question and progress > 0.65:
			var rise_t: float = (progress - 0.65) / 0.35
			pitch += profile.question_pitch_boost * rise_t
		elif _ends_with_exclamation:
			vol_db += profile.exclamation_vol_db
			pitch += 0.03

	pitch = clampf(pitch, 0.35, 3.0)
	_last_pitch_used = pitch
	_last_volume_used = vol_db

	var use_radio: bool = force_radio or profile.radio_filter_enabled
	var target_bus: StringName = RADIO_BUS_NAME if use_radio else _get_clean_bus_name()
	if AudioServer.get_bus_index(target_bus) == -1:
		target_bus = _get_clean_bus_name()

	_player.bus = String(target_bus)
	_player.stream = stream
	_player.pitch_scale = pitch
	_player.volume_db = vol_db
	# Monofonía limpia: cortar sílaba previa antes de reproducir la nueva
	_player.stop()
	_player.play()
	blip_played.emit(pitch, vol_db, use_radio)


func _pick_stream(ch: String) -> AudioStream:
	if not profile.samples.is_empty():
		var count: int = profile.samples.size()
		if count == 1:
			return profile.samples[0]
		var idx: int = _rng.randi_range(0, count - 1)
		if idx == _last_sample_index:
			idx = (idx + 1) % count
		_last_sample_index = idx
		return profile.samples[idx]

	_rebuild_procedural_bank_if_needed()
	if _procedural_bank.is_empty():
		return null

	var vowel_idx: int = _char_to_vowel_index(ch)
	if vowel_idx == _last_sample_index and _procedural_bank.size() > 1:
		vowel_idx = (vowel_idx + 1) % _procedural_bank.size()
	_last_sample_index = vowel_idx
	return _procedural_bank[vowel_idx]


func _char_to_vowel_index(ch: String) -> int:
	var lower: String = ch.to_lower()
	match lower:
		"a", "á":
			return 0
		"e", "é":
			return 1
		"i", "í", "y":
			return 2
		"o", "ó":
			return 3
		"u", "ú", "ü":
			return 4
		_:
			return abs(lower.unicode_at(0)) % VOWEL_FORMANT_RATIOS.size()


func _rebuild_procedural_bank_if_needed() -> void:
	if profile == null:
		return
	if is_equal_approx(_cached_formant_hz, profile.formant_hz) and is_equal_approx(_cached_duration_sec, profile.syllable_duration_sec) and not _procedural_bank.is_empty():
		return

	_cached_formant_hz = profile.formant_hz
	_cached_duration_sec = profile.syllable_duration_sec
	_procedural_bank.clear()

	for ratio: Vector2 in VOWEL_FORMANT_RATIOS:
		var wav: AudioStreamWAV = _synthesize_syllable_wav(profile.formant_hz, ratio, profile.syllable_duration_sec)
		_procedural_bank.append(wav)


func _synthesize_syllable_wav(base_hz: float, formant_ratio: Vector2, duration_sec: float) -> AudioStreamWAV:
	var frame_count: int = maxi(256, int(float(SAMPLE_RATE) * duration_sec))
	var pcm: PackedByteArray = PackedByteArray()
	pcm.resize(frame_count * 2)

	var f0: float = base_hz
	var f1: float = base_hz * formant_ratio.x
	var f2: float = base_hz * formant_ratio.y
	var inv_sr: float = 1.0 / float(SAMPLE_RATE)

	for i: int in range(frame_count):
		var t: float = float(i) * inv_sr
		var norm_t: float = float(i) / float(frame_count)

		# Envolvente suave (ataque rápido 12%, caída suave 35%) para cero clicks
		var env: float = 1.0
		if norm_t < 0.12:
			env = norm_t / 0.12
		elif norm_t > 0.65:
			env = (1.0 - norm_t) / 0.35
		env = clampf(env, 0.0, 1.0)

		# Ligera caída tonal natural dentro de la sílaba
		var pitch_bend: float = 1.0 - 0.06 * norm_t
		var phase0: float = TAU * f0 * pitch_bend * t
		var phase1: float = TAU * f1 * pitch_bend * t
		var phase2: float = TAU * f2 * pitch_bend * t

		var sample: float = (
			0.55 * sin(phase0)
			+ 0.30 * sin(phase1)
			+ 0.15 * sin(phase2)
		) * env * 0.72

		var pcm_i16: int = clampi(int(sample * 32767.0), -32768, 32767)
		pcm[i * 2] = pcm_i16 & 0xFF
		pcm[i * 2 + 1] = (pcm_i16 >> 8) & 0xFF

	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = pcm
	return wav

class_name AudioManagerClass
extends Node

## AudioManager con Modulación Dinámica Anti-Fatiga, Voice Pooling,
## Control de Polifonía y Escala Pentatónica para Coleccionables.

var sfx_streams: Dictionary = {}
var music_player: AudioStreamPlayer = null
var current_music_track: String = ""

# Voice pool de reproductores pre-instanciados
const POOL_SIZE: int = 24
var _sfx_pool: Array[AudioStreamPlayer] = []
var _active_sfx_map: Dictionary = {} # player -> sfx_name

# Control de tiempo y concurrencia por sonido
var _last_played_msec: Dictionary = {} # sfx_name -> msec
var _active_counts: Dictionary = {}    # sfx_name -> int

# Sistema de arpegio musical para EXP (previene fatiga de repetición)
var _exp_combo_count: int = 0
var _last_exp_msec: int = 0
const EXP_COMBO_TIMEOUT_MSEC: int = 420
const EXP_PITCH_STEPS: Array[float] = [
	0.88, 0.94, 1.00, 1.06, 1.12, 1.18, 1.25, 1.32, 1.40, 1.48, 1.56, 1.65
]

# Perfiles de modulación anti-fatiga por sonido:
# - min_interval_ms: tiempo mínimo entre dos disparos idénticos (anti-phasing)
# - max_polyphony: máximo de instancias simultáneas del mismo sonido
# - pitch_min / pitch_max: rango de variación tonal aleatoria
# - vol_jitter_db: rango de fluctuación de volumen para romper uniformidad robótica
const SFX_PROFILES: Dictionary = {
	"exp": {
		"min_interval_ms": 35,
		"max_polyphony": 5,
		"vol_jitter_db": 1.2,
		"use_combo": true
	},
	"laser": {
		"min_interval_ms": 40,
		"max_polyphony": 4,
		"pitch_min": 0.88,
		"pitch_max": 1.14,
		"vol_jitter_db": 1.5,
		"use_combo": false
	},
	"missile": {
		"min_interval_ms": 50,
		"max_polyphony": 4,
		"pitch_min": 0.86,
		"pitch_max": 1.15,
		"vol_jitter_db": 1.5,
		"use_combo": false
	},
	"explosion": {
		"min_interval_ms": 45,
		"max_polyphony": 4,
		"pitch_min": 0.76,
		"pitch_max": 1.22,
		"vol_jitter_db": 2.0,
		"use_combo": false
	},
	"player_hit": {
		"min_interval_ms": 80,
		"max_polyphony": 2,
		"pitch_min": 0.90,
		"pitch_max": 1.10,
		"vol_jitter_db": 1.0,
		"use_combo": false
	},
	"dash": {
		"min_interval_ms": 60,
		"max_polyphony": 3,
		"pitch_min": 0.91,
		"pitch_max": 1.11,
		"vol_jitter_db": 1.0,
		"use_combo": false
	},
	"bomb": {
		"min_interval_ms": 100,
		"max_polyphony": 2,
		"pitch_min": 0.94,
		"pitch_max": 1.06,
		"vol_jitter_db": 0.5,
		"use_combo": false
	},
	"ui_click": {
		"min_interval_ms": 30,
		"max_polyphony": 3,
		"pitch_min": 0.94,
		"pitch_max": 1.06,
		"vol_jitter_db": 0.8,
		"use_combo": false
	},
	"heal": {
		"min_interval_ms": 60,
		"max_polyphony": 2,
		"pitch_min": 0.93,
		"pitch_max": 1.07,
		"vol_jitter_db": 0.8,
		"use_combo": false
	},
	"magnet": {
		"min_interval_ms": 60,
		"max_polyphony": 2,
		"pitch_min": 0.93,
		"pitch_max": 1.07,
		"vol_jitter_db": 0.8,
		"use_combo": false
	}
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_init_music_player()
	_init_voice_pool()
	_preload_sfx()

func _init_music_player() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.bus = &"Music"
	add_child(music_player)

func _init_voice_pool() -> void:
	for i in range(POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.bus = &"SFX"
		player.finished.connect(_on_player_finished.bind(player))
		add_child(player)
		_sfx_pool.append(player)

func _preload_sfx() -> void:
	var sfx_files := {
		"laser": "res://assets/audio/sfx/laser_fire.wav",
		"missile": "res://assets/audio/sfx/missile_fire.wav",
		"explosion": "res://assets/audio/sfx/explosion.wav",
		"exp": "res://assets/audio/sfx/exp_pickup.wav",
		"dash": "res://assets/audio/sfx/dash.wav",
		"bomb": "res://assets/audio/sfx/bomb.wav",
		"player_hit": "res://assets/audio/sfx/player_hit.wav",
		"ui_click": "res://assets/audio/sfx/ui_click.wav",
		"heal": "res://assets/audio/sfx/heal.wav",
		"magnet": "res://assets/audio/sfx/magnet.wav"
	}
	for key in sfx_files.keys():
		var path: String = sfx_files[key]
		if ResourceLoader.exists(path):
			sfx_streams[key] = load(path)

func play_sfx(sfx_name: String, pitch_scale: float = 1.0, volume_db: float = 0.0) -> AudioStreamPlayer:
	if not sfx_streams.has(sfx_name):
		return null
	var stream: AudioStream = sfx_streams[sfx_name]
	if not stream:
		return null

	var now: int = Time.get_ticks_msec()
	var profile: Dictionary = SFX_PROFILES.get(sfx_name, {})

	# 1. Micro-interval throttling (evita saturación y chasquidos de fase)
	var min_interval: int = profile.get("min_interval_ms", 25)
	if _last_played_msec.has(sfx_name):
		if (now - _last_played_msec[sfx_name]) < min_interval:
			return null
	_last_played_msec[sfx_name] = now

	# 2. Control de polifonía máxima por sonido
	var max_poly: int = profile.get("max_polyphony", 4)
	var current_poly: int = _active_counts.get(sfx_name, 0)
	if current_poly >= max_poly:
		return null

	# 3. Modulación Dinámica Anti-Fatiga
	var final_pitch: float = pitch_scale
	var final_volume: float = volume_db

	if profile.get("use_combo", false):
		# Progresión musical ascendente para coleccionables continuos (EXP)
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
		# Modulación estocástica aleatoria según perfil
		var p_min: float = profile.get("pitch_min", 0.90)
		var p_max: float = profile.get("pitch_max", 1.10)
		final_pitch = pitch_scale * randf_range(p_min, p_max)

	# 4. Jitter de volumen sutil (rompe el efecto ametralladora)
	var vol_jitter: float = profile.get("vol_jitter_db", 1.0)
	if vol_jitter > 0.0:
		final_volume += randf_range(-vol_jitter, vol_jitter * 0.3)

	# 5. Asignar y reproducir desde el pool de voces
	var player := _get_available_player()
	if not player:
		return null

	player.stream = stream
	player.pitch_scale = clampf(final_pitch, 0.2, 3.5)
	player.volume_db = final_volume
	_active_sfx_map[player] = sfx_name
	_active_counts[sfx_name] = current_poly + 1
	player.play()
	return player

func _get_available_player() -> AudioStreamPlayer:
	for p in _sfx_pool:
		if not p.playing:
			return p
	# Si las 24 voces están en uso, robar la voz más antigua
	var oldest_player: AudioStreamPlayer = _sfx_pool[0]
	var max_pos: float = -1.0
	for p in _sfx_pool:
		var pos := p.get_playback_position()
		if pos > max_pos:
			max_pos = pos
			oldest_player = p
	_release_player_voice(oldest_player)
	return oldest_player

func _on_player_finished(player: AudioStreamPlayer) -> void:
	_release_player_voice(player)

func _release_player_voice(player: AudioStreamPlayer) -> void:
	if _active_sfx_map.has(player):
		var sfx_name: String = _active_sfx_map[player]
		_active_sfx_map.erase(player)
		if _active_counts.has(sfx_name):
			_active_counts[sfx_name] = maxi(0, _active_counts[sfx_name] - 1)

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

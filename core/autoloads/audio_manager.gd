class_name AudioManagerClass
extends Node

var sfx_streams: Dictionary = {}
var music_player: AudioStreamPlayer = null
var current_music_track: String = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_init_music_player()
	_preload_sfx()

func _init_music_player() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.bus = &"Music"
	add_child(music_player)

func _preload_sfx() -> void:
	var sfx_files := {
		"laser": "res://assets/audio/sfx/laser_fire.wav",
		"missile": "res://assets/audio/sfx/missile_fire.wav",
		"explosion": "res://assets/audio/sfx/explosion.wav",
		"exp": "res://assets/audio/sfx/exp_pickup.wav",
		"dash": "res://assets/audio/sfx/dash.wav",
		"bomb": "res://assets/audio/sfx/bomb.wav",
		"player_hit": "res://assets/audio/sfx/player_hit.wav",
		"ui_click": "res://assets/audio/sfx/ui_click.wav"
	}
	for key in sfx_files.keys():
		var path: String = sfx_files[key]
		if ResourceLoader.exists(path):
			sfx_streams[key] = load(path)

func play_sfx(sfx_name: String, pitch_scale: float = 1.0, volume_db: float = 0.0) -> void:
	if not sfx_streams.has(sfx_name):
		return
	var stream: AudioStream = sfx_streams[sfx_name]
	if not stream:
		return
	var player := AudioStreamPlayer.new()
	player.bus = &"SFX"
	player.stream = stream
	player.pitch_scale = pitch_scale * randf_range(0.96, 1.04)
	player.volume_db = volume_db
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

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

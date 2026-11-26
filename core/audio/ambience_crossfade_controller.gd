class_name AmbienceCrossfadeController
extends Node
## Controlador de cama atmosférica (Ambience Bed) con crossfade suave entre Hub, Cosmos y Title.

const SILENT_DB: float = -48.0
const ACTIVE_DB: float = -6.0

var current_track_id: String = "off"
var _tracks: Dictionary = {}
var _player_a: AudioStreamPlayer = null
var _player_b: AudioStreamPlayer = null
var _active_is_a: bool = true
var _fade_progress: float = 1.0
var _fade_duration: float = 1.8


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player_a = _create_ambience_player("AmbiencePlayerA")
	_player_b = _create_ambience_player("AmbiencePlayerB")


func _process(delta: float) -> void:
	if _fade_progress >= 1.0:
		return
	var unscaled_delta: float = delta
	if Engine.time_scale > 0.01 and Engine.time_scale < 0.99:
		unscaled_delta = clampf(delta / Engine.time_scale, 0.0, 0.05)

	_fade_progress = minf(1.0, _fade_progress + (unscaled_delta / maxf(0.05, _fade_duration)))
	var active_p: AudioStreamPlayer = _player_a if _active_is_a else _player_b
	var fading_p: AudioStreamPlayer = _player_b if _active_is_a else _player_a

	if active_p != null:
		if current_track_id == "off" or active_p.stream == null:
			active_p.volume_db = SILENT_DB
		else:
			active_p.volume_db = lerpf(SILENT_DB, ACTIVE_DB, _fade_progress)
	if fading_p != null and fading_p.playing:
		fading_p.volume_db = lerpf(ACTIVE_DB, SILENT_DB, _fade_progress)
		if _fade_progress >= 1.0:
			fading_p.stop()


func configure_tracks(track_map: Dictionary) -> void:
	_tracks = track_map.duplicate()


func transition_to(track_id: String, fade_sec: float = 1.8) -> void:
	var clean_id: String = track_id.strip_edges().to_lower()
	if clean_id == current_track_id:
		return
	current_track_id = clean_id
	_fade_duration = maxf(0.05, fade_sec)
	_fade_progress = 0.0
	_active_is_a = not _active_is_a

	var next_player: AudioStreamPlayer = _player_a if _active_is_a else _player_b
	if next_player == null:
		return

	if clean_id == "off" or not _tracks.has(clean_id):
		next_player.stop()
		next_player.stream = null
		return

	var path: String = str(_tracks[clean_id])
	var stream: AudioStream = _load_looping_stream(path)
	if stream == null:
		next_player.stop()
		next_player.stream = null
		return

	next_player.stream = stream
	next_player.volume_db = SILENT_DB
	next_player.play()


func _create_ambience_player(node_name: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.name = node_name
	p.bus = &"Ambience" if AudioServer.get_bus_index("Ambience") >= 0 else &"Master"
	p.volume_db = SILENT_DB
	add_child(p)
	return p


func _load_looping_stream(res_path: String) -> AudioStream:
	if res_path.is_empty():
		return null
	var stream: AudioStream = null
	if ResourceLoader.exists(res_path):
		stream = load(res_path) as AudioStream
	else:
		var abs_path: String = ProjectSettings.globalize_path(res_path)
		if FileAccess.file_exists(abs_path):
			var ext: String = abs_path.get_extension().to_lower()
			if ext == "ogg":
				stream = AudioStreamOggVorbis.load_from_file(abs_path)
			elif ext == "wav":
				stream = AudioStreamWAV.load_from_file(abs_path)
	if stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	return stream

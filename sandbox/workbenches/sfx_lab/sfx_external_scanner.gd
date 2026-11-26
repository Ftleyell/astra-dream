class_name SfxExternalScanner
extends RefCounted
## Escáner recursivo de packs de audio externos y analizador ligero de forma de onda.

const SUPPORTED_EXTENSIONS: Array[String] = ["wav", "ogg", "mp3", "flac", "aiff", "aif", "m4a", "opus"]
const IGNORED_DIRS: Array[String] = [".git", ".godot", "__MACOSX", "node_modules"]
const MAX_CACHE_ENTRIES: int = 48
const SILENCE_THRESHOLD: float = 0.015

var _cache: Dictionary = {} # abs_path -> Dictionary
var _cache_order: Array[String] = []


static func normalize_path_input(raw_path: String) -> String:
	var p: String = raw_path.strip_edges()
	while (p.begins_with("\"") and p.ends_with("\"")) or (p.begins_with("'") and p.ends_with("'")):
		if p.length() < 2:
			break
		p = p.substr(1, p.length() - 2).strip_edges()
	if p.begins_with("res://") or p.begins_with("user://"):
		p = ProjectSettings.globalize_path(p)
	p = p.replace("\\", "/")
	while p.ends_with("/") and p.length() > 3:
		p = p.substr(0, p.length() - 1)
	return p


static func scan_directory(root_dir: String, max_files: int = 8000) -> Dictionary:
	return scan_directories([root_dir], max_files)


static func scan_directories(root_dirs: Array[String], max_files: int = 8000) -> Dictionary:
	var entries: Array[Dictionary] = []
	var pack_set: Dictionary = {}
	var zip_files: Array[String] = []
	var seen_abs: Dictionary = {}
	var seen_zips: Dictionary = {}
	var truncated: bool = false

	for raw_root: String in root_dirs:
		var clean_root: String = normalize_path_input(raw_root)
		if clean_root.is_empty() or not DirAccess.dir_exists_absolute(clean_root):
			continue

		var stack: Array[String] = [clean_root]
		while not stack.is_empty():
			var current: String = stack.pop_back()
			var dir: DirAccess = DirAccess.open(current)
			if dir == null:
				continue
			dir.list_dir_begin()
			var item_name: String = dir.get_next()
			var subdirs: Array[String] = []
			while not item_name.is_empty():
				if item_name == "." or item_name == "..":
					item_name = dir.get_next()
					continue
				if dir.current_is_dir():
					if not IGNORED_DIRS.has(item_name) and not item_name.begins_with("."):
						subdirs.append(current + "/" + item_name)
				else:
					var ext: String = item_name.get_extension().to_lower()
					var abs_path: String = current + "/" + item_name
					if ext == "zip":
						if not seen_zips.has(abs_path):
							seen_zips[abs_path] = true
							zip_files.append(abs_path)
					elif SUPPORTED_EXTENSIONS.has(ext) and not seen_abs.has(abs_path):
						seen_abs[abs_path] = true
						var rel_path: String = abs_path
						if abs_path.begins_with(clean_root + "/"):
							rel_path = abs_path.substr(clean_root.length() + 1)
						var slash_idx: int = rel_path.find("/")
						var pack_name: String = rel_path.substr(0, slash_idx) if slash_idx >= 0 else clean_root.get_file()
						if pack_name.is_empty():
							pack_name = "<root>"
						pack_set[pack_name] = true
						entries.append({
							"abs_path": abs_path,
							"rel_path": rel_path,
							"filename": item_name,
							"pack": pack_name,
							"ext": ext,
						})
						if entries.size() >= max_files:
							truncated = true
							break
				item_name = dir.get_next()
			dir.list_dir_end()
			if truncated:
				break
			subdirs.sort()
			for i: int in range(subdirs.size() - 1, -1, -1):
				stack.append(subdirs[i])
		if truncated:
			break

	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("rel_path", "")).nocasecmp_to(str(b.get("rel_path", ""))) < 0
	)
	var packs: Array[String] = []
	for p_v: Variant in pack_set.keys():
		packs.append(str(p_v))
	packs.sort_custom(func(a: String, b: String) -> bool:
		return a.nocasecmp_to(b) < 0
	)
	zip_files.sort()
	return {"entries": entries, "packs": packs, "zip_files": zip_files, "truncated": truncated}


static func filter_entries(
	entries: Array[Dictionary],
	pack_filter: String,
	query: String,
	favorites: Dictionary,
	only_favorites: bool
) -> Array[Dictionary]:
	var clean_query: String = query.strip_edges().to_lower()
	var tokens: PackedStringArray = PackedStringArray()
	if not clean_query.is_empty():
		tokens = clean_query.split(" ", false)

	var filtered: Array[Dictionary] = []
	for entry: Dictionary in entries:
		var abs_path: String = str(entry.get("abs_path", ""))
		if only_favorites and not favorites.has(abs_path):
			continue
		if not pack_filter.is_empty() and pack_filter != "Todos":
			if str(entry.get("pack", "")) != pack_filter:
				continue
		if not tokens.is_empty():
			var haystack: String = str(entry.get("rel_path", "")).to_lower()
			var matched_all: bool = true
			for tok: String in tokens:
				if haystack.find(tok) < 0:
					matched_all = false
					break
			if not matched_all:
				continue
		filtered.append(entry)
	return filtered


func clear_cache() -> void:
	_cache.clear()
	_cache_order.clear()


func load_external_stream(abs_path: String) -> Dictionary:
	if _cache.has(abs_path):
		return _cache[abs_path] as Dictionary

	var result: Dictionary = _load_external_uncached(abs_path)
	if str(result.get("error", "")).is_empty() and result.get("stream", null) != null:
		_cache[abs_path] = result
		_cache_order.append(abs_path)
		if _cache_order.size() > MAX_CACHE_ENTRIES:
			var oldest: String = _cache_order.pop_front()
			_cache.erase(oldest)
	return result


func _load_external_uncached(abs_path: String) -> Dictionary:
	if abs_path.is_empty() or not FileAccess.file_exists(abs_path):
		return {"stream": null, "duration_ms": 0.0, "sample_rate": 0, "stereo": false, "leading_silence_ms": -1.0, "peaks": PackedFloat32Array(), "error": "Archivo no encontrado"}

	var ext: String = abs_path.get_extension().to_lower()
	var stream: AudioStream = null
	var decoded_fallback_used: bool = false

	if ext == "wav":
		stream = AudioStreamWAV.load_from_file(abs_path)
	elif ext == "ogg":
		stream = AudioStreamOggVorbis.load_from_file(abs_path)
	elif ext == "mp3":
		stream = AudioStreamMP3.load_from_file(abs_path)
		if stream == null:
			var mp3 := AudioStreamMP3.new()
			var bytes: PackedByteArray = FileAccess.get_file_as_bytes(abs_path)
			if not bytes.is_empty():
				mp3.data = bytes
				stream = mp3

	if stream == null:
		var preview_wav: AudioStreamWAV = _decode_via_python_preview(abs_path)
		if preview_wav != null:
			stream = preview_wav
			decoded_fallback_used = true

	if stream == null:
		return {"stream": null, "duration_ms": 0.0, "sample_rate": 0, "stereo": false, "leading_silence_ms": -1.0, "peaks": PackedFloat32Array(), "error": "No se pudo decodificar %s" % ext}

	var duration_ms: float = stream.get_length() * 1000.0
	var sample_rate: int = 44100
	var stereo: bool = false
	var leading_silence_ms: float = -1.0
	var peaks: PackedFloat32Array = PackedFloat32Array()

	if stream is AudioStreamWAV:
		var wav: AudioStreamWAV = stream as AudioStreamWAV
		sample_rate = wav.mix_rate
		stereo = wav.stereo
		var analysis: Dictionary = extract_wav_analysis(wav, 128)
		peaks = analysis.get("peaks", PackedFloat32Array()) as PackedFloat32Array
		leading_silence_ms = float(analysis.get("leading_silence_ms", -1.0))

	return {
		"stream": stream,
		"duration_ms": duration_ms,
		"sample_rate": sample_rate,
		"stereo": stereo,
		"leading_silence_ms": leading_silence_ms,
		"peaks": peaks,
		"decoded_fallback": decoded_fallback_used,
		"error": "",
	}


static func extract_wav_analysis(wav: AudioStreamWAV, bin_count: int = 128) -> Dictionary:
	var empty_peaks := PackedFloat32Array()
	if wav == null or wav.data.is_empty():
		return {"peaks": empty_peaks, "leading_silence_ms": -1.0}

	var channels: int = 2 if wav.stereo else 1
	var bytes_per_sample: int = 0
	if wav.format == AudioStreamWAV.FORMAT_16_BITS:
		bytes_per_sample = 2
	elif wav.format == AudioStreamWAV.FORMAT_8_BITS:
		bytes_per_sample = 1
	else:
		return {"peaks": empty_peaks, "leading_silence_ms": -1.0}

	var frame_stride: int = bytes_per_sample * channels
	var total_frames: int = wav.data.size() / frame_stride
	if total_frames <= 0 or wav.mix_rate <= 0:
		return {"peaks": empty_peaks, "leading_silence_ms": -1.0}

	var peaks := PackedFloat32Array()
	peaks.resize(bin_count)
	var first_active_frame: int = -1
	var sample_step: int = maxi(1, total_frames / 4096)

	for f_idx: int in range(0, total_frames, sample_step):
		var byte_offset: int = f_idx * frame_stride
		var amp: float = 0.0
		if bytes_per_sample == 2:
			var raw16: int = wav.data.decode_s16(byte_offset)
			amp = absf(float(raw16) / 32768.0)
			if channels == 2 and byte_offset + 2 < wav.data.size():
				var raw16_r: int = wav.data.decode_s16(byte_offset + 2)
				amp = maxf(amp, absf(float(raw16_r) / 32768.0))
		else:
			var raw8: int = wav.data.decode_s8(byte_offset)
			amp = absf(float(raw8) / 128.0)
			if channels == 2 and byte_offset + 1 < wav.data.size():
				var raw8_r: int = wav.data.decode_s8(byte_offset + 1)
				amp = maxf(amp, absf(float(raw8_r) / 128.0))

		if first_active_frame < 0 and amp >= SILENCE_THRESHOLD:
			first_active_frame = f_idx

		var bin_idx: int = clampi(int((float(f_idx) / float(total_frames)) * float(bin_count)), 0, bin_count - 1)
		if amp > peaks[bin_idx]:
			peaks[bin_idx] = amp

	var leading_silence_ms: float = 0.0
	if first_active_frame >= 0:
		leading_silence_ms = (float(first_active_frame) / float(wav.mix_rate)) * 1000.0
	else:
		leading_silence_ms = (float(total_frames) / float(wav.mix_rate)) * 1000.0

	return {"peaks": peaks, "leading_silence_ms": leading_silence_ms}


static func _decode_via_python_preview(abs_path: String) -> AudioStreamWAV:
	var script_abs: String = ProjectSettings.globalize_path("res://tools/normalize_sfx.py")
	if not FileAccess.file_exists(script_abs):
		return null
	var cache_dir: String = OS.get_user_data_dir().path_join("sfx_lab_cache")
	DirAccess.make_dir_recursive_absolute(cache_dir)
	var cache_wav: String = cache_dir.path_join("%d.wav" % abs_path.hash())
	if not FileAccess.file_exists(cache_wav):
		var args := PackedStringArray([
			script_abs,
			"--input", abs_path,
			"--output", cache_wav,
			"--decode-preview",
		])
		var output: Array = []
		var exit_code: int = OS.execute("python", args, output, true)
		if exit_code != 0:
			return null
	return AudioStreamWAV.load_from_file(cache_wav)

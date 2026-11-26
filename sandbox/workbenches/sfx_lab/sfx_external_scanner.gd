class_name SfxExternalScanner
extends RefCounted
## Escáner recursivo de packs de audio externos y analizador ligero de forma de onda.

const SUPPORTED_EXTENSIONS: Array[String] = ["wav", "ogg", "mp3", "flac", "aiff", "aif", "m4a", "opus"]
const IGNORED_DIRS: Array[String] = [".git", ".godot", "__MACOSX", "node_modules"]
const MAX_CACHE_ENTRIES: int = 96
const MAX_PREVIEW_SECONDS: float = 2.0
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
					if item_name.begins_with("._"):
						item_name = dir.get_next()
						continue
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
		stream = load_wav_fast_native(abs_path, MAX_PREVIEW_SECONDS)
		if stream == null:
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
		return {"stream": null, "duration_ms": 0.0, "sample_rate": 0, "stereo": false, "leading_silence_ms": -1.0, "peaks": PackedFloat32Array(), "decoded_fallback": false, "error": "Formato .%s no soportado en preview en vivo (usable al exportar)" % ext}

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


static func load_wav_fast_native(abs_path: String, max_preview_sec: float = MAX_PREVIEW_SECONDS) -> AudioStreamWAV:
	## Decodificador nativo RIFF/WAV en GDScript puro (8/16/24/32-bit PCM, IEEE float 32-bit y
	## WAVE_FORMAT_EXTENSIBLE) con decimation para 96/192 kHz y tope de lectura para preview instantáneo.
	var f: FileAccess = FileAccess.open(abs_path, FileAccess.READ)
	if f == null:
		return null
	var file_len: int = f.get_length()
	if file_len < 44:
		f.close()
		return null

	var riff_id: String = f.get_buffer(4).get_string_from_ascii()
	var _riff_size: int = f.get_32()
	var wave_id: String = f.get_buffer(4).get_string_from_ascii()
	if riff_id != "RIFF" or wave_id != "WAVE":
		f.close()
		return null

	var found_fmt: bool = false
	var found_data: bool = false
	var audio_format: int = 0
	var channels: int = 0
	var sample_rate: int = 0
	var bits_per_sample: int = 0
	var data_offset: int = 0
	var data_size: int = 0

	while f.get_position() + 8 <= file_len:
		var chunk_id: String = f.get_buffer(4).get_string_from_ascii()
		var chunk_size: int = f.get_32()
		var chunk_start: int = f.get_position()
		if chunk_id == "fmt " and chunk_size >= 16 and chunk_start + 16 <= file_len:
			audio_format = f.get_16()
			channels = f.get_16()
			sample_rate = f.get_32()
			var _byte_rate: int = f.get_32()
			var _block_align: int = f.get_16()
			bits_per_sample = f.get_16()
			if audio_format == 0xFFFE and chunk_size >= 40 and chunk_start + 26 <= file_len:
				f.seek(chunk_start + 24)
				audio_format = f.get_16()
			found_fmt = true
		elif chunk_id == "data":
			data_offset = chunk_start
			data_size = mini(chunk_size, maxi(0, file_len - chunk_start))
			found_data = true

		if found_fmt and found_data:
			break
		var next_pos: int = chunk_start + chunk_size + (chunk_size & 1)
		if next_pos <= chunk_start or next_pos > file_len:
			break
		f.seek(next_pos)

	if not found_fmt or not found_data:
		f.close()
		return null
	if channels < 1 or sample_rate <= 0 or data_size <= 0:
		f.close()
		return null
	var is_pcm: bool = audio_format == 1 and (bits_per_sample == 8 or bits_per_sample == 16 or bits_per_sample == 24 or bits_per_sample == 32)
	var is_f32: bool = audio_format == 3 and bits_per_sample == 32
	if not is_pcm and not is_f32:
		f.close()
		return null

	var bytes_per_sample: int = bits_per_sample / 8
	var frame_bytes: int = channels * bytes_per_sample
	var total_frames: int = data_size / frame_bytes
	if total_frames <= 0:
		f.close()
		return null

	var decimate: int = 1
	if sample_rate > 144000:
		decimate = 4
	elif sample_rate > 72000:
		decimate = 2

	var max_frames: int = int(maxf(0.25, max_preview_sec) * float(sample_rate))
	var frames_to_read: int = mini(total_frames, max_frames)
	if decimate > 1:
		frames_to_read = (frames_to_read / decimate) * decimate
	if frames_to_read <= 0:
		f.close()
		return null

	f.seek(data_offset)
	var raw: PackedByteArray = f.get_buffer(frames_to_read * frame_bytes)
	f.close()
	if raw.size() < frame_bytes:
		return null
	frames_to_read = mini(frames_to_read, raw.size() / frame_bytes)

	var out_channels: int = mini(channels, 2)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = maxi(8000, sample_rate / decimate)
	wav.stereo = (out_channels == 2)

	# Camino rápido para 16-bit PCM mono/estéreo sin decimation
	if audio_format == 1 and bits_per_sample == 16 and decimate == 1 and channels <= 2:
		wav.data = raw
		return wav

	var out_frames: int = frames_to_read / decimate
	if out_frames <= 0:
		return null
	var out := PackedByteArray()
	out.resize(out_frames * out_channels * 2)

	var step_bytes: int = frame_bytes * decimate
	var dst: int = 0
	var src_frame_off: int = 0

	if audio_format == 1 and bits_per_sample == 24:
		for _i: int in range(out_frames):
			out[dst] = raw[src_frame_off + 1]
			out[dst + 1] = raw[src_frame_off + 2]
			dst += 2
			if out_channels == 2:
				out[dst] = raw[src_frame_off + 4]
				out[dst + 1] = raw[src_frame_off + 5]
				dst += 2
			src_frame_off += step_bytes
	elif audio_format == 1 and bits_per_sample == 16:
		for _i: int in range(out_frames):
			out[dst] = raw[src_frame_off]
			out[dst + 1] = raw[src_frame_off + 1]
			dst += 2
			if out_channels == 2:
				out[dst] = raw[src_frame_off + 2]
				out[dst + 1] = raw[src_frame_off + 3]
				dst += 2
			src_frame_off += step_bytes
	elif audio_format == 1 and bits_per_sample == 32:
		for _i: int in range(out_frames):
			out[dst] = raw[src_frame_off + 2]
			out[dst + 1] = raw[src_frame_off + 3]
			dst += 2
			if out_channels == 2:
				out[dst] = raw[src_frame_off + 6]
				out[dst + 1] = raw[src_frame_off + 7]
				dst += 2
			src_frame_off += step_bytes
	elif audio_format == 3 and bits_per_sample == 32:
		for _i: int in range(out_frames):
			var s0: int = clampi(int(roundf(clampf(raw.decode_float(src_frame_off), -1.0, 1.0) * 32767.0)), -32767, 32767)
			out.encode_s16(dst, s0)
			dst += 2
			if out_channels == 2:
				var s1: int = clampi(int(roundf(clampf(raw.decode_float(src_frame_off + 4), -1.0, 1.0) * 32767.0)), -32767, 32767)
				out.encode_s16(dst, s1)
				dst += 2
			src_frame_off += step_bytes
	else:
		# 8-bit unsigned PCM -> 16-bit signed PCM
		for _i: int in range(out_frames):
			var s0_8: int = (int(raw[src_frame_off]) - 128) << 8
			out.encode_s16(dst, clampi(s0_8, -32768, 32767))
			dst += 2
			if out_channels == 2:
				var s1_8: int = (int(raw[src_frame_off + 1]) - 128) << 8
				out.encode_s16(dst, clampi(s1_8, -32768, 32767))
				dst += 2
			src_frame_off += step_bytes

	wav.data = out
	return wav

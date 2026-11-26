extends BaseTestSuite
## Suite aislada para SfxLabCatalog, SfxExternalScanner, SfxExporter (+ normalize_sfx.py)
## y SfxLab UI sin mutar assets/audio/sfx/ ni el manifiesto de usuario.

const CatalogScript = preload("res://sandbox/workbenches/sfx_lab/sfx_lab_catalog.gd")
const ScannerScript = preload("res://sandbox/workbenches/sfx_lab/sfx_external_scanner.gd")
const ExporterScript = preload("res://sandbox/workbenches/sfx_lab/sfx_exporter.gd")
const SfxLabScene: PackedScene = preload("res://sandbox/workbenches/sfx_lab/sfx_lab.tscn")
const SfxLabScript = preload("res://sandbox/workbenches/sfx_lab/sfx_lab.gd")

var _tmp_root_abs: String = ""


func _ready() -> void:
	timeout_seconds = 25.0
	super._ready()
	_tmp_root_abs = OS.get_user_data_dir().path_join("sfx_lab_test_tmp").replace("\\", "/")
	_remove_dir_recursive(_tmp_root_abs)
	DirAccess.make_dir_recursive_absolute(_tmp_root_abs)
	await _run_tests()


func _cleanup_and_quit(exit_code: int) -> void:
	_remove_dir_recursive(_tmp_root_abs)
	await super._cleanup_and_quit(exit_code)


func _await_frames(count: int = 2) -> void:
	for _i: int in range(count):
		await get_tree().process_frame


func _run_tests() -> void:
	var pack_dir: String = _tmp_root_abs.path_join("packs")
	var out_dir: String = _tmp_root_abs.path_join("exported")
	var backup_dir: String = _tmp_root_abs.path_join("backups")
	var manifest_path: String = _tmp_root_abs.path_join("manifest.json")

	var laser_wav: String = pack_dir.path_join("Shapeforms/laser_burst_01.wav")
	var ui_wav: String = pack_dir.path_join("KenneyUI/ui_click_soft.wav")
	_write_test_wav(laser_wav, 44100, 45.0, 90.0, 440.0)
	_write_test_wav(ui_wav, 44100, 0.0, 70.0, 880.0)

	await _test_catalog_and_manifest(manifest_path, laser_wav)
	await _test_scanner_and_silence_detection(pack_dir, laser_wav, ui_wav)
	await _test_exporter_ffmpeg_pipeline(laser_wav, ui_wav, out_dir, backup_dir)
	await _test_sfx_lab_ui(pack_dir, manifest_path, out_dir, backup_dir)

	pass_suite("SfxLab, Scanner, Catalog y Normalizador FFmpeg verificados sin mutar producción")


func _test_catalog_and_manifest(manifest_path: String, sample_wav: String) -> void:
	var specs: Array[Dictionary] = CatalogScript.get_slot_specs()
	assert_true(specs.size() == 32, "El catálogo debe definir 32 slots SFX (11 activos + 12 pendientes + 7 armas + 2 ambience)")

	var active_count: int = 0
	var keys_seen: Dictionary = {}
	for spec: Dictionary in specs:
		var k: String = str(spec.get("key", ""))
		var fname: String = str(spec.get("target_filename", ""))
		assert_true(not k.is_empty() and fname.ends_with(".wav"), "Cada slot debe tener key y .wav destino")
		assert_true(not keys_seen.has(k), "No debe haber keys duplicadas: %s" % k)
		keys_seen[k] = true
		if bool(spec.get("in_audio_manager", false)):
			active_count += 1
	assert_true(active_count == 20, "Debe haber 20 slots activos (11 base + 7 armas + 2 ambience)")

	var man: Dictionary = CatalogScript.create_empty_manifest()
	man["pack_root_dir"] = _tmp_root_abs
	man["favorites"] = [sample_wav]
	var slots: Dictionary = man["slots"] as Dictionary
	var laser_state: Dictionary = slots["laser"] as Dictionary
	laser_state["candidates"] = [sample_wav]
	laser_state["gain_db"] = -2.5
	assert_true(CatalogScript.save_manifest(man, manifest_path) == OK, "save_manifest debe escribir JSON válido")

	var loaded: Dictionary = CatalogScript.load_manifest(manifest_path)
	var loaded_slots: Dictionary = loaded.get("slots", {}) as Dictionary
	var loaded_laser: Dictionary = loaded_slots.get("laser", {}) as Dictionary
	assert_true(is_equal_approx(float(loaded_laser.get("gain_db", 0.0)), -2.5), "load_manifest debe restaurar gain_db")
	assert_true((loaded_laser.get("candidates", []) as Array).size() == 1, "load_manifest debe restaurar candidatos")
	await _await_frames(1)


func _test_scanner_and_silence_detection(pack_dir: String, laser_wav: String, ui_wav: String) -> void:
	assert_true(ScannerScript.normalize_path_input("  \"%s\"  " % pack_dir) == pack_dir.replace("\\", "/"), "normalize_path_input debe limpiar comillas y espacios")
	var scan_res: Dictionary = ScannerScript.scan_directory("\"%s\"" % pack_dir)
	var entries: Array[Dictionary] = scan_res.get("entries", []) as Array[Dictionary]
	var packs: Array[String] = scan_res.get("packs", []) as Array[String]
	assert_true(entries.size() == 2, "scan_directory debe encontrar los 2 WAVs de prueba")
	assert_true(packs.has("Shapeforms") and packs.has("KenneyUI"), "Debe detectar subcarpetas de packs")

	var favs: Dictionary = {ui_wav: true}
	var filtered_q: Array[Dictionary] = ScannerScript.filter_entries(entries, "Todos", "laser", favs, false)
	assert_true(filtered_q.size() == 1 and str(filtered_q[0].get("abs_path", "")) == laser_wav, "Filtro por texto debe encontrar laser_burst_01.wav")
	var filtered_fav: Array[Dictionary] = ScannerScript.filter_entries(entries, "Todos", "", favs, true)
	assert_true(filtered_fav.size() == 1 and str(filtered_fav[0].get("abs_path", "")) == ui_wav, "Filtro favoritos debe retornar solo ui_click_soft.wav")

	var scanner: SfxExternalScanner = ScannerScript.new()
	var info: Dictionary = scanner.load_external_stream(laser_wav)
	assert_true(str(info.get("error", "")).is_empty(), "Carga de WAV externo no debe fallar: %s" % str(info.get("error", "")))
	assert_true(info.get("stream", null) is AudioStreamWAV, "El stream cargado debe ser AudioStreamWAV")
	var peaks: PackedFloat32Array = info.get("peaks", PackedFloat32Array()) as PackedFloat32Array
	assert_true(peaks.size() == 128, "Debe extraer 128 bins de forma de onda")
	assert_true(float(info.get("leading_silence_ms", 0.0)) >= 35.0, "Debe detectar >= 35 ms de silencio inicial en el WAV de prueba")
	await _await_frames(1)


func _test_exporter_ffmpeg_pipeline(laser_wav: String, ui_wav: String, out_dir: String, backup_dir: String) -> void:
	var spec: Dictionary = {}
	for s: Dictionary in CatalogScript.get_slot_specs():
		if str(s.get("key", "")) == "laser":
			spec = s
			break
	var state: Dictionary = {
		"candidates": [laser_wav, ui_wav],
		"gain_db": 0.0,
		"trim_silence": true,
		"mono": true,
	}
	var res1: Dictionary = ExporterScript.export_slot(spec, state, out_dir, backup_dir)
	assert_true(bool(res1.get("ok", false)), "Exportación con normalize_sfx.py debe tener éxito: %s" % str(res1.get("errors", [])))
	var exported_files: Array = res1.get("exported_files", []) as Array
	assert_true(exported_files.size() == 2, "Debe exportar archivo principal y variante _v2")

	var main_out: String = str(exported_files[0])
	assert_true(main_out.ends_with("laser_fire.wav") and FileAccess.file_exists(main_out), "Debe crear laser_fire.wav en carpeta destino")
	var wav_out: AudioStreamWAV = AudioStreamWAV.load_from_file(main_out)
	assert_true(wav_out != null and wav_out.mix_rate == 44100 and not wav_out.stereo, "El WAV exportado debe ser 44.1 kHz Mono")
	var analysis: Dictionary = ScannerScript.extract_wav_analysis(wav_out, 64)
	assert_true(float(analysis.get("leading_silence_ms", 99.0)) < 10.0, "FFmpeg debe recortar el silencio inicial (< 10 ms)")

	# Segunda exportación debe generar backup del archivo previo
	var res2: Dictionary = ExporterScript.export_slot(spec, state, out_dir, backup_dir)
	assert_true(bool(res2.get("ok", false)), "Segunda exportación sobre existente debe tener éxito")
	assert_true(FileAccess.file_exists(backup_dir.path_join("laser_fire.wav")), "Debe crear respaldo automático antes de sobrescribir")
	await _await_frames(1)


func _test_sfx_lab_ui(pack_dir: String, manifest_path: String, out_dir: String, backup_dir: String) -> void:
	var lab: SfxLabScript = SfxLabScene.instantiate() as SfxLabScript
	assert_true(lab != null, "SfxLab debe instanciar desde sfx_lab.tscn")
	add_child(lab)
	await _await_frames(2)

	lab.set_manifest_path_for_test(manifest_path)
	var count: int = lab.scan_external_folder("\"%s\"" % pack_dir)
	assert_true(count == 2, "SfxLab debe escanear 2 archivos de prueba incluso con comillas")

	# Probar descompresión de ZIP de prueba y suma multi-carpeta
	var zip_path: String = _tmp_root_abs.path_join("extra_pack.zip")
	var extra_wav: String = _tmp_root_abs.path_join("raw_extra/explosion_mega.wav")
	_write_test_wav(extra_wav, 44100, 0.0, 220.0, 120.0)
	var zp := ZIPPacker.new()
	if zp.open(zip_path) == OK:
		zp.start_file("Sonniss/explosion_mega.wav")
		zp.write_file(FileAccess.get_file_as_bytes(extra_wav))
		zp.close_file()
		zp.close()
	var unpack_res: Dictionary = lab.unpack_detected_zips(_tmp_root_abs.path_join("unpacked"), [zip_path])
	assert_true(bool(unpack_res.get("ok", false)), "unpack_detected_zips debe extraer ZIP sin errores")
	assert_true(lab._all_entries.size() == 3, "Tras descomprimir ZIP deben verse 3 archivos acumulados")

	# Probar Perfiles Combinados 1-Clic, Alternativa y Tour del Perfil
	var armed: int = lab.apply_combined_profile("hibrido_stela", false)
	assert_true(armed >= 10, "apply_combined_profile debe armar múltiples slots automáticamente (actual: %d)" % armed)
	lab.select_slot_by_key("laser")
	lab.cycle_slot_suggestion_alternative()
	assert_true(lab.start_profile_tour(), "start_profile_tour debe iniciar la secuencia de audición")
	await _await_frames(2)
	lab.stop_all_audio()

	lab.select_slot_by_key("laser")
	lab.select_candidate_index(0)
	assert_true(lab.audition_selected(), "audition_selected debe reproducir el candidato actual")
	assert_true(lab.stage_selected_candidate(), "stage_selected_candidate debe asignar candidato al slot")
	assert_true(lab.assign_selected_as_layer2(), "assign_selected_as_layer2 debe asignar Capa 2")
	assert_true(lab.audition_layered_slot(), "audition_layered_slot debe reproducir Capas 1+2")
	assert_true(lab.run_candidate_suggester() == 3, "run_candidate_suggester debe analizar los 3 archivos")
	lab.toggle_burst_preview(false)
	await _await_frames(2)
	lab.stop_all_audio()

	var exp_res: Dictionary = lab.export_current_slot(out_dir, backup_dir)
	assert_true(bool(exp_res.get("ok", false)), "export_current_slot desde SfxLab debe completarse sin errores")
	assert_true(FileAccess.file_exists(out_dir.path_join("laser_fire_layer2.wav")), "Debe exportar laser_fire_layer2.wav cuando hay Capa 2")

	lab.queue_free()
	await _await_frames(2)


func _write_test_wav(abs_path: String, sample_rate: int, silence_ms: float, tone_ms: float, freq_hz: float) -> void:
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	var sil_samples: int = int(roundf((silence_ms / 1000.0) * float(sample_rate)))
	var tone_samples: int = int(roundf((tone_ms / 1000.0) * float(sample_rate)))
	var total_samples: int = sil_samples + tone_samples
	var data_bytes: int = total_samples * 2

	var buf := PackedByteArray()
	buf.resize(44 + data_bytes)
	# RIFF header
	buf.encode_u8(0, 82); buf.encode_u8(1, 73); buf.encode_u8(2, 70); buf.encode_u8(3, 70) # "RIFF"
	buf.encode_u32(4, 36 + data_bytes)
	buf.encode_u8(8, 87); buf.encode_u8(9, 65); buf.encode_u8(10, 86); buf.encode_u8(11, 69) # "WAVE"
	# fmt chunk
	buf.encode_u8(12, 102); buf.encode_u8(13, 109); buf.encode_u8(14, 116); buf.encode_u8(15, 32) # "fmt "
	buf.encode_u32(16, 16) # PCM chunk size
	buf.encode_u16(20, 1)  # PCM format
	buf.encode_u16(22, 1)  # Mono
	buf.encode_u32(24, sample_rate)
	buf.encode_u32(28, sample_rate * 2)
	buf.encode_u16(32, 2)
	buf.encode_u16(34, 16)
	# data chunk
	buf.encode_u8(36, 100); buf.encode_u8(37, 97); buf.encode_u8(38, 116); buf.encode_u8(39, 97) # "data"
	buf.encode_u32(40, data_bytes)

	for i: int in range(tone_samples):
		var t: float = float(i) / float(sample_rate)
		var env: float = exp(-t * 14.0)
		var sample_f: float = sin(TAU * freq_hz * t) * 0.5 * env
		var s16: int = clampi(int(roundf(sample_f * 32767.0)), -32767, 32767)
		buf.encode_s16(44 + (sil_samples + i) * 2, s16)

	var f: FileAccess = FileAccess.open(abs_path, FileAccess.WRITE)
	if f != null:
		f.store_buffer(buf)
		f.close()


func _remove_dir_recursive(dir_abs: String) -> void:
	if dir_abs.is_empty() or not DirAccess.dir_exists_absolute(dir_abs):
		return
	var d: DirAccess = DirAccess.open(dir_abs)
	if d == null:
		return
	d.list_dir_begin()
	var item: String = d.get_next()
	while not item.is_empty():
		if item != "." and item != "..":
			var full: String = dir_abs.path_join(item)
			if d.current_is_dir():
				_remove_dir_recursive(full)
			else:
				DirAccess.remove_absolute(full)
		item = d.get_next()
	d.list_dir_end()
	DirAccess.remove_absolute(dir_abs)

class_name SfxLab
extends Control
## Laboratorio interactivo para explorar packs externos de SFX, comparar A/B con producción,
## simular ráfagas de combate / combo EXP y exportar WAVs normalizados.

const CatalogScript = preload("res://sandbox/workbenches/sfx_lab/sfx_lab_catalog.gd")
const ScannerScript = preload("res://sandbox/workbenches/sfx_lab/sfx_external_scanner.gd")
const WaveformScript = preload("res://sandbox/workbenches/sfx_lab/sfx_waveform_preview.gd")
const AuditionEngineScript = preload("res://sandbox/workbenches/sfx_lab/sfx_audition_engine.gd")
const ExporterScript = preload("res://sandbox/workbenches/sfx_lab/sfx_exporter.gd")
const WORKBENCH_HUB_PATH: String = "res://sandbox/workbenches/workbench_hub.tscn"
const COMBAT_GYM_PATH: String = "res://sandbox/combat_gym/combat_gym.tscn"

var _scanner: SfxExternalScanner = ScannerScript.new()
var _audition: SfxAuditionEngine = null
var _waveform: SfxWaveformPreview = null

var _slot_specs: Array[Dictionary] = []
var _profile_specs: Array[Dictionary] = []
var _curated_presets: Dictionary = {}
var _custom_presets: Dictionary = {}
var _manifest: Dictionary = {}
var _manifest_path: String = CatalogScript.DEFAULT_MANIFEST_PATH
var _custom_presets_path: String = CatalogScript.DEFAULT_CUSTOM_PRESETS_PATH
var _favorites_set: Dictionary = {} # abs_path -> true

var _pack_dirs: Array[String] = []
var _detected_zips: Array[String] = []
var _all_entries: Array[Dictionary] = []
var _filtered_entries: Array[Dictionary] = []
var _available_packs: Array[String] = []
var _selected_slot_key: String = "laser"
var _selected_candidate_abs: String = ""
var _current_stream_info: Dictionary = {}
var _suggestions_by_slot: Dictionary = {} # slot_key -> Array[Dictionary]
var _profiles_by_id: Dictionary = {}      # profile_id -> Dictionary
var _slot_alt_cursor: Dictionary = {}     # slot_key -> int

# Referencias UI
var _dir_dialog: FileDialog = null
var _file_dialog: FileDialog = null
var _path_edit: LineEdit = null
var _unpack_zips_btn: Button = null
var _bgm_opt: OptionButton = null
var _step_progress_lbl: Label = null
var _preset_desc_lbl: Label = null
var _preset_buttons: Dictionary = {} # preset_id -> Button
var _tour_btn: Button = null
var _slot_filter_opt: OptionButton = null
var _slot_list: ItemList = null
var _slot_info_lbl: Label = null
var _keywords_row: HFlowContainer = null

var _browser_hdr_lbl: Label = null
var _pack_opt: OptionButton = null
var _search_edit: LineEdit = null
var _fav_only_check: CheckBox = null
var _auto_preview_check: CheckBox = null
var _files_count_lbl: Label = null
var _files_list: ItemList = null

var _selected_file_lbl: Label = null
var _fav_btn: Button = null
var _burst_btn: Button = null
var _suggestions_opt: OptionButton = null
var _layer2_lbl: Label = null
var _gain_slider: HSlider = null
var _gain_val_lbl: Label = null
var _pitch_slider: HSlider = null
var _pitch_val_lbl: Label = null
var _jitter_slider: HSlider = null
var _jitter_val_lbl: Label = null
var _trim_check: CheckBox = null
var _mono_check: CheckBox = null
var _staged_list: ItemList = null
var _status_lbl: Label = null

var _suppress_ui_signals: bool = false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_slot_specs = CatalogScript.get_slot_specs()
	_profile_specs = CatalogScript.get_profile_specs()
	_curated_presets = CatalogScript.load_curated_presets()
	_custom_presets = CatalogScript.load_custom_presets(_custom_presets_path)
	_manifest = CatalogScript.load_manifest(_manifest_path)
	_sync_favorites_from_manifest()
	_sync_pack_dirs_from_manifest()

	_audition = AuditionEngineScript.new()
	_audition.name = "SfxAuditionEngine"
	add_child(_audition)
	_audition.playhead_updated.connect(_on_playhead_updated)
	_audition.playback_event.connect(_on_playback_event)
	_audition.tour_step_changed.connect(_on_tour_step_changed)
	_audition.tour_finished.connect(_on_tour_finished)

	_build_ui()
	_refresh_slot_list()
	_refresh_preset_bar_buttons()
	_update_progress_banner()

	var vp: Viewport = get_viewport()
	if vp != null and vp.has_signal(&"files_dropped"):
		if not vp.files_dropped.is_connected(_on_files_dropped):
			vp.files_dropped.connect(_on_files_dropped)

	if _pack_dirs.is_empty() and DisplayServer.get_name() != "headless":
		var bundled_dir: String = ProjectSettings.globalize_path(CatalogScript.BUNDLED_PACKS_DIR).replace("\\", "/")
		var downloads_packs_dir: String = OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS).path_join("Stela_SFX_Packs").replace("\\", "/")
		if DirAccess.dir_exists_absolute(bundled_dir):
			_pack_dirs.append(bundled_dir)
		elif DirAccess.dir_exists_absolute(downloads_packs_dir):
			_pack_dirs.append(downloads_packs_dir)

	if not _pack_dirs.is_empty():
		_path_edit.text = "; ".join(_pack_dirs)
		_rescan_pack_dirs(false)
		if DisplayServer.get_name() != "headless" and _count_staged_slots() == 0 and _curated_presets.has("stela_signature"):
			apply_curated_preset("stela_signature", false, false)

	select_slot_by_key(_selected_slot_key, false)
	if DisplayServer.get_name() != "headless" and _slot_list != null:
		_slot_list.grab_focus()


func set_manifest_path_for_test(path: String) -> void:
	_manifest_path = path
	_manifest = CatalogScript.load_manifest(_manifest_path)
	_sync_favorites_from_manifest()
	_sync_pack_dirs_from_manifest()
	_refresh_slot_list()
	_refresh_slot_inspector()
	_update_progress_banner()


func _input(event: InputEvent) -> void:
	var key_ev := event as InputEventKey
	if key_ev == null or not key_ev.pressed or key_ev.echo:
		return

	var focus_owner: Control = get_viewport().gui_get_focus_owner()
	if focus_owner is LineEdit:
		if key_ev.keycode == KEY_ESCAPE:
			focus_owner.release_focus()
			get_viewport().set_input_as_handled()
		return

	match key_ev.keycode:
		KEY_SPACE:
			audition_selected()
			get_viewport().set_input_as_handled()
		KEY_A:
			audition_production()
			get_viewport().set_input_as_handled()
		KEY_R:
			toggle_burst_preview(false)
			get_viewport().set_input_as_handled()
		KEY_S, KEY_BACKSPACE:
			stop_all_audio()
			_set_status("Audio detenido [S].")
			get_viewport().set_input_as_handled()
		KEY_F:
			toggle_favorite_selected()
			get_viewport().set_input_as_handled()
		KEY_ENTER, KEY_KP_ENTER:
			replace_main_candidate()
			get_viewport().set_input_as_handled()
		KEY_ESCAPE:
			_return_to_hub()
			get_viewport().set_input_as_handled()


func scan_external_folder(dir_path: String) -> int:
	var clean_dir: String = ScannerScript.normalize_path_input(dir_path)
	_pack_dirs.clear()
	if not clean_dir.is_empty() and DirAccess.dir_exists_absolute(clean_dir):
		_pack_dirs.append(clean_dir)
	return _rescan_pack_dirs(false)


func add_external_folder(dir_path: String) -> int:
	var clean_dir: String = ScannerScript.normalize_path_input(dir_path)
	if clean_dir.is_empty():
		return _all_entries.size()
	if not DirAccess.dir_exists_absolute(clean_dir):
		_set_status("Carpeta no encontrada: %s (verificá comillas o descomprimí si es .zip)." % clean_dir)
		return _all_entries.size()
	if not _pack_dirs.has(clean_dir):
		_pack_dirs.append(clean_dir)
	return _rescan_pack_dirs(false)


func clear_external_folders() -> void:
	_pack_dirs.clear()
	_detected_zips.clear()
	_all_entries.clear()
	_filtered_entries.clear()
	_available_packs.clear()
	_suggestions_by_slot.clear()
	_profiles_by_id.clear()
	_manifest["pack_root_dir"] = ""
	_manifest["pack_dirs"] = [] as Array[String]
	_path_edit.text = ""
	_pack_opt.clear()
	_pack_opt.add_item("Todos")
	_apply_file_filters()
	_refresh_zip_button()
	_refresh_layer2_and_suggestions()
	_update_progress_banner()
	_set_status("Lista de carpetas limpiada. Agregá carpetas o arrastralas a la ventana.")


func _rescan_pack_dirs(auto_suggest: bool = false) -> int:
	_scanner.clear_cache()
	var valid_dirs: Array[String] = []
	for d: String in _pack_dirs:
		if DirAccess.dir_exists_absolute(d):
			valid_dirs.append(d)
	_pack_dirs = valid_dirs
	_manifest["pack_dirs"] = _pack_dirs.duplicate()
	_manifest["pack_root_dir"] = _pack_dirs[0] if not _pack_dirs.is_empty() else ""
	_path_edit.text = "; ".join(_pack_dirs)

	var res: Dictionary = ScannerScript.scan_directories(_pack_dirs)
	_all_entries = res.get("entries", []) as Array[Dictionary]
	_available_packs = res.get("packs", []) as Array[String]
	_detected_zips = res.get("zip_files", []) as Array[String]

	_suppress_ui_signals = true
	_pack_opt.clear()
	_pack_opt.add_item("Todos")
	for pack_name: String in _available_packs:
		_pack_opt.add_item(pack_name)
	_pack_opt.select(0)
	_suppress_ui_signals = false

	_apply_file_filters()
	_refresh_zip_button()
	if auto_suggest and not _all_entries.is_empty():
		run_candidate_suggester()
	_update_progress_banner()

	var truncated: bool = bool(res.get("truncated", false))
	var zip_note: String = " · %d .zip detectado(s)" % _detected_zips.size() if not _detected_zips.is_empty() else ""
	var note: String = " (límite 8000 alcanzado)" if truncated else ""
	if _all_entries.is_empty():
		_set_status("Sin audios sueltos en %d carpeta(s)%s. Si están comprimidos, pulsá 'Descomprimir ZIPs'." % [_pack_dirs.size(), zip_note])
	else:
		_set_status("Listo: %d audios en %d pack(s)%s%s. Elegí un Preset arriba y usá ↑/↓ en Columna 1." % [_all_entries.size(), _available_packs.size(), zip_note, note])
	return _all_entries.size()


func select_slot_by_key(slot_key: String, auto_play: bool = false) -> void:
	_selected_slot_key = slot_key
	for i: int in range(_slot_list.item_count):
		var meta: String = str(_slot_list.get_item_metadata(i))
		if meta == slot_key:
			_suppress_ui_signals = true
			_slot_list.select(i)
			_slot_list.ensure_current_is_visible()
			_suppress_ui_signals = false
			break
	_refresh_slot_inspector()
	_load_slot_main_into_deck(auto_play)


func _load_slot_main_into_deck(auto_play: bool = false) -> void:
	var st: Dictionary = _get_current_slot_state()
	var cands: Array = st.get("candidates", []) as Array
	var main_path: String = str(cands[0]) if not cands.is_empty() else ""
	if not main_path.is_empty() and FileAccess.file_exists(main_path):
		_selected_candidate_abs = main_path
		_selected_file_lbl.text = "[PRESET · Main] %s" % main_path.get_file()
		_selected_file_lbl.add_theme_color_override("font_color", Color(0.45, 0.96, 0.78, 1.0))
		_update_fav_button_label()
		_current_stream_info = _scanner.load_external_stream(main_path)
		_waveform.set_analysis(_current_stream_info)
		if _staged_list != null and _staged_list.item_count > 0:
			_suppress_ui_signals = true
			_staged_list.select(0)
			_suppress_ui_signals = false
		if auto_play:
			var l2: String = str(st.get("layer2_candidate", "")).strip_edges()
			if not l2.is_empty() and FileAccess.file_exists(l2):
				audition_layered_slot()
			else:
				audition_selected()
	else:
		_selected_candidate_abs = ""
		_current_stream_info = {}
		_selected_file_lbl.text = "[%s] Sin sonido asignado (elegí uno en Columna 2)" % _selected_slot_key
		_selected_file_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.90, 0.85))
		_update_fav_button_label()
		if _waveform != null:
			_waveform.clear_preview("Este slot no tiene reemplazo asignado. Pulsá [A] para oír Producción actual.")


func select_candidate_index(idx: int) -> void:
	if idx < 0 or idx >= _filtered_entries.size():
		_selected_candidate_abs = ""
		_current_stream_info = {}
		_waveform.clear_preview("Sin archivo seleccionado.")
		return
	var entry: Dictionary = _filtered_entries[idx]
	_selected_candidate_abs = str(entry.get("abs_path", ""))
	_suppress_ui_signals = true
	_files_list.select(idx)
	_suppress_ui_signals = false

	_selected_file_lbl.text = "[LIBRERÍA · sin asignar] %s" % str(entry.get("rel_path", _selected_candidate_abs.get_file()))
	_selected_file_lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.45, 1.0))
	_update_fav_button_label()
	_current_stream_info = _scanner.load_external_stream(_selected_candidate_abs)
	_waveform.set_analysis(_current_stream_info)
	if _auto_preview_check.button_pressed and DisplayServer.get_name() != "headless":
		audition_selected()


func audition_selected() -> bool:
	if _selected_candidate_abs.is_empty():
		var st_fallback: Dictionary = _get_current_slot_state()
		var cands_fb: Array = st_fallback.get("candidates", []) as Array
		if not cands_fb.is_empty():
			var first_cand: String = str(cands_fb[0])
			if FileAccess.file_exists(first_cand):
				_selected_candidate_abs = first_cand
				_selected_file_lbl.text = first_cand.get_file()
				_current_stream_info = _scanner.load_external_stream(first_cand)
				_waveform.set_analysis(_current_stream_info)
	if _selected_candidate_abs.is_empty():
		return audition_production()
	if _current_stream_info.is_empty():
		_current_stream_info = _scanner.load_external_stream(_selected_candidate_abs)
		_waveform.set_analysis(_current_stream_info)
	var stream: AudioStream = _current_stream_info.get("stream", null) as AudioStream
	if stream == null:
		_set_status("Error al reproducir: %s" % str(_current_stream_info.get("error", "stream nulo")))
		return false
	_audition.stop_burst()
	_audition.stop_tour()
	_burst_btn.text = "▶ Ráfaga [R]"
	if _tour_btn != null:
		_tour_btn.text = "▶ Tour (9 clave)"
	var st: Dictionary = _get_current_slot_state()
	var pitch: float = float(st.get("pitch_base", 1.0))
	var gain_db: float = float(st.get("gain_db", 0.0))
	_audition.play_stream_once(stream, pitch, gain_db, true, true)
	return true


func audition_production() -> bool:
	_burst_btn.text = "▶ Ráfaga [R]"
	if _tour_btn != null:
		_tour_btn.text = "▶ Tour (9 clave)"
	if _selected_file_lbl != null:
		_selected_file_lbl.text = "[PROD ACTUAL] %s" % _selected_slot_key
		_selected_file_lbl.add_theme_color_override("font_color", Color(0.75, 0.88, 1.0, 1.0))
	var ok: bool = _audition.play_production_slot(_selected_slot_key)
	if not ok:
		_set_status("El slot '%s' aún no tiene audio cargado en AudioManager." % _selected_slot_key)
	return ok


func toggle_burst_preview(force_exp_combo: bool = false) -> void:
	if _audition.is_burst_active() and not force_exp_combo:
		_audition.stop_burst()
		_burst_btn.text = "▶ Ráfaga Combate [R]"
		return

	var spec: Dictionary = _get_slot_spec(_selected_slot_key)
	var st: Dictionary = _get_current_slot_state()
	var streams: Array[AudioStream] = _collect_staged_streams(st)
	if streams.is_empty() and not _selected_candidate_abs.is_empty():
		var info: Dictionary = _scanner.load_external_stream(_selected_candidate_abs)
		var s: AudioStream = info.get("stream", null) as AudioStream
		if s != null:
			streams.append(s)
	if streams.is_empty():
		_set_status("Seleccioná o asigná al menos un sonido antes de probar ráfaga.")
		return

	var rate_hz: float = float(spec.get("burst_hz", 4.0))
	var use_combo: bool = force_exp_combo or bool(spec.get("use_combo", false))
	_audition.start_burst(
		streams,
		rate_hz,
		float(st.get("pitch_base", 1.0)),
		float(st.get("pitch_jitter", 0.08)),
		float(st.get("gain_db", 0.0)),
		use_combo
	)
	_burst_btn.text = "■ Detener Ráfaga [R]"


func stop_all_audio() -> void:
	_audition.stop_all()
	_burst_btn.text = "▶ Ráfaga [R]"
	if _tour_btn != null:
		_tour_btn.text = "▶ Tour (9 clave)"


func toggle_favorite_selected() -> bool:
	if _selected_candidate_abs.is_empty():
		return false
	if _favorites_set.has(_selected_candidate_abs):
		_favorites_set.erase(_selected_candidate_abs)
	else:
		_favorites_set[_selected_candidate_abs] = true
	_sync_manifest_from_favorites()
	_update_fav_button_label()
	_apply_file_filters()
	return _favorites_set.has(_selected_candidate_abs)


func replace_main_candidate() -> bool:
	if _selected_candidate_abs.is_empty():
		_set_status("Elegí primero un sonido de la Columna 2 para reemplazar [%s]." % _selected_slot_key)
		return false
	var st: Dictionary = _get_current_slot_state()
	var cands: Array[String] = []
	for c_v: Variant in (st.get("candidates", []) as Array):
		var s: String = str(c_v)
		if not s.is_empty():
			cands.append(s)
	if cands.is_empty():
		cands.append(_selected_candidate_abs)
	else:
		cands.erase(_selected_candidate_abs)
		if cands.is_empty():
			cands.append(_selected_candidate_abs)
		else:
			cands[0] = _selected_candidate_abs
	st["candidates"] = cands
	_selected_file_lbl.text = "[PRESET · Main] %s" % _selected_candidate_abs.get_file()
	_selected_file_lbl.add_theme_color_override("font_color", Color(0.45, 0.96, 0.78, 1.0))
	_refresh_staged_list()
	_refresh_slot_list()
	_update_progress_banner()
	_set_status("Reemplazado [Main] de [%s] → %s" % [_selected_slot_key, _selected_candidate_abs.get_file()])
	return true


func stage_selected_candidate() -> bool:
	if _selected_candidate_abs.is_empty():
		return false
	var st: Dictionary = _get_current_slot_state()
	var cands: Array[String] = []
	for c_v: Variant in (st.get("candidates", []) as Array):
		var s: String = str(c_v)
		if not s.is_empty():
			cands.append(s)
	if not cands.has(_selected_candidate_abs):
		cands.append(_selected_candidate_abs)
		st["candidates"] = cands
	_refresh_staged_list()
	_refresh_slot_list()
	_update_progress_banner()
	_set_status("Variante agregada a [%s]: %s (%d total)." % [_selected_slot_key, _selected_candidate_abs.get_file(), cands.size()])
	return true


func unstage_selected_candidate() -> bool:
	var sel: PackedInt32Array = _staged_list.get_selected_items()
	if sel.is_empty():
		return false
	var idx: int = sel[0]
	var st: Dictionary = _get_current_slot_state()
	var cands: Array[String] = []
	for c_v: Variant in (st.get("candidates", []) as Array):
		var s: String = str(c_v)
		if not s.is_empty():
			cands.append(s)
	if idx >= 0 and idx < cands.size():
		cands.remove_at(idx)
		st["candidates"] = cands
		_refresh_staged_list()
		_refresh_slot_list()
		_update_progress_banner()
		_set_status("Candidato quitado de [%s]." % _selected_slot_key)
		return true
	return false


func export_current_slot(target_dir_override: String = "", backup_dir_override: String = "") -> Dictionary:
	var spec: Dictionary = _get_slot_spec(_selected_slot_key)
	var st: Dictionary = _get_current_slot_state()
	var res: Dictionary = ExporterScript.export_slot(spec, st, target_dir_override, backup_dir_override)
	if bool(res.get("ok", false)):
		var files: Array[String] = res.get("exported_files", []) as Array[String]
		_set_status("Exportado [%s]: %d archivo(s) WAV normalizado(s)." % [_selected_slot_key, files.size()])
	else:
		var errs: Array[String] = res.get("errors", []) as Array[String]
		_set_status("Error exportando [%s]: %s" % [_selected_slot_key, "; ".join(errs)])
	return res


func export_all_staged(target_dir_override: String = "", backup_dir_override: String = "") -> Dictionary:
	var total_files: int = 0
	var exported_slots: int = 0
	var all_errors: Array[String] = []
	var slots_dict: Dictionary = _manifest.get("slots", {}) as Dictionary

	for spec: Dictionary in _slot_specs:
		var key: String = str(spec.get("key", ""))
		var st: Dictionary = slots_dict.get(key, {}) as Dictionary
		var cands: Array = st.get("candidates", []) as Array
		if cands.is_empty():
			continue
		var res: Dictionary = ExporterScript.export_slot(spec, st, target_dir_override, backup_dir_override)
		if bool(res.get("ok", false)):
			exported_slots += 1
			total_files += (res.get("exported_files", []) as Array).size()
		else:
			for err_v: Variant in (res.get("errors", []) as Array):
				all_errors.append("[%s] %s" % [key, str(err_v)])

	if exported_slots == 0 and all_errors.is_empty():
		_set_status("No hay slots con candidatos asignados para exportar.")
	elif all_errors.is_empty():
		_set_status("Exportación completa: %d slot(s), %d WAV(s) en assets/audio/sfx/." % [exported_slots, total_files])
	else:
		_set_status("Exportado con errores (%d ok, %d fallos): %s" % [exported_slots, all_errors.size(), all_errors[0]])

	return {"ok": all_errors.is_empty() and exported_slots > 0, "exported_slots": exported_slots, "total_files": total_files, "errors": all_errors}


func save_curation_manifest() -> Error:
	var err: Error = CatalogScript.save_manifest(_manifest, _manifest_path)
	if err == OK:
		_set_status("Curación guardada en %s." % _manifest_path)
	else:
		_set_status("Error al guardar curación (código %d)." % int(err))
	return err


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.025, 0.035, 0.06, 1.0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_theme_constant_override("separation", 10)
	margin.add_child(root_vbox)

	# --- Barra superior ---
	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 8)
	root_vbox.add_child(top_bar)

	var title := Label.new()
	title.text = "STELA GALACTICA — SFX LAB"
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", Color(0.68, 0.56, 1.0, 1.0))
	top_bar.add_child(title)

	var pick_btn := Button.new()
	pick_btn.text = "+ Carpeta..."
	pick_btn.focus_mode = Control.FOCUS_NONE
	pick_btn.pressed.connect(_open_folder_dialog)
	top_bar.add_child(pick_btn)

	var zip_pick_btn := Button.new()
	zip_pick_btn.text = "+ ZIP / Audio..."
	zip_pick_btn.focus_mode = Control.FOCUS_NONE
	zip_pick_btn.pressed.connect(_open_file_dialog)
	top_bar.add_child(zip_pick_btn)

	var dl_btn := Button.new()
	dl_btn.text = "Packs"
	dl_btn.focus_mode = Control.FOCUS_NONE
	dl_btn.pressed.connect(func() -> void:
		var bundled_dir: String = ProjectSettings.globalize_path(CatalogScript.BUNDLED_PACKS_DIR).replace("\\", "/")
		var dl_dir: String = OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
		var packs_dir: String = dl_dir.path_join("Stela_SFX_Packs")
		if DirAccess.dir_exists_absolute(bundled_dir):
			add_external_folder(bundled_dir)
		elif DirAccess.dir_exists_absolute(packs_dir):
			add_external_folder(packs_dir)
		elif not dl_dir.is_empty():
			add_external_folder(dl_dir)
	)
	top_bar.add_child(dl_btn)

	_path_edit = LineEdit.new()
	_path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_path_edit.placeholder_text = "Arrastrá carpetas/.zip aquí o pegá ruta (con o sin comillas)..."
	_path_edit.text_submitted.connect(func(new_text: String) -> void:
		_handle_path_submit(new_text)
		_path_edit.release_focus()
	)
	top_bar.add_child(_path_edit)

	var scan_btn := Button.new()
	scan_btn.text = "+ Agregar"
	scan_btn.focus_mode = Control.FOCUS_NONE
	scan_btn.pressed.connect(func() -> void: _handle_path_submit(_path_edit.text))
	top_bar.add_child(scan_btn)

	_unpack_zips_btn = Button.new()
	_unpack_zips_btn.text = "Descomprimir ZIPs (0)"
	_unpack_zips_btn.focus_mode = Control.FOCUS_NONE
	_unpack_zips_btn.visible = false
	_unpack_zips_btn.pressed.connect(func() -> void: unpack_detected_zips())
	top_bar.add_child(_unpack_zips_btn)

	var clr_packs_btn := Button.new()
	clr_packs_btn.text = "Limpiar"
	clr_packs_btn.focus_mode = Control.FOCUS_NONE
	clr_packs_btn.pressed.connect(clear_external_folders)
	top_bar.add_child(clr_packs_btn)

	var bgm_lbl := Label.new()
	bgm_lbl.text = "BGM:"
	top_bar.add_child(bgm_lbl)

	_bgm_opt = OptionButton.new()
	_bgm_opt.focus_mode = Control.FOCUS_NONE
	_bgm_opt.add_item("Off")
	_bgm_opt.add_item("Combat")
	_bgm_opt.add_item("Menu")
	_bgm_opt.item_selected.connect(func(idx: int) -> void:
		var modes: Array[String] = ["off", "combat", "menu"]
		_audition.set_bgm_mode(modes[clampi(idx, 0, modes.size() - 1)])
	)
	top_bar.add_child(_bgm_opt)

	var hub_btn := Button.new()
	hub_btn.text = "Hub [Esc]"
	hub_btn.focus_mode = Control.FOCUS_NONE
	hub_btn.pressed.connect(_return_to_hub)
	top_bar.add_child(hub_btn)

	# --- Barra guía + Presets 1-Clic ---
	var guide_panel := PanelContainer.new()
	var g_style := StyleBoxFlat.new()
	g_style.bg_color = Color(0.06, 0.08, 0.16, 0.96)
	g_style.border_color = Color(0.55, 0.42, 0.98, 0.6)
	g_style.set_border_width_all(1)
	g_style.set_corner_radius_all(6)
	g_style.set_content_margin_all(7)
	guide_panel.add_theme_stylebox_override("panel", g_style)
	root_vbox.add_child(guide_panel)

	var guide_vbox := VBoxContainer.new()
	guide_vbox.add_theme_constant_override("separation", 5)
	guide_panel.add_child(guide_vbox)

	var preset_row := HBoxContainer.new()
	preset_row.add_theme_constant_override("separation", 6)
	guide_vbox.add_child(preset_row)

	var pres_lbl := Label.new()
	pres_lbl.text = "PRESETS:"
	pres_lbl.add_theme_font_size_override("font_size", 12)
	pres_lbl.add_theme_color_override("font_color", Color(0.45, 0.96, 0.85, 1.0))
	preset_row.add_child(pres_lbl)

	_preset_buttons.clear()
	var preset_defs: Array[Array] = [
		["stela_signature", "1. Stela Signature"],
		["anime_sakuga", "2. Anime Sakuga"],
		["cyberpunk_tactico", "3. Cyberpunk"],
		["cosmos_cinematico", "4. Cosmos"],
		["zen_antifatiga", "5. Zen"],
		["custom_user", "☆ Custom"],
	]
	for p_def: Array in preset_defs:
		var pid: String = str(p_def[0])
		var p_btn := Button.new()
		p_btn.text = str(p_def[1])
		p_btn.toggle_mode = true
		p_btn.focus_mode = Control.FOCUS_NONE
		p_btn.pressed.connect(func() -> void:
			apply_curated_preset(pid, false, _auto_preview_check != null and _auto_preview_check.button_pressed)
			if _slot_list != null:
				_slot_list.grab_focus()
		)
		preset_row.add_child(p_btn)
		_preset_buttons[pid] = p_btn

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preset_row.add_child(spacer)

	_tour_btn = Button.new()
	_tour_btn.text = "▶ Tour (9 clave)"
	_tour_btn.focus_mode = Control.FOCUS_NONE
	_tour_btn.pressed.connect(func() -> void:
		if _audition.is_tour_active():
			_audition.stop_tour()
		else:
			start_profile_tour()
	)
	preset_row.add_child(_tour_btn)

	var top_stop_btn := Button.new()
	top_stop_btn.text = "■ Stop [S]"
	top_stop_btn.focus_mode = Control.FOCUS_NONE
	top_stop_btn.pressed.connect(stop_all_audio)
	preset_row.add_child(top_stop_btn)

	var save_custom_btn := Button.new()
	save_custom_btn.text = "★ Guardar Custom"
	save_custom_btn.focus_mode = Control.FOCUS_NONE
	save_custom_btn.pressed.connect(func() -> void: save_current_as_custom_preset())
	preset_row.add_child(save_custom_btn)

	var gym_btn := Button.new()
	gym_btn.text = "Combat Gym"
	gym_btn.focus_mode = Control.FOCUS_NONE
	gym_btn.pressed.connect(_open_combat_gym)
	preset_row.add_child(gym_btn)

	var guide_subrow := HBoxContainer.new()
	guide_subrow.add_theme_constant_override("separation", 10)
	guide_vbox.add_child(guide_subrow)

	_step_progress_lbl = Label.new()
	_step_progress_lbl.text = "Packs: 0 · Armados: 0/32"
	_step_progress_lbl.add_theme_font_size_override("font_size", 11)
	_step_progress_lbl.add_theme_color_override("font_color", Color(0.55, 0.96, 0.80, 1.0))
	guide_subrow.add_child(_step_progress_lbl)

	_preset_desc_lbl = Label.new()
	_preset_desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preset_desc_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_preset_desc_lbl.text = "Usá ↑/↓ en Columna 1 para escuchar cada slot del preset · [Space] Nuevo · [A] Prod Actual · [S] Stop"
	_preset_desc_lbl.add_theme_font_size_override("font_size", 11)
	_preset_desc_lbl.add_theme_color_override("font_color", Color(0.78, 0.86, 0.96, 0.92))
	guide_subrow.add_child(_preset_desc_lbl)

	# --- Cuerpo principal de 3 columnas ---
	var columns := HBoxContainer.new()
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 10)
	root_vbox.add_child(columns)

	_build_left_slots_panel(columns)
	_build_center_browser_panel(columns)
	_build_right_deck_panel(columns)

	# --- Barra inferior de estado ---
	_status_lbl = Label.new()
	_status_lbl.text = "Listo. Elegí una carpeta externa de packs SFX o escuchá los actuales de producción con [A]."
	_status_lbl.add_theme_font_size_override("font_size", 12)
	_status_lbl.add_theme_color_override("font_color", Color(0.55, 0.96, 0.72, 0.95))
	root_vbox.add_child(_status_lbl)

	_dir_dialog = FileDialog.new()
	_dir_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	_dir_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_dir_dialog.use_native_dialog = false
	_dir_dialog.title = "Seleccionar carpeta con packs de SFX"
	_dir_dialog.dir_selected.connect(func(dir: String) -> void:
		add_external_folder(dir)
	)
	add_child(_dir_dialog)

	_file_dialog = FileDialog.new()
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILES
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.use_native_dialog = false
	_file_dialog.title = "Seleccionar packs .zip o archivos de audio"
	_file_dialog.filters = PackedStringArray([
		"*.zip ; Packs comprimidos ZIP",
		"*.wav, *.ogg, *.mp3, *.flac, *.aiff, *.m4a, *.opus ; Archivos de audio",
	])
	_file_dialog.files_selected.connect(func(paths: PackedStringArray) -> void:
		_on_files_dropped(paths)
	)
	add_child(_file_dialog)


func _build_left_slots_panel(parent: HBoxContainer) -> void:
	var panel := _make_column_panel(340.0, false)
	parent.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var hdr := Label.new()
	hdr.text = "1. SLOTS DEL PRESET (↑/↓ escucha el sonido)"
	hdr.add_theme_font_size_override("font_size", 13)
	hdr.add_theme_color_override("font_color", Color(0.28, 0.92, 1.0, 1.0))
	vbox.add_child(hdr)

	_slot_filter_opt = OptionButton.new()
	_slot_filter_opt.focus_mode = Control.FOCUS_NONE
	_slot_filter_opt.add_item("Todos (32)")
	_slot_filter_opt.add_item("★ Esenciales (12 Clave)")
	_slot_filter_opt.add_item("Activos AudioManager (20)")
	_slot_filter_opt.add_item("Pendientes en Código (12)")
	_slot_filter_opt.add_item("Con Candidatos Staged")
	_slot_filter_opt.add_item("Familias de Armas (7)")
	_slot_filter_opt.add_item("Ambience (2)")
	_slot_filter_opt.item_selected.connect(func(_idx: int) -> void: _refresh_slot_list())
	vbox.add_child(_slot_filter_opt)

	_slot_list = ItemList.new()
	_slot_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_slot_list.allow_reselect = true
	_slot_list.item_selected.connect(func(idx: int) -> void:
		if _suppress_ui_signals:
			return
		var key: String = str(_slot_list.get_item_metadata(idx))
		var should_play: bool = _auto_preview_check != null and _auto_preview_check.button_pressed and DisplayServer.get_name() != "headless"
		select_slot_by_key(key, should_play)
	)
	vbox.add_child(_slot_list)

	_slot_info_lbl = Label.new()
	_slot_info_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_slot_info_lbl.add_theme_font_size_override("font_size", 11)
	_slot_info_lbl.add_theme_color_override("font_color", Color(0.78, 0.86, 0.95, 0.9))
	vbox.add_child(_slot_info_lbl)


func _build_center_browser_panel(parent: HBoxContainer) -> void:
	var panel := _make_column_panel(0.0, true)
	parent.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	_browser_hdr_lbl = Label.new()
	_browser_hdr_lbl.text = "2. REEMPLAZAR SONIDO DE [laser] (↑/↓ prueba · Doble clic reemplaza)"
	_browser_hdr_lbl.add_theme_font_size_override("font_size", 13)
	_browser_hdr_lbl.add_theme_color_override("font_color", Color(0.28, 0.92, 1.0, 1.0))
	vbox.add_child(_browser_hdr_lbl)

	var filter_row := HBoxContainer.new()
	filter_row.add_theme_constant_override("separation", 6)
	vbox.add_child(filter_row)

	_pack_opt = OptionButton.new()
	_pack_opt.custom_minimum_size = Vector2(160.0, 0.0)
	_pack_opt.focus_mode = Control.FOCUS_NONE
	_pack_opt.add_item("Todos")
	_pack_opt.item_selected.connect(func(_idx: int) -> void:
		if not _suppress_ui_signals:
			_apply_file_filters()
	)
	filter_row.add_child(_pack_opt)

	_search_edit = LineEdit.new()
	_search_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search_edit.placeholder_text = "Buscar reemplazo (ej: laser, click, hit)..."
	_search_edit.text_changed.connect(func(_txt: String) -> void: _apply_file_filters())
	filter_row.add_child(_search_edit)

	var clear_btn := Button.new()
	clear_btn.text = "Limpiar"
	clear_btn.focus_mode = Control.FOCUS_NONE
	clear_btn.pressed.connect(func() -> void:
		_search_edit.text = ""
		_apply_file_filters()
	)
	filter_row.add_child(clear_btn)

	_keywords_row = HFlowContainer.new()
	_keywords_row.add_theme_constant_override("h_separation", 4)
	_keywords_row.add_theme_constant_override("v_separation", 4)
	vbox.add_child(_keywords_row)

	var opts_row := HBoxContainer.new()
	opts_row.add_theme_constant_override("separation", 10)
	vbox.add_child(opts_row)

	_fav_only_check = CheckBox.new()
	_fav_only_check.text = "★ Favs"
	_fav_only_check.focus_mode = Control.FOCUS_NONE
	_fav_only_check.toggled.connect(func(_on: bool) -> void: _apply_file_filters())
	opts_row.add_child(_fav_only_check)

	_auto_preview_check = CheckBox.new()
	_auto_preview_check.text = "Auto-Preview"
	_auto_preview_check.button_pressed = true
	_auto_preview_check.focus_mode = Control.FOCUS_NONE
	opts_row.add_child(_auto_preview_check)

	var suggest_btn := Button.new()
	suggest_btn.text = "Sugerir Top 5"
	suggest_btn.focus_mode = Control.FOCUS_NONE
	suggest_btn.pressed.connect(func() -> void: run_candidate_suggester())
	opts_row.add_child(suggest_btn)

	_files_count_lbl = Label.new()
	_files_count_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_files_count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_files_count_lbl.text = "0 archivos"
	_files_count_lbl.add_theme_font_size_override("font_size", 11)
	_files_count_lbl.add_theme_color_override("font_color", Color(0.75, 0.85, 0.95, 0.85))
	opts_row.add_child(_files_count_lbl)

	_files_list = ItemList.new()
	_files_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_files_list.allow_reselect = true
	_files_list.item_selected.connect(func(idx: int) -> void:
		if not _suppress_ui_signals:
			select_candidate_index(idx)
	)
	_files_list.item_activated.connect(func(idx: int) -> void:
		select_candidate_index(idx)
		replace_main_candidate()
	)
	vbox.add_child(_files_list)


func _build_right_deck_panel(parent: HBoxContainer) -> void:
	var panel := _make_column_panel(395.0, false)
	parent.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var hdr := Label.new()
	hdr.text = "3. ESCUCHAR, COMPARAR A/B Y EXPORTAR"
	hdr.add_theme_font_size_override("font_size", 13)
	hdr.add_theme_color_override("font_color", Color(0.28, 0.92, 1.0, 1.0))
	vbox.add_child(hdr)

	_selected_file_lbl = Label.new()
	_selected_file_lbl.text = "Ningún archivo seleccionado"
	_selected_file_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_selected_file_lbl.add_theme_font_size_override("font_size", 11)
	_selected_file_lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.45, 1.0))
	vbox.add_child(_selected_file_lbl)

	_waveform = WaveformScript.new()
	vbox.add_child(_waveform)

	var play_row1 := HBoxContainer.new()
	play_row1.add_theme_constant_override("separation", 6)
	vbox.add_child(play_row1)

	var play_b_btn := Button.new()
	play_b_btn.text = "▶ Nuevo [Space]"
	play_b_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play_b_btn.focus_mode = Control.FOCUS_NONE
	play_b_btn.pressed.connect(audition_selected)
	play_row1.add_child(play_b_btn)

	var play_a_btn := Button.new()
	play_a_btn.text = "▶ Prod Actual [A]"
	play_a_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play_a_btn.focus_mode = Control.FOCUS_NONE
	play_a_btn.pressed.connect(audition_production)
	play_row1.add_child(play_a_btn)

	_fav_btn = Button.new()
	_fav_btn.text = "☆ Fav [F]"
	_fav_btn.focus_mode = Control.FOCUS_NONE
	_fav_btn.pressed.connect(toggle_favorite_selected)
	play_row1.add_child(_fav_btn)

	var play_row2 := HBoxContainer.new()
	play_row2.add_theme_constant_override("separation", 6)
	vbox.add_child(play_row2)

	_burst_btn = Button.new()
	_burst_btn.text = "▶ Ráfaga [R]"
	_burst_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_burst_btn.focus_mode = Control.FOCUS_NONE
	_burst_btn.pressed.connect(func() -> void: toggle_burst_preview(false))
	play_row2.add_child(_burst_btn)

	var exp_btn := Button.new()
	exp_btn.text = "▶ Combo EXP"
	exp_btn.focus_mode = Control.FOCUS_NONE
	exp_btn.pressed.connect(func() -> void: toggle_burst_preview(true))
	play_row2.add_child(exp_btn)

	var stop_btn := Button.new()
	stop_btn.text = "■ Stop [S]"
	stop_btn.focus_mode = Control.FOCUS_NONE
	stop_btn.pressed.connect(stop_all_audio)
	play_row2.add_child(stop_btn)

	# --- Ajustes de normalización por slot ---
	var gain_row: Dictionary = _make_slider_row(vbox, "Gain Offset (dB)", -18.0, 12.0, 0.5, 0.0, func(v: float) -> void:
		var st: Dictionary = _get_current_slot_state()
		st["gain_db"] = v
		_gain_val_lbl.text = "%+.1f dB" % v
	)
	_gain_slider = gain_row["slider"] as HSlider
	_gain_val_lbl = gain_row["value_lbl"] as Label

	var pitch_row: Dictionary = _make_slider_row(vbox, "Pitch Preview", 0.5, 1.8, 0.02, 1.0, func(v: float) -> void:
		var st: Dictionary = _get_current_slot_state()
		st["pitch_base"] = v
		_pitch_val_lbl.text = "%.2fx" % v
	)
	_pitch_slider = pitch_row["slider"] as HSlider
	_pitch_val_lbl = pitch_row["value_lbl"] as Label

	var jitter_row: Dictionary = _make_slider_row(vbox, "Pitch Jitter (Burst)", 0.0, 0.25, 0.01, 0.08, func(v: float) -> void:
		var st: Dictionary = _get_current_slot_state()
		st["pitch_jitter"] = v
		_jitter_val_lbl.text = "±%.0f%%" % (v * 100.0)
	)
	_jitter_slider = jitter_row["slider"] as HSlider
	_jitter_val_lbl = jitter_row["value_lbl"] as Label

	var flags_row := HBoxContainer.new()
	flags_row.add_theme_constant_override("separation", 10)
	vbox.add_child(flags_row)

	_trim_check = CheckBox.new()
	_trim_check.text = "Recortar silencio"
	_trim_check.focus_mode = Control.FOCUS_NONE
	_trim_check.toggled.connect(func(on: bool) -> void:
		if not _suppress_ui_signals:
			_get_current_slot_state()["trim_silence"] = on
	)
	flags_row.add_child(_trim_check)

	_mono_check = CheckBox.new()
	_mono_check.text = "Exportar Mono"
	_mono_check.focus_mode = Control.FOCUS_NONE
	_mono_check.toggled.connect(func(on: bool) -> void:
		if not _suppress_ui_signals:
			_get_current_slot_state()["mono"] = on
	)
	flags_row.add_child(_mono_check)

	# --- Sonidos asignados al slot ---
	var staged_hdr := Label.new()
	staged_hdr.text = "Sonidos del slot (clic para escuchar · [Main] = principal):"
	staged_hdr.add_theme_font_size_override("font_size", 11)
	staged_hdr.add_theme_color_override("font_color", Color(1.0, 0.55, 0.72, 1.0))
	vbox.add_child(staged_hdr)

	_staged_list = ItemList.new()
	_staged_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_staged_list.custom_minimum_size = Vector2(0.0, 86.0)
	_staged_list.allow_reselect = true
	_staged_list.item_selected.connect(func(idx: int) -> void:
		if _suppress_ui_signals:
			return
		var st: Dictionary = _get_current_slot_state()
		var cands: Array = st.get("candidates", []) as Array
		if idx >= 0 and idx < cands.size():
			var p: String = str(cands[idx])
			_selected_candidate_abs = p
			var role_tag: String = "Main" if idx == 0 else "Var %d" % (idx + 1)
			_selected_file_lbl.text = "[PRESET · %s] %s" % [role_tag, p.get_file()]
			_selected_file_lbl.add_theme_color_override("font_color", Color(0.45, 0.96, 0.78, 1.0))
			_update_fav_button_label()
			_current_stream_info = _scanner.load_external_stream(p)
			_waveform.set_analysis(_current_stream_info)
			audition_selected()
	)
	vbox.add_child(_staged_list)

	var stage_btns := HBoxContainer.new()
	stage_btns.add_theme_constant_override("separation", 6)
	vbox.add_child(stage_btns)

	var rep_btn := Button.new()
	rep_btn.text = "Reemplazar Main [Enter]"
	rep_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rep_btn.focus_mode = Control.FOCUS_NONE
	rep_btn.pressed.connect(replace_main_candidate)
	stage_btns.add_child(rep_btn)

	var add_btn := Button.new()
	add_btn.text = "+ Variante"
	add_btn.focus_mode = Control.FOCUS_NONE
	add_btn.pressed.connect(stage_selected_candidate)
	stage_btns.add_child(add_btn)

	var rm_btn := Button.new()
	rm_btn.text = "Quitar"
	rm_btn.focus_mode = Control.FOCUS_NONE
	rm_btn.pressed.connect(unstage_selected_candidate)
	stage_btns.add_child(rm_btn)

	# --- Capa 2 (Layering) y Sugerencias ---
	var layer_row := HBoxContainer.new()
	layer_row.add_theme_constant_override("separation", 4)
	vbox.add_child(layer_row)

	_layer2_lbl = Label.new()
	_layer2_lbl.text = "Capa 2: (ninguna)"
	_layer2_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_layer2_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_layer2_lbl.add_theme_font_size_override("font_size", 11)
	_layer2_lbl.add_theme_color_override("font_color", Color(0.75, 0.88, 1.0, 0.9))
	layer_row.add_child(_layer2_lbl)

	var l2_set_btn := Button.new()
	l2_set_btn.text = "+Capa 2"
	l2_set_btn.focus_mode = Control.FOCUS_NONE
	l2_set_btn.pressed.connect(assign_selected_as_layer2)
	layer_row.add_child(l2_set_btn)

	var l2_play_btn := Button.new()
	l2_play_btn.text = "▶ 1+2"
	l2_play_btn.focus_mode = Control.FOCUS_NONE
	l2_play_btn.pressed.connect(audition_layered_slot)
	layer_row.add_child(l2_play_btn)

	var l2_clr_btn := Button.new()
	l2_clr_btn.text = "×"
	l2_clr_btn.focus_mode = Control.FOCUS_NONE
	l2_clr_btn.pressed.connect(clear_layer2_candidate)
	layer_row.add_child(l2_clr_btn)

	var sug_row := HBoxContainer.new()
	sug_row.add_theme_constant_override("separation", 4)
	vbox.add_child(sug_row)

	_suggestions_opt = OptionButton.new()
	_suggestions_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_suggestions_opt.focus_mode = Control.FOCUS_NONE
	_suggestions_opt.add_item("Sugerencias: (pulsá 'Sugerir Top 5')")
	_suggestions_opt.item_selected.connect(_on_suggestion_selected)
	sug_row.add_child(_suggestions_opt)

	# --- Guardado & Exportación ---
	var export_row := HBoxContainer.new()
	export_row.add_theme_constant_override("separation", 6)
	vbox.add_child(export_row)

	var save_btn := Button.new()
	save_btn.text = "Guardar Lista"
	save_btn.focus_mode = Control.FOCUS_NONE
	save_btn.pressed.connect(save_curation_manifest)
	export_row.add_child(save_btn)

	var exp_one_btn := Button.new()
	exp_one_btn.text = "Exportar Slot"
	exp_one_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	exp_one_btn.focus_mode = Control.FOCUS_NONE
	exp_one_btn.pressed.connect(func() -> void: export_current_slot())
	export_row.add_child(exp_one_btn)

	var exp_all_btn := Button.new()
	exp_all_btn.text = "Exportar Todos Staged → assets/audio/sfx/"
	exp_all_btn.focus_mode = Control.FOCUS_NONE
	exp_all_btn.pressed.connect(func() -> void: export_all_staged())
	vbox.add_child(exp_all_btn)


func _make_column_panel(min_width: float, expand_h: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	if min_width > 0.0:
		panel.custom_minimum_size = Vector2(min_width, 0.0)
	if expand_h:
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.065, 0.11, 0.92)
	style.border_color = Color(0.22, 0.80, 0.96, 0.45)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _make_slider_row(
	parent: VBoxContainer,
	label_text: String,
	min_v: float,
	max_v: float,
	step_v: float,
	init_v: float,
	callback: Callable
) -> Dictionary:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	parent.add_child(box)

	var row := HBoxContainer.new()
	box.add_child(row)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 11)
	row.add_child(lbl)

	var val_lbl := Label.new()
	val_lbl.text = "%.2f" % init_v
	val_lbl.add_theme_font_size_override("font_size", 11)
	val_lbl.add_theme_color_override("font_color", Color(0.45, 0.92, 1.0, 1.0))
	row.add_child(val_lbl)

	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step_v
	slider.value = init_v
	slider.focus_mode = Control.FOCUS_NONE
	slider.value_changed.connect(func(v: float) -> void:
		if not _suppress_ui_signals:
			callback.call(v)
	)
	box.add_child(slider)
	return {"slider": slider, "value_lbl": val_lbl}


func _refresh_slot_list() -> void:
	var filter_idx: int = _slot_filter_opt.selected if _slot_filter_opt != null else 0
	var slots_dict: Dictionary = _manifest.get("slots", {}) as Dictionary

	_suppress_ui_signals = true
	_slot_list.clear()
	var selected_row: int = -1
	for spec: Dictionary in _slot_specs:
		var key: String = str(spec.get("key", ""))
		var in_am: bool = bool(spec.get("in_audio_manager", false))
		var st: Dictionary = slots_dict.get(key, {}) as Dictionary
		var staged_count: int = (st.get("candidates", []) as Array).size()

		var cat: String = str(spec.get("category", ""))
		var is_ess: bool = CatalogScript.is_essential_slot(key)
		if filter_idx == 1 and not is_ess:
			continue
		if filter_idx == 2 and not in_am:
			continue
		if filter_idx == 3 and in_am:
			continue
		if filter_idx == 4 and staged_count == 0:
			continue
		if filter_idx == 5 and cat != "Weapons":
			continue
		if filter_idx == 6 and cat != "Ambience":
			continue

		var status_tag: String = "PROD" if in_am else "VACÍO"
		var star_pfx: String = "★ " if is_ess else ""
		var cands_arr: Array = st.get("candidates", []) as Array
		var text: String = ""
		if staged_count > 0:
			var main_file: String = str(cands_arr[0]).get_file()
			var extra_suffix: String = " (+%d)" % (staged_count - 1) if staged_count > 1 else ""
			text = "%s%s → %s%s" % [star_pfx, key, main_file, extra_suffix]
		else:
			text = "%s[%s] %s → (sin asignar)" % [star_pfx, status_tag, key]
		var idx: int = _slot_list.add_item(text)
		_slot_list.set_item_metadata(idx, key)
		if staged_count > 0:
			_slot_list.set_item_custom_fg_color(idx, Color(0.45, 0.98, 0.70, 1.0))
		elif not in_am:
			_slot_list.set_item_custom_fg_color(idx, Color(1.0, 0.72, 0.45, 0.95))
		if key == _selected_slot_key:
			selected_row = idx

	if selected_row >= 0:
		_slot_list.select(selected_row)
	_suppress_ui_signals = false


func _refresh_slot_inspector() -> void:
	var spec: Dictionary = _get_slot_spec(_selected_slot_key)
	var st: Dictionary = _get_current_slot_state()
	var in_am: bool = bool(spec.get("in_audio_manager", false))
	var prod_state: String = "Activo en AudioManager" if in_am else "Pendiente en AudioManager"
	_slot_info_lbl.text = "%s · %s\n%s" % [
		str(spec.get("category", "")),
		prod_state,
		str(spec.get("description", "")),
	]
	if _browser_hdr_lbl != null:
		_browser_hdr_lbl.text = "2. REEMPLAZAR SONIDO DE [%s] (↑/↓ prueba · Doble clic reemplaza)" % _selected_slot_key

	for child: Node in _keywords_row.get_children():
		child.queue_free()
	var raw_kws: Variant = spec.get("keywords", [])
	if raw_kws is Array:
		for kw_v: Variant in (raw_kws as Array):
			var kw: String = str(kw_v)
			var chip := Button.new()
			chip.text = kw
			chip.focus_mode = Control.FOCUS_NONE
			chip.add_theme_font_size_override("font_size", 11)
			chip.pressed.connect(func() -> void:
				_search_edit.text = kw
				_apply_file_filters()
			)
			_keywords_row.add_child(chip)

	_suppress_ui_signals = true
	var g: float = float(st.get("gain_db", 0.0))
	_gain_slider.value = g
	_gain_val_lbl.text = "%+.1f dB" % g
	var p: float = float(st.get("pitch_base", 1.0))
	_pitch_slider.value = p
	_pitch_val_lbl.text = "%.2fx" % p
	var j: float = float(st.get("pitch_jitter", 0.08))
	_jitter_slider.value = j
	_jitter_val_lbl.text = "±%.0f%%" % (j * 100.0)
	_trim_check.button_pressed = bool(st.get("trim_silence", true))
	_mono_check.button_pressed = bool(st.get("mono", bool(spec.get("default_mono", true))))
	_suppress_ui_signals = false

	_refresh_staged_list()
	_refresh_layer2_and_suggestions()


func assign_selected_as_layer2() -> bool:
	if _selected_candidate_abs.is_empty():
		return false
	var st: Dictionary = _get_current_slot_state()
	st["layer2_candidate"] = _selected_candidate_abs
	_refresh_layer2_and_suggestions()
	_set_status("Capa 2 asignada a [%s]: %s" % [_selected_slot_key, _selected_candidate_abs.get_file()])
	return true


func clear_layer2_candidate() -> void:
	_get_current_slot_state()["layer2_candidate"] = ""
	_refresh_layer2_and_suggestions()


func audition_layered_slot() -> bool:
	var st: Dictionary = _get_current_slot_state()
	var cands: Array = st.get("candidates", []) as Array
	var main_stream: AudioStream = null
	if not cands.is_empty():
		main_stream = _scanner.load_external_stream(str(cands[0])).get("stream", null) as AudioStream
	if main_stream == null:
		main_stream = _current_stream_info.get("stream", null) as AudioStream
	if main_stream == null:
		return false
	_audition.stop_burst()
	_audition.stop_tour()
	_burst_btn.text = "▶ Ráfaga [R]"
	if _tour_btn != null:
		_tour_btn.text = "▶ Tour (9 clave)"
	var pitch: float = float(st.get("pitch_base", 1.0))
	var gain_db: float = float(st.get("gain_db", 0.0))
	_audition.play_stream_once(main_stream, pitch, gain_db, true, true)
	var l2_path: String = str(st.get("layer2_candidate", "")).strip_edges()
	if not l2_path.is_empty():
		var l2_info: Dictionary = _scanner.load_external_stream(l2_path)
		var l2_stream: AudioStream = l2_info.get("stream", null) as AudioStream
		if l2_stream != null:
			_audition.play_stream_once(l2_stream, pitch, gain_db - 3.0, false, false)
	return true


func run_candidate_suggester() -> int:
	if _pack_dirs.is_empty():
		var raw_edit: String = ScannerScript.normalize_path_input(_path_edit.text)
		if not raw_edit.is_empty() and DirAccess.dir_exists_absolute(raw_edit):
			_pack_dirs.append(raw_edit)
	if _pack_dirs.is_empty():
		_set_status("Primero seleccioná o arrastrá al menos una carpeta de packs válida.")
		return 0
	var script_abs: String = ProjectSettings.globalize_path("res://tools/suggest_sfx_candidates.py")
	var out_json: String = OS.get_user_data_dir().path_join("sfx_lab_suggestions.json")
	var args := PackedStringArray([script_abs])
	for d: String in _pack_dirs:
		args.append("--packs-dir")
		args.append(d)
	args.append("--output")
	args.append(out_json)
	args.append("--top")
	args.append("5")
	var exec_res: Dictionary = ExporterScript._execute_python(args)
	if int(exec_res.get("exit_code", -1)) != 0 or not FileAccess.file_exists(out_json):
		_set_status("Error ejecutando suggest_sfx_candidates.py")
		return 0
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(out_json))
	if not (parsed is Dictionary):
		return 0
	var p_dict: Dictionary = parsed as Dictionary
	var raw_sug: Variant = p_dict.get("suggestions", {})
	if raw_sug is Dictionary:
		_suggestions_by_slot = (raw_sug as Dictionary).duplicate(true)
	var raw_prof: Variant = p_dict.get("profiles", {})
	if raw_prof is Dictionary:
		_profiles_by_id = (raw_prof as Dictionary).duplicate(true)
	_refresh_layer2_and_suggestions()
	var total_files: int = int(p_dict.get("total_files", 0))
	_set_status("Listo: %d archivos analizados · 4 perfiles combinados armados." % total_files)
	return total_files


func unpack_detected_zips(dest_dir_override: String = "", explicit_zips: Array[String] = []) -> Dictionary:
	var targets: Array[String] = explicit_zips.duplicate() if not explicit_zips.is_empty() else _detected_zips.duplicate()
	if targets.is_empty():
		_set_status("No hay archivos .zip pendientes de descomprimir.")
		return {"ok": false, "unpacked_dirs": [] as Array[String]}
	var dest_dir: String = dest_dir_override.strip_edges()
	if dest_dir.is_empty():
		var dl_dir: String = OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
		if not dl_dir.is_empty() and DirAccess.dir_exists_absolute(dl_dir):
			dest_dir = dl_dir.path_join("Stela_SFX_Packs")
		else:
			dest_dir = OS.get_user_data_dir().path_join("sfx_lab_unpacked")
	var script_abs: String = ProjectSettings.globalize_path("res://tools/suggest_sfx_candidates.py")
	var args := PackedStringArray([script_abs])
	for z_path: String in targets:
		args.append("--unpack-zips-from")
		args.append(z_path)
	args.append("--unpack-dest")
	args.append(dest_dir)
	var exec_res: Dictionary = ExporterScript._execute_python(args)
	var parsed: Dictionary = ExporterScript._parse_last_json_line(str(exec_res.get("stdout", "")))
	if bool(parsed.get("ok", false)):
		var dirs: Variant = parsed.get("unpacked_dirs", [])
		if dirs is Array:
			for d_v: Variant in (dirs as Array):
				var d_str: String = str(d_v)
				if not d_str.is_empty() and not _pack_dirs.has(d_str):
					_pack_dirs.append(d_str)
		_rescan_pack_dirs(true)
	else:
		_set_status("Error descomprimiendo ZIPs: %s" % str(parsed.get("error", "")))
	return parsed


func apply_combined_profile(profile_id: String, only_empty_slots: bool = false) -> int:
	if _profiles_by_id.is_empty():
		run_candidate_suggester()
	if not _profiles_by_id.has(profile_id):
		_set_status("No hay datos del perfil '%s'. Primero cargá una carpeta con audios." % profile_id)
		return 0

	_manifest["active_profile_id"] = profile_id
	var prof: Dictionary = _profiles_by_id[profile_id] as Dictionary
	var prof_slots: Dictionary = prof.get("slots", {}) as Dictionary
	var slots_dict: Dictionary = _manifest.get("slots", {}) as Dictionary
	var applied_count: int = 0

	for spec: Dictionary in _slot_specs:
		var key: String = str(spec.get("key", ""))
		if not prof_slots.has(key):
			continue
		var cur_state: Dictionary = slots_dict.get(key, {}) as Dictionary
		var cur_cands: Array = cur_state.get("candidates", []) as Array
		if only_empty_slots and not cur_cands.is_empty():
			continue

		var src: Dictionary = prof_slots[key] as Dictionary
		var new_cands: Array[String] = []
		var raw_cands: Variant = src.get("candidates", [])
		if raw_cands is Array:
			for c_v: Variant in (raw_cands as Array):
				var p: String = str(c_v).strip_edges()
				if not p.is_empty():
					new_cands.append(p)
		if new_cands.is_empty():
			continue

		cur_state["candidates"] = new_cands
		cur_state["layer2_candidate"] = str(src.get("layer2_candidate", ""))
		cur_state["gain_db"] = float(src.get("gain_db", 0.0))
		cur_state["pitch_base"] = float(src.get("pitch_base", 1.0))
		cur_state["pitch_jitter"] = float(src.get("pitch_jitter", 0.08))
		cur_state["trim_silence"] = bool(src.get("trim_silence", true))
		cur_state["mono"] = bool(src.get("mono", bool(spec.get("default_mono", true))))
		slots_dict[key] = cur_state
		_slot_alt_cursor[key] = 0
		applied_count += 1

	_refresh_slot_list()
	_refresh_slot_inspector()
	_update_progress_banner()
	var prof_label: String = str(prof.get("label", profile_id))
	_set_status("Perfil '%s' armado: %d/32 slots listos. Pulsá '▶ Tour del Perfil' para escucharlo o 'Exportar Todos'." % [prof_label, applied_count])
	return applied_count


func apply_curated_preset(preset_id: String, only_empty_slots: bool = false, auto_play_current: bool = false) -> int:
	var preset: Dictionary = {}
	if _curated_presets.has(preset_id):
		preset = _curated_presets[preset_id] as Dictionary
	elif _custom_presets.has(preset_id):
		preset = _custom_presets[preset_id] as Dictionary
	if preset.is_empty():
		_set_status("Preset '%s' no encontrado." % preset_id)
		return 0

	var raw_slots: Variant = preset.get("slots", {})
	if not (raw_slots is Dictionary):
		return 0
	var src_slots: Dictionary = raw_slots as Dictionary
	var slots_dict: Dictionary = _manifest.get("slots", {}) as Dictionary
	var applied_count: int = 0
	_manifest["active_profile_id"] = preset_id

	for spec: Dictionary in _slot_specs:
		var key: String = str(spec.get("key", ""))
		if not src_slots.has(key) or not (src_slots[key] is Dictionary):
			continue
		var cur_state: Dictionary = slots_dict.get(key, {}) as Dictionary
		if only_empty_slots and not (cur_state.get("candidates", []) as Array).is_empty():
			continue

		var src: Dictionary = src_slots[key] as Dictionary
		var resolved_cands: Array[String] = []
		var raw_cands: Variant = src.get("candidates", [])
		if raw_cands is Array:
			for c_v: Variant in (raw_cands as Array):
				var res_path: String = CatalogScript.resolve_preset_path(str(c_v), _pack_dirs)
				if not res_path.is_empty() and not resolved_cands.has(res_path):
					resolved_cands.append(res_path)
		if resolved_cands.is_empty():
			continue

		var l2_res: String = CatalogScript.resolve_preset_path(str(src.get("layer2_candidate", "")), _pack_dirs)
		cur_state["candidates"] = resolved_cands
		cur_state["layer2_candidate"] = l2_res
		cur_state["gain_db"] = float(src.get("gain_db", 0.0))
		cur_state["pitch_base"] = float(src.get("pitch_base", 1.0))
		cur_state["pitch_jitter"] = float(src.get("pitch_jitter", 0.08))
		cur_state["trim_silence"] = bool(src.get("trim_silence", true))
		cur_state["mono"] = bool(src.get("mono", bool(spec.get("default_mono", true))))
		slots_dict[key] = cur_state
		applied_count += 1

	_refresh_preset_bar_buttons()
	_refresh_slot_list()
	_refresh_slot_inspector()
	_load_slot_main_into_deck(auto_play_current and DisplayServer.get_name() != "headless")
	_update_progress_banner()
	var label_str: String = str(preset.get("label", preset_id))
	var desc_str: String = str(preset.get("desc", ""))
	if _preset_desc_lbl != null:
		_preset_desc_lbl.text = "%s — %s" % [label_str, desc_str]
	if applied_count == 0:
		_set_status("Preset '%s' sin archivos resueltos en las carpetas actuales (cargá Stela_SFX_Packs)." % label_str)
	else:
		_set_status("%s (%d/32 slots listos). Usá ↑/↓ en Columna 1 para escuchar cada sonido." % [label_str, applied_count])
	return applied_count


func save_current_as_custom_preset(label: String = "Mi Preset Custom", custom_path_override: String = "") -> bool:
	var target_path: String = custom_path_override if not custom_path_override.is_empty() else _custom_presets_path
	var slots_dict: Dictionary = _manifest.get("slots", {}) as Dictionary
	var pid: String = "custom_user"
	var err: Error = CatalogScript.save_custom_preset(
		pid,
		"☆ Custom: %s" % label,
		"Preset personalizado guardado desde SfxLab.",
		slots_dict,
		target_path
	)
	if err != OK:
		_set_status("Error guardando preset custom (%d)." % int(err))
		return false
	_custom_presets = CatalogScript.load_custom_presets(target_path)
	_manifest["active_profile_id"] = pid
	_refresh_preset_bar_buttons()
	_set_status("Preset custom guardado (%d/32 slots) — disponible en el botón '☆ Custom'." % _count_staged_slots())
	return true


func _refresh_preset_bar_buttons() -> void:
	var active_id: String = str(_manifest.get("active_profile_id", "stela_signature"))
	for pid_v: Variant in _preset_buttons.keys():
		var pid: String = str(pid_v)
		var btn: Button = _preset_buttons[pid] as Button
		if btn == null:
			continue
		if pid == "custom_user":
			btn.visible = _custom_presets.has("custom_user")
		_suppress_ui_signals = true
		btn.button_pressed = (pid == active_id)
		_suppress_ui_signals = false
	if _preset_desc_lbl != null:
		var active_preset: Dictionary = {}
		if _curated_presets.has(active_id):
			active_preset = _curated_presets[active_id] as Dictionary
		elif _custom_presets.has(active_id):
			active_preset = _custom_presets[active_id] as Dictionary
		if not active_preset.is_empty():
			_preset_desc_lbl.text = "%s — %s" % [str(active_preset.get("label", active_id)), str(active_preset.get("desc", ""))]


func _count_staged_slots() -> int:
	var count: int = 0
	var slots_dict: Dictionary = _manifest.get("slots", {}) as Dictionary
	for spec: Dictionary in _slot_specs:
		var k: String = str(spec.get("key", ""))
		var st: Dictionary = slots_dict.get(k, {}) as Dictionary
		if not (st.get("candidates", []) as Array).is_empty():
			count += 1
	return count


func cycle_slot_suggestion_alternative() -> bool:
	if _suggestions_by_slot.is_empty():
		run_candidate_suggester()
	var list: Array = _suggestions_by_slot.get(_selected_slot_key, []) as Array
	if list.is_empty():
		_set_status("No hay sugerencias alternativas para [%s]." % _selected_slot_key)
		return false

	var next_idx: int = (int(_slot_alt_cursor.get(_selected_slot_key, 0)) + 1) % list.size()
	_slot_alt_cursor[_selected_slot_key] = next_idx
	var item: Dictionary = list[next_idx] as Dictionary
	var abs_path: String = str(item.get("abs_path", ""))
	if abs_path.is_empty():
		return false

	var st: Dictionary = _get_current_slot_state()
	var variants: Array[String] = []
	var raw_vars: Variant = item.get("variants", [])
	if raw_vars is Array:
		for v: Variant in (raw_vars as Array):
			var p: String = str(v)
			if not p.is_empty():
				variants.append(p)
	if variants.is_empty():
		variants.append(abs_path)
	st["candidates"] = variants.slice(0, 3)

	_selected_candidate_abs = abs_path
	_selected_file_lbl.text = str(item.get("rel_path", abs_path.get_file()))
	_current_stream_info = _scanner.load_external_stream(abs_path)
	_waveform.set_analysis(_current_stream_info)
	_refresh_staged_list()
	_refresh_slot_list()
	_update_progress_banner()
	audition_selected()
	_set_status("[%s] Alternativa %d/%d: %s" % [_selected_slot_key, next_idx + 1, list.size(), abs_path.get_file()])
	return true


func start_profile_tour() -> bool:
	var tour_keys: Array[String] = [
		"ui_click", "weapon_laser", "weapon_railgun", "weapon_blade",
		"explosion", "exp", "level_up", "bomb", "hub_footstep",
	]
	var steps: Array[Dictionary] = []
	var slots_dict: Dictionary = _manifest.get("slots", {}) as Dictionary

	for key: String in tour_keys:
		var spec: Dictionary = _get_slot_spec(key)
		var st: Dictionary = slots_dict.get(key, {}) as Dictionary
		var cands: Array = st.get("candidates", []) as Array
		var main_path: String = str(cands[0]) if not cands.is_empty() else ""
		var fallback_stream: AudioStream = AudioManager.sfx_streams.get(key, null) as AudioStream if AudioManager != null else null
		if main_path.is_empty() and fallback_stream == null:
			continue
		var is_exp: bool = bool(spec.get("use_combo", false))
		steps.append({
			"slot_key": key,
			"main_path": main_path,
			"layer2_path": str(st.get("layer2_candidate", "")).strip_edges(),
			"fallback_stream": fallback_stream,
			"pitch": float(st.get("pitch_base", 1.0)),
			"volume_db": float(st.get("gain_db", 0.0)),
			"repeat_count": 4 if is_exp else (3 if key == "weapon_laser" else 1),
			"use_exp_combo": is_exp,
			"gap_sec": 0.35,
		})

	if steps.is_empty():
		_set_status("No hay sonidos asignados ni cargados para el Tour.")
		return false
	if _tour_btn != null:
		_tour_btn.text = "■ Detener Tour"
	_audition.start_tour(steps, _load_tour_step_streams)
	return true


func _load_tour_step_streams(step: Dictionary) -> Dictionary:
	var main_path: String = str(step.get("main_path", "")).strip_edges()
	var l2_path: String = str(step.get("layer2_path", "")).strip_edges()
	var main_stream: AudioStream = null
	var layer2_stream: AudioStream = null
	if not main_path.is_empty() and FileAccess.file_exists(main_path):
		var info: Dictionary = _scanner.load_external_stream(main_path)
		main_stream = info.get("stream", null) as AudioStream
		if main_stream != null and _waveform != null:
			_current_stream_info = info
			_selected_candidate_abs = main_path
			_waveform.set_analysis(info)
			if _selected_file_lbl != null:
				_selected_file_lbl.text = "[TOUR] %s" % main_path.get_file()
	if not l2_path.is_empty() and FileAccess.file_exists(l2_path):
		var l2_info: Dictionary = _scanner.load_external_stream(l2_path)
		layer2_stream = l2_info.get("stream", null) as AudioStream
	return {"stream": main_stream, "layer2": layer2_stream}


func _refresh_layer2_and_suggestions() -> void:
	if _layer2_lbl != null:
		var l2_path: String = str(_get_current_slot_state().get("layer2_candidate", "")).strip_edges()
		_layer2_lbl.text = "Capa 2: %s" % (l2_path.get_file() if not l2_path.is_empty() else "(ninguna)")
	if _suggestions_opt != null:
		_suppress_ui_signals = true
		_suggestions_opt.clear()
		var list: Array = _suggestions_by_slot.get(_selected_slot_key, []) as Array
		if list.is_empty():
			_suggestions_opt.add_item("Sugerencias: (sin coincidencias / pulsá Sugerir)")
		else:
			_suggestions_opt.add_item("Sugerencias [%s] (%d):" % [_selected_slot_key, list.size()])
			for item_v: Variant in list:
				if item_v is Dictionary:
					var item: Dictionary = item_v as Dictionary
					var label: String = "%s (%.0fms · %.0f pts)" % [
						str(item.get("rel_path", "")).get_file(),
						float(item.get("duration_ms", 0.0)),
						float(item.get("score", 0.0)),
					]
					var idx: int = _suggestions_opt.item_count
					_suggestions_opt.add_item(label)
					_suggestions_opt.set_item_metadata(idx, item)
		_suggestions_opt.select(0)
		_suppress_ui_signals = false


func _on_suggestion_selected(idx: int) -> void:
	if _suppress_ui_signals or idx <= 0:
		return
	var meta: Variant = _suggestions_opt.get_item_metadata(idx)
	if not (meta is Dictionary):
		return
	var item: Dictionary = meta as Dictionary
	var abs_path: String = str(item.get("abs_path", ""))
	if abs_path.is_empty():
		return
	_selected_candidate_abs = abs_path
	_selected_file_lbl.text = str(item.get("rel_path", abs_path.get_file()))
	_update_fav_button_label()
	_current_stream_info = _scanner.load_external_stream(abs_path)
	_waveform.set_analysis(_current_stream_info)
	audition_selected()


func _refresh_staged_list() -> void:
	_staged_list.clear()
	var st: Dictionary = _get_current_slot_state()
	var cands: Array = st.get("candidates", []) as Array
	for i: int in range(cands.size()):
		var p: String = str(cands[i])
		var prefix: String = "[Main] " if i == 0 else "[Var %d] " % (i + 1)
		_staged_list.add_item(prefix + p.get_file())


func _apply_file_filters() -> void:
	var pack_filter: String = "Todos"
	if _pack_opt != null and _pack_opt.selected >= 0:
		pack_filter = _pack_opt.get_item_text(_pack_opt.selected)
	var query: String = _search_edit.text if _search_edit != null else ""
	var only_favs: bool = _fav_only_check != null and _fav_only_check.button_pressed
	_filtered_entries = ScannerScript.filter_entries(_all_entries, pack_filter, query, _favorites_set, only_favs)

	_suppress_ui_signals = true
	_files_list.clear()
	for entry: Dictionary in _filtered_entries:
		var abs_path: String = str(entry.get("abs_path", ""))
		var star: String = "★ " if _favorites_set.has(abs_path) else ""
		_files_list.add_item(star + str(entry.get("rel_path", "")))
	_suppress_ui_signals = false

	_files_count_lbl.text = "%d / %d archivos" % [_filtered_entries.size(), _all_entries.size()]


func _collect_staged_streams(st: Dictionary) -> Array[AudioStream]:
	var streams: Array[AudioStream] = []
	var cands: Array = st.get("candidates", []) as Array
	for c_v: Variant in cands:
		var info: Dictionary = _scanner.load_external_stream(str(c_v))
		var s: AudioStream = info.get("stream", null) as AudioStream
		if s != null:
			streams.append(s)
	return streams


func _get_slot_spec(slot_key: String) -> Dictionary:
	for spec: Dictionary in _slot_specs:
		if str(spec.get("key", "")) == slot_key:
			return spec
	return _slot_specs[0] if not _slot_specs.is_empty() else {}


func _get_current_slot_state() -> Dictionary:
	var slots_dict: Dictionary = _manifest.get("slots", {}) as Dictionary
	if not slots_dict.has(_selected_slot_key):
		slots_dict[_selected_slot_key] = CatalogScript.create_default_slot_state(_get_slot_spec(_selected_slot_key))
	return slots_dict[_selected_slot_key] as Dictionary


func _sync_favorites_from_manifest() -> void:
	_favorites_set.clear()
	var favs: Variant = _manifest.get("favorites", [])
	if favs is Array:
		for f_v: Variant in (favs as Array):
			var p: String = str(f_v)
			if not p.is_empty():
				_favorites_set[p] = true


func _sync_manifest_from_favorites() -> void:
	var favs: Array[String] = []
	for k_v: Variant in _favorites_set.keys():
		favs.append(str(k_v))
	favs.sort()
	_manifest["favorites"] = favs


func _update_fav_button_label() -> void:
	if _fav_btn == null:
		return
	var is_fav: bool = not _selected_candidate_abs.is_empty() and _favorites_set.has(_selected_candidate_abs)
	_fav_btn.text = "★ Fav [F]" if is_fav else "☆ Fav [F]"


func _open_folder_dialog() -> void:
	if _dir_dialog == null:
		return
	var cur: String = _pack_dirs[0] if not _pack_dirs.is_empty() else OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
	if not cur.is_empty() and DirAccess.dir_exists_absolute(cur):
		_dir_dialog.current_dir = cur
	_dir_dialog.popup_centered_ratio(0.65)


func _open_file_dialog() -> void:
	if _file_dialog == null:
		return
	var cur: String = OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
	if cur.is_empty() or not DirAccess.dir_exists_absolute(cur):
		cur = _pack_dirs[0] if not _pack_dirs.is_empty() else ""
	if not cur.is_empty() and DirAccess.dir_exists_absolute(cur):
		_file_dialog.current_dir = cur
	_file_dialog.popup_centered_ratio(0.65)


func _handle_path_submit(raw_input: String) -> void:
	var parts: PackedStringArray = raw_input.split(";", false)
	var added_any: bool = false
	for part: String in parts:
		var clean: String = ScannerScript.normalize_path_input(part)
		if clean.is_empty():
			continue
		if clean.get_extension().to_lower() == "zip" and FileAccess.file_exists(clean):
			unpack_detected_zips("", [clean])
			added_any = true
		elif DirAccess.dir_exists_absolute(clean):
			if not _pack_dirs.has(clean):
				_pack_dirs.append(clean)
			added_any = true
	if added_any:
		_rescan_pack_dirs(true)
	else:
		_set_status("No se encontró esa carpeta o .zip: %s" % raw_input)


func _on_files_dropped(files: PackedStringArray) -> void:
	var zips: Array[String] = []
	var first_audio: String = ""
	for raw_f: String in files:
		var p: String = ScannerScript.normalize_path_input(raw_f)
		if DirAccess.dir_exists_absolute(p):
			if not _pack_dirs.has(p):
				_pack_dirs.append(p)
		elif FileAccess.file_exists(p):
			var ext: String = p.get_extension().to_lower()
			if ext == "zip":
				zips.append(p)
			elif ScannerScript.SUPPORTED_EXTENSIONS.has(ext):
				var parent_dir: String = p.get_base_dir()
				if not _pack_dirs.has(parent_dir):
					_pack_dirs.append(parent_dir)
				if first_audio.is_empty():
					first_audio = p
	if not zips.is_empty():
		unpack_detected_zips("", zips)
	elif not _pack_dirs.is_empty():
		_rescan_pack_dirs(true)
	if not first_audio.is_empty():
		for i: int in range(_filtered_entries.size()):
			if str(_filtered_entries[i].get("abs_path", "")) == first_audio:
				select_candidate_index(i)
				break


func _sync_pack_dirs_from_manifest() -> void:
	_pack_dirs.clear()
	var raw_dirs: Variant = _manifest.get("pack_dirs", [])
	if raw_dirs is Array:
		for d_v: Variant in (raw_dirs as Array):
			var clean: String = ScannerScript.normalize_path_input(str(d_v))
			if not clean.is_empty() and DirAccess.dir_exists_absolute(clean) and not _pack_dirs.has(clean):
				_pack_dirs.append(clean)
	if _pack_dirs.is_empty():
		var legacy_root: String = ScannerScript.normalize_path_input(str(_manifest.get("pack_root_dir", "")))
		if not legacy_root.is_empty() and DirAccess.dir_exists_absolute(legacy_root):
			_pack_dirs.append(legacy_root)


func _refresh_zip_button() -> void:
	if _unpack_zips_btn == null:
		return
	var z_count: int = _detected_zips.size()
	_unpack_zips_btn.visible = z_count > 0
	_unpack_zips_btn.text = "Descomprimir ZIPs (%d)" % z_count


func _get_selected_profile_id() -> String:
	return str(_manifest.get("active_profile_id", "stela_signature"))


func _update_progress_banner() -> void:
	if _step_progress_lbl == null:
		return
	var staged_slots: int = _count_staged_slots()
	_step_progress_lbl.text = "Packs: %d · Armados: %d/%d" % [
		_all_entries.size(),
		staged_slots,
		_slot_specs.size(),
	]


func _on_tour_step_changed(slot_key: String, step_idx: int, total: int) -> void:
	select_slot_by_key(slot_key, false)
	_set_status("▶ Tour (%d/%d): probando [%s]..." % [step_idx, total, slot_key])


func _on_tour_finished() -> void:
	if _tour_btn != null:
		_tour_btn.text = "▶ Tour (9 clave)"


func _open_combat_gym() -> void:
	stop_all_audio()
	get_tree().change_scene_to_file(COMBAT_GYM_PATH)


func _on_playhead_updated(ratio: float) -> void:
	if _waveform != null:
		_waveform.set_playhead_ratio(ratio)


func _on_playback_event(label: String) -> void:
	_set_status(label)


func _set_status(msg: String) -> void:
	if _status_lbl != null:
		_status_lbl.text = msg


func _return_to_hub() -> void:
	stop_all_audio()
	get_tree().change_scene_to_file(WORKBENCH_HUB_PATH)

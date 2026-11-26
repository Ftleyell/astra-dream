class_name SfxExporter
extends RefCounted
## Exportador por lotes con normalización FFmpeg, respaldo automático y hot-reload en AudioManager.

const SfxCueBankScript = preload("res://core/audio/sfx_cue_bank.gd")
const PROD_SFX_RES_DIR: String = "res://assets/audio/sfx"
const PROD_AMBIENCE_RES_DIR: String = "res://assets/audio/ambience"


static func get_production_sfx_abs_dir() -> String:
	return ProjectSettings.globalize_path(PROD_SFX_RES_DIR).replace("\\", "/")


static func get_production_ambience_abs_dir() -> String:
	return ProjectSettings.globalize_path(PROD_AMBIENCE_RES_DIR).replace("\\", "/")


static func export_slot(
	slot_spec: Dictionary,
	slot_state: Dictionary,
	target_dir_abs: String = "",
	backup_dir_abs: String = ""
) -> Dictionary:
	var slot_key: String = str(slot_spec.get("key", ""))
	var target_filename: String = str(slot_spec.get("target_filename", ""))
	var raw_candidates: Variant = slot_state.get("candidates", [])
	var candidates: Array[String] = []
	if raw_candidates is Array:
		for c_v: Variant in (raw_candidates as Array):
			var p: String = str(c_v).strip_edges()
			if not p.is_empty():
				candidates.append(p)

	if slot_key.is_empty() or target_filename.is_empty() or candidates.is_empty():
		return {
			"ok": false,
			"exported_files": [] as Array[String],
			"errors": ["El slot '%s' no tiene candidatos asignados." % slot_key] as Array[String],
			"details": [] as Array[Dictionary],
		}

	var is_ambience: bool = bool(slot_spec.get("is_ambience", false))
	var resolved_target_dir: String = target_dir_abs.strip_edges().replace("\\", "/")
	var is_production_dir: bool = false
	if resolved_target_dir.is_empty():
		resolved_target_dir = get_production_ambience_abs_dir() if is_ambience else get_production_sfx_abs_dir()
		is_production_dir = true
	else:
		is_production_dir = (resolved_target_dir == get_production_sfx_abs_dir() or resolved_target_dir == get_production_ambience_abs_dir())

	DirAccess.make_dir_recursive_absolute(resolved_target_dir)

	var resolved_backup_dir: String = backup_dir_abs.strip_edges().replace("\\", "/")
	if resolved_backup_dir.is_empty():
		var stamp: String = Time.get_datetime_string_from_system(false, true).replace(":", "-").replace(" ", "_")
		resolved_backup_dir = OS.get_user_data_dir().path_join("sfx_lab_backups").path_join(stamp)

	var script_abs: String = ProjectSettings.globalize_path("res://tools/normalize_sfx.py")
	if not FileAccess.file_exists(script_abs):
		return {
			"ok": false,
			"exported_files": [] as Array[String],
			"errors": ["Falta tools/normalize_sfx.py"] as Array[String],
			"details": [] as Array[Dictionary],
		}

	var gain_db: float = float(slot_state.get("gain_db", 0.0))
	var trim_silence: bool = bool(slot_state.get("trim_silence", true))
	var mono: bool = bool(slot_state.get("mono", bool(slot_spec.get("default_mono", true))))

	var exported_files: Array[String] = []
	var errors: Array[String] = []
	var details: Array[Dictionary] = []
	var base_name: String = target_filename.get_basename()
	var ext_name: String = target_filename.get_extension()
	if ext_name.is_empty():
		ext_name = "wav"

	for idx: int in range(candidates.size()):
		var src_path: String = candidates[idx]
		var out_name: String = target_filename if idx == 0 else "%s_v%d.%s" % [base_name, idx + 1, ext_name]
		var out_abs: String = resolved_target_dir.path_join(out_name)

		if FileAccess.file_exists(out_abs):
			DirAccess.make_dir_recursive_absolute(resolved_backup_dir)
			var backup_abs: String = resolved_backup_dir.path_join(out_name)
			DirAccess.copy_absolute(out_abs, backup_abs)

		var args := PackedStringArray([
			script_abs,
			"--input", src_path,
			"--output", out_abs,
			"--gain-db", "%.2f" % gain_db,
			"--target-peak-db", "-3.0" if is_ambience else "-1.0",
			"--fade-out-ms", "0.0" if is_ambience else "5.0",
			"--sample-rate", "44100",
		])
		args.append("--trim-silence" if (trim_silence and not is_ambience) else "--no-trim-silence")
		args.append("--mono" if (mono and not is_ambience) else "--stereo")

		var exec_res: Dictionary = _execute_python(args)
		var exit_code: int = int(exec_res.get("exit_code", -1))
		var stdout_text: String = str(exec_res.get("stdout", ""))
		var parsed: Dictionary = _parse_last_json_line(stdout_text)

		if exit_code == 0 and bool(parsed.get("ok", false)) and FileAccess.file_exists(out_abs):
			exported_files.append(out_abs)
			details.append(parsed)
		else:
			var err_msg: String = str(parsed.get("error", stdout_text.strip_edges()))
			if err_msg.is_empty():
				err_msg = "Exit code %d exportando %s" % [exit_code, out_name]
			errors.append(err_msg)

	var layer2_path: String = str(slot_state.get("layer2_candidate", "")).strip_edges()
	if not layer2_path.is_empty() and not is_ambience:
		var l2_name: String = "%s_layer2.%s" % [base_name, ext_name]
		var l2_out: String = resolved_target_dir.path_join(l2_name)
		if FileAccess.file_exists(l2_out):
			DirAccess.make_dir_recursive_absolute(resolved_backup_dir)
			DirAccess.copy_absolute(l2_out, resolved_backup_dir.path_join(l2_name))
		var l2_args := PackedStringArray([
			script_abs,
			"--input", layer2_path,
			"--output", l2_out,
			"--gain-db", "%.2f" % gain_db,
			"--target-peak-db", "-1.0",
			"--fade-out-ms", "5.0",
			"--sample-rate", "44100",
			"--trim-silence",
			"--stereo",
		])
		var l2_exec: Dictionary = _execute_python(l2_args)
		var l2_parsed: Dictionary = _parse_last_json_line(str(l2_exec.get("stdout", "")))
		if int(l2_exec.get("exit_code", -1)) == 0 and bool(l2_parsed.get("ok", false)) and FileAccess.file_exists(l2_out):
			exported_files.append(l2_out)
			details.append(l2_parsed)
		else:
			errors.append(str(l2_parsed.get("error", "Error exportando capa 2")))

	if is_production_dir and not exported_files.is_empty():
		SfxCueBankScript.rebuild_and_save_default_bank()
		if AudioManager != null and AudioManager.has_method("reload_cue_bank"):
			AudioManager.reload_cue_bank()
		_hot_reload_audio_manager(slot_key, exported_files[0])

	return {
		"ok": errors.is_empty() and not exported_files.is_empty(),
		"exported_files": exported_files,
		"errors": errors,
		"details": details,
	}


static func _execute_python(args: PackedStringArray) -> Dictionary:
	var output: Array = []
	var exit_code: int = OS.execute("python", args, output, true)
	if exit_code == -1:
		output.clear()
		exit_code = OS.execute("py", args, output, true)
	var joined: String = ""
	for line_v: Variant in output:
		joined += str(line_v) + "\n"
	return {"exit_code": exit_code, "stdout": joined}


static func _parse_last_json_line(raw_text: String) -> Dictionary:
	var lines: PackedStringArray = raw_text.split("\n", false)
	for i: int in range(lines.size() - 1, -1, -1):
		var line: String = lines[i].strip_edges()
		if line.begins_with("{") and line.ends_with("}"):
			var parsed: Variant = JSON.parse_string(line)
			if parsed is Dictionary:
				return parsed as Dictionary
	return {}


static func _hot_reload_audio_manager(slot_key: String, wav_abs_path: String) -> void:
	if AudioManager == null or not FileAccess.file_exists(wav_abs_path):
		return
	var wav: AudioStreamWAV = AudioStreamWAV.load_from_file(wav_abs_path)
	if wav != null:
		AudioManager.sfx_streams[slot_key] = wav

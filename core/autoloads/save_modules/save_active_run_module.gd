class_name SaveActiveRunModule
extends RefCounted

## SaveActiveRunModule.gd
## Manejo especializado de serialización de runs activas (Mid-run resume) y tabla de récords (Highscores).

const ACTIVE_RUN_PATH := "user://active_run.json"
const HIGHSCORES_PATH := "user://highscores.json"
const MAX_HIGHSCORES := 10

static func save_active_run(run_data: Dictionary) -> Error:
	var file := FileAccess.open(ACTIVE_RUN_PATH, FileAccess.WRITE)
	if not file:
		return FileAccess.get_open_error()

	var json_str := JSON.stringify(run_data, "\t")
	file.store_string(json_str)
	file.close()
	return OK

static func has_active_run() -> bool:
	return FileAccess.file_exists(ACTIVE_RUN_PATH)

static func load_active_run() -> Dictionary:
	if not has_active_run():
		return {}
	var file := FileAccess.open(ACTIVE_RUN_PATH, FileAccess.READ)
	if not file:
		return {}
	var json_str := file.get_as_text()
	file.close()
	var parser := JSON.new()
	var err := parser.parse(json_str)
	if err != OK or not (parser.data is Dictionary):
		return {}
	return parser.data

static func clear_active_run() -> void:
	if has_active_run():
		DirAccess.remove_absolute(ACTIVE_RUN_PATH)

static func record_run_score(result: Dictionary) -> int:
	var scores := get_top_highscores()

	var new_entry := {
		"pilot_id": str(result.get("pilot_id", "nova")),
		"pilot_name": str(result.get("pilot_name", "Nova")),
		"wave_reached": int(result.get("wave_reached", 1)),
		"time_survived_seconds": float(result.get("time_survived_seconds", 0.0)),
		"time_survived_formatted": str(result.get("time_survived_formatted", "00:00")),
		"enemies_killed": int(result.get("enemies_killed", 0)),
		"credits_earned": int(result.get("credits_earned", 0)),
		"victory": bool(result.get("victory", false)),
		"score": int(result.get("score", 0)),
		"date": Time.get_datetime_string_from_system(false, true)
	}

	scores.append(new_entry)

	scores.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var wave_a: int = a.get("wave_reached", 0)
		var wave_b: int = b.get("wave_reached", 0)
		if wave_a != wave_b:
			return wave_a > wave_b
		var time_a: float = a.get("time_survived_seconds", 0.0)
		var time_b: float = b.get("time_survived_seconds", 0.0)
		if time_a != time_b:
			return time_a > time_b
		return int(a.get("enemies_killed", 0)) > int(b.get("enemies_killed", 0))
	)

	if scores.size() > MAX_HIGHSCORES:
		scores.resize(MAX_HIGHSCORES)

	var file := FileAccess.open(HIGHSCORES_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(scores, "\t"))
		file.close()

	for idx in range(scores.size()):
		if scores[idx] == new_entry:
			return idx + 1
	return -1

static func clear_highscores() -> void:
	if FileAccess.file_exists(HIGHSCORES_PATH):
		DirAccess.remove_absolute(HIGHSCORES_PATH)

static func get_top_highscores() -> Array[Dictionary]:
	if not FileAccess.file_exists(HIGHSCORES_PATH):
		return _get_default_highscores()

	var file := FileAccess.open(HIGHSCORES_PATH, FileAccess.READ)
	if not file:
		return _get_default_highscores()

	var json_str := file.get_as_text()
	file.close()

	var parser := JSON.new()
	var err := parser.parse(json_str)
	if err != OK or not (parser.data is Array):
		return _get_default_highscores()

	var res: Array[Dictionary] = []
	for item in parser.data:
		if item is Dictionary:
			res.append(item)
	return res

static func _get_default_highscores() -> Array[Dictionary]:
	return [
		{
			"pilot_id": "nova",
			"pilot_name": "Nova",
			"wave_reached": 6,
			"time_survived_seconds": 360.0,
			"time_survived_formatted": "06:00",
			"enemies_killed": 420,
			"credits_earned": 350,
			"victory": true,
			"date": "2026-09-20 12:00"
		}
	]

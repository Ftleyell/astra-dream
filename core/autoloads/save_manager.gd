extends Node

static var is_resuming_run: bool = false

const SAVE_PATH := "user://profile_data.json"
const SCHEMA_VERSION := 1

static func save_profile(unlocked_items: Array[StringName], character_bans: Dictionary, unlocked_chars: Array[StringName] = [], p_biomass: int = -1, p_antimatter: int = -1, p_skills: Variant = null, p_selected_char: StringName = &"") -> Error:
	var current_biomass: int = p_biomass
	if current_biomass < 0:
		current_biomass = get_biomass()

	var current_antimatter: int = p_antimatter
	if current_antimatter < 0:
		current_antimatter = get_antimatter()

	var current_skills: Dictionary
	if p_skills == null:
		var prof := load_profile()
		current_skills = prof.get("character_skills", {})
	else:
		current_skills = p_skills

	var current_char: StringName = p_selected_char
	if current_char == &"":
		var prof := load_profile()
		current_char = StringName(str(prof.get("selected_character", "nova")))

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		return FileAccess.get_open_error()

	var bans_serializable: Dictionary = {}
	for char_id: StringName in character_bans.keys():
		var bans: Array = character_bans[char_id]
		var str_list: Array[String] = []
		for item_id in bans:
			str_list.append(String(item_id))
		bans_serializable[String(char_id)] = str_list

	var str_unlocked_items: Array[String] = []
	for item_id in unlocked_items:
		str_unlocked_items.append(String(item_id))

	var str_unlocked_chars: Array[String] = []
	for char_id in unlocked_chars:
		str_unlocked_chars.append(String(char_id))

	var skills_serializable: Dictionary = {}
	for cid in current_skills.keys():
		var arr: Array = current_skills[cid]
		var str_arr: Array[String] = []
		for n in arr:
			str_arr.append(str(n))
		skills_serializable[String(cid)] = str_arr

	var payload := {
		"version": SCHEMA_VERSION,
		"unlocked_items": str_unlocked_items,
		"unlocked_characters": str_unlocked_chars,
		"character_banlists": bans_serializable,
		"biomass": current_biomass,
		"antimatter": current_antimatter,
		"character_skills": skills_serializable,
		"selected_character": String(current_char)
	}

	var json_str := JSON.stringify(payload, "\t")
	file.store_string(json_str)
	file.close()
	return OK

static func load_profile() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return _get_default_profile()

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return _get_default_profile()

	var json_str := file.get_as_text()
	file.close()

	var parser := JSON.new()
	var err := parser.parse(json_str)
	if err != OK:
		push_error("Error parsing save file: %s" % parser.get_error_message())
		return _get_default_profile()

	var data: Dictionary = parser.data
	return _clean_and_validate_data(data)

static func _get_default_profile() -> Dictionary:
	return {
		"unlocked_items": [
			&"botas", &"espada", &"escudo", &"corazon", &"manzana",
			&"iman", &"gafas", &"lupa", &"guante", &"trebol", &"carcaj"
		] as Array[StringName],
		"unlocked_characters": [
			&"nova", &"valentina", &"kira", &"selene", &"roxy", &"echo"
		] as Array[StringName],
		"character_banlists": {
			&"nova": [&"escudo"] as Array[StringName],
			&"valentina": [&"manzana"] as Array[StringName]
		} as Dictionary,
		"biomass": 0,
		"antimatter": 0,
		"character_skills": {} as Dictionary,
		"selected_character": &"nova"
	}

static func _clean_and_validate_data(raw: Dictionary) -> Dictionary:
	var cleaned := {
		"unlocked_items": [] as Array[StringName],
		"unlocked_characters": [] as Array[StringName],
		"character_banlists": {} as Dictionary,
		"biomass": int(raw.get("biomass", 0)),
		"antimatter": int(raw.get("antimatter", 0)),
		"character_skills": {} as Dictionary,
		"selected_character": StringName(str(raw.get("selected_character", "nova")))
	}

	if raw.has("unlocked_items"):
		for item in raw["unlocked_items"]:
			cleaned["unlocked_items"].append(StringName(item))

	if raw.has("unlocked_characters"):
		for ch in raw["unlocked_characters"]:
			cleaned["unlocked_characters"].append(StringName(ch))
	else:
		cleaned["unlocked_characters"] = [&"nova", &"valentina", &"kira", &"selene", &"roxy", &"echo"]

	if raw.has("character_banlists"):
		for char_id in raw["character_banlists"].keys():
			var bans: Array[StringName] = []
			for b in raw["character_banlists"][char_id]:
				bans.append(StringName(b))
			cleaned["character_banlists"][StringName(char_id)] = bans

	if raw.has("character_skills") and raw["character_skills"] is Dictionary:
		for cid in raw["character_skills"].keys():
			var arr: Array = raw["character_skills"][cid]
			var str_arr: Array[StringName] = []
			for n in arr:
				str_arr.append(StringName(str(n)))
			cleaned["character_skills"][StringName(cid)] = str_arr

	return cleaned

## Obtiene la cantidad persistente total de BioMasa acumulada
static func get_biomass() -> int:
	var profile := load_profile()
	return int(profile.get("biomass", 0))

## Agrega BioMasa persistente y guarda inmediatamente el perfil
static func add_biomass(amount: int) -> int:
	if amount <= 0:
		return get_biomass()
	var profile := load_profile()
	var new_total: int = int(profile.get("biomass", 0)) + amount
	var unlocked_items: Array[StringName] = profile.get("unlocked_items", [])
	var unlocked_chars: Array[StringName] = profile.get("unlocked_characters", [])
	var bans: Dictionary = profile.get("character_banlists", {})
	var antimatter: int = int(profile.get("antimatter", 0))
	var skills: Dictionary = profile.get("character_skills", {})
	save_profile(unlocked_items, bans, unlocked_chars, new_total, antimatter, skills)
	return new_total

## Atajo de test para sumar BioMasa
static func add_test_biomass(amount: int = 100) -> int:
	return add_biomass(amount)

## Obtiene la cantidad persistente total de Antimateria acumulada
static func get_antimatter() -> int:
	var profile := load_profile()
	return int(profile.get("antimatter", 0))

## Agrega Antimateria persistente y guarda inmediatamente el perfil
static func add_antimatter(amount: int) -> int:
	if amount <= 0:
		return get_antimatter()
	var profile := load_profile()
	var new_total: int = int(profile.get("antimatter", 0)) + amount
	var unlocked_items: Array[StringName] = profile.get("unlocked_items", [])
	var unlocked_chars: Array[StringName] = profile.get("unlocked_characters", [])
	var bans: Dictionary = profile.get("character_banlists", {})
	var biomass: int = int(profile.get("biomass", 0))
	var skills: Dictionary = profile.get("character_skills", {})
	save_profile(unlocked_items, bans, unlocked_chars, biomass, new_total, skills)
	return new_total

## Obtiene la lista de IDs de nodos de habilidad desbloqueados para un personaje
static func get_character_unlocked_nodes(char_id: StringName) -> Array[StringName]:
	var profile := load_profile()
	var skills: Dictionary = profile.get("character_skills", {})
	var list: Array = skills.get(char_id, skills.get(String(char_id), []))
	var result: Array[StringName] = []
	for n in list:
		var s := StringName(str(n))
		if not result.has(s):
			result.append(s)
	if not result.has(&"core"):
		result.append(&"core")
	return result

## Verifica si un nodo específico está desbloqueado
static func is_character_node_unlocked(char_id: StringName, node_id: StringName) -> bool:
	var unlocked := get_character_unlocked_nodes(char_id)
	return unlocked.has(node_id)

## Obtiene el conteo total de nodos de habilidad desbloqueados para un personaje (sin contar el core)
static func get_character_unlocked_nodes_count(char_id: StringName) -> int:
	var nodes := get_character_unlocked_nodes(char_id)
	var count: int = 0
	for n in nodes:
		if n != &"core":
			count += 1
	return count

## Desbloquea un nodo del árbol de habilidades deduciendo BioMasa y persistiendo en disco
static func unlock_character_skill_node(char_id: StringName, node_id: StringName, cost: int, req_node_id: StringName = &"") -> bool:
	var current_bio := get_biomass()
	if current_bio < cost:
		return false

	var profile := load_profile()
	var skills: Dictionary = profile.get("character_skills", {})
	var list: Array = skills.get(char_id, skills.get(String(char_id), []))
	var str_list: Array[StringName] = []
	for n in list:
		str_list.append(StringName(str(n)))
	if not str_list.has(&"core"):
		str_list.append(&"core")

	# Si ya está desbloqueado, no volver a comprar
	if str_list.has(node_id):
		return false

	# Requiere haber desbloqueado el nodo previo requerido (si se especifica)
	if req_node_id != &"" and not str_list.has(req_node_id):
		return false

	str_list.append(node_id)
	skills[char_id] = str_list

	var new_biomass := current_bio - cost
	var unlocked_items: Array[StringName] = profile.get("unlocked_items", [])
	var unlocked_chars: Array[StringName] = profile.get("unlocked_characters", [])
	var bans: Dictionary = profile.get("character_banlists", {})
	var antimatter: int = int(profile.get("antimatter", 0))

	save_profile(unlocked_items, bans, unlocked_chars, new_biomass, antimatter, skills)
	return true

## Reembolsa todos los nodos comprados para este personaje y devuelve la BioMasa
static func refund_character_skills(char_id: StringName, node_cost: int = 25) -> int:
	var profile := load_profile()
	var skills: Dictionary = profile.get("character_skills", {})
	var list: Array = skills.get(char_id, skills.get(String(char_id), []))

	var paid_nodes: int = 0
	for n in list:
		var s := StringName(str(n))
		if s != &"core":
			paid_nodes += 1

	var refund_biomass := paid_nodes * node_cost
	skills[char_id] = [&"core"] as Array[StringName]

	var current_bio: int = int(profile.get("biomass", 0))
	var new_biomass := current_bio + refund_biomass
	var unlocked_items: Array[StringName] = profile.get("unlocked_items", [])
	var unlocked_chars: Array[StringName] = profile.get("unlocked_characters", [])
	var bans: Dictionary = profile.get("character_banlists", {})
	var antimatter: int = int(profile.get("antimatter", 0))

	save_profile(unlocked_items, bans, unlocked_chars, new_biomass, antimatter, skills)
	return refund_biomass

## Obtiene el ID del personaje seleccionado actualmente para el combate
static func get_selected_character() -> StringName:
	var profile := load_profile()
	return StringName(str(profile.get("selected_character", "nova")))

## Establece el ID del personaje seleccionado para el combate y guarda el perfil
static func set_selected_character(char_id: StringName) -> void:
	if char_id == &"":
		return
	var profile := load_profile()
	var unlocked_items: Array[StringName] = profile.get("unlocked_items", [])
	var unlocked_chars: Array[StringName] = profile.get("unlocked_characters", [])
	var bans: Dictionary = profile.get("character_banlists", {})
	var biomass: int = int(profile.get("biomass", 0))
	var antimatter: int = int(profile.get("antimatter", 0))
	var skills: Dictionary = profile.get("character_skills", {})
	save_profile(unlocked_items, bans, unlocked_chars, biomass, antimatter, skills, char_id)

# ==============================================================================
# MID-RUN SAVE & RESUME (Partida en Curso)
# ==============================================================================

const ACTIVE_RUN_PATH := "user://active_run.json"

## Guarda el estado actual de la run en curso a disco
static func save_active_run(run_data: Dictionary) -> Error:
	var file := FileAccess.open(ACTIVE_RUN_PATH, FileAccess.WRITE)
	if not file:
		return FileAccess.get_open_error()

	var json_str := JSON.stringify(run_data, "\t")
	file.store_string(json_str)
	file.close()
	return OK

## Comprueba si existe una run guardada en curso
static func has_active_run() -> bool:
	return FileAccess.file_exists(ACTIVE_RUN_PATH)

## Carga los datos de la run en curso
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

## Elimina el archivo de la run en curso (Permadeath / Fin de partida)
static func clear_active_run() -> void:
	if has_active_run():
		DirAccess.remove_absolute(ACTIVE_RUN_PATH)

# ==============================================================================
# HIGHSCORES & RUN HISTORY (Top 10 Récords)
# ==============================================================================

const HIGHSCORES_PATH := "user://highscores.json"
const MAX_HIGHSCORES := 10

## Registra el resultado final de una partida en la tabla de Highscores
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
		"date": Time.get_datetime_string_from_system(false, true)
	}

	scores.append(new_entry)

	# Ordenar por: 1) Mayor oleada alcanzada, 2) Mayor tiempo de supervivencia, 3) Más enemigos eliminados
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

	# Limitar a los 10 mejores
	if scores.size() > MAX_HIGHSCORES:
		scores.resize(MAX_HIGHSCORES)

	var file := FileAccess.open(HIGHSCORES_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(scores, "\t"))
		file.close()

	# Retornar la posición alcanzada (1 a 10) o -1 si no entró
	for idx in range(scores.size()):
		if scores[idx] == new_entry:
			return idx + 1
	return -1

## Limpia la tabla de highscores (útil para tests o reseteo)
static func clear_highscores() -> void:
	if FileAccess.file_exists(HIGHSCORES_PATH):
		DirAccess.remove_absolute(HIGHSCORES_PATH)

## Obtiene la lista ordenada de los 10 mejores récords locales
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
	# Récords iniciales de muestra
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
		},
		{
			"pilot_id": "echo",
			"pilot_name": "Echo",
			"wave_reached": 4,
			"time_survived_seconds": 240.0,
			"time_survived_formatted": "04:00",
			"enemies_killed": 280,
			"credits_earned": 210,
			"victory": false,
			"date": "2026-09-20 11:30"
		},
		{
			"pilot_id": "selene",
			"pilot_name": "Selene",
			"wave_reached": 2,
			"time_survived_seconds": 120.0,
			"time_survived_formatted": "02:00",
			"enemies_killed": 110,
			"credits_earned": 95,
			"victory": false,
			"date": "2026-09-20 10:15"
		}
	]


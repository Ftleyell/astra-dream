class_name SaveManager
extends Node

const SAVE_PATH := "user://profile_data.json"
const SCHEMA_VERSION := 1

static func save_profile(unlocked_items: Array[StringName], character_bans: Dictionary, unlocked_chars: Array[StringName] = [], p_biomass: int = -1) -> Error:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		return FileAccess.get_open_error()

	var current_biomass: int = p_biomass
	if current_biomass < 0:
		current_biomass = get_biomass()

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

	var payload := {
		"version": SCHEMA_VERSION,
		"unlocked_items": str_unlocked_items,
		"unlocked_characters": str_unlocked_chars,
		"character_banlists": bans_serializable,
		"biomass": current_biomass
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
		"biomass": 0
	}

static func _clean_and_validate_data(raw: Dictionary) -> Dictionary:
	var cleaned := {
		"unlocked_items": [] as Array[StringName],
		"unlocked_characters": [] as Array[StringName],
		"character_banlists": {} as Dictionary,
		"biomass": int(raw.get("biomass", 0))
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
	save_profile(unlocked_items, bans, unlocked_chars, new_total)
	return new_total

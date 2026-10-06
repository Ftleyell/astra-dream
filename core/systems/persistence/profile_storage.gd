class_name ProfileStorage
extends RefCounted

## Gestor de lectura, escritura física y validación de esquema para el perfil de usuario.

const SAVE_PATH: String = "user://profile_data.json"
const SCHEMA_VERSION: int = 2

static func get_default_career_stats() -> Dictionary:
	return {
		"total_time_survived": 0.0,
		"total_credits_collected": 0,
		"total_biomass_collected": 0,
		"total_enemies_killed": 0,
		"total_bosses_killed": 0,
		"total_satellites_activated": 0,
		"total_runs_played": 0,
		"total_runs_cleared": 0
	}

static func get_default_profile() -> Dictionary:
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
		"dark_matter": 0,
		"trophies_unlocked": {
			"trophy_boss_aegis": 0,
			"trophy_biosphere_core": 0,
			"trophy_cryo_core": 0,
			"trophy_volcanic_core": 0,
			"trophy_monolith_master": 0
		},
		"character_skills": {} as Dictionary,
		"selected_character": &"nova",
		"game_speed": 1.0,
		"career_stats": get_default_career_stats(),
		"selected_pet": &"mochi",
		"unlocked_pets": [&"mochi", &"kuro", &"luna", &"pip"] as Array[StringName],
		"unlocked_endings": [] as Array[String],
		"selected_navigator": &"lyra",
		"unlocked_navigators": [&"lyra", &"vespera", &"caelia", &"zephyr"] as Array[StringName],
		"gacha_tokens": 0,
		"unlocked_skins": {} as Dictionary,
		"equipped_skins": {} as Dictionary,
		"gacha_pity": {"general": 0, "ships": 0, "pilots": 0} as Dictionary,
		"character_active_tomes": {} as Dictionary,
		"character_active_weapons": {} as Dictionary,
		"character_loadouts": {} as Dictionary
	}

static func save_profile(
	unlocked_items: Array[StringName],
	character_bans: Dictionary,
	unlocked_chars: Array[StringName] = [],
	p_biomass: int = -1,
	p_antimatter: int = -1,
	p_skills: Variant = null,
	p_selected_char: StringName = &"",
	p_dark_matter: int = -1,
	p_trophies: Variant = null,
	p_game_speed: float = -1.0,
	p_career_stats: Variant = null,
	p_selected_pet: StringName = &"",
	p_unlocked_pets: Variant = null,
	p_unlocked_endings: Variant = null,
	p_selected_navigator: StringName = &"",
	p_unlocked_navigators: Variant = null,
	p_gacha_tokens: int = -1,
	p_unlocked_skins: Variant = null,
	p_equipped_skins: Variant = null,
	p_gacha_pity: Variant = null
) -> Error:
	var existing_prof: Dictionary = load_profile()

	var current_speed: float = p_game_speed
	if current_speed <= 0.0:
		current_speed = float(existing_prof.get("game_speed", 1.0))
	if current_speed <= 0.0:
		current_speed = 1.0

	var current_biomass: int = p_biomass
	if current_biomass < 0:
		current_biomass = int(existing_prof.get("biomass", 0))

	var current_antimatter: int = p_antimatter
	if current_antimatter < 0:
		current_antimatter = int(existing_prof.get("antimatter", 0))

	var current_dark_matter: int = p_dark_matter
	if current_dark_matter < 0:
		current_dark_matter = int(existing_prof.get("dark_matter", 0))

	var current_trophies: Dictionary
	if p_trophies == null:
		current_trophies = existing_prof.get("trophies_unlocked", {})
	else:
		current_trophies = p_trophies

	var current_skills: Dictionary
	if p_skills == null:
		current_skills = existing_prof.get("character_skills", {})
	else:
		current_skills = p_skills

	var current_char: StringName = p_selected_char
	if current_char == &"":
		current_char = StringName(str(existing_prof.get("selected_character", "nova")))

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

	var trophies_serializable: Dictionary = {}
	for tid in current_trophies.keys():
		trophies_serializable[str(tid)] = int(current_trophies[tid])

	var current_career: Dictionary
	if p_career_stats == null:
		current_career = existing_prof.get("career_stats", get_default_career_stats())
	else:
		current_career = p_career_stats

	var current_pet: StringName = p_selected_pet
	if current_pet == &"":
		current_pet = StringName(str(existing_prof.get("selected_pet", "mochi")))

	var str_unlocked_pets: Array[String] = []
	if p_unlocked_pets != null:
		for p in p_unlocked_pets:
			str_unlocked_pets.append(String(p))
	else:
		var raw_pets: Array = existing_prof.get("unlocked_pets", ["mochi", "kuro", "luna", "pip"])
		for p in raw_pets:
			str_unlocked_pets.append(String(p))

	var str_unlocked_endings: Array[String] = []
	if p_unlocked_endings != null:
		for e in p_unlocked_endings:
			str_unlocked_endings.append(String(e))
	else:
		var raw_endings: Array = existing_prof.get("unlocked_endings", [])
		for e in raw_endings:
			str_unlocked_endings.append(String(e))

	var current_nav: StringName = p_selected_navigator
	if current_nav == &"":
		current_nav = StringName(str(existing_prof.get("selected_navigator", "lyra")))

	var str_unlocked_navs: Array[String] = []
	if p_unlocked_navigators != null:
		for n in p_unlocked_navigators:
			str_unlocked_navs.append(String(n))
	else:
		var raw_navs: Array = existing_prof.get("unlocked_navigators", ["lyra", "vespera", "caelia", "zephyr"])
		for n in raw_navs:
			str_unlocked_navs.append(String(n))

	var current_tokens: int = p_gacha_tokens
	if current_tokens < 0:
		current_tokens = int(existing_prof.get("gacha_tokens", 0))

	var current_unlocked_skins: Dictionary
	if p_unlocked_skins != null and p_unlocked_skins is Dictionary:
		current_unlocked_skins = p_unlocked_skins
	else:
		current_unlocked_skins = existing_prof.get("unlocked_skins", {})

	var current_equipped_skins: Dictionary
	if p_equipped_skins != null and p_equipped_skins is Dictionary:
		current_equipped_skins = p_equipped_skins
	else:
		current_equipped_skins = existing_prof.get("equipped_skins", {})

	var current_gacha_pity: Dictionary
	if p_gacha_pity != null and p_gacha_pity is Dictionary:
		current_gacha_pity = p_gacha_pity
	else:
		current_gacha_pity = existing_prof.get("gacha_pity", {"general": 0, "ships": 0, "pilots": 0})

	var payload: Dictionary = {
		"version": SCHEMA_VERSION,
		"unlocked_items": str_unlocked_items,
		"unlocked_characters": str_unlocked_chars,
		"character_banlists": bans_serializable,
		"biomass": current_biomass,
		"antimatter": current_antimatter,
		"dark_matter": current_dark_matter,
		"trophies_unlocked": trophies_serializable,
		"character_skills": skills_serializable,
		"selected_character": String(current_char),
		"game_speed": current_speed,
		"career_stats": current_career,
		"selected_pet": String(current_pet),
		"unlocked_pets": str_unlocked_pets,
		"unlocked_endings": str_unlocked_endings,
		"selected_navigator": String(current_nav),
		"unlocked_navigators": str_unlocked_navs,
		"gacha_tokens": current_tokens,
		"unlocked_skins": current_unlocked_skins,
		"equipped_skins": current_equipped_skins,
		"gacha_pity": current_gacha_pity,
		"character_active_tomes": existing_prof.get("character_active_tomes", {}),
		"character_active_weapons": existing_prof.get("character_active_weapons", {}),
		"character_loadouts": existing_prof.get("character_loadouts", {})
	}

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		return FileAccess.get_open_error()

	var json_str := JSON.stringify(payload, "\t")
	file.store_string(json_str)
	file.close()
	return OK

static func load_profile() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return get_default_profile()

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return get_default_profile()

	var json_str := file.get_as_text()
	file.close()

	if json_str.strip_edges().is_empty():
		return get_default_profile()

	var parser := JSON.new()
	var err := parser.parse(json_str)
	if err != OK:
		push_error("Error parsing save file: %s" % parser.get_error_message())
		return get_default_profile()

	var data: Dictionary = parser.data
	return clean_and_validate_data(data)

static func clean_and_validate_data(raw: Dictionary) -> Dictionary:
	var default_trophies: Dictionary = {
		"trophy_boss_aegis": 0,
		"trophy_biosphere_core": 0,
		"trophy_cryo_core": 0,
		"trophy_volcanic_core": 0,
		"trophy_monolith_master": 0
	}
	var trophies_clean: Dictionary = default_trophies.duplicate()
	if raw.has("trophies_unlocked") and raw["trophies_unlocked"] is Dictionary:
		for t_id in raw["trophies_unlocked"].keys():
			trophies_clean[str(t_id)] = int(raw["trophies_unlocked"][t_id])

	var career_clean: Dictionary = get_default_career_stats()
	if raw.has("career_stats") and raw["career_stats"] is Dictionary:
		var raw_c: Dictionary = raw["career_stats"]
		career_clean["total_time_survived"] = float(raw_c.get("total_time_survived", 0.0))
		career_clean["total_credits_collected"] = int(raw_c.get("total_credits_collected", 0))
		career_clean["total_biomass_collected"] = int(raw_c.get("total_biomass_collected", 0))
		career_clean["total_enemies_killed"] = int(raw_c.get("total_enemies_killed", 0))
		career_clean["total_bosses_killed"] = int(raw_c.get("total_bosses_killed", 0))
		career_clean["total_satellites_activated"] = int(raw_c.get("total_satellites_activated", 0))
		career_clean["total_runs_played"] = int(raw_c.get("total_runs_played", 0))
		career_clean["total_runs_cleared"] = int(raw_c.get("total_runs_cleared", 0))

	var cleaned: Dictionary = {
		"unlocked_items": [] as Array[StringName],
		"unlocked_characters": [] as Array[StringName],
		"character_banlists": {} as Dictionary,
		"biomass": int(raw.get("biomass", 0)),
		"antimatter": int(raw.get("antimatter", 0)),
		"dark_matter": int(raw.get("dark_matter", 0)),
		"trophies_unlocked": trophies_clean,
		"character_skills": {} as Dictionary,
		"selected_character": StringName(str(raw.get("selected_character", "nova"))),
		"game_speed": float(raw.get("game_speed", 1.0)),
		"career_stats": career_clean,
		"selected_pet": StringName(str(raw.get("selected_pet", "mochi"))),
		"unlocked_pets": [] as Array[StringName],
		"unlocked_endings": [] as Array[String],
		"selected_navigator": StringName(str(raw.get("selected_navigator", "lyra"))),
		"unlocked_navigators": [] as Array[StringName],
		"gacha_tokens": int(raw.get("gacha_tokens", 0)),
		"unlocked_skins": raw.get("unlocked_skins", {}) as Dictionary,
		"equipped_skins": raw.get("equipped_skins", {}) as Dictionary,
		"character_active_tomes": raw.get("character_active_tomes", {}) as Dictionary,
		"character_active_weapons": raw.get("character_active_weapons", {}) as Dictionary,
		"character_loadouts": {} as Dictionary,
		"gacha_pity": {
			"general": int(raw.get("gacha_pity", {}).get("general", 0)),
			"ships": int(raw.get("gacha_pity", {}).get("ships", 0)),
			"pilots": int(raw.get("gacha_pity", {}).get("pilots", 0))
		} as Dictionary
	}

	var raw_loadouts: Dictionary = raw.get("character_loadouts", {})
	var clean_loadouts: Dictionary = {}
	for c_name in [&"nova", &"echo", &"valentina", &"roxy"]:
		var c_str := String(c_name)
		var c_loadout: Dictionary = raw_loadouts.get(c_str, {}).duplicate() if raw_loadouts.has(c_str) else {}
		if not c_loadout.has("selected_pet") or str(c_loadout["selected_pet"]).is_empty():
			c_loadout["selected_pet"] = &"mochi"
		if not c_loadout.has("selected_navigator") or str(c_loadout["selected_navigator"]).is_empty():
			c_loadout["selected_navigator"] = &"lyra"
		if not c_loadout.has("equipped_pet_skin"):
			c_loadout["equipped_pet_skin"] = ""
		if not c_loadout.has("equipped_navigator_skin"):
			c_loadout["equipped_navigator_skin"] = ""
		if not c_loadout.has("equipped_ship_skin") or str(c_loadout["equipped_ship_skin"]).is_empty():
			c_loadout["equipped_ship_skin"] = "base"
		if not c_loadout.has("equipped_weapon_skin") or str(c_loadout["equipped_weapon_skin"]).is_empty():
			c_loadout["equipped_weapon_skin"] = "base"
		if not c_loadout.has("equipped_pilot_skin") or str(c_loadout["equipped_pilot_skin"]).is_empty():
			c_loadout["equipped_pilot_skin"] = "base"
		clean_loadouts[c_str] = c_loadout
	cleaned["character_loadouts"] = clean_loadouts

	if raw.has("unlocked_endings") and (raw["unlocked_endings"] is Array):
		for e in raw["unlocked_endings"]:
			cleaned["unlocked_endings"].append(String(e))

	if cleaned["selected_pet"] == &"":
		cleaned["selected_pet"] = &"mochi"

	if raw.has("unlocked_pets") and (raw["unlocked_pets"] is Array) and not raw["unlocked_pets"].is_empty():
		for p in raw["unlocked_pets"]:
			cleaned["unlocked_pets"].append(StringName(p))
	else:
		cleaned["unlocked_pets"] = [&"mochi", &"kuro", &"luna", &"pip"]

	for default_pid in [&"mochi", &"kuro", &"luna", &"pip"]:
		if not cleaned["unlocked_pets"].has(default_pid):
			cleaned["unlocked_pets"].append(default_pid)

	if cleaned["selected_navigator"] == &"":
		cleaned["selected_navigator"] = &"lyra"

	if raw.has("unlocked_navigators") and (raw["unlocked_navigators"] is Array) and not raw["unlocked_navigators"].is_empty():
		for n in raw["unlocked_navigators"]:
			cleaned["unlocked_navigators"].append(StringName(n))
	else:
		cleaned["unlocked_navigators"] = [&"lyra", &"vespera", &"caelia", &"zephyr"]

	for default_nid in [&"lyra", &"vespera", &"caelia", &"zephyr"]:
		if not cleaned["unlocked_navigators"].has(default_nid):
			cleaned["unlocked_navigators"].append(default_nid)

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


const TomeCatalogScript = preload("res://data/tomes/tome_catalog.gd")


static func get_character_active_tomes(char_id: StringName) -> Array[StringName]:
	var prof: Dictionary = load_profile()
	var tomes_dict: Dictionary = prof.get("character_active_tomes", {})
	if tomes_dict.has(str(char_id)):
		var raw_arr: Array = tomes_dict[str(char_id)]
		var result: Array[StringName] = []
		for item in raw_arr:
			result.append(StringName(str(item)))
		if not result.is_empty():
			return result
	return TomeCatalogScript.ALL_TOME_IDS.duplicate()


static func set_character_active_tomes(char_id: StringName, tomes: Array[StringName]) -> void:
	var prof: Dictionary = load_profile()
	var tomes_dict: Dictionary = prof.get("character_active_tomes", {}).duplicate()
	var str_arr: Array[String] = []
	for t: StringName in tomes:
		str_arr.append(str(t))
	tomes_dict[str(char_id)] = str_arr
	prof["character_active_tomes"] = tomes_dict

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(prof, "\t"))
		file.close()


const WeaponCatalogScript = preload("res://data/weapons/weapon_catalog.gd")


static func get_character_active_weapons(char_id: StringName) -> Array[StringName]:
	var prof: Dictionary = load_profile()
	var weapons_dict: Dictionary = prof.get("character_active_weapons", {})
	if weapons_dict.has(str(char_id)):
		var raw_arr: Array = weapons_dict[str(char_id)]
		var result: Array[StringName] = []
		for item in raw_arr:
			result.append(StringName(str(item)))
		if not result.is_empty():
			return result
	return WeaponCatalogScript.POOL_WEAPON_IDS.duplicate()


static func set_character_active_weapons(char_id: StringName, weapons: Array[StringName]) -> void:
	var prof: Dictionary = load_profile()
	var weapons_dict: Dictionary = prof.get("character_active_weapons", {}).duplicate()
	var str_arr: Array[String] = []
	for w: StringName in weapons:
		str_arr.append(str(w))
	weapons_dict[str(char_id)] = str_arr
	prof["character_active_weapons"] = weapons_dict

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(prof, "\t"))
		file.close()


static func get_character_loadout(char_id: StringName) -> Dictionary:
	var prof: Dictionary = load_profile()
	var loadouts: Dictionary = prof.get("character_loadouts", {})
	var cid_str := str(char_id)
	var loadout: Dictionary = {}
	var has_saved_loadout: bool = false
	if loadouts.has(cid_str) and loadouts[cid_str] is Dictionary:
		loadout = (loadouts[cid_str] as Dictionary).duplicate()
		has_saved_loadout = true

	var needs_save: bool = false
	if not loadout.has("selected_pet") or str(loadout["selected_pet"]).is_empty():
		loadout["selected_pet"] = &"mochi"
		needs_save = true
	if not loadout.has("selected_navigator") or str(loadout["selected_navigator"]).is_empty():
		loadout["selected_navigator"] = &"lyra"
		needs_save = true
	if not loadout.has("equipped_pet_skin"):
		loadout["equipped_pet_skin"] = ""
		needs_save = true
	if not loadout.has("equipped_navigator_skin"):
		loadout["equipped_navigator_skin"] = ""
		needs_save = true
	if not loadout.has("equipped_ship_skin") or str(loadout["equipped_ship_skin"]).is_empty():
		loadout["equipped_ship_skin"] = "base"
		needs_save = true
	if not loadout.has("equipped_weapon_skin") or str(loadout["equipped_weapon_skin"]).is_empty():
		loadout["equipped_weapon_skin"] = "base"
		needs_save = true
	if not loadout.has("equipped_pilot_skin") or str(loadout["equipped_pilot_skin"]).is_empty():
		loadout["equipped_pilot_skin"] = "base"
		needs_save = true

	if not has_saved_loadout or needs_save:
		set_character_loadout(char_id, loadout)

	return loadout


static func set_character_loadout(char_id: StringName, loadout: Dictionary) -> void:
	var prof: Dictionary = load_profile()
	var loadouts: Dictionary = prof.get("character_loadouts", {}).duplicate()
	loadouts[str(char_id)] = loadout.duplicate()
	prof["character_loadouts"] = loadouts

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(prof, "\t"))
		file.close()



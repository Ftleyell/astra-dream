extends Node

static var is_resuming_run: bool = false

const SAVE_PATH := "user://profile_data.json"
const SCHEMA_VERSION := 2

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
	p_career_stats: Variant = null
) -> Error:
	var existing_prof: Dictionary = {}
	if p_game_speed <= 0.0 or p_skills == null or p_selected_char == &"" or p_career_stats == null:
		existing_prof = load_profile()

	var current_speed: float = p_game_speed
	if current_speed <= 0.0:
		current_speed = float(existing_prof.get("game_speed", 1.0))
	if current_speed <= 0.0:
		current_speed = 1.0

	var current_biomass: int = p_biomass
	if current_biomass < 0:
		current_biomass = get_biomass()

	var current_antimatter: int = p_antimatter
	if current_antimatter < 0:
		current_antimatter = get_antimatter()

	var current_dark_matter: int = p_dark_matter
	if current_dark_matter < 0:
		current_dark_matter = get_dark_matter()

	var current_trophies: Dictionary
	if p_trophies == null:
		current_trophies = get_unlocked_trophies()
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
		current_career = existing_prof.get("career_stats", _get_default_career_stats())
	else:
		current_career = p_career_stats

	var payload := {
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
		"career_stats": current_career
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
		return _get_default_profile()

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return _get_default_profile()

	var json_str := file.get_as_text()
	file.close()

	if json_str.strip_edges().is_empty():
		return _get_default_profile()

	var parser := JSON.new()
	var err := parser.parse(json_str)
	if err != OK:
		push_error("Error parsing save file: %s" % parser.get_error_message())
		return _get_default_profile()

	var data: Dictionary = parser.data
	return _clean_and_validate_data(data)


static func _get_default_career_stats() -> Dictionary:
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
		"career_stats": _get_default_career_stats()
	}


static func _clean_and_validate_data(raw: Dictionary) -> Dictionary:
	var default_trophies := {
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

	var career_clean := _get_default_career_stats()
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

	var cleaned := {
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
		"career_stats": career_clean
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


# ==============================================================================
# ECONOMÍA: BIOMASA & ANTIMATERIA
# ==============================================================================

static func get_biomass() -> int:
	var profile := load_profile()
	return int(profile.get("biomass", 0))

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
	var dark_matter: int = int(profile.get("dark_matter", 0))
	var trophies: Dictionary = profile.get("trophies_unlocked", {})
	var sel_char: StringName = StringName(str(profile.get("selected_character", "nova")))
	save_profile(unlocked_items, bans, unlocked_chars, new_total, antimatter, skills, sel_char, dark_matter, trophies)
	return new_total

static func add_test_biomass(amount: int = 100) -> int:
	return add_biomass(amount)

static func get_antimatter() -> int:
	var profile := load_profile()
	return int(profile.get("antimatter", 0))

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
	var dark_matter: int = int(profile.get("dark_matter", 0))
	var trophies: Dictionary = profile.get("trophies_unlocked", {})
	var sel_char: StringName = StringName(str(profile.get("selected_character", "nova")))
	save_profile(unlocked_items, bans, unlocked_chars, biomass, new_total, skills, sel_char, dark_matter, trophies)
	return new_total


# ==============================================================================
# FASE 3: META-ECONOMÍA DE MATERIA OSCURA Y SALA DE TROFEOS
# ==============================================================================

static func get_dark_matter() -> int:
	var profile := load_profile()
	return int(profile.get("dark_matter", 0))

static func add_dark_matter(amount: int) -> int:
	if amount <= 0:
		return get_dark_matter()
	var profile := load_profile()
	var new_total: int = int(profile.get("dark_matter", 0)) + amount
	var unlocked_items: Array[StringName] = profile.get("unlocked_items", [])
	var unlocked_chars: Array[StringName] = profile.get("unlocked_characters", [])
	var bans: Dictionary = profile.get("character_banlists", {})
	var biomass: int = int(profile.get("biomass", 0))
	var antimatter: int = int(profile.get("antimatter", 0))
	var skills: Dictionary = profile.get("character_skills", {})
	var trophies: Dictionary = profile.get("trophies_unlocked", {})
	var sel_char: StringName = StringName(str(profile.get("selected_character", "nova")))
	save_profile(unlocked_items, bans, unlocked_chars, biomass, antimatter, skills, sel_char, new_total, trophies)
	return new_total

static func get_unlocked_trophies() -> Dictionary:
	var profile := load_profile()
	return profile.get("trophies_unlocked", {}).duplicate()

static func is_trophy_unlocked(trophy_id: StringName) -> bool:
	var trophies := get_unlocked_trophies()
	return int(trophies.get(str(trophy_id), 0)) > 0

static func get_trophy_mastery(trophy_id: StringName) -> int:
	var trophies := get_unlocked_trophies()
	return int(trophies.get(str(trophy_id), 0))

static func unlock_or_upgrade_trophy(trophy_id: StringName, mastery_level: int = 1) -> bool:
	var profile := load_profile()
	var trophies: Dictionary = profile.get("trophies_unlocked", {}).duplicate()
	var key := str(trophy_id)
	var current: int = int(trophies.get(key, 0))
	var new_level: int = maxi(current, mastery_level)
	trophies[key] = new_level

	var unlocked_items: Array[StringName] = profile.get("unlocked_items", [])
	var unlocked_chars: Array[StringName] = profile.get("unlocked_characters", [])
	var bans: Dictionary = profile.get("character_banlists", {})
	var biomass: int = int(profile.get("biomass", 0))
	var antimatter: int = int(profile.get("antimatter", 0))
	var skills: Dictionary = profile.get("character_skills", {})
	var dark_matter: int = int(profile.get("dark_matter", 0))
	var sel_char: StringName = StringName(str(profile.get("selected_character", "nova")))

	save_profile(unlocked_items, bans, unlocked_chars, biomass, antimatter, skills, sel_char, dark_matter, trophies)
	return true

static func upgrade_trophy_with_dark_matter(trophy_id: StringName, cost: int) -> bool:
	var current_dm := get_dark_matter()
	if current_dm < cost:
		return false
	var profile := load_profile()
	var trophies: Dictionary = profile.get("trophies_unlocked", {}).duplicate()
	var key := str(trophy_id)
	var current: int = int(trophies.get(key, 0))
	trophies[key] = current + 1

	var new_dm := current_dm - cost
	var unlocked_items: Array[StringName] = profile.get("unlocked_items", [])
	var unlocked_chars: Array[StringName] = profile.get("unlocked_characters", [])
	var bans: Dictionary = profile.get("character_banlists", {})
	var biomass: int = int(profile.get("biomass", 0))
	var antimatter: int = int(profile.get("antimatter", 0))
	var skills: Dictionary = profile.get("character_skills", {})
	var sel_char: StringName = StringName(str(profile.get("selected_character", "nova")))

	save_profile(unlocked_items, bans, unlocked_chars, biomass, antimatter, skills, sel_char, new_dm, trophies)
	return true

static func get_trophy_passive_bonuses() -> Dictionary:
	var trophies := get_unlocked_trophies()
	var bonuses := {
		"base_damage_pct": 0.0,
		"max_health": 0.0,
		"projectile_speed_pct": 0.0,
		"cooldown_reduction": 0.0,
		"crit_chance": 0.0,
		"crit_damage": 0.0,
		"pickup_radius_pct": 0.0
	}

	# 1. Nodriza Aegis: +10% Daño permanente (+5% por maestría)
	var aegis_lvl: int = int(trophies.get("trophy_boss_aegis", 0))
	if aegis_lvl > 0:
		bonuses["base_damage_pct"] += 0.10 + float(aegis_lvl - 1) * 0.05

	# 2. Núcleo Bioesfera: +15 HP Máximo permanente (+5 HP por maestría)
	var bio_lvl: int = int(trophies.get("trophy_biosphere_core", 0))
	if bio_lvl > 0:
		bonuses["max_health"] += 15.0 + float(bio_lvl - 1) * 5.0

	# 3. Núcleo Criogénico: +5% Vel. Proyectil y +5% Reducción enfriamiento (+2% por maestría)
	var cryo_lvl: int = int(trophies.get("trophy_cryo_core", 0))
	if cryo_lvl > 0:
		bonuses["projectile_speed_pct"] += 0.05 + float(cryo_lvl - 1) * 0.02
		bonuses["cooldown_reduction"] += 0.05 + float(cryo_lvl - 1) * 0.02

	# 4. Núcleo Volcánico: +5% Prob. Crítica y +0.20x Daño Crítico (+2% / +0.05x por maestría)
	var volc_lvl: int = int(trophies.get("trophy_volcanic_core", 0))
	if volc_lvl > 0:
		bonuses["crit_chance"] += 0.05 + float(volc_lvl - 1) * 0.02
		bonuses["crit_damage"] += 0.20 + float(volc_lvl - 1) * 0.05

	# 5. Reliquia del Monolito: +15% Rango de recogida / magnetismo (+5% por maestría)
	var mono_lvl: int = int(trophies.get("trophy_monolith_master", 0))
	if mono_lvl > 0:
		bonuses["pickup_radius_pct"] += 0.15 + float(mono_lvl - 1) * 0.05

	return bonuses


# ==============================================================================
# HABILIDADES Y PILOTOS
# ==============================================================================

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

static func is_character_node_unlocked(char_id: StringName, node_id: StringName) -> bool:
	var unlocked := get_character_unlocked_nodes(char_id)
	return unlocked.has(node_id)

static func get_character_unlocked_nodes_count(char_id: StringName) -> int:
	var nodes := get_character_unlocked_nodes(char_id)
	var count: int = 0
	for n in nodes:
		if n != &"core":
			count += 1
	return count

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

	if str_list.has(node_id):
		return false

	if req_node_id != &"" and not str_list.has(req_node_id):
		return false

	str_list.append(node_id)
	skills[char_id] = str_list

	var new_biomass := current_bio - cost
	var unlocked_items: Array[StringName] = profile.get("unlocked_items", [])
	var unlocked_chars: Array[StringName] = profile.get("unlocked_characters", [])
	var bans: Dictionary = profile.get("character_banlists", {})
	var antimatter: int = int(profile.get("antimatter", 0))
	var dark_matter: int = int(profile.get("dark_matter", 0))
	var trophies: Dictionary = profile.get("trophies_unlocked", {})
	var sel_char: StringName = StringName(str(profile.get("selected_character", "nova")))

	save_profile(unlocked_items, bans, unlocked_chars, new_biomass, antimatter, skills, sel_char, dark_matter, trophies)
	return true

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
	var dark_matter: int = int(profile.get("dark_matter", 0))
	var trophies: Dictionary = profile.get("trophies_unlocked", {})
	var sel_char: StringName = StringName(str(profile.get("selected_character", "nova")))

	save_profile(unlocked_items, bans, unlocked_chars, new_biomass, antimatter, skills, sel_char, dark_matter, trophies)
	return refund_biomass

static func get_selected_character() -> StringName:
	var profile := load_profile()
	return StringName(str(profile.get("selected_character", "nova")))

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
	var dark_matter: int = int(profile.get("dark_matter", 0))
	var trophies: Dictionary = profile.get("trophies_unlocked", {})
	save_profile(unlocked_items, bans, unlocked_chars, biomass, antimatter, skills, char_id, dark_matter, trophies)


static func get_game_speed() -> float:
	var profile := load_profile()
	var spd: float = float(profile.get("game_speed", 1.0))
	return spd if spd > 0.0 else 1.0

static func set_game_speed(speed: float) -> void:
	if speed <= 0.0:
		speed = 1.0
	Engine.time_scale = speed
	var profile := load_profile()
	var unlocked_items: Array[StringName] = profile.get("unlocked_items", [])
	var unlocked_chars: Array[StringName] = profile.get("unlocked_characters", [])
	var bans: Dictionary = profile.get("character_banlists", {})
	var biomass: int = int(profile.get("biomass", 0))
	var antimatter: int = int(profile.get("antimatter", 0))
	var skills: Dictionary = profile.get("character_skills", {})
	var sel_char: StringName = StringName(str(profile.get("selected_character", "nova")))
	var dark_matter: int = int(profile.get("dark_matter", 0))
	var trophies: Dictionary = profile.get("trophies_unlocked", {})
	save_profile(unlocked_items, bans, unlocked_chars, biomass, antimatter, skills, sel_char, dark_matter, trophies, speed)


# ==============================================================================
# ESTADÍSTICAS DE CARRERA Y DESBLOQUEO DE PERSONAJES
# ==============================================================================

static func get_career_stats() -> Dictionary:
	var prof := load_profile()
	var def := _get_default_career_stats()
	var current: Dictionary = prof.get("career_stats", {})
	for k in def.keys():
		if not current.has(k):
			current[k] = def[k]
	return current

static func is_character_unlocked(char_id: StringName) -> bool:
	var prof := load_profile()
	var chars: Array = prof.get("unlocked_characters", [])
	return chars.has(char_id) or chars.has(String(char_id))

static func unlock_character(char_id: StringName) -> bool:
	var prof := load_profile()
	var chars: Array[StringName] = []
	for c in prof.get("unlocked_characters", []):
		chars.append(StringName(str(c)))
	if not chars.has(char_id):
		chars.append(char_id)
		var unlocked_items: Array[StringName] = prof.get("unlocked_items", [])
		var bans: Dictionary = prof.get("character_banlists", {})
		var bio: int = int(prof.get("biomass", 0))
		var anti: int = int(prof.get("antimatter", 0))
		var skills: Dictionary = prof.get("character_skills", {})
		var sel_char: StringName = StringName(str(prof.get("selected_character", "nova")))
		var dm: int = int(prof.get("dark_matter", 0))
		var trophies: Dictionary = prof.get("trophies_unlocked", {})
		var spd: float = float(prof.get("game_speed", 1.0))
		var career: Dictionary = prof.get("career_stats", _get_default_career_stats())
		save_profile(unlocked_items, bans, chars, bio, anti, skills, sel_char, dm, trophies, spd, career)
		return true
	return false

static func record_boss_kill() -> bool:
	var prof := load_profile()
	var career: Dictionary = get_career_stats()
	career["total_bosses_killed"] = int(career.get("total_bosses_killed", 0)) + 1

	var unlocked_items: Array[StringName] = prof.get("unlocked_items", [])
	var chars: Array[StringName] = []
	for c in prof.get("unlocked_characters", []):
		chars.append(StringName(str(c)))
	var bans: Dictionary = prof.get("character_banlists", {})
	var bio: int = int(prof.get("biomass", 0))
	var anti: int = int(prof.get("antimatter", 0))
	var skills: Dictionary = prof.get("character_skills", {})
	var sel_char: StringName = StringName(str(prof.get("selected_character", "nova")))
	var dm: int = int(prof.get("dark_matter", 0))
	var trophies: Dictionary = prof.get("trophies_unlocked", {})
	var spd: float = float(prof.get("game_speed", 1.0))

	var newly_unlocked_nyx: bool = false
	if int(career["total_bosses_killed"]) >= 10:
		if not chars.has(&"nyx"):
			chars.append(&"nyx")
			newly_unlocked_nyx = true

	save_profile(unlocked_items, bans, chars, bio, anti, skills, sel_char, dm, trophies, spd, career)
	return newly_unlocked_nyx

static func record_career_run_end(stats_data: Dictionary) -> void:
	var prof := load_profile()
	var career: Dictionary = get_career_stats()
	career["total_time_survived"] = float(career.get("total_time_survived", 0.0)) + float(stats_data.get("time_survived", 0.0))
	career["total_credits_collected"] = int(career.get("total_credits_collected", 0)) + int(stats_data.get("credits_earned", 0))
	career["total_biomass_collected"] = int(career.get("total_biomass_collected", 0)) + int(stats_data.get("biomass_earned", 0))
	career["total_enemies_killed"] = int(career.get("total_enemies_killed", 0)) + int(stats_data.get("enemies_killed", 0))
	career["total_satellites_activated"] = int(career.get("total_satellites_activated", 0)) + int(stats_data.get("satellites_collected", 0))
	career["total_runs_played"] = int(career.get("total_runs_played", 0)) + 1
	if bool(stats_data.get("victory", false)):
		career["total_runs_cleared"] = int(career.get("total_runs_cleared", 0)) + 1

	var unlocked_items: Array[StringName] = prof.get("unlocked_items", [])
	var chars: Array[StringName] = []
	for c in prof.get("unlocked_characters", []):
		chars.append(StringName(str(c)))
	var bans: Dictionary = prof.get("character_banlists", {})
	var bio: int = int(prof.get("biomass", 0))
	var anti: int = int(prof.get("antimatter", 0))
	var skills: Dictionary = prof.get("character_skills", {})
	var sel_char: StringName = StringName(str(prof.get("selected_character", "nova")))
	var dm: int = int(prof.get("dark_matter", 0))
	var trophies: Dictionary = prof.get("trophies_unlocked", {})
	var spd: float = float(prof.get("game_speed", 1.0))

	if int(career.get("total_bosses_killed", 0)) >= 10 and not chars.has(&"nyx"):
		chars.append(&"nyx")

	save_profile(unlocked_items, bans, chars, bio, anti, skills, sel_char, dm, trophies, spd, career)


static func reset_career_stats() -> void:
	var prof := load_profile()
	var career := _get_default_career_stats()

	var unlocked_items: Array[StringName] = prof.get("unlocked_items", [])
	var chars: Array[StringName] = []
	for c in prof.get("unlocked_characters", []):
		var s := StringName(str(c))
		if s != &"nyx":
			chars.append(s)
	var bans: Dictionary = prof.get("character_banlists", {})
	var bio: int = int(prof.get("biomass", 0))
	var anti: int = int(prof.get("antimatter", 0))
	var skills: Dictionary = prof.get("character_skills", {})
	var sel_char: StringName = StringName(str(prof.get("selected_character", "nova")))
	if sel_char == &"nyx":
		sel_char = &"nova"
	var dm: int = int(prof.get("dark_matter", 0))
	var trophies: Dictionary = prof.get("trophies_unlocked", {})
	var spd: float = float(prof.get("game_speed", 1.0))

	save_profile(unlocked_items, bans, chars, bio, anti, skills, sel_char, dm, trophies, spd, career)


static func set_career_bosses_killed(count: int) -> void:
	var prof := load_profile()
	var career: Dictionary = get_career_stats()
	career["total_bosses_killed"] = count

	var unlocked_items: Array[StringName] = prof.get("unlocked_items", [])
	var chars: Array[StringName] = []
	for c in prof.get("unlocked_characters", []):
		var s := StringName(str(c))
		if count < 10 and s == &"nyx":
			continue
		chars.append(s)

	if count >= 10 and not chars.has(&"nyx"):
		chars.append(&"nyx")

	var bans: Dictionary = prof.get("character_banlists", {})
	var bio: int = int(prof.get("biomass", 0))
	var anti: int = int(prof.get("antimatter", 0))
	var skills: Dictionary = prof.get("character_skills", {})
	var sel_char: StringName = StringName(str(prof.get("selected_character", "nova")))
	if count < 10 and sel_char == &"nyx":
		sel_char = &"nova"
	var dm: int = int(prof.get("dark_matter", 0))
	var trophies: Dictionary = prof.get("trophies_unlocked", {})
	var spd: float = float(prof.get("game_speed", 1.0))

	save_profile(unlocked_items, bans, chars, bio, anti, skills, sel_char, dm, trophies, spd, career)



# ==============================================================================
# MID-RUN SAVE & RESUME
# ==============================================================================

const ACTIVE_RUN_PATH := "user://active_run.json"

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


# ==============================================================================
# HIGHSCORES & RUN HISTORY
# ==============================================================================

const HIGHSCORES_PATH := "user://highscores.json"
const MAX_HIGHSCORES := 10

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

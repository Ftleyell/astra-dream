class_name MetaProgressionState
extends RefCounted

## Gestor de estado de meta-progresión:
## Economía persistente (Biomasa, Antimateria, Materia Oscura), Trofeos de colosos,
## Árboles de talentos de heroínas, estadísticas de carrera y desbloqueo de personajes.

const ProfileStorageScript = preload("res://core/systems/persistence/profile_storage.gd")

# ==============================================================================
# ECONOMÍA: BIOMASA & ANTIMATERIA
# ==============================================================================

static func get_biomass() -> int:
	var profile: Dictionary = ProfileStorageScript.load_profile()
	return int(profile.get("biomass", 0))

static func add_biomass(amount: int, save_facade: Object) -> int:
	if amount <= 0:
		return get_biomass()
	var profile: Dictionary = ProfileStorageScript.load_profile()
	var new_total: int = int(profile.get("biomass", 0)) + amount
	var unlocked_items: Array[StringName] = profile.get("unlocked_items", [])
	var unlocked_chars: Array[StringName] = profile.get("unlocked_characters", [])
	var bans: Dictionary = profile.get("character_banlists", {})
	var antimatter: int = int(profile.get("antimatter", 0))
	var skills: Dictionary = profile.get("character_skills", {})
	var dark_matter: int = int(profile.get("dark_matter", 0))
	var trophies: Dictionary = profile.get("trophies_unlocked", {})
	var sel_char: StringName = StringName(str(profile.get("selected_character", "nova")))
	save_facade.save_profile(unlocked_items, bans, unlocked_chars, new_total, antimatter, skills, sel_char, dark_matter, trophies)
	return new_total

static func set_biomass(amount: int, save_facade: Object) -> void:
	var profile: Dictionary = ProfileStorageScript.load_profile()
	var unlocked_items: Array[StringName] = profile.get("unlocked_items", [])
	var bans: Dictionary = profile.get("character_banlists", {})
	var unlocked_chars: Array[StringName] = profile.get("unlocked_characters", [])
	var antimatter: int = int(profile.get("antimatter", 0))
	var skills: Dictionary = profile.get("character_skills", {})
	var sel_char: StringName = StringName(str(profile.get("selected_character", "nova")))
	var dark_matter: int = int(profile.get("dark_matter", 0))
	var trophies: Dictionary = profile.get("trophies_unlocked", {})
	save_facade.save_profile(unlocked_items, bans, unlocked_chars, maxi(0, amount), antimatter, skills, sel_char, dark_matter, trophies)

static func get_antimatter() -> int:
	var profile: Dictionary = ProfileStorageScript.load_profile()
	return int(profile.get("antimatter", 0))

static func add_antimatter(amount: int, save_facade: Object) -> int:
	if amount <= 0:
		return get_antimatter()
	var profile: Dictionary = ProfileStorageScript.load_profile()
	var new_total: int = int(profile.get("antimatter", 0)) + amount
	var unlocked_items: Array[StringName] = profile.get("unlocked_items", [])
	var unlocked_chars: Array[StringName] = profile.get("unlocked_characters", [])
	var bans: Dictionary = profile.get("character_banlists", {})
	var biomass: int = int(profile.get("biomass", 0))
	var skills: Dictionary = profile.get("character_skills", {})
	var dark_matter: int = int(profile.get("dark_matter", 0))
	var trophies: Dictionary = profile.get("trophies_unlocked", {})
	var sel_char: StringName = StringName(str(profile.get("selected_character", "nova")))
	save_facade.save_profile(unlocked_items, bans, unlocked_chars, biomass, new_total, skills, sel_char, dark_matter, trophies)
	return new_total

# ==============================================================================
# META-ECONOMÍA DE MATERIA OSCURA Y SALA DE TROFEOS
# ==============================================================================

static func get_dark_matter() -> int:
	var profile: Dictionary = ProfileStorageScript.load_profile()
	return int(profile.get("dark_matter", 0))

static func add_dark_matter(amount: int, save_facade: Object) -> int:
	if amount <= 0:
		return get_dark_matter()
	var profile: Dictionary = ProfileStorageScript.load_profile()
	var new_total: int = int(profile.get("dark_matter", 0)) + amount
	var unlocked_items: Array[StringName] = profile.get("unlocked_items", [])
	var unlocked_chars: Array[StringName] = profile.get("unlocked_characters", [])
	var bans: Dictionary = profile.get("character_banlists", {})
	var biomass: int = int(profile.get("biomass", 0))
	var antimatter: int = int(profile.get("antimatter", 0))
	var skills: Dictionary = profile.get("character_skills", {})
	var trophies: Dictionary = profile.get("trophies_unlocked", {})
	var sel_char: StringName = StringName(str(profile.get("selected_character", "nova")))
	save_facade.save_profile(unlocked_items, bans, unlocked_chars, biomass, antimatter, skills, sel_char, new_total, trophies)
	return new_total

static func get_unlocked_trophies() -> Dictionary:
	var profile: Dictionary = ProfileStorageScript.load_profile()
	return profile.get("trophies_unlocked", {}).duplicate()

static func is_trophy_unlocked(trophy_id: StringName) -> bool:
	var trophies: Dictionary = get_unlocked_trophies()
	return int(trophies.get(str(trophy_id), 0)) > 0

static func get_trophy_mastery(trophy_id: StringName) -> int:
	var trophies: Dictionary = get_unlocked_trophies()
	return int(trophies.get(str(trophy_id), 0))

static func unlock_or_upgrade_trophy(trophy_id: StringName, mastery_level: int, save_facade: Object) -> bool:
	var profile: Dictionary = ProfileStorageScript.load_profile()
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

	save_facade.save_profile(unlocked_items, bans, unlocked_chars, biomass, antimatter, skills, sel_char, dark_matter, trophies)
	return true

static func upgrade_trophy_with_dark_matter(trophy_id: StringName, cost: int, save_facade: Object) -> bool:
	var current_dm: int = get_dark_matter()
	if current_dm < cost:
		return false
	var profile: Dictionary = ProfileStorageScript.load_profile()
	var trophies: Dictionary = profile.get("trophies_unlocked", {}).duplicate()
	var key := str(trophy_id)
	var current: int = int(trophies.get(key, 0))
	trophies[key] = current + 1

	var new_dm: int = current_dm - cost
	var unlocked_items: Array[StringName] = profile.get("unlocked_items", [])
	var unlocked_chars: Array[StringName] = profile.get("unlocked_characters", [])
	var bans: Dictionary = profile.get("character_banlists", {})
	var biomass: int = int(profile.get("biomass", 0))
	var antimatter: int = int(profile.get("antimatter", 0))
	var skills: Dictionary = profile.get("character_skills", {})
	var sel_char: StringName = StringName(str(profile.get("selected_character", "nova")))

	save_facade.save_profile(unlocked_items, bans, unlocked_chars, biomass, antimatter, skills, sel_char, new_dm, trophies)
	return true

static func get_trophy_passive_bonuses() -> Dictionary:
	var trophies: Dictionary = get_unlocked_trophies()
	var bonuses: Dictionary = {
		"base_damage_pct": 0.0,
		"max_health": 0.0,
		"projectile_speed_pct": 0.0,
		"cooldown_reduction": 0.0,
		"crit_chance": 0.0,
		"crit_damage": 0.0,
		"pickup_radius_pct": 0.0
	}

	var aegis_lvl: int = int(trophies.get("trophy_boss_aegis", 0))
	if aegis_lvl > 0:
		bonuses["base_damage_pct"] += 0.10 + float(aegis_lvl - 1) * 0.05

	var bio_lvl: int = int(trophies.get("trophy_biosphere_core", 0))
	if bio_lvl > 0:
		bonuses["max_health"] += 15.0 + float(bio_lvl - 1) * 5.0

	var cryo_lvl: int = int(trophies.get("trophy_cryo_core", 0))
	if cryo_lvl > 0:
		bonuses["projectile_speed_pct"] += 0.05 + float(cryo_lvl - 1) * 0.02
		bonuses["cooldown_reduction"] += 0.05 + float(cryo_lvl - 1) * 0.02

	var volc_lvl: int = int(trophies.get("trophy_volcanic_core", 0))
	if volc_lvl > 0:
		bonuses["crit_chance"] += 0.05 + float(volc_lvl - 1) * 0.02
		bonuses["crit_damage"] += 0.20 + float(volc_lvl - 1) * 0.05

	var mono_lvl: int = int(trophies.get("trophy_monolith_master", 0))
	if mono_lvl > 0:
		bonuses["pickup_radius_pct"] += 0.15 + float(mono_lvl - 1) * 0.05

	return bonuses

# ==============================================================================
# HABILIDADES Y PILOTOS
# ==============================================================================

static func get_character_unlocked_nodes(char_id: StringName) -> Array[StringName]:
	var profile: Dictionary = ProfileStorageScript.load_profile()
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
	var unlocked: Array[StringName] = get_character_unlocked_nodes(char_id)
	return unlocked.has(node_id)

static func get_character_unlocked_nodes_count(char_id: StringName) -> int:
	var nodes: Array[StringName] = get_character_unlocked_nodes(char_id)
	var count: int = 0
	for n in nodes:
		if n != &"core":
			count += 1
	return count

static func unlock_character_skill_node(char_id: StringName, node_id: StringName, cost: int, req_node_id: StringName, save_facade: Object) -> bool:
	var current_bio: int = get_biomass()
	if current_bio < cost:
		return false

	var profile: Dictionary = ProfileStorageScript.load_profile()
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

	var new_biomass: int = current_bio - cost
	var unlocked_items: Array[StringName] = profile.get("unlocked_items", [])
	var unlocked_chars: Array[StringName] = profile.get("unlocked_characters", [])
	var bans: Dictionary = profile.get("character_banlists", {})
	var antimatter: int = int(profile.get("antimatter", 0))
	var dark_matter: int = int(profile.get("dark_matter", 0))
	var trophies: Dictionary = profile.get("trophies_unlocked", {})
	var sel_char: StringName = StringName(str(profile.get("selected_character", "nova")))

	save_facade.save_profile(unlocked_items, bans, unlocked_chars, new_biomass, antimatter, skills, sel_char, dark_matter, trophies)
	return true

static func refund_character_skills(char_id: StringName, node_cost: int, save_facade: Object) -> int:
	var profile: Dictionary = ProfileStorageScript.load_profile()
	var skills: Dictionary = profile.get("character_skills", {})
	var list: Array = skills.get(char_id, skills.get(String(char_id), []))

	var paid_nodes: int = 0
	for n in list:
		var s := StringName(str(n))
		if s != &"core":
			paid_nodes += 1

	var refund_biomass: int = paid_nodes * node_cost
	skills[char_id] = [&"core"] as Array[StringName]

	var current_bio: int = int(profile.get("biomass", 0))
	var new_biomass: int = current_bio + refund_biomass
	var unlocked_items: Array[StringName] = profile.get("unlocked_items", [])
	var unlocked_chars: Array[StringName] = profile.get("unlocked_characters", [])
	var bans: Dictionary = profile.get("character_banlists", {})
	var antimatter: int = int(profile.get("antimatter", 0))
	var dark_matter: int = int(profile.get("dark_matter", 0))
	var trophies: Dictionary = profile.get("trophies_unlocked", {})
	var sel_char: StringName = StringName(str(profile.get("selected_character", "nova")))

	save_facade.save_profile(unlocked_items, bans, unlocked_chars, new_biomass, antimatter, skills, sel_char, dark_matter, trophies)
	return refund_biomass

# ==============================================================================
# CONFIGURACIÓN Y ESTADÍSTICAS DE CARRERA
# ==============================================================================

static func get_selected_character() -> StringName:
	var profile: Dictionary = ProfileStorageScript.load_profile()
	return StringName(str(profile.get("selected_character", "nova")))

static func set_selected_character(char_id: StringName, save_facade: Object) -> void:
	if char_id == &"":
		return
	var profile: Dictionary = ProfileStorageScript.load_profile()
	var unlocked_items: Array[StringName] = profile.get("unlocked_items", [])
	var unlocked_chars: Array[StringName] = profile.get("unlocked_characters", [])
	var bans: Dictionary = profile.get("character_banlists", {})
	var biomass: int = int(profile.get("biomass", 0))
	var antimatter: int = int(profile.get("antimatter", 0))
	var skills: Dictionary = profile.get("character_skills", {})
	var dark_matter: int = int(profile.get("dark_matter", 0))
	var trophies: Dictionary = profile.get("trophies_unlocked", {})
	save_facade.save_profile(unlocked_items, bans, unlocked_chars, biomass, antimatter, skills, char_id, dark_matter, trophies)

static func get_game_speed() -> float:
	var profile: Dictionary = ProfileStorageScript.load_profile()
	var spd: float = float(profile.get("game_speed", 1.0))
	return spd if spd > 0.0 else 1.0

static func set_game_speed(speed: float, save_facade: Object) -> void:
	if speed <= 0.0:
		speed = 1.0
	Engine.time_scale = speed
	var profile: Dictionary = ProfileStorageScript.load_profile()
	var unlocked_items: Array[StringName] = profile.get("unlocked_items", [])
	var unlocked_chars: Array[StringName] = profile.get("unlocked_characters", [])
	var bans: Dictionary = profile.get("character_banlists", {})
	var biomass: int = int(profile.get("biomass", 0))
	var antimatter: int = int(profile.get("antimatter", 0))
	var skills: Dictionary = profile.get("character_skills", {})
	var sel_char: StringName = StringName(str(profile.get("selected_character", "nova")))
	var dark_matter: int = int(profile.get("dark_matter", 0))
	var trophies: Dictionary = profile.get("trophies_unlocked", {})
	save_facade.save_profile(unlocked_items, bans, unlocked_chars, biomass, antimatter, skills, sel_char, dark_matter, trophies, speed)

static func get_career_stats() -> Dictionary:
	var prof: Dictionary = ProfileStorageScript.load_profile()
	var def: Dictionary = ProfileStorageScript.get_default_career_stats()
	var current: Dictionary = prof.get("career_stats", {})
	for k in def.keys():
		if not current.has(k):
			current[k] = def[k]
	return current

static func is_character_unlocked(char_id: StringName) -> bool:
	var prof: Dictionary = ProfileStorageScript.load_profile()
	var chars: Array = prof.get("unlocked_characters", [])
	return chars.has(char_id) or chars.has(String(char_id))

static func unlock_character(char_id: StringName, save_facade: Object) -> bool:
	var prof: Dictionary = ProfileStorageScript.load_profile()
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
		var career: Dictionary = prof.get("career_stats", ProfileStorageScript.get_default_career_stats())
		save_facade.save_profile(unlocked_items, bans, chars, bio, anti, skills, sel_char, dm, trophies, spd, career)
		return true
	return false

static func lock_character(char_id: StringName, save_facade: Object) -> bool:
	var prof: Dictionary = ProfileStorageScript.load_profile()
	var chars: Array[StringName] = []
	var found: bool = false
	for c in prof.get("unlocked_characters", []):
		if StringName(str(c)) == char_id:
			found = true
		else:
			chars.append(StringName(str(c)))
	if found:
		var unlocked_items: Array[StringName] = prof.get("unlocked_items", [])
		var bans: Dictionary = prof.get("character_banlists", {})
		var bio: int = int(prof.get("biomass", 0))
		var anti: int = int(prof.get("antimatter", 0))
		var skills: Dictionary = prof.get("character_skills", {})
		var sel_char: StringName = StringName(str(prof.get("selected_character", "nova")))
		var dm: int = int(prof.get("dark_matter", 0))
		var trophies: Dictionary = prof.get("trophies_unlocked", {})
		var spd: float = float(prof.get("game_speed", 1.0))
		var career: Dictionary = prof.get("career_stats", ProfileStorageScript.get_default_career_stats())
		save_facade.save_profile(unlocked_items, bans, chars, bio, anti, skills, sel_char, dm, trophies, spd, career)
		return true
	return false

static func record_boss_kill(save_facade: Object) -> bool:
	var prof: Dictionary = ProfileStorageScript.load_profile()
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

	save_facade.save_profile(unlocked_items, bans, chars, bio, anti, skills, sel_char, dm, trophies, spd, career)
	return newly_unlocked_nyx

static func record_career_run_end(stats_data: Dictionary, save_facade: Object) -> void:
	var prof: Dictionary = ProfileStorageScript.load_profile()
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

	save_facade.save_profile(unlocked_items, bans, chars, bio, anti, skills, sel_char, dm, trophies, spd, career)

static func reset_career_stats(save_facade: Object) -> void:
	var prof: Dictionary = ProfileStorageScript.load_profile()
	var career: Dictionary = ProfileStorageScript.get_default_career_stats()

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

	save_facade.save_profile(unlocked_items, bans, chars, bio, anti, skills, sel_char, dm, trophies, spd, career)

static func set_career_bosses_killed(count: int, save_facade: Object) -> void:
	var prof: Dictionary = ProfileStorageScript.load_profile()
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

	save_facade.save_profile(unlocked_items, bans, chars, bio, anti, skills, sel_char, dm, trophies, spd, career)

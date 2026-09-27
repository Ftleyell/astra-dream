class_name SaveRosterModule
extends RefCounted

## SaveRosterModule.gd
## Manejo especializado de Mascotas (Pets), Navegadoras (Navigators) y Finales (Endings).

static func get_selected_pet(profile: Dictionary, is_unlocked_func: Callable) -> StringName:
	var pet := StringName(str(profile.get("selected_pet", "mochi")))
	if not is_unlocked_func.call(pet):
		return &"mochi"
	return pet

static func set_selected_pet(pet_id: StringName, save_manager_ref: Object) -> void:
	if pet_id == &"":
		return
	var prof: Dictionary = save_manager_ref.load_profile()
	var unlocked_items: Array[StringName] = prof.get("unlocked_items", [])
	var chars: Array[StringName] = prof.get("unlocked_characters", [])
	var bans: Dictionary = prof.get("character_banlists", {})
	var bio: int = int(prof.get("biomass", 0))
	var anti: int = int(prof.get("antimatter", 0))
	var skills: Dictionary = prof.get("character_skills", {})
	var sel_char: StringName = StringName(str(prof.get("selected_character", "nova")))
	var dm: int = int(prof.get("dark_matter", 0))
	var trophies: Dictionary = prof.get("trophies_unlocked", {})
	var spd: float = float(prof.get("game_speed", 1.0))
	var career: Dictionary = prof.get("career_stats", save_manager_ref._get_default_career_stats())
	var unlocked_pets = prof.get("unlocked_pets", ["mochi", "kuro", "luna", "pip"])

	save_manager_ref.save_profile(unlocked_items, bans, chars, bio, anti, skills, sel_char, dm, trophies, spd, career, pet_id, unlocked_pets)

static func get_unlocked_pets(profile: Dictionary) -> Array[StringName]:
	var raw_pets: Array = profile.get("unlocked_pets", [&"mochi", &"kuro", &"luna", &"pip"])
	var res: Array[StringName] = []
	for p in raw_pets:
		res.append(StringName(str(p)))
	return res

static func is_pet_unlocked(pet_id: StringName, profile: Dictionary) -> bool:
	var unlocked := get_unlocked_pets(profile)
	return unlocked.has(pet_id) or unlocked.has(String(pet_id))

static func unlock_pet(pet_id: StringName, save_manager_ref: Object) -> bool:
	var prof: Dictionary = save_manager_ref.load_profile()
	var unlocked := get_unlocked_pets(prof)
	if not unlocked.has(pet_id):
		unlocked.append(pet_id)
		var unlocked_items: Array[StringName] = prof.get("unlocked_items", [])
		var chars: Array[StringName] = prof.get("unlocked_characters", [])
		var bans: Dictionary = prof.get("character_banlists", {})
		var bio: int = int(prof.get("biomass", 0))
		var anti: int = int(prof.get("antimatter", 0))
		var skills: Dictionary = prof.get("character_skills", {})
		var sel_char: StringName = StringName(str(prof.get("selected_character", "nova")))
		var dm: int = int(prof.get("dark_matter", 0))
		var trophies: Dictionary = prof.get("trophies_unlocked", {})
		var spd: float = float(prof.get("game_speed", 1.0))
		var career: Dictionary = prof.get("career_stats", save_manager_ref._get_default_career_stats())
		var sel_pet: StringName = StringName(str(prof.get("selected_pet", "mochi")))

		save_manager_ref.save_profile(unlocked_items, bans, chars, bio, anti, skills, sel_char, dm, trophies, spd, career, sel_pet, unlocked)
		return true
	return false

static func lock_pet(pet_id: StringName, save_manager_ref: Object) -> void:
	var prof: Dictionary = save_manager_ref.load_profile()
	var unlocked := get_unlocked_pets(prof)
	unlocked.erase(pet_id)
	unlocked.erase(String(pet_id))

	var unlocked_items: Array[StringName] = prof.get("unlocked_items", [])
	var chars: Array[StringName] = prof.get("unlocked_characters", [])
	var bans: Dictionary = prof.get("character_banlists", {})
	var bio: int = int(prof.get("biomass", 0))
	var anti: int = int(prof.get("antimatter", 0))
	var skills: Dictionary = prof.get("character_skills", {})
	var sel_char: StringName = StringName(str(prof.get("selected_character", "nova")))
	var dm: int = int(prof.get("dark_matter", 0))
	var trophies: Dictionary = prof.get("trophies_unlocked", {})
	var spd: float = float(prof.get("game_speed", 1.0))
	var career: Dictionary = prof.get("career_stats", save_manager_ref._get_default_career_stats())
	var sel_pet: StringName = StringName(str(prof.get("selected_pet", "mochi")))
	if sel_pet == pet_id:
		sel_pet = &"mochi"

	save_manager_ref.save_profile(unlocked_items, bans, chars, bio, anti, skills, sel_char, dm, trophies, spd, career, sel_pet, unlocked)

static func get_unlocked_endings(profile: Dictionary) -> Array[String]:
	var raw = profile.get("unlocked_endings", [])
	var list: Array[String] = []
	if raw is Array:
		for e in raw:
			list.append(str(e))
	return list

static func has_unlocked_ending(ending_id: String, profile: Dictionary) -> bool:
	return get_unlocked_endings(profile).has(ending_id)

static func record_ending(ending_id: String, save_manager_ref: Object) -> bool:
	var prof: Dictionary = save_manager_ref.load_profile()
	var current := get_unlocked_endings(prof)
	var is_new: bool = false
	if not current.has(ending_id):
		current.append(ending_id)
		is_new = true
	var unlocked_items: Array[StringName] = prof.get("unlocked_items", [])
	var chars: Array[StringName] = prof.get("unlocked_characters", [])
	var bans: Dictionary = prof.get("character_banlists", {})
	var bio: int = int(prof.get("biomass", 0))
	var anti: int = int(prof.get("antimatter", 0))
	var skills: Dictionary = prof.get("character_skills", {})
	var sel_char: StringName = StringName(str(prof.get("selected_character", "nova")))
	var dm: int = int(prof.get("dark_matter", 0))
	var trophies: Dictionary = prof.get("trophies_unlocked", {})
	var spd: float = float(prof.get("game_speed", 1.0))
	var career: Dictionary = prof.get("career_stats", save_manager_ref._get_default_career_stats())
	var sel_pet: StringName = StringName(str(prof.get("selected_pet", "mochi")))
	var unlocked_pets = prof.get("unlocked_pets", ["mochi", "kuro", "luna", "pip"])
	var unlocked_navs = prof.get("unlocked_navigators", ["lyra", "vespera", "caelia", "zephyr"])
	var sel_nav: StringName = StringName(str(prof.get("selected_navigator", "lyra")))
	
	# Desbloquear a Iris al completar cualquier final
	var nav_arr: Array = []
	for n in unlocked_navs:
		nav_arr.append(StringName(str(n)))
	if not nav_arr.has(&"iris"):
		nav_arr.append(&"iris")

	save_manager_ref.save_profile(unlocked_items, bans, chars, bio, anti, skills, sel_char, dm, trophies, spd, career, sel_pet, unlocked_pets, current, sel_nav, nav_arr)
	return is_new

static func get_selected_navigator(profile: Dictionary, is_unlocked_func: Callable) -> StringName:
	var nav := StringName(str(profile.get("selected_navigator", "lyra")))
	if not is_unlocked_func.call(nav):
		return &"lyra"
	return nav

static func set_selected_navigator(nav_id: StringName, save_manager_ref: Object) -> void:
	if nav_id == &"":
		return
	var prof: Dictionary = save_manager_ref.load_profile()
	var unlocked_items: Array[StringName] = prof.get("unlocked_items", [])
	var chars: Array[StringName] = prof.get("unlocked_characters", [])
	var bans: Dictionary = prof.get("character_banlists", {})
	var bio: int = int(prof.get("biomass", 0))
	var anti: int = int(prof.get("antimatter", 0))
	var skills: Dictionary = prof.get("character_skills", {})
	var sel_char: StringName = StringName(str(prof.get("selected_character", "nova")))
	var dm: int = int(prof.get("dark_matter", 0))
	var trophies: Dictionary = prof.get("trophies_unlocked", {})
	var spd: float = float(prof.get("game_speed", 1.0))
	var career: Dictionary = prof.get("career_stats", save_manager_ref._get_default_career_stats())
	var sel_pet: StringName = StringName(str(prof.get("selected_pet", "mochi")))
	var unlocked_pets = prof.get("unlocked_pets", ["mochi", "kuro", "luna", "pip"])
	var unlocked_endings = prof.get("unlocked_endings", [])
	var unlocked_navs = prof.get("unlocked_navigators", ["lyra", "vespera", "caelia", "zephyr"])

	save_manager_ref.save_profile(unlocked_items, bans, chars, bio, anti, skills, sel_char, dm, trophies, spd, career, sel_pet, unlocked_pets, unlocked_endings, nav_id, unlocked_navs)

static func get_unlocked_navigators(profile: Dictionary) -> Array[StringName]:
	var raw_navs: Array = profile.get("unlocked_navigators", [&"lyra", &"vespera", &"caelia", &"zephyr"])
	var res: Array[StringName] = []
	var base_navs: Array[StringName] = [&"lyra", &"vespera", &"caelia", &"zephyr"]
	for b in base_navs:
		res.append(b)
	for n in raw_navs:
		var sn := StringName(str(n))
		if not res.has(sn) and sn != &"pip" and sn != &"mochi" and sn != &"kuro" and sn != &"luna":
			res.append(sn)
	return res

static func is_navigator_unlocked(nav_id: StringName, profile: Dictionary) -> bool:
	var unlocked := get_unlocked_navigators(profile)
	return unlocked.has(nav_id) or unlocked.has(String(nav_id))

static func unlock_navigator(nav_id: StringName, save_manager_ref: Object) -> bool:
	var prof: Dictionary = save_manager_ref.load_profile()
	var unlocked := get_unlocked_navigators(prof)
	if not unlocked.has(nav_id):
		unlocked.append(nav_id)
		var unlocked_items: Array[StringName] = prof.get("unlocked_items", [])
		var chars: Array[StringName] = prof.get("unlocked_characters", [])
		var bans: Dictionary = prof.get("character_banlists", {})
		var bio: int = int(prof.get("biomass", 0))
		var anti: int = int(prof.get("antimatter", 0))
		var skills: Dictionary = prof.get("character_skills", {})
		var sel_char: StringName = StringName(str(prof.get("selected_character", "nova")))
		var dm: int = int(prof.get("dark_matter", 0))
		var trophies: Dictionary = prof.get("trophies_unlocked", {})
		var spd: float = float(prof.get("game_speed", 1.0))
		var career: Dictionary = prof.get("career_stats", save_manager_ref._get_default_career_stats())
		var sel_pet: StringName = StringName(str(prof.get("selected_pet", "mochi")))
		var unlocked_pets = prof.get("unlocked_pets", ["mochi", "kuro", "luna", "pip"])
		var unlocked_endings = prof.get("unlocked_endings", [])
		var sel_nav: StringName = StringName(str(prof.get("selected_navigator", "lyra")))

		save_manager_ref.save_profile(unlocked_items, bans, chars, bio, anti, skills, sel_char, dm, trophies, spd, career, sel_pet, unlocked_pets, unlocked_endings, sel_nav, unlocked)
		return true
	return false

static func lock_navigator(nav_id: StringName, save_manager_ref: Object) -> void:
	var prof: Dictionary = save_manager_ref.load_profile()
	var unlocked := get_unlocked_navigators(prof)
	unlocked.erase(nav_id)
	unlocked.erase(String(nav_id))

	var unlocked_items: Array[StringName] = prof.get("unlocked_items", [])
	var chars: Array[StringName] = prof.get("unlocked_characters", [])
	var bans: Dictionary = prof.get("character_banlists", {})
	var bio: int = int(prof.get("biomass", 0))
	var anti: int = int(prof.get("antimatter", 0))
	var skills: Dictionary = prof.get("character_skills", {})
	var sel_char: StringName = StringName(str(prof.get("selected_character", "nova")))
	var dm: int = int(prof.get("dark_matter", 0))
	var trophies: Dictionary = prof.get("trophies_unlocked", {})
	var spd: float = float(prof.get("game_speed", 1.0))
	var career: Dictionary = prof.get("career_stats", save_manager_ref._get_default_career_stats())
	var sel_pet: StringName = StringName(str(prof.get("selected_pet", "mochi")))
	var unlocked_pets = prof.get("unlocked_pets", ["mochi", "kuro", "luna", "pip"])
	var unlocked_endings = prof.get("unlocked_endings", [])
	var sel_nav: StringName = StringName(str(prof.get("selected_navigator", "lyra")))
	if sel_nav == nav_id:
		sel_nav = &"lyra"

	save_manager_ref.save_profile(unlocked_items, bans, chars, bio, anti, skills, sel_char, dm, trophies, spd, career, sel_pet, unlocked_pets, unlocked_endings, sel_nav, unlocked)

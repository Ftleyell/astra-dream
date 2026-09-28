class_name SaveSkinsModule
extends RefCounted

## SaveSkinsModule.gd
## Manejo especializado de tokens de gacha, aspecto cosméticos y progresión de estrellas (1★, 2★, 3★).

const CosmeticsManager = preload("res://core/systems/cosmetics_manager.gd")

static func get_gacha_tokens(profile: Dictionary) -> int:
	return int(profile.get("gacha_tokens", 0))

static func add_gacha_tokens(amount: int, save_manager_ref: Object) -> int:
	if amount <= 0:
		return save_manager_ref.get_gacha_tokens()
	var profile: Dictionary = save_manager_ref.load_profile()
	var current: int = int(profile.get("gacha_tokens", 0))
	var new_total := current + amount
	var unlocked_items: Array[StringName] = profile.get("unlocked_items", [])
	var bans: Dictionary = profile.get("character_banlists", {})
	var unlocked_chars: Array[StringName] = profile.get("unlocked_characters", [])
	var biomass: int = int(profile.get("biomass", 0))
	var antimatter: int = int(profile.get("antimatter", 0))
	var skills: Dictionary = profile.get("character_skills", {})
	var sel_char: StringName = StringName(str(profile.get("selected_character", "nova")))
	var dark_matter: int = int(profile.get("dark_matter", 0))
	var trophies: Dictionary = profile.get("trophies_unlocked", {})
	var speed: float = float(profile.get("game_speed", 1.0))
	var career: Dictionary = profile.get("career_stats", {})
	var pet: StringName = StringName(str(profile.get("selected_pet", "mochi")))
	var pets: Array[StringName] = profile.get("unlocked_pets", [])
	var endings: Array[String] = profile.get("unlocked_endings", [])
	var nav: StringName = StringName(str(profile.get("selected_navigator", "lyra")))
	var navs: Array[StringName] = profile.get("unlocked_navigators", [])
	var unlocked_skins: Dictionary = profile.get("unlocked_skins", {})
	var equipped_skins: Dictionary = profile.get("equipped_skins", {})

	save_manager_ref.save_profile(
		unlocked_items, bans, unlocked_chars, biomass, antimatter, skills, sel_char,
		dark_matter, trophies, speed, career, pet, pets, endings, nav, navs,
		new_total, unlocked_skins, equipped_skins
	)
	return new_total

static func spend_gacha_tokens(amount: int, save_manager_ref: Object) -> bool:
	if amount <= 0:
		return true
	var profile: Dictionary = save_manager_ref.load_profile()
	var current: int = int(profile.get("gacha_tokens", 0))
	if current < amount:
		return false
	var new_total := current - amount
	var unlocked_items: Array[StringName] = profile.get("unlocked_items", [])
	var bans: Dictionary = profile.get("character_banlists", {})
	var unlocked_chars: Array[StringName] = profile.get("unlocked_characters", [])
	var biomass: int = int(profile.get("biomass", 0))
	var antimatter: int = int(profile.get("antimatter", 0))
	var skills: Dictionary = profile.get("character_skills", {})
	var sel_char: StringName = StringName(str(profile.get("selected_character", "nova")))
	var dark_matter: int = int(profile.get("dark_matter", 0))
	var trophies: Dictionary = profile.get("trophies_unlocked", {})
	var speed: float = float(profile.get("game_speed", 1.0))
	var career: Dictionary = profile.get("career_stats", {})
	var pet: StringName = StringName(str(profile.get("selected_pet", "mochi")))
	var pets: Array[StringName] = profile.get("unlocked_pets", [])
	var endings: Array[String] = profile.get("unlocked_endings", [])
	var nav: StringName = StringName(str(profile.get("selected_navigator", "lyra")))
	var navs: Array[StringName] = profile.get("unlocked_navigators", [])
	var unlocked_skins: Dictionary = profile.get("unlocked_skins", {})
	var equipped_skins: Dictionary = profile.get("equipped_skins", {})

	save_manager_ref.save_profile(
		unlocked_items, bans, unlocked_chars, biomass, antimatter, skills, sel_char,
		dark_matter, trophies, speed, career, pet, pets, endings, nav, navs,
		new_total, unlocked_skins, equipped_skins
	)
	return true

static func get_unlocked_skins(profile: Dictionary) -> Dictionary:
	return profile.get("unlocked_skins", {})

static func is_skin_unlocked(skin_id: String, profile: Dictionary) -> bool:
	var skins: Dictionary = profile.get("unlocked_skins", {})
	return skins.has(skin_id)

static func get_skin_stars(skin_id: String, profile: Dictionary) -> int:
	var skins: Dictionary = get_unlocked_skins(profile)
	if skins.has(skin_id):
		var entry = skins[skin_id]
		if entry is Dictionary:
			return int(entry.get("stars", 1))
		elif entry is int or entry is float:
			return int(entry)
	return 0

static func unlock_or_upgrade_skin(skin_id: String, save_manager_ref: Object) -> Dictionary:
	var profile: Dictionary = save_manager_ref.load_profile()
	var unlocked_skins: Dictionary = profile.get("unlocked_skins", {}).duplicate(true)
	var current_biomass: int = int(profile.get("biomass", 0))
	var current_stars: int = 0
	
	if unlocked_skins.has(skin_id):
		var entry = unlocked_skins[skin_id]
		if entry is Dictionary:
			current_stars = int(entry.get("stars", 1))
		else:
			current_stars = int(entry)
	
	var result := {
		"skin_id": skin_id,
		"previous_stars": current_stars,
		"new_stars": current_stars,
		"status": "new", # "new", "upgraded", "max_converted"
		"biomass_awarded": 0
	}
	
	if current_stars == 0:
		unlocked_skins[skin_id] = {
			"stars": 1,
			"unlocked_at": Time.get_datetime_string_from_system(false, true)
		}
		result["new_stars"] = 1
		result["status"] = "new"
	elif current_stars < 3:
		var next_stars := current_stars + 1
		unlocked_skins[skin_id] = {
			"stars": next_stars,
			"unlocked_at": Time.get_datetime_string_from_system(false, true)
		}
		result["new_stars"] = next_stars
		result["status"] = "upgraded"
	else:
		# Duplicado en 3★: Otorgar 150 Polvo Estelar (Biomasa para el árbol de talentos)
		result["new_stars"] = 3
		result["status"] = "max_converted"
		result["biomass_awarded"] = 150
		current_biomass += 150

	var unlocked_items: Array[StringName] = profile.get("unlocked_items", [])
	var bans: Dictionary = profile.get("character_banlists", {})
	var unlocked_chars: Array[StringName] = profile.get("unlocked_characters", [])
	var antimatter: int = int(profile.get("antimatter", 0))
	var skills: Dictionary = profile.get("character_skills", {})
	var sel_char: StringName = StringName(str(profile.get("selected_character", "nova")))
	var dark_matter: int = int(profile.get("dark_matter", 0))
	var trophies: Dictionary = profile.get("trophies_unlocked", {})
	var speed: float = float(profile.get("game_speed", 1.0))
	var career: Dictionary = profile.get("career_stats", {})
	var pet: StringName = StringName(str(profile.get("selected_pet", "mochi")))
	var pets: Array[StringName] = profile.get("unlocked_pets", [])
	var endings: Array[String] = profile.get("unlocked_endings", [])
	var nav: StringName = StringName(str(profile.get("selected_navigator", "lyra")))
	var navs: Array[StringName] = profile.get("unlocked_navigators", [])
	var tokens: int = int(profile.get("gacha_tokens", 0))
	var equipped_skins: Dictionary = profile.get("equipped_skins", {})

	save_manager_ref.save_profile(
		unlocked_items, bans, unlocked_chars, current_biomass, antimatter, skills, sel_char,
		dark_matter, trophies, speed, career, pet, pets, endings, nav, navs,
		tokens, unlocked_skins, equipped_skins
	)
	return result

static func equip_skin(slot_key: String, skin_id: String, save_manager_ref: Object) -> void:
	var profile: Dictionary = save_manager_ref.load_profile()
	var equipped: Dictionary = profile.get("equipped_skins", {}).duplicate(true)
	if skin_id.is_empty():
		equipped.erase(slot_key)
	else:
		equipped[slot_key] = skin_id

	var unlocked_items: Array[StringName] = profile.get("unlocked_items", [])
	var bans: Dictionary = profile.get("character_banlists", {})
	var unlocked_chars: Array[StringName] = profile.get("unlocked_characters", [])
	var biomass: int = int(profile.get("biomass", 0))
	var antimatter: int = int(profile.get("antimatter", 0))
	var skills: Dictionary = profile.get("character_skills", {})
	var sel_char: StringName = StringName(str(profile.get("selected_character", "nova")))
	var dark_matter: int = int(profile.get("dark_matter", 0))
	var trophies: Dictionary = profile.get("trophies_unlocked", {})
	var speed: float = float(profile.get("game_speed", 1.0))
	var career: Dictionary = profile.get("career_stats", {})
	var pet: StringName = StringName(str(profile.get("selected_pet", "mochi")))
	var pets: Array[StringName] = profile.get("unlocked_pets", [])
	var endings: Array[String] = profile.get("unlocked_endings", [])
	var nav: StringName = StringName(str(profile.get("selected_navigator", "lyra")))
	var navs: Array[StringName] = profile.get("unlocked_navigators", [])
	var tokens: int = int(profile.get("gacha_tokens", 0))
	var unlocked_skins: Dictionary = profile.get("unlocked_skins", {})

	save_manager_ref.save_profile(
		unlocked_items, bans, unlocked_chars, biomass, antimatter, skills, sel_char,
		dark_matter, trophies, speed, career, pet, pets, endings, nav, navs,
		tokens, unlocked_skins, equipped
	)

static func unequip_skin(slot_key: String, save_manager_ref: Object) -> void:
	equip_skin(slot_key, "", save_manager_ref)

static func get_equipped_skin(slot_key: String, profile: Dictionary) -> String:
	var equipped: Dictionary = profile.get("equipped_skins", {})
	return str(equipped.get(slot_key, ""))

static func get_equipped_skins(profile: Dictionary) -> Dictionary:
	return profile.get("equipped_skins", {})

static func set_gacha_tokens(amount: int, save_manager_ref: Object) -> void:
	var profile: Dictionary = save_manager_ref.load_profile()
	var unlocked_items: Array[StringName] = profile.get("unlocked_items", [])
	var bans: Dictionary = profile.get("character_banlists", {})
	var unlocked_chars: Array[StringName] = profile.get("unlocked_characters", [])
	var biomass: int = int(profile.get("biomass", 0))
	var antimatter: int = int(profile.get("antimatter", 0))
	var skills: Dictionary = profile.get("character_skills", {})
	var sel_char: StringName = StringName(str(profile.get("selected_character", "nova")))
	var dark_matter: int = int(profile.get("dark_matter", 0))
	var trophies: Dictionary = profile.get("trophies_unlocked", {})
	var speed: float = float(profile.get("game_speed", 1.0))
	var career: Dictionary = profile.get("career_stats", {})
	var pet: StringName = StringName(str(profile.get("selected_pet", "mochi")))
	var pets: Array[StringName] = profile.get("unlocked_pets", [])
	var endings: Array[String] = profile.get("unlocked_endings", [])
	var nav: StringName = StringName(str(profile.get("selected_navigator", "lyra")))
	var navs: Array[StringName] = profile.get("unlocked_navigators", [])
	var unlocked_skins: Dictionary = profile.get("unlocked_skins", {})
	var equipped: Dictionary = profile.get("equipped_skins", {})

	save_manager_ref.save_profile(
		unlocked_items, bans, unlocked_chars, biomass, antimatter, skills, sel_char,
		dark_matter, trophies, speed, career, pet, pets, endings, nav, navs,
		maxi(0, amount), unlocked_skins, equipped
	)

static func unlock_all_skins(star_level: int, save_manager_ref: Object) -> int:
	var profile: Dictionary = save_manager_ref.load_profile()
	var skins_dict: Dictionary = CosmeticsManager.get_all_skins()
	var unlocked: Dictionary = profile.get("unlocked_skins", {}).duplicate(true)
	var count := 0
	for sid in skins_dict.keys():
		unlocked[sid] = {
			"stars": clampi(star_level, 1, 3),
			"unlocked_at": Time.get_datetime_string_from_system(false, true)
		}
		count += 1

	var unlocked_items: Array[StringName] = profile.get("unlocked_items", [])
	var bans: Dictionary = profile.get("character_banlists", {})
	var unlocked_chars: Array[StringName] = profile.get("unlocked_characters", [])
	var biomass: int = int(profile.get("biomass", 0))
	var antimatter: int = int(profile.get("antimatter", 0))
	var skills: Dictionary = profile.get("character_skills", {})
	var sel_char: StringName = StringName(str(profile.get("selected_character", "nova")))
	var dark_matter: int = int(profile.get("dark_matter", 0))
	var trophies: Dictionary = profile.get("trophies_unlocked", {})
	var speed: float = float(profile.get("game_speed", 1.0))
	var career: Dictionary = profile.get("career_stats", {})
	var pet: StringName = StringName(str(profile.get("selected_pet", "mochi")))
	var pets: Array[StringName] = profile.get("unlocked_pets", [])
	var endings: Array[String] = profile.get("unlocked_endings", [])
	var nav: StringName = StringName(str(profile.get("selected_navigator", "lyra")))
	var navs: Array[StringName] = profile.get("unlocked_navigators", [])
	var tokens: int = int(profile.get("gacha_tokens", 0))
	var equipped: Dictionary = profile.get("equipped_skins", {})

	save_manager_ref.save_profile(
		unlocked_items, bans, unlocked_chars, biomass, antimatter, skills, sel_char,
		dark_matter, trophies, speed, career, pet, pets, endings, nav, navs,
		tokens, unlocked, equipped
	)
	return count

static func lock_all_skins(save_manager_ref: Object) -> void:
	var profile: Dictionary = save_manager_ref.load_profile()
	var unlocked_items: Array[StringName] = profile.get("unlocked_items", [])
	var bans: Dictionary = profile.get("character_banlists", {})
	var unlocked_chars: Array[StringName] = profile.get("unlocked_characters", [])
	var biomass: int = int(profile.get("biomass", 0))
	var antimatter: int = int(profile.get("antimatter", 0))
	var skills: Dictionary = profile.get("character_skills", {})
	var sel_char: StringName = StringName(str(profile.get("selected_character", "nova")))
	var dark_matter: int = int(profile.get("dark_matter", 0))
	var trophies: Dictionary = profile.get("trophies_unlocked", {})
	var speed: float = float(profile.get("game_speed", 1.0))
	var career: Dictionary = profile.get("career_stats", {})
	var pet: StringName = StringName(str(profile.get("selected_pet", "mochi")))
	var pets: Array[StringName] = profile.get("unlocked_pets", [])
	var endings: Array[String] = profile.get("unlocked_endings", [])
	var nav: StringName = StringName(str(profile.get("selected_navigator", "lyra")))
	var navs: Array[StringName] = profile.get("unlocked_navigators", [])
	var tokens: int = int(profile.get("gacha_tokens", 0))

	save_manager_ref.save_profile(
		unlocked_items, bans, unlocked_chars, biomass, antimatter, skills, sel_char,
		dark_matter, trophies, speed, career, pet, pets, endings, nav, navs,
		tokens, {}, {}
	)

static func get_banner_pity(banner_id: String, profile: Dictionary) -> int:
	var pity_dict: Dictionary = profile.get("gacha_pity", {})
	return int(pity_dict.get(banner_id, 0))

static func increment_banner_pity(banner_id: String, amount: int, save_manager_ref: Object) -> int:
	var profile: Dictionary = save_manager_ref.load_profile()
	var pity_dict: Dictionary = profile.get("gacha_pity", {}).duplicate()
	var current: int = int(pity_dict.get(banner_id, 0))
	var updated: int = clampi(current + amount, 0, 10)
	pity_dict[banner_id] = updated

	var unlocked_items: Array[StringName] = profile.get("unlocked_items", [])
	var bans: Dictionary = profile.get("character_banlists", {})
	var unlocked_chars: Array[StringName] = profile.get("unlocked_characters", [])
	var biomass: int = int(profile.get("biomass", 0))
	var antimatter: int = int(profile.get("antimatter", 0))
	var skills: Dictionary = profile.get("character_skills", {})
	var sel_char: StringName = StringName(str(profile.get("selected_character", "nova")))
	var dark_matter: int = int(profile.get("dark_matter", 0))
	var trophies: Dictionary = profile.get("trophies_unlocked", {})
	var speed: float = float(profile.get("game_speed", 1.0))
	var career: Dictionary = profile.get("career_stats", {})
	var pet: StringName = StringName(str(profile.get("selected_pet", "mochi")))
	var pets: Array[StringName] = profile.get("unlocked_pets", [])
	var endings: Array[String] = profile.get("unlocked_endings", [])
	var nav: StringName = StringName(str(profile.get("selected_navigator", "lyra")))
	var navs: Array[StringName] = profile.get("unlocked_navigators", [])
	var tokens: int = int(profile.get("gacha_tokens", 0))
	var skins: Dictionary = profile.get("unlocked_skins", {})
	var equipped: Dictionary = profile.get("equipped_skins", {})

	save_manager_ref.save_profile(
		unlocked_items, bans, unlocked_chars, biomass, antimatter, skills, sel_char,
		dark_matter, trophies, speed, career, pet, pets, endings, nav, navs,
		tokens, skins, equipped, pity_dict
	)
	return updated

static func reset_banner_pity(banner_id: String, save_manager_ref: Object) -> void:
	var profile: Dictionary = save_manager_ref.load_profile()
	var pity_dict: Dictionary = profile.get("gacha_pity", {}).duplicate()
	pity_dict[banner_id] = 0

	var unlocked_items: Array[StringName] = profile.get("unlocked_items", [])
	var bans: Dictionary = profile.get("character_banlists", {})
	var unlocked_chars: Array[StringName] = profile.get("unlocked_characters", [])
	var biomass: int = int(profile.get("biomass", 0))
	var antimatter: int = int(profile.get("antimatter", 0))
	var skills: Dictionary = profile.get("character_skills", {})
	var sel_char: StringName = StringName(str(profile.get("selected_character", "nova")))
	var dark_matter: int = int(profile.get("dark_matter", 0))
	var trophies: Dictionary = profile.get("trophies_unlocked", {})
	var speed: float = float(profile.get("game_speed", 1.0))
	var career: Dictionary = profile.get("career_stats", {})
	var pet: StringName = StringName(str(profile.get("selected_pet", "mochi")))
	var pets: Array[StringName] = profile.get("unlocked_pets", [])
	var endings: Array[String] = profile.get("unlocked_endings", [])
	var nav: StringName = StringName(str(profile.get("selected_navigator", "lyra")))
	var navs: Array[StringName] = profile.get("unlocked_navigators", [])
	var tokens: int = int(profile.get("gacha_tokens", 0))
	var skins: Dictionary = profile.get("unlocked_skins", {})
	var equipped: Dictionary = profile.get("equipped_skins", {})

	save_manager_ref.save_profile(
		unlocked_items, bans, unlocked_chars, biomass, antimatter, skills, sel_char,
		dark_matter, trophies, speed, career, pet, pets, endings, nav, navs,
		tokens, skins, equipped, pity_dict
	)


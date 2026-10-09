class_name ProfileStorage
extends RefCounted

## Gestor de lectura, escritura física y validación de esquema para el perfil de usuario.
## Coordina la serialización y persistencia delegando en los DTOs fuertemente tipados:
## - ProfileRosterData (pilotos, skins, acompañantes, banlists y equipamiento)
## - ProfileEconomyData (biomasa, antimateria, materia oscura, gacha)
## - ProfileSettingsData (velocidad, trofeos y estadísticas de carrera)

const SAVE_PATH: String = "user://profile_data.json"
const SCHEMA_VERSION: int = 2

const ProfileRosterDataScript = preload("res://core/systems/persistence/schemas/profile_roster_data.gd")
const ProfileEconomyDataScript = preload("res://core/systems/persistence/schemas/profile_economy_data.gd")
const ProfileSettingsDataScript = preload("res://core/systems/persistence/schemas/profile_settings_data.gd")

const TomeCatalogScript = preload("res://data/tomes/tome_catalog.gd")
const WeaponCatalogScript = preload("res://data/weapons/weapon_catalog.gd")

# ==============================================================================
# CREACIÓN DE PERFILES Y DICCIONARIOS BASE
# ==============================================================================

static func get_default_career_stats() -> Dictionary:
	return ProfileSettingsDataScript.get_default_career_stats()

static func get_default_profile() -> Dictionary:
	var roster: RefCounted = ProfileRosterDataScript.create_default()
	var economy: RefCounted = ProfileEconomyDataScript.create_default()
	var settings: RefCounted = ProfileSettingsDataScript.create_default()
	return assemble_profile_dict(roster, economy, settings)

static func assemble_profile_dict(
	roster: RefCounted,
	economy: RefCounted,
	settings: RefCounted
) -> Dictionary:
	return {
		"unlocked_items": roster.unlocked_items,
		"unlocked_characters": roster.unlocked_characters,
		"character_banlists": roster.character_banlists,
		"biomass": economy.biomass,
		"antimatter": economy.antimatter,
		"dark_matter": economy.dark_matter,
		"trophies_unlocked": settings.trophies_unlocked,
		"character_skills": roster.character_skills,
		"selected_character": roster.selected_character,
		"game_speed": settings.game_speed,
		"career_stats": settings.career_stats,
		"selected_pet": roster.selected_pet,
		"unlocked_pets": roster.unlocked_pets,
		"unlocked_endings": roster.unlocked_endings,
		"selected_navigator": roster.selected_navigator,
		"unlocked_navigators": roster.unlocked_navigators,
		"gacha_tokens": economy.gacha_tokens,
		"unlocked_skins": roster.unlocked_skins,
		"equipped_skins": roster.equipped_skins,
		"character_active_tomes": roster.character_active_tomes,
		"character_active_weapons": roster.character_active_weapons,
		"character_loadouts": roster.character_loadouts,
		"gacha_pity": economy.gacha_pity
	}

static func serialize_profile(
	roster: RefCounted,
	economy: RefCounted,
	settings: RefCounted
) -> Dictionary:
	var payload: Dictionary = {
		"version": SCHEMA_VERSION
	}
	payload.merge(roster.to_dict())
	payload.merge(economy.to_dict())
	payload.merge(settings.to_dict())
	return payload

# ==============================================================================
# CARGA Y SANEAMIENTO
# ==============================================================================

static func clean_and_validate_data(raw: Dictionary) -> Dictionary:
	var roster: RefCounted = ProfileRosterDataScript.new()
	roster.populate_from_dict(raw)

	var economy: RefCounted = ProfileEconomyDataScript.new()
	economy.populate_from_dict(raw)

	var settings: RefCounted = ProfileSettingsDataScript.new()
	settings.populate_from_dict(raw)

	return assemble_profile_dict(roster, economy, settings)

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

# ==============================================================================
# GUARDADO FÍSICO
# ==============================================================================

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

	var roster: RefCounted = ProfileRosterDataScript.new()
	roster.populate_from_dict(existing_prof)
	roster.unlocked_items = unlocked_items
	roster.character_banlists = character_bans
	if not unlocked_chars.is_empty():
		roster.unlocked_characters = unlocked_chars
	if p_skills != null and p_skills is Dictionary:
		roster.character_skills = p_skills
	if p_selected_char != &"":
		roster.selected_character = p_selected_char
	if p_selected_pet != &"":
		roster.selected_pet = p_selected_pet
	if p_unlocked_pets != null and p_unlocked_pets is Array:
		var pets_typed: Array[StringName] = []
		for p in p_unlocked_pets:
			pets_typed.append(StringName(str(p)))
		roster.unlocked_pets = pets_typed
	if p_unlocked_endings != null and p_unlocked_endings is Array:
		var endings_typed: Array[String] = []
		for e in p_unlocked_endings:
			endings_typed.append(String(e))
		roster.unlocked_endings = endings_typed
	if p_selected_navigator != &"":
		roster.selected_navigator = p_selected_navigator
	if p_unlocked_navigators != null and p_unlocked_navigators is Array:
		var navs_typed: Array[StringName] = []
		for n in p_unlocked_navigators:
			navs_typed.append(StringName(str(n)))
		roster.unlocked_navigators = navs_typed
	if p_unlocked_skins != null and p_unlocked_skins is Dictionary:
		roster.unlocked_skins = p_unlocked_skins
	if p_equipped_skins != null and p_equipped_skins is Dictionary:
		roster.equipped_skins = p_equipped_skins

	var economy: RefCounted = ProfileEconomyDataScript.new()
	economy.populate_from_dict(existing_prof)
	if p_biomass >= 0:
		economy.biomass = p_biomass
	if p_antimatter >= 0:
		economy.antimatter = p_antimatter
	if p_dark_matter >= 0:
		economy.dark_matter = p_dark_matter
	if p_gacha_tokens >= 0:
		economy.gacha_tokens = p_gacha_tokens
	if p_gacha_pity != null and p_gacha_pity is Dictionary:
		economy.gacha_pity = p_gacha_pity

	var settings: RefCounted = ProfileSettingsDataScript.new()
	settings.populate_from_dict(existing_prof)
	if p_game_speed > 0.0:
		settings.game_speed = p_game_speed
	if p_trophies != null and p_trophies is Dictionary:
		settings.trophies_unlocked = p_trophies
	if p_career_stats != null and p_career_stats is Dictionary:
		settings.career_stats = p_career_stats

	var payload: Dictionary = serialize_profile(roster, economy, settings)

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		return FileAccess.get_open_error()

	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	return OK

# ==============================================================================
# ACCESORES ESPECÍFICOS DE ROSTER Y EQUIPAMIENTO
# ==============================================================================

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

static func get_unlocked_items() -> Array[StringName]:
	var prof: Dictionary = load_profile()
	var raw_items: Array = prof.get("unlocked_items", [])
	var result: Array[StringName] = []
	for it in raw_items:
		result.append(StringName(str(it)))
	return result

static func is_item_unlocked(item_id: StringName) -> bool:
	var unlocked := get_unlocked_items()
	if unlocked.has(item_id) or unlocked.is_empty():
		return true
	return true

static func get_character_banlist(char_id: StringName) -> Array[StringName]:
	var prof: Dictionary = load_profile()
	var ban_dict: Dictionary = prof.get("character_banlists", {})
	if ban_dict.has(str(char_id)):
		var raw_arr: Array = ban_dict[str(char_id)]
		var result: Array[StringName] = []
		for item in raw_arr:
			result.append(StringName(str(item)))
		return result
	elif ban_dict.has(char_id):
		var raw_arr: Array = ban_dict[char_id]
		var result: Array[StringName] = []
		for item in raw_arr:
			result.append(StringName(str(item)))
		return result
	return []

static func set_character_banlist(char_id: StringName, banned_ids: Array[StringName]) -> void:
	var prof: Dictionary = load_profile()
	var ban_dict: Dictionary = prof.get("character_banlists", {}).duplicate()
	var str_arr: Array[String] = []
	for b: StringName in banned_ids:
		str_arr.append(str(b))
	ban_dict[str(char_id)] = str_arr
	prof["character_banlists"] = ban_dict

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

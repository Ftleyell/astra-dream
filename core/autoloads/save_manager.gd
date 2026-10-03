extends Node

const ProfileStorage = preload("res://core/systems/persistence/profile_storage.gd")
const MetaProgressionState = preload("res://core/systems/persistence/meta_progression_state.gd")
const ActiveRunStorage = preload("res://core/systems/persistence/active_run_storage.gd")
const SaveSkinsModule = preload("res://core/autoloads/save_modules/save_skins_module.gd")
const SaveRosterModule = preload("res://core/autoloads/save_modules/save_roster_module.gd")

static var is_resuming_run: bool = false
const SAVE_PATH: String = "user://profile_data.json"
const SCHEMA_VERSION: int = 2

# ==============================================================================
# PERFIL & DISCO I/O (DELEGACIÓN A PROFILE STORAGE)
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
	return ProfileStorage.save_profile(
		unlocked_items, character_bans, unlocked_chars, p_biomass, p_antimatter,
		p_skills, p_selected_char, p_dark_matter, p_trophies, p_game_speed,
		p_career_stats, p_selected_pet, p_unlocked_pets, p_unlocked_endings,
		p_selected_navigator, p_unlocked_navigators, p_gacha_tokens,
		p_unlocked_skins, p_equipped_skins, p_gacha_pity
	)

static func load_profile() -> Dictionary:
	return ProfileStorage.load_profile()

static func _get_default_career_stats() -> Dictionary:
	return ProfileStorage.get_default_career_stats()

static func _get_default_profile() -> Dictionary:
	return ProfileStorage.get_default_profile()

# ==============================================================================
# ECONOMÍA Y META-PROGRESIÓN (DELEGACIÓN A META PROGRESSION STATE)
# ==============================================================================

static func get_biomass() -> int:
	return MetaProgressionState.get_biomass()

static func add_biomass(amount: int) -> int:
	var self_class = load("res://core/autoloads/save_manager.gd")
	return MetaProgressionState.add_biomass(amount, self_class)

static func add_test_biomass(amount: int = 100) -> int:
	return add_biomass(amount)

static func set_biomass(amount: int) -> void:
	var self_class = load("res://core/autoloads/save_manager.gd")
	MetaProgressionState.set_biomass(amount, self_class)

static func get_antimatter() -> int:
	return MetaProgressionState.get_antimatter()

static func add_antimatter(amount: int) -> int:
	var self_class = load("res://core/autoloads/save_manager.gd")
	return MetaProgressionState.add_antimatter(amount, self_class)

static func get_dark_matter() -> int:
	return MetaProgressionState.get_dark_matter()

static func add_dark_matter(amount: int) -> int:
	var self_class = load("res://core/autoloads/save_manager.gd")
	return MetaProgressionState.add_dark_matter(amount, self_class)

static func get_unlocked_trophies() -> Dictionary:
	return MetaProgressionState.get_unlocked_trophies()

static func is_trophy_unlocked(trophy_id: StringName) -> bool:
	return MetaProgressionState.is_trophy_unlocked(trophy_id)

static func get_trophy_mastery(trophy_id: StringName) -> int:
	return MetaProgressionState.get_trophy_mastery(trophy_id)

static func unlock_or_upgrade_trophy(trophy_id: StringName, mastery_level: int = 1) -> bool:
	var self_class = load("res://core/autoloads/save_manager.gd")
	return MetaProgressionState.unlock_or_upgrade_trophy(trophy_id, mastery_level, self_class)

static func upgrade_trophy_with_dark_matter(trophy_id: StringName, cost: int) -> bool:
	var self_class = load("res://core/autoloads/save_manager.gd")
	return MetaProgressionState.upgrade_trophy_with_dark_matter(trophy_id, cost, self_class)

static func get_trophy_passive_bonuses() -> Dictionary:
	return MetaProgressionState.get_trophy_passive_bonuses()

# ==============================================================================
# HABILIDADES Y PILOTOS
# ==============================================================================

static func get_character_unlocked_nodes(char_id: StringName) -> Array[StringName]:
	return MetaProgressionState.get_character_unlocked_nodes(char_id)

static func is_character_node_unlocked(char_id: StringName, node_id: StringName) -> bool:
	return MetaProgressionState.is_character_node_unlocked(char_id, node_id)

static func get_character_unlocked_nodes_count(char_id: StringName) -> int:
	return MetaProgressionState.get_character_unlocked_nodes_count(char_id)

static func unlock_character_skill_node(char_id: StringName, node_id: StringName, cost: int, req_node_id: StringName = &"") -> bool:
	var self_class = load("res://core/autoloads/save_manager.gd")
	return MetaProgressionState.unlock_character_skill_node(char_id, node_id, cost, req_node_id, self_class)

static func refund_character_skills(char_id: StringName, node_cost: int = 25) -> int:
	var self_class = load("res://core/autoloads/save_manager.gd")
	return MetaProgressionState.refund_character_skills(char_id, node_cost, self_class)

static func get_selected_character() -> StringName:
	return MetaProgressionState.get_selected_character()

static func set_selected_character(char_id: StringName) -> void:
	var self_class = load("res://core/autoloads/save_manager.gd")
	MetaProgressionState.set_selected_character(char_id, self_class)

static func get_game_speed() -> float:
	return MetaProgressionState.get_game_speed()

static func set_game_speed(speed: float) -> void:
	var self_class = load("res://core/autoloads/save_manager.gd")
	MetaProgressionState.set_game_speed(speed, self_class)

# ==============================================================================
# ESTADÍSTICAS DE CARRERA Y DESBLOQUEO DE PERSONAJES
# ==============================================================================

static func get_career_stats() -> Dictionary:
	return MetaProgressionState.get_career_stats()

static func is_character_unlocked(char_id: StringName) -> bool:
	return MetaProgressionState.is_character_unlocked(char_id)

static func unlock_character(char_id: StringName) -> bool:
	var self_class = load("res://core/autoloads/save_manager.gd")
	return MetaProgressionState.unlock_character(char_id, self_class)

static func lock_character(char_id: StringName) -> bool:
	var self_class = load("res://core/autoloads/save_manager.gd")
	return MetaProgressionState.lock_character(char_id, self_class)

static func record_boss_kill() -> bool:
	var self_class = load("res://core/autoloads/save_manager.gd")
	return MetaProgressionState.record_boss_kill(self_class)

static func record_career_run_end(stats_data: Dictionary) -> void:
	var self_class = load("res://core/autoloads/save_manager.gd")
	MetaProgressionState.record_career_run_end(stats_data, self_class)

static func reset_career_stats() -> void:
	var self_class = load("res://core/autoloads/save_manager.gd")
	MetaProgressionState.reset_career_stats(self_class)

static func set_career_bosses_killed(count: int) -> void:
	var self_class = load("res://core/autoloads/save_manager.gd")
	MetaProgressionState.set_career_bosses_killed(count, self_class)

static func get_bosses_defeated_count() -> int:
	return int(get_career_stats().get("total_bosses_killed", 0))

# ==============================================================================
# PETS & COMPANIONS (DELEGACIÓN A SAVE ROSTER MODULE)
# ==============================================================================

static func get_selected_pet() -> StringName:
	return SaveRosterModule.get_selected_pet(load_profile(), is_pet_unlocked)

static func set_selected_pet(pet_id: StringName) -> void:
	var self_class = load("res://core/autoloads/save_manager.gd")
	SaveRosterModule.set_selected_pet(pet_id, self_class)

static func get_unlocked_pets() -> Array[StringName]:
	return SaveRosterModule.get_unlocked_pets(load_profile())

static func is_pet_unlocked(pet_id: StringName) -> bool:
	return SaveRosterModule.is_pet_unlocked(pet_id, load_profile())

static func unlock_pet(pet_id: StringName) -> bool:
	var self_class = load("res://core/autoloads/save_manager.gd")
	return SaveRosterModule.unlock_pet(pet_id, self_class)

static func lock_pet(pet_id: StringName) -> void:
	var self_class = load("res://core/autoloads/save_manager.gd")
	SaveRosterModule.lock_pet(pet_id, self_class)

static func get_unlocked_endings() -> Array[String]:
	return SaveRosterModule.get_unlocked_endings(load_profile())

static func has_unlocked_ending(ending_id: String) -> bool:
	return SaveRosterModule.has_unlocked_ending(ending_id, load_profile())

static func record_ending(ending_id: String) -> bool:
	var self_class = load("res://core/autoloads/save_manager.gd")
	return SaveRosterModule.record_ending(ending_id, self_class)

# ==============================================================================
# NAVIGATORS PERSISTENCE (NAVEGANTES)
# ==============================================================================

static func get_selected_navigator() -> StringName:
	return SaveRosterModule.get_selected_navigator(load_profile(), is_navigator_unlocked)

static func set_selected_navigator(nav_id: StringName) -> void:
	var self_class = load("res://core/autoloads/save_manager.gd")
	SaveRosterModule.set_selected_navigator(nav_id, self_class)

static func get_unlocked_navigators() -> Array[StringName]:
	return SaveRosterModule.get_unlocked_navigators(load_profile())

static func is_navigator_unlocked(nav_id: StringName) -> bool:
	return SaveRosterModule.is_navigator_unlocked(nav_id, load_profile())

static func unlock_navigator(nav_id: StringName) -> bool:
	var self_class = load("res://core/autoloads/save_manager.gd")
	return SaveRosterModule.unlock_navigator(nav_id, self_class)

static func lock_navigator(nav_id: StringName) -> void:
	var self_class = load("res://core/autoloads/save_manager.gd")
	SaveRosterModule.lock_navigator(nav_id, self_class)

# ==============================================================================
# RUN EN CURSO & HIGHSCORES (DELEGACIÓN A ACTIVE RUN STORAGE)
# ==============================================================================

const ACTIVE_RUN_PATH: String = "user://active_run.json"
const HIGHSCORES_PATH: String = "user://highscores.json"
const MAX_HIGHSCORES: int = 10

static func save_active_run(run_data: Dictionary) -> Error:
	return ActiveRunStorage.save_active_run(run_data)

static func has_active_run() -> bool:
	return ActiveRunStorage.has_active_run()

static func load_active_run() -> Dictionary:
	return ActiveRunStorage.load_active_run()

static func clear_active_run() -> void:
	ActiveRunStorage.clear_active_run()

static func record_run_score(result: Dictionary) -> int:
	return ActiveRunStorage.record_run_score(result)

static func clear_highscores() -> void:
	ActiveRunStorage.clear_highscores()

static func get_top_highscores() -> Array[Dictionary]:
	return ActiveRunStorage.get_top_highscores()

static func _get_default_highscores() -> Array[Dictionary]:
	return ActiveRunStorage.get_default_highscores()

# ==============================================================================
# GACHA & COSMÉTICOS (DELEGACIÓN A SAVE SKINS MODULE)
# ==============================================================================

static func get_gacha_tokens() -> int:
	return SaveSkinsModule.get_gacha_tokens(load_profile())

static func add_gacha_tokens(amount: int) -> int:
	var self_class = load("res://core/autoloads/save_manager.gd")
	return SaveSkinsModule.add_gacha_tokens(amount, self_class)

static func spend_gacha_tokens(amount: int) -> bool:
	var self_class = load("res://core/autoloads/save_manager.gd")
	return SaveSkinsModule.spend_gacha_tokens(amount, self_class)

static func get_unlocked_skins() -> Dictionary:
	return SaveSkinsModule.get_unlocked_skins(load_profile())

static func is_skin_unlocked(skin_id: String) -> bool:
	return SaveSkinsModule.is_skin_unlocked(skin_id, load_profile())

static func get_skin_stars(skin_id: String) -> int:
	return SaveSkinsModule.get_skin_stars(skin_id, load_profile())

static func unlock_or_upgrade_skin(skin_id: String) -> Dictionary:
	var self_class = load("res://core/autoloads/save_manager.gd")
	return SaveSkinsModule.unlock_or_upgrade_skin(skin_id, self_class)

static func equip_skin(slot_key: String, skin_id: String) -> void:
	var self_class = load("res://core/autoloads/save_manager.gd")
	SaveSkinsModule.equip_skin(slot_key, skin_id, self_class)

static func unequip_skin(slot_key: String) -> void:
	var self_class = load("res://core/autoloads/save_manager.gd")
	SaveSkinsModule.unequip_skin(slot_key, self_class)

static func get_equipped_skin(slot_key: String) -> String:
	return SaveSkinsModule.get_equipped_skin(slot_key, load_profile())

static func get_equipped_skins() -> Dictionary:
	return SaveSkinsModule.get_equipped_skins(load_profile())

static func set_gacha_tokens(amount: int) -> void:
	var self_class = load("res://core/autoloads/save_manager.gd")
	SaveSkinsModule.set_gacha_tokens(amount, self_class)

static func unlock_all_skins(star_level: int = 1) -> int:
	var self_class = load("res://core/autoloads/save_manager.gd")
	return SaveSkinsModule.unlock_all_skins(star_level, self_class)

static func lock_all_skins() -> void:
	var self_class = load("res://core/autoloads/save_manager.gd")
	SaveSkinsModule.lock_all_skins(self_class)

static func get_banner_pity(banner_id: String) -> int:
	return SaveSkinsModule.get_banner_pity(banner_id, load_profile())

static func increment_banner_pity(banner_id: String, amount: int) -> int:
	var self_class = load("res://core/autoloads/save_manager.gd")
	return SaveSkinsModule.increment_banner_pity(banner_id, amount, self_class)

static func reset_banner_pity(banner_id: String) -> void:
	var self_class = load("res://core/autoloads/save_manager.gd")
	SaveSkinsModule.reset_banner_pity(banner_id, self_class)

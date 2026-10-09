class_name ProfileSettingsData
extends RefCounted

## Schema DTO tipado para configuración de juego, trofeos y estadísticas de carrera del perfil.

const DEFAULT_TROPHIES: Dictionary = {
	"trophy_boss_aegis": 0,
	"trophy_biosphere_core": 0,
	"trophy_cryo_core": 0,
	"trophy_volcanic_core": 0,
	"trophy_monolith_master": 0
}

var game_speed: float = 1.0
var trophies_unlocked: Dictionary = DEFAULT_TROPHIES.duplicate()
var career_stats: Dictionary = get_default_career_stats()

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

static func create_default() -> RefCounted:
	var settings: RefCounted = (load("res://core/systems/persistence/schemas/profile_settings_data.gd") as GDScript).new()
	settings.game_speed = 1.0
	settings.trophies_unlocked = DEFAULT_TROPHIES.duplicate()
	settings.career_stats = get_default_career_stats()
	return settings

func populate_from_dict(raw: Dictionary) -> void:
	var speed: float = float(raw.get("game_speed", 1.0))
	game_speed = speed if speed > 0.0 else 1.0

	var trophies_clean: Dictionary = DEFAULT_TROPHIES.duplicate()
	if raw.has("trophies_unlocked") and raw["trophies_unlocked"] is Dictionary:
		var raw_trophies: Dictionary = raw["trophies_unlocked"]
		for t_id in raw_trophies.keys():
			trophies_clean[str(t_id)] = int(raw_trophies[t_id])
	trophies_unlocked = trophies_clean

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
	career_stats = career_clean

func to_dict() -> Dictionary:
	var trophies_serializable: Dictionary = {}
	for tid in trophies_unlocked.keys():
		trophies_serializable[str(tid)] = int(trophies_unlocked[tid])

	return {
		"game_speed": game_speed,
		"trophies_unlocked": trophies_serializable,
		"career_stats": career_stats.duplicate()
	}

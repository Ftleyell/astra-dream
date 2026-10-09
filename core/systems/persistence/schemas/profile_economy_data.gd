class_name ProfileEconomyData
extends RefCounted

## Schema DTO tipado para la economía y divisas de meta-progresión del perfil.

var biomass: int = 0
var antimatter: int = 0
var dark_matter: int = 0
var gacha_tokens: int = 0
var gacha_pity: Dictionary = {
	"general": 0,
	"ships": 0,
	"pilots": 0
}

static func create_default() -> RefCounted:
	var eco: RefCounted = (load("res://core/systems/persistence/schemas/profile_economy_data.gd") as GDScript).new()
	eco.biomass = 0
	eco.antimatter = 0
	eco.dark_matter = 0
	eco.gacha_tokens = 0
	eco.gacha_pity = {
		"general": 0,
		"ships": 0,
		"pilots": 0
	}
	return eco

func populate_from_dict(raw: Dictionary) -> void:
	biomass = int(raw.get("biomass", 0))
	antimatter = int(raw.get("antimatter", 0))
	dark_matter = int(raw.get("dark_matter", 0))
	gacha_tokens = int(raw.get("gacha_tokens", 0))
	
	var raw_pity: Dictionary = raw.get("gacha_pity", {}) if raw.get("gacha_pity") is Dictionary else {}
	gacha_pity = {
		"general": int(raw_pity.get("general", 0)),
		"ships": int(raw_pity.get("ships", 0)),
		"pilots": int(raw_pity.get("pilots", 0))
	}

func to_dict() -> Dictionary:
	return {
		"biomass": biomass,
		"antimatter": antimatter,
		"dark_matter": dark_matter,
		"gacha_tokens": gacha_tokens,
		"gacha_pity": {
			"general": int(gacha_pity.get("general", 0)),
			"ships": int(gacha_pity.get("ships", 0)),
			"pilots": int(gacha_pity.get("pilots", 0))
		}
	}

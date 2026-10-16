class_name GachaBannerEngine
extends RefCounted

## GachaBannerEngine.gd
## Motor probabilístico puro y configuración de banners para el sistema Gacha:
## - Reglas de Pity y garantías de rareza (Épico en pull 10).
## - Filtrado determinista de pools por banner temático.
## - Desacoplado de persistencia de guardado y de rendering visual de cúpula.

const PITY_THRESHOLD: int = 10
const DEFAULT_EPIC_RATE: float = 0.15
const DEFAULT_RARE_RATE: float = 0.35

const BANNERS_CONFIG := {
	"general": {
		"title": "🌌 BANNER ESTELAR GENERAL",
		"desc": "Todo el repertorio del cosmos: naves, pilotos, armas y mascotas con 15% de épico.",
		"color": Color(0.0, 0.94, 1.0, 1.0),
		"featured_badge": "★ POOL COMPLETO"
	},
	"ships": {
		"title": "🚀 HANGAR DE NAVES Y ARMAS",
		"desc": "Especialización táctica. Mayor probabilidad de skins para naves de asalto y armamento.",
		"color": Color(1.0, 0.5, 0.1, 1.0),
		"featured_badge": "★ TÁCTICO NAVAL"
	},
	"pilots": {
		"title": "👩‍✈️ ACADEMIA DE PILOTOS Y TRAJES",
		"desc": "Uniformes, trajes de combate y aspectos para tus heroínas y navegantes estelares.",
		"color": Color(1.0, 0.25, 0.7, 1.0),
		"featured_badge": "★ HEROÍNAS VIP"
	}
}

static func get_banner_config(banner_id: String) -> Dictionary:
	return BANNERS_CONFIG.get(banner_id, BANNERS_CONFIG["general"])

static func get_available_banner_ids() -> Array[String]:
	var ids: Array[String] = []
	for k: String in BANNERS_CONFIG.keys():
		ids.append(k)
	return ids

static func is_pity_triggered(current_pity: int) -> bool:
	return (current_pity + 1 >= PITY_THRESHOLD)

static func determine_rarity(roll_val: float, is_pity: bool, epic_rate: float = DEFAULT_EPIC_RATE, rare_rate: float = DEFAULT_RARE_RATE) -> String:
	if is_pity or roll_val < epic_rate:
		return "epic"
	if roll_val < (epic_rate + rare_rate):
		return "rare"
	return "common"

static func filter_skins_for_banner(all_skins: Dictionary, banner_id: String) -> Array[Dictionary]:
	var filtered: Array[Dictionary] = []
	for sid: String in all_skins.keys():
		var s: Dictionary = all_skins[sid]
		var cat: String = s.get("category", "")
		match banner_id:
			"ships":
				if cat == "ship" or cat == "weapon":
					filtered.append(s)
			"pilots":
				if cat == "pilot" or cat == "navigator":
					filtered.append(s)
			_:
				filtered.append(s)
	return filtered

static func resolve_pull(
	_banner_id: String,
	current_pity: int,
	available_skins: Array[Dictionary],
	forced_roll: float = -1.0
) -> Dictionary:
	if available_skins.is_empty():
		return {}

	var is_pity: bool = is_pity_triggered(current_pity)
	var roll_val: float = forced_roll if forced_roll >= 0.0 else randf()
	var rarity_target: String = determine_rarity(roll_val, is_pity)

	var epic_pool: Array[Dictionary] = []
	var rare_pool: Array[Dictionary] = []
	var common_pool: Array[Dictionary] = []
	for s: Dictionary in available_skins:
		var r: String = str(s.get("rarity", "common"))
		if r == "epic":
			epic_pool.append(s)
		elif r == "rare":
			rare_pool.append(s)
		else:
			common_pool.append(s)

	var chosen: Dictionary = {}
	if rarity_target == "epic":
		if not epic_pool.is_empty():
			chosen = epic_pool[randi() % epic_pool.size()]
		elif not rare_pool.is_empty():
			chosen = rare_pool[randi() % rare_pool.size()]
	elif rarity_target == "rare":
		if not rare_pool.is_empty():
			chosen = rare_pool[randi() % rare_pool.size()]
		elif not common_pool.is_empty():
			chosen = common_pool[randi() % common_pool.size()]
	else:
		if not common_pool.is_empty():
			chosen = common_pool[randi() % common_pool.size()]

	if chosen.is_empty():
		chosen = available_skins[randi() % available_skins.size()]

	var outcome_is_epic: bool = is_pity or str(chosen.get("rarity", "")) == "epic"
	var next_pity: int = 0 if outcome_is_epic else (current_pity + 1)

	return {
		"skin": chosen,
		"is_pity": is_pity,
		"rarity": chosen.get("rarity", "common"),
		"new_pity": next_pity
	}

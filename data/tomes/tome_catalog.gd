class_name TomeCatalog
extends RefCounted

const TomeDataScript = preload("res://data/tomes/tome_data.gd")
const TOMES_DIR: String = "res://data/tomes"

const ALL_TOME_IDS: Array[StringName] = [
	&"tome_base_damage",
	&"tome_attack_speed",
	&"tome_crit_chance",
	&"tome_crit_damage",
	&"tome_cooldown_reduction",
	&"tome_projectile_speed",
	&"tome_weapon_size",
	&"tome_projectile_count",
	&"tome_move_speed",
	&"tome_max_health",
	&"tome_health_regen",
	&"tome_armor",
	&"tome_pickup_radius",
	&"tome_luck",
	&"tome_exp_multiplier",
	&"tome_credits_multiplier",
	&"tome_biomass_multiplier",
	&"tome_curse",
]

static var _cached_tomes: Dictionary[StringName, TomeDataScript] = {}

static func load_tome(tome_id: StringName) -> TomeDataScript:
	if _cached_tomes.has(tome_id):
		return _cached_tomes[tome_id]
	var path: String = "%s/%s.tres" % [TOMES_DIR, str(tome_id)]
	if ResourceLoader.exists(path):
		var res: TomeDataScript = load(path) as TomeDataScript
		if res:
			_cached_tomes[tome_id] = res
			return res
	return null

static func get_all_tomes() -> Array[TomeDataScript]:
	var result: Array[TomeDataScript] = []
	for id: StringName in ALL_TOME_IDS:
		var tome: TomeDataScript = load_tome(id)
		if tome:
			result.append(tome)
	return result

static func get_tome_for_stat(stat_name: StringName) -> TomeDataScript:
	for id: StringName in ALL_TOME_IDS:
		var tome: TomeDataScript = load_tome(id)
		if tome and tome.stat_name == stat_name:
			return tome
	return null

class_name WeaponCatalog
extends RefCounted

const WEAPON_PATHS: Array[String] = [
	"res://data/weapons/roster/crescent_blade.tres",
	"res://data/weapons/roster/hive_cannon.tres",
	"res://data/weapons/roster/plasma_flak.tres",
	"res://data/weapons/roster/rail_launcher.tres",
	"res://data/weapons/roster/scatter_laser.tres",
	"res://data/weapons/roster/singularity_cannon.tres",
	"res://data/weapons/roster/singularity_pulsar.tres",
	"res://data/weapons/roster/sniper_rifle.tres",
	"res://data/weapons/roster/solar_flare.tres",
	"res://data/weapons/roster/swarm_missiles.tres",
	"res://data/weapons/roster/tachyon_beam.tres",
	"res://data/weapons/roster/tesla_arc.tres",
	"res://data/weapons/roster/titan_shotgun.tres",
	"res://data/weapons/roster/void_siphon.tres",
	"res://data/weapons/shop/cluster_submunition.tres",
	"res://data/weapons/shop/dimensional_blade.tres",
	"res://data/weapons/shop/nova_flak.tres",
	"res://data/weapons/shop/solar_beam.tres"
]

const PILOT_STARTING_WEAPON_IDS: Array[StringName] = [
	&"crescent_blade",
	&"hive_cannon",
	&"rail_launcher",
	&"singularity_pulsar",
	&"sniper_rifle",
	&"tesla_arc",
	&"titan_shotgun"
]

const POOL_WEAPON_IDS: Array[StringName] = [
	&"plasma_flak",
	&"scatter_laser",
	&"singularity_cannon",
	&"solar_flare",
	&"swarm_missiles",
	&"tachyon_beam",
	&"void_siphon",
	&"cluster_submunition",
	&"dimensional_blade",
	&"nova_flak",
	&"solar_beam"
]

static var _cached_weapons: Dictionary[StringName, WeaponData] = {}

static func get_pool_weapons() -> Array[WeaponData]:
	var result: Array[WeaponData] = []
	for wid: StringName in POOL_WEAPON_IDS:
		var w: WeaponData = get_weapon_by_id(wid)
		if w:
			result.append(w)
	return result

static func get_all_weapons() -> Array[WeaponData]:
	var result: Array[WeaponData] = []
	for p: String in WEAPON_PATHS:
		var w: WeaponData = load_weapon(p)
		if w:
			result.append(w)
	return result

static func load_weapon(path: String) -> WeaponData:
	if ResourceLoader.exists(path):
		var w: WeaponData = load(path) as WeaponData
		return w
	return null

static func get_weapon_by_id(weapon_id: StringName) -> WeaponData:
	if _cached_weapons.has(weapon_id):
		return _cached_weapons[weapon_id]
	for p: String in WEAPON_PATHS:
		var w: WeaponData = load_weapon(p)
		if w and w.weapon_id == weapon_id:
			_cached_weapons[weapon_id] = w
			return w
	return null

class_name CharacterData
extends Resource

@export_group("Identity")
@export var character_id: StringName = &"survivor_default"
@export var display_name: String = "Heroína Base"
@export var title: String = ""
@export_multiline var description: String = "Descripción del personaje."
@export var portrait_icon: Texture2D
@export var color: Color = Color.WHITE
@export var pts: PackedVector2Array = PackedVector2Array()
@export var sort_order: int = 0
@export var stats_summary: String = ""

@export_group("Visuals")
@export var ship_sprite: Texture2D
@export var fullbody_sprite: Texture2D
@export var weapon_sprite: Texture2D

@export_group("Base Attributes")
@export var max_health: float = 100.0
@export var health_regen: float = 0.5
@export var move_speed: float = 320.0
@export var armor: float = 0.0
@export var base_damage: float = 10.0
@export var attack_speed: float = 1.0
@export var crit_chance: float = 0.05
@export var crit_damage: float = 1.5
@export var luck: float = 1.0
@export var pickup_radius: float = 100.0
@export var projectile_count: float = 2.0
@export var projectile_speed: float = 1.0
@export var weapon_size: float = 1.0
@export var cooldown_reduction: float = 0.0
@export var exp_multiplier: float = 1.0

@export_group("Loadout")
@export var starting_weapon: WeaponData

@export_group("Megabonk Banlist Constraints")
@export var banned_tags: Array[StringName] = []
@export var inherent_item_banlist: Array[StringName] = []

# Accessor properties
var theme_color: Color:
	get:
		return color
	set(val):
		color = val

var silhouette_points: PackedVector2Array:
	get:
		return pts
	set(val):
		pts = val

var portrait_texture: Texture2D:
	get:
		return portrait_icon
	set(val):
		portrait_icon = val

func get_theme_color() -> Color:
	return color

func get_silhouette_points() -> PackedVector2Array:
	return pts

func get_portrait_texture() -> Texture2D:
	if portrait_icon:
		return portrait_icon
	var path := "res://assets/characters/portraits/portrait_%s.png" % str(character_id).to_lower()
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	var path_legacy := "res://assets/portraits/portrait_%s.png" % str(character_id).to_lower()
	if ResourceLoader.exists(path_legacy):
		return load(path_legacy) as Texture2D
	return null

func get_ship_texture() -> Texture2D:
	if ship_sprite:
		return ship_sprite
	var path := "res://assets/characters/ships/ship_%s.png" % str(character_id).to_lower()
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null

func get_fullbody_texture() -> Texture2D:
	if fullbody_sprite:
		return fullbody_sprite
	var path := "res://assets/characters/fullbody/fullbody_%s.png" % str(character_id).to_lower()
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null

func get_weapon_texture() -> Texture2D:
	if weapon_sprite:
		return weapon_sprite
	var path := "res://assets/characters/weapons/weapon_%s.png" % str(character_id).to_lower()
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null

func get_formatted_stats() -> String:
	if not stats_summary.is_empty():
		return stats_summary
	return "HP: %d | Vel: %d px/s | Daño: %d | Crítico: %d%% | Suerte: %+d" % [
		int(max_health),
		int(move_speed),
		int(base_damage),
		int(crit_chance * 100.0),
		int(luck)
	]

# Static roster loaders
static func load_roster() -> Dictionary[StringName, CharacterData]:
	var roster: Dictionary[StringName, CharacterData] = {}
	var roster_dir := "res://data/characters/roster/"
	
	if DirAccess.dir_exists_absolute(roster_dir):
		var dir := DirAccess.open(roster_dir)
		if dir:
			dir.list_dir_begin()
			var file_name := dir.get_next()
			while file_name != "":
				if not dir.current_is_dir() and (file_name.ends_with(".tres") or file_name.ends_with(".tres.remap")):
					var clean_name := file_name.trim_suffix(".remap")
					var res_path := roster_dir + clean_name
					if ResourceLoader.exists(res_path):
						var res = load(res_path)
						if res is CharacterData:
							var cd: CharacterData = res
							roster[cd.character_id] = cd
				file_name = dir.get_next()
			dir.list_dir_end()
	
	# Canonical fallback to ensure all 6 pilots are loaded
	var canonical_ids: Array[StringName] = [&"nova", &"valentina", &"kira", &"selene", &"roxy", &"echo"]
	for cid in canonical_ids:
		if not roster.has(cid):
			var fallback_path := "%s%s.tres" % [roster_dir, str(cid)]
			if ResourceLoader.exists(fallback_path):
				var res = load(fallback_path)
				if res is CharacterData:
					roster[cid] = res as CharacterData

	return roster

static func load_roster_ordered() -> Array[CharacterData]:
	var dict := load_roster()
	var list: Array[CharacterData] = []
	for k in dict.keys():
		var cd: CharacterData = dict[k]
		if cd:
			list.append(cd)
	list.sort_custom(func(a: CharacterData, b: CharacterData) -> bool:
		return a.sort_order < b.sort_order
	)
	return list

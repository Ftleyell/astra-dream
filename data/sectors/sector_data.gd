class_name SectorData
extends Resource

## Definición Data-Driven de un Sector Estelar para Astra Dream.
## Controla la identidad, ambientación de SpaceBackground, modificadores de combate/loot,
## asignación de piloto rival para intercepción y recompensas del cofre estelar.

@export_group("Identity")
@export var sector_id: StringName = &"sector_nebula_outskirts"
@export var display_name: String = "Periferia Nebular de Orión"
@export var title: String = "Sector de Patrulla Inicial"
@export_multiline var description: String = "Borde exterior de la galaxia. Densidad controlada de cazas y condiciones estables para pruebas de combate."
@export var sort_order: int = 0
@export var is_unlocked_by_default: bool = true

@export_group("Visuals & Atmosphere")
## Modulación de color para la capa Nebula en SpaceBackground
@export var nebula_tint: Color = Color(0.2, 0.7, 1.0, 1.0)
## Modulación de color para la capa de estrellas profundas
@export var stars_deep_tint: Color = Color(0.85, 0.9, 1.0, 1.0)
## Modulación de color para la capa de estrellas medias
@export var stars_mid_tint: Color = Color(0.9, 0.95, 1.0, 1.0)
## Modulación de color para el polvo espacial cercano
@export var dust_near_tint: Color = Color(0.5, 0.8, 1.0, 0.7)
## Textura opcional para sobreescribir la nebulosa base
@export var nebula_texture: Texture2D = null
## Dirección normalizada del drift cósmico
@export var drift_direction: Vector2 = Vector2(-1.0, -0.5)
## Velocidad base del drift de fondo (px/s)
@export var drift_speed: float = 16.0
## Color cromático distintivo para la interfaz de Starchart, bordes y radar
@export var theme_color: Color = Color(0.1, 0.85, 1.0, 1.0)
## Icono o miniatura representativa para tarjetas de UI
@export var icon_texture: Texture2D = null

@export_group("Combat & Loot Modifiers")
## Multiplicador de densidad y tope de enemigos simultáneos (EnemySpawner)
@export var enemy_density_mult: float = 1.0
## Multiplicador de salud base para enemigos
@export var enemy_health_mult: float = 1.0
## Multiplicador de daño infligido por enemigos
@export var enemy_damage_mult: float = 1.0
## Multiplicador de obtención de BioMasa
@export var biomass_mult: float = 1.0
## Multiplicador de obtención de Materia Oscura
@export var dark_matter_mult: float = 1.0
## Multiplicador de obtención de Créditos de combate
@export var credits_mult: float = 1.0
## Multiplicador de probabilidad de aparición de Arcanas
@export var arcana_chance_mult: float = 1.0

@export_group("Rival Pilot Encounter")
## Piloto rival asignado que interceptará la run en este sector
@export var rival_pilot_id: StringName = &"nova"
## Piloto rival de respaldo si el jugador juega con rival_pilot_id (evita mirror match)
@export var secondary_rival_pilot_id: StringName = &"valentina"
## Oleada en la que se programa el evento de intercepción del rival
@export var rival_encounter_wave: int = 1
## Mensaje de advertencia táctica en la alarma de intercepción
@export var rival_warning_subtitle: String = "Firma enemiga interceptada patrullando el perímetro de este sector."

@export_group("Stellar Rewards")
## BioMasa entregada al abrir el Cofre Estelar de Rival
@export var reward_biomass: int = 50
## Materia Oscura entregada al abrir el Cofre Estelar de Rival
@export var reward_dark_matter: int = 25
## Antimateria permanente otorgada al derrotar al rival de sector
@export var reward_antimatter: int = 10
## Si garantiza el drop de un orbe de Arcana en el cofre
@export var guaranteed_arcana_drop: bool = true

# ==============================================================================
# BACKWARD COMPATIBILITY GETTERS / ALIASES
# ==============================================================================
func _get(property: StringName) -> Variant:
	match property:
		&"id":
			return sector_id
		&"sector_name":
			return display_name
		&"enemy_density":
			return enemy_density_mult
		&"loot_multipliers":
			return {
				"biomass": biomass_mult,
				"credits": credits_mult,
				"dark_matter": dark_matter_mult,
				"arcana": arcana_chance_mult
			}
	return null

func _set(property: StringName, value: Variant) -> bool:
	match property:
		&"id":
			sector_id = StringName(value)
			return true
		&"sector_name":
			display_name = str(value)
			return true
		&"enemy_density":
			enemy_density_mult = float(value)
			return true
	return false

# ==============================================================================
# CATALOG & CACHE SYSTEM
# ==============================================================================
const CATALOG_DIR := "res://data/sectors/"
const CANONICAL_SECTOR_IDS: Array[StringName] = [
	&"sector_nebula_outskirts",
	&"sector_void_abyss",
	&"sector_plasma_storm",
	&"sector_singularity_core"
]

static var _cached_sectors: Dictionary = {}

static func load_catalog() -> Dictionary:
	var catalog: Dictionary = {}
	var ordered := load_catalog_ordered()
	for sec in ordered:
		if sec and sec.sector_id:
			catalog[sec.sector_id] = sec
	return catalog

static func load_catalog_ordered() -> Array[SectorData]:
	var list: Array[SectorData] = []
	var loaded_ids: Dictionary = {}

	if DirAccess.dir_exists_absolute(CATALOG_DIR):
		var da := DirAccess.open(CATALOG_DIR)
		if da:
			da.list_dir_begin()
			var fname := da.get_next()
			while not fname.is_empty():
				if not da.current_is_dir() and (fname.ends_with(".tres") or fname.ends_with(".tres.remap") or fname.ends_with(".res") or fname.ends_with(".res.remap")):
					var clean_name := fname.trim_suffix(".remap")
					var res_path := CATALOG_DIR.path_join(clean_name)
					if ResourceLoader.exists(res_path):
						var res = load(res_path)
						if res is SectorData:
							var sd: SectorData = res
							if not loaded_ids.has(sd.sector_id):
								loaded_ids[sd.sector_id] = true
								list.append(sd)
				fname = da.get_next()
			da.list_dir_end()

	# Canonical fallback to guarantee all 4 base sectors load even if directory scan is filtered
	for sid in CANONICAL_SECTOR_IDS:
		if not loaded_ids.has(sid):
			var direct_path := "%s/%s.tres" % [CATALOG_DIR, str(sid)]
			if ResourceLoader.exists(direct_path):
				var res = load(direct_path)
				if res is SectorData:
					var sd: SectorData = res
					loaded_ids[sd.sector_id] = true
					list.append(sd)

	list.sort_custom(func(a: SectorData, b: SectorData) -> bool:
		return a.sort_order < b.sort_order
	)
	return list

static func load_all_sectors() -> Array[SectorData]:
	return load_catalog_ordered()

static func get_sector(id: StringName) -> SectorData:
	if _cached_sectors.has(id) and _cached_sectors[id] != null:
		return _cached_sectors[id]

	var direct_path := "%s/%s.tres" % [CATALOG_DIR, str(id)]
	if ResourceLoader.exists(direct_path):
		var res = load(direct_path)
		if res is SectorData:
			_cached_sectors[id] = res
			return res

	var catalog := load_catalog()
	if catalog.has(id):
		_cached_sectors[id] = catalog[id]
		return catalog[id]
	elif not catalog.is_empty():
		return catalog.values()[0]
	return null

static func get_default_sector() -> SectorData:
	return get_sector(&"sector_nebula_outskirts")

# ==============================================================================
# INSTANCE HELPER METHODS
# ==============================================================================
func get_effective_drift_direction() -> Vector2:
	if drift_direction.length_squared() > 0.0001:
		return drift_direction.normalized()
	return Vector2(-1.0, -0.5).normalized()

func get_formatted_modifiers() -> String:
	return "Densidad: %d%% | BioMasa: %d%% | M. Oscura: %d%% | Créditos: %d%% | Arcanas: %d%%" % [
		int(enemy_density_mult * 100.0),
		int(biomass_mult * 100.0),
		int(dark_matter_mult * 100.0),
		int(credits_mult * 100.0),
		int(arcana_chance_mult * 100.0)
	]

func get_assigned_rival(player_char_id: StringName) -> StringName:
	if player_char_id == rival_pilot_id:
		return secondary_rival_pilot_id if secondary_rival_pilot_id != &"" else &"nyx"
	return rival_pilot_id

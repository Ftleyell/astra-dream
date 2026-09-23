class_name ArcanaData
extends Resource

## ArcanaData.gd
## Recurso de datos para las 24 Arcanas (Pactos de Alto Riesgo / Recompensa).
## Estructura extensible para los 4 cuadrantes tácticos:
## - "glass_cannon": Cañón de Cristal & Sangre
## - "danmaku_chaos": Danmaku & Caos Balístico
## - "spacetime": Espacio-Tiempo & Evasión
## - "greed": Pacto de Avaricia & Sobrecarga

@export var id: String = ""
@export var name: String = ""
@export_multiline var description_boon: String = ""
@export_multiline var description_curse: String = ""
@export_enum("glass_cannon", "danmaku_chaos", "spacetime", "greed") var quadrant: String = "glass_cannon"
@export var icon: Texture2D = null
@export var color_accent: Color = Color(0.1, 0.8, 1.0, 1.0)
@export var stat_modifiers: Dictionary = {}
@export var custom_tags: PackedStringArray = []


func get_quadrant_title() -> String:
	match quadrant:
		"glass_cannon":
			return "Cañón de Cristal & Sangre"
		"danmaku_chaos":
			return "Danmaku & Caos Balístico"
		"spacetime":
			return "Espacio-Tiempo & Evasión"
		"greed":
			return "Pacto de Avaricia & Sobrecarga"
		_:
			return "Pacto Desconocido"


func get_summary_text() -> String:
	return "[color=#55ff55]+ %s[/color]\n[color=#ff5555]- %s[/color]" % [description_boon, description_curse]


# ==============================================================================
# CARGADORES ESTÁTICOS DEL CATÁLOGO DE ARCANAS
# ==============================================================================

static var _cached_roster: Dictionary = {}

static func load_all_arcanas() -> Dictionary:
	if not _cached_roster.is_empty():
		return _cached_roster

	var roster: Dictionary = {}
	var roster_dir := "res://data/arcanas/roster/"

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
						if res is ArcanaData and not (res as ArcanaData).id.is_empty():
							roster[(res as ArcanaData).id] = res
				file_name = dir.get_next()
			dir.list_dir_end()

	# Fallback canónico si algún archivo no se listó directamente
	var canonical_ids: Array[String] = [
		# Cuadrante 1: Cañón de Cristal & Sangre
		"blood_pact", "agonic_fury", "vampiric_drain", "shield_sacrifice", "core_thirst", "last_breath",
		# Cuadrante 2: Danmaku & Caos Balístico
		"shrapnel_rain", "colossal_projectile", "unstable_fission", "quantum_ricochet", "heavy_ballistics", "danmaku_mirror",
		# Cuadrante 3: Espacio-Tiempo & Evasión
		"dimensional_leap", "gravitational_vortex", "time_dilation", "phantom_evasion", "warp_engine", "phase_flicker",
		# Cuadrante 4: Pacto de Avaricia & Sobrecarga
		"voracious_harvest", "midas_alchemy", "black_market", "magnet_overload", "high_risk_investment", "extraction_aura"
	]

	for arc_id in canonical_ids:
		if not roster.has(arc_id):
			var fallback_path := "%s%s.tres" % [roster_dir, arc_id]
			if ResourceLoader.exists(fallback_path):
				var res = load(fallback_path)
				if res is ArcanaData:
					roster[arc_id] = res

	_cached_roster = roster
	return roster


static func get_arcana(arcana_id: String) -> ArcanaData:
	var catalog := load_all_arcanas()
	return catalog.get(arcana_id, null) as ArcanaData


static func get_random_selection(count: int = 3, exclude_ids: Array = []) -> Array[ArcanaData]:
	var catalog := load_all_arcanas()
	var candidates: Array[ArcanaData] = []
	for k in catalog.keys():
		if not exclude_ids.has(k):
			var data: ArcanaData = catalog[k]
			if data:
				candidates.append(data)

	candidates.shuffle()

	var result: Array[ArcanaData] = []
	var take_count: int = mini(count, candidates.size())
	for i in range(take_count):
		result.append(candidates[i])

	return result

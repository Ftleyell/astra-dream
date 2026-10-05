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
@export var biomass_multiplier: float = 1.0
@export var credits_multiplier: float = 1.0
@export var curse: float = 0.0

@export_group("Loadout")
@export var starting_weapon: WeaponData

@export_group("Kit Dossier")
@export var weapon_archetype: String = ""
@export_multiline var weapon_description: String = ""
@export var tactical_ability_name: String = ""
@export_multiline var tactical_ability_description: String = ""
@export var dash_ability_name: String = ""
@export_multiline var dash_ability_description: String = ""
@export var innate_passive_name: String = ""
@export_multiline var innate_passive_description: String = ""
@export var favored_tome_id: StringName = &""

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

func get_portrait_texture(flipped: bool = false) -> Texture2D:
	if flipped:
		var path_flip := "res://assets/characters/portraits/portrait_%s_flipped.png" % str(character_id).to_lower()
		if ResourceLoader.exists(path_flip):
			return load(path_flip) as Texture2D
		var path_flip_legacy := "res://assets/portraits/portrait_%s_flipped.png" % str(character_id).to_lower()
		if ResourceLoader.exists(path_flip_legacy):
			return load(path_flip_legacy) as Texture2D
	if portrait_icon:
		return portrait_icon
	var path := "res://assets/characters/portraits/portrait_%s.png" % str(character_id).to_lower()
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	var path_legacy := "res://assets/portraits/portrait_%s.png" % str(character_id).to_lower()
	if ResourceLoader.exists(path_legacy):
		return load(path_legacy) as Texture2D
	return null

func get_avatar_texture() -> Texture2D:
	var path := "res://assets/portraits/avatars/avatar_%s.png" % str(character_id).to_lower()
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return get_portrait_texture()


func get_ship_texture() -> Texture2D:
	if ship_sprite:
		return ship_sprite
	var path := "res://assets/characters/ships/ship_%s.png" % str(character_id).to_lower()
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null

func get_fullbody_texture(flipped: bool = false) -> Texture2D:
	if flipped:
		var path_flip := "res://assets/characters/fullbody/fullbody_%s_flipped.png" % str(character_id).to_lower()
		if ResourceLoader.exists(path_flip):
			return load(path_flip) as Texture2D
	if fullbody_sprite:
		return fullbody_sprite
	var path := "res://assets/characters/fullbody/fullbody_%s.png" % str(character_id).to_lower()
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null

func get_selection_texture(flipped: bool = false) -> Texture2D:
	if flipped:
		var path_flip := "res://assets/characters/selection/selection_%s_flipped.png" % str(character_id).to_lower()
		if ResourceLoader.exists(path_flip):
			return load(path_flip) as Texture2D
	var path := "res://assets/characters/selection/selection_%s.png" % str(character_id).to_lower()
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return get_fullbody_texture(flipped)

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

func get_kit_dossier() -> Dictionary:
	var dossier: Dictionary = {
		"weapon_name": weapon_archetype,
		"weapon_desc": weapon_description,
		"tactical_name": tactical_ability_name,
		"tactical_desc": tactical_ability_description,
		"dash_name": dash_ability_name,
		"dash_desc": dash_ability_description,
		"passive_name": innate_passive_name,
		"passive_desc": innate_passive_description,
		"favored_tome": favored_tome_id
	}

	if String(dossier.weapon_name).is_empty():
		match character_id:
			&"nova":
				dossier.weapon_name = "Riel Magnético Dual"
				dossier.weapon_desc = "Proyectiles balísticos gemelos de alta cadencia y penetración cinética frontal."
				dossier.tactical_name = "Láser Focalizado de Vanguardia"
				dossier.tactical_desc = "Haz continuo que acelera su tiempo de carga con la velocidad de movimiento (hasta 1.2s)."
				dossier.dash_name = "Omega Spin"
				dossier.dash_desc = "Giro evasivo de 360° que aniquila proyectiles hostiles e inflige corte radial limpio."
				dossier.passive_name = "Sobrecarga de Vanguardia"
				dossier.passive_desc = "Favorece Tomo de Velocidad: cada +10% de velocidad otorga +6% de Daño a quemarropa (<120px)."
				dossier.favored_tome = &"tome_move_speed"
			&"valentina":
				dossier.weapon_name = "Cañón Francotirador Perforante"
				dossier.weapon_desc = "Disparos hipersónicos de largo alcance con penetración lineal y telemetría crítica."
				dossier.tactical_name = "Matriz de Puntería Óptica"
				dossier.tactical_desc = "Enfoca una retícula balística de alta precisión para impactos letales telegrafiados."
				dossier.dash_name = "Repliegue Táctico"
				dossier.dash_desc = "Impulso vectorial hacia atrás que incrementa la velocidad de proyectiles subsecuentes."
				dossier.passive_name = "Balística de Alta Celeridad"
				dossier.passive_desc = "Favorece Tomo de Velocidad de Proyectil: cada +10% de velocidad otorga +8% de Daño Crítico."
				dossier.favored_tome = &"tome_projectile_speed"
			&"roxy":
				dossier.weapon_name = "Escopeta de Dispersión Titánica"
				dossier.weapon_desc = "Descarga de perdigones de plasma masivo con alto retroceso y metralla pesada."
				dossier.tactical_name = "Barrera de Choque Térmico"
				dossier.tactical_desc = "Sobrecarga frontal de escudos que repele proyectiles hostiles y absorbe impactos."
				dossier.dash_name = "Embestida Blindada"
				dossier.dash_desc = "Carga pesada a través de formaciones enemigas infligiendo aturdimiento e inmunidad breve."
				dossier.passive_name = "Coraza Balística Pesada"
				dossier.passive_desc = "Favorece Tomo de Armadura: cada punto de armadura otorga +7% de Daño de Escopeta."
				dossier.favored_tome = &"tome_armor"
			&"selene":
				dossier.weapon_name = "Sifón Gravitatorio de Vacío"
				dossier.weapon_desc = "Vórtices singulares que colapsan y atraen cúmulos estelares de materia oscura."
				dossier.tactical_name = "Micro-Horizonte de Sucesos"
				dossier.tactical_desc = "Invoca un pozo gravitatorio estático que comprime enemigos y absorbe disparos."
				dossier.dash_name = "Pliegue Espacial"
				dossier.dash_desc = "Teletransporte cuántico que distorsiona el tejido del vacío evitando colisiones."
				dossier.passive_name = "Atracción Singular"
				dossier.passive_desc = "Favorece Tomo de Radio de Recolección: cada +20px de imán otorga +10% de Tamaño de Arma."
				dossier.favored_tome = &"tome_pickup_radius"
			&"nyx":
				dossier.weapon_name = "Hojas de Fractura Dimensional"
				dossier.weapon_desc = "Cortes hiper-densos de corto alcance que rasgan el espacio e ignoran corazas."
				dossier.tactical_name = "Desfase Abisal"
				dossier.tactical_desc = "Fase temporal de intangibilidad absoluta para reposicionamiento crítico en combate."
				dossier.dash_name = "Paso de Sombras"
				dossier.dash_desc = "Corte dimensional instantáneo en línea recta ejecutando enemigos vulnerables."
				dossier.passive_name = "Pacto de Sangre y Cenizas"
				dossier.passive_desc = "Favorece Tomo de Maldición: cada punto de Maldición otorga +12% de Daño Melee."
				dossier.favored_tome = &"tome_curse"
			&"echo":
				dossier.weapon_name = "Bobina Tesla Voltaica"
				dossier.weapon_desc = "Arcos voltaicos continuos que encadenan descargas eléctricas entre blancos múltiples."
				dossier.tactical_name = "Pulso EMP Sistémico"
				dossier.tactical_desc = "Sobrecarga electromagnética que neutraliza proyectiles cercanos y sobrecalienta escudos."
				dossier.dash_name = "Destello Cibernético"
				dossier.dash_desc = "Desplazamiento eléctrico ultrarrápido que deja terminales de inducción sobre el campo."
				dossier.passive_name = "Bucle de Frecuencia Acelerada"
				dossier.passive_desc = "Favorece Tomo de Enfriamiento: cada -5% de enfriamiento añade +1 arco eléctrico adicional."
				dossier.favored_tome = &"tome_cooldown_reduction"
			&"kira":
				dossier.weapon_name = "Enjambre Biomórfico"
				dossier.weapon_desc = "Micro-misiles orgánicos teledirigidos con seguimiento adaptativo de objetivos."
				dossier.tactical_name = "Colmena de Nanobots"
				dossier.tactical_desc = "Siembra un enjambre autónomo devorador de bio-materia que ralentiza enemigos."
				dossier.dash_name = "Desprendimiento Celular"
				dossier.dash_desc = "Impulso orgánico con señuelos de bio-materia que desorientan el fuego enemigo."
				dossier.passive_name = "Replicación Azarosa"
				dossier.passive_desc = "Favorece Tomo de Suerte: cada +5 puntos de Suerte añade probabilidad de duplicar la salva."
				dossier.favored_tome = &"tome_luck"
			_:
				dossier.weapon_name = starting_weapon.weapon_name if starting_weapon else "Arma Estándar"
				dossier.weapon_desc = starting_weapon.description if starting_weapon else "Armamento balístico estándar de combate."
				dossier.tactical_name = "Módulo Táctico"
				dossier.tactical_desc = "Sistema de apoyo auxiliar de combate."
				dossier.dash_name = "Propulsión Evasiva"
				dossier.dash_desc = "Impulso vectorial con micro-invulnerabilidad."
				dossier.passive_name = "Afinidad Táctica"
				dossier.passive_desc = "Sinergia estándar de combate espacial."
				dossier.favored_tome = &"tome_base_damage"
	return dossier

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
	
	# Canonical fallback to ensure all pilots are loaded
	var canonical_ids: Array[StringName] = [&"nova", &"valentina", &"kira", &"selene", &"roxy", &"echo", &"nyx"]
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

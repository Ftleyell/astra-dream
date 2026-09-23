extends SceneTree

const ArcanaDataScript = preload("res://data/arcanas/arcana_data.gd")

func _init() -> void:
	print("--- GENERATING 24 ARCANA RESOURCES ---")
	var target_dir := "res://data/arcanas/roster/"
	if not DirAccess.dir_exists_absolute(target_dir):
		DirAccess.make_dir_recursive_absolute(target_dir)

	var arcanas_spec: Array[Dictionary] = [
		# CUADRANTE 1: Cañón de Cristal & Sangre
		{
			"id": "blood_pact",
			"name": "Pacto de Sangre",
			"boon": "+60% Daño base a todas las armas",
			"curse": "-35% Vida máxima del chasis",
			"quadrant": "glass_cannon",
			"accent": Color(1.0, 0.15, 0.25, 1.0),
			"mods": {"base_damage_pct": 0.60, "max_health_pct": -0.35},
			"icon": "res://assets/icons/items/icon_sword.svg"
		},
		{
			"id": "agonic_fury",
			"name": "Furia Agónica",
			"boon": "+50% Cadencia de disparo ultra-rápida",
			"curse": "-50% Regeneración de salud por segundo",
			"quadrant": "glass_cannon",
			"accent": Color(1.0, 0.2, 0.35, 1.0),
			"mods": {"attack_speed_pct": 0.50, "health_regen_pct": -0.50},
			"icon": "res://assets/icons/items/icon_gauntlet.svg"
		},
		{
			"id": "vampiric_drain",
			"name": "Drenaje Vampírico",
			"boon": "+4.0 Regeneración masiva de vida continua",
			"curse": "-20% Velocidad de desplazamiento",
			"quadrant": "glass_cannon",
			"accent": Color(0.9, 0.1, 0.4, 1.0),
			"mods": {"health_regen": 4.0, "move_speed_pct": -0.20},
			"icon": "res://assets/icons/items/icon_apple.svg"
		},
		{
			"id": "shield_sacrifice",
			"name": "Sacrificio de Escudo",
			"boon": "+25% Probabilidad crítica y +0.50x Daño crítico",
			"curse": "-8 Armadura de protección reactiva",
			"quadrant": "glass_cannon",
			"accent": Color(1.0, 0.05, 0.3, 1.0),
			"mods": {"crit_chance": 0.25, "crit_damage": 0.50, "armor": -8.0},
			"icon": "res://assets/icons/items/icon_lens.svg"
		},
		{
			"id": "core_thirst",
			"name": "Sed de Núcleo",
			"boon": "+40% Daño base y +30% Tamaño de proyectiles",
			"curse": "-30% Radio magnético de recogida de EXP",
			"quadrant": "glass_cannon",
			"accent": Color(0.95, 0.2, 0.2, 1.0),
			"mods": {"base_damage_pct": 0.40, "weapon_size_pct": 0.30, "pickup_radius_pct": -0.30},
			"icon": "res://assets/icons/items/icon_heart.svg"
		},
		{
			"id": "last_breath",
			"name": "Último Aliento",
			"boon": "+45% Daño base y +20% Reducción de enfriamiento",
			"curse": "-40% Vida máxima total",
			"quadrant": "glass_cannon",
			"accent": Color(1.0, 0.1, 0.2, 1.0),
			"mods": {"base_damage_pct": 0.45, "cooldown_reduction": 0.20, "max_health_pct": -0.40},
			"icon": "res://assets/icons/items/icon_sword.svg"
		},

		# CUADRANTE 2: Danmaku & Caos Balístico
		{
			"id": "shrapnel_rain",
			"name": "Lluvia de Metralla",
			"boon": "+3 Proyectiles adicionales en cada disparo",
			"curse": "-30% Daño de cada bala individual",
			"quadrant": "danmaku_chaos",
			"accent": Color(0.0, 0.95, 1.0, 1.0),
			"mods": {"projectile_count": 3.0, "base_damage_pct": -0.30},
			"icon": "res://assets/icons/items/icon_quiver.svg"
		},
		{
			"id": "colossal_projectile",
			"name": "Proyectil Colosal",
			"boon": "+100% Tamaño colosal de proyectiles y +35% Daño",
			"curse": "-40% Velocidad de desplazamiento de balas",
			"quadrant": "danmaku_chaos",
			"accent": Color(0.1, 0.85, 1.0, 1.0),
			"mods": {"weapon_size_pct": 1.0, "base_damage_pct": 0.35, "projectile_speed_pct": -0.40},
			"icon": "res://assets/icons/icon_laser.png"
		},
		{
			"id": "unstable_fission",
			"name": "Fisión Inestable",
			"boon": "+2 Proyectiles y +20% Probabilidad crítica",
			"curse": "-25% Cadencia de disparo",
			"quadrant": "danmaku_chaos",
			"accent": Color(0.2, 1.0, 0.9, 1.0),
			"mods": {"projectile_count": 2.0, "crit_chance": 0.20, "attack_speed_pct": -0.25},
			"icon": "res://assets/icons/icon_missile.png"
		},
		{
			"id": "quantum_ricochet",
			"name": "Rebote Cuántico",
			"boon": "+40% Velocidad de proyectil e hiper-penetración",
			"curse": "-15% Daño base de proyectiles",
			"quadrant": "danmaku_chaos",
			"accent": Color(0.0, 0.9, 0.8, 1.0),
			"mods": {"projectile_speed_pct": 0.40, "base_damage_pct": -0.15},
			"icon": "res://assets/icons/items/icon_glasses.svg"
		},
		{
			"id": "heavy_ballistics",
			"name": "Balística Pesada",
			"boon": "+50% Daño devastador y +6 Armadura frontal",
			"curse": "-25% Velocidad de maniobra y giro",
			"quadrant": "danmaku_chaos",
			"accent": Color(0.3, 0.8, 1.0, 1.0),
			"mods": {"base_damage_pct": 0.50, "armor": 6.0, "move_speed_pct": -0.25},
			"icon": "res://assets/icons/items/icon_shield.svg"
		},
		{
			"id": "danmaku_mirror",
			"name": "Espejo Danmaku",
			"boon": "+4 Proyectiles en abanico y +30% Cadencia de fuego",
			"curse": "-50% Tamaño de proyectil y -20% Daño base",
			"quadrant": "danmaku_chaos",
			"accent": Color(0.15, 0.95, 1.0, 1.0),
			"mods": {"projectile_count": 4.0, "attack_speed_pct": 0.30, "weapon_size_pct": -0.50, "base_damage_pct": -0.20},
			"icon": "res://assets/icons/items/icon_quiver.svg"
		},

		# CUADRANTE 3: Espacio-Tiempo & Evasión
		{
			"id": "dimensional_leap",
			"name": "Salto Dimensional",
			"boon": "+45% Velocidad de maniobra y +35% Recarga de dash",
			"curse": "-20% Resistencia e integridad de casco (Max HP)",
			"quadrant": "spacetime",
			"accent": Color(0.75, 0.25, 1.0, 1.0),
			"mods": {"move_speed_pct": 0.45, "cooldown_reduction": 0.35, "max_health_pct": -0.20},
			"icon": "res://assets/icons/items/icon_boots.svg"
		},
		{
			"id": "gravitational_vortex",
			"name": "Vórtice Gravitatorio",
			"boon": "+120% Radio gravitatorio de aspiración de orbes",
			"curse": "-15% Velocidad de eyección de proyectiles",
			"quadrant": "spacetime",
			"accent": Color(0.65, 0.35, 1.0, 1.0),
			"mods": {"pickup_radius_pct": 1.20, "projectile_speed_pct": -0.15},
			"icon": "res://assets/icons/items/icon_magnet.svg"
		},
		{
			"id": "time_dilation",
			"name": "Dilatación Temporal",
			"boon": "+40% Aceleración de recargas y +15% Crítico",
			"curse": "-20% Velocidad lineal de proyectiles",
			"quadrant": "spacetime",
			"accent": Color(0.85, 0.3, 0.95, 1.0),
			"mods": {"cooldown_reduction": 0.40, "crit_chance": 0.15, "projectile_speed_pct": -0.20},
			"icon": "res://assets/icons/items/icon_lens.svg"
		},
		{
			"id": "phantom_evasion",
			"name": "Evasión Fantasma",
			"boon": "+10 Armadura espectral y +25% Velocidad",
			"curse": "-20% Daño infligido por armas",
			"quadrant": "spacetime",
			"accent": Color(0.7, 0.2, 0.9, 1.0),
			"mods": {"armor": 10.0, "move_speed_pct": 0.25, "base_damage_pct": -0.20},
			"icon": "res://assets/icons/items/icon_shield.svg"
		},
		{
			"id": "warp_engine",
			"name": "Motor de Curvatura",
			"boon": "+60% Velocidad extrema de traslación estelar",
			"curse": "-50% Radio magnético de captación",
			"quadrant": "spacetime",
			"accent": Color(0.8, 0.4, 1.0, 1.0),
			"mods": {"move_speed_pct": 0.60, "pickup_radius_pct": -0.50},
			"icon": "res://assets/icons/items/icon_boots.svg"
		},
		{
			"id": "phase_flicker",
			"name": "Parpadeo de Fase",
			"boon": "+30% Velocidad y +20% Cadencia con micro-saltos cuánticos",
			"curse": "-25% Capacidad máxima de salud",
			"quadrant": "spacetime",
			"accent": Color(0.9, 0.2, 0.85, 1.0),
			"mods": {"move_speed_pct": 0.30, "attack_speed_pct": 0.20, "max_health_pct": -0.25},
			"icon": "res://assets/icons/items/icon_gauntlet.svg"
		},

		# CUADRANTE 4: Pacto de Avaricia & Sobrecarga
		{
			"id": "voracious_harvest",
			"name": "Cosecha Voraz",
			"boon": "+100% Cosecha duplicada de BioMasa y Créditos",
			"curse": "-25% Vida máxima y -5 Armadura",
			"quadrant": "greed",
			"accent": Color(1.0, 0.85, 0.1, 1.0),
			"mods": {"max_health_pct": -0.25, "armor": -5.0, "biomass_multiplier": 1.0, "credits_multiplier": 1.0},
			"icon": "res://assets/icons/icon_credit.png"
		},
		{
			"id": "midas_alchemy",
			"name": "Alquimia de Midas",
			"boon": "+50 Puntos de Suerte cósmica y +50% Ganancia de EXP",
			"curse": "-20% Potencia de daño base",
			"quadrant": "greed",
			"accent": Color(1.0, 0.9, 0.2, 1.0),
			"mods": {"luck": 50.0, "exp_multiplier_pct": 0.50, "base_damage_pct": -0.20},
			"icon": "res://assets/icons/items/icon_clover.svg"
		},
		{
			"id": "black_market",
			"name": "Mercado Negro",
			"boon": "+75% Daño crítico y +30% Daño de armas",
			"curse": "-30 Suerte (peores probabilidades de botín)",
			"quadrant": "greed",
			"accent": Color(0.95, 0.75, 0.05, 1.0),
			"mods": {"crit_damage": 0.75, "base_damage_pct": 0.30, "luck": -30.0},
			"icon": "res://assets/icons/items/icon_sword.svg"
		},
		{
			"id": "magnet_overload",
			"name": "Sobrecarga de Imanes",
			"boon": "+150% Rango de atracción de todo mineral en pantalla",
			"curse": "-20% Velocidad por sobrecarga de masa",
			"quadrant": "greed",
			"accent": Color(0.85, 0.95, 0.2, 1.0),
			"mods": {"pickup_radius_pct": 1.50, "move_speed_pct": -0.20},
			"icon": "res://assets/icons/items/icon_magnet.svg"
		},
		{
			"id": "high_risk_investment",
			"name": "Inversión de Alto Riesgo",
			"boon": "+75% Ganancia de EXP y +35% Cadencia de ataque",
			"curse": "-40% Integridad de casco (Max HP)",
			"quadrant": "greed",
			"accent": Color(1.0, 0.7, 0.15, 1.0),
			"mods": {"exp_multiplier_pct": 0.75, "attack_speed_pct": 0.35, "max_health_pct": -0.40},
			"icon": "res://assets/icons/icon_credit.png"
		},
		{
			"id": "extraction_aura",
			"name": "Aura de Extracción",
			"boon": "+30 Suerte, +40% Radio de absorción y +50% BioMasa",
			"curse": "-15% Daño infligido por armas",
			"quadrant": "greed",
			"accent": Color(0.9, 0.8, 0.3, 1.0),
			"mods": {"luck": 30.0, "pickup_radius_pct": 0.40, "base_damage_pct": -0.15, "biomass_multiplier": 0.5},
			"icon": "res://assets/icons/items/icon_clover.svg"
		}
	]

	var saved_count: int = 0
	for spec in arcanas_spec:
		var arc := ArcanaDataScript.new()
		arc.id = spec["id"]
		arc.name = spec["name"]
		arc.description_boon = spec["boon"]
		arc.description_curse = spec["curse"]
		arc.quadrant = spec["quadrant"]
		arc.color_accent = spec["accent"]
		arc.stat_modifiers = spec["mods"]
		if spec.has("icon") and ResourceLoader.exists(spec["icon"]):
			arc.icon = load(spec["icon"])

		var save_path := target_dir + arc.id + ".tres"
		var err := ResourceSaver.save(arc, save_path)
		if err == OK:
			saved_count += 1
			print("Saved: %s" % save_path)
		else:
			print("Error saving %s: %d" % [save_path, err])

	print("TOTAL ARCANAS GENERATED: %d / %d" % [saved_count, arcanas_spec.size()])
	quit(0 if saved_count == arcanas_spec.size() else 1)

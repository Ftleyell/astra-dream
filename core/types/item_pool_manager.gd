class_name ItemPoolManager
extends Node

const TeslaCoilEffectClass := preload("res://data/items/effects/tesla_coil_effect.gd")
const KineticPlatingEffectClass := preload("res://data/items/effects/kinetic_plating_effect.gd")
const PhaseThrusterEffectClass := preload("res://data/items/effects/phase_thruster_effect.gd")
const RetaliationSwarmEffectClass := preload("res://data/items/effects/retaliation_swarm_effect.gd")
const EntropyCatalystEffectClass := preload("res://data/items/effects/entropy_catalyst_effect.gd")
const PhaseInverterEffectClass := preload("res://data/items/effects/phase_inverter_effect.gd")
const PyroclasticBatteryEffectClass := preload("res://data/items/effects/pyroclastic_battery_effect.gd")
const CryoCondenserEffectClass := preload("res://data/items/effects/cryo_condenser_effect.gd")
const PhotonicTransducerEffectClass := preload("res://data/items/effects/photonic_transducer_effect.gd")
const OverdrainModuleEffectClass := preload("res://data/items/effects/overdrain_module_effect.gd")

@export var master_catalog: Array[ItemData] = []

var _active_pool: Array[ItemData] = []
var _in_run_banished: Array[StringName] = []

func _ready() -> void:
	if master_catalog.is_empty():
		_populate_default_catalog()

static func create_canonical_stat_items() -> Array[ItemData]:
	var defs = [
		{"id": &"botas", "name": "Botas", "desc": "+10% Velocidad de Movimiento.", "stat": &"move_speed", "val": 0.10, "pct": true, "cost": 45, "rarity": Enums.Rarity.COMMON, "tags": [&"mobility", &"speed"]},
		{"id": &"espada", "name": "Espada", "desc": "+5 Daño Base en todas las armas.", "stat": &"base_damage", "val": 5.0, "pct": false, "cost": 45, "rarity": Enums.Rarity.COMMON, "tags": [&"offense", &"damage"]},
		{"id": &"escudo", "name": "Escudo", "desc": "+2 Armadura (Reduce daño recibido).", "stat": &"armor", "val": 2.0, "pct": false, "cost": 45, "rarity": Enums.Rarity.COMMON, "tags": [&"defense", &"armor"]},
		{"id": &"corazon", "name": "Corazón", "desc": "+20 Puntos de Vida Máxima.", "stat": &"max_health", "val": 20.0, "pct": false, "cost": 45, "rarity": Enums.Rarity.COMMON, "tags": [&"sustain", &"health"]},
		{"id": &"manzana", "name": "Manzana", "desc": "+0.5 Regeneración de Vida por segundo.", "stat": &"health_regen", "val": 0.5, "pct": false, "cost": 45, "rarity": Enums.Rarity.COMMON, "tags": [&"sustain", &"regen"]},
		{"id": &"iman", "name": "Imán", "desc": "+35 px Radio de Recogida y absorción de EXP.", "stat": &"pickup_radius", "val": 35.0, "pct": false, "cost": 45, "rarity": Enums.Rarity.COMMON, "tags": [&"utility", &"pickup"]},
		{"id": &"gafas", "name": "Gafas", "desc": "+7% Probabilidad de Golpe Crítico.", "stat": &"crit_chance", "val": 0.07, "pct": false, "cost": 60, "rarity": Enums.Rarity.UNCOMMON, "tags": [&"offense", &"crit"]},
		{"id": &"lupa", "name": "Lupa", "desc": "+30% Multiplicador de Daño Crítico.", "stat": &"crit_damage", "val": 0.30, "pct": true, "cost": 60, "rarity": Enums.Rarity.UNCOMMON, "tags": [&"offense", &"crit"]},
		{"id": &"guante", "name": "Guante", "desc": "+12% Velocidad de Ataque y Cadencia.", "stat": &"attack_speed", "val": 0.12, "pct": true, "cost": 60, "rarity": Enums.Rarity.UNCOMMON, "tags": [&"offense", &"speed"]},
		{"id": &"trebol", "name": "Trébol", "desc": "+20% Atributo de Suerte (Mejores Tiers).", "stat": &"luck", "val": 0.20, "pct": true, "cost": 60, "rarity": Enums.Rarity.UNCOMMON, "tags": [&"utility", &"luck"]},
		{"id": &"carcaj", "name": "Carcaj", "desc": "+1 Proyectil Adicional en todas las armas.", "stat": &"projectile_count", "val": 1.0, "pct": false, "cost": 95, "rarity": Enums.Rarity.RARE, "tags": [&"offense", &"projectiles"]},
		{"id": &"chip_telemetria", "name": "Chip de Telemetría", "desc": "+20% EXP obtenida en combate.", "stat": &"exp_multiplier", "val": 0.20, "pct": true, "cost": 60, "rarity": Enums.Rarity.UNCOMMON, "tags": [&"utility", &"exp"]},
		# 6 Ítems pasivos reactivos / procs (R3)
		{"id": &"tesla_coil", "name": "Bobina Tesla", "desc": "Los impactos críticos desatan rayos en cadena a enemigos cercanos.", "stat": &"", "val": 0.0, "pct": false, "cost": 75, "rarity": Enums.Rarity.RARE, "tags": [&"offense", &"crit", &"proc"], "effects": [TeslaCoilEffectClass.new()]},
		{"id": &"kinetic_plating", "name": "Blindaje Cinético", "desc": "Detona una onda de choque repelente al recibir daño.", "stat": &"", "val": 0.0, "pct": false, "cost": 60, "rarity": Enums.Rarity.UNCOMMON, "tags": [&"defense", &"proc"], "effects": [KineticPlatingEffectClass.new()]},
		{"id": &"phase_thruster", "name": "Propulsor de Fase", "desc": "El impulso de esquiva detona una onda de choque en el punto de inicio.", "stat": &"", "val": 0.0, "pct": false, "cost": 70, "rarity": Enums.Rarity.RARE, "tags": [&"mobility", &"dash", &"proc"], "effects": [PhaseThrusterEffectClass.new()]},
		{"id": &"retaliation_swarm", "name": "Enjambre de Represalia", "desc": "Dispara una salva de micromisiles teledirigidos al recibir daño.", "stat": &"", "val": 0.0, "pct": false, "cost": 75, "rarity": Enums.Rarity.RARE, "tags": [&"defense", &"missile", &"proc"], "effects": [RetaliationSwarmEffectClass.new()]},
		{"id": &"entropy_catalyst", "name": "Catalizador de Entropía", "desc": "Los impactos críticos generan un vórtice gravitacional que atrae y daña enemigos.", "stat": &"", "val": 0.0, "pct": false, "cost": 65, "rarity": Enums.Rarity.UNCOMMON, "tags": [&"offense", &"singularity", &"proc"], "effects": [EntropyCatalystEffectClass.new()]},
		{"id": &"phase_inverter", "name": "Inversor de Fase", "desc": "Probabilidad al impactar de desplegar una barrera protectora de fase.", "stat": &"", "val": 0.0, "pct": false, "cost": 85, "rarity": Enums.Rarity.EPIC, "tags": [&"defense", &"shield", &"proc"], "effects": [PhaseInverterEffectClass.new()]},
		# 3 Ítems con anti-sinergias y penalizaciones explícitas (R3)
		{"id": &"glass_reactor", "name": "Reactor de Cristal", "desc": "+50% Daño Base, pero -30% Vida Máxima.", "stat": &"base_damage", "val": 0.50, "pct": true, "sec_stat": &"max_health", "sec_val": -0.30, "sec_pct": true, "cost": 70, "rarity": Enums.Rarity.RARE, "tags": [&"offense", &"damage", &"penalty", &"anti_synergy"]},
		{"id": &"heavy_condenser", "name": "Condensador Pesado", "desc": "+60% Daño Base, pero -25% Cadencia de Ataque.", "stat": &"base_damage", "val": 0.60, "pct": true, "sec_stat": &"attack_speed", "sec_val": -0.25, "sec_pct": true, "cost": 70, "rarity": Enums.Rarity.RARE, "tags": [&"offense", &"damage", &"penalty", &"anti_synergy"]},
		{"id": &"tachyon_piercer", "name": "Perforador Taquiónico", "desc": "+30% Probabilidad Crítica, pero -20% Velocidad de Movimiento.", "stat": &"crit_chance", "val": 0.30, "pct": false, "sec_stat": &"move_speed", "sec_val": -0.20, "sec_pct": true, "cost": 75, "rarity": Enums.Rarity.RARE, "tags": [&"offense", &"crit", &"penalty", &"anti_synergy"]}
	]
	var icon_map := {
		&"botas": "res://assets/icons/items/icon_boots.svg",
		&"espada": "res://assets/icons/items/icon_sword.svg",
		&"escudo": "res://assets/icons/items/icon_shield.svg",
		&"corazon": "res://assets/icons/items/icon_heart.svg",
		&"manzana": "res://assets/icons/items/icon_apple.svg",
		&"iman": "res://assets/icons/items/icon_magnet.svg",
		&"gafas": "res://assets/icons/items/icon_glasses.svg",
		&"lupa": "res://assets/icons/items/icon_lens.svg",
		&"guante": "res://assets/icons/items/icon_gauntlet.svg",
		&"trebol": "res://assets/icons/items/icon_clover.svg",
		&"carcaj": "res://assets/icons/items/icon_quiver.svg",
		&"chip_telemetria": "res://assets/icons/items/icon_lens.svg",
		&"tesla_coil": "res://assets/icons/items/icon_sword.svg",
		&"kinetic_plating": "res://assets/icons/items/icon_shield.svg",
		&"phase_thruster": "res://assets/icons/items/icon_boots.svg",
		&"retaliation_swarm": "res://assets/icons/items/icon_quiver.svg",
		&"entropy_catalyst": "res://assets/icons/items/icon_magnet.svg",
		&"phase_inverter": "res://assets/icons/items/icon_shield.svg",
		&"glass_reactor": "res://assets/icons/items/icon_sword.svg",
		&"heavy_condenser": "res://assets/icons/items/icon_gauntlet.svg",
		&"tachyon_piercer": "res://assets/icons/items/icon_glasses.svg",
	}

	var items: Array[ItemData] = []
	for d in defs:
		var it := ItemData.new()
		it.item_id = d["id"]
		it.item_name = d["name"]
		it.description = d["desc"]
		it.stat_name = d["stat"]
		it.stat_value = d["val"]
		it.is_percentage = d["pct"]
		it.cost = d["cost"]
		it.rarity = d["rarity"]
		if d.has("sec_stat"):
			it.secondary_stat_name = d["sec_stat"]
			it.secondary_stat_value = d.get("sec_val", 0.0)
			it.secondary_is_percentage = d.get("sec_pct", false)
		if d.has("effects"):
			for eff in d["effects"]:
				if eff is ItemEffect:
					it.effects.append(eff)
		if icon_map.has(it.item_id) and ResourceLoader.exists(icon_map[it.item_id]):
			it.icon = load(icon_map[it.item_id]) as Texture2D
		var item_tags: Array[StringName] = []
		for t in d["tags"]:
			item_tags.append(StringName(t))
		it.tags = item_tags
		items.append(it)
	return items

static func create_satellite_shop_items() -> Array[ItemData]:
	var defs = [
		# --- 8 Módulos de Sobrecarga (Trade-offs) ---
		{"id": &"fusion_reactor", "name": "Reactor de Fusión", "desc": "+20% Daño Base, pero -15% Vida Máxima.", "stat": &"base_damage", "val": 0.20, "pct": true, "sec_stat": &"max_health", "sec_val": -0.15, "sec_pct": true, "cost": 60, "rarity": Enums.Rarity.UNCOMMON, "max_stacks": 2, "tags": [&"offense", &"damage", &"penalty", &"tradeoff"]},
		{"id": &"dense_turbine", "name": "Turbina Densa", "desc": "+25% Daño Base, pero -12% Cadencia de Ataque.", "stat": &"base_damage", "val": 0.25, "pct": true, "sec_stat": &"attack_speed", "sec_val": -0.12, "sec_pct": true, "cost": 65, "rarity": Enums.Rarity.UNCOMMON, "max_stacks": 2, "tags": [&"offense", &"damage", &"penalty", &"tradeoff"]},
		{"id": &"collimator_lens", "name": "Lente Colimadora", "desc": "+15% Probabilidad Crítica, pero -10% Velocidad de Movimiento.", "stat": &"crit_chance", "val": 0.15, "pct": false, "sec_stat": &"move_speed", "sec_val": -0.10, "sec_pct": true, "cost": 60, "rarity": Enums.Rarity.UNCOMMON, "max_stacks": 2, "tags": [&"offense", &"crit", &"penalty", &"tradeoff"]},
		{"id": &"split_salvo", "name": "Salva Dividida", "desc": "+1 Proyectil Adicional, pero -18% Daño por Proyectil.", "stat": &"projectile_count", "val": 1.0, "pct": false, "sec_stat": &"base_damage", "sec_val": -0.18, "sec_pct": true, "cost": 75, "rarity": Enums.Rarity.RARE, "max_stacks": 1, "tags": [&"offense", &"projectiles", &"penalty", &"tradeoff"]},
		{"id": &"rapid_injector", "name": "Inyector Rápido", "desc": "+20% Cadencia de Ataque, pero -10% Daño Base.", "stat": &"attack_speed", "val": 0.20, "pct": true, "sec_stat": &"base_damage", "sec_val": -0.10, "sec_pct": true, "cost": 65, "rarity": Enums.Rarity.UNCOMMON, "max_stacks": 2, "tags": [&"offense", &"speed", &"penalty", &"tradeoff"]},
		{"id": &"nanotitanium_plating", "name": "Revestimiento Nanotitanio", "desc": "+3 Armadura Base, pero -12% Velocidad de Movimiento.", "stat": &"armor", "val": 3.0, "pct": false, "sec_stat": &"move_speed", "sec_val": -0.12, "sec_pct": true, "cost": 55, "rarity": Enums.Rarity.COMMON, "max_stacks": 2, "tags": [&"defense", &"armor", &"penalty", &"tradeoff"]},
		{"id": &"afterburn_thruster", "name": "Post-ignición", "desc": "+20% Velocidad de Movimiento, pero -25 px Radio de Recogida.", "stat": &"move_speed", "val": 0.20, "pct": true, "sec_stat": &"pickup_radius", "sec_val": -25.0, "sec_pct": false, "cost": 55, "rarity": Enums.Rarity.COMMON, "max_stacks": 2, "tags": [&"mobility", &"speed", &"penalty", &"tradeoff"]},
		{"id": &"tachyon_prism", "name": "Prisma Taquiónico", "desc": "+35% Daño Crítico, pero -8% Probabilidad Crítica.", "stat": &"crit_damage", "val": 0.35, "pct": true, "sec_stat": &"crit_chance", "sec_val": -0.08, "sec_pct": false, "cost": 70, "rarity": Enums.Rarity.RARE, "max_stacks": 2, "tags": [&"offense", &"crit", &"penalty", &"tradeoff"]},

		# --- 8 Artefactos Reactivos / Proc ---
		{"id": &"tesla_coil", "name": "Bobina Tesla", "desc": "Los impactos críticos desatan rayos en cadena a 3 enemigos cercanos.", "stat": &"", "val": 0.0, "pct": false, "cost": 80, "rarity": Enums.Rarity.RARE, "max_stacks": 2, "tags": [&"offense", &"crit", &"proc"], "effects": [TeslaCoilEffectClass.new()]},
		{"id": &"kinetic_plating", "name": "Blindaje Cinético", "desc": "Detona una onda de choque repelente al recibir daño que destruye proyectiles.", "stat": &"", "val": 0.0, "pct": false, "cost": 75, "rarity": Enums.Rarity.UNCOMMON, "max_stacks": 1, "tags": [&"defense", &"proc"], "effects": [KineticPlatingEffectClass.new()]},
		{"id": &"phase_thruster", "name": "Propulsor de Fase", "desc": "El impulso de esquiva detona una trampa de distorsión que ralentiza enemigos.", "stat": &"", "val": 0.0, "pct": false, "cost": 75, "rarity": Enums.Rarity.RARE, "max_stacks": 2, "tags": [&"mobility", &"dash", &"proc"], "effects": [PhaseThrusterEffectClass.new()]},
		{"id": &"retaliation_swarm", "name": "Enjambre de Represalia", "desc": "Dispara una salva de 4 micromisiles guiados al recibir daño.", "stat": &"", "val": 0.0, "pct": false, "cost": 85, "rarity": Enums.Rarity.RARE, "max_stacks": 2, "tags": [&"defense", &"missile", &"proc"], "effects": [RetaliationSwarmEffectClass.new()]},
		{"id": &"entropy_catalyst", "name": "Catalizador de Entropía", "desc": "Los impactos críticos tienen probabilidad de generar un vórtice gravitatorio.", "stat": &"", "val": 0.0, "pct": false, "cost": 80, "rarity": Enums.Rarity.RARE, "max_stacks": 1, "tags": [&"offense", &"singularity", &"proc"], "effects": [EntropyCatalystEffectClass.new()]},
		{"id": &"phase_inverter", "name": "Inversor de Fase", "desc": "Una racha de 25 impactos consecutivos otorga una barrera de invulnerabilidad.", "stat": &"", "val": 0.0, "pct": false, "cost": 95, "rarity": Enums.Rarity.EPIC, "max_stacks": 1, "tags": [&"defense", &"shield", &"proc"], "effects": [PhaseInverterEffectClass.new()]},
		{"id": &"pyroclastic_battery", "name": "Batería Piroclástica", "desc": "Al derrotar a un enemigo, detona liberando 3 esquirlas incendiarias guiadas.", "stat": &"", "val": 0.0, "pct": false, "cost": 80, "rarity": Enums.Rarity.RARE, "max_stacks": 2, "tags": [&"offense", &"kill", &"proc"], "effects": [PyroclasticBatteryEffectClass.new()]},
		{"id": &"cryo_condenser", "name": "Condensador Criogénico", "desc": "Probabilidad al impactar de congelar y ralentizar a los enemigos un 30% por 1.5s.", "stat": &"", "val": 0.0, "pct": false, "cost": 85, "rarity": Enums.Rarity.RARE, "max_stacks": 2, "tags": [&"offense", &"control", &"proc"], "effects": [CryoCondenserEffectClass.new()]},

		# --- 8 Núcleos de Conversión ---
		{"id": &"alchemical_converter", "name": "Convertidor Alquímico", "desc": "El 15% de la EXP recogida se convierte en créditos de combate al instante.", "stat": &"", "val": 0.0, "pct": false, "cost": 95, "rarity": Enums.Rarity.RARE, "max_stacks": 1, "tags": [&"utility", &"economy", &"conversion"]},
		{"id": &"hemodynamic_cell", "name": "Célula Hemodinámica", "desc": "+3% Daño Base y +2% Cadencia por cada 10% de Vida Faltante (hasta +25% máx).", "stat": &"", "val": 0.0, "pct": false, "cost": 100, "rarity": Enums.Rarity.RARE, "max_stacks": 1, "tags": [&"offense", &"conversion"]},
		{"id": &"kinetic_converter", "name": "Conversor Cinético", "desc": "El 25% del bonus de Velocidad de Proyectil se suma al Daño porcentual de armas.", "stat": &"", "val": 0.0, "pct": false, "cost": 90, "rarity": Enums.Rarity.RARE, "max_stacks": 1, "tags": [&"offense", &"conversion"]},
		{"id": &"gravitational_resonator", "name": "Resonador Gravitatorio", "desc": "Cada 25 px de Radio de Recogida otorga +1 punto de Armadura efectiva.", "stat": &"", "val": 0.0, "pct": false, "cost": 95, "rarity": Enums.Rarity.RARE, "max_stacks": 1, "tags": [&"defense", &"conversion"]},
		{"id": &"photonic_transducer", "name": "Transductor Fotónico", "desc": "Al ejecutar un Dash, todas tus armas activas disparan una salva instantánea (CD: 4s).", "stat": &"", "val": 0.0, "pct": false, "cost": 110, "rarity": Enums.Rarity.EPIC, "max_stacks": 1, "tags": [&"offense", &"mobility", &"conversion"], "effects": [PhotonicTransducerEffectClass.new()]},
		{"id": &"overdrain_module", "name": "Módulo de Sobredrenaje", "desc": "Los impactos críticos curan 1 HP, pero tu Regeneración Pasiva de Vida es 0.", "stat": &"", "val": 0.0, "pct": false, "cost": 115, "rarity": Enums.Rarity.EPIC, "max_stacks": 1, "tags": [&"sustain", &"conversion"], "effects": [OverdrainModuleEffectClass.new()]},
		{"id": &"static_cell", "name": "Pila de Carga Estática", "desc": "Moverse acumula carga (0 a 100); al llegar a 100, el próximo ataque es un crítico garantizado.", "stat": &"", "val": 0.0, "pct": false, "cost": 105, "rarity": Enums.Rarity.RARE, "max_stacks": 1, "tags": [&"offense", &"mobility", &"conversion"]},
		{"id": &"stellar_scrap", "name": "Chatarra Estelar", "desc": "Al recibir daño letal, consume 100 créditos para revivir al 30% de HP (1 uso por run).", "stat": &"", "val": 0.0, "pct": false, "cost": 120, "rarity": Enums.Rarity.EPIC, "max_stacks": 1, "tags": [&"sustain", &"defense", &"conversion"]}
	]

	var icon_map := {
		&"fusion_reactor": "res://assets/icons/items/icon_sword.svg",
		&"dense_turbine": "res://assets/icons/items/icon_gauntlet.svg",
		&"collimator_lens": "res://assets/icons/items/icon_glasses.svg",
		&"split_salvo": "res://assets/icons/items/icon_quiver.svg",
		&"rapid_injector": "res://assets/icons/items/icon_gauntlet.svg",
		&"nanotitanium_plating": "res://assets/icons/items/icon_shield.svg",
		&"afterburn_thruster": "res://assets/icons/items/icon_boots.svg",
		&"tachyon_prism": "res://assets/icons/items/icon_lens.svg",
		&"tesla_coil": "res://assets/icons/items/icon_sword.svg",
		&"kinetic_plating": "res://assets/icons/items/icon_shield.svg",
		&"phase_thruster": "res://assets/icons/items/icon_boots.svg",
		&"retaliation_swarm": "res://assets/icons/items/icon_quiver.svg",
		&"entropy_catalyst": "res://assets/icons/items/icon_magnet.svg",
		&"phase_inverter": "res://assets/icons/items/icon_shield.svg",
		&"pyroclastic_battery": "res://assets/icons/items/icon_sword.svg",
		&"cryo_condenser": "res://assets/icons/items/icon_lens.svg",
		&"alchemical_converter": "res://assets/icons/items/icon_clover.svg",
		&"hemodynamic_cell": "res://assets/icons/items/icon_heart.svg",
		&"kinetic_converter": "res://assets/icons/items/icon_quiver.svg",
		&"gravitational_resonator": "res://assets/icons/items/icon_shield.svg",
		&"photonic_transducer": "res://assets/icons/items/icon_boots.svg",
		&"overdrain_module": "res://assets/icons/items/icon_apple.svg",
		&"static_cell": "res://assets/icons/items/icon_sword.svg",
		&"stellar_scrap": "res://assets/icons/items/icon_heart.svg",
	}

	var items: Array[ItemData] = []
	for d in defs:
		var it := ItemData.new()
		it.item_id = d["id"]
		it.item_name = d["name"]
		it.description = d["desc"]
		it.stat_name = d["stat"]
		it.stat_value = d["val"]
		it.is_percentage = d["pct"]
		it.cost = d["cost"]
		it.rarity = d["rarity"]
		it.max_stacks = d.get("max_stacks", 1)
		if d.has("sec_stat"):
			it.secondary_stat_name = d["sec_stat"]
			it.secondary_stat_value = d.get("sec_val", 0.0)
			it.secondary_is_percentage = d.get("sec_pct", false)
		if d.has("effects"):
			for eff in d["effects"]:
				if eff is ItemEffect:
					it.effects.append(eff)
		if icon_map.has(it.item_id) and ResourceLoader.exists(icon_map[it.item_id]):
			it.icon = load(icon_map[it.item_id]) as Texture2D
		var item_tags: Array[StringName] = []
		for t in d["tags"]:
			item_tags.append(StringName(t))
		it.tags = item_tags
		items.append(it)
	return items

func _populate_default_catalog() -> void:
	master_catalog = create_canonical_stat_items()
	var sat_items := create_satellite_shop_items()
	for s_it in sat_items:
		var exists := false
		for m_it in master_catalog:
			if m_it.item_id == s_it.item_id:
				exists = true
				break
		if not exists:
			master_catalog.append(s_it)

func rebuild_run_pool(character: CharacterData, unlocked_items: Array[StringName], player_banned_ids: Array[StringName]) -> void:
	_active_pool.clear()
	_in_run_banished.clear()

	for item in master_catalog:
		# Filtro 1: Meta-progreso
		if not unlocked_items.has(item.item_id):
			continue

		# Filtro 2: Restricciones de clase / personaje
		if character and character.inherent_item_banlist.has(item.item_id):
			continue
		if character:
			var has_banned_tag := false
			for t in item.tags:
				if character.banned_tags.has(t):
					has_banned_tag = true
					break
			if has_banned_tag:
				continue

		# Filtro 3: Banlist de Megabonk seleccionada por el jugador
		if player_banned_ids.has(item.item_id):
			continue

		_active_pool.append(item)

func get_active_pool() -> Array[ItemData]:
	return _active_pool

func roll_item(rarity_filter: Enums.Rarity = -1 as Enums.Rarity) -> ItemData:
	var eligible: Array[ItemData] = []
	for item in _active_pool:
		if rarity_filter == -1 or item.rarity == rarity_filter:
			eligible.append(item)

	if eligible.is_empty():
		return _active_pool.pick_random() if not _active_pool.is_empty() else null
	return eligible.pick_random()

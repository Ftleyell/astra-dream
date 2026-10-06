class_name ItemPoolManager
extends Node

const ITEM_ROSTER_DIR: String = "res://data/items/roster"

const OVERLOAD_ITEM_IDS: Array[StringName] = [
	&"fusion_reactor", &"dense_turbine", &"collimator_lens", &"split_salvo",
	&"rapid_injector", &"nanotitanium_plating", &"afterburn_thruster", &"tachyon_prism"
]

const REACTIVE_PROC_ITEM_IDS: Array[StringName] = [
	&"tesla_coil", &"kinetic_plating", &"phase_thruster", &"retaliation_swarm",
	&"entropy_catalyst", &"phase_inverter", &"pyroclastic_battery", &"cryo_condenser"
]

const UTILITY_CORE_ITEM_IDS: Array[StringName] = [
	&"alchemical_converter", &"hemodynamic_cell", &"kinetic_converter", &"gravitational_resonator",
	&"photonic_transducer", &"overdrain_module", &"static_cell", &"stellar_scrap"
]

const STRATEGIC_MODULE_ITEM_IDS: Array[StringName] = [
	&"abyssal_contract", &"antimatter_core", &"blood_capacitor", &"entropy_engine",
	&"bifocal_lens", &"inertial_thruster", &"chain_battery", &"photonic_prism",
	&"orbital_relay", &"quantum_recompiler", &"heavy_salvager", &"chronos_bank"
]

const CHEST_CANONICAL_ITEM_IDS: Array[StringName] = [
	&"botas", &"espada", &"escudo", &"corazon", &"manzana", &"iman",
	&"gafas", &"lupa", &"guante", &"trebol", &"carcaj", &"chip_telemetria",
	&"propulsor", &"lente_amplificadora", &"reloj_cuantico",
	&"moneda_oro", &"capsula_biomasa", &"reliquia_maldita",
	&"glass_reactor", &"heavy_condenser", &"tachyon_piercer",
	&"quantum_key", &"credit_card_green", &"credit_card_red"
]

const CANONICAL_ITEM_IDS: Array[StringName] = [
	&"botas", &"espada", &"escudo", &"corazon", &"manzana", &"iman",
	&"gafas", &"lupa", &"guante", &"trebol", &"carcaj", &"chip_telemetria",
	&"propulsor", &"lente_amplificadora", &"reloj_cuantico",
	&"moneda_oro", &"capsula_biomasa", &"reliquia_maldita",
	&"tesla_coil", &"kinetic_plating", &"phase_thruster", &"retaliation_swarm",
	&"entropy_catalyst", &"phase_inverter",
	&"glass_reactor", &"heavy_condenser", &"tachyon_piercer",
	&"quantum_key", &"credit_card_green", &"credit_card_red"
]

const SATELLITE_ITEM_IDS: Array[StringName] = [
	# 8 Sobrecargas
	&"fusion_reactor", &"dense_turbine", &"collimator_lens", &"split_salvo",
	&"rapid_injector", &"nanotitanium_plating", &"afterburn_thruster", &"tachyon_prism",
	# 8 Procs reactivos
	&"tesla_coil", &"kinetic_plating", &"phase_thruster", &"retaliation_swarm",
	&"entropy_catalyst", &"phase_inverter", &"pyroclastic_battery", &"cryo_condenser",
	# 8 Núcleos de Conversión / Utilidad
	&"alchemical_converter", &"hemodynamic_cell", &"kinetic_converter", &"gravitational_resonator",
	&"photonic_transducer", &"overdrain_module", &"static_cell", &"stellar_scrap",
	# 12 Estratégicos
	&"abyssal_contract", &"antimatter_core", &"blood_capacitor", &"entropy_engine",
	&"bifocal_lens", &"inertial_thruster", &"chain_battery", &"photonic_prism",
	&"orbital_relay", &"quantum_recompiler", &"heavy_salvager", &"chronos_bank"
]


@export var master_catalog: Array[ItemData] = []

var _active_pool: Array[ItemData] = []
var _in_run_banished: Array[StringName] = []

# Pseudo-Random Distribution (PRD) & Pity Tracking
var chests_since_last_rare: int = 0
var chests_since_last_epic: int = 0
var chests_since_last_legendary: int = 0

func _ready() -> void:
	if master_catalog.is_empty():
		_populate_default_catalog()

static func load_item(item_id: StringName) -> ItemData:
	var path := "%s/%s.tres" % [ITEM_ROSTER_DIR, str(item_id)]
	if ResourceLoader.exists(path):
		var res := load(path) as ItemData
		if res:
			return res.duplicate(true)
	return null

static func create_canonical_stat_items() -> Array[ItemData]:
	var result: Array[ItemData] = []
	for id in CANONICAL_ITEM_IDS:
		var it := load_item(id)
		if it:
			result.append(it)
	return result

static func create_satellite_shop_items() -> Array[ItemData]:
	var result: Array[ItemData] = []
	for id in SATELLITE_ITEM_IDS:
		var it := load_item(id)
		if it:
			result.append(it)
	return result

func _populate_default_catalog() -> void:
	var dir := DirAccess.open(ITEM_ROSTER_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while not file_name.is_empty():
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				var item_res := load("%s/%s" % [ITEM_ROSTER_DIR, file_name]) as ItemData
				if item_res:
					var exists := false
					for m_it in master_catalog:
						if m_it.item_id == item_res.item_id:
							exists = true
							break
					if not exists:
						master_catalog.append(item_res.duplicate(true))
			file_name = dir.get_next()
		dir.list_dir_end()
	if master_catalog.is_empty():
		master_catalog = create_canonical_stat_items()

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

## Realiza una tirada estocástica ponderada por rareza modulada por la Suerte del jugador
func roll_item_by_weights(weights: Dictionary, player_luck: float = 1.0) -> ItemData:
	if _active_pool.is_empty():
		if master_catalog.is_empty():
			_populate_default_catalog()
		_active_pool = master_catalog.duplicate()

	var total_weight: float = 0.0
	var weighted_map: Dictionary = {}
	var luck_mult: float = maxf(0.1, player_luck)

	for r in weights.keys():
		var rarity: Enums.Rarity = r as Enums.Rarity
		var base_w: float = float(weights[r])
		var adjusted_w: float = base_w
		if rarity == Enums.Rarity.COMMON:
			adjusted_w = base_w * maxf(0.05, 1.0 - (luck_mult - 1.0) * 0.25)
		elif rarity == Enums.Rarity.UNCOMMON:
			adjusted_w = base_w * (1.0 + (luck_mult - 1.0) * 0.15)
		elif rarity == Enums.Rarity.RARE:
			adjusted_w = base_w * (1.0 + (luck_mult - 1.0) * 0.35)
		elif rarity == Enums.Rarity.EPIC:
			adjusted_w = base_w * (1.0 + (luck_mult - 1.0) * 0.55)
		elif rarity == Enums.Rarity.LEGENDARY:
			adjusted_w = base_w * (1.0 + (luck_mult - 1.0) * 0.80)

		adjusted_w = maxf(0.0, adjusted_w)
		weighted_map[rarity] = adjusted_w
		total_weight += adjusted_w

	if total_weight <= 0.0:
		return roll_item()

	var roll_val: float = randf() * total_weight
	var accum: float = 0.0
	var chosen_rarity: Enums.Rarity = Enums.Rarity.COMMON

	for r in weighted_map.keys():
		accum += float(weighted_map[r])
		if roll_val <= accum:
			chosen_rarity = r as Enums.Rarity
			break

	var candidate: ItemData = roll_item(chosen_rarity)
	if not candidate:
		candidate = roll_item()
	return candidate

func reset_pity_counters() -> void:
	chests_since_last_rare = 0
	chests_since_last_epic = 0
	chests_since_last_legendary = 0

## Rueda un lote de N ítems distintos para elección de cofre según el tipo de cofre y suerte del jugador
func roll_chest_draft(chest_type_int: int, weights: Dictionary, player_luck: float = 1.0, count: int = 3) -> Array[ItemData]:
	if _active_pool.is_empty():
		if master_catalog.is_empty():
			_populate_default_catalog()
		_active_pool = master_catalog.duplicate()

	var results: Array[ItemData] = []
	var attempts: int = 0
	var max_attempts: int = 60

	# Pity system para cofre regular (chest_type_int == 1)
	if chest_type_int == 1:
		chests_since_last_rare += 1
		chests_since_last_epic += 1
		chests_since_last_legendary += 1

		var luck_discount: int = int(player_luck / 20.0)
		var forced_pity_rarity: int = -1

		if chests_since_last_legendary >= maxi(5, 15 - luck_discount):
			forced_pity_rarity = Enums.Rarity.LEGENDARY
		elif chests_since_last_epic >= maxi(3, 10 - luck_discount):
			forced_pity_rarity = Enums.Rarity.EPIC
		elif chests_since_last_rare >= maxi(2, 5 - luck_discount):
			forced_pity_rarity = Enums.Rarity.RARE

		if forced_pity_rarity != -1:
			var pity_candidates: Array[ItemData] = []
			for it in _active_pool:
				if it.rarity == forced_pity_rarity:
					pity_candidates.append(it)
			if pity_candidates.is_empty():
				for it in _active_pool:
					if it.rarity >= forced_pity_rarity:
						pity_candidates.append(it)
			if not pity_candidates.is_empty():
				results.append(pity_candidates.pick_random())

	while results.size() < count and attempts < max_attempts:
		attempts += 1
		var candidate: ItemData = null

		# Salvage (0): Forzar stats básicos comunes y poco comunes
		if chest_type_int == 0:
			var common_pool: Array[ItemData] = []
			for it in _active_pool:
				if (it.rarity == Enums.Rarity.COMMON or it.rarity == Enums.Rarity.UNCOMMON) and not it.tags.has(&"conversion"):
					common_pool.append(it)
			candidate = common_pool.pick_random() if not common_pool.is_empty() else roll_item()
		# Golden (2): Forzar ítems épicos, legendarios, raros y núcleos de conversión
		elif chest_type_int == 2:
			var high_tier_pool: Array[ItemData] = []
			for it in _active_pool:
				if it.rarity >= Enums.Rarity.RARE or it.tags.has(&"conversion") or it.tags.has(&"proc"):
					high_tier_pool.append(it)
			candidate = high_tier_pool.pick_random() if not high_tier_pool.is_empty() else roll_item()
		# Regular (1): Ponderado por pesos y suerte
		else:
			candidate = roll_item_by_weights(weights, player_luck)

		if candidate:
			var duplicate_found := false
			for existing in results:
				if existing.item_id == candidate.item_id:
					duplicate_found = true
					break
			if not duplicate_found:
				results.append(candidate)

	if results.size() < count:
		for fallback: ItemData in _active_pool:
			var dup := false
			for ex in results:
				if ex.item_id == fallback.item_id:
					dup = true
					break
			if not dup:
				results.append(fallback)
				if results.size() >= count:
					break

	# PRD counter reset según la mayor rareza obtenida en el draft de cofre regular
	if chest_type_int == 1:
		var has_legendary: bool = false
		var has_epic: bool = false
		var has_rare: bool = false
		for item in results:
			if item.rarity == Enums.Rarity.LEGENDARY:
				has_legendary = true
			elif item.rarity == Enums.Rarity.EPIC:
				has_epic = true
			elif item.rarity == Enums.Rarity.RARE:
				has_rare = true

		if has_legendary:
			chests_since_last_legendary = 0
			chests_since_last_epic = 0
			chests_since_last_rare = 0
		elif has_epic:
			chests_since_last_epic = 0
			chests_since_last_rare = 0
		elif has_rare:
			chests_since_last_rare = 0

	return results

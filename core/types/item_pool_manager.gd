class_name ItemPoolManager
extends Node

@export var master_catalog: Array[ItemData] = []

var _active_pool: Array[ItemData] = []
var _in_run_banished: Array[StringName] = []

func _ready() -> void:
	if master_catalog.is_empty():
		_populate_default_catalog()

func _populate_default_catalog() -> void:
	var defs = [
		{"id": &"ukulele", "name": "Ukelele de Plasma", "desc": "25% prob. de disparar rayos a 3 enemigos cercanos.", "rarity": Enums.Rarity.UNCOMMON, "tags": [&"electric", &"aoe"]},
		{"id": &"plasma_missile", "name": "Misil Rastreador", "desc": "10% prob. al golpear de lanzar misil teledirigido de alto daño.", "rarity": Enums.Rarity.UNCOMMON, "tags": [&"explosive", &"homing"]},
		{"id": &"bleed_dagger", "name": "Daga de Sangrado", "desc": "Golpes críticos aplican daño cortante continuo durante 3s.", "rarity": Enums.Rarity.COMMON, "tags": [&"bleed", &"crit"]},
		{"id": &"energy_shield", "name": "Escudo de Deflexión", "desc": "Otorga 30 puntos de escudo que absorben daño antes de la vida.", "rarity": Enums.Rarity.COMMON, "tags": [&"shield", &"defense"]},
		{"id": &"hyper_thruster", "name": "Hiper-Propulsor", "desc": "+15% velocidad de movimiento y +20% distancia de Dash.", "rarity": Enums.Rarity.COMMON, "tags": [&"mobility", &"speed"]},
		{"id": &"crit_lens", "name": "Lentes Oculares", "desc": "+10% de probabilidad de impacto crítico.", "rarity": Enums.Rarity.COMMON, "tags": [&"crit", &"offense"]},
		{"id": &"heavy_plating", "name": "Blindaje de Hiperaleación", "desc": "Reduce todo el daño recibido en 4 puntos fijos.", "rarity": Enums.Rarity.RARE, "tags": [&"defense", &"armor"]},
		{"id": &"vampiric_spark", "name": "Chispa Vampírica", "desc": "Eliminar monstruos recupera 3 puntos de vida.", "rarity": Enums.Rarity.UNCOMMON, "tags": [&"heal", &"sustain"]},
		{"id": &"nanite_swarm", "name": "Enjambre de Nanorobots", "desc": "2 micro-drones orbitan alrededor interceptando proyectiles.", "rarity": Enums.Rarity.RARE, "tags": [&"drone", &"defense"]},
		{"id": &"singularity_core", "name": "Núcleo de Singularidad", "desc": "Al usar la Bomba, genera un vórtice gravitacional destructivo.", "rarity": Enums.Rarity.EPIC, "tags": [&"void", &"bomb"]}
	]
	for d in defs:
		var it := ItemData.new()
		it.item_id = d["id"]
		it.item_name = d["name"]
		it.description = d["desc"]
		it.rarity = d["rarity"]
		var item_tags: Array[StringName] = []
		for t in d["tags"]:
			item_tags.append(StringName(t))
		it.tags = item_tags
		master_catalog.append(it)

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

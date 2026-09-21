class_name ItemPoolManager
extends Node

@export var master_catalog: Array[ItemData] = []

var _active_pool: Array[ItemData] = []
var _in_run_banished: Array[StringName] = []

func _ready() -> void:
	if master_catalog.is_empty():
		_populate_default_catalog()

static func create_canonical_stat_items() -> Array[ItemData]:
	var defs = [
		{"id": &"botas", "name": "Botas", "desc": "+10% Velocidad de Movimiento.", "stat": &"move_speed", "val": 0.10, "pct": true, "cost": 35, "rarity": Enums.Rarity.COMMON, "tags": [&"mobility", &"speed"]},
		{"id": &"espada", "name": "Espada", "desc": "+5 Daño Base en todas las armas.", "stat": &"base_damage", "val": 5.0, "pct": false, "cost": 35, "rarity": Enums.Rarity.COMMON, "tags": [&"offense", &"damage"]},
		{"id": &"escudo", "name": "Escudo", "desc": "+2 Armadura (Reduce daño recibido).", "stat": &"armor", "val": 2.0, "pct": false, "cost": 35, "rarity": Enums.Rarity.COMMON, "tags": [&"defense", &"armor"]},
		{"id": &"corazon", "name": "Corazón", "desc": "+20 Puntos de Vida Máxima.", "stat": &"max_health", "val": 20.0, "pct": false, "cost": 35, "rarity": Enums.Rarity.COMMON, "tags": [&"sustain", &"health"]},
		{"id": &"manzana", "name": "Manzana", "desc": "+0.5 Regeneración de Vida por segundo.", "stat": &"health_regen", "val": 0.5, "pct": false, "cost": 35, "rarity": Enums.Rarity.COMMON, "tags": [&"sustain", &"regen"]},
		{"id": &"iman", "name": "Imán", "desc": "+35 px Radio de Recogida y absorción de EXP.", "stat": &"pickup_radius", "val": 35.0, "pct": false, "cost": 35, "rarity": Enums.Rarity.COMMON, "tags": [&"utility", &"pickup"]},
		{"id": &"gafas", "name": "Gafas", "desc": "+7% Probabilidad de Golpe Crítico.", "stat": &"crit_chance", "val": 0.07, "pct": false, "cost": 55, "rarity": Enums.Rarity.UNCOMMON, "tags": [&"offense", &"crit"]},
		{"id": &"lupa", "name": "Lupa", "desc": "+30% Multiplicador de Daño Crítico.", "stat": &"crit_damage", "val": 0.30, "pct": true, "cost": 55, "rarity": Enums.Rarity.UNCOMMON, "tags": [&"offense", &"crit"]},
		{"id": &"guante", "name": "Guante", "desc": "+12% Velocidad de Ataque y Cadencia.", "stat": &"attack_speed", "val": 0.12, "pct": true, "cost": 55, "rarity": Enums.Rarity.UNCOMMON, "tags": [&"offense", &"speed"]},
		{"id": &"trebol", "name": "Trébol", "desc": "+20% Atributo de Suerte (Mejores Tiers).", "stat": &"luck", "val": 0.20, "pct": true, "cost": 55, "rarity": Enums.Rarity.UNCOMMON, "tags": [&"utility", &"luck"]},
		{"id": &"carcaj", "name": "Carcaj", "desc": "+1 Proyectil Adicional en todas las armas.", "stat": &"projectile_count", "val": 1.0, "pct": false, "cost": 90, "rarity": Enums.Rarity.RARE, "tags": [&"offense", &"projectiles"]},
		{"id": &"chip_telemetria", "name": "Chip de Telemetría", "desc": "+20% EXP obtenida en combate.", "stat": &"exp_multiplier", "val": 0.20, "pct": true, "cost": 45, "rarity": Enums.Rarity.UNCOMMON, "tags": [&"utility", &"exp"]}
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

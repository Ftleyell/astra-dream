class_name ArsenalBanlistDataController
extends RefCounted

## ArsenalBanlistDataController — Astra Dream
## Controlador puro y desacoplado de lógica y reglas de exclusión (Banlist).
## Gestiona las 7 categorías, el cálculo estricto del 40% máximo de bloqueos
## y la persistencia aislada por piloto en SaveManager sin dependencias de UI.

const WeaponCatalogScript = preload("res://data/weapons/weapon_catalog.gd")
const TomeCatalogScript = preload("res://data/tomes/tome_catalog.gd")
const ItemPoolManagerScript = preload("res://core/types/item_pool_manager.gd")

enum TabCategory {
	WEAPONS,
	TOMES,
	OVERLOADS,
	REACTIVE_PROCS,
	UTILITY_CORES,
	STRATEGIC_MODULES,
	CHEST_ITEMS
}

var character_id: StringName = &"nova"
var tabs_info: Array[Dictionary] = []

func _init(p_character_id: StringName = &"nova") -> void:
	character_id = p_character_id
	_init_tab_definitions()

func _init_tab_definitions() -> void:
	tabs_info = [
		{
			"id": TabCategory.WEAPONS,
			"name": "ARMAS",
			"full_title": "ARSENAL DE ARMAS // POOL DE SALVAS",
			"subtitle": "Armas adicionales desbloqueadas para tiradas durante la partida.",
			"category_tag": "// ARMA DE COMBATE",
			"item_ids": WeaponCatalogScript.POOL_WEAPON_IDS,
			"accent": Color(0.15, 0.9, 1.0)
		},
		{
			"id": TabCategory.TOMES,
			"name": "TOMOS",
			"full_title": "TOMOS ARCANOS // ATRIBUTOS",
			"subtitle": "Grimorios de especialización que potencian estadísticas de la nave.",
			"category_tag": "// TOMO ARCANO",
			"item_ids": TomeCatalogScript.ALL_TOME_IDS,
			"accent": Color(0.85, 0.45, 1.0)
		},
		{
			"id": TabCategory.OVERLOADS,
			"name": "SOBRECARGAS",
			"full_title": "SOBRECARGAS CON TRADE-OFF // SATÉLITE",
			"subtitle": "Módulos de alto rendimiento que ofrecen potencia a cambio de penalizaciones.",
			"category_tag": "// MÓDULO SATÉLITE - TRADE-OFF",
			"item_ids": ItemPoolManagerScript.OVERLOAD_ITEM_IDS,
			"accent": Color(1.0, 0.55, 0.2)
		},
		{
			"id": TabCategory.REACTIVE_PROCS,
			"name": "PROCS",
			"full_title": "PROCS REACTIVOS // SATÉLITE Y COMBATE",
			"subtitle": "Tecnología reactiva activada al recibir daño, esquivar o asestar críticos.",
			"category_tag": "// MÓDULO SATÉLITE - REACTIVO",
			"item_ids": ItemPoolManagerScript.REACTIVE_PROC_ITEM_IDS,
			"accent": Color(1.0, 0.85, 0.2)
		},
		{
			"id": TabCategory.UTILITY_CORES,
			"name": "UTILIDAD",
			"full_title": "NÚCLEOS DE CONVERSIÓN Y UTILIDAD",
			"subtitle": "Sistemas de conversión cinética, hemodinámica y absorción energética.",
			"category_tag": "// MÓDULO SATÉLITE - UTILIDAD",
			"item_ids": ItemPoolManagerScript.UTILITY_CORE_ITEM_IDS,
			"accent": Color(0.25, 1.0, 0.65)
		},
		{
			"id": TabCategory.STRATEGIC_MODULES,
			"name": "ESTRATÉGICOS",
			"full_title": "MÓDULOS ESTRATÉGICOS // SATÉLITE",
			"subtitle": "Sistemas arcanos y cósmicos de manipulación espacial y económica.",
			"category_tag": "// MÓDULO SATÉLITE - ESTRATÉGICO",
			"item_ids": ItemPoolManagerScript.STRATEGIC_MODULE_ITEM_IDS,
			"accent": Color(1.0, 0.35, 0.75)
		},
		{
			"id": TabCategory.CHEST_ITEMS,
			"name": "COFRES",
			"full_title": "ÍTEMS BÁSICOS Y COFRES DE COMBATE",
			"subtitle": "Reliquias, artefactos pasivos y tarjetas cuánticas de cofres regulares.",
			"category_tag": "// ÍTEM DE COFRE",
			"item_ids": ItemPoolManagerScript.CHEST_CANONICAL_ITEM_IDS,
			"accent": Color(0.9, 0.95, 1.0)
		}
	]

func get_tab_info(tab_id: int) -> Dictionary:
	if tab_id >= 0 and tab_id < tabs_info.size():
		return tabs_info[tab_id]
	return {}

func get_total_items_for_tab(tab_id: int) -> int:
	var info: Dictionary = get_tab_info(tab_id)
	if info.is_empty():
		return 0
	return (info["item_ids"] as Array).size()

func get_max_bans_for_tab(tab_id: int) -> int:
	var total: int = get_total_items_for_tab(tab_id)
	return int(floor(float(total) * 0.40))

func get_banned_ids_for_tab(tab_id: int) -> Array[StringName]:
	var info: Dictionary = get_tab_info(tab_id)
	if info.is_empty():
		return []
	var all_ids: Array = info["item_ids"]
	var result: Array[StringName] = []

	match tab_id:
		TabCategory.WEAPONS:
			var active: Array[StringName] = SaveManager.get_character_active_weapons(character_id)
			for w: StringName in all_ids:
				if not active.has(w):
					result.append(w)
		TabCategory.TOMES:
			var active: Array[StringName] = SaveManager.get_character_active_tomes(character_id)
			for t: StringName in all_ids:
				if not active.has(t):
					result.append(t)
		_:
			var banned_all: Array[StringName] = SaveManager.get_character_banlist(character_id)
			for it: StringName in all_ids:
				if banned_all.has(it):
					result.append(it)

	return result

func is_item_banned(tab_id: int, item_id: StringName) -> bool:
	return get_banned_ids_for_tab(tab_id).has(item_id)

func check_item_unlocked(tab_id: int, item_id: StringName) -> bool:
	match tab_id:
		TabCategory.WEAPONS, TabCategory.TOMES:
			return true
		_:
			if SaveManager.has_method("is_item_unlocked"):
				return SaveManager.is_item_unlocked(item_id)
			return true

## Alterna el estado de exclusión. Retorna true si tuvo éxito, o false si se denegó por límite de ban.
func toggle_item_ban(tab_id: int, item_id: StringName) -> bool:
	var banned_ids: Array[StringName] = get_banned_ids_for_tab(tab_id)
	var max_bans: int = get_max_bans_for_tab(tab_id)
	var currently_banned: bool = banned_ids.has(item_id)

	if currently_banned:
		set_item_banned_state(tab_id, item_id, false)
		return true
	else:
		if banned_ids.size() >= max_bans:
			return false
		set_item_banned_state(tab_id, item_id, true)
		return true

func set_item_banned_state(tab_id: int, item_id: StringName, should_ban: bool) -> void:
	match tab_id:
		TabCategory.WEAPONS:
			var active: Array[StringName] = SaveManager.get_character_active_weapons(character_id)
			if should_ban:
				active.erase(item_id)
			else:
				if not active.has(item_id):
					active.append(item_id)
			SaveManager.set_character_active_weapons(character_id, active)

		TabCategory.TOMES:
			var active: Array[StringName] = SaveManager.get_character_active_tomes(character_id)
			if should_ban:
				active.erase(item_id)
			else:
				if not active.has(item_id):
					active.append(item_id)
			SaveManager.set_character_active_tomes(character_id, active)

		_:
			var bans: Array[StringName] = SaveManager.get_character_banlist(character_id)
			if should_ban:
				if not bans.has(item_id):
					bans.append(item_id)
			else:
				bans.erase(item_id)
			SaveManager.set_character_banlist(character_id, bans)

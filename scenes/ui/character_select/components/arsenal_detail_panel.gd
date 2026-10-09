class_name ArsenalDetailPanel
extends RefCounted

## ArsenalDetailPanel — Astra Dream
## Componente desacoplado de renderizado e inspección de detalles para ArsenalBanlistModal.
## Gestiona la iconografía, rarezas, atributos y descripciones sin ensuciar el orquestador principal.

const WeaponCatalogScript = preload("res://data/weapons/weapon_catalog.gd")
const WeaponDataScript = preload("res://data/weapons/weapon_data.gd")
const TomeCatalogScript = preload("res://data/tomes/tome_catalog.gd")
const TomeDataScript = preload("res://data/tomes/tome_data.gd")
const ItemPoolManagerScript = preload("res://core/types/item_pool_manager.gd")
const ItemDataScript = preload("res://data/items/item_data.gd")

var icon_rect: TextureRect = null
var title_label: Label = null
var category_label: Label = null
var rarity_label: Label = null
var stats_label: Label = null
var desc_label: Label = null
var status_badge: Label = null
var status_panel: PanelContainer = null

func bind_nodes(
	p_icon_rect: TextureRect,
	p_title_label: Label,
	p_category_label: Label,
	p_rarity_label: Label,
	p_stats_label: Label,
	p_desc_label: Label,
	p_status_badge: Label,
	p_status_panel: PanelContainer
) -> void:
	icon_rect = p_icon_rect
	title_label = p_title_label
	category_label = p_category_label
	rarity_label = p_rarity_label
	stats_label = p_stats_label
	desc_label = p_desc_label
	status_badge = p_status_badge
	status_panel = p_status_panel

func inspect_item(item_id: StringName, tab_id: int, tab_info: Dictionary, is_banned: bool, is_unlocked: bool) -> void:
	if category_label:
		category_label.text = tab_info.get("category_tag", "")
	if icon_rect:
		icon_rect.texture = resolve_icon_texture(item_id, tab_id)

	if status_badge:
		if not is_unlocked:
			status_badge.text = "BLOQUEADO POR META-PROGRESIÓN"
			status_badge.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
		elif is_banned:
			status_badge.text = "EXCLUIDO DEL ARSENAL // NO APARECERÁ"
			status_badge.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		else:
			status_badge.text = "ACTIVO EN COMBATE // DISPONIBLE EN POOL"
			status_badge.add_theme_color_override("font_color", Color(0.2, 1.0, 0.65))

	match tab_id:
		0: # WEAPONS
			_inspect_weapon(item_id)
		1: # TOMES
			_inspect_tome(item_id)
		_:
			_inspect_inventory_item(item_id)

func _inspect_weapon(weapon_id: StringName) -> void:
	var wpn: WeaponData = WeaponCatalogScript.get_weapon_by_id(weapon_id)
	if rarity_label:
		rarity_label.text = "TIPO: ARMA DE SALVAS // PROC: %.2f" % (wpn.proc_coefficient if wpn else 1.0)
		rarity_label.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))

	if wpn:
		if title_label:
			title_label.text = wpn.weapon_name.to_upper()
		if stats_label:
			stats_label.text = "Daño Base: %.1f | Cadencia: %.2fs | Ráfaga: %d" % [
				wpn.base_damage, wpn.base_cooldown, wpn.active_burst_count
			]
		if desc_label:
			desc_label.text = wpn.description
	else:
		if title_label:
			title_label.text = str(weapon_id).to_upper()
		if stats_label:
			stats_label.text = ""
		if desc_label:
			desc_label.text = "Especificación balística clasificada."

func _inspect_tome(tome_id: StringName) -> void:
	var tome: TomeDataScript = TomeCatalogScript.load_tome(tome_id)
	if rarity_label:
		rarity_label.text = "TIPO: TOMO ARCANO DE ATRIBUTOS"
		rarity_label.add_theme_color_override("font_color", Color(0.85, 0.5, 1.0))

	if tome:
		if title_label:
			title_label.text = tome.display_name.to_upper()
		var stat_display: String = get_stat_display_name(tome.stat_name)
		var bonus_str: String = format_stat_bonus(tome.stat_value_per_level, tome.is_percentage, tome.stat_name)
		if stats_label:
			stats_label.text = "Atributo: %s (%s por nivel)" % [stat_display, bonus_str]
		if desc_label:
			desc_label.text = tome.description
	else:
		if title_label:
			title_label.text = str(tome_id).to_upper()
		if stats_label:
			stats_label.text = ""
		if desc_label:
			desc_label.text = "Grimorio de conocimiento arcano sin descifrar."

func _inspect_inventory_item(item_id: StringName) -> void:
	var item: ItemData = ItemPoolManagerScript.load_item(item_id)
	if item:
		if title_label:
			title_label.text = item.item_name.to_upper()
		var rarity_str: String = "COMÚN"
		var r_color := Color(0.7, 0.8, 0.9)
		match item.rarity:
			Enums.Rarity.UNCOMMON:
				rarity_str = "POCO COMÚN"
				r_color = Color(0.3, 1.0, 0.5)
			Enums.Rarity.RARE:
				rarity_str = "RARO"
				r_color = Color(0.2, 0.7, 1.0)
			Enums.Rarity.EPIC:
				rarity_str = "ÉPICO"
				r_color = Color(0.8, 0.35, 1.0)
			Enums.Rarity.LEGENDARY:
				rarity_str = "LEGENDARIO"
				r_color = Color(1.0, 0.8, 0.2)
		if rarity_label:
			rarity_label.text = "RAREZA: %s | COSTE BASE: %dc" % [rarity_str, item.cost]
			rarity_label.add_theme_color_override("font_color", r_color)

		var stats_desc := ""
		if not item.stat_name.is_empty():
			var val_str := format_stat_bonus(item.stat_value, item.is_percentage, item.stat_name)
			var name_str := get_stat_display_name(item.stat_name)
			stats_desc = "%s en %s" % [val_str, name_str]
		if not item.secondary_stat_name.is_empty():
			var val_str2 := format_stat_bonus(item.secondary_stat_value, item.secondary_is_percentage, item.secondary_stat_name)
			var name_str2 := get_stat_display_name(item.secondary_stat_name)
			var sep := "  |  " if not stats_desc.is_empty() else ""
			stats_desc += "%s%s en %s" % [sep, val_str2, name_str2]
		if stats_label:
			stats_label.text = stats_desc
		if desc_label:
			desc_label.text = item.description
	else:
		if title_label:
			title_label.text = str(item_id).to_upper()
		if rarity_label:
			rarity_label.text = "MÓDULO DE ARSENAL"
		if stats_label:
			stats_label.text = ""
		if desc_label:
			desc_label.text = "Módulo estratégico de hangar espacial."

static func get_stat_display_name(stat_key: StringName) -> String:
	match stat_key:
		&"base_damage":
			return "Daño Base"
		&"attack_speed":
			return "Cadencia de Ataque"
		&"movement_speed", &"move_speed":
			return "Velocidad de Movimiento"
		&"max_health":
			return "Vida Máxima"
		&"health_regen":
			return "Regeneración de Vida"
		&"armor":
			return "Armadura"
		&"crit_chance":
			return "Probabilidad Crítica"
		&"crit_damage":
			return "Daño Crítico"
		&"pickup_radius":
			return "Radio de Recogida"
		&"luck":
			return "Suerte"
		&"curse":
			return "Maldición"
		&"cooldown_reduction":
			return "Reducción de Enfriamiento"
		&"projectile_speed":
			return "Velocidad de Proyectil"
		&"weapon_size":
			return "Área de Proyectiles"
		&"projectile_count":
			return "Proyectiles Adicionales"
		&"exp_multiplier":
			return "EXP Obtenida"
		&"credits_multiplier":
			return "Créditos Obtenidos"
		&"biomass_multiplier":
			return "Biomasa Obtenida"
		_:
			return str(stat_key).capitalize().replace("_", " ")

static func format_stat_bonus(val: float, is_pct: bool, stat_key: StringName) -> String:
	var sign_str: String = "+" if val >= 0.0 else ""
	var is_effective_pct: bool = is_pct or (absf(val) < 2.0 and stat_key != &"health_regen" and stat_key != &"armor" and stat_key != &"curse" and stat_key != &"projectile_count")
	if is_effective_pct:
		var pct_val: float = val * (100.0 if absf(val) <= 1.0 else 1.0)
		return "%s%.0f%%" % [sign_str, pct_val]
	elif stat_key == &"pickup_radius":
		return "%s%d px" % [sign_str, int(roundf(val))]
	elif is_equal_approx(val, roundf(val)):
		return "%s%d" % [sign_str, int(val)]
	else:
		return "%s%.1f" % [sign_str, val]

static func resolve_icon_texture(item_id: StringName, tab_id: int) -> Texture2D:
	var path := ""
	match tab_id:
		0: # WEAPONS
			var wpn: WeaponData = WeaponCatalogScript.get_weapon_by_id(item_id)
			if wpn and wpn.icon:
				return wpn.icon
			path = "res://assets/characters/skills/weapons/icon_weapon_%s.png" % str(item_id)
			if not ResourceLoader.exists(path):
				path = "res://assets/ui/icons/weapons/%s.png" % str(item_id)
		1: # TOMES
			var tome = TomeCatalogScript.load_tome(item_id)
			if tome and tome.icon:
				return tome.icon
			path = "res://assets/ui/icons/tomes/%s.png" % str(item_id)
			if not ResourceLoader.exists(path):
				path = "res://assets/ui/icons/tomes/icon_tome_%s.png" % str(item_id)
		_:
			var item := ItemPoolManagerScript.load_item(item_id)
			if item and item.icon:
				return item.icon
			path = "res://assets/ui/icons/items/%s.png" % str(item_id)
			if not ResourceLoader.exists(path):
				path = "res://assets/ui/icons/items/icon_item_%s.png" % str(item_id)

	if ResourceLoader.exists(path):
		var tex = load(path)
		if tex is Texture2D:
			return tex
	return null

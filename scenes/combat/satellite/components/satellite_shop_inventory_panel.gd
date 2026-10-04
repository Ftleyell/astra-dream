class_name SatelliteShopInventoryPanel
extends RefCounted

## SatelliteShopInventoryPanel.gd
## Controlador del panel lateral de inventario y estadísticas de SatelliteShop:
## - Muestra las 14 estadísticas del piloto en tiempo real.
## - Permite previsualizar deltas numéricos al hacer hover/focus sobre ítems.
## - Renderiza las armas equipadas y los ítems pasivos con sus acumulaciones.

const WeaponSwapModalClass = preload("res://scenes/ui/modals/weapon_swap_modal.gd")

const STAT_ICON_MAP: Dictionary = {
	&"base_damage": "res://assets/icons/items/icon_sword.svg",
	&"attack_speed": "res://assets/icons/items/icon_gauntlet.svg",
	&"crit_chance": "res://assets/icons/items/icon_glasses.svg",
	&"crit_damage": "res://assets/icons/items/icon_lens.svg",
	&"max_health": "res://assets/icons/items/icon_heart.svg",
	&"move_speed": "res://assets/icons/items/icon_boots.svg",
	&"luck": "res://assets/icons/items/icon_clover.svg",
	&"projectile_count": "res://assets/icons/items/icon_quiver.svg",
	&"armor": "res://assets/icons/items/icon_shield.svg",
	&"health_regen": "res://assets/icons/items/icon_apple.svg",
	&"pickup_radius": "res://assets/icons/items/icon_magnet.svg",
}

const RUN_STATS_CONFIG: Array[Dictionary] = [
	{"name": "DAÑO", "key": &"base_damage", "fmt": "%.1f", "suffix": ""},
	{"name": "VEL. ATAQUE", "key": &"attack_speed", "fmt": "%.2f", "suffix": "x"},
	{"name": "PROB. CRÍTICA", "key": &"crit_chance", "fmt": "%.0f", "suffix": "%", "mult": 100.0},
	{"name": "DAÑO CRÍTICO", "key": &"crit_damage", "fmt": "%.2f", "suffix": "x"},
	{"name": "PROYECTILES", "key": &"projectile_count", "fmt": "%.0f", "suffix": ""},
	{"name": "VEL. PROYECTIL", "key": &"projectile_speed", "fmt": "%.0f", "suffix": "%", "mult": 100.0},
	{"name": "VEL. MOVIMIENTO", "key": &"move_speed", "fmt": "%.0f", "suffix": " px/s"},
	{"name": "ENFRIAMIENTO", "key": &"cooldown_reduction", "fmt": "%.0f", "suffix": "%", "mult": 100.0},
	{"name": "VIDA MÁXIMA", "key": &"max_health", "fmt": "%.0f", "suffix": " HP"},
	{"name": "REGEN. VIDA", "key": &"health_regen", "fmt": "%.1f", "suffix": "/s"},
	{"name": "ARMADURA", "key": &"armor", "fmt": "%.0f", "suffix": ""},
	{"name": "RADIO RECOGIDA", "key": &"pickup_radius", "fmt": "%.0f", "suffix": " px"},
	{"name": "MULTIPLICADOR EXP", "key": &"exp_multiplier", "fmt": "%.0f", "suffix": "%", "mult": 100.0},
	{"name": "SUERTE", "key": &"luck", "fmt": "%+.0f", "suffix": ""},
	{"name": "MALDICIÓN", "key": &"curse", "fmt": "%.0f", "suffix": ""},
]

var stats_list: VBoxContainer
var weapons_list: VBoxContainer
var items_list: VBoxContainer
var inventory_summary_label: Label
var stat_ui_entries: Dictionary = {}

func setup(p_stats_list: VBoxContainer, p_weapons_list: VBoxContainer, p_items_list: VBoxContainer, p_summary_lbl: Label) -> void:
	stats_list = p_stats_list
	weapons_list = p_weapons_list
	items_list = p_items_list
	inventory_summary_label = p_summary_lbl

func refresh_stats_display(player: Player) -> void:
	if not is_instance_valid(player) or not stats_list:
		return

	for child: Node in stats_list.get_children():
		child.queue_free()
	stat_ui_entries.clear()

	var data: CharacterData = player.character_data
	var stats: CharacterStats = player.stats
	if not stats:
		return

	var theme_col: Color = data.color if data else Color("#00F0FF")

	for cfg: Dictionary in RUN_STATS_CONFIG:
		var key: StringName = cfg["key"]
		var current_val: float = stats.get_stat(key)
		var base_val: float = data.get(key) if (data and key in data) else current_val
		var mult: float = cfg.get("mult", 1.0)
		var fmt: String = cfg["fmt"]
		var suffix: String = cfg["suffix"]

		var is_curse: bool = (key == &"curse")
		var is_buffed: bool = (current_val > base_val + 0.001) and not is_curse
		var is_cursed: bool = is_curse and current_val > 0.0

		var item_panel := PanelContainer.new()
		item_panel.custom_minimum_size = Vector2(0, 22)

		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.05, 0.07, 0.11, 0.85)
		sb.border_color = (Color("#FF4466") if is_cursed else (Color("#00FF9D") if is_buffed else theme_col.darkened(0.5)))
		sb.set_border_width_all(1)
		sb.border_width_left = 3
		sb.set_corner_radius_all(3)
		item_panel.add_theme_stylebox_override("panel", sb)

		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 6)
		margin.add_theme_constant_override("margin_right", 6)
		margin.add_theme_constant_override("margin_top", 1)
		margin.add_theme_constant_override("margin_bottom", 1)
		item_panel.add_child(margin)

		var hbox := HBoxContainer.new()
		hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
		margin.add_child(hbox)

		var lbl_name := Label.new()
		lbl_name.text = cfg["name"]
		lbl_name.add_theme_font_size_override("font_size", 10)
		lbl_name.add_theme_color_override("font_color", Color("#FF4466") if is_cursed else Color(0.8, 0.85, 0.9))
		lbl_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(lbl_name)

		var displayed_val: String = (fmt % (current_val * mult)) + suffix
		var lbl_val := Label.new()
		lbl_val.text = displayed_val
		lbl_val.add_theme_font_size_override("font_size", 10)
		lbl_val.add_theme_color_override("font_color", Color("#FF4466") if is_cursed else (Color("#00FF9D") if is_buffed else Color.WHITE))
		hbox.add_child(lbl_val)

		if is_buffed:
			var lbl_base := Label.new()
			var base_disp: String = (fmt % (base_val * mult)) + suffix
			lbl_base.text = " (%s)" % base_disp
			lbl_base.add_theme_font_size_override("font_size", 9)
			lbl_base.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7, 0.7))
			hbox.add_child(lbl_base)

		stats_list.add_child(item_panel)
		stat_ui_entries[key] = {
			"panel": item_panel,
			"is_buffed": is_buffed,
			"base_style": sb,
			"theme_col": theme_col,
			"current_val": current_val,
			"mult": mult,
			"fmt": fmt,
			"suffix": suffix,
			"displayed_val": displayed_val,
			"lbl_val": lbl_val
		}

func highlight_preview_stat(stat_key: StringName, delta_val: float, is_pct: bool) -> void:
	for key: StringName in stat_ui_entries.keys():
		var entry: Dictionary = stat_ui_entries[key]
		var p: PanelContainer = entry.get("panel") as PanelContainer
		if not is_instance_valid(p):
			continue
		var lbl_val: Label = entry.get("lbl_val") as Label
		var displayed_val: String = entry.get("displayed_val", "")
		var is_buffed: bool = entry.get("is_buffed", false)

		if key == stat_key:
			var high_style := StyleBoxFlat.new()
			high_style.bg_color = Color(0.12, 0.16, 0.24, 0.98)
			high_style.border_color = Color("#FFE600")
			high_style.set_border_width_all(2)
			high_style.border_width_left = 5
			high_style.set_corner_radius_all(4)
			high_style.shadow_color = Color(1.0, 0.9, 0.0, 0.3)
			high_style.shadow_size = 4
			p.add_theme_stylebox_override("panel", high_style)

			if is_instance_valid(lbl_val):
				var cur_v: float = entry.get("current_val", 0.0)
				var mult: float = entry.get("mult", 1.0)
				var fmt: String = entry.get("fmt", "%.1f")
				var suffix: String = entry.get("suffix", "")
				var projected_v: float = cur_v * (1.0 + delta_val) if is_pct else (cur_v + delta_val)
				var proj_str: String = (fmt % (projected_v * mult)) + suffix
				lbl_val.text = "%s → %s" % [displayed_val, proj_str]
				lbl_val.add_theme_color_override("font_color", Color("#00FF9D") if delta_val >= 0 else Color("#FF4466"))
		else:
			p.add_theme_stylebox_override("panel", entry["base_style"])
			if is_instance_valid(lbl_val):
				lbl_val.text = displayed_val
				if is_buffed:
					lbl_val.add_theme_color_override("font_color", Color("#00FF9D"))
				else:
					lbl_val.add_theme_color_override("font_color", Color.WHITE)

func clear_stat_highlights() -> void:
	for key: StringName in stat_ui_entries.keys():
		var entry: Dictionary = stat_ui_entries[key]
		var p: PanelContainer = entry.get("panel") as PanelContainer
		if not is_instance_valid(p):
			continue
		var lbl_val: Label = entry.get("lbl_val") as Label
		var displayed_val: String = entry.get("displayed_val", "")
		var is_buffed: bool = entry.get("is_buffed", false)

		p.add_theme_stylebox_override("panel", entry["base_style"])
		if is_instance_valid(lbl_val):
			lbl_val.text = displayed_val
			if is_buffed:
				lbl_val.add_theme_color_override("font_color", Color("#00FF9D"))
			else:
				lbl_val.add_theme_color_override("font_color", Color.WHITE)

func refresh_inventory_display(player: Player) -> void:
	if not is_instance_valid(player):
		return

	# 1. Armas Equipadas
	var weapons_count: int = 0
	if weapons_list:
		for child: Node in weapons_list.get_children():
			child.queue_free()

		var w_ctrl: WeaponController = player.get_node_or_null("WeaponController") as WeaponController
		if w_ctrl and not w_ctrl.equipped_weapons.is_empty():
			weapons_count = w_ctrl.equipped_weapons.size()
			for w_inst in w_ctrl.equipped_weapons:
				var w_data: WeaponData = w_inst.weapon_data if ("weapon_data" in w_inst) else (w_inst.get("data") as WeaponData)
				if not w_data:
					continue
				var w_lvl: int = w_inst.level if ("level" in w_inst) else 1
				var w_card: PanelContainer = _create_inventory_weapon_card(w_data, w_lvl)
				weapons_list.add_child(w_card)
		else:
			var default_lbl := Label.new()
			default_lbl.text = "• Sistema de Armas Básico"
			default_lbl.add_theme_font_size_override("font_size", 11)
			default_lbl.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75))
			weapons_list.add_child(default_lbl)
			weapons_count = 1

	# 2. Ítems Pasivos
	var items_count: int = 0
	if items_list:
		for child: Node in items_list.get_children():
			child.queue_free()

		var all_items: Array[Dictionary] = []
		if player.inventory:
			all_items = player.inventory.get_all_items()

		items_count = all_items.size()
		if all_items.is_empty():
			var empty_lbl := Label.new()
			empty_lbl.text = "Sin ítems adquiridos en esta misión."
			empty_lbl.add_theme_font_size_override("font_size", 11)
			empty_lbl.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65))
			empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
			items_list.add_child(empty_lbl)
		else:
			for entry: Dictionary in all_items:
				var it_data: ItemData = entry.get("data") as ItemData
				var it_count: int = int(entry.get("count", 1))
				if not it_data:
					continue
				var it_card: PanelContainer = _create_inventory_item_card(it_data, it_count)
				items_list.add_child(it_card)

	# 3. Resumen
	if inventory_summary_label:
		inventory_summary_label.text = "Armas: %d/6  |  Ítems Pasivos: %d" % [weapons_count, items_count]

func _create_inventory_weapon_card(w_data: WeaponData, w_level: int = 1) -> PanelContainer:
	var panel_item := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.08, 0.12, 0.9)
	sb.border_color = Color(1.0, 0.8, 0.2, 0.7)
	sb.set_border_width_all(1)
	sb.border_width_left = 3
	sb.set_corner_radius_all(4)
	panel_item.add_theme_stylebox_override("panel", sb)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	panel_item.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	margin.add_child(hbox)

	var tex_rect := TextureRect.new()
	tex_rect.custom_minimum_size = Vector2(24, 24)
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var icon_tex: Texture2D = w_data.icon
	if not icon_tex and ResourceLoader.exists("res://assets/icons/items/icon_sword.svg"):
		icon_tex = load("res://assets/icons/items/icon_sword.svg") as Texture2D
	tex_rect.texture = icon_tex
	tex_rect.modulate = Color(1.0, 0.85, 0.3)
	hbox.add_child(tex_rect)

	var lbl := Label.new()
	lbl.text = "%s [Nv. %d]" % [w_data.weapon_name, w_level] if w_level > 1 else w_data.weapon_name
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.7))
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(lbl)

	var dmg_lbl := Label.new()
	dmg_lbl.text = "%.0f Dmg" % w_data.base_damage
	dmg_lbl.add_theme_font_size_override("font_size", 10)
	dmg_lbl.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9, 0.8))
	hbox.add_child(dmg_lbl)

	return panel_item

func _create_inventory_item_card(it_data: ItemData, count: int) -> PanelContainer:
	var rarity_col: Color = _get_rarity_color(it_data.rarity)
	var panel_item := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.07, 0.11, 0.85)
	sb.border_color = rarity_col * Color(1.0, 1.0, 1.0, 0.6)
	sb.set_border_width_all(1)
	sb.border_width_left = 3
	sb.set_corner_radius_all(4)
	panel_item.add_theme_stylebox_override("panel", sb)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	panel_item.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	margin.add_child(hbox)

	var tex_rect := TextureRect.new()
	tex_rect.custom_minimum_size = Vector2(24, 24)
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var icon_tex: Texture2D = it_data.icon
	if not icon_tex and STAT_ICON_MAP.has(it_data.stat_name) and ResourceLoader.exists(STAT_ICON_MAP[it_data.stat_name]):
		icon_tex = load(STAT_ICON_MAP[it_data.stat_name]) as Texture2D
	if not icon_tex and ResourceLoader.exists("res://assets/icons/items/icon_heart.svg"):
		icon_tex = load("res://assets/icons/items/icon_heart.svg") as Texture2D
	tex_rect.texture = icon_tex
	tex_rect.modulate = rarity_col
	hbox.add_child(tex_rect)

	var lbl := Label.new()
	lbl.text = it_data.item_name
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(lbl)

	var stack_lbl := Label.new()
	stack_lbl.text = "x%d" % count
	stack_lbl.add_theme_font_size_override("font_size", 11)
	stack_lbl.add_theme_color_override("font_color", Color("#00FF9D"))
	hbox.add_child(stack_lbl)

	return panel_item

func _get_rarity_color(rarity: Enums.Rarity) -> Color:
	match rarity:
		Enums.Rarity.COMMON:
			return Color(0.5, 0.8, 1.0, 0.95)
		Enums.Rarity.UNCOMMON:
			return Color(0.2, 0.95, 0.4, 0.95)
		Enums.Rarity.RARE:
			return Color(1.0, 0.8, 0.15, 1.0)
		Enums.Rarity.LEGENDARY:
			return Color(0.9, 0.3, 1.0, 1.0)
		_:
			return Color.WHITE

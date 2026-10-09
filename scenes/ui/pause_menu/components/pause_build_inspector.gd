class_name PauseBuildInspector
extends RefCounted

## PauseBuildInspector — Astra Dream
## Componente desacoplado de renderizado e inspección de Build para PauseMenu.
## Muestra atributos numéricos, ítems agrupados por origen y arsenal/tomos/arcanas equipadas.

const TomeDataScript = preload("res://data/tomes/tome_data.gd")
const WeaponDataScript = preload("res://data/weapons/weapon_data.gd")

const RUN_STATS_CONFIG: Array[Dictionary] = [
	{"name": "DAÑO", "key": &"base_damage", "fmt": "%.1f", "suffix": ""},
	{"name": "VEL. ATAQUE", "key": &"attack_speed", "fmt": "%.2f", "suffix": "x"},
	{"name": "PROB. CRÍTICA", "key": &"crit_chance", "fmt": "%.0f", "suffix": "%", "mult": 100.0},
	{"name": "DAÑO CRÍTICO", "key": &"crit_damage", "fmt": "%.2f", "suffix": "x"},
	{"name": "PROYECTILES", "key": &"projectile_count", "fmt": "%.0f", "suffix": ""},
	{"name": "VEL. PROYECTIL", "key": &"projectile_speed", "fmt": "%.0f", "suffix": "%", "mult": 100.0},
	{"name": "TAMAÑO DE ARMA", "key": &"weapon_size", "fmt": "%.0f", "suffix": "%", "mult": 100.0},
	{"name": "VEL. MOVIMIENTO", "key": &"move_speed", "fmt": "%.0f", "suffix": " px/s"},
	{"name": "ENFRIAMIENTO", "key": &"cooldown_reduction", "fmt": "%.0f", "suffix": "%", "mult": 100.0},
	{"name": "VIDA MÁXIMA", "key": &"max_health", "fmt": "%.0f", "suffix": " HP"},
	{"name": "REGEN. VIDA", "key": &"health_regen", "fmt": "%.1f", "suffix": "/s"},
	{"name": "ARMADURA", "key": &"armor", "fmt": "%.0f", "suffix": ""},
	{"name": "RADIO RECOGIDA", "key": &"pickup_radius", "fmt": "%.0f", "suffix": " px"},
	{"name": "MULTIPLICADOR EXP", "key": &"exp_multiplier", "fmt": "%.0f", "suffix": "%", "mult": 100.0},
	{"name": "MULTIPLICADOR CRÉDITOS", "key": &"credits_multiplier", "fmt": "%.0f", "suffix": "%", "mult": 100.0},
	{"name": "MULTIPLICADOR BIOMASA", "key": &"biomass_multiplier", "fmt": "%.0f", "suffix": "%", "mult": 100.0},
	{"name": "SUERTE", "key": &"luck", "fmt": "%+.0f", "suffix": ""},
	{"name": "MALDICIÓN", "key": &"curse", "fmt": "%.0f", "suffix": ""},
]

static func refresh_build_inspector(
	player: Player,
	stats_container: VBoxContainer,
	items_container: VBoxContainer,
	upgrades_container: VBoxContainer
) -> void:
	populate_stats(player, stats_container)
	populate_items(player, items_container)
	populate_upgrades(player, upgrades_container)

static func populate_stats(player: Player, stats_container: VBoxContainer) -> void:
	if not stats_container:
		return
	for child in stats_container.get_children():
		child.queue_free()

	if not is_instance_valid(player) or not player.stats:
		var empty_lbl := Label.new()
		empty_lbl.text = "Sin datos de estadísticas."
		stats_container.add_child(empty_lbl)
		return

	var data: CharacterData = player.character_data
	var stats: CharacterStats = player.stats
	var theme_col: Color = data.color if data else Color("#00F0FF")

	for cfg: Dictionary in RUN_STATS_CONFIG:
		var key: StringName = cfg["key"]
		var current_val: float = stats.get_stat(key)
		var base_val: float = data.get(key) if (data and key in data) else current_val
		var mult: float = cfg.get("mult", 1.0)
		var fmt: String = cfg["fmt"]
		var suffix: String = cfg["suffix"]

		var displayed_val: String = (fmt % (current_val * mult)) + suffix
		var is_curse: bool = (key == &"curse")
		var is_buffed: bool = (current_val > base_val + 0.001) and not is_curse
		var is_cursed: bool = is_curse and current_val > 0.0

		var item_panel := PanelContainer.new()
		item_panel.custom_minimum_size = Vector2(260, 22)

		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.04, 0.06, 0.10, 0.85)
		sb.border_color = (Color("#FF4466") if is_cursed else (Color("#00FF9D") if is_buffed else theme_col.darkened(0.4)))
		sb.set_border_width_all(1)
		sb.border_width_left = 3
		sb.set_corner_radius_all(3)
		item_panel.add_theme_stylebox_override("panel", sb)

		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 6)
		margin.add_theme_constant_override("margin_right", 8)
		margin.add_theme_constant_override("margin_top", 1)
		margin.add_theme_constant_override("margin_bottom", 1)
		item_panel.add_child(margin)

		var hbox := HBoxContainer.new()
		margin.add_child(hbox)

		var lbl_name := Label.new()
		lbl_name.text = cfg["name"]
		lbl_name.add_theme_font_size_override("font_size", 10)
		lbl_name.add_theme_color_override("font_color", Color("#FF4466") if is_cursed else Color(0.8, 0.85, 0.9))
		lbl_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(lbl_name)

		var lbl_val := Label.new()
		lbl_val.text = displayed_val
		lbl_val.add_theme_font_size_override("font_size", 10)
		lbl_val.add_theme_color_override("font_color", Color("#FF4466") if is_cursed else (Color("#00FF9D") if is_buffed else Color.WHITE))
		lbl_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		lbl_val.custom_minimum_size = Vector2(85, 0)
		hbox.add_child(lbl_val)

		stats_container.add_child(item_panel)

static func populate_items(player: Player, items_container: VBoxContainer) -> void:
	if not items_container:
		return
	for child in items_container.get_children():
		child.queue_free()

	if not player or not player.inventory:
		var empty_lbl := Label.new()
		empty_lbl.text = "No se detectó inventario del jugador."
		items_container.add_child(empty_lbl)
		return

	var all_items := player.inventory.get_all_items()
	if all_items.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "Ningún ítem adquirido aún.\n(Encuentra cofres y satélites para equipar ítems)"
		empty_lbl.modulate = Color(0.6, 0.65, 0.75, 0.8)
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		items_container.add_child(empty_lbl)
		return

	var origin_order: Array[String] = [
		"COFRE ESPACIAL",
		"TIENDA DE SATÉLITE",
		"FORJA CUÁNTICA",
		"BOTÍN DE RIVAL",
		"CONSUMIBLE / CAMPO"
	]

	var items_by_origin: Dictionary = {}
	for orig in origin_order:
		items_by_origin[orig] = []
	items_by_origin["OTROS"] = []

	for entry in all_items:
		var orig: String = entry.get("origin", "DESCONOCIDO")
		if items_by_origin.has(orig):
			items_by_origin[orig].append(entry)
		else:
			items_by_origin["OTROS"].append(entry)

	for orig in origin_order + ["OTROS"]:
		var group: Array = items_by_origin[orig]
		if group.is_empty():
			continue

		var header_panel := PanelContainer.new()
		var h_sb := StyleBoxFlat.new()
		h_sb.bg_color = Color(0.08, 0.12, 0.18, 0.8)
		h_sb.set_border_width_all(1)
		h_sb.border_color = Color(0.3, 0.7, 1.0, 0.5)
		h_sb.set_corner_radius_all(3)
		header_panel.add_theme_stylebox_override("panel", h_sb)

		var h_margin := MarginContainer.new()
		h_margin.add_theme_constant_override("margin_left", 8)
		h_margin.add_theme_constant_override("margin_top", 3)
		h_margin.add_theme_constant_override("margin_bottom", 3)
		header_panel.add_child(h_margin)

		var orig_lbl := Label.new()
		orig_lbl.text = "◆ %s (%d)" % [orig, group.size()]
		orig_lbl.add_theme_font_size_override("font_size", 12)
		orig_lbl.modulate = Color(0.4, 0.9, 1.0)
		h_margin.add_child(orig_lbl)
		items_container.add_child(header_panel)

		for entry in group:
			var item: ItemData = entry["data"]
			var count: int = entry["count"]

			var panel := PanelContainer.new()
			panel.custom_minimum_size = Vector2(0, 44)
			var p_sb := StyleBoxFlat.new()
			p_sb.bg_color = Color(0.04, 0.06, 0.10, 0.75)
			p_sb.set_border_width_all(1)
			p_sb.border_color = Color(0.2, 0.35, 0.5, 0.4)
			p_sb.set_corner_radius_all(4)
			panel.add_theme_stylebox_override("panel", p_sb)

			var hbox := HBoxContainer.new()
			hbox.add_theme_constant_override("separation", 8)

			var icon_rect := TextureRect.new()
			icon_rect.custom_minimum_size = Vector2(32, 32)
			icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			if item.icon:
				icon_rect.texture = item.icon
			hbox.add_child(icon_rect)

			var count_lbl := Label.new()
			count_lbl.text = "x%d" % count
			count_lbl.modulate = Color(1.0, 0.85, 0.2, 1.0)
			count_lbl.add_theme_font_size_override("font_size", 12)
			hbox.add_child(count_lbl)

			var vbox := VBoxContainer.new()
			vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

			var name_lbl := Label.new()
			name_lbl.text = item.item_name
			name_lbl.add_theme_font_size_override("font_size", 13)

			var desc_lbl := Label.new()
			desc_lbl.text = item.description
			desc_lbl.modulate = Color(0.7, 0.8, 0.9, 0.8)
			desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
			desc_lbl.add_theme_font_size_override("font_size", 10)

			vbox.add_child(name_lbl)
			vbox.add_child(desc_lbl)
			hbox.add_child(vbox)

			var item_m := MarginContainer.new()
			item_m.add_theme_constant_override("margin_left", 6)
			item_m.add_theme_constant_override("margin_right", 6)
			item_m.add_theme_constant_override("margin_top", 4)
			item_m.add_theme_constant_override("margin_bottom", 4)
			item_m.add_child(hbox)
			panel.add_child(item_m)

			items_container.add_child(panel)

static func populate_upgrades(player: Player, upgrades_container: VBoxContainer) -> void:
	if not upgrades_container:
		return
	for child in upgrades_container.get_children():
		child.queue_free()

	if player:
		_populate_equipped_equipment(player, upgrades_container)

	if player and not player.active_arcanas.is_empty():
		var arc_header := PanelContainer.new()
		var a_sb := StyleBoxFlat.new()
		a_sb.bg_color = Color(0.15, 0.04, 0.12, 0.85)
		a_sb.border_color = Color("#FF1493")
		a_sb.set_border_width_all(1)
		a_sb.set_corner_radius_all(3)
		arc_header.add_theme_stylebox_override("panel", a_sb)

		var a_margin := MarginContainer.new()
		a_margin.add_theme_constant_override("margin_left", 8)
		a_margin.add_theme_constant_override("margin_top", 3)
		a_margin.add_theme_constant_override("margin_bottom", 3)
		arc_header.add_child(a_margin)

		var arc_title := Label.new()
		arc_title.text = "◈ PACTOS DE ARCANA (%d)" % player.active_arcanas.size()
		arc_title.add_theme_font_size_override("font_size", 12)
		arc_title.modulate = Color("#FF1493")
		a_margin.add_child(arc_title)
		upgrades_container.add_child(arc_header)

		for arc: ArcanaData in player.active_arcanas:
			var arc_panel := PanelContainer.new()
			var p_sb := StyleBoxFlat.new()
			p_sb.bg_color = Color(0.06, 0.03, 0.08, 0.8)
			p_sb.border_color = arc.color_accent if arc.color_accent != Color.BLACK else Color("#FF1493")
			p_sb.set_border_width_all(1)
			p_sb.border_width_left = 3
			p_sb.set_corner_radius_all(4)
			arc_panel.add_theme_stylebox_override("panel", p_sb)

			var m := MarginContainer.new()
			m.add_theme_constant_override("margin_left", 6)
			m.add_theme_constant_override("margin_right", 6)
			m.add_theme_constant_override("margin_top", 4)
			m.add_theme_constant_override("margin_bottom", 4)
			arc_panel.add_child(m)

			var v := VBoxContainer.new()
			v.add_theme_constant_override("separation", 2)

			var t_lbl := Label.new()
			t_lbl.text = "✦ %s [%s]" % [arc.name, arc.get_quadrant_title().to_upper()]
			t_lbl.add_theme_font_size_override("font_size", 12)
			t_lbl.modulate = Color(1.0, 0.9, 0.4)
			v.add_child(t_lbl)

			var b_lbl := Label.new()
			b_lbl.text = "▲ %s" % arc.description_boon
			b_lbl.add_theme_font_size_override("font_size", 10)
			b_lbl.modulate = Color(0.4, 1.0, 0.6)
			b_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
			v.add_child(b_lbl)

			if not arc.description_curse.is_empty():
				var c_lbl := Label.new()
				c_lbl.text = "▼ %s" % arc.description_curse
				c_lbl.add_theme_font_size_override("font_size", 10)
				c_lbl.modulate = Color(1.0, 0.4, 0.5)
				c_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
				v.add_child(c_lbl)

			m.add_child(v)
			upgrades_container.add_child(arc_panel)

	# Mejoras de Nivel (Stat Cards)
	var lvl_header := PanelContainer.new()
	var l_sb := StyleBoxFlat.new()
	l_sb.bg_color = Color(0.08, 0.12, 0.18, 0.8)
	l_sb.border_color = Color(1.0, 0.85, 0.2, 0.5)
	l_sb.set_border_width_all(1)
	l_sb.set_corner_radius_all(3)
	lvl_header.add_theme_stylebox_override("panel", l_sb)

	var l_margin := MarginContainer.new()
	l_margin.add_theme_constant_override("margin_left", 8)
	l_margin.add_theme_constant_override("margin_top", 3)
	l_margin.add_theme_constant_override("margin_bottom", 3)
	lvl_header.add_child(l_margin)

	var num_upgrades: int = player.chosen_stat_cards.size() if player else 0
	var lvl_title := Label.new()
	lvl_title.text = "★ MEJORAS DE NIVEL (%d)" % num_upgrades
	lvl_title.add_theme_font_size_override("font_size", 12)
	lvl_title.modulate = Color(1.0, 0.85, 0.2)
	l_margin.add_child(lvl_title)
	upgrades_container.add_child(lvl_header)

	if not player or player.chosen_stat_cards.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "Sin mejoras de nivel adquiridas aún."
		empty_lbl.modulate = Color(0.6, 0.65, 0.75, 0.8)
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		upgrades_container.add_child(empty_lbl)
		return

	var cards_by_stat: Dictionary = {}
	var stat_order: Array[StringName] = []

	for card: StatCardData in player.chosen_stat_cards:
		var stat_key: StringName = card.target_stat
		if not cards_by_stat.has(stat_key):
			cards_by_stat[stat_key] = []
			stat_order.append(stat_key)
		cards_by_stat[stat_key].append(card)

	for stat_key: StringName in stat_order:
		var cards_group: Array = cards_by_stat[stat_key]
		var count: int = cards_group.size()
		var first_card: StatCardData = cards_group[0]

		var total_mod: float = 0.0
		var is_pct: bool = first_card.is_percentage
		for c: StatCardData in cards_group:
			total_mod += c.modifier_value

		var stat_name: String = String(stat_key).to_upper()
		for cfg: Dictionary in RUN_STATS_CONFIG:
			if cfg["key"] == stat_key:
				stat_name = cfg["name"]
				break

		var value_text: String = LevelUpStatsInspector.format_stat_modifier(stat_key, total_mod, is_pct, true)

		var panel := PanelContainer.new()
		var p_sb := StyleBoxFlat.new()
		p_sb.bg_color = Color(0.04, 0.06, 0.10, 0.75)
		p_sb.border_color = Color(1.0, 0.85, 0.2, 0.4)
		p_sb.set_border_width_all(1)
		p_sb.border_width_left = 3
		p_sb.set_corner_radius_all(3)
		panel.add_theme_stylebox_override("panel", p_sb)

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)

		var count_badge := Label.new()
		count_badge.text = "x%d" % count
		count_badge.modulate = Color(1.0, 0.85, 0.2)
		count_badge.add_theme_font_size_override("font_size", 11)

		var name_lbl := Label.new()
		name_lbl.text = stat_name
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_font_size_override("font_size", 11)
		name_lbl.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))

		var val_lbl := Label.new()
		val_lbl.text = value_text
		val_lbl.add_theme_font_size_override("font_size", 11)
		val_lbl.add_theme_color_override("font_color", Color("#00FF9D"))

		hbox.add_child(count_badge)
		hbox.add_child(name_lbl)
		hbox.add_child(val_lbl)

		var cm := MarginContainer.new()
		cm.add_theme_constant_override("margin_left", 6)
		cm.add_theme_constant_override("margin_right", 8)
		cm.add_theme_constant_override("margin_top", 3)
		cm.add_theme_constant_override("margin_bottom", 3)
		cm.add_child(hbox)
		panel.add_child(cm)

		upgrades_container.add_child(panel)

static func _populate_equipped_equipment(player: Player, upgrades_container: VBoxContainer) -> void:
	var weapons: Array = []
	var w_ctrl: Node = player.get_node_or_null("WeaponController")
	if w_ctrl and "equipped_weapons" in w_ctrl:
		weapons = w_ctrl.get("equipped_weapons") as Array

	var tomes: Array = []
	var tome_levels: Dictionary = {}
	var t_ctrl: Node = player.get("tome_controller")
	if t_ctrl and "equipped_tomes" in t_ctrl:
		tomes = t_ctrl.get("equipped_tomes") as Array
		if "tome_levels" in t_ctrl:
			tome_levels = t_ctrl.get("tome_levels") as Dictionary

	var has_weapons: bool = false
	for w in weapons:
		if w != null:
			has_weapons = true
			break
	var has_tomes: bool = not tomes.is_empty()

	if not has_weapons and not has_tomes:
		return

	var eq_header := PanelContainer.new()
	var h_sb := StyleBoxFlat.new()
	h_sb.bg_color = Color(0.08, 0.14, 0.22, 0.85)
	h_sb.border_color = Color(0.15, 0.9, 1.0, 0.6)
	h_sb.set_border_width_all(1)
	h_sb.set_corner_radius_all(3)
	eq_header.add_theme_stylebox_override("panel", h_sb)

	var h_margin := MarginContainer.new()
	h_margin.add_theme_constant_override("margin_left", 8)
	h_margin.add_theme_constant_override("margin_top", 3)
	h_margin.add_theme_constant_override("margin_bottom", 3)
	eq_header.add_child(h_margin)

	var eq_title := Label.new()
	eq_title.text = "⚡ ARSENAL Y TOMOS EQUIPADOS"
	eq_title.add_theme_font_size_override("font_size", 12)
	eq_title.modulate = Color(0.2, 0.95, 1.0)
	h_margin.add_child(eq_title)
	upgrades_container.add_child(eq_header)

	var eq_container := VBoxContainer.new()
	eq_container.add_theme_constant_override("separation", 6)

	var weapons_row := HBoxContainer.new()
	weapons_row.add_theme_constant_override("separation", 8)
	weapons_row.alignment = BoxContainer.ALIGNMENT_BEGIN

	const TOTAL_WEAPON_SLOTS: int = 4
	for slot_idx in range(TOTAL_WEAPON_SLOTS):
		var w_inst = weapons[slot_idx] if slot_idx < weapons.size() else null
		var chip := PanelContainer.new()
		chip.custom_minimum_size = Vector2(44, 44)
		chip.clip_contents = true

		var chip_sb := StyleBoxFlat.new()
		chip_sb.set_corner_radius_all(5)

		if w_inst != null and w_inst.weapon_data != null:
			var wdata: WeaponData = w_inst.weapon_data
			var w_level: int = w_inst.level
			chip_sb.bg_color = Color(0.04, 0.07, 0.14, 0.95)
			chip_sb.set_border_width_all(2)
			chip_sb.border_color = HUDInventoryBarController.get_rarity_color(wdata.rarity)
			chip.add_theme_stylebox_override("panel", chip_sb)

			chip.tooltip_text = "[Arma #%d] %s (★%d)\n%s" % [slot_idx + 1, wdata.weapon_name, w_level, wdata.description]

			var inner := Control.new()
			inner.set_anchors_preset(Control.PRESET_FULL_RECT)
			inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
			chip.add_child(inner)

			var icon_rect := TextureRect.new()
			icon_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
			icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if wdata.icon:
				icon_rect.texture = wdata.icon
			inner.add_child(icon_rect)

			var lvl_badge := PanelContainer.new()
			var badge_sb := StyleBoxFlat.new()
			badge_sb.bg_color = Color(0.03, 0.05, 0.10, 0.85)
			badge_sb.border_color = Color(1.0, 0.85, 0.2, 0.8)
			badge_sb.set_border_width_all(1)
			badge_sb.set_corner_radius_all(3)
			lvl_badge.add_theme_stylebox_override("panel", badge_sb)
			lvl_badge.position = Vector2(18, 26)
			lvl_badge.custom_minimum_size = Vector2(24, 16)
			lvl_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE

			var badge_lbl := Label.new()
			badge_lbl.text = "★%d" % w_level
			badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			badge_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			badge_lbl.add_theme_font_size_override("font_size", 9)
			badge_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.25))
			lvl_badge.add_child(badge_lbl)
			inner.add_child(lvl_badge)
		else:
			chip_sb.bg_color = Color(0.02, 0.04, 0.08, 0.45)
			chip_sb.set_border_width_all(1)
			chip_sb.border_color = Color(0.2, 0.35, 0.5, 0.3)
			chip.add_theme_stylebox_override("panel", chip_sb)
			chip.tooltip_text = "[Arma #%d] Vacía" % (slot_idx + 1)

			var empty_lbl := Label.new()
			empty_lbl.text = "—"
			empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			empty_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			empty_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
			empty_lbl.add_theme_font_size_override("font_size", 14)
			empty_lbl.add_theme_color_override("font_color", Color(0.3, 0.4, 0.5, 0.4))
			chip.add_child(empty_lbl)

		weapons_row.add_child(chip)
	eq_container.add_child(weapons_row)

	var tomes_row := HBoxContainer.new()
	tomes_row.add_theme_constant_override("separation", 8)
	tomes_row.alignment = BoxContainer.ALIGNMENT_BEGIN

	const TOTAL_TOME_SLOTS: int = 4
	for slot_idx in range(TOTAL_TOME_SLOTS):
		var t_data = tomes[slot_idx] if slot_idx < tomes.size() else null
		var chip := PanelContainer.new()
		chip.custom_minimum_size = Vector2(44, 44)
		chip.clip_contents = true

		var chip_sb := StyleBoxFlat.new()
		chip_sb.set_corner_radius_all(5)

		if t_data != null:
			var t_level: int = int(tome_levels.get(t_data.tome_id, 1))
			chip_sb.bg_color = Color(0.06, 0.04, 0.10, 0.95)
			chip_sb.set_border_width_all(2)
			chip_sb.border_color = Color(0.85, 0.45, 1.0, 0.85)
			chip.add_theme_stylebox_override("panel", chip_sb)

			chip.tooltip_text = "[Tomo #%d] %s (Nvl. %d)\n%s\nEfecto: %s" % [
				slot_idx + 1,
				t_data.display_name,
				t_level,
				t_data.description,
				t_data.get_bonus_description(t_level)
			]

			var inner := Control.new()
			inner.set_anchors_preset(Control.PRESET_FULL_RECT)
			inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
			chip.add_child(inner)

			var icon_rect := TextureRect.new()
			icon_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
			icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if t_data.icon:
				icon_rect.texture = t_data.icon
			inner.add_child(icon_rect)

			var lvl_badge := PanelContainer.new()
			var badge_sb := StyleBoxFlat.new()
			badge_sb.bg_color = Color(0.04, 0.02, 0.08, 0.85)
			badge_sb.border_color = Color(0.85, 0.45, 1.0, 0.8)
			badge_sb.set_border_width_all(1)
			badge_sb.set_corner_radius_all(3)
			lvl_badge.add_theme_stylebox_override("panel", badge_sb)
			lvl_badge.position = Vector2(18, 26)
			lvl_badge.custom_minimum_size = Vector2(24, 16)
			lvl_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE

			var badge_lbl := Label.new()
			badge_lbl.text = "★%d" % t_level
			badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			badge_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			badge_lbl.add_theme_font_size_override("font_size", 9)
			badge_lbl.add_theme_color_override("font_color", Color(0.9, 0.7, 1.0))
			lvl_badge.add_child(badge_lbl)
			inner.add_child(lvl_badge)
		else:
			chip_sb.bg_color = Color(0.02, 0.04, 0.08, 0.45)
			chip_sb.set_border_width_all(1)
			chip_sb.border_color = Color(0.2, 0.35, 0.5, 0.3)
			chip.add_theme_stylebox_override("panel", chip_sb)
			chip.tooltip_text = "[Tomo #%d] Vacío" % (slot_idx + 1)

			var empty_lbl := Label.new()
			empty_lbl.text = "—"
			empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			empty_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			empty_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
			empty_lbl.add_theme_font_size_override("font_size", 14)
			empty_lbl.add_theme_color_override("font_color", Color(0.3, 0.4, 0.5, 0.4))
			chip.add_child(empty_lbl)

		tomes_row.add_child(chip)
	eq_container.add_child(tomes_row)

	upgrades_container.add_child(eq_container)

	var div := HSeparator.new()
	upgrades_container.add_child(div)

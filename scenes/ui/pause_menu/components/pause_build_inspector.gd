class_name PauseBuildInspector
extends RefCounted

## PauseBuildInspector — Astra Dream
## Componente desacoplado de renderizado e inspección de Build para PauseMenu.
## Muestra atributos numéricos, ítems agrupados por origen y arsenal/tomos/arcanas equipadas.

const TomeDataScript = preload("res://data/tomes/tome_data.gd")
const WeaponDataScript = preload("res://data/weapons/weapon_data.gd")
const BuildStatsMatrixPresenterScript = preload("res://scenes/ui/pause_menu/components/build_stats_matrix_presenter.gd")
const BuildSynergyCalculatorScript = preload("res://scenes/ui/pause_menu/components/build_synergy_calculator.gd")

const RUN_STATS_CONFIG: Array[Dictionary] = BuildStatsMatrixPresenterScript.RUN_STATS_CONFIG

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
	BuildStatsMatrixPresenterScript.populate_stats(player, stats_container)

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
	BuildSynergyCalculatorScript.populate_equipped_equipment(player, upgrades_container)


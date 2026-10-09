class_name BuildSynergyCalculator
extends RefCounted

## BuildSynergyCalculator.gd
## Calculador y presentador de sinergias del arsenal y grimorios en el menú de pausa.
## Extrae armas y tomos equipados, formateando los chips visuales correspondientes.

const TomeDataScript = preload("res://data/tomes/tome_data.gd")
const WeaponDataScript = preload("res://data/weapons/weapon_data.gd")

static func populate_equipped_equipment(player: Player, upgrades_container: VBoxContainer) -> void:
	if not upgrades_container or not player:
		return

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

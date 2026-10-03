class_name SatelliteShopCardBuilder
extends RefCounted

## SatelliteShopCardBuilder.gd
## Creador procedural de cartas de ítems y armas en la tienda de satélites:
## - Aplica estilos translúcidos cyberpunk según la rareza.
## - Configura badges de estadísticas exactas (+DMG, CD, proc).
## - Conecta hover y focus con el panel de estadísticas para previsualización inmediata.

static func create_item_card_ui(entry: Resource, index: int, shop: SatelliteShop) -> PanelContainer:
	var entry_rarity: Enums.Rarity = entry.get("rarity") if entry.get("rarity") != null else Enums.Rarity.COMMON
	var rarity_color: Color = _get_rarity_color(entry_rarity)

	var player: Player = shop.player
	var is_weapon_upgrade: bool = false
	var current_wp_lvl: int = 1
	if entry is WeaponData and is_instance_valid(player):
		var w_ctrl: WeaponController = player.get_node_or_null("WeaponController") as WeaponController
		if w_ctrl:
			var inst = w_ctrl.get_weapon_instance((entry as WeaponData).weapon_id)
			if inst:
				is_weapon_upgrade = true
				current_wp_lvl = inst.level

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(235, 330)
	card.mouse_filter = Control.MOUSE_FILTER_STOP

	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.06, 0.08, 0.13, 0.92)
	card_style.set_border_width_all(2)
	card_style.border_color = rarity_color * Color(1.0, 1.0, 1.0, 0.6)
	card_style.set_corner_radius_all(8)
	card_style.set_content_margin_all(10.0)
	card.add_theme_stylebox_override("panel", card_style)

	var vbox := VBoxContainer.new()
	vbox.set("theme_override_constants/separation", 6)

	# 1. Hotkey
	var hotkey_lbl := Label.new()
	hotkey_lbl.text = "[ TECLA %d ]" % (index + 1)
	hotkey_lbl.modulate = Color(1.0, 0.9, 0.35, 0.95)
	hotkey_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hotkey_lbl.add_theme_font_size_override("font_size", 11)

	# 2. Title
	var display_title: String = ""
	if is_weapon_upgrade:
		display_title = "[MEJORA] " + (entry as WeaponData).get_display_name() + " (Nv. %d)" % (current_wp_lvl + 1)
	elif entry is WeaponData:
		display_title = "[ARMA] " + (entry as WeaponData).get_display_name()
	elif "item_name" in entry:
		display_title = entry.item_name
		if is_instance_valid(player) and player.inventory and entry.get("max_stacks") != null and entry.max_stacks > 1:
			var cur_s: int = player.inventory.get_item_count(entry.item_id)
			display_title += " (%d/%d)" % [cur_s, entry.max_stacks]
	else:
		display_title = "Mejora Espacial"

	var name_lbl := Label.new()
	name_lbl.text = display_title
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	name_lbl.add_theme_color_override("font_color", rarity_color)
	name_lbl.add_theme_font_size_override("font_size", 13)

	# 3. Icon
	var icon_panel := PanelContainer.new()
	icon_panel.custom_minimum_size = Vector2(56, 56)
	icon_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var icon_style := StyleBoxFlat.new()
	icon_style.bg_color = Color(0.03, 0.04, 0.07, 0.95)
	icon_style.set_border_width_all(2)
	icon_style.border_color = rarity_color
	icon_style.set_corner_radius_all(6)
	icon_panel.add_theme_stylebox_override("panel", icon_style)

	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(44, 44)
	icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if entry.get("icon"):
		icon_rect.texture = entry.get("icon")
		icon_rect.modulate = rarity_color
	icon_panel.add_child(icon_rect)

	# 4. Chips
	var stat_badge_panel := PanelContainer.new()
	var stat_badge_sb := StyleBoxFlat.new()
	stat_badge_sb.set_corner_radius_all(3)
	stat_badge_sb.set_border_width_all(1)

	var stat_badge_lbl := Label.new()
	stat_badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stat_badge_lbl.add_theme_font_size_override("font_size", 10)

	var target_stat_for_hover: StringName = &""
	var stat_delta_for_hover: float = 0.0
	var is_pct_for_hover: bool = false

	if is_weapon_upgrade:
		stat_badge_sb.bg_color = Color(1.0, 0.7, 0.1, 0.18)
		stat_badge_sb.border_color = Color(1.0, 0.8, 0.2, 0.9)
		stat_badge_lbl.text = "★ NV. %d (+1 PROYECTIL)" % [current_wp_lvl + 1]
		stat_badge_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	elif entry is WeaponData:
		var wp: WeaponData = entry as WeaponData
		stat_badge_sb.bg_color = Color(1.0, 0.8, 0.2, 0.12)
		stat_badge_sb.border_color = Color(1.0, 0.8, 0.2, 0.8)
		stat_badge_lbl.text = "⚔ %.0f DMG  |  ⏱ %.2fs CD" % [wp.base_damage, wp.base_cooldown]
		stat_badge_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	elif entry is ItemData:
		var it: ItemData = entry as ItemData
		if it.stat_name != &"":
			target_stat_for_hover = it.stat_name
			stat_delta_for_hover = it.stat_value
			is_pct_for_hover = it.is_percentage

			var sign_s: String = "+" if it.stat_value > 0 else ""
			var val_s: String = ("%s%.0f%%" % [sign_s, it.stat_value * 100.0]) if it.is_percentage else ("%s%.0f" % [sign_s, it.stat_value])

			if it.secondary_stat_name != &"":
				var sec_sign: String = "+" if it.secondary_stat_value > 0 else ""
				var sec_val_s: String = ("%s%.0f%%" % [sec_sign, it.secondary_stat_value * 100.0]) if it.secondary_is_percentage else ("%s%.0f" % [sec_sign, it.secondary_stat_value])
				stat_badge_sb.bg_color = Color(1.0, 0.45, 0.1, 0.18)
				stat_badge_sb.border_color = Color(1.0, 0.55, 0.2, 0.8)
				stat_badge_lbl.text = "⚖ %s / %s" % [val_s, sec_val_s]
				stat_badge_lbl.add_theme_color_override("font_color", Color(1.0, 0.75, 0.4))
			else:
				var col_badge: Color = Color("#00FF9D") if it.stat_value >= 0 else Color("#FF4466")
				stat_badge_sb.bg_color = Color(col_badge.r, col_badge.g, col_badge.b, 0.12)
				stat_badge_sb.border_color = col_badge
				stat_badge_lbl.text = "▲ %s  %s" % [val_s, str(it.stat_name)]
				stat_badge_lbl.add_theme_color_override("font_color", col_badge)
		else:
			if it.tags.has(&"conversion"):
				stat_badge_sb.bg_color = Color(0.7, 0.1, 0.9, 0.18)
				stat_badge_sb.border_color = Color(0.85, 0.3, 1.0, 0.85)
				stat_badge_lbl.text = "⚛ NÚCLEO DE CONVERSIÓN"
				stat_badge_lbl.add_theme_color_override("font_color", Color(0.9, 0.55, 1.0))
			else:
				stat_badge_sb.bg_color = Color(0.1, 0.5, 0.8, 0.15)
				stat_badge_sb.border_color = Color(0.2, 0.7, 1.0, 0.7)
				stat_badge_lbl.text = "⚡ ARTEFACTO PROC"
				stat_badge_lbl.add_theme_color_override("font_color", Color(0.3, 0.85, 1.0))

	stat_badge_panel.add_theme_stylebox_override("panel", stat_badge_sb)
	var b_margin := MarginContainer.new()
	b_margin.add_theme_constant_override("margin_left", 6)
	b_margin.add_theme_constant_override("margin_right", 6)
	b_margin.add_theme_constant_override("margin_top", 3)
	b_margin.add_theme_constant_override("margin_bottom", 3)
	b_margin.add_child(stat_badge_lbl)
	stat_badge_panel.add_child(b_margin)

	# 5. Description
	var desc_lbl := Label.new()
	if is_weapon_upgrade:
		desc_lbl.text = "+1 Proyectil Adicional en todas las salvas activas y pasivas (+25% daño base)."
	else:
		desc_lbl.text = entry.get("description") if entry.get("description") != null else ""
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))

	# 6. Buy Button
	var cost: int = 100 if is_weapon_upgrade else (entry.get("cost") if entry.get("cost") != null and entry.get("cost") > 0 else 50)
	var buy_btn := Button.new()
	buy_btn.text = "Comprar (%d C) [%d]" % [cost, index + 1]
	UIFocusHelper.apply_cyber_focus(buy_btn)

	buy_btn.pressed.connect(func() -> void:
		shop.handle_item_purchase(entry, cost, buy_btn)
	)

	# Hover & Focus connections for stat preview
	if target_stat_for_hover != &"":
		card.mouse_entered.connect(func() -> void:
			shop.highlight_preview_stat(target_stat_for_hover, stat_delta_for_hover, is_pct_for_hover)
		)
		card.mouse_exited.connect(func() -> void:
			shop.clear_stat_highlights()
		)
		buy_btn.focus_entered.connect(func() -> void:
			shop.highlight_preview_stat(target_stat_for_hover, stat_delta_for_hover, is_pct_for_hover)
		)
		buy_btn.focus_exited.connect(func() -> void:
			shop.clear_stat_highlights()
		)

	vbox.add_child(hotkey_lbl)
	vbox.add_child(name_lbl)
	vbox.add_child(icon_panel)
	vbox.add_child(stat_badge_panel)
	vbox.add_child(desc_lbl)
	vbox.add_child(buy_btn)
	card.add_child(vbox)

	if shop.items_container:
		shop.items_container.add_child(card)
	shop.buy_buttons.append(buy_btn)
	return card

static func _get_rarity_color(rarity: Enums.Rarity) -> Color:
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

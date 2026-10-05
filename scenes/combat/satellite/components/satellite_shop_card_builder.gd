class_name SatelliteShopCardBuilder
extends RefCounted

## SatelliteShopCardBuilder.gd
## Creador procedural de cartas de ítems y armas en la tienda de satélites:
## - Aplica estilos translúcidos cyberpunk según la rareza.
## - Configura badges de estadísticas exactas (+DMG, CD, proc).
## - Conecta hover y focus con el panel de estadísticas para previsualización inmediata.

static func create_item_card_ui(entry: Resource, index: int, shop: SatelliteShop) -> Control:
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

	var card := Button.new()
	card.custom_minimum_size = Vector2(0, 118)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.focus_mode = Control.FOCUS_ALL

	# Ocultar texto nativo del botón para preservar el layout procedural
	card.add_theme_color_override("font_color", Color.TRANSPARENT)
	card.add_theme_color_override("font_focus_color", Color.TRANSPARENT)
	card.add_theme_color_override("font_hover_color", Color.TRANSPARENT)
	card.add_theme_color_override("font_pressed_color", Color.TRANSPARENT)
	card.add_theme_color_override("font_disabled_color", Color.TRANSPARENT)

	var base_style := StyleBoxFlat.new()
	base_style.bg_color = Color(0.06, 0.08, 0.13, 0.92)
	base_style.set_border_width_all(2)
	base_style.border_color = rarity_color * Color(1.0, 1.0, 1.0, 0.6)
	base_style.set_corner_radius_all(8)
	base_style.set_content_margin_all(8.0)
	card.add_theme_stylebox_override("normal", base_style)

	var hover_style: StyleBoxFlat = base_style.duplicate() as StyleBoxFlat
	hover_style.bg_color = Color(0.10, 0.14, 0.22, 0.96)
	hover_style.border_color = rarity_color.lightened(0.25)
	card.add_theme_stylebox_override("hover", hover_style)

	var pressed_style: StyleBoxFlat = base_style.duplicate() as StyleBoxFlat
	pressed_style.bg_color = Color(0.04, 0.05, 0.08, 0.98)
	pressed_style.border_color = rarity_color
	card.add_theme_stylebox_override("pressed", pressed_style)

	var focus_style: StyleBoxFlat = base_style.duplicate() as StyleBoxFlat
	focus_style.border_color = Color(0.0, 0.95, 1.0, 0.95)
	focus_style.set_border_width_all(2)
	card.add_theme_stylebox_override("focus", focus_style)

	var disabled_style: StyleBoxFlat = base_style.duplicate() as StyleBoxFlat
	disabled_style.bg_color = Color(0.03, 0.04, 0.06, 0.6)
	disabled_style.border_color = Color(0.3, 0.3, 0.3, 0.4)
	disabled_style.set_border_width_all(1)
	card.add_theme_stylebox_override("disabled", disabled_style)

	var card_margin := MarginContainer.new()
	card_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	card_margin.add_theme_constant_override("margin_left", 14)
	card_margin.add_theme_constant_override("margin_right", 16)
	card_margin.add_theme_constant_override("margin_top", 8)
	card_margin.add_theme_constant_override("margin_bottom", 8)
	card_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(card_margin)

	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.set("theme_override_constants/separation", 14)
	card_margin.add_child(hbox)

	# 1. Icono con marco de rareza
	var icon_panel := PanelContainer.new()
	icon_panel.custom_minimum_size = Vector2(52, 52)
	icon_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN

	var icon_style := StyleBoxFlat.new()
	icon_style.bg_color = Color(0.02, 0.04, 0.07, 0.95)
	icon_style.set_border_width_all(2)
	icon_style.border_color = rarity_color
	icon_style.set_corner_radius_all(6)
	icon_panel.add_theme_stylebox_override("panel", icon_style)

	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(38, 38)
	icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if entry.get("icon"):
		icon_rect.texture = entry.get("icon")
		icon_rect.modulate = rarity_color
	icon_panel.add_child(icon_rect)
	hbox.add_child(icon_panel)

	# 2. Información central extendida (Título, Badge, Descripción en todo el ancho)
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

	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info_vbox.set("theme_override_constants/separation", 4)

	# Fila superior de información: Nombre + Chip de Estadística
	var header_hbox := HBoxContainer.new()
	header_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.set("theme_override_constants/separation", 8)

	var name_lbl := Label.new()
	name_lbl.text = display_title
	name_lbl.add_theme_color_override("font_color", rarity_color)
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_lbl.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	header_hbox.add_child(name_lbl)

	# Chips / Badge de estadística
	var stat_badge_panel := PanelContainer.new()
	var stat_badge_sb := StyleBoxFlat.new()
	stat_badge_sb.set_corner_radius_all(4)
	stat_badge_sb.set_border_width_all(1)

	var stat_badge_lbl := Label.new()
	stat_badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stat_badge_lbl.add_theme_font_size_override("font_size", 9)

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
				stat_badge_lbl.text = "⚛ CONVERSIÓN"
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
	b_margin.add_theme_constant_override("margin_top", 2)
	b_margin.add_theme_constant_override("margin_bottom", 2)
	b_margin.add_child(stat_badge_lbl)
	stat_badge_panel.add_child(b_margin)
	stat_badge_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	header_hbox.add_child(stat_badge_panel)
	info_vbox.add_child(header_hbox)

	var desc_lbl := Label.new()
	if is_weapon_upgrade:
		desc_lbl.text = "+1 Proyectil Adicional en todas las salvas activas y pasivas (+25% daño base)."
	else:
		desc_lbl.text = entry.get("description") if entry.get("description") != null else ""
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 10)
	desc_lbl.add_theme_color_override("font_color", Color(0.82, 0.88, 0.94, 0.92))
	desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_child(desc_lbl)

	hbox.add_child(info_vbox)

	# 3. Columna derecha: Indicador de precio moderno (sin botones legacy)
	var price_vbox := VBoxContainer.new()
	price_vbox.custom_minimum_size = Vector2(100, 0)
	price_vbox.size_flags_horizontal = Control.SIZE_SHRINK_END
	price_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	price_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	price_vbox.set("theme_override_constants/separation", 4)

	var hotkey_lbl := Label.new()
	hotkey_lbl.text = "[ TECLA %d ]" % (index + 1)
	hotkey_lbl.modulate = Color(0.45, 0.82, 1.0, 0.85)
	hotkey_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hotkey_lbl.add_theme_font_size_override("font_size", 10)
	price_vbox.add_child(hotkey_lbl)

	var cost: int = 100 if is_weapon_upgrade else (entry.get("cost") if entry.get("cost") != null and entry.get("cost") > 0 else 50)
	var price_panel := PanelContainer.new()
	var price_sb := StyleBoxFlat.new()
	price_sb.bg_color = Color(0.04, 0.07, 0.12, 0.88)
	price_sb.border_color = Color(1.0, 0.82, 0.2, 0.8)
	price_sb.set_border_width_all(1)
	price_sb.set_corner_radius_all(14)
	price_sb.set_content_margin_all(0.0)
	price_panel.add_theme_stylebox_override("panel", price_sb)
	price_panel.custom_minimum_size = Vector2(96, 30)
	price_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var price_margin := MarginContainer.new()
	price_margin.add_theme_constant_override("margin_left", 8)
	price_margin.add_theme_constant_override("margin_right", 10)
	price_margin.add_theme_constant_override("margin_top", 2)
	price_margin.add_theme_constant_override("margin_bottom", 2)
	price_panel.add_child(price_margin)

	var price_hbox := HBoxContainer.new()
	price_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	price_hbox.set("theme_override_constants/separation", 6)
	price_margin.add_child(price_hbox)

	var credit_icon := TextureRect.new()
	credit_icon.custom_minimum_size = Vector2(20, 20)
	credit_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	credit_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	credit_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var coin_tex: Texture2D = load("res://assets/sprites/ui/credit_coin_icon.png") as Texture2D
	if coin_tex:
		credit_icon.texture = coin_tex
	credit_icon.modulate = Color(1.0, 0.85, 0.2, 1.0)
	price_hbox.add_child(credit_icon)

	var price_lbl := Label.new()
	price_lbl.text = "%d" % cost
	price_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	price_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.25, 1.0))
	price_lbl.add_theme_font_size_override("font_size", 14)
	price_hbox.add_child(price_lbl)

	price_vbox.add_child(price_panel)
	hbox.add_child(price_vbox)

	_set_mouse_filter_ignore_recursive(card_margin)

	card.set_meta(&"cost", cost)
	card.set_meta(&"price_label", price_lbl)
	card.set_meta(&"credit_icon", credit_icon)
	card.set_meta(&"price_panel", price_panel)
	card.set_meta(&"price_stylebox", price_sb)
	card.set_meta(&"hotkey_label", hotkey_lbl)

	# Verificar asequibilidad inicial si el shop tiene créditos
	if "current_credits" in shop:
		update_card_affordability(card, shop.current_credits)

	card.pressed.connect(func() -> void:
		shop.handle_item_purchase(entry, cost, card)
	)

	# Hover & Focus connections for stat preview
	if target_stat_for_hover != &"":
		card.mouse_entered.connect(func() -> void:
			shop.highlight_preview_stat(target_stat_for_hover, stat_delta_for_hover, is_pct_for_hover)
		)
		card.mouse_exited.connect(func() -> void:
			shop.clear_stat_highlights()
		)
		card.focus_entered.connect(func() -> void:
			shop.highlight_preview_stat(target_stat_for_hover, stat_delta_for_hover, is_pct_for_hover)
		)
		card.focus_exited.connect(func() -> void:
			shop.clear_stat_highlights()
		)

	if shop.items_container:
		shop.items_container.add_child(card)
	shop.buy_buttons.append(card)
	return card

static func mark_card_purchased(card: Button) -> void:
	if not is_instance_valid(card):
		return
	card.disabled = true
	card.text = "¡Adquirido!"
	var p_lbl: Label = card.get_meta(&"price_label", null) as Label
	if p_lbl:
		p_lbl.text = "ADQUIRIDO"
		p_lbl.add_theme_color_override("font_color", Color(0.25, 1.0, 0.6, 1.0))
		p_lbl.add_theme_font_size_override("font_size", 10)
	var c_icon: TextureRect = card.get_meta(&"credit_icon", null) as TextureRect
	if c_icon:
		c_icon.visible = false
	var price_panel: PanelContainer = card.get_meta(&"price_panel", null) as PanelContainer
	if price_panel:
		var bought_sb := StyleBoxFlat.new()
		bought_sb.bg_color = Color(0.04, 0.16, 0.08, 0.85)
		bought_sb.border_color = Color(0.2, 0.95, 0.55, 0.9)
		bought_sb.set_border_width_all(1)
		bought_sb.set_corner_radius_all(14)
		bought_sb.set_content_margin_all(0.0)
		price_panel.add_theme_stylebox_override("panel", bought_sb)
	var h_lbl: Label = card.get_meta(&"hotkey_label", null) as Label
	if h_lbl:
		h_lbl.text = "[ COMPRADO ]"
		h_lbl.modulate = Color(0.4, 0.5, 0.45, 0.5)

static func update_card_affordability(card: Button, player_credits: int) -> void:
	if not is_instance_valid(card) or card.disabled:
		return
	var cost: int = int(card.get_meta(&"cost", 0))
	var can_afford: bool = (player_credits >= cost)
	var p_lbl: Label = card.get_meta(&"price_label", null) as Label
	var c_icon: TextureRect = card.get_meta(&"credit_icon", null) as TextureRect
	var p_sb: StyleBoxFlat = card.get_meta(&"price_stylebox", null) as StyleBoxFlat

	if p_lbl:
		p_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.25, 1.0) if can_afford else Color(0.9, 0.45, 0.45, 0.85))
	if c_icon:
		c_icon.modulate = Color(1.0, 0.85, 0.2, 1.0) if can_afford else Color(0.9, 0.45, 0.45, 0.8)
	if p_sb:
		p_sb.border_color = Color(1.0, 0.82, 0.2, 0.85) if can_afford else Color(0.75, 0.3, 0.3, 0.6)

static func _set_mouse_filter_ignore_recursive(node: Node) -> void:
	for child: Node in node.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_mouse_filter_ignore_recursive(child)

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

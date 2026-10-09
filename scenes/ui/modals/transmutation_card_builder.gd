class_name TransmutationCardBuilder
extends RefCounted

## TransmutationCardBuilder.gd
## Generador y estilizado de tarjetas individuales para el catálogo de la Forja Cuántica.

const ItemDataScript = preload("res://data/items/item_data.gd")


static func create_item_card_button(item: ItemData, count: int, has_sacrifice: bool, on_selected: Callable) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 74)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.focus_mode = Control.FOCUS_ALL

	var r_col := get_rarity_color(item.rarity)
	if not has_sacrifice:
		btn.disabled = true
		btn.modulate = Color(0.6, 0.6, 0.6, 0.45)
		btn.tooltip_text = "Sin material de sacrificio disponible (se requiere otro ítem de esta rareza)"
	else:
		btn.tooltip_text = "%s (x%d)\n%s" % [item.item_name, count, item.description]

	var normal_box := StyleBoxFlat.new()
	normal_box.bg_color = Color(0.08, 0.08, 0.14, 0.9) if has_sacrifice else Color(0.05, 0.05, 0.08, 0.7)
	normal_box.border_color = r_col if has_sacrifice else Color(0.3, 0.3, 0.3, 0.5)
	normal_box.set_border_width_all(2)
	normal_box.set_corner_radius_all(6)
	normal_box.set_content_margin_all(8.0)
	btn.add_theme_stylebox_override("normal", normal_box)

	if has_sacrifice:
		var hover_box := normal_box.duplicate() as StyleBoxFlat
		hover_box.bg_color = Color(r_col.r * 0.25, r_col.g * 0.25, r_col.b * 0.25, 0.95)
		hover_box.border_color = Color.WHITE
		btn.add_theme_stylebox_override("hover", hover_box)
		UIFocusHelper.apply_cyber_focus(btn)
		btn.pressed.connect(on_selected)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.set("theme_override_constants/separation", 12)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(hbox)

	# Icon panel
	var icon_panel := PanelContainer.new()
	icon_panel.custom_minimum_size = Vector2(62, 62)
	icon_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var icon_style := StyleBoxFlat.new()
	icon_style.bg_color = Color(0.02, 0.04, 0.08, 0.95)
	icon_style.set_border_width_all(1)
	icon_style.border_color = r_col
	icon_style.set_corner_radius_all(6)
	icon_panel.add_theme_stylebox_override("panel", icon_style)

	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(56, 56)
	icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if item.icon:
		icon_rect.texture = item.icon
	icon_panel.add_child(icon_rect)
	hbox.add_child(icon_panel)

	# Info
	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info_vbox.add_theme_constant_override("separation", 2)
	info_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var title_lbl := Label.new()
	title_lbl.text = "%s  (x%d)" % [item.item_name, count]
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.add_theme_color_override("font_color", r_col if has_sacrifice else Color(0.6, 0.6, 0.6))
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_vbox.add_child(title_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = item.description
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9, 0.85) if has_sacrifice else Color(0.5, 0.5, 0.5, 0.6))
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_vbox.add_child(desc_lbl)
	hbox.add_child(info_vbox)

	# Action label
	var action_lbl := Label.new()
	action_lbl.text = "[ CLONAR ]" if has_sacrifice else "[ BLOQUEADO ]"
	action_lbl.add_theme_font_size_override("font_size", 12)
	action_lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.6) if has_sacrifice else Color(0.8, 0.4, 0.4))
	action_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	action_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(action_lbl)

	return btn


static func get_rarity_short_name(rarity: Enums.Rarity) -> String:
	match rarity:
		Enums.Rarity.COMMON: return "Común"
		Enums.Rarity.UNCOMMON: return "Poco Común"
		Enums.Rarity.RARE: return "Raro"
		Enums.Rarity.EPIC: return "Épico"
		Enums.Rarity.LEGENDARY: return "Legendario"
		_: return "Base"


static func get_rarity_color(rarity: Enums.Rarity) -> Color:
	match rarity:
		Enums.Rarity.COMMON: return Color(0.6, 0.9, 0.6)
		Enums.Rarity.UNCOMMON: return Color(0.3, 0.7, 1.0)
		Enums.Rarity.RARE: return Color(0.8, 0.4, 1.0)
		Enums.Rarity.EPIC: return Color(1.0, 0.3, 0.8)
		Enums.Rarity.LEGENDARY: return Color(1.0, 0.85, 0.2)
		_: return Color.WHITE

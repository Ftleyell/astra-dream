class_name SatelliteShopStyleProvider
extends RefCounted

## SatelliteShopStyleProvider.gd
## Proveedor desacoplado de estilos visuales, paletas de rareza y StyleBoxes
## para el ecosistema de la tienda satelital.

static func apply_panel_styles(panel: Panel, inventory_side_panel: PanelContainer) -> void:
	if panel:
		var shop_style := StyleBoxFlat.new()
		shop_style.bg_color = Color(0.04, 0.06, 0.1, 0.96)
		shop_style.set_border_width_all(2)
		shop_style.border_color = Color(0.2, 0.6, 1.0, 0.7)
		shop_style.set_corner_radius_all(12)
		shop_style.set_content_margin_all(14.0)
		panel.add_theme_stylebox_override("panel", shop_style)

	if inventory_side_panel:
		var inv_style := StyleBoxFlat.new()
		inv_style.bg_color = Color(0.02, 0.03, 0.06, 0.98)
		inv_style.set_border_width_all(1)
		inv_style.border_width_right = 3
		inv_style.border_color = Color(0.2, 0.7, 1.0, 0.9)
		inv_style.set_corner_radius_all(8)
		inv_style.shadow_color = Color(0.0, 0.0, 0.0, 0.6)
		inv_style.shadow_size = 8
		inventory_side_panel.add_theme_stylebox_override("panel", inv_style)

static func get_rarity_color(rarity: Enums.Rarity) -> Color:
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

static func create_card_button_styles(rarity_color: Color) -> Dictionary:
	var base_style := StyleBoxFlat.new()
	base_style.bg_color = Color(0.06, 0.08, 0.13, 0.92)
	base_style.set_border_width_all(2)
	base_style.border_color = rarity_color * Color(1.0, 1.0, 1.0, 0.6)
	base_style.set_corner_radius_all(8)
	base_style.set_content_margin_all(8.0)

	var hover_style: StyleBoxFlat = base_style.duplicate() as StyleBoxFlat
	hover_style.bg_color = Color(0.10, 0.14, 0.22, 0.96)
	hover_style.border_color = rarity_color.lightened(0.25)

	var pressed_style: StyleBoxFlat = base_style.duplicate() as StyleBoxFlat
	pressed_style.bg_color = Color(0.04, 0.05, 0.08, 0.98)
	pressed_style.border_color = rarity_color

	var focus_style: StyleBoxFlat = base_style.duplicate() as StyleBoxFlat
	focus_style.border_color = Color(0.0, 0.95, 1.0, 0.95)
	focus_style.set_border_width_all(2)

	var disabled_style: StyleBoxFlat = base_style.duplicate() as StyleBoxFlat
	disabled_style.bg_color = Color(0.03, 0.04, 0.06, 0.6)
	disabled_style.border_color = Color(0.3, 0.3, 0.3, 0.4)
	disabled_style.set_border_width_all(1)

	return {
		"normal": base_style,
		"hover": hover_style,
		"pressed": pressed_style,
		"focus": focus_style,
		"disabled": disabled_style
	}

static func create_buy_button_styles(rarity_color: Color) -> Dictionary:
	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color(0.08, 0.12, 0.20, 0.92)
	normal_style.set_border_width_all(1)
	normal_style.border_color = rarity_color * Color(1.0, 1.0, 1.0, 0.7)
	normal_style.set_corner_radius_all(6)
	normal_style.set_content_margin_all(4.0)

	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = Color(0.14, 0.22, 0.35, 1.0)
	hover_style.set_border_width_all(2)
	hover_style.border_color = rarity_color
	hover_style.set_corner_radius_all(6)
	hover_style.set_content_margin_all(4.0)

	var focus_style: StyleBoxFlat = hover_style.duplicate() as StyleBoxFlat
	focus_style.border_color = Color(0.0, 0.95, 1.0, 1.0)

	var disabled_style := StyleBoxFlat.new()
	disabled_style.bg_color = Color(0.04, 0.05, 0.08, 0.7)
	disabled_style.border_color = Color(0.3, 0.3, 0.3, 0.5)
	disabled_style.set_border_width_all(1)
	disabled_style.set_corner_radius_all(6)
	disabled_style.set_content_margin_all(4.0)

	return {
		"normal": normal_style,
		"hover": hover_style,
		"focus": focus_style,
		"disabled": disabled_style
	}

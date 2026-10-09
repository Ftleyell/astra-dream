class_name WeaponCardRenderer
extends RefCounted

## WeaponCardRenderer.gd
## Renderizador desacoplado de tarjetas en cuadrícula para WeaponSelectionModal.

const WeaponDataScript = preload("res://data/weapons/weapon_data.gd")

var card_size: Vector2 = Vector2(80, 80)
var icon_size: Vector2 = Vector2(62, 62)

var _card_panels: Dictionary[StringName, PanelContainer] = {}
var _card_badges: Dictionary[StringName, Label] = {}
var _card_buttons: Array[Button] = []
var _card_weapon_map: Dictionary[StringName, WeaponData] = {}


func clear() -> void:
	_card_panels.clear()
	_card_badges.clear()
	_card_buttons.clear()
	_card_weapon_map.clear()


func build_card(weapon: WeaponData, is_active: bool, on_pressed: Callable, on_hovered: Callable) -> PanelContainer:
	var wid: StringName = weapon.weapon_id
	_card_weapon_map[wid] = weapon

	var panel := PanelContainer.new()
	panel.custom_minimum_size = card_size
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)

	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = icon_size
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.texture = weapon.icon
	margin.add_child(icon_rect)

	var badge_lbl := Label.new()
	badge_lbl.add_theme_font_size_override("font_size", 10)
	badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	badge_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	margin.add_child(badge_lbl)

	var btn := Button.new()
	btn.flat = true
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	panel.add_child(btn)

	btn.pressed.connect(on_pressed.bind(wid))
	btn.mouse_entered.connect(on_hovered.bind(weapon))
	btn.focus_entered.connect(on_hovered.bind(weapon))
	UIFocusHelper.apply_cyber_focus(btn, true)

	_card_panels[wid] = panel
	_card_badges[wid] = badge_lbl
	_card_buttons.append(btn)

	refresh_card_visual(wid, is_active)
	return panel


func refresh_card_visual(weapon_id: StringName, is_active: bool) -> void:
	var panel: PanelContainer = _card_panels.get(weapon_id, null)
	var badge: Label = _card_badges.get(weapon_id, null)
	if not panel or not badge:
		return

	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(8)

	if is_active:
		style.bg_color = Color(0.04, 0.09, 0.16, 0.95)
		style.set_border_width_all(2)
		style.border_color = Color(0.15, 0.85, 1.0, 0.9)
		style.shadow_color = Color(0, 0.85, 1, 0.25)
		style.shadow_size = 6
		panel.modulate = Color.WHITE
		badge.text = "✓"
		badge.add_theme_color_override("font_color", Color(0.2, 1.0, 0.8))
	else:
		style.bg_color = Color(0.02, 0.03, 0.05, 0.75)
		style.set_border_width_all(1)
		style.border_color = Color(0.4, 0.25, 0.25, 0.6)
		panel.modulate = Color(0.45, 0.45, 0.45, 0.55)
		badge.text = "✗"
		badge.add_theme_color_override("font_color", Color(0.8, 0.35, 0.35))

	panel.add_theme_stylebox_override("panel", style)


func get_first_button() -> Button:
	if _card_buttons.size() > 0 and is_instance_valid(_card_buttons[0]):
		return _card_buttons[0]
	return null


func get_weapon(weapon_id: StringName) -> WeaponData:
	return _card_weapon_map.get(weapon_id, null)

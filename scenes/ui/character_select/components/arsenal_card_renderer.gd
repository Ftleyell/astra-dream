class_name ArsenalCardRenderer
extends RefCounted

## ArsenalCardRenderer — Astra Dream
## Componente desacoplado de renderizado procedural y gestión visual de tarjetas tácticas.
## Maneja botones, iconografía, indicadores de ban, mallas de foco y estilos StyleBox.

const ArsenalDetailPanelScript = preload("res://scenes/ui/character_select/components/arsenal_detail_panel.gd")

var card_size: Vector2 = Vector2(80, 80)
var icon_size: Vector2 = Vector2(68, 68)
var grid_columns: int = 6

var card_buttons: Array[Button] = []
var card_panels: Dictionary[StringName, PanelContainer] = {}
var card_icons: Dictionary[StringName, TextureRect] = {}
var card_ban_indicators: Dictionary[StringName, Label] = {}

func clear_cards(items_grid: GridContainer) -> void:
	for child in items_grid.get_children():
		child.queue_free()
	card_buttons.clear()
	card_panels.clear()
	card_icons.clear()
	card_ban_indicators.clear()

func create_item_card(
	items_grid: GridContainer,
	item_id: StringName,
	tab_id: int,
	is_banned: bool,
	is_unlocked: bool,
	on_pressed_callable: Callable,
	on_inspected_callable: Callable
) -> Button:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = card_size
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	update_card_panel_style(panel, is_banned, is_unlocked)
	items_grid.add_child(panel)
	card_panels[item_id] = panel

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)

	var icon_rect := TextureRect.new()
	icon_rect.mouse_filter = Control.MOUSE_FILTER_PASS
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.custom_minimum_size = icon_size
	icon_rect.texture = ArsenalDetailPanelScript.resolve_icon_texture(item_id, tab_id)
	margin.add_child(icon_rect)
	card_icons[item_id] = icon_rect

	if is_banned:
		icon_rect.modulate = Color(0.45, 0.25, 0.25, 0.45)
	else:
		icon_rect.modulate = Color(1.0, 1.0, 1.0, 1.0)

	var ban_ind := Label.new()
	ban_ind.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ban_ind.set_anchors_preset(Control.PRESET_FULL_RECT)
	ban_ind.text = "⊘"
	ban_ind.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ban_ind.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ban_ind.add_theme_font_size_override("font_size", 38)
	ban_ind.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25, 0.95))
	ban_ind.visible = is_banned
	panel.add_child(ban_ind)
	card_ban_indicators[item_id] = ban_ind

	var btn := Button.new()
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.flat = true
	btn.focus_mode = Control.FOCUS_ALL if is_unlocked else Control.FOCUS_NONE
	btn.disabled = not is_unlocked
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if is_unlocked else Control.CURSOR_FORBIDDEN
	btn.set_meta("item_id", item_id)
	btn.set_meta("tab_id", tab_id)

	var focus_sb := StyleBoxFlat.new()
	focus_sb.bg_color = Color(0, 0, 0, 0)
	focus_sb.border_color = Color(0.0, 1.0, 0.9, 0.95)
	focus_sb.set_border_width_all(2)
	focus_sb.set_corner_radius_all(8)
	btn.add_theme_stylebox_override("focus", focus_sb)

	btn.pressed.connect(on_pressed_callable.bind(item_id, tab_id))
	btn.mouse_entered.connect(on_inspected_callable.bind(item_id, tab_id))
	btn.focus_entered.connect(on_inspected_callable.bind(item_id, tab_id))

	panel.add_child(btn)
	card_buttons.append(btn)
	return btn

func update_card_visuals(item_id: StringName, is_banned: bool, is_unlocked: bool) -> void:
	if card_panels.has(item_id):
		update_card_panel_style(card_panels[item_id], is_banned, is_unlocked)

	if card_icons.has(item_id):
		var icon_rect: TextureRect = card_icons[item_id]
		if is_banned:
			icon_rect.modulate = Color(0.45, 0.25, 0.25, 0.45)
		else:
			icon_rect.modulate = Color(1.0, 1.0, 1.0, 1.0)

	if card_ban_indicators.has(item_id):
		card_ban_indicators[item_id].visible = is_banned

func update_card_panel_style(panel: PanelContainer, is_banned: bool, is_unlocked: bool) -> void:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(2)
	sb.set_content_margin_all(4)

	if not is_unlocked:
		sb.bg_color = Color(0.015, 0.02, 0.03, 0.7)
		sb.border_color = Color(0.2, 0.25, 0.3, 0.4)
		sb.shadow_size = 0
	elif is_banned:
		sb.bg_color = Color(0.14, 0.02, 0.03, 0.92)
		sb.border_color = Color(0.95, 0.2, 0.2, 0.9)
		sb.shadow_color = Color(0.9, 0.1, 0.1, 0.35)
		sb.shadow_size = 4
	else:
		sb.bg_color = Color(0.03, 0.06, 0.1, 0.92)
		sb.border_color = Color(0.0, 0.75, 0.95, 0.6)
		sb.shadow_color = Color(0.0, 0.6, 0.9, 0.15)
		sb.shadow_size = 4
	panel.add_theme_stylebox_override("panel", sb)

func setup_card_focus_mesh() -> void:
	for i in range(card_buttons.size()):
		var btn := card_buttons[i]
		if not is_instance_valid(btn):
			continue
		var up_idx: int = i - grid_columns
		var down_idx: int = i + grid_columns
		var left_idx: int = i - 1
		var right_idx: int = i + 1

		if up_idx >= 0 and up_idx < card_buttons.size():
			btn.focus_neighbor_top = card_buttons[up_idx].get_path()
		if down_idx >= 0 and down_idx < card_buttons.size():
			btn.focus_neighbor_bottom = card_buttons[down_idx].get_path()
		if left_idx >= 0 and i % grid_columns != 0:
			btn.focus_neighbor_left = card_buttons[left_idx].get_path()
		if right_idx < card_buttons.size() and (i + 1) % grid_columns != 0:
			btn.focus_neighbor_right = card_buttons[right_idx].get_path()

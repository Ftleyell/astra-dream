class_name TomeSelectionDetailPanel
extends RefCounted

## TomeSelectionDetailPanel.gd
## Controlador visual del panel lateral flotante de especificaciones arcanas para TomeSelectionModal.

const TomeDataScript = preload("res://data/tomes/tome_data.gd")

var panel: PanelContainer = null
var icon_rect: TextureRect = null
var title_label: Label = null
var category_label: Label = null
var stats_label: Label = null
var desc_label: Label = null
var status_badge: Label = null
var status_panel: PanelContainer = null

var last_inspected_tome: TomeDataScript = null


func build_panel(parent: Control, side_panel_size: Vector2) -> PanelContainer:
	panel = PanelContainer.new()
	panel.name = "SideDetailPanel"
	panel.custom_minimum_size = side_panel_size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var side_sb := StyleBoxFlat.new()
	side_sb.bg_color = Color(0.025, 0.04, 0.08, 0.96)
	side_sb.border_color = Color(1.0, 0.8, 0.2, 0.75)
	side_sb.set_border_width_all(2)
	side_sb.set_corner_radius_all(10)
	side_sb.shadow_color = Color(1.0, 0.7, 0.1, 0.2)
	side_sb.shadow_size = 12
	panel.add_theme_stylebox_override("panel", side_sb)
	parent.add_child(panel)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	category_label = Label.new()
	category_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	category_label.text = "// REGISTRO ARCANO DE TOMO"
	category_label.add_theme_font_size_override("font_size", 12)
	category_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 0.8))
	vbox.add_child(category_label)

	var icon_box := CenterContainer.new()
	icon_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_box.custom_minimum_size = Vector2(0, 130)
	vbox.add_child(icon_box)

	var icon_bg := PanelContainer.new()
	icon_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_bg.custom_minimum_size = Vector2(120, 120)
	var icon_bg_sb := StyleBoxFlat.new()
	icon_bg_sb.bg_color = Color(0.06, 0.05, 0.03, 0.95)
	icon_bg_sb.border_color = Color(1.0, 0.8, 0.2, 0.6)
	icon_bg_sb.set_border_width_all(2)
	icon_bg_sb.set_corner_radius_all(10)
	icon_bg_sb.shadow_color = Color(1.0, 0.7, 0.1, 0.2)
	icon_bg_sb.shadow_size = 8
	icon_bg.add_theme_stylebox_override("panel", icon_bg_sb)
	icon_box.add_child(icon_bg)

	var icon_margin := MarginContainer.new()
	icon_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_margin.add_theme_constant_override("margin_left", 8)
	icon_margin.add_theme_constant_override("margin_top", 8)
	icon_margin.add_theme_constant_override("margin_right", 8)
	icon_margin.add_theme_constant_override("margin_bottom", 8)
	icon_bg.add_child(icon_margin)

	icon_rect = TextureRect.new()
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.custom_minimum_size = Vector2(100, 100)
	icon_margin.add_child(icon_rect)

	title_label = Label.new()
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.text = "SELECCIONA UN TOMO"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(title_label)

	status_panel = PanelContainer.new()
	status_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_panel.custom_minimum_size = Vector2(0, 30)
	var st_sb := StyleBoxFlat.new()
	st_sb.bg_color = Color(0.12, 0.1, 0.03, 0.8)
	st_sb.border_color = Color(1.0, 0.8, 0.2, 0.6)
	st_sb.set_border_width_all(1)
	st_sb.set_corner_radius_all(6)
	status_panel.add_theme_stylebox_override("panel", st_sb)
	vbox.add_child(status_panel)

	status_badge = Label.new()
	status_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_badge.text = "[ DISPONIBLE EN EL ARSENAL ]"
	status_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_badge.add_theme_font_size_override("font_size", 11)
	status_badge.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	status_panel.add_child(status_badge)

	var sep := HSeparator.new()
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(sep)

	stats_label = Label.new()
	stats_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats_label.text = "Bonificación: -- por nivel"
	stats_label.add_theme_font_size_override("font_size", 12)
	stats_label.add_theme_color_override("font_color", Color(0.35, 1.0, 0.75))
	vbox.add_child(stats_label)

	desc_label = Label.new()
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desc_label.text = "Pasa el cursor o navega con el mando/teclado sobre un tomo para inspeccionar sus efectos y escalado."
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.add_theme_color_override("font_color", Color(0.75, 0.82, 0.92))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(desc_label)

	return panel


func inspect_tome(tome: TomeDataScript, is_active: bool) -> void:
	if not tome:
		return
	last_inspected_tome = tome

	if title_label:
		title_label.text = tome.display_name
	if icon_rect:
		icon_rect.texture = tome.icon
	if stats_label:
		stats_label.text = "Escalado: %s por nivel (Máx Nivel %d)" % [
			tome.get_bonus_description(1),
			tome.max_level
		]
	if desc_label:
		desc_label.text = tome.description

	update_status(is_active)


func update_status(is_active: bool) -> void:
	if not status_badge or not status_panel:
		return

	var st_sb := StyleBoxFlat.new()
	st_sb.set_corner_radius_all(6)
	st_sb.set_border_width_all(1)

	if is_active:
		st_sb.bg_color = Color(0.12, 0.1, 0.03, 0.85)
		st_sb.border_color = Color(1.0, 0.8, 0.2, 0.8)
		status_badge.text = "[ ACTIVO EN POOL // SUBIDAS DE NIVEL ]"
		status_badge.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	else:
		st_sb.bg_color = Color(0.2, 0.05, 0.08, 0.85)
		st_sb.border_color = Color(1.0, 0.35, 0.35, 0.8)
		status_badge.text = "[ EXCLUIDO // NO APARECERÁ EN RUN ]"
		status_badge.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))

	status_panel.add_theme_stylebox_override("panel", st_sb)

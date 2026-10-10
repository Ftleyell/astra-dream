class_name ArsenalBanlistLayoutBuilder
extends RefCounted

## ArsenalBanlistLayoutBuilder.gd
## Constructor procedural de la jerarquía de UI y estilos de ArsenalBanlistModal.
## Desacopla la creación de nodos, paneles y barras de pestañas para mantener el modal compacto.

static func build_ui(
	modal: ArsenalBanlistModal,
	modal_size: Vector2,
	side_panel_size: Vector2,
	grid_columns: int
) -> void:
	# 1. Overlay difuminado
	var dim_overlay := ColorRect.new()
	dim_overlay.name = "DimOverlay"
	dim_overlay.color = Color(0.015, 0.02, 0.04, 0.92)
	dim_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)

	var blur_shader: Shader = preload("res://shaders/screen_blur.gdshader")
	var blur_mat := ShaderMaterial.new()
	blur_mat.shader = blur_shader
	blur_mat.set_shader_parameter("blur_amount", 2.8)
	blur_mat.set_shader_parameter("tint_color", Color(0.015, 0.02, 0.05, 0.85))
	dim_overlay.material = blur_mat
	dim_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	dim_overlay.gui_input.connect(modal._on_dim_overlay_gui_input)
	modal.add_child(dim_overlay)
	modal.dim_overlay = dim_overlay

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	dim_overlay.add_child(center)

	var modal_wrapper := HBoxContainer.new()
	modal_wrapper.name = "ModalWrapper"
	modal_wrapper.mouse_filter = Control.MOUSE_FILTER_PASS
	modal_wrapper.add_theme_constant_override("separation", 18)
	center.add_child(modal_wrapper)

	var left_column := VBoxContainer.new()
	left_column.name = "LeftColumn"
	left_column.mouse_filter = Control.MOUSE_FILTER_PASS
	left_column.add_theme_constant_override("separation", -2)
	left_column.custom_minimum_size = Vector2(modal_size.x, modal_size.y + 36)
	modal_wrapper.add_child(left_column)

	# 2. Barra superior de Pestañas
	var tabs_container := HBoxContainer.new()
	tabs_container.name = "TabsContainer"
	tabs_container.mouse_filter = Control.MOUSE_FILTER_PASS
	tabs_container.add_theme_constant_override("separation", 2)
	tabs_container.custom_minimum_size = Vector2(modal_size.x, 36)
	tabs_container.alignment = BoxContainer.ALIGNMENT_BEGIN
	left_column.add_child(tabs_container)
	modal.tabs_container = tabs_container

	build_tabs_bar(modal, tabs_container, modal_size.x)

	# 3. Panel Principal
	var main_panel := PanelContainer.new()
	main_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	main_panel.custom_minimum_size = modal_size
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.05, 0.09, 0.98)
	sb.border_color = Color(0.0, 0.85, 1.0, 0.85)
	sb.set_border_width_all(2)
	sb.corner_radius_top_left = 0
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10
	sb.shadow_color = Color(0.0, 0.85, 1.0, 0.25)
	sb.shadow_size = 14
	main_panel.add_theme_stylebox_override("panel", sb)
	left_column.add_child(main_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 16)
	main_panel.add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 10)
	margin.add_child(root_vbox)

	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 16)
	root_vbox.add_child(header_row)

	var title_box := VBoxContainer.new()
	title_box.add_theme_constant_override("separation", 2)
	title_box.custom_minimum_size = Vector2(400, 48)
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(title_box)

	var title_label := Label.new()
	title_label.text = "GESTIÓN DE ARSENAL // BANLIST"
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", Color(0.2, 0.9, 1.0))
	title_label.clip_text = true
	title_box.add_child(title_label)
	modal.title_label = title_label

	var subtitle_label := Label.new()
	subtitle_label.text = "Todos los elementos están ACTIVOS por defecto. Puedes bloquear hasta un 40% del conjunto."
	subtitle_label.add_theme_font_size_override("font_size", 12)
	subtitle_label.add_theme_color_override("font_color", Color(0.65, 0.75, 0.9))
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_label.clip_text = true
	title_box.add_child(subtitle_label)
	modal.subtitle_label = subtitle_label

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_SHRINK_END
	header_row.add_child(spacer)

	var counter_box := VBoxContainer.new()
	counter_box.alignment = BoxContainer.ALIGNMENT_CENTER
	counter_box.custom_minimum_size = Vector2(280, 48)
	header_row.add_child(counter_box)

	var counter_label := Label.new()
	counter_label.text = "ACTIVOS: 11 / 11  |  BANEOS: 0 / 4"
	counter_label.add_theme_font_size_override("font_size", 15)
	counter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	counter_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.8))
	counter_box.add_child(counter_label)
	modal.counter_label = counter_label

	var max_rule_label := Label.new()
	max_rule_label.text = "(MÁXIMO 40% BANEOS · MÍNIMO 7 ACTIVOS)"
	max_rule_label.add_theme_font_size_override("font_size", 10)
	max_rule_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	max_rule_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85, 0.75))
	counter_box.add_child(max_rule_label)
	modal.max_rule_label = max_rule_label

	var warning_label := Label.new()
	warning_label.text = ""
	warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning_label.add_theme_font_size_override("font_size", 12)
	warning_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
	warning_label.custom_minimum_size = Vector2(0, 16)
	warning_label.modulate.a = 0.0
	root_vbox.add_child(warning_label)
	modal.warning_label = warning_label

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(modal_size.x - 40, 420)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_vbox.add_child(scroll)

	var items_grid := GridContainer.new()
	items_grid.columns = grid_columns
	items_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	items_grid.add_theme_constant_override("h_separation", 10)
	items_grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(items_grid)
	modal.items_grid = items_grid

	var footer_box := HBoxContainer.new()
	footer_box.alignment = BoxContainer.ALIGNMENT_CENTER
	root_vbox.add_child(footer_box)

	var hint_label := Label.new()
	hint_label.text = "✦ [Q / E] CAMBIAR PESTAÑA | [ESC] O CLIC AFUERA PARA GUARDAR Y CERRAR"
	hint_label.add_theme_font_size_override("font_size", 11)
	hint_label.add_theme_color_override("font_color", Color(0.4, 0.75, 0.9, 0.75))
	footer_box.add_child(hint_label)

	# 4. Panel Lateral de Detalle
	build_side_detail_panel(modal, modal_wrapper, side_panel_size.x, modal_size.y)


static func build_tabs_bar(modal: ArsenalBanlistModal, container: HBoxContainer, modal_width: float) -> void:
	var tabs_count: int = modal.data_ctrl.tabs_info.size()
	var tab_width: float = floor((modal_width - ((tabs_count - 1) * 2.0)) / float(tabs_count))
	for i in range(tabs_count):
		var info: Dictionary = modal.data_ctrl.tabs_info[i]
		var tab_id: int = info["id"]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(tab_width, 36)
		btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		btn.focus_mode = Control.FOCUS_NONE
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.flat = false
		btn.clip_text = true
		btn.text = "%s [0]" % info["name"]
		btn.add_theme_font_size_override("font_size", 10)
		btn.pressed.connect(modal._on_tab_pressed.bind(tab_id))
		container.add_child(btn)
		modal.tab_buttons[tab_id] = btn


static func build_side_detail_panel(modal: ArsenalBanlistModal, parent: Control, side_width: float, modal_height: float) -> void:
	var side_panel := PanelContainer.new()
	side_panel.name = "SideDetailPanel"
	side_panel.custom_minimum_size = Vector2(side_width, modal_height)
	side_panel.size_flags_vertical = Control.SIZE_SHRINK_END
	side_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var side_sb := StyleBoxFlat.new()
	side_sb.bg_color = Color(0.025, 0.04, 0.08, 0.96)
	side_sb.border_color = Color(0.0, 0.8, 1.0, 0.75)
	side_sb.set_border_width_all(2)
	side_sb.set_corner_radius_all(10)
	side_sb.shadow_color = Color(0.0, 0.5, 0.8, 0.25)
	side_sb.shadow_size = 12
	side_panel.add_theme_stylebox_override("panel", side_sb)
	parent.add_child(side_panel)
	modal.side_detail_panel = side_panel

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	side_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var detail_category_label := Label.new()
	detail_category_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_category_label.text = "// ESPECIFICACIÓN TÉCNICA"
	detail_category_label.add_theme_font_size_override("font_size", 11)
	detail_category_label.add_theme_color_override("font_color", Color(0.2, 0.85, 1.0, 0.8))
	vbox.add_child(detail_category_label)
	modal.detail_category_label = detail_category_label

	var icon_box := CenterContainer.new()
	icon_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_box.custom_minimum_size = Vector2(0, 130)
	vbox.add_child(icon_box)

	var icon_bg := PanelContainer.new()
	icon_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_bg.custom_minimum_size = Vector2(120, 120)
	var icon_bg_sb := StyleBoxFlat.new()
	icon_bg_sb.bg_color = Color(0.04, 0.07, 0.13, 0.95)
	icon_bg_sb.border_color = Color(0.0, 0.85, 1.0, 0.7)
	icon_bg_sb.set_border_width_all(2)
	icon_bg_sb.set_corner_radius_all(10)
	icon_bg_sb.shadow_color = Color(0.0, 0.85, 1.0, 0.25)
	icon_bg_sb.shadow_size = 10
	icon_bg.add_theme_stylebox_override("panel", icon_bg_sb)
	icon_box.add_child(icon_bg)

	var icon_margin := MarginContainer.new()
	icon_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_margin.add_theme_constant_override("margin_left", 8)
	icon_margin.add_theme_constant_override("margin_top", 8)
	icon_margin.add_theme_constant_override("margin_right", 8)
	icon_margin.add_theme_constant_override("margin_bottom", 8)
	icon_bg.add_child(icon_margin)

	var detail_icon_rect := TextureRect.new()
	detail_icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	detail_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	detail_icon_rect.custom_minimum_size = Vector2(104, 104)
	icon_margin.add_child(detail_icon_rect)
	modal.detail_icon_rect = detail_icon_rect

	var detail_title_label := Label.new()
	detail_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_title_label.text = "SELECCIONA UN ELEMENTO"
	detail_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_title_label.add_theme_font_size_override("font_size", 17)
	detail_title_label.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0))
	detail_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(detail_title_label)
	modal.detail_title_label = detail_title_label

	var detail_status_panel := PanelContainer.new()
	detail_status_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st_sb := StyleBoxFlat.new()
	st_sb.bg_color = Color(0.02, 0.12, 0.1, 0.85)
	st_sb.border_color = Color(0.2, 0.9, 0.6, 0.7)
	st_sb.set_border_width_all(1)
	st_sb.set_corner_radius_all(6)
	detail_status_panel.add_theme_stylebox_override("panel", st_sb)
	vbox.add_child(detail_status_panel)
	modal.detail_status_panel = detail_status_panel

	var st_margin := MarginContainer.new()
	st_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	st_margin.add_theme_constant_override("margin_left", 8)
	st_margin.add_theme_constant_override("margin_top", 4)
	st_margin.add_theme_constant_override("margin_right", 8)
	st_margin.add_theme_constant_override("margin_bottom", 4)
	detail_status_panel.add_child(st_margin)

	var detail_status_badge := Label.new()
	detail_status_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_status_badge.text = "ACTIVO EN COMBATE"
	detail_status_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_status_badge.add_theme_font_size_override("font_size", 11)
	detail_status_badge.add_theme_color_override("font_color", Color(0.3, 1.0, 0.7))
	st_margin.add_child(detail_status_badge)
	modal.detail_status_badge = detail_status_badge

	var detail_rarity_label := Label.new()
	detail_rarity_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_rarity_label.text = ""
	detail_rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_rarity_label.add_theme_font_size_override("font_size", 11)
	detail_rarity_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	vbox.add_child(detail_rarity_label)
	modal.detail_rarity_label = detail_rarity_label

	var div := HSeparator.new()
	div.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var div_sb := StyleBoxLine.new()
	div_sb.color = Color(0.1, 0.5, 0.7, 0.4)
	div_sb.thickness = 1
	div.add_theme_stylebox_override("separator", div_sb)
	vbox.add_child(div)

	var desc_scroll := ScrollContainer.new()
	desc_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	desc_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(desc_scroll)

	var desc_vbox := VBoxContainer.new()
	desc_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desc_vbox.add_theme_constant_override("separation", 8)
	desc_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_scroll.add_child(desc_vbox)

	var detail_stats_label := Label.new()
	detail_stats_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_stats_label.text = ""
	detail_stats_label.add_theme_font_size_override("font_size", 12)
	detail_stats_label.add_theme_color_override("font_color", Color(0.3, 0.95, 0.8))
	detail_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_vbox.add_child(detail_stats_label)
	modal.detail_stats_label = detail_stats_label

	var detail_desc_label := Label.new()
	detail_desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_desc_label.text = "Pasa el cursor sobre un elemento de la cuadrícula táctica para analizar sus telemetrías."
	detail_desc_label.add_theme_font_size_override("font_size", 11)
	detail_desc_label.add_theme_color_override("font_color", Color(0.75, 0.82, 0.95))
	detail_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_vbox.add_child(detail_desc_label)
	modal.detail_desc_label = detail_desc_label

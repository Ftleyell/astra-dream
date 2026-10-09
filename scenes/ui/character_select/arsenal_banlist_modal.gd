class_name ArsenalBanlistModal
extends CanvasLayer

## ArsenalBanlistModal.gd
## Modal unificado de gestión de Arsenal y Exclusiones (Banlist) para Astra Dream.
## Orquestador modular reducido (<200 líneas) apoyado en:
## - ArsenalBanlistDataController (reglas del 40%, conteos y persistencia)
## - ArsenalCardRenderer (botones, estilos de cartas e indicadores de ban)
## - ArsenalDetailPanel (renderizado e inspección del panel lateral)

const DataControllerScript = preload("res://scenes/ui/character_select/components/arsenal_banlist_data_controller.gd")
const CardRendererScript = preload("res://scenes/ui/character_select/components/arsenal_card_renderer.gd")
const DetailPanelScript = preload("res://scenes/ui/character_select/components/arsenal_detail_panel.gd")

enum TabCategory {
	WEAPONS,
	TOMES,
	OVERLOADS,
	REACTIVE_PROCS,
	UTILITY_CORES,
	STRATEGIC_MODULES,
	CHEST_ITEMS
}

@export_group("Dimensiones de Ventana")
@export var modal_size: Vector2 = Vector2(760, 580)
@export var side_panel_size: Vector2 = Vector2(340, 580)
@export var card_size: Vector2 = Vector2(80, 80)
@export var icon_size: Vector2 = Vector2(68, 68)
@export var grid_columns: int = 6

signal closed()
signal banlist_updated(char_id: StringName, tab_category: int)

var is_open: bool = false
var current_character_id: StringName = &"nova"
var active_tab: TabCategory = TabCategory.WEAPONS

# Submódulos desacoplados
var _data_ctrl: RefCounted = null
var _card_renderer: RefCounted = null
var _detail_panel: RefCounted = null

# Contenedores principales
var dim_overlay: ColorRect = null
var tabs_container: HBoxContainer = null
var title_label: Label = null
var subtitle_label: Label = null
var counter_label: Label = null
var max_rule_label: Label = null
var warning_label: Label = null
var items_grid: GridContainer = null

# Panel lateral de inspección
var side_detail_panel: PanelContainer = null
var detail_icon_rect: TextureRect = null
var detail_title_label: Label = null
var detail_category_label: Label = null
var detail_rarity_label: Label = null
var detail_stats_label: Label = null
var detail_desc_label: Label = null
var detail_status_badge: Label = null
var detail_status_panel: PanelContainer = null

var _tab_buttons: Dictionary[int, Button] = {}
var _warning_tween: Tween = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 126
	_data_ctrl = DataControllerScript.new(current_character_id)
	_card_renderer = CardRendererScript.new()
	_card_renderer.card_size = card_size
	_card_renderer.icon_size = icon_size
	_card_renderer.grid_columns = grid_columns
	_detail_panel = DetailPanelScript.new()
	_build_ui()
	hide()


func _build_ui() -> void:
	dim_overlay = ColorRect.new()
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
	dim_overlay.gui_input.connect(_on_dim_overlay_gui_input)
	add_child(dim_overlay)

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

	tabs_container = HBoxContainer.new()
	tabs_container.name = "TabsContainer"
	tabs_container.mouse_filter = Control.MOUSE_FILTER_PASS
	tabs_container.add_theme_constant_override("separation", 2)
	tabs_container.custom_minimum_size = Vector2(modal_size.x, 36)
	tabs_container.alignment = BoxContainer.ALIGNMENT_BEGIN
	left_column.add_child(tabs_container)
	_build_tabs_bar()

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

	title_label = Label.new()
	title_label.text = "GESTIÓN DE ARSENAL // BANLIST"
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", Color(0.2, 0.9, 1.0))
	title_label.clip_text = true
	title_box.add_child(title_label)

	subtitle_label = Label.new()
	subtitle_label.text = "Todos los elementos están ACTIVOS por defecto. Puedes bloquear hasta un 40% del conjunto."
	subtitle_label.add_theme_font_size_override("font_size", 12)
	subtitle_label.add_theme_color_override("font_color", Color(0.65, 0.75, 0.9))
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_label.clip_text = true
	title_box.add_child(subtitle_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_SHRINK_END
	header_row.add_child(spacer)

	var counter_box := VBoxContainer.new()
	counter_box.alignment = BoxContainer.ALIGNMENT_CENTER
	counter_box.custom_minimum_size = Vector2(280, 48)
	header_row.add_child(counter_box)

	counter_label = Label.new()
	counter_label.text = "ACTIVOS: 11 / 11  |  BANEOS: 0 / 4"
	counter_label.add_theme_font_size_override("font_size", 15)
	counter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	counter_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.8))
	counter_box.add_child(counter_label)

	max_rule_label = Label.new()
	max_rule_label.text = "(MÁXIMO 40% BANEOS · MÍNIMO 7 ACTIVOS)"
	max_rule_label.add_theme_font_size_override("font_size", 10)
	max_rule_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	max_rule_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85, 0.75))
	counter_box.add_child(max_rule_label)

	warning_label = Label.new()
	warning_label.text = ""
	warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning_label.add_theme_font_size_override("font_size", 12)
	warning_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
	warning_label.custom_minimum_size = Vector2(0, 16)
	warning_label.modulate.a = 0.0
	root_vbox.add_child(warning_label)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(modal_size.x - 40, 420)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_vbox.add_child(scroll)

	items_grid = GridContainer.new()
	items_grid.columns = grid_columns
	items_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	items_grid.add_theme_constant_override("h_separation", 10)
	items_grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(items_grid)

	var footer_box := HBoxContainer.new()
	footer_box.alignment = BoxContainer.ALIGNMENT_CENTER
	root_vbox.add_child(footer_box)

	var hint_label := Label.new()
	hint_label.text = "✦ [Q / E] CAMBIAR PESTAÑA | [ESC] O CLIC AFUERA PARA GUARDAR Y CERRAR"
	hint_label.add_theme_font_size_override("font_size", 11)
	hint_label.add_theme_color_override("font_color", Color(0.4, 0.75, 0.9, 0.75))
	footer_box.add_child(hint_label)

	_build_side_detail_panel(modal_wrapper)


func _build_tabs_bar() -> void:
	var tabs_count: int = _data_ctrl.tabs_info.size()
	var tab_width: float = floor((modal_size.x - ((tabs_count - 1) * 2.0)) / float(tabs_count))
	for i in range(tabs_count):
		var info: Dictionary = _data_ctrl.tabs_info[i]
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
		btn.pressed.connect(_on_tab_pressed.bind(tab_id))
		tabs_container.add_child(btn)
		_tab_buttons[tab_id] = btn


func _build_side_detail_panel(parent: Control) -> void:
	side_detail_panel = PanelContainer.new()
	side_detail_panel.name = "SideDetailPanel"
	side_detail_panel.custom_minimum_size = Vector2(side_panel_size.x, modal_size.y)
	side_detail_panel.size_flags_vertical = Control.SIZE_SHRINK_END
	side_detail_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var side_sb := StyleBoxFlat.new()
	side_sb.bg_color = Color(0.025, 0.04, 0.08, 0.96)
	side_sb.border_color = Color(0.0, 0.8, 1.0, 0.75)
	side_sb.set_border_width_all(2)
	side_sb.set_corner_radius_all(10)
	side_sb.shadow_color = Color(0.0, 0.5, 0.8, 0.25)
	side_sb.shadow_size = 12
	side_detail_panel.add_theme_stylebox_override("panel", side_sb)
	parent.add_child(side_detail_panel)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	side_detail_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	detail_category_label = Label.new()
	detail_category_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_category_label.text = "// ESPECIFICACIÓN TÉCNICA"
	detail_category_label.add_theme_font_size_override("font_size", 11)
	detail_category_label.add_theme_color_override("font_color", Color(0.2, 0.85, 1.0, 0.8))
	vbox.add_child(detail_category_label)

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

	detail_icon_rect = TextureRect.new()
	detail_icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	detail_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	detail_icon_rect.custom_minimum_size = Vector2(104, 104)
	icon_margin.add_child(detail_icon_rect)

	detail_title_label = Label.new()
	detail_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_title_label.text = "SELECCIONA UN ELEMENTO"
	detail_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_title_label.add_theme_font_size_override("font_size", 17)
	detail_title_label.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0))
	detail_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(detail_title_label)

	detail_status_panel = PanelContainer.new()
	detail_status_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st_sb := StyleBoxFlat.new()
	st_sb.bg_color = Color(0.02, 0.12, 0.1, 0.85)
	st_sb.border_color = Color(0.2, 0.9, 0.6, 0.7)
	st_sb.set_border_width_all(1)
	st_sb.set_corner_radius_all(6)
	detail_status_panel.add_theme_stylebox_override("panel", st_sb)
	vbox.add_child(detail_status_panel)

	var st_margin := MarginContainer.new()
	st_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	st_margin.add_theme_constant_override("margin_left", 8)
	st_margin.add_theme_constant_override("margin_top", 4)
	st_margin.add_theme_constant_override("margin_right", 8)
	st_margin.add_theme_constant_override("margin_bottom", 4)
	detail_status_panel.add_child(st_margin)

	detail_status_badge = Label.new()
	detail_status_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_status_badge.text = "ACTIVO EN COMBATE"
	detail_status_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_status_badge.add_theme_font_size_override("font_size", 11)
	detail_status_badge.add_theme_color_override("font_color", Color(0.3, 1.0, 0.7))
	st_margin.add_child(detail_status_badge)

	detail_rarity_label = Label.new()
	detail_rarity_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_rarity_label.text = ""
	detail_rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_rarity_label.add_theme_font_size_override("font_size", 11)
	detail_rarity_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	vbox.add_child(detail_rarity_label)

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

	detail_stats_label = Label.new()
	detail_stats_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_stats_label.text = ""
	detail_stats_label.add_theme_font_size_override("font_size", 12)
	detail_stats_label.add_theme_color_override("font_color", Color(0.3, 0.95, 0.8))
	detail_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_vbox.add_child(detail_stats_label)

	detail_desc_label = Label.new()
	detail_desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_desc_label.text = "Pasa el cursor sobre un elemento de la cuadrícula táctica para analizar sus telemetrías."
	detail_desc_label.add_theme_font_size_override("font_size", 11)
	detail_desc_label.add_theme_color_override("font_color", Color(0.75, 0.82, 0.95))
	detail_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_vbox.add_child(detail_desc_label)

	_detail_panel.bind_nodes(
		detail_icon_rect,
		detail_title_label,
		detail_category_label,
		detail_rarity_label,
		detail_stats_label,
		detail_desc_label,
		detail_status_badge,
		detail_status_panel
	)


func open_modal(character_id: StringName = &"nova", default_tab: int = 0) -> void:
	current_character_id = character_id
	if _data_ctrl:
		_data_ctrl.character_id = character_id
	is_open = true
	active_tab = clampi(default_tab, 0, _data_ctrl.tabs_info.size() - 1) as TabCategory
	show()
	_refresh_all_tab_badges()
	_load_active_tab()
	if not _card_renderer.card_buttons.is_empty() and is_instance_valid(_card_renderer.card_buttons[0]):
		_card_renderer.card_buttons[0].grab_focus()


func close_modal() -> void:
	if not is_open:
		return
	is_open = false
	hide()
	closed.emit()


func _on_dim_overlay_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close_modal()


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return

	if event.is_action_pressed("ui_cancel"):
		close_modal()
		get_viewport().set_input_as_handled()
		return

	var tabs_count: int = _data_ctrl.tabs_info.size()
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Q:
			var prev_tab: int = (int(active_tab) - 1 + tabs_count) % tabs_count
			_on_tab_pressed(prev_tab)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_E:
			var next_tab: int = (int(active_tab) + 1) % tabs_count
			_on_tab_pressed(next_tab)
			get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_LEFT_SHOULDER:
			var prev_tab: int = (int(active_tab) - 1 + tabs_count) % tabs_count
			_on_tab_pressed(prev_tab)
			get_viewport().set_input_as_handled()
		elif event.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			var next_tab: int = (int(active_tab) + 1) % tabs_count
			_on_tab_pressed(next_tab)
			get_viewport().set_input_as_handled()


func _on_tab_pressed(tab_id: int) -> void:
	active_tab = tab_id as TabCategory
	_refresh_all_tab_badges()
	_load_active_tab()
	if not _card_renderer.card_buttons.is_empty() and is_instance_valid(_card_renderer.card_buttons[0]):
		_card_renderer.card_buttons[0].grab_focus()


func get_max_bans_for_tab(tab_id: int) -> int:
	return _data_ctrl.get_max_bans_for_tab(tab_id)


func get_banned_ids_for_tab(tab_id: int) -> Array[StringName]:
	return _data_ctrl.get_banned_ids_for_tab(tab_id)


func is_item_banned(tab_id: int, item_id: StringName) -> bool:
	return _data_ctrl.is_item_banned(tab_id, item_id)


func _refresh_all_tab_badges() -> void:
	for i in range(_data_ctrl.tabs_info.size()):
		var info: Dictionary = _data_ctrl.tabs_info[i]
		var tab_id: int = info["id"]
		var btn: Button = _tab_buttons.get(tab_id)
		if not btn:
			continue

		var total_items: int = (info["item_ids"] as Array).size()
		var banned: Array[StringName] = _data_ctrl.get_banned_ids_for_tab(tab_id)
		var is_active_tab: bool = (tab_id == int(active_tab))

		if banned.is_empty():
			btn.text = "%s (%d)" % [info["name"], total_items]
		else:
			btn.text = "%s (%d) [%d⊘]" % [info["name"], total_items - banned.size(), banned.size()]

		var tab_sb := StyleBoxFlat.new()
		tab_sb.corner_radius_top_left = 8
		tab_sb.corner_radius_top_right = 8
		tab_sb.corner_radius_bottom_left = 0
		tab_sb.corner_radius_bottom_right = 0
		tab_sb.content_margin_top = 7
		tab_sb.content_margin_bottom = 7
		tab_sb.content_margin_left = 4
		tab_sb.content_margin_right = 4

		if is_active_tab:
			tab_sb.bg_color = Color(0.03, 0.05, 0.09, 0.98)
			tab_sb.border_color = info["accent"]
			tab_sb.border_width_top = 2
			tab_sb.border_width_left = 2
			tab_sb.border_width_right = 2
			tab_sb.border_width_bottom = 0
			btn.add_theme_color_override("font_color", info["accent"])
			btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
			btn.z_index = 2
		else:
			tab_sb.bg_color = Color(0.015, 0.025, 0.04, 0.8)
			tab_sb.border_color = Color(0.18, 0.28, 0.38, 0.6)
			tab_sb.border_width_top = 1
			tab_sb.border_width_left = 1
			tab_sb.border_width_right = 1
			tab_sb.border_width_bottom = 1
			btn.add_theme_color_override("font_color", Color(0.55, 0.65, 0.75))
			btn.add_theme_color_override("font_hover_color", Color(0.9, 0.95, 1.0))
			btn.z_index = 1

		btn.add_theme_stylebox_override("normal", tab_sb)
		btn.add_theme_stylebox_override("hover", tab_sb)
		btn.add_theme_stylebox_override("pressed", tab_sb)
		btn.add_theme_stylebox_override("focus", tab_sb)


func _load_active_tab() -> void:
	var tab_idx: int = int(active_tab)
	var info: Dictionary = _data_ctrl.get_tab_info(tab_idx)
	title_label.text = info["full_title"]
	subtitle_label.text = info["subtitle"]
	title_label.add_theme_color_override("font_color", info["accent"])

	var total_items: int = (info["item_ids"] as Array).size()
	var banned_ids: Array[StringName] = _data_ctrl.get_banned_ids_for_tab(tab_idx)
	var max_bans: int = _data_ctrl.get_max_bans_for_tab(tab_idx)
	var active_count: int = total_items - banned_ids.size()
	var min_active: int = total_items - max_bans

	counter_label.text = "ACTIVOS: %d / %d  |  BANEOS: %d / %d" % [active_count, total_items, banned_ids.size(), max_bans]
	max_rule_label.text = "(MÁXIMO 40%% BANEOS · MÍNIMO %d ACTIVOS EN COMBATE)" % min_active

	_card_renderer.clear_cards(items_grid)
	var all_ids: Array = info["item_ids"]
	for item_id in all_ids:
		var is_banned: bool = _data_ctrl.is_item_banned(tab_idx, item_id)
		var is_unlocked: bool = _data_ctrl.check_item_unlocked(tab_idx, item_id)
		_card_renderer.create_item_card(
			items_grid,
			item_id,
			tab_idx,
			is_banned,
			is_unlocked,
			Callable(self, "_on_card_pressed"),
			Callable(self, "_on_card_inspected")
		)

	_card_renderer.setup_card_focus_mesh()

	if not _card_renderer.card_buttons.is_empty():
		_inspect_item(_card_renderer.card_buttons[0].get_meta("item_id"), tab_idx)


func _on_card_pressed(item_id: StringName, tab_id: int) -> void:
	var ok: bool = _data_ctrl.toggle_item_ban(tab_id, item_id)
	if not ok:
		_deny_ban_action(_data_ctrl.get_max_bans_for_tab(tab_id))
		return

	_play_sfx("ui_click")
	_refresh_all_tab_badges()

	var is_banned: bool = _data_ctrl.is_item_banned(tab_id, item_id)
	var is_unlocked: bool = _data_ctrl.check_item_unlocked(tab_id, item_id)
	_card_renderer.update_card_visuals(item_id, is_banned, is_unlocked)

	var info: Dictionary = _data_ctrl.get_tab_info(tab_id)
	var total_items: int = (info["item_ids"] as Array).size()
	var banned_ids: Array[StringName] = _data_ctrl.get_banned_ids_for_tab(tab_id)
	var max_bans: int = _data_ctrl.get_max_bans_for_tab(tab_id)
	counter_label.text = "ACTIVOS: %d / %d  |  BANEOS: %d / %d" % [total_items - banned_ids.size(), total_items, banned_ids.size(), max_bans]

	_inspect_item(item_id, tab_id)
	banlist_updated.emit(current_character_id, tab_id)


func _deny_ban_action(max_bans: int) -> void:
	_play_sfx("ui_error")
	warning_label.text = "⚠️ LÍMITE ALCANZADO: MÁXIMO %d EXCLUSIONES PERMITIDAS (40%% DEL POOL)" % max_bans

	if _warning_tween and _warning_tween.is_valid():
		_warning_tween.kill()

	_warning_tween = create_tween()
	_warning_tween.tween_property(warning_label, "modulate:a", 1.0, 0.1)
	_warning_tween.tween_property(warning_label, "modulate:a", 1.0, 1.8)
	_warning_tween.tween_property(warning_label, "modulate:a", 0.0, 0.4)

	var t := create_tween()
	t.tween_property(counter_label, "modulate", Color(1.0, 0.3, 0.3), 0.1)
	t.tween_property(counter_label, "modulate", Color(1.0, 1.0, 1.0), 0.3)


func _on_card_inspected(item_id: StringName, tab_id: int) -> void:
	_inspect_item(item_id, tab_id)


func _inspect_item(item_id: StringName, tab_id: int) -> void:
	var info: Dictionary = _data_ctrl.get_tab_info(tab_id)
	var is_banned: bool = _data_ctrl.is_item_banned(tab_id, item_id)
	var is_unlocked: bool = _data_ctrl.check_item_unlocked(tab_id, item_id)
	_detail_panel.inspect_item(item_id, tab_id, info, is_banned, is_unlocked)


func _play_sfx(sfx_name: String) -> void:
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx(sfx_name)

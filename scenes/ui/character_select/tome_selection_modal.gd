class_name TomeSelectionModal
extends CanvasLayer

## TomeSelectionModal.gd
## Modal de selección y loadout de Tomos Arcanos de Atributos por Heroína/Piloto.
## Permite elegir qué tomos de estadísticas aparecerán durante las subidas de nivel.
## Exige un mínimo obligatorio de 6 tomos activos para evitar monopolios o exploits de pool reducida.

const TomeCatalog = preload("res://data/tomes/tome_catalog.gd")
const TomeDataScript = preload("res://data/tomes/tome_data.gd")

const MIN_ACTIVE_TOMES: int = 6

@export_group("Dimensiones de Ventana")
@export var modal_size: Vector2 = Vector2(660, 620)
@export var margin_horizontal: int = 24
@export var margin_vertical: int = 20
@export var content_separation: int = 14

@export_group("Cuadrícula de Tomos")
@export var grid_columns: int = 6
@export var grid_h_separation: int = 12
@export var grid_v_separation: int = 12

@export_group("Dimensiones de Tarjetas")
@export var card_size: Vector2 = Vector2(80, 80)
@export var icon_size: Vector2 = Vector2(62, 62)

@export_group("Dimensiones de Panel Lateral")
@export var side_panel_size: Vector2 = Vector2(340, 620)

@export_group("Reglas de Pool")
@export var min_active_tomes: int = 6

signal closed()
signal tomes_updated(char_id: StringName, active_tomes: Array[StringName])

var is_open: bool = false
var current_character_id: StringName = &"nova"
var active_tome_ids: Array[StringName] = []

var dim_overlay: ColorRect = null
var title_label: Label = null
var subtitle_label: Label = null
var counter_label: Label = null
var min_rule_label: Label = null
var warning_label: Label = null
var tomes_grid: GridContainer = null

# Panel lateral flotante de descripción
var side_detail_panel: PanelContainer = null
var detail_icon_rect: TextureRect = null
var detail_title_label: Label = null
var detail_category_label: Label = null
var detail_stats_label: Label = null
var detail_desc_label: Label = null
var detail_status_badge: Label = null
var detail_status_panel: PanelContainer = null

var _card_panels: Dictionary[StringName, PanelContainer] = {}
var _card_badges: Dictionary[StringName, Label] = {}
var _card_buttons: Array[Button] = []
var _card_tome_map: Dictionary[StringName, TomeDataScript] = {}
var _warning_tween: Tween = null
var _last_inspected_tome: TomeDataScript = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 126
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
	modal_wrapper.add_theme_constant_override("separation", 20)
	center.add_child(modal_wrapper)

	var panel := PanelContainer.new()
	panel.name = "MainGridPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.custom_minimum_size = modal_size
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.05, 0.09, 0.98)
	sb.border_color = Color(0, 0.85, 1, 0.85)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.shadow_color = Color(0, 0.85, 1, 0.25)
	sb.shadow_size = 14
	panel.add_theme_stylebox_override("panel", sb)
	modal_wrapper.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", margin_horizontal)
	margin.add_theme_constant_override("margin_top", margin_vertical)
	margin.add_theme_constant_override("margin_right", margin_horizontal)
	margin.add_theme_constant_override("margin_bottom", margin_vertical)
	panel.add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", content_separation)
	margin.add_child(root_vbox)

	# 1. Header Row
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 16)
	root_vbox.add_child(header_row)

	var title_box := VBoxContainer.new()
	title_box.add_theme_constant_override("separation", 2)
	header_row.add_child(title_box)

	title_label = Label.new()
	title_label.text = "BIBLIOTECA DE TOMOS // LOADOUT DE ATRIBUTOS"
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.add_theme_color_override("font_color", Color(0.2, 0.9, 1.0))
	title_box.add_child(title_label)

	subtitle_label = Label.new()
	subtitle_label.text = "Selecciona qué tomos de estadísticas podrán aparecer durante el combate."
	subtitle_label.add_theme_font_size_override("font_size", 13)
	subtitle_label.add_theme_color_override("font_color", Color(0.65, 0.75, 0.9))
	title_box.add_child(subtitle_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(spacer)

	var counter_box := VBoxContainer.new()
	counter_box.alignment = BoxContainer.ALIGNMENT_CENTER
	header_row.add_child(counter_box)

	counter_label = Label.new()
	counter_label.add_theme_font_size_override("font_size", 16)
	counter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	counter_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.8))
	counter_box.add_child(counter_label)

	min_rule_label = Label.new()
	min_rule_label.text = "(MÍNIMO %d ACTIVOS OBLIGATORIOS)" % min_active_tomes
	min_rule_label.add_theme_font_size_override("font_size", 11)
	min_rule_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	min_rule_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85, 0.75))
	counter_box.add_child(min_rule_label)

	# 2. Warning Label (Oculto / Flasheable)
	warning_label = Label.new()
	warning_label.text = ""
	warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning_label.add_theme_font_size_override("font_size", 13)
	warning_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
	warning_label.modulate.a = 0.0
	root_vbox.add_child(warning_label)

	# 3. Scrollable Grid of Tomes
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_vbox.add_child(scroll)

	tomes_grid = GridContainer.new()
	tomes_grid.columns = grid_columns
	tomes_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tomes_grid.add_theme_constant_override("h_separation", grid_h_separation)
	tomes_grid.add_theme_constant_override("v_separation", grid_v_separation)
	scroll.add_child(tomes_grid)

	# 4. Actions Row (Footer Hint)
	var footer_box := HBoxContainer.new()
	footer_box.alignment = BoxContainer.ALIGNMENT_CENTER
	root_vbox.add_child(footer_box)

	var hint_label := Label.new()
	hint_label.text = "✦ [ESC] O CLIC EN EL FONDO PARA GUARDAR Y CERRAR"
	hint_label.add_theme_font_size_override("font_size", 12)
	hint_label.add_theme_color_override("font_color", Color(0.4, 0.75, 0.9, 0.75))
	footer_box.add_child(hint_label)

	# 5. Panel Lateral Flotante de Detalles a la Derecha (No navegable)
	_build_side_detail_panel(modal_wrapper)


func _build_side_detail_panel(parent: Control) -> void:
	side_detail_panel = PanelContainer.new()
	side_detail_panel.name = "SideDetailPanel"
	side_detail_panel.custom_minimum_size = side_panel_size
	side_detail_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var side_sb := StyleBoxFlat.new()
	side_sb.bg_color = Color(0.025, 0.04, 0.08, 0.96)
	side_sb.border_color = Color(1.0, 0.8, 0.2, 0.75)
	side_sb.set_border_width_all(2)
	side_sb.set_corner_radius_all(10)
	side_sb.shadow_color = Color(1.0, 0.7, 0.1, 0.2)
	side_sb.shadow_size = 12
	side_detail_panel.add_theme_stylebox_override("panel", side_sb)
	parent.add_child(side_detail_panel)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 22)
	side_detail_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	detail_category_label = Label.new()
	detail_category_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_category_label.text = "// REGISTRO ARCANO DE TOMO"
	detail_category_label.add_theme_font_size_override("font_size", 12)
	detail_category_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 0.8))
	vbox.add_child(detail_category_label)

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

	detail_icon_rect = TextureRect.new()
	detail_icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	detail_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	detail_icon_rect.custom_minimum_size = Vector2(100, 100)
	icon_margin.add_child(detail_icon_rect)

	detail_title_label = Label.new()
	detail_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_title_label.text = "SELECCIONA UN TOMO"
	detail_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_title_label.add_theme_font_size_override("font_size", 16)
	detail_title_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
	detail_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(detail_title_label)

	detail_status_panel = PanelContainer.new()
	detail_status_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_status_panel.custom_minimum_size = Vector2(0, 30)
	var st_sb := StyleBoxFlat.new()
	st_sb.bg_color = Color(0.12, 0.1, 0.03, 0.8)
	st_sb.border_color = Color(1.0, 0.8, 0.2, 0.6)
	st_sb.set_border_width_all(1)
	st_sb.set_corner_radius_all(6)
	detail_status_panel.add_theme_stylebox_override("panel", st_sb)
	vbox.add_child(detail_status_panel)

	detail_status_badge = Label.new()
	detail_status_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_status_badge.text = "[ DISPONIBLE EN EL ARSENAL ]"
	detail_status_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_status_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	detail_status_badge.add_theme_font_size_override("font_size", 11)
	detail_status_badge.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	detail_status_panel.add_child(detail_status_badge)

	var sep := HSeparator.new()
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(sep)

	detail_stats_label = Label.new()
	detail_stats_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_stats_label.text = "Bonificación: -- por nivel"
	detail_stats_label.add_theme_font_size_override("font_size", 12)
	detail_stats_label.add_theme_color_override("font_color", Color(0.35, 1.0, 0.75))
	vbox.add_child(detail_stats_label)

	detail_desc_label = Label.new()
	detail_desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_desc_label.text = "Pasa el cursor o navega con el mando/teclado sobre un tomo para inspeccionar sus efectos y escalado."
	detail_desc_label.add_theme_font_size_override("font_size", 12)
	detail_desc_label.add_theme_color_override("font_color", Color(0.75, 0.82, 0.92))
	detail_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_desc_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(detail_desc_label)


func open_modal(char_id: StringName = &"") -> void:
	if not char_id.is_empty():
		current_character_id = char_id

	is_open = true
	show()

	if SaveManager.has_method("get_character_active_tomes"):
		active_tome_ids = SaveManager.get_character_active_tomes(current_character_id)
	else:
		active_tome_ids = TomeCatalog.ALL_TOME_IDS.duplicate()

	if active_tome_ids.size() < min_active_tomes:
		active_tome_ids = TomeCatalog.ALL_TOME_IDS.duplicate()
		if SaveManager.has_method("set_character_active_tomes"):
			SaveManager.set_character_active_tomes(current_character_id, active_tome_ids)

	if min_rule_label:
		min_rule_label.text = "(MÍNIMO %d ACTIVOS OBLIGATORIOS)" % min_active_tomes

	_update_header_text()
	_populate_grid()
	_update_counter_label()

	var all_tomes: Array[TomeDataScript] = TomeCatalog.get_all_tomes()
	if all_tomes.size() > 0:
		_inspect_tome(all_tomes[0])

	if _card_buttons.size() > 0 and is_instance_valid(_card_buttons[0]):
		_card_buttons[0].call_deferred("grab_focus")


func close_modal() -> void:
	if not is_open:
		return
	is_open = false
	hide()
	closed.emit()


func _on_dim_overlay_gui_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if get_viewport():
			get_viewport().set_input_as_handled()
		var audio_mgr := get_node_or_null("/root/AudioManager")
		if audio_mgr and audio_mgr.has_method("play_sfx"):
			audio_mgr.play_sfx(&"ui_click", 0.0, 1.0)
		close_modal()


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action("ui_focus_next") or event.is_action("ui_focus_prev"):
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		get_viewport().set_input_as_handled()
		close_modal()
		return


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return

	if event.is_action("ui_focus_next") or event.is_action("ui_focus_prev"):
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		get_viewport().set_input_as_handled()
		close_modal()
		return


func _update_header_text() -> void:
	if subtitle_label:
		subtitle_label.text = "PILOTO: %s — Activa o desactiva tomos para la subida de nivel." % [str(current_character_id).to_upper()]


func _update_counter_label() -> void:
	if not counter_label:
		return
	var count: int = active_tome_ids.size()
	var total: int = TomeCatalog.ALL_TOME_IDS.size()
	counter_label.text = "TOMOS ACTIVOS: %d / %d" % [count, total]
	if count <= min_active_tomes:
		counter_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	else:
		counter_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.8))


func _populate_grid() -> void:
	if not tomes_grid:
		return

	for child in tomes_grid.get_children():
		child.queue_free()

	_card_panels.clear()
	_card_badges.clear()
	_card_buttons.clear()

	var all_tomes: Array = TomeCatalog.get_all_tomes()
	for tome in all_tomes:
		if not tome:
			continue
		var card := _build_tome_card(tome)
		tomes_grid.add_child(card)


func _build_tome_card(tome: TomeDataScript) -> Control:
	var tid: StringName = tome.tome_id
	var is_active: bool = active_tome_ids.has(tid)
	_card_tome_map[tid] = tome

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
	icon_rect.texture = tome.icon
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

	btn.pressed.connect(_on_card_pressed.bind(tid))
	btn.mouse_entered.connect(_on_card_hovered.bind(tome))
	btn.focus_entered.connect(_on_card_hovered.bind(tome))
	UIFocusHelper.apply_cyber_focus(btn, true)

	_card_panels[tid] = panel
	_card_badges[tid] = badge_lbl
	_card_buttons.append(btn)

	_refresh_card_visual(tid, is_active)

	return panel


func _on_card_hovered(tome: TomeDataScript) -> void:
	_inspect_tome(tome)


func _inspect_tome(tome: TomeDataScript) -> void:
	if not tome:
		return
	_last_inspected_tome = tome

	if detail_title_label:
		detail_title_label.text = tome.display_name
	if detail_icon_rect:
		detail_icon_rect.texture = tome.icon
	if detail_stats_label:
		detail_stats_label.text = "Escalado: %s por nivel (Máx Nivel %d)" % [
			tome.get_bonus_description(1),
			tome.max_level
		]
	if detail_desc_label:
		detail_desc_label.text = tome.description

	var is_active: bool = active_tome_ids.has(tome.tome_id)
	_update_detail_status(is_active)


func _update_detail_status(is_active: bool) -> void:
	if not detail_status_badge or not detail_status_panel:
		return

	var st_sb := StyleBoxFlat.new()
	st_sb.set_corner_radius_all(6)
	st_sb.set_border_width_all(1)

	if is_active:
		st_sb.bg_color = Color(0.12, 0.1, 0.03, 0.85)
		st_sb.border_color = Color(1.0, 0.8, 0.2, 0.8)
		detail_status_badge.text = "[ ACTIVO EN POOL // SUBIDAS DE NIVEL ]"
		detail_status_badge.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	else:
		st_sb.bg_color = Color(0.2, 0.05, 0.08, 0.85)
		st_sb.border_color = Color(1.0, 0.35, 0.35, 0.8)
		detail_status_badge.text = "[ EXCLUIDO // NO APARECERÁ EN RUN ]"
		detail_status_badge.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))

	detail_status_panel.add_theme_stylebox_override("panel", st_sb)


func _refresh_card_visual(tome_id: StringName, is_active: bool) -> void:
	var panel: PanelContainer = _card_panels.get(tome_id, null)
	var badge: Label = _card_badges.get(tome_id, null)
	if not panel or not badge:
		return

	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(8)

	if is_active:
		style.bg_color = Color(0.06, 0.05, 0.03, 0.95)
		style.set_border_width_all(2)
		style.border_color = Color(1.0, 0.8, 0.2, 0.9)
		style.shadow_color = Color(1.0, 0.7, 0.1, 0.25)
		style.shadow_size = 6
		panel.modulate = Color.WHITE
		badge.text = "✓"
		badge.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	else:
		style.bg_color = Color(0.02, 0.03, 0.05, 0.75)
		style.set_border_width_all(1)
		style.border_color = Color(0.4, 0.25, 0.25, 0.6)
		panel.modulate = Color(0.45, 0.45, 0.45, 0.55)
		badge.text = "✗"
		badge.add_theme_color_override("font_color", Color(0.8, 0.35, 0.35))

	panel.add_theme_stylebox_override("panel", style)

	if _last_inspected_tome and _last_inspected_tome.tome_id == tome_id:
		_update_detail_status(is_active)


func _on_card_pressed(tome_id: StringName) -> void:
	var is_active: bool = active_tome_ids.has(tome_id)

	if is_active:
		if active_tome_ids.size() <= min_active_tomes:
			_show_warning("¡MÍNIMO %d TOMOS OBLIGATORIOS PARA DESPLEGAR!" % min_active_tomes)
			var audio_mgr := get_node_or_null("/root/AudioManager")
			if audio_mgr and audio_mgr.has_method("play_sfx"):
				audio_mgr.play_sfx(&"ui_error", 0.0, 0.9)
			return

		active_tome_ids.erase(tome_id)
		_refresh_card_visual(tome_id, false)
	else:
		active_tome_ids.append(tome_id)
		_refresh_card_visual(tome_id, true)

	if SaveManager.has_method("set_character_active_tomes"):
		SaveManager.set_character_active_tomes(current_character_id, active_tome_ids)

	_update_counter_label()
	tomes_updated.emit(current_character_id, active_tome_ids)

	var tome: TomeDataScript = _card_tome_map.get(tome_id, null)
	if tome:
		_inspect_tome(tome)


func _on_reset_pressed() -> void:
	active_tome_ids = TomeCatalog.ALL_TOME_IDS.duplicate()
	if SaveManager.has_method("set_character_active_tomes"):
		SaveManager.set_character_active_tomes(current_character_id, active_tome_ids)

	for tid: StringName in TomeCatalog.ALL_TOME_IDS:
		_refresh_card_visual(tid, true)

	_update_counter_label()
	tomes_updated.emit(current_character_id, active_tome_ids)

	if _last_inspected_tome:
		_update_detail_status(true)


func _show_warning(msg: String) -> void:
	if not warning_label:
		return
	warning_label.text = msg
	if _warning_tween and _warning_tween.is_valid():
		_warning_tween.kill()

	warning_label.modulate = Color(1.0, 0.3, 0.3, 1.0)
	_warning_tween = create_tween()
	_warning_tween.tween_interval(1.8)
	_warning_tween.tween_property(warning_label, "modulate:a", 0.0, 0.4)


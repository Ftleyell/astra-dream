class_name TomeSelectionModal
extends CanvasLayer

## TomeSelectionModal.gd
## Orquestador desacoplado del modal de selección y loadout de Tomos Arcanos de Atributos por Heroína/Piloto.
## Exige un mínimo obligatorio de 6 tomos activos para evitar monopolios de pool reducida.

const TomeCatalog = preload("res://data/tomes/tome_catalog.gd")
const TomeDataScript = preload("res://data/tomes/tome_data.gd")
const TomePoolDataControllerClass = preload("res://scenes/ui/character_select/components/tome_pool_data_controller.gd")
const TomeCardRendererClass = preload("res://scenes/ui/character_select/components/tome_card_renderer.gd")
const TomeSelectionDetailPanelClass = preload("res://scenes/ui/character_select/components/tome_selection_detail_panel.gd")

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

# Compatibilidad directa con suites de test y accesos externos
var active_tome_ids: Array[StringName]:
	get:
		return _data_controller.active_tome_ids if _data_controller else []
	set(value):
		if _data_controller:
			_data_controller.active_tome_ids = value

var dim_overlay: ColorRect = null
var title_label: Label = null
var subtitle_label: Label = null
var counter_label: Label = null
var min_rule_label: Label = null
var warning_label: Label = null
var tomes_grid: GridContainer = null

# Panel lateral flotante de descripción (expuesto para compatibilidad con tests)
var side_detail_panel: PanelContainer:
	get: return _detail_panel_controller.panel if _detail_panel_controller else null
var detail_icon_rect: TextureRect:
	get: return _detail_panel_controller.icon_rect if _detail_panel_controller else null
var detail_title_label: Label:
	get: return _detail_panel_controller.title_label if _detail_panel_controller else null
var detail_category_label: Label:
	get: return _detail_panel_controller.category_label if _detail_panel_controller else null
var detail_stats_label: Label:
	get: return _detail_panel_controller.stats_label if _detail_panel_controller else null
var detail_desc_label: Label:
	get: return _detail_panel_controller.desc_label if _detail_panel_controller else null
var detail_status_badge: Label:
	get: return _detail_panel_controller.status_badge if _detail_panel_controller else null
var detail_status_panel: PanelContainer:
	get: return _detail_panel_controller.status_panel if _detail_panel_controller else null

# Acceso de compatibilidad para suites de tests
var _card_panels: Dictionary[StringName, PanelContainer]:
	get: return _card_renderer.get_card_panels() if _card_renderer else {}
var _card_badges: Dictionary[StringName, Label]:
	get: return _card_renderer.get_card_badges() if _card_renderer else {}
var _card_buttons: Array[Button]:
	get: return _card_renderer.get_card_buttons() if _card_renderer else []
var _card_tome_map: Dictionary[StringName, TomeDataScript]:
	get: return _card_renderer.get_card_tome_map() if _card_renderer else {}

var _data_controller: TomePoolDataController = null
var _card_renderer: TomeCardRenderer = null
var _detail_panel_controller: TomeSelectionDetailPanel = null
var _warning_tween: Tween = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 126
	_data_controller = TomePoolDataControllerClass.new()
	_card_renderer = TomeCardRendererClass.new()
	_card_renderer.card_size = card_size
	_card_renderer.icon_size = icon_size
	_detail_panel_controller = TomeSelectionDetailPanelClass.new()

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

	warning_label = Label.new()
	warning_label.text = ""
	warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning_label.add_theme_font_size_override("font_size", 13)
	warning_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
	warning_label.modulate.a = 0.0
	root_vbox.add_child(warning_label)

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

	var footer_box := HBoxContainer.new()
	footer_box.alignment = BoxContainer.ALIGNMENT_CENTER
	root_vbox.add_child(footer_box)

	var hint_label := Label.new()
	hint_label.text = "✦ [ESC] O CLIC EN EL FONDO PARA GUARDAR Y CERRAR"
	hint_label.add_theme_font_size_override("font_size", 12)
	hint_label.add_theme_color_override("font_color", Color(0.4, 0.75, 0.9, 0.75))
	footer_box.add_child(hint_label)

	_detail_panel_controller.build_panel(modal_wrapper, side_panel_size)


func open_modal(char_id: StringName = &"") -> void:
	if not char_id.is_empty():
		current_character_id = char_id

	is_open = true
	show()

	_data_controller.initialize(current_character_id, min_active_tomes)

	if min_rule_label:
		min_rule_label.text = "(MÍNIMO %d ACTIVOS OBLIGATORIOS)" % min_active_tomes

	_update_header_text()
	_populate_grid()
	_update_counter_label()

	var all_tomes: Array[TomeDataScript] = TomeCatalog.get_all_tomes()
	if all_tomes.size() > 0:
		_inspect_tome(all_tomes[0])

	var first_btn: Button = _card_renderer.get_first_button()
	if first_btn:
		first_btn.call_deferred("grab_focus")


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
	if not counter_label or not _data_controller:
		return
	var count: int = _data_controller.get_active_count()
	var total: int = _data_controller.get_total_count()
	counter_label.text = "TOMOS ACTIVOS: %d / %d" % [count, total]
	if count <= min_active_tomes:
		counter_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	else:
		counter_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.8))


func _populate_grid() -> void:
	if not tomes_grid or not _card_renderer:
		return

	for child in tomes_grid.get_children():
		child.queue_free()

	_card_renderer.clear()

	var all_tomes: Array = TomeCatalog.get_all_tomes()
	for tome in all_tomes:
		if not tome:
			continue
		var is_active: bool = _data_controller.is_tome_active(tome.tome_id)
		var card := _card_renderer.build_card(
			tome,
			is_active,
			Callable(self, "_on_card_pressed"),
			Callable(self, "_inspect_tome")
		)
		tomes_grid.add_child(card)


func _inspect_tome(tome: TomeDataScript) -> void:
	if not _detail_panel_controller:
		return
	var is_active: bool = _data_controller.is_tome_active(tome.tome_id) if _data_controller else true
	_detail_panel_controller.inspect_tome(tome, is_active)


func _on_card_pressed(tome_id: StringName) -> void:
	var success: bool = _data_controller.toggle_tome(tome_id)
	if not success:
		_show_warning("¡MÍNIMO %d TOMOS OBLIGATORIOS PARA DESPLEGAR!" % min_active_tomes)
		var audio_mgr := get_node_or_null("/root/AudioManager")
		if audio_mgr and audio_mgr.has_method("play_sfx"):
			audio_mgr.play_sfx(&"ui_error", 0.0, 0.9)
		return

	var is_active: bool = _data_controller.is_tome_active(tome_id)
	_card_renderer.refresh_card_visual(tome_id, is_active)
	_update_counter_label()
	tomes_updated.emit(current_character_id, _data_controller.active_tome_ids)

	var tome: TomeDataScript = _card_renderer.get_tome(tome_id)
	if tome:
		_inspect_tome(tome)


func _on_reset_pressed() -> void:
	_data_controller.reset_to_default()
	for tid: StringName in TomeCatalog.ALL_TOME_IDS:
		_card_renderer.refresh_card_visual(tid, true)

	_update_counter_label()
	tomes_updated.emit(current_character_id, _data_controller.active_tome_ids)

	if _detail_panel_controller and _detail_panel_controller.last_inspected_tome:
		_detail_panel_controller.update_status(true)


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

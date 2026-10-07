class_name ArsenalBanlistModal
extends CanvasLayer

## ArsenalBanlistModal.gd
## Modal unificado de gestión de Arsenal y Exclusiones (Banlist) para Astra Dream.
## Integra en 7 pestañas con diseño de dossier sci-fi:
## 1. Armas (Pool de Salvas, máx 4 baneos de 11)
## 2. Tomos (Atributos Arcanos, máx 7 baneos de 18)
## 3. Sobrecargas (Trade-off Satélite, máx 3 baneos de 8)
## 4. Procs Reactivos (Satélite/Combate, máx 3 baneos de 8)
## 5. Conversión y Utilidad (Satélite, máx 3 baneos de 8)
## 6. Módulos Estratégicos (Satélite, máx 4 baneos de 12)
## 7. Básicos y Cofres (Cofres de Combate, máx 9 baneos de 24)
## Aplica la regla del 40% estricto: floor(total * 0.40) bloqueos permitidos por pestaña.

const WeaponCatalogScript = preload("res://data/weapons/weapon_catalog.gd")
const WeaponDataScript = preload("res://data/weapons/weapon_data.gd")
const TomeCatalogScript = preload("res://data/tomes/tome_catalog.gd")
const TomeDataScript = preload("res://data/tomes/tome_data.gd")
const ItemPoolManagerScript = preload("res://core/types/item_pool_manager.gd")
const ItemDataScript = preload("res://data/items/item_data.gd")

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

# Referencias dinámicas
var _tab_buttons: Dictionary[int, Button] = {}
var _tab_badges: Dictionary[int, Label] = {}
var _card_buttons: Array[Button] = []
var _card_panels: Dictionary[StringName, PanelContainer] = {}
var _card_badges: Dictionary[StringName, Label] = {}
var _card_icons: Dictionary[StringName, TextureRect] = {}
var _card_ban_indicators: Dictionary[StringName, Label] = {}
var _card_data_map: Dictionary[StringName, Resource] = {}
var _warning_tween: Tween = null
var _last_focused_card: Button = null

# Cache de definiciones de pestañas
var _tabs_info: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 126
	_init_tab_definitions()
	_build_ui()
	hide()


func _init_tab_definitions() -> void:
	_tabs_info = [
		{
			"id": TabCategory.WEAPONS,
			"name": "ARMAS",
			"full_title": "ARSENAL DE ARMAS // POOL DE SALVAS",
			"subtitle": "Armas adicionales desbloqueadas para tiradas durante la partida.",
			"category_tag": "// ARMA DE COMBATE",
			"item_ids": WeaponCatalogScript.POOL_WEAPON_IDS,
			"accent": Color(0.15, 0.9, 1.0)
		},
		{
			"id": TabCategory.TOMES,
			"name": "TOMOS",
			"full_title": "TOMOS ARCANOS // ATRIBUTOS",
			"subtitle": "Grimorios de especialización que potencian estadísticas de la nave.",
			"category_tag": "// TOMO ARCANO",
			"item_ids": TomeCatalogScript.ALL_TOME_IDS,
			"accent": Color(0.85, 0.45, 1.0)
		},
		{
			"id": TabCategory.OVERLOADS,
			"name": "SOBRECARGAS",
			"full_title": "SOBRECARGAS CON TRADE-OFF // SATÉLITE",
			"subtitle": "Módulos de alto rendimiento que ofrecen potencia a cambio de penalizaciones.",
			"category_tag": "// MÓDULO SATÉLITE - TRADE-OFF",
			"item_ids": ItemPoolManagerScript.OVERLOAD_ITEM_IDS,
			"accent": Color(1.0, 0.55, 0.2)
		},
		{
			"id": TabCategory.REACTIVE_PROCS,
			"name": "PROCS",
			"full_title": "PROCS REACTIVOS // SATÉLITE Y COMBATE",
			"subtitle": "Tecnología reactiva activada al recibir daño, esquivar o asestar críticos.",
			"category_tag": "// MÓDULO SATÉLITE - REACTIVO",
			"item_ids": ItemPoolManagerScript.REACTIVE_PROC_ITEM_IDS,
			"accent": Color(1.0, 0.85, 0.2)
		},
		{
			"id": TabCategory.UTILITY_CORES,
			"name": "UTILIDAD",
			"full_title": "NÚCLEOS DE CONVERSIÓN Y UTILIDAD",
			"subtitle": "Sistemas de conversión cinética, hemodinámica y absorción energética.",
			"category_tag": "// MÓDULO SATÉLITE - UTILIDAD",
			"item_ids": ItemPoolManagerScript.UTILITY_CORE_ITEM_IDS,
			"accent": Color(0.25, 1.0, 0.65)
		},
		{
			"id": TabCategory.STRATEGIC_MODULES,
			"name": "ESTRATÉGICOS",
			"full_title": "MÓDULOS ESTRATÉGICOS // SATÉLITE",
			"subtitle": "Sistemas arcanos y cósmicos de manipulación espacial y económica.",
			"category_tag": "// MÓDULO SATÉLITE - ESTRATÉGICO",
			"item_ids": ItemPoolManagerScript.STRATEGIC_MODULE_ITEM_IDS,
			"accent": Color(1.0, 0.35, 0.75)
		},
		{
			"id": TabCategory.CHEST_ITEMS,
			"name": "COFRES",
			"full_title": "ÍTEMS BÁSICOS Y COFRES DE COMBATE",
			"subtitle": "Reliquias, artefactos pasivos y tarjetas cuánticas de cofres regulares.",
			"category_tag": "// ÍTEM DE COFRE",
			"item_ids": ItemPoolManagerScript.CHEST_CANONICAL_ITEM_IDS,
			"accent": Color(0.9, 0.95, 1.0)
		}
	]


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

	# --- Columna Izquierda: Pestañas Extruidas + Panel Principal ---
	var left_column := VBoxContainer.new()
	left_column.name = "LeftColumn"
	left_column.mouse_filter = Control.MOUSE_FILTER_PASS
	left_column.add_theme_constant_override("separation", -2) # Solapamiento físico con el borde de la ventana
	left_column.custom_minimum_size = Vector2(modal_size.x, modal_size.y + 36)
	modal_wrapper.add_child(left_column)

	# 1. Pestañas Físicas Superiores (Extrusión hacia arriba estilo carpeta)
	tabs_container = HBoxContainer.new()
	tabs_container.name = "TabsContainer"
	tabs_container.mouse_filter = Control.MOUSE_FILTER_PASS
	tabs_container.add_theme_constant_override("separation", 2)
	tabs_container.custom_minimum_size = Vector2(modal_size.x, 36)
	tabs_container.alignment = BoxContainer.ALIGNMENT_BEGIN
	left_column.add_child(tabs_container)
	_build_tabs_bar()

	# 2. Panel Principal de Gestión (Cuerpo de la Carpeta)
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

	# A. Header con Títulos y Contador
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 16)
	root_vbox.add_child(header_row)

	var title_box := VBoxContainer.new()
	title_box.add_theme_constant_override("separation", 2)
	header_row.add_child(title_box)

	title_label = Label.new()
	title_label.text = "GESTIÓN DE ARSENAL // BANLIST"
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", Color(0.2, 0.9, 1.0))
	title_box.add_child(title_label)

	subtitle_label = Label.new()
	subtitle_label.text = "Todos los elementos están ACTIVOS por defecto. Puedes bloquear hasta un 40% del conjunto."
	subtitle_label.add_theme_font_size_override("font_size", 12)
	subtitle_label.add_theme_color_override("font_color", Color(0.65, 0.75, 0.9))
	title_box.add_child(subtitle_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(spacer)

	var counter_box := VBoxContainer.new()
	counter_box.alignment = BoxContainer.ALIGNMENT_CENTER
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

	# B. Warning Label Flasheable
	warning_label = Label.new()
	warning_label.text = ""
	warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning_label.add_theme_font_size_override("font_size", 12)
	warning_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
	warning_label.modulate.a = 0.0
	root_vbox.add_child(warning_label)

	# C. Scroll Container con Grilla de Tarjetas
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 420)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_vbox.add_child(scroll)

	items_grid = GridContainer.new()
	items_grid.columns = grid_columns
	items_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	items_grid.add_theme_constant_override("h_separation", 10)
	items_grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(items_grid)

	# D. Footer con atajos
	var footer_box := HBoxContainer.new()
	footer_box.alignment = BoxContainer.ALIGNMENT_CENTER
	root_vbox.add_child(footer_box)

	var hint_label := Label.new()
	hint_label.text = "✦ [Q / E] CAMBIAR PESTAÑA | [ESC] O CLIC AFUERA PARA GUARDAR Y CERRAR"
	hint_label.add_theme_font_size_override("font_size", 11)
	hint_label.add_theme_color_override("font_color", Color(0.4, 0.75, 0.9, 0.75))
	footer_box.add_child(hint_label)

	# --- Panel Lateral de Inspección Flotante ---
	_build_side_detail_panel(modal_wrapper)


func _build_tabs_bar() -> void:
	for i in range(_tabs_info.size()):
		var info: Dictionary = _tabs_info[i]
		var tab_id: int = info["id"]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(100, 36)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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


# ==============================================================================
# LÓGICA DE APERTURA, CIERRE Y PESTAÑAS
# ==============================================================================

func open_modal(character_id: StringName = &"nova", default_tab: int = 0) -> void:
	current_character_id = character_id
	is_open = true
	active_tab = clampi(default_tab, 0, _tabs_info.size() - 1) as TabCategory
	show()

	_refresh_all_tab_badges()
	_load_active_tab()

	if not _card_buttons.is_empty() and is_instance_valid(_card_buttons[0]):
		_card_buttons[0].grab_focus()


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

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Q:
			var prev_tab: int = (int(active_tab) - 1 + _tabs_info.size()) % _tabs_info.size()
			_on_tab_pressed(prev_tab)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_E:
			var next_tab: int = (int(active_tab) + 1) % _tabs_info.size()
			_on_tab_pressed(next_tab)
			get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_LEFT_SHOULDER:
			var prev_tab: int = (int(active_tab) - 1 + _tabs_info.size()) % _tabs_info.size()
			_on_tab_pressed(prev_tab)
			get_viewport().set_input_as_handled()
		elif event.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			var next_tab: int = (int(active_tab) + 1) % _tabs_info.size()
			_on_tab_pressed(next_tab)
			get_viewport().set_input_as_handled()


func _on_tab_pressed(tab_id: int) -> void:
	active_tab = tab_id as TabCategory
	_refresh_all_tab_badges()
	_load_active_tab()
	if not _card_buttons.is_empty() and is_instance_valid(_card_buttons[0]):
		_card_buttons[0].grab_focus()


# ==============================================================================
# GESTIÓN DE DATOS Y LÍMITES DEL 40%
# ==============================================================================

func get_max_bans_for_tab(tab_id: int) -> int:
	var info: Dictionary = _tabs_info[tab_id]
	var total: int = (info["item_ids"] as Array).size()
	return int(floor(float(total) * 0.40))


func get_banned_ids_for_tab(tab_id: int) -> Array[StringName]:
	var info: Dictionary = _tabs_info[tab_id]
	var all_ids: Array = info["item_ids"]
	var result: Array[StringName] = []

	match tab_id:
		TabCategory.WEAPONS:
			var active: Array[StringName] = SaveManager.get_character_active_weapons(current_character_id)
			for w: StringName in all_ids:
				if not active.has(w):
					result.append(w)
		TabCategory.TOMES:
			var active: Array[StringName] = SaveManager.get_character_active_tomes(current_character_id)
			for t: StringName in all_ids:
				if not active.has(t):
					result.append(t)
		_:
			var banned_all: Array[StringName] = SaveManager.get_character_banlist(current_character_id)
			for it: StringName in all_ids:
				if banned_all.has(it):
					result.append(it)

	return result


func is_item_banned(tab_id: int, item_id: StringName) -> bool:
	return get_banned_ids_for_tab(tab_id).has(item_id)


func _refresh_all_tab_badges() -> void:
	for i in range(_tabs_info.size()):
		var info: Dictionary = _tabs_info[i]
		var tab_id: int = info["id"]
		var btn: Button = _tab_buttons.get(tab_id)
		if not btn:
			continue

		var total_items: int = (info["item_ids"] as Array).size()
		var banned: Array[StringName] = get_banned_ids_for_tab(tab_id)
		var max_bans: int = get_max_bans_for_tab(tab_id)
		var is_active_tab: bool = (tab_id == int(active_tab))

		if banned.is_empty():
			btn.text = "%s (%d)" % [info["name"], total_items]
		else:
			btn.text = "%s (%d) [%d⊘]" % [info["name"], total_items - banned.size(), banned.size()]

		var sb := StyleBoxFlat.new()
		sb.corner_radius_top_left = 8
		sb.corner_radius_top_right = 8
		sb.corner_radius_bottom_left = 0
		sb.corner_radius_bottom_right = 0
		sb.content_margin_top = 7
		sb.content_margin_bottom = 7
		sb.content_margin_left = 4
		sb.content_margin_right = 4

		if is_active_tab:
			# Extrusión física hacia arriba: se fusiona sin borde inferior con el main_panel
			sb.bg_color = Color(0.03, 0.05, 0.09, 0.98)
			sb.border_color = info["accent"]
			sb.border_width_top = 2
			sb.border_width_left = 2
			sb.border_width_right = 2
			sb.border_width_bottom = 0
			btn.add_theme_color_override("font_color", info["accent"])
			btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
			btn.z_index = 2
		else:
			# Pestaña inactiva: aspecto de ficha guardada/recesada
			sb.bg_color = Color(0.015, 0.025, 0.04, 0.8)
			sb.border_color = Color(0.18, 0.28, 0.38, 0.6)
			sb.border_width_top = 1
			sb.border_width_left = 1
			sb.border_width_right = 1
			sb.border_width_bottom = 1
			btn.add_theme_color_override("font_color", Color(0.55, 0.65, 0.75))
			btn.add_theme_color_override("font_hover_color", Color(0.9, 0.95, 1.0))
			btn.z_index = 1

		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_stylebox_override("hover", sb)
		btn.add_theme_stylebox_override("pressed", sb)
		btn.add_theme_stylebox_override("focus", sb)


func _load_active_tab() -> void:
	var info: Dictionary = _tabs_info[int(active_tab)]
	title_label.text = info["full_title"]
	subtitle_label.text = info["subtitle"]
	title_label.add_theme_color_override("font_color", info["accent"])

	var total_items: int = (info["item_ids"] as Array).size()
	var banned_ids: Array[StringName] = get_banned_ids_for_tab(int(active_tab))
	var max_bans: int = get_max_bans_for_tab(int(active_tab))
	var active_count: int = total_items - banned_ids.size()
	var min_active: int = total_items - max_bans

	counter_label.text = "ACTIVOS: %d / %d  |  BANEOS: %d / %d" % [active_count, total_items, banned_ids.size(), max_bans]
	max_rule_label.text = "(MÁXIMO 40%% BANEOS · MÍNIMO %d ACTIVOS EN COMBATE)" % min_active

	# Limpiar grilla anterior
	for child in items_grid.get_children():
		child.queue_free()
	_card_buttons.clear()
	_card_panels.clear()
	_card_badges.clear()
	_card_icons.clear()
	_card_ban_indicators.clear()
	_card_data_map.clear()

	var all_ids: Array = info["item_ids"]
	for item_id in all_ids:
		_create_item_card(item_id, int(active_tab))

	_setup_card_focus_mesh()

	if not _card_buttons.is_empty():
		_inspect_item(_card_buttons[0].get_meta("item_id"), int(active_tab))


func _create_item_card(item_id: StringName, tab_id: int) -> void:
	var is_banned: bool = is_item_banned(tab_id, item_id)
	var is_unlocked: bool = _check_item_unlocked(item_id, tab_id)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = card_size
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	_update_card_panel_style(panel, is_banned, is_unlocked)
	items_grid.add_child(panel)
	_card_panels[item_id] = panel

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
	icon_rect.texture = _resolve_icon_texture(item_id, tab_id)
	margin.add_child(icon_rect)
	_card_icons[item_id] = icon_rect

	if is_banned:
		icon_rect.modulate = Color(0.45, 0.25, 0.25, 0.45)
	else:
		icon_rect.modulate = Color(1.0, 1.0, 1.0, 1.0)

	# Indicador centralizado y legible de exclusión
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
	_card_ban_indicators[item_id] = ban_ind

	# Botón invisible de captura interactiva
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

	btn.pressed.connect(_on_card_pressed.bind(item_id, tab_id))
	btn.mouse_entered.connect(_on_card_inspected.bind(item_id, tab_id))
	btn.focus_entered.connect(_on_card_inspected.bind(item_id, tab_id))

	panel.add_child(btn)
	_card_buttons.append(btn)


func _update_card_panel_style(panel: PanelContainer, is_banned: bool, is_unlocked: bool) -> void:
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


func _check_item_unlocked(item_id: StringName, tab_id: int) -> bool:
	match tab_id:
		TabCategory.WEAPONS, TabCategory.TOMES:
			return true
		_:
			if SaveManager.has_method("is_item_unlocked"):
				return SaveManager.is_item_unlocked(item_id)
			return true


func _on_card_pressed(item_id: StringName, tab_id: int) -> void:
	var banned_ids: Array[StringName] = get_banned_ids_for_tab(tab_id)
	var max_bans: int = get_max_bans_for_tab(tab_id)
	var is_banned: bool = banned_ids.has(item_id)

	if is_banned:
		# Desbanear (restablecer a ACTIVO)
		_set_item_banned_state(item_id, tab_id, false)
		_play_sfx("ui_click")
	else:
		# Intentar banear (verificar cupo del 40%)
		if banned_ids.size() >= max_bans:
			_deny_ban_action(max_bans)
			return
		_set_item_banned_state(item_id, tab_id, true)
		_play_sfx("ui_click")

	_refresh_all_tab_badges()
	_update_card_visuals(item_id, tab_id)
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

	# Sacudir suavemente el counter_label
	var original_pos: Vector2 = counter_label.position
	var t := create_tween()
	t.tween_property(counter_label, "modulate", Color(1.0, 0.3, 0.3), 0.1)
	t.tween_property(counter_label, "modulate", Color(1.0, 1.0, 1.0), 0.3)


func _set_item_banned_state(item_id: StringName, tab_id: int, should_ban: bool) -> void:
	match tab_id:
		TabCategory.WEAPONS:
			var active: Array[StringName] = SaveManager.get_character_active_weapons(current_character_id)
			if should_ban:
				active.erase(item_id)
			else:
				if not active.has(item_id):
					active.append(item_id)
			SaveManager.set_character_active_weapons(current_character_id, active)

		TabCategory.TOMES:
			var active: Array[StringName] = SaveManager.get_character_active_tomes(current_character_id)
			if should_ban:
				active.erase(item_id)
			else:
				if not active.has(item_id):
					active.append(item_id)
			SaveManager.set_character_active_tomes(current_character_id, active)

		_:
			var bans: Array[StringName] = SaveManager.get_character_banlist(current_character_id)
			if should_ban:
				if not bans.has(item_id):
					bans.append(item_id)
			else:
				bans.erase(item_id)
			SaveManager.set_character_banlist(current_character_id, bans)


func _update_card_visuals(item_id: StringName, tab_id: int) -> void:
	var is_banned: bool = is_item_banned(tab_id, item_id)
	var is_unlocked: bool = _check_item_unlocked(item_id, tab_id)

	if _card_panels.has(item_id):
		_update_card_panel_style(_card_panels[item_id], is_banned, is_unlocked)

	if _card_icons.has(item_id):
		var icon_rect: TextureRect = _card_icons[item_id]
		if is_banned:
			icon_rect.modulate = Color(0.45, 0.25, 0.25, 0.45)
		else:
			icon_rect.modulate = Color(1.0, 1.0, 1.0, 1.0)

	if _card_ban_indicators.has(item_id):
		_card_ban_indicators[item_id].visible = is_banned

	var info: Dictionary = _tabs_info[tab_id]
	var total_items: int = (info["item_ids"] as Array).size()
	var banned_ids: Array[StringName] = get_banned_ids_for_tab(tab_id)
	var max_bans: int = get_max_bans_for_tab(tab_id)
	var active_count: int = total_items - banned_ids.size()
	counter_label.text = "ACTIVOS: %d / %d  |  BANEOS: %d / %d" % [active_count, total_items, banned_ids.size(), max_bans]


func _on_card_inspected(item_id: StringName, tab_id: int) -> void:
	_inspect_item(item_id, tab_id)


# ==============================================================================
# PANEL LATERAL DE DETALLES
# ==============================================================================

func _inspect_item(item_id: StringName, tab_id: int) -> void:
	var info: Dictionary = _tabs_info[tab_id]
	detail_category_label.text = info["category_tag"]
	detail_icon_rect.texture = _resolve_icon_texture(item_id, tab_id)

	var is_banned: bool = is_item_banned(tab_id, item_id)
	var is_unlocked: bool = _check_item_unlocked(item_id, tab_id)

	# Actualizar status badge
	if not is_unlocked:
		detail_status_badge.text = "BLOQUEADO POR META-PROGRESIÓN"
		detail_status_badge.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	elif is_banned:
		detail_status_badge.text = "EXCLUIDO DEL ARSENAL // NO APARECERÁ"
		detail_status_badge.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	else:
		detail_status_badge.text = "ACTIVO EN COMBATE // DISPONIBLE EN POOL"
		detail_status_badge.add_theme_color_override("font_color", Color(0.2, 1.0, 0.65))

	match tab_id:
		TabCategory.WEAPONS:
			_inspect_weapon(item_id)
		TabCategory.TOMES:
			_inspect_tome(item_id)
		_:
			_inspect_inventory_item(item_id)


func _inspect_weapon(weapon_id: StringName) -> void:
	var wpn: WeaponData = WeaponCatalogScript.get_weapon_by_id(weapon_id)
	detail_rarity_label.text = "TIPO: ARMA DE SALVAS // PROC: %.2f" % (wpn.proc_coefficient if wpn else 1.0)
	detail_rarity_label.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))

	if wpn:
		detail_title_label.text = wpn.weapon_name.to_upper()
		detail_stats_label.text = "Daño Base: %.1f | Cadencia: %.2fs | Ráfaga: %d" % [
			wpn.base_damage, wpn.base_cooldown, wpn.active_burst_count
		]
		detail_desc_label.text = wpn.description
	else:
		detail_title_label.text = str(weapon_id).to_upper()
		detail_stats_label.text = ""
		detail_desc_label.text = "Especificación balística clasificada."


func _inspect_tome(tome_id: StringName) -> void:
	var tome: TomeDataScript = TomeCatalogScript.load_tome(tome_id)
	detail_rarity_label.text = "TIPO: TOMO ARCANO DE ATRIBUTOS"
	detail_rarity_label.add_theme_color_override("font_color", Color(0.85, 0.5, 1.0))

	if tome:
		detail_title_label.text = tome.display_name.to_upper()
		var stat_display: String = get_stat_display_name(tome.stat_name)
		var bonus_str: String = format_stat_bonus(tome.stat_value_per_level, tome.is_percentage, tome.stat_name)
		detail_stats_label.text = "Atributo: %s (%s por nivel)" % [stat_display, bonus_str]
		detail_desc_label.text = tome.description
	else:
		detail_title_label.text = str(tome_id).to_upper()
		detail_stats_label.text = ""
		detail_desc_label.text = "Grimorio de conocimiento arcano sin descifrar."


func _inspect_inventory_item(item_id: StringName) -> void:
	var item: ItemData = ItemPoolManagerScript.load_item(item_id)
	if item:
		detail_title_label.text = item.item_name.to_upper()
		var rarity_str: String = "COMÚN"
		var r_color := Color(0.7, 0.8, 0.9)
		match item.rarity:
			Enums.Rarity.UNCOMMON:
				rarity_str = "POCO COMÚN"
				r_color = Color(0.3, 1.0, 0.5)
			Enums.Rarity.RARE:
				rarity_str = "RARO"
				r_color = Color(0.2, 0.7, 1.0)
			Enums.Rarity.EPIC:
				rarity_str = "ÉPICO"
				r_color = Color(0.8, 0.35, 1.0)
			Enums.Rarity.LEGENDARY:
				rarity_str = "LEGENDARIO"
				r_color = Color(1.0, 0.8, 0.2)
		detail_rarity_label.text = "RAREZA: %s | COSTE BASE: %dc" % [rarity_str, item.cost]
		detail_rarity_label.add_theme_color_override("font_color", r_color)

		var stats_desc := ""
		if not item.stat_name.is_empty():
			var val_str := format_stat_bonus(item.stat_value, item.is_percentage, item.stat_name)
			var name_str := get_stat_display_name(item.stat_name)
			stats_desc = "%s en %s" % [val_str, name_str]
		if not item.secondary_stat_name.is_empty():
			var val_str2 := format_stat_bonus(item.secondary_stat_value, item.secondary_is_percentage, item.secondary_stat_name)
			var name_str2 := get_stat_display_name(item.secondary_stat_name)
			var sep := "  |  " if not stats_desc.is_empty() else ""
			stats_desc += "%s%s en %s" % [sep, val_str2, name_str2]
		detail_stats_label.text = stats_desc
		detail_desc_label.text = item.description
	else:
		detail_title_label.text = str(item_id).to_upper()
		detail_rarity_label.text = "MÓDULO DE ARSENAL"
		detail_stats_label.text = ""
		detail_desc_label.text = "Módulo estratégico de hangar espacial."


static func get_stat_display_name(stat_key: StringName) -> String:
	match stat_key:
		&"base_damage":
			return "Daño Base"
		&"attack_speed":
			return "Cadencia de Ataque"
		&"movement_speed", &"move_speed":
			return "Velocidad de Movimiento"
		&"max_health":
			return "Vida Máxima"
		&"health_regen":
			return "Regeneración de Vida"
		&"armor":
			return "Armadura"
		&"crit_chance":
			return "Probabilidad Crítica"
		&"crit_damage":
			return "Daño Crítico"
		&"pickup_radius":
			return "Radio de Recogida"
		&"luck":
			return "Suerte"
		&"curse":
			return "Maldición"
		&"cooldown_reduction":
			return "Reducción de Enfriamiento"
		&"projectile_speed":
			return "Velocidad de Proyectil"
		&"weapon_size":
			return "Área de Proyectiles"
		&"projectile_count":
			return "Proyectiles Adicionales"
		&"exp_multiplier":
			return "EXP Obtenida"
		&"credits_multiplier":
			return "Créditos Obtenidos"
		&"biomass_multiplier":
			return "Biomasa Obtenida"
		_:
			return str(stat_key).capitalize().replace("_", " ")


static func format_stat_bonus(val: float, is_pct: bool, stat_key: StringName) -> String:
	var sign_str: String = "+" if val >= 0.0 else ""
	var is_effective_pct: bool = is_pct or (absf(val) < 2.0 and stat_key != &"health_regen" and stat_key != &"armor" and stat_key != &"curse" and stat_key != &"projectile_count")
	if is_effective_pct:
		var pct_val: float = val * (100.0 if absf(val) <= 1.0 else 1.0)
		return "%s%.0f%%" % [sign_str, pct_val]
	elif stat_key == &"pickup_radius":
		return "%s%d px" % [sign_str, int(roundf(val))]
	elif is_equal_approx(val, roundf(val)):
		return "%s%d" % [sign_str, int(val)]
	else:
		return "%s%.1f" % [sign_str, val]


# ==============================================================================
# RESOLUCIÓN DE ICONOS Y AUDIO
# ==============================================================================

func _resolve_icon_texture(item_id: StringName, tab_id: int) -> Texture2D:
	var path := ""
	match tab_id:
		TabCategory.WEAPONS:
			var wpn: WeaponData = WeaponCatalogScript.get_weapon_by_id(item_id)
			if wpn and wpn.icon:
				return wpn.icon
			path = "res://assets/characters/skills/weapons/icon_weapon_%s.png" % str(item_id)
			if not ResourceLoader.exists(path):
				path = "res://assets/ui/icons/weapons/%s.png" % str(item_id)
		TabCategory.TOMES:
			var tome = TomeCatalogScript.load_tome(item_id)
			if tome and tome.icon:
				return tome.icon
			path = "res://assets/ui/icons/tomes/%s.png" % str(item_id)
			if not ResourceLoader.exists(path):
				path = "res://assets/ui/icons/tomes/icon_tome_%s.png" % str(item_id)
		_:
			var item := ItemPoolManagerScript.load_item(item_id)
			if item and item.icon:
				return item.icon
			path = "res://assets/ui/icons/items/%s.png" % str(item_id)
			if not ResourceLoader.exists(path):
				path = "res://assets/ui/icons/items/icon_item_%s.png" % str(item_id)

	if ResourceLoader.exists(path):
		var tex = load(path)
		if tex is Texture2D:
			return tex
	return null


func _play_sfx(sfx_name: String) -> void:
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx(sfx_name)


func _setup_card_focus_mesh() -> void:
	for i in range(_card_buttons.size()):
		var btn := _card_buttons[i]
		if not is_instance_valid(btn):
			continue
		var up_idx: int = i - grid_columns
		var down_idx: int = i + grid_columns
		var left_idx: int = i - 1
		var right_idx: int = i + 1

		if up_idx >= 0 and up_idx < _card_buttons.size():
			btn.focus_neighbor_top = _card_buttons[up_idx].get_path()
		if down_idx >= 0 and down_idx < _card_buttons.size():
			btn.focus_neighbor_bottom = _card_buttons[down_idx].get_path()
		if left_idx >= 0 and i % grid_columns != 0:
			btn.focus_neighbor_left = _card_buttons[left_idx].get_path()
		if right_idx < _card_buttons.size() and (i + 1) % grid_columns != 0:
			btn.focus_neighbor_right = _card_buttons[right_idx].get_path()

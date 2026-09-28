class_name GachaModal
extends CanvasLayer

## GachaModal.gd
## Refactor completo de la Máquina de Cápsulas Gacha:
## - Cúpula de cristal procedural con físicas de cápsulas rebotantes (GachaDomeWidget).
## - Palanca / actuador mecánico táctil con animación y retroalimentación audiovisual.
## - Banners temáticos seleccionables ("Estelar General", "Hangar de Naves", "Academia de Pilotos").
## - Sistema de Pity independiente de 10 tiradas por banner con medidor visual.
## - Secuencia de revelación interactiva con cápsula en 3D/2D, clics para abrir y botón de Salto Rápido.
## - Armario y colección de skins con filtros por categoría y toggle de adquiridos.

const CosmeticsManager = preload("res://core/systems/cosmetics_manager.gd")
const SaveManager = preload("res://core/autoloads/save_manager.gd")
const GachaDomeWidgetClass = preload("res://scenes/ui/gacha/gacha_dome_widget.gd")

signal skin_unlocked(skin_id: String, stars: int)
signal skin_equipped(slot_key: String, skin_id: String)
signal modal_closed()

var is_animating: bool = false
var _active_tab: int = 0 # 0 = Gacha, 1 = Wardrobe
var _active_category_filter: String = "all"
var _hide_locked: bool = false

# Banner Data
var _active_banner_id: String = "general"
const BANNERS_CONFIG := {
	"general": {
		"title": "🌌 BANNER ESTELAR GENERAL",
		"desc": "Todo el repertorio del cosmos: naves, pilotos, armas y mascotas con 15% de épico.",
		"color": Color(0.0, 0.94, 1.0, 1.0),
		"featured_badge": "★ POOL COMPLETO"
	},
	"ships": {
		"title": "🚀 HANGAR DE NAVES Y ARMAS",
		"desc": "Especialización táctica. Mayor probabilidad de skins para naves de asalto y armamento.",
		"color": Color(1.0, 0.5, 0.1, 1.0),
		"featured_badge": "★ TÁCTICO NAVAL"
	},
	"pilots": {
		"title": "👩‍✈️ ACADEMIA DE PILOTOS Y TRAJES",
		"desc": "Uniformes, trajes de combate y aspectos para tus heroínas y navegantes estelares.",
		"color": Color(1.0, 0.25, 0.7, 1.0),
		"featured_badge": "★ HEROÍNAS VIP"
	}
}

# UI Nodes
var _panel: PanelContainer
var _token_count_label: Label
var _biomass_count_label: Label
var _tab_gacha_btn: Button
var _tab_wardrobe_btn: Button

# Gacha Tab Elements
var _gacha_content: VBoxContainer
var _banner_buttons_box: HBoxContainer
var _banner_banner_panel: PanelContainer
var _banner_title_label: Label
var _banner_desc_label: Label
var _pity_count_label: Label
var _pity_progress_bar: ProgressBar
var _dome_widget: GachaDomeWidget
var _lever_btn: Button
var _pull_1_btn: Button
var _pull_5_btn: Button
var _pull_10_btn: Button

# Wardrobe Tab Elements
var _wardrobe_content: VBoxContainer
var _hide_locked_check: CheckBox
var _wardrobe_grid: GridContainer

# Interactive Reveal Theater Overlay
var _reveal_overlay: PanelContainer
var _reveal_vbox: VBoxContainer
var _reveal_capsule_display: CenterContainer
var _reveal_title_label: Label
var _reveal_subtitle_label: Label
var _reveal_capsule_btn: Button
var _reveal_cards_container: HBoxContainer
var _reveal_skip_btn: Button
var _current_pull_queue: Array[Dictionary] = []
var _current_pull_idx: int = 0
var _pulled_cards_history: Array[Dictionary] = []

# Final Summary Results Layer
var _results_layer: PanelContainer
var _results_grid: GridContainer


func _ready() -> void:
	layer = 130
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	hide()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.01, 0.05, 0.85)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(1040, 720)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.03, 0.10, 0.98)
	sb.border_color = Color(0.0, 0.94, 1.0, 0.9)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	_panel.add_theme_stylebox_override("panel", sb)
	center.add_child(_panel)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 10)
	_panel.add_child(root_vbox)

	# --- TOP HEADER ---
	var top_bar := HBoxContainer.new()
	top_bar.alignment = BoxContainer.ALIGNMENT_BEGIN
	root_vbox.add_child(top_bar)

	var title := Label.new()
	title.text = "🎰 CÁPSULAS GACHA DE COSMÉTICOS"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.2, 0.95, 1.0, 1.0))
	top_bar.add_child(title)

	var top_spacer := Control.new()
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(top_spacer)

	_token_count_label = Label.new()
	_token_count_label.text = "🎟️ Fichas: 0"
	_token_count_label.add_theme_font_size_override("font_size", 16)
	_token_count_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0))
	top_bar.add_child(_token_count_label)

	var token_spacer := Control.new()
	token_spacer.custom_minimum_size = Vector2(20, 0)
	top_bar.add_child(token_spacer)

	_biomass_count_label = Label.new()
	_biomass_count_label.text = "✨ Polvo Estelar: 0"
	_biomass_count_label.add_theme_font_size_override("font_size", 16)
	_biomass_count_label.add_theme_color_override("font_color", Color(0.8, 0.4, 1.0, 1.0))
	top_bar.add_child(_biomass_count_label)

	var close_btn := Button.new()
	close_btn.text = " ✖ CERRAR "
	close_btn.pressed.connect(_on_close_pressed)
	UIFocusHelper.apply_cyber_focus(close_btn)
	top_bar.add_child(close_btn)

	# --- TAB SWITCHER ---
	var tab_bar := HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 16)
	root_vbox.add_child(tab_bar)

	_tab_gacha_btn = Button.new()
	_tab_gacha_btn.text = "🎰 MÁQUINA DE TIRADAS"
	_tab_gacha_btn.custom_minimum_size = Vector2(240, 36)
	_tab_gacha_btn.pressed.connect(func(): _switch_tab(0))
	UIFocusHelper.apply_cyber_focus(_tab_gacha_btn)
	tab_bar.add_child(_tab_gacha_btn)

	_tab_wardrobe_btn = Button.new()
	_tab_wardrobe_btn.text = "👗 ARMARIO / COLECCIÓN DE SKINS"
	_tab_wardrobe_btn.custom_minimum_size = Vector2(280, 36)
	_tab_wardrobe_btn.pressed.connect(func(): _switch_tab(1))
	UIFocusHelper.apply_cyber_focus(_tab_wardrobe_btn)
	tab_bar.add_child(_tab_wardrobe_btn)

	var separator := HSeparator.new()
	root_vbox.add_child(separator)

	# =========================================================================
	# TAB 1: GACHA MACHINE & DOME
	# =========================================================================
	_gacha_content = VBoxContainer.new()
	_gacha_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_gacha_content.add_theme_constant_override("separation", 10)
	root_vbox.add_child(_gacha_content)

	# 1. Banner Selector Bar
	_banner_buttons_box = HBoxContainer.new()
	_banner_buttons_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_banner_buttons_box.add_theme_constant_override("separation", 16)
	_gacha_content.add_child(_banner_buttons_box)

	var b_keys := ["general", "ships", "pilots"]
	for b_id in b_keys:
		var cfg: Dictionary = BANNERS_CONFIG[b_id]
		var btn := Button.new()
		btn.text = cfg["title"]
		btn.custom_minimum_size = Vector2(260, 34)
		btn.pressed.connect(func(): _select_banner(b_id))
		UIFocusHelper.apply_cyber_focus(btn)
		_banner_buttons_box.add_child(btn)

	# 2. Main Stage (Dome in Center + Info Sidebars)
	var main_stage_hbox := HBoxContainer.new()
	main_stage_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_stage_hbox.add_theme_constant_override("separation", 24)
	main_stage_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_gacha_content.add_child(main_stage_hbox)

	# Left Column: Banner Details & Pity Meter
	var left_info_vbox := VBoxContainer.new()
	left_info_vbox.custom_minimum_size = Vector2(300, 0)
	left_info_vbox.add_theme_constant_override("separation", 12)
	left_info_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_stage_hbox.add_child(left_info_vbox)

	_banner_banner_panel = PanelContainer.new()
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color(0.08, 0.06, 0.18, 0.85)
	bsb.border_color = Color(0.0, 0.94, 1.0, 0.7)
	bsb.set_border_width_all(2)
	bsb.set_corner_radius_all(10)
	bsb.content_margin_left = 16
	bsb.content_margin_right = 16
	bsb.content_margin_top = 14
	bsb.content_margin_bottom = 14
	_banner_banner_panel.add_theme_stylebox_override("panel", bsb)
	left_info_vbox.add_child(_banner_banner_panel)

	var b_vbox := VBoxContainer.new()
	b_vbox.add_theme_constant_override("separation", 8)
	_banner_banner_panel.add_child(b_vbox)

	_banner_title_label = Label.new()
	_banner_title_label.text = "🌌 BANNER ESTELAR GENERAL"
	_banner_title_label.add_theme_font_size_override("font_size", 15)
	_banner_title_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3, 1.0))
	_banner_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b_vbox.add_child(_banner_title_label)

	_banner_desc_label = Label.new()
	_banner_desc_label.text = "Todo el repertorio del cosmos: naves, pilotos, armas y mascotas con 15% de épico."
	_banner_desc_label.add_theme_font_size_override("font_size", 12)
	_banner_desc_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.95, 0.9))
	_banner_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b_vbox.add_child(_banner_desc_label)

	# Pity Card
	var pity_panel := PanelContainer.new()
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0.06, 0.05, 0.14, 0.9)
	psb.border_color = Color(1.0, 0.8, 0.2, 0.6)
	psb.set_border_width_all(2)
	psb.set_corner_radius_all(8)
	psb.content_margin_left = 16
	psb.content_margin_right = 16
	psb.content_margin_top = 10
	psb.content_margin_bottom = 10
	pity_panel.add_theme_stylebox_override("panel", psb)
	left_info_vbox.add_child(pity_panel)

	var pity_vbox := VBoxContainer.new()
	pity_vbox.add_theme_constant_override("separation", 6)
	pity_panel.add_child(pity_vbox)

	_pity_count_label = Label.new()
	_pity_count_label.text = "⚡ PITY DE BANNER: 0 / 10"
	_pity_count_label.add_theme_font_size_override("font_size", 13)
	_pity_count_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0))
	pity_vbox.add_child(_pity_count_label)

	_pity_progress_bar = ProgressBar.new()
	_pity_progress_bar.custom_minimum_size = Vector2(0, 16)
	_pity_progress_bar.max_value = 10.0
	_pity_progress_bar.value = 0.0
	_pity_progress_bar.show_percentage = false
	pity_vbox.add_child(_pity_progress_bar)

	var pity_hint := Label.new()
	pity_hint.text = "Garantiza skin Épica al alcanzar 10 tiradas."
	pity_hint.add_theme_font_size_override("font_size", 11)
	pity_hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8, 0.7))
	pity_vbox.add_child(pity_hint)

	# Center Column: Glass Dome Widget
	var center_dome_vbox := VBoxContainer.new()
	center_dome_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_stage_hbox.add_child(center_dome_vbox)

	_dome_widget = GachaDomeWidgetClass.new()
	center_dome_vbox.add_child(_dome_widget)

	# Right Column: Interactive Arcade Lever & Controls
	var right_controls_vbox := VBoxContainer.new()
	right_controls_vbox.custom_minimum_size = Vector2(280, 0)
	right_controls_vbox.add_theme_constant_override("separation", 14)
	right_controls_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_stage_hbox.add_child(right_controls_vbox)

	# Lever Actuator Button
	_lever_btn = Button.new()
	_lever_btn.text = "🕹️ GIRAR PALANCA ARCADE\n[ Tirada Rápida x1 ]"
	_lever_btn.custom_minimum_size = Vector2(260, 68)
	_lever_btn.pressed.connect(func(): _on_lever_pulled())
	UIFocusHelper.apply_cyber_focus(_lever_btn)
	right_controls_vbox.add_child(_lever_btn)

	var lever_hint := Label.new()
	lever_hint.text = "Acciona el mecanismo magnético de la máquina"
	lever_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lever_hint.add_theme_font_size_override("font_size", 11)
	lever_hint.add_theme_color_override("font_color", Color(0.5, 0.7, 0.9, 0.8))
	right_controls_vbox.add_child(lever_hint)

	# 3. Bottom Pull Buttons Row
	var roll_btn_box := HBoxContainer.new()
	roll_btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	roll_btn_box.add_theme_constant_override("separation", 24)
	_gacha_content.add_child(roll_btn_box)

	_pull_1_btn = Button.new()
	_pull_1_btn.text = "🎟️ TIRADA SIMPLE\n(1 Ficha)"
	_pull_1_btn.custom_minimum_size = Vector2(190, 52)
	_pull_1_btn.pressed.connect(func(): _start_gacha_sequence(1))
	UIFocusHelper.apply_cyber_focus(_pull_1_btn)
	roll_btn_box.add_child(_pull_1_btn)

	_pull_5_btn = Button.new()
	_pull_5_btn.text = "🎟️ MULTI-TIRADA x5\n(5 Fichas)"
	_pull_5_btn.custom_minimum_size = Vector2(190, 52)
	_pull_5_btn.pressed.connect(func(): _start_gacha_sequence(5))
	UIFocusHelper.apply_cyber_focus(_pull_5_btn)
	roll_btn_box.add_child(_pull_5_btn)

	_pull_10_btn = Button.new()
	_pull_10_btn.text = "🎟️ MULTI-TIRADA x10\n(10 Fichas)"
	_pull_10_btn.custom_minimum_size = Vector2(190, 52)
	_pull_10_btn.pressed.connect(func(): _start_gacha_sequence(10))
	UIFocusHelper.apply_cyber_focus(_pull_10_btn)
	roll_btn_box.add_child(_pull_10_btn)

	# =========================================================================
	# TAB 2: WARDROBE CONTENT
	# =========================================================================
	_wardrobe_content = VBoxContainer.new()
	_wardrobe_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_wardrobe_content.add_theme_constant_override("separation", 10)
	root_vbox.add_child(_wardrobe_content)
	_wardrobe_content.hide()

	# Filter buttons
	var filter_bar := HBoxContainer.new()
	filter_bar.add_theme_constant_override("separation", 10)
	_wardrobe_content.add_child(filter_bar)

	var cats := [
		{"id": "all", "label": "TODAS"},
		{"id": "ship", "label": "🚀 NAVES"},
		{"id": "pilot", "label": "👩‍✈️ PILOTOS"},
		{"id": "weapon", "label": "⚡ ARMAS"},
		{"id": "pet", "label": "🐾 PETS"},
		{"id": "navigator", "label": "📡 NAVEGADORAS"}
	]
	for c in cats:
		var b := Button.new()
		b.text = c["label"]
		var cid: String = c["id"]
		b.pressed.connect(func(): _filter_wardrobe(cid))
		UIFocusHelper.apply_cyber_focus(b)
		filter_bar.add_child(b)

	var filter_spacer := Control.new()
	filter_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	filter_bar.add_child(filter_spacer)

	_hide_locked_check = CheckBox.new()
	_hide_locked_check.text = "👁️ Ocultar no adquiridos"
	_hide_locked_check.button_pressed = _hide_locked
	_hide_locked_check.toggled.connect(func(pressed: bool):
		_hide_locked = pressed
		_filter_wardrobe(_active_category_filter)
	)
	UIFocusHelper.apply_cyber_focus(_hide_locked_check)
	filter_bar.add_child(_hide_locked_check)

	# Scrollable Wardrobe Grid
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_wardrobe_content.add_child(scroll)

	_wardrobe_grid = GridContainer.new()
	_wardrobe_grid.columns = 4
	_wardrobe_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_wardrobe_grid.add_theme_constant_override("h_separation", 16)
	_wardrobe_grid.add_theme_constant_override("v_separation", 16)
	scroll.add_child(_wardrobe_grid)

	# =========================================================================
	# INTERACTIVE REVEAL THEATER OVERLAY (INSIDE _panel)
	# =========================================================================
	_reveal_overlay = PanelContainer.new()
	_reveal_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var rev_sb := StyleBoxFlat.new()
	rev_sb.bg_color = Color(0.03, 0.02, 0.08, 0.98)
	rev_sb.border_color = Color(0.0, 0.94, 1.0, 0.9)
	rev_sb.set_border_width_all(2)
	rev_sb.set_corner_radius_all(14)
	rev_sb.content_margin_left = 32
	rev_sb.content_margin_right = 32
	rev_sb.content_margin_top = 28
	rev_sb.content_margin_bottom = 28
	_reveal_overlay.add_theme_stylebox_override("panel", rev_sb)
	_reveal_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_reveal_overlay.gui_input.connect(_on_reveal_overlay_gui_input)
	_panel.add_child(_reveal_overlay)
	_reveal_overlay.hide()

	_reveal_vbox = VBoxContainer.new()
	_reveal_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_reveal_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reveal_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_reveal_vbox.add_theme_constant_override("separation", 24)
	_reveal_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	_reveal_overlay.add_child(_reveal_vbox)

	_reveal_title_label = Label.new()
	_reveal_title_label.text = "✨ ¡CÁPSULA EXPULSADA!"
	_reveal_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reveal_title_label.add_theme_font_size_override("font_size", 26)
	_reveal_title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0))
	_reveal_title_label.mouse_filter = Control.MOUSE_FILTER_PASS
	_reveal_vbox.add_child(_reveal_title_label)

	_reveal_subtitle_label = Label.new()
	_reveal_subtitle_label.text = "[ HAZ CLIC EN LA CÁPSULA PARA ABRIR ]"
	_reveal_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reveal_subtitle_label.add_theme_font_size_override("font_size", 15)
	_reveal_subtitle_label.add_theme_color_override("font_color", Color(0.0, 0.94, 1.0, 1.0))
	_reveal_subtitle_label.mouse_filter = Control.MOUSE_FILTER_PASS
	_reveal_vbox.add_child(_reveal_subtitle_label)

	# Big interactive capsule button / container
	_reveal_capsule_display = CenterContainer.new()
	_reveal_capsule_display.custom_minimum_size = Vector2(300, 240)
	_reveal_capsule_display.mouse_filter = Control.MOUSE_FILTER_PASS
	_reveal_vbox.add_child(_reveal_capsule_display)

	_reveal_capsule_btn = Button.new()
	_reveal_capsule_btn.text = "🔮\nABRIR"
	_reveal_capsule_btn.custom_minimum_size = Vector2(160, 160)
	_reveal_capsule_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_reveal_capsule_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_reveal_capsule_btn.add_theme_font_size_override("font_size", 24)
	var cap_sb := StyleBoxFlat.new()
	cap_sb.bg_color = Color(0.08, 0.06, 0.22, 0.95)
	cap_sb.border_color = Color(0.0, 0.94, 1.0, 1.0)
	cap_sb.set_border_width_all(4)
	cap_sb.set_corner_radius_all(80)
	_reveal_capsule_btn.add_theme_stylebox_override("normal", cap_sb)

	var cap_hover := cap_sb.duplicate() as StyleBoxFlat
	cap_hover.bg_color = Color(0.15, 0.10, 0.35, 0.98)
	cap_hover.border_color = Color(0.3, 1.0, 1.0, 1.0)
	_reveal_capsule_btn.add_theme_stylebox_override("hover", cap_hover)

	var cap_pressed := cap_sb.duplicate() as StyleBoxFlat
	cap_pressed.bg_color = Color(0.25, 0.18, 0.5, 1.0)
	cap_pressed.border_color = Color(1.0, 1.0, 1.0, 1.0)
	_reveal_capsule_btn.add_theme_stylebox_override("pressed", cap_pressed)

	_reveal_capsule_btn.pressed.connect(_on_capsule_opened)
	UIFocusHelper.apply_cyber_focus(_reveal_capsule_btn)
	_reveal_capsule_display.add_child(_reveal_capsule_btn)

	# Container for revealed card (replaces capsule button area when open)
	_reveal_cards_container = HBoxContainer.new()
	_reveal_cards_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_reveal_cards_container.custom_minimum_size = Vector2(200, 240)
	_reveal_cards_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reveal_cards_container.hide()
	_reveal_capsule_display.add_child(_reveal_cards_container)

	# Skip / Continue Button
	_reveal_skip_btn = Button.new()
	_reveal_skip_btn.text = "⏩ SALTAR TODO [ESC]"
	_reveal_skip_btn.custom_minimum_size = Vector2(240, 44)
	_reveal_skip_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_reveal_skip_btn.pressed.connect(_on_skip_reveal_pressed)
	UIFocusHelper.apply_cyber_focus(_reveal_skip_btn)
	_reveal_vbox.add_child(_reveal_skip_btn)

	# =========================================================================
	# FINAL RESULTS SUMMARY LAYER (INSIDE _panel)
	# =========================================================================
	_results_layer = PanelContainer.new()
	_results_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	var rsb := StyleBoxFlat.new()
	rsb.bg_color = Color(0.03, 0.02, 0.08, 0.98)
	rsb.border_color = Color(0.0, 0.94, 1.0, 0.9)
	rsb.set_border_width_all(2)
	rsb.set_corner_radius_all(14)
	rsb.content_margin_left = 28
	rsb.content_margin_right = 28
	rsb.content_margin_top = 24
	rsb.content_margin_bottom = 24
	_results_layer.add_theme_stylebox_override("panel", rsb)
	_panel.add_child(_results_layer)
	_results_layer.hide()

	var res_vbox := VBoxContainer.new()
	res_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	res_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	res_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	res_vbox.add_theme_constant_override("separation", 18)
	_results_layer.add_child(res_vbox)

	var res_title := Label.new()
	res_title.text = "🎉 ¡RECOMPENSAS DEL GACHA OBTENIDAS! 🎉"
	res_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	res_title.add_theme_font_size_override("font_size", 22)
	res_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0))
	res_vbox.add_child(res_title)

	var res_scroll := ScrollContainer.new()
	res_scroll.custom_minimum_size = Vector2(920, 480)
	res_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	res_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	res_vbox.add_child(res_scroll)

	var res_center := CenterContainer.new()
	res_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	res_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	res_scroll.add_child(res_center)

	_results_grid = GridContainer.new()
	_results_grid.columns = 5
	_results_grid.add_theme_constant_override("h_separation", 18)
	_results_grid.add_theme_constant_override("v_separation", 18)
	res_center.add_child(_results_grid)

	var res_close_btn := Button.new()
	res_close_btn.text = "✨ RECLAMAR Y CONTINUAR"
	res_close_btn.custom_minimum_size = Vector2(280, 50)
	res_close_btn.pressed.connect(func():
		_results_layer.hide()
		_reveal_overlay.hide()
		_refresh_currency()
		_refresh_banner_info()
	)
	UIFocusHelper.apply_cyber_focus(res_close_btn)
	res_vbox.add_child(res_close_btn)

	_refresh_banner_info()


# ── BANNER & PITY MANAGEMENT ──────────────────────────────────────────────────
func _select_banner(banner_id: String) -> void:
	if is_animating:
		return
	_active_banner_id = banner_id
	_refresh_banner_info()
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("ui_click")


func _refresh_banner_info() -> void:
	var cfg: Dictionary = BANNERS_CONFIG.get(_active_banner_id, BANNERS_CONFIG["general"])
	if _banner_title_label:
		_banner_title_label.text = cfg["title"]
		_banner_title_label.add_theme_color_override("font_color", cfg["color"])
	if _banner_desc_label:
		_banner_desc_label.text = cfg["desc"]

	var current_pity: int = SaveManager.get_banner_pity(_active_banner_id)
	if _pity_count_label:
		_pity_count_label.text = "⚡ PITY [%s]: %d / 10" % [cfg["featured_badge"], current_pity]
	if _pity_progress_bar:
		_pity_progress_bar.value = float(current_pity)

	# Resaltar botón de banner activo
	if _banner_buttons_box:
		var b_keys := ["general", "ships", "pilots"]
		for i in range(_banner_buttons_box.get_child_count()):
			var btn := _banner_buttons_box.get_child(i) as Button
			if btn and i < b_keys.size():
				if b_keys[i] == _active_banner_id:
					btn.modulate = Color(0.2, 1.0, 0.8, 1.0)
				else:
					btn.modulate = Color(0.65, 0.65, 0.65, 1.0)


func open_gacha_modal() -> void:
	_refresh_currency()
	_refresh_banner_info()
	_switch_tab(0)
	show()
	get_tree().paused = true


func _refresh_currency() -> void:
	var tokens := SaveManager.get_gacha_tokens()
	var bio := SaveManager.get_biomass()
	if _token_count_label:
		_token_count_label.text = "🎟️ Fichas: %d" % tokens
	if _biomass_count_label:
		_biomass_count_label.text = "✨ Polvo Estelar: %d" % bio


func _switch_tab(tab_idx: int) -> void:
	_active_tab = tab_idx
	if tab_idx == 0:
		_gacha_content.show()
		_wardrobe_content.hide()
		_tab_gacha_btn.modulate = Color(0.2, 1.0, 0.8, 1.0)
		_tab_wardrobe_btn.modulate = Color(0.7, 0.7, 0.7, 1.0)
		_refresh_banner_info()
	else:
		_gacha_content.hide()
		_wardrobe_content.show()
		_tab_gacha_btn.modulate = Color(0.7, 0.7, 0.7, 1.0)
		_tab_wardrobe_btn.modulate = Color(0.2, 1.0, 0.8, 1.0)
		_filter_wardrobe(_active_category_filter)


# ── PULL EXECUTION & LOGIC ────────────────────────────────────────────────────
func execute_pulls(count: int) -> Array[Dictionary]:
	var current_tokens := SaveManager.get_gacha_tokens()
	if current_tokens < count:
		return []

	# Spend tokens
	SaveManager.spend_gacha_tokens(count)
	if _token_count_label and _biomass_count_label:
		_refresh_currency()

	var pulled_results: Array[Dictionary] = []
	for i in range(count):
		# Comprobar si esta tirada activa el Pity (10 tiradas acumuladas)
		var current_pity := SaveManager.get_banner_pity(_active_banner_id)
		var is_pity: bool = (current_pity + 1 >= 10)

		var raw_skin := CosmeticsManager.roll_banner_skin(_active_banner_id, is_pity)
		if raw_skin.is_empty():
			continue

		var skin_id: String = raw_skin.get("id", "")
		var upgrade_res := SaveManager.unlock_or_upgrade_skin(skin_id)

		# Actualizar o reiniciar contador de pity del banner
		if is_pity or str(raw_skin.get("rarity", "")) == "epic":
			SaveManager.reset_banner_pity(_active_banner_id)
		else:
			SaveManager.increment_banner_pity(_active_banner_id, 1)

		pulled_results.append({
			"skin_data": raw_skin,
			"upgrade_data": upgrade_res
		})

	_refresh_banner_info()
	return pulled_results


func _on_lever_pulled() -> void:
	if is_animating:
		return
	var current_tokens := SaveManager.get_gacha_tokens()
	if current_tokens < 1:
		_flash_no_tokens()
		return

	# Animación de la palanca (resorte y giro de cápsulas)
	if _lever_btn:
		var tw := create_tween()
		tw.tween_property(_lever_btn, "scale", Vector2(0.92, 0.92), 0.1)
		tw.tween_property(_lever_btn, "scale", Vector2.ONE, 0.15)

	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("ui_click")

	_start_gacha_sequence(1)


func _start_gacha_sequence(count: int) -> void:
	if is_animating:
		return
	var current_tokens := SaveManager.get_gacha_tokens()
	if current_tokens < count:
		_flash_no_tokens()
		return

	is_animating = true
	if _dome_widget:
		_dome_widget.trigger_spin_and_shake(1.0)

	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("satellite_activate")

	# Ejecutar tiradas lógicas
	var results := execute_pulls(count)
	if results.is_empty():
		is_animating = false
		return

	_current_pull_queue = results
	_current_pull_idx = 0
	_pulled_cards_history.clear()

	# Esperar finalización de la sacudida de la cúpula para lanzar el reveal theater
	get_tree().create_timer(0.9).timeout.connect(func():
		_launch_reveal_theater()
	)


func _flash_no_tokens() -> void:
	if _token_count_label:
		_token_count_label.modulate = Color(1.0, 0.2, 0.2, 1.0)
		var tw := create_tween()
		if tw:
			tw.tween_property(_token_count_label, "modulate", Color.WHITE, 0.6)


# ── INTERACTIVE REVEAL THEATER ────────────────────────────────────────────────
func _launch_reveal_theater() -> void:
	_reveal_overlay.show()
	_show_next_capsule()


func _show_next_capsule() -> void:
	if _current_pull_idx >= _current_pull_queue.size():
		# Fin de la secuencia: mostrar resumen completo
		_reveal_overlay.hide()
		_display_pull_results(_current_pull_queue)
		is_animating = false
		return

	var pull_item: Dictionary = _current_pull_queue[_current_pull_idx]
	var skin: Dictionary = pull_item.get("skin_data", {})
	var rarity: String = skin.get("rarity", "common")

	# Limpiar y ocultar contenedor de carta previa para no bloquear el ratón
	for child in _reveal_cards_container.get_children():
		child.queue_free()
	_reveal_cards_container.hide()
	_reveal_cards_container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_reveal_capsule_btn.show()
	_reveal_capsule_btn.scale = Vector2.ONE
	_reveal_capsule_btn.move_to_front()
	_reveal_capsule_btn.grab_focus()
	_reveal_title_label.text = "✨ ¡CÁPSULA [%d / %d] EXPULSADA!" % [_current_pull_idx + 1, _current_pull_queue.size()]
	_reveal_subtitle_label.text = "[ HAZ CLIC EN LA CÁPSULA PARA ABRIR ]"

	# Color del botón según la rareza oculta (glow perimetral)
	var glow_color := Color(0.0, 0.94, 1.0, 1.0)
	match rarity:
		"epic":
			glow_color = Color(1.0, 0.85, 0.2, 1.0)
			_reveal_capsule_btn.text = "🌟\nÉPICA"
		"rare":
			glow_color = Color(0.85, 0.3, 1.0, 1.0)
			_reveal_capsule_btn.text = "🔮\nRARA"
		_:
			glow_color = Color(0.0, 0.94, 1.0, 1.0)
			_reveal_capsule_btn.text = "⚪\nCOMÚN"

	_reveal_capsule_btn.modulate = glow_color
	_reveal_capsule_btn.pivot_offset = _reveal_capsule_btn.size * 0.5 if _reveal_capsule_btn.size != Vector2.ZERO else Vector2(80, 80)

	# Animación de rebote inicial de la cápsula
	var tw := create_tween()
	tw.tween_property(_reveal_capsule_btn, "scale", Vector2(1.15, 1.15), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_reveal_capsule_btn, "scale", Vector2.ONE, 0.15)


func _on_capsule_opened() -> void:
	if not _reveal_capsule_btn.visible:
		return
	if _current_pull_idx >= _current_pull_queue.size():
		return

	var pull_item: Dictionary = _current_pull_queue[_current_pull_idx]
	var skin: Dictionary = pull_item.get("skin_data", {})
	var upg: Dictionary = pull_item.get("upgrade_data", {})

	# Sonido de revelación
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("ui_click")

	# Animación de apertura y pop de la carta
	_reveal_capsule_btn.hide()
	_reveal_cards_container.show()
	_reveal_cards_container.mouse_filter = Control.MOUSE_FILTER_PASS

	var card := _create_reward_card(skin, upg)
	card.pivot_offset = Vector2(85, 115) # Mitad de Vector2(170, 230) para escalado desde el centro exacto
	card.scale = Vector2(0.3, 0.3)
	_reveal_cards_container.add_child(card)

	var tw := create_tween()
	tw.tween_property(card, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	_reveal_subtitle_label.text = "[ PULSA ESPACIO O HAZ CLIC PARA CONTINUAR ]"

	_current_pull_idx += 1
	# Avanzar automáticamente tras un breve instante o esperar interacción
	get_tree().create_timer(1.3).timeout.connect(func():
		if _reveal_overlay.visible and _reveal_capsule_btn.visible == false:
			_show_next_capsule()
	)


func _on_reveal_overlay_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _reveal_capsule_btn.visible:
			_on_capsule_opened()
		else:
			_show_next_capsule()


func _on_skip_reveal_pressed() -> void:
	# Saltar toda la secuencia y mostrar pantalla final
	_reveal_overlay.hide()
	_display_pull_results(_current_pull_queue)
	is_animating = false


func _display_pull_results(results: Array[Dictionary]) -> void:
	for child in _results_grid.get_children():
		child.queue_free()

	for res in results:
		var skin: Dictionary = res.get("skin_data", {})
		var upg: Dictionary = res.get("upgrade_data", {})
		var card := _create_reward_card(skin, upg)
		_results_grid.add_child(card)

	_results_layer.show()


func _create_reward_card(skin: Dictionary, upg: Dictionary) -> Control:
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(170, 230)

	var stars: int = int(upg.get("new_stars", 1))
	var status: String = str(upg.get("status", "new"))
	var glow_hex: String = skin.get("glow_hex", "#00F0FF")

	var csb := StyleBoxFlat.new()
	csb.bg_color = Color(0.08, 0.06, 0.18, 0.96)
	csb.border_color = Color.from_string(glow_hex, Color.CYAN)
	csb.set_border_width_all(2)
	csb.set_corner_radius_all(10)
	csb.content_margin_left = 14
	csb.content_margin_right = 14
	csb.content_margin_top = 12
	csb.content_margin_bottom = 12
	frame.add_theme_stylebox_override("panel", csb)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 6)
	frame.add_child(vbox)

	# Image Icon
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(84, 84)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var tex := CosmeticsManager.get_skin_texture(skin)
	if tex:
		icon.texture = tex
	CosmeticsManager.apply_skin_to_canvas_item(icon, skin.get("id", ""), stars, false)
	vbox.add_child(icon)

	# Target Name
	var t_name := Label.new()
	t_name.text = skin.get("target_name", "")
	t_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t_name.add_theme_font_size_override("font_size", 13)
	t_name.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	vbox.add_child(t_name)

	# Skin Name
	var s_name := Label.new()
	s_name.text = skin.get("skin_name", "")
	s_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	s_name.add_theme_font_size_override("font_size", 11)
	s_name.add_theme_color_override("font_color", Color(0.8, 0.85, 0.95, 1.0))
	vbox.add_child(s_name)

	# Stars Label
	var star_str := ""
	for i in range(stars):
		star_str += "⭐"
	var stars_lbl := Label.new()
	stars_lbl.text = star_str
	stars_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stars_lbl.add_theme_font_size_override("font_size", 12)
	vbox.add_child(stars_lbl)

	# Status tag
	var tag := Label.new()
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_font_size_override("font_size", 11)
	match status:
		"new":
			tag.text = "¡NUEVO DESBLOQUEO!"
			tag.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4, 1.0))
		"upgraded":
			tag.text = "¡MEJORA A %d★!" % stars
			tag.add_theme_color_override("font_color", Color(0.2, 0.9, 1.0, 1.0))
		"max_converted":
			tag.text = "+150 POLVO ESTELAR"
			tag.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0))
	vbox.add_child(tag)

	return frame


# ── WARDROBE / COLLECTION ─────────────────────────────────────────────────────
func _filter_wardrobe(category_id: String) -> void:
	_active_category_filter = category_id
	if not _wardrobe_grid:
		return

	for child in _wardrobe_grid.get_children():
		child.queue_free()

	var all_skins := CosmeticsManager.get_all_skins()
	var unlocked_dict := SaveManager.get_unlocked_skins()
	var equipped_dict := SaveManager.get_equipped_skins()

	for sid in all_skins.keys():
		var skin: Dictionary = all_skins[sid]
		var cat: String = skin.get("category", "")
		if category_id != "all" and cat != category_id:
			continue

		var is_unlocked: bool = unlocked_dict.has(sid)
		if _hide_locked and not is_unlocked:
			continue

		var stars: int = 0
		if is_unlocked:
			var entry = unlocked_dict[sid]
			if entry is Dictionary:
				stars = int(entry.get("stars", 1))
			else:
				stars = int(entry)

		var target_id: String = skin.get("target_id", "")
		var slot_key := "%s:%s" % [cat, target_id]
		var is_equipped: bool = (equipped_dict.get(slot_key, "") == sid)

		var item_card := _create_wardrobe_card(skin, is_unlocked, stars, is_equipped, slot_key)
		_wardrobe_grid.add_child(item_card)


func _create_wardrobe_card(skin: Dictionary, is_unlocked: bool, stars: int, is_equipped: bool, slot_key: String) -> Control:
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(210, 260)

	var glow_hex: String = skin.get("glow_hex", "#00F0FF")
	var csb := StyleBoxFlat.new()
	csb.bg_color = Color(0.06, 0.05, 0.12, 0.95) if is_unlocked else Color(0.04, 0.03, 0.08, 0.7)
	csb.border_color = Color.from_string(glow_hex, Color.CYAN) if is_unlocked else Color(0.25, 0.25, 0.35, 0.5)
	csb.set_border_width_all(2)
	csb.set_corner_radius_all(8)
	csb.content_margin_left = 12
	csb.content_margin_right = 12
	csb.content_margin_top = 10
	csb.content_margin_bottom = 10
	frame.add_theme_stylebox_override("panel", csb)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 6)
	frame.add_child(vbox)

	# Icon
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(80, 80)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var tex := CosmeticsManager.get_skin_texture(skin)
	if tex:
		icon.texture = tex
	if is_unlocked:
		CosmeticsManager.apply_skin_to_canvas_item(icon, skin.get("id", ""), stars, false)
	else:
		icon.modulate = Color(0.3, 0.3, 0.4, 0.6)
	vbox.add_child(icon)

	# Target Name & Skin Name
	var t_name := Label.new()
	t_name.text = skin.get("target_name", "")
	t_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t_name.add_theme_font_size_override("font_size", 13)
	t_name.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0) if is_unlocked else Color(0.6, 0.6, 0.6, 0.8))
	vbox.add_child(t_name)

	var s_name := Label.new()
	s_name.text = skin.get("skin_name", "")
	s_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	s_name.add_theme_font_size_override("font_size", 11)
	s_name.add_theme_color_override("font_color", Color(0.7, 0.8, 0.95, 0.9) if is_unlocked else Color(0.5, 0.5, 0.5, 0.7))
	vbox.add_child(s_name)

	# Stars
	var star_lbl := Label.new()
	var star_str := ""
	for i in range(stars):
		star_str += "⭐"
	star_lbl.text = star_str if is_unlocked else "🔒 BLOQUEADO"
	star_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	star_lbl.add_theme_font_size_override("font_size", 11)
	star_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0) if is_unlocked else Color(0.5, 0.5, 0.6, 0.8))
	vbox.add_child(star_lbl)

	# Equip / Unequip Buttons
	if is_unlocked:
		var sid: String = skin.get("id", "")
		if is_equipped:
			var btn_box := HBoxContainer.new()
			btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
			btn_box.add_theme_constant_override("separation", 6)
			vbox.add_child(btn_box)

			var eq_lbl := Label.new()
			eq_lbl.text = "✅ ACTIVA"
			eq_lbl.add_theme_font_size_override("font_size", 11)
			eq_lbl.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4, 1.0))
			btn_box.add_child(eq_lbl)

			var unequip_btn := Button.new()
			unequip_btn.text = "QUITAR"
			unequip_btn.custom_minimum_size = Vector2(70, 26)
			unequip_btn.add_theme_font_size_override("font_size", 10)
			unequip_btn.pressed.connect(func():
				SaveManager.unequip_skin(slot_key)
				skin_equipped.emit(slot_key, "")
				_filter_wardrobe(_active_category_filter)
			)
			UIFocusHelper.apply_cyber_focus(unequip_btn)
			btn_box.add_child(unequip_btn)
		else:
			var eq_btn := Button.new()
			eq_btn.text = "EQUIPAR"
			eq_btn.custom_minimum_size = Vector2(110, 28)
			eq_btn.pressed.connect(func():
				SaveManager.equip_skin(slot_key, sid)
				skin_equipped.emit(slot_key, sid)
				_filter_wardrobe(_active_category_filter)
			)
			UIFocusHelper.apply_cyber_focus(eq_btn)
			vbox.add_child(eq_btn)

	return frame


func close_modal() -> void:
	_on_close_pressed()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		if _reveal_overlay and _reveal_overlay.visible:
			_on_skip_reveal_pressed()
			get_viewport().set_input_as_handled()
			return
		if _results_layer and _results_layer.visible:
			_results_layer.hide()
			_refresh_currency()
			_refresh_banner_info()
			get_viewport().set_input_as_handled()
			return
		close_modal()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER)):
		if _reveal_overlay and _reveal_overlay.visible:
			if _reveal_capsule_btn.visible:
				_on_capsule_opened()
			else:
				_show_next_capsule()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _reveal_overlay and _reveal_overlay.visible:
			if _reveal_capsule_btn.visible:
				_on_capsule_opened()
			else:
				_show_next_capsule()
			get_viewport().set_input_as_handled()


func _on_close_pressed() -> void:
	hide()
	get_tree().paused = false
	modal_closed.emit()

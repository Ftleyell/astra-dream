class_name GachaModal
extends CanvasLayer

## GachaModal.gd
## Orquestador desacoplado de la Máquina de Cápsulas Gacha y Armario de Cosméticos:
## - Cúpula procedural con físicas y actuador arcade táctil (GachaDomeWidget).
## - Banners temáticos ("Estelar General", "Hangar de Naves", "Academia de Pilotos").
## - Coordinación de tiradas y pity mediante GachaPullCoordinator.
## - Revelación cinematográfica y resumen de recompensas mediante GachaRevealTheater.
## - Armario y colección de skins mediante GachaWardrobeController.

const CosmeticsManager = preload("res://core/systems/cosmetics_manager.gd")
const SaveManager = preload("res://core/autoloads/save_manager.gd")
const GachaDomeWidgetClass = preload("res://scenes/ui/gacha/gacha_dome_widget.gd")
const GachaPullCoordinatorClass = preload("res://scenes/ui/gacha/components/gacha_pull_coordinator.gd")
const GachaRevealTheaterClass = preload("res://scenes/ui/gacha/components/gacha_reveal_theater.gd")
const GachaWardrobeControllerClass = preload("res://scenes/ui/gacha/components/gacha_wardrobe_controller.gd")
const GachaBannerEngineClass = preload("res://scenes/ui/gacha/components/gacha_banner_engine.gd")

signal skin_unlocked(skin_id: String, stars: int)
signal skin_equipped(slot_key: String, skin_id: String)
signal modal_closed()

var is_animating: bool = false
var _active_tab: int = 0 # 0 = Gacha, 1 = Wardrobe
var _active_banner_id: String = "general"

const BANNERS_CONFIG := GachaBannerEngineClass.BANNERS_CONFIG

# Sub-Controllers
var _pull_coordinator: RefCounted
var _reveal_theater: Control
var _wardrobe_controller: RefCounted

# UI Nodes
var _panel: PanelContainer
var _token_count_label: Label
var _biomass_count_label: Label
var _tab_gacha_btn: Button
var _tab_wardrobe_btn: Button

# Gacha Tab Elements
var _gacha_content: VBoxContainer
var _banner_buttons_box: HBoxContainer
var _banner_title_label: Label
var _banner_desc_label: Label
var _pity_count_label: Label
var _pity_progress_bar: ProgressBar
var _dome_widget: GachaDomeWidget
var _lever_btn: Button
var _pull_1_btn: Button
var _pull_5_btn: Button
var _pull_10_btn: Button

# Backwards Compatibility Facades for test suite
var _hide_locked: bool:
	get:
		return _wardrobe_controller.hide_locked if _wardrobe_controller else false
	set(val):
		if _wardrobe_controller:
			_wardrobe_controller.hide_locked = val

var _hide_locked_check: CheckBox:
	get:
		return _wardrobe_controller.hide_locked_check if _wardrobe_controller else null

var _wardrobe_grid: GridContainer:
	get:
		return _wardrobe_controller.wardrobe_grid if _wardrobe_controller else null

var _wardrobe_content: VBoxContainer:
	get:
		return _wardrobe_controller.wardrobe_content if _wardrobe_controller else null

var _active_category_filter: String:
	get:
		return _wardrobe_controller.active_category_filter if _wardrobe_controller else "all"


func _ready() -> void:
	layer = 130
	process_mode = Node.PROCESS_MODE_ALWAYS
	_pull_coordinator = GachaPullCoordinatorClass.new()
	_wardrobe_controller = GachaWardrobeControllerClass.new()
	_wardrobe_controller.skin_equipped.connect(_on_wardrobe_skin_equipped)
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
	_tab_gacha_btn.pressed.connect(func() -> void: _switch_tab(0))
	UIFocusHelper.apply_cyber_focus(_tab_gacha_btn)
	tab_bar.add_child(_tab_gacha_btn)

	_tab_wardrobe_btn = Button.new()
	_tab_wardrobe_btn.text = "👗 ARMARIO / COLECCIÓN DE SKINS"
	_tab_wardrobe_btn.custom_minimum_size = Vector2(280, 36)
	_tab_wardrobe_btn.pressed.connect(func() -> void: _switch_tab(1))
	UIFocusHelper.apply_cyber_focus(_tab_wardrobe_btn)
	tab_bar.add_child(_tab_wardrobe_btn)

	var separator := HSeparator.new()
	root_vbox.add_child(separator)

	# --- TAB 1: GACHA CONTENT ---
	_gacha_content = VBoxContainer.new()
	_gacha_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_gacha_content.add_theme_constant_override("separation", 10)
	root_vbox.add_child(_gacha_content)

	# Banner Selector Bar
	_banner_buttons_box = HBoxContainer.new()
	_banner_buttons_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_banner_buttons_box.add_theme_constant_override("separation", 16)
	_gacha_content.add_child(_banner_buttons_box)

	var banner_keys: Array[String] = ["general", "ships", "pilots"]
	var banner_labels: Array[String] = ["🌌 BANNER GENERAL", "🚀 HANGAR NAVES", "👩‍✈️ ACADEMIA PILOTOS"]
	for i: int in range(banner_keys.size()):
		var bid: String = banner_keys[i]
		var b_btn := Button.new()
		b_btn.text = banner_labels[i]
		b_btn.custom_minimum_size = Vector2(200, 34)
		b_btn.pressed.connect(func() -> void: _select_banner(bid))
		UIFocusHelper.apply_cyber_focus(b_btn)
		_banner_buttons_box.add_child(b_btn)

	# Main Stage HBox
	var main_stage_hbox := HBoxContainer.new()
	main_stage_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_stage_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_stage_hbox.add_theme_constant_override("separation", 24)
	_gacha_content.add_child(main_stage_hbox)

	# Left Column: Banner Info Panel
	var banner_info_panel := PanelContainer.new()
	banner_info_panel.custom_minimum_size = Vector2(280, 0)
	var bib_sb := StyleBoxFlat.new()
	bib_sb.bg_color = Color(0.06, 0.05, 0.14, 0.9)
	bib_sb.border_color = Color(0.1, 0.4, 0.7, 0.6)
	bib_sb.set_border_width_all(2)
	bib_sb.set_corner_radius_all(10)
	bib_sb.content_margin_left = 16
	bib_sb.content_margin_right = 16
	bib_sb.content_margin_top = 16
	bib_sb.content_margin_bottom = 16
	banner_info_panel.add_theme_stylebox_override("panel", bib_sb)
	main_stage_hbox.add_child(banner_info_panel)

	var banner_vbox := VBoxContainer.new()
	banner_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	banner_vbox.add_theme_constant_override("separation", 10)
	banner_info_panel.add_child(banner_vbox)

	_banner_title_label = Label.new()
	_banner_title_label.text = "BANNER ACTIVO"
	_banner_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner_title_label.add_theme_font_size_override("font_size", 14)
	banner_vbox.add_child(_banner_title_label)

	_banner_desc_label = Label.new()
	_banner_desc_label.text = "Descripción del banner..."
	_banner_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner_desc_label.add_theme_font_size_override("font_size", 12)
	_banner_desc_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.95, 0.8))
	banner_vbox.add_child(_banner_desc_label)

	var p_sep := HSeparator.new()
	banner_vbox.add_child(p_sep)

	var pity_vbox := VBoxContainer.new()
	pity_vbox.add_theme_constant_override("separation", 6)
	banner_vbox.add_child(pity_vbox)

	_pity_count_label = Label.new()
	_pity_count_label.text = "⚡ PITY: 0 / 10"
	_pity_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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

	# Right Column: Lever & Controls
	var right_controls_vbox := VBoxContainer.new()
	right_controls_vbox.custom_minimum_size = Vector2(280, 0)
	right_controls_vbox.add_theme_constant_override("separation", 14)
	right_controls_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_stage_hbox.add_child(right_controls_vbox)

	_lever_btn = Button.new()
	_lever_btn.text = "🕹️ GIRAR PALANCA ARCADE\n[ Tirada Rápida x1 ]"
	_lever_btn.custom_minimum_size = Vector2(260, 68)
	_lever_btn.pressed.connect(func() -> void: _on_lever_pulled())
	UIFocusHelper.apply_cyber_focus(_lever_btn)
	right_controls_vbox.add_child(_lever_btn)

	var lever_hint := Label.new()
	lever_hint.text = "Acciona el mecanismo magnético de la máquina"
	lever_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lever_hint.add_theme_font_size_override("font_size", 11)
	lever_hint.add_theme_color_override("font_color", Color(0.5, 0.7, 0.9, 0.8))
	right_controls_vbox.add_child(lever_hint)

	# Bottom Pull Buttons Row
	var roll_btn_box := HBoxContainer.new()
	roll_btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	roll_btn_box.add_theme_constant_override("separation", 24)
	_gacha_content.add_child(roll_btn_box)

	_pull_1_btn = Button.new()
	_pull_1_btn.text = "🎟️ TIRADA SIMPLE\n(1 Ficha)"
	_pull_1_btn.custom_minimum_size = Vector2(190, 52)
	_pull_1_btn.pressed.connect(func() -> void: _start_gacha_sequence(1))
	UIFocusHelper.apply_cyber_focus(_pull_1_btn)
	roll_btn_box.add_child(_pull_1_btn)

	_pull_5_btn = Button.new()
	_pull_5_btn.text = "🎟️ MULTI-TIRADA x5\n(5 Fichas)"
	_pull_5_btn.custom_minimum_size = Vector2(190, 52)
	_pull_5_btn.pressed.connect(func() -> void: _start_gacha_sequence(5))
	UIFocusHelper.apply_cyber_focus(_pull_5_btn)
	roll_btn_box.add_child(_pull_5_btn)

	_pull_10_btn = Button.new()
	_pull_10_btn.text = "🎟️ MULTI-TIRADA x10\n(10 Fichas)"
	_pull_10_btn.custom_minimum_size = Vector2(190, 52)
	_pull_10_btn.pressed.connect(func() -> void: _start_gacha_sequence(10))
	UIFocusHelper.apply_cyber_focus(_pull_10_btn)
	roll_btn_box.add_child(_pull_10_btn)

	# --- TAB 2: WARDROBE CONTENT ---
	_wardrobe_controller.setup(root_vbox)

	# --- OVERLAYS: REVEAL THEATER ---
	_reveal_theater = GachaRevealTheaterClass.new()
	_reveal_theater.setup(_panel)
	_reveal_theater.sequence_finished.connect(_on_reveal_theater_finished)

	_refresh_banner_info()


func _select_banner(banner_id: String) -> void:
	if is_animating or (_reveal_theater and _reveal_theater.is_theater_active()):
		return
	_active_banner_id = banner_id
	_refresh_banner_info()
	var audio_mgr: Node = get_node_or_null("/root/AudioManager")
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

	if _banner_buttons_box:
		var b_keys: Array[String] = ["general", "ships", "pilots"]
		for i: int in range(_banner_buttons_box.get_child_count()):
			var btn: Button = _banner_buttons_box.get_child(i) as Button
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
	var tokens: int = SaveManager.get_gacha_tokens()
	var bio: int = SaveManager.get_biomass()
	if _token_count_label:
		_token_count_label.text = "🎟️ Fichas: %d" % tokens
	if _biomass_count_label:
		_biomass_count_label.text = "✨ Polvo Estelar: %d" % bio


func _switch_tab(tab_idx: int) -> void:
	_active_tab = tab_idx
	if tab_idx == 0:
		_gacha_content.show()
		if _wardrobe_content:
			_wardrobe_content.hide()
		_tab_gacha_btn.modulate = Color(0.2, 1.0, 0.8, 1.0)
		_tab_wardrobe_btn.modulate = Color(0.7, 0.7, 0.7, 1.0)
		_refresh_banner_info()
	else:
		_gacha_content.hide()
		if _wardrobe_content:
			_wardrobe_content.show()
		_tab_gacha_btn.modulate = Color(0.7, 0.7, 0.7, 1.0)
		_tab_wardrobe_btn.modulate = Color(0.2, 1.0, 0.8, 1.0)
		_filter_wardrobe(_active_category_filter)


func _filter_wardrobe(category_id: String) -> void:
	if _wardrobe_controller:
		_wardrobe_controller.filter_wardrobe(category_id)


func execute_pulls(count: int) -> Array[Dictionary]:
	if not _pull_coordinator:
		return []
	var results: Array[Dictionary] = _pull_coordinator.execute_pulls(count, _active_banner_id)
	if not results.is_empty():
		_refresh_currency()
		_refresh_banner_info()
	return results


func _on_lever_pulled() -> void:
	if is_animating or (_reveal_theater and _reveal_theater.is_theater_active()):
		return
	var current_tokens: int = SaveManager.get_gacha_tokens()
	if current_tokens < 1:
		_flash_no_tokens()
		return

	if _lever_btn:
		var tw: Tween = create_tween()
		if tw:
			tw.tween_property(_lever_btn, "scale", Vector2(0.92, 0.92), 0.1)
			tw.tween_property(_lever_btn, "scale", Vector2.ONE, 0.15)

	var audio_mgr: Node = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("ui_click")

	_start_gacha_sequence(1)


func _start_gacha_sequence(count: int) -> void:
	if is_animating or (_reveal_theater and _reveal_theater.is_theater_active()):
		return
	var current_tokens: int = SaveManager.get_gacha_tokens()
	if current_tokens < count:
		_flash_no_tokens()
		return

	is_animating = true
	if _dome_widget:
		_dome_widget.trigger_spin_and_shake(1.0)

	var audio_mgr: Node = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("satellite_activate")

	var results: Array[Dictionary] = execute_pulls(count)
	if results.is_empty():
		is_animating = false
		return

	get_tree().create_timer(0.9).timeout.connect(func() -> void:
		if _reveal_theater:
			_reveal_theater.start_sequence(results)
	)


func _on_reveal_theater_finished() -> void:
	is_animating = false
	_refresh_currency()
	_refresh_banner_info()


func _flash_no_tokens() -> void:
	if _token_count_label:
		_token_count_label.modulate = Color(1.0, 0.2, 0.2, 1.0)
		var tw: Tween = create_tween()
		if tw:
			tw.tween_property(_token_count_label, "modulate", Color.WHITE, 0.6)


func _on_wardrobe_skin_equipped(slot_key: String, skin_id: String) -> void:
	skin_equipped.emit(slot_key, skin_id)


func close_modal() -> void:
	_on_close_pressed()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		if _reveal_theater and _reveal_theater.is_theater_active():
			_reveal_theater.skip_sequence()
			get_viewport().set_input_as_handled()
			return
		close_modal()
		get_viewport().set_input_as_handled()


func _on_close_pressed() -> void:
	hide()
	get_tree().paused = false
	modal_closed.emit()

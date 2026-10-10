class_name GachaModalLayoutBuilder
extends RefCounted

## GachaModalLayoutBuilder.gd
## Constructor de la interfaz y elementos visuales para GachaModal.
## Desacopla la creación masiva procedural de contenedores, paneles, botones y banners.

const GachaDomeWidgetClass = preload("res://scenes/ui/gacha/gacha_dome_widget.gd")
const GachaRevealTheaterClass = preload("res://scenes/ui/gacha/components/gacha_reveal_theater.gd")


func build_modal_ui(modal: GachaModal) -> void:
	if not modal:
		return

	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.01, 0.05, 0.85)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal.add_child(center)

	modal._panel = PanelContainer.new()
	modal._panel.custom_minimum_size = Vector2(1040, 720)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.03, 0.10, 0.98)
	sb.border_color = Color(0.0, 0.94, 1.0, 0.9)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	modal._panel.add_theme_stylebox_override("panel", sb)
	center.add_child(modal._panel)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 10)
	modal._panel.add_child(root_vbox)

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

	modal._token_count_label = Label.new()
	modal._token_count_label.text = "🎟️ Fichas: 0"
	modal._token_count_label.add_theme_font_size_override("font_size", 16)
	modal._token_count_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0))
	top_bar.add_child(modal._token_count_label)

	var token_spacer := Control.new()
	token_spacer.custom_minimum_size = Vector2(20, 0)
	top_bar.add_child(token_spacer)

	modal._biomass_count_label = Label.new()
	modal._biomass_count_label.text = "✨ Polvo Estelar: 0"
	modal._biomass_count_label.add_theme_font_size_override("font_size", 16)
	modal._biomass_count_label.add_theme_color_override("font_color", Color(0.8, 0.4, 1.0, 1.0))
	top_bar.add_child(modal._biomass_count_label)

	var close_btn := Button.new()
	close_btn.text = " ✖ CERRAR "
	close_btn.pressed.connect(modal._on_close_pressed)
	UIFocusHelper.apply_cyber_focus(close_btn)
	top_bar.add_child(close_btn)

	# --- TAB SWITCHER ---
	var tab_bar := HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 16)
	root_vbox.add_child(tab_bar)

	modal._tab_gacha_btn = Button.new()
	modal._tab_gacha_btn.text = "🎰 MÁQUINA DE TIRADAS"
	modal._tab_gacha_btn.custom_minimum_size = Vector2(240, 36)
	modal._tab_gacha_btn.pressed.connect(func() -> void: modal._switch_tab(0))
	UIFocusHelper.apply_cyber_focus(modal._tab_gacha_btn)
	tab_bar.add_child(modal._tab_gacha_btn)

	modal._tab_wardrobe_btn = Button.new()
	modal._tab_wardrobe_btn.text = "👗 ARMARIO / COLECCIÓN DE SKINS"
	modal._tab_wardrobe_btn.custom_minimum_size = Vector2(280, 36)
	modal._tab_wardrobe_btn.pressed.connect(func() -> void: modal._switch_tab(1))
	UIFocusHelper.apply_cyber_focus(modal._tab_wardrobe_btn)
	tab_bar.add_child(modal._tab_wardrobe_btn)

	var separator := HSeparator.new()
	root_vbox.add_child(separator)

	# --- TAB 1: GACHA CONTENT ---
	modal._gacha_content = VBoxContainer.new()
	modal._gacha_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	modal._gacha_content.add_theme_constant_override("separation", 10)
	root_vbox.add_child(modal._gacha_content)

	# Banner Selector Bar
	modal._banner_buttons_box = HBoxContainer.new()
	modal._banner_buttons_box.alignment = BoxContainer.ALIGNMENT_CENTER
	modal._banner_buttons_box.add_theme_constant_override("separation", 16)
	modal._gacha_content.add_child(modal._banner_buttons_box)

	var banner_keys: Array[String] = ["general", "ships", "pilots"]
	var banner_labels: Array[String] = ["🌌 BANNER GENERAL", "🚀 HANGAR NAVES", "👩‍✈️ ACADEMIA PILOTOS"]
	for i: int in range(banner_keys.size()):
		var bid: String = banner_keys[i]
		var b_btn := Button.new()
		b_btn.text = banner_labels[i]
		b_btn.custom_minimum_size = Vector2(200, 34)
		b_btn.pressed.connect(func() -> void: modal._select_banner(bid))
		UIFocusHelper.apply_cyber_focus(b_btn)
		modal._banner_buttons_box.add_child(b_btn)

	# Main Stage HBox
	var main_stage_hbox := HBoxContainer.new()
	main_stage_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_stage_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_stage_hbox.add_theme_constant_override("separation", 24)
	modal._gacha_content.add_child(main_stage_hbox)

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

	modal._banner_title_label = Label.new()
	modal._banner_title_label.text = "BANNER ACTIVO"
	modal._banner_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	modal._banner_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal._banner_title_label.add_theme_font_size_override("font_size", 14)
	banner_vbox.add_child(modal._banner_title_label)

	modal._banner_desc_label = Label.new()
	modal._banner_desc_label.text = "Descripción del banner..."
	modal._banner_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	modal._banner_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modal._banner_desc_label.add_theme_font_size_override("font_size", 12)
	modal._banner_desc_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.95, 0.8))
	banner_vbox.add_child(modal._banner_desc_label)

	var p_sep := HSeparator.new()
	banner_vbox.add_child(p_sep)

	var pity_vbox := VBoxContainer.new()
	pity_vbox.add_theme_constant_override("separation", 6)
	banner_vbox.add_child(pity_vbox)

	modal._pity_count_label = Label.new()
	modal._pity_count_label.text = "⚡ PITY: 0 / 10"
	modal._pity_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	modal._pity_count_label.add_theme_font_size_override("font_size", 13)
	modal._pity_count_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0))
	pity_vbox.add_child(modal._pity_count_label)

	modal._pity_progress_bar = ProgressBar.new()
	modal._pity_progress_bar.custom_minimum_size = Vector2(0, 16)
	modal._pity_progress_bar.max_value = 10.0
	modal._pity_progress_bar.value = 0.0
	modal._pity_progress_bar.show_percentage = false
	pity_vbox.add_child(modal._pity_progress_bar)

	var pity_hint := Label.new()
	pity_hint.text = "Garantiza skin Épica al alcanzar 10 tiradas."
	pity_hint.add_theme_font_size_override("font_size", 11)
	pity_hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8, 0.7))
	pity_vbox.add_child(pity_hint)

	# Center Column: Glass Dome Widget
	var center_dome_vbox := VBoxContainer.new()
	center_dome_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_stage_hbox.add_child(center_dome_vbox)

	modal._dome_widget = GachaDomeWidgetClass.new()
	center_dome_vbox.add_child(modal._dome_widget)

	# Right Column: Lever & Controls
	var right_controls_vbox := VBoxContainer.new()
	right_controls_vbox.custom_minimum_size = Vector2(280, 0)
	right_controls_vbox.add_theme_constant_override("separation", 14)
	right_controls_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_stage_hbox.add_child(right_controls_vbox)

	modal._lever_btn = Button.new()
	modal._lever_btn.text = "🕹️ GIRAR PALANCA ARCADE\n[ Tirada Rápida x1 ]"
	modal._lever_btn.custom_minimum_size = Vector2(260, 68)
	modal._lever_btn.pressed.connect(func() -> void: modal._on_lever_pulled())
	UIFocusHelper.apply_cyber_focus(modal._lever_btn)
	right_controls_vbox.add_child(modal._lever_btn)

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
	modal._gacha_content.add_child(roll_btn_box)

	modal._pull_1_btn = Button.new()
	modal._pull_1_btn.text = "🎟️ TIRADA SIMPLE\n(1 Ficha)"
	modal._pull_1_btn.custom_minimum_size = Vector2(190, 52)
	modal._pull_1_btn.pressed.connect(func() -> void: modal._start_gacha_sequence(1))
	UIFocusHelper.apply_cyber_focus(modal._pull_1_btn)
	roll_btn_box.add_child(modal._pull_1_btn)

	modal._pull_5_btn = Button.new()
	modal._pull_5_btn.text = "🎟️ MULTI-TIRADA x5\n(5 Fichas)"
	modal._pull_5_btn.custom_minimum_size = Vector2(190, 52)
	modal._pull_5_btn.pressed.connect(func() -> void: modal._start_gacha_sequence(5))
	UIFocusHelper.apply_cyber_focus(modal._pull_5_btn)
	roll_btn_box.add_child(modal._pull_5_btn)

	modal._pull_10_btn = Button.new()
	modal._pull_10_btn.text = "🎟️ MULTI-TIRADA x10\n(10 Fichas)"
	modal._pull_10_btn.custom_minimum_size = Vector2(190, 52)
	modal._pull_10_btn.pressed.connect(func() -> void: modal._start_gacha_sequence(10))
	UIFocusHelper.apply_cyber_focus(modal._pull_10_btn)
	roll_btn_box.add_child(modal._pull_10_btn)

	# --- TAB 2: WARDROBE CONTENT ---
	modal._wardrobe_controller.setup(root_vbox)

	# --- OVERLAYS: REVEAL THEATER ---
	modal._reveal_theater = GachaRevealTheaterClass.new()
	modal._reveal_theater.setup(modal._panel)
	modal._reveal_theater.sequence_finished.connect(modal._on_reveal_theater_finished)

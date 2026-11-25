class_name Gacha3DLabOverlay
extends CanvasLayer

## Overlay UI Astral Pop-Ink para Gacha3DLab (Fase 2).
## Gestiona Standby HUD, Overlay Cinematográfico (Saltar >= 0.20s + banner Fake-Out)
## y Reveal Overlay (×1 con inspector vivo o ×5/×10 con cascada animada y pausa heroica épica)
## usando un único ShaderSkinLivePreview compartido.

signal banner_selected(banner_id: String)
signal pull_requested(count: int)
signal refill_tokens_requested()
signal override_changed(override_idx: int)
signal skip_requested()
signal equip_reward_requested(reward_item: Dictionary)
signal reveal_closed()
signal reset_requested()
signal open_hub_art_lab_requested()
signal back_to_workbench_requested()

const ConfigScript = preload("res://scenes/ui/hub/astral_station/resources/hub_gacha_3d_config.gd")
const GachaBannerEngineScript = preload("res://scenes/ui/gacha/components/gacha_banner_engine.gd")
const CosmeticsManagerScript = preload("res://core/systems/cosmetics_manager.gd")
const CharacterDataScript = preload("res://data/characters/character_data.gd")
const ShaderSkinLivePreviewScript = preload("res://scenes/ui/cosmetics/components/shader_skin_live_preview.gd")
const ShaderSkinSwatchScript = preload("res://scenes/ui/cosmetics/components/shader_skin_swatch.gd")

const COLOR_BG_PANEL: Color = Color(0.035, 0.048, 0.102, 0.92)
const COLOR_ASTRAL_GOLD: Color = Color(0.95, 0.80, 0.34, 1.0)
const COLOR_PSYCHOPOP_PINK: Color = Color(1.0, 0.16, 0.62, 1.0)
const COLOR_CYAN_POP: Color = Color(0.08, 0.92, 1.0, 1.0)

var _config: ConfigScript = null
var _ui_built: bool = false
var _sandbox_panel_visible: bool = true
var _station_clean_mode: bool = false
var _station_exit_btn: Button = null

# Capas principales
var _standby_root: Control = null
var _cinematic_root: Control = null
var _reveal_root: Control = null

# Standby HUD
var _tokens_label: Label = null
var _pity_label: Label = null
var _pity_bar: ProgressBar = null
var _banner_title_label: Label = null
var _banner_desc_label: Label = null
var _equipped_status_label: Label = null
var _banner_buttons: Dictionary = {}
var _pull_buttons: Dictionary = {}
var _sandbox_panel: PanelContainer = null
var _override_option: OptionButton = null
var _telemetry_label: Label = null

# Cinematic Overlay
var _cinematic_phase_label: Label = null
var _fakeout_banner: PanelContainer = null
var _skip_btn: Button = null

# Reveal Overlay
var _cascade_panel: PanelContainer = null
var _cascade_grid: GridContainer = null
var _skip_cascade_btn: Button = null
var _inspector_panel: PanelContainer = null
var _shared_live_preview: ShaderSkinLivePreview = null
var _shared_legacy_tex: TextureRect = null
var _reward_title_label: Label = null
var _reward_meta_label: Label = null
var _reward_badges_label: Label = null
var _reward_status_label: Label = null
var _equip_btn: Button = null
var _pull_again_btn: Button = null

# Estado de revelación y cascada
var _current_batch: Dictionary = {}
var _current_rewards: Array[Dictionary] = []
var _cascade_cards: Array[Button] = []
var _selected_reward_idx: int = -1
var _cascade_active: bool = false
var _cascade_revealed_count: int = 0
var _cascade_timer: float = 0.0
var _last_banner_id: String = "general"


func setup(p_config: ConfigScript) -> void:
	_config = p_config
	_ensure_ui()
	set_standby_mode()


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_ui()


func _process(delta: float) -> void:
	if not _cascade_active or _reveal_root == null or not _reveal_root.visible:
		return
	if _cascade_revealed_count >= _cascade_cards.size():
		_finish_cascade()
		return
	_cascade_timer -= delta
	if _cascade_timer <= 0.0:
		_reveal_next_cascade_card()


func _ensure_ui() -> void:
	if _ui_built:
		return
	_build_standby_ui()
	_build_cinematic_ui()
	_build_reveal_ui()
	_ui_built = true


func _build_standby_ui() -> void:
	_standby_root = Control.new()
	_standby_root.name = "StandbyRoot"
	_standby_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_standby_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_standby_root)

	# Panel superior izquierdo (Estado, Fichas, Pity, Equipamiento)
	var top_panel := PanelContainer.new()
	top_panel.position = Vector2(18.0, 14.0)
	top_panel.custom_minimum_size = Vector2(450.0, 0.0)
	top_panel.add_theme_stylebox_override("panel", _make_panel_style(COLOR_BG_PANEL, COLOR_ASTRAL_GOLD))
	_standby_root.add_child(top_panel)

	var top_vbox := VBoxContainer.new()
	top_vbox.add_theme_constant_override("separation", 6)
	top_panel.add_child(top_vbox)

	var title_lbl := Label.new()
	title_lbl.text = "INVOCADOR GIROSCÓPICO 3D — ALA ESTE PSYCHO-POP"
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.add_theme_color_override("font_color", COLOR_ASTRAL_GOLD)
	top_vbox.add_child(title_lbl)

	var currency_row := HBoxContainer.new()
	currency_row.add_theme_constant_override("separation", 10)
	top_vbox.add_child(currency_row)

	_tokens_label = Label.new()
	_tokens_label.text = "Fichas Astrales: 30"
	_tokens_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tokens_label.add_theme_font_size_override("font_size", 15)
	_tokens_label.add_theme_color_override("font_color", COLOR_CYAN_POP)
	currency_row.add_child(_tokens_label)

	var refill_btn := Button.new()
	refill_btn.name = "RefillTokensButton"
	refill_btn.text = "+20 Fichas"
	refill_btn.focus_mode = Control.FOCUS_NONE
	refill_btn.pressed.connect(func() -> void: refill_tokens_requested.emit())
	currency_row.add_child(refill_btn)

	_banner_title_label = Label.new()
	_banner_title_label.add_theme_font_size_override("font_size", 13)
	top_vbox.add_child(_banner_title_label)

	_banner_desc_label = Label.new()
	_banner_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner_desc_label.add_theme_font_size_override("font_size", 11)
	_banner_desc_label.add_theme_color_override("font_color", Color(0.82, 0.88, 0.96, 0.92))
	top_vbox.add_child(_banner_desc_label)

	_pity_label = Label.new()
	_pity_label.text = "PITY: 0 / 10"
	_pity_label.add_theme_font_size_override("font_size", 12)
	top_vbox.add_child(_pity_label)

	_pity_bar = ProgressBar.new()
	_pity_bar.min_value = 0.0
	_pity_bar.max_value = float(GachaBannerEngineScript.PITY_THRESHOLD)
	_pity_bar.step = 1.0
	_pity_bar.custom_minimum_size = Vector2(0.0, 12.0)
	_pity_bar.show_percentage = false
	top_vbox.add_child(_pity_bar)

	_equipped_status_label = Label.new()
	_equipped_status_label.text = "Valentina (Vivo): Aspecto Base"
	_equipped_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_equipped_status_label.add_theme_font_size_override("font_size", 11)
	_equipped_status_label.add_theme_color_override("font_color", Color(0.95, 0.68, 0.86, 1.0))
	top_vbox.add_child(_equipped_status_label)

	# Panel derecho Sandbox (ocultable con [H])
	_sandbox_panel = PanelContainer.new()
	_sandbox_panel.name = "SandboxSidePanel"
	_sandbox_panel.anchor_left = 1.0
	_sandbox_panel.anchor_right = 1.0
	_sandbox_panel.offset_left = -318.0
	_sandbox_panel.offset_top = 14.0
	_sandbox_panel.offset_right = -16.0
	_sandbox_panel.add_theme_stylebox_override("panel", _make_panel_style(COLOR_BG_PANEL, COLOR_PSYCHOPOP_PINK))
	_standby_root.add_child(_sandbox_panel)

	var sb_vbox := VBoxContainer.new()
	sb_vbox.add_theme_constant_override("separation", 8)
	_sandbox_panel.add_child(sb_vbox)

	var sb_hdr := Label.new()
	sb_hdr.text = "CONTROL SANDBOX [H]"
	sb_hdr.add_theme_font_size_override("font_size", 13)
	sb_hdr.add_theme_color_override("font_color", COLOR_PSYCHOPOP_PINK)
	sb_vbox.add_child(sb_hdr)

	var ov_lbl := Label.new()
	ov_lbl.text = "Modo de Probabilidad / Override:"
	ov_lbl.add_theme_font_size_override("font_size", 11)
	sb_vbox.add_child(ov_lbl)

	_override_option = OptionButton.new()
	_override_option.name = "OverrideOption"
	_override_option.focus_mode = Control.FOCUS_NONE
	_override_option.add_item("Natural (15% Épico / Pity 10)")
	_override_option.add_item("Forzar Común (Cian)")
	_override_option.add_item("Forzar Épico (Oro/Carmesí)")
	_override_option.add_item("Forzar Pity (Garantizado 10/10)")
	_override_option.add_item("Forzar Fake-Out (Ruptura Cian->Oro)")
	_override_option.item_selected.connect(func(idx: int) -> void: override_changed.emit(idx))
	sb_vbox.add_child(_override_option)

	_telemetry_label = Label.new()
	_telemetry_label.text = "Estado: IDLE  |  [1..3] Banner  [Q/W/E] ×1/×5/×10"
	_telemetry_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_telemetry_label.add_theme_font_size_override("font_size", 11)
	_telemetry_label.add_theme_color_override("font_color", Color(0.84, 0.90, 0.98, 0.9))
	sb_vbox.add_child(_telemetry_label)

	var reset_btn := Button.new()
	reset_btn.text = "Resetear Sesión Simulada"
	reset_btn.focus_mode = Control.FOCUS_NONE
	reset_btn.pressed.connect(func() -> void: reset_requested.emit())
	sb_vbox.add_child(reset_btn)

	var nav_row := HBoxContainer.new()
	nav_row.add_theme_constant_override("separation", 6)
	sb_vbox.add_child(nav_row)

	var hub_lab_btn := Button.new()
	hub_lab_btn.text = "HubArtLab"
	hub_lab_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hub_lab_btn.focus_mode = Control.FOCUS_NONE
	hub_lab_btn.pressed.connect(func() -> void: open_hub_art_lab_requested.emit())
	nav_row.add_child(hub_lab_btn)

	var wb_btn := Button.new()
	wb_btn.text = "WorkbenchHub"
	wb_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wb_btn.focus_mode = Control.FOCUS_NONE
	wb_btn.pressed.connect(func() -> void: back_to_workbench_requested.emit())
	nav_row.add_child(wb_btn)

	# Dock inferior centrado: Banners + Botones de tirada ×1 / ×5 / ×10
	var dock := PanelContainer.new()
	dock.anchor_left = 0.5
	dock.anchor_right = 0.5
	dock.anchor_top = 1.0
	dock.anchor_bottom = 1.0
	dock.offset_left = -380.0
	dock.offset_right = 380.0
	dock.offset_top = -124.0
	dock.offset_bottom = -16.0
	dock.add_theme_stylebox_override("panel", _make_panel_style(COLOR_BG_PANEL, COLOR_CYAN_POP))
	_standby_root.add_child(dock)

	var dock_vbox := VBoxContainer.new()
	dock_vbox.add_theme_constant_override("separation", 8)
	dock.add_child(dock_vbox)

	var banner_row := HBoxContainer.new()
	banner_row.add_theme_constant_override("separation", 8)
	dock_vbox.add_child(banner_row)

	var banner_specs: Array[Dictionary] = [
		{"id": "general", "label": "[1] Estelar General"},
		{"id": "ships", "label": "[2] Alas & Armas"},
		{"id": "pilots", "label": "[3] Academia Pilotos"},
	]
	for spec: Dictionary in banner_specs:
		var bid: String = str(spec["id"])
		var btn := Button.new()
		btn.name = "BannerBtn_%s" % bid
		btn.text = str(spec["label"])
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(func() -> void: banner_selected.emit(bid))
		banner_row.add_child(btn)
		_banner_buttons[bid] = btn

	var pull_row := HBoxContainer.new()
	pull_row.add_theme_constant_override("separation", 10)
	dock_vbox.add_child(pull_row)

	for p_spec: Dictionary in [
		{"count": 1, "label": "INVOCAR ×1 [Q]"},
		{"count": 5, "label": "INVOCAR ×5 [W]"},
		{"count": 10, "label": "INVOCAR ×10 [E]"},
	]:
		var cnt: int = int(p_spec["count"])
		var p_btn := Button.new()
		p_btn.name = "PullBtn_%d" % cnt
		p_btn.text = str(p_spec["label"])
		p_btn.custom_minimum_size = Vector2(0.0, 42.0)
		p_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		p_btn.focus_mode = Control.FOCUS_NONE
		p_btn.pressed.connect(func() -> void: pull_requested.emit(cnt))
		pull_row.add_child(p_btn)
		_pull_buttons[cnt] = p_btn

	_station_exit_btn = Button.new()
	_station_exit_btn.name = "StationExitGachaButton"
	_station_exit_btn.text = "Volver a la Estación [ESC]"
	_station_exit_btn.anchor_left = 1.0
	_station_exit_btn.anchor_right = 1.0
	_station_exit_btn.offset_left = -240.0
	_station_exit_btn.offset_top = 18.0
	_station_exit_btn.offset_right = -18.0
	_station_exit_btn.offset_bottom = 54.0
	_station_exit_btn.focus_mode = Control.FOCUS_NONE
	_station_exit_btn.visible = false
	_station_exit_btn.pressed.connect(func() -> void: open_hub_art_lab_requested.emit())
	_standby_root.add_child(_station_exit_btn)


func _build_cinematic_ui() -> void:
	_cinematic_root = Control.new()
	_cinematic_root.name = "CinematicRoot"
	_cinematic_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cinematic_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cinematic_root.visible = false
	add_child(_cinematic_root)

	_fakeout_banner = PanelContainer.new()
	_fakeout_banner.name = "FakeOutBanner"
	_fakeout_banner.anchor_left = 0.5
	_fakeout_banner.anchor_right = 0.5
	_fakeout_banner.offset_left = -260.0
	_fakeout_banner.offset_right = 260.0
	_fakeout_banner.offset_top = 28.0
	_fakeout_banner.offset_bottom = 86.0
	_fakeout_banner.add_theme_stylebox_override("panel", _make_panel_style(Color(0.18, 0.03, 0.10, 0.94), COLOR_ASTRAL_GOLD))
	_fakeout_banner.visible = false
	_cinematic_root.add_child(_fakeout_banner)

	var fo_lbl := Label.new()
	fo_lbl.text = "⚡ ¡SELLO ROTO — SOBRERECARGA ÉPICA!"
	fo_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fo_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fo_lbl.add_theme_font_size_override("font_size", 20)
	fo_lbl.add_theme_color_override("font_color", COLOR_ASTRAL_GOLD)
	_fakeout_banner.add_child(fo_lbl)

	var phase_pill := PanelContainer.new()
	phase_pill.name = "CinematicPhasePill"
	phase_pill.anchor_left = 0.5
	phase_pill.anchor_right = 0.5
	phase_pill.anchor_top = 1.0
	phase_pill.anchor_bottom = 1.0
	phase_pill.offset_left = -260.0
	phase_pill.offset_right = 260.0
	phase_pill.offset_top = -62.0
	phase_pill.offset_bottom = -20.0
	phase_pill.add_theme_stylebox_override("panel", _make_panel_style(COLOR_BG_PANEL, COLOR_CYAN_POP))
	_cinematic_root.add_child(phase_pill)

	_cinematic_phase_label = Label.new()
	_cinematic_phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cinematic_phase_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cinematic_phase_label.add_theme_font_size_override("font_size", 14)
	_cinematic_phase_label.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0, 1.0))
	phase_pill.add_child(_cinematic_phase_label)

	_skip_btn = Button.new()
	_skip_btn.name = "SkipCinematicButton"
	_skip_btn.text = "SALTAR ⏩ [ESPACIO]"
	_skip_btn.anchor_left = 1.0
	_skip_btn.anchor_right = 1.0
	_skip_btn.anchor_top = 1.0
	_skip_btn.anchor_bottom = 1.0
	_skip_btn.offset_left = -226.0
	_skip_btn.offset_right = -24.0
	_skip_btn.offset_top = -64.0
	_skip_btn.offset_bottom = -20.0
	_skip_btn.focus_mode = Control.FOCUS_NONE
	_skip_btn.disabled = true
	_skip_btn.pressed.connect(func() -> void: skip_requested.emit())
	_cinematic_root.add_child(_skip_btn)


func _build_reveal_ui() -> void:
	_reveal_root = Control.new()
	_reveal_root.name = "RevealRoot"
	_reveal_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_reveal_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reveal_root.visible = false
	add_child(_reveal_root)

	# Panel de cascada multi-tirada (izquierda-inferior)
	_cascade_panel = PanelContainer.new()
	_cascade_panel.name = "MultiCascadePanel"
	_cascade_panel.anchor_top = 1.0
	_cascade_panel.anchor_bottom = 1.0
	_cascade_panel.offset_left = 20.0
	_cascade_panel.offset_right = 860.0
	_cascade_panel.offset_top = -346.0
	_cascade_panel.offset_bottom = -18.0
	_cascade_panel.add_theme_stylebox_override("panel", _make_panel_style(COLOR_BG_PANEL, COLOR_ASTRAL_GOLD))
	_cascade_panel.visible = false
	_reveal_root.add_child(_cascade_panel)

	var cas_vbox := VBoxContainer.new()
	cas_vbox.add_theme_constant_override("separation", 8)
	_cascade_panel.add_child(cas_vbox)

	var cas_top := HBoxContainer.new()
	cas_top.add_theme_constant_override("separation", 10)
	cas_vbox.add_child(cas_top)

	var cas_title := Label.new()
	cas_title.text = "RESULTADOS DE INVOCACIÓN"
	cas_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cas_title.add_theme_font_size_override("font_size", 14)
	cas_title.add_theme_color_override("font_color", COLOR_ASTRAL_GOLD)
	cas_top.add_child(cas_title)

	_skip_cascade_btn = Button.new()
	_skip_cascade_btn.name = "SkipCascadeButton"
	_skip_cascade_btn.text = "SALTAR CASCADA"
	_skip_cascade_btn.focus_mode = Control.FOCUS_NONE
	_skip_cascade_btn.pressed.connect(complete_cascade_instant)
	cas_top.add_child(_skip_cascade_btn)

	_cascade_grid = GridContainer.new()
	_cascade_grid.name = "CascadeGrid"
	_cascade_grid.columns = 5
	_cascade_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cascade_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_cascade_grid.add_theme_constant_override("h_separation", 8)
	_cascade_grid.add_theme_constant_override("v_separation", 8)
	cas_vbox.add_child(_cascade_grid)

	# Panel inspector derecho (1 único ShaderSkinLivePreview compartido)
	_inspector_panel = PanelContainer.new()
	_inspector_panel.name = "RewardInspectorPanel"
	_inspector_panel.anchor_left = 1.0
	_inspector_panel.anchor_right = 1.0
	_inspector_panel.anchor_top = 0.5
	_inspector_panel.anchor_bottom = 0.5
	_inspector_panel.offset_left = -354.0
	_inspector_panel.offset_right = -20.0
	_inspector_panel.offset_top = -275.0
	_inspector_panel.offset_bottom = 275.0
	_inspector_panel.add_theme_stylebox_override("panel", _make_panel_style(COLOR_BG_PANEL, COLOR_CYAN_POP))
	_reveal_root.add_child(_inspector_panel)

	var ins_vbox := VBoxContainer.new()
	ins_vbox.add_theme_constant_override("separation", 8)
	_inspector_panel.add_child(ins_vbox)

	_reward_badges_label = Label.new()
	_reward_badges_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reward_badges_label.add_theme_font_size_override("font_size", 12)
	_reward_badges_label.add_theme_color_override("font_color", COLOR_ASTRAL_GOLD)
	ins_vbox.add_child(_reward_badges_label)

	var preview_box := CenterContainer.new()
	preview_box.custom_minimum_size = Vector2(260.0, 260.0)
	ins_vbox.add_child(preview_box)

	_shared_live_preview = ShaderSkinLivePreviewScript.new() as ShaderSkinLivePreview
	_shared_live_preview.name = "SharedRewardLivePreview"
	_shared_live_preview.custom_minimum_size = Vector2(236.0, 256.0)
	_shared_live_preview.visible = false
	preview_box.add_child(_shared_live_preview)

	_shared_legacy_tex = TextureRect.new()
	_shared_legacy_tex.name = "SharedLegacyRewardTex"
	_shared_legacy_tex.custom_minimum_size = Vector2(180.0, 180.0)
	_shared_legacy_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_shared_legacy_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_shared_legacy_tex.visible = false
	preview_box.add_child(_shared_legacy_tex)

	_reward_title_label = Label.new()
	_reward_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reward_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reward_title_label.add_theme_font_size_override("font_size", 16)
	_reward_title_label.add_theme_color_override("font_color", Color.WHITE)
	ins_vbox.add_child(_reward_title_label)

	_reward_meta_label = Label.new()
	_reward_meta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reward_meta_label.add_theme_font_size_override("font_size", 12)
	_reward_meta_label.add_theme_color_override("font_color", Color(0.80, 0.88, 0.98, 1.0))
	ins_vbox.add_child(_reward_meta_label)

	_reward_status_label = Label.new()
	_reward_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reward_status_label.add_theme_font_size_override("font_size", 12)
	ins_vbox.add_child(_reward_status_label)

	_equip_btn = Button.new()
	_equip_btn.name = "EquipNowButton"
	_equip_btn.text = "EQUIPAR AHORA"
	_equip_btn.custom_minimum_size = Vector2(0.0, 42.0)
	_equip_btn.focus_mode = Control.FOCUS_NONE
	_equip_btn.pressed.connect(func() -> void:
		var sel: Dictionary = get_selected_reward()
		if not sel.is_empty():
			equip_reward_requested.emit(sel)
	)
	ins_vbox.add_child(_equip_btn)

	var bottom_row := HBoxContainer.new()
	bottom_row.add_theme_constant_override("separation", 8)
	ins_vbox.add_child(bottom_row)

	_pull_again_btn = Button.new()
	_pull_again_btn.name = "PullAgainOneButton"
	_pull_again_btn.text = "INVOCAR ×1"
	_pull_again_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pull_again_btn.focus_mode = Control.FOCUS_NONE
	_pull_again_btn.pressed.connect(func() -> void:
		reveal_closed.emit()
		pull_requested.emit(1)
	)
	bottom_row.add_child(_pull_again_btn)

	var close_btn := Button.new()
	close_btn.name = "CloseRevealButton"
	close_btn.text = "CERRAR [ESC]"
	close_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.pressed.connect(func() -> void: reveal_closed.emit())
	bottom_row.add_child(close_btn)


func set_standby_mode() -> void:
	_ensure_ui()
	_cascade_active = false
	_pause_shared_preview()
	_standby_root.visible = true
	_cinematic_root.visible = false
	_reveal_root.visible = false
	if _fakeout_banner != null:
		_fakeout_banner.visible = false
	if _sandbox_panel != null:
		_sandbox_panel.visible = _sandbox_panel_visible


func set_cinematic_mode(phase_text: String, can_skip_now: bool) -> void:
	_ensure_ui()
	_cascade_active = false
	_pause_shared_preview()
	_standby_root.visible = false
	_cinematic_root.visible = true
	_reveal_root.visible = false
	if _cinematic_phase_label != null:
		_cinematic_phase_label.text = phase_text
	if _skip_btn != null:
		_skip_btn.disabled = not can_skip_now


func update_cinematic_status(phase_text: String, can_skip_now: bool) -> void:
	if _cinematic_phase_label != null:
		_cinematic_phase_label.text = phase_text
	if _skip_btn != null:
		_skip_btn.disabled = not can_skip_now


func show_fakeout_banner() -> void:
	if _fakeout_banner != null:
		_fakeout_banner.visible = true


func show_reveal(batch: Dictionary) -> void:
	_ensure_ui()
	_current_batch = batch.duplicate(true)
	_current_rewards.clear()
	var raw_res: Array = batch.get("results", []) as Array
	for item_v: Variant in raw_res:
		if item_v is Dictionary:
			_current_rewards.append(item_v as Dictionary)

	_standby_root.visible = false
	_cinematic_root.visible = false
	_reveal_root.visible = true
	_clear_cascade_grid()

	if _current_rewards.is_empty():
		return

	var is_multi: bool = _current_rewards.size() > 1
	_cascade_panel.visible = is_multi
	if is_multi:
		_build_cascade_cards(_current_rewards)
		_cascade_active = true
		_cascade_revealed_count = 0
		_cascade_timer = 0.02
		_skip_cascade_btn.visible = true
	else:
		_cascade_active = false
		_skip_cascade_btn.visible = false

	var best_idx: int = _find_best_reward_index(_current_rewards)
	select_reward_index(best_idx)


func _build_cascade_cards(rewards: Array[Dictionary]) -> void:
	for idx: int in range(rewards.size()):
		var item: Dictionary = rewards[idx]
		var skin: Dictionary = item.get("skin_data", {}) as Dictionary
		var rarity: String = str(item.get("rarity", "common"))
		var is_pity: bool = bool(item.get("is_pity", false))
		var stars: int = int(item.get("new_stars", 1))

		var card_btn := Button.new()
		card_btn.name = "CascadeCard_%02d" % idx
		card_btn.custom_minimum_size = Vector2(150.0, 130.0)
		card_btn.focus_mode = Control.FOCUS_NONE
		var border_col: Color = _color_for_rarity(rarity, is_pity)
		card_btn.add_theme_stylebox_override("normal", _make_panel_style(Color(0.06, 0.07, 0.14, 0.96), border_col))
		card_btn.add_theme_stylebox_override("hover", _make_panel_style(Color(0.11, 0.13, 0.24, 0.98), Color.WHITE))
		var capture_idx: int = idx
		card_btn.pressed.connect(func() -> void: select_reward_index(capture_idx))

		var vbox := VBoxContainer.new()
		vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 4)
		card_btn.add_child(vbox)

		if CosmeticsManagerScript.is_shader_skin(skin):
			var sid: String = str(skin.get("id", ""))
			var cat: String = str(skin.get("category", "pilot"))
			var preset: PilotSkinPreset = CosmeticsManagerScript.get_skin_preset(sid)
			var swatch: ShaderSkinSwatch = ShaderSkinSwatchScript.new() as ShaderSkinSwatch
			swatch.custom_minimum_size = Vector2(56.0, 56.0)
			swatch.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			swatch.configure_swatch(preset, cat, stars, false, false)
			vbox.add_child(swatch)
		else:
			var icon := TextureRect.new()
			icon.custom_minimum_size = Vector2(52.0, 52.0)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var tex: Texture2D = CosmeticsManagerScript.get_skin_texture(skin)
			if tex != null:
				icon.texture = tex
			vbox.add_child(icon)

		var name_lbl := Label.new()
		name_lbl.text = str(skin.get("skin_name", "Skin"))
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.clip_text = true
		name_lbl.add_theme_font_size_override("font_size", 11)
		name_lbl.add_theme_color_override("font_color", border_col if (rarity == "epic" or is_pity) else Color.WHITE)
		vbox.add_child(name_lbl)

		var tag_lbl := Label.new()
		tag_lbl.text = "%s · %d★" % ["ÉPICA" if (rarity == "epic" or is_pity) else ("RARA" if rarity == "rare" else "COMÚN"), stars]
		tag_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag_lbl.add_theme_font_size_override("font_size", 10)
		tag_lbl.add_theme_color_override("font_color", border_col)
		vbox.add_child(tag_lbl)

		card_btn.modulate.a = 0.0
		_cascade_grid.add_child(card_btn)
		_cascade_cards.append(card_btn)


func _reveal_next_cascade_card() -> void:
	if _cascade_revealed_count >= _cascade_cards.size():
		_finish_cascade()
		return
	var idx: int = _cascade_revealed_count
	var card: Button = _cascade_cards[idx]
	card.modulate.a = 1.0
	_cascade_revealed_count += 1

	var item: Dictionary = _current_rewards[idx]
	var is_heroic: bool = (str(item.get("rarity", "")) == "epic" or bool(item.get("is_pity", false)))
	var step_d: float = _config.multi_cascade_step_delay if _config != null else 0.11
	var heroic_d: float = _config.multi_epic_heroic_pause if _config != null else 0.42
	_cascade_timer = heroic_d if is_heroic else step_d

	if is_heroic:
		select_reward_index(idx)
	if _cascade_revealed_count >= _cascade_cards.size():
		_finish_cascade()


func _finish_cascade() -> void:
	_cascade_active = false
	if _skip_cascade_btn != null:
		_skip_cascade_btn.visible = false


func complete_cascade_instant() -> void:
	for card: Button in _cascade_cards:
		card.modulate.a = 1.0
	_cascade_revealed_count = _cascade_cards.size()
	_finish_cascade()


func select_reward_index(idx: int) -> void:
	if idx < 0 or idx >= _current_rewards.size():
		return
	_selected_reward_idx = idx
	var item: Dictionary = _current_rewards[idx]
	var skin: Dictionary = item.get("skin_data", {}) as Dictionary
	var sid: String = str(skin.get("id", ""))
	var cat: String = str(skin.get("category", "pilot"))
	var tid_str: String = str(skin.get("target_id", "valentina")).to_lower()
	var rarity: String = str(item.get("rarity", "common"))
	var is_pity: bool = bool(item.get("is_pity", false))
	var stars: int = int(item.get("new_stars", 1))
	var status: String = str(item.get("status", "new"))
	var border_col: Color = _color_for_rarity(rarity, is_pity)

	var badges: PackedStringArray = []
	badges.append("★ ÉPICA" if (rarity == "epic" or is_pity) else ("◆ RARA" if rarity == "rare" else "● COMÚN"))
	if is_pity:
		badges.append("PITY 10/10")
	if bool(_current_batch.get("is_fakeout", false)) and (rarity == "epic" or is_pity):
		badges.append("⚡ FAKE-OUT")
	_reward_badges_label.text = "  ·  ".join(badges)
	_reward_badges_label.add_theme_color_override("font_color", border_col)

	_reward_title_label.text = str(skin.get("skin_name", sid))
	_reward_meta_label.text = "%s · Cat: %s · %d★" % [str(skin.get("target_name", tid_str.capitalize())), cat.to_upper(), stars]
	match status:
		"new":
			_reward_status_label.text = "¡NUEVA OBTENCIÓN!"
			_reward_status_label.add_theme_color_override("font_color", Color(0.32, 1.0, 0.56, 1.0))
		"upgraded":
			_reward_status_label.text = "¡SUBE A %d★!" % stars
			_reward_status_label.add_theme_color_override("font_color", COLOR_CYAN_POP)
		_:
			_reward_status_label.text = "DUPLICADO MAX (3★)"
			_reward_status_label.add_theme_color_override("font_color", COLOR_ASTRAL_GOLD)

	if CosmeticsManagerScript.is_shader_skin(skin):
		_shared_legacy_tex.visible = false
		var roster: Dictionary[StringName, CharacterData] = CharacterDataScript.load_roster()
		var cd: CharacterData = roster.get(StringName(tid_str), null)
		var prof: PilotRigProfile = cd.pilot_rig_profile if cd != null else null
		_shared_live_preview.configure(cat, prof, Vector2i(240, 280))
		var preset: PilotSkinPreset = CosmeticsManagerScript.get_skin_preset(sid)
		_shared_live_preview.apply_skin_preset(preset, stars, false)
		_shared_live_preview.visible = true
		_shared_live_preview.set_preview_paused(false)
	else:
		_pause_shared_preview()
		_shared_live_preview.visible = false
		_shared_legacy_tex.texture = CosmeticsManagerScript.get_skin_texture(skin)
		_shared_legacy_tex.visible = (_shared_legacy_tex.texture != null)


func sync_session_status(
	tokens: int,
	banner_id: String,
	pity: int,
	equipped_summary: Dictionary,
	telemetry_text: String = ""
) -> void:
	_ensure_ui()
	_last_banner_id = banner_id
	var b_cfg: Dictionary = GachaBannerEngineScript.get_banner_config(banner_id)
	var b_col: Color = b_cfg.get("color", COLOR_CYAN_POP) as Color

	if _tokens_label != null:
		_tokens_label.text = "Fichas Astrales: %d" % tokens
	if _banner_title_label != null:
		_banner_title_label.text = str(b_cfg.get("title", "Banner"))
		_banner_title_label.add_theme_color_override("font_color", b_col)
	if _banner_desc_label != null:
		_banner_desc_label.text = str(b_cfg.get("desc", ""))
	if _pity_label != null:
		_pity_label.text = "PITY [%s]: %d / %d" % [str(b_cfg.get("featured_badge", "")), pity, GachaBannerEngineScript.PITY_THRESHOLD]
		_pity_label.add_theme_color_override("font_color", b_col)
	if _pity_bar != null:
		_pity_bar.value = float(pity)

	for bid_v: Variant in _banner_buttons.keys():
		var bid: String = str(bid_v)
		var btn: Button = _banner_buttons[bid] as Button
		if btn != null:
			btn.modulate = Color.WHITE if bid == banner_id else Color(0.62, 0.66, 0.78, 1.0)

	for cnt_v: Variant in _pull_buttons.keys():
		var cnt: int = int(cnt_v)
		var p_btn: Button = _pull_buttons[cnt] as Button
		if p_btn != null:
			p_btn.disabled = tokens < cnt

	if _equipped_status_label != null:
		if equipped_summary.is_empty():
			_equipped_status_label.text = "Valentina (Vivo): Aspecto Base"
		else:
			var parts: PackedStringArray = []
			for k: Variant in equipped_summary.keys():
				var d: Dictionary = equipped_summary[k] as Dictionary
				parts.append("%s: %s" % [str(d.get("category", "")).to_upper(), str(d.get("skin_name", ""))])
			_equipped_status_label.text = "Equipado -> " + " | ".join(parts)

	if _telemetry_label != null and not telemetry_text.is_empty():
		_telemetry_label.text = telemetry_text


func set_station_clean_mode(clean: bool) -> void:
	_station_clean_mode = clean
	_ensure_ui()
	if _sandbox_panel != null:
		_sandbox_panel.visible = (not clean) and _sandbox_panel_visible
	if _station_exit_btn != null:
		_station_exit_btn.visible = clean


func is_station_clean_mode() -> bool:
	return _station_clean_mode


func toggle_sandbox_panel() -> void:
	_sandbox_panel_visible = not _sandbox_panel_visible
	if _sandbox_panel != null and _standby_root != null and _standby_root.visible:
		_sandbox_panel.visible = _sandbox_panel_visible and not _station_clean_mode
		_sandbox_panel.visible = _sandbox_panel_visible


func _pause_shared_preview() -> void:
	if _shared_live_preview != null:
		_shared_live_preview.set_preview_paused(true)


func _clear_cascade_grid() -> void:
	_cascade_cards.clear()
	if _cascade_grid == null:
		return
	for child: Node in _cascade_grid.get_children():
		_cascade_grid.remove_child(child)
		child.queue_free()


func _find_best_reward_index(rewards: Array[Dictionary]) -> int:
	var best_idx: int = 0
	var best_score: int = -1
	for i: int in range(rewards.size()):
		var item: Dictionary = rewards[i]
		var r: String = str(item.get("rarity", "common"))
		var p: bool = bool(item.get("is_pity", false))
		var sc: int = 3 if (r == "epic" or p) else (2 if r == "rare" else 1)
		if sc > best_score:
			best_score = sc
			best_idx = i
	return best_idx


func _color_for_rarity(rarity: String, is_pity: bool) -> Color:
	if rarity == "epic" or is_pity:
		return _config.epic_energy_color if _config != null else COLOR_ASTRAL_GOLD
	if rarity == "rare":
		return _config.rare_energy_color if _config != null else Color(0.76, 0.34, 1.0, 1.0)
	return _config.common_energy_color if _config != null else COLOR_CYAN_POP


func _make_panel_style(bg_col: Color, border_col: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_col
	sb.border_color = border_col
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(10)
	return sb


func is_reveal_visible() -> bool:
	return _reveal_root != null and _reveal_root.visible


func get_selected_reward() -> Dictionary:
	if _selected_reward_idx < 0 or _selected_reward_idx >= _current_rewards.size():
		return {}
	return _current_rewards[_selected_reward_idx]


func get_cascade_card_count() -> int:
	return _cascade_cards.size()


func get_live_preview() -> ShaderSkinLivePreview:
	return _shared_live_preview

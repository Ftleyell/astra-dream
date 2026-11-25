class_name HubArtLabHUD
extends CanvasLayer

## HUD Astral Pop-Ink de la Estación Astral v2:
## - Modo Limpio (visible por defecto): ficha compacta superior izquierda (Piloto, Coordenada, Recursos),
##   píldora diegética de interacción inferior, toast de calibración y hint de controles.
## - Panel Dev de calibración (oculto por defecto; toggle con [H]): cámaras [1..7], presets de progresión,
##   maestría de reliquias, semilla manual y sliders ArcSys 3D.

signal camera_mode_requested(mode: int)
signal accent_color_selected(color: Color)
signal station_state_cycled()
signal progression_preset_selected(preset_id: StringName)
signal relic_mastery_override_selected(level: int)
signal dry_run_toggled(is_dry_run: bool)
signal real_launch_toggled(launch_real: bool)
signal rematerialize_requested()
signal seed_apply_requested(seed_val: int)
signal seed_random_requested()
signal quality_tier_selected(tier: int)
signal shader_params_changed()
signal save_config_requested()
signal back_to_workbench_requested()
signal settings_requested()
signal return_to_title_requested()

const ConfigScript = preload("res://scenes/ui/hub/astral_station/resources/hub_art_lab_config.gd")
const RunLaunchRequestScript = preload("res://core/systems/run_launch_request.gd")
const SaveManagerScript = preload("res://core/autoloads/save_manager.gd")

const COLOR_BG := Color(0.038, 0.052, 0.112, 0.92)
const COLOR_GOLD := Color(0.95, 0.80, 0.34, 1.0)
const COLOR_CYAN := Color(0.05, 0.94, 1.0, 1.0)

const PILOT_SWATCHES: Array[Dictionary] = [
	{"label": "Val", "color": Color(0.95, 0.16, 0.34, 1.0)},
	{"label": "Nova", "color": Color(0.05, 0.90, 1.00, 1.0)},
	{"label": "Kira", "color": Color(1.00, 0.78, 0.12, 1.0)},
	{"label": "Selene", "color": Color(0.75, 0.38, 1.00, 1.0)},
	{"label": "Roxy", "color": Color(0.18, 0.95, 0.52, 1.0)},
]

var _clean_root: Control = null
var _top_bar: PanelContainer = null
var _status_label: Label = null
var _resources_label: Label = null
var _prompt_pill: PanelContainer = null
var _prompt_pill_label: Label = null
var _toast_panel: PanelContainer = null
var _toast_title_lbl: Label = null
var _toast_body_lbl: Label = null
var _toast_timer: float = 0.0
var _traversal_lbl: Label = null
var _departure_banner: PanelContainer = null
var _departure_lbl: Label = null
var _remat_btn: Button = null

var _panel: PanelContainer = null
var _station_btn: Button = null
var _seed_input: LineEdit = null
var _config: ConfigScript = null
var _sliders: Dictionary = {}
var is_dev_lab_mode: bool = false
var _hint_lbl: Label = null
var _top_right_bar: HBoxContainer = null


func setup(p_config: ConfigScript, p_is_dev_lab_mode: bool = false) -> void:
	_config = p_config
	is_dev_lab_mode = p_is_dev_lab_mode
	_build_ui()
	sync_from_config(p_config)


func toggle_visible() -> void:
	if _panel != null and is_dev_lab_mode:
		_panel.visible = not _panel.visible


func is_dev_panel_visible() -> bool:
	return _panel != null and _panel.visible


func set_clean_hud_visible(vis: bool) -> void:
	if _clean_root != null:
		_clean_root.visible = vis


func set_interaction_prompt(text: String, accent_col: Color, vis: bool) -> void:
	if _prompt_pill == null or _prompt_pill_label == null:
		return
	_prompt_pill.visible = vis and not text.is_empty()
	if not _prompt_pill.visible:
		return
	_prompt_pill_label.text = text
	_prompt_pill_label.add_theme_color_override("font_color", accent_col)
	var sb: StyleBoxFlat = _prompt_pill.get_theme_stylebox("panel") as StyleBoxFlat
	if sb != null:
		sb.border_color = accent_col


func show_toast(title_text: String, body_text: String, accent_col: Color = COLOR_GOLD, duration: float = 2.6) -> void:
	if _toast_panel == null:
		return
	_toast_timer = duration
	_toast_panel.visible = true
	_toast_panel.modulate.a = 1.0
	var sb: StyleBoxFlat = _toast_panel.get_theme_stylebox("panel") as StyleBoxFlat
	if sb != null:
		sb.border_color = accent_col
	if _toast_title_lbl != null:
		_toast_title_lbl.text = title_text
		_toast_title_lbl.add_theme_color_override("font_color", accent_col)
	if _toast_body_lbl != null:
		_toast_body_lbl.text = body_text


func _process(delta: float) -> void:
	if _toast_timer > 0.0 and _toast_panel != null and _toast_panel.visible:
		_toast_timer -= delta
		if _toast_timer < 0.45:
			_toast_panel.modulate.a = clampf(_toast_timer / 0.45, 0.0, 1.0)
		if _toast_timer <= 0.0:
			_toast_panel.visible = false


func update_status(
	mode_text: String,
	station_state_text: String,
	seed_val: int,
	coord_code: String = "",
	seed_badge: String = "",
	preset_name: String = "live",
	pilot_name: String = "Valentina"
) -> void:
	var code_str: String = coord_code if not coord_code.is_empty() else str(seed_val)
	if _status_label != null:
		var badge_str: String = (" " + seed_badge) if not seed_badge.is_empty() else ""
		_status_label.text = "Piloto: %s  ·  Salto: %s%s\nVista: %s  ·  Progresión: %s" % [
			pilot_name, code_str, badge_str, mode_text, preset_name
		]
	if _resources_label != null:
		_resources_label.text = "Biomasa: %d  |  M. Oscura: %d  |  Fichas Gacha: %d" % [
			SaveManagerScript.get_biomass(),
			SaveManagerScript.get_dark_matter(),
			SaveManagerScript.get_gacha_tokens(),
		]
	if _station_btn != null:
		_station_btn.text = "Ciclar Proyector (%s)" % station_state_text
	if _seed_input != null and not _seed_input.has_focus():
		_seed_input.text = code_str


func sync_from_config(cfg: ConfigScript) -> void:
	if cfg == null:
		return
	_config = cfg
	_set_slider_val("ink_strength", cfg.ink_strength)
	_set_slider_val("crease_ink_strength", cfg.crease_ink_strength)
	_set_slider_val("outline_width", cfg.outline_width)
	_set_slider_val("emissive_boost", cfg.emissive_boost)
	_set_slider_val("bloom_intensity", cfg.bloom_intensity)


func _set_slider_val(key: String, val: float) -> void:
	if _sliders.has(key):
		var s: HSlider = _sliders[key] as HSlider
		if s != null:
			s.set_value_no_signal(val)


func _build_ui() -> void:
	if _panel != null:
		return

	_clean_root = Control.new()
	_clean_root.name = "CleanProductionHUD"
	_clean_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_clean_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_clean_root)

	# 1. Ficha compacta superior izquierda Astral Pop-Ink
	_top_bar = PanelContainer.new()
	_top_bar.position = Vector2(18.0, 14.0)
	_top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top_bar.add_theme_stylebox_override("panel", _make_box_style(COLOR_BG, COLOR_GOLD, true))
	_clean_root.add_child(_top_bar)

	var top_vbox := VBoxContainer.new()
	top_vbox.add_theme_constant_override("separation", 3)
	_top_bar.add_child(top_vbox)
	var title_lbl := Label.new()
	title_lbl.text = "ESTACIÓN ASTRAL v2"
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.add_theme_color_override("font_color", COLOR_GOLD)
	top_vbox.add_child(title_lbl)

	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 12)
	_status_label.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0, 1.0))
	top_vbox.add_child(_status_label)

	_resources_label = Label.new()
	_resources_label.add_theme_font_size_override("font_size", 11)
	_resources_label.add_theme_color_override("font_color", COLOR_CYAN)
	top_vbox.add_child(_resources_label)

	_traversal_lbl = Label.new()
	_traversal_lbl.text = "MODO: DECK · WALK"
	_traversal_lbl.add_theme_font_size_override("font_size", 11)
	_traversal_lbl.add_theme_color_override("font_color", COLOR_GOLD)
	top_vbox.add_child(_traversal_lbl)

	# 1b. Pill de Despegue Radial / Rematerialización (parte superior centrada)
	_departure_banner = PanelContainer.new()
	_departure_banner.anchor_left = 0.5
	_departure_banner.anchor_right = 0.5
	_departure_banner.offset_left = -210.0
	_departure_banner.offset_right = 210.0
	_departure_banner.offset_top = 14.0
	_departure_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_departure_banner.visible = false
	_departure_banner.add_theme_stylebox_override("panel", _make_box_style(COLOR_BG, COLOR_CYAN, true))
	_clean_root.add_child(_departure_banner)

	_departure_lbl = Label.new()
	_departure_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_departure_lbl.add_theme_font_size_override("font_size", 12)
	_departure_lbl.add_theme_color_override("font_color", COLOR_CYAN)
	_departure_banner.add_child(_departure_lbl)

	# 2. Píldora inferior centrada de interacción
	_prompt_pill = PanelContainer.new()
	_prompt_pill.anchor_left = 0.5
	_prompt_pill.anchor_right = 0.5
	_prompt_pill.anchor_top = 1.0
	_prompt_pill.anchor_bottom = 1.0
	_prompt_pill.offset_left = -210.0
	_prompt_pill.offset_right = 210.0
	_prompt_pill.offset_top = -72.0
	_prompt_pill.offset_bottom = -28.0
	_prompt_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_pill.visible = false
	_prompt_pill.add_theme_stylebox_override("panel", _make_box_style(COLOR_BG, COLOR_GOLD, false))
	_clean_root.add_child(_prompt_pill)

	_prompt_pill_label = Label.new()
	_prompt_pill_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_pill_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt_pill_label.add_theme_font_size_override("font_size", 14)
	_prompt_pill.add_child(_prompt_pill_label)

	# 3. Toast superior centrado para avisos de calibración / desbloqueo
	_toast_panel = PanelContainer.new()
	_toast_panel.anchor_left = 0.5
	_toast_panel.anchor_right = 0.5
	_toast_panel.offset_left = -235.0
	_toast_panel.offset_right = 235.0
	_toast_panel.offset_top = 18.0
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_panel.visible = false
	_toast_panel.add_theme_stylebox_override("panel", _make_box_style(COLOR_BG, COLOR_GOLD, true))
	_clean_root.add_child(_toast_panel)

	var toast_vbox := VBoxContainer.new()
	toast_vbox.add_theme_constant_override("separation", 3)
	_toast_panel.add_child(toast_vbox)
	_toast_title_lbl = Label.new()
	_toast_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_title_lbl.add_theme_font_size_override("font_size", 13)
	toast_vbox.add_child(_toast_title_lbl)
	_toast_body_lbl = Label.new()
	_toast_body_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast_body_lbl.add_theme_font_size_override("font_size", 12)
	toast_vbox.add_child(_toast_body_lbl)

	# 4. Hint discreto de controles en esquina inferior derecha
	_hint_lbl = Label.new()
	_hint_lbl.anchor_left = 1.0
	_hint_lbl.anchor_right = 1.0
	_hint_lbl.anchor_top = 1.0
	_hint_lbl.anchor_bottom = 1.0
	_hint_lbl.offset_left = -760.0
	_hint_lbl.offset_top = -34.0
	_hint_lbl.offset_right = -18.0
	_hint_lbl.offset_bottom = -10.0
	_hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint_lbl.text = (
		"[WASD] Caminar/Volar al Espacio · [Rueda] Zoom · [E] Interactuar · [R] Rematerializar · [H] Dev"
		if is_dev_lab_mode
		else "[WASD] Caminar/Volar al Espacio · [Rueda] Zoom · [E] Interactuar · [ESC] Ajustes"
	)
	_hint_lbl.add_theme_font_size_override("font_size", 11)
	_hint_lbl.add_theme_color_override("font_color", Color(0.76, 0.82, 0.94, 0.78))
	_clean_root.add_child(_hint_lbl)

	if not is_dev_lab_mode:
		_top_right_bar = HBoxContainer.new()
		_top_right_bar.name = "TopRightActionBar"
		_top_right_bar.anchor_left = 1.0
		_top_right_bar.anchor_right = 1.0
		_top_right_bar.offset_left = -216.0
		_top_right_bar.offset_top = 14.0
		_top_right_bar.offset_right = -18.0
		_top_right_bar.offset_bottom = 48.0
		_top_right_bar.add_theme_constant_override("separation", 8)
		_top_right_bar.alignment = BoxContainer.ALIGNMENT_END
		_clean_root.add_child(_top_right_bar)

		var settings_btn := Button.new()
		settings_btn.name = "SettingsButton"
		settings_btn.text = "⚙ Ajustes"
		settings_btn.focus_mode = Control.FOCUS_NONE
		settings_btn.add_theme_font_size_override("font_size", 12)
		settings_btn.pressed.connect(func() -> void: settings_requested.emit())
		_top_right_bar.add_child(settings_btn)

		var title_btn := Button.new()
		title_btn.name = "TitleButton"
		title_btn.text = "Título"
		title_btn.focus_mode = Control.FOCUS_NONE
		title_btn.add_theme_font_size_override("font_size", 12)
		title_btn.pressed.connect(func() -> void: return_to_title_requested.emit())
		_top_right_bar.add_child(title_btn)

	# 5. Panel Dev de calibración (OCULTO por defecto -> abrir con [H])
	_panel = PanelContainer.new()
	_panel.name = "DevCalibrationPanel"
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.offset_left = -384.0
	_panel.offset_top = 14.0
	_panel.offset_right = -16.0
	_panel.visible = false
	_panel.add_theme_stylebox_override("panel", _make_box_style(COLOR_BG, COLOR_GOLD, true))
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	_panel.add_child(vbox)

	_add_section_header(vbox, "Cámara [1..7]  ([H] Ocultar Dev)")
	var cam_grid := GridContainer.new()
	cam_grid.columns = 4
	vbox.add_child(cam_grid)
	for spec: Dictionary in [
		{"label": "1 Free", "mode": 0},
		{"label": "2 Cápsula", "mode": 1},
		{"label": "3 Skins", "mode": 4},
		{"label": "4 Consola", "mode": 2},
		{"label": "5 Gacha", "mode": 5},
		{"label": "6 Reliquia", "mode": 6},
		{"label": "7 Salida", "mode": 7},
	]:
		var b := Button.new()
		b.text = str(spec["label"])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.focus_mode = Control.FOCUS_NONE
		var m: int = int(spec["mode"])
		b.pressed.connect(func() -> void: camera_mode_requested.emit(m))
		cam_grid.add_child(b)

	_add_section_header(vbox, "Color Acento Piloto (Reactivo)")
	var swatch_row := HBoxContainer.new()
	vbox.add_child(swatch_row)
	for sw: Dictionary in PILOT_SWATCHES:
		var b := Button.new()
		b.text = str(sw["label"])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.focus_mode = Control.FOCUS_NONE
		var col: Color = sw["color"] as Color
		b.add_theme_color_override("font_color", col)
		b.pressed.connect(func() -> void: accent_color_selected.emit(col))
		swatch_row.add_child(b)

	_add_section_header(vbox, "Simulador Progresión Antesala")
	var prog_grid := GridContainer.new()
	prog_grid.columns = 3
	vbox.add_child(prog_grid)
	for p_spec: Array in [
		["Live", &"live"],
		["Run 1", &"run1"],
		["PostRun", &"post_run1"],
		["PostBoss", &"post_boss"],
		["All On", &"all_online"],
		["Debug", &"debug_unlock"],
	]:
		var pb := Button.new()
		pb.text = str(p_spec[0])
		pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pb.focus_mode = Control.FOCUS_NONE
		var pid: StringName = p_spec[1] as StringName
		pb.pressed.connect(func() -> void: progression_preset_selected.emit(pid))
		prog_grid.add_child(pb)

	_station_btn = Button.new()
	_station_btn.text = "Ciclar Proyector"
	_station_btn.focus_mode = Control.FOCUS_NONE
	_station_btn.pressed.connect(func() -> void: station_state_cycled.emit())
	vbox.add_child(_station_btn)

	_add_section_header(vbox, "Ala Oeste — Maestría Reliquias")
	var mast_row := HBoxContainer.new()
	vbox.add_child(mast_row)
	for m_spec: Array in [["Live", -1], ["0", 0], ["1", 1], ["2", 2], ["3", 3], ["4", 4]]:
		var mb := Button.new()
		mb.text = str(m_spec[0])
		mb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mb.focus_mode = Control.FOCUS_NONE
		var lvl: int = int(m_spec[1])
		mb.pressed.connect(func() -> void: relic_mastery_override_selected.emit(lvl))
		mast_row.add_child(mb)

	_add_section_header(vbox, "Coordenada Cosmos & Despegue Radial 8-Dir")
	var seed_row := HBoxContainer.new()
	vbox.add_child(seed_row)
	_seed_input = LineEdit.new()
	_seed_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_seed_input.placeholder_text = "ASTR-XXXXXX o entero"
	seed_row.add_child(_seed_input)

	var apply_seed_btn := Button.new()
	apply_seed_btn.text = "Aplicar"
	apply_seed_btn.focus_mode = Control.FOCUS_NONE
	apply_seed_btn.pressed.connect(_on_apply_seed_pressed)
	seed_row.add_child(apply_seed_btn)

	var rand_seed_btn := Button.new()
	rand_seed_btn.text = "Auto"
	rand_seed_btn.focus_mode = Control.FOCUS_NONE
	rand_seed_btn.pressed.connect(func() -> void: seed_random_requested.emit())
	seed_row.add_child(rand_seed_btn)

	var launch_row := HBoxContainer.new()
	vbox.add_child(launch_row)
	var real_chk := CheckBox.new()
	real_chk.text = "Lanzar a MainGame Real"
	real_chk.button_pressed = false
	real_chk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	real_chk.focus_mode = Control.FOCUS_NONE
	real_chk.toggled.connect(func(pressed: bool) -> void:
		real_launch_toggled.emit(pressed)
		dry_run_toggled.emit(not pressed)
	)
	launch_row.add_child(real_chk)

	_remat_btn = Button.new()
	_remat_btn.text = "Rematerializar [R]"
	_remat_btn.focus_mode = Control.FOCUS_NONE
	_remat_btn.pressed.connect(func() -> void: rematerialize_requested.emit())
	launch_row.add_child(_remat_btn)

	var q_row := HBoxContainer.new()
	vbox.add_child(q_row)
	for qi: int in range(3):
		var qb := Button.new()
		qb.text = "Calidad %d" % qi
		qb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		qb.focus_mode = Control.FOCUS_NONE
		var q_val: int = qi
		qb.pressed.connect(func() -> void: quality_tier_selected.emit(q_val))
		q_row.add_child(qb)

	_add_section_header(vbox, "Calibración Shaders ArcSys 3D")
	_add_slider(vbox, "ink_strength", "Tinta SDF Suelo", 0.0, 1.0, 0.02)
	_add_slider(vbox, "crease_ink_strength", "Crease Ink Props", 0.0, 1.0, 0.02)
	_add_slider(vbox, "outline_width", "Contorno 3D", 0.006, 0.06, 0.002)
	_add_slider(vbox, "emissive_boost", "Emisión HDR", 0.3, 3.0, 0.05)
	_add_slider(vbox, "bloom_intensity", "AgX Bloom", 0.0, 2.0, 0.05)

	var action_row := HBoxContainer.new()
	vbox.add_child(action_row)
	var save_btn := Button.new()
	save_btn.text = "Guardar .tres"
	save_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_btn.focus_mode = Control.FOCUS_NONE
	save_btn.pressed.connect(func() -> void: save_config_requested.emit())
	action_row.add_child(save_btn)

	var back_btn := Button.new()
	back_btn.text = "WorkbenchHub"
	back_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back_btn.focus_mode = Control.FOCUS_NONE
	back_btn.pressed.connect(func() -> void: back_to_workbench_requested.emit())
	action_row.add_child(back_btn)


func update_traversal_telemetry(
	is_flying: bool,
	warn_progress: float,
	sector_info: Dictionary,
	is_dissolved_preview: bool
) -> void:
	if _traversal_lbl != null:
		_traversal_lbl.text = "TRAVESÍA: SPACE · FLIGHT" if is_flying else "TRAVESÍA: DECK · WALK"
		_traversal_lbl.add_theme_color_override("font_color", COLOR_CYAN if is_flying else COLOR_GOLD)

	if _departure_banner == null or _departure_lbl == null:
		return

	if is_dissolved_preview:
		_departure_banner.visible = true
		var sec_label: String = str(sector_info.get("label", "COSMOS ABIERTO"))
		_departure_lbl.text = "HUB DESMATERIALIZADO (%s) · Pulsa [R] para Rematerializar" % sec_label
		_departure_lbl.add_theme_color_override("font_color", COLOR_GOLD)
		var sb: StyleBoxFlat = _departure_banner.get_theme_stylebox("panel") as StyleBoxFlat
		if sb != null:
			sb.border_color = COLOR_GOLD
	elif warn_progress > 0.01:
		_departure_banner.visible = true
		var sec_label: String = str(sector_info.get("label", "SECTOR"))
		var sec_col: Color = sector_info.get("color", COLOR_CYAN) as Color
		_departure_lbl.text = "DESPEGUE SEAMLESS · %s · %d%%" % [sec_label, int(round(warn_progress * 100.0))]
		_departure_lbl.add_theme_color_override("font_color", sec_col)
		var sb: StyleBoxFlat = _departure_banner.get_theme_stylebox("panel") as StyleBoxFlat
		if sb != null:
			sb.border_color = sec_col
	else:
		_departure_banner.visible = false


func _on_apply_seed_pressed() -> void:
	if _seed_input == null:
		return
	var txt: String = _seed_input.text.strip_edges()
	var decoded: int = RunLaunchRequestScript.decode_coordinate_code(txt)
	if decoded <= 0:
		decoded = maxi(1, abs(txt.hash()) & 0x7FFFFFFF)
	_seed_input.release_focus()
	seed_apply_requested.emit(decoded)


func _add_section_header(parent: VBoxContainer, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", COLOR_GOLD)
	parent.add_child(lbl)


func _add_slider(parent: VBoxContainer, prop_key: String, title: String, min_v: float, max_v: float, step_v: float) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var lbl := Label.new()
	lbl.text = title
	lbl.custom_minimum_size = Vector2(124.0, 0.0)
	lbl.add_theme_font_size_override("font_size", 11)
	row.add_child(lbl)

	var slider := HSlider.new()
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.focus_mode = Control.FOCUS_NONE
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step_v
	slider.value_changed.connect(func(v: float) -> void:
		if _config != null:
			_config.set(prop_key, v)
		shader_params_changed.emit()
	)
	row.add_child(slider)
	_sliders[prop_key] = slider


func _make_box_style(bg: Color, border: Color, top_accent: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	if top_accent:
		sb.border_width_top = 4
	sb.set_content_margin_all(10.0)
	return sb

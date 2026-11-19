class_name ShaderLabHud
extends CanvasLayer
## Panel HUD izquierdo con pestañas y diseño limpio para el Laboratorio de Shaders de Valentina v2.

signal view_selected(view_key: String)
signal head_step_requested(delta_idx: int)
signal head_cycle_toggled(enabled: bool)
signal compare_mode_changed(mode_idx: int)
signal anim_toggled(playing: bool)
signal backdrop_changed(mode_idx: int)
signal debug_view_changed(mode_idx: int)
signal pinch_debug_toggled(enabled: bool)

signal style_preset_selected(index: int)
signal skin_preset_selected(index: int)
signal hair_preset_selected(index: int)
signal hair_style_mode_changed(mode_idx: int)
signal recolor_method_changed(method_idx: int)
signal reset_style_requested()
signal save_preset_requested(preset_name: String)

signal light_options_changed()
signal shader_param_changed(param_name: String, value: Variant)
signal pass2_param_changed(param_name: String, value: Variant)
signal inward_outline_changed()

const DIRECTIONS_8: Array[String] = ["s", "se", "e", "ne", "n", "nw", "w", "sw"]
const PANEL_WIDTH: float = 312.0

var _root_ctrl: Control = null
var _side_panel: PanelContainer = null
var _toggle_btn: Button = null
var _status_label: Label = null
var _head_label: Label = null
var _style_opt: OptionButton = null
var _skin_opt: OptionButton = null
var _hair_opt: OptionButton = null
var _hair_mode_opt: OptionButton = null
var _recolor_opt: OptionButton = null
var _pipeline_opt: OptionButton = null
var _halftone_pat_opt: OptionButton = null
var _halftone_zone_opt: OptionButton = null
var _save_name_edit: LineEdit = null
var _save_feedback_lbl: Label = null

var _dir_buttons: Dictionary = {}
var _sliders: Dictionary = {}
var _slider_labels: Dictionary = {}
var _checks: Dictionary = {}
var _suppress_signals: bool = false
var _panel_open: bool = true


func build_ui(
	style_labels: Array[String],
	skin_labels: Array[String],
	hair_labels: Array[String]
) -> void:
	layer = 20

	_root_ctrl = Control.new()
	_root_ctrl.name = "HudRoot"
	_root_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root_ctrl)

	var panel_style: StyleBoxFlat = _make_panel_style(Color(0.085, 0.098, 0.132, 0.92), Color(0.24, 0.30, 0.42, 0.75), 10)
	var bar_style: StyleBoxFlat = _make_panel_style(Color(0.085, 0.098, 0.132, 0.84), Color(0.24, 0.30, 0.42, 0.55), 8)

	# Panel principal anclado a la IZQUIERDA, con ancho acotado y márgenes cómodos
	_side_panel = PanelContainer.new()
	_side_panel.name = "LeftDrawer"
	_side_panel.anchor_left = 0.0
	_side_panel.anchor_right = 0.0
	_side_panel.anchor_top = 0.0
	_side_panel.anchor_bottom = 1.0
	_side_panel.offset_left = 12.0
	_side_panel.offset_right = 12.0 + PANEL_WIDTH
	_side_panel.offset_top = 12.0
	_side_panel.offset_bottom = -12.0
	_side_panel.clip_contents = true
	_side_panel.add_theme_stylebox_override("panel", panel_style)
	_root_ctrl.add_child(_side_panel)

	var drawer_vb := VBoxContainer.new()
	drawer_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	drawer_vb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	drawer_vb.add_theme_constant_override("separation", 8)
	_side_panel.add_child(drawer_vb)

	# Cabecera limpia del panel
	var header_row := HBoxContainer.new()
	drawer_vb.add_child(header_row)
	var title_lbl := Label.new()
	title_lbl.text = "Shader Lab — Valentina v2"
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.add_theme_font_size_override("font_size", 15)
	title_lbl.modulate = Color(0.86, 0.92, 1.0)
	header_row.add_child(title_lbl)

	var hide_btn := Button.new()
	hide_btn.text = "Ocultar (H)"
	hide_btn.pressed.connect(toggle_panel)
	header_row.add_child(hide_btn)

	# Contenedor con 4 pestañas claras
	var tabs := TabContainer.new()
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	drawer_vb.add_child(tabs)

	var tab_look: VBoxContainer = _make_tab_page(tabs, "Look")
	var tab_light: VBoxContainer = _make_tab_page(tabs, "Luz/Cel")
	var tab_fx: VBoxContainer = _make_tab_page(tabs, "Trama")
	var tab_dbg: VBoxContainer = _make_tab_page(tabs, "Extra")

	_build_look_tab(tab_look, style_labels, skin_labels, hair_labels)
	_build_light_cel_tab(tab_light)
	_build_trama_outline_tab(tab_fx)
	_build_extra_debug_tab(tab_dbg)

	# Botón flotante para reabrir el panel cuando está oculto
	_toggle_btn = Button.new()
	_toggle_btn.text = "▶ Abrir Shader Lab (H)"
	_toggle_btn.position = Vector2(12.0, 12.0)
	_toggle_btn.visible = false
	_toggle_btn.pressed.connect(toggle_panel)
	_root_ctrl.add_child(_toggle_btn)

	# Barra inferior compacta con atajos (no estorba arriba ni a los costados)
	var bottom_bar := PanelContainer.new()
	bottom_bar.anchor_left = 0.0
	bottom_bar.anchor_right = 0.0
	bottom_bar.anchor_top = 1.0
	bottom_bar.anchor_bottom = 1.0
	bottom_bar.offset_left = 24.0 + PANEL_WIDTH
	bottom_bar.offset_right = 800.0
	bottom_bar.offset_top = -42.0
	bottom_bar.offset_bottom = -12.0
	bottom_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_bar.add_theme_stylebox_override("panel", bar_style)
	_root_ctrl.add_child(bottom_bar)

	_status_label = Label.new()
	_status_label.text = "Rueda: Zoom  •  Arrastrar: Mover  •  1–8: Vistas  •  [ / ]: Cabeza  •  Tab: Comparar  •  R: Centrar  •  H: UI"
	_status_label.add_theme_font_size_override("font_size", 12)
	_status_label.modulate = Color(0.78, 0.84, 0.92, 0.92)
	bottom_bar.add_child(_status_label)


func toggle_panel() -> void:
	_panel_open = not _panel_open
	if _side_panel != null:
		_side_panel.visible = _panel_open
	if _toggle_btn != null:
		_toggle_btn.visible = not _panel_open


func set_status_text(txt: String) -> void:
	if _status_label != null:
		_status_label.text = txt


func set_active_view_ui(view_key: String, head_key: String) -> void:
	for k: String in _dir_buttons.keys():
		var btn: Button = _dir_buttons[k] as Button
		btn.button_pressed = (k == view_key)
	if _head_label != null:
		_head_label.text = head_key


func set_save_feedback(msg: String, is_ok: bool) -> void:
	if _save_feedback_lbl == null:
		return
	_save_feedback_lbl.text = msg
	_save_feedback_lbl.modulate = Color(0.55, 0.95, 0.65) if is_ok else Color(1.0, 0.55, 0.55)


func refresh_style_list(style_labels: Array[String], select_idx: int) -> void:
	if _style_opt == null:
		return
	_suppress_signals = true
	_style_opt.clear()
	for lbl: String in style_labels:
		_style_opt.add_item(lbl)
	if select_idx >= 0 and select_idx < _style_opt.item_count:
		_style_opt.select(select_idx)
	_suppress_signals = false


func sync_from_style_profile(profile: RigStyleProfile) -> void:
	if profile == null:
		return
	_suppress_signals = true
	if _pipeline_opt != null:
		_pipeline_opt.select(clampi(profile.pipeline_mode, 0, _pipeline_opt.item_count - 1))
	_set_check_val("enable_halftone", profile.enable_halftone)
	if _halftone_pat_opt != null:
		_halftone_pat_opt.select(clampi(profile.halftone_pattern_type, 0, _halftone_pat_opt.item_count - 1))
	if _halftone_zone_opt != null:
		_halftone_zone_opt.select(clampi(profile.halftone_zone_mode, 0, _halftone_zone_opt.item_count - 1))
	_set_slider_val("halftone_scale", profile.halftone_scale)
	_set_slider_val("halftone_strength", profile.halftone_strength)
	_set_slider_val("halftone_angle_deg", profile.halftone_angle_deg)
	_set_slider_val("halftone_threshold", profile.halftone_threshold)
	_set_slider_val("ink_boost", profile.ink_boost)
	_set_slider_val("cel_step_strength", profile.cel_step_strength)
	_set_slider_val("noir_shadow_crush", profile.noir_shadow_crush)
	_set_slider_val("noir_shadow_threshold", profile.noir_shadow_threshold)
	_set_slider_val("metal_sheen_strength", profile.metal_sheen_strength)
	_set_slider_val("rim_light_strength", profile.rim_light_strength)
	_set_slider_val("rim_width_px", profile.rim_width_px)
	_set_slider_val("dual_rim_strength", profile.dual_rim_strength)
	_set_slider_val("glow_intensity", profile.glow_intensity)
	_set_slider_val("outer_outline_tint_mix", profile.outer_outline_tint_mix)
	_suppress_signals = false


func export_current_style_profile(preset_id: String, preset_label: String) -> RigStyleProfile:
	var p := RigStyleProfile.new()
	p.id = preset_id
	p.label = preset_label
	p.pipeline_mode = _pipeline_opt.selected if _pipeline_opt != null else 0
	p.enable_halftone = get_check_val("enable_halftone")
	p.halftone_pattern_type = _halftone_pat_opt.selected if _halftone_pat_opt != null else 0
	p.halftone_zone_mode = _halftone_zone_opt.selected if _halftone_zone_opt != null else 0
	p.halftone_scale = get_slider_val("halftone_scale", 165.0)
	p.halftone_strength = get_slider_val("halftone_strength", 0.0)
	p.halftone_angle_deg = get_slider_val("halftone_angle_deg", 45.0)
	p.halftone_threshold = get_slider_val("halftone_threshold", 0.38)
	p.ink_boost = get_slider_val("ink_boost", 0.10)
	p.cel_step_strength = get_slider_val("cel_step_strength", 0.0)
	p.noir_shadow_crush = get_slider_val("noir_shadow_crush", 0.0)
	p.noir_shadow_threshold = get_slider_val("noir_shadow_threshold", 0.24)
	p.metal_sheen_strength = get_slider_val("metal_sheen_strength", 0.0)
	p.rim_light_strength = get_slider_val("rim_light_strength", 0.12)
	p.rim_width_px = get_slider_val("rim_width_px", 4.5)
	p.dual_rim_strength = get_slider_val("dual_rim_strength", 0.0)
	p.glow_intensity = get_slider_val("glow_intensity", 1.05)
	p.outer_outline_tint_mix = get_slider_val("outer_outline_tint_mix", 0.55)
	return p


func get_slider_val(key: String, fallback: float = 0.0) -> float:
	var s: HSlider = _sliders.get(key, null) as HSlider
	return float(s.value) if s != null else fallback


func get_check_val(key: String, fallback: bool = false) -> bool:
	var c: CheckBox = _checks.get(key, null) as CheckBox
	return c.button_pressed if c != null else fallback


func set_light_angle_deg_ui(angle_deg: float) -> void:
	_suppress_signals = true
	_set_slider_val("light_angle_deg", wrapf(angle_deg, 0.0, 360.0))
	_suppress_signals = false


func _make_panel_style(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(10)
	return sb


func _make_tab_page(tabs: TabContainer, title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_child(scroll)

	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_theme_constant_override("margin_left", 4)
	pad.add_theme_constant_override("margin_right", 8)
	pad.add_theme_constant_override("margin_top", 8)
	pad.add_theme_constant_override("margin_bottom", 8)
	scroll.add_child(pad)

	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 8)
	pad.add_child(vb)
	return vb


func _build_look_tab(
	parent: VBoxContainer,
	style_labels: Array[String],
	skin_labels: Array[String],
	hair_labels: Array[String]
) -> void:
	_add_section_title(parent, "Dirección y Cabeza")

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	parent.add_child(grid)
	for d_key: String in DIRECTIONS_8:
		var btn := Button.new()
		btn.text = d_key.to_upper()
		btn.toggle_mode = true
		btn.button_pressed = (d_key == "s")
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(func() -> void: view_selected.emit(d_key))
		grid.add_child(btn)
		_dir_buttons[d_key] = btn

	var head_row := HBoxContainer.new()
	parent.add_child(head_row)
	var prev_h := Button.new()
	prev_h.text = "◀"
	prev_h.pressed.connect(func() -> void: head_step_requested.emit(-1))
	head_row.add_child(prev_h)
	_head_label = Label.new()
	_head_label.text = "front"
	_head_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_head_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head_row.add_child(_head_label)
	var next_h := Button.new()
	next_h.text = "▶"
	next_h.pressed.connect(func() -> void: head_step_requested.emit(1))
	head_row.add_child(next_h)

	_add_section_title(parent, "Comparación y Fondo")
	var cmp_opt: OptionButton = _add_option_row(parent, "Vista", [
		"A/B Lado a Lado", "Hero (Solo Shader)", "Superpuesto (Tab)"
	])
	cmp_opt.item_selected.connect(func(idx: int) -> void: compare_mode_changed.emit(idx))

	var bg_opt: OptionButton = _add_option_row(parent, "Fondo", [
		"Oscuro Neutro", "Claro Estudio", "Grilla Damero", "Espacio / Nebulosa"
	])
	bg_opt.item_selected.connect(func(idx: int) -> void: backdrop_changed.emit(idx))

	_add_section_title(parent, "Presets de Apariencia")
	_style_opt = _add_option_row(parent, "Estilo", style_labels)
	_style_opt.item_selected.connect(func(idx: int) -> void:
		if not _suppress_signals:
			style_preset_selected.emit(idx)
	)
	_skin_opt = _add_option_row(parent, "Skin", skin_labels)
	_skin_opt.item_selected.connect(func(idx: int) -> void:
		if not _suppress_signals:
			skin_preset_selected.emit(idx)
	)
	_hair_opt = _add_option_row(parent, "Pelo", hair_labels)
	_hair_opt.item_selected.connect(func(idx: int) -> void:
		if not _suppress_signals:
			hair_preset_selected.emit(idx)
	)

	_add_section_title(parent, "Guardar Preset (.tres)")
	var save_row := HBoxContainer.new()
	parent.add_child(save_row)
	_save_name_edit = LineEdit.new()
	_save_name_edit.placeholder_text = "09_mi_estilo"
	_save_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_row.add_child(_save_name_edit)
	var save_btn := Button.new()
	save_btn.text = "Guardar"
	save_btn.pressed.connect(func() -> void: save_preset_requested.emit(_save_name_edit.text.strip_edges()))
	save_row.add_child(save_btn)

	var reset_btn := Button.new()
	reset_btn.text = "Volver a 00_original"
	reset_btn.pressed.connect(func() -> void: reset_style_requested.emit())
	parent.add_child(reset_btn)

	_save_feedback_lbl = Label.new()
	_save_feedback_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(_save_feedback_lbl)


func _build_light_cel_tab(parent: VBoxContainer) -> void:
	_add_section_title(parent, "Luz Direccional 2.5D")
	var row := HBoxContainer.new()
	parent.add_child(row)
	var nd_chk := _add_check_inline(row, "use_normal_depth", "Normales 2.5D", true)
	nd_chk.toggled.connect(func(_on: bool) -> void:
		if not _suppress_signals:
			light_options_changed.emit()
	)
	_add_check_inline(row, "auto_rotate_light", "Rotar Luz", false)

	_add_slider(parent, "light_angle_deg", "Ángulo de Luz (°)", 0.0, 360.0, 1.0, 234.0, func(_v: float) -> void:
		light_options_changed.emit()
	)
	_add_slider(parent, "light_z_tilt", "Elevación Z", 0.10, 2.0, 0.02, 0.58, func(v: float) -> void:
		shader_param_changed.emit("light_z_tilt", v)
	)
	_add_slider(parent, "normal_cel_influence", "Fuerza Normales", 0.0, 1.0, 0.02, 0.52, func(v: float) -> void:
		shader_param_changed.emit("normal_cel_influence", v)
	)
	_add_slider(parent, "normal_rim_strength", "Rim Normal 2.5D", 0.0, 2.5, 0.05, 0.45, func(_v: float) -> void:
		light_options_changed.emit()
	)

	_add_section_title(parent, "Cel-Shading y Rim Light")
	_pipeline_opt = _add_option_row(parent, "Modo", [
		"0: Original", "1: Trigger Cel", "2: Skullgirls", "3: Guilty Gear",
		"4: Spider-Verse", "5: Persona 5 Noir", "6: Edgerunners",
		"7: Kill la Kill", "8: Arcane Metal"
	])
	_pipeline_opt.item_selected.connect(func(idx: int) -> void:
		if not _suppress_signals:
			shader_param_changed.emit("pipeline_style_mode", idx)
	)

	_add_slider(parent, "cel_step_strength", "Escalón Cel", 0.0, 1.0, 0.02, 0.0, func(v: float) -> void:
		shader_param_changed.emit("cel_step_strength", v)
	)
	_add_slider(parent, "ink_boost", "Refuerzo de Tinta", 0.0, 1.0, 0.02, 0.10, func(v: float) -> void:
		shader_param_changed.emit("ink_boost", v)
	)
	_add_slider(parent, "noir_shadow_crush", "Sombras Noir", 0.0, 1.0, 0.02, 0.0, func(v: float) -> void:
		shader_param_changed.emit("noir_shadow_crush", v)
	)
	_add_slider(parent, "noir_shadow_threshold", "Umbral Noir", 0.10, 0.45, 0.01, 0.24, func(v: float) -> void:
		shader_param_changed.emit("noir_shadow_threshold", v)
	)
	_add_slider(parent, "metal_sheen_strength", "Brillo Metálico", 0.0, 1.5, 0.05, 0.0, func(v: float) -> void:
		shader_param_changed.emit("metal_sheen_strength", v)
	)
	_add_slider(parent, "rim_light_strength", "Rim Light", 0.0, 1.5, 0.05, 0.12, func(v: float) -> void:
		shader_param_changed.emit("rim_light_strength", v)
	)
	_add_slider(parent, "rim_width_px", "Ancho Rim (px)", 1.0, 14.0, 0.25, 4.5, func(v: float) -> void:
		shader_param_changed.emit("rim_width_px", v)
	)
	_add_slider(parent, "dual_rim_strength", "Dual Rim", 0.0, 1.5, 0.05, 0.0, func(v: float) -> void:
		shader_param_changed.emit("dual_rim_strength", v)
	)
	_add_slider(parent, "glow_intensity", "Glow Emisivo", 0.0, 3.0, 0.05, 1.05, func(v: float) -> void:
		shader_param_changed.emit("glow_intensity", v)
	)
	_add_slider(parent, "crt_hdr_boost", "Boost HDR", 1.0, 3.0, 0.05, 1.0, func(_v: float) -> void:
		light_options_changed.emit()
	)
	_add_slider(parent, "ilm_shadow_bias_strength", "ILM Shadow Bias", 0.0, 1.0, 0.02, 0.65, func(v: float) -> void:
		shader_param_changed.emit("ilm_shadow_bias_strength", v)
	)
	_add_slider(parent, "ilm_spec_strength", "ILM Especular", 0.0, 1.5, 0.05, 0.75, func(v: float) -> void:
		shader_param_changed.emit("ilm_spec_strength", v)
	)


func _build_trama_outline_tab(parent: VBoxContainer) -> void:
	_add_section_title(parent, "Semitono / Trama Manga")
	var ht_chk := _add_check(parent, "enable_halftone", "Activar Trama / Halftone", false)
	ht_chk.toggled.connect(func(on: bool) -> void:
		if not _suppress_signals:
			shader_param_changed.emit("enable_halftone", on)
	)

	_halftone_pat_opt = _add_option_row(parent, "Patrón", [
		"Puntos", "Líneas Manga", "Crosshatch", "Diamantes", "Ben-Day", "Hex"
	])
	_halftone_pat_opt.item_selected.connect(func(idx: int) -> void:
		if not _suppress_signals:
			shader_param_changed.emit("halftone_pattern_type", idx)
	)
	_halftone_zone_opt = _add_option_row(parent, "Zona", [
		"Sombras", "Medios", "Toda Silueta", "Bordes"
	])
	_halftone_zone_opt.item_selected.connect(func(idx: int) -> void:
		if not _suppress_signals:
			shader_param_changed.emit("halftone_zone_mode", idx)
	)

	_add_slider(parent, "halftone_strength", "Intensidad", 0.0, 1.0, 0.02, 0.0, func(v: float) -> void:
		shader_param_changed.emit("halftone_strength", v)
	)
	_add_slider(parent, "halftone_scale", "Densidad", 40.0, 320.0, 2.0, 165.0, func(v: float) -> void:
		shader_param_changed.emit("halftone_scale", v)
	)
	_add_slider(parent, "halftone_angle_deg", "Ángulo (°)", 0.0, 180.0, 1.0, 45.0, func(v: float) -> void:
		shader_param_changed.emit("halftone_angle_deg", v)
	)
	_add_slider(parent, "halftone_threshold", "Umbral", 0.15, 0.85, 0.01, 0.38, func(v: float) -> void:
		shader_param_changed.emit("halftone_threshold", v)
	)

	_add_section_title(parent, "Color y Outline")
	_add_slider(parent, "recolor_contrast", "Contraste", 0.4, 2.2, 0.02, 1.0, func(v: float) -> void:
		shader_param_changed.emit("recolor_contrast", v)
	)
	_add_slider(parent, "recolor_saturation", "Saturación", 0.0, 2.0, 0.02, 1.0, func(v: float) -> void:
		shader_param_changed.emit("recolor_saturation", v)
	)
	_add_slider(parent, "recolor_highlight", "Highlight", 0.0, 2.0, 0.02, 1.0, func(v: float) -> void:
		shader_param_changed.emit("recolor_highlight", v)
	)
	_add_slider(parent, "stocking_denier", "Denier Medias", 0.0, 1.0, 0.02, 0.35, func(v: float) -> void:
		shader_param_changed.emit("stocking_denier", v)
	)

	var out_row := HBoxContainer.new()
	parent.add_child(out_row)
	var in_chk := _add_check_inline(out_row, "inward_outline", "Outline Int.", true)
	in_chk.toggled.connect(func(_on: bool) -> void: inward_outline_changed.emit())
	var hd_chk := _add_check_inline(out_row, "inward_on_head", "+Cabeza", false)
	hd_chk.toggled.connect(func(_on: bool) -> void: inward_outline_changed.emit())

	_add_slider(parent, "inward_outline_px", "Grosor Interno (px)", 0.0, 4.0, 0.05, 1.35, func(_v: float) -> void:
		inward_outline_changed.emit()
	)
	_add_slider(parent, "outer_outline_tint_mix", "Pass2 Tint Mix", 0.0, 1.0, 0.02, 0.55, func(v: float) -> void:
		pass2_param_changed.emit("outer_outline_tint_mix", v)
	)
	_add_slider(parent, "hdr_light_wrap_strength", "Pass2 HDR Wrap", 0.0, 1.0, 0.02, 0.42, func(v: float) -> void:
		pass2_param_changed.emit("hdr_light_wrap_strength", v)
	)


func _build_extra_debug_tab(parent: VBoxContainer) -> void:
	_add_section_title(parent, "Movimiento y Recoloreo")
	var anim_chk := _add_check(parent, "anim_play", "Respiración / Animación sutil", false)
	anim_chk.toggled.connect(func(on: bool) -> void: anim_toggled.emit(on))
	var head_chk := _add_check(parent, "head_cycle", "Rotar cabeza automáticamente", false)
	head_chk.toggled.connect(func(on: bool) -> void: head_cycle_toggled.emit(on))

	_hair_mode_opt = _add_option_row(parent, "Pelo", [
		"Sólido Cel", "Bicolor Trigger", "Puntas Dip-Dye", "Angel Ring"
	])
	_hair_mode_opt.item_selected.connect(func(idx: int) -> void:
		if not _suppress_signals:
			hair_style_mode_changed.emit(idx)
	)
	_recolor_opt = _add_option_row(parent, "Recolor", [
		"Multiplicativo", "3-Tonos", "Perceptual", "Overlay", "Cel-Ramp 3B"
	])
	_recolor_opt.select(1)
	_recolor_opt.item_selected.connect(func(idx: int) -> void:
		if not _suppress_signals:
			recolor_method_changed.emit(idx)
	)

	_add_section_title(parent, "Inspector Rayos-X")
	var dbg_opt: OptionButton = _add_option_row(parent, "Canal", [
		"Render Final", "Clown-Pass ID", "Luminancia", "Solo Tinta", "Normales 2.5D", "Profundidad 2.5D", "ILM Mask"
	])
	dbg_opt.item_selected.connect(func(idx: int) -> void: debug_view_changed.emit(idx))

	var pinch_chk := _add_check(parent, "debug_pinch", "Mostrar Overlay Stocking Pinch", false)
	pinch_chk.toggled.connect(func(on: bool) -> void: pinch_debug_toggled.emit(on))


func _add_section_title(parent: VBoxContainer, title: String) -> void:
	var sep := HSeparator.new()
	parent.add_child(sep)
	var lbl := Label.new()
	lbl.text = title
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.modulate = Color(0.65, 0.84, 1.0)
	parent.add_child(lbl)


func _add_option_row(parent: VBoxContainer, label_txt: String, items: Array[String]) -> OptionButton:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(row)
	var lbl := Label.new()
	lbl.text = label_txt
	lbl.custom_minimum_size = Vector2(66.0, 0.0)
	lbl.modulate = Color(0.84, 0.88, 0.94)
	row.add_child(lbl)
	var opt := OptionButton.new()
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt.clip_text = true
	opt.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	for it: String in items:
		opt.add_item(it)
	row.add_child(opt)
	return opt


func _add_check(parent: VBoxContainer, key: String, text: String, init_val: bool) -> CheckBox:
	var chk := CheckBox.new()
	chk.text = text
	chk.button_pressed = init_val
	parent.add_child(chk)
	_checks[key] = chk
	return chk


func _add_check_inline(parent: HBoxContainer, key: String, text: String, init_val: bool) -> CheckBox:
	var chk := CheckBox.new()
	chk.text = text
	chk.button_pressed = init_val
	chk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(chk)
	_checks[key] = chk
	return chk


func _add_slider(
	parent: VBoxContainer,
	key: String,
	title: String,
	min_v: float,
	max_v: float,
	step_v: float,
	init_v: float,
	cb: Callable
) -> void:
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 2)
	parent.add_child(vb)

	var top := HBoxContainer.new()
	vb.add_child(top)
	var lbl := Label.new()
	lbl.text = title
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.modulate = Color(0.86, 0.90, 0.96)
	top.add_child(lbl)
	var val_lbl := Label.new()
	val_lbl.text = "%.2f" % init_v
	val_lbl.add_theme_font_size_override("font_size", 12)
	val_lbl.modulate = Color(0.68, 0.85, 1.0)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(val_lbl)

	var sl := HSlider.new()
	sl.min_value = min_v
	sl.max_value = max_v
	sl.step = step_v
	sl.value = init_v
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.value_changed.connect(func(v: float) -> void:
		val_lbl.text = "%.2f" % v
		if not _suppress_signals:
			cb.call(v)
	)
	vb.add_child(sl)

	_sliders[key] = sl
	_slider_labels[key] = val_lbl


func _set_slider_val(key: String, val: float) -> void:
	var s: HSlider = _sliders.get(key, null) as HSlider
	if s != null:
		s.value = val
	var lbl: Label = _slider_labels.get(key, null) as Label
	if lbl != null:
		lbl.text = "%.2f" % val


func _set_check_val(key: String, val: bool) -> void:
	var c: CheckBox = _checks.get(key, null) as CheckBox
	if c != null:
		c.button_pressed = val

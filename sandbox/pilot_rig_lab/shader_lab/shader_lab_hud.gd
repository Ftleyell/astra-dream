class_name ShaderLabHud
extends CanvasLayer
## Panel HUD izquierdo con pestañas y diseño limpio para el Laboratorio de Shaders de Valentina v2.

signal view_selected(view_key: String)
signal head_step_requested(delta_idx: int)
signal head_cycle_toggled(enabled: bool)
signal compare_mode_changed(mode_idx: int)
signal anim_toggled(playing: bool)
signal backdrop_changed(mode_idx: int)
signal supersampling_changed(scale_factor: float)
signal debug_view_changed(mode_idx: int)
signal pinch_debug_toggled(enabled: bool)

signal style_preset_selected(index: int)
signal skin_preset_selected(index: int)
signal hair_preset_selected(index: int)
signal hair_style_mode_changed(mode_idx: int)
signal recolor_method_changed(method_idx: int)
signal reset_style_requested()
signal definitive_style_requested()
signal save_preset_requested(preset_name: String)

signal light_options_changed()
signal counter_rim_options_changed()
signal shader_param_changed(param_name: String, value: Variant)
signal pass2_param_changed(param_name: String, value: Variant)

const DIRECTIONS_8: Array[String] = ["s", "se", "e", "ne", "n", "nw", "w", "sw"]
const PANEL_WIDTH: float = 324.0

var _root_ctrl: Control = null
var _side_panel: PanelContainer = null
var _toggle_btn: Button = null
var _status_label: Label = null
var _head_label: Label = null
var _backdrop_opt: OptionButton = null
var _style_opt: OptionButton = null
var _skin_opt: OptionButton = null
var _hair_opt: OptionButton = null
var _hair_mode_opt: OptionButton = null
var _recolor_opt: OptionButton = null
var _save_name_edit: LineEdit = null
var _save_feedback_lbl: Label = null

var _dir_buttons: Dictionary = {}
var _sliders: Dictionary = {}
var _slider_labels: Dictionary = {}
var _checks: Dictionary = {}
var _colors: Dictionary = {}
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
	var tab_cel: VBoxContainer = _make_tab_page(tabs, "Cel/Luz")
	var tab_mat: VBoxContainer = _make_tab_page(tabs, "Mat/Borde")
	var tab_dbg: VBoxContainer = _make_tab_page(tabs, "Extra")

	_build_look_tab(tab_look, style_labels, skin_labels, hair_labels)
	_build_cel_light_tab(tab_cel)
	_build_materials_outline_tab(tab_mat)
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


func set_backdrop_index(idx: int) -> void:
	if _backdrop_opt == null:
		return
	_suppress_signals = true
	_backdrop_opt.select(clampi(idx, 0, _backdrop_opt.item_count - 1))
	_suppress_signals = false


func sync_from_style_profile(profile: RigStyleProfile) -> void:
	if profile == null:
		return
	_suppress_signals = true
	_set_check_val("stylize_enabled", profile.stylize_enabled)
	_set_check_val("use_normal_depth", profile.use_normal_depth)
	_set_slider_val("cel_strength", profile.cel_strength)
	_set_slider_val("cel_threshold", profile.cel_threshold)
	_set_slider_val("cel_softness", profile.cel_softness)
	_set_slider_val("cel_mid_band_strength", profile.cel_mid_band_strength)
	_set_slider_val("albedo_de_shade", profile.albedo_de_shade)
	_set_slider_val("ilm_shadow_bias_strength", profile.ilm_shadow_bias_strength)
	_set_slider_val("ilm_ao_strength", profile.ilm_ao_strength)
	_set_slider_val("face_shadow_protect", profile.face_shadow_protect)
	_set_color_val("key_light_tint", profile.key_light_tint)
	_set_color_val("shadow_tint", profile.shadow_tint)
	_set_color_val("ao_tint", profile.ao_tint)
	_set_color_val("skin_shadow_tint", profile.skin_shadow_tint)
	_set_color_val("sss_skin_color", profile.sss_skin_color)
	_set_slider_val("sss_strength", profile.sss_strength)
	_set_slider_val("color_contrast", profile.color_contrast)
	_set_slider_val("color_saturation", profile.color_saturation)
	_set_slider_val("key_light_boost", profile.key_light_boost)
	_set_slider_val("armor_spec_strength", profile.armor_spec_strength)
	_set_slider_val("armor_spec_threshold", profile.armor_spec_threshold)
	_set_slider_val("suit_satin_strength", profile.suit_satin_strength)
	_set_slider_val("nylon_sheen_strength", profile.nylon_sheen_strength)
	_set_slider_val("stocking_denier", profile.stocking_denier)
	_set_slider_val("hair_angel_ring_strength", profile.hair_angel_ring_strength)
	_set_slider_val("emissive_glow_strength", profile.emissive_glow_strength)
	_set_slider_val("hdr_cap", profile.hdr_cap)
	_set_slider_val("albedo_lod_bias", profile.albedo_lod_bias)
	_set_slider_val("ink_strength", profile.ink_strength)
	_set_slider_val("ink_color_tint_mix", profile.ink_color_tint_mix)
	_set_color_val("ink_skin_tint", profile.ink_skin_tint)
	_set_color_val("ink_cool_tint", profile.ink_cool_tint)
	_set_slider_val("ink_sdf_bias_px", profile.ink_sdf_bias_px)
	_set_slider_val("ink_sdf_softness", profile.ink_sdf_softness)
	_set_slider_val("normal_rim_strength", profile.normal_rim_strength)
	_set_slider_val("silhouette_rim_strength", profile.silhouette_rim_strength)
	_set_slider_val("silhouette_rim_width_px", profile.silhouette_rim_width_px)
	_set_slider_val("counter_rim_strength", profile.counter_rim_strength)
	_set_color_val("rim_key_color", profile.rim_key_color)
	_set_check_val("counter_rim_use_skin_accent", profile.counter_rim_use_skin_accent)
	_set_color_val("counter_rim_override_color", profile.counter_rim_override_color)
	_set_check_val("enable_outer_outline", profile.enable_outer_outline)
	_set_slider_val("outer_outline_width_px", profile.outer_outline_width_px)
	_set_slider_val("outline_min_px", profile.outline_min_px)
	_set_slider_val("outline_max_px", profile.outline_max_px)
	_set_slider_val("outer_outline_strength", profile.outer_outline_strength)
	_set_slider_val("outer_outline_tint_mix", profile.outer_outline_tint_mix)
	_set_slider_val("outline_calligraphy_amount", profile.outline_calligraphy_amount)
	_set_slider_val("outline_crispness", profile.outline_crispness)
	_set_slider_val("outline_inward_replace", profile.outline_inward_replace)
	_set_slider_val("ign_jitter_strength", profile.ign_jitter_strength)
	_set_color_val("outer_outline_color", profile.outer_outline_color)
	_set_slider_val("hdr_light_wrap_strength", profile.hdr_light_wrap_strength)
	_set_slider_val("hdr_threshold", profile.hdr_threshold)
	_set_slider_val("cas_sharpen_strength", profile.cas_sharpen_strength)
	_suppress_signals = false


func export_current_style_profile(preset_id: String, preset_label: String) -> RigStyleProfile:
	var p := RigStyleProfile.new()
	p.id = preset_id
	p.label = preset_label
	p.stylize_enabled = get_check_val("stylize_enabled", true)
	p.use_normal_depth = get_check_val("use_normal_depth", true)
	p.cel_strength = get_slider_val("cel_strength", 0.88)
	p.cel_threshold = get_slider_val("cel_threshold", 0.05)
	p.cel_softness = get_slider_val("cel_softness", 0.038)
	p.cel_mid_band_strength = get_slider_val("cel_mid_band_strength", 0.42)
	p.albedo_de_shade = get_slider_val("albedo_de_shade", 0.34)
	p.ilm_shadow_bias_strength = get_slider_val("ilm_shadow_bias_strength", 0.74)
	p.ilm_ao_strength = get_slider_val("ilm_ao_strength", 0.82)
	p.face_shadow_protect = get_slider_val("face_shadow_protect", 0.88)
	p.key_light_tint = get_color_val("key_light_tint", Color(1.05, 1.02, 0.96, 1.0))
	p.shadow_tint = get_color_val("shadow_tint", Color(0.180, 0.169, 0.361, 1.0))
	p.ao_tint = get_color_val("ao_tint", Color(0.098, 0.078, 0.196, 1.0))
	p.skin_shadow_tint = get_color_val("skin_shadow_tint", Color(0.68, 0.43, 0.50, 1.0))
	p.sss_skin_color = get_color_val("sss_skin_color", Color(0.97, 0.37, 0.30, 1.0))
	p.sss_strength = get_slider_val("sss_strength", 0.48)
	p.color_contrast = get_slider_val("color_contrast", 1.09)
	p.color_saturation = get_slider_val("color_saturation", 1.12)
	p.key_light_boost = get_slider_val("key_light_boost", 1.08)
	p.armor_spec_strength = get_slider_val("armor_spec_strength", 0.92)
	p.armor_spec_threshold = get_slider_val("armor_spec_threshold", 0.65)
	p.suit_satin_strength = get_slider_val("suit_satin_strength", 0.34)
	p.nylon_sheen_strength = get_slider_val("nylon_sheen_strength", 0.68)
	p.stocking_denier = get_slider_val("stocking_denier", 0.34)
	p.hair_angel_ring_strength = get_slider_val("hair_angel_ring_strength", 0.88)
	p.emissive_glow_strength = get_slider_val("emissive_glow_strength", 1.35)
	p.hdr_cap = get_slider_val("hdr_cap", 1.85)
	p.albedo_lod_bias = get_slider_val("albedo_lod_bias", 0.0)
	p.ink_strength = get_slider_val("ink_strength", 0.68)
	p.ink_color_tint_mix = get_slider_val("ink_color_tint_mix", 0.78)
	p.ink_skin_tint = get_color_val("ink_skin_tint", Color(0.24, 0.11, 0.12, 1.0))
	p.ink_cool_tint = get_color_val("ink_cool_tint", Color(0.055, 0.055, 0.130, 1.0))
	p.ink_sdf_bias_px = get_slider_val("ink_sdf_bias_px", -0.05)
	p.ink_sdf_softness = get_slider_val("ink_sdf_softness", 0.55)
	p.normal_rim_strength = get_slider_val("normal_rim_strength", 0.78)
	p.silhouette_rim_strength = get_slider_val("silhouette_rim_strength", 0.62)
	p.silhouette_rim_width_px = get_slider_val("silhouette_rim_width_px", 1.45)
	p.counter_rim_strength = get_slider_val("counter_rim_strength", 0.52)
	p.rim_key_color = get_color_val("rim_key_color", Color(0.94, 0.97, 1.0, 1.0))
	p.counter_rim_use_skin_accent = get_check_val("counter_rim_use_skin_accent", true)
	p.counter_rim_override_color = get_color_val("counter_rim_override_color", Color(0.86, 0.18, 0.32, 1.0))
	p.enable_outer_outline = get_check_val("enable_outer_outline", true)
	p.outer_outline_width_px = get_slider_val("outer_outline_width_px", 0.78)
	p.outline_min_px = get_slider_val("outline_min_px", 0.48)
	p.outline_max_px = get_slider_val("outline_max_px", 1.15)
	p.outer_outline_strength = get_slider_val("outer_outline_strength", 0.92)
	p.outer_outline_tint_mix = get_slider_val("outer_outline_tint_mix", 0.78)
	p.outline_calligraphy_amount = get_slider_val("outline_calligraphy_amount", 0.65)
	p.outline_crispness = get_slider_val("outline_crispness", 0.42)
	p.outline_inward_replace = get_slider_val("outline_inward_replace", 0.12)
	p.ign_jitter_strength = get_slider_val("ign_jitter_strength", 0.0)
	p.outer_outline_color = get_color_val("outer_outline_color", Color(0.045, 0.040, 0.095, 1.0))
	p.hdr_light_wrap_strength = get_slider_val("hdr_light_wrap_strength", 0.58)
	p.hdr_threshold = get_slider_val("hdr_threshold", 1.05)
	p.cas_sharpen_strength = get_slider_val("cas_sharpen_strength", 0.0)
	return p


func get_slider_val(key: String, fallback: float = 0.0) -> float:
	var s: HSlider = _sliders.get(key, null) as HSlider
	return float(s.value) if s != null else fallback


func get_check_val(key: String, fallback: bool = false) -> bool:
	var c: CheckBox = _checks.get(key, null) as CheckBox
	return c.button_pressed if c != null else fallback


func get_color_val(key: String, fallback: Color = Color.WHITE) -> Color:
	var p: ColorPickerButton = _colors.get(key, null) as ColorPickerButton
	return p.color if p != null else fallback


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

	_backdrop_opt = _add_option_row(parent, "Fondo", [
		"Oscuro Neutro", "Claro Estudio", "Grilla Damero", "Espacio / Nebulosa"
	])
	_backdrop_opt.select(3)
	_backdrop_opt.item_selected.connect(func(idx: int) -> void:
		if not _suppress_signals:
			backdrop_changed.emit(idx)
	)
	var ssaa_opt: OptionButton = _add_option_row(parent, "SSAA", [
		"1.0× Nativo", "1.5× HQ", "2.0× Ultra (SubViewport)"
	])
	ssaa_opt.select(2)
	ssaa_opt.item_selected.connect(func(idx: int) -> void:
		if not _suppress_signals:
			var scales: Array[float] = [1.0, 1.5, 2.0]
			supersampling_changed.emit(scales[clampi(idx, 0, scales.size() - 1)])
	)

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
	_save_name_edit.placeholder_text = "01_valentina_definitive"
	_save_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_row.add_child(_save_name_edit)
	var save_btn := Button.new()
	save_btn.text = "Guardar"
	save_btn.pressed.connect(func() -> void: save_preset_requested.emit(_save_name_edit.text.strip_edges()))
	save_row.add_child(save_btn)

	var quick_row := HBoxContainer.new()
	parent.add_child(quick_row)
	var reset_btn := Button.new()
	reset_btn.text = "Baseline (00)"
	reset_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset_btn.pressed.connect(func() -> void: reset_style_requested.emit())
	quick_row.add_child(reset_btn)
	var def_btn := Button.new()
	def_btn.text = "Definitivo (01)"
	def_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	def_btn.pressed.connect(func() -> void: definitive_style_requested.emit())
	quick_row.add_child(def_btn)

	_save_feedback_lbl = Label.new()
	_save_feedback_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(_save_feedback_lbl)


func _build_cel_light_tab(parent: VBoxContainer) -> void:
	_add_section_title(parent, "Luz Direccional 2.5D")
	var sty_chk := _add_check(parent, "stylize_enabled", "Activar Estilizado Definitivo", true)
	sty_chk.toggled.connect(func(on: bool) -> void:
		if not _suppress_signals:
			shader_param_changed.emit("stylize_enabled", on)
	)

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

	_add_section_title(parent, "Corte Cel & ILM (ArcSys)")
	_add_slider(parent, "cel_strength", "Fuerza Cel", 0.0, 1.0, 0.02, 0.88, func(v: float) -> void:
		shader_param_changed.emit("cel_strength", v)
	)
	_add_slider(parent, "cel_threshold", "Umbral Corte Cel", -0.60, 0.60, 0.01, 0.05, func(v: float) -> void:
		shader_param_changed.emit("cel_threshold", v)
	)
	_add_slider(parent, "cel_softness", "Suavidad Terminador", 0.005, 0.25, 0.005, 0.038, func(v: float) -> void:
		shader_param_changed.emit("cel_softness", v)
	)
	_add_slider(parent, "cel_mid_band_strength", "Banda Intermedia", 0.0, 1.0, 0.02, 0.42, func(v: float) -> void:
		shader_param_changed.emit("cel_mid_band_strength", v)
	)
	_add_slider(parent, "albedo_de_shade", "Compensación Albedo", 0.0, 1.0, 0.02, 0.34, func(v: float) -> void:
		shader_param_changed.emit("albedo_de_shade", v)
	)
	_add_slider(parent, "ilm_shadow_bias_strength", "ILM Shadow Bias", 0.0, 1.0, 0.02, 0.74, func(v: float) -> void:
		shader_param_changed.emit("ilm_shadow_bias_strength", v)
	)
	_add_slider(parent, "ilm_ao_strength", "ILM Deep AO", 0.0, 1.0, 0.02, 0.82, func(v: float) -> void:
		shader_param_changed.emit("ilm_ao_strength", v)
	)
	_add_slider(parent, "face_shadow_protect", "Protección Rostro", 0.0, 1.0, 0.02, 0.88, func(v: float) -> void:
		shader_param_changed.emit("face_shadow_protect", v)
	)

	_add_section_title(parent, "Paleta y Color Grading")
	_add_color_row(parent, "key_light_tint", "Tinte Luz Clave", Color(1.05, 1.02, 0.96, 1.0), func(col: Color) -> void:
		shader_param_changed.emit("key_light_tint", col)
	)
	_add_color_row(parent, "shadow_tint", "Sombra Principal", Color(0.180, 0.169, 0.361, 1.0), func(col: Color) -> void:
		shader_param_changed.emit("shadow_tint", col)
	)
	_add_color_row(parent, "ao_tint", "Oclusión AO", Color(0.098, 0.078, 0.196, 1.0), func(col: Color) -> void:
		shader_param_changed.emit("ao_tint", col)
	)
	_add_color_row(parent, "skin_shadow_tint", "Sombra Piel", Color(0.68, 0.43, 0.50, 1.0), func(col: Color) -> void:
		shader_param_changed.emit("skin_shadow_tint", col)
	)
	_add_color_row(parent, "sss_skin_color", "SSS Terminador", Color(0.97, 0.37, 0.30, 1.0), func(col: Color) -> void:
		shader_param_changed.emit("sss_skin_color", col)
	)
	_add_slider(parent, "sss_strength", "Intensidad SSS", 0.0, 1.5, 0.02, 0.48, func(v: float) -> void:
		shader_param_changed.emit("sss_strength", v)
	)
	_add_slider(parent, "color_contrast", "Contraste Final", 0.7, 1.6, 0.01, 1.09, func(v: float) -> void:
		shader_param_changed.emit("color_contrast", v)
	)
	_add_slider(parent, "color_saturation", "Saturación Final", 0.5, 1.8, 0.02, 1.12, func(v: float) -> void:
		shader_param_changed.emit("color_saturation", v)
	)
	_add_slider(parent, "key_light_boost", "Boost Luz Clave", 0.8, 1.5, 0.01, 1.08, func(v: float) -> void:
		shader_param_changed.emit("key_light_boost", v)
	)


func _build_materials_outline_tab(parent: VBoxContainer) -> void:
	_add_section_title(parent, "Materiales (ID + ILM)")
	_add_slider(parent, "armor_spec_strength", "Especular Armadura", 0.0, 2.0, 0.02, 0.92, func(v: float) -> void:
		shader_param_changed.emit("armor_spec_strength", v)
	)
	_add_slider(parent, "armor_spec_threshold", "Umbral Armadura", 0.25, 0.95, 0.01, 0.65, func(v: float) -> void:
		shader_param_changed.emit("armor_spec_threshold", v)
	)
	_add_slider(parent, "suit_satin_strength", "Satén Traje", 0.0, 1.5, 0.02, 0.34, func(v: float) -> void:
		shader_param_changed.emit("suit_satin_strength", v)
	)
	_add_slider(parent, "nylon_sheen_strength", "Brillo Nylon Medias", 0.0, 1.5, 0.02, 0.68, func(v: float) -> void:
		shader_param_changed.emit("nylon_sheen_strength", v)
	)
	_add_slider(parent, "stocking_denier", "Denier Medias", 0.0, 1.0, 0.02, 0.34, func(v: float) -> void:
		shader_param_changed.emit("stocking_denier", v)
	)
	_add_slider(parent, "hair_angel_ring_strength", "Angel Ring Cabello", 0.0, 2.0, 0.02, 0.88, func(v: float) -> void:
		shader_param_changed.emit("hair_angel_ring_strength", v)
	)
	_add_slider(parent, "emissive_glow_strength", "Glow Emisivos", 0.0, 3.0, 0.05, 1.35, func(v: float) -> void:
		shader_param_changed.emit("emissive_glow_strength", v)
	)
	_add_slider(parent, "hdr_cap", "HDR Cap", 1.0, 3.0, 0.05, 1.85, func(_v: float) -> void:
		light_options_changed.emit()
	)

	_add_section_title(parent, "Rim-Light Híbrido (Pasada 1 + 2)")
	_add_slider(parent, "normal_rim_strength", "Rim Normal 2.5D (P1)", 0.0, 2.5, 0.02, 0.78, func(_v: float) -> void:
		light_options_changed.emit()
	)
	_add_slider(parent, "silhouette_rim_strength", "Rim Silueta Clave (P2)", 0.0, 1.5, 0.02, 0.62, func(v: float) -> void:
		pass2_param_changed.emit("silhouette_rim_strength", v)
	)
	_add_slider(parent, "silhouette_rim_width_px", "Ancho Rim Silueta (px)", 0.5, 4.0, 0.05, 1.45, func(v: float) -> void:
		pass2_param_changed.emit("silhouette_rim_width_px", v)
	)
	_add_slider(parent, "counter_rim_strength", "Contra-Rim (P1+P2)", 0.0, 1.5, 0.02, 0.52, func(v: float) -> void:
		shader_param_changed.emit("counter_rim_strength", v)
		pass2_param_changed.emit("counter_rim_strength", v)
	)
	_add_color_row(parent, "rim_key_color", "Color Rim Clave", Color(0.94, 0.97, 1.0, 1.0), func(col: Color) -> void:
		shader_param_changed.emit("rim_key_color", col)
		pass2_param_changed.emit("rim_key_color", col)
	)
	var ctr_acc_chk := _add_check(parent, "counter_rim_use_skin_accent", "Contra-Rim usa Accent Skin", true)
	ctr_acc_chk.toggled.connect(func(_on: bool) -> void:
		if not _suppress_signals:
			counter_rim_options_changed.emit()
	)
	_add_color_row(parent, "counter_rim_override_color", "Color Contra-Rim Manual", Color(0.86, 0.18, 0.32, 1.0), func(_col: Color) -> void:
		counter_rim_options_changed.emit()
	)

	_add_section_title(parent, "Lineart Interno, Nitidez y Silueta Caligráfica")
	_add_slider(parent, "albedo_lod_bias", "LOD Bias Albedo (P1)", -1.5, 0.5, 0.05, 0.0, func(v: float) -> void:
		shader_param_changed.emit("albedo_lod_bias_offset", v)
	)
	_add_slider(parent, "ink_strength", "Fuerza Tinta Interna", 0.0, 1.0, 0.02, 0.68, func(v: float) -> void:
		shader_param_changed.emit("ink_strength", v)
	)
	_add_slider(parent, "ink_color_tint_mix", "Colored Line Art Mix", 0.0, 1.0, 0.02, 0.78, func(v: float) -> void:
		shader_param_changed.emit("ink_color_tint_mix", v)
	)
	_add_slider(parent, "ink_sdf_bias_px", "Bias SDF Tinta (px)", -1.5, 2.0, 0.02, 0.15, func(v: float) -> void:
		shader_param_changed.emit("ink_sdf_bias_px", v)
	)
	_add_slider(parent, "ink_sdf_softness", "Suavidad SDF Tinta", 0.10, 2.0, 0.02, 0.50, func(v: float) -> void:
		shader_param_changed.emit("ink_sdf_softness", v)
	)
	_add_color_row(parent, "ink_skin_tint", "Tinta Piel", Color(0.24, 0.11, 0.12, 1.0), func(col: Color) -> void:
		shader_param_changed.emit("ink_skin_tint", col)
	)
	_add_color_row(parent, "ink_cool_tint", "Tinta Traje/Pelo", Color(0.055, 0.055, 0.130, 1.0), func(col: Color) -> void:
		shader_param_changed.emit("ink_cool_tint", col)
	)

	var out_chk := _add_check(parent, "enable_outer_outline", "Silueta Caligráfica (Pasada 2)", true)
	out_chk.toggled.connect(func(on: bool) -> void:
		if not _suppress_signals:
			pass2_param_changed.emit("enable_outer_outline", on)
	)
	_add_slider(parent, "outer_outline_width_px", "Grosor Silueta (px)", 0.0, 8.0, 0.05, 0.78, func(v: float) -> void:
		pass2_param_changed.emit("outer_outline_width_px", v)
	)
	_add_slider(parent, "outline_min_px", "Grosor Mín Silueta (px)", 0.1, 4.0, 0.02, 0.48, func(v: float) -> void:
		pass2_param_changed.emit("outline_min_px", v)
	)
	_add_slider(parent, "outline_max_px", "Grosor Máx Silueta (px)", 0.2, 8.0, 0.05, 1.15, func(v: float) -> void:
		pass2_param_changed.emit("outline_max_px", v)
	)
	_add_slider(parent, "outer_outline_strength", "Opacidad Silueta", 0.0, 1.0, 0.02, 0.92, func(v: float) -> void:
		pass2_param_changed.emit("outer_outline_strength", v)
	)
	_add_slider(parent, "outer_outline_tint_mix", "Colored Outline Mix", 0.0, 1.0, 0.02, 0.78, func(v: float) -> void:
		pass2_param_changed.emit("outer_outline_tint_mix", v)
	)
	_add_slider(parent, "outline_calligraphy_amount", "Caligrafía Luz/Sombra", 0.0, 1.0, 0.02, 0.65, func(v: float) -> void:
		pass2_param_changed.emit("outline_calligraphy_amount", v)
	)
	_add_slider(parent, "outline_crispness", "Crispness Silueta (AA)", 0.05, 0.65, 0.01, 0.42, func(v: float) -> void:
		pass2_param_changed.emit("outline_crispness", v)
	)
	_add_slider(parent, "outline_inward_replace", "Inward Replace Silueta", 0.0, 1.0, 0.02, 0.12, func(v: float) -> void:
		pass2_param_changed.emit("outline_inward_replace", v)
	)
	_add_slider(parent, "ign_jitter_strength", "Ruido IGN Silueta", 0.0, 1.0, 0.02, 0.0, func(v: float) -> void:
		pass2_param_changed.emit("ign_jitter_strength", v)
	)
	_add_color_row(parent, "outer_outline_color", "Color Base Silueta", Color(0.045, 0.040, 0.095, 1.0), func(col: Color) -> void:
		pass2_param_changed.emit("outer_outline_color", col)
	)
	_add_slider(parent, "hdr_light_wrap_strength", "Light-Wrap HDR (P2)", 0.0, 1.0, 0.02, 0.58, func(v: float) -> void:
		pass2_param_changed.emit("hdr_light_wrap_strength", v)
	)
	_add_slider(parent, "hdr_threshold", "Umbral HDR Wrap", 1.0, 1.5, 0.01, 1.05, func(v: float) -> void:
		pass2_param_changed.emit("hdr_threshold", v)
	)
	_add_slider(parent, "cas_sharpen_strength", "CAS Sharpen (P2)", 0.0, 1.0, 0.02, 0.0, func(v: float) -> void:
		pass2_param_changed.emit("cas_sharpen_strength", v)
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
	_add_slider(parent, "recolor_contrast", "Contraste Recolor", 0.4, 2.2, 0.02, 1.0, func(v: float) -> void:
		shader_param_changed.emit("recolor_contrast", v)
	)
	_add_slider(parent, "recolor_saturation", "Saturación Recolor", 0.0, 2.0, 0.02, 1.0, func(v: float) -> void:
		shader_param_changed.emit("recolor_saturation", v)
	)
	_add_slider(parent, "recolor_highlight", "Highlight Recolor", 0.0, 2.0, 0.02, 1.0, func(v: float) -> void:
		shader_param_changed.emit("recolor_highlight", v)
	)
	_add_slider(parent, "stocking_tint_strength", "Tinte Nylon Recolor", 0.0, 1.0, 0.02, 0.28, func(v: float) -> void:
		shader_param_changed.emit("stocking_tint_strength", v)
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


func _add_color_row(parent: VBoxContainer, key: String, title: String, init_col: Color, cb: Callable) -> ColorPickerButton:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(row)
	var lbl := Label.new()
	lbl.text = title
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.modulate = Color(0.86, 0.90, 0.96)
	row.add_child(lbl)
	var picker := ColorPickerButton.new()
	picker.custom_minimum_size = Vector2(72.0, 22.0)
	picker.color = init_col
	picker.edit_alpha = false
	picker.color_changed.connect(func(col: Color) -> void:
		if not _suppress_signals:
			cb.call(col)
	)
	row.add_child(picker)
	_colors[key] = picker
	return picker


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


func _set_color_val(key: String, col: Color) -> void:
	var p: ColorPickerButton = _colors.get(key, null) as ColorPickerButton
	if p != null:
		p.color = col

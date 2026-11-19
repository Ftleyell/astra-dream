class_name ShaderLabHud
extends CanvasLayer
## Panel HUD lateral del Laboratorio de Shaders de Valentina v2.
## Totalmente desacoplado: emite señales ante cada ajuste y sincroniza sliders desde RigStyleProfile.

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


func build_ui(
	style_labels: Array[String],
	skin_labels: Array[String],
	hair_labels: Array[String]
) -> void:
	layer = 20

	# Barra superior izquierda compacta con readout + atajos
	var top_panel := PanelContainer.new()
	top_panel.position = Vector2(12.0, 12.0)
	add_child(top_panel)
	var top_box := VBoxContainer.new()
	top_panel.add_child(top_box)
	_status_label = Label.new()
	_status_label.text = "Shader Lab A/B — Valentina v2 | Rueda: Zoom | Arrastrar: Pan | Tab: Comparar | R: Centrar"
	top_box.add_child(_status_label)

	# Panel lateral derecho con scroll
	var side_panel := PanelContainer.new()
	side_panel.anchor_left = 1.0
	side_panel.anchor_right = 1.0
	side_panel.anchor_top = 0.0
	side_panel.anchor_bottom = 1.0
	side_panel.offset_left = -356.0
	side_panel.offset_right = -10.0
	side_panel.offset_top = 10.0
	side_panel.offset_bottom = -10.0
	add_child(side_panel)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_panel.add_child(scroll)

	var root_vb := VBoxContainer.new()
	root_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vb.add_theme_constant_override("separation", 6)
	scroll.add_child(root_vb)

	_build_view_section(root_vb)
	_build_presets_section(root_vb, style_labels, skin_labels, hair_labels)
	_build_lighting_section(root_vb)
	_build_stylize_section(root_vb)
	_build_halftone_section(root_vb)
	_build_color_outline_section(root_vb)
	_build_backdrop_debug_section(root_vb)


func set_status_text(txt: String) -> void:
	if _status_label != null:
		_status_label.text = txt


func set_active_view_ui(view_key: String, head_key: String) -> void:
	for k: String in _dir_buttons.keys():
		var btn: Button = _dir_buttons[k] as Button
		btn.button_pressed = (k == view_key)
	if _head_label != null:
		_head_label.text = "Cabeza: %s" % head_key


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


func _build_view_section(parent: VBoxContainer) -> void:
	_add_header(parent, "1. VISTA 8-DIR Y COMPARACIÓN A/B")

	var grid := GridContainer.new()
	grid.columns = 4
	parent.add_child(grid)
	for d_key: String in DIRECTIONS_8:
		var btn := Button.new()
		btn.text = d_key.to_upper()
		btn.toggle_mode = true
		btn.button_pressed = (d_key == "s")
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(func() -> void:
			view_selected.emit(d_key)
		)
		grid.add_child(btn)
		_dir_buttons[d_key] = btn

	var head_row := HBoxContainer.new()
	parent.add_child(head_row)
	var prev_h := Button.new()
	prev_h.text = "< Cabeza"
	prev_h.pressed.connect(func() -> void: head_step_requested.emit(-1))
	head_row.add_child(prev_h)
	_head_label = Label.new()
	_head_label.text = "Cabeza: front"
	_head_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_head_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head_row.add_child(_head_label)
	var next_h := Button.new()
	next_h.text = "Cabeza >"
	next_h.pressed.connect(func() -> void: head_step_requested.emit(1))
	head_row.add_child(next_h)

	var cmp_opt := OptionButton.new()
	cmp_opt.add_item("Modo: A/B Lado a Lado", 0)
	cmp_opt.add_item("Modo: Hero (Solo Shader)", 1)
	cmp_opt.add_item("Modo: Superpuesto (Tab = Original)", 2)
	cmp_opt.item_selected.connect(func(idx: int) -> void: compare_mode_changed.emit(idx))
	parent.add_child(cmp_opt)

	var toggles_row := HBoxContainer.new()
	parent.add_child(toggles_row)
	var anim_chk := _add_check_inline(toggles_row, "anim_play", "Animación 2.5D", false)
	anim_chk.toggled.connect(func(on: bool) -> void: anim_toggled.emit(on))
	var head_chk := _add_check_inline(toggles_row, "head_cycle", "Auto Cabeza", false)
	head_chk.toggled.connect(func(on: bool) -> void: head_cycle_toggled.emit(on))


func _build_presets_section(
	parent: VBoxContainer,
	style_labels: Array[String],
	skin_labels: Array[String],
	hair_labels: Array[String]
) -> void:
	_add_header(parent, "2. PRESETS Y GUARDADO (.TRES)")

	_style_opt = _add_option_row(parent, "Estilo:", style_labels)
	_style_opt.item_selected.connect(func(idx: int) -> void:
		if not _suppress_signals:
			style_preset_selected.emit(idx)
	)

	_skin_opt = _add_option_row(parent, "Skin:", skin_labels)
	_skin_opt.item_selected.connect(func(idx: int) -> void:
		if not _suppress_signals:
			skin_preset_selected.emit(idx)
	)

	_hair_opt = _add_option_row(parent, "Pelo:", hair_labels)
	_hair_opt.item_selected.connect(func(idx: int) -> void:
		if not _suppress_signals:
			hair_preset_selected.emit(idx)
	)

	_hair_mode_opt = _add_option_row(parent, "Modo Pelo:", [
		"0: Sólido Cel", "1: Bicolor Trigger", "2: Puntas Dip-Dye", "3: Angel Ring"
	])
	_hair_mode_opt.item_selected.connect(func(idx: int) -> void:
		if not _suppress_signals:
			hair_style_mode_changed.emit(idx)
	)

	_recolor_opt = _add_option_row(parent, "Recolor:", [
		"0: Multiplicativo", "1: Gradiente 3-Tonos", "2: Contraste Perceptual", "3: Overlay/HardLight", "4: Cel-Ramp 3-Bandas"
	])
	_recolor_opt.select(1)
	_recolor_opt.item_selected.connect(func(idx: int) -> void:
		if not _suppress_signals:
			recolor_method_changed.emit(idx)
	)

	var save_row := HBoxContainer.new()
	parent.add_child(save_row)
	_save_name_edit = LineEdit.new()
	_save_name_edit.placeholder_text = "ej: 09_valentina_neon"
	_save_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_row.add_child(_save_name_edit)
	var save_btn := Button.new()
	save_btn.text = "Guardar .tres"
	save_btn.pressed.connect(func() -> void:
		save_preset_requested.emit(_save_name_edit.text.strip_edges())
	)
	save_row.add_child(save_btn)

	var reset_btn := Button.new()
	reset_btn.text = "Reset a 00_original"
	reset_btn.pressed.connect(func() -> void: reset_style_requested.emit())
	parent.add_child(reset_btn)

	_save_feedback_lbl = Label.new()
	_save_feedback_lbl.text = ""
	parent.add_child(_save_feedback_lbl)


func _build_lighting_section(parent: VBoxContainer) -> void:
	_add_header(parent, "3. ILUMINACIÓN 2.5D Y LUZ GIRATORIA")

	var row := HBoxContainer.new()
	parent.add_child(row)
	var nd_chk := _add_check_inline(row, "use_normal_depth", "Normal/Depth 2.5D", true)
	nd_chk.toggled.connect(func(_on: bool) -> void:
		if not _suppress_signals:
			light_options_changed.emit()
	)
	_add_check_inline(row, "auto_rotate_light", "Rotar Luz Auto", false)

	_add_slider(parent, "light_angle_deg", "Ángulo Luz (°)", 0.0, 360.0, 1.0, 234.0, func(_v: float) -> void:
		light_options_changed.emit()
	)
	_add_slider(parent, "light_z_tilt", "Elevación Luz Z", 0.10, 2.0, 0.02, 0.58, func(v: float) -> void:
		shader_param_changed.emit("light_z_tilt", v)
	)
	_add_slider(parent, "normal_cel_influence", "Influencia Cel Normal", 0.0, 1.0, 0.02, 0.52, func(v: float) -> void:
		shader_param_changed.emit("normal_cel_influence", v)
	)
	_add_slider(parent, "normal_rim_strength", "Rim Normal 2.5D", 0.0, 2.5, 0.05, 0.45, func(_v: float) -> void:
		light_options_changed.emit()
	)
	_add_slider(parent, "crt_hdr_boost", "CRT / HDR Boost", 1.0, 3.0, 0.05, 1.0, func(_v: float) -> void:
		light_options_changed.emit()
	)


func _build_stylize_section(parent: VBoxContainer) -> void:
	_add_header(parent, "4. ESTILIZADO AGRESIVO (CEL / RIM / TINTA)")

	_pipeline_opt = _add_option_row(parent, "Pipeline:", [
		"0: Original", "1: Trigger Cel", "2: Skullgirls", "3: Guilty Gear Rim",
		"4: Spider-Verse", "5: Persona 5 Noir", "6: Edgerunners Dual-Rim",
		"7: Kill la Kill Hatch", "8: Arcane Metal"
	])
	_pipeline_opt.item_selected.connect(func(idx: int) -> void:
		if not _suppress_signals:
			shader_param_changed.emit("pipeline_style_mode", idx)
	)

	_add_slider(parent, "cel_step_strength", "Cel-Step Strength", 0.0, 1.0, 0.02, 0.0, func(v: float) -> void:
		shader_param_changed.emit("cel_step_strength", v)
	)
	_add_slider(parent, "ink_boost", "Ink Boost (Tinta)", 0.0, 1.0, 0.02, 0.10, func(v: float) -> void:
		shader_param_changed.emit("ink_boost", v)
	)
	_add_slider(parent, "noir_shadow_crush", "Noir Shadow Crush", 0.0, 1.0, 0.02, 0.0, func(v: float) -> void:
		shader_param_changed.emit("noir_shadow_crush", v)
	)
	_add_slider(parent, "noir_shadow_threshold", "Noir Threshold", 0.10, 0.45, 0.01, 0.24, func(v: float) -> void:
		shader_param_changed.emit("noir_shadow_threshold", v)
	)
	_add_slider(parent, "metal_sheen_strength", "Metal Sheen", 0.0, 1.5, 0.05, 0.0, func(v: float) -> void:
		shader_param_changed.emit("metal_sheen_strength", v)
	)
	_add_slider(parent, "rim_light_strength", "Rim Light Strength", 0.0, 1.5, 0.05, 0.12, func(v: float) -> void:
		shader_param_changed.emit("rim_light_strength", v)
	)
	_add_slider(parent, "rim_width_px", "Rim Width (px)", 1.0, 14.0, 0.25, 4.5, func(v: float) -> void:
		shader_param_changed.emit("rim_width_px", v)
	)
	_add_slider(parent, "dual_rim_strength", "Dual Rim Strength", 0.0, 1.5, 0.05, 0.0, func(v: float) -> void:
		shader_param_changed.emit("dual_rim_strength", v)
	)
	_add_slider(parent, "glow_intensity", "Glow Emisivo", 0.0, 3.0, 0.05, 1.05, func(v: float) -> void:
		shader_param_changed.emit("glow_intensity", v)
	)


func _build_halftone_section(parent: VBoxContainer) -> void:
	_add_header(parent, "5. SEMITONO / TRAMA (HALFTONE / HATCH)")

	var ht_chk := _add_check(parent, "enable_halftone", "Activar Halftone / Trama", false)
	ht_chk.toggled.connect(func(on: bool) -> void:
		if not _suppress_signals:
			shader_param_changed.emit("enable_halftone", on)
	)

	_halftone_pat_opt = _add_option_row(parent, "Patrón:", [
		"0: Puntos Clásicos", "1: Líneas Manga", "2: Crosshatch", "3: Diamantes", "4: Ben-Day", "5: Hex"
	])
	_halftone_pat_opt.item_selected.connect(func(idx: int) -> void:
		if not _suppress_signals:
			shader_param_changed.emit("halftone_pattern_type", idx)
	)

	_halftone_zone_opt = _add_option_row(parent, "Zona:", [
		"0: Sombras", "1: Medios", "2: Toda Silueta", "3: Bordes"
	])
	_halftone_zone_opt.item_selected.connect(func(idx: int) -> void:
		if not _suppress_signals:
			shader_param_changed.emit("halftone_zone_mode", idx)
	)

	_add_slider(parent, "halftone_strength", "Intensidad Trama", 0.0, 1.0, 0.02, 0.0, func(v: float) -> void:
		shader_param_changed.emit("halftone_strength", v)
	)
	_add_slider(parent, "halftone_scale", "Escala Trama", 40.0, 320.0, 2.0, 165.0, func(v: float) -> void:
		shader_param_changed.emit("halftone_scale", v)
	)
	_add_slider(parent, "halftone_angle_deg", "Ángulo Trama (°)", 0.0, 180.0, 1.0, 45.0, func(v: float) -> void:
		shader_param_changed.emit("halftone_angle_deg", v)
	)
	_add_slider(parent, "halftone_threshold", "Umbral Trama", 0.15, 0.85, 0.01, 0.38, func(v: float) -> void:
		shader_param_changed.emit("halftone_threshold", v)
	)


func _build_color_outline_section(parent: VBoxContainer) -> void:
	_add_header(parent, "6. CURVA DE COLOR Y OUTLINE")

	_add_slider(parent, "recolor_contrast", "Contraste", 0.4, 2.2, 0.02, 1.0, func(v: float) -> void:
		shader_param_changed.emit("recolor_contrast", v)
	)
	_add_slider(parent, "recolor_saturation", "Saturación", 0.0, 2.0, 0.02, 1.0, func(v: float) -> void:
		shader_param_changed.emit("recolor_saturation", v)
	)
	_add_slider(parent, "recolor_highlight", "Brillo / Highlight", 0.0, 2.0, 0.02, 1.0, func(v: float) -> void:
		shader_param_changed.emit("recolor_highlight", v)
	)
	_add_slider(parent, "stocking_denier", "Denier Medias", 0.0, 1.0, 0.02, 0.35, func(v: float) -> void:
		shader_param_changed.emit("stocking_denier", v)
	)

	var out_row := HBoxContainer.new()
	parent.add_child(out_row)
	var in_chk := _add_check_inline(out_row, "inward_outline", "Outline Interno", true)
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


func _build_backdrop_debug_section(parent: VBoxContainer) -> void:
	_add_header(parent, "7. FONDOS Y DEPURACIÓN (RAYOS-X)")

	var bg_opt := _add_option_row(parent, "Fondo:", [
		"0: Oscuro Neutro", "1: Claro Estudio", "2: Grilla Damero", "3: Espacio / Nebulosa"
	])
	bg_opt.item_selected.connect(func(idx: int) -> void: backdrop_changed.emit(idx))

	var dbg_opt := _add_option_row(parent, "Canal:", [
		"0: Render Final", "1: Clown-Pass ID", "2: Luminancia", "3: Solo Tinta",
		"4: Normales 2.5D", "5: Profundidad 2.5D"
	])
	dbg_opt.item_selected.connect(func(idx: int) -> void: debug_view_changed.emit(idx))

	var pinch_chk := _add_check(parent, "debug_pinch", "Overlay Stocking Pinch", false)
	pinch_chk.toggled.connect(func(on: bool) -> void: pinch_debug_toggled.emit(on))


func _add_header(parent: VBoxContainer, title: String) -> void:
	var sep := HSeparator.new()
	parent.add_child(sep)
	var lbl := Label.new()
	lbl.text = title
	lbl.modulate = Color(0.68, 0.85, 1.0)
	parent.add_child(lbl)


func _add_option_row(parent: VBoxContainer, label_txt: String, items: Array[String]) -> OptionButton:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var lbl := Label.new()
	lbl.text = label_txt
	lbl.custom_minimum_size = Vector2(88.0, 0.0)
	row.add_child(lbl)
	var opt := OptionButton.new()
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	vb.add_theme_constant_override("separation", 1)
	parent.add_child(vb)

	var top := HBoxContainer.new()
	vb.add_child(top)
	var lbl := Label.new()
	lbl.text = title
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(lbl)
	var val_lbl := Label.new()
	val_lbl.text = "%.2f" % init_v
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(val_lbl)

	var sl := HSlider.new()
	sl.min_value = min_v
	sl.max_value = max_v
	sl.step = step_v
	sl.value = init_v
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

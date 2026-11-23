class_name ValentinaBannerLabHUD
extends RefCounted
## Constructor de HUD interactivo para ValentinaBannerLab (Live Splash Art 2.5D).

const ConfigScript = preload("res://data/pilots/schemas/pilot_live_banner_config.gd")
const PANEL_WIDTH: float = 330.0


static func build_hud(
	parent: Node,
	config: ConfigScript,
	skin_labels: Array[String],
	callbacks: Dictionary
) -> Dictionary:
	var layer := CanvasLayer.new()
	layer.name = "BannerLabHUDLayer"
	layer.layer = 20
	parent.add_child(layer)

	var panel := PanelContainer.new()
	panel.name = "ControlPanel"
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.anchor_right = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 10.0
	panel.offset_top = 10.0
	panel.offset_right = 10.0 + PANEL_WIDTH
	panel.offset_bottom = -10.0

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.11, 0.86)
	style.border_color = Color(0.92, 0.28, 0.48, 0.55)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(vbox)

	var title := Label.new()
	title.text = "BANNER LAB — LIVE SPLASH 2.5D"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(1.0, 0.42, 0.58, 1.0))
	vbox.add_child(title)

	var hint := Label.new()
	hint.text = "Enter/E: Elegir Piloto · Space: Hover · B: Parpadeo"
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.74, 0.80, 0.90, 0.85))
	vbox.add_child(hint)

	var select_row := HBoxContainer.new()
	select_row.add_theme_constant_override("separation", 6)
	var select_btn := Button.new()
	select_btn.text = "ELEGIR PILOTO [Enter]"
	select_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	select_btn.pressed.connect(func() -> void:
		var cb: Callable = callbacks.get("on_select_pilot", Callable())
		if cb.is_valid():
			cb.call()
	)
	select_row.add_child(select_btn)

	var reset_btn := Button.new()
	reset_btn.text = "Reset"
	reset_btn.pressed.connect(func() -> void:
		var cb: Callable = callbacks.get("on_reset_select", Callable())
		if cb.is_valid():
			cb.call()
	)
	select_row.add_child(reset_btn)
	vbox.add_child(select_row)

	vbox.add_child(HSeparator.new())

	# --- Acciones rápidas & Inspección ---
	_add_header(vbox, "Inspección y Skins")

	var debug_opt := OptionButton.new()
	debug_opt.add_item("Vista: Final Live 2.5D", 0)
	debug_opt.add_item("Debug: Motion Mask (RGB)", 1)
	debug_opt.add_item("Debug: FX Mask (RGB)", 2)
	debug_opt.add_item("Debug: Depth Map (Gris)", 3)
	debug_opt.add_item("Debug: Normal Map (RGB)", 4)
	debug_opt.add_item("Debug: Ink SDF (Tinta)", 5)
	debug_opt.add_item("Debug: ILM Map (Metal/AO/Satin)", 6)
	debug_opt.select(0)
	debug_opt.item_selected.connect(func(idx: int) -> void:
		var cb: Callable = callbacks.get("on_debug_view_selected", Callable())
		if cb.is_valid():
			cb.call(idx)
	)
	vbox.add_child(debug_opt)

	var skin_opt := OptionButton.new()
	for i: int in range(skin_labels.size()):
		skin_opt.add_item(skin_labels[i], i)
	if not skin_labels.is_empty():
		skin_opt.select(0)
	skin_opt.item_selected.connect(func(idx: int) -> void:
		var cb: Callable = callbacks.get("on_skin_selected", Callable())
		if cb.is_valid():
			cb.call(idx)
	)
	vbox.add_child(skin_opt)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 6)
	var blink_btn := Button.new()
	blink_btn.text = "Parpadear [B]"
	blink_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	blink_btn.pressed.connect(func() -> void:
		var cb: Callable = callbacks.get("on_trigger_blink", Callable())
		if cb.is_valid():
			cb.call()
	)
	btn_row.add_child(blink_btn)

	var impulse_btn := Button.new()
	impulse_btn.text = "Impulso Hover"
	impulse_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	impulse_btn.pressed.connect(func() -> void:
		var cb: Callable = callbacks.get("on_trigger_impulse", Callable())
		if cb.is_valid():
			cb.call()
	)
	btn_row.add_child(impulse_btn)
	vbox.add_child(btn_row)

	vbox.add_child(HSeparator.new())

	# --- Sliders de Animación Orgánica ---
	_add_header(vbox, "Movimiento Orgánico")
	var sliders: Dictionary = {}
	sliders["breath_expand_amp"] = _add_slider(vbox, "Respiración (Expansión)", 0.0, 0.05, 0.001, config.breath_expand_amp, func(v: float) -> void:
		config.breath_expand_amp = v
	)
	sliders["breath_lift_px"] = _add_slider(vbox, "Respiración (Elevación px)", 0.0, 12.0, 0.2, config.breath_lift_px, func(v: float) -> void:
		config.breath_lift_px = v
	)
	sliders["breath_speed"] = _add_slider(vbox, "Ritmo Respiración", 0.3, 4.0, 0.05, config.breath_speed, func(v: float) -> void:
		config.breath_speed = v
	)
	sliders["hover_jiggle_amp"] = _add_slider(vbox, "Rebote / Jiggle Hover", 0.0, 0.04, 0.001, config.hover_jiggle_amp, func(v: float) -> void:
		config.hover_jiggle_amp = v
	)
	sliders["hair_sway_amp_px"] = _add_slider(vbox, "Cabello Zero-G (px)", 0.0, 20.0, 0.25, config.hair_sway_amp_px, func(v: float) -> void:
		config.hair_sway_amp_px = v
	)
	sliders["hair_sway_speed"] = _add_slider(vbox, "Velocidad Cabello", 0.3, 5.0, 0.05, config.hair_sway_speed, func(v: float) -> void:
		config.hair_sway_speed = v
	)
	sliders["body_sway_amp_px"] = _add_slider(vbox, "Balanceo Corporal (px)", 0.0, 12.0, 0.2, config.body_sway_amp_px, func(v: float) -> void:
		config.body_sway_amp_px = v
	)
	sliders["arm_persp_scale_amp"] = _add_slider(vbox, "Brazo 2.5D (Escala Persp.)", 0.0, 0.12, 0.002, config.arm_persp_scale_amp, func(v: float) -> void:
		config.arm_persp_scale_amp = v
	)
	sliders["arm_sway_x_px"] = _add_slider(vbox, "Brazo 2.5D (Desplaz. X)", 0.0, 18.0, 0.5, config.arm_sway_x_px, func(v: float) -> void:
		config.arm_sway_x_px = v
	)
	sliders["arm_depth_shade_amp"] = _add_slider(vbox, "Brazo 2.5D (Luz/Sombra)", 0.0, 0.35, 0.01, config.arm_depth_shade_amp, func(v: float) -> void:
		config.arm_depth_shade_amp = v
	)
	sliders["wings_scale"] = _add_slider(vbox, "Escala Alas Desplegadas", 0.20, 0.85, 0.01, config.wings_scale, func(v: float) -> void:
		config.wings_scale = v
	)

	vbox.add_child(HSeparator.new())

	# --- Parallax 2.5D y Luz ---
	_add_header(vbox, "Profundidad 2.5D e Iluminación")
	sliders["mouse_parallax_strength"] = _add_slider(vbox, "Profundidad 2.5D (Idle)", 0.0, 0.06, 0.001, config.mouse_parallax_strength, func(v: float) -> void:
		config.mouse_parallax_strength = v
	)
	sliders["mouse_tilt_deg"] = _add_slider(vbox, "Balanceo Idle (°)", 0.0, 6.0, 0.1, config.mouse_tilt_deg, func(v: float) -> void:
		config.mouse_tilt_deg = v
	)
	sliders["rim_light_strength"] = _add_slider(vbox, "Rim Light Dinámico", 0.0, 1.4, 0.02, config.rim_light_strength, func(v: float) -> void:
		config.rim_light_strength = v
	)
	sliders["emissive_boost"] = _add_slider(vbox, "Brillo Emisivos / HUD", 0.0, 1.6, 0.02, config.emissive_boost, func(v: float) -> void:
		config.emissive_boost = v
	)
	sliders["eye_glow_boost"] = _add_slider(vbox, "Brillo Ojos", 0.0, 1.2, 0.02, config.eye_glow_boost, func(v: float) -> void:
		config.eye_glow_boost = v
	)

	vbox.add_child(HSeparator.new())

	# --- Shader Combate 2.5D (Cel-Shading + Ink SDF) ---
	_add_header(vbox, "Shader Combate (Cel + Ink SDF)")
	var shader_toggles := HBoxContainer.new()
	shader_toggles.add_theme_constant_override("separation", 8)
	var cel_chk := CheckBox.new()
	cel_chk.text = "Cel 2.5D"
	cel_chk.button_pressed = config.cel_shading_enabled
	cel_chk.toggled.connect(func(v: bool) -> void:
		config.cel_shading_enabled = v
	)
	shader_toggles.add_child(cel_chk)

	var ink_chk := CheckBox.new()
	ink_chk.text = "Ink SDF"
	ink_chk.button_pressed = config.ink_sdf_enabled
	ink_chk.toggled.connect(func(v: bool) -> void:
		config.ink_sdf_enabled = v
	)
	shader_toggles.add_child(ink_chk)
	vbox.add_child(shader_toggles)

	sliders["cel_strength"] = _add_slider(vbox, "Fuerza Cel-Shading", 0.0, 1.0, 0.02, config.cel_strength, func(v: float) -> void:
		config.cel_strength = v
	)
	sliders["cel_light_angle_deg"] = _add_slider(vbox, "Ángulo Luz (°)", -180.0, 180.0, 2.0, config.cel_light_angle_deg, func(v: float) -> void:
		config.cel_light_angle_deg = v
	)
	sliders["cel_specular_strength"] = _add_slider(vbox, "Especular Armadura", 0.0, 1.2, 0.02, config.cel_specular_strength, func(v: float) -> void:
		config.cel_specular_strength = v
	)
	sliders["ink_strength"] = _add_slider(vbox, "Fuerza Tinta SDF", 0.0, 1.0, 0.02, config.ink_strength, func(v: float) -> void:
		config.ink_strength = v
	)
	sliders["ink_width_bias"] = _add_slider(vbox, "Grosor Tinta SDF", -0.10, 0.12, 0.005, config.ink_width_bias, func(v: float) -> void:
		config.ink_width_bias = v
	)

	vbox.add_child(HSeparator.new())

	# --- Persistencia ---
	var save_row := HBoxContainer.new()
	save_row.add_theme_constant_override("separation", 6)
	var save_btn := Button.new()
	save_btn.text = "Guardar .tres"
	save_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_btn.pressed.connect(func() -> void:
		var cb: Callable = callbacks.get("on_save_config", Callable())
		if cb.is_valid():
			cb.call()
	)
	save_row.add_child(save_btn)

	var reload_btn := Button.new()
	reload_btn.text = "Recargar"
	reload_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reload_btn.pressed.connect(func() -> void:
		var cb: Callable = callbacks.get("on_reload_config", Callable())
		if cb.is_valid():
			cb.call()
	)
	save_row.add_child(reload_btn)
	vbox.add_child(save_row)

	var status_label := Label.new()
	status_label.text = ""
	status_label.add_theme_font_size_override("font_size", 11)
	status_label.add_theme_color_override("font_color", Color(0.55, 0.95, 0.68, 1.0))
	vbox.add_child(status_label)

	return {
		"layer": layer,
		"panel": panel,
		"status_label": status_label,
		"sliders": sliders,
	}


static func sync_sliders(hud_refs: Dictionary, config: ConfigScript) -> void:
	if config == null or not hud_refs.has("sliders"):
		return
	var sliders: Dictionary = hud_refs["sliders"] as Dictionary
	_set_val(sliders, "breath_expand_amp", config.breath_expand_amp)
	_set_val(sliders, "breath_lift_px", config.breath_lift_px)
	_set_val(sliders, "breath_speed", config.breath_speed)
	_set_val(sliders, "hover_jiggle_amp", config.hover_jiggle_amp)
	_set_val(sliders, "hair_sway_amp_px", config.hair_sway_amp_px)
	_set_val(sliders, "hair_sway_speed", config.hair_sway_speed)
	_set_val(sliders, "body_sway_amp_px", config.body_sway_amp_px)
	_set_val(sliders, "mouse_parallax_strength", config.mouse_parallax_strength)
	_set_val(sliders, "mouse_tilt_deg", config.mouse_tilt_deg)
	_set_val(sliders, "rim_light_strength", config.rim_light_strength)
	_set_val(sliders, "emissive_boost", config.emissive_boost)
	_set_val(sliders, "eye_glow_boost", config.eye_glow_boost)


static func _set_val(sliders: Dictionary, key: String, val: float) -> void:
	if not sliders.has(key):
		return
	var pair: Dictionary = sliders[key] as Dictionary
	var s: HSlider = pair.get("slider", null) as HSlider
	var l: Label = pair.get("val_label", null) as Label
	if is_instance_valid(s):
		s.set_value_no_signal(val)
	if is_instance_valid(l):
		l.text = "%.3f" % val if absf(val) < 0.1 else "%.2f" % val


static func _add_header(parent: VBoxContainer, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text.to_upper()
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.92, 0.52, 0.66, 0.95))
	parent.add_child(lbl)


static func _add_slider(
	parent: VBoxContainer,
	label_text: String,
	min_v: float,
	max_v: float,
	step_v: float,
	init_v: float,
	on_changed: Callable
) -> Dictionary:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 1)

	var top := HBoxContainer.new()
	var lbl := Label.new()
	lbl.text = label_text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 11)
	top.add_child(lbl)

	var val_lbl := Label.new()
	val_lbl.text = "%.3f" % init_v if absf(init_v) < 0.1 else "%.2f" % init_v
	val_lbl.add_theme_font_size_override("font_size", 11)
	val_lbl.add_theme_color_override("font_color", Color(0.65, 0.92, 1.0, 1.0))
	top.add_child(val_lbl)
	row.add_child(top)

	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step_v
	slider.value = init_v
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(func(v: float) -> void:
		val_lbl.text = "%.3f" % v if absf(v) < 0.1 else "%.2f" % v
		if on_changed.is_valid():
			on_changed.call(v)
	)
	row.add_child(slider)
	parent.add_child(row)

	return {"slider": slider, "val_label": val_lbl}

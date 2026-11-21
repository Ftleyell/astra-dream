class_name ValentinaVFXLabHUD
extends RefCounted
## Panel lateral interactivo para calibrar en vivo PilotPropulsionVFXConfig (.tres)
## y probar modos de vuelo/ráfaga en la escena aislada ValentinaVFXLab.


const BasePropConfigScript = preload("res://sandbox/pilot_rig_lab/data/pilot_base_propulsion_config.gd")


static func build_hud(
	parent_node: Node,
	config: PilotPropulsionVFXConfig,
	callbacks: Dictionary,
	base_config: BasePropConfigScript = null
) -> Dictionary:
	var refs: Dictionary = {}

	var layer := CanvasLayer.new()
	layer.name = "VFXLabHUDLayer"
	layer.layer = 20
	parent_node.add_child(layer)
	refs["layer"] = layer

	var panel := PanelContainer.new()
	panel.name = "VFXControlPanel"
	panel.position = Vector2(14.0, 14.0)
	panel.custom_minimum_size = Vector2(310.0, 0.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.11, 0.86)
	style.border_color = Color(0.28, 0.56, 0.88, 0.55)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(290.0, 620.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(vbox)

	var title := Label.new()
	title.text = "VALENTINA VFX LAB — SANDEVISTAN"
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color("#00F0FF"))
	vbox.add_child(title)

	var telemetry := Label.new()
	telemetry.name = "TelemetryLabel"
	telemetry.text = "Ghosts: 0 | Seq: 0.00 | BASE"
	telemetry.add_theme_font_size_override("font_size", 11)
	telemetry.add_theme_color_override("font_color", Color(0.84, 0.90, 1.0, 0.92))
	vbox.add_child(telemetry)
	refs["telemetry_label"] = telemetry

	var hint := Label.new()
	hint.text = "WASD: Volar | Mouse: Apuntar | Espacio: Ráfaga | B: Freno | Rueda: Zoom"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Color(0.65, 0.72, 0.85, 0.85))
	vbox.add_child(hint)

	vbox.add_child(HSeparator.new())

	# Selector de modo de vuelo
	var mode_row := HBoxContainer.new()
	var mode_lbl := Label.new()
	mode_lbl.text = "Modo:"
	mode_lbl.add_theme_font_size_override("font_size", 11)
	mode_row.add_child(mode_lbl)

	var mode_opt := OptionButton.new()
	mode_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_opt.add_item("Auto: Curva S + Ráfagas", 0)
	mode_opt.add_item("Auto: Órbita Kiting", 1)
	mode_opt.add_item("Auto: Ráfaga Sandevistan Loop", 2)
	mode_opt.add_item("Manual (WASD + Mouse)", 3)
	mode_opt.select(0)
	var on_mode: Callable = callbacks.get("on_mode_selected", Callable()) as Callable
	if on_mode.is_valid():
		mode_opt.item_selected.connect(on_mode)
	mode_row.add_child(mode_opt)
	vbox.add_child(mode_row)
	refs["mode_opt"] = mode_opt

	# Acciones rápidas
	var act_row := HBoxContainer.new()
	act_row.add_theme_constant_override("separation", 6)

	var burst_btn := Button.new()
	burst_btn.text = "⚡ Ráfaga [Espacio]"
	burst_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var on_burst: Callable = callbacks.get("on_trigger_burst", Callable()) as Callable
	if on_burst.is_valid():
		burst_btn.pressed.connect(on_burst)
	act_row.add_child(burst_btn)

	var clear_btn := Button.new()
	clear_btn.text = "Limpiar"
	var on_clear: Callable = callbacks.get("on_clear_ghosts", Callable()) as Callable
	if on_clear.is_valid():
		clear_btn.pressed.connect(on_clear)
	act_row.add_child(clear_btn)
	vbox.add_child(act_row)

	# Toggles de entorno y feedback
	var chk_orbs := CheckBox.new()
	chk_orbs.text = "Balas Danmaku (Prueba de Legibilidad)"
	chk_orbs.button_pressed = true
	var on_orbs: Callable = callbacks.get("on_orbs_toggled", Callable()) as Callable
	if on_orbs.is_valid():
		chk_orbs.toggled.connect(on_orbs)
	vbox.add_child(chk_orbs)

	var chk_slowmo := CheckBox.new()
	chk_slowmo.text = "Asimetría Temporal en Ráfaga (Slow-Mo)"
	chk_slowmo.button_pressed = true
	var on_slowmo: Callable = callbacks.get("on_slowmo_toggled", Callable()) as Callable
	if on_slowmo.is_valid():
		chk_slowmo.toggled.connect(on_slowmo)
	vbox.add_child(chk_slowmo)

	var chk_aberr := CheckBox.new()
	chk_aberr.text = "Aberración Cromática en Bordes"
	chk_aberr.button_pressed = config.aberration_enabled if config != null else true
	chk_aberr.toggled.connect(func(v: bool) -> void:
		if config != null:
			config.aberration_enabled = v
	)
	vbox.add_child(chk_aberr)

	var chk_sandev := CheckBox.new()
	chk_sandev.text = "Power-Up Sandevistan Activo"
	chk_sandev.button_pressed = true
	var on_sandev: Callable = callbacks.get("on_sandevistan_toggled", Callable()) as Callable
	if on_sandev.is_valid():
		chk_sandev.toggled.connect(on_sandev)
	vbox.add_child(chk_sandev)

	var slider_bindings: Array[Dictionary] = []

	if base_config != null:
		vbox.add_child(HSeparator.new())
		var base_title := Label.new()
		base_title.text = "PROPULSIÓN BASE (ALAS + RIBBONS + POLVO)"
		base_title.add_theme_font_size_override("font_size", 11)
		base_title.add_theme_color_override("font_color", Color("#FF5C7C"))
		vbox.add_child(base_title)

		var chk_wings := CheckBox.new()
		chk_wings.text = "Capa 1: Alas Serafín Astral"
		chk_wings.button_pressed = base_config.wings_enabled
		chk_wings.toggled.connect(func(v: bool) -> void: base_config.wings_enabled = v)
		vbox.add_child(chk_wings)

		var chk_ribbons := CheckBox.new()
		chk_ribbons.text = "Capa 2: Slipstream Ribbons"
		chk_ribbons.button_pressed = base_config.ribbons_enabled
		chk_ribbons.toggled.connect(func(v: bool) -> void: base_config.ribbons_enabled = v)
		vbox.add_child(chk_ribbons)

		var chk_dust := CheckBox.new()
		chk_dust.text = "Capa 3: Polvo Estelar"
		chk_dust.button_pressed = base_config.stardust_enabled
		chk_dust.toggled.connect(func(v: bool) -> void: base_config.stardust_enabled = v)
		vbox.add_child(chk_dust)

		_add_slider(vbox, slider_bindings, "Escala Alas", 0.60, 2.60, 0.05, base_config.wing_scale,
			func(v: float) -> void: base_config.wing_scale = v)
		_add_slider(vbox, slider_bindings, "Separación Flotante", 20.0, 120.0, 1.0, base_config.wing_root_spread_x_du,
			func(v: float) -> void: base_config.wing_root_spread_x_du = v)
		_add_slider(vbox, slider_bindings, "Deslizamiento Empuje", 0.0, 50.0, 1.0, base_config.thrust_linear_slide_du,
			func(v: float) -> void: base_config.thrust_linear_slide_du = v)
		_add_slider(vbox, slider_bindings, "Abanico Cuchillas (°)", 0.0, 20.0, 0.5, base_config.blade_fan_spread_deg,
			func(v: float) -> void: base_config.blade_fan_spread_deg = v)
		_add_slider(vbox, slider_bindings, "Brillo Rojo Empuje", 1.0, 5.0, 0.1, base_config.thrust_emissive_boost,
			func(v: float) -> void: base_config.thrust_emissive_boost = v)
		_add_slider(vbox, slider_bindings, "Glow Rojo HDR", 0.2, 3.5, 0.05, base_config.red_glow_thrust_intensity,
			func(v: float) -> void: base_config.red_glow_thrust_intensity = v)
		_add_slider(vbox, slider_bindings, "Rim Carmesí Empuje", 0.0, 2.5, 0.05, base_config.effort_rim_strength,
			func(v: float) -> void: base_config.effort_rim_strength = v)
		_add_slider(vbox, slider_bindings, "Vibración Empuje", 0.0, 4.0, 0.1, base_config.effort_vibration_amp_du,
			func(v: float) -> void: base_config.effort_vibration_amp_du = v)
		_add_slider(vbox, slider_bindings, "Ancho Cintas Rojas", 1.5, 10.0, 0.2, base_config.ribbon_width_px,
			func(v: float) -> void: base_config.ribbon_width_px = v)

	vbox.add_child(HSeparator.new())

	var sliders_title := Label.new()
	sliders_title.text = "PARÁMETROS SANDEVISTAN (.tres)"
	sliders_title.add_theme_font_size_override("font_size", 11)
	sliders_title.add_theme_color_override("font_color", Color("#E6B8FF"))
	vbox.add_child(sliders_title)
	_add_slider(vbox, slider_bindings, "Dist. Base (px)", 10.0, 80.0, 1.0, config.base_spawn_distance_px,
		func(v: float) -> void: config.base_spawn_distance_px = v)
	_add_slider(vbox, slider_bindings, "Dist. Ráfaga (px)", 8.0, 50.0, 1.0, config.burst_spawn_distance_px,
		func(v: float) -> void: config.burst_spawn_distance_px = v)
	_add_slider(vbox, slider_bindings, "Max Copias Base", 1.0, 12.0, 1.0, float(config.base_max_ghosts),
		func(v: float) -> void: config.base_max_ghosts = int(roundf(v)))
	_add_slider(vbox, slider_bindings, "Max Copias Ráfaga", 4.0, 16.0, 1.0, float(config.burst_max_ghosts),
		func(v: float) -> void: config.burst_max_ghosts = int(roundf(v)))
	_add_slider(vbox, slider_bindings, "Vida Base (s)", 0.10, 0.80, 0.02, config.base_lifetime_sec,
		func(v: float) -> void: config.base_lifetime_sec = v)
	_add_slider(vbox, slider_bindings, "Vida Ráfaga (s)", 0.15, 1.00, 0.02, config.burst_lifetime_sec,
		func(v: float) -> void: config.burst_lifetime_sec = v)
	_add_slider(vbox, slider_bindings, "Grosor Outline (px)", 0.5, 6.0, 0.1, config.outline_width_px,
		func(v: float) -> void: config.outline_width_px = v)
	_add_slider(vbox, slider_bindings, "Oscurecer Outline", 0.05, 0.80, 0.02, config.outline_darken_amount,
		func(v: float) -> void: config.outline_darken_amount = v)
	_add_slider(vbox, slider_bindings, "Tinta Interna (Ink)", 0.0, 1.0, 0.05, config.internal_ink_strength,
		func(v: float) -> void: config.internal_ink_strength = v)
	_add_slider(vbox, slider_bindings, "Opacidad Relleno", 0.05, 1.0, 0.02, config.fill_opacity_max,
		func(v: float) -> void: config.fill_opacity_max = v)
	_add_slider(vbox, slider_bindings, "Opacidad Outline", 0.10, 1.0, 0.02, config.outline_opacity_max,
		func(v: float) -> void: config.outline_opacity_max = v)
	_add_slider(vbox, slider_bindings, "Boost Amatista", 1.0, 2.4, 0.05, config.amethyst_emissive_boost,
		func(v: float) -> void: config.amethyst_emissive_boost = v)
	_add_slider(vbox, slider_bindings, "Paso Color / Copia", 0.05, 0.45, 0.01, config.color_step_per_ghost,
		func(v: float) -> void: config.color_step_per_ghost = v)
	refs["sliders"] = slider_bindings

	vbox.add_child(HSeparator.new())

	# Guardar / Recargar .tres
	var io_row := HBoxContainer.new()
	io_row.add_theme_constant_override("separation", 6)

	var save_btn := Button.new()
	save_btn.text = "Guardar .tres"
	save_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var on_save: Callable = callbacks.get("on_save_config", Callable()) as Callable
	if on_save.is_valid():
		save_btn.pressed.connect(on_save)
	io_row.add_child(save_btn)

	var reload_btn := Button.new()
	reload_btn.text = "Recargar"
	var on_reload: Callable = callbacks.get("on_reload_config", Callable()) as Callable
	if on_reload.is_valid():
		reload_btn.pressed.connect(on_reload)
	io_row.add_child(reload_btn)
	vbox.add_child(io_row)

	var status_lbl := Label.new()
	status_lbl.text = ""
	status_lbl.add_theme_font_size_override("font_size", 10)
	status_lbl.add_theme_color_override("font_color", Color("#00E5A8"))
	vbox.add_child(status_lbl)
	refs["status_label"] = status_lbl

	return refs


static func _add_slider(
	parent_vbox: VBoxContainer,
	bindings: Array[Dictionary],
	label_text: String,
	min_v: float,
	max_v: float,
	step_v: float,
	init_v: float,
	setter: Callable
) -> void:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 1)

	var head := HBoxContainer.new()
	var lbl := Label.new()
	lbl.text = label_text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 10)
	head.add_child(lbl)

	var val_lbl := Label.new()
	val_lbl.text = "%.2f" % init_v if step_v < 1.0 else "%d" % int(roundf(init_v))
	val_lbl.add_theme_font_size_override("font_size", 10)
	val_lbl.add_theme_color_override("font_color", Color("#00F0FF"))
	head.add_child(val_lbl)
	row.add_child(head)

	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step_v
	slider.value = init_v
	slider.value_changed.connect(func(v: float) -> void:
		setter.call(v)
		val_lbl.text = "%.2f" % v if step_v < 1.0 else "%d" % int(roundf(v))
	)
	row.add_child(slider)
	parent_vbox.add_child(row)

	bindings.append({
		"slider": slider,
		"val_lbl": val_lbl,
		"step": step_v,
	})

class_name Valentina3DLabHUD
extends RefCounted
## Constructor de HUD interactivo para Valentina3DLab (Alas 3D Cel-Shaded ArcSys).
## Expone los 6 modos de animación 3D, turntable 360°, comparativa A/B con alas 2D,
## sincronización de las 10 skins, calibración en vivo y guardado directo en .tres.

const ConfigScript = preload("res://data/pilots/schemas/pilot_wings_3d_config.gd")
const WingsCtrlScript = preload("res://scenes/pilots/vfx/astral_wings_3d_controller.gd")

const PANEL_WIDTH: float = 340.0
const VIEW_KEYS: Array[String] = ["s", "se", "e", "ne", "n", "nw", "w", "sw"]


static func build_hud(
	parent: Node,
	config: ConfigScript,
	callbacks: Dictionary,
	skin_choices: Array[PilotSkinPreset] = []
) -> Dictionary:
	var refs: Dictionary = {}

	var layer := CanvasLayer.new()
	layer.name = "Wings3DLabHUDLayer"
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

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.05, 0.06, 0.11, 0.88)
	panel_style.border_color = Color(0.95, 0.24, 0.44, 0.62)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(8)
	panel_style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", panel_style)
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
	title.text = "3D LAB — ALAS ASTRAL SERAPH (ARCSYS)"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(1.0, 0.40, 0.58, 1.0))
	vbox.add_child(title)

	var hint := Label.new()
	hint.text = "1-6: Anims · Space/Click: Pulso · WASD: Vuelo · T: 360° · B: 2D"
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.75, 0.80, 0.90, 0.88))
	vbox.add_child(hint)

	var telemetry_label := Label.new()
	telemetry_label.name = "TelemetryLabel"
	telemetry_label.text = "Yaw: 0° | Front: 0 / Back: 12 | Tris: 0"
	telemetry_label.add_theme_font_size_override("font_size", 11)
	telemetry_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.42, 0.96))
	vbox.add_child(telemetry_label)
	refs["telemetry_label"] = telemetry_label

	vbox.add_child(HSeparator.new())

	# --- Sección 1: Animaciones 3D ---
	_add_section_header(vbox, "Animaciones 3D (12 Cuchillas)")

	var anim_opt := OptionButton.new()
	for label_txt: String in WingsCtrlScript.ANIM_LABELS:
		anim_opt.add_item(label_txt)
	anim_opt.selected = 0
	anim_opt.item_selected.connect(func(idx: int) -> void:
		var cb: Callable = callbacks.get("on_anim_selected", Callable()) as Callable
		if cb.is_valid():
			cb.call(idx)
	)
	vbox.add_child(anim_opt)
	refs["anim_opt"] = anim_opt

	var anim_grid := GridContainer.new()
	anim_grid.columns = 2
	anim_grid.add_theme_constant_override("h_separation", 4)
	anim_grid.add_theme_constant_override("v_separation", 4)
	var short_names: Array[String] = [
		"1 · Idle Zero-G",
		"2 · Crucero Boost",
		"3 · Seraph Bloom",
		"4 · Escudo Aegis",
		"5 · Full Burst",
		"6 · Vórtice 360°",
	]
	for i: int in range(short_names.size()):
		var abtn := Button.new()
		abtn.text = short_names[i]
		abtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var anim_idx: int = i
		abtn.pressed.connect(func() -> void:
			anim_opt.select(anim_idx)
			var cb: Callable = callbacks.get("on_anim_selected", Callable()) as Callable
			if cb.is_valid():
				cb.call(anim_idx)
		)
		anim_grid.add_child(abtn)
	vbox.add_child(anim_grid)

	var pulse_row := HBoxContainer.new()
	pulse_row.add_theme_constant_override("separation", 6)
	var pulse_btn := Button.new()
	pulse_btn.text = "Pulso / Salva (Space)"
	pulse_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pulse_btn.pressed.connect(func() -> void:
		var cb: Callable = callbacks.get("on_trigger_pulse", Callable()) as Callable
		if cb.is_valid():
			cb.call()
	)
	pulse_row.add_child(pulse_btn)

	var auto_burst_chk := CheckBox.new()
	auto_burst_chk.text = "Auto-Burst"
	auto_burst_chk.button_pressed = true
	auto_burst_chk.toggled.connect(func(pressed: bool) -> void:
		var cb: Callable = callbacks.get("on_auto_burst_toggled", Callable()) as Callable
		if cb.is_valid():
			cb.call(pressed)
	)
	pulse_row.add_child(auto_burst_chk)
	vbox.add_child(pulse_row)

	vbox.add_child(HSeparator.new())

	# --- Sección 2: Orientación 360°, Piloto y Skins ---
	_add_section_header(vbox, "Rotación 360°, Piloto y Skins")

	var view_grid := GridContainer.new()
	view_grid.columns = 4
	view_grid.add_theme_constant_override("h_separation", 4)
	view_grid.add_theme_constant_override("v_separation", 4)
	for vk: String in VIEW_KEYS:
		var vbtn := Button.new()
		vbtn.text = vk.to_upper()
		vbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var key_copy: String = vk
		vbtn.pressed.connect(func() -> void:
			var cb: Callable = callbacks.get("on_view_selected", Callable()) as Callable
			if cb.is_valid():
				cb.call(key_copy)
		)
		view_grid.add_child(vbtn)
	vbox.add_child(view_grid)

	var yaw_slider: HSlider = _add_slider_row(vbox, "Giro Manual 360°", -180.0, 180.0, 1.0, 0.0, func(val: float) -> void:
		var cb: Callable = callbacks.get("on_yaw_deg_changed", Callable()) as Callable
		if cb.is_valid():
			cb.call(val)
	)
	refs["yaw_slider"] = yaw_slider

	var toggles_grid := GridContainer.new()
	toggles_grid.columns = 2
	toggles_grid.add_theme_constant_override("h_separation", 4)

	var turntable_chk := CheckBox.new()
	turntable_chk.text = "Turntable 360° (T)"
	turntable_chk.toggled.connect(func(pressed: bool) -> void:
		var cb: Callable = callbacks.get("on_turntable_toggled", Callable()) as Callable
		if cb.is_valid():
			cb.call(pressed)
	)
	toggles_grid.add_child(turntable_chk)
	refs["turntable_chk"] = turntable_chk

	var light_chk := CheckBox.new()
	light_chk.text = "Luz Giratoria"
	light_chk.toggled.connect(func(pressed: bool) -> void:
		var cb: Callable = callbacks.get("on_light_orbit_toggled", Callable()) as Callable
		if cb.is_valid():
			cb.call(pressed)
	)
	toggles_grid.add_child(light_chk)

	var compare_2d_chk := CheckBox.new()
	compare_2d_chk.text = "Comparar 2D (B)"
	compare_2d_chk.toggled.connect(func(pressed: bool) -> void:
		var cb: Callable = callbacks.get("on_compare_2d_toggled", Callable()) as Callable
		if cb.is_valid():
			cb.call(pressed)
	)
	toggles_grid.add_child(compare_2d_chk)
	refs["compare_2d_chk"] = compare_2d_chk

	var show_pilot_chk := CheckBox.new()
	show_pilot_chk.text = "Mostrar Piloto"
	show_pilot_chk.button_pressed = true
	show_pilot_chk.toggled.connect(func(pressed: bool) -> void:
		var cb: Callable = callbacks.get("on_show_pilot_toggled", Callable()) as Callable
		if cb.is_valid():
			cb.call(pressed)
	)
	toggles_grid.add_child(show_pilot_chk)

	var idle_pilot_chk := CheckBox.new()
	idle_pilot_chk.text = "Idle Piloto"
	idle_pilot_chk.button_pressed = true
	idle_pilot_chk.toggled.connect(func(pressed: bool) -> void:
		var cb: Callable = callbacks.get("on_idle_pilot_toggled", Callable()) as Callable
		if cb.is_valid():
			cb.call(pressed)
	)
	toggles_grid.add_child(idle_pilot_chk)

	var trails_chk := CheckBox.new()
	trails_chk.text = "Estelas HDR"
	trails_chk.button_pressed = config.enable_trails
	trails_chk.toggled.connect(func(pressed: bool) -> void:
		config.enable_trails = pressed
	)
	toggles_grid.add_child(trails_chk)

	var stardust_chk := CheckBox.new()
	stardust_chk.text = "Polvo Estelar"
	stardust_chk.button_pressed = config.enable_stardust
	stardust_chk.toggled.connect(func(pressed: bool) -> void:
		config.enable_stardust = pressed
	)
	toggles_grid.add_child(stardust_chk)

	var follow_skin_chk := CheckBox.new()
	follow_skin_chk.text = "Sync Skin"
	follow_skin_chk.button_pressed = config.follow_skin_palette
	follow_skin_chk.toggled.connect(func(pressed: bool) -> void:
		config.follow_skin_palette = pressed
		var cb: Callable = callbacks.get("on_follow_skin_toggled", Callable()) as Callable
		if cb.is_valid():
			cb.call(pressed)
	)
	toggles_grid.add_child(follow_skin_chk)

	vbox.add_child(toggles_grid)

	if not skin_choices.is_empty():
		var skin_opt := OptionButton.new()
		for sk: PilotSkinPreset in skin_choices:
			if sk != null:
				skin_opt.add_item("Skin: %s" % sk.label)
		skin_opt.selected = 0
		skin_opt.item_selected.connect(func(idx: int) -> void:
			var cb: Callable = callbacks.get("on_skin_selected", Callable()) as Callable
			if cb.is_valid():
				cb.call(idx)
		)
		vbox.add_child(skin_opt)
		refs["skin_opt"] = skin_opt

	vbox.add_child(HSeparator.new())

	# --- Sección 3: Calibración .tres ---
	_add_section_header(vbox, "Calibración 3D & Shader (.tres)")

	_add_slider_row(vbox, "Escala Alas", 0.5, 1.8, 0.02, config.wing_scale, func(val: float) -> void:
		config.wing_scale = val
	)
	_add_slider_row(vbox, "Separación Hombro", 0.30, 1.30, 0.02, config.root_spread_x, func(val: float) -> void:
		config.root_spread_x = val
	)
	_add_slider_row(vbox, "Barrido Atrás (°)", 0.0, 50.0, 1.0, config.blade_sweep_back_deg, func(val: float) -> void:
		config.blade_sweep_back_deg = val
	)
	_add_slider_row(vbox, "Amplitud Onda (°)", 0.0, 24.0, 0.5, config.wave_amp_deg, func(val: float) -> void:
		config.wave_amp_deg = val
	)
	_add_slider_row(vbox, "Elevación Cám (°)", -20.0, 35.0, 1.0, config.camera_elev_deg, func(val: float) -> void:
		config.camera_elev_deg = val
	)
	_add_slider_row(vbox, "Contorno 3D", 0.004, 0.050, 0.002, config.outline_width, func(val: float) -> void:
		config.outline_width = val
	)
	_add_slider_row(vbox, "Caligrafía Tinta", 0.0, 1.0, 0.05, config.outline_calligraphy_amount, func(val: float) -> void:
		config.outline_calligraphy_amount = val
	)
	_add_slider_row(vbox, "Tinta Aristas 3D", 0.0, 1.0, 0.04, config.crease_ink_strength, func(val: float) -> void:
		config.crease_ink_strength = val
	)
	_add_slider_row(vbox, "Glow Canales HDR", 0.0, 3.0, 0.05, config.channel_glow_strength, func(val: float) -> void:
		config.channel_glow_strength = val
	)
	_add_slider_row(vbox, "Flujo Energía", 0.0, 8.0, 0.2, config.energy_flow_speed, func(val: float) -> void:
		config.energy_flow_speed = val
	)
	_add_slider_row(vbox, "Rebote Carmesí", 0.0, 1.0, 0.04, config.crimson_bounce_strength, func(val: float) -> void:
		config.crimson_bounce_strength = val
	)
	_add_slider_row(vbox, "Rim-Light 3D", 0.0, 1.6, 0.04, config.rim_strength, func(val: float) -> void:
		config.rim_strength = val
	)

	vbox.add_child(HSeparator.new())
	_add_section_header(vbox, "Post-Pass 2D (Estilo Valentina)")

	var post_chk := CheckBox.new()
	post_chk.text = "Activar Post-Pass 2D (CAS + Borde)"
	post_chk.button_pressed = config.enable_post_pass
	post_chk.toggled.connect(func(pressed: bool) -> void:
		config.enable_post_pass = pressed
	)
	vbox.add_child(post_chk)

	_add_slider_row(vbox, "Borde 2D (px)", 0.0, 3.5, 0.05, config.post_outline_width_px, func(val: float) -> void:
		config.post_outline_width_px = val
	)
	_add_slider_row(vbox, "Fuerza Borde 2D", 0.0, 1.0, 0.05, config.post_outline_strength, func(val: float) -> void:
		config.post_outline_strength = val
	)
	_add_slider_row(vbox, "CAS Nitidez", 0.0, 1.0, 0.05, config.cas_sharpen_strength, func(val: float) -> void:
		config.cas_sharpen_strength = val
	)
	_add_slider_row(vbox, "Micro-Rim 2D", 0.0, 1.5, 0.05, config.post_rim_strength, func(val: float) -> void:
		config.post_rim_strength = val
	)

	vbox.add_child(HSeparator.new())

	var io_row := HBoxContainer.new()
	io_row.add_theme_constant_override("separation", 6)
	var save_btn := Button.new()
	save_btn.text = "Guardar .tres"
	save_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_btn.pressed.connect(func() -> void:
		var cb: Callable = callbacks.get("on_save_config", Callable()) as Callable
		if cb.is_valid():
			cb.call()
	)
	io_row.add_child(save_btn)

	var reload_btn := Button.new()
	reload_btn.text = "Recargar .tres"
	reload_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reload_btn.pressed.connect(func() -> void:
		var cb: Callable = callbacks.get("on_reload_config", Callable()) as Callable
		if cb.is_valid():
			cb.call()
	)
	io_row.add_child(reload_btn)
	vbox.add_child(io_row)

	var status_label := Label.new()
	status_label.text = "Preset: valentina_v2_wings_3d.tres"
	status_label.add_theme_font_size_override("font_size", 11)
	status_label.add_theme_color_override("font_color", Color(0.55, 0.92, 0.72, 0.9))
	vbox.add_child(status_label)
	refs["status_label"] = status_label

	return refs


static func _add_section_header(parent: VBoxContainer, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.45, 0.88, 1.0, 0.95))
	parent.add_child(lbl)


static func _add_slider_row(
	parent: VBoxContainer,
	label_text: String,
	min_v: float,
	max_v: float,
	step_v: float,
	init_v: float,
	on_change: Callable
) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(128.0, 0.0)
	lbl.add_theme_font_size_override("font_size", 11)
	row.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step_v
	slider.value = init_v
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)

	var val_lbl := Label.new()
	val_lbl.text = "%.3f" % init_v if step_v < 0.01 else "%.2f" % init_v
	val_lbl.custom_minimum_size = Vector2(44.0, 0.0)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_lbl.add_theme_font_size_override("font_size", 11)
	row.add_child(val_lbl)

	slider.value_changed.connect(func(v: float) -> void:
		val_lbl.text = "%.3f" % v if step_v < 0.01 else "%.2f" % v
		if on_change.is_valid():
			on_change.call(v)
	)

	parent.add_child(row)
	return slider

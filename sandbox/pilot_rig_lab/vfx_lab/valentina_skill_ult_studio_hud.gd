class_name ValentinaSkillUltStudioHUD
extends RefCounted
## Panel lateral interactivo de 5 pestañas + scrubber de línea de tiempo para calibrar en vivo
## PilotSkillConfig y PilotUltimateConfig (Valentina v2) sobre PilotCutInTheater.
## Corre en layer = 35 (PROCESS_MODE_ALWAYS) por encima del teatro para editar frames congelados.


static func build_hud(
	parent_node: Node,
	skill_cfg: PilotSkillConfig,
	ult_cfg: PilotUltimateConfig,
	skin_names: Array[String],
	callbacks: Dictionary
) -> Dictionary:
	var refs: Dictionary = {}

	var layer := CanvasLayer.new()
	layer.name = "SkillUltStudioHUDLayer"
	layer.layer = 35
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	parent_node.add_child(layer)
	refs["layer"] = layer

	var panel := PanelContainer.new()
	panel.name = "StudioControlPanel"
	panel.position = Vector2(14.0, 14.0)
	panel.custom_minimum_size = Vector2(340.0, 0.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.04, 0.095, 0.90)
	style.border_color = Color(0.95, 0.22, 0.42, 0.65)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	refs["panel"] = panel

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 6)
	panel.add_child(root_vbox)

	# Cabecera
	var title := Label.new()
	title.text = "VALENTINA v2 — SKILL & ULTIMATE STUDIO"
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(1.0, 0.32, 0.52, 1.0))
	root_vbox.add_child(title)

	var phase_lbl := Label.new()
	phase_lbl.name = "PhaseTelemetryLabel"
	phase_lbl.text = "Fase: IDLE | Blanco: Dummy #1 | [Tab] Ocultar HUD"
	phase_lbl.add_theme_font_size_override("font_size", 11)
	phase_lbl.add_theme_color_override("font_color", Color(0.84, 0.90, 1.0, 0.95))
	root_vbox.add_child(phase_lbl)
	refs["phase_label"] = phase_lbl

	# Botones principales [R] y [Q]
	var cast_row := HBoxContainer.new()
	cast_row.add_theme_constant_override("separation", 6)
	root_vbox.add_child(cast_row)

	var btn_skill := Button.new()
	btn_skill.text = "[R] Probar Skill"
	btn_skill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_skill.pressed.connect(func() -> void: _invoke(callbacks, "on_trigger_skill"))
	cast_row.add_child(btn_skill)

	var btn_ult := Button.new()
	btn_ult.text = "[Q] Probar Ultimate"
	btn_ult.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_ult.pressed.connect(func() -> void: _invoke(callbacks, "on_trigger_ultimate"))
	cast_row.add_child(btn_ult)

	# Transporte: Congelar + Velocidad + Escenarios
	var transport_row := HBoxContainer.new()
	transport_row.add_theme_constant_override("separation", 5)
	root_vbox.add_child(transport_row)

	var btn_freeze := Button.new()
	btn_freeze.text = "[P] Congelar"
	btn_freeze.toggle_mode = true
	btn_freeze.toggled.connect(func(pressed: bool) -> void: _invoke_1(callbacks, "on_freeze_toggled", pressed))
	transport_row.add_child(btn_freeze)
	refs["freeze_button"] = btn_freeze

	var speed_opt := OptionButton.new()
	speed_opt.add_item("1.0x", 0)
	speed_opt.add_item("0.5x", 1)
	speed_opt.add_item("0.2x", 2)
	speed_opt.item_selected.connect(func(idx: int) -> void:
		var spd: float = 1.0 if idx == 0 else (0.5 if idx == 1 else 0.2)
		_invoke_1(callbacks, "on_speed_changed", spd)
	)
	transport_row.add_child(speed_opt)

	var scen_opt := OptionButton.new()
	scen_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scen_opt.add_item("Enjambre (12)", 0)
	scen_opt.add_item("Escuadrón (4)", 1)
	scen_opt.add_item("Jefe Único (1)", 2)
	scen_opt.item_selected.connect(func(idx: int) -> void: _invoke_1(callbacks, "on_scenario_changed", idx))
	transport_row.add_child(scen_opt)

	# Scrubber de Línea de Tiempo
	var scrub_row := HBoxContainer.new()
	var scrub_lbl := Label.new()
	scrub_lbl.text = "Timeline:"
	scrub_lbl.add_theme_font_size_override("font_size", 11)
	scrub_row.add_child(scrub_lbl)

	var scrubber := HSlider.new()
	scrubber.min_value = 0.0
	scrubber.max_value = 1.0
	scrubber.step = 0.005
	scrubber.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scrubber.value_changed.connect(func(val: float) -> void: _invoke_1(callbacks, "on_timeline_scrub", val))
	scrub_row.add_child(scrubber)
	refs["scrubber"] = scrubber
	root_vbox.add_child(scrub_row)

	# Contenedor de 5 Pestañas
	var tabs := TabContainer.new()
	tabs.custom_minimum_size = Vector2(320.0, 445.0)
	root_vbox.add_child(tabs)

	var tab_skill := _make_scroll_tab(tabs, "[R] Skill")
	var tab_pose := _make_scroll_tab(tabs, "[Q] Pose")
	var tab_impact := _make_scroll_tab(tabs, "Impact")
	var tab_wings := _make_scroll_tab(tabs, "12 Alas")
	var tab_skins := _make_scroll_tab(tabs, "Skins/.tres")

	var on_changed: Callable = callbacks.get("on_config_changed", Callable()) as Callable

	# --- TAB 1: [R] SKILL & VISOR ---
	_add_check(tab_skill, "Usar Arte Nuevo de Valentina", skill_cfg.use_custom_cutin_art, func(b: bool) -> void:
		skill_cfg.use_custom_cutin_art = b
		_call_if_valid(on_changed)
	)
	_add_enum_row(tab_skill, "Formato Cut-In", ["Diagonal 35° (ZZZ)", "Visor Horizontal (HSR)", "Ventana HUD (WuWa)"], int(skill_cfg.cutin_style), func(idx: int) -> void:
		skill_cfg.cutin_style = idx as PilotSkillConfig.SkillCutInStyle
		_call_if_valid(on_changed)
	)
	_add_slider(tab_skill, "Pausa Skill (s)", 0.15, 1.60, 0.02, skill_cfg.time_stop_sec, func(v: float) -> void:
		skill_cfg.time_stop_sec = v
		_call_if_valid(on_changed)
	)
	_add_slider(tab_skill, "Impact Frame (s)", 0.0, 0.25, 0.005, skill_cfg.impact_frame_sec, func(v: float) -> void:
		skill_cfg.impact_frame_sec = v
		_call_if_valid(on_changed)
	)
	_add_slider(tab_skill, "Ángulo Franja (°)", -38.0, 38.0, 1.0, skill_cfg.strip_angle_deg, func(v: float) -> void:
		skill_cfg.strip_angle_deg = v
		_call_if_valid(on_changed)
	)
	_add_slider(tab_skill, "Altura Franja", 0.12, 0.50, 0.01, skill_cfg.strip_height_ratio, func(v: float) -> void:
		skill_cfg.strip_height_ratio = v
		_call_if_valid(on_changed)
	)
	_add_slider(tab_skill, "Posición Y Franja", 0.20, 0.80, 0.01, skill_cfg.strip_y_ratio, func(v: float) -> void:
		skill_cfg.strip_y_ratio = v
		_call_if_valid(on_changed)
	)
	_add_slider(tab_skill, "Zoom Ojo/Monóculo", 1.0, 4.0, 0.05, skill_cfg.eye_zoom_scale, func(v: float) -> void:
		skill_cfg.eye_zoom_scale = v
		_call_if_valid(on_changed)
	)
	_add_slider(tab_skill, "Ancho Haz Sniper", 12.0, 120.0, 2.0, skill_cfg.beam_width_px, func(v: float) -> void:
		skill_cfg.beam_width_px = v
		_call_if_valid(on_changed)
	)
	_add_slider(tab_skill, "Duración Haz (s)", 0.10, 0.80, 0.02, skill_cfg.beam_duration_sec, func(v: float) -> void:
		skill_cfg.beam_duration_sec = v
		_call_if_valid(on_changed)
	)
	_add_check(tab_skill, "Perforar toda la línea", skill_cfg.pierce_all_in_line, func(b: bool) -> void:
		skill_cfg.pierce_all_in_line = b
		_call_if_valid(on_changed)
	)

	# --- TAB 2: [Q] POSE WALLPAPER ENGINE ---
	_add_enum_row(tab_pose, "Motor Cut-In [Q]", ["ARTE NUEVO (Wallpaper)", "LIVE_BANNER_25D (HD)", "RIG_BATTLE_POSE (18h)"], int(ult_cfg.render_mode), func(idx: int) -> void:
		ult_cfg.render_mode = idx as PilotUltimateConfig.CutInRenderMode
		_call_if_valid(on_changed)
	)
	_add_enum_row(tab_pose, "Composición Marco", ["Fullscreen Bleed", "Slash Asimétrico (ZZZ)", "Letterbox Widescreen"], int(ult_cfg.frame_composition), func(idx: int) -> void:
		ult_cfg.frame_composition = idx as PilotUltimateConfig.FrameComposition
		_call_if_valid(on_changed)
	)
	_add_slider(tab_pose, "Zoom Rostro Banner", 0.9, 3.6, 0.05, ult_cfg.face_closeup_zoom, func(v: float) -> void:
		ult_cfg.face_closeup_zoom = v
		_call_if_valid(on_changed)
	)
	_add_slider(tab_pose, "Offset Y Rostro", -100.0, 300.0, 5.0, ult_cfg.face_focus_offset_px.y, func(v: float) -> void:
		ult_cfg.face_focus_offset_px.y = v
		_call_if_valid(on_changed)
	)
	_add_slider(tab_pose, "Dutch Tilt (°)", -18.0, 18.0, 0.5, ult_cfg.dutch_tilt_deg, func(v: float) -> void:
		ult_cfg.dutch_tilt_deg = v
		_call_if_valid(on_changed)
	)
	_add_slider(tab_pose, "Drift Cámara X", -80.0, 80.0, 2.0, ult_cfg.camera_drift_px.x, func(v: float) -> void:
		ult_cfg.camera_drift_px.x = v
		_call_if_valid(on_changed)
	)
	_add_slider(tab_pose, "Zoom Rig (18 huesos)", 1.0, 4.5, 0.05, ult_cfg.rig_closeup_zoom, func(v: float) -> void:
		ult_cfg.rig_closeup_zoom = v
		_call_if_valid(on_changed)
	)
	_add_slider(tab_pose, "Inclinación Torso Rig", -24.0, 24.0, 0.5, ult_cfg.rig_torso_lean_deg, func(v: float) -> void:
		ult_cfg.rig_torso_lean_deg = v
		_call_if_valid(on_changed)
	)
	_add_slider(tab_pose, "Fulgor Ojo/Monóculo", 0.0, 2.5, 0.05, ult_cfg.eye_flare_boost, func(v: float) -> void:
		ult_cfg.eye_flare_boost = v
		_call_if_valid(on_changed)
	)

	# --- TAB 3: IMPACT FRAMES & FRACTURA OBSIDIANA ---
	_add_slider(tab_impact, "Fase Cut-In (s)", 0.20, 2.00, 0.02, ult_cfg.cutin_phase_sec, func(v: float) -> void:
		ult_cfg.cutin_phase_sec = v
		ult_cfg.ensure_defaults()
		_call_if_valid(on_changed)
	)
	_add_slider(tab_impact, "Fase 1: B/N HDR (s)", 0.03, 0.40, 0.01, ult_cfg.impact_bw_phase_sec, func(v: float) -> void:
		ult_cfg.impact_bw_phase_sec = v
		ult_cfg.ensure_defaults()
		_call_if_valid(on_changed)
	)
	_add_slider(tab_impact, "Fase 2: Fractura (s)", 0.03, 0.50, 0.01, ult_cfg.impact_shatter_phase_sec, func(v: float) -> void:
		ult_cfg.impact_shatter_phase_sec = v
		ult_cfg.ensure_defaults()
		_call_if_valid(on_changed)
	)
	_add_slider(tab_impact, "Umbral B/N Luma", 0.08, 0.72, 0.02, ult_cfg.bw_luma_threshold, func(v: float) -> void:
		ult_cfg.bw_luma_threshold = v
		_call_if_valid(on_changed)
	)
	_add_slider(tab_impact, "Boost Acento HDR", 0.8, 3.0, 0.05, ult_cfg.accent_hdr_boost, func(v: float) -> void:
		ult_cfg.accent_hdr_boost = v
		_call_if_valid(on_changed)
	)
	_add_slider(tab_impact, "Celdas Voronoi", 6.0, 32.0, 1.0, ult_cfg.shatter_cell_density, func(v: float) -> void:
		ult_cfg.shatter_cell_density = v
		_call_if_valid(on_changed)
	)
	_add_slider(tab_impact, "Grosor Grietas (px)", 0.8, 7.0, 0.2, ult_cfg.shatter_crack_width_px, func(v: float) -> void:
		ult_cfg.shatter_crack_width_px = v
		_call_if_valid(on_changed)
	)
	_add_slider(tab_impact, "Refracción Cristal", 0.0, 36.0, 1.0, ult_cfg.shatter_refraction_px, func(v: float) -> void:
		ult_cfg.shatter_refraction_px = v
		_call_if_valid(on_changed)
	)
	_add_slider(tab_impact, "Speedlines Radiales", 0.0, 1.2, 0.05, ult_cfg.radial_speedlines_strength, func(v: float) -> void:
		ult_cfg.radial_speedlines_strength = v
		_call_if_valid(on_changed)
	)
	_add_slider(tab_impact, "Aberración Cromática", 0.0, 24.0, 0.5, ult_cfg.chromatic_aberration_px, func(v: float) -> void:
		ult_cfg.chromatic_aberration_px = v
		_call_if_valid(on_changed)
	)

	# --- TAB 4: 12 ALAS & CORTES ---
	_add_slider(tab_wings, "N° de Cuchillas", 2.0, 12.0, 1.0, float(ult_cfg.blade_count), func(v: float) -> void:
		ult_cfg.blade_count = int(roundf(v))
		_call_if_valid(on_changed)
	)
	_add_slider(tab_wings, "Stagger Salida (s)", 0.0, 0.08, 0.004, ult_cfg.blade_launch_stagger_sec, func(v: float) -> void:
		ult_cfg.blade_launch_stagger_sec = v
		_call_if_valid(on_changed)
	)
	_add_slider(tab_wings, "Duración Ida (s)", 0.10, 0.65, 0.02, ult_cfg.blade_flight_sec, func(v: float) -> void:
		ult_cfg.blade_flight_sec = v
		_call_if_valid(on_changed)
	)
	_add_slider(tab_wings, "Giro Ápice (s)", 0.04, 0.40, 0.01, ult_cfg.blade_apex_hold_sec, func(v: float) -> void:
		ult_cfg.blade_apex_hold_sec = v
		_call_if_valid(on_changed)
	)
	_add_slider(tab_wings, "Duración Regreso (s)", 0.10, 0.70, 0.02, ult_cfg.blade_return_sec, func(v: float) -> void:
		ult_cfg.blade_return_sec = v
		_call_if_valid(on_changed)
	)
	_add_slider(tab_wings, "Curvatura Arco (px)", 0.0, 280.0, 10.0, ult_cfg.blade_arc_curvature_px, func(v: float) -> void:
		ult_cfg.blade_arc_curvature_px = v
		_call_if_valid(on_changed)
	)
	_add_slider(tab_wings, "Escala Cuchillas", 0.20, 1.00, 0.02, ult_cfg.blade_scale, func(v: float) -> void:
		ult_cfg.blade_scale = v
		_call_if_valid(on_changed)
	)
	_add_slider(tab_wings, "Persistencia Cortes", 0.12, 1.00, 0.02, ult_cfg.slash_trail_linger_sec, func(v: float) -> void:
		ult_cfg.slash_trail_linger_sec = v
		_call_if_valid(on_changed)
	)
	_add_check(tab_wings, "Purgar Orbes Danmaku", ult_cfg.purge_all_bullets, func(b: bool) -> void:
		ult_cfg.purge_all_bullets = b
		_call_if_valid(on_changed)
	)

	# --- TAB 5: SKINS SHADER, HUD PREVIEW & GUARDADO .TRES ---
	_add_enum_row(tab_skins, "HUD Preview (3 Ideas)", ["Idea 1: WuWa/Genshin Circular", "Idea 2: ZZZ Hex + Decibel", "Idea 3: Cockpit Central"], 0, func(idx: int) -> void:
		_invoke_1(callbacks, "on_hud_style_selected", idx)
	)
	var btn_charge_ult := Button.new()
	btn_charge_ult.text = "Recargar Energía Ult [Q] al 100%"
	btn_charge_ult.pressed.connect(func() -> void: _invoke(callbacks, "on_refill_energy"))
	tab_skins.add_child(btn_charge_ult)

	if not skin_names.is_empty():
		_add_enum_row(tab_skins, "Skin Piloto/Alas", skin_names, 0, func(idx: int) -> void:
			_invoke_1(callbacks, "on_skin_selected", idx)
		)
	_add_check(tab_skins, "Mostrar Orbes Danmaku", true, func(b: bool) -> void:
		_invoke_1(callbacks, "on_orbs_toggled", b)
	)

	tab_skins.add_child(HSeparator.new())
	var btn_save := Button.new()
	btn_save.text = "Guardar .tres en Producción"
	btn_save.pressed.connect(func() -> void: _invoke(callbacks, "on_save_configs"))
	tab_skins.add_child(btn_save)

	var btn_reload := Button.new()
	btn_reload.text = "Recargar .tres desde Disco"
	btn_reload.pressed.connect(func() -> void: _invoke(callbacks, "on_reload_configs"))
	tab_skins.add_child(btn_reload)

	var btn_wb := Button.new()
	btn_wb.text = "Abrir Skill & Ult Workbench (Prod.)"
	btn_wb.pressed.connect(func() -> void: _invoke(callbacks, "on_open_workbench"))
	tab_skins.add_child(btn_wb)

	var btn_back := Button.new()
	btn_back.text = "Volver a VFX Lab (Sandevistan)"
	btn_back.pressed.connect(func() -> void: _invoke(callbacks, "on_back_to_vfx_lab"))
	tab_skins.add_child(btn_back)

	var save_status := Label.new()
	save_status.text = ""
	save_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	save_status.add_theme_font_size_override("font_size", 11)
	save_status.add_theme_color_override("font_color", Color(0.42, 1.0, 0.68, 1.0))
	tab_skins.add_child(save_status)
	refs["save_status"] = save_status

	return refs


static func _make_scroll_tab(tabs: TabContainer, title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 6)
	scroll.add_child(vb)
	return vb


static func _add_enum_row(parent: VBoxContainer, label_text: String, items: Array[String], initial: int, on_sel: Callable) -> void:
	var row := HBoxContainer.new()
	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 11)
	row.add_child(lbl)
	var opt := OptionButton.new()
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i: int in range(items.size()):
		opt.add_item(items[i], i)
	opt.select(clampi(initial, 0, maxi(0, items.size() - 1)))
	opt.item_selected.connect(on_sel)
	row.add_child(opt)
	parent.add_child(row)


static func _add_slider(parent: VBoxContainer, label_text: String, min_v: float, max_v: float, step_v: float, init_v: float, on_val: Callable) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	var head := HBoxContainer.new()
	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(lbl)

	var val_lbl := Label.new()
	val_lbl.text = "%.2f" % init_v
	val_lbl.add_theme_font_size_override("font_size", 11)
	val_lbl.add_theme_color_override("font_color", Color(0.55, 0.92, 1.0, 1.0))
	head.add_child(val_lbl)
	box.add_child(head)

	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step_v
	slider.value = clampf(init_v, min_v, max_v)
	slider.value_changed.connect(func(v: float) -> void:
		val_lbl.text = "%.2f" % v
		on_val.call(v)
	)
	box.add_child(slider)
	parent.add_child(box)


static func _add_check(parent: VBoxContainer, label_text: String, init_v: bool, on_toggle: Callable) -> void:
	var cb := CheckButton.new()
	cb.text = label_text
	cb.button_pressed = init_v
	cb.toggled.connect(on_toggle)
	parent.add_child(cb)


static func _invoke(callbacks: Dictionary, key: String) -> void:
	var c: Callable = callbacks.get(key, Callable()) as Callable
	if c.is_valid():
		c.call()


static func _invoke_1(callbacks: Dictionary, key: String, arg: Variant) -> void:
	var c: Callable = callbacks.get(key, Callable()) as Callable
	if c.is_valid():
		c.call(arg)


static func _call_if_valid(c: Callable) -> void:
	if c.is_valid():
		c.call()

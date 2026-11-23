class_name ValentinaGunsLabHUD
extends RefCounted
## Constructor de HUD interactivo para ValentinaGunsLab.
## Permite calibrar en vivo la geometría 3D del anillo orbital, la deformación 2.5D
## del arma (escorzo, trapezoide, extrusión, escala perspectiva), cantidad de slots (1..4),
## vista 8-dir de Valentina y guardar/recargar el recurso .tres.

const ConfigScript = preload("res://data/pilots/schemas/pilot_orbital_weapon_config.gd")

const PANEL_WIDTH: float = 330.0
const VIEW_KEYS: Array[String] = ["s", "se", "e", "ne", "n", "nw", "w", "sw"]


static func build_hud(
	parent: Node,
	config: ConfigScript,
	weapon_choices: Array[Dictionary],
	callbacks: Dictionary,
	skin_choices: Array[PilotSkinPreset] = []
) -> Dictionary:
	var layer := CanvasLayer.new()
	layer.name = "GunsLabHUDLayer"
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
	panel_style.bg_color = Color(0.05, 0.06, 0.11, 0.86)
	panel_style.border_color = Color(0.24, 0.78, 0.96, 0.55)
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
	title.text = "GUNS LAB — ANILLO ORBITAL 2.5D"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.35, 0.92, 1.0, 1.0))
	vbox.add_child(title)

	var hint := Label.new()
	hint.text = "Click/Space: Disparar · P: Pausa · Rueda: Zoom"
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.72, 0.78, 0.88, 0.85))
	vbox.add_child(hint)

	var telemetry_label := Label.new()
	telemetry_label.name = "TelemetryLabel"
	telemetry_label.text = "θ: 0° | depth: 0.00 | barrel_z: 0.00 | z: 11"
	telemetry_label.add_theme_font_size_override("font_size", 11)
	telemetry_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.42, 0.95))
	vbox.add_child(telemetry_label)

	vbox.add_child(HSeparator.new())

	# --- Sección 1: Modo de Órbita y Armas ---
	_add_section_header(vbox, "Órbita y Armamento")

	var mode_opt := OptionButton.new()
	mode_opt.add_item("Auto Órbita Radial 360° (Showcase 3D)", 0)
	mode_opt.add_item("Mouse Aim (Seguimiento en Anillo)", 1)
	mode_opt.add_item("Auto Órbita Tangente (Escolta)", 2)
	mode_opt.select(0)
	mode_opt.item_selected.connect(func(idx: int) -> void:
		var cb: Callable = callbacks.get("on_mode_selected", Callable())
		if cb.is_valid():
			cb.call(idx)
	)
	vbox.add_child(mode_opt)

	var weapon_opt := OptionButton.new()
	for i: int in range(weapon_choices.size()):
		weapon_opt.add_item(String(weapon_choices[i].get("label", "Weapon %d" % i)), i)
	if not weapon_choices.is_empty():
		weapon_opt.select(0)
	weapon_opt.item_selected.connect(func(idx: int) -> void:
		var cb: Callable = callbacks.get("on_weapon_selected", Callable())
		if cb.is_valid():
			cb.call(idx)
	)
	vbox.add_child(weapon_opt)

	var count_row := HBoxContainer.new()
	count_row.add_theme_constant_override("separation", 4)
	var count_lbl := Label.new()
	count_lbl.text = "Slots:"
	count_lbl.add_theme_font_size_override("font_size", 12)
	count_row.add_child(count_lbl)
	for c: int in range(1, 5):
		var btn := Button.new()
		btn.text = "%d" % c
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var slot_count: int = c
		btn.pressed.connect(func() -> void:
			var cb: Callable = callbacks.get("on_weapon_count_selected", Callable())
			if cb.is_valid():
				cb.call(slot_count)
		)
		count_row.add_child(btn)
	vbox.add_child(count_row)

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 6)
	var fire_btn := Button.new()
	fire_btn.text = "Disparar"
	fire_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fire_btn.pressed.connect(func() -> void:
		var cb: Callable = callbacks.get("on_trigger_fire", Callable())
		if cb.is_valid():
			cb.call()
	)
	action_row.add_child(fire_btn)

	var pause_btn := Button.new()
	pause_btn.text = "Pausar Órbita"
	pause_btn.toggle_mode = true
	pause_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pause_btn.toggled.connect(func(pressed: bool) -> void:
		pause_btn.text = "Reanudar" if pressed else "Pausar Órbita"
		var cb: Callable = callbacks.get("on_orbit_pause_toggled", Callable())
		if cb.is_valid():
			cb.call(pressed)
	)
	action_row.add_child(pause_btn)
	vbox.add_child(action_row)

	var toggles_row := HBoxContainer.new()
	toggles_row.add_theme_constant_override("separation", 8)
	var autofire_chk := CheckBox.new()
	autofire_chk.text = "Auto-Fire"
	autofire_chk.button_pressed = false
	autofire_chk.toggled.connect(func(v: bool) -> void:
		var cb: Callable = callbacks.get("on_auto_fire_toggled", Callable())
		if cb.is_valid():
			cb.call(v)
	)
	toggles_row.add_child(autofire_chk)

	var ring_chk := CheckBox.new()
	ring_chk.text = "Ver Anillo"
	ring_chk.button_pressed = true
	ring_chk.toggled.connect(func(v: bool) -> void:
		var cb: Callable = callbacks.get("on_show_ring_toggled", Callable())
		if cb.is_valid():
			cb.call(v)
	)
	toggles_row.add_child(ring_chk)
	vbox.add_child(toggles_row)

	var ring_sync_chk := CheckBox.new()
	ring_sync_chk.text = "Sync Anillo y VFX con Skin"
	ring_sync_chk.button_pressed = config.ring_follow_skin
	ring_sync_chk.toggled.connect(func(v: bool) -> void:
		var cb: Callable = callbacks.get("on_ring_follow_skin_toggled", Callable())
		if cb.is_valid():
			cb.call(v)
	)
	vbox.add_child(ring_sync_chk)

	var ring_tex_chk := CheckBox.new()
	ring_tex_chk.text = "Anillo Textura IA (Mecha)"
	ring_tex_chk.button_pressed = config.ring_use_texture
	ring_tex_chk.toggled.connect(func(v: bool) -> void:
		var cb: Callable = callbacks.get("on_ring_use_texture_toggled", Callable())
		if cb.is_valid():
			cb.call(v)
	)
	vbox.add_child(ring_tex_chk)

	vbox.add_child(HSeparator.new())

	# --- Sección 2: Valentina v2 (Rig estático + toggles) ---
	_add_section_header(vbox, "Valentina v2 (Rig)")

	var view_row := HBoxContainer.new()
	view_row.add_theme_constant_override("separation", 6)
	var view_lbl := Label.new()
	view_lbl.text = "Vista 8-Dir:"
	view_lbl.add_theme_font_size_override("font_size", 12)
	view_row.add_child(view_lbl)
	var view_opt := OptionButton.new()
	view_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i: int in range(VIEW_KEYS.size()):
		view_opt.add_item(VIEW_KEYS[i].to_upper(), i)
	view_opt.select(0)
	view_opt.item_selected.connect(func(idx: int) -> void:
		var cb: Callable = callbacks.get("on_view_selected", Callable())
		if cb.is_valid() and idx >= 0 and idx < VIEW_KEYS.size():
			cb.call(VIEW_KEYS[idx])
	)
	view_row.add_child(view_opt)
	vbox.add_child(view_row)

	var skin_opt: OptionButton = null
	if not skin_choices.is_empty():
		var skin_row := HBoxContainer.new()
		skin_row.add_theme_constant_override("separation", 6)
		var skin_lbl := Label.new()
		skin_lbl.text = "Skin:"
		skin_lbl.add_theme_font_size_override("font_size", 12)
		skin_row.add_child(skin_lbl)
		skin_opt = OptionButton.new()
		skin_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for si: int in range(skin_choices.size()):
			var sk: PilotSkinPreset = skin_choices[si]
			skin_opt.add_item(sk.label if not sk.label.is_empty() else ("Skin %d" % si), si)
		skin_opt.select(0)
		skin_opt.item_selected.connect(func(idx: int) -> void:
			var cb: Callable = callbacks.get("on_skin_selected", Callable())
			if cb.is_valid():
				cb.call(idx)
		)
		skin_row.add_child(skin_opt)
		vbox.add_child(skin_row)

	var rig_toggles := HBoxContainer.new()
	rig_toggles.add_theme_constant_override("separation", 8)
	var wings_chk := CheckBox.new()
	wings_chk.text = "Alas Psíquicas"
	wings_chk.button_pressed = false
	wings_chk.toggled.connect(func(v: bool) -> void:
		var cb: Callable = callbacks.get("on_wings_toggled", Callable())
		if cb.is_valid():
			cb.call(v)
	)
	rig_toggles.add_child(wings_chk)

	var idle_chk := CheckBox.new()
	idle_chk.text = "Idle Zero-G"
	idle_chk.button_pressed = false
	idle_chk.toggled.connect(func(v: bool) -> void:
		var cb: Callable = callbacks.get("on_idle_toggled", Callable())
		if cb.is_valid():
			cb.call(v)
	)
	rig_toggles.add_child(idle_chk)
	vbox.add_child(rig_toggles)

	vbox.add_child(HSeparator.new())

	# --- Sección 3: Geometría del Anillo 3D ---
	_add_section_header(vbox, "Geometría Anillo 3D")
	var sliders: Dictionary = {}
	sliders["ring_radius_x"] = _add_slider(vbox, "Radio X", 60.0, 220.0, 1.0, config.ring_radius_x, func(v: float) -> void:
		config.ring_radius_x = v
	)
	sliders["ring_radius_y"] = _add_slider(vbox, "Radio Y (Tilt 3D)", 14.0, 150.0, 1.0, config.ring_radius_y, func(v: float) -> void:
		config.ring_radius_y = v
	)
	sliders["ring_tilt_deg"] = _add_slider(vbox, "Inclinación (°)", -35.0, 35.0, 0.5, config.ring_tilt_deg, func(v: float) -> void:
		config.ring_tilt_deg = v
	)
	sliders["ring_offset_y"] = _add_slider(vbox, "Offset Y", -60.0, 60.0, 1.0, config.ring_center_offset.y, func(v: float) -> void:
		config.ring_center_offset.y = v
	)
	sliders["orbit_speed_rad"] = _add_slider(vbox, "Velocidad Órbita", 0.0, 4.0, 0.05, config.orbit_speed_rad, func(v: float) -> void:
		config.orbit_speed_rad = v
	)
	sliders["ring_inner_arc_speed"] = _add_slider(vbox, "Vel. Arcos Astrolabio", -2.0, 2.0, 0.05, config.ring_inner_arc_speed, func(v: float) -> void:
		config.ring_inner_arc_speed = v
	)
	sliders["ring_diamond_size_px"] = _add_slider(vbox, "Cristales Anclaje (px)", 4.0, 18.0, 0.5, config.ring_diamond_size_px, func(v: float) -> void:
		config.ring_diamond_size_px = v
	)

	vbox.add_child(HSeparator.new())

	# --- Sección 4: Perspectiva 2.5D y Volumen ---
	_add_section_header(vbox, "Perspectiva 2.5D del Arma")
	sliders["weapon_base_scale"] = _add_slider(vbox, "Escala Arma", 0.06, 0.30, 0.005, config.weapon_base_scale, func(v: float) -> void:
		config.weapon_base_scale = v
	)
	sliders["perspective_scale_amp"] = _add_slider(vbox, "Escala Perspectiva", 0.0, 0.45, 0.01, config.perspective_scale_amp, func(v: float) -> void:
		config.perspective_scale_amp = v
	)
	sliders["foreshorten_min_x"] = _add_slider(vbox, "Escorzo Mín X", 0.25, 1.0, 0.01, config.foreshorten_min_x, func(v: float) -> void:
		config.foreshorten_min_x = v
	)
	sliders["trapezoid_strength"] = _add_slider(vbox, "Trapezoide 2.5D", 0.0, 0.85, 0.01, config.trapezoid_strength, func(v: float) -> void:
		config.trapezoid_strength = v
	)
	sliders["extrude_depth_px"] = _add_slider(vbox, "Extrusión 3D (px)", 0.0, 12.0, 0.25, config.extrude_depth_px, func(v: float) -> void:
		config.extrude_depth_px = v
	)
	sliders["depth_back_dim"] = _add_slider(vbox, "Oscurecer Atrás", 0.0, 0.75, 0.02, config.depth_back_dim, func(v: float) -> void:
		config.depth_back_dim = v
	)
	sliders["rim_strength"] = _add_slider(vbox, "Rim Light", 0.0, 1.2, 0.02, config.rim_strength, func(v: float) -> void:
		config.rim_strength = v
	)
	sliders["ink_sdf_strength"] = _add_slider(vbox, "Tinta SDF 2×", 0.0, 1.0, 0.02, config.ink_sdf_strength, func(v: float) -> void:
		config.ink_sdf_strength = v
	)
	sliders["recoil_kick_px"] = _add_slider(vbox, "Recoil (px)", 0.0, 40.0, 0.5, config.recoil_kick_px, func(v: float) -> void:
		config.recoil_kick_px = v
	)

	vbox.add_child(HSeparator.new())

	# --- Sección 5: Guardar / Recargar ---
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
	status_label.name = "StatusLabel"
	status_label.text = ""
	status_label.add_theme_font_size_override("font_size", 11)
	status_label.add_theme_color_override("font_color", Color(0.55, 0.95, 0.65, 1.0))
	vbox.add_child(status_label)

	return {
		"layer": layer,
		"panel": panel,
		"telemetry_label": telemetry_label,
		"status_label": status_label,
		"pause_btn": pause_btn,
		"mode_opt": mode_opt,
		"skin_opt": skin_opt,
		"ring_sync_chk": ring_sync_chk,
		"ring_tex_chk": ring_tex_chk,
		"sliders": sliders,
	}


static func sync_sliders_from_config(hud_refs: Dictionary, config: ConfigScript) -> void:
	if config == null or not hud_refs.has("sliders"):
		return
	var sliders: Dictionary = hud_refs["sliders"] as Dictionary
	_set_slider_val(sliders, "ring_radius_x", config.ring_radius_x)
	_set_slider_val(sliders, "ring_radius_y", config.ring_radius_y)
	_set_slider_val(sliders, "ring_tilt_deg", config.ring_tilt_deg)
	_set_slider_val(sliders, "ring_offset_y", config.ring_center_offset.y)
	_set_slider_val(sliders, "orbit_speed_rad", config.orbit_speed_rad)
	_set_slider_val(sliders, "ring_inner_arc_speed", config.ring_inner_arc_speed)
	_set_slider_val(sliders, "ring_diamond_size_px", config.ring_diamond_size_px)
	_set_slider_val(sliders, "weapon_base_scale", config.weapon_base_scale)
	_set_slider_val(sliders, "perspective_scale_amp", config.perspective_scale_amp)
	_set_slider_val(sliders, "foreshorten_min_x", config.foreshorten_min_x)
	_set_slider_val(sliders, "trapezoid_strength", config.trapezoid_strength)
	_set_slider_val(sliders, "extrude_depth_px", config.extrude_depth_px)
	_set_slider_val(sliders, "depth_back_dim", config.depth_back_dim)
	_set_slider_val(sliders, "rim_strength", config.rim_strength)
	_set_slider_val(sliders, "ink_sdf_strength", config.ink_sdf_strength)
	_set_slider_val(sliders, "recoil_kick_px", config.recoil_kick_px)


static func _set_slider_val(sliders: Dictionary, key: String, val: float) -> void:
	if not sliders.has(key):
		return
	var pair: Dictionary = sliders[key] as Dictionary
	var slider: HSlider = pair.get("slider", null) as HSlider
	var lbl: Label = pair.get("val_label", null) as Label
	if is_instance_valid(slider):
		slider.set_value_no_signal(val)
	if is_instance_valid(lbl):
		lbl.text = "%.2f" % val


static func _add_section_header(parent: VBoxContainer, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text.to_upper()
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.88, 0.55, 0.65, 0.95))
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
	val_lbl.text = "%.2f" % init_v
	val_lbl.add_theme_font_size_override("font_size", 11)
	val_lbl.add_theme_color_override("font_color", Color(0.62, 0.90, 1.0, 1.0))
	top.add_child(val_lbl)
	row.add_child(top)

	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step_v
	slider.value = init_v
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(func(v: float) -> void:
		val_lbl.text = "%.2f" % v
		if on_changed.is_valid():
			on_changed.call(v)
	)
	row.add_child(slider)
	parent.add_child(row)

	return {"slider": slider, "val_label": val_lbl}

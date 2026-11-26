class_name PetBubbleLabHUD
extends Control

## HUD lateral interactivo para el Lab de 3D Pets.

signal pet_selected(selection_id: StringName)
signal mode_selected(mode_idx: int)
signal emote_triggered(kind: StringName)
signal overrides_changed(opacity_mult: float, spin_mult: float, fresnel_mult: float, normal_strength: float, edge_tex_opacity: float, bubble_bump: float)
signal sun_changed(angle_deg: float, auto_sun: bool)
signal orbit_params_changed(tilt_deg: float, scale_mult: float, show_guide: bool)
signal layers_changed(show_back: bool, show_pet: bool, show_front: bool, show_particles: bool)
signal debug_mode_changed(mode_idx: int)
signal auto_gestures_changed(enabled: bool)

var _status_label: Label = null
var _pet_buttons: Dictionary = {}
var _mode_buttons: Array[Button] = []
var _debug_buttons: Array[Button] = []

var _slider_opacity: HSlider = null
var _slider_spin: HSlider = null
var _slider_fresnel: HSlider = null
var _slider_normal: HSlider = null
var _slider_edge_opacity: HSlider = null
var _slider_bubble_bump: HSlider = null
var _slider_sun: HSlider = null
var _slider_tilt: HSlider = null
var _slider_scale: HSlider = null

var _chk_back: CheckBox = null
var _chk_pet: CheckBox = null
var _chk_front: CheckBox = null
var _chk_particles: CheckBox = null
var _chk_auto_sun: CheckBox = null
var _chk_orbit_guide: CheckBox = null
var _chk_auto_gestures: CheckBox = null


func _ready() -> void:
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 0.0
	anchor_bottom = 1.0
	offset_left = -332.0
	offset_right = -12.0
	offset_top = 12.0
	offset_bottom = -12.0
	_build_ui()


func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.14, 0.86)
	style.border_color = Color(0.32, 0.54, 0.88, 0.45)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 8)
	scroll.add_child(root)

	var title := Label.new()
	title.text = "3D PETS BUBBLE LAB"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0))
	root.add_child(title)

	var hint := Label.new()
	hint.text = "WASD/Drag: Mover · 1-6: Pet · Space/R/E/Q/F/Tab"
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.68, 0.74, 0.86))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(hint)

	_status_label = Label.new()
	_status_label.text = "Pet: Mochi · Modo: Órbita 3D"
	_status_label.add_theme_font_size_override("font_size", 12)
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.52))
	root.add_child(_status_label)

	root.add_child(HSeparator.new())
	root.add_child(_section_label("PET ACTIVA"))

	var pet_grid := GridContainer.new()
	pet_grid.columns = 3
	pet_grid.add_theme_constant_override("h_separation", 4)
	pet_grid.add_theme_constant_override("v_separation", 4)
	root.add_child(pet_grid)

	var pet_entries: Array[Dictionary] = [
		{"id": &"mochi", "label": "1. Mochi"},
		{"id": &"kuro", "label": "2. Kuro"},
		{"id": &"luna", "label": "3. Luna"},
		{"id": &"pip", "label": "4. Pip"},
		{"id": &"cosmo", "label": "5. Cosmo"},
		{"id": &"all", "label": "6. ALL 5"},
	]
	for item: Dictionary in pet_entries:
		var btn := Button.new()
		btn.text = str(item["label"])
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var pid: StringName = item["id"] as StringName
		btn.pressed.connect(func() -> void:
			pet_selected.emit(pid)
		)
		pet_grid.add_child(btn)
		_pet_buttons[pid] = btn

	root.add_child(_section_label("MODO DE PRUEBA"))
	var mode_grid := GridContainer.new()
	mode_grid.columns = 2
	mode_grid.add_theme_constant_override("h_separation", 4)
	mode_grid.add_theme_constant_override("v_separation", 4)
	root.add_child(mode_grid)

	var mode_names: Array[String] = ["Órbita 3D", "Closeup Hero", "Fetch Dash", "In-Game 64px"]
	for m_idx: int in range(mode_names.size()):
		var m_btn := Button.new()
		m_btn.text = mode_names[m_idx]
		m_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		m_btn.pressed.connect(func() -> void:
			mode_selected.emit(m_idx)
		)
		mode_grid.add_child(m_btn)
		_mode_buttons.append(m_btn)

	root.add_child(_section_label("GESTOS PLANOS & GIRO DESTELLO"))
	var emote_grid := GridContainer.new()
	emote_grid.columns = 3
	emote_grid.add_theme_constant_override("h_separation", 4)
	emote_grid.add_theme_constant_override("v_separation", 4)
	root.add_child(emote_grid)
	var gesture_items: Array[Array] = [
		[&"roll_360", "Voltereta 360°"],
		[&"wiggle", "Meneo"],
		[&"hop", "Saltito"],
		[&"curious_tilt", "Curioso"],
		[&"flip", "Giro Destello"],
		[&"dash", "Dash Pop"],
	]
	for em: Array in gesture_items:
		var e_btn := Button.new()
		e_btn.text = str(em[1])
		e_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var kind: StringName = em[0] as StringName
		e_btn.pressed.connect(func() -> void:
			emote_triggered.emit(kind)
		)
		emote_grid.add_child(e_btn)

	_chk_auto_gestures = _add_checkbox(root, "Gestos Auto (Zero-G)", true)
	_chk_auto_gestures.toggled.connect(func(on: bool) -> void:
		auto_gestures_changed.emit(on)
	)

	root.add_child(HSeparator.new())
	root.add_child(_section_label("SHADER & FÍSICA EN VIVO"))

	_slider_opacity = _add_slider(root, "Opacidad Burbuja", 0.0, 2.0, 1.0, 0.05)
	_slider_edge_opacity = _add_slider(root, "Opacidad Borde Tex", 0.0, 1.0, 0.78, 0.02)
	_slider_bubble_bump = _add_slider(root, "Relieve Normal Burbuja", 0.0, 1.0, 0.30, 0.02)
	_slider_spin = _add_slider(root, "Giro 3D Burbuja", 0.0, 3.0, 1.0, 0.05)
	_slider_fresnel = _add_slider(root, "Brillo Fresnel", 0.0, 2.0, 1.0, 0.05)
	_slider_normal = _add_slider(root, "Fuerza Normal Pet", 0.0, 2.0, 1.0, 0.05)
	_slider_sun = _add_slider(root, "Ángulo Sol (°)", 0.0, 360.0, 35.0, 1.0)
	_slider_tilt = _add_slider(root, "Inclinación Órbita (°)", -55.0, 55.0, 22.0, 1.0)
	_slider_scale = _add_slider(root, "Escala Burbuja", 0.5, 1.8, 1.0, 0.05)

	root.add_child(HSeparator.new())
	root.add_child(_section_label("CAPAS & DEBUG"))

	var chk_grid := GridContainer.new()
	chk_grid.columns = 2
	root.add_child(chk_grid)
	_chk_back = _add_checkbox(chk_grid, "Back Shell", true)
	_chk_pet = _add_checkbox(chk_grid, "Pet 2D", true)
	_chk_front = _add_checkbox(chk_grid, "Front Shell", true)
	_chk_particles = _add_checkbox(chk_grid, "Partículas", true)
	_chk_auto_sun = _add_checkbox(chk_grid, "Sol Auto", true)
	_chk_orbit_guide = _add_checkbox(chk_grid, "Guía Órbita", true)

	var dbg_row := HBoxContainer.new()
	dbg_row.add_theme_constant_override("separation", 4)
	root.add_child(dbg_row)
	var dbg_names: Array[String] = ["Final", "Flat", "Normal", "Light"]
	for d_idx: int in range(dbg_names.size()):
		var d_btn := Button.new()
		d_btn.text = dbg_names[d_idx]
		d_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		d_btn.pressed.connect(func() -> void:
			debug_mode_changed.emit(d_idx)
		)
		dbg_row.add_child(d_btn)
		_debug_buttons.append(d_btn)

	for s: HSlider in [_slider_opacity, _slider_edge_opacity, _slider_bubble_bump, _slider_spin, _slider_fresnel, _slider_normal]:
		s.value_changed.connect(func(_v: float) -> void:
			_emit_overrides()
		)
	_slider_sun.value_changed.connect(func(_v: float) -> void:
		sun_changed.emit(_slider_sun.value, _chk_auto_sun.button_pressed)
	)
	_chk_auto_sun.toggled.connect(func(_on: bool) -> void:
		sun_changed.emit(_slider_sun.value, _chk_auto_sun.button_pressed)
	)
	for s_orb: HSlider in [_slider_tilt, _slider_scale]:
		s_orb.value_changed.connect(func(_v: float) -> void:
			_emit_orbit_params()
		)
	_chk_orbit_guide.toggled.connect(func(_on: bool) -> void:
		_emit_orbit_params()
	)
	for c: CheckBox in [_chk_back, _chk_pet, _chk_front, _chk_particles]:
		c.toggled.connect(func(_on: bool) -> void:
			_emit_layers()
		)


func _section_label(text_str: String) -> Label:
	var lbl := Label.new()
	lbl.text = text_str
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.58, 0.78, 1.0))
	return lbl


func _add_slider(parent: Control, label_text: String, min_v: float, max_v: float, init_v: float, step_v: float) -> HSlider:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	parent.add_child(box)

	var top := HBoxContainer.new()
	box.add_child(top)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 11)
	top.add_child(lbl)

	var val_lbl := Label.new()
	val_lbl.text = "%.2f" % init_v
	val_lbl.add_theme_font_size_override("font_size", 11)
	val_lbl.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0))
	top.add_child(val_lbl)

	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step_v
	slider.value = init_v
	slider.value_changed.connect(func(val: float) -> void:
		val_lbl.text = "%.2f" % val
	)
	box.add_child(slider)
	return slider


func _add_checkbox(parent: Control, label_text: String, init_on: bool) -> CheckBox:
	var chk := CheckBox.new()
	chk.text = label_text
	chk.button_pressed = init_on
	chk.add_theme_font_size_override("font_size", 11)
	parent.add_child(chk)
	return chk


func _emit_overrides() -> void:
	overrides_changed.emit(
		_slider_opacity.value,
		_slider_spin.value,
		_slider_fresnel.value,
		_slider_normal.value,
		_slider_edge_opacity.value,
		_slider_bubble_bump.value
	)


func _emit_orbit_params() -> void:
	orbit_params_changed.emit(
		_slider_tilt.value,
		_slider_scale.value,
		_chk_orbit_guide.button_pressed
	)


func _emit_layers() -> void:
	layers_changed.emit(
		_chk_back.button_pressed,
		_chk_pet.button_pressed,
		_chk_front.button_pressed,
		_chk_particles.button_pressed
	)


func set_status_text(txt: String) -> void:
	if _status_label != null:
		_status_label.text = txt

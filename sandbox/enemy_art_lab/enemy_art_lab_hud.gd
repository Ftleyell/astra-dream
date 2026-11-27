extends CanvasLayer

## Interactive HUD + live 2.5D Inspector & Rig Calibration drawer for Enemy Workbench.

signal state_selected(state_idx: int)
signal bite_requested()
signal hit_flash_requested()
signal shatter_toggle_requested()
signal swarm_toggle_requested()
signal motion_mode_cycled()
signal variant_cycled()
signal backdrop_cycled()
signal auto_light_toggled()
signal bright_light_toggled()
signal lock_tilt_toggled()
signal reset_tilt_requested()
signal flat_compare_toggled(enabled: bool)
signal debug_mode_selected(mode: int)
signal cosmos_biome_requested()
signal cosmos_vantage_requested()
signal save_config_requested()
signal calibration_changed()
signal show_pivots_toggled(enabled: bool)
signal light_params_changed(angle_deg: float, light_z: float)
signal sequence_selected(seq_idx: int)
signal auto_reel_toggled()

const RigConfigScript = preload("res://data/enemies/schemas/enemy_scarab_rig_config.gd")
const FactionStyleScript = preload("res://data/enemies/schemas/enemy_faction_style.gd")

const DEBUG_LABELS: Array[String] = [
	"0 Final",
	"1 Albedo",
	"2 World N",
	"3 Height",
	"4 AO+Spec",
	"5 Ink SDF",
	"6 Out SDF",
	"7 FX Map",
]

var _status_label: Label = null
var _calib_panel: PanelContainer = null
var _btn_calib_toggle: Button = null
var _btn_auto_light: Button = null
var _btn_bright_light: Button = null
var _btn_lock_tilt: Button = null
var _btn_flat_ab: Button = null
var _btn_pivots: Button = null
var _btn_auto_reel: Button = null
var _seq_buttons: Array[Button] = []

var _rig_config: RigConfigScript = null
var _style_cfg: FactionStyleScript = null
var _light_angle_deg: float = -125.0
var _light_z: float = 0.58

var _sliders: Dictionary = {}
var _slider_val_labels: Dictionary = {}
var _slider_steps: Dictionary = {}
var _suppress_slider_signal: bool = false


func setup(cfg: RigConfigScript, style: FactionStyleScript) -> void:
	_rig_config = cfg
	_style_cfg = style
	_build_ui()
	sync_sliders_from_config()


func _build_ui() -> void:
	name = "EnemyWorkbenchHUD"
	layer = 50

	var top_panel := PanelContainer.new()
	top_panel.position = Vector2(14.0, 14.0)
	top_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.32, 0.92, 0.65, 0.60)))
	add_child(top_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	top_panel.add_child(vbox)

	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 12)
	_status_label.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0, 1.0))
	vbox.add_child(_status_label)

	var row_states := HBoxContainer.new()
	row_states.add_theme_constant_override("separation", 5)
	vbox.add_child(row_states)
	for pair: Array in [
		["[1] Idle", func() -> void: state_selected.emit(0)],
		["[2] Cruise", func() -> void: state_selected.emit(1)],
		["[3] Telegraph", func() -> void: state_selected.emit(2)],
		["[4] Lunge", func() -> void: state_selected.emit(3)],
		["[F] Bite!", func() -> void: bite_requested.emit()],
		["[H] Hit", func() -> void: hit_flash_requested.emit()],
		["[X] Shatter", func() -> void: shatter_toggle_requested.emit()],
	]:
		row_states.add_child(_make_btn(pair[0], pair[1], 80.0))

	var row_world := HBoxContainer.new()
	row_world.add_theme_constant_override("separation", 5)
	vbox.add_child(row_world)
	for pair: Array in [
		["[P] Mode", func() -> void: motion_mode_cycled.emit()],
		["[B] Backdrop", func() -> void: backdrop_cycled.emit()],
		["[V] Variant", func() -> void: variant_cycled.emit()],
		["[M] Swarm 6x", func() -> void: swarm_toggle_requested.emit()],
		["[T] CosmosLoc", func() -> void: cosmos_vantage_requested.emit()],
		["[K] Biome", func() -> void: cosmos_biome_requested.emit()],
	]:
		row_world.add_child(_make_btn(pair[0], pair[1], 92.0))

	var row_seq := HBoxContainer.new()
	row_seq.add_theme_constant_override("separation", 4)
	vbox.add_child(row_seq)
	_btn_auto_reel = _make_btn("[G] Reel: ON", func() -> void: auto_reel_toggled.emit(), 86.0)
	row_seq.add_child(_btn_auto_reel)
	_seq_buttons.clear()
	var seq_names: Array[String] = ["Patrulla", "Acecho+Mordida", "Enjambre 6x", "Solar/Eclipse", "Daño/Muerte"]
	for s_i: int in range(seq_names.size()):
		var seq_idx: int = s_i
		var sbtn: Button = _make_btn(seq_names[s_i], func() -> void: sequence_selected.emit(seq_idx), 88.0)
		row_seq.add_child(sbtn)
		_seq_buttons.append(sbtn)

	var row_xray := HBoxContainer.new()
	row_xray.add_theme_constant_override("separation", 4)
	vbox.add_child(row_xray)
	for i: int in range(DEBUG_LABELS.size()):
		var mode_idx: int = i
		row_xray.add_child(_make_btn(DEBUG_LABELS[i], func() -> void: debug_mode_selected.emit(mode_idx), 68.0))

	# Right-side 2.5D & Calibration Inspector Drawer (collapsed by default so Cosmic space stays clear)
	var right_box := VBoxContainer.new()
	right_box.anchor_left = 1.0
	right_box.anchor_right = 1.0
	right_box.offset_left = -346.0
	right_box.offset_top = 14.0
	right_box.offset_right = -14.0
	right_box.add_theme_constant_override("separation", 5)
	add_child(right_box)

	_btn_calib_toggle = _make_btn("Workbench 2.5D Inspector [C] ▼", _toggle_calib_panel, 316.0)
	right_box.add_child(_btn_calib_toggle)

	_calib_panel = PanelContainer.new()
	_calib_panel.visible = false
	_calib_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.68, 0.36, 0.96, 0.60)))
	right_box.add_child(_calib_panel)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(316.0, 520.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_calib_panel.add_child(scroll)

	var cal_v := VBoxContainer.new()
	cal_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cal_v.add_theme_constant_override("separation", 3)
	scroll.add_child(cal_v)

	# Quick Toggle Row inside Inspector
	var toggles_row := HBoxContainer.new()
	toggles_row.add_theme_constant_override("separation", 4)
	cal_v.add_child(toggles_row)

	_btn_auto_light = _make_btn("Light Orbit: ON [L]", func() -> void: auto_light_toggled.emit(), 148.0)
	_btn_bright_light = _make_btn("Luz Alta: OFF [E]", func() -> void: bright_light_toggled.emit(), 148.0)
	toggles_row.add_child(_btn_auto_light)
	toggles_row.add_child(_btn_bright_light)

	var toggles_row2 := HBoxContainer.new()
	toggles_row2.add_theme_constant_override("separation", 4)
	cal_v.add_child(toggles_row2)
	_btn_flat_ab = _make_btn("[Tab] A/B Flat", func() -> void:
		_btn_flat_ab.button_pressed = not _btn_flat_ab.button_pressed
		flat_compare_toggled.emit(_btn_flat_ab.button_pressed)
	, 76.0)
	_btn_flat_ab.toggle_mode = true
	_btn_pivots = _make_btn("Pivots", func() -> void:
		_btn_pivots.button_pressed = not _btn_pivots.button_pressed
		_btn_pivots.modulate = Color(1.0, 0.45, 0.95, 1.0) if _btn_pivots.button_pressed else Color(0.88, 0.92, 1.0, 1.0)
		show_pivots_toggled.emit(_btn_pivots.button_pressed)
	, 58.0)
	_btn_pivots.toggle_mode = true
	_btn_lock_tilt = _make_btn("Lock Tilt", func() -> void: lock_tilt_toggled.emit(), 76.0)
	var btn_reset_tilt := _make_btn("Reset [R]", func() -> void: reset_tilt_requested.emit(), 72.0)
	toggles_row2.add_child(_btn_flat_ab)
	toggles_row2.add_child(_btn_pivots)
	toggles_row2.add_child(_btn_lock_tilt)
	toggles_row2.add_child(btn_reset_tilt)

	_add_section_header(cal_v, "── Alineación Fina Élitros & Alas ──", Color(0.45, 0.98, 0.72, 1.0))
	_add_fine_slider(cal_v, "elytron_offset_x", "Élitros X px", -30.0, 60.0, 0.5)
	_add_fine_slider(cal_v, "elytron_offset_y", "Élitros Y px", -110.0, 15.0, 0.5)
	_add_fine_slider(cal_v, "elytron_hinge_u", "Bisagra U", 0.28, 0.64, 0.002)
	_add_fine_slider(cal_v, "elytron_hinge_v", "Bisagra V", 0.18, 0.52, 0.002)
	_add_fine_slider(cal_v, "elytron_closed_deg", "Cerrado°", -20.0, 20.0, 0.25)
	_add_fine_slider(cal_v, "elytron_scale", "Élitros Esc", 0.70, 1.40, 0.005)
	_add_fine_slider(cal_v, "wing_offset_x", "Alas X px", -25.0, 55.0, 0.5)
	_add_fine_slider(cal_v, "wing_offset_y", "Alas Y px", -95.0, 25.0, 0.5)

	_add_section_header(cal_v, "── Caparazón 3D, Alas & Luz ──", Color(0.75, 0.58, 1.0, 1.0))

	_add_slider(cal_v, "light_angle", "Light Angle°", -180.0, 180.0, 1.0)
	_add_slider(cal_v, "light_z", "Light Z Elev", 0.15, 1.50, 0.02)
	_add_slider(cal_v, "studio_exposure", "Luz Exposure", 0.70, 2.60, 0.05)
	_add_slider(cal_v, "ambient_fill_strength", "Ambient Fill", 0.0, 1.10, 0.02)
	_add_slider(cal_v, "green_bounce_strength", "Green Bounce", 0.0, 2.50, 0.05)
	_add_slider(cal_v, "relief_depth_px", "3D Relief px", 0.0, 55.0, 1.0)
	_add_slider(cal_v, "parallax_strength", "Parallax", 0.0, 0.07, 0.002)
	_add_slider(cal_v, "shell_thickness_px", "Shell Thick px", 0.0, 28.0, 0.5)
	_add_slider(cal_v, "core_light_strength", "Core Light", 0.0, 3.5, 0.05)
	_add_slider(cal_v, "iridescence_strength", "Iridescence", 0.0, 2.0, 0.05)
	_add_slider(cal_v, "specular_strength", "Specular", 0.0, 2.5, 0.05)
	_add_slider(cal_v, "cast_shadow_opacity", "Cast Shadow", 0.0, 1.0, 0.02)
	_add_slider(cal_v, "mandible_bite_deg", "Bite Angle°", 10.0, 50.0, 1.0)
	_add_slider(cal_v, "elytron_open_deg", "Elytron Open°", 10.0, 75.0, 1.0)
	_add_slider(cal_v, "elytron_open_pitch_deg", "Elytron 3D Pitch°", 0.0, 75.0, 1.0)
	_add_slider(cal_v, "elytron_open_roll_deg", "Elytron 3D Roll°", -45.0, 145.0, 1.0)
	_add_slider(cal_v, "elytron_dome_height_px", "Shell 3D Dome", 0.0, 50.0, 1.0)
	_add_slider(cal_v, "elytron_rim_thickness_px", "Elytron Rim px", 1.0, 14.0, 0.5)
	_add_slider(cal_v, "elytron_lift_px", "Elytron Lift", 0.0, 32.0, 1.0)
	_add_slider(cal_v, "wing_blur_max_deg", "Wing Blur°", 0.0, 38.0, 1.0)
	_add_slider(cal_v, "wing_shutter_speed", "Wing Shutter", 8.0, 65.0, 1.0)
	_add_slider(cal_v, "wing_wind_arcs_strength", "Wing Air Arcs", 0.0, 1.5, 0.05)
	_add_slider(cal_v, "display_scale", "Base Scale", 0.12, 0.70, 0.01)

	var save_btn := _make_btn("Guardar .tres (Config + Style)", func() -> void: save_config_requested.emit(), 268.0)
	save_btn.modulate = Color(0.55, 1.0, 0.72, 1.0)
	cal_v.add_child(save_btn)


func _toggle_calib_panel() -> void:
	if _calib_panel == null:
		return
	_calib_panel.visible = not _calib_panel.visible
	if _btn_calib_toggle != null:
		_btn_calib_toggle.text = "Workbench 2.5D Inspector [C] ▲" if _calib_panel.visible else "Workbench 2.5D Inspector [C] ▼"


func toggle_calibration() -> void:
	_toggle_calib_panel()


func set_toggle_labels(auto_light: bool, lock_tilt: bool, flat_mode: bool, bright_light: bool = false) -> void:
	if _btn_auto_light != null:
		_btn_auto_light.text = "Light Orbit: ON [L]" if auto_light else "Light Orbit: OFF [L]"
		_btn_auto_light.modulate = Color(0.55, 1.0, 0.75, 1.0) if auto_light else Color(0.85, 0.88, 0.95, 1.0)
	if _btn_bright_light != null:
		_btn_bright_light.text = "Luz Alta: ON [E]" if bright_light else "Luz Alta: OFF [E]"
		_btn_bright_light.modulate = Color(1.0, 0.94, 0.55, 1.0) if bright_light else Color(0.85, 0.88, 0.95, 1.0)
	if _btn_lock_tilt != null:
		_btn_lock_tilt.text = "Lock: ON" if lock_tilt else "Lock Tilt"
		_btn_lock_tilt.modulate = Color(1.0, 0.82, 0.42, 1.0) if lock_tilt else Color(0.85, 0.88, 0.95, 1.0)
	if _btn_flat_ab != null:
		_btn_flat_ab.button_pressed = flat_mode
		_btn_flat_ab.modulate = Color(1.0, 0.65, 0.45, 1.0) if flat_mode else Color(0.92, 0.95, 1.0, 1.0)


func set_sequence_ui(auto_reel: bool, active_seq: int, in_sequence_mode: bool) -> void:
	if _btn_auto_reel != null:
		_btn_auto_reel.text = "[G] Reel: ON" if auto_reel else "[G] Reel: OFF"
		_btn_auto_reel.modulate = Color(0.48, 1.0, 0.72, 1.0) if (auto_reel and in_sequence_mode) else Color(0.85, 0.88, 0.95, 1.0)
	for i: int in range(_seq_buttons.size()):
		var sb: Button = _seq_buttons[i]
		if sb != null:
			var is_act: bool = in_sequence_mode and i == active_seq
			sb.modulate = Color(0.45, 0.95, 1.0, 1.0) if is_act else Color(0.85, 0.88, 0.95, 1.0)


func set_light_ui(angle_deg: float, light_z: float) -> void:
	_light_angle_deg = wrapf(angle_deg, -180.0, 180.0)
	_light_z = light_z
	_suppress_slider_signal = true
	if _sliders.has("light_angle"):
		(_sliders["light_angle"] as HSlider).value = _light_angle_deg
		_update_val_label("light_angle", _light_angle_deg)
	if _sliders.has("light_z"):
		(_sliders["light_z"] as HSlider).value = _light_z
		_update_val_label("light_z", _light_z)
	_suppress_slider_signal = false


func _add_section_header(parent: VBoxContainer, title: String, col: Color) -> void:
	var lbl := Label.new()
	lbl.text = title
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", col)
	parent.add_child(lbl)


func _add_fine_slider(parent: VBoxContainer, key: String, title: String, min_v: float, max_v: float, step_v: float) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = title
	lbl.custom_minimum_size = Vector2(74.0, 0.0)
	lbl.add_theme_font_size_override("font_size", 11)
	row.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step_v
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.focus_mode = Control.FOCUS_NONE
	slider.value_changed.connect(func(val: float) -> void: _on_slider_changed(key, val))

	var btn_minus := _make_btn("-", func() -> void: slider.value = clampf(slider.value - step_v, min_v, max_v), 20.0)
	btn_minus.custom_minimum_size = Vector2(20.0, 20.0)
	var btn_plus := _make_btn("+", func() -> void: slider.value = clampf(slider.value + step_v, min_v, max_v), 20.0)
	btn_plus.custom_minimum_size = Vector2(20.0, 20.0)

	row.add_child(btn_minus)
	row.add_child(slider)
	row.add_child(btn_plus)

	var val_lbl := Label.new()
	val_lbl.custom_minimum_size = Vector2(46.0, 0.0)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_lbl.add_theme_font_size_override("font_size", 11)
	row.add_child(val_lbl)

	_sliders[key] = slider
	_slider_val_labels[key] = val_lbl
	_slider_steps[key] = step_v


func _add_slider(parent: VBoxContainer, key: String, title: String, min_v: float, max_v: float, step_v: float) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = title
	lbl.custom_minimum_size = Vector2(90.0, 0.0)
	lbl.add_theme_font_size_override("font_size", 11)
	row.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step_v
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.focus_mode = Control.FOCUS_NONE
	slider.value_changed.connect(func(val: float) -> void: _on_slider_changed(key, val))
	row.add_child(slider)

	var val_lbl := Label.new()
	val_lbl.custom_minimum_size = Vector2(44.0, 0.0)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_lbl.add_theme_font_size_override("font_size", 11)
	row.add_child(val_lbl)

	_sliders[key] = slider
	_slider_val_labels[key] = val_lbl
	_slider_steps[key] = step_v


func _on_slider_changed(key: String, val: float) -> void:
	if _suppress_slider_signal:
		return
	match key:
		"elytron_offset_x":
			if _rig_config != null: _rig_config.elytron_offset.x = val
		"elytron_offset_y":
			if _rig_config != null: _rig_config.elytron_offset.y = val
		"elytron_hinge_u":
			if _rig_config != null: _rig_config.elytron_hinge_uv.x = val
		"elytron_hinge_v":
			if _rig_config != null: _rig_config.elytron_hinge_uv.y = val
		"elytron_closed_deg":
			if _rig_config != null: _rig_config.elytron_closed_deg = val
		"elytron_scale":
			if _rig_config != null: _rig_config.elytron_scale = val
		"wing_offset_x":
			if _rig_config != null: _rig_config.wing_offset.x = val
		"wing_offset_y":
			if _rig_config != null: _rig_config.wing_offset.y = val
		"light_angle":
			_light_angle_deg = val
			_update_val_label(key, val)
			light_params_changed.emit(_light_angle_deg, _light_z)
			return
		"light_z":
			_light_z = val
			_update_val_label(key, val)
			light_params_changed.emit(_light_angle_deg, _light_z)
			return
		"studio_exposure":
			if _style_cfg != null: _style_cfg.studio_exposure = val
		"ambient_fill_strength":
			if _style_cfg != null: _style_cfg.ambient_fill_strength = val
		"green_bounce_strength":
			if _style_cfg != null: _style_cfg.green_bounce_strength = val
		"relief_depth_px":
			if _style_cfg != null: _style_cfg.relief_depth_px = val
		"parallax_strength":
			if _style_cfg != null: _style_cfg.parallax_strength = val
		"shell_thickness_px":
			if _style_cfg != null: _style_cfg.shell_thickness_px = val
		"core_light_strength":
			if _style_cfg != null: _style_cfg.core_light_strength = val
		"iridescence_strength":
			if _style_cfg != null: _style_cfg.iridescence_strength = val
		"specular_strength":
			if _style_cfg != null: _style_cfg.specular_strength = val
		"cast_shadow_opacity":
			if _style_cfg != null: _style_cfg.cast_shadow_opacity = val
		"mandible_bite_deg":
			if _rig_config != null: _rig_config.mandible_bite_deg = val
		"elytron_open_deg":
			if _rig_config != null: _rig_config.elytron_open_deg = val
		"elytron_open_pitch_deg":
			if _rig_config != null: _rig_config.elytron_open_pitch_deg = val
		"elytron_open_roll_deg":
			if _rig_config != null: _rig_config.elytron_open_roll_deg = val
		"elytron_dome_height_px":
			if _rig_config != null: _rig_config.elytron_dome_height_px = val
		"elytron_rim_thickness_px":
			if _rig_config != null: _rig_config.elytron_rim_thickness_px = val
		"elytron_lift_px":
			if _rig_config != null: _rig_config.elytron_lift_px = val
		"wing_blur_max_deg":
			if _rig_config != null: _rig_config.wing_blur_max_deg = val
		"wing_shutter_speed":
			if _rig_config != null: _rig_config.wing_shutter_speed = val
		"wing_wind_arcs_strength":
			if _rig_config != null: _rig_config.wing_wind_arcs_strength = val
		"display_scale":
			if _rig_config != null: _rig_config.display_scale = val
	_update_val_label(key, val)
	calibration_changed.emit()


func _update_val_label(key: String, val: float) -> void:
	var lbl: Label = _slider_val_labels.get(key) as Label
	if lbl != null:
		var st: float = float(_slider_steps.get(key, 0.1))
		if st <= 0.005:
			lbl.text = "%.3f" % val
		elif st <= 0.25 or absf(val) < 5.0:
			lbl.text = "%.2f" % val
		else:
			lbl.text = "%.1f" % val


func sync_sliders_from_config() -> void:
	_suppress_slider_signal = true
	var mapping: Dictionary = {
		"light_angle": _light_angle_deg,
		"light_z": _light_z,
	}
	if _style_cfg != null:
		mapping["studio_exposure"] = _style_cfg.studio_exposure
		mapping["ambient_fill_strength"] = _style_cfg.ambient_fill_strength
		mapping["green_bounce_strength"] = _style_cfg.green_bounce_strength
		mapping["relief_depth_px"] = _style_cfg.relief_depth_px
		mapping["parallax_strength"] = _style_cfg.parallax_strength
		mapping["shell_thickness_px"] = _style_cfg.shell_thickness_px
		mapping["core_light_strength"] = _style_cfg.core_light_strength
		mapping["iridescence_strength"] = _style_cfg.iridescence_strength
		mapping["specular_strength"] = _style_cfg.specular_strength
		mapping["cast_shadow_opacity"] = _style_cfg.cast_shadow_opacity
	if _rig_config != null:
		mapping["elytron_offset_x"] = _rig_config.elytron_offset.x
		mapping["elytron_offset_y"] = _rig_config.elytron_offset.y
		mapping["elytron_hinge_u"] = _rig_config.elytron_hinge_uv.x
		mapping["elytron_hinge_v"] = _rig_config.elytron_hinge_uv.y
		mapping["elytron_closed_deg"] = _rig_config.elytron_closed_deg
		mapping["elytron_scale"] = _rig_config.elytron_scale
		mapping["wing_offset_x"] = _rig_config.wing_offset.x
		mapping["wing_offset_y"] = _rig_config.wing_offset.y
		mapping["mandible_bite_deg"] = _rig_config.mandible_bite_deg
		mapping["elytron_open_deg"] = _rig_config.elytron_open_deg
		mapping["elytron_open_pitch_deg"] = _rig_config.elytron_open_pitch_deg
		mapping["elytron_open_roll_deg"] = _rig_config.elytron_open_roll_deg
		mapping["elytron_dome_height_px"] = _rig_config.elytron_dome_height_px
		mapping["elytron_rim_thickness_px"] = _rig_config.elytron_rim_thickness_px
		mapping["elytron_lift_px"] = _rig_config.elytron_lift_px
		mapping["wing_blur_max_deg"] = _rig_config.wing_blur_max_deg
		mapping["wing_shutter_speed"] = _rig_config.wing_shutter_speed
		mapping["wing_wind_arcs_strength"] = _rig_config.wing_wind_arcs_strength
		mapping["display_scale"] = _rig_config.display_scale

	for k: String in mapping.keys():
		var sl: HSlider = _sliders.get(k) as HSlider
		var v: float = float(mapping[k])
		if sl != null:
			sl.value = v
		_update_val_label(k, v)
	_suppress_slider_signal = false


func set_status_text(txt: String) -> void:
	if _status_label != null:
		_status_label.text = txt


func _make_btn(text_label: String, cb: Callable, min_w: float) -> Button:
	var btn := Button.new()
	btn.text = text_label
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(min_w, 24.0)
	btn.add_theme_font_size_override("font_size", 11)
	btn.pressed.connect(cb)
	return btn


func _make_panel_style(border_col: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.04, 0.08, 0.82)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = border_col
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(8)
	return sb

class_name HubArtLabHUD
extends CanvasLayer

## HUD de calibración en tiempo real para Hub Art Lab (ocultable con [H]).
## Permite probar modos de cámara, paletas de piloto, estados de estación (CALIBRATING/NEWLY_UNLOCKED/ONLINE),
## semillas del Cosmos en el Ventanal Norte y ajuste/guardado directo de HubArtLabConfig (.tres).

signal camera_mode_requested(mode: int)
signal accent_color_selected(color: Color)
signal station_state_cycled()
signal seed_apply_requested(seed_val: int)
signal seed_random_requested()
signal quality_tier_selected(tier: int)
signal shader_params_changed()
signal save_config_requested()
signal back_to_workbench_requested()

const ConfigScript = preload("res://sandbox/hub_art_lab/resources/hub_art_lab_config.gd")

const PILOT_SWATCHES: Array[Dictionary] = [
	{"label": "Val", "color": Color(0.95, 0.16, 0.34, 1.0)},
	{"label": "Nova", "color": Color(0.05, 0.90, 1.00, 1.0)},
	{"label": "Kira", "color": Color(1.00, 0.78, 0.12, 1.0)},
	{"label": "Selene", "color": Color(0.75, 0.38, 1.00, 1.0)},
	{"label": "Roxy", "color": Color(0.18, 0.95, 0.52, 1.0)},
]

var _panel: PanelContainer = null
var _status_label: Label = null
var _station_btn: Button = null
var _seed_input: LineEdit = null
var _config: ConfigScript = null
var _sliders: Dictionary = {}


func setup(p_config: ConfigScript) -> void:
	_config = p_config
	_build_ui()
	sync_from_config(p_config)


func toggle_visible() -> void:
	if _panel != null:
		_panel.visible = not _panel.visible


func update_status(mode_text: String, station_state_text: String, seed_val: int) -> void:
	if _status_label != null:
		_status_label.text = "Cámara: %s  |  Consola Der.: %s\nSeed Cosmos: %d  |  [WASD] Volar  [E] Interactuar  [H] HUD" % [mode_text, station_state_text, seed_val]
	if _station_btn != null:
		_station_btn.text = "Ciclar Consola Der. (%s)" % station_state_text
	if _seed_input != null and not _seed_input.has_focus():
		_seed_input.text = str(seed_val)


func sync_from_config(cfg: ConfigScript) -> void:
	if cfg == null:
		return
	_config = cfg
	_set_slider_val("ink_strength", cfg.ink_strength)
	_set_slider_val("crease_ink_strength", cfg.crease_ink_strength)
	_set_slider_val("outline_width", cfg.outline_width)
	_set_slider_val("emissive_boost", cfg.emissive_boost)
	_set_slider_val("bloom_intensity", cfg.bloom_intensity)


func _set_slider_val(key: String, val: float) -> void:
	if _sliders.has(key):
		var s: HSlider = _sliders[key] as HSlider
		if s != null:
			s.set_value_no_signal(val)


func _build_ui() -> void:
	if _panel != null:
		return

	var top_bar := PanelContainer.new()
	top_bar.position = Vector2(18.0, 14.0)
	top_bar.add_theme_stylebox_override("panel", _make_box_style(Color(0.035, 0.051, 0.102, 0.90), Color(0.91, 0.78, 0.44, 0.95)))
	add_child(top_bar)

	var top_vbox := VBoxContainer.new()
	top_bar.add_child(top_vbox)
	var title_lbl := Label.new()
	title_lbl.text = "ESTACIÓN ASTRAL v2 — VERTICAL SLICE (ASTRAL POP-INK)"
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.add_theme_color_override("font_color", Color(0.91, 0.78, 0.44, 1.0))
	top_vbox.add_child(title_lbl)

	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 12)
	_status_label.add_theme_color_override("font_color", Color(0.90, 0.93, 0.98, 1.0))
	top_vbox.add_child(_status_label)

	_panel = PanelContainer.new()
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.offset_left = -356.0
	_panel.offset_top = 14.0
	_panel.offset_right = -16.0
	_panel.add_theme_stylebox_override("panel", _make_box_style(Color(0.035, 0.051, 0.102, 0.90), Color(0.91, 0.78, 0.44, 0.95)))
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_panel.add_child(vbox)

	_add_section_header(vbox, "Cámara [1..4]")
	var cam_row := HBoxContainer.new()
	vbox.add_child(cam_row)
	var cam_specs: Array[Dictionary] = [
		{"label": "1 Free", "mode": 0},
		{"label": "2 Cápsula", "mode": 1},
		{"label": "3 Consola", "mode": 2},
		{"label": "4 Ignición", "mode": 3},
	]
	for spec: Dictionary in cam_specs:
		var b := Button.new()
		b.text = str(spec["label"])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var m: int = int(spec["mode"])
		b.pressed.connect(func() -> void: camera_mode_requested.emit(m))
		cam_row.add_child(b)

	_add_section_header(vbox, "Color Acento Piloto (Reactivo)")
	var swatch_row := HBoxContainer.new()
	vbox.add_child(swatch_row)
	for sw: Dictionary in PILOT_SWATCHES:
		var b := Button.new()
		b.text = str(sw["label"])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var col: Color = sw["color"] as Color
		b.add_theme_color_override("font_color", col)
		b.pressed.connect(func() -> void: accent_color_selected.emit(col))
		swatch_row.add_child(b)

	_add_section_header(vbox, "Progresión Antesala")
	_station_btn = Button.new()
	_station_btn.text = "Ciclar Consola Der."
	_station_btn.pressed.connect(func() -> void: station_state_cycled.emit())
	vbox.add_child(_station_btn)

	_add_section_header(vbox, "Ventanal Norte — Cosmos Seed & Calidad")
	var seed_row := HBoxContainer.new()
	vbox.add_child(seed_row)
	_seed_input = LineEdit.new()
	_seed_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_seed_input.placeholder_text = "Seed entero"
	seed_row.add_child(_seed_input)

	var apply_seed_btn := Button.new()
	apply_seed_btn.text = "Aplicar"
	apply_seed_btn.pressed.connect(_on_apply_seed_pressed)
	seed_row.add_child(apply_seed_btn)

	var rand_seed_btn := Button.new()
	rand_seed_btn.text = "Random"
	rand_seed_btn.pressed.connect(func() -> void: seed_random_requested.emit())
	seed_row.add_child(rand_seed_btn)

	var q_row := HBoxContainer.new()
	vbox.add_child(q_row)
	for qi: int in range(3):
		var qb := Button.new()
		qb.text = "Calidad %d" % qi
		qb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var q_val: int = qi
		qb.pressed.connect(func() -> void: quality_tier_selected.emit(q_val))
		q_row.add_child(qb)

	_add_section_header(vbox, "Calibración Shaders ArcSys 3D")
	_add_slider(vbox, "ink_strength", "Tinta SDF Suelo", 0.0, 1.0, 0.02)
	_add_slider(vbox, "crease_ink_strength", "Crease Ink Props", 0.0, 1.0, 0.02)
	_add_slider(vbox, "outline_width", "Contorno 3D", 0.006, 0.06, 0.002)
	_add_slider(vbox, "emissive_boost", "Emisión HDR", 0.3, 3.0, 0.05)
	_add_slider(vbox, "bloom_intensity", "AgX Bloom", 0.0, 2.0, 0.05)

	var action_row := HBoxContainer.new()
	vbox.add_child(action_row)
	var save_btn := Button.new()
	save_btn.text = "Guardar .tres"
	save_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_btn.pressed.connect(func() -> void: save_config_requested.emit())
	action_row.add_child(save_btn)

	var back_btn := Button.new()
	back_btn.text = "WorkbenchHub"
	back_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back_btn.pressed.connect(func() -> void: back_to_workbench_requested.emit())
	action_row.add_child(back_btn)


func _on_apply_seed_pressed() -> void:
	if _seed_input == null:
		return
	var txt: String = _seed_input.text.strip_edges()
	var val: int = int(txt) if txt.is_valid_int() else abs(txt.hash())
	seed_apply_requested.emit(maxi(1, val & 0x7FFFFFFF))


func _add_section_header(parent: VBoxContainer, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.91, 0.78, 0.44, 1.0))
	parent.add_child(lbl)


func _add_slider(parent: VBoxContainer, prop_key: String, title: String, min_v: float, max_v: float, step_v: float) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var lbl := Label.new()
	lbl.text = title
	lbl.custom_minimum_size = Vector2(128.0, 0.0)
	lbl.add_theme_font_size_override("font_size", 11)
	row.add_child(lbl)

	var slider := HSlider.new()
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step_v
	slider.value_changed.connect(func(v: float) -> void:
		if _config != null:
			_config.set(prop_key, v)
		shader_params_changed.emit()
	)
	row.add_child(slider)
	_sliders[prop_key] = slider


func _make_box_style(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_content_margin_all(10.0)
	return sb

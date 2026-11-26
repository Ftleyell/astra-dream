class_name HubLocomotionLabHud
extends RefCounted
## HUD modular para el Hub 3D Locomotion Lab: barra superior de telemetría y panel derecho scrollable de calibración.

const GroundedConfigScript = preload("res://data/pilots/schemas/pilot_grounded_locomotion_config.gd")

const SLIDER_SECTIONS: Array[Dictionary] = [
	{
		"title": "A. ARCO, DISTANCIA Y REBOTE",
		"items": [
			{"key": "glide_stride_length_m", "label": "Distancia Ciclo (2 saltos m)", "min": 2.4, "max": 12.0, "step": 0.1, "rad": false},
			{"key": "glide_contact_duty", "label": "Tiempo Contacto/Rebote %", "min": 0.08, "max": 0.42, "step": 0.01, "rad": false},
			{"key": "glide_arc_height_rig_px", "label": "Altura Arco 2D (rig px)", "min": 12.0, "max": 90.0, "step": 1.0, "rad": false},
			{"key": "glide_3d_lift_m", "label": "Elevación 3D Sombra/Sprite (m)", "min": 0.0, "max": 0.60, "step": 0.01, "rad": false},
			{"key": "glide_arc_hang_power", "label": "Flotación Ápice (<1 = más flote)", "min": 0.45, "max": 1.30, "step": 0.02, "rad": false},
			{"key": "glide_arc_peak_shift", "label": "Ápice Adelantado (u)", "min": 0.28, "max": 0.60, "step": 0.01, "rad": false},
			{"key": "glide_crouch_dip_rig_px", "label": "Hundimiento Pelvis Rebote (px)", "min": 0.0, "max": 14.0, "step": 0.25, "rad": false},
			{"key": "glide_squash_amount", "label": "Squash Aterrizaje", "min": 0.0, "max": 0.12, "step": 0.002, "rad": false},
			{"key": "glide_stretch_amount", "label": "Stretch Impulso", "min": 0.0, "max": 0.10, "step": 0.002, "rad": false},
			{"key": "hub_move_speed", "label": "Velocidad Hub (m/s)", "min": 3.0, "max": 10.0, "step": 0.1, "rad": false},
		],
	},
	{
		"title": "B. PIERNAS (JETÉ GRÁCIL, PUNTA Y RODILLAS)",
		"items": [
			{"key": "glide_lead_thigh_fwd_rad", "label": "Muslo Líder Adelante", "min": 0.05, "max": 0.60, "step": 0.01, "rad": true},
			{"key": "glide_lead_knee_poise_rad", "label": "Rodilla Líder Poised", "min": 0.05, "max": 0.70, "step": 0.01, "rad": true},
			{"key": "glide_trail_thigh_back_rad", "label": "Muslo Trasero Extensión", "min": 0.05, "max": 0.65, "step": 0.01, "rad": true},
			{"key": "glide_trail_knee_sweep_rad", "label": "Rodilla Trasera Sweep", "min": 0.0, "max": 0.60, "step": 0.01, "rad": true},
			{"key": "glide_ankle_point_rad", "label": "Empeine en Punta (Vuelo)", "min": 0.0, "max": 0.55, "step": 0.01, "rad": true},
			{"key": "glide_ankle_reach_rad", "label": "Tobillo Alcance Caída", "min": -0.30, "max": 0.20, "step": 0.01, "rad": true},
			{"key": "glide_rebound_knee_rad", "label": "Flexión Rodillas Rebote", "min": 0.05, "max": 0.55, "step": 0.01, "rad": true},
			{"key": "glide_25d_leg_depth_amp", "label": "Profundidad 2.5D Piernas", "min": 0.0, "max": 0.55, "step": 0.01, "rad": false},
		],
	},
	{
		"title": "C. TORSO, BRAZOS Y CABELLO",
		"items": [
			{"key": "glide_forward_lean_rad", "label": "Inclinación Aerodinámica", "min": 0.0, "max": 0.20, "step": 0.005, "rad": true},
			{"key": "glide_torso_bank_rad", "label": "Balanceo Lateral (Bank)", "min": 0.0, "max": 0.08, "step": 0.002, "rad": true},
			{"key": "glide_arm_grace_rad", "label": "Amplitud Brazos Grácil", "min": 0.05, "max": 0.55, "step": 0.01, "rad": true},
			{"key": "glide_arm_elbow_soft_rad", "label": "Suavidad Codo", "min": 0.0, "max": 0.50, "step": 0.01, "rad": true},
			{"key": "glide_hair_trail_px", "label": "Arrastre Cabello (px)", "min": 0.0, "max": 12.0, "step": 0.2, "rad": false},
		],
	},
	{
		"title": "D. RIPPLE ASTRAL DE REBOTE Y SOMBRAS",
		"items": [
			{"key": "ripple_outer_radius_m", "label": "Radio Onda Exterior (m)", "min": 0.30, "max": 1.60, "step": 0.02, "rad": false},
			{"key": "ripple_inner_radius_m", "label": "Radio Onda Interior (m)", "min": 0.15, "max": 1.00, "step": 0.02, "rad": false},
			{"key": "ripple_duration_sec", "label": "Duración Ripple (s)", "min": 0.18, "max": 1.00, "step": 0.02, "rad": false},
			{"key": "ripple_intensity", "label": "Intensidad Luminosa", "min": 0.20, "max": 2.40, "step": 0.05, "rad": false},
			{"key": "hop_shadow_shrink_ratio", "label": "Contracción Sombra Aire", "min": 0.0, "max": 0.75, "step": 0.02, "rad": false},
			{"key": "hop_shadow_alpha_fade", "label": "Atenuación Sombra Aire", "min": 0.0, "max": 0.85, "step": 0.02, "rad": false},
		],
	},
]

var _canvas_layer: CanvasLayer = null
var _right_panel: PanelContainer = null
var _top_bar: PanelContainer = null
var _telemetry_lbl: Label = null
var _feedback_lbl: Label = null
var _cam_opt: OptionButton = null
var _motion_opt: OptionButton = null
var _gait_opt: OptionButton = null
var _slowmo_opt: OptionButton = null
var _skin_opt: OptionButton = null
var _treadmill_dir_opt: OptionButton = null
var _scrub_chk: CheckBox = null
var _scrub_slider: HSlider = null
var _scrub_val_lbl: Label = null
var _ripple_chk: CheckBox = null
var _ripple_accent_chk: CheckBox = null
var _spark_slider: HSlider = null
var _spark_val_lbl: Label = null
var _slider_rows: Dictionary = {}


func build(
	host: Node,
	cfg: GroundedConfigScript,
	skin_names: Array[String],
	callbacks: Dictionary
) -> void:
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.name = "LocomotionLabHUDLayer"
	_canvas_layer.layer = 10
	host.add_child(_canvas_layer)

	_build_top_bar(callbacks)
	_build_right_panel(cfg, skin_names, callbacks)
	sync_from_config(cfg)


func toggle_panel_visibility() -> void:
	if _right_panel != null:
		_right_panel.visible = not _right_panel.visible


func set_feedback(msg: String, is_ok: bool = true) -> void:
	if _feedback_lbl == null:
		return
	_feedback_lbl.text = msg
	_feedback_lbl.add_theme_color_override(
		"font_color",
		Color(0.45, 0.96, 0.68, 1.0) if is_ok else Color(1.0, 0.52, 0.52, 1.0)
	)


func update_telemetry(info: Dictionary) -> void:
	if _telemetry_lbl == null:
		return
	var ph_deg: float = rad_to_deg(float(info.get("phase", 0.0)))
	var sub: String = str(info.get("subphase", "IDLE"))
	var lift: float = float(info.get("pelvis_lift_norm", 0.0))
	var lead_s: float = float(info.get("lead_side", 1.0))
	var pie_txt: String = "L" if lead_s >= 0.0 else "R"
	var view_k: String = str(info.get("view_key", "s")).to_upper()
	var gait_id: int = int(info.get("gait_style", 2))
	var gait_txt: String = "ASTRAL GLIDE" if gait_id == 2 else ("MOON HOP" if gait_id == 1 else "WALK")
	_telemetry_lbl.text = "Modo: %s  |  Vista: %s  |  Fase: %3.0f° (%s)  |  Pie Líder: %s  |  Lift: %.2f" % [
		gait_txt, view_k, ph_deg, sub, pie_txt, lift
	]


func sync_controls_state(
	cam_idx: int,
	motion_idx: int,
	gait_idx: int,
	slowmo_idx: int,
	scrub_enabled: bool,
	scrub_deg: float
) -> void:
	if _cam_opt != null:
		_cam_opt.select(clampi(cam_idx, 0, _cam_opt.item_count - 1))
	if _motion_opt != null:
		_motion_opt.select(clampi(motion_idx, 0, _motion_opt.item_count - 1))
	if _gait_opt != null:
		_gait_opt.select(clampi(gait_idx, 0, _gait_opt.item_count - 1))
	if _slowmo_opt != null:
		_slowmo_opt.select(clampi(slowmo_idx, 0, _slowmo_opt.item_count - 1))
	if _scrub_chk != null:
		_scrub_chk.set_pressed_no_signal(scrub_enabled)
	if _scrub_slider != null:
		_scrub_slider.set_value_no_signal(scrub_deg)
	if _scrub_val_lbl != null:
		_scrub_val_lbl.text = "%3.0f°" % scrub_deg


func sync_from_config(cfg: GroundedConfigScript) -> void:
	if cfg == null:
		return
	if _gait_opt != null:
		_gait_opt.select(clampi(cfg.gait_style, 0, _gait_opt.item_count - 1))
	if _ripple_chk != null:
		_ripple_chk.set_pressed_no_signal(cfg.ripple_enabled)
	if _ripple_accent_chk != null:
		_ripple_accent_chk.set_pressed_no_signal(cfg.ripple_use_skin_accent)
	if _spark_slider != null:
		_spark_slider.set_value_no_signal(float(cfg.ripple_spark_count))
	if _spark_val_lbl != null:
		_spark_val_lbl.text = "%d" % cfg.ripple_spark_count
	for key_v: Variant in _slider_rows.keys():
		var key: String = str(key_v)
		if not (key in cfg):
			continue
		var row: Dictionary = _slider_rows[key] as Dictionary
		var spec: Dictionary = row["spec"] as Dictionary
		var val: float = float(cfg.get(key))
		(row["slider"] as HSlider).set_value_no_signal(val)
		(row["val_lbl"] as Label).text = _format_value(val, spec)


func _build_top_bar(callbacks: Dictionary) -> void:
	_top_bar = PanelContainer.new()
	_top_bar.anchor_left = 0.0
	_top_bar.anchor_top = 0.0
	_top_bar.anchor_right = 1.0
	_top_bar.offset_left = 12.0
	_top_bar.offset_top = 10.0
	_top_bar.offset_right = -364.0
	_top_bar.offset_bottom = 66.0

	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.04, 0.06, 0.12, 0.86)
	st.border_color = Color(0.28, 0.88, 1.0, 0.45)
	st.set_border_width_all(1)
	st.set_corner_radius_all(8)
	st.set_content_margin_all(8)
	_top_bar.add_theme_stylebox_override("panel", st)
	_canvas_layer.add_child(_top_bar)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	_top_bar.add_child(vbox)

	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 10)
	vbox.add_child(row1)

	var back_btn := Button.new()
	back_btn.text = "← WorkbenchHub [Esc]"
	back_btn.focus_mode = Control.FOCUS_NONE
	back_btn.pressed.connect(func() -> void:
		var cb: Callable = callbacks.get("on_back", Callable())
		if cb.is_valid():
			cb.call()
	)
	row1.add_child(back_btn)

	var title := Label.new()
	title.text = "HUB 3D LOCOMOTION LAB — VALENTINA V2"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.35, 0.94, 1.0, 1.0))
	row1.add_child(title)

	var help_lbl := Label.new()
	help_lbl.text = "[WASD] Mover · [1-4] Cám · [M] Slow-Mo · [G] Estilo · [Space] Scrub · [R] Centro · [H] HUD"
	help_lbl.add_theme_font_size_override("font_size", 11)
	help_lbl.add_theme_color_override("font_color", Color(0.75, 0.85, 0.96, 0.88))
	row1.add_child(help_lbl)

	_telemetry_lbl = Label.new()
	_telemetry_lbl.text = "Iniciando telemetría..."
	_telemetry_lbl.add_theme_font_size_override("font_size", 12)
	_telemetry_lbl.add_theme_color_override("font_color", Color(0.95, 0.86, 0.55, 1.0))
	vbox.add_child(_telemetry_lbl)


func _build_right_panel(cfg: GroundedConfigScript, skin_names: Array[String], callbacks: Dictionary) -> void:
	_right_panel = PanelContainer.new()
	_right_panel.anchor_left = 1.0
	_right_panel.anchor_top = 0.0
	_right_panel.anchor_right = 1.0
	_right_panel.anchor_bottom = 1.0
	_right_panel.offset_left = -352.0
	_right_panel.offset_top = 10.0
	_right_panel.offset_right = -10.0
	_right_panel.offset_bottom = -10.0

	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.04, 0.055, 0.11, 0.90)
	st.border_color = Color(0.85, 0.35, 0.72, 0.55)
	st.set_border_width_all(1)
	st.set_corner_radius_all(8)
	st.set_content_margin_all(10)
	_right_panel.add_theme_stylebox_override("panel", st)
	_canvas_layer.add_child(_right_panel)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_right_panel.add_child(scroll)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	scroll.add_child(box)

	_add_header(box, "CONTROL DE CÁMARA Y SIMULACIÓN")

	_cam_opt = _add_option_row(box, "Cámara [1..4]:", [
		"1: Hub 3D Real (FOV 26° / -46°)",
		"2: Close-Up 3/4 (-30°)",
		"3: Perfil Lateral (-11°)",
		"4: Cenital (-62°)",
	], callbacks.get("on_cam_changed", Callable()) as Callable)

	_motion_opt = _add_option_row(box, "Circuito:", [
		"0: Libre (WASD)",
		"1: Auto 8-Dir Octágono",
		"2: Auto Perfil (E ↔ W)",
		"3: Auto Frontal (S ↔ N)",
		"4: Treadmill + Scrub",
	], callbacks.get("on_motion_changed", Callable()) as Callable)

	_gait_opt = _add_option_row(box, "Estilo [G]:", [
		"0: Walk Stride (Base)",
		"1: Moon Hop (Legacy)",
		"2: Astral Glide-Hop (Nuevo)",
	], callbacks.get("on_gait_changed", Callable()) as Callable)

	_slowmo_opt = _add_option_row(box, "Slow-Mo [M]:", [
		"1.00× (Normal)",
		"0.50× (Medio)",
		"0.25× (Detalle)",
		"0.12× (Frame-by-Frame)",
	], callbacks.get("on_slowmo_changed", Callable()) as Callable)

	if not skin_names.is_empty():
		_skin_opt = _add_option_row(box, "Skin Valentina:", skin_names, callbacks.get("on_skin_changed", Callable()) as Callable)

	_treadmill_dir_opt = _add_option_row(box, "Vista Treadmill:", [
		"E (Perfil Der.)", "SE (3/4 Der.)", "S (Frontal)", "SW (3/4 Izq.)",
		"W (Perfil Izq.)", "NW (Espalda Izq.)", "N (Espalda)", "NE (Espalda Der.)",
	], callbacks.get("on_treadmill_dir_changed", Callable()) as Callable)

	_scrub_chk = CheckBox.new()
	_scrub_chk.text = "Congelar & Scrub Manual de Fase [Space]"
	_scrub_chk.focus_mode = Control.FOCUS_NONE
	_scrub_chk.toggled.connect(func(v: bool) -> void:
		var cb: Callable = callbacks.get("on_scrub_toggled", Callable())
		if cb.is_valid():
			cb.call(v)
	)
	box.add_child(_scrub_chk)

	var scrub_row := HBoxContainer.new()
	box.add_child(scrub_row)
	var scrub_lbl := Label.new()
	scrub_lbl.text = "Fase Ciclo (0°..360°)"
	scrub_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scrub_lbl.add_theme_font_size_override("font_size", 11)
	scrub_row.add_child(scrub_lbl)
	_scrub_val_lbl = Label.new()
	_scrub_val_lbl.text = "0°"
	_scrub_val_lbl.add_theme_font_size_override("font_size", 11)
	scrub_row.add_child(_scrub_val_lbl)

	_scrub_slider = HSlider.new()
	_scrub_slider.min_value = 0.0
	_scrub_slider.max_value = 360.0
	_scrub_slider.step = 1.0
	_scrub_slider.focus_mode = Control.FOCUS_NONE
	_scrub_slider.value_changed.connect(func(deg: float) -> void:
		if _scrub_val_lbl != null:
			_scrub_val_lbl.text = "%3.0f°" % deg
		var cb: Callable = callbacks.get("on_scrub_changed", Callable())
		if cb.is_valid():
			cb.call(deg)
	)
	box.add_child(_scrub_slider)

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 6)
	box.add_child(action_row)

	var ripple_btn := Button.new()
	ripple_btn.text = "💥 Disparar Ripple"
	ripple_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ripple_btn.focus_mode = Control.FOCUS_NONE
	ripple_btn.pressed.connect(func() -> void:
		var cb: Callable = callbacks.get("on_test_ripple", Callable())
		if cb.is_valid():
			cb.call()
	)
	action_row.add_child(ripple_btn)

	var center_btn := Button.new()
	center_btn.text = "⌖ Centro [R]"
	center_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_btn.focus_mode = Control.FOCUS_NONE
	center_btn.pressed.connect(func() -> void:
		var cb: Callable = callbacks.get("on_recenter", Callable())
		if cb.is_valid():
			cb.call()
	)
	action_row.add_child(center_btn)

	for sec: Dictionary in SLIDER_SECTIONS:
		_add_header(box, str(sec["title"]))
		var items: Array = sec["items"] as Array
		for spec_v: Variant in items:
			var spec: Dictionary = spec_v as Dictionary
			_add_slider_row(box, spec, callbacks.get("on_param_changed", Callable()) as Callable)

	_ripple_chk = CheckBox.new()
	_ripple_chk.text = "Ripple Astral Activo al Rebotar"
	_ripple_chk.focus_mode = Control.FOCUS_NONE
	_ripple_chk.toggled.connect(func(v: bool) -> void:
		var cb: Callable = callbacks.get("on_bool_changed", Callable())
		if cb.is_valid():
			cb.call("ripple_enabled", v)
	)
	box.add_child(_ripple_chk)

	_ripple_accent_chk = CheckBox.new()
	_ripple_accent_chk.text = "Usar Color Acento del Skin Activo"
	_ripple_accent_chk.focus_mode = Control.FOCUS_NONE
	_ripple_accent_chk.toggled.connect(func(v: bool) -> void:
		var cb: Callable = callbacks.get("on_bool_changed", Callable())
		if cb.is_valid():
			cb.call("ripple_use_skin_accent", v)
	)
	box.add_child(_ripple_accent_chk)

	var sp_row := HBoxContainer.new()
	box.add_child(sp_row)
	var sp_lbl := Label.new()
	sp_lbl.text = "Chispas de Impulso (0..8)"
	sp_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp_lbl.add_theme_font_size_override("font_size", 11)
	sp_row.add_child(sp_lbl)
	_spark_val_lbl = Label.new()
	_spark_val_lbl.text = "%d" % (cfg.ripple_spark_count if cfg != null else 5)
	_spark_val_lbl.add_theme_font_size_override("font_size", 11)
	sp_row.add_child(_spark_val_lbl)

	_spark_slider = HSlider.new()
	_spark_slider.min_value = 0.0
	_spark_slider.max_value = 8.0
	_spark_slider.step = 1.0
	_spark_slider.focus_mode = Control.FOCUS_NONE
	_spark_slider.value_changed.connect(func(val: float) -> void:
		var cnt: int = int(round(val))
		if _spark_val_lbl != null:
			_spark_val_lbl.text = "%d" % cnt
		var cb: Callable = callbacks.get("on_int_changed", Callable())
		if cb.is_valid():
			cb.call("ripple_spark_count", cnt)
	)
	box.add_child(_spark_slider)

	_add_header(box, "PERSISTENCIA (.TRES PRODUCCIÓN)")
	var io_row := HBoxContainer.new()
	io_row.add_theme_constant_override("separation", 6)
	box.add_child(io_row)

	var save_btn := Button.new()
	save_btn.text = "💾 Guardar .tres"
	save_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_btn.focus_mode = Control.FOCUS_NONE
	save_btn.pressed.connect(func() -> void:
		var cb: Callable = callbacks.get("on_save", Callable())
		if cb.is_valid():
			cb.call()
	)
	io_row.add_child(save_btn)

	var reload_btn := Button.new()
	reload_btn.text = "↺ Recargar"
	reload_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reload_btn.focus_mode = Control.FOCUS_NONE
	reload_btn.pressed.connect(func() -> void:
		var cb: Callable = callbacks.get("on_reload", Callable())
		if cb.is_valid():
			cb.call()
	)
	io_row.add_child(reload_btn)

	var reset_btn := Button.new()
	reset_btn.text = "⚡ Restaurar Defaults Astral Glide-Hop"
	reset_btn.focus_mode = Control.FOCUS_NONE
	reset_btn.pressed.connect(func() -> void:
		var cb: Callable = callbacks.get("on_reset", Callable())
		if cb.is_valid():
			cb.call()
	)
	box.add_child(reset_btn)

	_feedback_lbl = Label.new()
	_feedback_lbl.text = ""
	_feedback_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feedback_lbl.add_theme_font_size_override("font_size", 11)
	box.add_child(_feedback_lbl)


func _add_option_row(parent: VBoxContainer, label_txt: String, items: Array[String], on_sel: Callable) -> OptionButton:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = label_txt
	lbl.custom_minimum_size = Vector2(96.0, 0.0)
	lbl.add_theme_font_size_override("font_size", 11)
	row.add_child(lbl)

	var opt := OptionButton.new()
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt.focus_mode = Control.FOCUS_NONE
	for i: int in range(items.size()):
		opt.add_item(items[i], i)
	opt.item_selected.connect(func(idx: int) -> void:
		if on_sel.is_valid():
			on_sel.call(idx)
	)
	row.add_child(opt)
	return opt


func _add_slider_row(parent: VBoxContainer, spec: Dictionary, on_change: Callable) -> void:
	var key: String = str(spec["key"])
	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", 1)
	parent.add_child(container)

	var top_row := HBoxContainer.new()
	container.add_child(top_row)

	var lbl := Label.new()
	lbl.text = str(spec["label"])
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 11)
	top_row.add_child(lbl)

	var val_lbl := Label.new()
	val_lbl.text = "0.00"
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_lbl.add_theme_font_size_override("font_size", 11)
	val_lbl.add_theme_color_override("font_color", Color(0.75, 0.90, 1.0, 0.95))
	top_row.add_child(val_lbl)

	var slider := HSlider.new()
	slider.min_value = float(spec["min"])
	slider.max_value = float(spec["max"])
	slider.step = float(spec["step"])
	slider.focus_mode = Control.FOCUS_NONE
	slider.custom_minimum_size = Vector2(0.0, 16.0)
	slider.value_changed.connect(func(val: float) -> void:
		val_lbl.text = _format_value(val, spec)
		if on_change.is_valid():
			on_change.call(key, val)
	)
	container.add_child(slider)

	_slider_rows[key] = {
		"slider": slider,
		"val_lbl": val_lbl,
		"spec": spec,
	}


func _format_value(val: float, spec: Dictionary) -> String:
	if bool(spec.get("rad", false)):
		return "%.3f (%.1f°)" % [val, rad_to_deg(val)]
	return "%.2f" % val


func _add_header(parent: VBoxContainer, title_text: String) -> void:
	parent.add_child(HSeparator.new())
	var lbl := Label.new()
	lbl.text = title_text
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.55, 0.90, 1.0, 1.0))
	parent.add_child(lbl)

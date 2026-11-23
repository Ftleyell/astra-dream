class_name ValentinaFaceLabHud
extends RefCounted
## HUD lateral en 4 pestañas ([1. Ojos/Expr], [2. 2.5D/Cuello], [3. Pelo/HUD], [4. Vista/Debug])
## para el laboratorio independiente del rig facial de Valentina v2.

const FaceConfigScript = preload("res://data/pilots/schemas/pilot_face_anim_config.gd")

const SLIDERS_TAB_1: Array[Dictionary] = [
	{"key": "eye_look_max_px", "label": "Rango Mirada Iris (px)", "min": 0.0, "max": 4.2, "step": 0.05},
	{"key": "eye_saccade_speed", "label": "Velocidad Sacadas", "min": 0.4, "max": 6.0, "step": 0.1},
	{"key": "blink_interval_sec", "label": "Intervalo Parpadeo (s)", "min": 1.0, "max": 8.0, "step": 0.1},
	{"key": "blink_duration_sec", "label": "Duración Parpadeo (s)", "min": 0.08, "max": 0.40, "step": 0.01},
	{"key": "double_blink_chance", "label": "Prob. Doble Parpadeo", "min": 0.0, "max": 1.0, "step": 0.05},
	{"key": "squint_amount", "label": "Entrecerrado (Squint)", "min": 0.0, "max": 1.0, "step": 0.02},
	{"key": "brow_lift_px", "label": "Cejas Altura Offset (px)", "min": -3.0, "max": 3.0, "step": 0.05},
	{"key": "brow_furrow", "label": "Cejas Inclinación / Ceño", "min": -0.08, "max": 0.08, "step": 0.002},
	{"key": "mouth_open", "label": "Boca Apertura Offset", "min": 0.0, "max": 1.0, "step": 0.02},
	{"key": "mouth_smile", "label": "Boca Sonrisa / Mueca", "min": -1.0, "max": 1.0, "step": 0.04},
	{"key": "comms_talk_speed_hz", "label": "Comms Velocidad (Hz)", "min": 2.0, "max": 12.0, "step": 0.25},
	{"key": "comms_talk_amp", "label": "Comms Amplitud", "min": 0.1, "max": 1.0, "step": 0.02},
	{"key": "iris_scale_offset", "label": "Dilatación Pupila Offset", "min": -0.25, "max": 0.25, "step": 0.01},
	{"key": "eye_highlight_strength", "label": "Brillo Especular Ojo", "min": 0.0, "max": 1.5, "step": 0.05},
	{"key": "eye_lid_shadow_strength", "label": "Sombra Fija Párpado Sup.", "min": 0.0, "max": 1.5, "step": 0.05},
	{"key": "eye_far_clarity", "label": "Nitidez Ojo a Distancia", "min": 0.0, "max": 1.0, "step": 0.05},
	{"key": "eye_combat_glow_strength", "label": "Micro-Glow Iris Táctico", "min": 0.0, "max": 1.5, "step": 0.05},
]

const SLIDERS_TAB_2: Array[Dictionary] = [
	{"key": "neck_weld_strength", "label": "Soldadura Base Cuello", "min": 0.0, "max": 1.0, "step": 0.02},
	{"key": "cursor_head_tilt_deg", "label": "Inclinación Cursor (°)", "min": 0.0, "max": 12.0, "step": 0.25},
	{"key": "neck_idle_nod_px", "label": "Respiración Cabeceo (du)", "min": 0.0, "max": 4.0, "step": 0.05},
	{"key": "neck_idle_freq_rad", "label": "Frecuencia Cabeceo (rad/s)", "min": 0.4, "max": 4.0, "step": 0.05},
	{"key": "chin_shadow_strength", "label": "Sombra Mentón Cuello", "min": 0.0, "max": 1.5, "step": 0.04},
	{"key": "face_parallax_px", "label": "Parallax 2.5D Live2D (px)", "min": 0.0, "max": 9.0, "step": 0.1},
	{"key": "face_parallax_cursor_gain", "label": "Ganancia Cursor 2.5D", "min": 0.0, "max": 2.5, "step": 0.05},
	{"key": "face_parallax_pivot", "label": "Pivote Profundidad Rostro", "min": 0.25, "max": 0.80, "step": 0.02},
]

const SLIDERS_TAB_3: Array[Dictionary] = [
	{"key": "hair_bangs_amp_px", "label": "Flequillo (R) Amp (px)", "min": 0.0, "max": 7.0, "step": 0.1},
	{"key": "hair_bangs_freq_hz", "label": "Flequillo (R) Frec (Hz)", "min": 0.8, "max": 5.0, "step": 0.05},
	{"key": "hair_sides_amp_px", "label": "Mechones Lat. (G) Amp (px)", "min": 0.0, "max": 8.0, "step": 0.1},
	{"key": "hair_sides_freq_hz", "label": "Mechones Lat. (G) Frec (Hz)", "min": 0.8, "max": 5.0, "step": 0.05},
	{"key": "hair_back_amp_px", "label": "Puntas Nuca (B) Amp (px)", "min": 0.0, "max": 9.0, "step": 0.1},
	{"key": "hair_back_freq_hz", "label": "Puntas Nuca (B) Frec (Hz)", "min": 0.8, "max": 5.0, "step": 0.05},
	{"key": "hair_wind_strength", "label": "Brisa Espacial Zero-G", "min": 0.0, "max": 1.5, "step": 0.05},
	{"key": "hair_normal_light_strength", "label": "Brillo Normal Cabello", "min": 0.0, "max": 0.08, "step": 0.002},
	{"key": "hair_max_clamp_px", "label": "Tope Elástico (px)", "min": 1.5, "max": 12.0, "step": 0.25},
	{"key": "monocle_hud_strength", "label": "Monóculo HUD Brillo", "min": 0.0, "max": 1.5, "step": 0.05},
	{"key": "monocle_gaze_reactivity", "label": "Monóculo Reactividad", "min": 0.0, "max": 1.5, "step": 0.05},
]

const DEBUG_VIEW_ITEMS: Array[Dictionary] = [
	{"id": 0, "label": "0: Render Final"},
	{"id": 1, "label": "1: Clown-Pass ID"},
	{"id": 4, "label": "4: Normales 2.5D"},
	{"id": 5, "label": "5: Profundidad 2.5D"},
	{"id": 6, "label": "6: ILM Mask"},
	{"id": 7, "label": "7: Face Live Mask (R/G/B/A)"},
	{"id": 8, "label": "8: Hair 3-Zone (R/G/B)"},
]

const DIR_BUTTON_SPECS: Array[Dictionary] = [
	{"dir": "S", "head": "head_front"},
	{"dir": "SE", "head": "head_front_r"},
	{"dir": "E", "head": "head_side_r"},
	{"dir": "NE", "head": "head_back_r"},
	{"dir": "N", "head": "head_back"},
	{"dir": "NW", "head": "head_back_l"},
	{"dir": "W", "head": "head_side_l"},
	{"dir": "SW", "head": "head_front_l"},
]

var _callbacks: Dictionary = {}
var _tab_buttons: Array[Button] = []
var _tab_pages: Array[VBoxContainer] = []
var _sliders: Dictionary = {}
var _slider_labels: Dictionary = {}
var _toggles: Dictionary = {}
var _dir_buttons: Dictionary = {}

var _gaze_opt: OptionButton = null
var _preset_opt: OptionButton = null
var _view_mode_opt: OptionButton = null
var _skin_opt: OptionButton = null
var _hair_opt: OptionButton = null
var _debug_opt: OptionButton = null
var _slowmo_opt: OptionButton = null
var _ab_btn: Button = null
var _feedback_lbl: Label = null
var _syncing: bool = false


func build(
	parent: Node,
	cfg: FaceConfigScript,
	skins: Array,
	hair_presets: Array,
	callbacks: Dictionary
) -> void:
	_callbacks = callbacks
	var layer := CanvasLayer.new()
	layer.name = "FaceLabHUD"
	layer.layer = 10
	parent.add_child(layer)

	var panel := PanelContainer.new()
	panel.position = Vector2(14.0, 14.0)
	panel.size = Vector2(368.0, 690.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.13, 0.90)
	style.border_color = Color(0.28, 0.38, 0.56, 0.85)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)

	var root_box := VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 6)
	panel.add_child(root_box)

	var title := Label.new()
	title.text = "Valentina v2 — Face Rig Lab"
	title.add_theme_font_size_override("font_size", 15)
	title.modulate = Color(0.75, 0.90, 1.0, 1.0)
	root_box.add_child(title)

	var tab_bar := HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 4)
	root_box.add_child(tab_bar)

	var tab_names: Array[String] = ["1. Ojos", "2. 2.5D", "3. Pelo", "4. Vista"]
	for i: int in range(tab_names.size()):
		var btn := Button.new()
		btn.text = tab_names[i]
		btn.toggle_mode = true
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var idx: int = i
		btn.pressed.connect(func() -> void: select_tab(idx))
		tab_bar.add_child(btn)
		_tab_buttons.append(btn)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_box.add_child(scroll)

	var pages_holder := VBoxContainer.new()
	pages_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(pages_holder)

	for i: int in range(4):
		var page := VBoxContainer.new()
		page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		page.add_theme_constant_override("separation", 6)
		pages_holder.add_child(page)
		_tab_pages.append(page)

	_build_tab_1(_tab_pages[0], cfg)
	_build_tab_2(_tab_pages[1], cfg)
	_build_tab_3(_tab_pages[2], cfg)
	_build_tab_4(_tab_pages[3], skins, hair_presets)
	_build_footer(root_box)

	select_tab(0)
	sync_from_config(cfg, "head_front", true, false, false, 0, 0)


func _build_tab_1(page: VBoxContainer, cfg: FaceConfigScript) -> void:
	_add_toggle(page, "enable_eyes_live", "Ojos y Parpadeo Activos", cfg.enable_eyes_live, "on_bool_changed")
	_add_toggle(page, "enable_pupil_dilation", "Dilatación Dinámica Pupila", cfg.enable_pupil_dilation, "on_bool_changed")
	_preset_opt = _add_option_row(page, "Expresión:", FaceConfigScript.PRESET_LABELS, func(idx: int) -> void:
		if not _syncing and _callbacks.has("on_preset_changed"):
			(_callbacks["on_preset_changed"] as Callable).call(idx)
	)
	_gaze_opt = _add_option_row(page, "Mirada:", FaceConfigScript.GAZE_LABELS, func(idx: int) -> void:
		if not _syncing and _callbacks.has("on_gaze_mode_changed"):
			(_callbacks["on_gaze_mode_changed"] as Callable).call(idx)
	)

	var act_row := HBoxContainer.new()
	act_row.add_theme_constant_override("separation", 6)
	page.add_child(act_row)
	var blink_btn := Button.new()
	blink_btn.text = "Parpadear (B)"
	blink_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	blink_btn.pressed.connect(func() -> void:
		if _callbacks.has("on_trigger_blink"):
			(_callbacks["on_trigger_blink"] as Callable).call()
	)
	act_row.add_child(blink_btn)

	var whip_btn := Button.new()
	whip_btn.text = "Whip Pelo (W)"
	whip_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	whip_btn.pressed.connect(func() -> void:
		if _callbacks.has("on_trigger_whip"):
			(_callbacks["on_trigger_whip"] as Callable).call()
	)
	act_row.add_child(whip_btn)

	_add_slider_list(page, SLIDERS_TAB_1, cfg)


func _build_tab_2(page: VBoxContainer, cfg: FaceConfigScript) -> void:
	_add_toggle(page, "enable_neck_weld", "Soldadura Cervical Anclada", cfg.enable_neck_weld, "on_bool_changed")
	_add_toggle(page, "enable_face_parallax", "Parallax 2.5D Live2D", cfg.enable_face_parallax, "on_bool_changed")
	_add_slider_list(page, SLIDERS_TAB_2, cfg)


func _build_tab_3(page: VBoxContainer, cfg: FaceConfigScript) -> void:
	_add_toggle(page, "enable_hair_3zone", "Cabello 3 Zonas (R/G/B)", cfg.enable_hair_3zone, "on_bool_changed")
	_add_toggle(page, "enable_monocle_hud", "Monóculo Táctico Vivo", cfg.enable_monocle_hud, "on_bool_changed")
	_add_slider_list(page, SLIDERS_TAB_3, cfg)


func _build_tab_4(page: VBoxContainer, skins: Array, hair_presets: Array) -> void:
	var view_items: Array[String] = ["0: Hero Close-Up", "1: Galería 8-Dir (2x4)"]
	_view_mode_opt = _add_option_row(page, "Vista (V):", view_items, func(idx: int) -> void:
		if not _syncing and _callbacks.has("on_view_mode_changed"):
			(_callbacks["on_view_mode_changed"] as Callable).call(idx)
	)

	var dir_lbl := Label.new()
	dir_lbl.text = "Dirección de Cabeza (Teclas 1..8):"
	page.add_child(dir_lbl)
	var dir_grid := GridContainer.new()
	dir_grid.columns = 4
	dir_grid.add_theme_constant_override("h_separation", 4)
	dir_grid.add_theme_constant_override("v_separation", 4)
	page.add_child(dir_grid)
	for spec: Dictionary in DIR_BUTTON_SPECS:
		var hk: String = str(spec["head"])
		var btn := Button.new()
		btn.text = str(spec["dir"])
		btn.toggle_mode = true
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(func() -> void:
			if not _syncing and _callbacks.has("on_head_selected"):
				(_callbacks["on_head_selected"] as Callable).call(hk)
		)
		dir_grid.add_child(btn)
		_dir_buttons[hk] = btn

	_add_toggle(page, "auto_dir_cursor", "Auto-Rotar Cabeza al Cursor", false, "on_lab_toggle")
	_add_toggle(page, "show_torso_ref", "Mostrar Torso Ref (T)", true, "on_lab_toggle")

	var skin_names: Array[String] = []
	for s_v: Variant in skins:
		var sk: PilotSkinPreset = s_v as PilotSkinPreset
		skin_names.append(sk.label if sk != null and not sk.label.is_empty() else "Skin")
	if skin_names.is_empty():
		skin_names.append("Base")
	_skin_opt = _add_option_row(page, "Skin:", skin_names, func(idx: int) -> void:
		if not _syncing and _callbacks.has("on_skin_selected"):
			(_callbacks["on_skin_selected"] as Callable).call(idx)
	)

	var hair_names: Array[String] = []
	for h_v: Variant in hair_presets:
		var hp: PilotHairPreset = h_v as PilotHairPreset
		hair_names.append(hp.label if hp != null and not hp.label.is_empty() else "Hair")
	if hair_names.is_empty():
		hair_names.append("Base")
	_hair_opt = _add_option_row(page, "Cabello:", hair_names, func(idx: int) -> void:
		if not _syncing and _callbacks.has("on_hair_selected"):
			(_callbacks["on_hair_selected"] as Callable).call(idx)
	)

	var dbg_names: Array[String] = []
	for d_item: Dictionary in DEBUG_VIEW_ITEMS:
		dbg_names.append(str(d_item["label"]))
	_debug_opt = _add_option_row(page, "Rayos-X:", dbg_names, func(idx: int) -> void:
		if not _syncing and _callbacks.has("on_debug_mode_changed"):
			var mode_id: int = int(DEBUG_VIEW_ITEMS[clampi(idx, 0, DEBUG_VIEW_ITEMS.size() - 1)]["id"])
			(_callbacks["on_debug_mode_changed"] as Callable).call(mode_id)
	)

	var sm_items: Array[String] = ["1.00x (Normal)", "0.50x", "0.25x", "0.12x"]
	_slowmo_opt = _add_option_row(page, "Velocidad (M):", sm_items, func(idx: int) -> void:
		if not _syncing and _callbacks.has("on_slowmo_changed"):
			(_callbacks["on_slowmo_changed"] as Callable).call(idx)
	)


func _build_footer(root_box: VBoxContainer) -> void:
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 4)
	root_box.add_child(row1)

	_ab_btn = Button.new()
	_ab_btn.text = "A/B Estático (Tab)"
	_ab_btn.toggle_mode = true
	_ab_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ab_btn.toggled.connect(func(pressed: bool) -> void:
		if not _syncing and _callbacks.has("on_ab_toggled"):
			(_callbacks["on_ab_toggled"] as Callable).call(pressed)
	)
	row1.add_child(_ab_btn)

	var cam_btn := Button.new()
	cam_btn.text = "Cam (R)"
	cam_btn.pressed.connect(func() -> void:
		if _callbacks.has("on_reset_camera"):
			(_callbacks["on_reset_camera"] as Callable).call()
	)
	row1.add_child(cam_btn)

	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 4)
	root_box.add_child(row2)
	var save_btn := Button.new()
	save_btn.text = "Guardar .tres"
	save_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_btn.pressed.connect(func() -> void:
		if _callbacks.has("on_save_tres"):
			(_callbacks["on_save_tres"] as Callable).call()
	)
	row2.add_child(save_btn)

	var reload_btn := Button.new()
	reload_btn.text = "Recargar"
	reload_btn.pressed.connect(func() -> void:
		if _callbacks.has("on_reload_tres"):
			(_callbacks["on_reload_tres"] as Callable).call()
	)
	row2.add_child(reload_btn)

	var reset_btn := Button.new()
	reset_btn.text = "Reset"
	reset_btn.pressed.connect(func() -> void:
		if _callbacks.has("on_reset_defaults"):
			(_callbacks["on_reset_defaults"] as Callable).call()
	)
	row2.add_child(reset_btn)

	_feedback_lbl = Label.new()
	_feedback_lbl.text = "Listo. Mueve el ratón para mirar · B parpadeo · W whip"
	_feedback_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feedback_lbl.add_theme_font_size_override("font_size", 11)
	_feedback_lbl.modulate = Color(0.68, 0.85, 0.98, 0.92)
	root_box.add_child(_feedback_lbl)


func _add_toggle(
	page: VBoxContainer,
	key: String,
	label: String,
	initial: bool,
	cb_key: String
) -> void:
	var chk := CheckBox.new()
	chk.text = label
	chk.button_pressed = initial
	chk.toggled.connect(func(val: bool) -> void:
		if not _syncing and _callbacks.has(cb_key):
			(_callbacks[cb_key] as Callable).call(key, val)
	)
	page.add_child(chk)
	_toggles[key] = chk


func _add_option_row(
	page: VBoxContainer,
	label_text: String,
	items: Array[String],
	on_select: Callable
) -> OptionButton:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	page.add_child(row)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(100.0, 0.0)
	row.add_child(lbl)
	var opt := OptionButton.new()
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for item: String in items:
		opt.add_item(item)
	opt.item_selected.connect(on_select)
	row.add_child(opt)
	return opt


func _add_slider_list(page: VBoxContainer, specs: Array[Dictionary], cfg: FaceConfigScript) -> void:
	for spec: Dictionary in specs:
		var key: String = str(spec["key"])
		var init_val: float = float(cfg.get(key)) if (cfg != null and key in cfg) else 0.0
		var hdr := HBoxContainer.new()
		page.add_child(hdr)
		var name_lbl := Label.new()
		name_lbl.text = str(spec["label"])
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_font_size_override("font_size", 12)
		hdr.add_child(name_lbl)
		var val_lbl := Label.new()
		val_lbl.text = "%.2f" % init_val
		val_lbl.add_theme_font_size_override("font_size", 12)
		hdr.add_child(val_lbl)

		var sl := HSlider.new()
		sl.min_value = float(spec["min"])
		sl.max_value = float(spec["max"])
		sl.step = float(spec["step"])
		sl.value = init_val
		sl.value_changed.connect(func(v: float) -> void:
			val_lbl.text = "%.2f" % v
			if not _syncing and _callbacks.has("on_param_changed"):
				(_callbacks["on_param_changed"] as Callable).call(key, v)
		)
		page.add_child(sl)
		_sliders[key] = sl
		_slider_labels[key] = val_lbl


func select_tab(tab_idx: int) -> void:
	for i: int in range(_tab_pages.size()):
		var active: bool = (i == tab_idx)
		_tab_pages[i].visible = active
		_tab_buttons[i].set_pressed_no_signal(active)


func sync_from_config(
	cfg: FaceConfigScript,
	active_head: String,
	show_torso: bool,
	auto_dir: bool,
	ab_static: bool,
	view_mode: int,
	slowmo_idx: int
) -> void:
	if cfg == null:
		return
	_syncing = true
	for k: String in _sliders.keys():
		if k in cfg:
			var v: float = float(cfg.get(k))
			(_sliders[k] as HSlider).value = v
			(_slider_labels[k] as Label).text = "%.2f" % v
	for k: String in ["enable_eyes_live", "enable_pupil_dilation", "enable_neck_weld", "enable_face_parallax", "enable_hair_3zone", "enable_monocle_hud"]:
		if _toggles.has(k) and k in cfg:
			(_toggles[k] as CheckBox).set_pressed_no_signal(bool(cfg.get(k)))
	if _toggles.has("show_torso_ref"):
		(_toggles["show_torso_ref"] as CheckBox).set_pressed_no_signal(show_torso)
	if _toggles.has("auto_dir_cursor"):
		(_toggles["auto_dir_cursor"] as CheckBox).set_pressed_no_signal(auto_dir)
	if _preset_opt != null:
		_preset_opt.select(clampi(cfg.expression_preset, 0, FaceConfigScript.PRESET_LABELS.size() - 1))
	if _gaze_opt != null:
		_gaze_opt.select(clampi(cfg.gaze_mode, 0, FaceConfigScript.GAZE_LABELS.size() - 1))
	if _view_mode_opt != null:
		_view_mode_opt.select(clampi(view_mode, 0, 1))
	if _slowmo_opt != null:
		_slowmo_opt.select(clampi(slowmo_idx, 0, 3))
	if _ab_btn != null:
		_ab_btn.set_pressed_no_signal(ab_static)
	for hk: String in _dir_buttons.keys():
		(_dir_buttons[hk] as Button).set_pressed_no_signal(hk == active_head)
	_syncing = false


func sync_debug_mode_id(mode_id: int) -> void:
	if _debug_opt == null:
		return
	_syncing = true
	for i: int in range(DEBUG_VIEW_ITEMS.size()):
		if int(DEBUG_VIEW_ITEMS[i]["id"]) == mode_id:
			_debug_opt.select(i)
			break
	_syncing = false


func set_feedback(msg: String, ok: bool) -> void:
	if _feedback_lbl != null:
		_feedback_lbl.text = msg
		_feedback_lbl.modulate = Color(0.55, 0.98, 0.72, 1.0) if ok else Color(1.0, 0.55, 0.52, 1.0)

class_name PilotDialogueLabHUD
extends RefCounted
## Constructor del HUD flotante colapsable (capa 40) y del Teatro de Diálogos In-Game
## 1920x1080 centrado inferior (capa 25) para PilotDialogueLab.

const ConfigScript = preload("res://data/pilots/schemas/pilot_dialogue_portrait_config.gd")
const EntryScript = preload("res://data/pilots/schemas/pilot_dialogue_portrait_entry.gd")

const PANEL_WIDTH: float = 320.0


static func build_hud(
	parent: Node,
	config: ConfigScript,
	skin_labels: Array[String],
	pet_ids: Array[String],
	conversations: Array[Dictionary],
	callbacks: Dictionary
) -> Dictionary:
	var refs: Dictionary = {}

	# --- 1. Teatro de Diálogo Análogo al In-Game (CanvasLayer 25, 1920x1080) ---
	var theater_layer := CanvasLayer.new()
	theater_layer.name = "DialogueTheaterLayer"
	theater_layer.layer = 25
	parent.add_child(theater_layer)

	var dlg_box := PanelContainer.new()
	dlg_box.name = "TheaterDialogueBox"
	dlg_box.anchor_left = 0.0
	dlg_box.anchor_top = 1.0
	dlg_box.anchor_right = 1.0
	dlg_box.anchor_bottom = 1.0
	dlg_box.offset_left = 200.0
	dlg_box.offset_right = -200.0
	dlg_box.offset_top = -238.0
	dlg_box.offset_bottom = -28.0

	var box_style := StyleBoxFlat.new()
	box_style.bg_color = Color(0.035, 0.048, 0.10, 0.94)
	box_style.border_color = Color(0.56, 0.74, 1.0, 0.78)
	box_style.set_border_width_all(2)
	box_style.set_corner_radius_all(14)
	box_style.content_margin_left = 28.0
	box_style.content_margin_right = 28.0
	box_style.content_margin_top = 26.0
	box_style.content_margin_bottom = 16.0
	dlg_box.add_theme_stylebox_override("panel", box_style)
	dlg_box.gui_input.connect(func(ev: InputEvent) -> void:
		var mb := ev as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_invoke(callbacks, "on_advance_dialogue")
	)
	theater_layer.add_child(dlg_box)
	refs["dialogue_box_style"] = box_style

	var box_v := VBoxContainer.new()
	box_v.add_theme_constant_override("separation", 8)
	dlg_box.add_child(box_v)

	var body_lbl := RichTextLabel.new()
	body_lbl.name = "DialogueBodyLabel"
	body_lbl.bbcode_enabled = true
	body_lbl.fit_content = false
	body_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body_lbl.add_theme_font_size_override("normal_font_size", 26)
	body_lbl.add_theme_color_override("default_color", Color(0.94, 0.96, 1.0, 1.0))
	body_lbl.text = "Selecciona una conversación o emoción desde Controles Lab [H]."
	box_v.add_child(body_lbl)
	refs["body_label"] = body_lbl

	var footer_h := HBoxContainer.new()
	footer_h.add_theme_constant_override("separation", 12)
	box_v.add_child(footer_h)

	var step_lbl := Label.new()
	step_lbl.text = "Inspección Libre"
	step_lbl.add_theme_font_size_override("font_size", 13)
	step_lbl.add_theme_color_override("font_color", Color(0.72, 0.78, 0.92, 0.78))
	footer_h.add_child(step_lbl)
	refs["conv_step_label"] = step_lbl

	var f_spacer := Control.new()
	f_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer_h.add_child(f_spacer)

	var footer_lbl := Label.new()
	footer_lbl.text = "Clic o [Espacio] para avanzar ▸"
	footer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	footer_lbl.add_theme_font_size_override("font_size", 13)
	footer_lbl.add_theme_color_override("font_color", Color(0.62, 0.80, 1.0, 0.85))
	footer_h.add_child(footer_lbl)

	# Nameplate flotante anclado al borde superior izquierdo de la caja in-game
	var nameplate := PanelContainer.new()
	nameplate.name = "NameplatePanel"
	nameplate.anchor_left = 0.0
	nameplate.anchor_right = 0.0
	nameplate.anchor_top = 1.0
	nameplate.anchor_bottom = 1.0
	nameplate.offset_left = 228.0
	nameplate.offset_right = 640.0
	nameplate.offset_top = -266.0
	nameplate.offset_bottom = -224.0
	nameplate.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var np_style := StyleBoxFlat.new()
	np_style.bg_color = Color(0.055, 0.075, 0.15, 0.96)
	np_style.border_color = Color(0.56, 0.74, 1.0, 0.85)
	np_style.set_border_width_all(2)
	np_style.set_corner_radius_all(9)
	np_style.content_margin_left = 18.0
	np_style.content_margin_right = 18.0
	np_style.content_margin_top = 4.0
	np_style.content_margin_bottom = 4.0
	nameplate.add_theme_stylebox_override("panel", np_style)
	theater_layer.add_child(nameplate)
	refs["nameplate_style"] = np_style

	var np_h := HBoxContainer.new()
	np_h.add_theme_constant_override("separation", 12)
	np_h.alignment = BoxContainer.ALIGNMENT_BEGIN
	nameplate.add_child(np_h)

	var speaker_lbl := Label.new()
	speaker_lbl.text = "VALENTINA"
	speaker_lbl.add_theme_font_size_override("font_size", 22)
	speaker_lbl.add_theme_color_override("font_color", Color(0.98, 0.44, 0.58, 1.0))
	np_h.add_child(speaker_lbl)
	refs["speaker_label"] = speaker_lbl

	var badge_lbl := Label.new()
	badge_lbl.text = "[NEUTRAL]"
	badge_lbl.add_theme_font_size_override("font_size", 13)
	badge_lbl.add_theme_color_override("font_color", Color(0.62, 0.86, 1.0, 0.92))
	np_h.add_child(badge_lbl)
	refs["pose_badge_label"] = badge_lbl

	# --- 2. Cajón Flotante Colapsable de Calibración (CanvasLayer 40) ---
	var layer := CanvasLayer.new()
	layer.name = "DialogueLabHUDLayer"
	layer.layer = 40
	parent.add_child(layer)
	refs["controls_layer"] = layer

	var top_bar := HBoxContainer.new()
	top_bar.name = "TopUtilityBar"
	top_bar.anchor_left = 0.0
	top_bar.anchor_top = 0.0
	top_bar.offset_left = 16.0
	top_bar.offset_top = 14.0
	top_bar.offset_right = 420.0
	top_bar.offset_bottom = 48.0
	top_bar.add_theme_constant_override("separation", 8)
	layer.add_child(top_bar)

	var toggle_btn := Button.new()
	toggle_btn.name = "ToggleControlsBtn"
	toggle_btn.text = "⚙ Controles Lab [H]"
	toggle_btn.toggle_mode = true
	toggle_btn.button_pressed = true
	toggle_btn.toggled.connect(func(on: bool) -> void: _invoke_arg(callbacks, "on_hud_toggled", on))
	top_bar.add_child(toggle_btn)
	refs["toggle_hud_btn"] = toggle_btn

	var guides_btn := Button.new()
	guides_btn.name = "GuidesToggleBtn"
	guides_btn.text = "⊞ Guías [G]"
	guides_btn.toggle_mode = true
	guides_btn.button_pressed = false
	guides_btn.toggled.connect(func(on: bool) -> void: _invoke_arg(callbacks, "on_guides_toggled", on))
	top_bar.add_child(guides_btn)
	refs["guides_btn"] = guides_btn

	var hub_pill_btn := Button.new()
	hub_pill_btn.name = "ReturnHubBtn"
	hub_pill_btn.text = "← Hub"
	hub_pill_btn.pressed.connect(func() -> void: _invoke(callbacks, "on_return_hub"))
	top_bar.add_child(hub_pill_btn)

	var panel := PanelContainer.new()
	panel.name = "ControlPanel"
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.anchor_right = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_left = 16.0
	panel.offset_top = 54.0
	panel.offset_right = 16.0 + PANEL_WIDTH
	panel.offset_bottom = 812.0

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.04, 0.055, 0.10, 0.88)
	panel_style.border_color = Color(0.56, 0.72, 1.0, 0.55)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(8)
	panel_style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", panel_style)
	layer.add_child(panel)
	refs["control_panel"] = panel

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(vbox)

	var title := Label.new()
	title.text = "PILOT DIALOGUE LAB — ANALOG 1080P"
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(0.62, 0.82, 1.0, 1.0))
	vbox.add_child(title)

	var hint := Label.new()
	hint.text = "1..5: Emoción · Space: Línea · H: Panel · G: Guías · F: Turno · M: Espejo · C: Cosmos"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.75, 0.82, 0.92, 0.85))
	vbox.add_child(hint)

	var next_btn := Button.new()
	next_btn.text = "Siguiente Línea [Space]"
	next_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	next_btn.pressed.connect(func() -> void: _invoke(callbacks, "on_advance_dialogue"))
	vbox.add_child(next_btn)

	vbox.add_child(HSeparator.new())
	_add_header(vbox, "Interlocutor Pet (Slot Derecho)")

	var pet_opt := OptionButton.new()
	for i: int in range(pet_ids.size()):
		var pid: String = pet_ids[i]
		pet_opt.add_item("Pet: %s" % pid.capitalize(), i)
	if not pet_ids.is_empty():
		pet_opt.select(0)
	pet_opt.item_selected.connect(func(idx: int) -> void:
		if idx >= 0 and idx < pet_ids.size():
			_invoke_arg(callbacks, "on_pet_selected", pet_ids[idx])
	)
	vbox.add_child(pet_opt)
	refs["pet_option"] = pet_opt

	vbox.add_child(HSeparator.new())
	_add_header(vbox, "Poses & Emociones")

	var emotion_btns: Dictionary = {}
	if config != null:
		for i: int in range(config.entries.size()):
			var entry: EntryScript = config.entries[i]
			if entry == null:
				continue
			var btn := Button.new()
			btn.text = "[%d] %s" % [i + 1, entry.display_label]
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			var eid: StringName = entry.emotion_id
			btn.pressed.connect(func() -> void: _invoke_arg(callbacks, "on_emotion_selected", eid))
			vbox.add_child(btn)
			emotion_btns[eid] = btn
	refs["emotion_buttons"] = emotion_btns

	vbox.add_child(HSeparator.new())
	_add_header(vbox, "Teatro de Conversaciones")
	for conv: Dictionary in conversations:
		var cid: String = str(conv.get("id", ""))
		var cbtn := Button.new()
		cbtn.text = str(conv.get("title", cid))
		cbtn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		cbtn.pressed.connect(func() -> void: _invoke_arg(callbacks, "on_conversation_selected", cid))
		vbox.add_child(cbtn)

	vbox.add_child(HSeparator.new())
	_add_header(vbox, "Shaders, Skins & Rayos-X")

	var debug_opt := OptionButton.new()
	debug_opt.add_item("Vista: Final Living 2.5D", 0)
	debug_opt.add_item("Debug: Albedo Crudo (Sin Luz)", 1)
	debug_opt.add_item("Debug: Normal Map (Sapiens 3D)", 2)
	debug_opt.add_item("Debug: Depth Map (DA-V2)", 3)
	debug_opt.add_item("Debug: ID Mask (RGB)", 4)
	debug_opt.add_item("Debug: ILM Map (Metal/AO/Pelo)", 5)
	debug_opt.add_item("Debug: Motion Mask (Resp/Pelo/Ojo)", 6)
	debug_opt.select(0)
	debug_opt.item_selected.connect(func(idx: int) -> void: _invoke_arg(callbacks, "on_debug_view_selected", idx))
	vbox.add_child(debug_opt)
	refs["debug_option"] = debug_opt

	var skin_opt := OptionButton.new()
	for i: int in range(skin_labels.size()):
		skin_opt.add_item(skin_labels[i], i)
	if not skin_labels.is_empty():
		skin_opt.select(0)
	skin_opt.item_selected.connect(func(idx: int) -> void: _invoke_arg(callbacks, "on_skin_selected", idx))
	vbox.add_child(skin_opt)
	refs["skin_option"] = skin_opt

	var hair_chk := CheckButton.new()
	hair_chk.text = "Recolorear Cabello con Skin"
	hair_chk.button_pressed = false
	hair_chk.toggled.connect(func(on: bool) -> void: _invoke_arg(callbacks, "on_hair_recolor_toggled", on))
	vbox.add_child(hair_chk)

	vbox.add_child(HSeparator.new())
	_add_header(vbox, "Vida Orgánica & Turnos")

	var living_chk := _add_check(vbox, "Living Motion [Tab]", true, callbacks, "on_living_toggled")
	var comms_chk := _add_check(vbox, "Modo Radio Comms [R]", false, callbacks, "on_comms_toggled")
	var focus_chk := _add_check(vbox, "Foco Valentina [F]", true, callbacks, "on_focused_toggled")
	var mirror_chk := _add_check(vbox, "Intercambiar Lados [M]", false, callbacks, "on_mirror_toggled")
	var part_chk := _add_check(vbox, "Partículas Cósmicas", true, callbacks, "on_particles_toggled")
	var cosmos_chk := _add_check(vbox, "Fondo Cosmos Engine [C]", false, callbacks, "on_cosmos_toggled")
	refs["living_check"] = living_chk
	refs["comms_check"] = comms_chk
	refs["focus_check"] = focus_chk
	refs["mirror_check"] = mirror_chk
	refs["particles_check"] = part_chk
	refs["cosmos_check"] = cosmos_chk

	var pulse_btn := Button.new()
	pulse_btn.text = "Pulso Óptico (Ojo/Monóculo)"
	pulse_btn.pressed.connect(func() -> void: _invoke(callbacks, "on_speech_pulse"))
	vbox.add_child(pulse_btn)

	vbox.add_child(HSeparator.new())
	_add_header(vbox, "Dimensiones Portables 1080p")

	var cfg_sliders: Dictionary = {}
	var init_h: float = config.base_display_height_px if config != null else 860.0
	var init_fade: float = config.bottom_fade_start if config != null else 0.86
	cfg_sliders["base_display_height_px"] = _add_slider(vbox, "Altura Retrato (px)", 520.0, 1080.0, 10.0, init_h, callbacks, "on_config_param_changed", "base_display_height_px")
	cfg_sliders["bottom_fade_start"] = _add_slider(vbox, "Fade Inferior UV.y", 0.60, 0.98, 0.01, init_fade, callbacks, "on_config_param_changed", "bottom_fade_start")
	refs["config_sliders"] = cfg_sliders

	vbox.add_child(HSeparator.new())
	_add_header(vbox, "Calibración .tres (Entrada Activa)")

	var sliders: Dictionary = {}
	sliders["rim_light_strength"] = _add_slider(vbox, "Rim Light Fuerza", 0.0, 1.5, 0.02, 0.56, callbacks, "on_param_changed", "rim_light_strength")
	sliders["rim_light_angle_deg"] = _add_slider(vbox, "Rim Light Ángulo", -180.0, 180.0, 1.0, -40.0, callbacks, "on_param_changed", "rim_light_angle_deg")
	sliders["cel_strength"] = _add_slider(vbox, "Cel-Shading 2.5D", 0.0, 1.0, 0.02, 0.44, callbacks, "on_param_changed", "cel_strength")
	sliders["specular_strength"] = _add_slider(vbox, "Especular Metal / Pelo", 0.0, 1.5, 0.02, 0.72, callbacks, "on_param_changed", "specular_strength")
	sliders["face_shadow_protect"] = _add_slider(vbox, "Protección Facial", 0.0, 1.0, 0.02, 0.92, callbacks, "on_param_changed", "face_shadow_protect")
	sliders["breath_amp_px"] = _add_slider(vbox, "Respiración (px)", 0.0, 10.0, 0.2, 2.8, callbacks, "on_param_changed", "breath_amp_px")
	sliders["hair_sway_amp_px"] = _add_slider(vbox, "Cabello Zero-G (px)", 0.0, 10.0, 0.2, 3.0, callbacks, "on_param_changed", "hair_sway_amp_px")
	sliders["eye_shimmer_strength"] = _add_slider(vbox, "Brillo Ojo/Monóculo", 0.0, 1.5, 0.02, 0.30, callbacks, "on_param_changed", "eye_shimmer_strength")
	refs["sliders"] = sliders

	var save_row := HBoxContainer.new()
	save_row.add_theme_constant_override("separation", 6)
	var save_btn := Button.new()
	save_btn.text = "Guardar .tres"
	save_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_btn.pressed.connect(func() -> void: _invoke(callbacks, "on_save_config"))
	save_row.add_child(save_btn)

	var reload_btn := Button.new()
	reload_btn.text = "Recargar"
	reload_btn.pressed.connect(func() -> void: _invoke(callbacks, "on_reload_config"))
	save_row.add_child(reload_btn)
	vbox.add_child(save_row)

	var status_lbl := Label.new()
	status_lbl.text = "Listo (Escenario 1920x1080 In-Game)"
	status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_lbl.add_theme_font_size_override("font_size", 11)
	status_lbl.add_theme_color_override("font_color", Color(0.75, 0.92, 0.78, 0.95))
	vbox.add_child(status_lbl)
	refs["status_label"] = status_lbl

	return refs


static func set_hud_panel_visible(refs: Dictionary, vis: bool) -> void:
	var panel: PanelContainer = refs.get("control_panel", null) as PanelContainer
	if is_instance_valid(panel):
		panel.visible = vis
	var btn: Button = refs.get("toggle_hud_btn", null) as Button
	if is_instance_valid(btn):
		btn.set_pressed_no_signal(vis)


static func sync_entry_sliders(refs: Dictionary, entry: EntryScript) -> void:
	if entry == null:
		return
	var sliders: Dictionary = refs.get("sliders", {}) as Dictionary
	var values: Dictionary = {
		"rim_light_strength": entry.rim_light_strength,
		"rim_light_angle_deg": entry.rim_light_angle_deg,
		"cel_strength": entry.cel_strength,
		"specular_strength": entry.specular_strength,
		"face_shadow_protect": entry.face_shadow_protect,
		"breath_amp_px": entry.breath_amp_px,
		"hair_sway_amp_px": entry.hair_sway_amp_px,
		"eye_shimmer_strength": entry.eye_shimmer_strength,
	}
	_sync_slider_dict(sliders, values)


static func sync_config_sliders(refs: Dictionary, config: ConfigScript) -> void:
	if config == null:
		return
	var cfg_sliders: Dictionary = refs.get("config_sliders", {}) as Dictionary
	var values: Dictionary = {
		"base_display_height_px": config.base_display_height_px,
		"bottom_fade_start": config.bottom_fade_start,
	}
	_sync_slider_dict(cfg_sliders, values)


static func _sync_slider_dict(sliders: Dictionary, values: Dictionary) -> void:
	for k: String in values.keys():
		var pair: Variant = sliders.get(k, null)
		if pair is Dictionary:
			var d: Dictionary = pair as Dictionary
			var sl: HSlider = d.get("slider", null) as HSlider
			var val_lbl: Label = d.get("val_lbl", null) as Label
			var v: float = float(values[k])
			if is_instance_valid(sl):
				sl.set_value_no_signal(v)
			if is_instance_valid(val_lbl):
				val_lbl.text = "%.2f" % v


static func _add_header(parent: VBoxContainer, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text.to_upper()
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.68, 0.78, 0.94, 0.85))
	parent.add_child(lbl)


static func _add_check(parent: VBoxContainer, text: String, initial: bool, callbacks: Dictionary, cb_key: String) -> CheckButton:
	var chk := CheckButton.new()
	chk.text = text
	chk.button_pressed = initial
	chk.toggled.connect(func(on: bool) -> void: _invoke_arg(callbacks, cb_key, on))
	parent.add_child(chk)
	return chk


static func _add_slider(
	parent: VBoxContainer,
	label_txt: String,
	min_v: float,
	max_v: float,
	step_v: float,
	init_v: float,
	callbacks: Dictionary,
	cb_key: String,
	param_name: String
) -> Dictionary:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	var top := HBoxContainer.new()
	var lbl := Label.new()
	lbl.text = label_txt
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 11)
	var val_lbl := Label.new()
	val_lbl.text = "%.2f" % init_v
	val_lbl.add_theme_font_size_override("font_size", 11)
	val_lbl.add_theme_color_override("font_color", Color(0.75, 0.88, 1.0, 0.9))
	top.add_child(lbl)
	top.add_child(val_lbl)
	row.add_child(top)

	var sl := HSlider.new()
	sl.min_value = min_v
	sl.max_value = max_v
	sl.step = step_v
	sl.value = init_v
	sl.value_changed.connect(func(val: float) -> void:
		val_lbl.text = "%.2f" % val
		var cb: Callable = callbacks.get(cb_key, Callable())
		if cb.is_valid():
			cb.call(param_name, val)
	)
	row.add_child(sl)
	parent.add_child(row)
	return {"slider": sl, "val_lbl": val_lbl}


static func _invoke(callbacks: Dictionary, key: String) -> void:
	var cb: Callable = callbacks.get(key, Callable())
	if cb.is_valid():
		cb.call()


static func _invoke_arg(callbacks: Dictionary, key: String, arg: Variant) -> void:
	var cb: Callable = callbacks.get(key, Callable())
	if cb.is_valid():
		cb.call(arg)

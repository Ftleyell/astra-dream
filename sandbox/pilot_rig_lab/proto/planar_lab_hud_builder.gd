class_name PlanarLabHudBuilder
extends RefCounted
## Constructor desacoplado del panel HUD para el Pilot Rig Lab.
## Escanea pilotos `.tres` en `pilots/*/*.tres` y expone controles de estilo,
## iluminación 2.5D, hit_flash, transiciones snappy (4..6) e inspección estática.

const PILOTS_ROOT_DIR: String = "res://sandbox/pilot_rig_lab/pilots"
const BODY_KEYS: Array[String] = ["s", "se", "e", "ne", "n", "nw", "w", "sw"]
const HEAD_KEYS: Array[String] = [
	"head_front", "head_front_l", "head_front_r",
	"head_side_l", "head_side_r",
	"head_back", "head_back_l", "head_back_r",
]


static func scan_pilot_profiles() -> Array[PilotRigProfile]:
	var profiles: Array[PilotRigProfile] = []
	var root_dir := DirAccess.open(PILOTS_ROOT_DIR)
	if root_dir == null:
		return profiles
	root_dir.list_dir_begin()
	var sub: String = root_dir.get_next()
	while not sub.is_empty():
		if root_dir.current_is_dir() and not sub.begins_with("."):
			var sub_path: String = PILOTS_ROOT_DIR.path_join(sub)
			var sub_dir := DirAccess.open(sub_path)
			if sub_dir != null:
				sub_dir.list_dir_begin()
				var fname: String = sub_dir.get_next()
				while not fname.is_empty():
					if not sub_dir.current_is_dir() and fname.ends_with(".tres"):
						var full_p: String = sub_path.path_join(fname)
						var res: Resource = ResourceLoader.load(full_p)
						if res is PilotRigProfile:
							profiles.append(res as PilotRigProfile)
					fname = sub_dir.get_next()
				sub_dir.list_dir_end()
		sub = root_dir.get_next()
	root_dir.list_dir_end()
	profiles.sort_custom(func(a: PilotRigProfile, b: PilotRigProfile) -> bool: return a.pilot_id < b.pilot_id)
	return profiles


static func rebuild_static_body_options(body_opt: OptionButton, rig: PlanarCombatRig) -> Array[String]:
	if body_opt == null:
		return []
	var prev_key: String = ""
	if body_opt.has_meta("view_keys"):
		var old_keys: Variant = body_opt.get_meta("view_keys")
		if old_keys is Array and body_opt.selected >= 0 and body_opt.selected < (old_keys as Array).size():
			prev_key = str((old_keys as Array)[body_opt.selected])
	body_opt.clear()
	var view_keys: Array[String] = rig.get_available_view_keys() if rig != null else []
	if view_keys.is_empty():
		view_keys.assign(BODY_KEYS)
	for i: int in range(view_keys.size()):
		body_opt.add_item("Cuerpo %s" % view_keys[i].to_upper(), i)
	body_opt.set_meta("view_keys", view_keys)
	var restore_idx: int = view_keys.find(prev_key)
	body_opt.select(restore_idx if restore_idx >= 0 else 0)
	return view_keys


static func build_hud(host: Node, rig: PlanarCombatRig, callbacks: Dictionary) -> Dictionary:
	var hud_layer := CanvasLayer.new()
	host.add_child(hud_layer)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.0
	panel.anchor_right = 0.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 12.0
	panel.offset_right = 352.0
	panel.offset_top = 12.0
	panel.offset_bottom = -12.0
	hud_layer.add_child(panel)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	scroll.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 5)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "PILOT RIG LAB — PLANAR 8-DIR"
	vbox.add_child(title)

	var status_lbl := Label.new()
	status_lbl.text = "Body=S | Head=front"
	status_lbl.add_theme_font_size_override("font_size", 11)
	vbox.add_child(status_lbl)

	# --- 0. PILOTO ---
	_add_section_header(vbox, "0. PILOTO (.tres)")
	var profiles: Array[PilotRigProfile] = scan_pilot_profiles()
	var pilot_opt := OptionButton.new()
	for p: PilotRigProfile in profiles:
		pilot_opt.add_item("%s (%s)" % [p.display_name, p.pilot_id])
	if profiles.is_empty():
		pilot_opt.add_item("(Sin perfiles .tres)")
	_add_opt_with_steppers(vbox, pilot_opt)

	# --- 1. ESTILO & RECOLOR ---
	_add_section_header(vbox, "1. ESTILO & RECOLOR")

	var halftone_slider := HSlider.new()
	var profile_opt := OptionButton.new()
	var skin_opt := OptionButton.new()
	var hair_opt := OptionButton.new()

	var populate_presets: Callable = func(p: PilotRigProfile) -> void:
		profile_opt.clear()
		skin_opt.clear()
		hair_opt.clear()
		if p == null:
			return
		for sp: RigStyleProfile in p.style_profiles:
			if sp != null:
				profile_opt.add_item(sp.label)
		for sk: PilotSkinPreset in p.skins:
			if sk != null:
				skin_opt.add_item(sk.label)
		for hp: PilotHairPreset in p.hair_presets:
			if hp != null:
				hair_opt.add_item(hp.label)

	var active_profile: Array = [profiles[0] if not profiles.is_empty() else (rig.pilot_profile as PilotRigProfile)]
	populate_presets.call(active_profile[0] as PilotRigProfile)

	profile_opt.item_selected.connect(func(idx: int) -> void:
		var p: PilotRigProfile = active_profile[0] as PilotRigProfile
		if p == null or idx < 0 or idx >= p.style_profiles.size():
			return
		var sp: RigStyleProfile = p.style_profiles[idx]
		rig.apply_style_profile(sp)
		halftone_slider.set_value_no_signal(sp.halftone_strength)
	)
	_add_opt_with_steppers(vbox, profile_opt)

	skin_opt.item_selected.connect(func(idx: int) -> void:
		var p: PilotRigProfile = active_profile[0] as PilotRigProfile
		if p == null or idx < 0 or idx >= p.skins.size():
			return
		var sk: PilotSkinPreset = p.skins[idx]
		rig.apply_skin_preset(sk)
		if hair_opt.selected > 0 and hair_opt.selected < p.hair_presets.size():
			rig.apply_hair_preset(p.hair_presets[hair_opt.selected], sk.hair_color)
	)
	_add_opt_with_steppers(vbox, skin_opt)

	var recolor_method_opt := OptionButton.new()
	for rm_lbl: String in [
		"Recolor 0: Multiplicativo Clásico",
		"Recolor 1: Gradiente 3-Tonos (ArcSys)",
		"Recolor 2: Perceptual Contraste",
		"Recolor 3: Overlay / Hard-Light",
		"Recolor 4: Cel-Ramp 3-Bandas",
	]:
		recolor_method_opt.add_item(rm_lbl)
	recolor_method_opt.selected = 1
	recolor_method_opt.item_selected.connect(func(idx: int) -> void:
		rig.set_recolor_method(idx)
	)
	vbox.add_child(recolor_method_opt)

	hair_opt.item_selected.connect(func(idx: int) -> void:
		var p: PilotRigProfile = active_profile[0] as PilotRigProfile
		if p == null or idx < 0 or idx >= p.hair_presets.size():
			return
		var sk_idx: int = clampi(skin_opt.selected, 0, maxi(p.skins.size() - 1, 0))
		var skin_hair: Color = p.skins[sk_idx].hair_color if not p.skins.is_empty() else Color.WHITE
		rig.apply_hair_preset(p.hair_presets[idx], skin_hair)
	)
	_add_opt_with_steppers(vbox, hair_opt)

	var hair_style_opt := OptionButton.new()
	for hs_lbl: String in [
		"Estilo Pelo 0: Sólido Cel-Shaded",
		"Estilo Pelo 1: Bicolor Trigger",
		"Estilo Pelo 2: Puntas Dip-Dye",
		"Estilo Pelo 3: Halo Angel Ring",
	]:
		hair_style_opt.add_item(hs_lbl)
	hair_style_opt.item_selected.connect(func(idx: int) -> void:
		rig.set_hair_style_mode(idx)
	)
	vbox.add_child(hair_style_opt)

	var ht_lbl := Label.new()
	ht_lbl.text = "Fuerza Semitono / Trama"
	vbox.add_child(ht_lbl)
	halftone_slider.min_value = 0.0
	halftone_slider.max_value = 1.0
	halftone_slider.step = 0.05
	halftone_slider.value = 0.0
	halftone_slider.value_changed.connect(func(v: float) -> void:
		rig.set_shader_param_all("enable_halftone", v > 0.01)
		rig.set_shader_param_all("halftone_strength", v)
	)
	vbox.add_child(halftone_slider)

	# --- 2. ILUMINACIÓN 2.5D, HIT FLASH & OUTLINE ---
	_add_section_header(vbox, "2. ILUMINACIÓN 2.5D, FX & OUTLINE")

	var normal_chk := CheckBox.new()
	normal_chk.text = "Iluminación 2.5D + Rim Cónico"
	normal_chk.button_pressed = true
	vbox.add_child(normal_chk)

	var light_lbl := Label.new()
	light_lbl.text = "Ángulo Luz 2.5D"
	vbox.add_child(light_lbl)
	var light_slider := HSlider.new()
	light_slider.min_value = -180.0
	light_slider.max_value = 180.0
	light_slider.value = -125.0
	vbox.add_child(light_slider)

	var cel_infl_lbl := Label.new()
	cel_infl_lbl.text = "Influencia Cel 2.5D"
	vbox.add_child(cel_infl_lbl)
	var cel_infl_slider := HSlider.new()
	cel_infl_slider.min_value = 0.0
	cel_infl_slider.max_value = 1.0
	cel_infl_slider.step = 0.05
	cel_infl_slider.value = 0.52
	cel_infl_slider.value_changed.connect(func(v: float) -> void: rig.set_shader_param_all("normal_cel_influence", v))
	vbox.add_child(cel_infl_slider)

	var hdr_lbl := Label.new()
	hdr_lbl.text = "HDR Glow / Rim Boost"
	vbox.add_child(hdr_lbl)
	var hdr_slider := HSlider.new()
	hdr_slider.min_value = 1.0
	hdr_slider.max_value = 2.2
	hdr_slider.step = 0.05
	hdr_slider.value = 1.15
	vbox.add_child(hdr_slider)

	var sync_lighting: Callable = callbacks.get("sync_lighting", Callable())
	if sync_lighting.is_valid():
		normal_chk.toggled.connect(func(_v: bool) -> void: sync_lighting.call())
		light_slider.value_changed.connect(func(_v: float) -> void: sync_lighting.call())
		hdr_slider.value_changed.connect(func(_v: float) -> void: sync_lighting.call())

	var flash_row := HBoxContainer.new()
	vbox.add_child(flash_row)
	var flash_btn := Button.new()
	flash_btn.text = "Pulso Hit Flash"
	flash_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flash_btn.pressed.connect(func() -> void: rig.trigger_hit_flash(1.0))
	flash_row.add_child(flash_btn)

	var flash_hold_chk := CheckBox.new()
	flash_hold_chk.text = "Hold 1.0"
	flash_hold_chk.toggled.connect(func(v: bool) -> void: rig.set_hit_flash(1.0 if v else 0.0))
	flash_row.add_child(flash_hold_chk)

	var impact_btn := Button.new()
	impact_btn.text = "Impact Frame + Hit-Stop (55ms)"
	impact_btn.pressed.connect(func() -> void: rig.trigger_impact_frame(55.0, 6.0))
	vbox.add_child(impact_btn)

	var pass2_out_str_lbl := Label.new()
	pass2_out_str_lbl.text = "Outline Pasada 2 — Fuerza: 1.00"
	vbox.add_child(pass2_out_str_lbl)
	var pass2_out_str_slider := HSlider.new()
	pass2_out_str_slider.min_value = 0.0
	pass2_out_str_slider.max_value = 1.0
	pass2_out_str_slider.step = 0.05
	pass2_out_str_slider.value = 1.0
	vbox.add_child(pass2_out_str_slider)

	var pass2_out_w_lbl := Label.new()
	pass2_out_w_lbl.text = "Outline Pasada 2 — Grosor: 1.45 px"
	vbox.add_child(pass2_out_w_lbl)
	var pass2_out_w_slider := HSlider.new()
	pass2_out_w_slider.min_value = 0.0
	pass2_out_w_slider.max_value = 8.0
	pass2_out_w_slider.step = 0.05
	pass2_out_w_slider.value = 1.45
	vbox.add_child(pass2_out_w_slider)

	var sync_pass2_outline: Callable = func(_v: float = 0.0) -> void:
		var s_val: float = pass2_out_str_slider.value
		var w_val: float = pass2_out_w_slider.value
		rig.set_outer_outline_params(s_val > 0.01 and w_val > 0.01, w_val, s_val)
		pass2_out_str_lbl.text = "Outline Pasada 2 — Fuerza: %.2f" % s_val
		pass2_out_w_lbl.text = "Outline Pasada 2 — Grosor: %.2f px" % w_val
	pass2_out_str_slider.value_changed.connect(sync_pass2_outline)
	pass2_out_w_slider.value_changed.connect(sync_pass2_outline)
	sync_pass2_outline.call()

	var refresh_static_ui: Array[Callable] = [Callable()]
	var sync_clock_ui: Array[Callable] = [Callable()]
	pilot_opt.item_selected.connect(func(idx: int) -> void:
		if idx < 0 or idx >= profiles.size():
			return
		var p: PilotRigProfile = profiles[idx]
		active_profile[0] = p
		rig.load_pilot_profile(p)
		populate_presets.call(p)
		if not p.style_profiles.is_empty():
			rig.apply_style_profile(p.style_profiles[0])
			halftone_slider.set_value_no_signal(p.style_profiles[0].halftone_strength)
		if not p.skins.is_empty():
			rig.apply_skin_preset(p.skins[0])
		rig.set_recolor_method(recolor_method_opt.selected)
		rig.set_hair_style_mode(hair_style_opt.selected)
		rig.set_shader_param_all("normal_cel_influence", cel_infl_slider.value)
		if flash_hold_chk.button_pressed:
			rig.set_hit_flash(1.0)
		sync_pass2_outline.call()
		if sync_lighting.is_valid():
			sync_lighting.call()
		if refresh_static_ui[0].is_valid():
			refresh_static_ui[0].call()
		if sync_clock_ui[0].is_valid():
			sync_clock_ui[0].call()
	)

	# --- 3. DIRECCIÓN 8-DIR + TRANSICIÓN DE ORIENTACIÓN ---
	_add_section_header(vbox, "3. DIRECCIÓN 8-DIR & TRANSICIÓN")

	var transition_opt := OptionButton.new()
	transition_opt.add_item("Transición 4: Whip-Snap + Afterimage (Recomendado)", 4)
	transition_opt.add_item("Transición 5: Micro-Flash + Snap Seco", 5)
	transition_opt.add_item("Transición 6: Holo-Snap Acelerado (65ms)", 6)
	transition_opt.select(0)
	transition_opt.item_selected.connect(func(idx: int) -> void:
		rig.set_transition_style(transition_opt.get_item_id(idx))
	)
	vbox.add_child(transition_opt)

	var slowmo_chk := CheckButton.new()
	slowmo_chk.text = "Slow-Mo 0.25x (Inspección)"
	slowmo_chk.button_pressed = false
	slowmo_chk.toggled.connect(func(toggled_on: bool) -> void:
		Engine.time_scale = 0.25 if toggled_on else 1.0
	)
	vbox.add_child(slowmo_chk)

	var auto_demo_chk := CheckBox.new()
	auto_demo_chk.text = "Demo Auto 8-Dir + Aim"
	auto_demo_chk.button_pressed = true
	var on_auto_demo: Callable = callbacks.get("on_auto_demo", Callable())
	if on_auto_demo.is_valid():
		auto_demo_chk.toggled.connect(on_auto_demo)
	vbox.add_child(auto_demo_chk)

	# --- 4. INSPECCIÓN & ESCENA ---
	_add_section_header(vbox, "4. INSPECCIÓN & ESCENA")

	var debug_opt := OptionButton.new()
	for lbl: String in [
		"X-Ray 0: Render Final",
		"X-Ray 1: Clown-Pass ID",
		"X-Ray 2: Luminancia",
		"X-Ray 3: Solo Tinta",
		"X-Ray 4: Normales 2.5D",
		"X-Ray 5: Profundidad 2.5D",
	]:
		debug_opt.add_item(lbl)
	debug_opt.item_selected.connect(func(idx: int) -> void:
		rig.set_debug_view_mode(idx)
	)
	vbox.add_child(debug_opt)

	var zoom_opt := OptionButton.new()
	zoom_opt.add_item("Zoom: Close-Up (2.0x)")
	zoom_opt.add_item("Zoom: Combat (1.15x)")
	zoom_opt.add_item("Zoom: Escuadrón (0.65x)")
	var on_zoom: Callable = callbacks.get("on_zoom", Callable())
	if on_zoom.is_valid():
		zoom_opt.item_selected.connect(on_zoom)
	vbox.add_child(zoom_opt)

	var white_bg_chk := CheckBox.new()
	white_bg_chk.text = "Fondo Blanco (Inspección)"
	white_bg_chk.button_pressed = false
	var space_nebula_chk := CheckBox.new()
	space_nebula_chk.text = "Fondo Espacial / Nebulosa (HDR)"
	space_nebula_chk.button_pressed = false
	var on_white_bg: Callable = callbacks.get("on_white_bg", Callable())
	var on_space_nebula: Callable = callbacks.get("on_space_nebula", Callable())
	white_bg_chk.toggled.connect(func(v: bool) -> void:
		if v and space_nebula_chk.button_pressed:
			space_nebula_chk.set_pressed_no_signal(false)
		if on_white_bg.is_valid():
			on_white_bg.call(v)
	)
	space_nebula_chk.toggled.connect(func(v: bool) -> void:
		if v and white_bg_chk.button_pressed:
			white_bg_chk.set_pressed_no_signal(false)
		if on_space_nebula.is_valid():
			on_space_nebula.call(v)
	)
	vbox.add_child(white_bg_chk)
	vbox.add_child(space_nebula_chk)

	var orbit_enemy_chk := CheckBox.new()
	orbit_enemy_chk.text = "Enemigo Base Orbitando (Drone)"
	orbit_enemy_chk.button_pressed = false
	var on_orbit_enemy: Callable = callbacks.get("on_orbit_enemy", Callable())
	if on_orbit_enemy.is_valid():
		orbit_enemy_chk.toggled.connect(on_orbit_enemy)
	vbox.add_child(orbit_enemy_chk)

	var static_inspect_chk := CheckBox.new()
	static_inspect_chk.text = "Inspección Estática (Cuerpo + Cabeza)"
	static_inspect_chk.button_pressed = false
	vbox.add_child(static_inspect_chk)

	var combo_row := HBoxContainer.new()
	vbox.add_child(combo_row)

	var static_body_opt := OptionButton.new()
	rebuild_static_body_options(static_body_opt, rig)
	static_body_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	combo_row.add_child(static_body_opt)

	var static_head_opt := OptionButton.new()
	for i: int in range(HEAD_KEYS.size()):
		static_head_opt.add_item(HEAD_KEYS[i], i)
	static_head_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	combo_row.add_child(static_head_opt)

	var on_static_apply: Callable = callbacks.get("on_static_apply", Callable())
	var on_static_step: Callable = callbacks.get("on_static_step", Callable())
	refresh_static_ui[0] = func() -> void:
		rebuild_static_body_options(static_body_opt, rig)
		if static_inspect_chk.button_pressed and on_static_apply.is_valid():
			on_static_apply.call()
	if on_static_apply.is_valid():
		static_inspect_chk.toggled.connect(func(_v: bool) -> void: on_static_apply.call())
		static_body_opt.item_selected.connect(func(_idx: int) -> void:
			if not static_inspect_chk.button_pressed:
				static_inspect_chk.button_pressed = true
			else:
				on_static_apply.call()
		)
		static_head_opt.item_selected.connect(func(_idx: int) -> void:
			if not static_inspect_chk.button_pressed:
				static_inspect_chk.button_pressed = true
			else:
				on_static_apply.call()
		)

	var nav_row := HBoxContainer.new()
	vbox.add_child(nav_row)
	var prev_btn := Button.new()
	prev_btn.text = "<- Anterior"
	prev_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if on_static_step.is_valid():
		prev_btn.pressed.connect(func() -> void: on_static_step.call(-1))
	nav_row.add_child(prev_btn)

	var next_btn := Button.new()
	next_btn.text = "Siguiente ->"
	next_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if on_static_step.is_valid():
		next_btn.pressed.connect(func() -> void: on_static_step.call(1))
	nav_row.add_child(next_btn)

	var static_combo_lbl := Label.new()
	static_combo_lbl.text = "Combo: (Modo Dinámico)"
	static_combo_lbl.add_theme_font_size_override("font_size", 11)
	vbox.add_child(static_combo_lbl)

	return {
		"hud_layer": hud_layer,
		"pilot_opt": pilot_opt,
		"pilot_profiles": profiles,
		"status_lbl": status_lbl,
		"normal_chk": normal_chk,
		"light_slider": light_slider,
		"hdr_slider": hdr_slider,
		"auto_demo_chk": auto_demo_chk,
		"static_inspect_chk": static_inspect_chk,
		"static_body_opt": static_body_opt,
		"static_head_opt": static_head_opt,
		"static_combo_lbl": static_combo_lbl,
		"active_profile": active_profile[0],
		"flash_hold_chk": flash_hold_chk,
	}


static func _add_opt_with_steppers(parent: VBoxContainer, opt: OptionButton) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)

	var prev_b := Button.new()
	prev_b.text = "<"
	prev_b.custom_minimum_size = Vector2(28.0, 0.0)
	row.add_child(prev_b)

	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt.clip_text = true
	row.add_child(opt)

	var next_b := Button.new()
	next_b.text = ">"
	next_b.custom_minimum_size = Vector2(28.0, 0.0)
	row.add_child(next_b)

	prev_b.pressed.connect(func() -> void:
		if opt.item_count <= 0:
			return
		var nxt: int = (opt.selected - 1 + opt.item_count) % opt.item_count
		opt.select(nxt)
		opt.item_selected.emit(nxt)
	)
	next_b.pressed.connect(func() -> void:
		if opt.item_count <= 0:
			return
		var nxt: int = (opt.selected + 1) % opt.item_count
		opt.select(nxt)
		opt.item_selected.emit(nxt)
	)


static func _add_section_header(parent: VBoxContainer, title_text: String) -> void:
	var sep := HSeparator.new()
	parent.add_child(sep)
	var lbl := Label.new()
	lbl.text = title_text
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.65, 0.88, 1.0, 1.0))
	parent.add_child(lbl)

class_name PlanarLabHudBuilder
extends RefCounted
## Constructor desacoplado del panel HUD para el Planar Combat Rig Lab.
## Expone únicamente las secciones activas:
## - 1. Estilo & Skins (estilos .tres, skins, método recolor, pelo)
## - 3. Dirección 8-Dir & Transición (modos 4..6, slow-mo, órbita auto)
## - 4. Inspección & Escena (Rayos-X, zoom, fondo, dron orbitando)

const PILOTS_ROOT_DIR: String = "res://data/pilots"


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


static func build_hud(
	host: Node,
	rig: PlanarCombatRig,
	styles: Array[RigStyleProfile],
	callbacks: Dictionary
) -> Dictionary:
	var hud_layer := CanvasLayer.new()
	hud_layer.name = "CombatLabHudLayer"
	hud_layer.layer = 10
	host.add_child(hud_layer)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.0
	panel.anchor_right = 0.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 12.0
	panel.offset_right = 336.0
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

	# --- 1. ESTILO & SKINS ---
	_add_section_header(vbox, "1. ESTILO & SKINS")

	var active_profile: PilotRigProfile = rig.pilot_profile as PilotRigProfile if rig != null else null
	var profile_opt := OptionButton.new()
	var skin_opt := OptionButton.new()
	var hair_opt := OptionButton.new()

	for sp: RigStyleProfile in styles:
		if sp != null:
			profile_opt.add_item(sp.label if not sp.label.is_empty() else sp.id)
	if active_profile != null:
		for sk: PilotSkinPreset in active_profile.skins:
			if sk != null:
				skin_opt.add_item(sk.label)
		for hp: PilotHairPreset in active_profile.hair_presets:
			if hp != null:
				hair_opt.add_item(hp.label)

	var on_style_selected: Callable = callbacks.get("on_style_selected", Callable())
	profile_opt.item_selected.connect(func(idx: int) -> void:
		if on_style_selected.is_valid():
			on_style_selected.call(idx)
		elif rig != null and idx >= 0 and idx < styles.size():
			rig.apply_style_profile(styles[idx])
	)
	_add_opt_with_steppers(vbox, profile_opt)

	skin_opt.item_selected.connect(func(idx: int) -> void:
		if rig == null or active_profile == null or idx < 0 or idx >= active_profile.skins.size():
			return
		var sk: PilotSkinPreset = active_profile.skins[idx]
		rig.apply_skin_preset(sk)
		if hair_opt.selected > 0 and hair_opt.selected < active_profile.hair_presets.size():
			rig.apply_hair_preset(active_profile.hair_presets[hair_opt.selected], sk.hair_color)
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
		if rig != null:
			rig.set_recolor_method(idx)
	)
	vbox.add_child(recolor_method_opt)

	hair_opt.item_selected.connect(func(idx: int) -> void:
		if rig == null or active_profile == null or idx < 0 or idx >= active_profile.hair_presets.size():
			return
		var sk_idx: int = clampi(skin_opt.selected, 0, maxi(active_profile.skins.size() - 1, 0))
		var skin_hair: Color = active_profile.skins[sk_idx].hair_color if not active_profile.skins.is_empty() else Color.WHITE
		rig.apply_hair_preset(active_profile.hair_presets[idx], skin_hair)
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
		if rig != null:
			rig.set_hair_style_mode(idx)
	)
	vbox.add_child(hair_style_opt)

	# --- 3. DIRECCIÓN 8-DIR & TRANSICIÓN ---
	_add_section_header(vbox, "3. DIRECCIÓN 8-DIR & TRANSICIÓN")

	var transition_opt := OptionButton.new()
	transition_opt.add_item("Transición 4: Whip-Snap + Afterimage (Recomendado)", 4)
	transition_opt.add_item("Transición 5: Micro-Flash + Snap Seco", 5)
	transition_opt.add_item("Transición 6: Holo-Snap Acelerado (65ms)", 6)
	transition_opt.select(0)
	transition_opt.item_selected.connect(func(idx: int) -> void:
		if rig != null:
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
	auto_demo_chk.text = "Órbita Auto (Estrella + Mira Fija)"
	auto_demo_chk.button_pressed = true
	auto_demo_chk.focus_mode = Control.FOCUS_NONE
	var manual_control_chk := CheckBox.new()
	manual_control_chk.text = "Control Manual (WASD + Ratón)"
	manual_control_chk.button_pressed = false
	manual_control_chk.focus_mode = Control.FOCUS_NONE

	var on_auto_demo: Callable = callbacks.get("on_auto_demo", Callable())
	var on_manual_control: Callable = callbacks.get("on_manual_control", Callable())
	auto_demo_chk.toggled.connect(func(v: bool) -> void:
		manual_control_chk.set_pressed_no_signal(not v)
		if on_auto_demo.is_valid():
			on_auto_demo.call(v)
	)
	manual_control_chk.toggled.connect(func(v: bool) -> void:
		auto_demo_chk.set_pressed_no_signal(not v)
		if on_manual_control.is_valid():
			on_manual_control.call(v)
		elif on_auto_demo.is_valid():
			on_auto_demo.call(not v)
	)
	vbox.add_child(auto_demo_chk)
	vbox.add_child(manual_control_chk)

	var pose_row := HBoxContainer.new()
	pose_row.add_theme_constant_override("separation", 4)
	vbox.add_child(pose_row)

	var pose_mode_opt := OptionButton.new()
	pose_mode_opt.add_item("Pose Base: Guardia Zero-G (Huesos + 2.5D)", 0)
	pose_mode_opt.add_item("Pose Base: Guardia Zero-G (Solo Huesos 2D)", 1)
	pose_mode_opt.add_item("Pose Base: Guardia Zero-G (Solo 2.5D)", 2)
	pose_mode_opt.add_item("Pose Base: Default Rig (Rest Pose)", 3)
	pose_mode_opt.select(0)
	pose_mode_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pose_mode_opt.clip_text = true
	var on_pose_mode: Callable = callbacks.get("on_pose_mode_selected", Callable())
	if on_pose_mode.is_valid():
		pose_mode_opt.item_selected.connect(on_pose_mode)
	pose_row.add_child(pose_mode_opt)

	var reload_pose_btn := Button.new()
	reload_pose_btn.text = "↺ .tres"
	reload_pose_btn.tooltip_text = "Recargar Pose Base, Idle, Vuelo, Giros, Jiggle y Facial desde .tres"
	var on_reload_pose: Callable = callbacks.get("on_reload_base_pose", Callable())
	if on_reload_pose.is_valid():
		reload_pose_btn.pressed.connect(on_reload_pose)
	pose_row.add_child(reload_pose_btn)

	var idle_anim_chk := CheckBox.new()
	idle_anim_chk.text = "Animación Idle Zero-G (.tres)"
	idle_anim_chk.button_pressed = true
	var on_idle_anim: Callable = callbacks.get("on_idle_anim_toggled", Callable())
	if on_idle_anim.is_valid():
		idle_anim_chk.toggled.connect(on_idle_anim)
	vbox.add_child(idle_anim_chk)

	var loco_anim_chk := CheckBox.new()
	loco_anim_chk.text = "Movimiento & Freno Suave (.tres)"
	loco_anim_chk.button_pressed = true
	var on_loco_anim: Callable = callbacks.get("on_loco_anim_toggled", Callable())
	if on_loco_anim.is_valid():
		loco_anim_chk.toggled.connect(on_loco_anim)
	vbox.add_child(loco_anim_chk)

	var kiting_anim_chk := CheckBox.new()
	kiting_anim_chk.text = "Kiting 360° & Reversa (.tres)"
	kiting_anim_chk.button_pressed = true
	var on_kiting_anim: Callable = callbacks.get("on_kiting_anim_toggled", Callable())
	if on_kiting_anim.is_valid():
		kiting_anim_chk.toggled.connect(on_kiting_anim)
	vbox.add_child(kiting_anim_chk)

	var turn_anim_chk := CheckBox.new()
	turn_anim_chk.text = "Giros Snappy & Whip Cabeza (.tres)"
	turn_anim_chk.button_pressed = true
	var on_turn_anim: Callable = callbacks.get("on_turn_anim_toggled", Callable())
	if on_turn_anim.is_valid():
		turn_anim_chk.toggled.connect(on_turn_anim)
	vbox.add_child(turn_anim_chk)

	var jiggle_anim_chk := CheckBox.new()
	jiggle_anim_chk.text = "Jiggle Busto & Glúteos (.tres)"
	jiggle_anim_chk.button_pressed = true
	var on_jiggle_anim: Callable = callbacks.get("on_jiggle_anim_toggled", Callable())
	if on_jiggle_anim.is_valid():
		jiggle_anim_chk.toggled.connect(on_jiggle_anim)
	vbox.add_child(jiggle_anim_chk)

	var face_anim_chk := CheckBox.new()
	face_anim_chk.text = "Rig Facial Vivo & Personalidad (.tres)"
	face_anim_chk.button_pressed = true
	var on_face_anim: Callable = callbacks.get("on_face_anim_toggled", Callable())
	if on_face_anim.is_valid():
		face_anim_chk.toggled.connect(on_face_anim)
	vbox.add_child(face_anim_chk)

	var face_personality_opt := OptionButton.new()
	face_personality_opt.add_item("Personalidad: Táctica Fría (Estoica)", 0)
	face_personality_opt.add_item("Personalidad: Piloto Ace Confiada", 1)
	face_personality_opt.add_item("Personalidad: Anime Dinámico", 2)
	face_personality_opt.select(0)
	var on_face_pers: Callable = callbacks.get("on_face_personality_selected", Callable())
	if on_face_pers.is_valid():
		face_personality_opt.item_selected.connect(func(idx: int) -> void:
			on_face_pers.call(face_personality_opt.get_item_id(idx))
		)
	vbox.add_child(face_personality_opt)

	var face_comms_btn := Button.new()
	face_comms_btn.text = "Comms Táctico (C)"
	var on_face_comms: Callable = callbacks.get("on_face_comms_pressed", Callable())
	if on_face_comms.is_valid():
		face_comms_btn.pressed.connect(on_face_comms)
	vbox.add_child(face_comms_btn)

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
		"X-Ray 6: Máscara ILM",
		"X-Ray 7: Face Live Mask (R/G/B/A)",
		"X-Ray 8: Hair 3-Zone (R/G/B)",
	]:
		debug_opt.add_item(lbl)
	debug_opt.item_selected.connect(func(idx: int) -> void:
		if rig != null:
			rig.set_debug_view_mode(idx)
	)
	vbox.add_child(debug_opt)

	var zoom_opt := OptionButton.new()
	zoom_opt.add_item("Zoom: Close-Up (2.0x)")
	zoom_opt.add_item("Zoom: Estudio (1.45x)")
	zoom_opt.add_item("Zoom: Combat (1.15x)")
	zoom_opt.add_item("Zoom: Escuadrón (0.65x)")
	zoom_opt.select(1)
	var on_zoom: Callable = callbacks.get("on_zoom", Callable())
	if on_zoom.is_valid():
		zoom_opt.item_selected.connect(on_zoom)
	vbox.add_child(zoom_opt)

	var white_bg_chk := CheckBox.new()
	white_bg_chk.text = "Fondo Blanco (Inspección)"
	white_bg_chk.button_pressed = false
	var space_nebula_chk := CheckBox.new()
	space_nebula_chk.text = "Fondo Espacial / Nebulosa (HDR)"
	space_nebula_chk.button_pressed = true
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

	return {
		"hud_layer": hud_layer,
		"status_lbl": status_lbl,
		"profile_opt": profile_opt,
		"skin_opt": skin_opt,
		"recolor_method_opt": recolor_method_opt,
		"hair_opt": hair_opt,
		"hair_style_opt": hair_style_opt,
		"transition_opt": transition_opt,
		"slowmo_chk": slowmo_chk,
		"auto_demo_chk": auto_demo_chk,
		"manual_control_chk": manual_control_chk,
		"pose_mode_opt": pose_mode_opt,
		"reload_pose_btn": reload_pose_btn,
		"idle_anim_chk": idle_anim_chk,
		"loco_anim_chk": loco_anim_chk,
		"kiting_anim_chk": kiting_anim_chk,
		"turn_anim_chk": turn_anim_chk,
		"jiggle_anim_chk": jiggle_anim_chk,
		"face_anim_chk": face_anim_chk,
		"face_personality_opt": face_personality_opt,
		"face_comms_btn": face_comms_btn,
		"debug_opt": debug_opt,
		"zoom_opt": zoom_opt,
		"white_bg_chk": white_bg_chk,
		"space_nebula_chk": space_nebula_chk,
		"orbit_enemy_chk": orbit_enemy_chk,
		"active_profile": active_profile,
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

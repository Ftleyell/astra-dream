class_name RigCalibratorLayerBuilder
extends RefCounted
## Sincronizador visual de capas, opacidad, orden Z en CanvasGroup, Ghost Pose
## y generador de filas en el Dock Izquierdo para el Calibrador de Valentina v2.

const PARTS_TIE_ORDER: Array[String] = ["leg_r", "leg_l", "arm_r", "arm_l", "body_core", "pauldron_r", "pauldron_l"]


static func rebuild_layers_ui(
	layers_list: VBoxContainer,
	bones_list: VBoxContainer,
	store: RigCalibrationStore,
	view_key: String,
	head_key: String,
	state: Dictionary,
	callbacks: Dictionary
) -> void:
	for c: Node in layers_list.get_children():
		layers_list.remove_child(c)
		c.queue_free()
	for c: Node in bones_list.get_children():
		bones_list.remove_child(c)
		c.queue_free()

	var part_vis: Dictionary = state["part_vis"] as Dictionary
	var part_opac: Dictionary = state["part_opac"] as Dictionary
	var sel_kind: String = str(state["selected_kind"])
	var sel_name: String = str(state["selected_name"])
	var solo_target: String = str(state.get("solo_target", ""))

	# Fila de Cabeza (Pass 2: rostro/pelo sobre torso) arriba del todo
	_add_layer_row(
		layers_list,
		"head",
		"Cabeza (%s) [Over]" % head_key.replace("head_", ""),
		bool(state.get("head_vis", true)),
		float(state.get("head_opac", 1.0)),
		sel_kind == "head",
		solo_target == "head",
		false,
		0,
		callbacks
	)

	var ordered: Array[String] = store.get_ordered_part_names(view_key)
	for p_name: String in ordered:
		var z_val: int = store.get_part_z_order(view_key, p_name)
		_add_layer_row(
			layers_list,
			p_name,
			p_name,
			bool(part_vis.get(p_name, true)),
			float(part_opac.get(p_name, 1.0)),
			sel_kind == "part" and sel_name == p_name,
			solo_target == p_name,
			true,
			z_val,
			callbacks
		)

	# Fila de Cuello/Pelo trasero (Pass 1: bajo torso) abajo del todo
	_add_layer_row(
		layers_list,
		"head_under",
		"Cuello (%s) [Under]" % head_key.replace("head_", ""),
		bool(state.get("head_under_vis", true)),
		float(state.get("head_under_opac", 1.0)),
		false,
		solo_target == "head_under",
		false,
		0,
		callbacks
	)

	var bone_names: Array[String] = store.get_bone_names(view_key)
	for b_name: String in bone_names:
		var b_btn := Button.new()
		b_btn.text = b_name
		b_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b_btn.add_theme_font_size_override("font_size", 11)
		if sel_kind == "bone" and sel_name == b_name:
			b_btn.modulate = Color(1.0, 0.90, 0.35, 1.0)
		var cb_bone: Callable = callbacks.get("on_select_bone", Callable())
		b_btn.pressed.connect(func() -> void:
			if cb_bone.is_valid():
				cb_bone.call(b_name)
		)
		bones_list.add_child(b_btn)


static func _add_layer_row(
	parent: VBoxContainer,
	key: String,
	label_txt: String,
	is_vis: bool,
	opacity: float,
	is_selected: bool,
	is_solo: bool,
	allow_z: bool,
	z_val: int,
	callbacks: Dictionary
) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	parent.add_child(box)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	box.add_child(row)

	var eye_btn := Button.new()
	eye_btn.text = "V" if is_vis else "-"
	eye_btn.tooltip_text = "Mostrar / Ocultar"
	eye_btn.custom_minimum_size = Vector2(24.0, 0.0)
	eye_btn.modulate = Color(0.55, 0.95, 0.72, 1.0) if is_vis else Color(0.55, 0.55, 0.60, 0.75)
	var cb_vis: Callable = callbacks.get("on_toggle_vis", Callable())
	eye_btn.pressed.connect(func() -> void:
		if cb_vis.is_valid():
			cb_vis.call(key)
	)
	row.add_child(eye_btn)

	var solo_btn := Button.new()
	solo_btn.text = "S"
	solo_btn.tooltip_text = "Aislar (Solo esta pieza)"
	solo_btn.custom_minimum_size = Vector2(24.0, 0.0)
	if is_solo:
		solo_btn.modulate = Color(1.0, 0.78, 0.25, 1.0)
	var cb_solo: Callable = callbacks.get("on_toggle_solo", Callable())
	solo_btn.pressed.connect(func() -> void:
		if cb_solo.is_valid():
			cb_solo.call(key)
	)
	row.add_child(solo_btn)

	var sel_btn := Button.new()
	sel_btn.text = ("%s [Z%d]" % [label_txt, z_val]) if allow_z else label_txt
	sel_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	sel_btn.clip_text = true
	sel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sel_btn.add_theme_font_size_override("font_size", 11)
	if is_selected:
		sel_btn.modulate = Color(1.0, 0.88, 0.30, 1.0)
	var cb_sel: Callable = callbacks.get("on_select_layer", Callable())
	sel_btn.pressed.connect(func() -> void:
		if cb_sel.is_valid():
			cb_sel.call(key)
	)
	row.add_child(sel_btn)

	if allow_z:
		var up_btn := Button.new()
		up_btn.text = "^"
		up_btn.tooltip_text = "Subir Z-Order"
		up_btn.custom_minimum_size = Vector2(22.0, 0.0)
		var dn_btn := Button.new()
		dn_btn.text = "v"
		dn_btn.tooltip_text = "Bajar Z-Order"
		dn_btn.custom_minimum_size = Vector2(22.0, 0.0)
		var cb_z: Callable = callbacks.get("on_step_z", Callable())
		up_btn.pressed.connect(func() -> void:
			if cb_z.is_valid():
				cb_z.call(key, 1)
		)
		dn_btn.pressed.connect(func() -> void:
			if cb_z.is_valid():
				cb_z.call(key, -1)
		)
		row.add_child(up_btn)
		row.add_child(dn_btn)

	var op_slider := HSlider.new()
	op_slider.min_value = 0.05
	op_slider.max_value = 1.0
	op_slider.step = 0.05
	op_slider.value = opacity
	op_slider.custom_minimum_size = Vector2(0.0, 12.0)
	var cb_op: Callable = callbacks.get("on_opacity_changed", Callable())
	op_slider.value_changed.connect(func(v: float) -> void:
		if cb_op.is_valid():
			cb_op.call(key, v)
	)
	box.add_child(op_slider)


static func sync_rig_live_state(
	rig: PlanarCombatRig,
	store: RigCalibrationStore,
	view_key: String,
	head_key: String,
	built_part_origins: Dictionary,
	state: Dictionary
) -> void:
	if rig == null:
		return
	var views: Dictionary = rig.get_views()
	if not views.has(view_key):
		return
	var vd: Dictionary = views[view_key] as Dictionary
	var polys: Dictionary = vd.get("polys", {}) as Dictionary
	var bones: Dictionary = vd.get("bones", {}) as Dictionary
	var rest_pos: Dictionary = vd.get("rest_pos", {}) as Dictionary
	var view_root: Node2D = vd.get("root", null) as Node2D
	var meshes_root: Node2D = view_root.get_node_or_null("Meshes") as Node2D if view_root != null else null

	var part_vis: Dictionary = state["part_vis"] as Dictionary
	var part_opac: Dictionary = state["part_opac"] as Dictionary
	var view_built_origins: Dictionary = built_part_origins.get(view_key, {}) as Dictionary

	# 1. Aplicar posiciones, visibilidad y opacidad de piezas (incluyendo _stocking)
	for p_name: String in RigCalibrationStore.PART_KEYS:
		var cur_rect: Rect2 = store.get_part_rect_rel(view_key, p_name, false)
		var built_origin: Vector2 = view_built_origins.get(p_name, cur_rect.position) as Vector2
		var offset_delta: Vector2 = cur_rect.position - built_origin
		var vis: bool = bool(part_vis.get(p_name, true))
		var alpha: float = float(part_opac.get(p_name, 1.0))
		var p_out: Dictionary = store.get_part_outline(view_key, p_name, false)

		for poly_key: String in [p_name, "%s_stocking" % p_name]:
			if not polys.has(poly_key):
				continue
			var poly: Polygon2D = polys[poly_key] as Polygon2D
			if poly == null:
				continue
			poly.position = offset_delta
			poly.visible = vis
			poly.modulate.a = alpha
			if poly.material is ShaderMaterial:
				var p_mat: ShaderMaterial = poly.material as ShaderMaterial
				if cur_rect.size != Vector2.ZERO:
					p_mat.set_shader_parameter(
						"part_rig_rect",
						Vector4(cur_rect.position.x / 490.0, cur_rect.position.y / 490.0, cur_rect.size.x / 490.0, cur_rect.size.y / 490.0)
					)
				_apply_outline_uniforms(p_mat, p_out)

	# 1b. Aplicar sombra cel de contacto traje -> piernas (hip_cast_shadow) + pinch de media (stocking_pinch)
	var hip_sh: Dictionary = store.get_hip_cast_shadow(view_key, false)
	var st_pinch: Dictionary = store.get_stocking_pinch(view_key, false)
	var bc_poly: Polygon2D = polys.get("body_core", null) as Polygon2D
	var bc_tex: Texture2D = bc_poly.texture if bc_poly != null else null
	var bc_rect_cur: Rect2 = store.get_part_rect_rel(view_key, "body_core", false)
	var bc_rect_abs: Rect2 = store.get_part_rect_abs(view_key, "body_core", false)
	var bc_rect_v4 := Vector4(bc_rect_cur.position.x / 490.0, bc_rect_cur.position.y / 490.0, bc_rect_cur.size.x / 490.0, bc_rect_cur.size.y / 490.0)
	var neck_rel_live: Vector2 = store.get_neck_anchor_rel(view_key, false)
	if bc_poly != null and bc_poly.material is ShaderMaterial and bc_rect_abs.size.x > 1.0 and bc_rect_abs.size.y > 1.0:
		var bc_mat: ShaderMaterial = bc_poly.material as ShaderMaterial
		var neck_abs_live: Vector2 = store.get_rig_origin(view_key) + neck_rel_live
		var neck_u: float = clampf((neck_abs_live.x - bc_rect_abs.position.x) / bc_rect_abs.size.x, 0.05, 0.95)
		var neck_v_norm: float = clampf((neck_abs_live.y - bc_rect_abs.position.y) / bc_rect_abs.size.y, 0.0, 0.22)
		var neck_max_v: float = maxf(0.085, neck_v_norm + 0.040)
		var neck_half_w: float = clampf(22.0 / bc_rect_abs.size.x, 0.14, 0.28)
		bc_mat.set_shader_parameter("neck_seam_u", neck_u)
		bc_mat.set_shader_parameter("neck_seam_half_w", neck_half_w)
		bc_mat.set_shader_parameter("neck_seam_max_v", neck_max_v)
	var use_cast: bool = bool(hip_sh["enabled"]) and bc_tex != null and bc_rect_cur.size != Vector2.ZERO
	var use_pinch: bool = bool(st_pinch["enabled"])
	for leg_poly_key: String in ["leg_r", "leg_r_stocking", "leg_l", "leg_l_stocking"]:
		var l_poly: Polygon2D = polys.get(leg_poly_key, null) as Polygon2D
		if l_poly == null or not (l_poly.material is ShaderMaterial):
			continue
		var l_mat: ShaderMaterial = l_poly.material as ShaderMaterial
		l_mat.set_shader_parameter("enable_hip_cast_shadow", use_cast)
		if use_cast:
			l_mat.set_shader_parameter("hip_cast_body_tex", bc_tex)
			l_mat.set_shader_parameter("hip_cast_body_rect", bc_rect_v4)
			l_mat.set_shader_parameter("hip_cast_pelvis_delta", Vector2.ZERO)
			l_mat.set_shader_parameter("hip_cast_shadow_offset_px", hip_sh["offset"] as Vector2)
			l_mat.set_shader_parameter("hip_cast_shadow_color", hip_sh["color"] as Color)
		var v_key_sp: String = "v_l" if leg_poly_key.begins_with("leg_l") else "v_r"
		var tilt_key: String = "tilt_l" if leg_poly_key.begins_with("leg_l") else "tilt_r"
		var v_val_sp: float = float(st_pinch[v_key_sp])
		var center_u_sp: float = RigCalibrationStore.compute_pinch_center_u(l_poly.texture, v_val_sp)
		l_mat.set_shader_parameter("enable_stocking_pinch", use_pinch)
		l_mat.set_shader_parameter("debug_stocking_pinch_overlay", bool(state.get("pinch_overlay", false)))
		l_mat.set_shader_parameter("stocking_pinch_v", v_val_sp)
		l_mat.set_shader_parameter("stocking_pinch_center_u", center_u_sp)
		l_mat.set_shader_parameter("stocking_pinch_tilt", float(st_pinch[tilt_key]))
		l_mat.set_shader_parameter("stocking_pinch_strength", float(st_pinch["strength"]))
		l_mat.set_shader_parameter("stocking_pinch_width", float(st_pinch["width"]))
		l_mat.set_shader_parameter("stocking_pinch_shadow", float(st_pinch["shadow"]))

	# 2. Reordenar hijos en Meshes según z_orders (siempre z_index = 0 dentro de CanvasGroup)
	if meshes_root != null:
		var z_orders: Dictionary = store.get_view_meta(view_key).get("z_orders", {}) as Dictionary
		var sorted_parts: Array[String] = []
		for pk: String in PARTS_TIE_ORDER:
			if polys.has(pk):
				sorted_parts.append(pk)
		sorted_parts.sort_custom(func(a: String, b: String) -> bool:
			var za: int = int(z_orders.get(a, 0))
			var zb: int = int(z_orders.get(b, 0))
			if za != zb:
				return za < zb
			return PARTS_TIE_ORDER.find(a) < PARTS_TIE_ORDER.find(b)
		)
		var child_idx: int = 0
		for pk: String in sorted_parts:
			var p_node: Polygon2D = polys[pk] as Polygon2D
			if p_node != null and p_node.get_parent() == meshes_root:
				p_node.z_index = 0
				meshes_root.move_child(p_node, child_idx)
				child_idx += 1
			if pk == "body_core":
				for st_k: String in ["leg_r_stocking", "leg_l_stocking"]:
					if polys.has(st_k):
						var st_node: Polygon2D = polys[st_k] as Polygon2D
						if st_node != null and st_node.get_parent() == meshes_root:
							st_node.z_index = 0
							meshes_root.move_child(st_node, child_idx)
							child_idx += 1

	# 3. Sincronizar posiciones locales de huesos (manteniendo rest_pos actualizado)
	for b_name: String in store.get_bone_names(view_key):
		if not bones.has(b_name):
			continue
		var bone: Bone2D = bones[b_name] as Bone2D
		var parent_name: String = store.get_bone_parent(view_key, b_name)
		var rel_p: Vector2 = store.get_bone_pos_rel(view_key, b_name, false)
		var parent_rel: Vector2 = store.get_bone_pos_rel(view_key, parent_name, false) if not parent_name.is_empty() else Vector2.ZERO
		var local_p: Vector2 = rel_p - parent_rel
		bone.position = local_p
		bone.rest = bone.transform
		rest_pos[b_name] = local_p

	# 4. Sincronizar cabezas (ambas pasadas: head_anchor [Pass 2] y head_under_anchor [Pass 1 cuello])
	var head_vis: bool = bool(state.get("head_vis", true))
	var head_alpha: float = float(state.get("head_opac", 1.0))
	var head_under_vis: bool = bool(state.get("head_under_vis", true))
	var head_under_alpha: float = float(state.get("head_under_opac", 1.0))
	var h_off: Vector2 = store.get_head_combo_offset(view_key, head_key, false)
	var h_scale_mul: float = store.get_head_combo_scale(view_key, head_key, false)
	var neck_rel: Vector2 = store.get_neck_anchor_rel(view_key, false)
	var disp_sz: Vector2 = store.get_head_disp_size(head_key)
	var scaled_disp_sz: Vector2 = disp_sz * h_scale_mul
	var h_orig: Vector2 = neck_rel + h_off - scaled_disp_sz * 0.5
	var heads_meta_snap: Dictionary = store.get_heads_meta_snapshot()
	var h_out: Dictionary = store.get_head_outline(head_key, false)

	var head_passes: Array[Dictionary] = [
		{"data": rig.get_head_data(), "vis": head_vis, "alpha": head_alpha},
		{"data": rig.get_head_under_data(), "vis": head_under_vis, "alpha": head_under_alpha},
	]
	for pass_cfg: Dictionary in head_passes:
		var h_dict: Dictionary = pass_cfg["data"] as Dictionary
		if h_dict.is_empty():
			continue
		if not heads_meta_snap.is_empty():
			h_dict["meta"] = heads_meta_snap.duplicate(true)
		var base_offsets: Dictionary = h_dict.get("base_offsets", {}) as Dictionary
		var base_scales: Dictionary = h_dict.get("base_scales", {}) as Dictionary
		if not store.has_head_combo(view_key, head_key, false):
			base_offsets[head_key] = h_off
		var sprites: Dictionary = h_dict.get("sprites", {}) as Dictionary
		if sprites.has(head_key):
			var spr: Sprite2D = sprites[head_key] as Sprite2D
			var b_scale: Vector2 = base_scales.get(head_key, spr.scale) as Vector2
			spr.position = h_off
			spr.scale = b_scale * h_scale_mul
			spr.visible = bool(pass_cfg["vis"])
			spr.modulate.a = float(pass_cfg["alpha"])
			if spr.material is ShaderMaterial:
				var h_mat: ShaderMaterial = spr.material as ShaderMaterial
				h_mat.set_shader_parameter(
					"part_rig_rect",
					Vector4(h_orig.x / 490.0, h_orig.y / 490.0, scaled_disp_sz.x / 490.0, scaled_disp_sz.y / 490.0)
				)
				_apply_outline_uniforms(h_mat, h_out)


static func _apply_outline_uniforms(mat: ShaderMaterial, cfg: Dictionary) -> void:
	mat.set_shader_parameter("enable_part_edge_outline", bool(cfg.get("enabled", false)))
	mat.set_shader_parameter("part_edge_erode_du", float(cfg.get("erode_du", 0.0)))
	mat.set_shader_parameter("part_edge_outline_du", float(cfg.get("outline_du", 0.0)))
	mat.set_shader_parameter("part_edge_outline_color", cfg.get("color", RigCalibrationStore.DEFAULT_PART_OUTLINE_COLOR) as Color)
	mat.set_shader_parameter("part_edge_respect_seams", bool(cfg.get("respect_seams", false)))


static func rebuild_ghost_node(
	ghost_root: Node2D,
	rig: PlanarCombatRig,
	store: RigCalibrationStore,
	view_key: String,
	head_key: String,
	visible_ghost: bool,
	ghost_opacity: float
) -> void:
	for c: Node in ghost_root.get_children():
		ghost_root.remove_child(c)
		c.queue_free()
	ghost_root.visible = visible_ghost
	if not visible_ghost or rig == null:
		return
	var views: Dictionary = rig.get_views()
	if not views.has(view_key):
		return
	ghost_root.scale = rig.scale
	ghost_root.modulate = Color(0.35, 0.88, 1.0, ghost_opacity)

	var vd: Dictionary = views[view_key] as Dictionary
	var polys: Dictionary = vd.get("polys", {}) as Dictionary
	var ordered: Array[String] = store.get_ordered_part_names(view_key)
	ordered.reverse()
	for p_name: String in ordered:
		if not polys.has(p_name):
			continue
		var src_poly: Polygon2D = polys[p_name] as Polygon2D
		var base_r: Rect2 = store.get_part_rect_rel(view_key, p_name, true)
		if src_poly == null or src_poly.texture == null or base_r.size == Vector2.ZERO:
			continue
		var g_spr := Sprite2D.new()
		g_spr.texture = src_poly.texture
		g_spr.centered = false
		g_spr.position = base_r.position
		var tex_sz: Vector2 = src_poly.texture.get_size()
		g_spr.scale = Vector2(base_r.size.x / maxf(tex_sz.x, 1.0), base_r.size.y / maxf(tex_sz.y, 1.0))
		ghost_root.add_child(g_spr)

	var h_data: Dictionary = rig.get_head_data()
	var h_sprites: Dictionary = h_data.get("sprites", {}) as Dictionary
	var h_base_scales: Dictionary = h_data.get("base_scales", {}) as Dictionary
	if h_sprites.has(head_key):
		var src_h: Sprite2D = h_sprites[head_key] as Sprite2D
		if src_h != null and src_h.texture != null:
			var gh_spr := Sprite2D.new()
			gh_spr.texture = src_h.texture
			gh_spr.centered = true
			gh_spr.position = store.get_neck_anchor_rel(view_key, true) + store.get_head_combo_offset(view_key, head_key, true)
			var base_sc: Vector2 = h_base_scales.get(head_key, src_h.scale) as Vector2
			gh_spr.scale = base_sc * store.get_head_combo_scale(view_key, head_key, true)
			ghost_root.add_child(gh_spr)

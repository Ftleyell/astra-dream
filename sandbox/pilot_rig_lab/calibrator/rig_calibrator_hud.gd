class_name RigCalibratorHud
extends RefCounted
## Constructor modular de la interfaz IDE/CAD para el Calibrador Manual de Valentina v2.
## Tres paneles acoplados (Barra Superior, Dock Izquierdo de Capas, Dock Derecho de Inspector)
## dejando el área central libre para el viewport y reglas.

const LEFT_DOCK_W: float = 268.0
const RIGHT_DOCK_W: float = 320.0
const TOP_BAR_H: float = 44.0

const VIEW_KEYS: Array[String] = ["s", "se", "e", "ne", "n", "nw", "w", "sw"]
const HEAD_KEYS: Array[String] = [
	"head_front", "head_front_r", "head_side_r", "head_back_r",
	"head_back", "head_back_l", "head_side_l", "head_front_l",
]
const STEP_PRESETS: Array[float] = [0.25, 1.0, 5.0, 10.0]


static func populate_head_options(head_opt: OptionButton, allowed_heads: Array[String], selected_head: String) -> void:
	if head_opt == null:
		return
	head_opt.clear()
	var sel_idx: int = 0
	for i: int in range(allowed_heads.size()):
		var hk: String = allowed_heads[i]
		head_opt.add_item(hk)
		head_opt.set_item_metadata(i, hk)
		if hk == selected_head:
			sel_idx = i
	if head_opt.item_count > 0:
		head_opt.select(sel_idx)


static func build_ui(parent_layer: CanvasLayer, callbacks: Dictionary) -> Dictionary:
	var root := Control.new()
	root.name = "CalibratorHudRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent_layer.add_child(root)

	# --- TOP TOOLBAR ---
	var top_panel := PanelContainer.new()
	top_panel.anchor_left = 0.0
	top_panel.anchor_right = 1.0
	top_panel.anchor_top = 0.0
	top_panel.anchor_bottom = 0.0
	top_panel.offset_bottom = TOP_BAR_H
	root.add_child(top_panel)

	var top_hbox := HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 6)
	top_panel.add_child(top_hbox)

	var view_lbl := Label.new()
	view_lbl.text = "Vista:"
	top_hbox.add_child(view_lbl)

	var prev_view_btn := Button.new()
	prev_view_btn.text = "<"
	top_hbox.add_child(prev_view_btn)

	var view_opt := OptionButton.new()
	for vk: String in VIEW_KEYS:
		view_opt.add_item(vk.to_upper())
	top_hbox.add_child(view_opt)

	var next_view_btn := Button.new()
	next_view_btn.text = ">"
	top_hbox.add_child(next_view_btn)

	var head_lbl := Label.new()
	head_lbl.text = "Cabeza:"
	top_hbox.add_child(head_lbl)

	var head_opt := OptionButton.new()
	head_opt.tooltip_text = "Cabezas compatibles con el cuerpo activo (misma lista que Animation Lab)"
	top_hbox.add_child(head_opt)

	var auto_head_chk := CheckBox.new()
	auto_head_chk.text = "Auto"
	auto_head_chk.button_pressed = true
	top_hbox.add_child(auto_head_chk)

	var next_combo_btn := Button.new()
	next_combo_btn.text = "Combo >"
	next_combo_btn.tooltip_text = "Ciclar cabezas válidas de la vista activa"
	top_hbox.add_child(next_combo_btn)

	top_hbox.add_child(VSeparator.new())

	var step_lbl := Label.new()
	step_lbl.text = "Paso:"
	top_hbox.add_child(step_lbl)

	var step_group := ButtonGroup.new()
	var step_btns: Dictionary = {}
	for sp_val: float in STEP_PRESETS:
		var sb := Button.new()
		sb.toggle_mode = true
		sb.button_group = step_group
		sb.text = ("%.2f" % sp_val) if sp_val < 1.0 else ("%d" % int(sp_val))
		sb.button_pressed = is_equal_approx(sp_val, 1.0)
		var cb_step: Callable = callbacks.get("on_step_selected", Callable())
		sb.pressed.connect(func() -> void:
			if cb_step.is_valid():
				cb_step.call(sp_val)
		)
		top_hbox.add_child(sb)
		step_btns[sp_val] = sb

	top_hbox.add_child(VSeparator.new())

	var snap_grid_chk := CheckBox.new()
	snap_grid_chk.text = "Snap Grilla"
	snap_grid_chk.button_pressed = false
	top_hbox.add_child(snap_grid_chk)

	var snap_guide_chk := CheckBox.new()
	snap_guide_chk.text = "Snap Guías"
	snap_guide_chk.button_pressed = true
	top_hbox.add_child(snap_guide_chk)

	top_hbox.add_child(VSeparator.new())

	var rulers_chk := CheckBox.new()
	rulers_chk.text = "Reglas"
	rulers_chk.button_pressed = true
	top_hbox.add_child(rulers_chk)

	var grid_chk := CheckBox.new()
	grid_chk.text = "Grilla"
	grid_chk.button_pressed = true
	top_hbox.add_child(grid_chk)

	var bbox_chk := CheckBox.new()
	bbox_chk.text = "BBox"
	bbox_chk.button_pressed = true
	top_hbox.add_child(bbox_chk)

	var bones_chk := CheckBox.new()
	bones_chk.text = "Huesos"
	bones_chk.button_pressed = true
	top_hbox.add_child(bones_chk)

	var ghost_chk := CheckBox.new()
	ghost_chk.text = "Ghost"
	ghost_chk.button_pressed = false
	top_hbox.add_child(ghost_chk)

	var white_bg_chk := CheckBox.new()
	white_bg_chk.text = "Fondo Claro"
	white_bg_chk.button_pressed = false
	top_hbox.add_child(white_bg_chk)

	var clear_guides_btn := Button.new()
	clear_guides_btn.text = "Limpiar Guías"
	top_hbox.add_child(clear_guides_btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_child(spacer)

	var undo_btn := Button.new()
	undo_btn.text = "Undo"
	top_hbox.add_child(undo_btn)

	var redo_btn := Button.new()
	redo_btn.text = "Redo"
	top_hbox.add_child(redo_btn)

	var save_btn := Button.new()
	save_btn.text = "Guardar (Ctrl+S)"
	top_hbox.add_child(save_btn)

	# --- LEFT DOCK: LAYERS & VISIBILITY ---
	var left_panel := PanelContainer.new()
	left_panel.anchor_left = 0.0
	left_panel.anchor_right = 0.0
	left_panel.anchor_top = 0.0
	left_panel.anchor_bottom = 1.0
	left_panel.offset_top = TOP_BAR_H
	left_panel.offset_right = LEFT_DOCK_W
	root.add_child(left_panel)

	var left_scroll := ScrollContainer.new()
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_panel.add_child(left_scroll)

	var left_margin := MarginContainer.new()
	left_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_margin.add_theme_constant_override("margin_left", 8)
	left_margin.add_theme_constant_override("margin_right", 8)
	left_margin.add_theme_constant_override("margin_top", 8)
	left_margin.add_theme_constant_override("margin_bottom", 8)
	left_scroll.add_child(left_margin)

	var left_vbox := VBoxContainer.new()
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.add_theme_constant_override("separation", 6)
	left_margin.add_child(left_vbox)

	_add_header(left_vbox, "CAPAS & VISIBILIDAD (Orden Z)")

	var quick_vis_row := HBoxContainer.new()
	quick_vis_row.add_theme_constant_override("separation", 4)
	left_vbox.add_child(quick_vis_row)

	var show_all_btn := Button.new()
	show_all_btn.text = "Todo"
	show_all_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quick_vis_row.add_child(show_all_btn)

	var hide_arms_btn := Button.new()
	hide_arms_btn.text = "-Brazos"
	hide_arms_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quick_vis_row.add_child(hide_arms_btn)

	var only_limbs_btn := Button.new()
	only_limbs_btn.text = "Extrem."
	only_limbs_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quick_vis_row.add_child(only_limbs_btn)

	var toggle_head_btn := Button.new()
	toggle_head_btn.text = "±Cabeza"
	toggle_head_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quick_vis_row.add_child(toggle_head_btn)

	var layers_list := VBoxContainer.new()
	layers_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layers_list.add_theme_constant_override("separation", 4)
	left_vbox.add_child(layers_list)

	var ghost_row := HBoxContainer.new()
	left_vbox.add_child(ghost_row)
	var ghost_op_lbl := Label.new()
	ghost_op_lbl.text = "Ghost Opac:"
	ghost_op_lbl.add_theme_font_size_override("font_size", 11)
	ghost_row.add_child(ghost_op_lbl)
	var ghost_op_slider := HSlider.new()
	ghost_op_slider.min_value = 0.05
	ghost_op_slider.max_value = 0.90
	ghost_op_slider.step = 0.05
	ghost_op_slider.value = 0.35
	ghost_op_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ghost_row.add_child(ghost_op_slider)

	_add_header(left_vbox, "ANCLAS & HUESOS (18)")

	var select_neck_btn := Button.new()
	select_neck_btn.text = "Seleccionar neck_anchor"
	left_vbox.add_child(select_neck_btn)

	var bones_list := VBoxContainer.new()
	bones_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bones_list.add_theme_constant_override("separation", 2)
	left_vbox.add_child(bones_list)

	# --- RIGHT DOCK: NUMERIC INSPECTOR & SYMMETRY ---
	var right_panel := Panel.new()
	right_panel.anchor_left = 1.0
	right_panel.anchor_right = 1.0
	right_panel.anchor_top = 0.0
	right_panel.anchor_bottom = 1.0
	right_panel.offset_top = TOP_BAR_H
	right_panel.offset_left = -RIGHT_DOCK_W
	right_panel.offset_right = 0.0
	right_panel.offset_bottom = 0.0
	right_panel.clip_contents = true
	root.add_child(right_panel)

	var right_scroll := ScrollContainer.new()
	right_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_panel.add_child(right_scroll)

	var right_margin := MarginContainer.new()
	right_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_margin.add_theme_constant_override("margin_left", 8)
	right_margin.add_theme_constant_override("margin_right", 8)
	right_margin.add_theme_constant_override("margin_top", 8)
	right_margin.add_theme_constant_override("margin_bottom", 8)
	right_scroll.add_child(right_margin)

	var right_vbox := VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.add_theme_constant_override("separation", 6)
	right_margin.add_child(right_vbox)

	_add_header(right_vbox, "INSPECTOR NUMÉRICO (du)")

	var sel_title_lbl := Label.new()
	sel_title_lbl.text = "Pieza: body_core"
	sel_title_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35, 1.0))
	right_vbox.add_child(sel_title_lbl)

	var rel_grid := GridContainer.new()
	rel_grid.columns = 2
	rel_grid.add_theme_constant_override("h_separation", 6)
	rel_grid.add_theme_constant_override("v_separation", 4)
	right_vbox.add_child(rel_grid)

	var rel_x_lbl := Label.new()
	rel_x_lbl.text = "Rel X (rig):"
	rel_grid.add_child(rel_x_lbl)
	var rel_x_spin := _make_spin(-600.0, 600.0, 0.01)
	rel_grid.add_child(rel_x_spin)

	var rel_y_lbl := Label.new()
	rel_y_lbl.text = "Rel Y (rig):"
	rel_grid.add_child(rel_y_lbl)
	var rel_y_spin := _make_spin(-600.0, 600.0, 0.01)
	rel_grid.add_child(rel_y_spin)

	var abs_x_lbl := Label.new()
	abs_x_lbl.text = "Abs X (520):"
	rel_grid.add_child(abs_x_lbl)
	var abs_x_spin := _make_spin(-200.0, 800.0, 0.01)
	rel_grid.add_child(abs_x_spin)

	var abs_y_lbl := Label.new()
	abs_y_lbl.text = "Abs Y (560):"
	rel_grid.add_child(abs_y_lbl)
	var abs_y_spin := _make_spin(-200.0, 800.0, 0.01)
	rel_grid.add_child(abs_y_spin)

	var delta_lbl := Label.new()
	delta_lbl.text = "Delta vs Guardado: (0.00, 0.00)"
	delta_lbl.add_theme_font_size_override("font_size", 11)
	right_vbox.add_child(delta_lbl)

	var size_lbl := Label.new()
	size_lbl.text = "Tamaño: --"
	size_lbl.add_theme_font_size_override("font_size", 11)
	right_vbox.add_child(size_lbl)

	var z_row := HBoxContainer.new()
	right_vbox.add_child(z_row)
	var z_lbl := Label.new()
	z_lbl.text = "Z-Order:"
	z_row.add_child(z_lbl)
	var z_spin := SpinBox.new()
	z_spin.min_value = -10
	z_spin.max_value = 20
	z_spin.step = 1
	z_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	z_row.add_child(z_spin)

	var head_scale_row := HBoxContainer.new()
	head_scale_row.visible = false
	right_vbox.add_child(head_scale_row)
	var head_scale_lbl := Label.new()
	head_scale_lbl.text = "Escala Combo:"
	head_scale_row.add_child(head_scale_lbl)
	var head_scale_spin := _make_spin(0.50, 1.50, 0.005)
	head_scale_spin.custom_arrow_step = 0.01
	head_scale_row.add_child(head_scale_spin)

	var bone_children_chk := CheckBox.new()
	bone_children_chk.text = "Mover hijos al arrastrar hueso"
	bone_children_chk.button_pressed = false
	bone_children_chk.visible = false
	right_vbox.add_child(bone_children_chk)

	var reset_row := HBoxContainer.new()
	right_vbox.add_child(reset_row)
	var reset_item_btn := Button.new()
	reset_item_btn.text = "Reset Elemento"
	reset_item_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset_row.add_child(reset_item_btn)
	var reset_view_btn := Button.new()
	reset_view_btn.text = "Reset Vista"
	reset_view_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset_row.add_child(reset_view_btn)

	_add_header(right_vbox, "SIMETRÍA")

	var mirror_partner_btn := Button.new()
	mirror_partner_btn.text = "Espejar Vista -> Partner"
	mirror_partner_btn.clip_text = true
	right_vbox.add_child(mirror_partner_btn)

	var sym_row := HBoxContainer.new()
	right_vbox.add_child(sym_row)
	var sym_r_to_l_btn := Button.new()
	sym_r_to_l_btn.text = "Copia R -> L"
	sym_r_to_l_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sym_row.add_child(sym_r_to_l_btn)
	var sym_l_to_r_btn := Button.new()
	sym_l_to_r_btn.text = "Copia L -> R"
	sym_l_to_r_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sym_row.add_child(sym_l_to_r_btn)

	_add_header(right_vbox, "SOMBRA TRAJE (HIP)")

	var sh_top_row := HBoxContainer.new()
	right_vbox.add_child(sh_top_row)
	var hip_sh_chk := CheckBox.new()
	hip_sh_chk.text = "Activa"
	hip_sh_chk.button_pressed = true
	sh_top_row.add_child(hip_sh_chk)

	var hip_sh_col := ColorPickerButton.new()
	hip_sh_col.color = Color(0.82, 0.68, 0.74, 1.0)
	hip_sh_col.edit_alpha = false
	hip_sh_col.custom_minimum_size = Vector2(44.0, 22.0)
	sh_top_row.add_child(hip_sh_col)

	var sh_off_row := HBoxContainer.new()
	right_vbox.add_child(sh_off_row)
	var sh_x_lbl := Label.new()
	sh_x_lbl.text = "X"
	sh_off_row.add_child(sh_x_lbl)
	var hip_sh_x_spin := _make_spin(-12.0, 12.0, 0.1)
	hip_sh_x_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sh_off_row.add_child(hip_sh_x_spin)
	var sh_y_lbl := Label.new()
	sh_y_lbl.text = "Y"
	sh_off_row.add_child(sh_y_lbl)
	var hip_sh_y_spin := _make_spin(-8.0, 16.0, 0.1)
	hip_sh_y_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sh_off_row.add_child(hip_sh_y_spin)

	var select_hip_sh_btn := Button.new()
	select_hip_sh_btn.text = "Mover Sombra (Drag)"
	select_hip_sh_btn.clip_text = true
	right_vbox.add_child(select_hip_sh_btn)

	_add_header(right_vbox, "PINCH MEDIA (LIGA)")

	var sp_chk := CheckBox.new()
	sp_chk.text = "Pinch Activo"
	sp_chk.button_pressed = true
	right_vbox.add_child(sp_chk)

	var sp_vis_chk := CheckBox.new()
	sp_vis_chk.text = "Ver Zona Pinch (Color)"
	sp_vis_chk.button_pressed = false
	right_vbox.add_child(sp_vis_chk)

	var sp_grid := GridContainer.new()
	sp_grid.columns = 2
	sp_grid.add_theme_constant_override("h_separation", 6)
	sp_grid.add_theme_constant_override("v_separation", 4)
	right_vbox.add_child(sp_grid)

	var sp_vr_lbl := Label.new()
	sp_vr_lbl.text = "V R"
	sp_grid.add_child(sp_vr_lbl)
	var sp_vr_spin := _make_spin(0.02, 0.75, 0.001)
	sp_grid.add_child(sp_vr_spin)

	var sp_vl_lbl := Label.new()
	sp_vl_lbl.text = "V L"
	sp_grid.add_child(sp_vl_lbl)
	var sp_vl_spin := _make_spin(0.02, 0.75, 0.001)
	sp_grid.add_child(sp_vl_spin)

	var sp_tr_lbl := Label.new()
	sp_tr_lbl.text = "Tilt R"
	sp_grid.add_child(sp_tr_lbl)
	var sp_tr_spin := _make_spin(-0.45, 0.45, 0.001)
	sp_grid.add_child(sp_tr_spin)

	var sp_tl_lbl := Label.new()
	sp_tl_lbl.text = "Tilt L"
	sp_grid.add_child(sp_tl_lbl)
	var sp_tl_spin := _make_spin(-0.45, 0.45, 0.001)
	sp_grid.add_child(sp_tl_spin)

	var sp_s_lbl := Label.new()
	sp_s_lbl.text = "Fuerza"
	sp_grid.add_child(sp_s_lbl)
	var sp_s_spin := _make_spin(0.0, 0.45, 0.001)
	sp_grid.add_child(sp_s_spin)

	var sp_w_lbl := Label.new()
	sp_w_lbl.text = "Ancho"
	sp_grid.add_child(sp_w_lbl)
	var sp_w_spin := _make_spin(0.005, 0.18, 0.001)
	sp_grid.add_child(sp_w_spin)

	var sp_sh_lbl := Label.new()
	sp_sh_lbl.text = "Sombra"
	sp_grid.add_child(sp_sh_lbl)
	var sp_sh_spin := _make_spin(0.0, 1.0, 0.005)
	sp_grid.add_child(sp_sh_spin)

	_add_header(right_vbox, "RENDER & ZOOM")

	var xray_opt := OptionButton.new()
	xray_opt.fit_to_longest_item = false
	xray_opt.clip_text = true
	xray_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for xl: String in [
		"X-Ray 0: Render Final",
		"X-Ray 1: Clown-Pass ID",
		"X-Ray 2: Luminancia",
		"X-Ray 3: Solo Tinta",
		"X-Ray 4: Normales 2.5D",
		"X-Ray 5: Profundidad 2.5D",
	]:
		xray_opt.add_item(xl)
	right_vbox.add_child(xray_opt)

	var skin_opt := OptionButton.new()
	skin_opt.fit_to_longest_item = false
	skin_opt.clip_text = true
	skin_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.add_child(skin_opt)

	var zoom_row := HBoxContainer.new()
	right_vbox.add_child(zoom_row)
	var zoom_lbl := Label.new()
	zoom_lbl.text = "Zoom: 3.0x"
	zoom_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	zoom_row.add_child(zoom_lbl)
	var zoom_2_btn := Button.new()
	zoom_2_btn.text = "2x"
	zoom_row.add_child(zoom_2_btn)
	var zoom_5_btn := Button.new()
	zoom_5_btn.text = "5x"
	zoom_row.add_child(zoom_5_btn)
	var zoom_10_btn := Button.new()
	zoom_10_btn.text = "10x"
	zoom_row.add_child(zoom_10_btn)
	var center_cam_btn := Button.new()
	center_cam_btn.text = "Centrar"
	zoom_row.add_child(center_cam_btn)

	_add_header(right_vbox, "CURSOR & ATAJOS")

	var cursor_lbl := Label.new()
	cursor_lbl.text = "Cursor: X=0.0, Y=0.0 du"
	cursor_lbl.add_theme_font_size_override("font_size", 11)
	right_vbox.add_child(cursor_lbl)

	var help_lbl := Label.new()
	help_lbl.text = "Flechas: mover por paso | Shift: x10 | Ctrl: 0.25\nArrastrar desde reglas: crear guía\nRueda: zoom | MMB/Espacio+Drag: pan\nCtrl+Z / Ctrl+Y: Undo/Redo | Ctrl+S: Guardar"
	help_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help_lbl.add_theme_font_size_override("font_size", 10)
	help_lbl.add_theme_color_override("font_color", Color(0.70, 0.76, 0.86, 0.90))
	right_vbox.add_child(help_lbl)

	var toast_lbl := Label.new()
	toast_lbl.text = ""
	toast_lbl.add_theme_font_size_override("font_size", 11)
	toast_lbl.add_theme_color_override("font_color", Color(0.45, 0.96, 0.65, 1.0))
	toast_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right_vbox.add_child(toast_lbl)

	# Wire simple callbacks
	_connect_opt(view_opt, callbacks.get("on_view_changed", Callable()))
	_connect_stepper(prev_view_btn, view_opt, -1)
	_connect_stepper(next_view_btn, view_opt, 1)
	_connect_opt(head_opt, callbacks.get("on_head_changed", Callable()))
	_connect_chk(auto_head_chk, callbacks.get("on_auto_head_toggled", Callable()))
	_connect_btn(next_combo_btn, callbacks.get("on_next_combo", Callable()))
	_connect_chk(snap_grid_chk, callbacks.get("on_snap_grid_toggled", Callable()))
	_connect_chk(snap_guide_chk, callbacks.get("on_snap_guide_toggled", Callable()))
	_connect_chk(rulers_chk, callbacks.get("on_rulers_toggled", Callable()))
	_connect_chk(grid_chk, callbacks.get("on_grid_toggled", Callable()))
	_connect_chk(bbox_chk, callbacks.get("on_bbox_toggled", Callable()))
	_connect_chk(bones_chk, callbacks.get("on_bones_toggled", Callable()))
	_connect_chk(ghost_chk, callbacks.get("on_ghost_toggled", Callable()))
	_connect_chk(white_bg_chk, callbacks.get("on_white_bg_toggled", Callable()))
	_connect_btn(clear_guides_btn, callbacks.get("on_clear_guides", Callable()))
	_connect_btn(undo_btn, callbacks.get("on_undo", Callable()))
	_connect_btn(redo_btn, callbacks.get("on_redo", Callable()))
	_connect_btn(save_btn, callbacks.get("on_save", Callable()))

	_connect_btn(show_all_btn, callbacks.get("on_vis_preset", Callable()), ["all"])
	_connect_btn(hide_arms_btn, callbacks.get("on_vis_preset", Callable()), ["no_arms"])
	_connect_btn(only_limbs_btn, callbacks.get("on_vis_preset", Callable()), ["limbs"])
	_connect_btn(toggle_head_btn, callbacks.get("on_vis_preset", Callable()), ["toggle_head"])
	_connect_btn(select_neck_btn, callbacks.get("on_select_neck", Callable()))

	_connect_btn(reset_item_btn, callbacks.get("on_reset_item", Callable()))
	_connect_btn(reset_view_btn, callbacks.get("on_reset_view", Callable()))
	_connect_btn(mirror_partner_btn, callbacks.get("on_mirror_partner", Callable()))
	_connect_btn(sym_r_to_l_btn, callbacks.get("on_sym_lr", Callable()), ["r"])
	_connect_btn(sym_l_to_r_btn, callbacks.get("on_sym_lr", Callable()), ["l"])

	_connect_opt(xray_opt, callbacks.get("on_xray_changed", Callable()))
	_connect_opt(skin_opt, callbacks.get("on_skin_changed", Callable()))
	_connect_btn(zoom_2_btn, callbacks.get("on_zoom_preset", Callable()), [2.0])
	_connect_btn(zoom_5_btn, callbacks.get("on_zoom_preset", Callable()), [5.0])
	_connect_btn(zoom_10_btn, callbacks.get("on_zoom_preset", Callable()), [10.0])
	_connect_btn(center_cam_btn, callbacks.get("on_center_cam", Callable()))

	return {
		"root": root,
		"view_opt": view_opt,
		"head_opt": head_opt,
		"auto_head_chk": auto_head_chk,
		"next_combo_btn": next_combo_btn,
		"step_btns": step_btns,
		"undo_btn": undo_btn,
		"redo_btn": redo_btn,
		"save_btn": save_btn,
		"layers_list": layers_list,
		"bones_list": bones_list,
		"ghost_op_slider": ghost_op_slider,
		"sel_title_lbl": sel_title_lbl,
		"rel_x_spin": rel_x_spin,
		"rel_y_spin": rel_y_spin,
		"abs_x_spin": abs_x_spin,
		"abs_y_spin": abs_y_spin,
		"delta_lbl": delta_lbl,
		"size_lbl": size_lbl,
		"z_row": z_row,
		"z_spin": z_spin,
		"head_scale_row": head_scale_row,
		"head_scale_spin": head_scale_spin,
		"bone_children_chk": bone_children_chk,
		"mirror_partner_btn": mirror_partner_btn,
		"sym_r_to_l_btn": sym_r_to_l_btn,
		"sym_l_to_r_btn": sym_l_to_r_btn,
		"hip_sh_chk": hip_sh_chk,
		"hip_sh_col": hip_sh_col,
		"hip_sh_x_spin": hip_sh_x_spin,
		"hip_sh_y_spin": hip_sh_y_spin,
		"select_hip_sh_btn": select_hip_sh_btn,
		"sp_chk": sp_chk,
		"sp_vis_chk": sp_vis_chk,
		"sp_vr_spin": sp_vr_spin,
		"sp_vl_spin": sp_vl_spin,
		"sp_tr_spin": sp_tr_spin,
		"sp_tl_spin": sp_tl_spin,
		"sp_s_spin": sp_s_spin,
		"sp_w_spin": sp_w_spin,
		"sp_sh_spin": sp_sh_spin,
		"skin_opt": skin_opt,
		"zoom_lbl": zoom_lbl,
		"cursor_lbl": cursor_lbl,
		"toast_lbl": toast_lbl,
	}


static func _make_spin(min_v: float, max_v: float, step_v: float) -> SpinBox:
	var sp := SpinBox.new()
	sp.min_value = min_v
	sp.max_value = max_v
	sp.step = step_v
	sp.custom_arrow_step = step_v
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return sp


static func _add_header(parent: VBoxContainer, txt: String) -> void:
	var sep := HSeparator.new()
	parent.add_child(sep)
	var lbl := Label.new()
	lbl.text = txt
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.62, 0.86, 1.0, 1.0))
	parent.add_child(lbl)


static func _connect_opt(opt: OptionButton, cb: Callable) -> void:
	if cb.is_valid():
		opt.item_selected.connect(func(idx: int) -> void: cb.call(idx))


static func _connect_chk(chk: CheckBox, cb: Callable) -> void:
	if cb.is_valid():
		chk.toggled.connect(func(v: bool) -> void: cb.call(v))


static func _connect_btn(btn: Button, cb: Callable, args: Array = []) -> void:
	if cb.is_valid():
		btn.pressed.connect(func() -> void:
			if args.is_empty():
				cb.call()
			else:
				cb.callv(args)
		)


static func _connect_stepper(btn: Button, opt: OptionButton, delta: int) -> void:
	btn.pressed.connect(func() -> void:
		if opt.item_count <= 0:
			return
		var nxt: int = posmod(opt.selected + delta, opt.item_count)
		opt.select(nxt)
		opt.item_selected.emit(nxt)
	)

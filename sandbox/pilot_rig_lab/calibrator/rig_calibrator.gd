extends Node2D
## Herramienta independiente de calibración manual para Valentina Rig v2.
## Permite ajustar piezas, cabeza, neck_anchor, huesos y orden Z con reglas graduadas,
## guías arrastrables, snap, opacidad/aislamiento por capa, simetría y guardado en JSON.

const PlanarRigScript = preload("res://scenes/pilots/rig/planar_combat_rig.gd")
const StoreScript = preload("res://sandbox/pilot_rig_lab/calibrator/rig_calibration_store.gd")
const OverlayScript = preload("res://sandbox/pilot_rig_lab/calibrator/rig_calibrator_overlay.gd")
const HudScript = preload("res://sandbox/pilot_rig_lab/calibrator/rig_calibrator_hud.gd")
const LayerBuilderScript = preload("res://sandbox/pilot_rig_lab/calibrator/rig_calibrator_layer_builder.gd")
const ViewRouterScript = preload("res://scenes/pilots/rig/planar_rig_view_router.gd")
const ProfilePath: String = "res://data/pilots/valentina_v2/valentina_v2_profile.tres"

var _store: RigCalibrationStore = null
var _rig: PlanarCombatRig = null
var _ghost_root: Node2D = null
var _camera: Camera2D = null
var _bg_rect: ColorRect = null
var _hud_layer: CanvasLayer = null
var _overlay: RigCalibratorOverlay = null
var _hud_refs: Dictionary = {}

var _active_view: String = "s"
var _active_head: String = "head_front"
var _active_allowed_heads: Array[String] = []
var _auto_head: bool = true
var _step_du: float = 1.0
var _snap_grid: bool = false
var _snap_guides: bool = true
var _show_ghost: bool = false
var _ghost_opacity: float = 0.35
var _show_pinch_overlay: bool = false
var _move_bone_children: bool = false

var _selected_kind: String = "part"
var _selected_name: String = "body_core"
var _part_vis: Dictionary = {}
var _part_opac: Dictionary = {}
var _head_vis: bool = true
var _head_opac: float = 1.0
var _head_under_vis: bool = true
var _head_under_opac: float = 1.0
var _solo_target: String = ""
var _pre_solo_snapshot: Dictionary = {}

var _built_part_origins: Dictionary = {}
var _tex_image_cache: Dictionary = {}
var _active_profile: PilotRigProfile = null

var _panning: bool = false
var _dragging_item: bool = false
var _drag_undo_pushed: bool = false
var _drag_start_mouse_du: Vector2 = Vector2.ZERO
var _drag_start_item_pos: Vector2 = Vector2.ZERO
var _syncing_ui: bool = false
var _toast_timer: float = 0.0


func _ready() -> void:
	_store = StoreScript.new()
	_store.load_from_root(StoreScript.DEFAULT_ASSETS_ROOT)

	_build_backdrop()
	_camera = Camera2D.new()
	_camera.position = Vector2(0.0, -14.0)
	_camera.zoom = Vector2(3.5, 3.5)
	add_child(_camera)

	_ghost_root = Node2D.new()
	_ghost_root.name = "GhostBaselineLayer"
	_ghost_root.z_index = -5
	_ghost_root.visible = false
	add_child(_ghost_root)

	_rig = PlanarRigScript.new()
	_rig.name = "CalibratorPlanarRig"
	_rig.calibration_manual_pose = true
	if ResourceLoader.exists(ProfilePath):
		_active_profile = ResourceLoader.load(ProfilePath) as PilotRigProfile
		_rig.pilot_profile = _active_profile
	add_child(_rig)
	_rig.enable_afterimage = false

	_record_built_part_origins()
	_init_visibility_defaults()

	_hud_layer = CanvasLayer.new()
	_hud_layer.name = "CalibratorHudLayer"
	add_child(_hud_layer)

	_overlay = OverlayScript.new()
	_overlay.name = "CalibratorOverlay"
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud_layer.add_child(_overlay)

	_hud_refs = HudScript.build_ui(_hud_layer, {
		"on_view_changed": Callable(self, "_on_view_selected"),
		"on_head_changed": Callable(self, "_on_head_selected"),
		"on_auto_head_toggled": func(v: bool) -> void:
			_auto_head = v
			if v:
				_apply_auto_head_for_view(),
		"on_next_combo": Callable(self, "_cycle_valid_combo"),
		"on_step_selected": Callable(self, "_on_step_selected"),
		"on_snap_grid_toggled": func(v: bool) -> void: _snap_grid = v,
		"on_snap_guide_toggled": func(v: bool) -> void: _snap_guides = v,
		"on_rulers_toggled": func(v: bool) -> void:
			_overlay.show_rulers = v
			_overlay.queue_redraw(),
		"on_grid_toggled": func(v: bool) -> void:
			_overlay.show_grid = v
			_overlay.queue_redraw(),
		"on_bbox_toggled": func(v: bool) -> void:
			_overlay.show_bboxes = v
			_overlay.queue_redraw(),
		"on_bones_toggled": func(v: bool) -> void:
			_overlay.show_bones = v
			_overlay.queue_redraw(),
		"on_ghost_toggled": func(v: bool) -> void:
			_show_ghost = v
			_rebuild_ghost(),
		"on_white_bg_toggled": Callable(self, "_set_white_bg"),
		"on_clear_guides": func() -> void:
			_overlay.clear_guides()
			_show_toast("Guías eliminadas"),
		"on_undo": Callable(self, "_perform_undo"),
		"on_redo": Callable(self, "_perform_redo"),
		"on_save": Callable(self, "_perform_save"),
		"on_vis_preset": Callable(self, "_apply_visibility_preset"),
		"on_select_neck": func() -> void: _select_target("neck_anchor", "neck_anchor"),
		"on_reset_item": Callable(self, "_reset_selected_item"),
		"on_reset_view": Callable(self, "_reset_active_view"),
		"on_mirror_partner": Callable(self, "_mirror_to_partner"),
		"on_sym_lr": Callable(self, "_symmetrize_lr"),
		"on_xray_changed": func(idx: int) -> void:
			if _rig != null:
				_rig.set_debug_view_mode(idx),
		"on_skin_changed": Callable(self, "_on_skin_selected"),
		"on_zoom_preset": Callable(self, "_set_zoom_level"),
		"on_center_cam": func() -> void:
			_camera.position = Vector2(0.0, -14.0)
			_update_zoom_label(),
	})

	_wire_inspector_signals()
	_populate_skins()
	_apply_initial_style_and_view()


func _build_backdrop() -> void:
	_bg_rect = ColorRect.new()
	_bg_rect.color = Color(0.065, 0.072, 0.105, 1.0)
	_bg_rect.size = Vector2(6000.0, 6000.0)
	_bg_rect.position = Vector2(-3000.0, -3000.0)
	_bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg_rect.z_index = -50
	add_child(_bg_rect)


func _record_built_part_origins() -> void:
	_built_part_origins.clear()
	var views: Dictionary = _rig.get_views()
	for v_key: String in views.keys():
		var vd: Dictionary = views[v_key] as Dictionary
		var part_rects: Dictionary = vd.get("part_rects", {}) as Dictionary
		var map: Dictionary = {}
		for p_name: String in part_rects.keys():
			map[p_name] = (part_rects[p_name] as Rect2).position
		_built_part_origins[v_key] = map


func _init_visibility_defaults() -> void:
	for pk: String in StoreScript.PART_KEYS:
		_part_vis[pk] = true
		_part_opac[pk] = 1.0
	_head_vis = true
	_head_opac = 1.0
	_head_under_vis = true
	_head_under_opac = 1.0


func _wire_inspector_signals() -> void:
	var rel_x: SpinBox = _hud_refs["rel_x_spin"] as SpinBox
	var rel_y: SpinBox = _hud_refs["rel_y_spin"] as SpinBox
	var abs_x: SpinBox = _hud_refs["abs_x_spin"] as SpinBox
	var abs_y: SpinBox = _hud_refs["abs_y_spin"] as SpinBox
	var z_spin: SpinBox = _hud_refs["z_spin"] as SpinBox
	var head_scale_spin: SpinBox = _hud_refs["head_scale_spin"] as SpinBox
	var bone_chk: CheckBox = _hud_refs["bone_children_chk"] as CheckBox
	var ghost_slider: HSlider = _hud_refs["ghost_op_slider"] as HSlider

	rel_x.value_changed.connect(func(v: float) -> void:
		if _syncing_ui:
			return
		_apply_selected_pos_from_inspector(Vector2(v, rel_y.value), false)
	)
	rel_y.value_changed.connect(func(v: float) -> void:
		if _syncing_ui:
			return
		_apply_selected_pos_from_inspector(Vector2(rel_x.value, v), false)
	)
	abs_x.value_changed.connect(func(v: float) -> void:
		if _syncing_ui:
			return
		_apply_selected_pos_from_inspector(Vector2(v, abs_y.value), true)
	)
	abs_y.value_changed.connect(func(v: float) -> void:
		if _syncing_ui:
			return
		_apply_selected_pos_from_inspector(Vector2(abs_x.value, v), true)
	)
	z_spin.value_changed.connect(func(v: float) -> void:
		if _syncing_ui or _selected_kind != "part":
			return
		_store.push_undo_snapshot()
		_store.set_part_z_order(_active_view, _selected_name, int(v))
		_refresh_all()
	)
	head_scale_spin.value_changed.connect(func(v: float) -> void:
		if _syncing_ui or _selected_kind != "head":
			return
		_store.push_undo_snapshot()
		_store.set_head_combo_scale(_active_view, _active_head, v)
		_refresh_live_and_inspector()
	)
	bone_chk.toggled.connect(func(v: bool) -> void: _move_bone_children = v)
	ghost_slider.value_changed.connect(func(v: float) -> void:
		_ghost_opacity = v
		_rebuild_ghost()
	)
	var po_chk: CheckBox = _hud_refs["po_chk"] as CheckBox
	var po_col: ColorPickerButton = _hud_refs["po_col"] as ColorPickerButton
	var po_seams_chk: CheckBox = _hud_refs["po_seams_chk"] as CheckBox
	var po_erode_slider: HSlider = _hud_refs["po_erode_slider"] as HSlider
	var po_erode_spin: SpinBox = _hud_refs["po_erode_spin"] as SpinBox
	var po_out_slider: HSlider = _hud_refs["po_out_slider"] as HSlider
	var po_out_spin: SpinBox = _hud_refs["po_out_spin"] as SpinBox
	var po_copy_view_btn: Button = _hud_refs["po_copy_view_btn"] as Button
	var po_copy_all_btn: Button = _hud_refs["po_copy_all_btn"] as Button
	var apply_po: Callable = func(erode_v: float, out_v: float, auto_enable: bool, record_undo: bool) -> void:
		if _syncing_ui:
			return
		var en: bool = po_chk.button_pressed
		if auto_enable and not en and (erode_v > 0.001 or out_v > 0.001):
			en = true
		if _selected_kind == "part":
			_store.set_part_outline(_active_view, _selected_name, en, erode_v, out_v, po_col.color, po_seams_chk.button_pressed, record_undo)
		elif _selected_kind == "head":
			_store.set_head_outline(_active_head, en, erode_v, out_v, po_col.color, po_seams_chk.button_pressed, record_undo)
		else:
			return
		_refresh_live_and_inspector()
	po_chk.toggled.connect(func(_v: bool) -> void: apply_po.call(po_erode_spin.value, po_out_spin.value, false, true))
	po_col.color_changed.connect(func(_c: Color) -> void: apply_po.call(po_erode_spin.value, po_out_spin.value, false, true))
	po_seams_chk.toggled.connect(func(_v: bool) -> void: apply_po.call(po_erode_spin.value, po_out_spin.value, false, true))
	po_erode_slider.drag_started.connect(func() -> void: _store.push_undo_snapshot())
	po_erode_slider.value_changed.connect(func(v: float) -> void: apply_po.call(v, po_out_spin.value, true, false))
	po_erode_spin.value_changed.connect(func(v: float) -> void: apply_po.call(v, po_out_spin.value, true, true))
	po_out_slider.drag_started.connect(func() -> void: _store.push_undo_snapshot())
	po_out_slider.value_changed.connect(func(v: float) -> void: apply_po.call(po_erode_spin.value, v, true, false))
	po_out_spin.value_changed.connect(func(v: float) -> void: apply_po.call(po_erode_spin.value, v, true, true))
	po_copy_view_btn.pressed.connect(func() -> void:
		if _selected_kind != "part":
			return
		_store.copy_part_outline_to_view(_active_view, _selected_name)
		_refresh_live_and_inspector()
		_show_toast("Outline de %s copiado a toda la vista %s" % [_selected_name, _active_view.to_upper()])
	)
	po_copy_all_btn.pressed.connect(func() -> void:
		if _selected_kind == "part":
			_store.copy_part_outline_to_all_views(_active_view, _selected_name)
			_refresh_live_and_inspector()
			_show_toast("Outline de %s copiado a las 8 vistas" % _selected_name)
		elif _selected_kind == "head":
			_store.copy_head_outline_to_all_heads(_active_head)
			_refresh_live_and_inspector()
			_show_toast("Outline de %s copiado a las 8 cabezas" % _active_head)
	)
	var hip_sh_chk: CheckBox = _hud_refs["hip_sh_chk"] as CheckBox
	var hip_sh_col: ColorPickerButton = _hud_refs["hip_sh_col"] as ColorPickerButton
	var hip_sh_x: SpinBox = _hud_refs["hip_sh_x_spin"] as SpinBox
	var hip_sh_y: SpinBox = _hud_refs["hip_sh_y_spin"] as SpinBox
	var apply_hip_sh: Callable = func() -> void:
		if _syncing_ui:
			return
		_store.set_hip_cast_shadow(_active_view, hip_sh_chk.button_pressed, Vector2(hip_sh_x.value, hip_sh_y.value), hip_sh_col.color, true)
		_refresh_live_and_inspector()
	hip_sh_chk.toggled.connect(func(_v: bool) -> void: apply_hip_sh.call())
	hip_sh_col.color_changed.connect(func(_c: Color) -> void: apply_hip_sh.call())
	hip_sh_x.value_changed.connect(func(_v: float) -> void: apply_hip_sh.call())
	hip_sh_y.value_changed.connect(func(_v: float) -> void: apply_hip_sh.call())
	(_hud_refs["select_hip_sh_btn"] as Button).pressed.connect(func() -> void:
		_select_target("hip_shadow", "hip_shadow")
	)
	var sp_chk: CheckBox = _hud_refs["sp_chk"] as CheckBox
	var sp_vis_chk: CheckBox = _hud_refs["sp_vis_chk"] as CheckBox
	var sp_vr: SpinBox = _hud_refs["sp_vr_spin"] as SpinBox
	var sp_vl: SpinBox = _hud_refs["sp_vl_spin"] as SpinBox
	var sp_tr: SpinBox = _hud_refs["sp_tr_spin"] as SpinBox
	var sp_tl: SpinBox = _hud_refs["sp_tl_spin"] as SpinBox
	var sp_s: SpinBox = _hud_refs["sp_s_spin"] as SpinBox
	var sp_w: SpinBox = _hud_refs["sp_w_spin"] as SpinBox
	var sp_sh: SpinBox = _hud_refs["sp_sh_spin"] as SpinBox
	var apply_sp: Callable = func() -> void:
		if _syncing_ui:
			return
		_store.set_stocking_pinch(_active_view, sp_chk.button_pressed, sp_vr.value, sp_vl.value, sp_tr.value, sp_tl.value, sp_s.value, sp_w.value, sp_sh.value, true)
		_refresh_live_and_inspector()
	sp_chk.toggled.connect(func(_v: bool) -> void: apply_sp.call())
	sp_vis_chk.toggled.connect(func(v: bool) -> void:
		_show_pinch_overlay = v
		_refresh_live_and_inspector()
	)
	sp_vr.value_changed.connect(func(_v: float) -> void: apply_sp.call())
	sp_vl.value_changed.connect(func(_v: float) -> void: apply_sp.call())
	sp_tr.value_changed.connect(func(_v: float) -> void: apply_sp.call())
	sp_tl.value_changed.connect(func(_v: float) -> void: apply_sp.call())
	sp_s.value_changed.connect(func(_v: float) -> void: apply_sp.call())
	sp_w.value_changed.connect(func(_v: float) -> void: apply_sp.call())
	sp_sh.value_changed.connect(func(_v: float) -> void: apply_sp.call())


func _populate_skins() -> void:
	var skin_opt: OptionButton = _hud_refs["skin_opt"] as OptionButton
	skin_opt.clear()
	if _active_profile == null:
		return
	for sk: PilotSkinPreset in _active_profile.skins:
		if sk != null:
			skin_opt.add_item(sk.label)


func _apply_initial_style_and_view() -> void:
	if _active_profile != null:
		if not _active_profile.style_profiles.is_empty():
			_rig.apply_style_profile(_active_profile.style_profiles[0])
		if not _active_profile.skins.is_empty():
			_rig.apply_skin_preset(_active_profile.skins[0])
	_rig.set_outer_outline_params(true, 1.45, 1.0)
	_switch_view_and_head("s", "head_front")
	_update_zoom_label()


func _process(delta: float) -> void:
	if _toast_timer > 0.0:
		_toast_timer -= delta
		if _toast_timer <= 0.0:
			(_hud_refs["toast_lbl"] as Label).text = ""

	if _rig != null:
		_rig.set_zoom_scale(_camera.zoom.x)
	_sync_overlay_state()


func _sync_overlay_state() -> void:
	var vp_size: Vector2 = get_viewport_rect().size
	var work_r := Rect2(
		HudScript.LEFT_DOCK_W,
		HudScript.TOP_BAR_H,
		maxf(64.0, vp_size.x - HudScript.LEFT_DOCK_W - HudScript.RIGHT_DOCK_W),
		maxf(64.0, vp_size.y - HudScript.TOP_BAR_H)
	)
	_overlay.selected_kind = _selected_kind
	_overlay.selected_name = _selected_name
	_overlay.part_visibility = _part_vis
	_overlay.active_head_visible = _head_vis or _head_under_vis
	_overlay.active_neck_rel = _store.get_neck_anchor_rel(_active_view, false)

	var p_rects: Dictionary = {}
	for pk: String in StoreScript.PART_KEYS:
		var r: Rect2 = _store.get_part_rect_rel(_active_view, pk, false)
		if r.size != Vector2.ZERO:
			p_rects[pk] = r
	_overlay.active_part_rects = p_rects

	var h_scale: float = _store.get_head_combo_scale(_active_view, _active_head, false)
	var h_sz: Vector2 = _store.get_head_disp_size(_active_head) * h_scale
	var h_off: Vector2 = _store.get_head_combo_offset(_active_view, _active_head, false)
	_overlay.active_head_rect = Rect2(_overlay.active_neck_rel + h_off - h_sz * 0.5, h_sz)
	_overlay.active_head_label = "%s (%.2f, %.2f) x%.2f" % [_active_head, h_off.x, h_off.y, h_scale]

	var b_rel: Dictionary = {}
	var b_par: Dictionary = {}
	for b_name: String in _store.get_bone_names(_active_view):
		b_rel[b_name] = _store.get_bone_pos_rel(_active_view, b_name, false)
		b_par[b_name] = _store.get_bone_parent(_active_view, b_name)
	_overlay.active_bones_rel = b_rel
	_overlay.active_bone_parents = b_par

	_overlay.update_view_state(
		work_r,
		get_viewport().get_canvas_transform(),
		_rig.global_position,
		_rig.scale,
		_store.get_rig_origin(_active_view)
	)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var ke: InputEventKey = event as InputEventKey
		if ke.pressed:
			_handle_key_input(ke)
		return

	if event is InputEventMouseButton:
		_handle_mouse_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event as InputEventMouseMotion)


func _handle_key_input(ke: InputEventKey) -> void:
	var focus_owner: Control = get_viewport().gui_get_focus_owner()
	if ke.keycode == KEY_ESCAPE or ke.keycode == KEY_ENTER or ke.keycode == KEY_KP_ENTER:
		if focus_owner != null:
			focus_owner.release_focus()
			return

	if ke.ctrl_pressed:
		if ke.keycode == KEY_S and not ke.echo:
			_perform_save()
			get_viewport().set_input_as_handled()
			return
		elif ke.keycode == KEY_Z and not ke.echo:
			if ke.shift_pressed:
				_perform_redo()
			else:
				_perform_undo()
			get_viewport().set_input_as_handled()
			return
		elif ke.keycode == KEY_Y and not ke.echo:
			_perform_redo()
			get_viewport().set_input_as_handled()
			return

	if focus_owner is LineEdit or focus_owner is SpinBox:
		return

	var arrow_dir := Vector2.ZERO
	if ke.keycode == KEY_LEFT:
		arrow_dir.x = -1.0
	elif ke.keycode == KEY_RIGHT:
		arrow_dir.x = 1.0
	elif ke.keycode == KEY_UP:
		arrow_dir.y = -1.0
	elif ke.keycode == KEY_DOWN:
		arrow_dir.y = 1.0

	if arrow_dir != Vector2.ZERO:
		var mult: float = _step_du
		if ke.shift_pressed:
			mult = _step_du * 10.0
		elif ke.ctrl_pressed:
			mult = 0.25
		if not ke.echo:
			_store.push_undo_snapshot()
		_nudge_selected_by(arrow_dir * mult)
		get_viewport().set_input_as_handled()


func _handle_mouse_button(mb: InputEventMouseButton) -> void:
	var m_pos: Vector2 = mb.position
	var in_work: bool = _overlay.work_rect.has_point(m_pos)

	if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed and in_work:
		_zoom_at_screen_pos(1.18, m_pos)
		return
	elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed and in_work:
		_zoom_at_screen_pos(1.0 / 1.18, m_pos)
		return

	if mb.button_index == MOUSE_BUTTON_MIDDLE or mb.button_index == MOUSE_BUTTON_RIGHT or (mb.button_index == MOUSE_BUTTON_LEFT and Input.is_key_pressed(KEY_SPACE)):
		_panning = mb.pressed and in_work
		return

	if mb.button_index != MOUSE_BUTTON_LEFT:
		return

	if mb.pressed:
		if not in_work:
			return
		var focus_owner: Control = get_viewport().gui_get_focus_owner()
		if focus_owner != null:
			focus_owner.release_focus()

		if _overlay.is_in_top_ruler(m_pos):
			var y_du: float = _overlay.screen_to_rig(m_pos).y
			_overlay.h_guides_du.append(y_du)
			_overlay.dragging_guide_axis = "h"
			_overlay.dragging_guide_idx = _overlay.h_guides_du.size() - 1
			return
		if _overlay.is_in_left_ruler(m_pos):
			var x_du: float = _overlay.screen_to_rig(m_pos).x
			_overlay.v_guides_du.append(x_du)
			_overlay.dragging_guide_axis = "v"
			_overlay.dragging_guide_idx = _overlay.v_guides_du.size() - 1
			return

		var g_hit: Dictionary = _overlay.hit_test_guide(m_pos)
		if not g_hit.is_empty():
			_overlay.dragging_guide_axis = str(g_hit["axis"])
			_overlay.dragging_guide_idx = int(g_hit["index"])
			return

		var canvas_r: Rect2 = _overlay.get_canvas_rect_screen()
		if canvas_r.has_point(m_pos):
			if not _try_pick_and_start_drag(m_pos):
				_panning = true
		else:
			_panning = true
	else:
		if not _overlay.dragging_guide_axis.is_empty():
			_finish_guide_drag(m_pos)
		_panning = false
		_dragging_item = false
		_drag_undo_pushed = false
		_overlay.snapped_x_du = null
		_overlay.snapped_y_du = null


func _handle_mouse_motion(mm: InputEventMouseMotion) -> void:
	var m_pos: Vector2 = mm.position
	_overlay.cursor_inside_work = _overlay.get_canvas_rect_screen().has_point(m_pos)
	_overlay.cursor_rig_du = _overlay.screen_to_rig(m_pos)
	(_hud_refs["cursor_lbl"] as Label).text = "Cursor: X=%.2f, Y=%.2f du" % [_overlay.cursor_rig_du.x, _overlay.cursor_rig_du.y]

	if _panning:
		_camera.position -= mm.relative / _camera.zoom
		return

	if not _overlay.dragging_guide_axis.is_empty():
		var m_du: Vector2 = _overlay.screen_to_rig(m_pos)
		if _overlay.dragging_guide_axis == "h":
			_overlay.h_guides_du[_overlay.dragging_guide_idx] = snappedf(m_du.y, 0.25)
		else:
			_overlay.v_guides_du[_overlay.dragging_guide_idx] = snappedf(m_du.x, 0.25)
		_overlay.queue_redraw()
		return

	if _dragging_item:
		if not _drag_undo_pushed:
			_store.push_undo_snapshot()
			_drag_undo_pushed = true
		var cur_du: Vector2 = _overlay.screen_to_rig(m_pos)
		var delta_du: Vector2 = cur_du - _drag_start_mouse_du
		if Input.is_key_pressed(KEY_SHIFT):
			if absf(delta_du.x) >= absf(delta_du.y):
				delta_du.y = 0.0
			else:
				delta_du.x = 0.0
		var target_pos: Vector2 = _apply_snapping(_drag_start_item_pos + delta_du)
		_set_selected_pos_rel(target_pos)
		return

	var g_hit: Dictionary = _overlay.hit_test_guide(m_pos)
	_overlay.hovered_guide_axis = str(g_hit.get("axis", ""))
	_overlay.hovered_guide_idx = int(g_hit.get("index", -1))
	_overlay.queue_redraw()


func _finish_guide_drag(m_pos: Vector2) -> void:
	var canvas_r: Rect2 = _overlay.get_canvas_rect_screen()
	if not canvas_r.has_point(m_pos):
		if _overlay.dragging_guide_axis == "h":
			_overlay.h_guides_du.remove_at(_overlay.dragging_guide_idx)
		else:
			_overlay.v_guides_du.remove_at(_overlay.dragging_guide_idx)
	_overlay.dragging_guide_axis = ""
	_overlay.dragging_guide_idx = -1
	_overlay.queue_redraw()


func _try_pick_and_start_drag(screen_pos: Vector2) -> bool:
	var m_du: Vector2 = _overlay.screen_to_rig(screen_pos)
	if _selected_kind == "hip_shadow":
		for p_name: String in ["body_core", "leg_r", "leg_l"]:
			if _hit_test_part_pixel(p_name, m_du):
				_begin_item_drag(m_du)
				return true

	var neck_s: Vector2 = _overlay.rig_to_screen(_store.get_neck_anchor_rel(_active_view, false))
	if screen_pos.distance_to(neck_s) <= 8.0:
		_select_target("neck_anchor", "neck_anchor")
		_begin_item_drag(m_du)
		return true

	if _overlay.show_bones:
		for b_name: String in _store.get_bone_names(_active_view):
			var bs: Vector2 = _overlay.rig_to_screen(_store.get_bone_pos_rel(_active_view, b_name, false))
			if screen_pos.distance_to(bs) <= 8.0:
				_select_target("bone", b_name)
				_begin_item_drag(m_du)
				return true

	# Pixel-accurate hit-test: Head Pass 2 (face/hair), then body parts in top-to-bottom draw order, then Head Pass 1 (neck).
	if _head_vis and _hit_test_head_pixel(m_du, true):
		_select_target("head", _active_head)
		_begin_item_drag(m_du)
		return true

	var ordered: Array[String] = _store.get_ordered_part_names(_active_view)
	for p_name: String in ordered:
		if not bool(_part_vis.get(p_name, true)):
			continue
		if _hit_test_part_pixel(p_name, m_du):
			_select_target("part", p_name)
			_begin_item_drag(m_du)
			return true

	if _head_under_vis and _hit_test_head_pixel(m_du, false):
		_select_target("head", _active_head)
		_begin_item_drag(m_du)
		return true

	# Fallback to currently selected item drag if clicked inside its bounding box
	if _selected_kind == "part" and bool(_part_vis.get(_selected_name, true)):
		var r_sel: Rect2 = _store.get_part_rect_rel(_active_view, _selected_name, false)
		if r_sel.has_point(m_du):
			_begin_item_drag(m_du)
			return true
	elif _selected_kind == "head" and (_head_vis or _head_under_vis):
		if _overlay.active_head_rect.has_point(m_du):
			_begin_item_drag(m_du)
			return true
	return false


func _begin_item_drag(mouse_du: Vector2) -> void:
	_dragging_item = true
	_drag_undo_pushed = false
	_drag_start_mouse_du = mouse_du
	_drag_start_item_pos = _get_selected_pos_rel()


func _hit_test_part_pixel(part_name: String, point_du: Vector2) -> bool:
	var r: Rect2 = _store.get_part_rect_rel(_active_view, part_name, false)
	if not r.has_point(point_du):
		return false
	var views: Dictionary = _rig.get_views()
	if not views.has(_active_view):
		return true
	var polys: Dictionary = (views[_active_view] as Dictionary).get("polys", {}) as Dictionary
	if not polys.has(part_name):
		return false
	var tex: Texture2D = (polys[part_name] as Polygon2D).texture
	var uv := Vector2((point_du.x - r.position.x) / maxf(r.size.x, 1.0), (point_du.y - r.position.y) / maxf(r.size.y, 1.0))
	return _sample_texture_alpha(tex, uv) > 0.05


func _hit_test_head_pixel(point_du: Vector2, skip_collar_behind_body: bool = true) -> bool:
	var neck_rel: Vector2 = _store.get_neck_anchor_rel(_active_view, false)
	var h_off: Vector2 = _store.get_head_combo_offset(_active_view, _active_head, false)
	var h_scale: float = _store.get_head_combo_scale(_active_view, _active_head, false)
	var h_sz: Vector2 = _store.get_head_disp_size(_active_head) * h_scale
	var r := Rect2(neck_rel + h_off - h_sz * 0.5, h_sz)
	if not r.has_point(point_du):
		return false
	var h_sprites: Dictionary = _rig.get_head_data().get("sprites", {}) as Dictionary
	if not h_sprites.has(_active_head):
		return false
	var spr: Sprite2D = h_sprites[_active_head] as Sprite2D
	var tex: Texture2D = spr.texture
	var uv := Vector2((point_du.x - r.position.x) / maxf(r.size.x, 1.0), (point_du.y - r.position.y) / maxf(r.size.y, 1.0))
	if _sample_texture_alpha(tex, uv) <= 0.05:
		return false
	if skip_collar_behind_body and bool(_part_vis.get("body_core", true)) and _hit_test_part_pixel("body_core", point_du):
		if spr.material is ShaderMaterial:
			var id_tex: Texture2D = (spr.material as ShaderMaterial).get_shader_parameter("id_mask_tex") as Texture2D
			if id_tex != null:
				var id_col: Color = _sample_texture_color(id_tex, uv)
				if id_col.b > 0.45 and id_col.a < 0.25:
					return false
	return true


func _sample_texture_color(tex: Texture2D, uv: Vector2) -> Color:
	if tex == null:
		return Color(0.0, 0.0, 0.0, 0.0)
	var key: int = tex.get_instance_id()
	var img: Image = _tex_image_cache.get(key, null) as Image
	if img == null:
		img = tex.get_image()
		if img == null or img.is_empty():
			return Color(0.0, 0.0, 0.0, 1.0)
		if img.is_compressed():
			img.decompress()
		_tex_image_cache[key] = img
	var px: int = clampi(int(uv.x * float(img.get_width())), 0, img.get_width() - 1)
	var py: int = clampi(int(uv.y * float(img.get_height())), 0, img.get_height() - 1)
	return img.get_pixel(px, py)


func _sample_texture_alpha(tex: Texture2D, uv: Vector2) -> float:
	return _sample_texture_color(tex, uv).a


func _apply_snapping(pos_du: Vector2) -> Vector2:
	var out: Vector2 = pos_du
	_overlay.snapped_x_du = null
	_overlay.snapped_y_du = null
	if Input.is_key_pressed(KEY_ALT):
		return out
	if _snap_grid:
		out.x = snappedf(out.x, _step_du)
		out.y = snappedf(out.y, _step_du)
	if _snap_guides:
		var thr: float = maxf(6.0 / _overlay.get_px_per_du(), 0.75)
		var best_dx: float = thr
		for vx: float in _overlay.v_guides_du:
			if absf(out.x - vx) < best_dx:
				best_dx = absf(out.x - vx)
				out.x = vx
				_overlay.snapped_x_du = vx
		var best_dy: float = thr
		for hy: float in _overlay.h_guides_du:
			if absf(out.y - hy) < best_dy:
				best_dy = absf(out.y - hy)
				out.y = hy
				_overlay.snapped_y_du = hy
	return out


func _get_selected_pos_rel() -> Vector2:
	if _selected_kind == "part":
		return _store.get_part_rect_rel(_active_view, _selected_name, false).position
	if _selected_kind == "head":
		return _store.get_head_combo_offset(_active_view, _active_head, false)
	if _selected_kind == "neck_anchor":
		return _store.get_neck_anchor_rel(_active_view, false)
	if _selected_kind == "bone":
		return _store.get_bone_pos_rel(_active_view, _selected_name, false)
	if _selected_kind == "hip_shadow":
		return _store.get_hip_cast_shadow(_active_view, false)["offset"] as Vector2
	return Vector2.ZERO


func _set_selected_pos_rel(pos_du: Vector2) -> void:
	if _selected_kind == "part":
		_store.set_part_pos_rel(_active_view, _selected_name, pos_du)
	elif _selected_kind == "head":
		_store.set_head_combo_offset(_active_view, _active_head, pos_du)
	elif _selected_kind == "neck_anchor":
		_store.set_neck_anchor_rel(_active_view, pos_du)
	elif _selected_kind == "bone":
		_store.set_bone_pos_rel(_active_view, _selected_name, pos_du, _move_bone_children)
	elif _selected_kind == "hip_shadow":
		var sh: Dictionary = _store.get_hip_cast_shadow(_active_view, false)
		_store.set_hip_cast_shadow(_active_view, bool(sh["enabled"]), pos_du, sh["color"] as Color, false)
	_refresh_live_and_inspector()


func _nudge_selected_by(delta_du: Vector2) -> void:
	_set_selected_pos_rel(_get_selected_pos_rel() + delta_du)


func _apply_selected_pos_from_inspector(val: Vector2, is_abs: bool) -> void:
	_store.push_undo_snapshot()
	if _selected_kind == "head":
		_store.set_head_combo_offset(_active_view, _active_head, val)
	elif _selected_kind == "hip_shadow":
		var sh: Dictionary = _store.get_hip_cast_shadow(_active_view, false)
		_store.set_hip_cast_shadow(_active_view, bool(sh["enabled"]), val, sh["color"] as Color, false)
	elif is_abs:
		var orig: Vector2 = _store.get_rig_origin(_active_view)
		_set_selected_pos_rel(val - orig)
		return
	else:
		_set_selected_pos_rel(val)
		return
	_refresh_live_and_inspector()


func _select_target(kind: String, t_name: String) -> void:
	_selected_kind = kind
	_selected_name = t_name
	_refresh_all()


func _switch_view_and_head(v_key: String, h_key: String) -> void:
	var allowed: Array[String] = StoreScript.get_allowed_heads_for_view(v_key)
	var safe_head: String = h_key
	if not allowed.has(safe_head):
		var def_h: String = ViewRouterScript.get_default_head_for_body(v_key)
		safe_head = def_h if allowed.has(def_h) else (allowed[0] if not allowed.is_empty() else def_h)
	_active_view = v_key
	_active_head = safe_head
	_active_allowed_heads = allowed
	if _selected_kind == "head":
		_selected_name = _active_head
	_rig.set_static_inspection(true, _active_view, _active_head, false)
	_syncing_ui = true
	var v_opt: OptionButton = _hud_refs["view_opt"] as OptionButton
	var h_opt: OptionButton = _hud_refs["head_opt"] as OptionButton
	v_opt.select(maxi(0, HudScript.VIEW_KEYS.find(_active_view)))
	HudScript.populate_head_options(h_opt, _active_allowed_heads, _active_head)
	_syncing_ui = false
	_rebuild_ghost()
	_refresh_all()


func _cycle_valid_combo() -> void:
	var allowed: Array[String] = _active_allowed_heads if not _active_allowed_heads.is_empty() else StoreScript.get_allowed_heads_for_view(_active_view)
	if allowed.is_empty():
		return
	var cur_idx: int = allowed.find(_active_head)
	var nxt_idx: int = (cur_idx + 1) % allowed.size()
	var nxt_head: String = allowed[nxt_idx]
	_switch_view_and_head(_active_view, nxt_head)
	_show_toast("Combo %s + %s (%d/%d)" % [_active_view.to_upper(), nxt_head, nxt_idx + 1, allowed.size()])


func _apply_auto_head_for_view() -> void:
	var def_h: String = ViewRouterScript.get_default_head_for_body(_active_view)
	_switch_view_and_head(_active_view, def_h)


func _on_view_selected(idx: int) -> void:
	if _syncing_ui or idx < 0 or idx >= HudScript.VIEW_KEYS.size():
		return
	var v_key: String = HudScript.VIEW_KEYS[idx]
	var allowed: Array[String] = StoreScript.get_allowed_heads_for_view(v_key)
	var h_key: String = ViewRouterScript.get_default_head_for_body(v_key) if (_auto_head or not allowed.has(_active_head)) else _active_head
	_switch_view_and_head(v_key, h_key)


func _on_head_selected(idx: int) -> void:
	if _syncing_ui or idx < 0 or idx >= _active_allowed_heads.size():
		return
	_switch_view_and_head(_active_view, _active_allowed_heads[idx])


func _on_step_selected(step_val: float) -> void:
	_step_du = step_val
	for sp: SpinBox in [_hud_refs["rel_x_spin"] as SpinBox, _hud_refs["rel_y_spin"] as SpinBox, _hud_refs["abs_x_spin"] as SpinBox, _hud_refs["abs_y_spin"] as SpinBox]:
		sp.custom_arrow_step = step_val


func _on_skin_selected(idx: int) -> void:
	if _active_profile == null or idx < 0 or idx >= _active_profile.skins.size():
		return
	_rig.apply_skin_preset(_active_profile.skins[idx])


func _set_white_bg(enabled: bool) -> void:
	_bg_rect.color = Color(0.96, 0.96, 0.98, 1.0) if enabled else Color(0.065, 0.072, 0.105, 1.0)
	_overlay.white_bg_mode = enabled
	_overlay.queue_redraw()


func _zoom_at_screen_pos(factor: float, screen_pos: Vector2) -> void:
	var before_world: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * screen_pos
	var new_z: float = clampf(_camera.zoom.x * factor, 0.5, 24.0)
	_camera.zoom = Vector2(new_z, new_z)
	var after_world: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * screen_pos
	_camera.position += (before_world - after_world)
	_update_zoom_label()


func _set_zoom_level(z: float) -> void:
	_camera.zoom = Vector2(z, z)
	_update_zoom_label()


func _update_zoom_label() -> void:
	(_hud_refs["zoom_lbl"] as Label).text = "Zoom: %.1fx" % _camera.zoom.x


func _refresh_all() -> void:
	_refresh_live_and_inspector()
	_rebuild_layers_panel()
	_update_symmetry_buttons()


func _refresh_live_and_inspector() -> void:
	LayerBuilderScript.sync_rig_live_state(_rig, _store, _active_view, _active_head, _built_part_origins, {
		"part_vis": _part_vis,
		"part_opac": _part_opac,
		"head_vis": _head_vis,
		"head_opac": _head_opac,
		"head_under_vis": _head_under_vis,
		"head_under_opac": _head_under_opac,
		"pinch_overlay": _show_pinch_overlay,
	})
	_sync_inspector_values()
	_update_save_button_state()
	_overlay.queue_redraw()


func _sync_inspector_values() -> void:
	_syncing_ui = true
	var sel_lbl: Label = _hud_refs["sel_title_lbl"] as Label
	var rel_x: SpinBox = _hud_refs["rel_x_spin"] as SpinBox
	var rel_y: SpinBox = _hud_refs["rel_y_spin"] as SpinBox
	var abs_x: SpinBox = _hud_refs["abs_x_spin"] as SpinBox
	var abs_y: SpinBox = _hud_refs["abs_y_spin"] as SpinBox
	var delta_lbl: Label = _hud_refs["delta_lbl"] as Label
	var size_lbl: Label = _hud_refs["size_lbl"] as Label
	var z_row: Control = _hud_refs["z_row"] as Control
	var z_spin: SpinBox = _hud_refs["z_spin"] as SpinBox
	var head_scale_row: Control = _hud_refs["head_scale_row"] as Control
	var head_scale_spin: SpinBox = _hud_refs["head_scale_spin"] as SpinBox
	var bone_chk: CheckBox = _hud_refs["bone_children_chk"] as CheckBox

	var orig: Vector2 = _store.get_rig_origin(_active_view)
	var cur_rel: Vector2 = _get_selected_pos_rel()
	var base_rel: Vector2 = Vector2.ZERO
	var sc_cur: float = _store.get_head_combo_scale(_active_view, _active_head, false)
	var sc_base: float = _store.get_head_combo_scale(_active_view, _active_head, true)
	z_row.visible = (_selected_kind == "part")
	head_scale_row.visible = (_selected_kind == "head")
	head_scale_spin.editable = (_selected_kind == "head")
	head_scale_spin.value = sc_cur
	bone_chk.visible = (_selected_kind == "bone")
	abs_x.editable = (_selected_kind != "head" and _selected_kind != "hip_shadow")
	abs_y.editable = (_selected_kind != "head" and _selected_kind != "hip_shadow")

	if _selected_kind == "part":
		sel_lbl.text = "Pieza: %s (%s)" % [_selected_name, _active_view.to_upper()]
		var r_cur: Rect2 = _store.get_part_rect_rel(_active_view, _selected_name, false)
		base_rel = _store.get_part_rect_rel(_active_view, _selected_name, true).position
		size_lbl.text = "Tamaño: %.1f x %.1f du" % [r_cur.size.x, r_cur.size.y]
		z_spin.value = _store.get_part_z_order(_active_view, _selected_name)
	elif _selected_kind == "head":
		base_rel = _store.get_head_combo_offset(_active_view, _active_head, true)
		var disp_sz: Vector2 = _store.get_head_disp_size(_active_head)
		sel_lbl.text = "Cabeza: %s (Solo cuerpo %s)" % [_active_head, _active_view.to_upper()]
		size_lbl.text = "Disp: %.1f x %.1f du (Esc %.3fx)" % [disp_sz.x * sc_cur, disp_sz.y * sc_cur, sc_cur]
	elif _selected_kind == "neck_anchor":
		sel_lbl.text = "Ancla: neck_anchor (%s)" % _active_view.to_upper()
		base_rel = _store.get_neck_anchor_rel(_active_view, true)
		size_lbl.text = "Sincronizado con hueso Neck"
	elif _selected_kind == "bone":
		sel_lbl.text = "Hueso: %s (%s)" % [_selected_name, _active_view.to_upper()]
		base_rel = _store.get_bone_pos_rel(_active_view, _selected_name, true)
		var par: String = _store.get_bone_parent(_active_view, _selected_name)
		size_lbl.text = "Padre: %s" % (par if not par.is_empty() else "(Raíz)")
	elif _selected_kind == "hip_shadow":
		sel_lbl.text = "Sombra Traje (%s)" % _active_view.to_upper()
		base_rel = _store.get_hip_cast_shadow(_active_view, true)["offset"] as Vector2
		size_lbl.text = "Offset en px de rig (Flechas / Drag)"

	rel_x.value = cur_rel.x
	rel_y.value = cur_rel.y
	if _selected_kind == "head":
		var neck_rel: Vector2 = _store.get_neck_anchor_rel(_active_view, false)
		abs_x.value = orig.x + neck_rel.x + cur_rel.x
		abs_y.value = orig.y + neck_rel.y + cur_rel.y
	else:
		abs_x.value = orig.x + cur_rel.x
		abs_y.value = orig.y + cur_rel.y

	var d_pos: Vector2 = cur_rel - base_rel
	var po_target_lbl: Label = _hud_refs["po_target_lbl"] as Label
	var po_chk: CheckBox = _hud_refs["po_chk"] as CheckBox
	var po_col: ColorPickerButton = _hud_refs["po_col"] as ColorPickerButton
	var po_seams_chk: CheckBox = _hud_refs["po_seams_chk"] as CheckBox
	var po_erode_slider: HSlider = _hud_refs["po_erode_slider"] as HSlider
	var po_erode_spin: SpinBox = _hud_refs["po_erode_spin"] as SpinBox
	var po_out_slider: HSlider = _hud_refs["po_out_slider"] as HSlider
	var po_out_spin: SpinBox = _hud_refs["po_out_spin"] as SpinBox
	var po_copy_view_btn: Button = _hud_refs["po_copy_view_btn"] as Button
	var po_copy_all_btn: Button = _hud_refs["po_copy_all_btn"] as Button
	var is_outline_editable: bool = (_selected_kind == "part" or _selected_kind == "head")
	po_chk.disabled = not is_outline_editable
	po_col.disabled = not is_outline_editable
	po_seams_chk.disabled = not is_outline_editable
	po_erode_slider.editable = is_outline_editable
	po_erode_spin.editable = is_outline_editable
	po_out_slider.editable = is_outline_editable
	po_out_spin.editable = is_outline_editable
	po_copy_view_btn.disabled = (_selected_kind != "part")
	po_copy_all_btn.disabled = not is_outline_editable
	if _selected_kind == "part":
		po_target_lbl.text = "Objetivo: %s (%s)" % [_selected_name, _active_view.to_upper()]
		po_copy_all_btn.text = "A 8 Vistas"
		var po_d: Dictionary = _store.get_part_outline(_active_view, _selected_name, false)
		po_chk.button_pressed = bool(po_d["enabled"])
		po_col.color = po_d["color"] as Color
		po_seams_chk.button_pressed = bool(po_d["respect_seams"])
		po_erode_slider.value = minf(float(po_d["erode_du"]), po_erode_slider.max_value)
		po_erode_spin.value = float(po_d["erode_du"])
		po_out_slider.value = minf(float(po_d["outline_du"]), po_out_slider.max_value)
		po_out_spin.value = float(po_d["outline_du"])
	elif _selected_kind == "head":
		po_target_lbl.text = "Objetivo: %s (Cabeza)" % _active_head
		po_copy_all_btn.text = "A 8 Cabezas"
		var ho_d: Dictionary = _store.get_head_outline(_active_head, false)
		po_chk.button_pressed = bool(ho_d["enabled"])
		po_col.color = ho_d["color"] as Color
		po_seams_chk.button_pressed = bool(ho_d["respect_seams"])
		po_erode_slider.value = minf(float(ho_d["erode_du"]), po_erode_slider.max_value)
		po_erode_spin.value = float(ho_d["erode_du"])
		po_out_slider.value = minf(float(ho_d["outline_du"]), po_out_slider.max_value)
		po_out_spin.value = float(ho_d["outline_du"])
	else:
		po_target_lbl.text = "Objetivo: selecciona pieza o cabeza"
		po_copy_all_btn.text = "A 8 Vistas"
		po_chk.button_pressed = false
		po_erode_slider.value = 0.0
		po_erode_spin.value = 0.0
		po_out_slider.value = 0.0
		po_out_spin.value = 0.0

	var hip_sh: Dictionary = _store.get_hip_cast_shadow(_active_view, false)
	(_hud_refs["hip_sh_chk"] as CheckBox).button_pressed = bool(hip_sh["enabled"])
	(_hud_refs["hip_sh_col"] as ColorPickerButton).color = hip_sh["color"] as Color
	var sh_off: Vector2 = hip_sh["offset"] as Vector2
	(_hud_refs["hip_sh_x_spin"] as SpinBox).value = sh_off.x
	(_hud_refs["hip_sh_y_spin"] as SpinBox).value = sh_off.y
	var sp: Dictionary = _store.get_stocking_pinch(_active_view, false)
	(_hud_refs["sp_chk"] as CheckBox).button_pressed = bool(sp["enabled"])
	(_hud_refs["sp_vr_spin"] as SpinBox).value = float(sp["v_r"])
	(_hud_refs["sp_vl_spin"] as SpinBox).value = float(sp["v_l"])
	(_hud_refs["sp_tr_spin"] as SpinBox).value = float(sp["tilt_r"])
	(_hud_refs["sp_tl_spin"] as SpinBox).value = float(sp["tilt_l"])
	(_hud_refs["sp_s_spin"] as SpinBox).value = float(sp["strength"])
	(_hud_refs["sp_w_spin"] as SpinBox).value = float(sp["width"])
	(_hud_refs["sp_sh_spin"] as SpinBox).value = float(sp["shadow"])
	if _selected_kind == "head":
		delta_lbl.text = "Delta vs Guardado: (%+.2f, %+.2f) du | Esc %+.3f" % [d_pos.x, d_pos.y, sc_cur - sc_base]
	else:
		delta_lbl.text = "Delta vs Guardado: (%+.2f, %+.2f) du" % [d_pos.x, d_pos.y]
	_syncing_ui = false


func _rebuild_layers_panel() -> void:
	LayerBuilderScript.rebuild_layers_ui(
		_hud_refs["layers_list"] as VBoxContainer,
		_hud_refs["bones_list"] as VBoxContainer,
		_store,
		_active_view,
		_active_head,
		{
			"part_vis": _part_vis,
			"part_opac": _part_opac,
			"head_vis": _head_vis,
			"head_opac": _head_opac,
			"head_under_vis": _head_under_vis,
			"head_under_opac": _head_under_opac,
			"selected_kind": _selected_kind,
			"selected_name": _selected_name,
			"solo_target": _solo_target,
		},
		{
			"on_toggle_vis": Callable(self, "_toggle_layer_vis"),
			"on_toggle_solo": Callable(self, "_toggle_layer_solo"),
			"on_select_layer": func(k: String) -> void:
				if k == "head" or k == "head_under":
					_select_target("head", _active_head)
				else:
					_select_target("part", k),
			"on_step_z": Callable(self, "_step_part_z"),
			"on_opacity_changed": Callable(self, "_set_layer_opacity"),
			"on_select_bone": func(b_name: String) -> void: _select_target("bone", b_name),
		}
	)


func _toggle_layer_vis(key: String) -> void:
	_solo_target = ""
	if key == "head":
		_head_vis = not _head_vis
	elif key == "head_under":
		_head_under_vis = not _head_under_vis
	else:
		_part_vis[key] = not bool(_part_vis.get(key, true))
	_refresh_all()


func _toggle_layer_solo(key: String) -> void:
	if _solo_target == key:
		_solo_target = ""
		if not _pre_solo_snapshot.is_empty():
			_part_vis = (_pre_solo_snapshot["part_vis"] as Dictionary).duplicate()
			_head_vis = bool(_pre_solo_snapshot["head_vis"])
			_head_under_vis = bool(_pre_solo_snapshot.get("head_under_vis", true))
	else:
		if _solo_target.is_empty():
			_pre_solo_snapshot = {
				"part_vis": _part_vis.duplicate(),
				"head_vis": _head_vis,
				"head_under_vis": _head_under_vis,
			}
		_solo_target = key
		_head_vis = (key == "head")
		_head_under_vis = (key == "head_under")
		for pk: String in StoreScript.PART_KEYS:
			_part_vis[pk] = (pk == key)
	_refresh_all()


func _set_layer_opacity(key: String, val: float) -> void:
	if key == "head":
		_head_opac = val
	elif key == "head_under":
		_head_under_opac = val
	else:
		_part_opac[key] = val
	_refresh_live_and_inspector()


func _step_part_z(part_name: String, delta_z: int) -> void:
	_store.push_undo_snapshot()
	var cur_z: int = _store.get_part_z_order(_active_view, part_name)
	_store.set_part_z_order(_active_view, part_name, cur_z + delta_z)
	_refresh_all()


func _apply_visibility_preset(preset: String) -> void:
	_solo_target = ""
	if preset == "all":
		_init_visibility_defaults()
	elif preset == "no_arms":
		_part_vis["arm_r"] = false
		_part_vis["arm_l"] = false
		_part_vis["pauldron_r"] = false
		_part_vis["pauldron_l"] = false
	elif preset == "limbs":
		for pk: String in StoreScript.PART_KEYS:
			_part_vis[pk] = (pk != "body_core")
		_head_vis = false
		_head_under_vis = false
	elif preset == "toggle_head":
		var next_vis: bool = not (_head_vis or _head_under_vis)
		_head_vis = next_vis
		_head_under_vis = next_vis
	_refresh_all()


func _rebuild_ghost() -> void:
	LayerBuilderScript.rebuild_ghost_node(_ghost_root, _rig, _store, _active_view, _active_head, _show_ghost, _ghost_opacity)


func _update_symmetry_buttons() -> void:
	var partner: String = _store.get_mirror_partner_view(_active_view)
	var m_btn: Button = _hud_refs["mirror_partner_btn"] as Button
	m_btn.disabled = partner.is_empty()
	m_btn.text = ("Espejar %s -> %s" % [_active_view.to_upper(), partner.to_upper()]) if not partner.is_empty() else "Espejar (solo laterales)"
	var is_axial: bool = (_active_view == "s" or _active_view == "n")
	(_hud_refs["sym_r_to_l_btn"] as Button).disabled = not is_axial
	(_hud_refs["sym_l_to_r_btn"] as Button).disabled = not is_axial


func _mirror_to_partner() -> void:
	_store.push_undo_snapshot()
	var dst: String = _store.mirror_view_to_partner(_active_view)
	if not dst.is_empty():
		_show_toast("Espejado %s -> %s" % [_active_view.to_upper(), dst.to_upper()])
		_update_save_button_state()


func _symmetrize_lr(src_side: String) -> void:
	_store.push_undo_snapshot()
	if _store.symmetrize_lr_in_view(_active_view, src_side):
		_refresh_all()
		_show_toast("Simetrizado %s en vista %s" % [src_side.to_upper(), _active_view.to_upper()])


func _reset_selected_item() -> void:
	_store.push_undo_snapshot()
	_store.reset_item_to_baseline(_active_view, _selected_kind, _selected_name)
	_refresh_all()
	_show_toast("Elemento reseteado al último guardado")


func _reset_active_view() -> void:
	_store.push_undo_snapshot()
	_store.reset_view_to_baseline(_active_view)
	_refresh_all()
	_show_toast("Vista %s reseteada al último guardado" % _active_view.to_upper())


func _perform_undo() -> void:
	if _store.undo():
		_refresh_all()
		_show_toast("Deshacer aplicado")


func _perform_redo() -> void:
	if _store.redo():
		_refresh_all()
		_show_toast("Rehacer aplicado")


func _perform_save() -> void:
	var res: Dictionary = _store.save_all()
	if bool(res.get("ok", false)):
		_rebuild_ghost()
		_refresh_all()
		_show_toast("Guardado OK (%d vistas + heads + overrides)" % (res["saved_views"] as Array).size())
	else:
		_show_toast("Error al guardar: %s" % str(res.get("errors", [])))


func _update_save_button_state() -> void:
	var save_btn: Button = _hud_refs.get("save_btn", null) as Button
	var undo_btn: Button = _hud_refs.get("undo_btn", null) as Button
	var redo_btn: Button = _hud_refs.get("redo_btn", null) as Button
	if save_btn != null:
		save_btn.text = "Guardar* (Ctrl+S)" if _store.is_dirty() else "Guardar (Ctrl+S)"
		save_btn.modulate = Color(1.0, 0.85, 0.35, 1.0) if _store.is_dirty() else Color.WHITE
	if undo_btn != null:
		undo_btn.disabled = not _store.can_undo()
	if redo_btn != null:
		redo_btn.disabled = not _store.can_redo()


func _show_toast(msg: String) -> void:
	var lbl: Label = _hud_refs.get("toast_lbl", null) as Label
	if lbl != null:
		lbl.text = msg
	_toast_timer = 3.5

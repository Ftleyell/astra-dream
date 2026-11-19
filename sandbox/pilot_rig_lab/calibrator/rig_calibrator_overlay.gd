class_name RigCalibratorOverlay
extends Control
## Overlay CAD de precisión en espacio de pantalla: reglas graduadas (Top/Left),
## guías arrastrables con snap, grilla en du, bounding boxes, anclas y pines de huesos.

const RULER_SIZE: float = 24.0
const GUIDE_PICK_PX: float = 7.0

var show_rulers: bool = true
var show_grid: bool = true
var show_bboxes: bool = true
var show_bones: bool = true
var white_bg_mode: bool = false

var work_rect: Rect2 = Rect2(268.0, 44.0, 720.0, 640.0)
var rig_origin_canvas: Vector2 = Vector2(260.0, 286.7)
var canvas_size_du: Vector2 = Vector2(520.0, 560.0)

var selected_kind: String = "part"
var selected_name: String = "body_core"
var active_part_rects: Dictionary = {}
var active_head_rect: Rect2 = Rect2()
var active_head_visible: bool = true
var active_head_label: String = ""
var active_neck_rel: Vector2 = Vector2.ZERO
var active_bones_rel: Dictionary = {}
var active_bone_parents: Dictionary = {}
var part_visibility: Dictionary = {}

var h_guides_du: Array[float] = []
var v_guides_du: Array[float] = []
var hovered_guide_axis: String = ""
var hovered_guide_idx: int = -1
var dragging_guide_axis: String = ""
var dragging_guide_idx: int = -1
var snapped_x_du: Variant = null
var snapped_y_du: Variant = null

var cursor_rig_du: Vector2 = Vector2.ZERO
var cursor_inside_work: bool = false

var _world_to_screen: Transform2D = Transform2D.IDENTITY
var _rig_world_pos: Vector2 = Vector2.ZERO
var _rig_scale: Vector2 = Vector2(0.378, 0.378)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func update_view_state(
	p_work_rect: Rect2,
	p_canvas_xf: Transform2D,
	p_rig_world_pos: Vector2,
	p_rig_scale: Vector2,
	p_rig_origin_canvas: Vector2
) -> void:
	work_rect = p_work_rect
	_world_to_screen = p_canvas_xf
	_rig_world_pos = p_rig_world_pos
	_rig_scale = p_rig_scale
	rig_origin_canvas = p_rig_origin_canvas
	queue_redraw()


func rig_to_screen(p_rig_du: Vector2) -> Vector2:
	var p_world: Vector2 = _rig_world_pos + p_rig_du * _rig_scale
	return _world_to_screen * p_world


func screen_to_rig(p_screen: Vector2) -> Vector2:
	var p_world: Vector2 = _world_to_screen.affine_inverse() * p_screen
	var sx: float = _rig_scale.x if absf(_rig_scale.x) > 0.0001 else 1.0
	var sy: float = _rig_scale.y if absf(_rig_scale.y) > 0.0001 else 1.0
	return Vector2((p_world.x - _rig_world_pos.x) / sx, (p_world.y - _rig_world_pos.y) / sy)


func get_px_per_du() -> float:
	var p0: Vector2 = rig_to_screen(Vector2.ZERO)
	var p1: Vector2 = rig_to_screen(Vector2(1.0, 0.0))
	return maxf(p0.distance_to(p1), 0.01)


func get_canvas_rect_screen() -> Rect2:
	if show_rulers:
		return Rect2(
			work_rect.position + Vector2(RULER_SIZE, RULER_SIZE),
			(work_rect.size - Vector2(RULER_SIZE, RULER_SIZE)).max(Vector2(64.0, 64.0))
		)
	return work_rect


func is_in_top_ruler(screen_pos: Vector2) -> bool:
	if not show_rulers:
		return false
	var r := Rect2(work_rect.position.x + RULER_SIZE, work_rect.position.y, work_rect.size.x - RULER_SIZE, RULER_SIZE)
	return r.has_point(screen_pos)


func is_in_left_ruler(screen_pos: Vector2) -> bool:
	if not show_rulers:
		return false
	var r := Rect2(work_rect.position.x, work_rect.position.y + RULER_SIZE, RULER_SIZE, work_rect.size.y - RULER_SIZE)
	return r.has_point(screen_pos)


func hit_test_guide(screen_pos: Vector2) -> Dictionary:
	var canvas_r: Rect2 = get_canvas_rect_screen()
	if not canvas_r.has_point(screen_pos):
		return {}
	for i: int in range(h_guides_du.size()):
		var gy: float = rig_to_screen(Vector2(0.0, h_guides_du[i])).y
		if absf(screen_pos.y - gy) <= GUIDE_PICK_PX:
			return {"axis": "h", "index": i}
	for j: int in range(v_guides_du.size()):
		var gx: float = rig_to_screen(Vector2(v_guides_du[j], 0.0)).x
		if absf(screen_pos.x - gx) <= GUIDE_PICK_PX:
			return {"axis": "v", "index": j}
	return {}


func clear_guides() -> void:
	h_guides_du.clear()
	v_guides_du.clear()
	hovered_guide_axis = ""
	hovered_guide_idx = -1
	queue_redraw()


func _draw() -> void:
	var canvas_r: Rect2 = get_canvas_rect_screen()
	if canvas_r.size.x < 16.0 or canvas_r.size.y < 16.0:
		return

	var font: Font = ThemeDB.fallback_font
	var px_per_du: float = get_px_per_du()
	var top_left_du: Vector2 = screen_to_rig(canvas_r.position)
	var bot_right_du: Vector2 = screen_to_rig(canvas_r.position + canvas_r.size)

	# 1. Grilla de diseño (du)
	if show_grid:
		_draw_grid(canvas_r, top_left_du, bot_right_du, px_per_du)

	# 2. Marco canónico del lienzo 520x560 du
	var sheet_tl: Vector2 = rig_to_screen(-rig_origin_canvas)
	var sheet_br: Vector2 = rig_to_screen(canvas_size_du - rig_origin_canvas)
	var sheet_r := Rect2(sheet_tl, sheet_br - sheet_tl).intersection(canvas_r)
	if sheet_r.size.x > 2.0 and sheet_r.size.y > 2.0:
		var frame_col := Color(0.45, 0.55, 0.72, 0.35) if not white_bg_mode else Color(0.25, 0.35, 0.55, 0.35)
		draw_rect(Rect2(sheet_tl, sheet_br - sheet_tl), frame_col, false, 1.0)

	# 3. Bounding Boxes de piezas visibles y cabeza
	if show_bboxes:
		_draw_bounding_boxes(canvas_r, font)

	# 4. Guías horizontales y verticales
	_draw_guides(canvas_r, font)

	# 5. Crosshair de rig_origin (0,0) y neck_anchor
	_draw_anchors(canvas_r, font)

	# 6. Esqueleto (18 huesos)
	if show_bones:
		_draw_bones(canvas_r, font)

	# 7. Reglas graduadas (Top & Left)
	if show_rulers:
		_draw_rulers(font, px_per_du)


func _draw_grid(canvas_r: Rect2, tl_du: Vector2, br_du: Vector2, px_per_du: float) -> void:
	var major_step: float = 10.0
	if px_per_du < 1.2:
		major_step = 50.0
	elif px_per_du < 2.2:
		major_step = 20.0

	var minor_step: float = 0.0
	if px_per_du >= 6.0:
		minor_step = 1.0
	elif px_per_du >= 2.8:
		minor_step = 5.0

	var minor_col := Color(0.32, 0.42, 0.62, 0.14) if not white_bg_mode else Color(0.20, 0.25, 0.35, 0.14)
	var major_col := Color(0.40, 0.54, 0.80, 0.28) if not white_bg_mode else Color(0.20, 0.30, 0.48, 0.28)
	var axis_x_col := Color(0.90, 0.32, 0.38, 0.48)
	var axis_y_col := Color(0.32, 0.86, 0.48, 0.48)

	if minor_step > 0.0:
		var sx0: int = int(floor(tl_du.x / minor_step))
		var sx1: int = int(ceil(br_du.x / minor_step))
		if sx1 - sx0 <= 400:
			for ix: int in range(sx0, sx1 + 1):
				var x_du: float = float(ix) * minor_step
				var sx: float = rig_to_screen(Vector2(x_du, 0.0)).x
				if sx >= canvas_r.position.x and sx <= canvas_r.end.x:
					draw_line(Vector2(sx, canvas_r.position.y), Vector2(sx, canvas_r.end.y), minor_col, 1.0)
		var sy0: int = int(floor(tl_du.y / minor_step))
		var sy1: int = int(ceil(br_du.y / minor_step))
		if sy1 - sy0 <= 400:
			for iy: int in range(sy0, sy1 + 1):
				var y_du: float = float(iy) * minor_step
				var sy: float = rig_to_screen(Vector2(0.0, y_du)).y
				if sy >= canvas_r.position.y and sy <= canvas_r.end.y:
					draw_line(Vector2(canvas_r.position.x, sy), Vector2(canvas_r.end.x, sy), minor_col, 1.0)

	var mx0: int = int(floor(tl_du.x / major_step))
	var mx1: int = int(ceil(br_du.x / major_step))
	for ix: int in range(mx0, mx1 + 1):
		var x_du: float = float(ix) * major_step
		var sx: float = rig_to_screen(Vector2(x_du, 0.0)).x
		if sx >= canvas_r.position.x and sx <= canvas_r.end.x:
			var col: Color = axis_y_col if ix == 0 else major_col
			draw_line(Vector2(sx, canvas_r.position.y), Vector2(sx, canvas_r.end.y), col, 1.0)

	var my0: int = int(floor(tl_du.y / major_step))
	var my1: int = int(ceil(br_du.y / major_step))
	for iy: int in range(my0, my1 + 1):
		var y_du: float = float(iy) * major_step
		var sy: float = rig_to_screen(Vector2(0.0, y_du)).y
		if sy >= canvas_r.position.y and sy <= canvas_r.end.y:
			var col: Color = axis_x_col if iy == 0 else major_col
			draw_line(Vector2(canvas_r.position.x, sy), Vector2(canvas_r.end.x, sy), col, 1.0)


func _draw_bounding_boxes(canvas_r: Rect2, font: Font) -> void:
	for p_name: String in active_part_rects.keys():
		if not bool(part_visibility.get(p_name, true)):
			continue
		var r_du: Rect2 = active_part_rects[p_name] as Rect2
		if r_du.size == Vector2.ZERO:
			continue
		var is_sel: bool = (selected_kind == "part" and selected_name == p_name)
		var tl: Vector2 = rig_to_screen(r_du.position)
		var br: Vector2 = rig_to_screen(r_du.end)
		var sr := Rect2(tl, br - tl)
		if not canvas_r.intersects(sr):
			continue
		var box_col := Color(1.0, 0.82, 0.22, 0.95) if is_sel else Color(0.55, 0.78, 1.0, 0.30)
		draw_rect(sr, box_col, false, 1.5 if is_sel else 1.0)
		if is_sel:
			_draw_corner_handles(sr, box_col)
			if font != null:
				var lbl_txt: String = "%s (%.2f, %.2f)" % [p_name, r_du.position.x, r_du.position.y]
				draw_string(font, tl + Vector2(3.0, -5.0), lbl_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, box_col)

	if active_head_visible and active_head_rect.size != Vector2.ZERO:
		var is_h_sel: bool = (selected_kind == "head")
		var htl: Vector2 = rig_to_screen(active_head_rect.position)
		var hbr: Vector2 = rig_to_screen(active_head_rect.end)
		var hsr := Rect2(htl, hbr - htl)
		if canvas_r.intersects(hsr):
			var h_col := Color(0.28, 1.0, 0.84, 0.95) if is_h_sel else Color(0.35, 0.92, 0.80, 0.32)
			draw_rect(hsr, h_col, false, 1.5 if is_h_sel else 1.0)
			if is_h_sel:
				_draw_corner_handles(hsr, h_col)
				if font != null:
					var h_txt: String = active_head_label if not active_head_label.is_empty() else selected_name
					draw_string(font, htl + Vector2(3.0, -5.0), h_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, h_col)


func _draw_corner_handles(sr: Rect2, col: Color) -> void:
	var hs: float = 3.5
	for pt: Vector2 in [sr.position, Vector2(sr.end.x, sr.position.y), sr.end, Vector2(sr.position.x, sr.end.y)]:
		draw_rect(Rect2(pt - Vector2(hs, hs), Vector2(hs * 2.0, hs * 2.0)), col, true)


func _draw_guides(canvas_r: Rect2, font: Font) -> void:
	for i: int in range(h_guides_du.size()):
		var y_du: float = h_guides_du[i]
		var sy: float = rig_to_screen(Vector2(0.0, y_du)).y
		if sy < canvas_r.position.y or sy > canvas_r.end.y:
			continue
		var is_hot: bool = (hovered_guide_axis == "h" and hovered_guide_idx == i) or (dragging_guide_axis == "h" and dragging_guide_idx == i) or (snapped_y_du != null and absf(float(snapped_y_du) - y_du) < 0.01)
		var col := Color(1.0, 0.90, 0.25, 0.95) if is_hot else Color(0.20, 0.88, 1.0, 0.72)
		draw_dashed_line(Vector2(canvas_r.position.x, sy), Vector2(canvas_r.end.x, sy), col, 1.2 if is_hot else 1.0, 6.0)
		if font != null:
			draw_string(font, Vector2(canvas_r.position.x + 6.0, sy - 3.0), "Y=%.2f" % y_du, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, col)

	for j: int in range(v_guides_du.size()):
		var x_du: float = v_guides_du[j]
		var sx: float = rig_to_screen(Vector2(x_du, 0.0)).x
		if sx < canvas_r.position.x or sx > canvas_r.end.x:
			continue
		var is_hot: bool = (hovered_guide_axis == "v" and hovered_guide_idx == j) or (dragging_guide_axis == "v" and dragging_guide_idx == j) or (snapped_x_du != null and absf(float(snapped_x_du) - x_du) < 0.01)
		var col := Color(1.0, 0.90, 0.25, 0.95) if is_hot else Color(0.20, 0.88, 1.0, 0.72)
		draw_dashed_line(Vector2(sx, canvas_r.position.y), Vector2(sx, canvas_r.end.y), col, 1.2 if is_hot else 1.0, 6.0)
		if font != null:
			draw_string(font, Vector2(sx + 4.0, canvas_r.position.y + 14.0), "X=%.2f" % x_du, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, col)


func _draw_anchors(canvas_r: Rect2, font: Font) -> void:
	var orig_s: Vector2 = rig_to_screen(Vector2.ZERO)
	if canvas_r.has_point(orig_s):
		draw_line(orig_s + Vector2(-8.0, 0.0), orig_s + Vector2(8.0, 0.0), Color(0.3, 1.0, 0.5, 0.9), 1.5)
		draw_line(orig_s + Vector2(0.0, -8.0), orig_s + Vector2(0.0, 8.0), Color(0.3, 1.0, 0.5, 0.9), 1.5)
		draw_circle(orig_s, 3.0, Color(0.3, 1.0, 0.5, 0.9))

	var neck_s: Vector2 = rig_to_screen(active_neck_rel)
	if canvas_r.has_point(neck_s):
		var is_n_sel: bool = (selected_kind == "neck_anchor")
		var n_col := Color(1.0, 0.35, 0.85, 1.0) if is_n_sel else Color(1.0, 0.45, 0.85, 0.75)
		var r: float = 6.5 if is_n_sel else 5.0
		var pts := PackedVector2Array([
			neck_s + Vector2(0.0, -r),
			neck_s + Vector2(r, 0.0),
			neck_s + Vector2(0.0, r),
			neck_s + Vector2(-r, 0.0),
			neck_s + Vector2(0.0, -r),
		])
		draw_polyline(pts, n_col, 1.8 if is_n_sel else 1.2)
		if is_n_sel and font != null:
			draw_string(font, neck_s + Vector2(9.0, 4.0), "neck_anchor (%.2f, %.2f)" % [active_neck_rel.x, active_neck_rel.y], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, n_col)


func _draw_bones(canvas_r: Rect2, font: Font) -> void:
	for b_name: String in active_bones_rel.keys():
		var p_name: String = str(active_bone_parents.get(b_name, ""))
		if p_name.is_empty() or not active_bones_rel.has(p_name):
			continue
		var p0: Vector2 = rig_to_screen(active_bones_rel[p_name] as Vector2)
		var p1: Vector2 = rig_to_screen(active_bones_rel[b_name] as Vector2)
		if canvas_r.has_point(p0) or canvas_r.has_point(p1):
			draw_line(p0, p1, Color(0.95, 0.75, 0.35, 0.65), 1.4)

	for b_name: String in active_bones_rel.keys():
		var pos_du: Vector2 = active_bones_rel[b_name] as Vector2
		var ps: Vector2 = rig_to_screen(pos_du)
		if not canvas_r.has_point(ps):
			continue
		var is_sel: bool = (selected_kind == "bone" and selected_name == b_name)
		var col := Color(1.0, 0.92, 0.20, 1.0) if is_sel else Color(0.95, 0.65, 0.25, 0.90)
		draw_circle(ps, 5.0 if is_sel else 3.2, col)
		draw_arc(ps, 5.0 if is_sel else 3.2, 0.0, TAU, 14, Color(0.08, 0.08, 0.12, 0.9), 1.0)
		if is_sel and font != null:
			draw_string(font, ps + Vector2(8.0, 3.0), "%s (%.1f, %.1f)" % [b_name, pos_du.x, pos_du.y], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, col)


func _draw_rulers(font: Font, px_per_du: float) -> void:
	var bg_col := Color(0.11, 0.12, 0.16, 0.94)
	var border_col := Color(0.28, 0.34, 0.45, 0.95)
	var tick_col := Color(0.75, 0.82, 0.92, 0.78)
	var sub_tick_col := Color(0.50, 0.56, 0.68, 0.45)

	var top_r := Rect2(work_rect.position.x + RULER_SIZE, work_rect.position.y, work_rect.size.x - RULER_SIZE, RULER_SIZE)
	var left_r := Rect2(work_rect.position.x, work_rect.position.y + RULER_SIZE, RULER_SIZE, work_rect.size.y - RULER_SIZE)
	var corner_r := Rect2(work_rect.position.x, work_rect.position.y, RULER_SIZE, RULER_SIZE)

	draw_rect(top_r, bg_col, true)
	draw_rect(left_r, bg_col, true)
	draw_rect(corner_r, Color(0.08, 0.09, 0.12, 0.98), true)
	draw_rect(top_r, border_col, false, 1.0)
	draw_rect(left_r, border_col, false, 1.0)
	draw_rect(corner_r, border_col, false, 1.0)

	if font != null:
		draw_string(font, corner_r.position + Vector2(4.0, 16.0), "du", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.65, 0.88, 1.0, 0.95))

	var step_du: float = _pick_ruler_step(px_per_du)
	var sub_divs: int = 5 if step_du >= 5.0 else 2

	var x_min_du: float = screen_to_rig(Vector2(top_r.position.x, 0.0)).x
	var x_max_du: float = screen_to_rig(Vector2(top_r.end.x, 0.0)).x
	var ix0: int = int(floor(x_min_du / step_du))
	var ix1: int = int(ceil(x_max_du / step_du))
	for ix: int in range(ix0, ix1 + 1):
		var val_du: float = float(ix) * step_du
		var sx: float = rig_to_screen(Vector2(val_du, 0.0)).x
		if sx >= top_r.position.x and sx <= top_r.end.x:
			draw_line(Vector2(sx, top_r.end.y - 9.0), Vector2(sx, top_r.end.y), tick_col, 1.0)
			if font != null:
				draw_string(font, Vector2(sx + 2.0, top_r.position.y + 11.0), "%d" % int(round(val_du)), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, tick_col)
		for s: int in range(1, sub_divs):
			var sub_du: float = val_du + step_du * (float(s) / float(sub_divs))
			var ssx: float = rig_to_screen(Vector2(sub_du, 0.0)).x
			if ssx >= top_r.position.x and ssx <= top_r.end.x:
				draw_line(Vector2(ssx, top_r.end.y - 4.0), Vector2(ssx, top_r.end.y), sub_tick_col, 1.0)

	var y_min_du: float = screen_to_rig(Vector2(0.0, left_r.position.y)).y
	var y_max_du: float = screen_to_rig(Vector2(0.0, left_r.end.y)).y
	var iy0: int = int(floor(y_min_du / step_du))
	var iy1: int = int(ceil(y_max_du / step_du))
	for iy: int in range(iy0, iy1 + 1):
		var val_y_du: float = float(iy) * step_du
		var sy: float = rig_to_screen(Vector2(0.0, val_y_du)).y
		if sy >= left_r.position.y and sy <= left_r.end.y:
			draw_line(Vector2(left_r.end.x - 9.0, sy), Vector2(left_r.end.x, sy), tick_col, 1.0)
			if font != null:
				draw_string(font, Vector2(left_r.position.x + 2.0, sy + 9.0), "%d" % int(round(val_y_du)), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, tick_col)
		for s: int in range(1, sub_divs):
			var sub_y_du: float = val_y_du + step_du * (float(s) / float(sub_divs))
			var ssy: float = rig_to_screen(Vector2(0.0, sub_y_du)).y
			if ssy >= left_r.position.y and ssy <= left_r.end.y:
				draw_line(Vector2(left_r.end.x - 4.0, ssy), Vector2(left_r.end.x, ssy), sub_tick_col, 1.0)

	if cursor_inside_work:
		var c_scr: Vector2 = rig_to_screen(cursor_rig_du)
		if c_scr.x >= top_r.position.x and c_scr.x <= top_r.end.x:
			draw_line(Vector2(c_scr.x, top_r.position.y), Vector2(c_scr.x, top_r.end.y), Color(1.0, 0.35, 0.45, 0.95), 1.5)
		if c_scr.y >= left_r.position.y and c_scr.y <= left_r.end.y:
			draw_line(Vector2(left_r.position.x, c_scr.y), Vector2(left_r.end.x, c_scr.y), Color(1.0, 0.35, 0.45, 0.95), 1.5)


static func _pick_ruler_step(px_per_du: float) -> float:
	var candidates: Array[float] = [1.0, 2.0, 5.0, 10.0, 20.0, 25.0, 50.0, 100.0]
	for step_val: float in candidates:
		if step_val * px_per_du >= 34.0:
			return step_val
	return 100.0

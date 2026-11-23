class_name WorkbenchAlignmentOverlay
extends Control
## Overlay visual de alineación, grilla, bounds de UI, cotas de distancia y anillos radiales 2D.
## Diseñado para verificar equidistancia entre HUD, barra de vida diegética y anillo orbital.

var show_guides: bool = false:
	set(val):
		show_guides = val
		visible = val
		queue_redraw()

var show_grid: bool = true:
	set(val):
		show_grid = val
		queue_redraw()

var show_safe_margins: bool = true:
	set(val):
		show_safe_margins = val
		queue_redraw()

var show_control_boxes: bool = true:
	set(val):
		show_control_boxes = val
		queue_redraw()

var show_world_rings: bool = true:
	set(val):
		show_world_rings = val
		queue_redraw()

var grid_step_px: float = 64.0

var _controls: Array[Dictionary] = []
var _gap_pairs: Array[Dictionary] = []
var _world_target: Node2D = null
var _world_rings: Array[Dictionary] = []


static func attach_to(parent: Node, layer_index: int = 75) -> Control:
	var layer := CanvasLayer.new()
	layer.name = "WorkbenchAlignmentLayer"
	layer.layer = layer_index
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(layer)

	var self_script: GDScript = load("res://sandbox/workbenches/shared/workbench_alignment_overlay.gd") as GDScript
	var overlay: Control = self_script.new() as Control
	overlay.name = "AlignmentOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.visible = false
	layer.add_child(overlay)
	return overlay


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	if show_guides:
		queue_redraw()


func register_control(label: String, ctrl: Control) -> void:
	if ctrl == null:
		return
	_controls.append({"label": label, "ctrl": ctrl})


func register_gap_pair(label: String, a: Control, b: Control) -> void:
	if a == null or b == null:
		return
	_gap_pairs.append({"label": label, "a": a, "b": b})


func clear_targets() -> void:
	_controls.clear()
	_gap_pairs.clear()
	_world_rings.clear()
	_world_target = null
	queue_redraw()


func set_world_target(node: Node2D) -> void:
	_world_target = node


func set_world_rings(rings: Array[Dictionary]) -> void:
	_world_rings = rings.duplicate(true)
	if show_guides:
		queue_redraw()


func _draw() -> void:
	if not show_guides:
		return
	var vp_rect: Rect2 = get_viewport_rect()
	var size_px: Vector2 = vp_rect.size
	if size_px.x <= 1.0 or size_px.y <= 1.0:
		return
	var font: Font = ThemeDB.fallback_font

	if show_grid:
		_draw_grid(size_px)
	if show_safe_margins:
		_draw_safe_margins(size_px, font)
	if show_control_boxes:
		_draw_control_boxes(font)
		_draw_gap_pairs(font)
	if show_world_rings and is_instance_valid(_world_target):
		_draw_world_rings(font)


func _draw_grid(size_px: Vector2) -> void:
	var step: float = maxf(16.0, grid_step_px)
	var grid_col := Color(0.35, 0.85, 1.0, 0.08)
	var x: float = step
	while x < size_px.x:
		draw_line(Vector2(x, 0.0), Vector2(x, size_px.y), grid_col, 1.0)
		x += step
	var y: float = step
	while y < size_px.y:
		draw_line(Vector2(0.0, y), Vector2(size_px.x, y), grid_col, 1.0)
		y += step

	var center: Vector2 = size_px * 0.5
	var axis_col := Color(0.2, 0.95, 1.0, 0.35)
	draw_line(Vector2(center.x, 0.0), Vector2(center.x, size_px.y), axis_col, 1.5)
	draw_line(Vector2(0.0, center.y), Vector2(size_px.x, center.y), axis_col, 1.5)


func _draw_safe_margins(size_px: Vector2, font: Font) -> void:
	var margin_outer := Rect2(Vector2(24.0, 16.0), size_px - Vector2(48.0, 32.0))
	draw_rect(margin_outer, Color(1.0, 0.82, 0.2, 0.35), false, 1.5)
	if font != null:
		draw_string(
			font,
			Vector2(28.0, 32.0),
			"%dx%d | Margen HUD (24,16)" % [int(size_px.x), int(size_px.y)],
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			12,
			Color(1.0, 0.85, 0.35, 0.85)
		)


func _draw_control_boxes(font: Font) -> void:
	var box_col := Color(0.25, 1.0, 0.65, 0.72)
	for item: Dictionary in _controls:
		var ctrl: Control = item.get("ctrl") as Control
		if not is_instance_valid(ctrl) or not ctrl.is_visible_in_tree():
			continue
		var rect: Rect2 = ctrl.get_global_rect()
		draw_rect(rect, box_col, false, 1.5)
		var center: Vector2 = rect.get_center()
		draw_line(center + Vector2(-5.0, 0.0), center + Vector2(5.0, 0.0), box_col, 1.5)
		draw_line(center + Vector2(0.0, -5.0), center + Vector2(0.0, 5.0), box_col, 1.5)
		if font != null:
			var tag: String = "%s [%dx%d]" % [str(item.get("label", ctrl.name)), int(roundf(rect.size.x)), int(roundf(rect.size.y))]
			draw_string(font, rect.position + Vector2(2.0, -4.0), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, box_col)


func _draw_gap_pairs(font: Font) -> void:
	var gap_col := Color(1.0, 0.42, 0.65, 0.92)
	for pair: Dictionary in _gap_pairs:
		var a: Control = pair.get("a") as Control
		var b: Control = pair.get("b") as Control
		if not is_instance_valid(a) or not is_instance_valid(b):
			continue
		if not a.is_visible_in_tree() or not b.is_visible_in_tree():
			continue
		var ra: Rect2 = a.get_global_rect()
		var rb: Rect2 = b.get_global_rect()

		var p1 := Vector2(ra.get_center().x, ra.end.y)
		var p2 := Vector2(rb.get_center().x, rb.position.y)
		var gap_px: float = rb.position.y - ra.end.y
		if absf(gap_px) < 1.0 and absf(rb.position.x - ra.end.x) > absf(gap_px):
			p1 = Vector2(ra.end.x, ra.get_center().y)
			p2 = Vector2(rb.position.x, rb.get_center().y)
			gap_px = rb.position.x - ra.end.x

		draw_line(p1, p2, gap_col, 2.0)
		draw_circle(p1, 3.0, gap_col)
		draw_circle(p2, 3.0, gap_col)
		if font != null:
			var mid: Vector2 = (p1 + p2) * 0.5 + Vector2(8.0, 4.0)
			draw_string(
				font,
				mid,
				"%s: %.1fpx" % [str(pair.get("label", "Gap")), gap_px],
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				11,
				gap_col
			)


func _draw_world_rings(font: Font) -> void:
	var vp: Viewport = get_viewport()
	if vp == null:
		return
	var canvas_xf: Transform2D = vp.get_canvas_transform()
	var screen_center: Vector2 = canvas_xf * _world_target.global_position
	var zoom_scale: Vector2 = Vector2(canvas_xf.x.length(), canvas_xf.y.length())

	draw_circle(screen_center, 4.0, Color(1.0, 0.95, 0.3, 0.9))
	for i: int in range(_world_rings.size()):
		var ring: Dictionary = _world_rings[i]
		var rx: float = float(ring.get("radius_x", 0.0)) * zoom_scale.x
		var ry: float = float(ring.get("radius_y", rx)) * zoom_scale.y
		if rx <= 1.0 or ry <= 1.0:
			continue
		var ring_offset: Vector2 = ring.get("offset", Vector2.ZERO) as Vector2
		var ring_center: Vector2 = screen_center + Vector2(ring_offset.x * zoom_scale.x, ring_offset.y * zoom_scale.y)
		var col: Color = ring.get("color", Color(0.2, 0.95, 1.0, 0.85))
		var pts := PackedVector2Array()
		var segs: int = 72
		for s: int in range(segs + 1):
			var ang: float = TAU * float(s) / float(segs)
			pts.append(ring_center + Vector2(cos(ang) * rx, sin(ang) * ry))
		draw_polyline(pts, col, 1.75, true)
		if font != null:
			var lbl: String = "%s (rx=%.1f ry=%.1f)" % [
				str(ring.get("label", "Ring")),
				float(ring.get("radius_x", 0.0)),
				float(ring.get("radius_y", 0.0)),
			]
			draw_string(
				font,
				ring_center + Vector2(rx + 8.0, -18.0 + float(i) * 18.0),
				lbl,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				11,
				col
			)

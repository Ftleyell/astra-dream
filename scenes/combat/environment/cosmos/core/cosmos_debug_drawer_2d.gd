class_name CosmosDebugCanvasDrawer2D
extends Node2D

## Visual Debugger 2D para Cosmos Engine.
## Renderiza gizmos vectoriales analíticos para macro-grid, frustum de cámara,
## radios de delimitación galáctica, sistemas keplerianos y origen flotante.

@export var enabled: bool = false
@export var cosmos_root: CosmosRootNode
@export var camera: Camera2D

@export_group("Filtros de Gizmos")
@export var draw_camera_frustum: bool = true
@export var draw_macro_grid: bool = true
@export var draw_galaxy_bounds: bool = true
@export var draw_solar_bounds: bool = true
@export var draw_floating_origin: bool = true

var _default_font: Font = null

func _ready() -> void:
	z_index = 100
	_default_font = ThemeDB.fallback_font

func _process(_delta: float) -> void:
	if enabled:
		queue_redraw()

## Alterna la activación de los gizmos en vivo
func toggle_debug_draw() -> bool:
	set_debug_enabled(not enabled)
	return enabled

func set_debug_enabled(p_enabled: bool) -> void:
	enabled = p_enabled
	queue_redraw()

func _draw() -> void:
	if not enabled or camera == null or cosmos_root == null:
		return

	var vp_rect: Rect2 = get_viewport_rect()
	var vp_size: Vector2 = vp_rect.size if vp_rect.size != Vector2.ZERO else Vector2(1920.0, 1080.0)
	var cam_zoom: Vector2 = camera.zoom if camera.zoom.x > 0.001 else Vector2.ONE
	var half_extents: Vector2 = (vp_size * 0.5) / cam_zoom
	var cam_world_center: Vector2 = camera.get_screen_center_position()
	if cam_world_center == Vector2.ZERO and camera.global_position != Vector2.ZERO:
		cam_world_center = camera.global_position
	var local_cam_center: Vector2 = to_local(cam_world_center)
	var frustum_rect: Rect2 = Rect2(local_cam_center - half_extents, half_extents * 2.0)

	if draw_macro_grid:
		_draw_grid(frustum_rect)

	if draw_camera_frustum:
		_draw_frustum(frustum_rect, cam_zoom)

	if draw_galaxy_bounds:
		_draw_galaxies(cam_world_center)

	if draw_solar_bounds:
		_draw_solar_systems(cam_world_center)

	if draw_floating_origin:
		_draw_origin_marker()

func _draw_frustum(frustum: Rect2, zoom: Vector2) -> void:
	var color: Color = Color(0.1, 1.0, 0.45, 0.85)
	draw_rect(frustum, color, false, 2.0)
	
	# Esquinas decorativas
	var corner_len: float = 24.0 / zoom.x
	# Top-left
	draw_line(frustum.position, frustum.position + Vector2(corner_len, 0), color, 3.0)
	draw_line(frustum.position, frustum.position + Vector2(0, corner_len), color, 3.0)
	# Top-right
	var tr: Vector2 = Vector2(frustum.end.x, frustum.position.y)
	draw_line(tr, tr + Vector2(-corner_len, 0), color, 3.0)
	draw_line(tr, tr + Vector2(0, corner_len), color, 3.0)
	# Bottom-left
	var bl: Vector2 = Vector2(frustum.position.x, frustum.end.y)
	draw_line(bl, bl + Vector2(corner_len, 0), color, 3.0)
	draw_line(bl, bl + Vector2(0, -corner_len), color, 3.0)
	# Bottom-right
	draw_line(frustum.end, frustum.end + Vector2(-corner_len, 0), color, 3.0)
	draw_line(frustum.end, frustum.end + Vector2(0, -corner_len), color, 3.0)

	if _default_font != null:
		var label_pos: Vector2 = frustum.position + Vector2(8.0, 20.0 / zoom.x)
		var text: String = "CAMERA FRUSTUM [%.0fx%.0f] Zoom: %.2fx" % [frustum.size.x, frustum.size.y, zoom.x]
		draw_string(_default_font, label_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, color)

func _draw_grid(frustum: Rect2) -> void:
	var cell_size: float = 16000.0
	if cosmos_root.solar_streamer != null and cosmos_root.solar_streamer.system_profile != null:
		cell_size = cosmos_root.solar_streamer.system_profile.cell_size

	var min_cx: int = int(floor(frustum.position.x / cell_size)) - 1
	var max_cx: int = int(floor(frustum.end.x / cell_size)) + 1
	var min_cy: int = int(floor(frustum.position.y / cell_size)) - 1
	var max_cy: int = int(floor(frustum.end.y / cell_size)) + 1

	var grid_color: Color = Color(0.2, 0.45, 0.85, 0.3)
	var text_color: Color = Color(0.4, 0.7, 1.0, 0.7)

	for cx: int in range(min_cx, max_cx + 1):
		var x_pos: float = float(cx) * cell_size
		draw_line(Vector2(x_pos, float(min_cy) * cell_size), Vector2(x_pos, float(max_cy + 1) * cell_size), grid_color, 1.0)

	for cy: int in range(min_cy, max_cy + 1):
		var y_pos: float = float(cy) * cell_size
		draw_line(Vector2(float(min_cx) * cell_size, y_pos), Vector2(float(max_cx + 1) * cell_size, y_pos), grid_color, 1.0)

	if _default_font != null:
		for cx: int in range(min_cx, max_cx + 1):
			for cy: int in range(min_cy, max_cy + 1):
				var cell_corner: Vector2 = Vector2(float(cx) * cell_size + 15.0, float(cy) * cell_size + 30.0)
				if frustum.has_point(cell_corner):
					var cell_label: String = "Grid Cell [%d, %d]" % [cx, cy]
					draw_string(_default_font, cell_corner, cell_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, text_color)

func _project_parallax_to_local(raw_global_pos: Vector2, parallax_layer: Parallax2D, cam_world_pos: Vector2) -> Vector2:
	if parallax_layer == null:
		return to_local(raw_global_pos)
	var parallax_offset: Vector2 = cam_world_pos * (Vector2.ONE - parallax_layer.scroll_scale) + parallax_layer.scroll_offset
	return to_local(raw_global_pos + parallax_offset)

func _draw_galaxies(cam_world_pos: Vector2) -> void:
	if cosmos_root.galaxy_streamer == null or not is_instance_valid(cosmos_root.galaxy_streamer):
		return

	var streamer: CosmosGalaxyStreamer2D = cosmos_root.galaxy_streamer
	if not streamer.is_galaxy_rendered():
		return

	var active_galaxies: Dictionary = streamer.get_active_galaxies()
	var prof: CosmosGalaxyLandmarkProfile = streamer.landmark_profile
	var bound_r: float = prof.maximum_bounding_radius if prof != null else 2000.0
	var pad: float = prof.safety_padding if prof != null else 400.0

	var yellow_color: Color = Color(1.0, 0.85, 0.2, 0.6)
	var magenta_color: Color = Color(0.95, 0.25, 0.85, 0.35)
	var parallax: Parallax2D = cosmos_root.parallax_macro_galaxies

	for cell: Vector2i in active_galaxies.keys():
		var sprite: Sprite2D = active_galaxies[cell] as Sprite2D
		if sprite == null or not is_instance_valid(sprite) or not sprite.visible:
			continue

		var local_pos: Vector2 = _project_parallax_to_local(sprite.global_position, parallax, cam_world_pos)

		# Radio de delimitación analítico
		draw_arc(local_pos, bound_r, 0.0, TAU, 48, yellow_color, 2.0)
		# Zona de amortiguación (safety padding)
		draw_arc(local_pos, bound_r + pad, 0.0, TAU, 48, magenta_color, 1.5)

		# Cruz en el núcleo
		draw_line(local_pos + Vector2(-30, 0), local_pos + Vector2(30, 0), yellow_color, 2.0)
		draw_line(local_pos + Vector2(0, -30), local_pos + Vector2(0, 30), yellow_color, 2.0)

		if _default_font != null:
			var label: String = "GALAXY SECTOR [%d, %d]\nBounding Radius: %.0f px\nSafety Margin: +%.0f px" % [cell.x, cell.y, bound_r, pad]
			draw_string(_default_font, local_pos + Vector2(35.0, -10.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, yellow_color)

func _draw_solar_systems(cam_world_pos: Vector2) -> void:
	if cosmos_root.solar_streamer == null or not is_instance_valid(cosmos_root.solar_streamer):
		return

	var active_sys: Dictionary = cosmos_root.solar_streamer.get_active_systems()
	var cyan_color: Color = Color(0.15, 0.85, 1.0, 0.65)
	var orbit_color: Color = Color(0.3, 0.9, 0.9, 0.3)
	var parallax: Parallax2D = cosmos_root.parallax_solar_systems

	for cell_coords: Vector2i in active_sys.keys():
		var sys: CosmosSolarSystem2D = active_sys[cell_coords] as CosmosSolarSystem2D
		if sys == null or not is_instance_valid(sys) or not sys.visible:
			continue

		var local_pos: Vector2 = _project_parallax_to_local(sys.global_position, parallax, cam_world_pos)
		var bound_r: float = sys.get_bounding_radius()
		if bound_r <= 0.0:
			bound_r = 6000.0

		draw_arc(local_pos, bound_r, 0.0, TAU, 48, cyan_color, 1.8)

		# Cruz en el sol
		draw_line(local_pos + Vector2(-20, 0), local_pos + Vector2(20, 0), cyan_color, 2.0)
		draw_line(local_pos + Vector2(0, -20), local_pos + Vector2(0, 20), cyan_color, 2.0)

		if _default_font != null:
			var sys_label: String = "SOLAR SYSTEM [%d, %d]\nPlanets: %d | Bound R: %.0f px" % [cell_coords.x, cell_coords.y, sys.planets.size(), bound_r]
			draw_string(_default_font, local_pos + Vector2(25.0, -10.0), sys_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, cyan_color)

func _draw_origin_marker() -> void:
	var origin_local: Vector2 = to_local(cosmos_root.global_position)
	var gold: Color = Color(1.0, 0.8, 0.1, 0.9)
	var cross_len: float = 50.0

	draw_line(origin_local + Vector2(-cross_len, 0), origin_local + Vector2(cross_len, 0), gold, 2.5)
	draw_line(origin_local + Vector2(0, -cross_len), origin_local + Vector2(0, cross_len), gold, 2.5)
	draw_arc(origin_local, 15.0, 0.0, TAU, 24, gold, 1.5)

	if _default_font != null:
		var shifts: int = cosmos_root.get_origin_shift_count()
		var acc: Vector2 = cosmos_root.get_accumulated_shift()
		var text: String = "FLOATING ORIGIN (0, 0)\nShifts: %d | Accumulated: (%.0f, %.0f)" % [shifts, acc.x, acc.y]
		draw_string(_default_font, origin_local + Vector2(20.0, 30.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, gold)

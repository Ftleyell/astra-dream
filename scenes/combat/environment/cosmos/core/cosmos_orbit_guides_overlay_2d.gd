class_name CosmosOrbitGuidesOverlay2D
extends Node2D

## Overlay modular de diagnóstico visual para auditar las elipses 3D, inclinaciones,
## cruces frontales/traseros (depth_z) y zonas de exclusión en Cosmos Engine.
## Permanece invisible y con coste nulo en producción salvo activación explícita (p. ej. Lab [O]).

var _system: CosmosSolarSystem2D = null
var _star_exclusion_radius: float = 0.0

var _pts_64: PackedVector2Array = PackedVector2Array()
var _cols_64: PackedColorArray = PackedColorArray()
var _pts_40: PackedVector2Array = PackedVector2Array()
var _cols_40: PackedColorArray = PackedColorArray()
var _pts_36: PackedVector2Array = PackedVector2Array()
var _cols_36: PackedColorArray = PackedColorArray()

func _init() -> void:
	name = "CosmosOrbitGuidesOverlay2D"
	visible = false
	z_index = 1
	_pts_64.resize(65)
	_cols_64.resize(65)
	_pts_40.resize(41)
	_cols_40.resize(41)
	_pts_36.resize(37)
	_cols_36.resize(37)

func setup(p_system: CosmosSolarSystem2D, p_star_exclusion_radius: float) -> void:
	_system = p_system
	_star_exclusion_radius = maxf(p_star_exclusion_radius, 0.0)
	if visible:
		queue_redraw()

func refresh_if_visible() -> void:
	if visible:
		queue_redraw()

func _draw() -> void:
	if not visible or _system == null or not is_instance_valid(_system):
		return

	var inv_zoom: float = 1.0
	if is_inside_tree() and get_viewport() != null:
		var cam: Camera2D = get_viewport().get_camera_2d()
		if cam != null and cam.zoom.x > 0.001:
			inv_zoom = clampf(1.0 / cam.zoom.x, 0.75, 5.5)

	var w_major: float = 1.8 * inv_zoom
	var w_minor: float = 1.45 * inv_zoom
	var w_env: float = 1.15 * inv_zoom

	# 1. Radio de exclusión solar
	if _star_exclusion_radius > 1.0:
		draw_arc(Vector2.ZERO, _star_exclusion_radius, 0.0, TAU, 64, Color(1.0, 0.35, 0.35, 0.62), w_major)

	# 2. Planetas primarios, envolvente visual + lunas, estaciones y pastoras
	var col_planet_front: Color = Color(0.68, 0.90, 1.0, 0.56)
	var col_planet_back: Color = Color(0.45, 0.68, 0.95, 0.22)
	var col_env: Color = Color(0.35, 0.85, 0.78, 0.30)
	var col_moon_front: Color = Color(0.86, 0.66, 1.0, 0.76)
	var col_moon_back: Color = Color(0.64, 0.45, 0.85, 0.26)
	var col_station_front: Color = Color(0.24, 0.96, 1.0, 0.78)
	var col_station_back: Color = Color(0.18, 0.64, 0.82, 0.26)

	for planet_body: CosmosOrbitalBody2D in _system.planets:
		if not is_instance_valid(planet_body):
			continue
		if planet_body.orbit_radius > 1.0:
			_draw_ellipse_3d(
				Vector2.ZERO,
				Vector2.ONE,
				planet_body.orbit_radius,
				planet_body.orbit_eccentricity,
				planet_body.orbit_periapsis_angle,
				planet_body.orbit_plane_tilt,
				planet_body.orbit_plane_squash,
				col_planet_front,
				col_planet_back,
				w_major,
				64,
				_pts_64,
				_cols_64,
				true,
				inv_zoom
			)

		var p_vis_r: float = float(planet_body.get_meta(&"visual_radius", 120.0))
		var p_ring_r: float = float(planet_body.get_meta(&"ring_outer_radius", 0.0))
		var env_r: float = maxf(p_vis_r, p_ring_r) * planet_body.scale.x
		if env_r > 1.0:
			draw_arc(planet_body.position, env_r, 0.0, TAU, 40, col_env, w_env)

		for sub_body: CosmosOrbitalBody2D in planet_body.get_orbital_children():
			if not is_instance_valid(sub_body) or sub_body.orbit_radius <= 1.0:
				continue
			var is_moon: bool = bool(sub_body.get_meta(&"is_moon", false))
			_draw_ellipse_3d(
				planet_body.position,
				planet_body.scale,
				sub_body.orbit_radius,
				sub_body.orbit_eccentricity,
				sub_body.orbit_periapsis_angle,
				sub_body.orbit_plane_tilt,
				sub_body.orbit_plane_squash,
				col_moon_front if is_moon else col_station_front,
				col_moon_back if is_moon else col_station_back,
				w_minor,
				40,
				_pts_40,
				_cols_40,
				false,
				inv_zoom
			)

	# 3. Slot destructible reservado (ámbar)
	if _system.destructible_orbit_radius > 1.0:
		_draw_ellipse_3d(
			Vector2.ZERO,
			Vector2.ONE,
			_system.destructible_orbit_radius,
			_system.destructible_eccentricity,
			_system.destructible_periapsis_angle,
			_system.destructible_plane_tilt,
			_system.destructible_plane_squash,
			Color(1.0, 0.78, 0.28, 0.56),
			Color(0.85, 0.56, 0.18, 0.20),
			w_major,
			64,
			_pts_64,
			_cols_64,
			true,
			inv_zoom
		)

	# 4. Cometas elípticos (menta)
	var col_comet_front: Color = Color(0.42, 1.0, 0.78, 0.54)
	var col_comet_back: Color = Color(0.28, 0.75, 0.58, 0.18)
	for entry: Dictionary in _system.get_comet_entries():
		var a_c: float = float(entry.get("a", 0.0))
		if a_c <= 1.0:
			continue
		_draw_ellipse_3d(
			Vector2.ZERO,
			Vector2.ONE,
			a_c,
			float(entry.get("ecc", 0.0)),
			float(entry.get("peri", 0.0)),
			float(entry.get("tilt", 0.0)),
			float(entry.get("squash", 1.0)),
			col_comet_front,
			col_comet_back,
			w_minor,
			64,
			_pts_64,
			_cols_64,
			true,
			inv_zoom
		)

	# 5. Lunas pastoras en plano del anillo (blanco hielo)
	var col_shep_front: Color = Color(0.88, 0.96, 1.0, 0.48)
	var col_shep_back: Color = Color(0.70, 0.84, 0.96, 0.16)
	for entry: Dictionary in _system.get_shepherd_entries():
		var host: CosmosOrbitalBody2D = entry.get("host", null) as CosmosOrbitalBody2D
		var a_s: float = float(entry.get("a", 0.0))
		if not is_instance_valid(host) or a_s <= 1.0:
			continue
		_draw_ellipse_3d(
			host.position,
			host.scale,
			a_s,
			float(entry.get("ecc", 0.0)),
			float(entry.get("peri", 0.0)),
			float(entry.get("tilt", 0.0)),
			float(entry.get("squash", 1.0)),
			col_shep_front,
			col_shep_back,
			w_env,
			36,
			_pts_36,
			_cols_36,
			false,
			inv_zoom
		)

func _draw_ellipse_3d(
	origin: Vector2,
	parent_scale: Vector2,
	semi_major_axis: float,
	eccentricity: float,
	periapsis_angle: float,
	plane_tilt: float,
	plane_squash: float,
	front_col: Color,
	back_col: Color,
	line_w: float,
	seg_count: int,
	pts_buf: PackedVector2Array,
	cols_buf: PackedColorArray,
	draw_periapsis_tick: bool,
	inv_zoom: float
) -> void:
	draw_ellipse_3d_on(
		self,
		origin,
		parent_scale,
		semi_major_axis,
		eccentricity,
		periapsis_angle,
		plane_tilt,
		plane_squash,
		front_col,
		back_col,
		line_w,
		seg_count,
		pts_buf,
		cols_buf,
		draw_periapsis_tick,
		inv_zoom
	)

static func draw_ellipse_3d_on(
	canvas: CanvasItem,
	origin: Vector2,
	parent_scale: Vector2,
	semi_major_axis: float,
	eccentricity: float,
	periapsis_angle: float,
	plane_tilt: float,
	plane_squash: float,
	front_col: Color,
	back_col: Color,
	line_w: float,
	seg_count: int,
	pts_buf: PackedVector2Array,
	cols_buf: PackedColorArray,
	draw_periapsis_tick: bool,
	inv_zoom: float
) -> void:
	var inv_seg: float = TAU / float(seg_count)
	for i: int in range(seg_count + 1):
		var phase_i: float = float(i) * inv_seg
		var st: Vector3 = CosmosKeplerOrbitMath.calculate_orbit_state_3d(
			semi_major_axis,
			phase_i,
			0.0,
			0.0,
			eccentricity,
			periapsis_angle,
			plane_tilt,
			plane_squash
		)
		pts_buf[i] = origin + Vector2(st.x * parent_scale.x, st.y * parent_scale.y)
		var front_mix: float = smoothstep(-0.08, 0.08, st.z)
		cols_buf[i] = back_col.lerp(front_col, front_mix)

	canvas.draw_polyline_colors(pts_buf, cols_buf, line_w, true)

	if draw_periapsis_tick and eccentricity > 0.01:
		var pe_pt: Vector2 = pts_buf[0]
		canvas.draw_circle(pe_pt, 3.2 * inv_zoom, front_col)

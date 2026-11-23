class_name CosmosOrbitalTrail2D
extends Node2D

## CosmosOrbitalTrail2D.gd
## Renderiza una estela luminosa 2.5D/3D puramente analítica detrás de un cuerpo orbital.
## Pre-aloca buffers geométricos en setup_orbit() para garantizar cero allocaciones por frame
## y separa limpiamente pases trasero (z_index = -1) y delantero (z_index = +1) respecto al anfitrión.

class _TrailPassDrawer extends Node2D:
	var indices: PackedInt32Array = PackedInt32Array()
	var verts: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()
	var uvs: PackedVector2Array = PackedVector2Array()
	var active_count: int = 0

	func _draw() -> void:
		if active_count < 3 or indices.size() != verts.size() or verts.is_empty():
			return
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), indices, verts, colors, uvs)

var _semi_major_axis: float = 0.0
var _initial_theta: float = 0.0
var _angular_velocity: float = 0.0
var _eccentricity: float = 0.0
var _periapsis_angle: float = 0.0
var _plane_tilt: float = 0.0
var _plane_squash: float = 1.0

var _sample_count: int = 16
var _arc_radians: float = 1.15
var _head_half_width: float = 2.2
var _head_color: Color = Color(0.75, 0.90, 1.0, 0.30)
var _tail_color: Color = Color(0.38, 0.55, 0.92, 0.0)
var _split_z_passes: bool = true

var _sample_pos: PackedVector2Array = PackedVector2Array()
var _sample_z: PackedFloat32Array = PackedFloat32Array()
var _back_drawer: _TrailPassDrawer = null
var _front_drawer: _TrailPassDrawer = null

static var _additive_mat: CanvasItemMaterial = null

static func _get_additive_material() -> CanvasItemMaterial:
	if _additive_mat == null:
		_additive_mat = CanvasItemMaterial.new()
		_additive_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _additive_mat

func _ready() -> void:
	_ensure_drawers()

func _ensure_drawers() -> void:
	var add_mat: CanvasItemMaterial = _get_additive_material()
	if _back_drawer == null:
		_back_drawer = _TrailPassDrawer.new()
		_back_drawer.name = "TrailBackPass"
		_back_drawer.z_index = -1
		_back_drawer.material = add_mat
		add_child(_back_drawer)
	if _front_drawer == null:
		_front_drawer = _TrailPassDrawer.new()
		_front_drawer.name = "TrailFrontPass"
		_front_drawer.z_index = 1
		_front_drawer.material = add_mat
		add_child(_front_drawer)

func configure_from_body(
	body: CosmosOrbitalBody2D,
	p_arc_radians: float,
	p_head_width: float,
	p_head_color: Color,
	p_tail_color: Color,
	p_sample_count: int = 16,
	p_split_z_passes: bool = true
) -> void:
	if body == null:
		return
	setup_orbit(
		body.orbit_radius,
		body.initial_theta,
		body.angular_velocity,
		body.orbit_eccentricity,
		body.orbit_periapsis_angle,
		body.orbit_plane_tilt,
		body.orbit_plane_squash,
		p_arc_radians,
		p_head_width,
		p_head_color,
		p_tail_color,
		p_sample_count,
		p_split_z_passes
	)

func setup_orbit(
	p_semi_major_axis: float,
	p_initial_theta: float,
	p_angular_velocity: float,
	p_eccentricity: float,
	p_periapsis_angle: float,
	p_plane_tilt: float,
	p_plane_squash: float,
	p_arc_radians: float,
	p_head_width: float,
	p_head_color: Color,
	p_tail_color: Color,
	p_sample_count: int = 16,
	p_split_z_passes: bool = true
) -> void:
	_ensure_drawers()
	_semi_major_axis = p_semi_major_axis
	_initial_theta = p_initial_theta
	_angular_velocity = p_angular_velocity
	_eccentricity = p_eccentricity
	_periapsis_angle = p_periapsis_angle
	_plane_tilt = p_plane_tilt
	_plane_squash = p_plane_squash
	_arc_radians = maxf(p_arc_radians, 0.15)
	_head_half_width = maxf(p_head_width * 0.5, 0.4)
	_head_color = p_head_color
	_tail_color = p_tail_color
	_sample_count = clampi(p_sample_count, 6, 36)
	_split_z_passes = p_split_z_passes

	_sample_pos.resize(_sample_count)
	_sample_z.resize(_sample_count)

	var v_count: int = (_sample_count - 1) * 6
	_back_drawer.indices.resize(v_count)
	_back_drawer.verts.resize(v_count)
	_back_drawer.colors.resize(v_count)
	_back_drawer.uvs.resize(v_count)
	_front_drawer.indices.resize(v_count)
	_front_drawer.verts.resize(v_count)
	_front_drawer.colors.resize(v_count)
	_front_drawer.uvs.resize(v_count)
	for i: int in range(v_count):
		_back_drawer.indices[i] = i
		_front_drawer.indices[i] = i
		_back_drawer.uvs[i] = Vector2.ZERO
		_front_drawer.uvs[i] = Vector2.ZERO
	_back_drawer.visible = _split_z_passes

func update_trail(global_time: float) -> void:
	if not visible or _semi_major_axis <= 1.0 or absf(_angular_velocity) <= 0.000001:
		return
	if _back_drawer == null or _front_drawer == null:
		return

	var time_span: float = _arc_radians / absf(_angular_velocity)
	var inv_seg: float = 1.0 / float(_sample_count - 1)

	for i: int in range(_sample_count):
		var frac: float = float(i) * inv_seg
		var t_sample: float = global_time - (frac * time_span)
		var state: Vector3 = CosmosKeplerOrbitMath.calculate_orbit_state_3d(
			_semi_major_axis,
			_initial_theta,
			_angular_velocity,
			t_sample,
			_eccentricity,
			_periapsis_angle,
			_plane_tilt,
			_plane_squash
		)
		_sample_pos[i] = Vector2(state.x, state.y)
		_sample_z[i] = state.z

	var b_idx: int = 0
	var f_idx: int = 0
	var prev_n: Vector2 = Vector2.UP
	var dir0: Vector2 = _sample_pos[0] - _sample_pos[1]
	if dir0.length_squared() > 0.0001:
		prev_n = Vector2(-dir0.y, dir0.x).normalized()
	var w_head: float = _head_half_width * clampf(1.0 + _sample_z[0] * 0.25, 0.55, 1.30)
	var prev_l: Vector2 = _sample_pos[0] + (prev_n * w_head)
	var prev_r: Vector2 = _sample_pos[0] - (prev_n * w_head)

	for i: int in range(_sample_count - 1):
		var p1: Vector2 = _sample_pos[i + 1]
		var z0: float = _sample_z[i]
		var z1: float = _sample_z[i + 1]

		var f0: float = float(i) * inv_seg
		var f1: float = float(i + 1) * inv_seg

		var n1: Vector2 = prev_n
		if i + 2 < _sample_count:
			var tan_vec: Vector2 = _sample_pos[i] - _sample_pos[i + 2]
			if tan_vec.length_squared() > 0.0001:
				n1 = Vector2(-tan_vec.y, tan_vec.x).normalized()
		else:
			var tail_vec: Vector2 = _sample_pos[i] - p1
			if tail_vec.length_squared() > 0.0001:
				n1 = Vector2(-tail_vec.y, tail_vec.x).normalized()
		prev_n = n1

		var w1: float = _head_half_width * pow(maxf(1.0 - f1, 0.0), 1.25) * clampf(1.0 + z1 * 0.25, 0.55, 1.30)
		var curr_l: Vector2 = p1 + (n1 * w1)
		var curr_r: Vector2 = p1 - (n1 * w1)

		var a0: float = pow(maxf(1.0 - f0, 0.0), 1.55)
		var a1: float = pow(maxf(1.0 - f1, 0.0), 1.55)
		var col0_base: Color = _head_color.lerp(_tail_color, f0)
		var col1_base: Color = _head_color.lerp(_tail_color, f1)

		var front_w0: float = 1.0
		var front_w1: float = 1.0
		if _split_z_passes:
			front_w0 = smoothstep(-0.07, 0.07, z0)
			front_w1 = smoothstep(-0.07, 0.07, z1)

		var back_w0: float = 1.0 - front_w0
		var back_w1: float = 1.0 - front_w1

		# Pase frontal (z_index = +1)
		if front_w0 > 0.005 or front_w1 > 0.005:
			var cf0: Color = Color(col0_base.r, col0_base.g, col0_base.b, col0_base.a * a0 * front_w0)
			var cf1: Color = Color(col1_base.r, col1_base.g, col1_base.b, col1_base.a * a1 * front_w1)
			f_idx = _write_quad(_front_drawer, f_idx, prev_l, prev_r, curr_r, curr_l, cf0, cf1)

		# Pase trasero (z_index = -1, más frío y tenue detrás del planeta)
		if _split_z_passes and (back_w0 > 0.005 or back_w1 > 0.005):
			var cb0: Color = Color(col0_base.r * 0.78, col0_base.g * 0.85, col0_base.b, col0_base.a * a0 * back_w0 * 0.50)
			var cb1: Color = Color(col1_base.r * 0.78, col1_base.g * 0.85, col1_base.b, col1_base.a * a1 * back_w1 * 0.50)
			b_idx = _write_quad(_back_drawer, b_idx, prev_l, prev_r, curr_r, curr_l, cb0, cb1)

		prev_l = curr_l
		prev_r = curr_r

	# Colapsar cola sobrante de buffers sin asignar memoria nueva en runtime
	var zero_col: Color = Color(0.0, 0.0, 0.0, 0.0)
	var head_anchor: Vector2 = _sample_pos[0]
	_front_drawer.active_count = f_idx
	for k: int in range(f_idx, _front_drawer.verts.size()):
		_front_drawer.verts[k] = head_anchor
		_front_drawer.colors[k] = zero_col
	_front_drawer.queue_redraw()

	if _split_z_passes:
		_back_drawer.active_count = b_idx
		for k: int in range(b_idx, _back_drawer.verts.size()):
			_back_drawer.verts[k] = head_anchor
			_back_drawer.colors[k] = zero_col
		_back_drawer.queue_redraw()

static func _write_quad(
	drawer: _TrailPassDrawer,
	idx: int,
	p0_l: Vector2,
	p0_r: Vector2,
	p1_r: Vector2,
	p1_l: Vector2,
	c0: Color,
	c1: Color
) -> int:
	drawer.verts[idx] = p0_l
	drawer.colors[idx] = c0
	drawer.verts[idx + 1] = p0_r
	drawer.colors[idx + 1] = c0
	drawer.verts[idx + 2] = p1_r
	drawer.colors[idx + 2] = c1

	drawer.verts[idx + 3] = p0_l
	drawer.colors[idx + 3] = c0
	drawer.verts[idx + 4] = p1_r
	drawer.colors[idx + 4] = c1
	drawer.verts[idx + 5] = p1_l
	drawer.colors[idx + 5] = c1
	return idx + 6

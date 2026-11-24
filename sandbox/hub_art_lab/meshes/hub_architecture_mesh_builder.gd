class_name HubArchitectureMeshBuilder
extends RefCounted

## Constructor procedural de la arquitectura en "U" abierta al Sur (+Z) de la Estación Astral v2.
## - Superficies planas (piso, muros laterales) con UV métrico uniforme para hub_arcsys_surface_3d.gdshader.
## - Marcos, costillas estructurales y barandal Sur en contrato ArcSys de 3 superficies.

const Primitives = preload("res://sandbox/hub_art_lab/meshes/hub_arcsys_mesh_primitives.gd")

static var _cached_floor: ArrayMesh = null
static var _cached_wall: ArrayMesh = null
static var _cached_ribs: ArrayMesh = null
static var _cached_north_frame: ArrayMesh = null
static var _cached_south_railing: ArrayMesh = null
static var _cached_ignition_socket: ArrayMesh = null
static var _cached_wing_pads: ArrayMesh = null


static func build_floor_mesh(width: float = 24.0, depth: float = 22.0, tile_meters: float = 6.0) -> ArrayMesh:
	if _cached_floor != null and is_equal_approx(width, 24.0) and is_equal_approx(depth, 22.0) and is_equal_approx(tile_meters, 6.0):
		return _cached_floor

	var hx: float = width * 0.5
	var hz: float = depth * 0.5
	var tm: float = maxf(tile_meters, 0.25)
	var u_half: float = hx / tm
	var v_half: float = hz / tm
	var u_min: float = 0.5 - u_half
	var u_max: float = 0.5 + u_half
	var v_min: float = 0.5 - v_half
	var v_max: float = 0.5 + v_half

	var a := Vector3(-hx, 0.0, -hz)
	var b := Vector3(hx, 0.0, -hz)
	var c := Vector3(hx, 0.0, hz)
	var d := Vector3(-hx, 0.0, hz)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := Vector3.UP

	# Triángulo 1 (a, b, c) -> normal (c - a) x (b - a) = +Y (UV centrado en 0.5 para simetría exacta en X=0)
	st.set_normal(n); st.set_uv(Vector2(u_min, v_min)); st.add_vertex(a)
	st.set_normal(n); st.set_uv(Vector2(u_max, v_min)); st.add_vertex(b)
	st.set_normal(n); st.set_uv(Vector2(u_max, v_max)); st.add_vertex(c)

	# Triángulo 2 (a, c, d) -> normal +Y
	st.set_normal(n); st.set_uv(Vector2(u_min, v_min)); st.add_vertex(a)
	st.set_normal(n); st.set_uv(Vector2(u_max, v_max)); st.add_vertex(c)
	st.set_normal(n); st.set_uv(Vector2(u_min, v_max)); st.add_vertex(d)

	var mesh := st.commit()
	if is_equal_approx(width, 24.0) and is_equal_approx(depth, 22.0) and is_equal_approx(tile_meters, 6.0):
		_cached_floor = mesh
	return mesh


static func build_side_wall_mesh(length: float = 22.0, height: float = 3.8, _tile_meters: float = 4.0) -> ArrayMesh:
	if _cached_wall != null and is_equal_approx(length, 22.0) and is_equal_approx(height, 3.8):
		return _cached_wall

	var hz: float = length * 0.5
	var bay_width: float = height * (16.0 / 9.0)
	var u_max: float = length / maxf(bay_width, 0.25)
	var v_max: float = 1.0

	# Plano mirando hacia +X (se rota PI en Y para el muro Este mirando hacia -X)
	var a := Vector3(0.0, height, -hz)
	var b := Vector3(0.0, height, hz)
	var c := Vector3(0.0, 0.0, hz)
	var d := Vector3(0.0, 0.0, -hz)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := Vector3.RIGHT

	# Winding horario Godot 4 (v2 - v0) x (v1 - v0) = +X hacia el interior de la estación
	st.set_normal(n); st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(a)
	st.set_normal(n); st.set_uv(Vector2(u_max, v_max)); st.add_vertex(c)
	st.set_normal(n); st.set_uv(Vector2(u_max, 0.0)); st.add_vertex(b)

	st.set_normal(n); st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(a)
	st.set_normal(n); st.set_uv(Vector2(0.0, v_max)); st.add_vertex(d)
	st.set_normal(n); st.set_uv(Vector2(u_max, v_max)); st.add_vertex(c)

	var mesh := st.commit()
	if is_equal_approx(length, 22.0) and is_equal_approx(height, 3.8):
		_cached_wall = mesh
	return mesh


static func build_structural_ribs_mesh() -> ArrayMesh:
	if _cached_ribs != null:
		return _cached_ribs

	var armor_tris: Array[Array] = []
	var chassis_tris: Array[Array] = []
	var crystal_tris: Array[Array] = []

	var z_slots: Array[float] = [-7.5, -2.0, 3.5, 9.0]
	for side_sign: float in [-1.0, 1.0]:
		# Zócalo continuo inferior, cornisa superior y bisel parapet limpio (sin Z-fighting coplanar)
		Primitives.add_box(chassis_tris, Vector3(side_sign * 11.75, 0.16, 0.5), Vector3(0.24, 0.16, 10.5))
		Primitives.add_box(armor_tris, Vector3(side_sign * 11.75, 3.70, 0.5), Vector3(0.28, 0.15, 10.5))
		Primitives.add_box(chassis_tris, Vector3(side_sign * 11.77, 3.88, 0.5), Vector3(0.24, 0.04, 10.52))
		Primitives.add_beam_segment(
			crystal_tris,
			Vector3(side_sign * 11.44, 3.62, -9.8),
			Vector3(side_sign * 11.44, 3.62, 10.8),
			0.024,
			0.018
		)

		for z_pos: float in z_slots:
			var x_wall: float = side_sign * 11.78
			var x_in: float = side_sign * 11.34
			var rib_rings: Array[Array] = [
				Primitives.make_box_ring(x_in, 0.30, z_pos, 0.28, 0.24),
				Primitives.make_box_ring(lerpf(x_in, x_wall, 0.48), 1.75, z_pos, 0.24, 0.20),
				Primitives.make_box_ring(x_wall - side_sign * 0.12, 3.58, z_pos, 0.22, 0.18),
			]
			Primitives.add_loft(armor_tris, rib_rings, true, true, Vector3(lerpf(x_in, x_wall, 0.45), 1.95, z_pos))
			Primitives.add_box(chassis_tris, Vector3(x_in - side_sign * 0.08, 0.20, z_pos), Vector3(0.32, 0.20, 0.29))
			Primitives.add_framed_vein(
				crystal_tris,
				chassis_tris,
				Vector3(x_in - side_sign * 0.28, 0.52, z_pos),
				Vector3(x_wall - side_sign * 0.32, 3.35, z_pos),
				0.036,
				0.026
			)

	_cached_ribs = Primitives.build_three_surface_mesh(armor_tris, chassis_tris, crystal_tris, 0.0, 3.92, 1)
	return _cached_ribs


static func build_north_window_frame_mesh() -> ArrayMesh:
	if _cached_north_frame != null:
		return _cached_north_frame

	var armor_tris: Array[Array] = []
	var chassis_tris: Array[Array] = []
	var crystal_tris: Array[Array] = []

	# Pilones laterales biselados más estilizados + cartelas diagonales en esquinas superiores
	for side_sign: float in [-1.0, 1.0]:
		var x_bot: float = side_sign * 10.45
		var x_top: float = side_sign * 9.85
		var pylon_rings: Array[Array] = [
			Primitives.make_box_ring(x_bot, 0.0, -10.15, 0.55, 0.56),
			Primitives.make_box_ring(lerpf(x_bot, x_top, 0.5), 4.0, -10.22, 0.48, 0.50),
			Primitives.make_box_ring(x_top, 8.15, -10.28, 0.44, 0.46),
		]
		Primitives.add_loft(armor_tris, pylon_rings, true, true, Vector3(x_bot, 4.0, -10.22))
		Primitives.add_box(chassis_tris, Vector3(x_bot, 0.32, -10.15), Vector3(0.68, 0.32, 0.66))
		Primitives.add_framed_vein(
			crystal_tris,
			chassis_tris,
			Vector3(x_bot - side_sign * 0.36, 0.72, -9.62),
			Vector3(x_top - side_sign * 0.34, 7.45, -9.78),
			0.052,
			0.034
		)

		# Cartela / diagonal de puente de mando en esquina superior del ventanal
		var gusset_rings: Array[Array] = [
			Primitives.make_box_ring(side_sign * 9.65, 5.65, -10.18, 0.32, 0.32),
			Primitives.make_box_ring(side_sign * 7.25, 7.80, -10.24, 0.36, 0.32),
		]
		Primitives.add_loft(chassis_tris, gusset_rings, true, true, Vector3(side_sign * 8.45, 6.72, -10.20))
		Primitives.add_framed_vein(
			crystal_tris,
			chassis_tris,
			Vector3(side_sign * 9.25, 5.88, -9.84),
			Vector3(side_sign * 7.42, 7.56, -9.88),
			0.038,
			0.028
		)

	# Dintel superior elegante (y = 7.75..8.30) y antepecho panorámico bajo (y = 0.0..0.48)
	Primitives.add_box(armor_tris, Vector3(0.0, 8.05, -10.28), Vector3(10.35, 0.25, 0.46))
	Primitives.add_box(chassis_tris, Vector3(0.0, 7.78, -10.24), Vector3(9.6, 0.10, 0.40))
	Primitives.add_framed_vein(crystal_tris, chassis_tris, Vector3(-9.0, 7.98, -9.78), Vector3(9.0, 7.98, -9.78), 0.044, 0.030)

	Primitives.add_box(chassis_tris, Vector3(0.0, 0.22, -10.25), Vector3(10.1, 0.22, 0.40))
	Primitives.add_box(armor_tris, Vector3(0.0, 0.43, -10.22), Vector3(9.8, 0.05, 0.34))
	Primitives.add_framed_vein(crystal_tris, chassis_tris, Vector3(-9.3, 0.49, -9.88), Vector3(9.3, 0.49, -9.88), 0.040, 0.026)

	_cached_north_frame = Primitives.build_three_surface_mesh(armor_tris, chassis_tris, crystal_tris, 0.0, 8.35, 1)
	return _cached_north_frame


static func build_south_railing_mesh() -> ArrayMesh:
	if _cached_south_railing != null:
		return _cached_south_railing

	var armor_tris: Array[Array] = []
	var chassis_tris: Array[Array] = []
	var crystal_tris: Array[Array] = []

	var z_rail: float = 11.2
	# Postes biselados bajos (altura <= 0.55 m para cero oclusión de cámara -42°)
	for x_post: float in [-10.8, -5.4, 0.0, 5.4, 10.8]:
		Primitives.add_beveled_slab(chassis_tris, Vector3(x_post, 0.14, z_rail), 0.24, 0.20, 0.28, 0.05, 6)
		Primitives.add_beveled_slab(armor_tris, Vector3(x_post, 0.39, z_rail), 0.16, 0.14, 0.18, 0.04, 6)

	# Doble riel delgado: barra chasis inferior + barra cristalina superior
	Primitives.add_box(chassis_tris, Vector3(0.0, 0.06, z_rail), Vector3(11.5, 0.06, 0.22))
	Primitives.add_box(chassis_tris, Vector3(0.0, 0.27, z_rail), Vector3(11.1, 0.032, 0.055))
	Primitives.add_framed_vein(crystal_tris, chassis_tris, Vector3(-11.2, 0.49, z_rail), Vector3(11.2, 0.49, z_rail), 0.036, 0.026)

	_cached_south_railing = Primitives.build_three_surface_mesh(armor_tris, chassis_tris, crystal_tris, 0.0, 0.55, 1)
	return _cached_south_railing


static func build_ignition_pad_socket_mesh() -> ArrayMesh:
	if _cached_ignition_socket != null:
		return _cached_ignition_socket

	var armor_tris: Array[Array] = []
	var chassis_tris: Array[Array] = []
	var crystal_tris: Array[Array] = []

	# Zócalo octogonal empotrado en obsidiana abisal oscura (contraste máximo bajo el anillo)
	Primitives.add_beveled_slab(chassis_tris, Vector3(0.0, 0.0225, 0.0), 2.38, 2.38, 0.045, 0.14, 8)
	Primitives.add_beveled_slab(chassis_tris, Vector3(0.0, 0.038, 0.0), 2.16, 2.16, 0.024, 0.08, 8)

	# 4 mordazas angulares externas en armadura (diagonales)
	for d_idx: int in range(4):
		var a: float = PI * 0.25 + float(d_idx) * PI * 0.5
		var dir_x: float = cos(a)
		var dir_z: float = sin(a)
		var clamp_rings: Array[Array] = [
			Primitives.make_box_ring(dir_x * 2.32, 0.02, dir_z * 2.32, 0.24, 0.24),
			Primitives.make_box_ring(dir_x * 1.98, 0.14, dir_z * 1.98, 0.18, 0.18),
		]
		Primitives.add_loft(armor_tris, clamp_rings, true, true, Vector3(dir_x * 2.15, 0.08, dir_z * 2.15))
		Primitives.add_framed_vein(
			crystal_tris,
			chassis_tris,
			Vector3(dir_x * 1.92, 0.12, dir_z * 1.92),
			Vector3(dir_x * 2.26, 0.05, dir_z * 2.26),
			0.036,
			0.022
		)

	# 3 cheurones direccionales en la entrada Sur (+Z) apuntando hacia el Norte (-Z)
	for ci: int in range(3):
		var cz: float = 2.35 + float(ci) * 0.50
		Primitives.add_framed_vein(
			crystal_tris,
			chassis_tris,
			Vector3(-0.42, 0.035, cz + 0.22),
			Vector3(0.0, 0.035, cz),
			0.036,
			0.016
		)
		Primitives.add_framed_vein(
			crystal_tris,
			chassis_tris,
			Vector3(0.42, 0.035, cz + 0.22),
			Vector3(0.0, 0.035, cz),
			0.036,
			0.016
		)

	_cached_ignition_socket = Primitives.build_three_surface_mesh(armor_tris, chassis_tris, crystal_tris, -2.5, 3.6, 2)
	return _cached_ignition_socket


static func build_wing_alcove_pads_mesh() -> ArrayMesh:
	if _cached_wing_pads != null:
		return _cached_wing_pads

	var armor_tris: Array[Array] = []
	var chassis_tris: Array[Array] = []
	var crystal_tris: Array[Array] = []

	# Marcos perimetrales abiertos dejando ver el suelo Ink SDF 2x intacto en el centro
	for side_sign: float in [-1.0, 1.0]:
		var cx: float = side_sign * 8.4
		var cz: float = 0.8
		var x_min: float = cx - 2.0
		var x_max: float = cx + 2.0
		var z_min: float = cz - 3.4
		var z_max: float = cz + 3.4

		# 4 bolardos esquineros bajos biselados (h = 0.24 m)
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var bx: float = cx + sx * 2.0
				var bz: float = cz + sz * 3.4
				Primitives.add_beveled_slab(chassis_tris, Vector3(bx, 0.09, bz), 0.18, 0.18, 0.18, 0.04, 6)
				Primitives.add_beveled_slab(armor_tris, Vector3(bx, 0.21, bz), 0.14, 0.14, 0.06, 0.03, 6)

		# Rieles perimetrales bajos estrictamente contenidos entre los bolardos
		var rail_edges: Array[Array] = [
			[Vector3(x_min + 0.12, 0.032, z_min), Vector3(x_max - 0.12, 0.032, z_min)],
			[Vector3(x_min + 0.12, 0.032, z_max), Vector3(x_max - 0.12, 0.032, z_max)],
			[Vector3(x_min, 0.032, z_min + 0.12), Vector3(x_min, 0.032, z_max - 0.12)],
			[Vector3(x_max, 0.032, z_min + 0.12), Vector3(x_max, 0.032, z_max - 0.12)],
		]
		for edge: Array in rail_edges:
			var p0: Vector3 = edge[0] as Vector3
			var p1: Vector3 = edge[1] as Vector3
			Primitives.add_beam_segment(chassis_tris, p0 - Vector3(0.0, 0.014, 0.0), p1 - Vector3(0.0, 0.014, 0.0), 0.055, 0.016)
			Primitives.add_beam_segment(crystal_tris, p0 + Vector3(0.0, 0.010, 0.0), p1 + Vector3(0.0, 0.010, 0.0), 0.022, 0.010)

	# Ala Este (+8.4, 0.8): zócalo octogonal hueco de pedestal bajo para futuro Invocador Gacha 3D
	var east_segs: int = 8
	var r_gacha: float = 1.15
	for i: int in range(east_segs):
		var a0: float = TAU * float(i) / float(east_segs)
		var a1: float = TAU * float(i + 1) / float(east_segs)
		var gp0 := Vector3(8.4 + cos(a0) * r_gacha, 0.04, 0.8 + sin(a0) * r_gacha)
		var gp1 := Vector3(8.4 + cos(a1) * r_gacha, 0.04, 0.8 + sin(a1) * r_gacha)
		Primitives.add_beam_segment(armor_tris if i % 2 == 0 else chassis_tris, gp0, gp1, 0.065, 0.038)
		var cp0 := Vector3(8.4 + cos(a0) * (r_gacha - 0.16), 0.045, 0.8 + sin(a0) * (r_gacha - 0.16))
		var cp1 := Vector3(8.4 + cos(a1) * (r_gacha - 0.16), 0.045, 0.8 + sin(a1) * (r_gacha - 0.16))
		Primitives.add_beam_segment(crystal_tris, cp0, cp1, 0.016, 0.011)

	# Ala Oeste (-8.4, 0.8): 3 plintos bajos en semicírculo para futuro Santuario de Reliquias
	var west_plinths: Array[Vector3] = [
		Vector3(-9.4, 0.0, -1.2),
		Vector3(-9.0, 0.0, 0.8),
		Vector3(-9.4, 0.0, 2.8),
	]
	for wp: Vector3 in west_plinths:
		Primitives.add_beveled_slab(chassis_tris, Vector3(wp.x, 0.05, wp.z), 0.36, 0.36, 0.10, 0.06, 6)
		Primitives.add_beveled_slab(armor_tris, Vector3(wp.x, 0.12, wp.z), 0.28, 0.28, 0.04, 0.04, 6)
		Primitives.add_framed_vein(
			crystal_tris,
			chassis_tris,
			Vector3(wp.x + 0.24, 0.11, wp.z - 0.14),
			Vector3(wp.x + 0.24, 0.11, wp.z + 0.14),
			0.020,
			0.012
		)

	_cached_wing_pads = Primitives.build_three_surface_mesh(armor_tris, chassis_tris, crystal_tris, -4.0, 4.0, 2)
	return _cached_wing_pads

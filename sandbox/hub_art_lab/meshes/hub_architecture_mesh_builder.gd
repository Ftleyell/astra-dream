class_name HubArchitectureMeshBuilder
extends RefCounted

## Constructor procedural de la arquitectura en "U" abierta al Sur (+Z) de la Estación Astral v2.
## - Superficies planas (piso, muros laterales) con UV métrico uniforme para hub_arcsys_surface_3d.gdshader.
## - Marcos, costillas estructurales y barandal Sur en contrato ArcSys de 3 superficies.

const Primitives = preload("res://scenes/ui/hub/astral_station/meshes/hub_arcsys_mesh_primitives.gd")

static var _cached_floor: ArrayMesh = null
static var _cached_wall: ArrayMesh = null
static var _cached_ribs: ArrayMesh = null
static var _cached_north_frame: ArrayMesh = null
static var _cached_south_railing: ArrayMesh = null
static var _cached_ignition_socket: ArrayMesh = null
static var _cached_wing_pads: ArrayMesh = null
static var _cached_south_superstructure: ArrayMesh = null
static var _cached_west_chamber: ArrayMesh = null
static var _cached_west_chamber_floor: ArrayMesh = null


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

	st.generate_tangents()
	var mesh := st.commit()
	if is_equal_approx(width, 24.0) and is_equal_approx(depth, 22.0) and is_equal_approx(tile_meters, 6.0):
		_cached_floor = mesh
	return mesh


static func build_west_chamber_floor_mesh() -> ArrayMesh:
	if _cached_west_chamber_floor != null:
		return _cached_west_chamber_floor

	# Extensión continua del deck hacia la Galería Oeste (X = -19.8 .. -11.9, Z = -4.2 .. +5.8)
	var x0: float = -19.8
	var x1: float = -11.9
	var z0: float = -4.2
	var z1: float = 5.8
	var tm: float = 6.0
	var u0: float = 0.5 + x0 / tm
	var u1: float = 0.5 + x1 / tm
	var v0: float = 0.5 + (z0 - 0.5) / tm
	var v1: float = 0.5 + (z1 - 0.5) / tm

	var a := Vector3(x0, 0.0, z0)
	var b := Vector3(x1, 0.0, z0)
	var c := Vector3(x1, 0.0, z1)
	var d := Vector3(x0, 0.0, z1)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := Vector3.UP
	st.set_normal(n); st.set_uv(Vector2(u0, v0)); st.add_vertex(a)
	st.set_normal(n); st.set_uv(Vector2(u1, v0)); st.add_vertex(b)
	st.set_normal(n); st.set_uv(Vector2(u1, v1)); st.add_vertex(c)
	st.set_normal(n); st.set_uv(Vector2(u0, v0)); st.add_vertex(a)
	st.set_normal(n); st.set_uv(Vector2(u1, v1)); st.add_vertex(c)
	st.set_normal(n); st.set_uv(Vector2(u0, v1)); st.add_vertex(d)
	st.generate_tangents()
	_cached_west_chamber_floor = st.commit()
	return _cached_west_chamber_floor


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

	st.generate_tangents()
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
		if side_sign < 0.0:
			# Lado Oeste dividido para dejar libre el Portal hacia la Galería de Trofeos (Z = -2.4 .. +4.0)
			for seg_pair: Vector2 in [Vector2(-10.0, -2.5), Vector2(4.1, 11.0)]:
				var za: float = float(seg_pair.x)
				var zb: float = float(seg_pair.y)
				var zc: float = (za + zb) * 0.5
				var zhalf: float = (zb - za) * 0.5
				Primitives.add_box(chassis_tris, Vector3(side_sign * 11.75, 0.16, zc), Vector3(0.24, 0.16, zhalf))
				Primitives.add_box(armor_tris, Vector3(side_sign * 11.75, 3.70, zc), Vector3(0.28, 0.15, zhalf))
				Primitives.add_box(chassis_tris, Vector3(side_sign * 11.77, 3.88, zc), Vector3(0.24, 0.04, zhalf))
				Primitives.add_beam_segment(crystal_tris, Vector3(side_sign * 11.44, 3.62, za), Vector3(side_sign * 11.44, 3.62, zb), 0.024, 0.018)
			var west_soffit_rings: Array[Array] = [
				Primitives.make_box_ring(side_sign * 11.65, 3.92, 0.5, 0.42, 10.65),
				Primitives.make_box_ring(side_sign * 11.45, 4.18, 0.5, 0.62, 10.72),
			]
			Primitives.add_loft(chassis_tris, west_soffit_rings, true, true, Vector3(side_sign * 11.55, 4.05, 0.5))
			Primitives.add_box(armor_tris, Vector3(side_sign * 10.92, 4.10, 0.5), Vector3(0.14, 0.08, 10.72))
		else:
			# Zócalo continuo inferior, cornisa superior y sofito biselado de techo (Lado Este)
			Primitives.add_box(chassis_tris, Vector3(side_sign * 11.75, 0.16, 0.5), Vector3(0.24, 0.16, 10.5))
			Primitives.add_box(armor_tris, Vector3(side_sign * 11.75, 3.70, 0.5), Vector3(0.28, 0.15, 10.5))
			Primitives.add_box(chassis_tris, Vector3(side_sign * 11.77, 3.88, 0.5), Vector3(0.24, 0.04, 10.52))
			var soffit_rings: Array[Array] = [
				Primitives.make_box_ring(side_sign * 11.65, 3.92, 0.5, 0.42, 10.65),
				Primitives.make_box_ring(side_sign * 11.45, 4.18, 0.5, 0.62, 10.72),
			]
			Primitives.add_loft(chassis_tris, soffit_rings, true, true, Vector3(side_sign * 11.55, 4.05, 0.5))
			Primitives.add_box(armor_tris, Vector3(side_sign * 10.92, 4.10, 0.5), Vector3(0.14, 0.08, 10.72))
			Primitives.add_beam_segment(
				crystal_tris,
				Vector3(side_sign * 11.44, 3.62, -9.8),
				Vector3(side_sign * 11.44, 3.62, 10.8),
				0.024,
				0.018
			)

		var west_z_slots: Array[float] = [-7.5, -3.2, 4.8, 9.0]
		var side_z_slots: Array[float] = west_z_slots if side_sign < 0.0 else z_slots
		for z_pos: float in side_z_slots:
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

		# Cierre arquitectónico sólido de esquinas Noroeste y Noreste (conecta X=±10.45 con X=±12.0)
		var corner_rings: Array[Array] = [
			Primitives.make_box_ring(side_sign * 11.28, 0.0, -10.35, 0.85, 0.42),
			Primitives.make_box_ring(side_sign * 11.28, 4.18, -10.35, 0.85, 0.42),
		]
		Primitives.add_loft(chassis_tris, corner_rings, true, true, Vector3(side_sign * 11.28, 2.09, -10.35))
		Primitives.add_box(armor_tris, Vector3(side_sign * 11.20, 3.82, -9.98), Vector3(0.76, 0.16, 0.14))
		Primitives.add_framed_vein(
			crystal_tris,
			chassis_tris,
			Vector3(side_sign * 11.15, 0.45, -9.88),
			Vector3(side_sign * 11.15, 3.62, -9.88),
			0.036,
			0.024
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

	# Collarín anular hueco de 16 segmentos: deja ver el deck esculpido integrado dentro del anillo
	var ring_segs: int = 16
	var r_outer: float = 2.34
	var r_mid: float = 2.16
	var r_inner: float = 1.98
	for si: int in range(ring_segs):
		var a0: float = TAU * float(si) / float(ring_segs)
		var a1: float = TAU * float(si + 1) / float(ring_segs)
		var p_out0 := Vector3(cos(a0) * r_outer, 0.036, sin(a0) * r_outer)
		var p_out1 := Vector3(cos(a1) * r_outer, 0.036, sin(a1) * r_outer)
		Primitives.add_beam_segment(chassis_tris, p_out0, p_out1, 0.14, 0.036)

		var p_mid0 := Vector3(cos(a0) * r_mid, 0.056, sin(a0) * r_mid)
		var p_mid1 := Vector3(cos(a1) * r_mid, 0.056, sin(a1) * r_mid)
		Primitives.add_beam_segment(armor_tris, p_mid0, p_mid1, 0.075, 0.022)

		var p_in0 := Vector3(cos(a0) * r_inner, 0.050, sin(a0) * r_inner)
		var p_in1 := Vector3(cos(a1) * r_inner, 0.050, sin(a1) * r_inner)
		Primitives.add_beam_segment(crystal_tris, p_in0, p_in1, 0.024, 0.015)

	# 4 pilones estabilizadores angulares esculpidos (zapatas + aletas inclinadas hacia el núcleo + cristal)
	for d_idx: int in range(4):
		var a: float = PI * 0.25 + float(d_idx) * PI * 0.5
		var dx: float = cos(a)
		var dz: float = sin(a)
		var tx: float = -dz
		var tz: float = dx

		# Zapata exterior anclada al deck
		Primitives.add_beveled_slab(chassis_tris, Vector3(dx * 2.52, 0.055, dz * 2.52), 0.34, 0.34, 0.11, 0.06, 8)
		# Espolón blindado progresivo inclinado hacia el interior
		var blade_rings: Array[Array] = [
			[
				Vector3(dx * 2.66 - tx * 0.18, 0.10, dz * 2.66 - tz * 0.18),
				Vector3(dx * 2.66 + tx * 0.18, 0.10, dz * 2.66 + tz * 0.18),
				Vector3(dx * 2.26 + tx * 0.15, 0.10, dz * 2.26 + tz * 0.15),
				Vector3(dx * 2.26 - tx * 0.15, 0.10, dz * 2.26 - tz * 0.15),
			],
			[
				Vector3(dx * 2.52 - tx * 0.14, 0.36, dz * 2.52 - tz * 0.14),
				Vector3(dx * 2.52 + tx * 0.14, 0.36, dz * 2.52 + tz * 0.14),
				Vector3(dx * 2.12 + tx * 0.11, 0.36, dz * 2.12 + tz * 0.11),
				Vector3(dx * 2.12 - tx * 0.11, 0.36, dz * 2.12 - tz * 0.11),
			],
			[
				Vector3(dx * 2.34 - tx * 0.09, 0.62, dz * 2.34 - tz * 0.09),
				Vector3(dx * 2.34 + tx * 0.09, 0.62, dz * 2.34 + tz * 0.09),
				Vector3(dx * 2.02 + tx * 0.07, 0.62, dz * 2.02 + tz * 0.07),
				Vector3(dx * 2.02 - tx * 0.07, 0.62, dz * 2.02 - tz * 0.07),
			],
		]
		Primitives.add_loft(armor_tris, blade_rings, true, true, Vector3(dx * 2.32, 0.34, dz * 2.32))
		Primitives.add_framed_vein(
			crystal_tris,
			chassis_tris,
			Vector3(dx * 2.08, 0.12, dz * 2.08),
			Vector3(dx * 1.98, 0.60, dz * 1.98),
			0.032,
			0.022
		)

	# 3 cheurones direccionales bajos integrados al corredor Norte
	for ci: int in range(3):
		var cz: float = 2.45 + float(ci) * 0.46
		Primitives.add_framed_vein(crystal_tris, chassis_tris, Vector3(-0.38, 0.022, cz + 0.20), Vector3(0.0, 0.022, cz), 0.028, 0.012)
		Primitives.add_framed_vein(crystal_tris, chassis_tris, Vector3(0.38, 0.022, cz + 0.20), Vector3(0.0, 0.022, cz), 0.028, 0.012)

	_cached_ignition_socket = Primitives.build_three_surface_mesh(armor_tris, chassis_tris, crystal_tris, -2.5, 3.6, 2)
	return _cached_ignition_socket


static func build_wing_alcove_pads_mesh() -> ArrayMesh:
	if _cached_wing_pads != null:
		return _cached_wing_pads

	var armor_tris: Array[Array] = []
	var chassis_tris: Array[Array] = []
	var crystal_tris: Array[Array] = []

	# Pórtico limpio pegado a la pared Este + umbral del portal Oeste (cero stumps en el suelo abierto)
	var east_wall_x: float = 11.22
	Primitives.add_box(chassis_tris, Vector3(east_wall_x, 0.20, 0.8), Vector3(0.18, 0.20, 4.10))
	Primitives.add_box(armor_tris, Vector3(east_wall_x - 0.10, 0.44, 0.8), Vector3(0.10, 0.05, 3.90))

	# Ala Este (+8.4, 0.8): zócalo anular bajo integrado para el Invocador Gacha 3D
	var east_segs: int = 16
	var r_gacha: float = 1.28
	for i: int in range(east_segs):
		var a0: float = TAU * float(i) / float(east_segs)
		var a1: float = TAU * float(i + 1) / float(east_segs)
		var gp0 := Vector3(8.4 + cos(a0) * r_gacha, 0.036, 0.8 + sin(a0) * r_gacha)
		var gp1 := Vector3(8.4 + cos(a1) * r_gacha, 0.036, 0.8 + sin(a1) * r_gacha)
		Primitives.add_beam_segment(armor_tris if i % 2 == 0 else chassis_tris, gp0, gp1, 0.072, 0.036)
		var cp0 := Vector3(8.4 + cos(a0) * (r_gacha - 0.16), 0.044, 0.8 + sin(a0) * (r_gacha - 0.16))
		var cp1 := Vector3(8.4 + cos(a1) * (r_gacha - 0.16), 0.044, 0.8 + sin(a1) * (r_gacha - 0.16))
		Primitives.add_beam_segment(crystal_tris, cp0, cp1, 0.015, 0.010)

	_cached_wing_pads = Primitives.build_three_surface_mesh(armor_tris, chassis_tris, crystal_tris, -4.0, 4.0, 2)
	return _cached_wing_pads


static func build_south_superstructure_mesh() -> ArrayMesh:
	if _cached_south_superstructure != null:
		return _cached_south_superstructure

	var armor_tris: Array[Array] = []
	var chassis_tris: Array[Array] = []
	var crystal_tris: Array[Array] = []

	# Cubierta inferior de hangar / pasarela exterior más allá del barandal Sur (elimina el vacío negro)
	Primitives.add_box(chassis_tris, Vector3(0.0, -0.45, 11.75), Vector3(12.2, 0.35, 0.65))
	Primitives.add_box(armor_tris, Vector3(0.0, -1.65, 14.8), Vector3(11.6, 0.24, 2.2))
	Primitives.add_box(chassis_tris, Vector3(0.0, -3.40, 18.8), Vector3(13.8, 0.32, 3.2))

	# Costillas estructurales monumentales descendiendo bajo la estación hacia el Cosmos
	for x_rib: float in [-10.8, -5.4, 0.0, 5.4, 10.8]:
		var keel_rings: Array[Array] = [
			Primitives.make_box_ring(x_rib, -0.35, 11.55, 0.28, 0.30),
			Primitives.make_box_ring(x_rib * 0.94, -2.10, 14.80, 0.34, 0.42),
			Primitives.make_box_ring(x_rib * 0.88, -4.50, 19.60, 0.24, 0.32),
		]
		Primitives.add_loft(armor_tris, keel_rings, true, true, Vector3(x_rib * 0.94, -2.3, 15.2))
		Primitives.add_framed_vein(
			crystal_tris,
			chassis_tris,
			Vector3(x_rib, -0.25, 11.88),
			Vector3(x_rib * 0.90, -3.85, 18.80),
			0.032,
			0.020
		)

	# Vigas transversales horizontales e iluminación de navegación en cubierta inferior
	Primitives.add_box(armor_tris, Vector3(0.0, -1.35, 16.75), Vector3(11.8, 0.14, 0.28))
	Primitives.add_framed_vein(crystal_tris, chassis_tris, Vector3(-11.2, -1.24, 16.45), Vector3(11.2, -1.24, 16.45), 0.034, 0.022)
	Primitives.add_framed_vein(crystal_tris, chassis_tris, Vector3(-12.8, -3.05, 21.4), Vector3(12.8, -3.05, 21.4), 0.038, 0.024)

	# Torres exteriores de acoplamiento y vigas de puente visibles sobre el horizonte Sur (Z = 14..18)
	for side_sign: float in [-1.0, 1.0]:
		var gx: float = side_sign * 9.8
		var gantry_rings: Array[Array] = [
			Primitives.make_box_ring(gx, -1.8, 15.6, 0.44, 0.48),
			Primitives.make_box_ring(gx * 0.96, 0.6, 16.2, 0.36, 0.40),
			Primitives.make_box_ring(gx * 0.90, 2.8, 16.8, 0.24, 0.28),
		]
		Primitives.add_loft(armor_tris, gantry_rings, true, true, Vector3(gx * 0.95, 0.5, 16.2))
		Primitives.add_framed_vein(crystal_tris, chassis_tris, Vector3(gx * 0.95, -1.2, 15.1), Vector3(gx * 0.90, 2.65, 16.3), 0.034, 0.022)
	Primitives.add_box(chassis_tris, Vector3(0.0, 0.45, 16.4), Vector3(8.8, 0.12, 0.24))
	Primitives.add_framed_vein(crystal_tris, chassis_tris, Vector3(-8.4, 0.54, 16.18), Vector3(8.4, 0.54, 16.18), 0.028, 0.018)

	_cached_south_superstructure = Primitives.build_three_surface_mesh(armor_tris, chassis_tris, crystal_tris, -5.2, 2.9, 1)
	return _cached_south_superstructure


static func build_west_sanctuary_chamber_mesh() -> ArrayMesh:
	if _cached_west_chamber != null:
		return _cached_west_chamber

	var armor_tris: Array[Array] = []
	var chassis_tris: Array[Array] = []
	var crystal_tris: Array[Array] = []

	# Portal de entrada en X = -12.0 (Z = -2.4 .. +4.0, alto = 3.55 m)
	for side_z: float in [-2.60, 4.20]:
		var jamb_rings: Array[Array] = [
			Primitives.make_box_ring(-12.0, 0.0, side_z, 0.42, 0.34),
			Primitives.make_box_ring(-12.0, 3.65, side_z, 0.36, 0.28),
		]
		Primitives.add_loft(armor_tris, jamb_rings, true, true, Vector3(-12.0, 1.82, side_z))
		Primitives.add_framed_vein(crystal_tris, chassis_tris, Vector3(-11.58, 0.32, side_z), Vector3(-11.58, 3.45, side_z), 0.034, 0.024)

	# Dintel del portal Oeste
	Primitives.add_box(armor_tris, Vector3(-12.0, 3.68, 0.80), Vector3(0.45, 0.26, 3.70))
	Primitives.add_framed_vein(crystal_tris, chassis_tris, Vector3(-11.52, 3.46, -2.35), Vector3(-11.52, 3.46, 3.95), 0.032, 0.020)

	# Muros perimetrales de la Galería Oeste (Norte Z=-4.2, Sur Z=+5.8, Fondo X=-19.8) y zócalo
	Primitives.add_box(chassis_tris, Vector3(-15.9, 2.0, -4.35), Vector3(4.0, 2.05, 0.22))
	Primitives.add_box(chassis_tris, Vector3(-15.9, 2.0, 5.95), Vector3(4.0, 2.05, 0.22))
	Primitives.add_box(chassis_tris, Vector3(-19.9, 2.0, 0.80), Vector3(0.24, 2.05, 5.25))

	# Costillas abovedadas internas + techo parcial de la galería
	for rz: float in [-3.4, -0.6, 2.2, 5.0]:
		var rib_rings: Array[Array] = [
			Primitives.make_box_ring(-19.45, 0.20, rz, 0.28, 0.22),
			Primitives.make_box_ring(-19.25, 3.65, rz, 0.24, 0.18),
		]
		Primitives.add_loft(armor_tris, rib_rings, true, true, Vector3(-19.35, 1.9, rz))
		Primitives.add_framed_vein(crystal_tris, chassis_tris, Vector3(-19.12, 0.55, rz), Vector3(-18.95, 3.42, rz), 0.030, 0.022)

	# Borde decorativo superior perimetral del techo de galería
	Primitives.add_box(armor_tris, Vector3(-19.4, 3.85, 0.80), Vector3(0.42, 0.14, 5.10))
	Primitives.add_framed_vein(crystal_tris, chassis_tris, Vector3(-19.05, 3.70, -3.6), Vector3(-19.05, 3.70, 5.2), 0.028, 0.018)

	# Arco luminoso en el suelo conectando los 5 pedestales dentro de la Galería Oeste
	var arc_pts: Array[Vector3] = [
		Vector3(-17.4, 0.03, -2.4),
		Vector3(-16.5, 0.03, -0.8),
		Vector3(-16.2, 0.03, 0.8),
		Vector3(-16.5, 0.03, 2.4),
		Vector3(-17.4, 0.03, 4.0),
	]
	for ai: int in range(arc_pts.size() - 1):
		Primitives.add_framed_vein(crystal_tris, chassis_tris, arc_pts[ai], arc_pts[ai + 1], 0.024, 0.014)

	_cached_west_chamber = Primitives.build_three_surface_mesh(armor_tris, chassis_tris, crystal_tris, 0.0, 4.05, 1)
	return _cached_west_chamber

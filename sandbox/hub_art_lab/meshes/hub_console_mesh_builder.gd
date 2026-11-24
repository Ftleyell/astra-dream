class_name HubConsoleMeshBuilder
extends RefCounted

## Constructor procedural 3D ArcSys para las Consolas Modulares de la Antesala de Loadout.
## Diseñadas para lucir limpias tanto en CALIBRATING (apagado/ámbar) como en ONLINE (HDR + prisma).

const Primitives = preload("res://sandbox/hub_art_lab/meshes/hub_arcsys_mesh_primitives.gd")

static var _cached_console_mesh: ArrayMesh = null
static var _cached_prism_mesh: ArrayMesh = null


static func build_console_body_mesh() -> ArrayMesh:
	if _cached_console_mesh != null:
		return _cached_console_mesh

	var armor_tris: Array[Array] = []
	var chassis_tris: Array[Array] = []
	var crystal_tris: Array[Array] = []

	# 1. Base octogonal anclada al suelo (ancho total 1.15 m -> rx = 0.575 m)
	Primitives.add_beveled_slab(chassis_tris, Vector3(0.0, 0.05, 0.0), 0.76, 0.62, 0.10, 0.08, 8)
	Primitives.add_beveled_slab(armor_tris, Vector3(0.0, 0.14, 0.0), 0.62, 0.50, 0.08, 0.07, 8)

	# 2. Pedestal en V invertida sin caras coplanares (cero Z-fighting)
	for side_sign: float in [-1.0, 1.0]:
		var leg_rings: Array[Array] = [
			Primitives.make_box_ring(side_sign * 0.24, 0.18, 0.02, 0.11, 0.20),
			Primitives.make_box_ring(side_sign * 0.19, 0.64, -0.02, 0.10, 0.18),
			Primitives.make_box_ring(side_sign * 0.28, 1.06, -0.05, 0.12, 0.20),
		]
		Primitives.add_loft(chassis_tris, leg_rings, true, true, Vector3(side_sign * 0.24, 0.62, -0.01))

		var plate_rings: Array[Array] = [
			Primitives.make_box_ring(side_sign * 0.37, 0.24, 0.02, 0.055, 0.18),
			Primitives.make_box_ring(side_sign * 0.42, 0.98, -0.04, 0.05, 0.19),
		]
		Primitives.add_loft(armor_tris, plate_rings, true, true, Vector3(side_sign * 0.39, 0.61, 0.0))

		Primitives.add_framed_vein(
			crystal_tris,
			chassis_tris,
			Vector3(side_sign * 0.46, 0.30, 0.12),
			Vector3(side_sign * 0.50, 0.94, 0.06),
			0.026,
			0.018
		)

	# Núcleo central oscuro separado ligeramente en Z para evitar coplanaridad
	Primitives.add_box(chassis_tris, Vector3(0.0, 0.58, 0.0), Vector3(0.11, 0.38, 0.15))

	# 3. Cabezal / pupitre táctil inclinado hacia +Z (h = 1.38 m max)
	var desk_rings: Array[Array] = [
		Primitives.make_box_ring(0.0, 1.06, 0.04, 0.575, 0.32),
		Primitives.make_box_ring(0.0, 1.24, -0.04, 0.535, 0.27),
	]
	Primitives.add_loft(armor_tris, desk_rings, true, true, Vector3(0.0, 1.15, 0.0))
	Primitives.add_box(chassis_tris, Vector3(0.0, 1.265, 0.0), Vector3(0.45, 0.025, 0.19))
	Primitives.add_framed_vein(crystal_tris, chassis_tris, Vector3(-0.48, 1.21, 0.25), Vector3(0.48, 1.21, 0.25), 0.030, 0.022)

	# Emisor holográfico superior
	Primitives.add_beveled_slab(chassis_tris, Vector3(0.0, 1.315, -0.02), 0.20, 0.16, 0.05, 0.03, 6)
	Primitives.add_beveled_slab(crystal_tris, Vector3(0.0, 1.355, -0.02), 0.12, 0.10, 0.04, 0.02, 6)

	_cached_console_mesh = Primitives.build_three_surface_mesh(armor_tris, chassis_tris, crystal_tris, 0.0, 1.38, 1)
	return _cached_console_mesh


static func build_console_holo_prism_mesh() -> ArrayMesh:
	if _cached_prism_mesh != null:
		return _cached_prism_mesh

	var armor_tris: Array[Array] = []
	var chassis_tris: Array[Array] = []
	var crystal_tris: Array[Array] = []

	# Cristal octaédrico estilizado (r = 0.15, h = 0.42)
	var r0: Array[Vector3] = Primitives.make_polygon_ring_y(Vector3(0.0, -0.21, 0.0), 0.015, 0.015, 4, 0.0)
	var r1: Array[Vector3] = Primitives.make_polygon_ring_y(Vector3(0.0, 0.0, 0.0), 0.15, 0.15, 4, 0.0)
	var r2: Array[Vector3] = Primitives.make_polygon_ring_y(Vector3(0.0, 0.21, 0.0), 0.015, 0.015, 4, 0.0)
	Primitives.add_loft(crystal_tris, [r0, r1, r2], true, true, Vector3.ZERO)

	# Aro giroscópico delgado inclinado (8 segmentos finos)
	var ring_pts: int = 8
	var tilt: float = deg_to_rad(22.0)
	var c_t: float = cos(tilt)
	var s_t: float = sin(tilt)
	for i: int in range(ring_pts):
		var a0: float = TAU * float(i) / float(ring_pts)
		var a1: float = TAU * float(i + 1) / float(ring_pts)
		var v0 := Vector3(cos(a0) * 0.23, 0.0, sin(a0) * 0.23)
		var v1 := Vector3(cos(a1) * 0.23, 0.0, sin(a1) * 0.23)
		var p0 := Vector3(v0.x, v0.y * c_t - v0.z * s_t, v0.y * s_t + v0.z * c_t)
		var p1 := Vector3(v1.x, v1.y * c_t - v1.z * s_t, v1.y * s_t + v1.z * c_t)
		Primitives.add_beam_segment(armor_tris, p0, p1, 0.013, 0.011)

	Primitives.add_box(chassis_tris, Vector3(0.0, -0.24, 0.0), Vector3(0.05, 0.018, 0.05))

	_cached_prism_mesh = Primitives.build_three_surface_mesh(armor_tris, chassis_tris, crystal_tris, -0.24, 0.24, 1)
	return _cached_prism_mesh

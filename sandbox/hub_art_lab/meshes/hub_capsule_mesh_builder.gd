class_name HubCapsuleMeshBuilder
extends RefCounted

## Constructor procedural 3D ArcSys para la Cápsula Central de Sincronización.
## Plataforma octogonal escalonada de perfil medio (h_max ~1.72 m) abierta al Sur (+Z)
## con cuna trasera estilo dock de Valkiria para cero oclusión de la Antesala.

const Primitives = preload("res://sandbox/hub_art_lab/meshes/hub_arcsys_mesh_primitives.gd")

static var _cached_base_mesh: ArrayMesh = null
static var _cached_halo_mesh: ArrayMesh = null


static func build_capsule_base_mesh() -> ArrayMesh:
	if _cached_base_mesh != null:
		return _cached_base_mesh

	var armor_tris: Array[Array] = []
	var chassis_tris: Array[Array] = []
	var crystal_tris: Array[Array] = []

	# 1. Plataforma octogonal escalonada en 2 niveles limpios (h_total = 0.15 m)
	Primitives.add_beveled_slab(chassis_tris, Vector3(0.0, 0.038, 0.0), 2.05, 2.05, 0.076, 0.12, 8)
	Primitives.add_beveled_slab(armor_tris, Vector3(0.0, 0.112, 0.0), 1.72, 1.72, 0.072, 0.10, 8)
	Primitives.add_beveled_slab(chassis_tris, Vector3(0.0, 0.150, 0.0), 1.42, 1.42, 0.018, 0.04, 8)

	# Aro emisor empotrado continuo alrededor de r = 1.62 m (cero Z-fighting)
	var emit_segs: int = 8
	for si: int in range(emit_segs):
		var a0: float = (PI / 8.0) + TAU * float(si) / float(emit_segs)
		var a1: float = (PI / 8.0) + TAU * float(si + 1) / float(emit_segs)
		var p0 := Vector3(cos(a0) * 1.56, 0.155, sin(a0) * 1.56)
		var p1 := Vector3(cos(a1) * 1.56, 0.155, sin(a1) * 1.56)
		Primitives.add_beam_segment(crystal_tris, p0, p1, 0.028, 0.014)

	# 4 mordazas diagonales en bisel sobre la plataforma
	for d_idx: int in range(4):
		var a: float = PI * 0.25 + float(d_idx) * PI * 0.5
		var dx: float = cos(a)
		var dz: float = sin(a)
		var clamp_rings: Array[Array] = [
			Primitives.make_box_ring(dx * 1.98, 0.04, dz * 1.98, 0.18, 0.18),
			Primitives.make_box_ring(dx * 1.72, 0.18, dz * 1.72, 0.13, 0.13),
		]
		Primitives.add_loft(armor_tris, clamp_rings, true, true, Vector3(dx * 1.85, 0.11, dz * 1.85))

	# 2. Cuna trasera estilizada en -Z (altura máxima ~1.72 m para cero oclusión de Antesala)
	for side_sign: float in [-1.0, 1.0]:
		var pylon_rings: Array[Array] = [
			Primitives.make_box_ring(side_sign * 1.48, 0.12, -1.06, 0.16, 0.20),
			Primitives.make_box_ring(side_sign * 1.62, 0.92, -1.22, 0.14, 0.17),
			Primitives.make_box_ring(side_sign * 1.55, 1.65, -1.15, 0.10, 0.13),
		]
		Primitives.add_loft(armor_tris, pylon_rings, true, true, Vector3(side_sign * 1.55, 0.90, -1.15))

		Primitives.add_framed_vein(
			crystal_tris,
			chassis_tris,
			Vector3(side_sign * 1.44, 0.30, -0.90),
			Vector3(side_sign * 1.52, 1.54, -1.00),
			0.036,
			0.024
		)

		# Aleta estabilizadora delgada hacia afuera
		var fin_rings: Array[Array] = [
			Primitives.make_box_ring(side_sign * 1.72, 0.95, -1.18, 0.04, 0.10),
			Primitives.make_box_ring(side_sign * 2.08, 1.45, -1.12, 0.018, 0.04),
		]
		Primitives.add_loft(crystal_tris, fin_rings, true, true, Vector3(side_sign * 1.90, 1.20, -1.15))

	# Barra-puente trasera baja (y = 0.65 m) enmarcando la zona trasera sin tapar la vista frontal
	Primitives.add_box(chassis_tris, Vector3(0.0, 0.65, -1.22), Vector3(1.42, 0.08, 0.12))
	Primitives.add_framed_vein(crystal_tris, chassis_tris, Vector3(-1.30, 0.68, -1.08), Vector3(1.30, 0.68, -1.08), 0.032, 0.020)

	_cached_base_mesh = Primitives.build_three_surface_mesh(armor_tris, chassis_tris, crystal_tris, 0.0, 1.75, 1)
	return _cached_base_mesh


static func build_capsule_halo_mesh() -> ArrayMesh:
	if _cached_halo_mesh != null:
		return _cached_halo_mesh

	var armor_tris: Array[Array] = []
	var chassis_tris: Array[Array] = []
	var crystal_tris: Array[Array] = []

	# Doble aro astrolabio vertical fino en plano XY (para enmarcar detrás de Valentina en -Z)
	var segments: int = 20
	var r_outer: float = 1.06
	var r_inner: float = 0.86
	for i: int in range(segments):
		var a0: float = TAU * float(i) / float(segments)
		var a1: float = TAU * float(i + 1) / float(segments)
		var po0 := Vector3(cos(a0) * r_outer, sin(a0) * r_outer, 0.0)
		var po1 := Vector3(cos(a1) * r_outer, sin(a1) * r_outer, 0.0)
		if i % 5 == 2:
			Primitives.add_framed_vein(crystal_tris, chassis_tris, po0, po1, 0.018, 0.014)
		else:
			Primitives.add_beam_segment(armor_tris, po0, po1, 0.018, 0.014)

		var pi0 := Vector3(cos(a0) * r_inner, sin(a0) * r_inner, 0.0)
		var pi1 := Vector3(cos(a1) * r_inner, sin(a1) * r_inner, 0.0)
		Primitives.add_beam_segment(chassis_tris if i % 2 == 0 else armor_tris, pi0, pi1, 0.012, 0.010)

	# 4 marcas cardinales de diamante conectando ambos aros
	for ci: int in range(4):
		var a: float = float(ci) * (PI * 0.5)
		var dx: float = cos(a)
		var dy: float = sin(a)
		Primitives.add_framed_vein(
			crystal_tris,
			chassis_tris,
			Vector3(dx * 0.82, dy * 0.82, 0.0),
			Vector3(dx * 1.12, dy * 1.12, 0.0),
			0.016,
			0.012
		)

	_cached_halo_mesh = Primitives.build_three_surface_mesh(armor_tris, chassis_tris, crystal_tris, -1.2, 1.2, 0)
	return _cached_halo_mesh

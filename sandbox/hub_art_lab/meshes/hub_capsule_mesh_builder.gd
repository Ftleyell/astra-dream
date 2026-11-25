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

	# 1. Estrado circular Hero Valkyrie de 16 lados (plataforma metálica de titanio luminosa + aro)
	Primitives.add_beveled_slab(chassis_tris, Vector3(0.0, 0.025, 0.0), 2.16, 2.16, 0.050, 0.14, 16)
	Primitives.add_beveled_slab(armor_tris, Vector3(0.0, 0.068, 0.0), 1.92, 1.92, 0.044, 0.11, 16)
	Primitives.add_beveled_slab(armor_tris, Vector3(0.0, 0.094, 0.0), 1.62, 1.62, 0.018, 0.06, 16)

	# Anillo sutil empotrado en titanio + filete cristalino tenue
	var segs: int = 16
	for si: int in range(segs):
		var a0: float = TAU * float(si) / float(segs)
		var a1: float = TAU * float(si + 1) / float(segs)
		var p0 := Vector3(cos(a0) * 1.72, 0.096, sin(a0) * 1.72)
		var p1 := Vector3(cos(a1) * 1.72, 0.096, sin(a1) * 1.72)
		Primitives.add_beam_segment(crystal_tris, p0, p1, 0.018, 0.008)

	# 8 nervios radiales metálicos en rasante
	for ri: int in range(8):
		var ra: float = TAU * float(ri) / 8.0
		Primitives.add_beam_segment(
			armor_tris,
			Vector3(cos(ra) * 0.45, 0.092, sin(ra) * 0.45),
			Vector3(cos(ra) * 1.68, 0.092, sin(ra) * 1.68),
			0.026,
			0.010
		)

	# 2. Cuna trasera escultural estilo hangar de Valkiria (alas curvas detrás de la piloto)
	for side_sign: float in [-1.0, 1.0]:
		var arch_rings: Array[Array] = [
			Primitives.make_box_ring(side_sign * 1.62, 0.08, -0.78, 0.13, 0.18),
			Primitives.make_box_ring(side_sign * 1.78, 0.72, -1.04, 0.11, 0.15),
			Primitives.make_box_ring(side_sign * 1.56, 1.48, -1.18, 0.09, 0.12),
			Primitives.make_box_ring(side_sign * 1.18, 2.08, -1.24, 0.06, 0.09),
		]
		Primitives.add_loft(armor_tris, arch_rings, true, true, Vector3(side_sign * 1.54, 1.05, -1.06))

		Primitives.add_framed_vein(
			crystal_tris,
			chassis_tris,
			Vector3(side_sign * 1.50, 0.24, -0.74),
			Vector3(side_sign * 1.16, 1.98, -1.14),
			0.026,
			0.018
		)

		# Aleta aerodinámica secundaria
		var fin_rings: Array[Array] = [
			Primitives.make_box_ring(side_sign * 1.80, 0.88, -1.02, 0.03, 0.12),
			Primitives.make_box_ring(side_sign * 2.26, 1.44, -1.08, 0.016, 0.05),
		]
		Primitives.add_loft(chassis_tris, fin_rings, true, true, Vector3(side_sign * 2.02, 1.16, -1.05))

	# Puente trasero curvo bajo de anclaje
	Primitives.add_box(chassis_tris, Vector3(0.0, 0.56, -1.26), Vector3(1.36, 0.07, 0.12))
	Primitives.add_framed_vein(crystal_tris, chassis_tris, Vector3(-1.26, 0.60, -1.12), Vector3(1.26, 0.60, -1.12), 0.022, 0.014)

	_cached_base_mesh = Primitives.build_three_surface_mesh(armor_tris, chassis_tris, crystal_tris, 0.0, 2.15, 1)
	return _cached_base_mesh


static func build_capsule_halo_mesh() -> ArrayMesh:
	if _cached_halo_mesh != null:
		return _cached_halo_mesh

	var armor_tris: Array[Array] = []
	var chassis_tris: Array[Array] = []
	var crystal_tris: Array[Array] = []

	# Doble aro astrolabio de 48 segmentos (curva ultra suave en primer plano)
	var segments: int = 48
	var r_outer: float = 1.16
	var r_inner: float = 0.94
	for i: int in range(segments):
		var a0: float = TAU * float(i) / float(segments)
		var a1: float = TAU * float(i + 1) / float(segments)
		var po0 := Vector3(cos(a0) * r_outer, sin(a0) * r_outer, 0.0)
		var po1 := Vector3(cos(a1) * r_outer, sin(a1) * r_outer, 0.0)
		if i % 12 == 5:
			Primitives.add_framed_vein(crystal_tris, chassis_tris, po0, po1, 0.020, 0.015)
		else:
			Primitives.add_beam_segment(armor_tris, po0, po1, 0.020, 0.015)

		var pi0 := Vector3(cos(a0) * r_inner, sin(a0) * r_inner, 0.0)
		var pi1 := Vector3(cos(a1) * r_inner, sin(a1) * r_inner, 0.0)
		Primitives.add_beam_segment(chassis_tris if i % 3 == 0 else armor_tris, pi0, pi1, 0.013, 0.010)

	# 4 marcas cardinales de diamante conectando ambos aros + cresta cenital
	for ci: int in range(4):
		var a: float = float(ci) * (PI * 0.5)
		var dx: float = cos(a)
		var dy: float = sin(a)
		Primitives.add_framed_vein(
			crystal_tris,
			chassis_tris,
			Vector3(dx * 0.88, dy * 0.88, 0.0),
			Vector3(dx * 1.22, dy * 1.22, 0.0),
			0.015,
			0.011
		)

	_cached_halo_mesh = Primitives.build_three_surface_mesh(armor_tris, chassis_tris, crystal_tris, -1.25, 1.25, 0)
	return _cached_halo_mesh

class_name HubGachaSummonerMeshBuilder
extends RefCounted

## Constructor procedural 3D ArcSys para el Invocador Giroscópico Astral (Fase 2).
## Genera las 7 mallas hero con contrato estricto de 3 superficies (ARMOR, CHASSIS, CRYSTAL),
## winding horario saliente Godot 4 y normales suaves soldadas en UV/UV2 para contorno inverted-hull.

const Primitives = preload("res://scenes/ui/hub/astral_station/meshes/hub_arcsys_mesh_primitives.gd")

static var _cached_pedestal: ArrayMesh = null
static var _cached_outer_ring: ArrayMesh = null
static var _cached_mid_ring: ArrayMesh = null
static var _cached_inner_ring: ArrayMesh = null
static var _cached_core_upper: ArrayMesh = null
static var _cached_core_lower: ArrayMesh = null
static var _cached_reward_capsule: ArrayMesh = null
static var _cached_spark_shard: ArrayMesh = null


static func build_pedestal_base_mesh() -> ArrayMesh:
	if _cached_pedestal != null:
		return _cached_pedestal

	var armor_tris: Array[Array] = []
	var chassis_tris: Array[Array] = []
	var crystal_tris: Array[Array] = []

	# 1. Base octogonal escalonada Psycho-Pop (r = 1.62 -> 1.38 -> 1.18 -> 1.04)
	Primitives.add_beveled_slab(chassis_tris, Vector3(0.0, 0.11, 0.0), 1.62, 1.62, 0.22, 0.14, 8)
	Primitives.add_beveled_slab(armor_tris, Vector3(0.0, 0.30, 0.0), 1.38, 1.38, 0.16, 0.10, 8)
	Primitives.add_beveled_slab(chassis_tris, Vector3(0.0, 0.48, 0.0), 1.14, 1.14, 0.20, 0.09, 8)
	Primitives.add_beveled_slab(armor_tris, Vector3(0.0, 0.64, 0.0), 0.96, 0.96, 0.12, 0.07, 8)
	Primitives.add_beveled_slab(chassis_tris, Vector3(0.0, 0.73, 0.0), 0.72, 0.72, 0.06, 0.04, 8)

	# 2. Canaletas emisivas octogonales inferior y superior
	var segs: int = 8
	for i: int in range(segs):
		var a0: float = (PI / 8.0) + TAU * float(i) / float(segs)
		var a1: float = (PI / 8.0) + TAU * float(i + 1) / float(segs)
		Primitives.add_framed_vein(
			crystal_tris,
			chassis_tris,
			Vector3(cos(a0) * 1.42, 0.23, sin(a0) * 1.42),
			Vector3(cos(a1) * 1.42, 0.23, sin(a1) * 1.42),
			0.026,
			0.018
		)
		Primitives.add_beam_segment(
			crystal_tris,
			Vector3(cos(a0) * 0.86, 0.71, sin(a0) * 0.86),
			Vector3(cos(a1) * 0.86, 0.71, sin(a1) * 0.86),
			0.022,
			0.015
		)

	# 3. 4 pilones-garra diagonales con blindaje biselado y venas HDR hacia el núcleo
	for d_idx: int in range(4):
		var a: float = PI * 0.25 + float(d_idx) * PI * 0.5
		var dx: float = cos(a)
		var dz: float = sin(a)
		var base_c := Vector3(dx * 1.48, 0.22, dz * 1.48)
		var mid_c := Vector3(dx * 1.34, 0.64, dz * 1.34)
		var tip_c := Vector3(dx * 1.12, 0.98, dz * 1.12)
		var claw_center: Vector3 = (base_c + tip_c) * 0.5

		var claw_rings: Array[Array] = [
			_make_oriented_rect_ring(base_c, dx, dz, 0.16, 0.22),
			_make_oriented_rect_ring(mid_c, dx, dz, 0.13, 0.17),
			_make_oriented_rect_ring(tip_c, dx, dz, 0.08, 0.10),
		]
		Primitives.add_loft(armor_tris, claw_rings, true, true, claw_center)

		var cradle_base := Vector3(dx * 1.54, 0.14, dz * 1.54)
		var cradle_top := Vector3(dx * 1.42, 0.44, dz * 1.42)
		var cradle_rings: Array[Array] = [
			_make_oriented_rect_ring(cradle_base, dx, dz, 0.20, 0.25),
			_make_oriented_rect_ring(cradle_top, dx, dz, 0.16, 0.19),
		]
		Primitives.add_loft(chassis_tris, cradle_rings, true, true, (cradle_base + cradle_top) * 0.5)

		Primitives.add_framed_vein(
			crystal_tris,
			chassis_tris,
			Vector3(dx * 1.24, 0.34, dz * 1.24),
			Vector3(dx * 1.04, 0.92, dz * 1.04),
			0.030,
			0.022
		)

	_cached_pedestal = Primitives.build_three_surface_mesh(armor_tris, chassis_tris, crystal_tris, 0.0, 1.05, 1)
	return _cached_pedestal


static func build_outer_ring_mesh() -> ArrayMesh:
	if _cached_outer_ring != null:
		return _cached_outer_ring

	var armor_tris: Array[Array] = []
	var chassis_tris: Array[Array] = []
	var crystal_tris: Array[Array] = []

	var segs: int = 24
	var radius: float = 1.48
	for i: int in range(segs):
		var a0: float = TAU * float(i) / float(segs)
		var a1: float = TAU * float(i + 1) / float(segs)
		var p0 := Vector3(cos(a0) * radius, sin(a0) * radius, 0.0)
		var p1 := Vector3(cos(a1) * radius, sin(a1) * radius, 0.0)
		var p_in0 := Vector3(cos(a0) * (radius - 0.09), sin(a0) * (radius - 0.09), 0.0)
		var p_in1 := Vector3(cos(a1) * (radius - 0.09), sin(a1) * (radius - 0.09), 0.0)

		if i % 3 == 0:
			Primitives.add_beam_segment(chassis_tris, p0, p1, 0.056, 0.052)
			Primitives.add_framed_vein(crystal_tris, chassis_tris, p_in0, p_in1, 0.022, 0.020)
		else:
			Primitives.add_beam_segment(armor_tris, p0, p1, 0.068, 0.048)
			Primitives.add_beam_segment(chassis_tris, p_in0, p_in1, 0.032, 0.034)

	# 4 aletas estabilizadoras diagonales con venas HDR
	for fi: int in range(4):
		var a: float = PI * 0.25 + float(fi) * PI * 0.5
		var dir := Vector3(cos(a), sin(a), 0.0)
		var tang := Vector3(-sin(a), cos(a), 0.0)
		var fin_root: Vector3 = dir * (radius + 0.02)
		var fin_mid: Vector3 = dir * (radius + 0.22)
		var fin_tip: Vector3 = dir * (radius + 0.38)
		var fin_center: Vector3 = (fin_root + fin_tip) * 0.5

		var fin_rings: Array[Array] = [
			_make_ring_on_axis(fin_root, tang, Vector3.BACK, 0.14, 0.060),
			_make_ring_on_axis(fin_mid, tang, Vector3.BACK, 0.11, 0.045),
			_make_ring_on_axis(fin_tip, tang, Vector3.BACK, 0.045, 0.022),
		]
		Primitives.add_loft(armor_tris, fin_rings, true, true, fin_center)
		Primitives.add_beam_segment(chassis_tris, dir * (radius - 0.06), dir * (radius + 0.12), 0.15, 0.070)
		Primitives.add_framed_vein(
			crystal_tris,
			chassis_tris,
			dir * (radius - 0.10) + Vector3(0.0, 0.0, 0.052),
			dir * (radius + 0.32) + Vector3(0.0, 0.0, 0.030),
			0.024,
			0.018
		)
		Primitives.add_framed_vein(
			crystal_tris,
			chassis_tris,
			dir * (radius - 0.10) - Vector3(0.0, 0.0, 0.052),
			dir * (radius + 0.32) - Vector3(0.0, 0.0, 0.030),
			0.024,
			0.018
		)

	_cached_outer_ring = Primitives.build_three_surface_mesh(armor_tris, chassis_tris, crystal_tris, -1.9, 1.9, 0)
	return _cached_outer_ring


static func build_mid_ring_mesh() -> ArrayMesh:
	if _cached_mid_ring != null:
		return _cached_mid_ring

	var armor_tris: Array[Array] = []
	var chassis_tris: Array[Array] = []
	var crystal_tris: Array[Array] = []

	var segs: int = 20
	var radius: float = 1.12
	for i: int in range(segs):
		var a0: float = TAU * float(i) / float(segs)
		var a1: float = TAU * float(i + 1) / float(segs)
		var p0 := Vector3(cos(a0) * radius, sin(a0) * radius, 0.0)
		var p1 := Vector3(cos(a1) * radius, sin(a1) * radius, 0.0)
		var p_out0 := Vector3(cos(a0) * (radius + 0.07), sin(a0) * (radius + 0.07), 0.0)
		var p_out1 := Vector3(cos(a1) * (radius + 0.07), sin(a1) * (radius + 0.07), 0.0)

		if i % 5 == 0:
			Primitives.add_beam_segment(chassis_tris, p0, p1, 0.062, 0.054)
			Primitives.add_framed_vein(crystal_tris, chassis_tris, p_out0, p_out1, 0.024, 0.020)
		else:
			Primitives.add_beam_segment(armor_tris, p0, p1, 0.054, 0.044)
			Primitives.add_beam_segment(chassis_tris, p_out0, p_out1, 0.026, 0.028)

	# 4 nodos de blindaje y cristal en ejes cardinales
	for ni: int in range(4):
		var a: float = float(ni) * PI * 0.5
		var dir := Vector3(cos(a), sin(a), 0.0)
		var node_c: Vector3 = dir * radius
		Primitives.add_beveled_slab(chassis_tris, node_c, 0.13, 0.13, 0.13, 0.03, 6)
		Primitives.add_framed_vein(
			crystal_tris,
			chassis_tris,
			node_c + Vector3(0.0, 0.0, -0.08),
			node_c + Vector3(0.0, 0.0, 0.08),
			0.032,
			0.026
		)

	_cached_mid_ring = Primitives.build_three_surface_mesh(armor_tris, chassis_tris, crystal_tris, -1.3, 1.3, 1)
	return _cached_mid_ring


static func build_inner_ring_mesh() -> ArrayMesh:
	if _cached_inner_ring != null:
		return _cached_inner_ring

	var armor_tris: Array[Array] = []
	var chassis_tris: Array[Array] = []
	var crystal_tris: Array[Array] = []

	var segs: int = 16
	var radius: float = 0.78
	for i: int in range(segs):
		var a0: float = TAU * float(i) / float(segs)
		var a1: float = TAU * float(i + 1) / float(segs)
		var p0 := Vector3(cos(a0) * radius, sin(a0) * radius, 0.0)
		var p1 := Vector3(cos(a1) * radius, sin(a1) * radius, 0.0)
		if i % 2 == 0:
			Primitives.add_beam_segment(armor_tris, p0, p1, 0.044, 0.038)
		else:
			Primitives.add_beam_segment(chassis_tris, p0, p1, 0.040, 0.034)
			Primitives.add_beam_segment(crystal_tris, p0, p1, 0.018, 0.046)

	# 4 cheurones de enfoque apuntando hacia el núcleo central
	for ci: int in range(4):
		var a: float = float(ci) * PI * 0.5
		var dir := Vector3(cos(a), sin(a), 0.0)
		var tang := Vector3(-sin(a), cos(a), 0.0)
		var base_p: Vector3 = dir * (radius + 0.04)
		var tip_p: Vector3 = dir * (radius - 0.20)
		var chev_rings: Array[Array] = [
			_make_ring_on_axis(base_p, tang, Vector3.BACK, 0.085, 0.045),
			_make_ring_on_axis(tip_p, tang, Vector3.BACK, 0.025, 0.018),
		]
		Primitives.add_loft(armor_tris, chev_rings, true, true, (base_p + tip_p) * 0.5)
		Primitives.add_framed_vein(crystal_tris, chassis_tris, dir * (radius + 0.06), dir * (radius - 0.17), 0.020, 0.048)

	_cached_inner_ring = Primitives.build_three_surface_mesh(armor_tris, chassis_tris, crystal_tris, -0.9, 0.9, 0)
	return _cached_inner_ring


static func build_core_upper_half_mesh() -> ArrayMesh:
	if _cached_core_upper != null:
		return _cached_core_upper

	var armor_tris: Array[Array] = []
	var chassis_tris: Array[Array] = []
	var crystal_tris: Array[Array] = []

	# Faceta cristalina superior multifaceta (y = 0.03 .. +0.58)
	var crystal_rings: Array[Array] = [
		Primitives.make_polygon_ring_y(Vector3(0.0, 0.03, 0.0), 0.34, 0.34, 8, PI / 8.0),
		Primitives.make_polygon_ring_y(Vector3(0.0, 0.24, 0.0), 0.26, 0.26, 8, PI / 8.0),
		Primitives.make_polygon_ring_y(Vector3(0.0, 0.58, 0.0), 0.02, 0.02, 8, PI / 8.0),
	]
	Primitives.add_loft(crystal_tris, crystal_rings, true, true, Vector3(0.0, 0.24, 0.0))

	# Collarín de corte ecuatorial en chasis oscuro + 4 costillas blindadas
	Primitives.add_beveled_slab(chassis_tris, Vector3(0.0, 0.05, 0.0), 0.37, 0.37, 0.065, 0.02, 8)
	for ri: int in range(4):
		var a: float = PI * 0.25 + float(ri) * PI * 0.5
		var dx: float = cos(a)
		var dz: float = sin(a)
		var p_bot := Vector3(dx * 0.36, 0.06, dz * 0.36)
		var p_top := Vector3(dx * 0.21, 0.38, dz * 0.21)
		var rib_rings: Array[Array] = [
			_make_oriented_rect_ring(p_bot, dx, dz, 0.055, 0.055),
			_make_oriented_rect_ring(p_top, dx, dz, 0.030, 0.030),
		]
		Primitives.add_loft(armor_tris, rib_rings, true, true, (p_bot + p_top) * 0.5)

	_cached_core_upper = Primitives.build_three_surface_mesh(armor_tris, chassis_tris, crystal_tris, 0.0, 0.60, 1)
	return _cached_core_upper


static func build_core_lower_half_mesh() -> ArrayMesh:
	if _cached_core_lower != null:
		return _cached_core_lower

	var armor_tris: Array[Array] = []
	var chassis_tris: Array[Array] = []
	var crystal_tris: Array[Array] = []

	# Faceta cristalina inferior espejada (y = -0.58 .. -0.03)
	var crystal_rings: Array[Array] = [
		Primitives.make_polygon_ring_y(Vector3(0.0, -0.58, 0.0), 0.02, 0.02, 8, PI / 8.0),
		Primitives.make_polygon_ring_y(Vector3(0.0, -0.24, 0.0), 0.26, 0.26, 8, PI / 8.0),
		Primitives.make_polygon_ring_y(Vector3(0.0, -0.03, 0.0), 0.34, 0.34, 8, PI / 8.0),
	]
	Primitives.add_loft(crystal_tris, crystal_rings, true, true, Vector3(0.0, -0.24, 0.0))

	# Collarín de corte ecuatorial + 4 costillas blindadas inferiores
	Primitives.add_beveled_slab(chassis_tris, Vector3(0.0, -0.05, 0.0), 0.37, 0.37, 0.065, 0.02, 8)
	for ri: int in range(4):
		var a: float = PI * 0.25 + float(ri) * PI * 0.5
		var dx: float = cos(a)
		var dz: float = sin(a)
		var p_top := Vector3(dx * 0.36, -0.06, dz * 0.36)
		var p_bot := Vector3(dx * 0.21, -0.38, dz * 0.21)
		var rib_rings: Array[Array] = [
			_make_oriented_rect_ring(p_bot, dx, dz, 0.030, 0.030),
			_make_oriented_rect_ring(p_top, dx, dz, 0.055, 0.055),
		]
		Primitives.add_loft(armor_tris, rib_rings, true, true, (p_bot + p_top) * 0.5)

	_cached_core_lower = Primitives.build_three_surface_mesh(armor_tris, chassis_tris, crystal_tris, -0.60, 0.0, 1)
	return _cached_core_lower


static func build_reward_capsule_mesh() -> ArrayMesh:
	if _cached_reward_capsule != null:
		return _cached_reward_capsule

	var armor_tris: Array[Array] = []
	var chassis_tris: Array[Array] = []
	var crystal_tris: Array[Array] = []

	# Prisma holográfico interior de recompensa (expuesto en BLOOM_BURST y REVEAL)
	var core_rings: Array[Array] = [
		Primitives.make_polygon_ring_y(Vector3(0.0, -0.22, 0.0), 0.14, 0.14, 6, 0.0),
		Primitives.make_polygon_ring_y(Vector3(0.0, 0.0, 0.0), 0.22, 0.22, 6, 0.0),
		Primitives.make_polygon_ring_y(Vector3(0.0, 0.22, 0.0), 0.14, 0.14, 6, 0.0),
	]
	Primitives.add_loft(crystal_tris, core_rings, true, true, Vector3.ZERO)

	# Tapas de chasis + aros de armadura
	Primitives.add_beveled_slab(chassis_tris, Vector3(0.0, 0.25, 0.0), 0.18, 0.18, 0.07, 0.03, 6)
	Primitives.add_beveled_slab(chassis_tris, Vector3(0.0, -0.25, 0.0), 0.18, 0.18, 0.07, 0.03, 6)
	Primitives.add_beveled_slab(armor_tris, Vector3(0.0, 0.19, 0.0), 0.21, 0.21, 0.05, 0.03, 6)
	Primitives.add_beveled_slab(armor_tris, Vector3(0.0, -0.19, 0.0), 0.21, 0.21, 0.05, 0.03, 6)

	_cached_reward_capsule = Primitives.build_three_surface_mesh(armor_tris, chassis_tris, crystal_tris, -0.30, 0.30, 1)
	return _cached_reward_capsule


static func build_spark_shard_mesh() -> ArrayMesh:
	if _cached_spark_shard != null:
		return _cached_spark_shard

	var tris: Array[Array] = []
	var rings: Array[Array] = [
		Primitives.make_polygon_ring_y(Vector3(0.0, -0.11, 0.0), 0.01, 0.01, 4, 0.0),
		Primitives.make_polygon_ring_y(Vector3(0.0, 0.0, 0.0), 0.055, 0.055, 4, 0.0),
		Primitives.make_polygon_ring_y(Vector3(0.0, 0.11, 0.0), 0.01, 0.01, 4, 0.0),
	]
	Primitives.add_loft(tris, rings, true, true, Vector3.ZERO)

	var mesh := ArrayMesh.new()
	Primitives.commit_surface(mesh, tris, -0.12, 0.12, 1)
	_cached_spark_shard = mesh
	return _cached_spark_shard


static func _make_oriented_rect_ring(
	center: Vector3,
	rad_x: float,
	rad_z: float,
	half_tangent: float,
	half_radial: float
) -> Array[Vector3]:
	var radial := Vector3(rad_x, 0.0, rad_z).normalized()
	var tang := Vector3(-radial.z, 0.0, radial.x)
	return [
		center - tang * half_tangent - radial * half_radial,
		center + tang * half_tangent - radial * half_radial,
		center + tang * half_tangent + radial * half_radial,
		center - tang * half_tangent + radial * half_radial,
	]


static func _make_ring_on_axis(
	center: Vector3,
	axis_a: Vector3,
	axis_b: Vector3,
	half_a: float,
	half_b: float
) -> Array[Vector3]:
	return [
		center - axis_a * half_a - axis_b * half_b,
		center + axis_a * half_a - axis_b * half_b,
		center + axis_a * half_a + axis_b * half_b,
		center - axis_a * half_a + axis_b * half_b,
	]

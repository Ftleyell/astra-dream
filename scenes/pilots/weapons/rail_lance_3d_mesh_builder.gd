class_name RailLance3DMeshBuilder
extends RefCounted
## Generador procedural de malla 3D facetada para el "Rail-Lance Autónomo" (Guns Lab — Valentina v2).
## Construye un ArrayMesh de 3 superficies (Armadura, Chasis, Cristal/Energía) con normales
## planas para cel-shading ArcSys y normales suaves precomputadas en UV/UV2 para contorno watertight.

const MUZZLE_LOCAL_POS := Vector3(0.0, 0.0, -2.18)

const SURFACE_ARMOR: int = 0
const SURFACE_CHASSIS: int = 1
const SURFACE_CRYSTAL: int = 2

static var _cached_mesh: ArrayMesh = null


static func build_rail_lance_mesh() -> ArrayMesh:
	if _cached_mesh != null:
		return _cached_mesh

	var armor_tris: Array[Array] = []
	var chassis_tris: Array[Array] = []
	var crystal_tris: Array[Array] = []

	_build_magnetic_rails(armor_tris)
	_build_armor_cowlings(armor_tris)
	_build_stabilizer_fins(armor_tris, crystal_tris)
	_build_inner_chassis(chassis_tris)
	_build_crystal_and_conduits(crystal_tris)

	var mesh := ArrayMesh.new()
	_commit_surface(mesh, armor_tris)
	_commit_surface(mesh, chassis_tris)
	_commit_surface(mesh, crystal_tris)
	_cached_mesh = mesh
	return _cached_mesh


static func _build_magnetic_rails(armor_tris: Array[Array]) -> void:
	for sign_y: float in [1.0, -1.0]:
		var rings: Array[Array] = [
			_hex_ring(0.0, sign_y * 0.29, -0.10, 0.16, 0.13, sign_y),
			_hex_ring(0.0, sign_y * 0.30, -0.52, 0.21, 0.16, sign_y),
			_hex_ring(0.0, sign_y * 0.24, -0.82, 0.15, 0.105, sign_y),
			_hex_ring(0.0, sign_y * 0.20, -1.78, 0.105, 0.072, sign_y),
			_hex_ring(0.0, sign_y * 0.155, -2.18, 0.014, 0.014, sign_y),
		]
		_add_loft(armor_tris, rings, true, true)


static func _build_armor_cowlings(armor_tris: Array[Array]) -> void:
	# Placas protectoras superiores/inferiores que envuelven la cámara del cristal
	for sign_y: float in [1.0, -1.0]:
		var rings: Array[Array] = [
			_hex_ring(0.0, sign_y * 0.25, 0.56, 0.14, 0.08, sign_y),
			_hex_ring(0.0, sign_y * 0.31, 0.22, 0.19, 0.11, sign_y),
			_hex_ring(0.0, sign_y * 0.33, -0.18, 0.20, 0.115, sign_y),
			_hex_ring(0.0, sign_y * 0.27, -0.48, 0.16, 0.09, sign_y),
		]
		_add_loft(armor_tris, rings, true, true)

	# Flancos traseros laterales izquierdo/derecho
	for sign_x: float in [1.0, -1.0]:
		var side_rings: Array[Array] = [
			_box_ring(sign_x * 0.14, 0.0, 0.58, 0.06, 0.18),
			_box_ring(sign_x * 0.17, 0.0, 0.28, 0.075, 0.22),
			_box_ring(sign_x * 0.16, 0.0, -0.08, 0.065, 0.17),
		]
		_add_loft(armor_tris, side_rings, true, true)


static func _build_stabilizer_fins(armor_tris: Array[Array], crystal_tris: Array[Array]) -> void:
	# 4 aletas estabilizadoras barridas hacia atrás (2 superiores, 2 inferiores)
	# Cada aleta se divide en cuerpo plata (armor) + punta cristalina (crystal)
	for sign_y: float in [1.0, -1.0]:
		# Aleta primaria larga (exterior trasera)
		var p_root := Vector3(0.0, sign_y * 0.24, 0.44)
		var p_mid := Vector3(0.0, sign_y * 0.54, 1.18)
		var p_tip := Vector3(0.0, sign_y * 0.68, 1.54)
		_add_fin_blade(armor_tris, p_root, p_mid, 0.06, 0.13 * sign_y, 0.032)
		_add_fin_blade(crystal_tris, p_mid, p_tip, 0.032, 0.07 * sign_y, 0.008)

		# Aleta secundaria interna (más vertical)
		var s_root := Vector3(0.0, sign_y * 0.28, 0.26)
		var s_mid := Vector3(0.0, sign_y * 0.72, 0.84)
		var s_tip := Vector3(0.0, sign_y * 0.90, 1.08)
		_add_fin_blade(armor_tris, s_root, s_mid, 0.055, 0.10 * sign_y, 0.026)
		_add_fin_blade(crystal_tris, s_mid, s_tip, 0.026, 0.055 * sign_y, 0.007)


static func _add_fin_blade(
	tris: Array[Array],
	a: Vector3,
	b: Vector3,
	half_w_a: float,
	chord_y_a: float,
	tip_w_b: float
) -> void:
	var r0: Array[Vector3] = [
		a + Vector3(0.0, chord_y_a * 0.55, -0.05),
		a + Vector3(half_w_a, 0.0, 0.0),
		a + Vector3(0.0, -chord_y_a * 0.45, 0.06),
		a + Vector3(-half_w_a, 0.0, 0.0),
	]
	var r1: Array[Vector3] = [
		b + Vector3(0.0, chord_y_a * 0.22, -0.02),
		b + Vector3(tip_w_b, 0.0, 0.0),
		b + Vector3(0.0, -chord_y_a * 0.18, 0.02),
		b + Vector3(-tip_w_b, 0.0, 0.0),
	]
	_add_loft(tris, [r0, r1], true, true)


static func _build_inner_chassis(chassis_tris: Array[Array]) -> void:
	# Cuna mecánica oscura central alrededor del cristal y puente frontal
	var body_rings: Array[Array] = [
		_oct_ring(0.0, 0.0, 0.72, 0.13, 0.18),
		_oct_ring(0.0, 0.0, 0.46, 0.175, 0.26),
		_oct_ring(0.0, 0.0, -0.05, 0.18, 0.27),
		_oct_ring(0.0, 0.0, -0.52, 0.15, 0.21),
		_oct_ring(0.0, 0.0, -0.74, 0.11, 0.13),
	]
	_add_loft(chassis_tris, body_rings, true, true)

	# Soporte interno oscuro detrás de cada conducto de riel
	for sign_y: float in [1.0, -1.0]:
		var rail_back: Array[Array] = [
			_box_ring(0.0, sign_y * 0.125, -0.60, 0.11, 0.032),
			_box_ring(0.0, sign_y * 0.120, -1.85, 0.078, 0.022),
		]
		_add_loft(chassis_tris, rail_back, true, true)


static func _build_crystal_and_conduits(crystal_tris: Array[Array]) -> void:
	# Núcleo cristalino octogonal prominente (sobresale en +-X para lectura lateral y 3/4)
	var core_rings: Array[Array] = [
		_oct_ring(0.0, 0.0, 0.36, 0.055, 0.065),
		_oct_ring(0.0, 0.0, 0.14, 0.22, 0.195),
		_oct_ring(0.0, 0.0, -0.14, 0.225, 0.195),
		_oct_ring(0.0, 0.0, -0.44, 0.045, 0.045),
	]
	_add_loft(crystal_tris, core_rings, true, true)

	# Conductos energéticos gemelos dentro del canal de los rieles
	for sign_y: float in [1.0, -1.0]:
		var cond_rings: Array[Array] = [
			_box_ring(0.0, sign_y * 0.102, -0.56, 0.082, 0.020),
			_box_ring(0.0, sign_y * 0.102, -1.82, 0.058, 0.016),
		]
		_add_loft(crystal_tris, cond_rings, true, true)


static func _hex_ring(cx: float, cy: float, z: float, hw: float, hh: float, sign_y: float) -> Array[Vector3]:
	var pts: Array[Vector3] = [
		Vector3(cx, cy + sign_y * hh, z),
		Vector3(cx + hw, cy + sign_y * hh * 0.25, z),
		Vector3(cx + hw * 0.72, cy - sign_y * hh * 0.85, z),
		Vector3(cx, cy - sign_y * hh, z),
		Vector3(cx - hw * 0.72, cy - sign_y * hh * 0.85, z),
		Vector3(cx - hw, cy + sign_y * hh * 0.25, z),
	]
	return pts


static func _oct_ring(cx: float, cy: float, z: float, hw: float, hh: float) -> Array[Vector3]:
	return [
		Vector3(cx, cy + hh, z),
		Vector3(cx + hw * 0.72, cy + hh * 0.72, z),
		Vector3(cx + hw, cy, z),
		Vector3(cx + hw * 0.72, cy - hh * 0.72, z),
		Vector3(cx, cy - hh, z),
		Vector3(cx - hw * 0.72, cy - hh * 0.72, z),
		Vector3(cx - hw, cy, z),
		Vector3(cx - hw * 0.72, cy + hh * 0.72, z),
	]


static func _box_ring(cx: float, cy: float, z: float, hw: float, hh: float) -> Array[Vector3]:
	return [
		Vector3(cx - hw, cy + hh, z),
		Vector3(cx + hw, cy + hh, z),
		Vector3(cx + hw, cy - hh, z),
		Vector3(cx - hw, cy - hh, z),
	]


static func _add_loft(
	tris: Array[Array],
	rings: Array[Array],
	cap_start: bool,
	cap_end: bool
) -> void:
	if rings.size() < 2:
		return

	# Centroide global del volumen para orientar todas las normales hacia afuera
	var center := Vector3.ZERO
	var v_count: int = 0
	for r: Array in rings:
		for v: Vector3 in r:
			center += v
			v_count += 1
	if v_count > 0:
		center /= float(v_count)

	for ri: int in range(rings.size() - 1):
		var r0: Array = rings[ri]
		var r1: Array = rings[ri + 1]
		var n: int = r0.size()
		for i: int in range(n):
			var j: int = (i + 1) % n
			var a: Vector3 = r0[i] as Vector3
			var b: Vector3 = r0[j] as Vector3
			var c: Vector3 = r1[j] as Vector3
			var d: Vector3 = r1[i] as Vector3
			_push_tri_outward(tris, a, b, c, center)
			_push_tri_outward(tris, a, c, d, center)

	if cap_start:
		var r_s: Array = rings[0]
		var cs := Vector3.ZERO
		for v: Vector3 in r_s:
			cs += v
		cs /= float(r_s.size())
		for i: int in range(r_s.size()):
			var j: int = (i + 1) % r_s.size()
			_push_tri_outward(tris, cs, r_s[i] as Vector3, r_s[j] as Vector3, center)

	if cap_end:
		var r_e: Array = rings[rings.size() - 1]
		var ce := Vector3.ZERO
		for v: Vector3 in r_e:
			ce += v
		ce /= float(r_e.size())
		for i: int in range(r_e.size()):
			var j: int = (i + 1) % r_e.size()
			_push_tri_outward(tris, ce, r_e[i] as Vector3, r_e[j] as Vector3, center)


static func _push_tri_outward(
	tris: Array[Array],
	a: Vector3,
	b: Vector3,
	c: Vector3,
	volume_center: Vector3
) -> void:
	# En Godot 4, el winding frontal (cull_back) es HORARIO (clockwise):
	# la normal saliente de SurfaceTool es (c - a).cross(b - a).
	var out_n: Vector3 = (c - a).cross(b - a)
	if out_n.length_squared() < 1e-10:
		return
	var tri_center: Vector3 = (a + b + c) / 3.0
	if out_n.dot(tri_center - volume_center) < 0.0:
		tris.append([a, c, b])
	else:
		tris.append([a, b, c])


static func _commit_surface(mesh: ArrayMesh, tris: Array[Array]) -> void:
	if tris.is_empty():
		return

	# Acumular normales suaves por posición soldada (para outline inverted-hull sin grietas)
	var smooth_acc: Dictionary = {}
	var flat_normals: Array[Vector3] = []
	flat_normals.resize(tris.size())

	for ti: int in range(tris.size()):
		var t: Array = tris[ti]
		var a: Vector3 = t[0] as Vector3
		var b: Vector3 = t[1] as Vector3
		var c: Vector3 = t[2] as Vector3
		var n: Vector3 = (c - a).cross(b - a).normalized()
		flat_normals[ti] = n
		for v: Vector3 in t:
			var key := Vector3i(roundi(v.x * 1000.0), roundi(v.y * 1000.0), roundi(v.z * 1000.0))
			var prev: Vector3 = smooth_acc.get(key, Vector3.ZERO) as Vector3
			smooth_acc[key] = prev + n

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for ti: int in range(tris.size()):
		var t: Array = tris[ti]
		var fn: Vector3 = flat_normals[ti]
		for v: Vector3 in t:
			var key := Vector3i(roundi(v.x * 1000.0), roundi(v.y * 1000.0), roundi(v.z * 1000.0))
			var sn: Vector3 = (smooth_acc.get(key, fn) as Vector3).normalized()
			st.set_normal(fn)
			st.set_uv(Vector2(sn.x, sn.y))
			st.set_uv2(Vector2(sn.z, 0.0))
			st.add_vertex(v)

	st.commit(mesh)

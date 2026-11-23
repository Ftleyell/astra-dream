class_name AstralWings3DMeshBuilder
extends RefCounted
## Generador procedural de mallas 3D facetadas fieles 1:1 a las alas originales
## "Astral Seraph" de Valentina v2 (wing_0deg_r_s0..s5).
## - Tier 0 (Shard 0): Brazo cristalino segmentado con quiebre en codo, espuela superior,
##   costura diagonal carmesí, vena en Y y punta rubí asimétrica.
## - Tier 1/2 (Shards 1..5): Dagas cristalinas bipunta blanco-plata con vena carmesí en Y
##   y bisel de punta rubí asimétrico en el borde posterior (-Y).
## - 3 superficies (0: Cristal Plata, 1: Núcleo/Bisel Oscuro, 2: Rubí/Energía HDR),
##   normales planas + suaves en UV/UV2 y simetría exacta en ±Z.

const SURFACE_ARMOR: int = 0
const SURFACE_CHASSIS: int = 1
const SURFACE_CRYSTAL: int = 2

const TIER_PRIMARY: int = 0
const TIER_MID: int = 1
const TIER_LOWER: int = 2

# Longitudes calibradas proporcionalmente a wings_metadata.json (s0 = 1.00, s1 = 0.66, s2..s5 = 0.55..0.46)
const TIER_LENGTHS: Array[float] = [2.05, 1.35, 1.00]
const TIER_WIDTHS: Array[float] = [0.22, 0.21, 0.19]
const TIER_THICKNESSES: Array[float] = [0.068, 0.062, 0.056]

static var _cached_meshes: Dictionary = {}
static var _cached_tri_counts: Dictionary = {}


static func build_wing_blade_mesh(tier: int = TIER_PRIMARY) -> ArrayMesh:
	var safe_tier: int = clampi(tier, TIER_PRIMARY, TIER_LOWER)
	if _cached_meshes.has(safe_tier):
		return _cached_meshes[safe_tier] as ArrayMesh

	var length: float = TIER_LENGTHS[safe_tier]
	var width: float = TIER_WIDTHS[safe_tier]
	var thick: float = TIER_THICKNESSES[safe_tier]

	var armor_tris: Array[Array] = []
	var chassis_tris: Array[Array] = []
	var crystal_tris: Array[Array] = []

	if safe_tier == TIER_PRIMARY:
		_build_hero_shard_s0(armor_tris, chassis_tris, crystal_tris, length, width, thick)
	else:
		_build_crystal_dagger_shard(armor_tris, chassis_tris, crystal_tris, length, width, thick)

	var mesh := ArrayMesh.new()
	_commit_surface(mesh, armor_tris, length)
	_commit_surface(mesh, chassis_tris, length)
	_commit_surface(mesh, crystal_tris, length)

	_cached_meshes[safe_tier] = mesh
	_cached_tri_counts[safe_tier] = armor_tris.size() + chassis_tris.size() + crystal_tris.size()
	return mesh


static func get_tip_local_pos(tier: int = TIER_PRIMARY) -> Vector3:
	var safe_tier: int = clampi(tier, TIER_PRIMARY, TIER_LOWER)
	var length: float = TIER_LENGTHS[safe_tier]
	return Vector3(length, 0.0, 0.0)


static func get_triangle_count(tier: int = TIER_PRIMARY) -> int:
	var safe_tier: int = clampi(tier, TIER_PRIMARY, TIER_LOWER)
	if not _cached_tri_counts.has(safe_tier):
		build_wing_blade_mesh(safe_tier)
	return int(_cached_tri_counts.get(safe_tier, 0))


static func _build_hero_shard_s0(
	armor_tris: Array[Array],
	chassis_tris: Array[Array],
	crystal_tris: Array[Array],
	L: float,
	W: float,
	T: float
) -> void:
	# 1. Segmento inferior de raíz (daga cristalina basal 0%..25% con chevron carmesí)
	var seg_a_rings: Array[Array] = [
		_crystal_ring(0.00 * L, 0.00 * W, 0.02 * W, 0.02 * W, 0.12 * T),
		_crystal_ring(0.11 * L, -0.04 * W, 0.28 * W, 0.24 * W, 0.72 * T),
		_crystal_ring(0.21 * L, -0.05 * W, 0.24 * W, 0.22 * W, 0.68 * T),
		_crystal_ring(0.26 * L, -0.07 * W, 0.03 * W, 0.04 * W, 0.16 * T),
	]
	_add_loft(armor_tris, seg_a_rings, true, true)

	# Chevron carmesí basal enmarcado con tinta oscura (contraste nítido sin Z-fighting)
	_add_framed_vein(crystal_tris, chassis_tris, Vector3(0.06 * L, -0.03 * W, 0.0), Vector3(0.17 * L, 0.14 * W, 0.0), 0.075 * W, 0.96 * T)
	_add_framed_vein(crystal_tris, chassis_tris, Vector3(0.06 * L, -0.03 * W, 0.0), Vector3(0.18 * L, -0.17 * W, 0.0), 0.075 * W, 0.96 * T)

	# 2. Segmento medio acodado + espuela superior icónica (20%..52%)
	var seg_b_rings: Array[Array] = [
		_crystal_ring(0.18 * L, 0.02 * W, 0.05 * W, 0.05 * W, 0.20 * T),
		_crystal_ring(0.29 * L, 0.22 * W, 0.34 * W, 0.28 * W, 0.92 * T),
		_crystal_ring(0.41 * L, 0.16 * W, 0.36 * W, 0.26 * W, 0.95 * T),
		_crystal_ring(0.51 * L, 0.26 * W, 0.22 * W, 0.10 * W, 0.56 * T),
		_crystal_ring(0.55 * L, 0.34 * W, 0.025 * W, 0.025 * W, 0.12 * T),
	]
	_add_loft(armor_tris, seg_b_rings, true, true)

	# Costuras luminosas diagonales enmarcadas separando el codo de la lanza principal
	_add_framed_vein(crystal_tris, chassis_tris, Vector3(0.17 * L, -0.01 * W, 0.0), Vector3(0.31 * L, 0.05 * W, 0.0), 0.095 * W, 1.08 * T)
	_add_framed_vein(crystal_tris, chassis_tris, Vector3(0.38 * L, -0.12 * W, 0.0), Vector3(0.52 * L, 0.18 * W, 0.0), 0.108 * W, 1.15 * T)

	# 3. Lanza cristalina principal superior (42%..100%)
	var seg_c_body: Array[Array] = [
		_crystal_ring(0.41 * L, -0.06 * W, 0.08 * W, 0.08 * W, 0.30 * T),
		_crystal_ring(0.52 * L, 0.04 * W, 0.44 * W, 0.34 * W, 1.00 * T),
		_crystal_ring(0.66 * L, 0.02 * W, 0.48 * W, 0.42 * W, 0.96 * T),
		_crystal_ring(0.79 * L, 0.02 * W, 0.36 * W, 0.32 * W, 0.80 * T),
	]
	_add_loft(armor_tris, seg_c_body, true, true)

	# Filo superior plata continuando hasta casi la punta (78%..95%)
	var seg_c_upper_silver: Array[Array] = [
		_crystal_ring(0.78 * L, 0.16 * W, 0.22 * W, 0.14 * W, 0.72 * T),
		_crystal_ring(0.87 * L, 0.11 * W, 0.15 * W, 0.09 * W, 0.48 * T),
		_crystal_ring(0.95 * L, 0.04 * W, 0.03 * W, 0.02 * W, 0.12 * T),
	]
	_add_loft(armor_tris, seg_c_upper_silver, true, true)

	# Punta cristalina rubí asimétrica en el borde posterior (-Y, 76%..100%)
	var seg_c_ruby_tip: Array[Array] = [
		_crystal_ring(0.76 * L, -0.11 * W, 0.13 * W, 0.24 * W, 0.78 * T),
		_crystal_ring(0.85 * L, -0.04 * W, 0.15 * W, 0.17 * W, 0.66 * T),
		_crystal_ring(0.93 * L, 0.00 * W, 0.095 * W, 0.095 * W, 0.38 * T),
		_crystal_ring(1.00 * L, 0.00 * W, 0.014 * W, 0.014 * W, 0.08 * T),
	]
	_add_loft(crystal_tris, seg_c_ruby_tip, true, true)

	# Línea de tinta oscura nítida en el corte diagonal plata ↔ punta rubí
	_add_vein_strip(chassis_tris, Vector3(0.76 * L, -0.26 * W, 0.0), Vector3(0.92 * L, 0.07 * W, 0.0), 0.040 * W, 0.86 * T)

	# Vena en Y carmesí acentuada y enmarcada sobre la lanza principal
	_add_framed_vein(crystal_tris, chassis_tris, Vector3(0.46 * L, 0.12 * W, 0.0), Vector3(0.62 * L, 0.03 * W, 0.0), 0.088 * W, 1.22 * T)
	_add_framed_vein(crystal_tris, chassis_tris, Vector3(0.54 * L, -0.32 * W, 0.0), Vector3(0.62 * L, 0.03 * W, 0.0), 0.085 * W, 1.20 * T)
	_add_framed_vein(crystal_tris, chassis_tris, Vector3(0.61 * L, 0.03 * W, 0.0), Vector3(0.80 * L, 0.01 * W, 0.0), 0.084 * W, 1.16 * T)


static func _build_crystal_dagger_shard(
	armor_tris: Array[Array],
	chassis_tris: Array[Array],
	crystal_tris: Array[Array],
	L: float,
	W: float,
	T: float
) -> void:
	# Daga cristalina bipunta fiel a wing_0deg_r_s1..s5:
	# Raíz puntiaguda en x=0, cuerpo romboidal plata hasta 72%, luego punta asimétrica
	# (filo superior +Y blanco-plata hasta 93%, bisel inferior -Y rubí sólido hasta 100%).
	var body_rings: Array[Array] = [
		_crystal_ring(0.00 * L, 0.00 * W, 0.018 * W, 0.018 * W, 0.12 * T),
		_crystal_ring(0.16 * L, 0.01 * W, 0.38 * W, 0.30 * W, 0.78 * T),
		_crystal_ring(0.32 * L, 0.02 * W, 0.50 * W, 0.44 * W, 1.00 * T),
		_crystal_ring(0.54 * L, 0.02 * W, 0.44 * W, 0.38 * W, 0.92 * T),
		_crystal_ring(0.72 * L, 0.02 * W, 0.32 * W, 0.28 * W, 0.76 * T),
	]
	_add_loft(armor_tris, body_rings, true, true)

	# Filo superior blanco-plata (+Y, 70%..93%)
	var upper_silver_rings: Array[Array] = [
		_crystal_ring(0.70 * L, 0.15 * W, 0.20 * W, 0.13 * W, 0.70 * T),
		_crystal_ring(0.83 * L, 0.10 * W, 0.13 * W, 0.08 * W, 0.46 * T),
		_crystal_ring(0.93 * L, 0.03 * W, 0.025 * W, 0.02 * W, 0.12 * T),
	]
	_add_loft(armor_tris, upper_silver_rings, true, true)

	# Punta rubí asimétrica (-Y, 69%..100%)
	var ruby_tip_rings: Array[Array] = [
		_crystal_ring(0.69 * L, -0.10 * W, 0.12 * W, 0.22 * W, 0.76 * T),
		_crystal_ring(0.82 * L, -0.04 * W, 0.14 * W, 0.17 * W, 0.62 * T),
		_crystal_ring(0.92 * L, 0.00 * W, 0.085 * W, 0.085 * W, 0.36 * T),
		_crystal_ring(1.00 * L, 0.00 * W, 0.014 * W, 0.014 * W, 0.08 * T),
	]
	_add_loft(crystal_tris, ruby_tip_rings, true, true)

	# Corte de tinta oscura en la costura diagonal plata ↔ punta rubí
	_add_vein_strip(chassis_tris, Vector3(0.69 * L, -0.26 * W, 0.0), Vector3(0.90 * L, 0.06 * W, 0.0), 0.040 * W, 0.84 * T)

	# Vena carmesí en Y acentuada y enmarcada en tinta oscura (brazos 16%..39% + vena central 38%..72%)
	_add_framed_vein(crystal_tris, chassis_tris, Vector3(0.17 * L, 0.34 * W, 0.0), Vector3(0.39 * L, 0.02 * W, 0.0), 0.092 * W, 1.24 * T)
	_add_framed_vein(crystal_tris, chassis_tris, Vector3(0.23 * L, -0.36 * W, 0.0), Vector3(0.39 * L, 0.02 * W, 0.0), 0.092 * W, 1.24 * T)
	_add_framed_vein(crystal_tris, chassis_tris, Vector3(0.38 * L, 0.02 * W, 0.0), Vector3(0.73 * L, 0.00 * W, 0.0), 0.090 * W, 1.20 * T)


static func _add_framed_vein(
	crystal_tris: Array[Array],
	chassis_tris: Array[Array],
	p0: Vector3,
	p1: Vector3,
	half_w: float,
	half_z: float
) -> void:
	# Cuna de tinta oscura ligeramente más ancha y un paso debajo en Z para enmarcar el canal rojo
	_add_vein_strip(chassis_tris, p0, p1, half_w * 1.46, half_z * 0.92)
	# Canal cristalino carmesí HDR sobresaliendo limpiamente del marco oscuro
	_add_vein_strip(crystal_tris, p0, p1, half_w, half_z)


static func _add_vein_strip(
	tris: Array[Array],
	p0: Vector3,
	p1: Vector3,
	half_w: float,
	half_z: float
) -> void:
	# Tira prismática de cristal carmesí orientada en el plano XY, simétrica en ±Z
	var seg: Vector3 = p1 - p0
	if seg.length_squared() < 1e-6:
		return
	var dir: Vector3 = seg.normalized()
	var perp := Vector3(-dir.y, dir.x, 0.0).normalized()

	var r0: Array[Vector3] = [
		p0 + perp * half_w,
		p0 + Vector3(0.0, 0.0, half_z),
		p0 - perp * half_w,
		p0 - Vector3(0.0, 0.0, half_z),
	]
	var r1: Array[Vector3] = [
		p1 + perp * half_w,
		p1 + Vector3(0.0, 0.0, half_z),
		p1 - perp * half_w,
		p1 - Vector3(0.0, 0.0, half_z),
	]
	_add_loft(tris, [r0, r1], true, true)


static func _crystal_ring(
	x: float,
	cy: float,
	up_y: float,
	down_y: float,
	hz: float
) -> Array[Vector3]:
	# Sección hexagonal afilada tipo hoja de cristal, 100% simétrica en Z = 0
	return [
		Vector3(x, cy + up_y, 0.0),
		Vector3(x, cy + up_y * 0.36, hz),
		Vector3(x, cy - down_y * 0.36, hz),
		Vector3(x, cy - down_y, 0.0),
		Vector3(x, cy - down_y * 0.36, -hz),
		Vector3(x, cy + up_y * 0.36, -hz),
	]


static func _diamond_section(x: float, cy: float, ry: float, hz: float) -> Array[Vector3]:
	return [
		Vector3(x, cy + ry, 0.0),
		Vector3(x, cy, hz),
		Vector3(x, cy - ry, 0.0),
		Vector3(x, cy, -hz),
	]


static func _add_loft(
	tris: Array[Array],
	rings: Array[Array],
	cap_start: bool,
	cap_end: bool
) -> void:
	if rings.size() < 2:
		return

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
	# Winding horario Godot 4 (cull_back): normal saliente = (c - a) x (b - a)
	var out_n: Vector3 = (c - a).cross(b - a)
	if out_n.length_squared() < 1e-10:
		return
	var tri_center: Vector3 = (a + b + c) / 3.0
	if out_n.dot(tri_center - volume_center) < 0.0:
		tris.append([a, c, b])
	else:
		tris.append([a, b, c])


static func _commit_surface(mesh: ArrayMesh, tris: Array[Array], blade_length: float) -> void:
	if tris.is_empty():
		return

	var inv_len: float = 1.0 / maxf(blade_length, 0.001)
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
			var u_blade: float = clampf(v.x * inv_len, 0.0, 1.0)
			st.set_normal(fn)
			st.set_uv(Vector2(sn.x, sn.y))
			st.set_uv2(Vector2(sn.z, u_blade))
			st.add_vertex(v)

	st.commit(mesh)

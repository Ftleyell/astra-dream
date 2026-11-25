class_name HubFloatingIslandsMeshBuilder
extends RefCounted

## Constructor procedural ArcSys Elevado v4 — Mandala Octagonal de 9 Islas:
## - Isla Central Octogonal con 4 aberturas REALES caladas al Cosmos + biseles en Oro Astral.
## - Isla Norte (Observatorio Abierto para Spotlight de Skins).
## - Isla Sur (Gran Octágono Ceremonial con hueco central calado al Cosmos para Altar de Talentos).
## - Par Espejado Bastión Medialuna-Octogonal (Oeste Reliquias / Este Gacha con 5 brazos cantiléver).
## - 4 Octágonos Intermedios Compactos (NW, NE, SW, SE) + Muelles con mordazas de oro a 90° exactos.

const Primitives = preload("res://scenes/ui/hub/astral_station/meshes/hub_arcsys_mesh_primitives.gd")

const CENTRAL_OCT_R: float = 7.60
const NORTH_OCT_R: float = 4.113
const SOUTH_OCT_R: float = 4.546
const COMPACT_OCT_R: float = 3.15
const BASTION_DOCK_X: float = 3.80
const BASTION_ARC_R: float = 5.35

static var _cached_central: ArrayMesh = null
static var _cached_central_deck: ArrayMesh = null
static var _cached_central_gold: ArrayMesh = null
static var _cached_central_glass: ArrayMesh = null
static var _cached_north: ArrayMesh = null
static var _cached_north_deck: ArrayMesh = null
static var _cached_north_gold: ArrayMesh = null
static var _cached_south: ArrayMesh = null
static var _cached_south_deck: ArrayMesh = null
static var _cached_south_gold: ArrayMesh = null
static var _cached_compact: ArrayMesh = null
static var _cached_compact_deck: ArrayMesh = null
static var _cached_compact_gold: ArrayMesh = null
static var _cached_under_keel_ring: ArrayMesh = null
static var _cached_central_corners: ArrayMesh = null
static var _cached_future_anchor: ArrayMesh = null
static var _cached_bastion_hulls: Dictionary = {}
static var _cached_bastion_decks: Dictionary = {}
static var _cached_bastion_gold: Dictionary = {}
static var _cached_compass_arc: ArrayMesh = null


static func _octagon_point_at_angle(radius: float, theta: float) -> Vector2:
	# Octágono regular con ángulo de vértices en PI/8 (caras planas en 0, 45, 90...)
	var sector: float = PI * 0.25
	var local_a: float = fposmod(theta + sector * 0.5, sector) - sector * 0.5
	var apothem: float = radius * cos(PI / 8.0)
	var r_edge: float = apothem / maxf(cos(local_a), 0.5)
	return Vector2(cos(theta) * r_edge, sin(theta) * r_edge)


static func _add_up_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, tm: float) -> void:
	var n := Vector3.UP
	var cross_y: float = (c - a).cross(b - a).y
	var p1: Vector3 = b if cross_y > 0.0 else d
	var p3: Vector3 = d if cross_y > 0.0 else b
	var uv := func(v: Vector3) -> Vector2:
		return Vector2(0.5 + v.x / tm, 0.5 + v.z / tm)
	st.set_normal(n); st.set_uv(uv.call(a)); st.add_vertex(a)
	st.set_normal(n); st.set_uv(uv.call(p1)); st.add_vertex(p1)
	st.set_normal(n); st.set_uv(uv.call(c)); st.add_vertex(c)
	st.set_normal(n); st.set_uv(uv.call(a)); st.add_vertex(a)
	st.set_normal(n); st.set_uv(uv.call(c)); st.add_vertex(c)
	st.set_normal(n); st.set_uv(uv.call(p3)); st.add_vertex(p3)


static func _is_central_pierced_wedge(wedge_idx: int) -> bool:
	# 32 sub-cuñas de 11.25° (idx = 0..31). Cuñas caladas alrededor de 22.5°, 157.5°, 202.5°, 337.5°
	return wedge_idx in [1, 2, 13, 14, 17, 18, 29, 30]


static func build_central_flagship_island_mesh() -> ArrayMesh:
	if _cached_central != null:
		return _cached_central

	var armor_tris: Array[Array] = []
	var chassis_tris: Array[Array] = []
	var crystal_tris: Array[Array] = []

	var sub_segs: int = 32
	var r_mid_in: float = 3.21
	var r_mid_out: float = 5.49
	var y_top: float = 0.0
	var y_bot: float = -0.34

	# 1. Plataforma central sólida interior r <= 3.12 (sin invadir los 4 calados) + quilla escalonada profunda
	Primitives.add_chamfered_polygon_prism(armor_tris, Vector3.ZERO, 3.12, 3.12, 0.0, -0.34, 0.08, 0.06, 16, PI / 16.0)
	Primitives.add_chamfered_polygon_prism(chassis_tris, Vector3.ZERO, 2.85, 2.85, -0.32, -2.35, 0.24, 0.18, 8, PI / 8.0)
	Primitives.add_keel_spire(chassis_tris, Vector3(0.0, -2.20, 0.0), 2.55, 2.55, 3.6, 8, PI / 8.0)
	Primitives.add_keel_spire(crystal_tris, Vector3(0.0, -4.40, 0.0), 0.72, 0.72, 1.15, 8, PI / 8.0)

	# 4 nervios inferiores en cruz cardinal (N/S/E/W) sosteniendo el anillo exterior sin cruzar los calados
	for ci: int in range(4):
		var ca: float = float(ci) * (PI * 0.5)
		var dv := Vector3(cos(ca), 0.0, sin(ca))
		Primitives.add_beam_segment(chassis_tris, dv * 1.8 + Vector3(0.0, -2.0, 0.0), dv * 6.5 + Vector3(0.0, -0.34, 0.0), 0.28, 0.30)
		Primitives.add_beam_segment(crystal_tris, dv * 2.0 + Vector3(0.0, -2.25, 0.0), dv * 6.3 + Vector3(0.0, -0.58, 0.0), 0.04, 0.05)

	# 2. Cuñas del anillo exterior y del anillo intermedio (con 4 aberturas REALES al vacío, perfil -0.34m)
	for wi: int in range(sub_segs):
		var a0: float = TAU * float(wi) / float(sub_segs)
		var a1: float = TAU * float(wi + 1) / float(sub_segs)
		var d0 := Vector2(cos(a0), sin(a0))
		var d1 := Vector2(cos(a1), sin(a1))
		var p_out0: Vector2 = _octagon_point_at_angle(CENTRAL_OCT_R, a0)
		var p_out1: Vector2 = _octagon_point_at_angle(CENTRAL_OCT_R, a1)
		var p_bevel0: Vector2 = _octagon_point_at_angle(CENTRAL_OCT_R + 0.16, a0)
		var p_bevel1: Vector2 = _octagon_point_at_angle(CENTRAL_OCT_R + 0.16, a1)

		# Anillo exterior perimetral siempre sólido (r_mid_out -> borde octágono)
		var p_mo0 := d0 * r_mid_out
		var p_mo1 := d1 * r_mid_out
		var mid_out_c := Vector3((p_mo0.x + p_out1.x) * 0.5, (y_top + y_bot) * 0.5, (p_mo0.y + p_out1.y) * 0.5)
		var bot_ring_out: Array[Vector3] = [
			Vector3(p_mo0.x, y_bot, p_mo0.y),
			Vector3(p_out0.x * 0.94, y_bot, p_out0.y * 0.94),
			Vector3(p_out1.x * 0.94, y_bot, p_out1.y * 0.94),
			Vector3(p_mo1.x, y_bot, p_mo1.y),
		]
		var shd_ring_out: Array[Vector3] = [
			Vector3(p_mo0.x, y_top - 0.16, p_mo0.y),
			Vector3(p_bevel0.x, y_top - 0.16, p_bevel0.y),
			Vector3(p_bevel1.x, y_top - 0.16, p_bevel1.y),
			Vector3(p_mo1.x, y_top - 0.16, p_mo1.y),
		]
		var top_ring_out: Array[Vector3] = [
			Vector3(p_mo0.x, y_top, p_mo0.y),
			Vector3(p_out0.x, y_top, p_out0.y),
			Vector3(p_out1.x, y_top, p_out1.y),
			Vector3(p_mo1.x, y_top, p_mo1.y),
		]
		Primitives.add_loft(armor_tris, [bot_ring_out, shd_ring_out, top_ring_out], true, true, mid_out_c)

		if not _is_central_pierced_wedge(wi):
			var p_mi0 := d0 * r_mid_in
			var p_mi1 := d1 * r_mid_in
			var mid_c := Vector3((p_mi0.x + p_mo1.x) * 0.5, (y_top + y_bot) * 0.5, (p_mi0.y + p_mo1.y) * 0.5)
			var bot_m: Array[Vector3] = [
				Vector3(p_mi0.x, y_bot, p_mi0.y),
				Vector3(p_mo0.x, y_bot, p_mo0.y),
				Vector3(p_mo1.x, y_bot, p_mo1.y),
				Vector3(p_mi1.x, y_bot, p_mi1.y),
			]
			var top_m: Array[Vector3] = [
				Vector3(p_mi0.x, y_top, p_mi0.y),
				Vector3(p_mo0.x, y_top, p_mo0.y),
				Vector3(p_mo1.x, y_top, p_mo1.y),
				Vector3(p_mi1.x, y_top, p_mi1.y),
			]
			Primitives.add_loft(armor_tris, [bot_m, top_m], true, true, mid_c)

	_cached_central = Primitives.build_three_surface_mesh(armor_tris, chassis_tris, crystal_tris, -5.5, 0.4, 1)
	return _cached_central


static func build_central_deck_surface_mesh() -> ArrayMesh:
	if _cached_central_deck != null:
		return _cached_central_deck
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tm: float = 8.0
	var sub_segs: int = 32
	var r_mid_in: float = 3.25
	var r_mid_out: float = 5.45
	var y: float = 0.014

	for wi: int in range(sub_segs):
		var a0: float = TAU * float(wi) / float(sub_segs)
		var a1: float = TAU * float(wi + 1) / float(sub_segs)
		var d0 := Vector2(cos(a0), sin(a0))
		var d1 := Vector2(cos(a1), sin(a1))
		var p_in0 := d0 * r_mid_in
		var p_in1 := d1 * r_mid_in
		var p_mo0 := d0 * r_mid_out
		var p_mo1 := d1 * r_mid_out
		var p_out0: Vector2 = _octagon_point_at_angle(CENTRAL_OCT_R, a0)
		var p_out1: Vector2 = _octagon_point_at_angle(CENTRAL_OCT_R, a1)

		# Disco interior
		var v_c := Vector3(0.0, y, 0.0)
		var v_i0 := Vector3(p_in0.x, y, p_in0.y)
		var v_i1 := Vector3(p_in1.x, y, p_in1.y)
		st.set_normal(Vector3.UP); st.set_uv(Vector2(0.5, 0.5)); st.add_vertex(v_c)
		if (v_i1 - v_c).cross(v_i0 - v_c).y > 0.0:
			st.set_normal(Vector3.UP); st.set_uv(Vector2(0.5 + p_in0.x / tm, 0.5 + p_in0.y / tm)); st.add_vertex(v_i0)
			st.set_normal(Vector3.UP); st.set_uv(Vector2(0.5 + p_in1.x / tm, 0.5 + p_in1.y / tm)); st.add_vertex(v_i1)
		else:
			st.set_normal(Vector3.UP); st.set_uv(Vector2(0.5 + p_in1.x / tm, 0.5 + p_in1.y / tm)); st.add_vertex(v_i1)
			st.set_normal(Vector3.UP); st.set_uv(Vector2(0.5 + p_in0.x / tm, 0.5 + p_in0.y / tm)); st.add_vertex(v_i0)

		# Corona intermedia (sólo en cuñas NO caladas)
		if not _is_central_pierced_wedge(wi):
			_add_up_quad(st, Vector3(p_in0.x, y, p_in0.y), Vector3(p_mo0.x, y, p_mo0.y), Vector3(p_mo1.x, y, p_mo1.y), Vector3(p_in1.x, y, p_in1.y), tm)

		# Corona exterior octogonal hasta el borde
		_add_up_quad(st, Vector3(p_mo0.x, y, p_mo0.y), Vector3(p_out0.x, y, p_out0.y), Vector3(p_out1.x, y, p_out1.y), Vector3(p_mo1.x, y, p_mo1.y), tm)

	st.generate_tangents()
	_cached_central_deck = st.commit()
	return _cached_central_deck


static func _compute_miter_vectors(ring_xz: Array[Vector2]) -> Array[Vector2]:
	var n: int = ring_xz.size()
	var miters: Array[Vector2] = []
	if n < 3:
		return miters
	var area2: float = 0.0
	for i: int in range(n):
		var a: Vector2 = ring_xz[i]
		var b: Vector2 = ring_xz[(i + 1) % n]
		area2 += a.x * b.y - b.x * a.y
	var sign_flip: float = 1.0 if area2 >= 0.0 else -1.0
	var edge_normals: Array[Vector2] = []
	for i: int in range(n):
		var a: Vector2 = ring_xz[i]
		var b: Vector2 = ring_xz[(i + 1) % n]
		var e: Vector2 = (b - a).normalized()
		edge_normals.append(Vector2(e.y, -e.x) * sign_flip)
	for i: int in range(n):
		var n_prev: Vector2 = edge_normals[(i - 1 + n) % n]
		var n_next: Vector2 = edge_normals[i]
		var avg: Vector2 = n_prev + n_next
		if avg.length_squared() < 1e-6:
			miters.append(n_next)
		else:
			var dir: Vector2 = avg.normalized()
			var denom: float = maxf(dir.dot(n_next), 0.52)
			miters.append(dir / denom)
	return miters


static func _make_collar_ring_at(p: Vector2, miter_v: Vector2, y_c: float, half_w: float, half_h: float) -> Array[Vector3]:
	var p_in_bot: Vector2 = p - miter_v * (half_w * 0.85)
	var p_out_bot: Vector2 = p + miter_v * (half_w * 0.85)
	var p_out_mid: Vector2 = p + miter_v * half_w
	var p_out_top: Vector2 = p + miter_v * (half_w * 0.62)
	var p_in_top: Vector2 = p - miter_v * (half_w * 0.62)
	var p_in_mid: Vector2 = p - miter_v * half_w
	return [
		Vector3(p_in_bot.x, y_c - half_h, p_in_bot.y),
		Vector3(p_out_bot.x, y_c - half_h, p_out_bot.y),
		Vector3(p_out_mid.x, y_c, p_out_mid.y),
		Vector3(p_out_top.x, y_c + half_h, p_out_top.y),
		Vector3(p_in_top.x, y_c + half_h, p_in_top.y),
		Vector3(p_in_mid.x, y_c, p_in_mid.y),
	]


static func _add_mitered_collar_span(
	armor_tris: Array[Array],
	p0: Vector2,
	m0: Vector2,
	p1: Vector2,
	m1: Vector2,
	y_c: float,
	half_w: float,
	half_h: float,
	cap_start: bool = false,
	cap_end: bool = false
) -> void:
	var r0: Array[Vector3] = _make_collar_ring_at(p0, m0, y_c, half_w, half_h)
	var r1: Array[Vector3] = _make_collar_ring_at(p1, m1, y_c, half_w, half_h)
	var seg_c := Vector3((p0.x + p1.x) * 0.5, y_c, (p0.y + p1.y) * 0.5)
	Primitives.add_loft(armor_tris, [r0, r1], cap_start, cap_end, seg_c)


static func _add_corner_beacon_cap(
	armor_tris: Array[Array],
	chassis_tris: Array[Array],
	crystal_tris: Array[Array],
	pos_xz: Vector2,
	scale: float = 1.0,
	y_base: float = 0.0
) -> void:
	var px: float = pos_xz.x
	var pz: float = pos_xz.y
	Primitives.add_beveled_slab(chassis_tris, Vector3(px, y_base + 0.055 * scale, pz), 0.21 * scale, 0.21 * scale, 0.11 * scale, 0.045 * scale, 8)
	Primitives.add_beveled_slab(armor_tris, Vector3(px, y_base + 0.135 * scale, pz), 0.155 * scale, 0.155 * scale, 0.08 * scale, 0.04 * scale, 8)
	Primitives.add_beveled_slab(crystal_tris, Vector3(px, y_base + 0.195 * scale, pz), 0.075 * scale, 0.075 * scale, 0.06 * scale, 0.02 * scale, 8)


static func _add_mitered_closed_frame(
	armor_tris: Array[Array],
	chassis_tris: Array[Array],
	crystal_tris: Array[Array],
	outer_pts: Array[Vector2],
	inner_pts: Array[Vector2],
	top_y: float = 0.042,
	bot_y: float = -0.22,
	add_inner_vein: bool = true
) -> void:
	var count: int = mini(outer_pts.size(), inner_pts.size())
	if count < 3:
		return
	var y_rim: float = top_y - 0.020
	var y_step: float = top_y - 0.036

	var make_armor_ring := func(o: Vector2, in_p: Vector2) -> Array[Vector3]:
		var p: Vector2 = o.lerp(in_p, 0.42)
		var rec: Vector2 = o.lerp(in_p, 0.76)
		return [
			Vector3(o.x, y_rim - 0.032, o.y),
			Vector3(o.x, y_rim, o.y),
			Vector3(p.x, top_y, p.y),
			Vector3(rec.x, y_step, rec.y),
			Vector3(rec.x, y_step - 0.032, rec.y),
		]

	var make_crystal_ring := func(o: Vector2, in_p: Vector2) -> Array[Vector3]:
		var cr_out: Vector2 = o.lerp(in_p, 0.79)
		var cr_in: Vector2 = o.lerp(in_p, 0.90)
		return [
			Vector3(cr_out.x, y_step - 0.020, cr_out.y),
			Vector3(cr_out.x, y_step - 0.004, cr_out.y),
			Vector3(cr_in.x, y_step - 0.004, cr_in.y),
			Vector3(cr_in.x, y_step - 0.020, cr_in.y),
		]

	var make_chassis_ring := func(o: Vector2, in_p: Vector2) -> Array[Vector3]:
		var ch_out: Vector2 = o.lerp(in_p, 0.775)
		var ch_wall: Vector2 = o.lerp(in_p, 0.915)
		return [
			Vector3(ch_out.x, bot_y, ch_out.y),
			Vector3(ch_out.x, y_step - 0.024, ch_out.y),
			Vector3(ch_wall.x, y_step - 0.024, ch_wall.y),
			Vector3(ch_wall.x, y_step - 0.006, ch_wall.y),
			Vector3(in_p.x, y_step - 0.006, in_p.y),
			Vector3(in_p.x, bot_y, in_p.y),
		]

	for i: int in range(count):
		var j: int = (i + 1) % count
		var o0: Vector2 = outer_pts[i]
		var o1: Vector2 = outer_pts[j]
		var in0: Vector2 = inner_pts[i]
		var in1: Vector2 = inner_pts[j]
		var seg_c := Vector3((o0.x + in1.x) * 0.5, (top_y + bot_y) * 0.5, (o0.y + in1.y) * 0.5)

		Primitives.add_loft(armor_tris, [make_armor_ring.call(o0, in0), make_armor_ring.call(o1, in1)], false, false, seg_c)
		Primitives.add_loft(chassis_tris, [make_chassis_ring.call(o0, in0), make_chassis_ring.call(o1, in1)], false, false, seg_c)
		if add_inner_vein:
			Primitives.add_loft(crystal_tris, [make_crystal_ring.call(o0, in0), make_crystal_ring.call(o1, in1)], false, false, seg_c)


static func _add_gold_docking_edge_mitered(
	armor_tris: Array[Array],
	crystal_tris: Array[Array],
	p0_xz: Vector2,
	m0: Vector2,
	p1_xz: Vector2,
	m1: Vector2,
	out_normal_xz: Vector2,
	y: float,
	half_w: float,
	half_h: float,
	gap_half_w: float
) -> void:
	var edge_v: Vector2 = p1_xz - p0_xz
	var edge_len: float = edge_v.length()
	if edge_len <= gap_half_w * 2.15:
		_add_mitered_collar_span(armor_tris, p0_xz, m0, p1_xz, m1, y, half_w, half_h, false, false)
		return
	var dir2: Vector2 = edge_v / edge_len
	var mid2: Vector2 = (p0_xz + p1_xz) * 0.5
	var jaw_a2: Vector2 = mid2 - dir2 * gap_half_w
	var jaw_b2: Vector2 = mid2 + dir2 * gap_half_w

	_add_mitered_collar_span(armor_tris, p0_xz, m0, jaw_a2, out_normal_xz, y, half_w, half_h, false, true)
	_add_mitered_collar_span(armor_tris, jaw_b2, out_normal_xz, p1_xz, m1, y, half_w, half_h, true, false)

	# Terminales en cuña esculpidos flanqueando la boca de cada puente a 90° exactos
	var dir := Vector3(dir2.x, 0.0, dir2.y)
	var out_n := Vector3(out_normal_xz.x, 0.0, out_normal_xz.y).normalized()
	var jaw_a := Vector3(jaw_a2.x, y, jaw_a2.y)
	var jaw_b := Vector3(jaw_b2.x, y, jaw_b2.y)
	for side_idx: int in range(2):
		var jp: Vector3 = jaw_a if side_idx == 0 else jaw_b
		var inward_dir: Vector3 = dir if side_idx == 0 else -dir
		var wedge_c: Vector3 = jp - inward_dir * 0.16 + Vector3(0.0, 0.035, 0.0)
		var ring_bot: Array[Vector3] = [
			jp - inward_dir * 0.34 - out_n * 0.18 + Vector3(0.0, -0.02, 0.0),
			jp - inward_dir * 0.34 + out_n * 0.18 + Vector3(0.0, -0.02, 0.0),
			jp + out_n * 0.12 + Vector3(0.0, -0.02, 0.0),
			jp - out_n * 0.12 + Vector3(0.0, -0.02, 0.0),
		]
		var ring_top: Array[Vector3] = [
			jp - inward_dir * 0.28 - out_n * 0.13 + Vector3(0.0, 0.085, 0.0),
			jp - inward_dir * 0.28 + out_n * 0.13 + Vector3(0.0, 0.085, 0.0),
			jp + out_n * 0.07 + Vector3(0.0, 0.055, 0.0),
			jp - out_n * 0.07 + Vector3(0.0, 0.055, 0.0),
		]
		Primitives.add_loft(armor_tris, [ring_bot, ring_top], true, true, wedge_c)
		Primitives.add_beam_segment(
			crystal_tris,
			jp - out_n * 0.08 + Vector3(0.0, 0.036, 0.0),
			jp + out_n * 0.09 + Vector3(0.0, 0.036, 0.0),
			0.026,
			0.018
		)


static func build_central_gold_collar_mesh() -> ArrayMesh:
	if _cached_central_gold != null:
		return _cached_central_gold
	var armor_tris: Array[Array] = []
	var chassis_tris: Array[Array] = []
	var crystal_tris: Array[Array] = []

	var oct_pts: Array[Vector2] = []
	for i: int in range(8):
		var a: float = PI / 8.0 + TAU * float(i) / 8.0
		oct_pts.append(Vector2(cos(a) * CENTRAL_OCT_R, sin(a) * CENTRAL_OCT_R))
	var miters: Array[Vector2] = _compute_miter_vectors(oct_pts)

	# Perímetro octogonal en Oro Astral continuamente ingletado con bocas en cuña en las 8 caras
	for i: int in range(8):
		var j: int = (i + 1) % 8
		var p0: Vector2 = oct_pts[i]
		var p1: Vector2 = oct_pts[j]
		var e: Vector2 = (p1 - p0).normalized()
		var face_out := Vector2(e.y, -e.x)
		var is_cardinal_face: bool = ((i % 2) == 1)
		var gap_hw: float = 1.08 if is_cardinal_face else 0.94
		_add_gold_docking_edge_mitered(armor_tris, crystal_tris, p0, miters[i], p1, miters[j], face_out, 0.034, 0.115, 0.042, gap_hw)

	# 4 marcos continuos a inglete con rebaje escalonado perfilando los calados reales al Cosmos
	var hole_pairs: Array[Array] = [[1, 3], [13, 15], [17, 19], [29, 31]]
	var ang_pad: float = 0.036
	var r_in_edge: float = 3.25
	var r_out_edge: float = 5.45
	for hp: Array in hole_pairs:
		var wi0: int = int(hp[0])
		var wi1: int = int(hp[1])
		var ang0: float = TAU * float(wi0) / 32.0
		var ang1: float = TAU * float(wi1) / 32.0
		var ang_mid: float = (ang0 + ang1) * 0.5
		var inner_pts: Array[Vector2] = [
			Vector2(cos(ang0) * r_in_edge, sin(ang0) * r_in_edge),
			Vector2(cos(ang_mid) * r_in_edge, sin(ang_mid) * r_in_edge),
			Vector2(cos(ang1) * r_in_edge, sin(ang1) * r_in_edge),
			Vector2(cos(ang1) * r_out_edge, sin(ang1) * r_out_edge),
			Vector2(cos(ang_mid) * r_out_edge, sin(ang_mid) * r_out_edge),
			Vector2(cos(ang0) * r_out_edge, sin(ang0) * r_out_edge),
		]
		var outer_pts: Array[Vector2] = [
			Vector2(cos(ang0 - ang_pad) * (r_in_edge - 0.22), sin(ang0 - ang_pad) * (r_in_edge - 0.22)),
			Vector2(cos(ang_mid) * (r_in_edge - 0.22), sin(ang_mid) * (r_in_edge - 0.22)),
			Vector2(cos(ang1 + ang_pad) * (r_in_edge - 0.22), sin(ang1 + ang_pad) * (r_in_edge - 0.22)),
			Vector2(cos(ang1 + ang_pad * 0.75) * (r_out_edge + 0.22), sin(ang1 + ang_pad * 0.75) * (r_out_edge + 0.22)),
			Vector2(cos(ang_mid) * (r_out_edge + 0.22), sin(ang_mid) * (r_out_edge + 0.22)),
			Vector2(cos(ang0 - ang_pad * 0.75) * (r_out_edge + 0.22), sin(ang0 - ang_pad * 0.75) * (r_out_edge + 0.22)),
		]
		_add_mitered_closed_frame(armor_tris, chassis_tris, crystal_tris, outer_pts, inner_pts, 0.044, -0.34, true)

	_cached_central_gold = Primitives.build_three_surface_mesh(armor_tris, chassis_tris, crystal_tris, -7.8, 7.8, 1)
	return _cached_central_gold


static func build_central_glass_cutouts_mesh() -> ArrayMesh:
	if _cached_central_glass != null:
		return _cached_central_glass
	# Cristales ultrafinos suspendidos dentro de la fosa (y = -0.22) lejos del borde luminoso superior
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hole_pairs: Array[Array] = [[1, 3], [13, 15], [17, 19], [29, 31]]
	var y: float = -0.22
	for hp: Array in hole_pairs:
		var wi0: int = int(hp[0])
		for sub: int in [wi0, wi0 + 1]:
			var a0: float = TAU * float(sub) / 32.0
			var a1: float = TAU * float(sub + 1) / 32.0
			var d0 := Vector2(cos(a0), sin(a0))
			var d1 := Vector2(cos(a1), sin(a1))
			_add_up_quad(st, Vector3(d0.x * 3.29, y, d0.y * 3.29), Vector3(d0.x * 5.41, y, d0.y * 5.41), Vector3(d1.x * 5.41, y, d1.y * 5.41), Vector3(d1.x * 3.29, y, d1.y * 3.29), 4.0)
	_cached_central_glass = st.commit()
	return _cached_central_glass


static func _bastion_outline_xz(mirror_sign_x: float) -> Array[Vector2]:
	var pts: Array[Vector2] = []
	pts.append(Vector2(-BASTION_DOCK_X * mirror_sign_x, -2.75))
	pts.append(Vector2(-1.90 * mirror_sign_x, -4.65))
	var arc_segs: int = 16
	for i: int in range(arc_segs + 1):
		var deg: float = lerpf(-90.0, 90.0, float(i) / float(arc_segs))
		var rad: float = deg_to_rad(deg)
		pts.append(Vector2(cos(rad) * BASTION_ARC_R * mirror_sign_x, sin(rad) * BASTION_ARC_R))
	pts.append(Vector2(-1.90 * mirror_sign_x, 4.65))
	pts.append(Vector2(-BASTION_DOCK_X * mirror_sign_x, 2.75))
	return pts


static func build_mirrored_bastion_island_mesh(mirror_sign_x: float) -> ArrayMesh:
	var key: int = 1 if mirror_sign_x >= 0.0 else -1
	if _cached_bastion_hulls.has(key):
		return _cached_bastion_hulls[key] as ArrayMesh
	var sx: float = float(key)

	var armor_tris: Array[Array] = []
	var chassis_tris: Array[Array] = []
	var crystal_tris: Array[Array] = []

	var ring_xz: Array[Vector2] = _bastion_outline_xz(sx)
	var n: int = ring_xz.size()
	var r_top: Array[Vector3] = []
	var r_shd: Array[Vector3] = []
	var r_bot: Array[Vector3] = []
	for p: Vector2 in ring_xz:
		r_top.append(Vector3(p.x, 0.0, p.y))
		var sh_scale: float = 1.03
		r_shd.append(Vector3(p.x * sh_scale, -0.22, p.y * sh_scale))
		r_bot.append(Vector3(p.x * 0.68, -1.28, p.y * 0.68))
	Primitives.add_loft(armor_tris, [r_bot, r_shd, r_top], true, true, Vector3(0.4 * sx, -0.62, 0.0))

	# Quilla escalonada inferior espejada
	Primitives.add_keel_spire(chassis_tris, Vector3(0.35 * sx, -1.20, 0.0), 3.1, 3.4, 3.2, 8, PI / 8.0)
	Primitives.add_keel_spire(crystal_tris, Vector3(0.35 * sx, -3.55, 0.0), 0.72, 0.72, 1.05, 8, PI / 8.0)

	# 5 brazos cantiléver al vacío naciendo limpiamente por fuera del collar perimetral (cero solapamiento)
	for deg: float in [-64.0, -32.0, 0.0, 32.0, 64.0]:
		var rad: float = deg_to_rad(deg)
		var d := Vector3(cos(rad) * sx, 0.0, sin(rad))
		var side_v := Vector3(-sin(rad), 0.0, cos(rad) * sx).normalized()
		var p_in := d * 5.44 + Vector3(0.0, 0.00, 0.0)
		var p_out := d * 6.95 + Vector3(0.0, 0.12, 0.0)
		var arm_r0: Array[Vector3] = [
			p_in - side_v * 0.16 + Vector3(0.0, -0.075, 0.0),
			p_in + side_v * 0.16 + Vector3(0.0, -0.075, 0.0),
			p_in + side_v * 0.13 + Vector3(0.0, 0.055, 0.0),
			p_in - side_v * 0.13 + Vector3(0.0, 0.055, 0.0),
		]
		var arm_r1: Array[Vector3] = [
			p_out - side_v * 0.11 + Vector3(0.0, -0.055, 0.0),
			p_out + side_v * 0.11 + Vector3(0.0, -0.055, 0.0),
			p_out + side_v * 0.085 + Vector3(0.0, 0.045, 0.0),
			p_out - side_v * 0.085 + Vector3(0.0, 0.045, 0.0),
		]
		Primitives.add_loft(armor_tris, [arm_r0, arm_r1], true, true, (p_in + p_out) * 0.5)
		Primitives.add_framed_vein(
			crystal_tris,
			chassis_tris,
			d * 5.58 + Vector3(0.0, 0.062, 0.0),
			d * 6.80 + Vector3(0.0, 0.168, 0.0),
			0.024,
			0.013
		)

	var mesh: ArrayMesh = Primitives.build_three_surface_mesh(armor_tris, chassis_tris, crystal_tris, -5.0, 0.4, 1)
	_cached_bastion_hulls[key] = mesh
	return mesh


static func build_mirrored_bastion_deck_surface_mesh(mirror_sign_x: float) -> ArrayMesh:
	var key: int = 1 if mirror_sign_x >= 0.0 else -1
	if _cached_bastion_decks.has(key):
		return _cached_bastion_decks[key] as ArrayMesh
	var ring_xz: Array[Vector2] = _bastion_outline_xz(float(key))
	var mesh: ArrayMesh = Primitives.build_flat_polygon_deck_mesh(ring_xz, 0.014, 6.0)
	_cached_bastion_decks[key] = mesh
	return mesh


static func build_mirrored_bastion_gold_collar_mesh(mirror_sign_x: float) -> ArrayMesh:
	var key: int = 1 if mirror_sign_x >= 0.0 else -1
	if _cached_bastion_gold.has(key):
		return _cached_bastion_gold[key] as ArrayMesh
	var sx: float = float(key)

	var armor_tris: Array[Array] = []
	var chassis_tris: Array[Array] = []
	var crystal_tris: Array[Array] = []

	var ring_xz: Array[Vector2] = _bastion_outline_xz(sx)
	var miters: Array[Vector2] = _compute_miter_vectors(ring_xz)
	var n: int = ring_xz.size()
	for i: int in range(n):
		var j: int = (i + 1) % n
		var a: Vector2 = ring_xz[i]
		var b: Vector2 = ring_xz[j]
		if i == n - 1:
			_add_gold_docking_edge_mitered(armor_tris, crystal_tris, a, miters[i], b, miters[j], Vector2(-sx, 0.0), 0.034, 0.11, 0.040, 1.08)
		else:
			_add_mitered_collar_span(armor_tris, a, miters[i], b, miters[j], 0.034, 0.11, 0.040, false, false)

	# Balizas de remate centradas en las 6 esquinas angulares del bastión
	for corner_idx: int in [0, 1, 2, n - 3, n - 2, n - 1]:
		_add_corner_beacon_cap(armor_tris, chassis_tris, crystal_tris, ring_xz[corner_idx], 0.78, 0.0)

	# Zócalos arquitectónicos de anclaje en el borde exterior (r=5.22..5.56) + remates en las 5 puntas cantiléver
	for deg: float in [-64.0, -32.0, 0.0, 32.0, 64.0]:
		var rad: float = deg_to_rad(deg)
		var d_xz := Vector2(cos(rad) * sx, sin(rad))
		var t_xz := Vector2(-sin(rad), cos(rad) * sx).normalized()
		var p_s_in := d_xz * 5.20
		var p_s_out := d_xz * 5.56
		var sock_r0: Array[Vector3] = [
			Vector3((p_s_in - t_xz * 0.24).x, -0.01, (p_s_in - t_xz * 0.24).y),
			Vector3((p_s_in + t_xz * 0.24).x, -0.01, (p_s_in + t_xz * 0.24).y),
			Vector3((p_s_in + t_xz * 0.18).x, 0.095, (p_s_in + t_xz * 0.18).y),
			Vector3((p_s_in - t_xz * 0.18).x, 0.095, (p_s_in - t_xz * 0.18).y),
		]
		var sock_r1: Array[Vector3] = [
			Vector3((p_s_out - t_xz * 0.21).x, -0.02, (p_s_out - t_xz * 0.21).y),
			Vector3((p_s_out + t_xz * 0.21).x, -0.02, (p_s_out + t_xz * 0.21).y),
			Vector3((p_s_out + t_xz * 0.15).x, 0.088, (p_s_out + t_xz * 0.15).y),
			Vector3((p_s_out - t_xz * 0.15).x, 0.088, (p_s_out - t_xz * 0.15).y),
		]
		Primitives.add_loft(armor_tris, [sock_r0, sock_r1], true, true, Vector3((d_xz * 5.38).x, 0.04, (d_xz * 5.38).y))
		Primitives.add_beveled_slab(chassis_tris, Vector3((d_xz * 5.36).x, 0.092, (d_xz * 5.36).y), 0.17, 0.17, 0.032, 0.03, 6)

		var p_tip := Vector3(cos(rad) * 6.95 * sx, 0.145, sin(rad) * 6.95)
		Primitives.add_beveled_slab(armor_tris, p_tip, 0.23, 0.23, 0.075, 0.045, 6)

	var mesh: ArrayMesh = Primitives.build_three_surface_mesh(armor_tris, chassis_tris, crystal_tris, -7.2, 7.2, 1)
	_cached_bastion_gold[key] = mesh
	return mesh


static func build_west_crescent_island_mesh() -> ArrayMesh:
	return build_mirrored_bastion_island_mesh(-1.0)


static func build_west_crescent_deck_surface_mesh() -> ArrayMesh:
	return build_mirrored_bastion_deck_surface_mesh(-1.0)


static func build_west_crescent_gold_collar_mesh() -> ArrayMesh:
	return build_mirrored_bastion_gold_collar_mesh(-1.0)


static func build_east_island_mesh() -> ArrayMesh:
	return build_mirrored_bastion_island_mesh(1.0)


static func build_east_deck_surface_mesh() -> ArrayMesh:
	return build_mirrored_bastion_deck_surface_mesh(1.0)


static func build_east_gold_collar_mesh() -> ArrayMesh:
	return build_mirrored_bastion_gold_collar_mesh(1.0)


static func build_north_observatory_island_mesh() -> ArrayMesh:
	if _cached_north != null:
		return _cached_north
	var armor_tris: Array[Array] = []
	var chassis_tris: Array[Array] = []
	var crystal_tris: Array[Array] = []
	Primitives.add_chamfered_polygon_prism(armor_tris, Vector3.ZERO, NORTH_OCT_R + 0.16, NORTH_OCT_R + 0.16, 0.0, -1.18, 0.26, 0.18, 8, PI / 8.0)
	Primitives.add_keel_spire(chassis_tris, Vector3(0.0, -1.12, 0.0), 2.35, 2.35, 2.6, 8, PI / 8.0)
	Primitives.add_keel_spire(crystal_tris, Vector3(0.0, -3.15, 0.0), 0.56, 0.56, 0.85, 8, PI / 8.0)
	_cached_north = Primitives.build_three_surface_mesh(armor_tris, chassis_tris, crystal_tris, -4.2, 0.3, 1)
	return _cached_north


static func build_north_observatory_deck_surface_mesh() -> ArrayMesh:
	if _cached_north_deck != null:
		return _cached_north_deck
	var ring: Array[Vector2] = []
	for i: int in range(8):
		var a: float = PI / 8.0 + TAU * float(i) / 8.0
		ring.append(Vector2(cos(a) * NORTH_OCT_R, sin(a) * NORTH_OCT_R))
	_cached_north_deck = Primitives.build_flat_polygon_deck_mesh(ring, 0.014, 5.0)
	return _cached_north_deck


static func build_north_observatory_gold_collar_mesh() -> ArrayMesh:
	if _cached_north_gold != null:
		return _cached_north_gold
	var armor_tris: Array[Array] = []
	var chassis_tris: Array[Array] = []
	var crystal_tris: Array[Array] = []
	var oct_pts: Array[Vector2] = []
	for i: int in range(8):
		var a: float = PI / 8.0 + TAU * float(i) / 8.0
		oct_pts.append(Vector2(cos(a) * NORTH_OCT_R, sin(a) * NORTH_OCT_R))
	var miters: Array[Vector2] = _compute_miter_vectors(oct_pts)
	for i: int in range(8):
		var j: int = (i + 1) % 8
		var p0: Vector2 = oct_pts[i]
		var p1: Vector2 = oct_pts[j]
		if i == 1:
			var e: Vector2 = (p1 - p0).normalized()
			_add_gold_docking_edge_mitered(armor_tris, crystal_tris, p0, miters[i], p1, miters[j], Vector2(e.y, -e.x), 0.034, 0.11, 0.040, 1.08)
		else:
			_add_mitered_collar_span(armor_tris, p0, miters[i], p1, miters[j], 0.034, 0.11, 0.040, false, false)
		_add_corner_beacon_cap(armor_tris, chassis_tris, crystal_tris, p0, 0.72, 0.0)
	_cached_north_gold = Primitives.build_three_surface_mesh(armor_tris, chassis_tris, crystal_tris, -4.5, 4.5, 1)
	return _cached_north_gold


static func build_south_talents_island_mesh() -> ArrayMesh:
	if _cached_south != null:
		return _cached_south
	var armor_tris: Array[Array] = []
	var chassis_tris: Array[Array] = []
	var crystal_tris: Array[Array] = []

	var hole_r: float = 1.71
	var y_top: float = 0.0
	var y_bot: float = -0.36

	# Anillo octogonal calado al centro para ver el Cosmos bajo el Altar de Talentos
	for i: int in range(8):
		var a0: float = PI / 8.0 + TAU * float(i) / 8.0
		var a1: float = PI / 8.0 + TAU * float((i + 1) % 8) / 8.0
		var pin0 := Vector2(cos(a0) * hole_r, sin(a0) * hole_r)
		var pin1 := Vector2(cos(a1) * hole_r, sin(a1) * hole_r)
		var pout0 := Vector2(cos(a0) * SOUTH_OCT_R, sin(a0) * SOUTH_OCT_R)
		var pout1 := Vector2(cos(a1) * SOUTH_OCT_R, sin(a1) * SOUTH_OCT_R)
		var psh0 := Vector2(cos(a0) * (SOUTH_OCT_R + 0.18), sin(a0) * (SOUTH_OCT_R + 0.18))
		var psh1 := Vector2(cos(a1) * (SOUTH_OCT_R + 0.18), sin(a1) * (SOUTH_OCT_R + 0.18))

		var seg_c := Vector3((pin0.x + pout1.x) * 0.5, -0.18, (pin0.y + pout1.y) * 0.5)
		var bot_r: Array[Vector3] = [
			Vector3(pin0.x * 1.02, y_bot, pin0.y * 1.02),
			Vector3(pout0.x * 0.94, y_bot, pout0.y * 0.94),
			Vector3(pout1.x * 0.94, y_bot, pout1.y * 0.94),
			Vector3(pin1.x * 1.02, y_bot, pin1.y * 1.02),
		]
		var sh_r: Array[Vector3] = [
			Vector3(pin0.x, y_top - 0.18, pin0.y),
			Vector3(psh0.x, y_top - 0.18, psh0.y),
			Vector3(psh1.x, y_top - 0.18, psh1.y),
			Vector3(pin1.x, y_top - 0.18, pin1.y),
		]
		var top_r: Array[Vector3] = [
			Vector3(pin0.x, y_top, pin0.y),
			Vector3(pout0.x, y_top, pout0.y),
			Vector3(pout1.x, y_top, pout1.y),
			Vector3(pin1.x, y_top, pin1.y),
		]
		Primitives.add_loft(armor_tris, [bot_r, sh_r, top_r], false, false, seg_c)

	# 4 contrafuertes diagonales bajo el casco convergiendo muy por debajo del hueco
	for ci: int in range(4):
		var a: float = PI / 4.0 + float(ci) * (PI * 0.5)
		var dv := Vector3(cos(a), 0.0, sin(a))
		Primitives.add_beam_segment(chassis_tris, dv * 2.8 + Vector3(0.0, -0.34, 0.0), Vector3(0.0, -3.2, 0.0), 0.22, 0.24)
	Primitives.add_keel_spire(crystal_tris, Vector3(0.0, -3.15, 0.0), 0.55, 0.55, 0.95, 8, PI / 8.0)

	_cached_south = Primitives.build_three_surface_mesh(armor_tris, chassis_tris, crystal_tris, -4.2, 0.3, 1)
	return _cached_south


static func build_south_talents_deck_surface_mesh() -> ArrayMesh:
	if _cached_south_deck != null:
		return _cached_south_deck
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hole_r: float = 1.68
	var tm: float = 5.5
	var y: float = 0.014
	for i: int in range(8):
		var a0: float = PI / 8.0 + TAU * float(i) / 8.0
		var a1: float = PI / 8.0 + TAU * float((i + 1) % 8) / 8.0
		var pin0 := Vector3(cos(a0) * hole_r, y, sin(a0) * hole_r)
		var pin1 := Vector3(cos(a1) * hole_r, y, sin(a1) * hole_r)
		var pout0 := Vector3(cos(a0) * SOUTH_OCT_R, y, sin(a0) * SOUTH_OCT_R)
		var pout1 := Vector3(cos(a1) * SOUTH_OCT_R, y, sin(a1) * SOUTH_OCT_R)
		_add_up_quad(st, pin0, pout0, pout1, pin1, tm)
	st.generate_tangents()
	_cached_south_deck = st.commit()
	return _cached_south_deck


static func build_south_talents_gold_collar_mesh() -> ArrayMesh:
	if _cached_south_gold != null:
		return _cached_south_gold
	var armor_tris: Array[Array] = []
	var chassis_tris: Array[Array] = []
	var crystal_tris: Array[Array] = []
	var hole_r: float = 1.68
	var oct_pts: Array[Vector2] = []
	var inner_pts: Array[Vector2] = []
	var outer_pts: Array[Vector2] = []
	for i: int in range(8):
		var a0: float = PI / 8.0 + TAU * float(i) / 8.0
		oct_pts.append(Vector2(cos(a0) * SOUTH_OCT_R, sin(a0) * SOUTH_OCT_R))
		inner_pts.append(Vector2(cos(a0) * hole_r, sin(a0) * hole_r))
		outer_pts.append(Vector2(cos(a0) * (hole_r + 0.24), sin(a0) * (hole_r + 0.24)))
	var miters: Array[Vector2] = _compute_miter_vectors(oct_pts)
	for i: int in range(8):
		var j: int = (i + 1) % 8
		var p0: Vector2 = oct_pts[i]
		var p1: Vector2 = oct_pts[j]
		if i == 5:
			var e: Vector2 = (p1 - p0).normalized()
			_add_gold_docking_edge_mitered(armor_tris, crystal_tris, p0, miters[i], p1, miters[j], Vector2(e.y, -e.x), 0.034, 0.11, 0.040, 1.08)
		else:
			_add_mitered_collar_span(armor_tris, p0, miters[i], p1, miters[j], 0.034, 0.11, 0.040, false, false)
		_add_corner_beacon_cap(armor_tris, chassis_tris, crystal_tris, p0, 0.75, 0.0)

	_add_mitered_closed_frame(armor_tris, chassis_tris, crystal_tris, outer_pts, inner_pts, 0.044, -0.36, true)
	_cached_south_gold = Primitives.build_three_surface_mesh(armor_tris, chassis_tris, crystal_tris, -4.8, 4.8, 1)
	return _cached_south_gold


static func build_compact_octagon_island_mesh() -> ArrayMesh:
	if _cached_compact != null:
		return _cached_compact
	var armor_tris: Array[Array] = []
	var chassis_tris: Array[Array] = []
	var crystal_tris: Array[Array] = []
	Primitives.add_chamfered_polygon_prism(armor_tris, Vector3.ZERO, COMPACT_OCT_R + 0.14, COMPACT_OCT_R + 0.14, 0.0, -1.04, 0.22, 0.16, 8, PI / 8.0)
	Primitives.add_keel_spire(chassis_tris, Vector3(0.0, -0.98, 0.0), 1.85, 1.85, 2.2, 8, PI / 8.0)
	Primitives.add_keel_spire(crystal_tris, Vector3(0.0, -2.55, 0.0), 0.48, 0.48, 0.78, 8, PI / 8.0)
	_cached_compact = Primitives.build_three_surface_mesh(armor_tris, chassis_tris, crystal_tris, -3.5, 0.3, 1)
	return _cached_compact


static func build_compact_octagon_deck_surface_mesh() -> ArrayMesh:
	if _cached_compact_deck != null:
		return _cached_compact_deck
	var ring: Array[Vector2] = []
	for i: int in range(8):
		var a: float = PI / 8.0 + TAU * float(i) / 8.0
		ring.append(Vector2(cos(a) * COMPACT_OCT_R, sin(a) * COMPACT_OCT_R))
	_cached_compact_deck = Primitives.build_flat_polygon_deck_mesh(ring, 0.014, 4.5)
	return _cached_compact_deck


static func build_compact_octagon_gold_collar_mesh() -> ArrayMesh:
	if _cached_compact_gold != null:
		return _cached_compact_gold
	var armor_tris: Array[Array] = []
	var chassis_tris: Array[Array] = []
	var crystal_tris: Array[Array] = []
	var oct_pts: Array[Vector2] = []
	for i: int in range(8):
		var a: float = PI / 8.0 + TAU * float(i) / 8.0
		oct_pts.append(Vector2(cos(a) * COMPACT_OCT_R, sin(a) * COMPACT_OCT_R))
	var miters: Array[Vector2] = _compute_miter_vectors(oct_pts)
	for i: int in range(8):
		var j: int = (i + 1) % 8
		var p0: Vector2 = oct_pts[i]
		var p1: Vector2 = oct_pts[j]
		if i == 5:
			var e: Vector2 = (p1 - p0).normalized()
			_add_gold_docking_edge_mitered(armor_tris, crystal_tris, p0, miters[i], p1, miters[j], Vector2(e.y, -e.x), 0.032, 0.095, 0.036, 0.94)
		else:
			_add_mitered_collar_span(armor_tris, p0, miters[i], p1, miters[j], 0.032, 0.095, 0.036, false, false)
		_add_corner_beacon_cap(armor_tris, chassis_tris, crystal_tris, p0, 0.65, 0.0)
	_cached_compact_gold = Primitives.build_three_surface_mesh(armor_tris, chassis_tris, crystal_tris, -3.5, 3.5, 1)
	return _cached_compact_gold


static func build_loadout_pod_mesh() -> ArrayMesh:
	return build_compact_octagon_island_mesh()


static func build_loadout_pod_deck_surface_mesh() -> ArrayMesh:
	return build_compact_octagon_deck_surface_mesh()


static func build_loadout_pod_gold_collar_mesh() -> ArrayMesh:
	return build_compact_octagon_gold_collar_mesh()


static func build_future_slot_anchor_mesh() -> ArrayMesh:
	if _cached_future_anchor != null:
		return _cached_future_anchor
	var armor_tris: Array[Array] = []
	var chassis_tris: Array[Array] = []
	var crystal_tris: Array[Array] = []

	# Monolito Astral Sellado para el Slot Futuro NW (pedestal octogonal + 4 columnas + obelisco latente)
	Primitives.add_beveled_slab(chassis_tris, Vector3(0.0, 0.04, 0.0), 1.18, 1.18, 0.08, 0.09, 8)
	Primitives.add_beveled_slab(armor_tris, Vector3(0.0, 0.10, 0.0), 0.90, 0.90, 0.055, 0.07, 8)

	for ci: int in range(4):
		var a: float = PI / 4.0 + float(ci) * (PI * 0.5)
		var dx: float = cos(a)
		var dz: float = sin(a)
		var col_r: Array[Array] = [
			Primitives.make_box_ring(dx * 0.78, 0.12, dz * 0.78, 0.10, 0.10),
			Primitives.make_box_ring(dx * 0.54, 1.56, dz * 0.54, 0.05, 0.05),
		]
		Primitives.add_loft(armor_tris, col_r, true, true, Vector3(dx * 0.66, 0.84, dz * 0.66))
		Primitives.add_framed_vein(crystal_tris, chassis_tris, Vector3(dx * 0.74, 0.18, dz * 0.74), Vector3(dx * 0.52, 1.50, dz * 0.52), 0.018, 0.012)

	# Obelisco central suspendido en modo latente + anillo de sello inclinado
	var r0: Array[Vector3] = Primitives.make_polygon_ring_y(Vector3(0.0, 0.44, 0.0), 0.04, 0.04, 6, 0.0)
	var r1: Array[Vector3] = Primitives.make_polygon_ring_y(Vector3(0.0, 1.12, 0.0), 0.24, 0.24, 6, 0.0)
	var r2: Array[Vector3] = Primitives.make_polygon_ring_y(Vector3(0.0, 1.98, 0.0), 0.02, 0.02, 6, 0.0)
	Primitives.add_loft(crystal_tris, [r0, r1, r2], true, true, Vector3(0.0, 1.18, 0.0))

	var segs: int = 18
	var rad: float = 0.56
	var tilt: float = deg_to_rad(28.0)
	for i: int in range(segs):
		var a0: float = TAU * float(i) / float(segs)
		var a1: float = TAU * float(i + 1) / float(segs)
		var v0 := Vector3(cos(a0) * rad, 0.0, sin(a0) * rad)
		var v1 := Vector3(cos(a1) * rad, 0.0, sin(a1) * rad)
		var p0 := Vector3(v0.x, 1.24 + v0.y * cos(tilt) - v0.z * sin(tilt), v0.y * sin(tilt) + v0.z * cos(tilt))
		var p1 := Vector3(v1.x, 1.24 + v1.y * cos(tilt) - v1.z * sin(tilt), v1.y * sin(tilt) + v1.z * cos(tilt))
		Primitives.add_beam_segment(armor_tris if i % 3 != 0 else chassis_tris, p0, p1, 0.022, 0.014)

	_cached_future_anchor = Primitives.build_three_surface_mesh(armor_tris, chassis_tris, crystal_tris, 0.0, 2.05, 1)
	return _cached_future_anchor


static func build_central_under_keel_ring_mesh() -> ArrayMesh:
	if _cached_under_keel_ring != null:
		return _cached_under_keel_ring
	var armor_tris: Array[Array] = []
	var chassis_tris: Array[Array] = []
	var crystal_tris: Array[Array] = []

	# Aro astrolabio bajo la quilla (visible girando a través de los 4 calados centrales)
	var segs: int = 32
	var r_mid: float = 4.28
	for i: int in range(segs):
		var a0: float = TAU * float(i) / float(segs)
		var a1: float = TAU * float(i + 1) / float(segs)
		var p_out0 := Vector3(cos(a0) * 4.65, 0.0, sin(a0) * 4.65)
		var p_out1 := Vector3(cos(a1) * 4.65, 0.0, sin(a1) * 4.65)
		var p_in0 := Vector3(cos(a0) * 3.92, -0.08, sin(a0) * 3.92)
		var p_in1 := Vector3(cos(a1) * 3.92, -0.08, sin(a1) * 3.92)
		Primitives.add_beam_segment(armor_tris, p_out0, p_out1, 0.14, 0.07)
		Primitives.add_beam_segment(chassis_tris, p_in0, p_in1, 0.10, 0.06)
		if i % 4 == 0:
			var p_n := Vector3(cos(a0) * r_mid, 0.04, sin(a0) * r_mid)
			Primitives.add_beveled_slab(armor_tris, p_n, 0.34, 0.34, 0.16, 0.06, 6)
			Primitives.add_beveled_slab(crystal_tris, p_n + Vector3(0.0, 0.09, 0.0), 0.16, 0.16, 0.08, 0.03, 6)

	_cached_under_keel_ring = Primitives.build_three_surface_mesh(armor_tris, chassis_tris, crystal_tris, -4.8, 4.8, 1)
	return _cached_under_keel_ring


static func build_central_corner_beacons_mesh() -> ArrayMesh:
	if _cached_central_corners != null:
		return _cached_central_corners
	var armor_tris: Array[Array] = []
	var chassis_tris: Array[Array] = []
	var crystal_tris: Array[Array] = []

	# 8 balizas centradas exactamente sobre los vértices exteriores ingletados (CENTRAL_OCT_R = 7.60m)
	for i: int in range(8):
		var a: float = PI / 8.0 + TAU * float(i) / 8.0
		var corner_xz := Vector2(cos(a) * CENTRAL_OCT_R, sin(a) * CENTRAL_OCT_R)
		_add_corner_beacon_cap(armor_tris, chassis_tris, crystal_tris, corner_xz, 1.08, 0.015)

	_cached_central_corners = Primitives.build_three_surface_mesh(armor_tris, chassis_tris, crystal_tris, 0.0, 0.4, 1)
	return _cached_central_corners


static func build_hardlight_bridge_surface_mesh(length: float, width: float) -> ArrayMesh:
	var hx: float = width * 0.5
	var hz: float = length * 0.5 + 0.06
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var a := Vector3(-hx, 0.022, -hz)
	var b := Vector3(hx, 0.022, -hz)
	var c := Vector3(hx, 0.022, hz)
	var d := Vector3(-hx, 0.022, hz)
	st.set_normal(Vector3.UP); st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(a)
	st.set_normal(Vector3.UP); st.set_uv(Vector2(1.0, 0.0)); st.add_vertex(b)
	st.set_normal(Vector3.UP); st.set_uv(Vector2(1.0, 1.0)); st.add_vertex(c)
	st.set_normal(Vector3.UP); st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(a)
	st.set_normal(Vector3.UP); st.set_uv(Vector2(1.0, 1.0)); st.add_vertex(c)
	st.set_normal(Vector3.UP); st.set_uv(Vector2(0.0, 1.0)); st.add_vertex(d)
	return st.commit()


static func build_bridge_emitter_pylons_mesh(length: float, width: float) -> ArrayMesh:
	var armor_tris: Array[Array] = []
	var chassis_tris: Array[Array] = []
	var crystal_tris: Array[Array] = []
	var hz: float = length * 0.5
	var hx: float = width * 0.52
	for sign_z: float in [-1.0, 1.0]:
		Primitives.add_framed_vein(crystal_tris, chassis_tris, Vector3(-hx * 0.85, 0.026, sign_z * hz), Vector3(hx * 0.85, 0.026, sign_z * hz), 0.022, 0.012)
	Primitives.add_beveled_slab(armor_tris, Vector3(-hx, 0.03, -hz), 0.10, 0.10, 0.05, 0.02, 6)
	return Primitives.build_three_surface_mesh(armor_tris, chassis_tris, crystal_tris, 0.0, 0.2, 1)


static func build_perimeter_compass_arc_mesh() -> ArrayMesh:
	if _cached_compass_arc != null:
		return _cached_compass_arc
	var armor_tris: Array[Array] = []
	var chassis_tris: Array[Array] = []
	var crystal_tris: Array[Array] = []
	var segs: int = 12
	var r: float = 2.6
	for i: int in range(segs):
		var t0: float = float(i) / float(segs)
		var t1: float = float(i + 1) / float(segs)
		var a0: float = deg_to_rad(lerpf(-28.0, 28.0, t0) - 90.0)
		var a1: float = deg_to_rad(lerpf(-28.0, 28.0, t1) - 90.0)
		var p0 := Vector3(cos(a0) * r, 0.08, sin(a0) * r)
		var p1 := Vector3(cos(a1) * r, 0.08, sin(a1) * r)
		Primitives.add_framed_vein(crystal_tris, chassis_tris, p0, p1, 0.045, 0.022)
	Primitives.add_beam_segment(armor_tris, Vector3(-0.28, 0.08, -r - 0.10), Vector3(0.0, 0.10, -r - 0.55), 0.06, 0.03)
	Primitives.add_beam_segment(armor_tris, Vector3(0.28, 0.08, -r - 0.10), Vector3(0.0, 0.10, -r - 0.55), 0.06, 0.03)
	_cached_compass_arc = Primitives.build_three_surface_mesh(armor_tris, chassis_tris, crystal_tris, -3.5, 0.5, 2)
	return _cached_compass_arc


static func build_data_spark_mesh() -> ArrayMesh:
	var tris: Array[Array] = []
	var top := Vector3(0.0, 0.16, 0.0)
	var bot := Vector3(0.0, -0.16, 0.0)
	var r: float = 0.065
	var ring: Array[Vector3] = [
		Vector3(r, 0.0, 0.0),
		Vector3(0.0, 0.0, r),
		Vector3(-r, 0.0, 0.0),
		Vector3(0.0, 0.0, -r),
	]
	for i: int in range(4):
		var j: int = (i + 1) % 4
		Primitives.push_tri_outward(tris, top, ring[i], ring[j], Vector3.ZERO)
		Primitives.push_tri_outward(tris, bot, ring[j], ring[i], Vector3.ZERO)
	var mesh := ArrayMesh.new()
	Primitives.commit_surface(mesh, tris, -0.16, 0.16, 1, Primitives.SURFACE_CRYSTAL)
	return mesh

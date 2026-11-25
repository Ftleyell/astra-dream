class_name HubArcSysMeshPrimitives
extends RefCounted

## Utilidades geométricas compartidas para mallas 3D procedurales ArcSys del Hub.
## Garantiza contrato de 3 superficies (ARMOR, CHASSIS, CRYSTAL), winding horario Godot 4,
## normal plana en NORMAL (cel-shading + crease ink) y normal suave soldada en UV/UV2 (outline watertight).

const SURFACE_ARMOR: int = 0
const SURFACE_CHASSIS: int = 1
const SURFACE_CRYSTAL: int = 2


static func push_tri_outward(
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


static func add_loft(
	tris: Array[Array],
	rings: Array[Array],
	cap_start: bool = true,
	cap_end: bool = true,
	custom_center: Vector3 = Vector3(INF, INF, INF)
) -> void:
	if rings.size() < 2:
		return

	var center: Vector3 = custom_center
	if not center.is_finite():
		center = Vector3.ZERO
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
		var n: int = mini(r0.size(), r1.size())
		for i: int in range(n):
			var j: int = (i + 1) % n
			var a: Vector3 = r0[i] as Vector3
			var b: Vector3 = r0[j] as Vector3
			var c: Vector3 = r1[j] as Vector3
			var d: Vector3 = r1[i] as Vector3
			push_tri_outward(tris, a, b, c, center)
			push_tri_outward(tris, a, c, d, center)

	if cap_start:
		var r_s: Array = rings[0]
		var cs: Vector3 = Vector3.ZERO
		for v: Vector3 in r_s:
			cs += v
		cs /= maxf(float(r_s.size()), 1.0)
		for i: int in range(r_s.size()):
			var j: int = (i + 1) % r_s.size()
			push_tri_outward(tris, cs, r_s[i] as Vector3, r_s[j] as Vector3, center)

	if cap_end:
		var r_e: Array = rings[rings.size() - 1]
		var ce: Vector3 = Vector3.ZERO
		for v: Vector3 in r_e:
			ce += v
		ce /= maxf(float(r_e.size()), 1.0)
		for i: int in range(r_e.size()):
			var j: int = (i + 1) % r_e.size()
			push_tri_outward(tris, ce, r_e[i] as Vector3, r_e[j] as Vector3, center)


static func make_box_ring(cx: float, cy: float, cz: float, hx: float, hz: float) -> Array[Vector3]:
	return [
		Vector3(cx - hx, cy, cz - hz),
		Vector3(cx + hx, cy, cz - hz),
		Vector3(cx + hx, cy, cz + hz),
		Vector3(cx - hx, cy, cz + hz),
	]


static func make_polygon_ring_y(center: Vector3, rx: float, rz: float, sides: int, angle_offset_rad: float = 0.0) -> Array[Vector3]:
	var ring: Array[Vector3] = []
	var count: int = maxi(sides, 3)
	for i: int in range(count):
		var a: float = angle_offset_rad + TAU * float(i) / float(count)
		ring.append(Vector3(center.x + cos(a) * rx, center.y, center.z + sin(a) * rz))
	return ring


static func add_box(tris: Array[Array], center: Vector3, half_extents: Vector3) -> void:
	var r0: Array[Vector3] = make_box_ring(center.x, center.y - half_extents.y, center.z, half_extents.x, half_extents.z)
	var r1: Array[Vector3] = make_box_ring(center.x, center.y + half_extents.y, center.z, half_extents.x, half_extents.z)
	add_loft(tris, [r0, r1], true, true, center)


static func add_beveled_slab(
	tris: Array[Array],
	center: Vector3,
	rx: float,
	rz: float,
	height: float,
	bevel_inset: float = 0.12,
	sides: int = 8
) -> void:
	var half_h: float = height * 0.5
	var bevel_h: float = minf(height * 0.28, bevel_inset * 0.85)
	var angle_off: float = PI / float(maxi(sides, 3))
	var r_bot: Array[Vector3] = make_polygon_ring_y(Vector3(center.x, center.y - half_h, center.z), rx, rz, sides, angle_off)
	var r_mid: Array[Vector3] = make_polygon_ring_y(Vector3(center.x, center.y + half_h - bevel_h, center.z), rx, rz, sides, angle_off)
	var r_top: Array[Vector3] = make_polygon_ring_y(
		Vector3(center.x, center.y + half_h, center.z),
		maxf(rx - bevel_inset, 0.05),
		maxf(rz - bevel_inset, 0.05),
		sides,
		angle_off
	)
	add_loft(tris, [r_bot, r_mid, r_top], true, true, center)


static func add_beam_segment(
	tris: Array[Array],
	a: Vector3,
	b: Vector3,
	half_w: float,
	half_h: float
) -> void:
	var dir: Vector3 = b - a
	var len: float = dir.length()
	if len < 0.0005:
		return
	var fwd: Vector3 = dir / len
	var up_ref: Vector3 = Vector3.UP if absf(fwd.dot(Vector3.UP)) < 0.94 else Vector3.FORWARD
	var side: Vector3 = fwd.cross(up_ref).normalized()
	var up: Vector3 = side.cross(fwd).normalized()

	var make_ring := func(p: Vector3, w: float, h: float) -> Array[Vector3]:
		return [
			p - side * w - up * h,
			p + side * w - up * h,
			p + side * w + up * h,
			p - side * w + up * h,
		]

	var r0: Array[Vector3] = make_ring.call(a, half_w, half_h)
	var r1: Array[Vector3] = make_ring.call(b, half_w, half_h)
	add_loft(tris, [r0, r1], true, true, (a + b) * 0.5)


static func add_framed_vein(
	crystal_tris: Array[Array],
	chassis_tris: Array[Array],
	a: Vector3,
	b: Vector3,
	half_w: float,
	half_h: float
) -> void:
	# Cuna de tinta oscura ligeramente más ancha/baja para evitar Z-fighting bajo el canal HDR
	add_beam_segment(chassis_tris, a, b, half_w * 1.45, half_h * 0.90)
	add_beam_segment(crystal_tris, a, b, half_w, half_h * 1.15)


static func add_chamfered_polygon_prism(
	tris: Array[Array],
	center: Vector3,
	rx: float,
	rz: float,
	top_y: float,
	bot_y: float,
	bevel_inset: float = 0.25,
	bevel_drop: float = 0.18,
	sides: int = 6,
	angle_off: float = 0.0
) -> void:
	var r_top: Array[Vector3] = make_polygon_ring_y(
		Vector3(center.x, top_y, center.z),
		maxf(rx - bevel_inset, 0.1),
		maxf(rz - bevel_inset, 0.1),
		sides,
		angle_off
	)
	var r_shoulder: Array[Vector3] = make_polygon_ring_y(
		Vector3(center.x, top_y - bevel_drop, center.z),
		rx,
		rz,
		sides,
		angle_off
	)
	var r_waist: Array[Vector3] = make_polygon_ring_y(
		Vector3(center.x, lerpf(top_y - bevel_drop, bot_y, 0.48), center.z),
		rx * 0.86,
		rz * 0.86,
		sides,
		angle_off
	)
	var r_bot: Array[Vector3] = make_polygon_ring_y(
		Vector3(center.x, bot_y, center.z),
		rx * 0.42,
		rz * 0.42,
		sides,
		angle_off
	)
	add_loft(tris, [r_bot, r_waist, r_shoulder, r_top], true, true, Vector3(center.x, (top_y + bot_y) * 0.5, center.z))


static func add_keel_spire(
	tris: Array[Array],
	top_center: Vector3,
	rx: float,
	rz: float,
	depth: float,
	sides: int = 6,
	angle_off: float = 0.0
) -> void:
	var r0: Array[Vector3] = make_polygon_ring_y(top_center, rx, rz, sides, angle_off)
	var r1: Array[Vector3] = make_polygon_ring_y(top_center + Vector3(0.0, -depth * 0.45, 0.0), rx * 0.58, rz * 0.58, sides, angle_off)
	var r2: Array[Vector3] = make_polygon_ring_y(top_center + Vector3(0.0, -depth, 0.0), 0.04, 0.04, sides, angle_off)
	add_loft(tris, [r2, r1, r0], true, true, top_center + Vector3(0.0, -depth * 0.45, 0.0))


static func add_crescent_arc_slab(
	tris: Array[Array],
	center: Vector3,
	inner_r: float,
	outer_r: float,
	start_deg: float,
	end_deg: float,
	top_y: float,
	bot_y: float,
	segments: int = 12
) -> void:
	var segs: int = maxi(segments, 4)
	var a0: float = deg_to_rad(start_deg)
	var a1: float = deg_to_rad(end_deg)
	var bevel_h: float = minf(absf(top_y - bot_y) * 0.28, 0.18)
	var inner_inset: float = minf((outer_r - inner_r) * 0.14, 0.18)
	var slab_center := Vector3(center.x, (top_y + bot_y) * 0.5, center.z)

	for i: int in range(segs):
		var t0: float = float(i) / float(segs)
		var t1: float = float(i + 1) / float(segs)
		var ang0: float = lerpf(a0, a1, t0)
		var ang1: float = lerpf(a0, a1, t1)
		var d0 := Vector3(cos(ang0), 0.0, sin(ang0))
		var d1 := Vector3(cos(ang1), 0.0, sin(ang1))
		var mid_d: Vector3 = (d0 + d1).normalized()
		var seg_center: Vector3 = slab_center + mid_d * ((inner_r + outer_r) * 0.5)

		var bot_ring: Array[Vector3] = [
			center + d0 * (inner_r + 0.16) + Vector3(0.0, bot_y, 0.0),
			center + d0 * (outer_r - 0.18) + Vector3(0.0, bot_y, 0.0),
			center + d1 * (outer_r - 0.18) + Vector3(0.0, bot_y, 0.0),
			center + d1 * (inner_r + 0.16) + Vector3(0.0, bot_y, 0.0),
		]
		var mid_ring: Array[Vector3] = [
			center + d0 * inner_r + Vector3(0.0, top_y - bevel_h, 0.0),
			center + d0 * outer_r + Vector3(0.0, top_y - bevel_h, 0.0),
			center + d1 * outer_r + Vector3(0.0, top_y - bevel_h, 0.0),
			center + d1 * inner_r + Vector3(0.0, top_y - bevel_h, 0.0),
		]
		var top_ring: Array[Vector3] = [
			center + d0 * (inner_r + inner_inset) + Vector3(0.0, top_y, 0.0),
			center + d0 * (outer_r - inner_inset) + Vector3(0.0, top_y, 0.0),
			center + d1 * (outer_r - inner_inset) + Vector3(0.0, top_y, 0.0),
			center + d1 * (inner_r + inner_inset) + Vector3(0.0, top_y, 0.0),
		]
		add_loft(tris, [bot_ring, mid_ring, top_ring], i == 0, i == segs - 1, seg_center)


static func _compute_trim_uv(v: Vector3, fn: Vector3, uv_band: int) -> Vector2:
	if uv_band == SURFACE_CRYSTAL:
		return Vector2((v.x + v.z) * 0.42, clampf(0.925 + fn.y * 0.045, 0.87, 0.98))
	if absf(fn.y) > 0.62:
		return Vector2(v.x * 0.18, clampf(0.20 + v.z * 0.032, 0.03, 0.37))
	var horiz: float = (v.x * 0.34 - v.z * 0.34) if absf(fn.x) > absf(fn.z) else (v.x * 0.34 + v.z * 0.34)
	return Vector2(horiz, clampf(0.55 - v.y * 0.075, 0.42, 0.68))


static func build_flat_polygon_deck_mesh(
	ring_xz: Array[Vector2],
	y: float = 0.012,
	tile_meters: float = 5.5
) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := Vector3.UP
	var tm: float = maxf(tile_meters, 0.5)
	var c_xz := Vector2.ZERO
	for p: Vector2 in ring_xz:
		c_xz += p
	c_xz /= maxf(float(ring_xz.size()), 1.0)

	var c_v := Vector3(c_xz.x, y, c_xz.y)
	var c_uv := Vector2(0.5 + c_xz.x / tm, 0.5 + c_xz.y / tm)
	var count: int = ring_xz.size()
	for i: int in range(count):
		var p0: Vector2 = ring_xz[i]
		var p1: Vector2 = ring_xz[(i + 1) % count]
		var v0 := Vector3(p0.x, y, p0.y)
		var v1 := Vector3(p1.x, y, p1.y)
		var cross_n: Vector3 = (v1 - c_v).cross(v0 - c_v)
		if cross_n.y < 0.0:
			var tmp := v0
			v0 = v1
			v1 = tmp
			var tp := p0
			p0 = p1
			p1 = tp
		st.set_normal(n); st.set_uv(c_uv); st.add_vertex(c_v)
		st.set_normal(n); st.set_uv(Vector2(0.5 + p0.x / tm, 0.5 + p0.y / tm)); st.add_vertex(v0)
		st.set_normal(n); st.set_uv(Vector2(0.5 + p1.x / tm, 0.5 + p1.y / tm)); st.add_vertex(v1)
	st.generate_tangents()
	return st.commit()


static func build_crescent_deck_surface_mesh(
	inner_r: float,
	outer_r: float,
	start_deg: float,
	end_deg: float,
	y: float = 0.012,
	segments: int = 24,
	tile_meters: float = 5.5
) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := Vector3.UP
	var tm: float = maxf(tile_meters, 0.5)
	var segs: int = maxi(segments, 4)
	var a0: float = deg_to_rad(start_deg)
	var a1: float = deg_to_rad(end_deg)
	for i: int in range(segs):
		var ang0: float = lerpf(a0, a1, float(i) / float(segs))
		var ang1: float = lerpf(a0, a1, float(i + 1) / float(segs))
		var p_in0 := Vector2(cos(ang0) * inner_r, sin(ang0) * inner_r)
		var p_out0 := Vector2(cos(ang0) * outer_r, sin(ang0) * outer_r)
		var p_out1 := Vector2(cos(ang1) * outer_r, sin(ang1) * outer_r)
		var p_in1 := Vector2(cos(ang1) * inner_r, sin(ang1) * inner_r)
		var v0 := Vector3(p_in0.x, y, p_in0.y)
		var v1 := Vector3(p_out0.x, y, p_out0.y)
		var v2 := Vector3(p_out1.x, y, p_out1.y)
		var v3 := Vector3(p_in1.x, y, p_in1.y)
		var uv0 := Vector2(0.5 + p_in0.x / tm, 0.5 + p_in0.y / tm)
		var uv1 := Vector2(0.5 + p_out0.x / tm, 0.5 + p_out0.y / tm)
		var uv2 := Vector2(0.5 + p_out1.x / tm, 0.5 + p_out1.y / tm)
		var uv3 := Vector2(0.5 + p_in1.x / tm, 0.5 + p_in1.y / tm)
		# Winding horario +Y: (v2 - v0) x (v1 - v0) apunta hacia +Y
		st.set_normal(n); st.set_uv(uv0); st.add_vertex(v0)
		st.set_normal(n); st.set_uv(uv1); st.add_vertex(v1)
		st.set_normal(n); st.set_uv(uv2); st.add_vertex(v2)
		st.set_normal(n); st.set_uv(uv0); st.add_vertex(v0)
		st.set_normal(n); st.set_uv(uv2); st.add_vertex(v2)
		st.set_normal(n); st.set_uv(uv3); st.add_vertex(v3)
	st.generate_tangents()
	return st.commit()


static func commit_surface(
	mesh: ArrayMesh,
	tris: Array[Array],
	progress_min: float = 0.0,
	progress_max: float = 1.0,
	progress_axis: int = 1,
	uv_band: int = SURFACE_ARMOR
) -> void:
	if tris.is_empty():
		return

	var inv_span: float = 1.0 / maxf(progress_max - progress_min, 0.001)
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
		var tri_uvs: Array[Vector2] = []
		for v: Vector3 in t:
			tri_uvs.append(_compute_trim_uv(v, fn, uv_band))
		# Garantiza UVs no degenerados para generate_tangents() sin warnings
		var uv_area: float = absf((tri_uvs[1] - tri_uvs[0]).cross(tri_uvs[2] - tri_uvs[0]))
		if uv_area < 1e-6:
			tri_uvs[1] += Vector2(0.01, 0.0)
			tri_uvs[2] += Vector2(0.0, 0.01)

		for vi: int in range(3):
			var v: Vector3 = t[vi] as Vector3
			var key := Vector3i(roundi(v.x * 1000.0), roundi(v.y * 1000.0), roundi(v.z * 1000.0))
			var sn: Vector3 = (smooth_acc.get(key, fn) as Vector3).normalized()
			var coord: float = v.y if progress_axis == 1 else (v.x if progress_axis == 0 else v.z)
			var u_prog: float = clampf((coord - progress_min) * inv_span, 0.0, 1.0)
			st.set_normal(fn)
			st.set_color(Color(sn.x * 0.5 + 0.5, sn.y * 0.5 + 0.5, sn.z * 0.5 + 0.5, 1.0))
			st.set_uv(tri_uvs[vi])
			st.set_uv2(Vector2(sn.z, u_prog))
			st.add_vertex(v)

	st.generate_tangents()
	st.commit(mesh)


static func build_three_surface_mesh(
	armor_tris: Array[Array],
	chassis_tris: Array[Array],
	crystal_tris: Array[Array],
	progress_min: float = 0.0,
	progress_max: float = 2.0,
	progress_axis: int = 1
) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	commit_surface(mesh, armor_tris, progress_min, progress_max, progress_axis, SURFACE_ARMOR)
	commit_surface(mesh, chassis_tris, progress_min, progress_max, progress_axis, SURFACE_CHASSIS)
	commit_surface(mesh, crystal_tris, progress_min, progress_max, progress_axis, SURFACE_CRYSTAL)
	return mesh

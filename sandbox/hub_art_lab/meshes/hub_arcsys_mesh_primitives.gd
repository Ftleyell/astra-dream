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


static func commit_surface(
	mesh: ArrayMesh,
	tris: Array[Array],
	progress_min: float = 0.0,
	progress_max: float = 1.0,
	progress_axis: int = 1
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
		for v: Vector3 in t:
			var key := Vector3i(roundi(v.x * 1000.0), roundi(v.y * 1000.0), roundi(v.z * 1000.0))
			var sn: Vector3 = (smooth_acc.get(key, fn) as Vector3).normalized()
			var coord: float = v.y if progress_axis == 1 else (v.x if progress_axis == 0 else v.z)
			var u_prog: float = clampf((coord - progress_min) * inv_span, 0.0, 1.0)
			st.set_normal(fn)
			st.set_uv(Vector2(sn.x, sn.y))
			st.set_uv2(Vector2(sn.z, u_prog))
			st.add_vertex(v)

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
	commit_surface(mesh, armor_tris, progress_min, progress_max, progress_axis)
	commit_surface(mesh, chassis_tris, progress_min, progress_max, progress_axis)
	commit_surface(mesh, crystal_tris, progress_min, progress_max, progress_axis)
	return mesh

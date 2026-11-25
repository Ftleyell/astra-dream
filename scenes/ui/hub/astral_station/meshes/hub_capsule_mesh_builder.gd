class_name HubCapsuleMeshBuilder
extends RefCounted

## Constructor procedural 3D ArcSys para el Santuario Valkiria Astral de la Cápsula Central.
## Estrado escalonado abierto al Sur (+Z) con pilares-ala arqueados en titanio perla + Oro Astral,
## plumas escalonadas y astrolabio sagrado bicírculo detrás de la piloto.

const Primitives = preload("res://scenes/ui/hub/astral_station/meshes/hub_arcsys_mesh_primitives.gd")

static var _cached_base_mesh: ArrayMesh = null
static var _cached_gold_trim_mesh: ArrayMesh = null
static var _cached_dais_surface: ArrayMesh = null
static var _cached_halo_mesh: ArrayMesh = null


static func _v2_lerp_cross(c: Vector3, right: Vector3, up: Vector3, hw: float, hh: float) -> Array[Vector3]:
	return [
		c - right * hw - up * hh,
		c + right * hw - up * hh,
		c + right * hw * 0.78 + up * hh,
		c - right * hw * 0.78 + up * hh,
	]


static func build_capsule_dais_surface_mesh() -> ArrayMesh:
	if _cached_dais_surface != null:
		return _cached_dais_surface
	var ring: Array[Vector2] = []
	var segs: int = 32
	var r: float = 1.88
	for i: int in range(segs):
		var a: float = TAU * float(i) / float(segs)
		ring.append(Vector2(cos(a) * r, sin(a) * r))
	_cached_dais_surface = Primitives.build_flat_polygon_deck_mesh(ring, 0.106, 3.8)
	return _cached_dais_surface


static func build_capsule_base_mesh() -> ArrayMesh:
	if _cached_base_mesh != null:
		return _cached_base_mesh

	var armor_tris: Array[Array] = []
	var chassis_tris: Array[Array] = []
	var crystal_tris: Array[Array] = []

	# 1. Estrado circular Hero Valkyrie (calibrado a capsule_pad_hover_y = 0.112 m)
	Primitives.add_beveled_slab(chassis_tris, Vector3(0.0, 0.025, 0.0), 2.24, 2.24, 0.050, 0.15, 24)
	Primitives.add_beveled_slab(armor_tris, Vector3(0.0, 0.068, 0.0), 2.02, 2.02, 0.044, 0.12, 24)
	Primitives.add_beveled_slab(armor_tris, Vector3(0.0, 0.094, 0.0), 1.62, 1.62, 0.018, 0.06, 24)

	# Anillo luminoso embutido fino en el borde superior del estrado
	var segs: int = 32
	for si: int in range(segs):
		var a0: float = TAU * float(si) / float(segs)
		var a1: float = TAU * float(si + 1) / float(segs)
		var p0 := Vector3(cos(a0) * 1.91, 0.105, sin(a0) * 1.91)
		var p1 := Vector3(cos(a1) * 1.91, 0.105, sin(a1) * 1.91)
		Primitives.add_beam_segment(crystal_tris if si % 4 == 0 else chassis_tris, p0, p1, 0.016, 0.008)

	# 2. Zócalo trasero curvado bajo (reemplaza la vieja viga horizontal a media altura)
	var rear_segs: int = 12
	var rear_rings_ch: Array[Array] = []
	var rear_rings_ar: Array[Array] = []
	for ri: int in range(rear_segs + 1):
		var t: float = float(ri) / float(rear_segs)
		var ang: float = lerpf(-150.0, -30.0, t)
		var rad: float = deg_to_rad(ang)
		var dir_xz := Vector3(cos(rad), 0.0, sin(rad))
		var base_c := dir_xz * 1.88 + Vector3(0.0, 0.14, 0.0)
		rear_rings_ch.append([
			base_c - dir_xz * 0.14 + Vector3(0.0, -0.04, 0.0),
			base_c + dir_xz * 0.16 + Vector3(0.0, -0.04, 0.0),
			base_c + dir_xz * 0.12 + Vector3(0.0, 0.10, 0.0),
			base_c - dir_xz * 0.10 + Vector3(0.0, 0.10, 0.0),
		])
		if ri >= 2 and ri <= rear_segs - 2:
			var ar_c := dir_xz * 1.90 + Vector3(0.0, 0.25, 0.0)
			rear_rings_ar.append([
				ar_c - dir_xz * 0.09 + Vector3(0.0, -0.03, 0.0),
				ar_c + dir_xz * 0.10 + Vector3(0.0, -0.03, 0.0),
				ar_c + dir_xz * 0.06 + Vector3(0.0, 0.05, 0.0),
				ar_c - dir_xz * 0.06 + Vector3(0.0, 0.05, 0.0),
			])
	Primitives.add_loft(chassis_tris, rear_rings_ch, true, true, Vector3(0.0, 0.16, -1.70))
	Primitives.add_loft(armor_tris, rear_rings_ar, true, true, Vector3(0.0, 0.25, -1.78))

	# 3. Pilares-Ala Gemelos del Santuario Valkiria + 3 Plumas Esculpidas por lado
	for side_sign: float in [-1.0, 1.0]:
		var spine_pts: Array[Vector3] = [
			Vector3(side_sign * 1.66, 0.08, -0.78),
			Vector3(side_sign * 1.92, 0.62, -1.04),
			Vector3(side_sign * 1.98, 1.24, -1.24),
			Vector3(side_sign * 1.72, 1.92, -1.36),
			Vector3(side_sign * 1.26, 2.46, -1.42),
			Vector3(side_sign * 0.88, 2.74, -1.44),
		]
		var spine_hw: Array[float] = [0.16, 0.14, 0.125, 0.105, 0.082, 0.052]
		var spine_hh: Array[float] = [0.22, 0.18, 0.155, 0.130, 0.100, 0.065]

		var armor_rings: Array[Array] = []
		var chassis_rings: Array[Array] = []
		for pi: int in range(spine_pts.size()):
			var p: Vector3 = spine_pts[pi]
			var tangent: Vector3
			if pi == 0:
				tangent = (spine_pts[1] - spine_pts[0]).normalized()
			elif pi == spine_pts.size() - 1:
				tangent = (spine_pts[pi] - spine_pts[pi - 1]).normalized()
			else:
				tangent = (spine_pts[pi + 1] - spine_pts[pi - 1]).normalized()
			var right: Vector3 = tangent.cross(Vector3.FORWARD).normalized()
			var depth_dir: Vector3 = right.cross(tangent).normalized()
			armor_rings.append(_v2_lerp_cross(p, right, depth_dir, spine_hw[pi], spine_hh[pi]))
			chassis_rings.append(_v2_lerp_cross(
				p + depth_dir * (spine_hh[pi] * 0.42),
				right,
				depth_dir,
				spine_hw[pi] * 0.72,
				spine_hh[pi] * 0.68
			))

		var wing_center := Vector3(side_sign * 1.60, 1.35, -1.24)
		Primitives.add_loft(armor_tris, armor_rings, true, true, wing_center)
		Primitives.add_loft(chassis_tris, chassis_rings, true, true, wing_center + Vector3(0.0, 0.0, -0.10))

		# Vena luminosa fina embutida por el canto interno del arco
		for vi: int in range(spine_pts.size() - 1):
			var va: Vector3 = spine_pts[vi] + Vector3(-side_sign * (spine_hw[vi] * 0.65), 0.0, 0.05)
			var vb: Vector3 = spine_pts[vi + 1] + Vector3(-side_sign * (spine_hw[vi + 1] * 0.65), 0.0, 0.05)
			Primitives.add_beam_segment(crystal_tris, va, vb, 0.015, 0.010)

		# 3 Plumas Valkiria escalonadas saliendo hacia el Cosmos
		var feather_specs: Array[Array] = [
			[Vector3(side_sign * 1.94, 0.88, -1.14), Vector3(side_sign * 2.52, 1.24, -1.28), 0.11, 0.036],
			[Vector3(side_sign * 1.88, 1.38, -1.26), Vector3(side_sign * 2.66, 1.88, -1.40), 0.125, 0.040],
			[Vector3(side_sign * 1.64, 1.88, -1.36), Vector3(side_sign * 2.34, 2.48, -1.48), 0.105, 0.034],
		]
		for fs: Array in feather_specs:
			var f_root: Vector3 = fs[0] as Vector3
			var f_tip: Vector3 = fs[1] as Vector3
			var f_w: float = float(fs[2])
			var f_h: float = float(fs[3])
			var f_mid: Vector3 = f_root.lerp(f_tip, 0.56)
			var r_b := [
				f_root + Vector3(0.0, -f_h, -f_w),
				f_root + Vector3(0.0, f_h, -f_w * 0.7),
				f_root + Vector3(0.0, f_h, f_w * 0.7),
				f_root + Vector3(0.0, -f_h, f_w),
			]
			var r_m := [
				f_mid + Vector3(0.0, -f_h * 0.75, -f_w * 0.85),
				f_mid + Vector3(0.0, f_h * 0.85, -f_w * 0.45),
				f_mid + Vector3(0.0, f_h * 0.85, f_w * 0.45),
				f_mid + Vector3(0.0, -f_h * 0.75, f_w * 0.85),
			]
			var r_t := [
				f_tip + Vector3(0.0, -f_h * 0.25, -f_w * 0.22),
				f_tip + Vector3(0.0, f_h * 0.30, -f_w * 0.12),
				f_tip + Vector3(0.0, f_h * 0.30, f_w * 0.12),
				f_tip + Vector3(0.0, -f_h * 0.25, f_w * 0.22),
			]
			var fc: Vector3 = (f_root + f_tip) * 0.5
			Primitives.add_loft(armor_tris, [r_b, r_m, r_t], true, true, fc)
			Primitives.add_beam_segment(crystal_tris, f_root.lerp(f_tip, 0.15) + Vector3(0.0, f_h * 0.75, 0.0), f_root.lerp(f_tip, 0.78) + Vector3(0.0, f_h * 0.55, 0.0), 0.012, 0.008)

	_cached_base_mesh = Primitives.build_three_surface_mesh(armor_tris, chassis_tris, crystal_tris, 0.0, 2.80, 1)
	return _cached_base_mesh


static func build_capsule_gold_trim_mesh() -> ArrayMesh:
	if _cached_gold_trim_mesh != null:
		return _cached_gold_trim_mesh

	var armor_tris: Array[Array] = []
	var chassis_tris: Array[Array] = []
	var crystal_tris: Array[Array] = []

	# 1. Collarín dorado discontinuo en los arcos trasero y laterales del estrado (entrada Sur abierta)
	var rim_segs: int = 32
	for si: int in range(rim_segs):
		var a0: float = TAU * float(si) / float(rim_segs)
		var a1: float = TAU * float(si + 1) / float(rim_segs)
		var mid_a: float = (a0 + a1) * 0.5
		if sin(mid_a) > 0.55:
			continue
		var p0 := Vector3(cos(a0) * 2.04, 0.088, sin(a0) * 2.04)
		var p1 := Vector3(cos(a1) * 2.04, 0.088, sin(a1) * 2.04)
		Primitives.add_beam_segment(armor_tris, p0, p1, 0.038, 0.018)

	# 2. Filigranas doradas de los pilares-ala + remates en corona + abrazaderas de plumas
	for side_sign: float in [-1.0, 1.0]:
		var gold_curve: Array[Vector3] = [
			Vector3(side_sign * 1.54, 0.12, -0.74),
			Vector3(side_sign * 1.78, 0.64, -1.00),
			Vector3(side_sign * 1.84, 1.24, -1.19),
			Vector3(side_sign * 1.60, 1.92, -1.31),
			Vector3(side_sign * 1.16, 2.46, -1.37),
			Vector3(side_sign * 0.82, 2.78, -1.40),
		]
		for gi: int in range(gold_curve.size() - 1):
			Primitives.add_beam_segment(armor_tris, gold_curve[gi], gold_curve[gi + 1], 0.032, 0.024)

		# Remate corona en punta superior + abrazadera base
		Primitives.add_beveled_slab(chassis_tris, Vector3(side_sign * 1.66, 0.11, -0.78), 0.24, 0.28, 0.07, 0.05, 8)
		Primitives.add_beveled_slab(armor_tris, Vector3(side_sign * 1.66, 0.16, -0.78), 0.19, 0.23, 0.045, 0.04, 8)
		var crown_r := [
			Vector3(side_sign * 0.86, 2.70, -1.44) + Vector3(-0.07, 0.0, -0.08),
			Vector3(side_sign * 0.86, 2.70, -1.44) + Vector3(0.07, 0.0, -0.08),
			Vector3(side_sign * 0.86, 2.70, -1.44) + Vector3(0.07, 0.0, 0.08),
			Vector3(side_sign * 0.86, 2.70, -1.44) + Vector3(-0.07, 0.0, 0.08),
		]
		var crown_top := [
			Vector3(side_sign * 0.68, 2.94, -1.45) + Vector3(-0.02, 0.0, -0.02),
			Vector3(side_sign * 0.68, 2.94, -1.45) + Vector3(0.02, 0.0, -0.02),
			Vector3(side_sign * 0.68, 2.94, -1.45) + Vector3(0.02, 0.0, 0.02),
			Vector3(side_sign * 0.68, 2.94, -1.45) + Vector3(-0.02, 0.0, 0.02),
		]
		Primitives.add_loft(armor_tris, [crown_r, crown_top], true, true, Vector3(side_sign * 0.78, 2.82, -1.44))
		Primitives.add_beveled_slab(crystal_tris, Vector3(side_sign * 1.88, 1.24, -1.19), 0.045, 0.045, 0.14, 0.015, 6)

	_cached_gold_trim_mesh = Primitives.build_three_surface_mesh(armor_tris, chassis_tris, crystal_tris, 0.0, 2.95, 1)
	return _cached_gold_trim_mesh


static func build_capsule_halo_mesh() -> ArrayMesh:
	if _cached_halo_mesh != null:
		return _cached_halo_mesh

	var armor_tris: Array[Array] = []
	var chassis_tris: Array[Array] = []
	var crystal_tris: Array[Array] = []

	# Astrolabio Sagrado bicírculo biselado (64 segmentos suaves, sin palos sobresaliendo hacia afuera)
	var segments: int = 64
	var r_outer: float = 1.24
	var r_energy: float = 1.10
	var r_inner: float = 0.96

	var ring_out_front: Array[Vector3] = []
	var ring_out_back: Array[Vector3] = []
	var ring_out_in_f: Array[Vector3] = []
	var ring_out_in_b: Array[Vector3] = []

	for i: int in range(segments):
		var a0: float = TAU * float(i) / float(segments)
		var a1: float = TAU * float(i + 1) / float(segments)
		var c0 := Vector3(cos(a0), sin(a0), 0.0)
		var c1 := Vector3(cos(a1), sin(a1), 0.0)

		# Aro exterior dorado continuo sin costuras de viga
		var ro_a: Array[Vector3] = [
			c0 * (r_outer - 0.026) + Vector3(0.0, 0.0, -0.020),
			c0 * (r_outer + 0.026) + Vector3(0.0, 0.0, -0.014),
			c0 * (r_outer + 0.026) + Vector3(0.0, 0.0, 0.014),
			c0 * (r_outer - 0.026) + Vector3(0.0, 0.0, 0.020),
		]
		var ro_b: Array[Vector3] = [
			c1 * (r_outer - 0.026) + Vector3(0.0, 0.0, -0.020),
			c1 * (r_outer + 0.026) + Vector3(0.0, 0.0, -0.014),
			c1 * (r_outer + 0.026) + Vector3(0.0, 0.0, 0.014),
			c1 * (r_outer - 0.026) + Vector3(0.0, 0.0, 0.020),
		]
		Primitives.add_loft(armor_tris, [ro_a, ro_b], false, false, (c0 + c1) * (r_outer * 0.5))

		# Aro interior oscuro de chasis
		var ri_a: Array[Vector3] = [
			c0 * (r_inner - 0.020) + Vector3(0.0, 0.0, -0.016),
			c0 * (r_inner + 0.020) + Vector3(0.0, 0.0, -0.012),
			c0 * (r_inner + 0.020) + Vector3(0.0, 0.0, 0.012),
			c0 * (r_inner - 0.020) + Vector3(0.0, 0.0, 0.016),
		]
		var ri_b: Array[Vector3] = [
			c1 * (r_inner - 0.020) + Vector3(0.0, 0.0, -0.016),
			c1 * (r_inner + 0.020) + Vector3(0.0, 0.0, -0.012),
			c1 * (r_inner + 0.020) + Vector3(0.0, 0.0, 0.012),
			c1 * (r_inner - 0.020) + Vector3(0.0, 0.0, 0.016),
		]
		Primitives.add_loft(chassis_tris, [ri_a, ri_b], false, false, (c0 + c1) * (r_inner * 0.5))

		# Filamento de energía continuo entre ambos aros
		Primitives.add_beam_segment(crystal_tris, c0 * r_energy, c1 * r_energy, 0.011, 0.009)

	# 8 nodos diamante embutidos ESTRICTAMENTE entre r_inner y r_outer (cero palos salientes)
	for ci: int in range(8):
		var a: float = float(ci) * (PI * 0.25)
		var radial := Vector3(cos(a), sin(a), 0.0)
		var tang := Vector3(-sin(a), cos(a), 0.0)
		var is_cardinal: bool = ((ci % 2) == 0)
		var w_dia: float = 0.048 if is_cardinal else 0.032
		var c_pos: Vector3 = radial * r_energy
		var diamond_center: Array[Vector3] = [
			c_pos + radial * 0.115,
			c_pos + tang * w_dia + Vector3(0.0, 0.0, 0.022),
			c_pos - radial * 0.115,
			c_pos - tang * w_dia + Vector3(0.0, 0.0, 0.022),
		]
		var diamond_back: Array[Vector3] = [
			c_pos + radial * 0.115,
			c_pos + tang * w_dia + Vector3(0.0, 0.0, -0.022),
			c_pos - radial * 0.115,
			c_pos - tang * w_dia + Vector3(0.0, 0.0, -0.022),
		]
		Primitives.add_loft(armor_tris if is_cardinal else chassis_tris, [diamond_back, diamond_center], true, true, c_pos)

	ring_out_front.clear()
	ring_out_back.clear()
	ring_out_in_f.clear()
	ring_out_in_b.clear()

	_cached_halo_mesh = Primitives.build_three_surface_mesh(armor_tris, chassis_tris, crystal_tris, -1.30, 1.30, 0)
	return _cached_halo_mesh

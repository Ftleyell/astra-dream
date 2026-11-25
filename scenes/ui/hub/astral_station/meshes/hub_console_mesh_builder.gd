class_name HubConsoleMeshBuilder
extends RefCounted

## Constructor procedural 3D ArcSys para las Consolas Modulares de la Antesala de Loadout.
## Diseñadas para lucir limpias tanto en CALIBRATING (apagado/ámbar) como en ONLINE (HDR + prisma).

const Primitives = preload("res://scenes/ui/hub/astral_station/meshes/hub_arcsys_mesh_primitives.gd")

static var _cached_console_mesh: ArrayMesh = null
static var _cached_prism_mesh: ArrayMesh = null
static var _cached_station_bodies: Dictionary = {}
static var _cached_station_holos: Dictionary = {}


static func build_station_body_mesh(station_id: StringName) -> ArrayMesh:
	if _cached_station_bodies.has(station_id):
		return _cached_station_bodies[station_id] as ArrayMesh

	var mesh: ArrayMesh = null
	match station_id:
		&"skins_mirror":
			mesh = _build_skins_mirror_body()
		&"talents_nexus":
			mesh = _build_talents_nexus_body()
		&"companions_projector":
			mesh = _build_companions_projector_body()
		&"tactical_console":
			mesh = _build_tactical_wartable_body()
		_:
			mesh = build_console_body_mesh()
	_cached_station_bodies[station_id] = mesh
	return mesh


static func build_station_holo_mesh(station_id: StringName) -> ArrayMesh:
	if _cached_station_holos.has(station_id):
		return _cached_station_holos[station_id] as ArrayMesh

	var mesh: ArrayMesh = null
	match station_id:
		&"skins_mirror":
			mesh = _build_skins_mirror_holo()
		&"talents_nexus":
			mesh = _build_talents_nexus_holo()
		&"companions_projector":
			mesh = _build_companions_holo()
		&"tactical_console":
			mesh = _build_tactical_holo()
		_:
			mesh = build_console_holo_prism_mesh()
	_cached_station_holos[station_id] = mesh
	return mesh


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


static func _build_skins_mirror_body() -> ArrayMesh:
	var armor_tris: Array[Array] = []
	var chassis_tris: Array[Array] = []
	var crystal_tris: Array[Array] = []

	# Pasarela-Observatorio Abierta para Spotlight de Skins (perfil ultra bajo, 100% Cosmos detrás de la piloto)
	Primitives.add_beveled_slab(chassis_tris, Vector3(0.0, 0.035, 0.0), 1.32, 1.32, 0.07, 0.09, 16)
	Primitives.add_beveled_slab(armor_tris, Vector3(0.0, 0.080, 0.0), 1.16, 1.16, 0.036, 0.06, 16)

	var ring_segs: int = 24
	for i: int in range(ring_segs):
		var a0: float = TAU * float(i) / float(ring_segs)
		var a1: float = TAU * float(i + 1) / float(ring_segs)
		Primitives.add_beam_segment(
			crystal_tris,
			Vector3(cos(a0) * 1.10, 0.098, sin(a0) * 1.10),
			Vector3(cos(a1) * 1.10, 0.098, sin(a1) * 1.10),
			0.018,
			0.008
		)

	# 2 proyectores Spotlight + bolardos prismáticos bajos flanqueando la tarima (perfil <= 0.52 m, Cosmos 100% libre detrás)
	for side_sign: float in [-1.0, 1.0]:
		var lamp_base := Vector3(side_sign * 1.68, 0.10, 0.55)
		Primitives.add_beveled_slab(chassis_tris, lamp_base, 0.24, 0.28, 0.20, 0.05, 6)
		Primitives.add_beveled_slab(armor_tris, lamp_base + Vector3(0.0, 0.13, -0.04), 0.16, 0.18, 0.10, 0.04, 6)
		Primitives.add_framed_vein(
			crystal_tris,
			chassis_tris,
			Vector3(side_sign * 1.56, 0.20, 0.42),
			Vector3(side_sign * 1.18, 0.11, 0.12),
			0.022,
			0.014
		)

		var bollard_base := Vector3(side_sign * 2.32, 0.0, -0.82)
		var bol_rings: Array[Array] = [
			Primitives.make_box_ring(bollard_base.x, 0.0, bollard_base.z, 0.15, 0.15),
			Primitives.make_box_ring(bollard_base.x, 0.48, bollard_base.z, 0.09, 0.09),
		]
		Primitives.add_loft(armor_tris, bol_rings, true, true, bollard_base + Vector3(0.0, 0.24, 0.0))
		Primitives.add_beveled_slab(crystal_tris, bollard_base + Vector3(0.0, 0.52, 0.0), 0.09, 0.09, 0.07, 0.025, 6)

	# Barandilla trasera baja de media luna (h <= 0.22 m) para destacar la silueta ante el Cosmos
	for bi: int in range(8):
		var b0: float = deg_to_rad(lerpf(-140.0, -40.0, float(bi) / 8.0))
		var b1: float = deg_to_rad(lerpf(-140.0, -40.0, float(bi + 1) / 8.0))
		var p0 := Vector3(cos(b0) * 1.52, 0.16, sin(b0) * 1.52)
		var p1 := Vector3(cos(b1) * 1.52, 0.16, sin(b1) * 1.52)
		Primitives.add_beam_segment(armor_tris, p0, p1, 0.038, 0.024)
		Primitives.add_beam_segment(crystal_tris, p0 + Vector3(0.0, 0.032, 0.0), p1 + Vector3(0.0, 0.032, 0.0), 0.014, 0.010)

	return Primitives.build_three_surface_mesh(armor_tris, chassis_tris, crystal_tris, 0.0, 0.45, 1)


static func _build_talents_nexus_body() -> ArrayMesh:
	var armor_tris: Array[Array] = []
	var chassis_tris: Array[Array] = []
	var crystal_tris: Array[Array] = []

	# 4 pilares inclinados anclados alrededor de la abertura calada Sur (r = 1.72) sosteniendo la Constelación Neural
	for ci: int in range(4):
		var a: float = PI / 4.0 + float(ci) * (PI * 0.5)
		var dx: float = cos(a)
		var dz: float = sin(a)
		var claw_rings: Array[Array] = [
			Primitives.make_box_ring(dx * 1.88, 0.02, dz * 1.88, 0.14, 0.14),
			Primitives.make_box_ring(dx * 1.72, 0.56, dz * 1.72, 0.10, 0.10),
			Primitives.make_box_ring(dx * 1.38, 0.96, dz * 1.38, 0.06, 0.06),
		]
		Primitives.add_loft(armor_tris, claw_rings, true, true, Vector3(dx * 1.66, 0.48, dz * 1.66))
		Primitives.add_framed_vein(
			crystal_tris,
			chassis_tris,
			Vector3(dx * 1.84, 0.10, dz * 1.84),
			Vector3(dx * 1.40, 0.94, dz * 1.40),
			0.024,
			0.016
		)

	return Primitives.build_three_surface_mesh(armor_tris, chassis_tris, crystal_tris, 0.0, 1.05, 1)


static func _build_companions_projector_body() -> ArrayMesh:
	var armor_tris: Array[Array] = []
	var chassis_tris: Array[Array] = []
	var crystal_tris: Array[Array] = []

	# Pedestal parabólico de Holocomunicaciones (plato emisor + antenas laterales)
	Primitives.add_beveled_slab(chassis_tris, Vector3(0.0, 0.05, 0.0), 0.78, 0.68, 0.10, 0.08, 8)
	Primitives.add_beveled_slab(armor_tris, Vector3(0.0, 0.14, 0.0), 0.64, 0.54, 0.08, 0.07, 8)

	var stem_rings: Array[Array] = [
		Primitives.make_box_ring(0.0, 0.18, -0.06, 0.20, 0.18),
		Primitives.make_box_ring(0.0, 0.96, -0.14, 0.16, 0.15),
		Primitives.make_box_ring(0.0, 1.24, -0.02, 0.56, 0.36),
	]
	Primitives.add_loft(chassis_tris, stem_rings, true, true, Vector3(0.0, 0.72, -0.06))
	Primitives.add_beveled_slab(armor_tris, Vector3(0.0, 1.28, 0.02), 0.54, 0.38, 0.06, 0.08, 8)

	for side_sign: float in [-1.0, 1.0]:
		var ant_rings: Array[Array] = [
			Primitives.make_box_ring(side_sign * 0.44, 1.18, -0.12, 0.05, 0.07),
			Primitives.make_box_ring(side_sign * 0.58, 2.02, -0.18, 0.024, 0.036),
		]
		Primitives.add_loft(armor_tris, ant_rings, true, true, Vector3(side_sign * 0.51, 1.60, -0.15))
		Primitives.add_framed_vein(crystal_tris, chassis_tris, Vector3(side_sign * 0.40, 1.24, -0.08), Vector3(side_sign * 0.56, 1.98, -0.14), 0.020, 0.014)

	Primitives.add_beveled_slab(crystal_tris, Vector3(0.0, 1.34, 0.02), 0.34, 0.24, 0.03, 0.03, 8)
	return Primitives.build_three_surface_mesh(armor_tris, chassis_tris, crystal_tris, 0.0, 2.06, 1)


static func _build_tactical_wartable_body() -> ArrayMesh:
	var armor_tris: Array[Array] = []
	var chassis_tris: Array[Array] = []
	var crystal_tris: Array[Array] = []

	# Mesa táctica / War-Table ancha para carta estelar (ancho = 1.56 m)
	Primitives.add_beveled_slab(chassis_tris, Vector3(0.0, 0.05, 0.0), 0.96, 0.68, 0.10, 0.09, 8)
	Primitives.add_beveled_slab(armor_tris, Vector3(0.0, 0.14, 0.0), 0.82, 0.56, 0.08, 0.07, 8)

	var base_col: Array[Array] = [
		Primitives.make_box_ring(0.0, 0.18, 0.0, 0.42, 0.24),
		Primitives.make_box_ring(0.0, 0.92, -0.02, 0.32, 0.20),
		Primitives.make_box_ring(0.0, 1.10, 0.0, 0.78, 0.44),
	]
	Primitives.add_loft(chassis_tris, base_col, true, true, Vector3(0.0, 0.64, 0.0))

	# Tablero blindado ancho + cubeta holográfica
	Primitives.add_beveled_slab(armor_tris, Vector3(0.0, 1.14, 0.0), 0.82, 0.48, 0.08, 0.08, 8)
	Primitives.add_beveled_slab(chassis_tris, Vector3(0.0, 1.19, 0.0), 0.62, 0.32, 0.025, 0.04, 8)
	Primitives.add_framed_vein(crystal_tris, chassis_tris, Vector3(-0.68, 1.16, 0.40), Vector3(0.68, 1.16, 0.40), 0.026, 0.018)

	for side_sign: float in [-1.0, 1.0]:
		Primitives.add_box(armor_tris, Vector3(side_sign * 0.82, 1.06, -0.02), Vector3(0.08, 0.12, 0.34))
		Primitives.add_framed_vein(crystal_tris, chassis_tris, Vector3(side_sign * 0.38, 0.24, 0.22), Vector3(side_sign * 0.72, 1.06, 0.22), 0.024, 0.016)

	return Primitives.build_three_surface_mesh(armor_tris, chassis_tris, crystal_tris, 0.0, 1.24, 1)


static func _build_skins_mirror_holo() -> ArrayMesh:
	var armor_tris: Array[Array] = []
	var chassis_tris: Array[Array] = []
	var crystal_tris: Array[Array] = []
	var r0: Array[Vector3] = Primitives.make_polygon_ring_y(Vector3(0.0, -0.18, 0.0), 0.012, 0.012, 6, 0.0)
	var r1: Array[Vector3] = Primitives.make_polygon_ring_y(Vector3(0.0, 0.0, 0.0), 0.13, 0.06, 6, 0.0)
	var r2: Array[Vector3] = Primitives.make_polygon_ring_y(Vector3(0.0, 0.18, 0.0), 0.012, 0.012, 6, 0.0)
	Primitives.add_loft(crystal_tris, [r0, r1, r2], true, true, Vector3.ZERO)
	Primitives.add_beveled_slab(armor_tris, Vector3(0.0, -0.22, 0.0), 0.12, 0.10, 0.03, 0.02, 6)
	Primitives.add_box(chassis_tris, Vector3(0.0, -0.24, 0.0), Vector3(0.06, 0.015, 0.06))
	return Primitives.build_three_surface_mesh(armor_tris, chassis_tris, crystal_tris, -0.24, 0.24, 1)


static func _build_talents_nexus_holo() -> ArrayMesh:
	var armor_tris: Array[Array] = []
	var chassis_tris: Array[Array] = []
	var crystal_tris: Array[Array] = []
	# Núcleo de Sinapsis Neural octogonal + 3 anillos giroscópicos anidados flotando sobre el vacío Sur
	var r0: Array[Vector3] = Primitives.make_polygon_ring_y(Vector3(0.0, -0.34, 0.0), 0.02, 0.02, 8, 0.0)
	var r1: Array[Vector3] = Primitives.make_polygon_ring_y(Vector3(0.0, 0.0, 0.0), 0.26, 0.26, 8, 0.0)
	var r2: Array[Vector3] = Primitives.make_polygon_ring_y(Vector3(0.0, 0.34, 0.0), 0.02, 0.02, 8, 0.0)
	Primitives.add_loft(crystal_tris, [r0, r1, r2], true, true, Vector3.ZERO)

	var ring_specs: Array[Array] = [
		[1.18, 22.0, armor_tris, 0.026],
		[0.86, -34.0, chassis_tris, 0.022],
		[0.54, 48.0, crystal_tris, 0.018],
	]
	for rs: Array in ring_specs:
		var segs: int = 24
		var rad: float = float(rs[0])
		var tilt: float = deg_to_rad(float(rs[1]))
		var target_tris: Array[Array] = rs[2] as Array[Array]
		var bw: float = float(rs[3])
		for i: int in range(segs):
			var a0: float = TAU * float(i) / float(segs)
			var a1: float = TAU * float(i + 1) / float(segs)
			var v0 := Vector3(cos(a0) * rad, 0.0, sin(a0) * rad)
			var v1 := Vector3(cos(a1) * rad, 0.0, sin(a1) * rad)
			var p0 := Vector3(v0.x, v0.y * cos(tilt) - v0.z * sin(tilt), v0.y * sin(tilt) + v0.z * cos(tilt))
			var p1 := Vector3(v1.x, v1.y * cos(tilt) - v1.z * sin(tilt), v1.y * sin(tilt) + v1.z * cos(tilt))
			Primitives.add_beam_segment(target_tris, p0, p1, bw, bw * 0.75)

	# 8 nodos-estrella luminosos en constelación alrededor del vacío Sur + filamentos sinápticos
	for ni: int in range(8):
		var a: float = TAU * float(ni) / 8.0
		var ny: float = sin(float(ni) * 1.57) * 0.36 + 0.10
		var star_p := Vector3(cos(a) * 1.44, ny, sin(a) * 1.44)
		Primitives.add_beveled_slab(crystal_tris, star_p, 0.09, 0.09, 0.12, 0.03, 6)
		Primitives.add_beam_segment(chassis_tris, star_p * 0.55, star_p, 0.009, 0.006)
	return Primitives.build_three_surface_mesh(armor_tris, chassis_tris, crystal_tris, -1.55, 1.55, 1)


static func _build_companions_holo() -> ArrayMesh:
	return build_console_holo_prism_mesh()


static func _build_tactical_holo() -> ArrayMesh:
	var armor_tris: Array[Array] = []
	var chassis_tris: Array[Array] = []
	var crystal_tris: Array[Array] = []
	var segs: int = 12
	for i: int in range(segs):
		var a0: float = TAU * float(i) / float(segs)
		var a1: float = TAU * float(i + 1) / float(segs)
		Primitives.add_beam_segment(armor_tris, Vector3(cos(a0) * 0.26, 0.0, sin(a0) * 0.26), Vector3(cos(a1) * 0.26, 0.0, sin(a1) * 0.26), 0.014, 0.010)
		Primitives.add_beam_segment(chassis_tris, Vector3(cos(a0) * 0.16, 0.05, sin(a0) * 0.16), Vector3(cos(a1) * 0.16, 0.05, sin(a1) * 0.16), 0.011, 0.008)
	Primitives.add_beveled_slab(crystal_tris, Vector3(0.0, 0.04, 0.0), 0.08, 0.08, 0.22, 0.03, 4)
	return Primitives.build_three_surface_mesh(armor_tris, chassis_tris, crystal_tris, -0.15, 0.18, 1)

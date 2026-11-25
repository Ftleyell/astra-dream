class_name HubEastWingMeshBuilder
extends RefCounted

## Constructor procedural 3D ArcSys para el Ala Este Psycho-Pop Neón:
## - Tótem de Telemetría (monolito vertical para pantalla holográfica de Récords)
## - Pads antigravedad de Lounge de Mascotas (discos octogonales flotantes)

const Primitives = preload("res://scenes/ui/hub/astral_station/meshes/hub_arcsys_mesh_primitives.gd")

static var _cached_telemetry_totem: ArrayMesh = null
static var _cached_pet_lounge_pad: ArrayMesh = null


static func build_telemetry_totem_mesh() -> ArrayMesh:
	if _cached_telemetry_totem != null:
		return _cached_telemetry_totem

	var armor_tris: Array[Array] = []
	var chassis_tris: Array[Array] = []
	var crystal_tris: Array[Array] = []

	# Base octogonal anclada al piso
	Primitives.add_beveled_slab(chassis_tris, Vector3(0.0, 0.08, 0.0), 0.96, 0.78, 0.16, 0.10, 8)
	Primitives.add_beveled_slab(armor_tris, Vector3(0.0, 0.21, 0.0), 0.80, 0.64, 0.10, 0.08, 8)

	# Columna monolítica principal biselada (y = 0.24 .. 2.75)
	var body_rings: Array[Array] = [
		Primitives.make_box_ring(0.0, 0.24, -0.06, 0.56, 0.30),
		Primitives.make_box_ring(0.0, 1.35, -0.08, 0.50, 0.26),
		Primitives.make_box_ring(0.0, 2.55, -0.10, 0.44, 0.22),
		Primitives.make_box_ring(0.0, 2.82, -0.10, 0.28, 0.16),
	]
	Primitives.add_loft(chassis_tris, body_rings, true, true, Vector3(0.0, 1.48, -0.08))

	# Flancos blindados estilo Psycho-Pop en ambos costados
	for side_sign: float in [-1.0, 1.0]:
		var fin_rings: Array[Array] = [
			Primitives.make_box_ring(side_sign * 0.64, 0.30, -0.02, 0.12, 0.24),
			Primitives.make_box_ring(side_sign * 0.72, 1.45, -0.04, 0.10, 0.20),
			Primitives.make_box_ring(side_sign * 0.58, 2.58, -0.08, 0.08, 0.14),
		]
		Primitives.add_loft(armor_tris, fin_rings, true, true, Vector3(side_sign * 0.65, 1.45, -0.04))

		# Vena vertical luminosa
		Primitives.add_framed_vein(
			crystal_tris,
			chassis_tris,
			Vector3(side_sign * 0.54, 0.38, 0.16),
			Vector3(side_sign * 0.48, 2.50, 0.12),
			0.028,
			0.020
		)

	# Visera superior y corona de antena telemétrica
	Primitives.add_box(armor_tris, Vector3(0.0, 2.66, 0.06), Vector3(0.56, 0.07, 0.22))
	Primitives.add_framed_vein(
		crystal_tris,
		chassis_tris,
		Vector3(-0.48, 2.74, 0.16),
		Vector3(0.48, 2.74, 0.16),
		0.024,
		0.018
	)
	Primitives.add_beveled_slab(crystal_tris, Vector3(0.0, 2.94, -0.10), 0.14, 0.14, 0.22, 0.06, 4)

	_cached_telemetry_totem = Primitives.build_three_surface_mesh(armor_tris, chassis_tris, crystal_tris, 0.0, 3.05, 1)
	return _cached_telemetry_totem


static func build_pet_lounge_pad_mesh() -> ArrayMesh:
	if _cached_pet_lounge_pad != null:
		return _cached_pet_lounge_pad

	var armor_tris: Array[Array] = []
	var chassis_tris: Array[Array] = []
	var crystal_tris: Array[Array] = []

	# Base circular limpia de 12 lados y perfil bajo
	Primitives.add_beveled_slab(chassis_tris, Vector3(0.0, 0.032, 0.0), 0.70, 0.70, 0.064, 0.08, 12)
	Primitives.add_beveled_slab(armor_tris, Vector3(0.0, 0.072, 0.0), 0.56, 0.56, 0.032, 0.05, 12)
	Primitives.add_beveled_slab(chassis_tris, Vector3(0.0, 0.088, 0.0), 0.40, 0.40, 0.014, 0.03, 12)

	# Aro perimetral discreto de estado
	var segs: int = 12
	for i: int in range(segs):
		var a0: float = TAU * float(i) / float(segs)
		var a1: float = TAU * float(i + 1) / float(segs)
		var p0 := Vector3(cos(a0) * 0.48, 0.092, sin(a0) * 0.48)
		var p1 := Vector3(cos(a1) * 0.48, 0.092, sin(a1) * 0.48)
		Primitives.add_beam_segment(crystal_tris, p0, p1, 0.014, 0.008)

	_cached_pet_lounge_pad = Primitives.build_three_surface_mesh(armor_tris, chassis_tris, crystal_tris, 0.0, 0.22, 1)
	return _cached_pet_lounge_pad

class_name HubWestSanctuaryMeshBuilder
extends RefCounted

## Constructor procedural 3D ArcSys para el Ala Oeste — Santuario Ceremonial Oscuro:
## - Pedestal octogonal de pizarra índigo (#101324) + energía Materia Oscura (#BF00FF)
## - 5 Reliquias Cristalinas diferenciadas para los 5 trofeos canónicos
## - Anillos orbitales secundarios para escalado visual según maestría (Nv. 2 / Nv. 3+)

const Primitives = preload("res://scenes/ui/hub/astral_station/meshes/hub_arcsys_mesh_primitives.gd")

static var _cached_pedestal: ArrayMesh = null
static var _cached_artifacts: Dictionary = {}
static var _cached_orbit_rings: Dictionary = {}


static func build_relic_pedestal_mesh() -> ArrayMesh:
	if _cached_pedestal != null:
		return _cached_pedestal

	var armor_tris: Array[Array] = []
	var chassis_tris: Array[Array] = []
	var crystal_tris: Array[Array] = []

	# Zócalo ceremonial octogonal escalonado
	Primitives.add_beveled_slab(chassis_tris, Vector3(0.0, 0.07, 0.0), 0.72, 0.72, 0.14, 0.09, 8)
	Primitives.add_beveled_slab(armor_tris, Vector3(0.0, 0.18, 0.0), 0.56, 0.56, 0.08, 0.06, 8)

	# Pilar central cónico octogonal
	var shaft_rings: Array[Array] = [
		Primitives.make_polygon_ring_y(Vector3(0.0, 0.22, 0.0), 0.44, 0.44, 8, PI / 8.0),
		Primitives.make_polygon_ring_y(Vector3(0.0, 0.56, 0.0), 0.34, 0.34, 8, PI / 8.0),
		Primitives.make_polygon_ring_y(Vector3(0.0, 0.78, 0.0), 0.42, 0.42, 8, PI / 8.0),
	]
	Primitives.add_loft(chassis_tris, shaft_rings, true, true, Vector3(0.0, 0.50, 0.0))

	# Capitel superior en armadura + cuna de cristal
	Primitives.add_beveled_slab(armor_tris, Vector3(0.0, 0.83, 0.0), 0.48, 0.48, 0.09, 0.06, 8)
	Primitives.add_beveled_slab(crystal_tris, Vector3(0.0, 0.89, 0.0), 0.28, 0.28, 0.03, 0.03, 8)

	# 4 contrafuertes cardinales con venas de Materia Oscura
	for i: int in range(4):
		var a: float = PI * 0.25 + float(i) * PI * 0.5
		var dx: float = cos(a)
		var dz: float = sin(a)
		Primitives.add_framed_vein(
			crystal_tris,
			chassis_tris,
			Vector3(dx * 0.52, 0.20, dz * 0.52),
			Vector3(dx * 0.40, 0.78, dz * 0.40),
			0.024,
			0.018
		)

	_cached_pedestal = Primitives.build_three_surface_mesh(armor_tris, chassis_tris, crystal_tris, 0.0, 0.92, 1)
	return _cached_pedestal


static func build_relic_artifact_mesh(relic_id: StringName) -> ArrayMesh:
	if _cached_artifacts.has(relic_id):
		return _cached_artifacts[relic_id] as ArrayMesh

	var armor_tris: Array[Array] = []
	var chassis_tris: Array[Array] = []
	var crystal_tris: Array[Array] = []

	match relic_id:
		&"trophy_boss_aegis":
			_build_aegis_artifact(armor_tris, chassis_tris, crystal_tris)
		&"trophy_biosphere_core":
			_build_biosphere_artifact(armor_tris, chassis_tris, crystal_tris)
		&"trophy_cryo_core":
			_build_cryo_artifact(armor_tris, chassis_tris, crystal_tris)
		&"trophy_volcanic_core":
			_build_volcanic_artifact(armor_tris, chassis_tris, crystal_tris)
		_:
			_build_monolith_artifact(armor_tris, chassis_tris, crystal_tris)

	var mesh: ArrayMesh = Primitives.build_three_surface_mesh(armor_tris, chassis_tris, crystal_tris, -0.5, 0.5, 1)
	_cached_artifacts[relic_id] = mesh
	return mesh


static func build_relic_orbit_ring_mesh(radius: float = 0.54) -> ArrayMesh:
	var key: int = roundi(radius * 100.0)
	if _cached_orbit_rings.has(key):
		return _cached_orbit_rings[key] as ArrayMesh

	var armor_tris: Array[Array] = []
	var chassis_tris: Array[Array] = []
	var crystal_tris: Array[Array] = []

	var segs: int = 12
	for i: int in range(segs):
		var a0: float = TAU * float(i) / float(segs)
		var a1: float = TAU * float(i + 1) / float(segs)
		var p0 := Vector3(cos(a0) * radius, 0.0, sin(a0) * radius)
		var p1 := Vector3(cos(a1) * radius, 0.0, sin(a1) * radius)
		Primitives.add_beam_segment(chassis_tris if i % 2 == 0 else armor_tris, p0, p1, 0.022, 0.016)
		if i % 3 == 0:
			var np := Vector3(cos(a0) * (radius + 0.06), 0.0, sin(a0) * (radius + 0.06))
			Primitives.add_beveled_slab(crystal_tris, np, 0.045, 0.045, 0.045, 0.015, 4)

	var mesh: ArrayMesh = Primitives.build_three_surface_mesh(armor_tris, chassis_tris, crystal_tris, -0.1, 0.1, 1)
	_cached_orbit_rings[key] = mesh
	return mesh


static func _build_aegis_artifact(armor_tris: Array[Array], chassis_tris: Array[Array], crystal_tris: Array[Array]) -> void:
	# Reactor octaedro central + 4 aletas blindadas en cruz
	var core_rings: Array[Array] = [
		Primitives.make_polygon_ring_y(Vector3(0.0, -0.36, 0.0), 0.04, 0.04, 4, 0.0),
		Primitives.make_polygon_ring_y(Vector3(0.0, 0.0, 0.0), 0.24, 0.24, 4, 0.0),
		Primitives.make_polygon_ring_y(Vector3(0.0, 0.36, 0.0), 0.04, 0.04, 4, 0.0),
	]
	Primitives.add_loft(crystal_tris, core_rings, true, true, Vector3.ZERO)
	for i: int in range(4):
		var a: float = float(i) * PI * 0.5
		var dx: float = cos(a)
		var dz: float = sin(a)
		Primitives.add_beam_segment(armor_tris, Vector3(dx * 0.18, -0.22, dz * 0.18), Vector3(dx * 0.36, 0.0, dz * 0.36), 0.042, 0.028)
		Primitives.add_beam_segment(chassis_tris, Vector3(dx * 0.36, 0.0, dz * 0.36), Vector3(dx * 0.18, 0.26, dz * 0.18), 0.036, 0.024)


static func _build_biosphere_artifact(armor_tris: Array[Array], chassis_tris: Array[Array], crystal_tris: Array[Array]) -> void:
	# Núcleo facetado hexagonal + 2 meridianos orgánicos
	var geo_rings: Array[Array] = [
		Primitives.make_polygon_ring_y(Vector3(0.0, -0.28, 0.0), 0.06, 0.06, 6, 0.0),
		Primitives.make_polygon_ring_y(Vector3(0.0, -0.14, 0.0), 0.24, 0.24, 6, 0.0),
		Primitives.make_polygon_ring_y(Vector3(0.0, 0.14, 0.0), 0.24, 0.24, 6, 0.0),
		Primitives.make_polygon_ring_y(Vector3(0.0, 0.28, 0.0), 0.06, 0.06, 6, 0.0),
	]
	Primitives.add_loft(crystal_tris, geo_rings, true, true, Vector3.ZERO)
	for i: int in range(6):
		var a0: float = TAU * float(i) / 6.0
		var a1: float = TAU * float(i + 1) / 6.0
		Primitives.add_beam_segment(armor_tris, Vector3(cos(a0) * 0.32, 0.0, sin(a0) * 0.32), Vector3(cos(a1) * 0.32, 0.0, sin(a1) * 0.32), 0.024, 0.020)
		Primitives.add_beam_segment(chassis_tris, Vector3(cos(a0) * 0.28, -0.18, sin(a0) * 0.28), Vector3(cos(a1) * 0.28, 0.18, sin(a1) * 0.28), 0.018, 0.014)


static func _build_cryo_artifact(armor_tris: Array[Array], chassis_tris: Array[Array], crystal_tris: Array[Array]) -> void:
	# Obelisco criogénico hexagonal alargado con corona superior
	var ob_rings: Array[Array] = [
		Primitives.make_polygon_ring_y(Vector3(0.0, -0.40, 0.0), 0.04, 0.04, 6, 0.0),
		Primitives.make_polygon_ring_y(Vector3(0.0, -0.12, 0.0), 0.18, 0.18, 6, 0.0),
		Primitives.make_polygon_ring_y(Vector3(0.0, 0.22, 0.0), 0.14, 0.14, 6, 0.0),
		Primitives.make_polygon_ring_y(Vector3(0.0, 0.44, 0.0), 0.03, 0.03, 6, 0.0),
	]
	Primitives.add_loft(crystal_tris, ob_rings, true, true, Vector3.ZERO)
	Primitives.add_beveled_slab(armor_tris, Vector3(0.0, -0.14, 0.0), 0.26, 0.26, 0.08, 0.04, 6)
	Primitives.add_beveled_slab(chassis_tris, Vector3(0.0, 0.18, 0.0), 0.22, 0.22, 0.06, 0.04, 6)


static func _build_volcanic_artifact(armor_tris: Array[Array], chassis_tris: Array[Array], crystal_tris: Array[Array]) -> void:
	# Geoda magmática de facetas inclinadas + corona dorsal
	var geode_rings: Array[Array] = [
		Primitives.make_polygon_ring_y(Vector3(0.0, -0.32, 0.0), 0.05, 0.05, 5, 0.2),
		Primitives.make_polygon_ring_y(Vector3(0.02, -0.05, 0.0), 0.28, 0.22, 5, 0.5),
		Primitives.make_polygon_ring_y(Vector3(-0.02, 0.20, 0.02), 0.20, 0.25, 5, 0.8),
		Primitives.make_polygon_ring_y(Vector3(0.0, 0.38, 0.0), 0.05, 0.05, 5, 1.0),
	]
	Primitives.add_loft(chassis_tris, geode_rings, true, true, Vector3.ZERO)
	for i: int in range(5):
		var a: float = TAU * float(i) / 5.0
		Primitives.add_beam_segment(crystal_tris, Vector3(0.0, -0.10, 0.0), Vector3(cos(a) * 0.34, 0.26, sin(a) * 0.34), 0.034, 0.026)
		Primitives.add_beveled_slab(armor_tris, Vector3(cos(a) * 0.24, -0.16, sin(a) * 0.24), 0.08, 0.08, 0.12, 0.02, 4)


static func _build_monolith_artifact(armor_tris: Array[Array], chassis_tris: Array[Array], crystal_tris: Array[Array]) -> void:
	# Aguja monolítica rúnica con diamante flotante superior
	var slab_rings: Array[Array] = [
		Primitives.make_box_ring(0.0, -0.36, 0.0, 0.15, 0.08),
		Primitives.make_box_ring(0.0, 0.05, 0.0, 0.18, 0.10),
		Primitives.make_box_ring(0.0, 0.26, 0.0, 0.10, 0.06),
	]
	Primitives.add_loft(chassis_tris, slab_rings, true, true, Vector3.ZERO)
	Primitives.add_framed_vein(crystal_tris, armor_tris, Vector3(0.0, -0.28, 0.10), Vector3(0.0, 0.20, 0.08), 0.030, 0.018)
	Primitives.add_beveled_slab(crystal_tris, Vector3(0.0, 0.38, 0.0), 0.11, 0.11, 0.16, 0.04, 4)

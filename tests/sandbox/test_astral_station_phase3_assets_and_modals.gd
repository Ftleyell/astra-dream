extends BaseTestSuite

## Suite enfocada de Fase 3:
## 1. Mallas ArcSys 3D (3 superficies + winding horario Godot 4) de Ala Este y Ala Oeste.
## 2. Apertura y cierre limpio de modales reales de producción y paneles laterales en HubAntesalaModalCoordinator.

const ProgressionConfigScript = preload("res://scenes/ui/hub/resources/hub_progression_config.gd")
const DEFAULT_PROGRESSION_CONFIG: ProgressionConfigScript = preload("res://data/hub/default_hub_progression_config.tres")
const ProgressionEvaluatorScript = preload("res://scenes/ui/hub/components/hub_progression_evaluator.gd")
const ModalCoordScript = preload("res://scenes/ui/hub/astral_station/components/hub_antesala_modal_coordinator.gd")
const EastMeshBuilder = preload("res://scenes/ui/hub/astral_station/meshes/hub_east_wing_mesh_builder.gd")
const WestMeshBuilder = preload("res://scenes/ui/hub/astral_station/meshes/hub_west_sanctuary_mesh_builder.gd")
const RunLaunchRequestScript = preload("res://core/systems/run_launch_request.gd")


func _ready() -> void:
	timeout_seconds = 14.0
	super._ready()
	await _run_tests()


func _run_tests() -> void:
	_test_phase3_wing_meshes_arcsys_contract()
	await _test_production_modals_open_and_close()
	pass_suite("Fase 3 Assets y Modales verificados: 9 mallas ArcSys Ala Este/Oeste + modales de producción.")


func _test_phase3_wing_meshes_arcsys_contract() -> void:
	var meshes: Array[Dictionary] = [
		{"name": "TelemetryTotem", "mesh": EastMeshBuilder.build_telemetry_totem_mesh()},
		{"name": "PetLoungePad", "mesh": EastMeshBuilder.build_pet_lounge_pad_mesh()},
		{"name": "RelicPedestal", "mesh": WestMeshBuilder.build_relic_pedestal_mesh()},
		{"name": "RelicOrbitRing", "mesh": WestMeshBuilder.build_relic_orbit_ring_mesh(0.54)},
		{"name": "RelicAegis", "mesh": WestMeshBuilder.build_relic_artifact_mesh(&"trophy_boss_aegis")},
		{"name": "RelicBiosphere", "mesh": WestMeshBuilder.build_relic_artifact_mesh(&"trophy_biosphere_core")},
		{"name": "RelicCryo", "mesh": WestMeshBuilder.build_relic_artifact_mesh(&"trophy_cryo_core")},
		{"name": "RelicVolcanic", "mesh": WestMeshBuilder.build_relic_artifact_mesh(&"trophy_volcanic_core")},
		{"name": "RelicMonolith", "mesh": WestMeshBuilder.build_relic_artifact_mesh(&"trophy_monolith_master")},
	]

	for spec: Dictionary in meshes:
		var m: ArrayMesh = spec["mesh"] as ArrayMesh
		var label: String = str(spec["name"])
		assert_true(m != null and m.get_surface_count() == 3, "%s debe tener exactamente 3 superficies (ARMOR/CHASSIS/CRYSTAL)" % label)
		for s_idx: int in range(3):
			var arr: Array = m.surface_get_arrays(s_idx)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX] as PackedVector3Array
			var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL] as PackedVector3Array
			assert_true(verts.size() >= 3 and norms.size() == verts.size(), "%s surf %d debe tener vértices y normales" % [label, s_idx])
			var tri_cross: Vector3 = (verts[2] - verts[0]).cross(verts[1] - verts[0]).normalized()
			assert_true(tri_cross.dot(norms[0]) > 0.9, "%s surf %d debe mantener winding horario saliente" % [label, s_idx])


func _test_production_modals_open_and_close() -> void:
	var eval: ProgressionEvaluatorScript = ProgressionEvaluatorScript.new()
	eval.setup(DEFAULT_PROGRESSION_CONFIG)
	eval.build_preset_snapshot(&"all_online")

	var coord: ModalCoordScript = ModalCoordScript.new()
	coord.name = "TestModalCoordinator"
	add_child(coord)
	coord.setup(eval, null, RunLaunchRequestScript.create_random_auto())

	coord.open_talents_nexus(Vector3.ZERO)
	assert_true(coord.is_any_modal_open(), "Nexo de Talentos debe abrir CharacterSkillTreeModal")
	coord.close_active_modal()
	assert_true(not coord.is_any_modal_open(), "Cerrar Nexo de Talentos debe cerrar CharacterSkillTreeModal")

	coord.open_trophy_details(&"trophy_cryo_core", Vector3.ZERO)
	assert_true(coord.is_any_modal_open(), "Interactuar con reliquia debe abrir TrophyDetailsModal")
	coord.close_active_modal()
	assert_true(not coord.is_any_modal_open(), "Cerrar TrophyDetailsModal debe dejar sin modales activos")

	coord.open_telemetry_totem(Vector3.ZERO)
	assert_true(coord.is_any_modal_open(), "Tótem de Telemetría debe abrir HighscoresModal")
	coord.close_active_modal()
	assert_true(not coord.is_any_modal_open(), "Cerrar HighscoresModal debe dejar sin modales activos")

	coord.open_pilot_capsule(Vector3.ZERO)
	assert_true(coord.is_any_modal_open(), "Cápsula de Piloto debe abrir panel lateral")
	coord.close_active_modal()
	assert_true(not coord.is_any_modal_open(), "Cerrar Cápsula de Piloto debe ocultar panel lateral")

	coord.open_companions_projector(Vector3.ZERO)
	assert_true(coord.is_any_modal_open(), "Proyector de Compañía debe abrir panel lateral")
	coord.close_active_modal()
	assert_true(not coord.is_any_modal_open(), "Cerrar Proyector de Compañía debe ocultar panel lateral")

	coord.open_tactical_console(Vector3.ZERO)
	assert_true(coord.is_any_modal_open(), "Consola Táctica debe abrir panel lateral")
	coord.close_active_modal()
	assert_true(not coord.is_any_modal_open(), "Cerrar Consola Táctica debe ocultar panel lateral")

	coord.queue_free()
	await get_tree().process_frame

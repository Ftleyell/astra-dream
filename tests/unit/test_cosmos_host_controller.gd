class_name TestCosmosHostController
extends BaseTestSuite

const CosmosHostController = preload("res://scenes/combat/environment/cosmos/core/cosmos_host_controller.gd")
const CosmosRootNode = preload("res://scenes/combat/environment/cosmos/scenes/cosmos_root.gd")
const CosmicBiomeBlender = preload("res://scenes/combat/environment/cosmos/core/cosmic_biome_blender.gd")
const CosmicPoiConfig = preload("res://scenes/combat/environment/cosmos/resources/cosmic_poi_config.gd")

## Suite de pruebas para CosmosHostController, transiciones de región y congelamiento/pausa (Sesión 4).
## Valida:
## 1. Inicialización e inyección de CosmosRoot en la fachada.
## 2. API de Freeze / Hit-Stop desacoplada (set_frozen).
## 3. Integración y reacción ante cambios en PauseArbitrator.
## 4. Transiciones de región espaciales vía CosmicBiomeBlender (inmediatas y con interpolación).
## 5. Inyección y limpieza de POIs narrativos a través de la fachada.

var _scene_root: Node2D = null
var _cosmos_root: CosmosRootNode = null
var _host_controller: CosmosHostController = null

func _ready() -> void:
	super._ready()
	_run_suite()

func _run_suite() -> void:
	_setup_test_scene()
	_test_facade_initialization()
	_test_freeze_and_hitstop_behavior()
	_test_pause_arbitrator_integration()
	_test_region_transitions_and_blender()
	_test_poi_injection_via_facade()
	_teardown_test_scene()
	pass_suite("TestCosmosHostController completado exitosamente (100% PASS).")

func _setup_test_scene() -> void:
	_scene_root = Node2D.new()
	add_child(_scene_root)

	var root_scn: PackedScene = load("res://scenes/combat/environment/cosmos/scenes/cosmos_root.tscn") as PackedScene
	assert_true(root_scn != null, "La escena cosmos_root.tscn debe cargar correctamente.")

	_cosmos_root = root_scn.instantiate() as CosmosRootNode
	_scene_root.add_child(_cosmos_root)

	_host_controller = CosmosHostController.new()
	_host_controller.cosmos_root = _cosmos_root
	_host_controller.default_region_id = &"perseus_rift"
	_scene_root.add_child(_host_controller)

func _teardown_test_scene() -> void:
	if _scene_root != null:
		_scene_root.queue_free()

func _test_facade_initialization() -> void:
	assert_true(_host_controller != null, "CosmosHostController debe instanciarse.")
	assert_true(_host_controller.cosmos_root == _cosmos_root, "CosmosRootNode debe estar asignado a la fachada.")
	assert_true(_host_controller.get_biome_blender() != null, "CosmicBiomeBlender debe inicializarse.")
	assert_true(_host_controller.get_current_region_id() == &"perseus_rift", "La región inicial debe ser perseus_rift.")

func _test_freeze_and_hitstop_behavior() -> void:
	assert_true(not _host_controller.is_frozen(), "El estado de congelamiento inicial debe ser falso.")
	assert_true(not _cosmos_root.is_frozen, "CosmosRoot no debe estar congelado inicialmente.")

	var initial_time: float = _cosmos_root.get_global_time()

	# Activar freeze (simulación de hit-stop)
	_host_controller.set_frozen(true)
	assert_true(_host_controller.is_frozen(), "is_frozen() debe ser true.")
	assert_true(_cosmos_root.is_frozen, "CosmosRoot.is_frozen debe ser true.")

	# Procesar 1 segundo con freeze activo
	_cosmos_root._process(1.0)
	var time_after_freeze_process: float = _cosmos_root.get_global_time()
	assert_true(is_equal_approx(initial_time, time_after_freeze_process), "El tiempo cósmico no debe avanzar mientras está congelado.")

	# Descongelar
	_host_controller.set_frozen(false)
	assert_true(not _host_controller.is_frozen(), "is_frozen() debe ser false tras descongelar.")
	assert_true(not _cosmos_root.is_frozen, "CosmosRoot.is_frozen debe ser false tras descongelar.")

	# Procesar 0.5 segundos descongelado
	_cosmos_root._process(0.5)
	var time_resumed: float = _cosmos_root.get_global_time()
	assert_true(time_resumed >= initial_time + 0.49, "El tiempo cósmico debe reanudarse normalmente tras descongelar.")

func _test_pause_arbitrator_integration() -> void:
	if not Engine.has_singleton("PauseArbitrator") and not is_instance_valid(PauseArbitrator):
		return

	# Adquirir pausa mediante PauseArbitrator
	PauseArbitrator.acquire_pause(&"test_cosmos_freeze")
	assert_true(_host_controller.is_frozen(), "CosmosHostController debe reflejar freeze cuando PauseArbitrator adquiere pausa.")
	assert_true(_cosmos_root.is_frozen, "CosmosRoot debe estar congelado por la pausa.")

	# Liberar pausa
	PauseArbitrator.release_pause(&"test_cosmos_freeze")
	assert_true(not _host_controller.is_frozen(), "CosmosHostController debe volver a descongelarse al liberar la pausa.")
	assert_true(not _cosmos_root.is_frozen, "CosmosRoot debe descongelarse al liberar la pausa.")

func _test_region_transitions_and_blender() -> void:
	var blender: CosmicBiomeBlender = _host_controller.get_biome_blender()
	assert_true(blender != null, "Blender debe existir.")

	# Cambio inmediato a Hyperion Forge (duration = 0.0)
	var success_hyperion: bool = _host_controller.change_region(&"hyperion_forge", 0.0)
	assert_true(success_hyperion, "change_region hacia hyperion_forge debe ser exitoso.")
	assert_true(_host_controller.get_current_region_id() == &"hyperion_forge", "La región activa debe ser hyperion_forge.")
	assert_true(not blender.is_transitioning(), "Blender no debe estar transicionando tras cambio inmediato.")
	assert_true(_cosmos_root.nebula_controller.biome_a.biome_id == &"biome_hyperion_forge", "El bioma principal de la nebulosa debe ser hyperion_forge.")

	# Cambio con transición hacia Carina Abyss (duration > 0.0)
	var success_carina: bool = _host_controller.change_region(&"carina_abyss", 1.5)
	assert_true(success_carina, "change_region hacia carina_abyss debe ser exitoso.")
	assert_true(blender.is_transitioning(), "Blender debe indicar que está transicionando.")
	assert_true(_cosmos_root.nebula_controller.biome_b != null, "Bioma B debe estar configurado como destino.")

	# Avanzar mezcla manualmente
	blender.advance_manual_blend(0.5)
	assert_true(is_equal_approx(blender.get_blend_progress(), 0.5), "El progreso de mezcla debe ser 0.5.")
	assert_true(is_equal_approx(_cosmos_root.nebula_controller.biome_blend_factor, 0.5), "El blend factor del controller debe ser 0.5.")

	# Completar mezcla manualmente
	blender.advance_manual_blend(0.5)
	assert_true(not blender.is_transitioning(), "La transición debe haber concluido.")
	assert_true(_cosmos_root.nebula_controller.biome_a.biome_id == &"biome_carina_abyss", "El bioma A debe haberse fijado a carina_abyss.")

func _test_poi_injection_via_facade() -> void:
	var poi: CosmicPoiConfig = CosmicPoiConfig.new()
	poi.custom_label = &"Test Citadel Station"
	poi.planet_count = 4

	var test_coord: Vector2i = Vector2i(77, -44)
	_host_controller.inject_poi_at_virtual_coords(test_coord, poi)

	assert_true(_cosmos_root.has_poi(test_coord), "CosmosRoot debe contener el POI inyectado en (77, -44).")
	var retrieved: CosmicPoiConfig = _cosmos_root.get_poi(test_coord)
	assert_true(retrieved != null and retrieved.custom_label == "Test Citadel Station", "Los datos del POI inyectado deben ser íntegros.")

	_host_controller.clear_poi_overrides()
	assert_true(not _cosmos_root.has_poi(test_coord), "clear_poi_overrides() debe purgar los POIs registrados.")

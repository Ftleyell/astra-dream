class_name TestCosmosEngineIntegration
extends BaseTestSuite

## Suite de integración de Cosmos Engine (Sesión 6).
## Valida:
## 1. Presencia e inicialización de los 6 estratos en CosmosRoot (Nebula, Galaxies, Starfield 8K, Solar, Debris, Gameplay).
## 2. Inyección de dependencias y enlace de cámara en streamers y background shaders.
## 3. Propagación de tiempo global cósmico (global_time) en los subsistemas.
## 4. Desplazamiento de gran escala (>= 50.000 unidades) con FloatingOriginTracker:
##    - Recentrado de origen coordinado.
##    - Absorción analítica en todos los estratos de paralaje.
##    - Cero NaN, cero distorsiones de posición y consistencia de coordenadas absolutas.

var _scene_instance: Node2D = null
var _cosmos_root: CosmosRoot = null

func _ready() -> void:
	super._ready()
	_run_integration_tests()

func _run_integration_tests() -> void:
	_test_strata_presence_and_initialization()
	_test_cosmic_time_propagation()
	_test_large_scale_displacement_and_origin_shifts()
	_test_camera_streamer_binding_consistency()
	pass_suite("TestCosmosEngineIntegration completado con éxito (100% de aserciones pasadas).")

func _test_strata_presence_and_initialization() -> void:
	var demo_scene: PackedScene = load("res://sandbox/scenes/cosmos_engine_demo.tscn") as PackedScene
	assert_true(demo_scene != null, "La escena cosmos_engine_demo.tscn debe cargar correctamente.")
	
	_scene_instance = demo_scene.instantiate() as Node2D
	add_child(_scene_instance)

	_cosmos_root = _scene_instance.get_node_or_null("CosmosRoot") as CosmosRoot
	assert_true(_cosmos_root != null, "CosmosRoot debe existir e instanciarse en la escena.")

	# Validar los 6 estratos
	assert_true(_cosmos_root.nebula_controller != null, "Estrato 1 (ParallaxNebulaDeep / NebulaBackdrop) debe estar asignado.")
	assert_true(_cosmos_root.parallax_macro_galaxies != null, "Estrato 2 (ParallaxMacroGalaxies) debe existir.")
	assert_true(_cosmos_root.galaxy_streamer != null, "GalaxyStreamer2D debe estar vinculado a ParallaxMacroGalaxies.")
	assert_true(_cosmos_root.parallax_starfield_8k != null, "Estrato 3 (ParallaxStarfield8K) debe existir.")
	assert_true(_cosmos_root.parallax_solar_systems != null, "Estrato 4 (ParallaxSolarSystems) debe existir.")
	assert_true(_cosmos_root.solar_streamer != null, "SolarSystemStreamer debe estar vinculado a ParallaxSolarSystems.")
	assert_true(_cosmos_root.parallax_debris_belt != null, "Estrato 5 (ParallaxDebrisBelt) debe existir.")
	assert_true(_cosmos_root.debris_streamer != null, "DebrisStreamer2D debe estar vinculado a ParallaxDebrisBelt.")
	assert_true(_cosmos_root.gameplay_world != null, "Estrato 6 (GameplayWorld) debe existir.")

	# Validar FloatingOriginTracker
	assert_true(_cosmos_root.floating_origin_tracker != null, "FloatingOriginTracker debe estar vinculado en CosmosRoot.")
	assert_true(_cosmos_root.floating_origin_tracker.parallax_layers.size() >= 3, "FloatingOriginTracker debe supervisar los estratos de paralaje.")

func _test_cosmic_time_propagation() -> void:
	var initial_time: float = _cosmos_root.get_global_time()
	assert_true(initial_time >= 0.0, "El tiempo inicial cósmico debe ser no negativo.")

	# Simular avance de 2.5 segundos de proceso
	_cosmos_root._process(1.5)
	_cosmos_root._process(1.0)

	var progressed_time: float = _cosmos_root.get_global_time()
	assert_true(progressed_time >= initial_time + 2.49, "CosmosRoot debe acumular global_time fidedignamente.")

func _test_large_scale_displacement_and_origin_shifts() -> void:
	var vessel: PlayerVessel = _scene_instance.get_node_or_null("CosmosRoot/PlayerVessel") as PlayerVessel
	var tracker: FloatingOriginTracker = _cosmos_root.floating_origin_tracker
	assert_true(vessel != null, "PlayerVessel debe existir.")
	assert_true(tracker != null, "Tracker debe existir.")

	var initial_shift_count: int = _cosmos_root.get_origin_shift_count()
	var layers: Array[Parallax2D] = tracker.parallax_layers

	# Capturar offsets iniciales de paralaje
	var initial_offsets: Dictionary = {}
	for layer: Parallax2D in layers:
		initial_offsets[layer] = layer.scroll_offset

	# Simular un desplazamiento acumulado de 50.000 unidades en diagonal hacia (35355, 35355)
	# Umbral por defecto es 10.000 unidades, por lo que disparará múltiples recentrados
	var step_displacement: Vector2 = Vector2(12000.0, 12000.0)
	var expected_shifts: int = 0

	for i: int in range(5):
		vessel.global_position += step_displacement
		if tracker.check_and_shift():
			expected_shifts += 1

	# Validar que los recentrados ocurrieron
	var final_shifts: int = _cosmos_root.get_origin_shift_count()
	assert_true(final_shifts > initial_shift_count, "Debe haberse disparado al menos un origin shift en 50.000 px de viaje.")
	assert_true(final_shifts == expected_shifts, "El contador de shifts en CosmosRoot debe coincidir exactamente con los shifts ejecutados.")

	# Validar posición absoluta preservada
	var abs_pos: Vector2 = _cosmos_root.get_absolute_position(vessel.global_position)
	assert_true(not is_nan(abs_pos.x) and not is_nan(abs_pos.y), "La posición absoluta cósmica no debe ser NaN.")
	assert_true(abs_pos.length() > 40000.0, "La posición cósmica absoluta debe reflejar la gran escala (aprox 50.000 px).")

	# Validar que la posición local se mantuvo acotada (por debajo del umbral de recentrado de 10.000)
	assert_true(vessel.global_position.length() <= tracker.threshold_distance * 1.5, "La posición local de la nave debe permanecer acotada cerca del centro tras los shifts.")

	# Validar que todas las capas de paralaje absorbieron el shift en su scroll_offset proporcional
	for layer: Parallax2D in layers:
		var initial_off: Vector2 = initial_offsets[layer]
		var total_shift: Vector2 = _cosmos_root.get_accumulated_shift()
		var expected_off: Vector2 = initial_off - total_shift * layer.scroll_scale
		var diff: float = (layer.scroll_offset - expected_off).length()
		assert_true(diff <= 0.01, "La capa de paralaje %s debe absorber exactamente el shift acumulado." % layer.name)

	# Validar que la cámara no sufrió doble traslación y sigue anclada a la nave
	var cam_child: Camera2D = vessel.get_node_or_null("CosmosCamera2D") as Camera2D
	assert_true(cam_child != null, "CosmosCamera2D debe existir como nodo hijo de vessel.")
	assert_true(cam_child.position == Vector2.ZERO, "La cámara de la nave debe mantener su position local en (0, 0) tras los recentrados.")

func _test_camera_streamer_binding_consistency() -> void:
	var cam: Camera2D = _cosmos_root.camera
	assert_true(cam != null, "La cámara de CosmosRoot debe estar asignada.")
	assert_true(_cosmos_root.galaxy_streamer.camera == cam, "GalaxyStreamer debe compartir la cámara activa.")
	assert_true(_cosmos_root.solar_streamer.camera == cam, "SolarSystemStreamer debe compartir la cámara activa.")
	assert_true(_cosmos_root.debris_streamer.camera == cam, "DebrisStreamer debe compartir la cámara activa.")
	assert_true(_cosmos_root.nebula_controller.camera == cam, "NebulaController debe compartir la cámara activa.")

	# Limpiar nodo de escena
	if _scene_instance != null:
		_scene_instance.queue_free()

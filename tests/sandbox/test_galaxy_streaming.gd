class_name TestGalaxyStreaming
extends BaseTestSuite

## Suite de pruebas para GalaxyStreamer2D:
## Valida arquitectura de Macro-Sectores 3x3, multi-galaxy pooling, frustum culling y zero-allocation.

var _landmark_profile: GalaxyLandmarkProfile
var _parallax_layer: Parallax2D
var _camera: Camera2D
var _streamer: GalaxyStreamer2D

func _ready() -> void:
	super._ready()
	_run_galaxy_streaming_tests()

func _run_galaxy_streaming_tests() -> void:
	_setup_test_nodes()
	_test_macro_sector_geometry_derivation()
	_test_zero_allocation_and_pool_integrity()
	_test_spatial_sweep_and_streaming()
	_test_fade_transitions_and_drift()
	pass_suite("TestGalaxyStreaming completado con éxito (100% assertions pasadas).")

func _setup_test_nodes() -> void:
	_landmark_profile = GalaxyLandmarkProfile.new()
	_landmark_profile.galaxy_id = &"test_galaxy"
	_landmark_profile.maximum_bounding_radius = 1600.0
	_landmark_profile.safety_padding = 400.0
	_landmark_profile.base_scale_range = Vector2(0.8, 1.2)
	_landmark_profile.max_drift_rotation_speed = 0.001
	_landmark_profile.modulate_colors = [Color.WHITE, Color.CYAN]
	_landmark_profile.pool_size = 4
	_landmark_profile.solar_cells_span = 3
	_landmark_profile.cell_size = 3000.0
	_landmark_profile.spawn_chance = 1.0

	_camera = Camera2D.new()
	_camera.position = Vector2.ZERO
	_camera.zoom = Vector2(1.0, 1.0)
	add_child(_camera)

	_parallax_layer = Parallax2D.new()
	_parallax_layer.scroll_scale = Vector2(0.02, 0.02)
	add_child(_parallax_layer)

	_streamer = GalaxyStreamer2D.new()
	_streamer.landmark_profile = _landmark_profile
	_streamer.parallax_layer = _parallax_layer
	_streamer.camera = _camera
	_streamer.run_seed = 8943719
	_streamer.pool_size = 4
	_parallax_layer.add_child(_streamer)

func _test_macro_sector_geometry_derivation() -> void:
	var cell_size: float = _streamer.get_calculated_cell_size()
	var min_dist: float = _streamer.get_safe_min_distance()
	
	assert_true(cell_size > 0.0, "El tamaño de celda calculado debe ser mayor a 0.")
	assert_true(min_dist > 0.0, "La distancia de seguridad mínima debe ser mayor a 0.")
	assert_true(cell_size == 3000.0, "El tamaño de celda debe respetar el valor del perfil de prueba.")

func _test_zero_allocation_and_pool_integrity() -> void:
	var initial_children_count: int = _streamer.get_child_count()
	assert_true(initial_children_count == 4, "GalaxyStreamer2D debe poseer exactamente 4 hijos pre-asignados en su pool (pool_size).")
	
	var active_sprite: Sprite2D = _streamer.get_active_sprite()
	assert_true(active_sprite != null, "El sprite pre-asignado no debe ser nulo.")

	# Simular 30 frames de render y movimiento sin crear ni eliminar nodos
	for step: int in range(30):
		_camera.position += Vector2(100.0, 50.0)
		_streamer._process(0.016)
		assert_true(_streamer.get_child_count() == 4, "Zero-allocation violada: el número de hijos varió durante el loop de streaming.")

func _test_spatial_sweep_and_streaming() -> void:
	var sample_points: Array[Vector2] = [
		Vector2.ZERO,
		Vector2(10000.0, 0.0),
		Vector2(-25000.0, 50000.0),
		Vector2(120000.0, -80000.0),
		Vector2(-500000.0, -500000.0),
		Vector2(999999.0, 123456.0)
	]

	var grid: CosmicMacroGrid = _streamer.get_macro_grid()
	assert_true(grid != null, "CosmicMacroGrid debe estar instanciado en el streamer.")

	for pos: Vector2 in sample_points:
		_camera.position = pos
		_streamer._process(0.016)

		var active_count: int = _streamer.get_active_galaxies_count()
		assert_true(active_count <= _landmark_profile.pool_size, "El conteo de galaxias activas no debe superar el tamaño del pool.")
		assert_true(_streamer.get_child_count() == _landmark_profile.pool_size, "Zero-allocation violada durante el barrido espacial.")

func _test_fade_transitions_and_drift() -> void:
	var found_cell: Vector2i = Vector2i(0, 0)
	var target_layer_pos: Vector2 = _streamer.evaluate_galaxy_layer_position(found_cell)
	_camera.position = target_layer_pos / _parallax_layer.scroll_scale
	
	# Evaluar entrada
	_streamer._process(0.016)
	assert_true(_streamer.is_galaxy_rendered(), "Debe renderizarse una galaxia en la posición del target.")
	assert_true(_streamer.get_target_alpha() == 1.0, "Target alpha debe ser 1.0 al intersectar la galaxia.")
	
	# Procesar varios frames para que el fade y rotación progresen
	var initial_rot: float = _streamer.get_active_sprite().rotation
	for i in range(10):
		_streamer._process(0.1)
		
	assert_true(_streamer.get_current_alpha() > 0.0, "Current alpha debe haberse incrementado suavemente.")
	assert_true(_streamer.get_active_sprite().rotation != initial_rot, "La rotación de drift cósmico debe actualizarse con el paso del tiempo.")

class_name TestGalaxyStreaming
extends BaseTestSuite

## Suite de pruebas para GalaxyStreamer2D:
## Valida exclusividad analítica 1-a-1, frustum culling, zero-allocation y persistencia del pool.

var _landmark_profile: GalaxyLandmarkProfile
var _parallax_layer: Parallax2D
var _camera: Camera2D
var _streamer: GalaxyStreamer2D

func _ready() -> void:
	super._ready()
	_run_galaxy_streaming_tests()

func _run_galaxy_streaming_tests() -> void:
	_setup_test_nodes()
	_test_exclusivity_geometry_derivation()
	_test_zero_allocation_and_single_node()
	_test_spatial_sweep_exclusivity()
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
	_parallax_layer.add_child(_streamer)

func _test_exclusivity_geometry_derivation() -> void:
	var cell_size: float = _streamer.get_calculated_cell_size()
	var min_dist: float = _streamer.get_safe_min_distance()
	
	assert_true(cell_size > 0.0, "El tamaño de celda calculado debe ser mayor a 0.")
	assert_true(min_dist > 0.0, "La distancia de seguridad mínima debe ser mayor a 0.")
	assert_true(cell_size >= 2.0 * min_dist, "L_cell debe ser mayor o igual a 2 * D_min para garantizar matemáticamente exclusividad 1-a-1.")

func _test_zero_allocation_and_single_node() -> void:
	var initial_children_count: int = _streamer.get_child_count()
	assert_true(initial_children_count == 1, "GalaxyStreamer2D debe poseer exactamente 1 hijo pre-asignado en su pool (Sprite2D).")
	
	var active_sprite: Sprite2D = _streamer.get_active_sprite()
	assert_true(active_sprite != null, "El sprite pre-asignado no debe ser nulo.")

	# Simular 30 frames de render y movimiento sin crear ni eliminar nodos
	for step: int in range(30):
		_camera.position += Vector2(100.0, 50.0)
		_streamer._process(0.016)
		assert_true(_streamer.get_child_count() == 1, "Zero-allocation violada: el número de hijos varió durante el loop de streaming.")
		assert_true(_streamer.get_active_sprite() == active_sprite, "La instancia del sprite debe ser reciclada en memoria sin nuevas asignaciones.")

func _test_spatial_sweep_exclusivity() -> void:
	# Recorrer un barrido extenso simulando miles de píxeles a través del espacio cósmico
	# En cada paso, verificar que el macro grid y la geometría analítica nunca permitan más de 1 galaxia candidata a la vez
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

		var cam_layer_pos: Vector2 = pos * _parallax_layer.scroll_scale
		var cur_cell: Vector2i = grid.world_to_grid_coords(cam_layer_pos)

		var candidate_count: int = 0
		for ox: int in range(-1, 2):
			for oy: int in range(-1, 2):
				var test_cell: Vector2i = cur_cell + Vector2i(ox, oy)
				if grid.get_cell_pseudorandom_float(test_cell, 551) > 0.65:
					continue
				
				var gal_pos: Vector2 = _streamer.evaluate_galaxy_layer_position(test_cell)
				var half_extents: Vector2 = (get_viewport().get_visible_rect().size * 0.5)
				if half_extents == Vector2.ZERO:
					half_extents = Vector2(960.0, 540.0)
				
				if _streamer._intersects_frustum(gal_pos, cam_layer_pos, half_extents):
					candidate_count += 1

		assert_true(candidate_count <= 1, "Violación de exclusividad 1-a-1: se detectaron %d galaxias simultáneas en el frustum en la posición %s." % [candidate_count, str(pos)])

func _test_fade_transitions_and_drift() -> void:
	# Posicionar la cámara en una celda que garantice una galaxia para evaluar el fade
	var grid: CosmicMacroGrid = _streamer.get_macro_grid()
	var found_cell: Vector2i = Vector2i.ZERO
	var found: bool = false
	
	for cx: int in range(10):
		for cy: int in range(10):
			var test_c: Vector2i = Vector2i(cx, cy)
			if grid.get_cell_pseudorandom_float(test_c, 551) <= 0.65:
				found_cell = test_c
				found = true
				break
		if found:
			break
			
	assert_true(found, "Debe existir al menos una celda con probabilidad favorable en la muestra de prueba.")
	
	var target_layer_pos: Vector2 = _streamer.evaluate_galaxy_layer_position(found_cell)
	_camera.position = target_layer_pos / _parallax_layer.scroll_scale
	
	# Evaluar entrada
	_streamer._process(0.016)
	assert_true(_streamer.get_target_alpha() == 1.0, "Target alpha debe ser 1.0 al intersectar la galaxia.")
	
	# Procesar varios frames para que el fade progrese suavemente
	var initial_rot: float = _streamer.get_active_sprite().rotation
	for i in range(10):
		_streamer._process(0.1)
		
	assert_true(_streamer.get_current_alpha() > 0.0, "Current alpha debe haberse incrementado suavemente hacia 1.0.")
	assert_true(_streamer.get_active_sprite().rotation != initial_rot, "La rotación de drift cósmico debe actualizarse con el paso del tiempo.")

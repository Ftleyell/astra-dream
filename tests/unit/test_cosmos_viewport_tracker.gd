class_name TestCosmosViewportTracker
extends BaseTestSuite

const CosmosViewportCanvasTracker = preload("res://scenes/combat/environment/cosmos/core/viewport_canvas_tracker.gd")
const CosmosSolarSystemStreamer = preload("res://scenes/combat/environment/cosmos/core/solar_system_streamer.gd")
const CosmosFloatingOriginTracker = preload("res://scenes/combat/environment/cosmos/core/floating_origin_tracker.gd")
const CosmosRootNode = preload("res://scenes/combat/environment/cosmos/scenes/cosmos_root.gd")

## Suite de pruebas unitarias para verificar el ViewportCanvasTracker y la compatibilidad con cinemáticas (Sesión 3).

func _ready() -> void:
	timeout_seconds = 8.0
	super._ready()
	_run_suite()

func _run_suite() -> void:
	print("TEST: Starting _test_viewport_tracker_sampling...")
	_test_viewport_tracker_sampling()
	print("TEST: Starting _test_streamer_camera_override...")
	_test_streamer_camera_override()
	print("TEST: Starting _test_cosmos_root_viewport_sync...")
	_test_cosmos_root_viewport_sync()
	print("TEST: Starting _test_floating_origin_viewport_target...")
	_test_floating_origin_viewport_target()
	print("TEST: Finishing suite...")
	pass_suite("TestCosmosViewportTracker completado con éxito (100% verificado).")

func _test_viewport_tracker_sampling() -> void:
	var tracker: CosmosViewportCanvasTracker = CosmosViewportCanvasTracker.new()

	var state: Dictionary = {
		"signal_received": false,
		"received_pos": Vector2.ZERO,
		"received_zoom": Vector2.ZERO
	}

	tracker.viewport_updated.connect(func(pos: Vector2, zoom: Vector2, _rot: float) -> void:
		state["signal_received"] = true
		state["received_pos"] = pos
		state["received_zoom"] = zoom
	)

	add_child(tracker)

	# Simular muestreo directo
	tracker.sample_viewport()
	assert_true(bool(state["signal_received"]), "El tracker debe emitir la señal viewport_updated al muestrear.")
	assert_true(tracker.current_zoom.x > 0.0, "El zoom detectado debe ser un valor positivo.")

	# Simular teletransporte / corte de cinemática
	var teleport_dest: Vector2 = Vector2(15000.0, -8000.0)
	tracker.force_teleport(teleport_dest)
	assert_true(tracker.current_center == teleport_dest, "force_teleport debe actualizar la posición central inmediatamente.")
	assert_true(state["received_pos"] == teleport_dest, "La señal debe reflejar el centro tras force_teleport.")

	tracker.queue_free()

func _test_streamer_camera_override() -> void:
	var solar_streamer: CosmosSolarSystemStreamer = CosmosSolarSystemStreamer.new()
	var profile: CosmosCelestialSystemProfile = load("res://scenes/combat/environment/cosmos/resources/data/default_celestial_system.tres") as CosmosCelestialSystemProfile
	solar_streamer.system_profile = profile
	add_child(solar_streamer)

	var virtual_cam_pos: Vector2 = Vector2(3000.0, 4000.0)
	var virtual_zoom: Vector2 = Vector2(1.5, 1.5)
	solar_streamer.set_camera_override(virtual_cam_pos, virtual_zoom)

	assert_true(solar_streamer._has_camera_override, "El streamer debe registrar que tiene activo el override de cámara.")
	assert_true(solar_streamer._override_cam_pos == virtual_cam_pos, "La posición del override debe coincidir exactamente.")
	assert_true(solar_streamer._override_zoom == virtual_zoom, "El zoom del override debe coincidir exactamente.")

	solar_streamer.clear_camera_override()
	assert_true(not solar_streamer._has_camera_override, "clear_camera_override debe desactivar el override de cámara.")

	solar_streamer.queue_free()

func _test_cosmos_root_viewport_sync() -> void:
	var cosmos_scene: PackedScene = load("res://scenes/combat/environment/cosmos/scenes/cosmos_root.tscn") as PackedScene
	assert_true(cosmos_scene != null, "La escena cosmos_root.tscn debe cargar correctamente.")

	var cosmos_root: CosmosRootNode = cosmos_scene.instantiate() as CosmosRootNode
	add_child(cosmos_root)

	assert_true(cosmos_root.viewport_tracker != null, "CosmosRootNode debe inicializar y enlazar viewport_tracker automáticamente.")

	# Simular emisión de coordenadas de cámara cinemática
	var test_center: Vector2 = Vector2(8500.0, -4200.0)
	var test_zoom: Vector2 = Vector2(0.8, 0.8)
	cosmos_root._on_viewport_updated(test_center, test_zoom, 0.0)

	if cosmos_root.solar_streamer != null:
		assert_true(cosmos_root.solar_streamer._has_camera_override, "solar_streamer debe tener el override activo.")
		assert_true(cosmos_root.solar_streamer._override_cam_pos == test_center, "solar_streamer debe recibir la coordenada central del viewport.")
	if cosmos_root.galaxy_streamer != null:
		assert_true(cosmos_root.galaxy_streamer._has_camera_override, "galaxy_streamer debe tener el override activo.")
	if cosmos_root.debris_streamer != null:
		assert_true(cosmos_root.debris_streamer._has_camera_override, "debris_streamer debe tener el override activo.")

	cosmos_root.queue_free()

func _test_floating_origin_viewport_target() -> void:
	var tracker: CosmosFloatingOriginTracker = CosmosFloatingOriginTracker.new()
	tracker.threshold_distance = 5000.0
	add_child(tracker)

	var vp_tracker: CosmosViewportCanvasTracker = CosmosViewportCanvasTracker.new()
	add_child(vp_tracker)
	tracker.viewport_tracker = vp_tracker

	vp_tracker.current_center = Vector2(2000.0, 1000.0)
	assert_true(not tracker.check_and_shift(), "No debe disparar recentrado por debajo del umbral de distancia.")

	vp_tracker.current_center = Vector2(6000.0, 0.0)
	var shift_state: Dictionary = {
		"shifted": false,
		"shift_vec": Vector2.ZERO
	}
	tracker.origin_shifted.connect(func(s: Vector2) -> void:
		shift_state["shifted"] = true
		shift_state["shift_vec"] = s
	)

	var did_shift: bool = tracker.check_and_shift()
	assert_true(did_shift, "Debe recentrar al superar el umbral de distancia mediante el viewport tracker.")
	assert_true(bool(shift_state["shifted"]), "La señal origin_shifted debe ser emitida.")
	assert_true(shift_state["shift_vec"] == Vector2(6000.0, 0.0), "El vector de desplazamiento debe corresponder al target.")

	tracker.queue_free()
	vp_tracker.queue_free()

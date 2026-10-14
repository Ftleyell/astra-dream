class_name TestOrbitalBindingEvents
extends BaseTestSuite

const CosmosHostController = preload("res://scenes/combat/environment/cosmos/core/cosmos_host_controller.gd")
const CosmosRootNode = preload("res://scenes/combat/environment/cosmos/scenes/cosmos_root.gd")
const PlanetSpawner = preload("res://scenes/combat/environment/planet_spawner.gd")
const CombatSatelliteCoordinator = preload("res://scenes/combat/systems/combat_satellite_coordinator.gd")
const OrbitalWorldFollower2D = preload("res://scenes/combat/environment/cosmos/core/orbital_world_follower_2d.gd")
const CosmosOrbitSlot = preload("res://scenes/combat/environment/cosmos/core/cosmos_orbit_slot.gd")

var _scene_root: Node2D = null
var _cosmos_root: CosmosRootNode = null
var _host_controller: CosmosHostController = null

func _ready() -> void:
	super._ready()
	_run_suite()

func _run_suite() -> void:
	_setup_test_scene()
	_test_slot_factory_and_stream_events()
	_test_orbital_follower_freeze()
	_teardown_test_scene()
	pass_suite("TestOrbitalBindingEvents completado exitosamente (100% PASS).")

func _setup_test_scene() -> void:
	_scene_root = Node2D.new()
	add_child(_scene_root)

	var root_scn: PackedScene = load("res://scenes/combat/environment/cosmos/scenes/cosmos_root.tscn") as PackedScene
	assert_true(root_scn != null, "La escena cosmos_root.tscn debe cargar correctamente.")

	_cosmos_root = root_scn.instantiate() as CosmosRootNode
	_scene_root.add_child(_cosmos_root)

	_host_controller = CosmosHostController.new()
	_host_controller.cosmos_root = _cosmos_root
	_scene_root.add_child(_host_controller)

func _teardown_test_scene() -> void:
	if _scene_root != null:
		_scene_root.queue_free()

func _test_slot_factory_and_stream_events() -> void:
	var tracker := _host_controller.get_slot_tracker()
	assert_true(tracker != null, "El slot tracker debe estar disponible.")

	# Forzar la activación de un sistema solar en streamer
	var streamer := _cosmos_root.solar_streamer
	assert_true(streamer != null, "El streamer solar debe existir en CosmosRoot.")

	var test_cell := Vector2i(1, 1)
	var sys_pos := streamer.get_system_position_for_cell(test_cell)

	# Simular streaming de un sistema solar
	var sys: CosmosSolarSystem2D = CosmosSolarSystem2D.new()
	sys.system_profile = streamer.system_profile
	sys.build_system(12345)
	sys.position = sys_pos
	streamer.add_child(sys)

	var slots_dict: Dictionary = tracker.get_slots_for_system(sys, test_cell)
	var star_slot: CosmosOrbitSlot = slots_dict.get("star_slot")
	var planet_slots: Array[CosmosOrbitSlot] = slots_dict.get("planet_slots", [])

	assert_true(star_slot != null, "Debe generarse un star_slot para el sistema solar.")
	assert_true(star_slot.center_type == CosmosOrbitSlot.SlotCenterType.STAR, "star_slot debe ser de tipo STAR.")
	assert_true(star_slot.body_reference != null, "star_slot debe tener referencia al star_body.")
	assert_true(not planet_slots.is_empty(), "Debe generarse al menos un planet_slot para los planetas de fondo.")
	assert_true(planet_slots[0].center_type == CosmosOrbitSlot.SlotCenterType.PLANET, "planet_slot debe ser de tipo PLANET.")
	assert_true(planet_slots[0].body_reference != null, "planet_slot debe tener referencia al planet_body.")

	# Probar emisión de señal en host_controller
	var signal_box: Array[bool] = [false]
	var handler: Callable = func(_s: CosmosSolarSystem2D, cell: Vector2i, _ss: CosmosOrbitSlot, _ps: Array) -> void:
		if cell == test_cell:
			signal_box[0] = true
	_host_controller.solar_system_streamed.connect(handler)

	streamer.system_streamed.emit(sys, test_cell)
	assert_true(signal_box[0], "solar_system_streamed debe propagarse a través de CosmosHostController.")

	sys.queue_free()

func _test_orbital_follower_freeze() -> void:
	var follower := OrbitalWorldFollower2D.new()
	var dummy_node := Node2D.new()
	dummy_node.position = Vector2(500.0, 500.0)
	dummy_node.add_child(follower)
	_scene_root.add_child(dummy_node)

	var cam := Camera2D.new()
	cam.global_position = Vector2(100.0, 100.0)
	_scene_root.add_child(cam)

	var dummy_slot := CosmosOrbitSlot.new(
		CosmosOrbitSlot.SlotCenterType.STAR,
		Vector2i(0, 0),
		Vector2(1000.0, 1000.0),
		0.0,
		0.0,
		0.0,
		null,
		&"TestFreezeSlot",
		Vector2(0.20, 0.20)
	)

	follower.setup_orbital_binding(dummy_slot, cam, _cosmos_root)
	follower._update_position(0.0)
	var pos_at_cam100: Vector2 = dummy_node.global_position

	# 1. Congelar y mover la cámara
	follower.freeze_parallax_drag = true
	assert_true(follower.freeze_parallax_drag, "freeze_parallax_drag debe ser configurable a true.")
	cam.global_position = Vector2(600.0, 600.0)
	follower._update_position(0.016)
	assert_true(dummy_node.global_position.distance_to(pos_at_cam100) <= 0.01, "freeze_parallax_drag debe bloquear el arrastre de cámara.")

	# 2. Descongelar con interpolación anti-snapping (0.4s)
	follower.freeze_parallax_drag = false
	follower._update_position(0.2)
	assert_true(is_equal_approx(follower._freeze_weight, 0.5), "El peso de congelamiento debe transicionar suavemente hacia 0.")

	follower._update_position(0.2)
	assert_true(is_zero_approx(follower._freeze_weight), "El peso de congelamiento debe alcanzar 0 tras 0.4s.")
	assert_true(dummy_node.global_position.distance_to(Vector2(1480.0, 1480.0)) <= 0.01, "La posición tras descongelar debe recuperar el paralaje completo de la cámara sin saltos.")

	cam.queue_free()
	dummy_node.queue_free()

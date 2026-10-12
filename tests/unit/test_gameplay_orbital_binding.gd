class_name TestGameplayOrbitalBinding
extends BaseTestSuite

## TestGameplayOrbitalBinding.gd
## Arnés de pruebas automatizado para validar el enlace analítico de órbitas de gameplay en sistemas solares.
## Valida:
## 1. Generación y acceso a slots analíticos (estrellas y planetas) desde CosmosHostController y CosmosOrbitalSlotTracker.
## 2. Proyección exacta de coordenadas al mundo de GameplayWorld sin deriva numérica.
## 3. Comportamiento y tracking continuo de OrbitalWorldFollower2D sobre satélites y planetas destruibles.
## 4. Coexistencia con la cámara y sincronización de paralaje (scroll_scale = 0.20).

const CosmosHostController = preload("res://scenes/combat/environment/cosmos/core/cosmos_host_controller.gd")
const CosmosRootNode = preload("res://scenes/combat/environment/cosmos/scenes/cosmos_root.gd")
const CosmosOrbitSlot = preload("res://scenes/combat/environment/cosmos/core/cosmos_orbit_slot.gd")
const CosmosOrbitalSlotTracker = preload("res://scenes/combat/environment/cosmos/core/cosmos_orbital_slot_tracker.gd")
const OrbitalWorldFollower2D = preload("res://scenes/combat/environment/cosmos/core/orbital_world_follower_2d.gd")

var _scene_root: Node2D = null
var _cosmos_root: CosmosRootNode = null
var _host_controller: CosmosHostController = null
var _camera: Camera2D = null

func _ready() -> void:
	super._ready()
	_run_suite()

func _run_suite() -> void:
	_setup_test_scene()
	_test_slot_generation_and_tracking()
	_test_world_projection_formula()
	_test_orbital_world_follower_behavior()
	_test_zero_drift_long_term_orbit()
	_test_spawner_orbital_direct_projection()
	_teardown_test_scene()
	pass_suite("TestGameplayOrbitalBinding completado exitosamente (100% PASS).")

func _setup_test_scene() -> void:
	_scene_root = Node2D.new()
	add_child(_scene_root)

	var root_scn: PackedScene = load("res://scenes/combat/environment/cosmos/scenes/cosmos_root.tscn") as PackedScene
	assert_true(root_scn != null, "La escena cosmos_root.tscn debe cargar correctamente.")

	_cosmos_root = root_scn.instantiate() as CosmosRootNode
	_scene_root.add_child(_cosmos_root)

	_camera = Camera2D.new()
	_camera.position = Vector2(1000.0, 500.0)
	_scene_root.add_child(_camera)
	_cosmos_root.camera = _camera

	_host_controller = CosmosHostController.new()
	_host_controller.cosmos_root = _cosmos_root
	_scene_root.add_child(_host_controller)

func _teardown_test_scene() -> void:
	if _scene_root != null:
		_scene_root.queue_free()

func _test_slot_generation_and_tracking() -> void:
	var tracker: CosmosOrbitalSlotTracker = _host_controller.get_slot_tracker()
	assert_true(tracker != null, "CosmosOrbitalSlotTracker debe ser accesible desde CosmosHostController.")

	# Forzar actualización inicial de streamers
	if _cosmos_root.solar_streamer != null:
		_cosmos_root.solar_streamer._update_streaming_and_orbits(0.0)

	var star_slots: Array[CosmosOrbitSlot] = _host_controller.get_star_orbit_slots(Vector2.ZERO, 30000.0)
	assert_true(not star_slots.is_empty(), "Debe encontrar al menos un slot orbital estelar en el área.")

	var first_star_slot: CosmosOrbitSlot = star_slots[0]
	assert_true(first_star_slot.center_type == CosmosOrbitSlot.SlotCenterType.STAR, "El tipo de slot debe ser STAR.")
	assert_true(first_star_slot.orbit_radius > 0.0, "El radio del slot de estrella debe ser mayor a 0.")
	assert_true(first_star_slot.angular_velocity != 0.0, "La velocidad angular kepleriana no debe ser 0.")

	var planet_slots: Array[CosmosOrbitSlot] = _host_controller.get_planet_orbit_slots(Vector2.ZERO, 30000.0)
	if not planet_slots.is_empty():
		var first_planet_slot: CosmosOrbitSlot = planet_slots[0]
		assert_true(first_planet_slot.center_type == CosmosOrbitSlot.SlotCenterType.PLANET, "El tipo de slot debe ser PLANET.")
		assert_true(first_planet_slot.orbit_radius > 0.0, "El radio de órbita del planeta debe ser positivo.")

func _test_world_projection_formula() -> void:
	# Crear slot analítico sintético para verificación matemática exacta
	var dummy_slot := CosmosOrbitSlot.new(
		CosmosOrbitSlot.SlotCenterType.STAR,
		Vector2i(0, 0),
		Vector2(2000.0, 1000.0),
		500.0,
		0.1,
		0.0,
		null,
		&"TestSlot",
		Vector2(0.20, 0.20)
	)

	# Posición de cámara conocida
	_camera.global_position = Vector2(400.0, 300.0)

	var t0: float = 0.0
	var layer_pos: Vector2 = dummy_slot.calculate_layer_position(t0) # Vector2(2500, 1000)
	assert_true(absf(layer_pos.x - 2500.0) <= 0.01, "Posición inicial en capa debe coincidir con center + r.")
	assert_true(absf(layer_pos.y - 1000.0) <= 0.01, "Posición inicial en capa y.")

	# Proyectar a GameplayWorld
	# PosWorld = PosCam * (1.0 - 0.20) + PosLayer = (400, 300)*0.8 + (2500, 1000) = (320, 240) + (2500, 1000) = (2820, 1240)
	var world_proj: Vector2 = CosmosOrbitalSlotTracker.project_slot_to_world(dummy_slot, t0, _camera)
	assert_true(absf(world_proj.x - 2820.0) <= 0.1, "Proyección X debe aplicar paralaje y offset de cámara.")
	assert_true(absf(world_proj.y - 1240.0) <= 0.1, "Proyección Y debe aplicar paralaje y offset de cámara.")

	# Verificar que en coordenadas de pantalla ambas entidades coinciden exactamente:
	# PosPantalla_Gameplay = world_proj - cam_pos = (2820, 1240) - (400, 300) = (2420, 940)
	# PosPantalla_Layer = layer_pos - cam_pos * scroll_scale = (2500, 1000) - (400, 300) * 0.20 = (2500, 1000) - (80, 60) = (2420, 940)
	var screen_gameplay: Vector2 = world_proj - _camera.global_position
	var screen_layer: Vector2 = layer_pos - (_camera.global_position * dummy_slot.layer_scroll_scale)
	assert_true(absf(screen_gameplay.x - screen_layer.x) <= 0.01, "La posición en pantalla debe ser idéntica entre Gameplay y Parallax.")
	assert_true(absf(screen_gameplay.y - screen_layer.y) <= 0.01, "La posición en pantalla debe ser idéntica entre Gameplay y Parallax.")

func _test_orbital_world_follower_behavior() -> void:
	var dummy_entity := Node2D.new()
	dummy_entity.name = "DummyGameplayEntity"
	_scene_root.add_child(dummy_entity)

	var dummy_slot := CosmosOrbitSlot.new(
		CosmosOrbitSlot.SlotCenterType.PLANET,
		Vector2i(0, 0),
		Vector2(1000.0, 500.0),
		200.0,
		0.5,
		0.0,
		null,
		&"TestPlanetSlot",
		Vector2(0.20, 0.20)
	)

	var follower := OrbitalWorldFollower2D.new()
	follower.name = "OrbitalWorldFollower2D"
	dummy_entity.add_child(follower)

	follower.setup_orbital_binding(dummy_slot, _camera, _cosmos_root)
	assert_true(follower.active, "El seguidor debe estar activo tras configurarse.")

	var initial_pos: Vector2 = dummy_entity.global_position
	assert_true(initial_pos != Vector2.ZERO, "La posición inicial debe sincronizarse inmediatamente.")

	# Simular avance de tiempo
	follower._update_position(1.0)
	var advanced_pos: Vector2 = dummy_entity.global_position
	assert_true(advanced_pos != initial_pos, "La entidad en GameplayWorld debe desplazarse siguiendo la órbita.")

	dummy_entity.queue_free()

func _test_zero_drift_long_term_orbit() -> void:
	var dummy_slot := CosmosOrbitSlot.new(
		CosmosOrbitSlot.SlotCenterType.STAR,
		Vector2i(0, 0),
		Vector2(0.0, 0.0),
		1000.0,
		0.02, # vel angular
		0.0,
		null,
		&"DriftTestSlot",
		Vector2(0.20, 0.20)
	)

	# Evaluar t = 0 y t = TAU / omega (un ciclo orbital completo)
	var period: float = TAU / 0.02
	var pos_t0: Vector2 = CosmosOrbitalSlotTracker.project_slot_to_world(dummy_slot, 0.0, _camera)
	var pos_1cycle: Vector2 = CosmosOrbitalSlotTracker.project_slot_to_world(dummy_slot, period, _camera)
	var pos_100cycles: Vector2 = CosmosOrbitalSlotTracker.project_slot_to_world(dummy_slot, period * 100.0, _camera)

	assert_true(absf(pos_t0.x - pos_1cycle.x) <= 0.01, "La posición tras 1 ciclo no debe tener deriva.")
	assert_true(absf(pos_t0.y - pos_1cycle.y) <= 0.01, "La posición tras 1 ciclo no debe tener deriva.")
	assert_true(absf(pos_t0.x - pos_100cycles.x) <= 0.02, "La posición tras 100 ciclos no debe tener deriva analítica.")
	assert_true(absf(pos_t0.y - pos_100cycles.y) <= 0.02, "La posición tras 100 ciclos no debe tener deriva analítica.")

func _test_spawner_orbital_direct_projection() -> void:
	var tracker: CosmosOrbitalSlotTracker = _host_controller.get_slot_tracker()
	var slots: Array[CosmosOrbitSlot] = tracker.get_star_orbit_slots(Vector2.ZERO, 30000.0)
	assert_true(not slots.is_empty(), "Tracker debe proveer slots de estrella.")

	var slot: CosmosOrbitSlot = slots[0]
	var cam: Camera2D = _camera
	var t0: float = _cosmos_root.get_global_time()
	var projected_pos: Vector2 = CosmosOrbitalSlotTracker.project_slot_to_world(slot, t0, cam)

	var dummy_planet := Node2D.new()
	dummy_planet.name = "DummyOrbitBoundPlanet"
	_scene_root.add_child(dummy_planet)
	dummy_planet.global_position = projected_pos

	var follower := OrbitalWorldFollower2D.new()
	dummy_planet.add_child(follower)
	follower.setup_orbital_binding(slot, cam, _cosmos_root)

	assert_true(dummy_planet.global_position.distance_to(projected_pos) <= 0.05, "La entidad spawnada directamente en el slot proyectado debe conservar su posición orbital sin saltos.")
	dummy_planet.queue_free()

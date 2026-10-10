class_name TestSolarSystem
extends BaseTestSuite

## Suite de pruebas unitarias y de integración determinista para SolarSystem2D, OrbitalBody2D y SolarSystemStreamer.
## Valida cinemática kepleriana analítica, reversibilidad temporal exacta (cero deriva numérica), y pooling.

var _system_profile: CelestialSystemProfile
var _solar_system: SolarSystem2D

func _ready() -> void:
	super._ready()
	_run_solar_system_tests()

func _run_solar_system_tests() -> void:
	_setup_test_profile()
	_test_analytical_orbital_evaluation()
	_test_hierarchical_moon_orbit()
	_test_zero_numerical_drift_reversibility()
	_test_solar_system_streamer_pooling()
	pass_suite("TestSolarSystem completado con éxito (100% de aserciones pasadas).")

func _setup_test_profile() -> void:
	_system_profile = CelestialSystemProfile.new()
	_system_profile.star_name_prefix = "TEST_STAR"
	_system_profile.star_base_radius = 400.0
	_system_profile.min_planets = 3
	_system_profile.max_planets = 5
	_system_profile.orbit_radius_min = 1000.0
	_system_profile.orbit_radius_max = 5000.0
	_system_profile.base_angular_velocity = 0.05
	_system_profile.moon_spawn_probability = 1.0 # Forzar luna en tests
	_system_profile.moon_orbit_radius_range = Vector2(150.0, 250.0)

	_solar_system = SolarSystem2D.new()
	_solar_system.system_profile = _system_profile
	add_child(_solar_system)

func _test_analytical_orbital_evaluation() -> void:
	var body: OrbitalBody2D = OrbitalBody2D.new()
	body.orbit_radius = 1000.0
	body.angular_velocity = 0.1
	body.initial_theta = 0.0
	add_child(body)

	# En t = 0 -> (1000, 0)
	body.evaluate_orbital_position(0.0)
	assert_true(is_equal_approx(body.position.x, 1000.0), "La posición X inicial debe ser r * cos(0) = 1000.")
	assert_true(is_equal_approx(body.position.y, 0.0), "La posición Y inicial debe ser r * sin(0) = 0.")

	# En t = PI / (2 * 0.1) = 5 * PI -> theta = PI/2 -> (0, 1000)
	var t_quarter: float = (PI * 0.5) / 0.1
	body.evaluate_orbital_position(t_quarter)
	assert_true(absf(body.position.x) < 0.001, "A un cuarto de órbita (PI/2), X debe ser ~0.")
	assert_true(is_equal_approx(body.position.y, 1000.0), "A un cuarto de órbita (PI/2), Y debe ser 1000.")

	body.queue_free()

func _test_hierarchical_moon_orbit() -> void:
	var planet: OrbitalBody2D = OrbitalBody2D.new()
	planet.orbit_radius = 2000.0
	planet.angular_velocity = 0.02
	planet.initial_theta = 0.0
	add_child(planet)

	var moon: OrbitalBody2D = OrbitalBody2D.new()
	moon.orbit_radius = 200.0
	moon.angular_velocity = 0.2
	moon.initial_theta = 0.0
	planet.add_orbital_child(moon)

	# Evaluar estado en t = 10.0
	var test_t: float = 10.0
	planet.evaluate_orbital_position(test_t)

	var expected_planet_theta: float = 0.02 * test_t
	var expected_planet_pos: Vector2 = Vector2(2000.0 * cos(expected_planet_theta), 2000.0 * sin(expected_planet_theta))
	assert_true(planet.position.distance_to(expected_planet_pos) < 0.001, "La posición del planeta debe concordar analíticamente.")

	var expected_moon_theta: float = 0.2 * test_t
	var expected_moon_local_pos: Vector2 = Vector2(200.0 * cos(expected_moon_theta), 200.0 * sin(expected_moon_theta))
	assert_true(moon.position.distance_to(expected_moon_local_pos) < 0.001, "La posición local de la luna relativa a su planeta debe ser exacta.")

	planet.queue_free()

func _test_zero_numerical_drift_reversibility() -> void:
	# Construir sistema completo
	_solar_system.build_system(49152)
	assert_true(_solar_system.planets.size() >= 3, "El sistema solar debe haber instanciado al menos 3 planetas.")

	# Evaluar t = 0 y registrar posiciones locales exactas
	_solar_system.update_astronomical_state(0.0)
	var initial_positions: Array[Vector2] = []
	for p: OrbitalBody2D in _solar_system.planets:
		initial_positions.append(p.position)

	# Saltar a un tiempo cósmico lejano (t = 10000.0 s)
	_solar_system.update_astronomical_state(10000.0)
	
	# Verificar que los planetas se hayan movido
	var moved: bool = false
	for i: int in range(_solar_system.planets.size()):
		if _solar_system.planets[i].position.distance_to(initial_positions[i]) > 1.0:
			moved = true
			break
	assert_true(moved, "Los planetas deben haberse desplazado a t = 10000 s.")

	# Reversibilidad estricta: volver a evaluar exactamente t = 0.0
	_solar_system.update_astronomical_state(0.0)

	for i: int in range(_solar_system.planets.size()):
		var err_dist: float = _solar_system.planets[i].position.distance_to(initial_positions[i])
		assert_true(err_dist < 0.0001, "Error euclidiano en t=0 tras simulación debe ser < 0.0001 px (obtenido: " + str(err_dist) + "). Cero deriva numérica garantizada.")

func _test_solar_system_streamer_pooling() -> void:
	var streamer: SolarSystemStreamer = SolarSystemStreamer.new()
	streamer.system_profile = _system_profile
	streamer.pool_size = 3
	streamer.cell_size = 20000.0
	add_child(streamer)

	assert_true(streamer.get_pool_available_count() == 3, "El streamer debe haber pre-asignado 3 instancias de SolarSystem2D en su pool.")
	assert_true(streamer.get_active_systems_count() == 0, "No debe haber sistemas activos sin cámara configurada.")

	# Simular actualización con tiempo
	streamer._update_streaming_and_orbits(50.0)
	assert_true(streamer.get_pool_available_count() == 3, "El pool debe mantenerse íntegro y sin fugas.")

	streamer.queue_free()

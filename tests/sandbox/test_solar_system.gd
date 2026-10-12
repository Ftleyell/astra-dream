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
	_test_star_archetypes_and_visual_light()
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

	# Validar matemáticamente que ningún sistema solar cruza el margen periférico (cell_boundary_padding = 500px)
	var test_cells: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, -1), Vector2i(2, 3)]
	for c in test_cells:
		var c_center: Vector2 = streamer.get_macro_grid().grid_to_world_center(c)
		var s_pos: Vector2 = streamer.get_system_position_for_cell(c)
		var offset_from_center: Vector2 = (s_pos - c_center).abs()
		var max_allowed_half: float = (streamer.cell_size * 0.5) - _system_profile.cell_boundary_padding
		# El centro del sol + su radio de alcance debe respetar el medio ancho seguro
		assert_true(offset_from_center.x <= max_allowed_half + 0.1, "El jitter X debe permanecer dentro del margen seguro.")
		assert_true(offset_from_center.y <= max_allowed_half + 0.1, "El jitter Y debe permanecer dentro del margen seguro.")

	streamer.queue_free()

func _test_star_archetypes_and_visual_light() -> void:
	# Cargar o instanciar los 3 arquetipos estelares
	var arch_yellow: StarArchetype = load("res://sandbox/resources/data/star_archetypes/yellow_dwarf.tres")
	var arch_blue: StarArchetype = load("res://sandbox/resources/data/star_archetypes/blue_giant.tres")
	var arch_red: StarArchetype = load("res://sandbox/resources/data/star_archetypes/red_dwarf.tres")

	assert_true(arch_yellow != null, "yellow_dwarf.tres debe existir y cargar correctamente.")
	assert_true(arch_blue != null, "blue_giant.tres debe existir y cargar correctamente.")
	assert_true(arch_red != null, "red_dwarf.tres debe existir y cargar correctamente.")

	var multi_profile: CelestialSystemProfile = load("res://sandbox/resources/data/default_celestial_system.tres")
	assert_true(multi_profile != null, "default_celestial_system.tres debe cargar correctamente.")

	# Comprobar selección ponderada determinista
	var selected_arch: StarArchetype = multi_profile.get_archetype_for_seed(12345)
	assert_true(selected_arch != null, "La selección determinista de arquetipo debe retornar un StarArchetype válido.")

	# Comprobar construcción de sistema solar con arquetipo
	var test_system: SolarSystem2D = SolarSystem2D.new()
	test_system.system_profile = multi_profile
	add_child(test_system)
	test_system.build_system(8888)

	assert_true(test_system.active_archetype != null, "El sistema solar debe tener su active_archetype asignado.")
	assert_true(test_system.star_body != null, "El sistema solar debe instanciar su star_body central.")

	# Verificar StarVisual y su ShaderMaterial
	var star_visual: Sprite2D = test_system.star_body.get_node_or_null("StarVisual") as Sprite2D
	assert_true(star_visual != null, "CentralStar debe contener un nodo hijo StarVisual.")
	assert_true(star_visual.material != null, "StarVisual debe tener asignado su ShaderMaterial de corona estelar.")
	var star_mat: ShaderMaterial = star_visual.material as ShaderMaterial
	assert_true(star_mat != null, "El material de StarVisual debe ser de tipo ShaderMaterial.")
	assert_true(star_mat.get_shader_parameter("heat_distortion_strength") > 0.0, "El shader de la estrella debe tener heat_distortion_strength activo.")

	# Verificar StarFlatCore y su ShaderMaterial de fondo plano sólido
	var star_flat_core: Sprite2D = test_system.star_body.get_node_or_null("StarFlatCore") as Sprite2D
	assert_true(star_flat_core != null, "CentralStar debe contener el fondo plano StarFlatCore.")
	assert_true(star_flat_core.material != null, "StarFlatCore debe tener asignado su ShaderMaterial.")
	var flat_core_mat: ShaderMaterial = star_flat_core.material as ShaderMaterial
	assert_true(flat_core_mat != null, "El material de StarFlatCore debe ser ShaderMaterial.")
	var assigned_flat_color: Color = flat_core_mat.get_shader_parameter("flat_color")
	assert_true(assigned_flat_color.a > 0.0, "StarFlatCore debe tener un flat_color opaco configurado.")
	var assigned_core_radius: float = flat_core_mat.get_shader_parameter("core_radius")
	assert_true(assigned_core_radius <= 0.35 and assigned_core_radius >= 0.25, "El radio del núcleo plano debe estar calibrado acorde a la masa del sol (0.25 - 0.35).")

	# Verificar SolarSystemLightField y su ShaderMaterial de luz ambiental orbital
	var light_field: Sprite2D = test_system.star_body.get_node_or_null("SolarSystemLightField") as Sprite2D
	assert_true(light_field != null, "CentralStar debe contener el campo de luz ambiental SolarSystemLightField.")
	assert_true(light_field.material != null, "SolarSystemLightField debe tener asignado su ShaderMaterial.")
	var light_mat: ShaderMaterial = light_field.material as ShaderMaterial
	assert_true(light_mat != null, "El material de luz debe ser ShaderMaterial.")
	assert_true(light_mat.get_shader_parameter("heliosphere_noise_strength") > 0.0, "La heliosfera debe tener heliosphere_noise_strength activo.")
	assert_true(light_mat.get_shader_parameter("heliosphere_edge_feather") > 0.0, "La heliosfera debe tener heliosphere_edge_feather activo.")
	var field_scale: float = light_field.scale.x
	assert_true(field_scale >= test_system.active_archetype.orbit_radius_max, "La escala del campo de luz debe cubrir todo el rango orbital exterior.")

	# Verificar que el bounding radius cubre la luz orbital y los planetas
	assert_true(test_system.get_bounding_radius() >= field_scale, "El bounding radius debe abarcar el campo de luz orbital.")

	# Verificar escala de planetas (al 75% del rango base) y tinte solar estelar
	for planet: OrbitalBody2D in test_system.planets:
		var p_vis: Sprite2D = planet.get_node_or_null("PlanetVisual") as Sprite2D
		assert_true(p_vis != null, "Cada planeta debe tener su nodo PlanetVisual.")
		assert_true(p_vis.scale.x <= (1.1 * 0.75 + 0.001), "La escala del planeta debe estar dentro del 75% del tamaño base.")
		var p_mat: ShaderMaterial = p_vis.material as ShaderMaterial
		assert_true(p_mat != null, "El material de PlanetVisual debe ser ShaderMaterial.")
		assert_true(p_mat.get_shader_parameter("star_light_tint_strength") > 0.0, "El planeta debe recibir tinte solar estelar.")

		# Verificar que cada planeta tiene al menos 1 estación espacial orbitando
		var station: OrbitalBody2D = planet.get_node_or_null("Station_1") as OrbitalBody2D
		if station == null:
			for ch in planet.get_children():
				if ch is OrbitalBody2D and ch.name.begins_with("Station_"):
					station = ch
					break
		assert_true(station != null, "Cada planeta debe tener garantizada su estación espacial orbitando.")
		var st_vis: Sprite2D = station.get_node_or_null("StationVisual") as Sprite2D
		assert_true(st_vis != null, "La estación debe tener su nodo StationVisual.")
		var p_diam: float = (float(p_vis.texture.get_width()) if p_vis.texture != null else 256.0) * p_vis.scale.x
		var st_diam: float = (float(st_vis.texture.get_width()) if st_vis.texture != null else 128.0) * st_vis.scale.x
		assert_true(is_equal_approx(st_diam, p_diam * 0.15), "El diámetro visual de la estación debe ser exactamente el 15% del planeta.")

	# Verificar buffer orbital mínimo garantizado anti-pisado entre planetas consecutivos
	var min_gap: float = test_system.active_archetype.min_orbital_spacing
	for i: int in range(test_system.planets.size() - 1):
		var p1: OrbitalBody2D = test_system.planets[i]
		var p2: OrbitalBody2D = test_system.planets[i + 1]
		var gap: float = p2.orbit_radius - p1.orbit_radius
		assert_true(gap >= min_gap - 0.1, "El espacio entre las órbitas %d y %d debe ser >= %.1f (obtenido: %.1f). Cero colisiones garantizadas." % [i, i + 1, min_gap, gap])

	test_system.queue_free()

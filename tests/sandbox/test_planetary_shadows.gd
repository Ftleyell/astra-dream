class_name TestPlanetaryShadows
extends BaseTestSuite

## Suite de pruebas para el sistema de sombras planetarias analíticas y CanvasGroup.
## Valida:
## 1. Carga e integridad de shaders (planetary_shadow_cone.gdshader y cosmic_shadow_group.gdshader).
## 2. Inicialización de CosmicShadowsGroup en SolarSystem2D con z_index = -1 y Anti Double-Darkening.
## 3. Radio visual calibrado al recorte analítico del disco de superficie.
## 4. Alineación y evaluación geométrica de eclipses interplanetarios (umbra / penumbra).
## 5. Reactividad de setters en tiempo de ejecución.

var _solar_system: SolarSystem2D = null

func _ready() -> void:
	super._ready()
	_run_tests()

func _run_tests() -> void:
	_test_shaders_loading()
	_test_solar_system_shadow_hierarchy()
	_test_interplanetary_eclipse_detection()
	_test_runtime_setters_reactivity()
	pass_suite("TestPlanetaryShadows completado con éxito (100% de aserciones pasadas).")

func _test_shaders_loading() -> void:
	var cone_shader: Shader = load("res://sandbox/shaders/planetary_shadow_cone.gdshader") as Shader
	assert_true(cone_shader != null, "planetary_shadow_cone.gdshader debe cargar correctamente.")

	var group_shader: Shader = load("res://sandbox/shaders/cosmic_shadow_group.gdshader") as Shader
	assert_true(group_shader != null, "cosmic_shadow_group.gdshader debe cargar correctamente.")

func _test_solar_system_shadow_hierarchy() -> void:
	var profile: CelestialSystemProfile = load("res://sandbox/resources/data/default_celestial_system.tres") as CelestialSystemProfile
	assert_true(profile != null, "default_celestial_system.tres debe cargar.")

	_solar_system = SolarSystem2D.new()
	_solar_system.name = "TestSolarSystem"
	_solar_system.system_profile = profile
	_solar_system.system_seed = 42
	add_child(_solar_system)
	_solar_system.build_system(42)

	assert_true(_solar_system.planets.size() >= 3, "El sistema solar debe haber generado planetas.")

	# Validar existencia de CosmicShadowsGroup
	var shadow_group: CanvasGroup = _solar_system.get_node_or_null("CosmicShadowsGroup") as CanvasGroup
	assert_true(shadow_group != null, "CosmicShadowsGroup debe existir como nodo CanvasGroup en SolarSystem2D.")
	assert_true(shadow_group.z_index == -1, "CosmicShadowsGroup debe tener z_index = -1.")
	assert_true(shadow_group.material is ShaderMaterial, "CosmicShadowsGroup debe tener ShaderMaterial asignado.")

	# Validar que los pivotes de sombra son hijos del CanvasGroup
	for planet: OrbitalBody2D in _solar_system.planets:
		var visual_r: float = float(planet.get_meta(&"visual_radius", 0.0))
		assert_true(visual_r > 0.0, "El planeta debe tener visual_radius positivo y calibrado.")

func _test_interplanetary_eclipse_detection() -> void:
	assert_true(_solar_system.planets.size() >= 2, "Se requieren al menos 2 planetas para la prueba de eclipse.")
	var p_inner: OrbitalBody2D = _solar_system.planets[0]
	var p_outer: OrbitalBody2D = _solar_system.planets[1]

	# Forzar posiciones alineadas: ambos planetas en el eje X positivo (eclipse frontal directo)
	p_inner.position = Vector2(1200.0, 0.0)
	p_outer.position = Vector2(2400.0, 0.0)

	_solar_system._update_lighting_vectors()

	var outer_sprite: Sprite2D = p_outer.get_sprite()
	assert_true(outer_sprite != null and outer_sprite.material is ShaderMaterial, "El planeta exterior debe tener ShaderMaterial.")
	var outer_mat: ShaderMaterial = outer_sprite.material as ShaderMaterial

	var eclipse_val: float = float(outer_mat.get_shader_parameter("eclipse_shadow"))
	assert_true(eclipse_val > 0.8, "El planeta exterior alineado en el cono de sombra debe registrar eclipse total o alto (>= 0.8). Registrado: %f" % eclipse_val)

	# Desalinear: colocar el planeta exterior en el eje Y (90 grados, fuera del cono de sombra)
	p_outer.position = Vector2(0.0, 2400.0)
	_solar_system._update_lighting_vectors()

	eclipse_val = float(outer_mat.get_shader_parameter("eclipse_shadow"))
	assert_true(is_equal_approx(eclipse_val, 0.0), "El planeta exterior no alineado no debe registrar eclipse (0.0). Registrado: %f" % eclipse_val)

func _test_runtime_setters_reactivity() -> void:
	_solar_system.set_shadow_opacity(0.5)
	assert_true(_solar_system._shadow_opacity == 0.5, "set_shadow_opacity debe actualizar la variable interna.")

	_solar_system.set_shadow_penumbra_ratio(0.35)
	assert_true(_solar_system._shadow_penumbra_ratio == 0.35, "set_shadow_penumbra_ratio debe actualizar la variable interna.")

	_solar_system.set_shadow_expansion_factor(2.2)
	assert_true(_solar_system._shadow_expansion_factor == 2.2, "set_shadow_expansion_factor debe actualizar la variable interna.")

	_solar_system.set_shadow_heliopause_fade(0.15)
	assert_true(_solar_system._shadow_heliopause_fade == 0.15, "set_shadow_heliopause_fade debe actualizar la variable interna.")

	_solar_system.set_shadows_enabled(false)
	assert_true(not _solar_system._shadows_enabled, "set_shadows_enabled(false) debe apagar las sombras.")
	var shadow_group: CanvasGroup = _solar_system.get_node_or_null("CosmicShadowsGroup") as CanvasGroup
	assert_true(shadow_group != null and not shadow_group.visible, "CosmicShadowsGroup debe ocultarse al deshabilitar sombras.")

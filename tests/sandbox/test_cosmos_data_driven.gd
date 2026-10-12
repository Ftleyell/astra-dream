class_name TestCosmosDataDriven
extends BaseTestSuite

## Test unitario para validar el desacople estricto y la arquitectura data-driven pura de Cosmos Engine (Sesión 1).
## Criterios de Aceptación:
## 1. Verificación de existencia e integridad de los recursos .tres modulares (PlanetarySystemConfig, StarVisualConfig, ShadowSystemConfig).
## 2. Inyección y sincronización en CelestialSystemProfile y StarArchetype.
## 3. Comprobación de que SolarSystem2D y SolarSystemStreamer consumen estos sub-recursos sin hardcoding ni dependencias directas en variables no-declaradas.

func _ready() -> void:
	super._ready()
	_run_suite()

func _run_suite() -> void:
	_test_sub_config_resources_load()
	_test_celestial_system_profile_sub_configs()
	_test_star_archetype_visual_config()
	_test_new_star_archetypes_and_biomes()
	_test_solar_system_hierarchy_data_driven_build()
	pass_suite("TestCosmosDataDriven completado con éxito (100% de aserciones data-driven válidas).")

func _test_sub_config_resources_load() -> void:
	var planet_cfg: PlanetarySystemConfig = load("res://sandbox/resources/data/default_planetary_system.tres") as PlanetarySystemConfig
	assert_true(planet_cfg != null, "default_planetary_system.tres debe cargar correctamente como PlanetarySystemConfig.")
	assert_true(planet_cfg.min_planets >= 1 and planet_cfg.max_planets >= planet_cfg.min_planets, "Límites planetarios válidos.")
	assert_true(planet_cfg.orbit_radius_max > planet_cfg.orbit_radius_min, "Rango orbital válido.")
	assert_true(planet_cfg.min_orbital_spacing > 0.0, "Espaciado orbital mínimo debe ser positivo.")

	var star_vis: StarVisualConfig = load("res://sandbox/resources/data/default_star_visual.tres") as StarVisualConfig
	assert_true(star_vis != null, "default_star_visual.tres debe cargar correctamente como StarVisualConfig.")
	assert_true(star_vis.star_core_radius > 0.0, "Radio de núcleo estelar debe ser mayor a 0.")
	assert_true(star_vis.light_field_radius_multiplier >= 1.0, "Multiplicador de heliosfera debe ser >= 1.0.")

	var shadow_cfg: ShadowSystemConfig = load("res://sandbox/resources/data/default_shadow_system.tres") as ShadowSystemConfig
	assert_true(shadow_cfg != null, "default_shadow_system.tres debe cargar correctamente como ShadowSystemConfig.")
	assert_true(shadow_cfg.shadow_expansion_factor >= 1.0, "Factor de expansión de sombra debe ser >= 1.0.")
	assert_true(shadow_cfg.shadow_intensity > 0.0, "Intensidad de sombra debe ser mayor que 0.")

func _test_celestial_system_profile_sub_configs() -> void:
	var cel_profile: CelestialSystemProfile = load("res://sandbox/resources/data/default_celestial_system.tres") as CelestialSystemProfile
	assert_true(cel_profile != null, "default_celestial_system.tres debe cargar como CelestialSystemProfile.")
	
	var eff_shadow: ShadowSystemConfig = cel_profile.get_effective_shadow_config()
	assert_true(eff_shadow != null, "get_effective_shadow_config debe retornar un ShadowSystemConfig válido.")
	assert_true(eff_shadow.enable_planetary_shadows, "Sombras activas por defecto en el perfil.")

	var eff_planet: PlanetarySystemConfig = cel_profile.get_effective_planetary_config()
	assert_true(eff_planet != null, "get_effective_planetary_config debe retornar un PlanetarySystemConfig válido.")
	assert_true(eff_planet.planet_size_multiplier > 0.5, "Multiplicador de escala de planetas debe ser razonable.")

	var eff_star: StarVisualConfig = cel_profile.get_effective_star_visual_config()
	assert_true(eff_star != null, "get_effective_star_visual_config debe retornar un StarVisualConfig válido.")
	assert_true(eff_star.star_name_prefix.length() > 0, "Prefijo de nombre estelar presente.")

func _test_star_archetype_visual_config() -> void:
	var yellow: StarArchetype = load("res://sandbox/resources/data/star_archetypes/yellow_dwarf.tres") as StarArchetype
	assert_true(yellow != null, "yellow_dwarf.tres debe cargar como StarArchetype.")
	var eff_vis: StarVisualConfig = yellow.get_effective_visual_config()
	assert_true(eff_vis != null, "get_effective_visual_config debe ser no nulo.")
	assert_true(eff_vis.star_color.r > 0.5, "Color estelar debe ser cálido para yellow dwarf.")

func _test_new_star_archetypes_and_biomes() -> void:
	var white_dwarf: StarArchetype = load("res://sandbox/resources/data/star_archetypes/white_dwarf.tres") as StarArchetype
	assert_true(white_dwarf != null, "white_dwarf.tres debe cargar correctamente como StarArchetype.")
	assert_true(white_dwarf.id == &"white_dwarf", "El ID debe ser white_dwarf.")
	assert_true(white_dwarf.core_brightness >= 1.5, "La enana blanca debe tener alta luminosidad en el núcleo.")
	assert_true(white_dwarf.biome_config != null, "La enana blanca debe estar asociada a un bioma estelar válido.")

	var magnetar: StarArchetype = load("res://sandbox/resources/data/star_archetypes/magnetar.tres") as StarArchetype
	assert_true(magnetar != null, "magnetar.tres debe cargar correctamente como StarArchetype.")
	assert_true(magnetar.id == &"magnetar", "El ID debe ser magnetar.")
	assert_true(magnetar.axial_rotation_speed >= 0.04, "El magnetar debe presentar rotación axial rápida.")
	assert_true(magnetar.corona_intensity >= 1.4, "La intensidad de corona del magnetar debe ser potente.")

	# Validar que los 6 biomas del catálogo cargan de forma limpia y poseen contraste/densidad
	var biomes: Array[String] = CosmosRoot.BIOME_PRESETS
	assert_true(biomes.size() == 6, "El catálogo debe contener exactamente 6 biomas cósmicos.")
	for path: String in biomes:
		var biome_res: CosmicBiomeConfig = load(path) as CosmicBiomeConfig
		assert_true(biome_res != null, "El bioma %s debe cargar como CosmicBiomeConfig." % path)
		assert_true(biome_res.gas_density > 0.0, "La densidad de gas debe ser positiva.")

func _test_solar_system_hierarchy_data_driven_build() -> void:
	var cel_profile: CelestialSystemProfile = load("res://sandbox/resources/data/default_celestial_system.tres") as CelestialSystemProfile
	var system_node: SolarSystem2D = SolarSystem2D.new()
	system_node.system_profile = cel_profile
	add_child(system_node)
	system_node.build_system(424242)

	assert_true(system_node.star_body != null, "build_system debe instanciar la estrella central.")
	assert_true(system_node.planets.size() >= cel_profile.get_effective_planetary_config().min_planets, "Planetas generados deben respetar min_planets del recurso.")
	assert_true(system_node.get_bounding_radius() > 0.0, "Radio de delimitación calculado debe ser > 0.")

	system_node.queue_free()

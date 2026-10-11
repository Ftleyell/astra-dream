class_name TestCosmosEnvironmentProfile
extends BaseTestSuite

## Suite de pruebas para CosmosEnvironmentProfile y el sistema de Hot-Debugging.
## Valida:
## 1. Integridad del recurso maestro unificado (.tres).
## 2. Propagación reactiva en caliente de factores de paralaje y shaders a CosmosRoot.
## 3. Conmutación de visibilidad de estratos 1 a 5.
## 4. Control de escala de tiempo cósmico (Time Warp).
## 5. Funcionamiento e integridad de CosmosDebugDrawer2D.

var _scene_instance: Node2D = null
var _cosmos_root: CosmosRoot = null

func _ready() -> void:
	super._ready()
	_run_suite()

func _run_suite() -> void:
	_test_profile_resource_integrity()
	_test_strata_propagation_and_reactivity()
	_test_layer_visibility_toggles()
	_test_time_warp_controls()
	_test_visual_debugger_gizmos()
	_test_six_cosmic_biomes()
	pass_suite("TestCosmosEnvironmentProfile completado con éxito (100% de aserciones pasadas).")

func _test_profile_resource_integrity() -> void:
	var res: CosmosEnvironmentProfile = load("res://sandbox/resources/data/default_cosmos_environment.tres") as CosmosEnvironmentProfile
	assert_true(res != null, "default_cosmos_environment.tres debe cargar como CosmosEnvironmentProfile.")
	assert_true(res.biome_a_profile != null, "Sub-perfil de bioma A debe estar vinculado.")
	assert_true(res.galaxy_profile != null, "Sub-perfil de galaxia debe estar vinculado.")
	assert_true(res.solar_profile != null, "Sub-perfil solar debe estar vinculado.")
	assert_true(res.debris_profile != null, "Sub-perfil de escombros debe estar vinculado.")
	assert_true(res.parallax_multiplier == 1.0, "Parallax multiplier por defecto debe ser 1.0.")
	assert_true(res.star_intensity > 0.0, "Intensidad estelar debe ser mayor que 0.")
	assert_true(res.nebula_deep_stars_intensity > 0.0, "Intensidad de microestrellas nebulares debe ser mayor que 0.")

func _test_strata_propagation_and_reactivity() -> void:
	var demo_scene: PackedScene = load("res://sandbox/scenes/cosmos_engine_demo.tscn") as PackedScene
	assert_true(demo_scene != null, "cosmos_engine_demo.tscn debe cargar correctamente.")

	_scene_instance = demo_scene.instantiate() as Node2D
	add_child(_scene_instance)

	_cosmos_root = _scene_instance.get_node_or_null("CosmosRoot") as CosmosRoot
	assert_true(_cosmos_root != null, "CosmosRoot debe existir en la escena demo.")
	assert_true(_cosmos_root.environment_profile != null, "CosmosRoot debe tener asignado environment_profile.")

	var prof: CosmosEnvironmentProfile = _cosmos_root.environment_profile

	# Verificar propagación inicial
	assert_true(_cosmos_root.parallax_macro_galaxies.scroll_scale.is_equal_approx(prof.galaxy_scroll_scale), "Scroll scale de galaxias debe coincidir con el perfil.")
	assert_true(_cosmos_root.parallax_starfield_8k.scroll_scale.is_equal_approx(prof.starfield_scroll_scale), "Scroll scale de starfield debe coincidir con el perfil.")
	assert_true(_cosmos_root.parallax_solar_systems.scroll_scale.is_equal_approx(prof.solar_scroll_scale), "Scroll scale solar debe coincidir con el perfil.")
	assert_true(_cosmos_root.parallax_debris_belt.scroll_scale.is_equal_approx(prof.debris_scroll_scale), "Scroll scale de escombros debe coincidir con el perfil.")

	# Modificar multiplicador en caliente y verificar propagación reactiva automática
	prof.parallax_multiplier = 2.0
	assert_true(_cosmos_root.parallax_macro_galaxies.scroll_scale.is_equal_approx(prof.galaxy_scroll_scale * 2.0), "Scroll scale de galaxias debe reaccionar al multiplicador.")
	assert_true(_cosmos_root.parallax_starfield_8k.scroll_scale.is_equal_approx(prof.starfield_scroll_scale * 2.0), "Scroll scale de starfield debe reaccionar al multiplicador.")
	assert_true(_cosmos_root.parallax_solar_systems.scroll_scale.is_equal_approx(prof.solar_scroll_scale * 2.0), "Scroll scale solar debe reaccionar al multiplicador.")
	assert_true(_cosmos_root.parallax_debris_belt.scroll_scale.is_equal_approx(prof.debris_scroll_scale * 2.0), "Scroll scale de escombros debe reaccionar al multiplicador.")

	# Restaurar multiplicador
	prof.parallax_multiplier = 1.0

func _test_layer_visibility_toggles() -> void:
	for layer_idx: int in range(1, 6):
		assert_true(_cosmos_root.get_layer_visibility(layer_idx), "La capa %d debe iniciar visible." % layer_idx)
		
		_cosmos_root.set_layer_visibility(layer_idx, false)
		assert_true(not _cosmos_root.get_layer_visibility(layer_idx), "La capa %d debe ocultarse correctamente." % layer_idx)
		
		var toggled_st: bool = _cosmos_root.toggle_layer_visibility(layer_idx)
		assert_true(toggled_st and _cosmos_root.get_layer_visibility(layer_idx), "La capa %d debe volver a ser visible tras toggle." % layer_idx)

func _test_time_warp_controls() -> void:
	var initial_time: float = _cosmos_root.get_global_time()

	# Probar warp 5x
	_cosmos_root.time_scale = 5.0
	_cosmos_root._process(1.0)
	var time_after_5x: float = _cosmos_root.get_global_time()
	assert_true(is_equal_approx(time_after_5x - initial_time, 5.0), "Warp 5x debe avanzar 5.0 segundos por cada segundo delta.")

	# Probar pausa 0x
	_cosmos_root.time_scale = 0.0
	_cosmos_root._process(1.0)
	var time_after_pause: float = _cosmos_root.get_global_time()
	assert_true(is_equal_approx(time_after_pause, time_after_5x), "Warp 0x no debe incrementar el tiempo cósmico.")

	# Restaurar tiempo
	_cosmos_root.time_scale = 1.0

func _test_visual_debugger_gizmos() -> void:
	var drawer: CosmosDebugDrawer2D = _cosmos_root.get_node_or_null("CosmosDebugDrawer2D") as CosmosDebugDrawer2D
	assert_true(drawer != null, "CosmosDebugDrawer2D debe existir en CosmosRoot.")

	assert_true(not drawer.enabled, "Gizmos deben iniciar desactivados por defecto.")
	var active_st: bool = drawer.toggle_debug_draw()
	assert_true(active_st and drawer.enabled, "toggle_debug_draw debe habilitar los gizmos.")

	# Simular proceso y dibujo sin excepciones
	drawer._process(0.016)
	drawer._draw()

	var inactive_st: bool = drawer.toggle_debug_draw()
	assert_true(not inactive_st and not drawer.enabled, "toggle_debug_draw debe deshabilitar los gizmos.")

func _test_six_cosmic_biomes() -> void:
	assert_true(CosmosRoot.BIOME_PRESETS.size() == 6, "Deben existir exactamente 6 presets de bioma.")

	for idx: int in range(CosmosRoot.BIOME_PRESETS.size()):
		var path: String = CosmosRoot.BIOME_PRESETS[idx]
		var b: CosmicBiomeConfig = load(path) as CosmicBiomeConfig
		assert_true(b != null, "Bioma en %s debe cargar correctamente como CosmicBiomeConfig." % path)
		assert_true(not b.biome_id.is_empty(), "Bioma %s debe tener un biome_id válido." % path)
		assert_true(not b.display_name.is_empty(), "Bioma %s debe tener un display_name válido." % path)
		assert_true(b.gas_density > 0.0, "Bioma %s debe tener gas_density positivo." % path)
		assert_true(is_equal_approx(b.gas_density, 2.0), "Bioma %s debe tener gas_density configurado en 2.0 por defecto." % path)
		assert_true(b.gas_contrast > 0.0, "Bioma %s debe tener gas_contrast positivo." % path)
		assert_true(b.starfield_energy > 0.0, "Bioma %s debe tener starfield_energy positivo." % path)

	# Probar ciclo en runtime
	var initial_biome_idx: int = _cosmos_root.get_active_biome_index()
	var next_b: CosmicBiomeConfig = _cosmos_root.cycle_biome(true)
	assert_true(next_b != null, "cycle_biome(true) debe devolver un nuevo bioma.")
	assert_true(_cosmos_root.get_active_biome_index() == (initial_biome_idx + 1) % 6, "Índice de bioma activo debe incrementarse.")
	assert_true(_cosmos_root.environment_profile.biome_a_profile == next_b, "El perfil de entorno debe actualizarse con el nuevo bioma.")

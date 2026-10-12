class_name TestCosmicPoiRegistry
extends BaseTestSuite

const CosmicPoiConfig = preload("res://scenes/combat/environment/cosmos/resources/cosmic_poi_config.gd")
const CosmicPoiRegistry = preload("res://scenes/combat/environment/cosmos/core/cosmic_poi_registry.gd")

## Suite de pruebas para verificar CosmicPoiRegistry y la inyección narrativa determinista (Sesión 2).

func _ready() -> void:
	timeout_seconds = 8.0
	super._ready()
	_run_suite()

func _run_suite() -> void:
	_test_poi_registration_and_lookup()
	_test_solar_system_poi_injection()
	_test_cosmos_root_delegation()
	pass_suite("TestCosmicPoiRegistry completado con éxito (100% verificado).")

func _test_poi_registration_and_lookup() -> void:
	var registry: CosmicPoiRegistry = CosmicPoiRegistry.new()
	assert_true(registry.get_poi_count() == 0, "El registro debe iniciar vacío.")
	
	var poi: CosmicPoiConfig = CosmicPoiConfig.new()
	poi.custom_label = &"Terra_Nova_Prime"
	poi.planet_count = 5
	poi.hazard_level = 2
	
	var cell_abs: Vector2i = Vector2i(4, -2)
	registry.register_poi(cell_abs, poi)
	
	assert_true(registry.has_poi(cell_abs), "has_poi debe retornar true para celda registrada.")
	assert_true(registry.get_poi(cell_abs) == poi, "get_poi debe retornar la instancia exacta registrada.")
	assert_true(registry.get_poi_count() == 1, "Debe haber 1 POI registrado.")
	
	# Registro relativo
	var origin: Vector2i = Vector2i(10, 10)
	var offset: Vector2i = Vector2i(3, -4)
	var target_cell: Vector2i = registry.register_relative_poi(offset, poi, origin)
	assert_true(target_cell == Vector2i(13, 6), "register_relative_poi debe calcular correctamente la coordenada absoluta.")
	assert_true(registry.has_poi(Vector2i(13, 6)), "La celda relativa debe existir en el registro.")
	assert_true(registry.get_poi_count() == 2, "Debe haber 2 POIs registrados.")
	
	# Desregistro
	registry.unregister_poi(cell_abs)
	assert_true(not registry.has_poi(cell_abs), "has_poi debe retornar false tras unregister.")
	assert_true(registry.get_poi_count() == 1, "Debe quedar 1 POI registrado.")
	
	# Limpieza
	registry.clear_overrides()
	assert_true(registry.get_poi_count() == 0, "clear_overrides debe vaciar el registro.")
	assert_true(not registry.has_poi(target_cell), "target_cell ya no debe existir tras clear_overrides.")

func _test_solar_system_poi_injection() -> void:
	var streamer: CosmosSolarSystemStreamer = CosmosSolarSystemStreamer.new()
	var profile: CosmosCelestialSystemProfile = load("res://scenes/combat/environment/cosmos/resources/data/default_celestial_system.tres") as CosmosCelestialSystemProfile
	assert_true(profile != null, "default_celestial_system.tres debe cargar correctamente.")
	
	streamer.system_profile = profile
	streamer.cell_size = 10000.0
	streamer.pool_size = 4
	
	var registry: CosmicPoiRegistry = CosmicPoiRegistry.new()
	streamer.poi_registry = registry
	
	var poi: CosmicPoiConfig = load("res://scenes/combat/environment/cosmos/resources/data/pois/poi_magnetar_outpost.tres") as CosmicPoiConfig
	assert_true(poi != null, "poi_magnetar_outpost.tres debe cargar correctamente.")
	
	var test_cell: Vector2i = Vector2i(0, 0)
	registry.register_poi(test_cell, poi)
	
	add_child(streamer)
	
	var cam: Camera2D = Camera2D.new()
	cam.position = Vector2.ZERO
	add_child(cam)
	
	var plax: Parallax2D = Parallax2D.new()
	plax.scroll_scale = Vector2(0.2, 0.2)
	add_child(plax)
	
	streamer.camera = cam
	streamer.parallax_layer = plax
	
	streamer._update_streaming_and_orbits(0.0)
	
	var active_sys: Dictionary = streamer.get_active_systems()
	assert_true(active_sys.has(test_cell), "El sistema solar con POI override debe estar activo en la celda (0,0).")
	
	var sys: CosmosSolarSystem2D = active_sys[test_cell] as CosmosSolarSystem2D
	assert_true(sys != null, "La instancia activa de CosmosSolarSystem2D debe ser válida.")
	assert_true(sys.active_archetype == poi.star_archetype, "El arquetipo del sistema debe coincidir con el POI inyectado.")
	assert_true(sys.star_body.body_name == poi.custom_label, "El nombre de la estrella debe ser el custom_label del POI.")
	assert_true(sys.planets.size() == poi.planet_count, "El número de planetas debe ser el planet_count forzado por el POI.")
	
	streamer.queue_free()
	cam.queue_free()
	plax.queue_free()

func _test_cosmos_root_delegation() -> void:
	var scene_res: PackedScene = load("res://scenes/combat/environment/cosmos/scenes/cosmos_root.tscn") as PackedScene
	assert_true(scene_res != null, "cosmos_root.tscn debe cargar limpiamente.")
	
	var root: CosmosRootNode = scene_res.instantiate() as CosmosRootNode
	assert_true(root != null, "cosmos_root debe instanciarse como CosmosRootNode.")
	add_child(root)
	
	assert_true(root.poi_registry != null, "CosmosRootNode debe inicializar poi_registry.")
	assert_true(root.solar_streamer.poi_registry == root.poi_registry, "solar_streamer debe tener el poi_registry sincronizado.")
	assert_true(root.galaxy_streamer.poi_registry == root.poi_registry, "galaxy_streamer debe tener el poi_registry sincronizado.")
	
	var poi: CosmicPoiConfig = CosmicPoiConfig.new()
	poi.custom_label = &"Delegated_POI"
	root.register_poi(Vector2i(5, 5), poi)
	
	assert_true(root.has_poi(Vector2i(5, 5)), "root.has_poi debe retornar true.")
	assert_true(root.get_poi(Vector2i(5, 5)) == poi, "root.get_poi debe retornar la instancia.")
	
	root.clear_poi_overrides()
	assert_true(not root.has_poi(Vector2i(5, 5)), "root.clear_poi_overrides debe vaciar los POIs.")
	
	root.queue_free()

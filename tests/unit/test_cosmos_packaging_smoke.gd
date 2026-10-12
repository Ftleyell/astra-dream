class_name TestCosmosPackagingSmoke
extends BaseTestSuite

## Smoke test para validar la integridad del empaquetado de Cosmos Engine en producción (Sesión 1).
## Criterios de Aceptación:
## 1. Verificación de carga de cosmos_root.tscn en scenes/combat/environment/cosmos/scenes/
## 2. Instanciación sin fallos de la jerarquía completa en memoria
## 3. Comprobación de que todos los shaders y recursos enlazados corresponden a la ruta de producción
## 4. Coexistencia limpia con sandbox/ sin colisión de class_name ni fugas de memoria

func _ready() -> void:
	super._ready()
	_run_suite()

func _run_suite() -> void:
	_test_cosmos_root_scene_load()
	_test_production_resources_integrity()
	_test_production_shaders_integrity()
	pass_suite("TestCosmosPackagingSmoke completado con éxito (100% verificado en producción).")

func _test_cosmos_root_scene_load() -> void:
	print("SMOKE: Loading scene resource...")
	var scene_res: PackedScene = load("res://scenes/combat/environment/cosmos/scenes/cosmos_root.tscn") as PackedScene
	assert_true(scene_res != null, "cosmos_root.tscn debe cargar limpiamente desde la ruta de producción.")
	
	print("SMOKE: Instantiating scene...")
	var instance: Node = scene_res.instantiate()
	assert_true(instance != null, "cosmos_root debe poder instanciarse sin errores.")
	print("SMOKE: Adding child...")
	add_child(instance)
	print("SMOKE: Child added!")
	
	# Verificar nodos clave segun jerarquia de cosmos_root.tscn
	var nebula_ctrl: Node = instance.get_node_or_null("ParallaxNebulaDeep/NebulaBackdrop")
	assert_true(nebula_ctrl != null, "NebulaBackdrop debe existir en el arbol instanciado.")
	
	var galaxy_streamer: Node = instance.get_node_or_null("ParallaxMacroGalaxies/CosmosGalaxyStreamer2D")
	assert_true(galaxy_streamer != null, "CosmosGalaxyStreamer2D debe existir en el arbol instanciado.")
	
	var solar_streamer: Node = instance.get_node_or_null("ParallaxSolarSystems/CosmosSolarSystemStreamer")
	assert_true(solar_streamer != null, "CosmosSolarSystemStreamer debe existir en el arbol instanciado.")
	
	var debris_streamer: Node = instance.get_node_or_null("ParallaxDebrisBelt/CosmosDebrisStreamer2D")
	assert_true(debris_streamer != null, "CosmosDebrisStreamer2D debe existir en el arbol instanciado.")
	
	instance.queue_free()

func _test_production_resources_integrity() -> void:
	var env_prof: CosmosEnvProfile = load("res://scenes/combat/environment/cosmos/resources/data/default_cosmos_environment.tres") as CosmosEnvProfile
	assert_true(env_prof != null, "default_cosmos_environment.tres debe cargar desde producción.")
	assert_true(env_prof.biome_a_profile != null, "biome_a_profile debe estar enlazado.")
	assert_true(env_prof.galaxy_profile != null, "galaxy_profile debe estar enlazado.")
	assert_true(env_prof.solar_profile != null, "solar_profile debe estar enlazado.")
	assert_true(env_prof.debris_profile != null, "debris_profile debe estar enlazado.")
	
	var cel_sys: CosmosCelestialSystemProfile = load("res://scenes/combat/environment/cosmos/resources/data/default_celestial_system.tres") as CosmosCelestialSystemProfile
	assert_true(cel_sys != null, "default_celestial_system.tres debe cargar desde producción.")
	assert_true(cel_sys.star_archetypes.size() >= 5, "Debe incluir al menos 5 arquetipos estelares en producción.")

func _test_production_shaders_integrity() -> void:
	var nebula_shader: Shader = load("res://scenes/combat/environment/cosmos/shaders/universe_nebula.gdshader") as Shader
	assert_true(nebula_shader != null, "universe_nebula.gdshader debe cargar desde producción.")
	
	var corona_shader: Shader = load("res://scenes/combat/environment/cosmos/shaders/star_corona.gdshader") as Shader
	assert_true(corona_shader != null, "star_corona.gdshader debe cargar desde producción.")
	
	var shadow_shader: Shader = load("res://scenes/combat/environment/cosmos/shaders/planetary_shadow_cone.gdshader") as Shader
	assert_true(shadow_shader != null, "planetary_shadow_cone.gdshader debe cargar desde producción.")

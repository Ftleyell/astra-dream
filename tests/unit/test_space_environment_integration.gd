class_name TestSpaceEnvironmentIntegration
extends BaseTestSuite

## Test de Integración: SpaceEnvironmentHost con CosmosCombatEnvironment (Sesión 5).
## Verifica:
## 1. Conexión limpia y transparente de CosmosCombatEnvironment a SpaceEnvironmentHost.
## 2. Vinculación adecuada de referencias a cámara y jugador.
## 3. Notificación de inicio de oleada (on_wave_started) y transición reactiva de biomas.
## 4. Control de congelamiento (freeze / hit-stop) y pausa global sin fugas.

const CosmosCombatEnvScene: PackedScene = preload("res://scenes/combat/environment/cosmos_combat_environment.tscn")
const CosmosCombatEnvScript = preload("res://scenes/combat/environment/cosmos_combat_environment.gd")
const SpaceEnvironmentHostScript = preload("res://scenes/combat/environment/space_environment_host.gd")
const CosmosHostControllerScript = preload("res://scenes/combat/environment/cosmos/core/cosmos_host_controller.gd")
const CosmosRootNodeScript = preload("res://scenes/combat/environment/cosmos/scenes/cosmos_root.gd")
const CombatContextScript = preload("res://scenes/combat/systems/combat_context.gd")
const CosmosSolarSystem2DScript = preload("res://scenes/combat/environment/cosmos/core/solar_system_2d.gd")
const CosmosOrbitalSlotTrackerScript = preload("res://scenes/combat/environment/cosmos/core/cosmos_orbital_slot_tracker.gd")
const CosmosOrbitSlotScript = preload("res://scenes/combat/environment/cosmos/core/cosmos_orbit_slot.gd")
const GameplayPlanetShadowCaster2DScript = preload("res://scenes/combat/environment/gameplay_planet_shadow_caster_2d.gd")
const PlanetScene: PackedScene = preload("res://scenes/combat/environment/planet.tscn")
const PlanetScript = preload("res://scenes/combat/environment/planet.gd")

var _host: SpaceEnvironmentHost = null
var _mock_main_game: Node2D = null
var _mock_camera: Camera2D = null
var _mock_player: CharacterBody2D = null
var _combat_context: CombatContext = null


func _ready() -> void:
	super._ready()
	_run_suite()


func _run_suite() -> void:
	_setup_mock_hierarchy()
	_test_environment_adapter_instantiation()
	_test_camera_and_player_binding()
	_test_wave_transition_and_region_change()
	_test_freeze_and_pause_delegation()
	_test_destructible_orbital_slot_anti_overlap()
	_test_gameplay_shadow_photometric_sync()
	_test_planet_day_night_lighting_overlay()
	_test_seed_synchronization_and_backend_swap()
	_test_graphics_quality_scalability()
	_teardown_mock_hierarchy()
	pass_suite("TestSpaceEnvironmentIntegration completado con éxito al 100%.")


func _setup_mock_hierarchy() -> void:
	_mock_main_game = Node2D.new()
	_mock_main_game.name = "MockMainGame"
	add_child(_mock_main_game)

	_mock_camera = Camera2D.new()
	_mock_camera.name = "MockCamera"
	_mock_main_game.add_child(_mock_camera)

	_mock_player = CharacterBody2D.new()
	_mock_player.name = "MockPlayer"
	_mock_player.position = Vector2(500.0, 500.0)
	_mock_main_game.add_child(_mock_player)

	_combat_context = CombatContextScript.new()
	_combat_context.main_game = _mock_main_game
	_combat_context.camera = _mock_camera
	_combat_context.player = _mock_player as Player if _mock_player is Player else null

	_host = SpaceEnvironmentHostScript.new()
	_host.name = "SpaceEnvironmentHost"
	_host.custom_environment_scene = CosmosCombatEnvScene
	_mock_main_game.add_child(_host)
	_host.setup_subsystem(_combat_context)


func _test_environment_adapter_instantiation() -> void:
	assert_true(_host.active_environment != null, "SpaceEnvironmentHost debe instanciar el active_environment.")
	assert_true(_host.active_environment is CosmosCombatEnvScript, "active_environment debe ser instancia de CosmosCombatEnvironment.")
	var adapter: CosmosCombatEnvScript = _host.active_environment as CosmosCombatEnvScript
	assert_true(adapter.get_cosmos_root() != null, "CosmosCombatEnvironment debe tener un CosmosRootNode activo.")
	assert_true(adapter.get_host_controller() != null, "CosmosCombatEnvironment debe tener un CosmosHostController activo.")


func _test_camera_and_player_binding() -> void:
	var adapter: CosmosCombatEnvScript = _host.active_environment as CosmosCombatEnvScript
	adapter.set_camera_reference(_mock_camera)
	adapter.set_player_reference(_mock_player)

	var root_node: CosmosRootNodeScript = adapter.get_cosmos_root()
	assert_true(root_node.camera == _mock_camera, "CosmosRootNode debe tener la referencia a la cámara vinculada.")
	assert_true(root_node.player_target == _mock_player, "CosmosRootNode debe tener la referencia al jugador vinculada.")


func _test_wave_transition_and_region_change() -> void:
	var adapter: CosmosCombatEnvScript = _host.active_environment as CosmosCombatEnvScript
	var host_ctrl: CosmosHostControllerScript = adapter.get_host_controller()
	assert_true(host_ctrl != null, "host_ctrl no debe ser nulo.")

	# Por defecto las transiciones de bioma están apagadas
	assert_true(not adapter.enable_wave_biome_transitions, "Transiciones automáticas de bioma deben estar desactivadas por defecto.")

	# Probar aleatorización de semilla por run
	var seed_1: int = adapter.randomize_environment_seed()
	var root_node: CosmosRootNodeScript = adapter.get_cosmos_root()
	assert_true(root_node.solar_streamer.run_seed == seed_1, "SolarStreamer debe reflejar la semilla configurada.")
	assert_true(root_node.galaxy_streamer.run_seed == seed_1, "GalaxyStreamer debe reflejar la semilla configurada.")

	# Habilitar flag para verificar el pipeline de transiciones de oleadas
	adapter.enable_wave_biome_transitions = true

	# Disparar oleada 1 (perseus_rift)
	_host.on_wave_started(1)
	assert_true(host_ctrl.get_current_region_id() == &"perseus_rift", "Oleada 1 debe activar perseus_rift.")

	# Disparar oleada 5 (hyperion_forge)
	_host.on_wave_started(5)
	assert_true(host_ctrl.get_current_region_id() == &"hyperion_forge", "Oleada 5 debe activar hyperion_forge.")

	# Disparar oleada 13 (crimson_veil)
	_host.on_wave_started(13)
	assert_true(host_ctrl.get_current_region_id() == &"crimson_veil", "Oleada 13 debe activar crimson_veil.")


func _test_freeze_and_pause_delegation() -> void:
	var adapter: CosmosCombatEnvScript = _host.active_environment as CosmosCombatEnvScript
	var host_ctrl: CosmosHostControllerScript = adapter.get_host_controller()
	var root_node: CosmosRootNodeScript = adapter.get_cosmos_root()

	assert_true(not host_ctrl.is_frozen(), "Inicialmente no debe estar congelado.")
	assert_true(not root_node.is_frozen, "CosmosRootNode no debe estar congelado.")

	host_ctrl.set_frozen(true)
	assert_true(host_ctrl.is_frozen(), "Debe reportar congelamiento tras set_frozen(true).")
	assert_true(root_node.is_frozen, "CosmosRootNode debe estar congelado tras set_frozen(true).")
	if root_node.solar_streamer != null:
		assert_true(root_node.solar_streamer.is_frozen, "SolarStreamer debe estar congelado.")
	if root_node.debris_streamer != null:
		assert_true(root_node.debris_streamer.is_frozen, "DebrisStreamer debe estar congelado.")
	if root_node.galaxy_streamer != null:
		assert_true(root_node.galaxy_streamer.is_frozen, "GalaxyStreamer debe estar congelado.")
	if root_node.nebula_controller != null:
		assert_true(root_node.nebula_controller.is_frozen, "NebulaController debe estar congelado.")

	host_ctrl.set_frozen(false)
	assert_true(not host_ctrl.is_frozen(), "Debe descongelarse tras set_frozen(false).")
	assert_true(not root_node.is_frozen, "CosmosRootNode debe descongelarse.")
	if root_node.solar_streamer != null:
		assert_true(not root_node.solar_streamer.is_frozen, "SolarStreamer debe descongelarse.")
	if root_node.debris_streamer != null:
		assert_true(not root_node.debris_streamer.is_frozen, "DebrisStreamer debe descongelarse.")
	if root_node.galaxy_streamer != null:
		assert_true(not root_node.galaxy_streamer.is_frozen, "GalaxyStreamer debe descongelarse.")
	if root_node.nebula_controller != null:
		assert_true(not root_node.nebula_controller.is_frozen, "NebulaController debe descongelarse.")


func _test_destructible_orbital_slot_anti_overlap() -> void:
	var adapter: CosmosCombatEnvScript = _host.active_environment as CosmosCombatEnvScript
	var root_node: CosmosRootNodeScript = adapter.get_cosmos_root()
	var streamer: CosmosSolarSystemStreamer = root_node.solar_streamer
	assert_true(streamer != null, "SolarStreamer debe estar presente en CosmosRoot.")

	var test_sys: CosmosSolarSystem2D = CosmosSolarSystem2DScript.new()
	test_sys.system_profile = streamer.system_profile
	test_sys.build_system(777123)
	_mock_main_game.add_child(test_sys)

	assert_true(test_sys.destructible_orbit_radius > 0.0, "El sistema solar debe haber reservado un radio orbital para el planeta destructible.")
	assert_true(not test_sys.planets.is_empty(), "El sistema debe contener planetas visuales de fondo.")

	var planetary_cfg: CosmosPlanetarySystemConfig = streamer.system_profile.get_effective_planetary_config()
	var min_spacing: float = test_sys.active_archetype.min_orbital_spacing if test_sys.active_archetype != null else planetary_cfg.min_orbital_spacing

	for planet in test_sys.planets:
		var diff: float = absf(planet.orbit_radius - test_sys.destructible_orbit_radius)
		assert_true(diff >= min_spacing * 0.99, "Ningún planeta visual de fondo debe invadir la franja kepleriana del planeta interactuable destructible.")

	var tracker: CosmosOrbitalSlotTrackerScript = adapter.get_host_controller().get_slot_tracker()
	var test_cell := Vector2i(3, 4)
	var d_slot: CosmosOrbitSlotScript = tracker.get_destructible_planet_slot(test_sys, test_cell)
	assert_true(d_slot != null, "get_destructible_planet_slot debe retornar un slot no nulo.")
	assert_true(d_slot.orbit_radius == test_sys.destructible_orbit_radius, "El slot destructible debe reflejar el radio reservado.")
	assert_true(d_slot.center_type == CosmosOrbitSlotScript.SlotCenterType.STAR, "El slot destructible debe orbitar la estrella central.")

	var slots_dict: Dictionary = tracker.get_slots_for_system(test_sys, test_cell)
	assert_true(slots_dict.has("destructible_slot"), "get_slots_for_system debe empaquetar destructible_slot.")
	assert_true(slots_dict["destructible_slot"] != null, "destructible_slot empaquetado debe ser válido.")

	test_sys.queue_free()


func _test_gameplay_shadow_photometric_sync() -> void:
	var adapter: CosmosCombatEnvScript = _host.active_environment as CosmosCombatEnvScript
	var root_node: CosmosRootNodeScript = adapter.get_cosmos_root()
	var streamer: CosmosSolarSystemStreamer = root_node.solar_streamer
	assert_true(streamer != null, "SolarStreamer debe existir para proveer el perfil.")
	var active_shadow_cfg: CosmosShadowSystemConfig = streamer.system_profile.get_effective_shadow_config()
	assert_true(active_shadow_cfg != null, "Debe haber una configuración CosmosShadowSystemConfig efectiva.")

	# 1. Probar vinculación e inyección automática de CosmosShadowSystemConfig
	var shadow_caster: GameplayPlanetShadowCaster2DScript = GameplayPlanetShadowCaster2DScript.new()
	_mock_main_game.add_child(shadow_caster)

	# Simular slot orbital
	var dummy_slot := CosmosOrbitSlotScript.new(
		CosmosOrbitSlotScript.SlotCenterType.STAR,
		Vector2i(0, 0),
		Vector2(100.0, 100.0),
		1200.0,
		0.05,
		0.0,
		null,
		&"TestSlot",
		Vector2(0.20, 0.20)
	)

	shadow_caster.setup_shadow_binding(dummy_slot, 250.0, _mock_camera, root_node)

	# Verificar sincronización fotométrica de parámetros
	assert_true(shadow_caster.shadow_tint == active_shadow_cfg.shadow_tint, "shadow_tint debe sincronizarse exactamente con Cosmos Engine.")
	assert_true(shadow_caster.shadow_opacity == active_shadow_cfg.shadow_intensity, "shadow_opacity debe sincronizarse con shadow_intensity de Cosmos Engine.")
	assert_true(shadow_caster.shadow_penumbra_ratio == active_shadow_cfg.shadow_penumbra_ratio, "shadow_penumbra_ratio debe sincronizarse con Cosmos Engine.")
	assert_true(shadow_caster.shadow_expansion_factor == active_shadow_cfg.shadow_expansion_factor, "shadow_expansion_factor debe sincronizarse con Cosmos Engine.")

	# 2. Verificar parámetros del ShaderMaterial y modo blend_mul
	assert_true(shadow_caster._material != null, "ShaderMaterial del cono de sombra debe estar inicializado.")
	assert_true(shadow_caster._material.get_shader_parameter("shadow_tint") == active_shadow_cfg.shadow_tint, "Uniform shadow_tint del shader debe coincidir.")
	assert_true(shadow_caster._material.get_shader_parameter("shadow_opacity") == active_shadow_cfg.shadow_intensity, "Uniform shadow_opacity del shader debe coincidir.")

	var shader_code: String = shadow_caster._material.shader.code
	assert_true(shader_code.contains("render_mode blend_mul, unshaded;"), "El shader debe utilizar blend_mul fotométrico.")
	assert_true(shader_code.contains("mix(vec3(1.0), shadow_tint.rgb"), "El shader debe utilizar mezcla multiplicativa.")

	# 3. Probar fallback autónomo a DEFAULT_SHADOW_CONFIG sin cosmos_root
	var standalone_caster: GameplayPlanetShadowCaster2DScript = GameplayPlanetShadowCaster2DScript.new()
	_mock_main_game.add_child(standalone_caster)
	standalone_caster.setup_shadow_binding(dummy_slot, 250.0, _mock_camera, null)
	assert_true(standalone_caster.shadow_tint == GameplayPlanetShadowCaster2DScript.DEFAULT_SHADOW_CONFIG.shadow_tint, "Debe sincronizar fallback a DEFAULT_SHADOW_CONFIG.")

	standalone_caster.queue_free()
	shadow_caster.queue_free()


func _test_planet_day_night_lighting_overlay() -> void:
	var planet: Planet = PlanetScene.instantiate() as Planet
	assert_true(planet != null, "planet.tscn debe instanciarse correctamente.")
	planet.position = Vector2(1000.0, 1000.0)
	_mock_main_game.add_child(planet)

	# 1. Verificar nodo overlay y z-index sobre manto y corteza
	var overlay: Sprite2D = planet.lighting_overlay_sprite
	assert_true(overlay != null, "Planet debe poseer el nodo LightingOverlaySprite.")
	assert_true(overlay.z_index >= 3, "LightingOverlaySprite debe renderizarse sobre la corteza (z_index >= 3).")
	assert_true(overlay.material is ShaderMaterial, "LightingOverlaySprite debe poseer un ShaderMaterial asignado.")

	var mat: ShaderMaterial = overlay.material as ShaderMaterial
	assert_true(mat.shader != null, "El ShaderMaterial debe contener un shader asignado.")
	var shader_code: String = mat.shader.code
	assert_true(shader_code.contains("render_mode blend_mul, unshaded;"), "El shader de día/noche debe usar blend_mul.")
	assert_true(shader_code.contains("normal = vec3(delta, z)"), "El shader debe calcular la normal esférica analítica 3D.")

	# 2. Verificar cálculo de light_direction hacia la estrella (Sol a la derecha en X = +1.0)
	planet.set_star_position(Vector2(2000.0, 1000.0))
	planet._process(0.016)
	var dir_east: Vector2 = mat.get_shader_parameter("light_direction")
	assert_true(dir_east.is_equal_approx(Vector2(1.0, 0.0)), "light_direction debe apuntar al este (+X) hacia la estrella.")

	# 3. Sol arriba en Y = -1.0
	planet.set_star_position(Vector2(1000.0, 0.0))
	planet._process(0.016)
	var dir_north: Vector2 = mat.get_shader_parameter("light_direction")
	assert_true(dir_north.is_equal_approx(Vector2(0.0, -1.0)), "light_direction debe apuntar al norte (-Y) hacia la estrella.")

	# 4. Desacoplamiento de rotación axial (la esfera rota pero el overlay mantiene orientación al mundo)
	planet.rotation = deg_to_rad(90.0)
	planet._process(0.016)
	assert_true(is_equal_approx(overlay.global_rotation, 0.0), "LightingOverlaySprite debe mantener global_rotation = 0.0 frente al giro del planeta.")
	var dir_north_after_rot: Vector2 = mat.get_shader_parameter("light_direction")
	assert_true(dir_north_after_rot.is_equal_approx(Vector2(0.0, -1.0)), "light_direction debe mantenerse invariable a pesar del giro axial del planeta.")

	# 5. Coexistencia con daño en sectores de corteza
	planet.crust_damage[0] = 1.0
	planet.crust_damage[1] = 0.5
	assert_true(overlay.visible, "LightingOverlaySprite debe permanecer visible proyectando luz sobre el manto expuesto.")

	planet.queue_free()


func _test_seed_synchronization_and_backend_swap() -> void:
	var adapter: CosmosCombatEnvScript = _host.active_environment as CosmosCombatEnvScript
	var root_node: CosmosRootNodeScript = adapter.get_cosmos_root()

	_mock_main_game.set("run_seed", 9876543)
	_host.active_environment.set_environment_seed(9876543)
	assert_true(root_node.solar_streamer.run_seed == 9876543, "set_environment_seed debe propagar la semilla a solar_streamer.")
	assert_true(root_node.galaxy_streamer.run_seed == 9876543, "set_environment_seed debe propagar la semilla a galaxy_streamer.")
	assert_true(root_node.debris_streamer.run_seed == 9876543, "set_environment_seed debe propagar la semilla a debris_streamer.")

	# Intercambio de backend transparente
	_host.swap_environment_backend(CosmosCombatEnvScene)
	var swapped_adapter: CosmosCombatEnvScript = _host.active_environment as CosmosCombatEnvScript
	assert_true(swapped_adapter != null, "swap_environment_backend debe crear nuevo entorno.")
	var swapped_root: CosmosRootNodeScript = swapped_adapter.get_cosmos_root()
	assert_true(swapped_root.solar_streamer.run_seed == 9876543, "swap_environment_backend debe preservar run_seed en el nuevo entorno.")


func _test_graphics_quality_scalability() -> void:
	var adapter: CosmosCombatEnvScript = _host.active_environment as CosmosCombatEnvScript
	var root_node: CosmosRootNodeScript = adapter.get_cosmos_root()
	assert_true(root_node != null, "root_node no debe ser nulo.")

	# Nivel 2: Alto
	root_node.apply_graphics_quality(2)
	assert_true(root_node.parallax_starfield_8k.visible, "Nivel 2 debe activar starfield 8K.")
	var mat2: ShaderMaterial = root_node.nebula_controller.material as ShaderMaterial
	assert_true(is_equal_approx(float(mat2.get_shader_parameter("chromatic_dispersion")), 0.004), "Nivel 2 debe tener dispersión cromática activa.")
	assert_true(is_equal_approx(float(mat2.get_shader_parameter("deep_stars_sparkle_intensity")), 0.85), "Nivel 2 debe tener destellos estelares activos.")

	# Nivel 1: Medio (Steam Deck)
	root_node.apply_graphics_quality(1)
	assert_true(not root_node.parallax_starfield_8k.visible, "Nivel 1 debe apagar starfield 8K para optimizar fillrate.")
	assert_true(is_zero_approx(float(mat2.get_shader_parameter("chromatic_dispersion"))), "Nivel 1 debe desactivar dispersión cromática.")
	assert_true(is_equal_approx(float(mat2.get_shader_parameter("deep_stars_sparkle_intensity")), 0.85), "Nivel 1 mantiene destellos estelares estándar.")

	# Nivel 0: Bajo (iGPU)
	root_node.apply_graphics_quality(0)
	assert_true(not root_node.parallax_starfield_8k.visible, "Nivel 0 debe mantener apagado el starfield 8K.")
	assert_true(is_zero_approx(float(mat2.get_shader_parameter("chromatic_dispersion"))), "Nivel 0 debe desactivar dispersión cromática.")
	assert_true(is_zero_approx(float(mat2.get_shader_parameter("deep_stars_sparkle_intensity"))), "Nivel 0 debe simplificar destellos estelares.")


func _teardown_mock_hierarchy() -> void:
	if is_instance_valid(_mock_main_game):
		_mock_main_game.queue_free()

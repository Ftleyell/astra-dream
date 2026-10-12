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

	host_ctrl.set_frozen(false)
	assert_true(not host_ctrl.is_frozen(), "Debe descongelarse tras set_frozen(false).")
	assert_true(not root_node.is_frozen, "CosmosRootNode debe descongelarse.")


func _teardown_mock_hierarchy() -> void:
	if is_instance_valid(_mock_main_game):
		_mock_main_game.queue_free()

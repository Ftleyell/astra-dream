class_name CosmosCombatEnvironment
extends BaseSpaceEnvironment

## CosmosCombatEnvironment.gd
## Adaptador drop-in que implementa BaseSpaceEnvironment para conectar Cosmos Engine
## con SpaceEnvironmentHost y MainGame.
##
## Aloja y coordina:
## - CosmosRootNode: la escena jerárquica multicapa (galaxia, estrellas 8K, soles keplerianos, debris).
## - CosmosHostController: la fachada de control de biomas, hit-stops, pausas e inyección de POIs.

const CosmosRootNodeScript = preload("res://scenes/combat/environment/cosmos/scenes/cosmos_root.gd")
const CosmosHostControllerScript = preload("res://scenes/combat/environment/cosmos/core/cosmos_host_controller.gd")
const CosmosRootScene = preload("res://scenes/combat/environment/cosmos/scenes/cosmos_root.tscn")

@export var cosmos_root: CosmosRootNodeScript = null
@export var host_controller: CosmosHostControllerScript = null

## Mapeo de progresión de biomas cósmicos según rangos de oleadas de combate
const WAVE_BIOME_MAP: Dictionary[int, StringName] = {
	1: &"perseus_rift",     # Oleadas 1-4: azul/cian profundo
	5: &"hyperion_forge",   # Oleadas 5-8: forja naranja/bronce
	9: &"carina_abyss",     # Oleadas 9-12: verde jade / abismo estelar
	13: &"crimson_veil",    # Oleadas 13-16: velo carmesí
	17: &"silica_corona",   # Oleadas 17-20: plasma brillante / solar
	21: &"bootes_void"      # Oleadas 21+: vacío cósmico profundo
}

@export var enable_wave_biome_transitions: bool = false
@export var randomize_seed_on_ready: bool = true

var _camera_ref: Camera2D = null
var _player_ref: CharacterBody2D = null


func _ready() -> void:
	_ensure_components()
	if randomize_seed_on_ready:
		randomize_environment_seed()


## Genera y aplica una nueva semilla procedural para la partida actual
func randomize_environment_seed() -> int:
	var new_seed: int = int(randi()) & 0x7FFFFFFF
	set_environment_seed(new_seed)
	return new_seed


## Aplica una semilla específica a los subsistemas cósmicos
func set_environment_seed(p_seed: int) -> void:
	if cosmos_root != null and is_instance_valid(cosmos_root):
		cosmos_root.set_run_seed(p_seed)


func _ensure_components() -> void:
	if cosmos_root == null:
		cosmos_root = get_node_or_null("CosmosRoot") as CosmosRootNodeScript
		if cosmos_root == null:
			cosmos_root = get_node_or_null("CosmosRootNode") as CosmosRootNodeScript

	if cosmos_root == null and CosmosRootScene != null:
		cosmos_root = CosmosRootScene.instantiate() as CosmosRootNodeScript
		cosmos_root.name = "CosmosRoot"
		add_child(cosmos_root)

	if host_controller == null:
		host_controller = get_node_or_null("CosmosHostController") as CosmosHostControllerScript

	if host_controller == null:
		host_controller = CosmosHostControllerScript.new()
		host_controller.name = "CosmosHostController"
		host_controller.cosmos_root = cosmos_root
		add_child(host_controller)
	elif host_controller.cosmos_root == null:
		host_controller.cosmos_root = cosmos_root

	_rebind_references()


func _rebind_references() -> void:
	if cosmos_root == null:
		return

	if _camera_ref != null and is_instance_valid(_camera_ref):
		cosmos_root.camera = _camera_ref
		if cosmos_root.has_method("_bind_camera_to_streamers"):
			cosmos_root.call("_bind_camera_to_streamers")

	if _player_ref != null and is_instance_valid(_player_ref):
		cosmos_root.player_target = _player_ref
		if cosmos_root.floating_origin_tracker != null:
			cosmos_root.floating_origin_tracker.player_target = _player_ref


func set_camera_reference(p_camera: Camera2D) -> void:
	_camera_ref = p_camera
	if cosmos_root != null and is_instance_valid(cosmos_root):
		cosmos_root.camera = p_camera
		if cosmos_root.has_method("_bind_camera_to_streamers"):
			cosmos_root.call("_bind_camera_to_streamers")


func set_player_reference(p_player: CharacterBody2D) -> void:
	_player_ref = p_player
	if cosmos_root != null and is_instance_valid(cosmos_root):
		cosmos_root.player_target = p_player
		if cosmos_root.floating_origin_tracker != null:
			cosmos_root.floating_origin_tracker.player_target = p_player


func notify_wave_started(wave_idx: int) -> void:
	if enable_wave_biome_transitions:
		_apply_wave_biome_transition(wave_idx)


func _apply_wave_biome_transition(wave_idx: int) -> void:
	if not enable_wave_biome_transitions or host_controller == null or not is_instance_valid(host_controller):
		return

	var target_region: StringName = &""
	var sorted_thresholds: Array = WAVE_BIOME_MAP.keys()
	sorted_thresholds.sort()

	for threshold: int in sorted_thresholds:
		if wave_idx >= threshold:
			target_region = WAVE_BIOME_MAP[threshold]

	if target_region != &"" and target_region != host_controller.get_current_region_id():
		host_controller.change_region(target_region, 3.5)


func get_host_controller() -> CosmosHostControllerScript:
	return host_controller


func get_cosmos_root() -> CosmosRootNodeScript:
	return cosmos_root

class_name SpaceEnvironmentHost
extends CombatSubsystem

## SpaceEnvironmentHost.gd
## Subsistema desacoplado Plug & Play para alojar y orquestar el entorno visual de combate.
## Permite intercambiar de forma transparente la implementación visual de fondo
## (por ejemplo el fondo actual de Parallax vs los shaders procedurales de sandbox)
## sin modificar la escena ni la lógica de MainGame.

const BaseSpaceEnvironmentScript = preload("res://scenes/combat/environment/base_space_environment.gd")

@export var default_environment_scene: PackedScene = preload("res://scenes/combat/environment/space_background.tscn")
@export var custom_environment_scene: PackedScene = null

var active_environment: Node2D = null


func setup_subsystem(p_context: CombatContext) -> void:
	super.setup_subsystem(p_context)
	_ensure_active_environment()
	_bind_environment_references()


func _ensure_active_environment() -> void:
	if is_instance_valid(active_environment):
		return

	if not context or not context.main_game:
		return

	# Buscar si ya existe un nodo de entorno en la escena raíz
	var existing: Node = context.main_game.get_node_or_null("SpaceBackground")
	if existing and existing is Node2D:
		active_environment = existing as Node2D
		return

	# Instanciar el entorno custom si está provisto, o el default
	var scene_to_instantiate: PackedScene = custom_environment_scene if custom_environment_scene else default_environment_scene
	if scene_to_instantiate:
		var env_node: Node2D = scene_to_instantiate.instantiate() as Node2D
		env_node.name = "SpaceBackground"
		context.main_game.add_child(env_node)
		context.main_game.move_child(env_node, 0)
		active_environment = env_node


func _bind_environment_references() -> void:
	if not is_instance_valid(active_environment) or not context:
		return

	if active_environment.has_method("set_camera_reference") and context.camera:
		active_environment.call("set_camera_reference", context.camera)

	if active_environment.has_method("set_player_reference") and context.player:
		active_environment.call("set_player_reference", context.player)


func on_wave_started(wave_idx: int) -> void:
	if is_instance_valid(active_environment) and active_environment.has_method("notify_wave_started"):
		active_environment.call("notify_wave_started", wave_idx)


func swap_environment_backend(new_scene: PackedScene) -> void:
	custom_environment_scene = new_scene
	if is_instance_valid(active_environment):
		active_environment.queue_free()
		active_environment = null
	_ensure_active_environment()
	_bind_environment_references()

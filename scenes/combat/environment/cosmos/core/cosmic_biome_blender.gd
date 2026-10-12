class_name CosmicBiomeBlender
extends RefCounted

## CosmicBiomeBlender.gd
## Controlador desacoplado de mezcla y transición de biomas cósmicos para Cosmos Engine.
## Maneja transiciones suaves mediante interpolación manual o tweens en SceneTree
## para modificar uniforms de nebulosa y paletas sin allocations en tiempo de ejecución.

const CosmosBiomeConfig = preload("res://scenes/combat/environment/cosmos/resources/cosmic_biome_config.gd")
const CosmosNebulaBackdropController = preload("res://scenes/combat/environment/cosmos/core/nebula_backdrop_controller.gd")
const CosmosEnvProfile = preload("res://scenes/combat/environment/cosmos/resources/cosmos_environment_profile.gd")

var nebula_controller: CosmosNebulaBackdropController = null
var environment_profile: CosmosEnvProfile = null

var _current_tween: Tween = null
var _is_transitioning: bool = false
var _target_biome: CosmosBiomeConfig = null
var _blend_progress: float = 0.0

func _init(p_nebula: CosmosNebulaBackdropController = null, p_profile: CosmosEnvProfile = null) -> void:
	nebula_controller = p_nebula
	environment_profile = p_profile

## Inicia una transición fluida hacia el bioma objetivo a lo largo de transition_duration segundos.
## Utiliza un Tween desacoplado del SceneTree (si está disponible a través de target_node).
func blend_to_biome(target_biome: CosmosBiomeConfig, duration: float, owner_node: Node = null) -> void:
	if target_biome == null:
		return

	if duration <= 0.0:
		apply_biome_immediate(target_biome)
		return

	_target_biome = target_biome
	_is_transitioning = true

	# Cancelar tween previo si existía
	if _current_tween != null and _current_tween.is_valid():
		_current_tween.kill()
		_current_tween = null

	# Configurar Bioma B como el destino en el nebula controller
	if nebula_controller != null and is_instance_valid(nebula_controller):
		nebula_controller.set_biome_b(target_biome)
		nebula_controller.set_blend_factor(0.0)

	if owner_node != null and owner_node.is_inside_tree():
		var tree: SceneTree = owner_node.get_tree()
		if tree != null:
			_current_tween = tree.create_tween()
			_current_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			_current_tween.tween_method(_on_tween_step, 0.0, 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			_current_tween.finished.connect(_on_tween_finished)
			return

	# Fallback si no hay SceneTree disponible: aplicar inmediato
	apply_biome_immediate(target_biome)

## Progreso manual de la interpolación (útil para tests headless y entornos sin SceneTree).
func advance_manual_blend(delta_progress: float) -> void:
	if not _is_transitioning or _target_biome == null:
		return
	_blend_progress = clampf(_blend_progress + delta_progress, 0.0, 1.0)
	_on_tween_step(_blend_progress)
	if _blend_progress >= 1.0:
		_on_tween_finished()

## Aplica el bioma de forma inmediata sin transición.
func apply_biome_immediate(target_biome: CosmosBiomeConfig) -> void:
	if target_biome == null:
		return

	if _current_tween != null and _current_tween.is_valid():
		_current_tween.kill()
		_current_tween = null

	_is_transitioning = false
	_blend_progress = 0.0
	_target_biome = null

	if environment_profile != null:
		environment_profile.biome_a_profile = target_biome
		environment_profile.biome_blend_factor = 0.0

	if nebula_controller != null and is_instance_valid(nebula_controller):
		nebula_controller.biome_a = target_biome
		nebula_controller.biome_b = null
		nebula_controller.set_blend_factor(0.0)
		nebula_controller.apply_biome_configurations()

func cancel_transition() -> void:
	if _current_tween != null and _current_tween.is_valid():
		_current_tween.kill()
		_current_tween = null
	_is_transitioning = false
	_blend_progress = 0.0
	_target_biome = null

func is_transitioning() -> bool:
	return _is_transitioning

func get_blend_progress() -> float:
	return _blend_progress

func _on_tween_step(progress: float) -> void:
	_blend_progress = progress
	if nebula_controller != null and is_instance_valid(nebula_controller):
		nebula_controller.set_blend_factor(progress)
	if environment_profile != null:
		environment_profile.biome_blend_factor = progress

func _on_tween_finished() -> void:
	if _target_biome != null:
		var target: CosmosBiomeConfig = _target_biome
		_is_transitioning = false
		_blend_progress = 0.0
		_target_biome = null
		apply_biome_immediate(target)
	else:
		_is_transitioning = false
		_blend_progress = 0.0

class_name CosmosFloatingOriginTracker
extends Node

## Supervisor del sistema de Origen Flotante para grandes escalas astronómicas.
## Detecta cuando el objetivo (player/nave) se aleja más allá de threshold_distance
## respecto al centro global (0, 0), recentrando las entidades del mundo y
## aplicando compensación exacta sobre Parallax2D.scroll_offset para garantizar
## cero tirones (jitter/stutter) visuales.

signal origin_shifted(shift_vector: Vector2)

@export var player_target: Node2D
@export var camera: Camera2D
@export var threshold_distance: float = 10000.0
@export var parallax_layers: Array[Parallax2D] = []

func _physics_process(_delta: float) -> void:
	check_and_shift()

## Evalúa si el objetivo superó el umbral y efectúa el recentrado si corresponde.
func check_and_shift() -> bool:
	if not is_instance_valid(player_target):
		return false
	
	var len_sq: float = player_target.global_position.length_squared()
	var thresh_sq: float = threshold_distance * threshold_distance
	if len_sq >= thresh_sq:
		trigger_shift(player_target.global_position)
		return true
	return false

## Aplica el recentrado vectorial trasladando el objetivo, cámara y capas de paralaje.
func trigger_shift(shift: Vector2) -> void:
	if shift == Vector2.ZERO:
		return

	if is_instance_valid(player_target):
		player_target.global_position -= shift
		if player_target.has_method("on_origin_shifted"):
			player_target.call("on_origin_shifted", shift)

	if is_instance_valid(camera):
		if camera.has_method("on_origin_shifted"):
			camera.call("on_origin_shifted", shift)
		else:
			var is_child: bool = is_instance_valid(player_target) and player_target.is_ancestor_of(camera)
			var is_top_level: bool = (camera as CanvasItem).top_level if camera is CanvasItem else false
			if is_top_level or not is_child:
				camera.global_position -= shift
			if camera.has_method("reset_smoothing"):
				camera.reset_smoothing()


	for layer: Parallax2D in parallax_layers:
		if is_instance_valid(layer):
			layer.scroll_offset -= shift * layer.scroll_scale

	origin_shifted.emit(shift)

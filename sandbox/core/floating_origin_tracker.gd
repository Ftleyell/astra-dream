class_name FloatingOriginTracker
extends RefCounted

## floating_origin_tracker.gd
## Rastreador de coordenadas lógicas en 64 bits con floating origin (rebase).
## Mantiene la posición del mundo desacoplada de la precisión float32 de la GPU/física.

signal rebased(offset: Vector2)

var _origin: Vector2 = Vector2.ZERO
var _actor_position: Vector2 = Vector2.ZERO
var _threshold: float = 8192.0


func _init(rebase_threshold: float = 8192.0) -> void:
	_threshold = maxf(rebase_threshold, 1024.0)


func update_actor_position(local_pos: Vector2) -> bool:
	_actor_position = local_pos
	if _actor_position.length_squared() >= _threshold * _threshold:
		trigger_rebase()
		return true
	return false


func trigger_rebase() -> void:
	var delta_offset: Vector2 = _actor_position
	_origin += delta_offset
	_actor_position = Vector2.ZERO
	rebased.emit(delta_offset)


func get_logical_position() -> Vector2:
	return _origin + _actor_position


func get_origin() -> Vector2:
	return _origin


func get_actor_position() -> Vector2:
	return _actor_position


func get_threshold() -> float:
	return _threshold


func set_threshold(value: float) -> void:
	_threshold = maxf(value, 1024.0)


func reset(new_origin: Vector2 = Vector2.ZERO) -> void:
	_origin = new_origin
	_actor_position = Vector2.ZERO

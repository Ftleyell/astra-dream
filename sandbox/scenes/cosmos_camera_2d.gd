class_name CosmosCamera2D
extends Camera2D

## Cámara con zoom elástico suave por rueda del mouse y seguimiento amortiguado.
## Diseñada específicamente para exploración multi-escala del Cosmos Engine.
## Implementa seguimiento amortiguado relativo con preservación analítica de lag vectorial
## para garantizar cero snapback / saltitos en recentrados de Origen Flotante.

@export var target: Node2D = null
@export var smoothing_enabled: bool = true
@export var smoothing_speed: float = 8.0
@export var max_smoothing_distance: float = 600.0
@export var ignore_camera_rotation: bool = true

@export var min_zoom: float = 0.05
@export var max_zoom: float = 2.5
@export var zoom_speed: float = 10.0
@export var zoom_step: float = 0.15

var _target_zoom: Vector2 = Vector2.ONE
var _world_lag: Vector2 = Vector2.ZERO

func _ready() -> void:
	_target_zoom = zoom
	# Desactivamos el suavizado nativo de Godot que resetea bruscamente el lag en floating origin shifts
	position_smoothing_enabled = false
	ignore_rotation = ignore_camera_rotation
	process_priority = -10

	if target == null:
		var p: Node = get_parent()
		if p is Node2D:
			target = p as Node2D

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_pressed():
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_target_zoom = (_target_zoom * (1.0 + zoom_step)).clamp(Vector2.ONE * min_zoom, Vector2.ONE * max_zoom)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_target_zoom = (_target_zoom * (1.0 - zoom_step)).clamp(Vector2.ONE * min_zoom, Vector2.ONE * max_zoom)

func _process(delta: float) -> void:
	# Teclado alternativo para zoom
	if Input.is_key_pressed(KEY_EQUAL) or Input.is_key_pressed(KEY_PLUS):
		_target_zoom = (_target_zoom * (1.0 + zoom_step * delta * 5.0)).clamp(Vector2.ONE * min_zoom, Vector2.ONE * max_zoom)
	elif Input.is_key_pressed(KEY_MINUS):
		_target_zoom = (_target_zoom * (1.0 - zoom_step * delta * 5.0)).clamp(Vector2.ONE * min_zoom, Vector2.ONE * max_zoom)

	zoom = zoom.lerp(_target_zoom, zoom_speed * delta)
	_update_tracking(delta)

func _update_tracking(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return

	if not smoothing_enabled:
		_world_lag = Vector2.ZERO
		position = Vector2.ZERO
		return

	var target_velocity: Vector2 = Vector2.ZERO
	if target is CharacterBody2D:
		target_velocity = (target as CharacterBody2D).velocity
	elif target.has_method("get_velocity"):
		target_velocity = target.call("get_velocity")

	# Lag objetivo en coordenadas del mundo
	var desired_world_lag: Vector2 = Vector2.ZERO
	if smoothing_speed > 0.001:
		desired_world_lag = -target_velocity / smoothing_speed
		if max_smoothing_distance > 0.0:
			desired_world_lag = desired_world_lag.limit_length(max_smoothing_distance)

	var factor: float = 1.0 - exp(-smoothing_speed * delta)
	_world_lag = _world_lag.lerp(desired_world_lag, factor)

	# Si la cámara es hija del target, convertimos world_lag al espacio local del padre
	var p: Node2D = get_parent() as Node2D
	if p != null and not top_level:
		if p.rotation != 0.0:
			position = _world_lag.rotated(-p.rotation)
		else:
			position = _world_lag
	else:
		global_position = target.global_position + _world_lag

## Responde al recentrado vectorial de Origen Flotante preservando de manera analítica el lag de amortiguación.
func on_origin_shifted(shift: Vector2) -> void:
	# Si la cámara es top_level o no es hija del objetivo, trasladar su posición global
	if top_level or not (is_instance_valid(target) and target.is_ancestor_of(self)):
		global_position -= shift

## Invalida el lag acumulado y centra la cámara inmediatamente en el objetivo.
func snap_to_target() -> void:
	_world_lag = Vector2.ZERO
	position = Vector2.ZERO
	if target != null and is_instance_valid(target) and (top_level or not target.is_ancestor_of(self)):
		global_position = target.global_position




class_name CosmosCamera2D
extends Camera2D

## Cámara con zoom elástico suave por rueda del mouse y seguimiento amortiguado.
## Diseñada específicamente para exploración multi-escala del Cosmos Engine.

@export var min_zoom: float = 0.05
@export var max_zoom: float = 2.5
@export var zoom_speed: float = 10.0
@export var zoom_step: float = 0.15

var _target_zoom: Vector2 = Vector2.ONE

func _ready() -> void:
	_target_zoom = zoom
	position_smoothing_enabled = true
	position_smoothing_speed = 8.0

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

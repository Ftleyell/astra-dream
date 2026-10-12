class_name TestSolarSystemTimeController
extends Node

## Controlador interactivo para test_solar_hierarchy.tscn:
## Permite manipular la velocidad del tiempo cosmológico mediante teclado (1: 1x, 2: 5x, 3: 20x, Espacio: pausa/reanudar).

@export var solar_system: SolarSystem2D
@export var time_scale: float = 1.0

var _is_paused: bool = false
var _elapsed_time: float = 0.0

func _process(delta: float) -> void:
	if Input.is_key_pressed(KEY_1):
		time_scale = 1.0
	elif Input.is_key_pressed(KEY_2):
		time_scale = 5.0
	elif Input.is_key_pressed(KEY_3):
		time_scale = 20.0

	if Input.is_action_just_pressed("ui_accept"):
		_is_paused = not _is_paused

	if not _is_paused:
		_elapsed_time += delta * time_scale

	if solar_system != null:
		solar_system.update_astronomical_state(_elapsed_time)

class_name BaseSpaceEnvironment
extends Node2D

## BaseSpaceEnvironment.gd
## Contrato e interfaz base para los entornos espaciales en combate (SpaceEnvironmentHost).
## Define los métodos requeridos para cualquier implementación de fondo/entorno (Parallax actual,
## shaders de sandbox, generadores cósmicos procedurales).

@export var enable_auto_drift: bool = true
@export var drift_direction: Vector2 = Vector2(-0.894427, -0.447214)
@export var base_drift_speed: float = 16.0


func set_camera_reference(_camera: Camera2D) -> void:
	pass


func set_player_reference(_player: CharacterBody2D) -> void:
	pass


func set_drift_parameters(direction: Vector2, speed: float) -> void:
	drift_direction = direction
	base_drift_speed = speed


func notify_wave_started(_wave_idx: int) -> void:
	pass

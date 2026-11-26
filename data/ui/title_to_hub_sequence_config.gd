class_name TitleToHubSequenceConfig
extends Resource

## Parámetros data-driven para la transición inmersiva Title -> Hub 3D
## sobre una única instancia viva de Cosmos Engine.

@export var title_cosmos_drift_speed: Vector2 = Vector2(38.0, -14.0)
@export var title_camera_offset_px: Vector2 = Vector2(-520.0, -280.0)
@export var title_camera_zoom: float = 0.82
@export var camera_glide_duration_sec: float = 1.10
@export var station_materialize_delay_sec: float = 0.25
@export var station_materialize_duration_sec: float = 1.25
@export var pilot_flyin_delay_sec: float = 0.72
@export var pilot_flyin_duration_sec: float = 0.78
@export var pilot_flyin_start_offset_px: Vector2 = Vector2(0.0, -480.0)

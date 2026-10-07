class_name TitleImpactConfig
extends Resource

## TitleImpactConfig
## Configuración data-driven para la cinemática de impacto y reposo del logotipo.

@export_group("Cinemática de Caída")
@export var drop_duration: float = 0.42
@export var drop_height_offset: float = 380.0
@export var hitstop_duration: float = 0.08
@export var use_engine_time_scale: bool = false
@export var start_scale: Vector2 = Vector2(4.8, 4.8)
@export var target_scale: Vector2 = Vector2(1.0, 1.0)

@export_group("Deformación Mecánica (Squash & Stretch)")
@export var squash_scale: Vector2 = Vector2(1.35, 0.65)
@export var squash_duration: float = 0.06
@export var stretch_scale: Vector2 = Vector2(0.92, 1.08)
@export var stretch_duration: float = 0.12
@export var bounce_duration: float = 0.20

@export_group("Trauma y Sacudida")
@export var trauma_decay: float = 2.0
@export var shake_offset_x: float = 28.0
@export var shake_offset_y: float = 20.0
@export var noise_frequency: float = 0.08

@export_group("Imágenes Residuales (Afterimages)")
@export var afterimage_count: int = 5
@export var afterimage_fade_time: float = 0.22
@export var afterimage_scale_ratio: float = 0.92
@export var afterimage_color: Color = Color(0.2, 0.8, 2.5, 0.65)

@export_group("Efectos de Shader")
@export var flash_duration: float = 0.25
@export var glitch_duration: float = 0.45
@export var flash_color: Color = Color(1.0, 1.0, 1.0, 1.0)

@export_group("Reposo Activo (Idle)")
@export var idle_scale_duration: float = 1.6
@export var idle_scale_a: Vector2 = Vector2(1.025, 0.985)
@export var idle_scale_b: Vector2 = Vector2(0.985, 1.025)
@export var idle_float_duration: float = 2.1
@export var idle_float_offset: float = 5.0

@export_group("Panel Secundario")
@export var panel_reveal_delay: float = 0.15
@export var panel_reveal_duration: float = 0.45

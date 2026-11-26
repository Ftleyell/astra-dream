class_name SingularityTransitionConfig
extends Resource

## Configuración data-driven de la transición cinemática Singularidad
## (Big Crunch -> Punto Blanco Vivo -> Big Bang).

@export_group("Timings")
@export var crunch_duration_sec: float = 0.42
@export var min_singularity_hold_sec: float = 0.35
@export var big_bang_duration_sec: float = 0.62
@export var threaded_load_timeout_sec: float = 4.0

@export_group("Gravitational Collapse & Shockwave")
@export var swirl_strength: float = 2.4
@export var chromatic_aberration: float = 0.036
@export var singularity_core_radius: float = 0.015
@export var anamorphic_flare_intensity: float = 1.35
@export var shockwave_refraction: float = 0.085
@export var particle_density: float = 1.0

@export_group("Palette")
@export var core_tint: Color = Color(0.86, 0.95, 1.0, 1.0)
@export var shockwave_tint: Color = Color(0.32, 0.88, 1.0, 1.0)

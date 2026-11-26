class_name StelaLogoVfxConfig
extends Resource

## Configuración data-driven para el logotipo cel-shaded de Stela Galactica,
## iluminación reactiva al Cosmos Engine, anillos astrolabio y tajo energético.

@export_group("Cel Shading & Normal Map")
@export var normal_strength: float = 0.90
@export var cel_shadow_threshold: float = 0.16
@export var cel_spec_threshold: float = 0.72
@export var cosmos_light_mix: float = 0.68
@export var rim_intensity: float = 0.85
@export var gold_specular_intensity: float = 1.15

@export_group("Anime Shine Sweep")
@export var shine_interval_sec: float = 4.2
@export var shine_duration_sec: float = 0.85

@export_group("Astrolabe Medallion & Rings")
@export var medallion_rotation_speed: float = 0.06
@export var medallion_scale: float = 0.88
@export var astrolabe_outer_speed: float = 0.08
@export var astrolabe_inner_speed: float = -0.15
@export var astrolabe_alpha: float = 0.62
@export var astrolabe_primary_color: Color = Color(0.58, 0.42, 0.98, 1.0)
@export var astrolabe_secondary_color: Color = Color(0.18, 0.90, 1.0, 1.0)

@export_group("Energy Slash")
@export var slash_angle_deg: float = -27.0
@export var slash_flow_speed: float = 1.9
@export var slash_intensity: float = 1.15
@export var slash_core_color: Color = Color(1.0, 0.92, 1.0, 1.0)
@export var slash_mid_color: Color = Color(0.76, 0.22, 1.0, 1.0)
@export var slash_edge_color: Color = Color(0.14, 0.88, 1.0, 1.0)

@export_group("Motion & Transitions")
@export var hover_amplitude_px: float = 6.0
@export var hover_freq_hz: float = 0.42
@export var reveal_duration_sec: float = 0.95
@export var dissolve_duration_sec: float = 0.55

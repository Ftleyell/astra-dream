class_name CosmosStarVisualConfig
extends Resource

## Configuración data-driven para la visualización del sol central, corona y heliosfera.

@export_group("Texturas y Color")
@export var star_name_prefix: String = "SOLARIS"
@export var star_textures: Array[Texture2D] = []
@export var star_color: Color = Color(1.0, 0.88, 0.55, 1.0)
@export var flat_core_color: Color = Color(1.0, 0.85, 0.45, 1.0)
@export_range(0.1, 0.5, 0.01) var flat_core_radius: float = 0.32
@export_range(0.005, 0.1, 0.005) var flat_core_feather: float = 0.035
@export var star_core_radius: float = 420.0

@export_group("Dinámica de Plasma y Rotación")
@export_range(0.001, 0.1, 0.001) var axial_rotation_speed: float = 0.008
@export_range(0.0, 0.15, 0.005) var heat_distortion_strength: float = 0.045
@export_range(0.1, 5.0, 0.1) var pulse_speed: float = 1.4
@export_range(1.0, 2.5, 0.05) var corona_size_multiplier: float = 1.35
@export_range(0.0, 2.5, 0.05) var corona_intensity: float = 1.18
@export_range(0.8, 2.5, 0.05) var core_brightness: float = 1.25

@export_group("Luz Orbital y Heliosfera")
@export_range(1.0, 2.5, 0.05) var light_field_radius_multiplier: float = 1.25
@export_range(0.0, 2.0, 0.02) var light_field_intensity: float = 0.85
@export_range(0.0, 1.0, 0.02) var heliosphere_noise_strength: float = 0.40
@export_range(0.05, 0.5, 0.01) var heliosphere_edge_feather: float = 0.22
@export_range(0.0, 1.0, 0.05) var planet_day_tint_strength: float = 0.60
@export_range(0.0, 1.0, 0.05) var planet_atmo_tint_strength: float = 0.65

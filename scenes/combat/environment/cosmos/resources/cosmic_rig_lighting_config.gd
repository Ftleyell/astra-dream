class_name CosmicRigLightingConfig
extends Resource

## Configuración data-driven para el puente de iluminación Cosmos Engine -> Rig 2.5D y Armas 3D.

@export_group("Dirección y Suavizado")
@export var fallback_light_dir_2d: Vector2 = Vector2(-0.58, -0.81)
@export_range(0.1, 1.5, 0.05) var light_z_3d: float = 0.55
@export_range(0.5, 25.0, 0.5) var dir_smooth_rate: float = 8.0
@export_range(0.5, 20.0, 0.5) var color_smooth_rate: float = 5.0

@export_group("Pesos de Sol y Bioma")
@export_range(0.0, 1.0, 0.02) var max_star_tint_mix: float = 0.52
@export_range(0.0, 1.0, 0.02) var max_rim_tint_mix: float = 0.78
@export_range(0.0, 1.0, 0.02) var max_biome_shadow_mix: float = 0.58
@export_range(0.0, 0.4, 0.02) var star_near_boost: float = 0.12
@export_range(1.0, 3.0, 0.05) var star_influence_radius_multiplier: float = 1.55

@export_group("Eclipses Planetarios y Legibilidad")
@export_range(0.25, 0.95, 0.02) var eclipse_min_visibility_floor: float = 0.58
@export_range(1.0, 2.5, 0.05) var eclipse_emissive_boost: float = 1.38
@export_range(0.0, 1.0, 0.05) var eclipse_rim_attenuation: float = 0.65
@export_range(4.0, 64.0, 1.0) var rig_eclipse_receiver_radius: float = 18.0

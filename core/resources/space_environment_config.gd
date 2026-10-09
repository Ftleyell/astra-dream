class_name SpaceEnvironmentConfig
extends Resource

## space_environment_config.gd
## Recurso exportado data-driven para balance de generación cósmica procedural,
## jerarquía de macro-entidades (planetas vs estaciones), rangos de paralaje continuo Z
## y parámetros visuales de galaxias de fondo.

# 1. Macro-entidades: Planetas vs Estaciones (Jerarquía 3:1)
@export_group("Macro Entities")
@export var planet_spawn_interval: float = 7000.0
@export var planet_min_distance: float = 2000.0
@export var planet_max_active: int = 3
@export var planet_projection_distance: float = 1800.0

@export var station_base_distance: float = 2500.0
@export var station_distance_increment: float = 400.0
@export var station_min_distance_to_planet: float = 2500.0

# 2. Rangos de Paralaje Continuo Z (Rango dinámico acentuado)
@export_group("Parallax Continuous Z")
@export var parallax_layer0_nebula_scroll: Vector2 = Vector2(0.02, 0.02)
@export var parallax_layer0_drift_factor: float = 0.20

@export var parallax_layer1_deep_scroll: Vector2 = Vector2(0.10, 0.10)
@export var parallax_layer1_drift_factor: float = 0.50

@export var parallax_layer2_mid_scroll: Vector2 = Vector2(0.30, 0.30)
@export var parallax_layer2_drift_factor: float = 1.00

@export var parallax_layer3_near_scroll: Vector2 = Vector2(0.55, 0.55)
@export var parallax_layer3_drift_factor: float = 1.60

# 3. Visibilidad y Escalas de Galaxias (Medias y Colosales)
@export_group("Galaxies")
@export var galaxy_scale_min: float = 2.4
@export var galaxy_scale_max: float = 4.2
@export var galaxy_overall_brightness: float = 0.92
@export var galaxy_radial_fade_start: float = 0.38
@export var galaxy_radial_fade_end: float = 0.50
@export var galaxy_spawn_interval: float = 4800.0
@export var galaxy_macro_chance: float = 0.85
@export var galaxy_scroll_scale: float = 0.02

# 4. Cinemática de Cámara y Deriva Cósmica
@export_group("Camera and Drift")
@export var base_drift_speed: float = 16.0
@export var drift_direction: Vector2 = Vector2(-0.894427, -0.447214)

# 5. Zócalos Solares y Cinemática Orbital
@export_group("Solar Sockets and Orbits")
@export var solar_socket_spacing: float = 12000.0
@export var binary_system_chance: float = 0.20
@export var planets_per_sun_min: int = 1
@export var planets_per_sun_max: int = 3
@export var planet_orbit_min_radius: float = 1800.0
@export var planet_orbit_max_radius: float = 4200.0
@export var planet_min_angular_separation_deg: float = 60.0
@export var stations_per_socket_min: int = 1
@export var stations_per_socket_max: int = 2
@export var station_orbit_min_radius: float = 800.0
@export var station_orbit_max_radius: float = 1600.0
@export var orbit_period_min_sec: float = 180.0
@export var orbit_period_max_sec: float = 480.0

# 6. Jerarquía Visual y Profundidad Z Calibrada
@export_group("Visual Hierarchy and Z Scales")
@export var sun_scale_min: float = 2.0
@export var sun_scale_max: float = 3.0
@export var sun_z_depth: float = 0.15

@export var planet_scale_min: float = 1.6
@export var planet_scale_max: float = 2.6
@export var planet_z_depth_min: float = 0.20
@export var planet_z_depth_max: float = 0.35

@export var station_scale_min: float = 0.45
@export var station_scale_max: float = 0.65
@export var station_z_depth_min: float = 0.45
@export var station_z_depth_max: float = 0.65

@export var singularity_scale_min: float = 0.30
@export var singularity_scale_max: float = 0.48
@export var singularity_z_depth_min: float = 0.03
@export var singularity_z_depth_max: float = 0.05

@export var galaxy_z_depth: float = 0.02

# 7. Dispersión Rayleigh y Árbitro de Viewport
@export_group("Atmospheric Scattering and Viewport Arbiter")
@export var rayleigh_deep_absorption: float = 0.55
@export var rayleigh_foreground_contrast: float = 1.2
@export var viewport_margin_factor: float = 1.20
@export var max_visible_galaxies: int = 1
@export var max_visible_singularities: int = 1
@export var max_visible_same_variant_planets: int = 1


class_name CosmosPlanetarySystemConfig
extends Resource

## Configuración data-driven para espaciado, escalas y dispersión de planetas.

@export_group("Conteo Planetario")
@export_range(1, 8, 1) var min_planets: int = 3
@export_range(1, 8, 1) var max_planets: int = 6

@export_group("Límites y Espaciado Orbital")
@export var orbit_radius_min: float = 980.0
@export var orbit_radius_max: float = 2760.0
@export var min_orbital_spacing: float = 440.0
@export_range(0.0, 45.0, 1.0) var planet_theta_jitter_degrees: float = 25.0

@export_group("Escalas y Tamaños")
@export_range(0.5, 3.0, 0.05) var planet_size_multiplier: float = 1.15
@export_range(0.0, 0.5, 0.01) var planet_night_ambient: float = 0.22
@export_range(0.8, 2.5, 0.05) var planet_day_exposure: float = 1.30

@export_group("Texturas Planetarias por Zona")
@export var planet_textures: Array[Texture2D] = []
@export var interior_planet_textures: Array[Texture2D] = []
@export var habitable_planet_textures: Array[Texture2D] = []
@export var exterior_planet_textures: Array[Texture2D] = []

@export_group("Arquetipos v2 (Esfera 3D + Máscaras + Anillos)")
@export var planet_archetypes: Array[CosmosPlanetArchetype] = []
@export var moon_archetypes: Array[CosmosPlanetArchetype] = []

@export_group("Estructuras Secundarias (Lunas y Estaciones)")
@export_range(0.0, 1.0, 0.05) var moon_spawn_probability: float = 0.65
@export var moon_orbit_radius_range: Vector2 = Vector2(120.0, 200.0)
@export_range(0.05, 0.5, 0.01) var moon_size_ratio: float = 0.20
@export var moon_textures: Array[Texture2D] = []
@export var normal_moon_texture: Texture2D
@export var magma_moon_texture: Texture2D

@export_range(0.0, 1.0, 0.05) var station_spawn_probability: float = 1.0
@export var station_orbit_radius_range: Vector2 = Vector2(130.0, 220.0)
@export_range(0.05, 0.5, 0.01) var station_size_ratio: float = 0.15
@export var space_station_textures: Array[Texture2D] = []

@export_group("Cinemática 3D Eclíptica y Excentricidad")
@export var system_ecliptic_squash_range: Vector2 = Vector2(0.80, 0.93)
@export_range(0.0, 0.4, 0.01) var planet_tilt_scatter_rad: float = 0.16
@export var planet_eccentricity_range: Vector2 = Vector2(0.03, 0.09)
@export var eccentric_archetype_ecc_range: Vector2 = Vector2(0.06, 0.14)
@export_range(0.0, 0.25, 0.01) var planet_depth_scale_amp: float = 0.07
@export_range(0.0, 0.5, 0.05) var retrograde_outer_planet_chance: float = 0.25

@export_group("Órbitas 3D de Satélites (Lunas y Estaciones)")
@export var moon_squash_range: Vector2 = Vector2(0.26, 0.56)
@export var moon_eccentricity_range: Vector2 = Vector2(0.04, 0.18)
@export_range(0.0, 0.35, 0.01) var moon_depth_scale_amp: float = 0.18
@export_range(0.0, 0.5, 0.05) var moon_retrograde_chance: float = 0.22
@export var station_squash_range: Vector2 = Vector2(0.24, 0.54)
@export var station_eccentricity_range: Vector2 = Vector2(0.02, 0.10)
@export_range(0.0, 0.35, 0.01) var station_depth_scale_amp: float = 0.17

@export_group("Estelas Cinéticas 3D")
@export var enable_orbital_trails: bool = true
@export_range(0.2, 3.0, 0.05) var moon_trail_arc_radians: float = 1.25
@export_range(0.2, 3.0, 0.05) var station_trail_arc_radians: float = 1.05
@export_range(0.0, 1.0, 0.02) var trail_base_opacity: float = 0.30

@export_group("Variedad Orgánica (Cometas, Troyanos y Pastoras)")
@export_range(0.0, 1.0, 0.05) var comet_spawn_probability: float = 0.80
@export_range(0, 4, 1) var max_comets_per_system: int = 2
@export var comet_eccentricity_range: Vector2 = Vector2(0.44, 0.64)
@export var comet_squash_range: Vector2 = Vector2(0.48, 0.84)
@export_range(0.0, 0.35, 0.01) var comet_depth_scale_amp: float = 0.15
@export_range(0.0, 1.0, 0.05) var trojan_cluster_probability: float = 0.55
@export var trojan_bodies_per_pocket: Vector2i = Vector2i(2, 4)
@export_range(0.0, 1.0, 0.05) var shepherd_moonlet_probability: float = 0.80

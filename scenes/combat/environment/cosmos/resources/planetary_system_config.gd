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

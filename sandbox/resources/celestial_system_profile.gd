class_name CelestialSystemProfile
extends Resource

## Perfil data-driven para sistemas celestes (estrellas, planetas y lunas) en Cosmos Engine.

@export_group("Estrella Central")
@export var star_name_prefix: String = "SOLARIS"
@export var star_texture: Texture2D
@export var star_textures: Array[Texture2D] = []
@export var star_base_radius: float = 400.0
@export var star_emission_color: Color = Color(1.0, 0.78, 0.35, 1.0)
@export_range(0.001, 0.1, 0.001) var star_axial_rotation_speed: float = 0.012

@export_group("Planetas Primarios")
@export_range(3, 6, 1) var min_planets: int = 3
@export_range(3, 6, 1) var max_planets: int = 6
@export var orbit_radius_min: float = 1000.0
@export var orbit_radius_max: float = 6000.0
@export var planet_textures: Array[Texture2D] = []

@export_group("Cinemática Orbital")
@export_range(0.005, 0.1, 0.001) var base_angular_velocity: float = 0.025
@export_range(0.0, 0.3, 0.01) var max_orbital_eccentricity: float = 0.04

@export_group("Estructuras Secundarias (Lunas y Estaciones)")
@export_range(0.0, 1.0, 0.05) var moon_spawn_probability: float = 0.70
@export var moon_orbit_radius_range: Vector2 = Vector2(160.0, 300.0)
@export var moon_textures: Array[Texture2D] = []
@export_range(0.0, 1.0, 0.05) var station_spawn_probability: float = 0.50
@export var station_orbit_radius_range: Vector2 = Vector2(180.0, 320.0)
@export var space_station_textures: Array[Texture2D] = []

@export_group("Visualización y Guías Orbitales")
@export var show_orbit_lines: bool = true
@export var orbit_line_color: Color = Color(1.0, 1.0, 1.0, 0.12)
@export var orbit_line_width: float = 1.5


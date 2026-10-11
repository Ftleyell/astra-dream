class_name CelestialSystemProfile
extends Resource

## Perfil data-driven para sistemas celestes (estrellas, planetas y lunas) en Cosmos Engine.

@export_group("Arquetipos Estelares")
@export var star_archetypes: Array[StarArchetype] = []

@export_group("Estrella Central (Fallback)")
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
@export var min_orbital_spacing: float = 650.0
@export_range(0.0, 45.0, 1.0) var planet_theta_jitter_degrees: float = 25.0
@export_range(0.5, 3.0, 0.05) var planet_size_multiplier: float = 1.0
@export var planet_textures: Array[Texture2D] = []
@export var interior_planet_textures: Array[Texture2D] = []
@export var habitable_planet_textures: Array[Texture2D] = []
@export var exterior_planet_textures: Array[Texture2D] = []

@export_group("Generación y Cuadrícula Espacial")
@export var cell_size: float = 16000.0
@export var cell_boundary_padding: float = 250.0
@export_range(0.0, 1.0, 0.05) var spawn_chance: float = 0.75

@export_group("Cinemática Orbital")
@export_range(0.005, 0.1, 0.001) var base_angular_velocity: float = 0.025
@export_range(0.0, 0.3, 0.01) var max_orbital_eccentricity: float = 0.04

@export_group("Estructuras Secundarias (Lunas y Estaciones)")
@export_range(0.0, 1.0, 0.05) var moon_spawn_probability: float = 0.70
@export var moon_orbit_radius_range: Vector2 = Vector2(160.0, 300.0)
@export_range(0.05, 0.5, 0.01) var moon_size_ratio: float = 0.20
@export var moon_textures: Array[Texture2D] = []
@export var normal_moon_texture: Texture2D
@export var magma_moon_texture: Texture2D
@export_range(0.0, 1.0, 0.05) var station_spawn_probability: float = 0.50
@export var station_orbit_radius_range: Vector2 = Vector2(180.0, 320.0)
@export_range(0.05, 0.5, 0.01) var station_size_ratio: float = 0.15
@export var space_station_textures: Array[Texture2D] = []

@export_group("Visualización y Guías Orbitales")
@export var show_orbit_lines: bool = true
@export var orbit_line_color: Color = Color(1.0, 1.0, 1.0, 0.12)
@export var orbit_line_width: float = 1.5

## Obtiene el arquetipo estelar determinista correspondiente para una semilla dada.
## Si la lista está vacía o ningún arquetipo es válido, devuelve null (preservando retrocompatibilidad).
func get_archetype_for_seed(p_seed: int) -> StarArchetype:
	if star_archetypes.is_empty():
		return null
	var total_weight: float = 0.0
	for arch: StarArchetype in star_archetypes:
		if arch != null:
			total_weight += maxf(arch.spawn_weight, 0.001)
	if total_weight <= 0.0:
		return star_archetypes[0]
	
	var rnd: float = CosmicHasher.hash_2d_float(p_seed, 77, 7) * total_weight
	var acc: float = 0.0
	for arch: StarArchetype in star_archetypes:
		if arch == null:
			continue
		acc += maxf(arch.spawn_weight, 0.001)
		if rnd <= acc:
			return arch
	return star_archetypes[0]

## Calcula el alcance orbital máximo contemplando todos los arquetipos estelares configurados.
func get_maximum_orbital_bound() -> float:
	var max_r: float = orbit_radius_max
	for arch: StarArchetype in star_archetypes:
		if arch != null and arch.orbit_radius_max > max_r:
			max_r = arch.orbit_radius_max
	return max_r


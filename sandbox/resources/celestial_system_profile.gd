class_name CelestialSystemProfile
extends Resource

## Perfil data-driven para sistemas celestes (estrellas, planetas y lunas) en Cosmos Engine.

@export_group("Configuraciones Modulares Data-Driven")
@export var star_visual_config: StarVisualConfig
@export var planetary_config: PlanetarySystemConfig
@export var shadow_config: ShadowSystemConfig

@export_group("Arquetipos Estelares")
@export var star_archetypes: Array[StarArchetype] = []

@export_group("Estrella Central (Fallback)")
@export var star_name_prefix: String = "SOLARIS"
@export var star_texture: Texture2D
@export var star_textures: Array[Texture2D] = []
@export var star_base_radius: float = 400.0
@export var star_emission_color: Color = Color(1.0, 0.78, 0.35, 1.0)
@export var star_flat_core_color: Color = Color(0.0, 0.0, 0.0, 0.0)
@export_range(0.1, 0.5, 0.01) var star_flat_core_radius: float = 0.32
@export_range(0.005, 0.1, 0.005) var star_flat_core_feather: float = 0.035
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

@export_group("Sombras Planetarias y Fotometría")
@export var enable_planetary_shadows: bool = true
@export_range(0.0, 1.0, 0.05) var shadow_intensity: float = 0.75
@export_range(0.05, 0.90, 0.05) var shadow_penumbra_ratio: float = 0.45
@export_range(1.0, 3.5, 0.05) var shadow_expansion_factor: float = 1.85
@export_range(0.02, 0.50, 0.01) var shadow_heliopause_fade: float = 0.22
@export var shadow_tint: Color = Color(0.18, 0.18, 0.24, 1.0)
@export_range(0.0, 0.5, 0.01) var planet_night_ambient: float = 0.22
@export_range(0.8, 2.5, 0.05) var planet_day_exposure: float = 1.30

# Campos de compatibilidad de recursos previamente serializados
@export_range(0.05, 0.5, 0.01) var shadow_penumbra_feather: float = 0.18
@export_range(0.01, 0.8, 0.01) var shadow_longitudinal_fade: float = 0.20
@export_range(0.05, 3.0, 0.05) var shadow_length_multiplier: float = 0.60
@export_range(0.4, 2.5, 0.05) var shadow_base_width_scale: float = 1.0
@export_range(0.0, 3.0, 0.05) var shadow_tip_curvature: float = 0.40

@export_group("Visualización y Guías Orbitales")
@export var show_orbit_lines: bool = true
@export var orbit_line_color: Color = Color(1.0, 1.0, 1.0, 0.12)
@export var orbit_line_width: float = 1.5

## Devuelve la configuración efectiva de sombras
func get_effective_shadow_config() -> ShadowSystemConfig:
	if shadow_config != null:
		return shadow_config
	var cfg: ShadowSystemConfig = ShadowSystemConfig.new()
	cfg.enable_planetary_shadows = enable_planetary_shadows
	cfg.shadow_intensity = shadow_intensity
	cfg.shadow_penumbra_ratio = shadow_penumbra_ratio
	cfg.shadow_expansion_factor = shadow_expansion_factor
	cfg.shadow_heliopause_fade = shadow_heliopause_fade
	cfg.shadow_tint = shadow_tint
	cfg.shadow_base_width_scale = shadow_base_width_scale
	cfg.shadow_tip_curvature = shadow_tip_curvature
	return cfg

## Devuelve la configuración efectiva de planetas
func get_effective_planetary_config() -> PlanetarySystemConfig:
	if planetary_config != null:
		return planetary_config
	var cfg: PlanetarySystemConfig = PlanetarySystemConfig.new()
	cfg.min_planets = min_planets
	cfg.max_planets = max_planets
	cfg.orbit_radius_min = orbit_radius_min
	cfg.orbit_radius_max = orbit_radius_max
	cfg.min_orbital_spacing = min_orbital_spacing
	cfg.planet_theta_jitter_degrees = planet_theta_jitter_degrees
	cfg.planet_size_multiplier = planet_size_multiplier
	cfg.planet_night_ambient = planet_night_ambient
	cfg.planet_day_exposure = planet_day_exposure
	cfg.planet_textures = planet_textures
	cfg.interior_planet_textures = interior_planet_textures
	cfg.habitable_planet_textures = habitable_planet_textures
	cfg.exterior_planet_textures = exterior_planet_textures
	cfg.moon_spawn_probability = moon_spawn_probability
	cfg.moon_orbit_radius_range = moon_orbit_radius_range
	cfg.moon_size_ratio = moon_size_ratio
	cfg.moon_textures = moon_textures
	cfg.normal_moon_texture = normal_moon_texture
	cfg.magma_moon_texture = magma_moon_texture
	cfg.station_spawn_probability = station_spawn_probability
	cfg.station_orbit_radius_range = station_orbit_radius_range
	cfg.station_size_ratio = station_size_ratio
	cfg.space_station_textures = space_station_textures
	return cfg

## Devuelve la configuración efectiva visual estelar (fallback)
func get_effective_star_visual_config() -> StarVisualConfig:
	if star_visual_config != null:
		return star_visual_config
	var cfg: StarVisualConfig = StarVisualConfig.new()
	cfg.star_name_prefix = star_name_prefix
	cfg.star_textures = star_textures
	cfg.star_color = star_emission_color
	cfg.flat_core_color = star_flat_core_color
	cfg.flat_core_radius = star_flat_core_radius
	cfg.flat_core_feather = star_flat_core_feather
	cfg.star_core_radius = star_base_radius
	cfg.axial_rotation_speed = star_axial_rotation_speed
	return cfg


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
	var max_r: float = planetary_config.orbit_radius_max if planetary_config != null else orbit_radius_max
	for arch: StarArchetype in star_archetypes:
		if arch != null and arch.orbit_radius_max > max_r:
			max_r = arch.orbit_radius_max
	return max_r


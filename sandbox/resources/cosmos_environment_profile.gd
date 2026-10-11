class_name CosmosEnvironmentProfile
extends Resource

## Perfil maestro data-driven unificado para Cosmos Engine.
## Centraliza factores de paralaje, sub-perfiles celestes y parámetros de shaders
## para permitir ajuste en caliente reactivo con propagación automática.

@export_group("Escalas de Paralaje")
@export var nebula_parallax_factor: float = 0.01:
	set(v):
		nebula_parallax_factor = v
		emit_changed()

@export var galaxy_scroll_scale: Vector2 = Vector2(0.08, 0.08):
	set(v):
		galaxy_scroll_scale = v
		emit_changed()

@export var starfield_scroll_scale: Vector2 = Vector2(0.003, 0.003):
	set(v):
		starfield_scroll_scale = v
		emit_changed()

@export var solar_scroll_scale: Vector2 = Vector2(0.2, 0.2):
	set(v):
		solar_scroll_scale = v
		emit_changed()

@export var debris_scroll_scale: Vector2 = Vector2(0.5, 0.5):
	set(v):
		debris_scroll_scale = v
		emit_changed()

@export_range(0.0, 3.0, 0.05) var parallax_multiplier: float = 1.0:
	set(v):
		parallax_multiplier = v
		emit_changed()

@export_group("Sub-perfiles Cósmicos")
@export var biome_a_profile: CosmicBiomeConfig:
	set(v):
		biome_a_profile = v
		emit_changed()

@export var biome_b_profile: CosmicBiomeConfig:
	set(v):
		biome_b_profile = v
		emit_changed()

@export_range(0.0, 1.0, 0.01) var biome_blend_factor: float = 0.2:
	set(v):
		biome_blend_factor = v
		emit_changed()

@export var galaxy_profile: GalaxyLandmarkProfile:
	set(v):
		galaxy_profile = v
		emit_changed()

@export var solar_profile: CelestialSystemProfile:
	set(v):
		solar_profile = v
		emit_changed()

@export var debris_profile: DebrisLayerProfile:
	set(v):
		debris_profile = v
		emit_changed()

@export_group("Parámetros de Shader: Nebulosa")
@export_range(0.0, 3.0, 0.05) var nebula_deep_stars_intensity: float = 0.55:
	set(v):
		nebula_deep_stars_intensity = v
		emit_changed()

@export_range(0.5, 10.0, 0.1) var nebula_deep_stars_scale: float = 3.0:
	set(v):
		nebula_deep_stars_scale = v
		emit_changed()

@export_range(0.0, 0.05, 0.001) var nebula_deep_stars_parallax: float = 0.005:
	set(v):
		nebula_deep_stars_parallax = v
		emit_changed()

@export_range(0.1, 10.0, 0.1) var nebula_deep_stars_twinkle_speed: float = 2.2:
	set(v):
		nebula_deep_stars_twinkle_speed = v
		emit_changed()

@export_range(0.0, 2.0, 0.05) var nebula_deep_stars_sparkle_intensity: float = 0.85:
	set(v):
		nebula_deep_stars_sparkle_intensity = v
		emit_changed()

@export_range(0.1, 3.0, 0.05) var nebula_deep_stars_halo_radius: float = 1.35:
	set(v):
		nebula_deep_stars_halo_radius = v
		emit_changed()

@export_range(0.0, 2.0, 0.05) var nebula_deep_stars_gas_interaction: float = 0.75:
	set(v):
		nebula_deep_stars_gas_interaction = v
		emit_changed()

@export_group("Segundo Estrato Estelar en Nebulosa (Mid-Stars)")
@export_range(0.0, 5.0, 0.05) var nebula_mid_stars_intensity: float = 1.6:
	set(v):
		nebula_mid_stars_intensity = v
		emit_changed()

@export_range(0.0, 0.05, 0.0005) var nebula_mid_stars_parallax: float = 0.0065:
	set(v):
		nebula_mid_stars_parallax = v
		emit_changed()

@export_range(0.1, 10.0, 0.05) var nebula_mid_stars_scale: float = 1.35:
	set(v):
		nebula_mid_stars_scale = v
		emit_changed()

@export_range(0.1, 10.0, 0.1) var nebula_mid_stars_twinkle_speed: float = 2.4:
	set(v):
		nebula_mid_stars_twinkle_speed = v
		emit_changed()

@export_range(0.0, 3.0, 0.05) var nebula_mid_stars_sparkle_intensity: float = 1.4:
	set(v):
		nebula_mid_stars_sparkle_intensity = v
		emit_changed()

@export_range(0.1, 4.0, 0.05) var nebula_mid_stars_halo_radius: float = 1.8:
	set(v):
		nebula_mid_stars_halo_radius = v
		emit_changed()

@export_range(0.0, 2.0, 0.05) var nebula_mid_stars_gas_interaction: float = 0.85:
	set(v):
		nebula_mid_stars_gas_interaction = v
		emit_changed()

@export_range(0.0, 1.0, 0.05) var nebula_tile_mix: float = 0.45:
	set(v):
		nebula_tile_mix = v
		emit_changed()

@export_range(0.00005, 0.002, 0.00005) var nebula_tile_scale: float = 0.00035:
	set(v):
		nebula_tile_scale = v
		emit_changed()

@export_range(0.1, 2.0, 0.05) var nebula_density_multiplier: float = 1.0:
	set(v):
		nebula_density_multiplier = v
		emit_changed()

@export_group("Parámetros de Shader: Buffer Estelar 8K")
@export_range(0.1, 5.0, 0.1) var star_intensity: float = 2.4:
	set(v):
		star_intensity = v
		emit_changed()

@export_range(0.005, 0.20, 0.005) var star_threshold_cutoff: float = 0.02:
	set(v):
		star_threshold_cutoff = v
		emit_changed()

@export_range(0.5, 10.0, 0.1) var star_window_scale: float = 2.8:
	set(v):
		star_window_scale = v
		emit_changed()

@export_range(0.0, 1.0, 0.05) var star_twinkle_amount: float = 0.20:
	set(v):
		star_twinkle_amount = v
		emit_changed()

@export_range(0.1, 10.0, 0.1) var star_twinkle_speed: float = 2.0:
	set(v):
		star_twinkle_speed = v
		emit_changed()

@export_range(0.0, 5.0, 0.1) var star_lens_flare_intensity: float = 2.5:
	set(v):
		star_lens_flare_intensity = v
		emit_changed()

@export_range(0.1, 5.0, 0.1) var star_lens_flare_length: float = 2.0:
	set(v):
		star_lens_flare_length = v
		emit_changed()

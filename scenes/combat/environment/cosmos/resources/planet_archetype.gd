class_name CosmosPlanetArchetype
extends Resource

## Arquetipo visual data-driven para planetas y lunas v2 del Cosmos Engine.
## Trabaja junto con celestial_body.gdshader (proyección esférica 3D real 2:1)
## y planetary_ring.gdshader (anillos 2.5D con sombra real proyectada).

enum ZoneType {
	INTERIOR = 0,
	HABITABLE = 1,
	EXTERIOR = 2,
	MOON = 3,
}

@export_group("Identificación y Zona")
@export var archetype_id: StringName = &"planet_generic"
@export var display_name: String = "Planeta Genérico"
@export_enum("Interior:0", "Habitable:1", "Exterior:2", "Luna:3") var zone: int = ZoneType.HABITABLE
@export_range(0.05, 10.0, 0.05) var spawn_weight: float = 1.0
@export var is_magma_moon: bool = false
@export var is_cryo_moon: bool = false

@export_group("Texturas y Mapas Compilados (2:1 / Polar)")
@export var albedo_texture: Texture2D
@export var surface_maps_texture: Texture2D
@export var normal_ao_texture: Texture2D
@export var ring_texture: Texture2D

@export_group("Geometría, Inclinación y Nubes 3D")
@export var diameter_range: Vector2 = Vector2(200.0, 260.0)
@export_range(-65.0, 65.0, 1.0) var axial_tilt_deg: float = 14.0
@export var spin_speed_range: Vector2 = Vector2(0.005, 0.014)
@export_range(-0.08, 0.08, 0.001) var cloud_spin_speed_offset: float = 0.007
@export_range(0.0, 1.5, 0.02) var cloud_coverage: float = 0.0
@export var cloud_tint: Color = Color(0.96, 0.98, 1.0, 1.0)
@export_range(0.0, 0.04, 0.002) var cloud_shadow_offset: float = 0.011
@export_range(0.0, 0.04, 0.002) var cloud_height_parallax: float = 0.016
@export_range(0.0, 0.12, 0.002) var gas_band_shear: float = 0.0

@export_group("Atmósfera Anime Space-Opera")
@export var atmosphere_color: Color = Color(0.35, 0.78, 1.0, 1.0)
@export_range(0.0, 4.0, 0.05) var atmosphere_intensity: float = 1.45
@export_range(0.0, 0.08, 0.002) var outer_atmosphere_thickness: float = 0.028
@export var twilight_scatter_color: Color = Color(1.0, 0.42, 0.56, 1.0)
@export_range(0.0, 1.5, 0.05) var twilight_scatter_strength: float = 0.58

@export_group("Superficie, Emisivos Nocturnos, Especular y Auroras")
@export var night_emissive_color: Color = Color(1.0, 0.72, 0.32, 1.0)
@export_range(0.0, 3.0, 0.05) var night_emissive_strength: float = 0.0
@export_range(0.0, 1.0, 0.05) var night_emissive_day_keep: float = 0.0
@export_range(0.0, 1.0, 0.05) var night_emissive_albedo_mix: float = 0.0
@export_range(0.0, 2.0, 0.05) var specular_strength: float = 0.0
@export_range(4.0, 96.0, 1.0) var specular_shininess: float = 28.0
@export_range(0.0, 1.5, 0.02) var bump_strength: float = 0.25
@export_range(0.0, 1.0, 0.02) var ao_strength: float = 0.48
@export var aurora_color: Color = Color(0.25, 1.0, 0.78, 1.0)
@export_range(0.0, 2.0, 0.05) var aurora_strength: float = 0.0

@export_group("Anillos Planetarios 2.5D")
@export_range(0.0, 1.0, 0.05) var ring_probability: float = 0.0
@export_range(1.05, 2.2, 0.02) var ring_inner_radius: float = 1.28
@export_range(1.4, 3.5, 0.05) var ring_outer_radius: float = 2.28
@export_range(35.0, 82.0, 1.0) var ring_tilt_x_deg: float = 68.0
@export var ring_roll_deg_range: Vector2 = Vector2(-28.0, 28.0)
@export var ring_tint: Color = Color(1.0, 1.0, 1.0, 1.0)
@export_range(-0.08, 0.08, 0.002) var ring_spin_speed: float = 0.012
@export_range(0.0, 1.5, 0.05) var ring_opacity: float = 0.90

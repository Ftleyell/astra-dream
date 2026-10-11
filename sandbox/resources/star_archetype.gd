class_name StarArchetype
extends Resource

## Define la taxonomía y propiedades físicas/visuales de un arquetipo estelar (sol).
## Configuración data-driven para enanas amarillas, gigantes azules, enanas rojas, etc.

@export_group("Identidad y Clasificación")
@export var id: StringName = &"yellow_dwarf"
@export var display_name: String = "Enana Amarilla"
@export var name_prefixes: Array[String] = ["SOLARIS", "HELIOS", "AURELIA"]
@export_range(0.01, 10.0, 0.05) var spawn_weight: float = 1.0

@export_group("Visuales y Corona")
@export var star_textures: Array[Texture2D] = []
@export var star_color: Color = Color(1.0, 0.85, 0.45, 1.0)
@export var star_core_radius: float = 350.0
@export_range(0.001, 0.05, 0.001) var axial_rotation_speed: float = 0.008
@export_range(0.0, 0.15, 0.005) var heat_distortion_strength: float = 0.045
@export_range(0.1, 5.0, 0.1) var pulse_speed: float = 1.5
@export_range(1.0, 2.5, 0.05) var corona_size_multiplier: float = 1.35
@export_range(0.0, 2.5, 0.05) var corona_intensity: float = 1.30

@export_group("Bioma Estelar")
@export var biome_config: CosmicBiomeConfig

@export_group("Reglas Planetarias y Luz Orbital")
@export var orbit_radius_min: float = 800.0
@export var orbit_radius_max: float = 3200.0
@export var min_orbital_spacing: float = 650.0
@export_range(0.0, 45.0, 1.0) var planet_theta_jitter_degrees: float = 25.0
@export_range(1.0, 2.0, 0.05) var light_field_radius_multiplier: float = 1.25
@export_range(0.0, 1.0, 0.02) var light_field_intensity: float = 0.32
@export_range(0.0, 1.0, 0.02) var heliosphere_noise_strength: float = 0.35
@export_range(0.05, 0.5, 0.01) var heliosphere_edge_feather: float = 0.22
@export_range(0.0, 1.0, 0.05) var planet_day_tint_strength: float = 0.40
@export_range(0.0, 1.0, 0.05) var planet_atmo_tint_strength: float = 0.50

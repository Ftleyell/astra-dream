class_name GalaxyLandmarkProfile
extends Resource

## Perfil data-driven para landmarks cósmicos (macro-galaxias) en capas de paralaje ultra-lento.

@export_group("Visuales")
@export var galaxy_id: StringName = &"spiral_andromeda_type"
@export var galaxy_textures: Array[Texture2D] = []

@export_group("Dimensiones y Frustum")
@export var maximum_bounding_radius: float = 2000.0
@export var safety_padding: float = 400.0
@export var base_scale_range: Vector2 = Vector2(1.2, 2.0)
@export_range(0.0, 1.0, 0.05) var spawn_chance: float = 1.0

@export_group("Macro-Sectores y Cuadrícula")
@export var solar_cells_span: int = 3
@export var cell_size: float = 0.0 ## Si es 0.0, se calcula automáticamente según solar_cells_span * solar_cell_size * scroll_scale
@export var pool_size: int = 6
@export_range(0.0, 0.5, 0.05) var jitter_factor: float = 0.20

@export_group("Dinámica")
@export_range(0.0001, 0.1, 0.0005) var max_drift_rotation_speed: float = 0.012
@export_range(-0.1, 0.1, 0.001) var shader_spin_speed: float = 0.015
@export_range(0.2, 3.0, 0.05) var overall_brightness: float = 1.45
@export_range(0.0, 1.0, 0.02) var core_pulse_intensity: float = 0.35
@export var modulate_colors: Array[Color] = [
	Color(0.85, 0.90, 1.0, 1.0),
	Color(1.0, 0.85, 0.95, 1.0),
	Color(0.75, 1.0, 0.90, 1.0)
]

class_name GalaxyLandmarkProfile
extends Resource

## Perfil data-driven para landmarks cósmicos (macro-galaxias) en capas de paralaje ultra-lento.

@export_group("Visuales")
@export var galaxy_id: StringName = &"spiral_andromeda_type"
@export var galaxy_textures: Array[Texture2D] = []

@export_group("Dimensiones y Frustum")
@export var maximum_bounding_radius: float = 1600.0
@export var safety_padding: float = 400.0
@export var base_scale_range: Vector2 = Vector2(0.8, 1.3)

@export_group("Dinámica")
@export_range(0.0001, 0.005, 0.0001) var max_drift_rotation_speed: float = 0.0006
@export var modulate_colors: Array[Color] = [
	Color(0.82, 0.88, 1.0, 1.0),
	Color(1.0, 0.82, 0.92, 1.0),
	Color(0.72, 1.0, 0.88, 1.0)
]

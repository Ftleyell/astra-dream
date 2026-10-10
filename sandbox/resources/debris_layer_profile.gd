class_name DebrisLayerProfile
extends Resource

## Perfil data-driven para capas de escombros y basura espacial renderizados por GPU en Cosmos Engine.

@export_group("Instanciación GPU")
@export var mesh_texture: Texture2D
@export_range(50, 2500, 50) var instance_count: int = 600
@export var field_bounding_box: Vector2 = Vector2(8192.0, 8192.0)

@export_group("Variación Estocástica")
@export var scale_range: Vector2 = Vector2(0.3, 1.4)
@export_range(0.0, 6.28318, 0.1) var max_initial_rotation: float = 6.28318
@export var alpha_modulation: Color = Color(0.85, 0.9, 0.95, 0.6)

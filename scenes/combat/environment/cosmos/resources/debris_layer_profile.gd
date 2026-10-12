class_name CosmosDebrisLayerProfile
extends Resource

## Perfil data-driven para capas de escombros y basura espacial renderizados por GPU en Cosmos Engine.

@export_group("Texturas de Atlas")
## Textura de atlas para rocas y asteroides naturales (debris_atlas_0.png)
@export var rock_texture: Texture2D
## Textura de atlas para chatarra mecánica y restos industriales (debris_atlas_1.png)
@export var scrap_texture: Texture2D
## Textura base (compatibilidad legacy)
@export var mesh_texture: Texture2D

@export_group("Instanciación GPU")
## Cantidad de instancias para el estrato de rocas
@export_range(50, 2500, 50) var instance_count: int = 1000
## Cantidad de instancias para el estrato de chatarra (0 para desactivar)
@export_range(0, 2500, 50) var scrap_instance_count: int = 600
@export var field_bounding_box: Vector2 = Vector2(8192.0, 8192.0)

@export_group("Estratificación de Tamaños (Atmósfera)")
## Porcentaje estocástico de micro-fragmentos (partículas de profundidad y polvo)
@export_range(0.0, 1.0, 0.05) var micro_ratio: float = 0.70
## Porcentaje estocástico de fragmentos medianos en rotación
@export_range(0.0, 1.0, 0.05) var medium_ratio: float = 0.25
## Porcentaje estocástico de macro-bloques raros (mega asteroides / restos gigantes)
@export_range(0.0, 1.0, 0.01) var macro_ratio: float = 0.05

@export_group("Escalas por Estrato")
@export var micro_scale_range: Vector2 = Vector2(0.20, 0.45)
@export var medium_scale_range: Vector2 = Vector2(0.55, 1.10)
@export var macro_scale_range: Vector2 = Vector2(1.25, 2.10)
## Rango global de escala fallback
@export var scale_range: Vector2 = Vector2(0.35, 1.6)

@export_group("Variación Visual y Alfa")
@export_range(0.0, 6.28318, 0.1) var max_initial_rotation: float = 6.28318
@export var alpha_modulation: Color = Color(0.85, 0.9, 0.95, 0.75)
@export var micro_alpha_multiplier: float = 0.60
@export var medium_alpha_multiplier: float = 0.90
@export var macro_alpha_multiplier: float = 1.00

@export_group("Patrones Espaciales de Spawn (Anti-Overlap)")
## Porcentaje en el cinturón exterior del sistema solar (anillo Kuiper)
@export_range(0.0, 1.0, 0.05) var kuiper_belt_ratio: float = 0.50
## Porcentaje en los márgenes de frontera entre celdas (corredores interestelares)
@export_range(0.0, 1.0, 0.05) var border_corridor_ratio: float = 0.40
## Porcentaje residual en el espacio abierto (polvo ambiente)
@export_range(0.0, 1.0, 0.05) var ambient_space_ratio: float = 0.10

## Ancho radial del cinturón Kuiper exterior al sistema solar (px)
@export var kuiper_belt_width: float = 700.0
## Margen de inicio del cinturón Kuiper tras la órbita del último planeta (px)
@export var kuiper_inner_padding: float = 300.0
## Radio por defecto del cinturón Kuiper si la celda no posee estrella propia (px)
@export var kuiper_default_radius: float = 4600.0
## Ancho del corredor perimetral de frontera entre celdas (px)
@export var border_corridor_width: float = 900.0

@export_group("Umbrales de Clasificación de Área (px²)")
@export var rock_micro_max_area: float = 7000.0
@export var rock_medium_max_area: float = 25000.0
@export var scrap_micro_max_area: float = 9000.0
@export var scrap_medium_max_area: float = 28000.0

func get_effective_rock_texture() -> Texture2D:
	if rock_texture != null:
		return rock_texture
	return mesh_texture

func get_effective_scrap_texture() -> Texture2D:
	return scrap_texture


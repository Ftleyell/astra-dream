class_name BiomeData
extends Resource

## biome_data.gd
## Recurso exportado de datos para biomas y sectores espaciales.
## Controla la apariencia del shader procedural cósmico y la atmósfera del sector.

@export var sector_name: String = "Vacío Neutro"
@export var space_color: Color = Color(0.01, 0.012, 0.025, 1.0)
@export var nebula_primary: Color = Color(0.18, 0.05, 0.32, 1.0)
@export var nebula_secondary: Color = Color(0.02, 0.22, 0.40, 1.0)
@export var nebula_density: float = 0.90
@export var nebula_scale: float = 0.00035
@export var star_density: float = 90.0
@export var star_brightness_cutoff: float = 0.965
@export var chromatic_aberration: float = 0.0

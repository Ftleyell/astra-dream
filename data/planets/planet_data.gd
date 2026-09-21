class_name PlanetData
extends Resource

## PlanetData.gd
## Recurso de definición data-driven para arquetipos y tipos de planetas.

@export var planet_id: StringName = &"verdant"
@export var display_name: String = "Planeta Frondoso"

# Paleta cromática por capas
@export var core_color: Color = Color(0.2, 0.95, 0.6, 1.0)
@export var mantle_color: Color = Color(0.25, 0.58, 0.35, 1.0)
@export var crust_color: Color = Color(0.38, 0.48, 0.32, 1.0)
@export var crust_border_color: Color = Color(0.58, 0.78, 0.48, 1.0)

# Balance y combate por capa
@export var crust_health: float = 60.0
@export var mantle_health: float = 90.0
@export var biomass_per_crust: int = 2
@export var biomass_per_mantle: int = 4

# Metadatos para futura digitalización
@export var core_type: StringName = &"biosphere_core"
@export var texture_overlay: Texture2D = null

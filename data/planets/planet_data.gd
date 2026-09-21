class_name PlanetData
extends Resource

## PlanetData.gd
## Recurso de definición data-driven para arquetipos y tipos de planetas a gran escala.

@export var planet_id: StringName = &"verdant"
@export var display_name: String = "Planeta Frondoso"

# Paleta cromática por capas (de adentro hacia afuera)
@export var core_color: Color = Color(0.2, 0.95, 0.6, 1.0)
@export var deep_mantle_color: Color = Color(0.18, 0.42, 0.28, 1.0)
@export var mid_mantle_color: Color = Color(0.25, 0.58, 0.35, 1.0)
@export var crust_color: Color = Color(0.38, 0.48, 0.32, 1.0)
@export var crust_border_color: Color = Color(0.58, 0.78, 0.48, 1.0)

# Dureza y salud por capa
@export var crust_health: float = 120.0
@export var mid_mantle_health: float = 350.0
@export var deep_mantle_health: float = 700.0

# Recompensas de BioMasa
@export var biomass_per_crust: int = 1
@export var biomass_per_mid_mantle: int = 2
@export var biomass_per_deep_mantle: int = 3
@export var core_biomass_reward: int = 20

# Metadatos para digitalización
@export var core_type: StringName = &"biosphere_core"
@export var texture_overlay: Texture2D = null

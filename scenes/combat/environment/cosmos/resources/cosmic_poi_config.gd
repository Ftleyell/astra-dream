class_name CosmicPoiConfig
extends Resource

## Configuración de Punto de Interés (POI) Narrativo o de Evento para Cosmos Engine.
## Permite forzar arquetipos estelares, conteo de planetas, marcas narrativas y niveles de amenaza
## en coordenadas virtuales específicas del macro-grid.

enum PoiType {
	SOLAR_SYSTEM,
	GALAXY,
	DEBRIS_ANOMALY,
	CUSTOM,
}

@export var poi_type: PoiType = PoiType.SOLAR_SYSTEM
@export var star_archetype: CosmosStarArchetype = null
@export var planet_count: int = -1 ## -1 usa el rango procedural por defecto; >= 0 fuerza la cantidad exacta.
@export var custom_label: StringName = &""
@export var hazard_level: int = 0
@export var seed_override: int = -1 ## -1 usa el hash procedural de la celda; >= 0 fuerza la semilla fija.
@export var extra_metadata: Dictionary = {}

class_name ChestEconomyConfig
extends Resource

## ChestEconomyConfig.gd
## Recurso exportado para calibración data-driven del sistema de cofres espaciales
## y de la economía transaccional inspirada en Megabonk y Risk of Rain 2.

@export_group("Precios Base e Inflación Híbrida")
## Coste inicial base del cofre regular (C_0)
@export var regular_chest_base_cost: int = 20
## Crecimiento del coste base por número de oleada
@export var wave_cost_growth: int = 4
## Tasa de inflación local por cofres abiertos en la misma oleada
@export var local_inflation_rate: float = 0.15
## Recargo porcentual permanente al coste de los cofres por stack de Tarjeta Verde
@export var green_card_surcharge: float = 0.10
## Coste fijo o base del cofre dorado de alta densidad
@export var golden_chest_base_cost: int = 120
## Coste de cápsulas de chatarra/suministro (generalmente 0)
@export var salvage_capsule_cost: int = 0

## Aliases de compatibilidad para código legacy
var base_regular_chest_cost: int:
	get: return regular_chest_base_cost
	set(val): regular_chest_base_cost = val
var green_card_cost_surcharge_pct: float:
	get: return green_card_surcharge
	set(val): green_card_surcharge = val

@export_group("Llave Cuántica (Key)")
## Constante de atenuación hiperbólica K: P(gratis) = n / (K + n)
@export var key_hyperbolic_k: float = 10.0

@export_group("Tarjetas de Crédito")
## Incremento porcentual permanente de Suerte por cada cofre abierto con Tarjeta Verde
@export var green_card_luck_bonus_per_chest: float = 0.05
## Incremento porcentual permanente de Daño Global por cada cofre abierto con Tarjeta Roja
@export var red_card_damage_bonus_per_chest: float = 0.02

@export_group("Presupuesto de Generación Espacial por Oleada")
## Rango de cápsulas de chatarra (gratuitas) a spawnear por oleada [min, max]
@export var salvage_capsules_per_wave: Vector2i = Vector2i(1, 3)
## Rango de cofres regulares a spawnear por oleada [min, max]
@export var regular_chests_per_wave: Vector2i = Vector2i(4, 8)
## Probabilidad por oleada de spawnear un cofre dorado (0.0 a 1.0)
@export_range(0.0, 1.0, 0.05) var golden_chest_chance_per_wave: float = 0.40
## Radio mínimo de dispersión respecto a la posición del jugador
@export var min_spawn_radius: float = 500.0
## Radio máximo de dispersión respecto a la posición del jugador
@export var max_spawn_radius: float = 1600.0

@export_group("Distribución de Rarezas y Suerte")
## Pesos base de aparición para cofre regular: [COMMON, UNCOMMON, RARE, EPIC, LEGENDARY]
@export var regular_base_rarity_weights: Dictionary = {
	Enums.Rarity.COMMON: 75.0,
	Enums.Rarity.UNCOMMON: 20.0,
	Enums.Rarity.RARE: 4.5,
	Enums.Rarity.EPIC: 0.5,
	Enums.Rarity.LEGENDARY: 0.0,
}
## Pesos base de aparición para cofre dorado: [COMMON, UNCOMMON, RARE, EPIC, LEGENDARY]
@export var golden_base_rarity_weights: Dictionary = {
	Enums.Rarity.COMMON: 0.0,
	Enums.Rarity.UNCOMMON: 40.0,
	Enums.Rarity.RARE: 45.0,
	Enums.Rarity.EPIC: 12.0,
	Enums.Rarity.LEGENDARY: 3.0,
}

## Calcula el coste en créditos de un cofre regular según la fórmula híbrida de oleada e inflación local
func calculate_regular_chest_cost(wave: int = 1, local_chests_in_wave: int = 0, green_card_stacks: int = 0, has_quantum_key: bool = false) -> int:
	var base: float = float(regular_chest_base_cost) + float(wave_cost_growth) * float(maxi(1, wave))
	var local_multiplier: float = 1.0 + (local_inflation_rate * float(maxi(0, local_chests_in_wave)))
	var card_multiplier: float = 1.0 + (green_card_surcharge * float(maxi(0, green_card_stacks)))
	var key_discount: float = 0.80 if has_quantum_key else 1.0
	return int(floor(base * local_multiplier * card_multiplier * key_discount))

## Calcula la probabilidad de apertura gratuita por Llaves Cuánticas
func calculate_key_free_chance(key_count: int) -> float:
	if key_count <= 0:
		return 0.0
	var k: float = float(key_count)
	return k / (key_hyperbolic_k + k)

class_name ChestEconomyConfig
extends Resource

## ChestEconomyConfig.gd
## Recurso exportado para calibración data-driven del sistema de cofres espaciales
## y de la economía transaccional inspirada en Megabonk y Risk of Rain 2.

@export_group("Precios Base e Inflación")
## Coste inicial del cofre regular (C_0)
@export var base_regular_chest_cost: int = 25
## Factor de escalado lineal por compras pagadas (A * n)
@export var cost_growth_linear: float = 8.0
## Factor de escalado cuadrático de segundo orden (B * n^2)
@export var cost_growth_quadratic: float = 1.5
## Coste fijo o base del cofre dorado de alta densidad
@export var golden_chest_base_cost: int = 150
## Coste de cápsulas de chatarra/suministro (generalmente 0)
@export var salvage_capsule_cost: int = 0

@export_group("Llave Cuántica (Key)")
## Constante de atenuación hiperbólica K: P(gratis) = n / (K + n)
@export var key_hyperbolic_k: float = 10.0

@export_group("Tarjetas de Crédito")
## Incremento porcentual permanente de Suerte por cada cofre abierto con Tarjeta Verde
@export var green_card_luck_bonus_per_chest: float = 0.05
## Recargo porcentual permanente al coste de los cofres por stack de Tarjeta Verde
@export var green_card_cost_surcharge_pct: float = 0.10
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

## Calcula el coste en créditos de un cofre regular tras 'paid_chests' compras pagadas
func calculate_regular_chest_cost(paid_chests: int, green_card_stacks: int = 0) -> int:
	var n: float = float(maxi(0, paid_chests))
	var base_calc: float = float(base_regular_chest_cost) + (cost_growth_linear * n) + (cost_growth_quadratic * n * n)
	if green_card_stacks > 0:
		base_calc *= (1.0 + (green_card_cost_surcharge_pct * float(green_card_stacks)))
	return maxi(1, int(round(base_calc)))

## Calcula la probabilidad de apertura gratuita por Llaves Cuánticas
func calculate_key_free_chance(key_count: int) -> float:
	if key_count <= 0:
		return 0.0
	var k: float = float(key_count)
	return k / (key_hyperbolic_k + k)

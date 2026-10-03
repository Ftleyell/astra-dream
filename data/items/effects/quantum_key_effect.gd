class_name QuantumKeyEffect
extends ItemEffect

## QuantumKeyEffect.gd
## Efecto de la Llave Cuántica: Permite calcular la probabilidad hiperbólica
## de apertura gratuita de cofres espaciales y la congelación del coste.

@export var k_constant: float = 10.0

func _init() -> void:
	trigger = Enums.TriggerType.PASSIVE_STAT
	base_chance = 1.0
	proc_coefficient = 1.0

## Calcula la probabilidad hiperbólica n / (k + n)
func get_free_chance(stack_count: int) -> float:
	if stack_count <= 0:
		return 0.0
	var n: float = float(stack_count)
	return n / (k_constant + n)

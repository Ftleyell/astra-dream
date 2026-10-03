class_name CreditCardRedEffect
extends ItemEffect

## CreditCardRedEffect.gd
## Efecto de la Tarjeta de Crédito Roja:
## Al abrir un cofre espacial, otorga +2% permanente de Daño Base/Global por copia del ítem.

@export var damage_gain_per_chest: float = 0.02

func _init() -> void:
	trigger = Enums.TriggerType.ON_CHEST_OPENED
	base_chance = 1.0
	proc_coefficient = 1.0

func execute(_context: HitContext, stack_count: int, source_entity: Node) -> void:
	if not source_entity or not is_instance_valid(source_entity):
		return
	if source_entity is Player:
		var p: Player = source_entity as Player
		if p.character_stats:
			var bonus: float = damage_gain_per_chest * float(maxi(1, stack_count))
			var current_mod: CharacterStats.StatModifier = p.character_stats.get_stat_modifier(&"base_damage", &"credit_card_red_proc")
			var existing_val: float = current_mod.value if current_mod else 0.0
			var new_mod := CharacterStats.StatModifier.new(&"credit_card_red_proc", existing_val + bonus, true, &"credit_card_red")
			p.character_stats.set_or_replace_modifier(&"base_damage", new_mod)

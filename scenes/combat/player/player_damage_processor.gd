class_name PlayerDamageProcessor
extends RefCounted

## PlayerDamageProcessor.gd
## Componente modular especializado en procesamiento de daño, OSP (One-Shot Protection) y mitigación.
## Extraído de Player y PlayerShieldController como parte de la Fase 3 del Plan de Erradicación de Monolitos.

func process_incoming_damage(player: CharacterBody2D, ctx: HitContext, shield_controller: RefCounted, stats: CharacterStats, inventory: Node) -> void:
	if not player or not ctx or player.get("is_invulnerable") == true:
		return

	if shield_controller:
		shield_controller.take_damage(player, ctx, stats, inventory)


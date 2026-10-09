class_name PlayerDamageProcessor
extends RefCounted

## PlayerDamageProcessor.gd
## Componente modular especializado en procesamiento de daño, OSP (One-Shot Protection) y mitigación.
## Extraído de Player y PlayerShieldController como parte de la Fase 3 del Plan de Erradicación de Monolitos.

func process_incoming_damage(player: CharacterBody2D, arg: Variant, shield_controller: RefCounted, stats: CharacterStats, inventory: Node) -> void:
	if not player or player.get("is_invulnerable") == true:
		return

	var ctx: HitContext
	if arg is HitContext:
		ctx = arg as HitContext
	elif arg is float or arg is int:
		ctx = HitContext.create_direct_hit(float(arg))
	else:
		return

	var current_shield_val: float = float(shield_controller.current_shield) if (shield_controller and "current_shield" in shield_controller) else 0.0
	var max_shield_val: float = float(shield_controller.max_shield) if (shield_controller and "max_shield" in shield_controller) else 0.0
	var current_combined: float = player.current_health + current_shield_val
	var max_hp_val: float = stats.get_stat(&"max_health") if stats else 100.0
	var max_combined: float = max_hp_val + max_shield_val

	var osp_threshold: float = 0.90
	if (stats and stats.has_method("has_modifier") and stats.has_modifier(&"max_health", &"glass_cannon")) or player.has_meta("glass_cannon"):
		osp_threshold = 0.95

	var osp_did_trigger: bool = false
	if not ctx.bypass_osp and current_combined >= (max_combined * osp_threshold):
		if ctx.final_damage >= current_combined:
			ctx.final_damage = maxf(0.0, current_combined - 1.0)
			osp_did_trigger = true

	if osp_did_trigger:
		player.set_meta(&"osp_active_frame", true)

	if shield_controller:
		shield_controller.take_damage(player, ctx.final_damage, stats, inventory)

	if osp_did_trigger:
		if player.has_meta(&"osp_active_frame"):
			player.remove_meta(&"osp_active_frame")
		player.current_health = maxf(1.0, player.current_health)
		player.is_invulnerable = true
		var tree: SceneTree = player.get_tree()
		if tree:
			tree.create_timer(0.5, false, false, true).timeout.connect(func() -> void:
				if is_instance_valid(player):
					player.is_invulnerable = false
			)
		if player.has_signal("osp_triggered"):
			player.emit_signal("osp_triggered", player.current_health)

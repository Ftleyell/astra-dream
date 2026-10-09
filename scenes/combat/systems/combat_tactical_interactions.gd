class_name CombatTacticalInteractions
extends RefCounted

## Gestor desacoplado de interacciones con ítems tácticos de campo (Chronos Bank, Heavy Salvager).
## Extraído de MainGame para modularidad y separación de responsabilidades.

static func apply_chronos_bank_interest(player: Player, hud: GameHUD) -> void:
	if not is_instance_valid(player) or not player.inventory:
		return
	if player.inventory.get_item_count(&"chronos_bank") > 0:
		var unspent: int = player.run_credits
		if unspent > 0:
			var interest: int = mini(50, int(floor(float(unspent) * 0.10)))
			if interest > 0:
				player.run_credits += interest
				if player.has_signal("credits_changed"):
					player.credits_changed.emit(player.run_credits)
				if is_instance_valid(hud) and hud.has_method("show_tactical_alert"):
					hud.show_tactical_alert("⏳ BANCO CRONOS", "+%d créditos generados" % interest, Color(1.0, 0.85, 0.2))

static func on_salvage_capsule_opened(player: Player, hud: GameHUD) -> void:
	if not is_instance_valid(player) or not player.inventory:
		return
	if player.inventory.get_item_count(&"heavy_salvager") > 0:
		if player.character_stats:
			var cur_base_hp: float = player.character_stats.get_base_stat(&"max_health")
			player.character_stats.set_base_stat(&"max_health", cur_base_hp + 2.0)
		if player.has_method("heal"):
			player.heal(2.0)
		player.run_credits += 3
		if player.has_signal("credits_changed"):
			player.credits_changed.emit(player.run_credits)
		if is_instance_valid(hud) and hud.has_method("show_tactical_alert"):
			hud.show_tactical_alert("📦 RECUPERADOR PESADO", "+2 HP Máxima • +3 créditos", Color(0.4, 1.0, 0.6))
static func handle_tactical_inventory_changes(player: Player, hud: GameHUD, chest_director: ChestDirector, last_keys: int, last_green_cards: int) -> Array[int]:
	if not is_instance_valid(player) or not player.inventory:
		return [last_keys, last_green_cards]
	var cur_keys: int = player.inventory.get_item_count(&"quantum_key")
	var cur_cards: int = player.inventory.get_item_count(&"credit_card_green")
	if cur_keys != last_keys or cur_cards != last_green_cards:
		if cur_keys != last_keys and hud and hud.has_method("update_quantum_keys"):
			hud.update_quantum_keys(cur_keys)
		if cur_cards != last_green_cards and chest_director:
			chest_director.refresh_all_chest_prices(cur_cards)
	return [cur_keys, cur_cards]

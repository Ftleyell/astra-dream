class_name TransmutationDataController
extends RefCounted

## TransmutationDataController.gd
## Lógica de negocio y reglas desacopladas para la Forja Cuántica de Transmutación.
## Valida elegibilidad de ítems, existencia de sacrificios de la misma rareza y transacciones.

const ItemDataScript = preload("res://data/items/item_data.gd")


static func is_item_eligible_for_transmutation(it: ItemData) -> bool:
	if not it:
		return false
	if it.item_id == &"quantum_key":
		return false
	if it.tags.has(&"consumable") or it.tags.has(&"key"):
		return false
	return true


static func get_eligible_items(inventory: Node) -> Array[Dictionary]:
	if not inventory or not inventory.has_method("get_all_items"):
		return []

	var all_items: Array = inventory.get_all_items()
	var eligible: Array[Dictionary] = []
	for entry in all_items:
		var it: ItemData = entry.get("data", null)
		if is_item_eligible_for_transmutation(it):
			eligible.append(entry)
	return eligible


static func find_sacrifice_candidates(target_item: ItemData, eligible_items: Array[Dictionary]) -> Array[ItemData]:
	var candidates: Array[ItemData] = []
	if not target_item:
		return candidates

	for entry in eligible_items:
		var it: ItemData = entry.get("data", null)
		var cnt: int = entry.get("count", 0)
		if not is_item_eligible_for_transmutation(it):
			continue
		if it.rarity == target_item.rarity:
			if it.item_id != target_item.item_id:
				candidates.append(it)
			elif cnt > 1:
				candidates.append(it)
	return candidates


static func has_sacrifice_available(item: ItemData, eligible_items: Array[Dictionary]) -> bool:
	if not item:
		return false
	for other_entry in eligible_items:
		var other_it: ItemData = other_entry.get("data", null)
		var other_count: int = other_entry.get("count", 0)
		if other_it and other_it.rarity == item.rarity:
			if other_it.item_id != item.item_id or other_count > 1:
				return true
	return false


static func execute_transmutation(player: Player, target_item: ItemData, transmutation_cost: int) -> Dictionary:
	# Retorna: {"success": bool, "error": String, "sacrifice": ItemData}
	if not player or not is_instance_valid(player):
		return {"success": false, "error": "Jugador inválido.", "sacrifice": null}

	if player.run_credits < transmutation_cost:
		return {"success": false, "error": "¡Créditos insuficientes! Se requieren %dc." % transmutation_cost, "sacrifice": null}

	if not player.inventory:
		return {"success": false, "error": "Inventario no disponible.", "sacrifice": null}

	var eligible_items := get_eligible_items(player.inventory)
	var candidates := find_sacrifice_candidates(target_item, eligible_items)

	if candidates.is_empty():
		return {"success": false, "error": "¡Sin material de sacrificio!", "sacrifice": null}

	var sacrifice_item: ItemData = candidates.pick_random()
	player.run_credits -= transmutation_cost
	if player.has_signal("credits_changed"):
		player.credits_changed.emit(player.run_credits)

	player.inventory.remove_item_stacks(sacrifice_item.item_id, 1)

	return {"success": true, "error": "", "sacrifice": sacrifice_item}

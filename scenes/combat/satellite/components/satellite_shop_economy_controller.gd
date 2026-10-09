class_name SatelliteShopEconomyController
extends RefCounted

## SatelliteShopEconomyController.gd
## Controlador económico y de inventario dinámico para la Tienda de Satélites:
## - Seguimiento de créditos y costes de reroll por visita.
## - Algoritmo de rodada de ofertas (garantía de arma en slot 0, límites de stacks de ítems).
## - Registro y validación de compras por slot.

var current_credits: int = 100
var base_reroll_cost: int = 30
var max_rerolls_per_satellite: int = 1
var reroll_cost: int = 30
var rerolls_used_this_visit: int = 0
var active_satellite_id: int = -1
var purchased_slots: Array[int] = []
var current_offered_items: Array[Resource] = []

static func calculate_item_cost(entry: Resource, player: Player = null) -> int:
	if entry is WeaponData and is_instance_valid(player):
		var w_ctrl: WeaponController = player.get_node_or_null("WeaponController") as WeaponController
		if w_ctrl and w_ctrl.get_weapon_instance((entry as WeaponData).weapon_id):
			return 100
	var cost_val: Variant = entry.get("cost")
	if cost_val != null and int(cost_val) > 0:
		return int(cost_val)
	return 50

func can_purchase(cost: int) -> bool:
	return current_credits >= cost

func can_reroll() -> bool:
	return rerolls_used_this_visit < max_rerolls_per_satellite and current_credits >= reroll_cost

func open_visit(credits: int, satellite_id: int, p_base_reroll_cost: int, p_max_rerolls: int) -> bool:
	current_credits = credits
	base_reroll_cost = p_base_reroll_cost
	max_rerolls_per_satellite = p_max_rerolls

	var is_same_satellite: bool = (satellite_id != -1 and satellite_id == active_satellite_id and not current_offered_items.is_empty())
	if not is_same_satellite:
		active_satellite_id = satellite_id
		reroll_cost = base_reroll_cost
		rerolls_used_this_visit = 0
		purchased_slots.clear()
	return is_same_satellite

func roll_shop_items(available_items_pool: Array[Resource], player: Player) -> Array[Resource]:
	purchased_slots.clear()
	current_offered_items.clear()

	var pool_copy: Array[Resource] = available_items_pool.duplicate()
	pool_copy.shuffle()

	var selected_items: Array[Resource] = []

	# Slot 0: Arma garantizada si está disponible en el pool
	for res: Resource in pool_copy:
		if res is WeaponData:
			selected_items.append(res)
			break

	# Slots 1 y 2: Ítems filtrados por max_stacks del jugador
	var eligible_items: Array[ItemData] = []
	for res: Resource in pool_copy:
		if res is ItemData:
			var it: ItemData = res as ItemData
			var count: int = 0
			if is_instance_valid(player) and player.inventory:
				count = player.inventory.get_item_count(it.item_id)
			if count < it.max_stacks:
				eligible_items.append(it)

	for it: ItemData in eligible_items:
		if selected_items.size() >= 3:
			break
		if not selected_items.has(it):
			selected_items.append(it)

	# Fallback si el pool no alcanza a llenar 3 ranuras
	for res: Resource in pool_copy:
		if selected_items.size() >= 3:
			break
		if not selected_items.has(res):
			selected_items.append(res)

	while selected_items.size() < 3 and not pool_copy.is_empty():
		selected_items.append(pool_copy[randi() % pool_copy.size()])

	current_offered_items = selected_items
	return current_offered_items

func execute_reroll(player: Player) -> int:
	if not can_reroll():
		return 0
	var cost_paid: int = reroll_cost
	current_credits -= cost_paid
	rerolls_used_this_visit += 1
	if is_instance_valid(player):
		player.run_credits = current_credits
		if player.has_signal("credits_changed"):
			player.credits_changed.emit(player.run_credits)
	return cost_paid

func record_purchase(slot_idx: int, cost: int, player: Player) -> void:
	current_credits = maxi(0, current_credits - cost)
	if slot_idx >= 0 and not purchased_slots.has(slot_idx):
		purchased_slots.append(slot_idx)
	if is_instance_valid(player):
		player.run_credits = current_credits
		if player.has_signal("credits_changed"):
			player.credits_changed.emit(player.run_credits)

func can_afford_any(buy_buttons: Array[Button]) -> bool:
	if can_reroll():
		return true
	for btn: Button in buy_buttons:
		if is_instance_valid(btn) and not btn.disabled:
			var cost: int = int(btn.get_meta(&"cost", 999999))
			if current_credits >= cost:
				return true
	return false

func is_slot_purchased(slot_idx: int) -> bool:
	return purchased_slots.has(slot_idx)

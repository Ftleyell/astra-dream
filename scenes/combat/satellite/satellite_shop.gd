class_name SatelliteShop
extends CanvasLayer

## SatelliteShop.gd
## Orquestador desacoplado y ligero (<200 líneas) de la Tienda de Satélites:
## - Panel de compras interactivo con soporte completo de teclado, mando y ratón.
## - Panel lateral de inventario y estadísticas coordinado por SatelliteShopInventoryPanel.
## - Construcción modular de cartas de ítems mediante SatelliteShopCardBuilder.
## - Gestión económica delegada en SatelliteShopEconomyController.
## - Navegación y atajos despachados por SatelliteShopNavigationController.

const WeaponSwapModalClass = preload("res://scenes/ui/modals/weapon_swap_modal.gd")
const SatelliteShopInventoryPanelClass = preload("res://scenes/combat/satellite/components/satellite_shop_inventory_panel.gd")
const SatelliteShopCardBuilderClass = preload("res://scenes/combat/satellite/components/satellite_shop_card_builder.gd")
const SatelliteShopEconomyControllerClass = preload("res://scenes/combat/satellite/components/satellite_shop_economy_controller.gd")
const SatelliteShopNavigationControllerClass = preload("res://scenes/combat/satellite/components/satellite_shop_navigation_controller.gd")

signal item_purchased(item: Resource, cost: int)
signal shop_closed()

@export var available_items_pool: Array[Resource] = []
@export var player: Player

@export var base_reroll_cost: int = 30
@export var max_rerolls_per_satellite: int = 1

# Sub-Controllers
var _inventory_panel: RefCounted
var _economy: RefCounted

# Backwards Compatibility Facades
var current_credits: int:
	get:
		return _economy.current_credits if _economy else 100
	set(val):
		if _economy:
			_economy.current_credits = val

var reroll_cost: int:
	get:
		return _economy.reroll_cost if _economy else 30
	set(val):
		if _economy:
			_economy.reroll_cost = val

var rerolls_used_this_visit: int:
	get:
		return _economy.rerolls_used_this_visit if _economy else 0
	set(val):
		if _economy:
			_economy.rerolls_used_this_visit = val

var active_satellite_id: int:
	get:
		return _economy.active_satellite_id if _economy else -1
	set(val):
		if _economy:
			_economy.active_satellite_id = val

var purchased_slots: Array[int]:
	get:
		return _economy.purchased_slots if _economy else []

var current_offered_items: Array[Resource]:
	get:
		return _economy.current_offered_items if _economy else []

var buy_buttons: Array[Button] = []

# Node References
@onready var panel: Panel = $ShopPanel
@onready var items_container: VBoxContainer = find_child("ItemsContainer", true, false) as VBoxContainer
@onready var credits_label: Label = find_child("CreditsLabel", true, false) as Label
@onready var reroll_btn: Button = find_child("RerollButton", true, false) as Button
@onready var close_btn: Button = find_child("CloseButton", true, false) as Button
@onready var inventory_side_panel: PanelContainer = find_child("InventorySidePanel", true, false) as PanelContainer
@onready var inventory_summary_label: Label = find_child("InventorySummary", true, false) as Label
@onready var stats_header_label: Label = find_child("StatsHeader", true, false) as Label
@onready var stats_list: VBoxContainer = find_child("StatsList", true, false) as VBoxContainer
@onready var weapons_list: VBoxContainer = find_child("WeaponsList", true, false) as VBoxContainer
@onready var items_list: VBoxContainer = find_child("ItemsList", true, false) as VBoxContainer

var stat_ui_entries: Dictionary:
	get:
		return _inventory_panel.stat_ui_entries if _inventory_panel else {}


func can_reroll() -> bool:
	return _economy.can_reroll() if _economy else false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()

	_inventory_panel = SatelliteShopInventoryPanelClass.new()
	_inventory_panel.setup(stats_list, weapons_list, items_list, inventory_summary_label)
	_economy = SatelliteShopEconomyControllerClass.new()

	SatelliteShopCardBuilderClass.apply_panel_styles(panel, inventory_side_panel)

	if close_btn:
		close_btn.pressed.connect(close_shop)
		UIFocusHelper.apply_cyber_focus(close_btn)
	if reroll_btn:
		reroll_btn.pressed.connect(_on_reroll_pressed)
		UIFocusHelper.apply_cyber_focus(reroll_btn)

	if available_items_pool.is_empty():
		_generate_default_shop_items()


func _ensure_player() -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Player
	if not is_instance_valid(player) and get_parent() and "player" in get_parent() and is_instance_valid(get_parent().player):
		player = get_parent().player as Player


func _generate_default_shop_items() -> void:
	available_items_pool.clear()
	for it: ItemData in ItemPoolManager.create_satellite_shop_items():
		available_items_pool.append(it)


func open_shop(credits: int, satellite_id: int = -1) -> void:
	_ensure_player()
	var is_same_satellite: bool = _economy.open_visit(credits, satellite_id, base_reroll_cost, max_rerolls_per_satellite)

	if not is_same_satellite:
		_roll_shop_items()
	else:
		_restore_existing_shop_view()

	_update_credits_display()
	_refresh_stats_display()
	_refresh_inventory_display()

	show()
	PauseArbitrator.acquire_pause(&"satellite_shop")
	var hud: Node = _get_hud_node()
	if hud and hud.has_method("set_stats_dock_requested"):
		hud.set_stats_dock_requested(&"satellite_shop", true)
	_setup_focus_and_grab()


func _restore_existing_shop_view() -> void:
	if not items_container:
		return
	for child: Node in items_container.get_children():
		child.queue_free()
	buy_buttons.clear()

	for i: int in range(current_offered_items.size()):
		var entry: Resource = current_offered_items[i]
		SatelliteShopCardBuilderClass.create_item_card_ui(entry, i, self)
		if i in purchased_slots and i < buy_buttons.size():
			var btn: Button = buy_buttons[i]
			if is_instance_valid(btn):
				SatelliteShopCardBuilderClass.mark_card_purchased(btn)


func restore_focus() -> void:
	_focus_next_available_buy_button()


func close_shop() -> void:
	hide()
	PauseArbitrator.release_pause(&"satellite_shop")
	var hud: Node = _get_hud_node()
	if hud and hud.has_method("set_stats_dock_requested"):
		hud.set_stats_dock_requested(&"satellite_shop", false)
	_clear_stat_highlights()
	shop_closed.emit()


func _get_hud_node() -> Node:
	var hud_node: Node = get_tree().get_first_node_in_group("hud") if get_tree() else null
	if not hud_node and get_parent() and "hud" in get_parent() and is_instance_valid(get_parent().hud):
		hud_node = get_parent().hud
	return hud_node


func _refresh_stats_display() -> void:
	_ensure_player()
	var hud: Node = _get_hud_node()
	if hud and "combat_stats_dock" in hud and is_instance_valid(hud.combat_stats_dock) and is_instance_valid(player):
		hud.combat_stats_dock.refresh_stats(player)
	if _inventory_panel:
		_inventory_panel.refresh_stats_display(player)


func _highlight_preview_stat(stat_key: StringName, delta_val: float, is_pct: bool) -> void:
	var hud: Node = _get_hud_node()
	if hud and "combat_stats_dock" in hud and is_instance_valid(hud.combat_stats_dock):
		hud.combat_stats_dock.preview_raw_stat(stat_key, delta_val, is_pct)
	if _inventory_panel:
		_inventory_panel.highlight_preview_stat(stat_key, delta_val, is_pct)


func _clear_stat_highlights() -> void:
	var hud: Node = _get_hud_node()
	if hud and "combat_stats_dock" in hud and is_instance_valid(hud.combat_stats_dock):
		hud.combat_stats_dock.clear_previews()
	if _inventory_panel:
		_inventory_panel.clear_stat_highlights()


func _refresh_inventory_display() -> void:
	_ensure_player()
	if _inventory_panel:
		_inventory_panel.refresh_inventory_display(player)


func highlight_preview_stat(stat_key: StringName, delta_val: float, is_pct: bool) -> void: _highlight_preview_stat(stat_key, delta_val, is_pct)
func clear_stat_highlights() -> void: _clear_stat_highlights()


func _buy_item_by_index(index: int) -> void:
	SatelliteShopNavigationControllerClass.buy_item_by_index(index, self)


func _unhandled_input(event: InputEvent) -> void:
	SatelliteShopNavigationControllerClass.handle_unhandled_input(event, self)


func _can_afford_any_option() -> bool:
	return _economy.can_afford_any(buy_buttons) if _economy else false


func _update_credits_display() -> void:
	if credits_label:
		credits_label.text = "Créditos: %d" % current_credits
	for btn: Button in buy_buttons:
		if is_instance_valid(btn) and not btn.disabled:
			SatelliteShopCardBuilderClass.update_card_affordability(btn, current_credits)
	SatelliteShopCardBuilderClass.update_action_buttons(
		reroll_btn, close_btn, current_credits, reroll_cost,
		rerolls_used_this_visit, max_rerolls_per_satellite, _can_afford_any_option()
	)


func _roll_shop_items() -> void:
	if not items_container:
		return
	for child: Node in items_container.get_children():
		child.queue_free()
	buy_buttons.clear()

	if available_items_pool.is_empty():
		_generate_default_shop_items()

	_ensure_player()
	var selected_items: Array[Resource] = _economy.roll_shop_items(available_items_pool, player)
	for i: int in range(selected_items.size()):
		SatelliteShopCardBuilderClass.create_item_card_ui(selected_items[i], i, self)
	_setup_focus_and_grab()


func handle_item_purchase(entry: Resource, cost: int, buy_btn: Button) -> void:
	if not _economy.can_purchase(cost):
		return

	if entry is WeaponData:
		_ensure_player()
		if is_instance_valid(player):
			var w_ctrl: WeaponController = player.get_node_or_null("WeaponController") as WeaponController
			if w_ctrl and w_ctrl.has_method("is_full") and w_ctrl.is_full() and not w_ctrl.get_weapon_instance((entry as WeaponData).weapon_id):
				_open_shop_weapon_swap(entry as WeaponData, cost, buy_btn)
				return

	var btn_idx: int = buy_buttons.find(buy_btn)
	_economy.record_purchase(btn_idx, cost, player)
	_update_credits_display()
	SatelliteShopCardBuilderClass.mark_card_purchased(buy_btn)
	item_purchased.emit(entry, cost)

	call_deferred("_refresh_inventory_display")
	call_deferred("_refresh_stats_display")
	_clear_stat_highlights()
	_focus_next_available_buy_button()


func _setup_focus_and_grab() -> void:
	SatelliteShopCardBuilderClass.wire_directional_focus(buy_buttons, reroll_btn, close_btn)
	_focus_next_available_buy_button()


func _focus_next_available_buy_button() -> void:
	if _can_afford_any_option():
		for btn: Button in buy_buttons:
			if is_instance_valid(btn) and not btn.disabled:
				var cost: int = int(btn.get_meta(&"cost", 0))
				if current_credits >= cost:
					btn.grab_focus()
					return
		if can_reroll() and reroll_btn and is_instance_valid(reroll_btn) and not reroll_btn.disabled:
			reroll_btn.grab_focus()
			return

	if close_btn and is_instance_valid(close_btn):
		close_btn.grab_focus()


func _on_reroll_pressed() -> void:
	if not can_reroll():
		return
	_ensure_player()
	_economy.execute_reroll(player)
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("update_credits"):
		hud.update_credits(current_credits)
	_update_credits_display()
	_roll_shop_items()


func _open_shop_weapon_swap(w_data: WeaponData, cost: int, buy_btn: Button) -> void:
	var swap_modal: Node = WeaponSwapModalClass.new()
	get_tree().root.add_child(swap_modal)
	swap_modal.prompt_swap(player, w_data,
		func(_idx: int, _new_w: WeaponData) -> void:
			var btn_idx: int = buy_buttons.find(buy_btn)
			_economy.record_purchase(btn_idx, cost, player)
			var hud: Node = get_tree().get_first_node_in_group("hud")
			if hud and hud.has_method("update_credits"):
				hud.update_credits(current_credits)
			_update_credits_display()
			if is_instance_valid(buy_btn):
				SatelliteShopCardBuilderClass.mark_card_purchased(buy_btn)
			item_purchased.emit(w_data, cost)
			call_deferred("_refresh_inventory_display")
			call_deferred("_refresh_stats_display")
			_clear_stat_highlights()
			_focus_next_available_buy_button()
			get_tree().paused = true
			swap_modal.queue_free(),
		func(_discarded_w: WeaponData) -> void:
			get_tree().paused = true
			if is_instance_valid(buy_btn):
				buy_btn.grab_focus()
			else:
				_focus_next_available_buy_button()
			swap_modal.queue_free()
	)

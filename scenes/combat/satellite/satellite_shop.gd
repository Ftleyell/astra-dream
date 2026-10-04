class_name SatelliteShop
extends CanvasLayer

## SatelliteShop.gd
## Orquestador desacoplado de la Tienda de Satélites:
## - Panel de compras interactivo con soporte completo de teclado, mando y ratón.
## - Panel lateral de inventario y estadísticas coordinado por SatelliteShopInventoryPanel.
## - Construcción modular de cartas de ítems mediante SatelliteShopCardBuilder.
## - Modal de reemplazo de armas (WeaponSwapModal) al alcanzar el tope de 6 armas.

const WeaponSwapModalClass = preload("res://scenes/ui/modals/weapon_swap_modal.gd")
const SatelliteShopInventoryPanelClass = preload("res://scenes/combat/satellite/components/satellite_shop_inventory_panel.gd")
const SatelliteShopCardBuilderClass = preload("res://scenes/combat/satellite/components/satellite_shop_card_builder.gd")

signal item_purchased(item: Resource, cost: int)
signal shop_closed()

@export var available_items_pool: Array[Resource] = []
@export var player: Player

var current_credits: int = 100
@export var base_reroll_cost: int = 30
@export var max_rerolls_per_satellite: int = 1
var reroll_cost: int = 30
var rerolls_used_this_visit: int = 0
var active_satellite_id: int = -1
var purchased_slots: Array[int] = []
var current_offered_items: Array[Resource] = []
var buy_buttons: Array[Button] = []

# Sub-Controllers
var _inventory_panel: RefCounted

# Node References
@onready var panel: Panel = $ShopPanel
@onready var items_container: HBoxContainer = find_child("ItemsContainer", true, false) as HBoxContainer
@onready var credits_label: Label = find_child("CreditsLabel", true, false) as Label
@onready var reroll_btn: Button = find_child("RerollButton", true, false) as Button
@onready var close_btn: Button = find_child("CloseButton", true, false) as Button
@onready var inventory_side_panel: PanelContainer = find_child("InventorySidePanel", true, false) as PanelContainer
@onready var inventory_summary_label: Label = find_child("InventorySummary", true, false) as Label
@onready var stats_header_label: Label = find_child("StatsHeader", true, false) as Label
@onready var stats_list: VBoxContainer = find_child("StatsList", true, false) as VBoxContainer
@onready var weapons_list: VBoxContainer = find_child("WeaponsList", true, false) as VBoxContainer
@onready var items_list: VBoxContainer = find_child("ItemsList", true, false) as VBoxContainer

# Backwards Compatibility Facade for test suite
var stat_ui_entries: Dictionary:
	get:
		return _inventory_panel.stat_ui_entries if _inventory_panel else {}

func can_reroll() -> bool:
	return rerolls_used_this_visit < max_rerolls_per_satellite and current_credits >= reroll_cost


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()

	# Sub-controller setup
	_inventory_panel = SatelliteShopInventoryPanelClass.new()
	_inventory_panel.setup(stats_list, weapons_list, items_list, inventory_summary_label)

	# Estilos translúcidos de alta tecnología
	var shop_style := StyleBoxFlat.new()
	shop_style.bg_color = Color(0.04, 0.06, 0.1, 0.96)
	shop_style.set_border_width_all(2)
	shop_style.border_color = Color(0.2, 0.6, 1.0, 0.7)
	shop_style.set_corner_radius_all(12)
	shop_style.set_content_margin_all(16.0)
	if panel:
		panel.add_theme_stylebox_override("panel", shop_style)

	if inventory_side_panel:
		var inv_style := StyleBoxFlat.new()
		inv_style.bg_color = Color(0.03, 0.04, 0.07, 0.92)
		inv_style.set_border_width_all(1)
		inv_style.border_color = Color(0.2, 0.5, 0.8, 0.5)
		inv_style.set_corner_radius_all(8)
		inventory_side_panel.add_theme_stylebox_override("panel", inv_style)

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


func _generate_default_shop_items() -> void:
	available_items_pool.clear()
	var items: Array[ItemData] = ItemPoolManager.create_satellite_shop_items()
	for it: ItemData in items:
		available_items_pool.append(it)

	# Añadir las 4 armas exclusivas de la tienda
	var shop_weapon_paths: Array[String] = [
		"res://data/weapons/shop/nova_flak.tres",
		"res://data/weapons/shop/dimensional_blade.tres",
		"res://data/weapons/shop/solar_beam.tres",
		"res://data/weapons/shop/cluster_submunition.tres"
	]
	for p: String in shop_weapon_paths:
		if ResourceLoader.exists(p):
			var w: Resource = load(p)
			if w:
				available_items_pool.append(w)


func open_shop(credits: int, satellite_id: int = -1) -> void:
	current_credits = credits
	_ensure_player()

	var is_same_satellite: bool = (satellite_id != -1 and satellite_id == active_satellite_id and not current_offered_items.is_empty())

	if not is_same_satellite:
		active_satellite_id = satellite_id
		reroll_cost = base_reroll_cost
		rerolls_used_this_visit = 0
		purchased_slots.clear()
		_roll_shop_items()
	else:
		_restore_existing_shop_view()

	_update_credits_display()
	_refresh_stats_display()
	_refresh_inventory_display()

	show()
	get_tree().paused = true
	_setup_focus_and_grab()


func _restore_existing_shop_view() -> void:
	if not items_container:
		return
	items_container.queue_free_children() if items_container.has_method("queue_free_children") else null
	for child: Node in items_container.get_children():
		child.queue_free()
	buy_buttons.clear()

	for i: int in range(current_offered_items.size()):
		var entry: Resource = current_offered_items[i]
		SatelliteShopCardBuilderClass.create_item_card_ui(entry, i, self)
		if i in purchased_slots and i < buy_buttons.size():
			var btn: Button = buy_buttons[i]
			if is_instance_valid(btn):
				btn.disabled = true
				btn.text = "¡Adquirido!"


func restore_focus() -> void:
	_focus_next_available_buy_button()


func close_shop() -> void:
	hide()
	get_tree().paused = false
	_clear_stat_highlights()
	shop_closed.emit()


func _refresh_stats_display() -> void:
	_ensure_player()
	if _inventory_panel:
		_inventory_panel.refresh_stats_display(player)


func _highlight_preview_stat(stat_key: StringName, delta_val: float, is_pct: bool) -> void:
	if _inventory_panel:
		_inventory_panel.highlight_preview_stat(stat_key, delta_val, is_pct)


func _clear_stat_highlights() -> void:
	if _inventory_panel:
		_inventory_panel.clear_stat_highlights()


func _refresh_inventory_display() -> void:
	_ensure_player()
	if _inventory_panel:
		_inventory_panel.refresh_inventory_display(player)


func highlight_preview_stat(stat_key: StringName, delta_val: float, is_pct: bool) -> void:
	_highlight_preview_stat(stat_key, delta_val, is_pct)


func clear_stat_highlights() -> void:
	_clear_stat_highlights()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		close_shop()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_select") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE):
		var focus_owner: Control = get_viewport().gui_get_focus_owner()
		if focus_owner is Button and not focus_owner.disabled:
			focus_owner.emit_signal("pressed")
			get_viewport().set_input_as_handled()
			return
		_focus_next_available_buy_button()
		var new_focus: Control = get_viewport().gui_get_focus_owner()
		if new_focus is Button and not new_focus.disabled:
			new_focus.emit_signal("pressed")
		else:
			close_shop()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				_buy_item_by_index(0)
				get_viewport().set_input_as_handled()
			KEY_2:
				_buy_item_by_index(1)
				get_viewport().set_input_as_handled()
			KEY_3:
				_buy_item_by_index(2)
				get_viewport().set_input_as_handled()
			KEY_R:
				if can_reroll():
					_on_reroll_pressed()
					get_viewport().set_input_as_handled()

	if event.is_action_pressed("ui_left") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_A or event.keycode == KEY_LEFT)):
		_navigate_focus(SIDE_LEFT)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_D or event.keycode == KEY_RIGHT)):
		_navigate_focus(SIDE_RIGHT)
		get_viewport().set_input_as_handled()


func _navigate_focus(side: Side) -> void:
	var focus_owner: Control = get_viewport().gui_get_focus_owner()
	var current_idx: int = buy_buttons.find(focus_owner as Button)

	if current_idx != -1:
		var n: int = buy_buttons.size()
		var step: int = -1 if side == SIDE_LEFT else 1
		for offset: int in range(1, n + 1):
			var target_idx: int = (current_idx + step * offset + n) % n
			var target_btn: Button = buy_buttons[target_idx]
			if is_instance_valid(target_btn) and not target_btn.disabled:
				target_btn.grab_focus()
				return
	else:
		_focus_next_available_buy_button()


func _buy_item_by_index(index: int) -> void:
	if index >= 0 and index < buy_buttons.size():
		var btn: Button = buy_buttons[index]
		if is_instance_valid(btn) and not btn.disabled:
			btn.emit_signal("pressed")


func _update_credits_display() -> void:
	if credits_label:
		credits_label.text = "Créditos: %d" % current_credits
	if reroll_btn:
		if rerolls_used_this_visit >= max_rerolls_per_satellite:
			reroll_btn.disabled = true
			reroll_btn.text = "Re-roll [AGOTADO (%d/%d)]" % [rerolls_used_this_visit, max_rerolls_per_satellite]
			reroll_btn.modulate = Color(0.6, 0.6, 0.6, 0.6)
		elif current_credits < reroll_cost:
			reroll_btn.disabled = true
			reroll_btn.text = "Re-roll (%d C) [R]" % reroll_cost
			reroll_btn.modulate = Color(0.6, 0.6, 0.6, 0.6)
		else:
			reroll_btn.disabled = false
			reroll_btn.text = "Re-roll (%d C) [R]" % reroll_cost
			reroll_btn.modulate = Color(1.0, 1.0, 1.0, 1.0)
	if close_btn:
		close_btn.text = "Cerrar y Continuar [ESC / ESPACIO]"


func _roll_shop_items() -> void:
	if not items_container:
		return

	for child: Node in items_container.get_children():
		child.queue_free()
	buy_buttons.clear()
	current_offered_items.clear()

	if available_items_pool.is_empty():
		_generate_default_shop_items()

	var selected_items: Array[Resource] = []
	var pool_copy: Array[Resource] = available_items_pool.duplicate()
	pool_copy.shuffle()

	# Slot 0: Arma garantizada si está disponible en el pool
	_ensure_player()
	var w_ctrl: WeaponController = player.get_node_or_null("WeaponController") as WeaponController if is_instance_valid(player) else null
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

	for i: int in range(selected_items.size()):
		SatelliteShopCardBuilderClass.create_item_card_ui(selected_items[i], i, self)

	_setup_focus_and_grab()


func handle_item_purchase(entry: Resource, cost: int, buy_btn: Button) -> void:
	if current_credits < cost:
		return

	if entry is WeaponData:
		_ensure_player()
		if is_instance_valid(player):
			var w_ctrl: WeaponController = player.get_node_or_null("WeaponController") as WeaponController
			if w_ctrl and w_ctrl.has_method("is_full") and w_ctrl.is_full() and not w_ctrl.get_weapon_instance((entry as WeaponData).weapon_id):
				_open_shop_weapon_swap(entry as WeaponData, cost, buy_btn)
				return

	current_credits -= cost
	_update_credits_display()
	buy_btn.disabled = true
	buy_btn.text = "¡Adquirido!"
	var btn_idx: int = buy_buttons.find(buy_btn)
	if btn_idx != -1 and not purchased_slots.has(btn_idx):
		purchased_slots.append(btn_idx)
	item_purchased.emit(entry, cost)

	call_deferred("_refresh_inventory_display")
	call_deferred("_refresh_stats_display")
	_clear_stat_highlights()
	_focus_next_available_buy_button()


func _setup_focus_and_grab() -> void:
	if buy_buttons.is_empty():
		return

	var n_items: int = buy_buttons.size()
	for i: int in range(n_items):
		var btn: Button = buy_buttons[i]
		var left_btn: Button = buy_buttons[(i - 1 + n_items) % n_items]
		var right_btn: Button = buy_buttons[(i + 1) % n_items]

		btn.focus_neighbor_left = left_btn.get_path()
		btn.focus_neighbor_right = right_btn.get_path()
		btn.focus_neighbor_bottom = reroll_btn.get_path() if i < 2 else close_btn.get_path()
		btn.focus_neighbor_top = close_btn.get_path()

	if reroll_btn and close_btn:
		reroll_btn.focus_neighbor_left = close_btn.get_path()
		reroll_btn.focus_neighbor_right = close_btn.get_path()
		reroll_btn.focus_neighbor_top = buy_buttons[0].get_path()
		reroll_btn.focus_neighbor_bottom = buy_buttons[0].get_path()

		close_btn.focus_neighbor_left = reroll_btn.get_path()
		close_btn.focus_neighbor_right = reroll_btn.get_path()
		close_btn.focus_neighbor_top = buy_buttons[mini(2, n_items - 1)].get_path()
		close_btn.focus_neighbor_bottom = buy_buttons[mini(2, n_items - 1)].get_path()

	_focus_next_available_buy_button()


func _focus_next_available_buy_button() -> void:
	for btn: Button in buy_buttons:
		if is_instance_valid(btn) and not btn.disabled:
			btn.grab_focus()
			return
	if close_btn and is_instance_valid(close_btn):
		close_btn.grab_focus()


func _on_reroll_pressed() -> void:
	if not can_reroll():
		return
	current_credits -= reroll_cost
	rerolls_used_this_visit += 1
	_ensure_player()
	if is_instance_valid(player):
		player.run_credits = current_credits
		if player.has_signal("credits_changed"):
			player.credits_changed.emit(player.run_credits)
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("update_credits"):
		hud.update_credits(current_credits)
	_update_credits_display()
	purchased_slots.clear()
	_roll_shop_items()


func _open_shop_weapon_swap(w_data: WeaponData, cost: int, buy_btn: Button) -> void:
	var swap_modal: Node = WeaponSwapModalClass.new()
	get_tree().root.add_child(swap_modal)
	swap_modal.prompt_swap(player, w_data,
		func(_idx: int, _new_w: WeaponData) -> void:
			if is_instance_valid(player):
				player.run_credits = maxi(0, player.run_credits - cost)
				current_credits = player.run_credits
				if player.has_signal("credits_changed"):
					player.credits_changed.emit(player.run_credits)
			else:
				current_credits = maxi(0, current_credits - cost)
			var hud: Node = get_tree().get_first_node_in_group("hud")
			if hud and hud.has_method("update_credits"):
				hud.update_credits(current_credits)
			_update_credits_display()
			if is_instance_valid(buy_btn):
				buy_btn.disabled = true
				buy_btn.text = "¡Adquirido!"
				var btn_idx: int = buy_buttons.find(buy_btn)
				if btn_idx != -1 and not purchased_slots.has(btn_idx):
					purchased_slots.append(btn_idx)
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

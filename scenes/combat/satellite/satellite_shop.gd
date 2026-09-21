class_name SatelliteShop
extends CanvasLayer

signal item_purchased(item: ItemData, cost: int)
signal shop_closed()

@export var available_items_pool: Array[ItemData] = []

var current_credits: int = 100
var reroll_cost: int = 15
var current_offered_items: Array[ItemData] = []
var buy_buttons: Array[Button] = []

@onready var panel: Panel = $ShopPanel
@onready var items_container: HBoxContainer = $ShopPanel/VBoxContainer/ItemsContainer
@onready var credits_label: Label = $ShopPanel/VBoxContainer/TopBar/CreditsLabel
@onready var reroll_btn: Button = $ShopPanel/VBoxContainer/BottomBar/RerollButton
@onready var close_btn: Button = $ShopPanel/VBoxContainer/BottomBar/CloseButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	close_btn.pressed.connect(close_shop)
	reroll_btn.pressed.connect(_on_reroll_pressed)
	if available_items_pool.is_empty():
		_generate_default_shop_items()

func _generate_default_shop_items() -> void:
	available_items_pool = ItemPoolManager.create_canonical_stat_items()

func open_shop(credits: int) -> void:
	current_credits = credits
	_update_credits_display()
	_roll_shop_items()
	get_tree().paused = true
	show()
	call_deferred("_setup_focus_and_grab")

func close_shop() -> void:
	hide()
	get_tree().paused = false
	shop_closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		match event.keycode:
			# Atajos directos de compra (1, 2, 3 y Numpad)
			KEY_1, KEY_KP_1:
				_buy_item_by_index(0)
				get_viewport().set_input_as_handled()
				return
			KEY_2, KEY_KP_2:
				_buy_item_by_index(1)
				get_viewport().set_input_as_handled()
				return
			KEY_3, KEY_KP_3:
				_buy_item_by_index(2)
				get_viewport().set_input_as_handled()
				return
			# Atajo de Re-roll (R)
			KEY_R:
				_on_reroll_pressed()
				get_viewport().set_input_as_handled()
				return
			# Salir de la tienda (Escape o Tab)
			KEY_ESCAPE, KEY_TAB:
				close_shop()
				get_viewport().set_input_as_handled()
				return
			# Navegación con WASD
			KEY_W:
				_navigate_focus(SIDE_TOP)
				get_viewport().set_input_as_handled()
				return
			KEY_S:
				_navigate_focus(SIDE_BOTTOM)
				get_viewport().set_input_as_handled()
				return
			KEY_A:
				_navigate_focus(SIDE_LEFT)
				get_viewport().set_input_as_handled()
				return
			KEY_D:
				_navigate_focus(SIDE_RIGHT)
				get_viewport().set_input_as_handled()
				return
			# Activación / Click con Barra Espaciadora
			KEY_SPACE:
				var focused := get_viewport().gui_get_focus_owner() as Button
				if focused and is_instance_valid(focused) and not focused.disabled:
					focused.pressed.emit()
				elif not focused and not buy_buttons.is_empty():
					_buy_item_by_index(0)
				get_viewport().set_input_as_handled()
				return

func _navigate_focus(side: Side) -> void:
	var focused := get_viewport().gui_get_focus_owner() as Control
	if not focused or not is_instance_valid(focused):
		if not buy_buttons.is_empty() and not buy_buttons[0].disabled:
			buy_buttons[0].grab_focus()
		else:
			close_btn.grab_focus()
		return

	var neighbor_path := focused.get_focus_neighbor(side)
	if neighbor_path:
		var neighbor := focused.get_node_or_null(neighbor_path) as Control
		if neighbor and is_instance_valid(neighbor) and neighbor is Button and not (neighbor as Button).disabled:
			neighbor.grab_focus()
			return

	var next := focused.find_valid_focus_neighbor(side)
	if next and is_instance_valid(next):
		next.grab_focus()

func _buy_item_by_index(index: int) -> void:
	if index >= 0 and index < buy_buttons.size():
		var btn := buy_buttons[index]
		if is_instance_valid(btn) and not btn.disabled:
			btn.pressed.emit()

func _update_credits_display() -> void:
	credits_label.text = "Créditos: %d" % current_credits
	reroll_btn.text = "Re-roll (%d C) [R]" % reroll_cost
	close_btn.text = "Cerrar y Continuar [ESC / ESPACIO]"

func _roll_shop_items() -> void:
	for child in items_container.get_children():
		child.queue_free()

	current_offered_items.clear()
	buy_buttons.clear()

	var pool_copy := available_items_pool.duplicate()
	pool_copy.shuffle()

	var count := mini(3, pool_copy.size())
	for i in range(count):
		var item: ItemData = pool_copy[i]
		current_offered_items.append(item)
		_create_item_card_ui(item, i)

	_setup_focus_and_grab()

func _create_item_card_ui(item: ItemData, index: int) -> void:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(220, 260)

	var vbox := VBoxContainer.new()
	vbox.set("theme_override_constants/separation", 8)

	# Indicador de atajo de teclado
	var hotkey_lbl := Label.new()
	hotkey_lbl.text = "[ TECLA %d ]" % (index + 1)
	hotkey_lbl.modulate = Color(1.0, 0.9, 0.35, 0.95)
	hotkey_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hotkey_lbl.add_theme_font_size_override("font_size", 12)

	var name_lbl := Label.new()
	name_lbl.text = item.item_name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD

	var desc_lbl := Label.new()
	desc_lbl.text = item.description
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var cost: int = item.cost if "cost" in item and item.cost > 0 else item.get_meta("cost", 35)
	var buy_btn := Button.new()
	buy_btn.text = "Comprar (%d C) [%d]" % [cost, index + 1]

	buy_btn.pressed.connect(func():
		if current_credits >= cost:
			current_credits -= cost
			_update_credits_display()
			buy_btn.disabled = true
			buy_btn.text = "¡Adquirido!"
			item_purchased.emit(item, cost)
			# Si aún hay créditos y otros botones, enfocar el siguiente disponible
			_focus_next_available_buy_button()
	)

	vbox.add_child(hotkey_lbl)
	vbox.add_child(name_lbl)
	vbox.add_child(desc_lbl)
	vbox.add_child(buy_btn)
	card.add_child(vbox)
	items_container.add_child(card)

	buy_buttons.append(buy_btn)

func _setup_focus_and_grab() -> void:
	if buy_buttons.is_empty():
		return

	# Configurar vecinos de foco explícitos para navegación WASD y mando
	var n_items := buy_buttons.size()
	for i in range(n_items):
		var btn := buy_buttons[i]
		var left_btn := buy_buttons[(i - 1 + n_items) % n_items]
		var right_btn := buy_buttons[(i + 1) % n_items]

		btn.focus_neighbor_left = left_btn.get_path()
		btn.focus_neighbor_right = right_btn.get_path()
		btn.focus_neighbor_bottom = reroll_btn.get_path() if i < 2 else close_btn.get_path()
		btn.focus_neighbor_top = close_btn.get_path()

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
	for btn in buy_buttons:
		if is_instance_valid(btn) and not btn.disabled:
			btn.grab_focus()
			return
	close_btn.grab_focus()

func _on_reroll_pressed() -> void:
	if current_credits >= reroll_cost:
		current_credits -= reroll_cost
		reroll_cost += 10
		_update_credits_display()
		_roll_shop_items()

class_name SatelliteShop
extends CanvasLayer

const UIFocusHelper := preload("res://core/utils/ui_focus_helper.gd")

signal item_purchased(item: Resource, cost: int)
signal shop_closed()

@export var available_items_pool: Array[Resource] = []

var current_credits: int = 100
var reroll_cost: int = 15
var current_offered_items: Array[Resource] = []
var buy_buttons: Array[Button] = []

@onready var panel: Panel = $ShopPanel
@onready var items_container: HBoxContainer = $ShopPanel/VBoxContainer/ItemsContainer
@onready var credits_label: Label = $ShopPanel/VBoxContainer/TopBar/CreditsLabel
@onready var reroll_btn: Button = $ShopPanel/VBoxContainer/BottomBar/RerollButton
@onready var close_btn: Button = $ShopPanel/VBoxContainer/BottomBar/CloseButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	UIFocusHelper.apply_cyber_focus(close_btn)
	UIFocusHelper.apply_cyber_focus(reroll_btn)
	close_btn.pressed.connect(close_shop)
	reroll_btn.pressed.connect(_on_reroll_pressed)
	if available_items_pool.is_empty():
		_generate_default_shop_items()

func _generate_default_shop_items() -> void:
	var items: Array[ItemData] = ItemPoolManager.create_canonical_stat_items()
	for it in items:
		available_items_pool.append(it)

	# Añadir las 4 armas exclusivas de la tienda
	var shop_weapon_paths: Array[String] = [
		"res://data/weapons/shop/nova_flak.tres",
		"res://data/weapons/shop/dimensional_blade.tres",
		"res://data/weapons/shop/solar_beam.tres",
		"res://data/weapons/shop/cluster_submunition.tres"
	]
	for p in shop_weapon_paths:
		if ResourceLoader.exists(p):
			var w = load(p)
			if w:
				available_items_pool.append(w)

func open_shop(credits: int) -> void:
	current_credits = credits
	_update_credits_display()
	_roll_shop_items()
	get_tree().paused = true
	show()
	call_deferred("_setup_focus_and_grab")

func restore_focus() -> void:
	_setup_focus_and_grab()

func close_shop() -> void:
	hide()
	var parent_game = get_parent()
	if parent_game and parent_game.has_method("is_any_combat_modal_active") and parent_game.is_any_combat_modal_active():
		get_tree().paused = true
		if parent_game.has_method("restore_combat_modal_focus"):
			parent_game.restore_combat_modal_focus()
	else:
		get_tree().paused = false
	shop_closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	# Si la pausa está activa por encima, ignorar cualquier entrada
	var parent_game = get_parent()
	if parent_game and parent_game.has_method("is_pause_menu_active") and parent_game.is_pause_menu_active():
		return
	var root_pm = get_tree().root.find_child("PauseMenu", true, false)
	if root_pm and root_pm.visible:
		return

	if event.is_action_pressed("ui_cancel"):
		close_shop()
		get_viewport().set_input_as_handled()
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
		var entry: Resource = pool_copy[i]
		current_offered_items.append(entry)
		_create_item_card_ui(entry, i)

	_setup_focus_and_grab()

func _create_item_card_ui(entry: Resource, index: int) -> void:
	var entry_rarity: Enums.Rarity = entry.get("rarity") if entry.get("rarity") != null else Enums.Rarity.COMMON
	var rarity_color := _get_rarity_color(entry_rarity)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(230, 310)

	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.06, 0.08, 0.13, 0.92)
	card_style.set_border_width_all(2)
	card_style.border_color = rarity_color * Color(1.0, 1.0, 1.0, 0.6)
	card_style.set_corner_radius_all(8)
	card_style.set_content_margin_all(10.0)
	card.add_theme_stylebox_override("panel", card_style)

	var vbox := VBoxContainer.new()
	vbox.set("theme_override_constants/separation", 8)

	# Indicador de atajo de teclado
	var hotkey_lbl := Label.new()
	hotkey_lbl.text = "[ TECLA %d ]" % (index + 1)
	hotkey_lbl.modulate = Color(1.0, 0.9, 0.35, 0.95)
	hotkey_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hotkey_lbl.add_theme_font_size_override("font_size", 12)

	var display_title: String = ""
	if entry is WeaponData:
		display_title = "[ARMA] " + (entry as WeaponData).weapon_name
	elif "item_name" in entry:
		display_title = entry.item_name
	else:
		display_title = "Mejora Espacial"

	var name_lbl := Label.new()
	name_lbl.text = display_title
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	name_lbl.add_theme_color_override("font_color", rarity_color)

	# Marco contenedor del icono de 64x64 px centrado
	var icon_panel := PanelContainer.new()
	icon_panel.custom_minimum_size = Vector2(64, 64)
	icon_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var icon_style := StyleBoxFlat.new()
	icon_style.bg_color = Color(0.03, 0.04, 0.07, 0.95)
	icon_style.set_border_width_all(2)
	icon_style.border_color = rarity_color
	icon_style.set_corner_radius_all(6)
	icon_panel.add_theme_stylebox_override("panel", icon_style)

	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(50, 50)
	icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if entry.get("icon"):
		icon_rect.texture = entry.get("icon")
		icon_rect.modulate = rarity_color
	icon_panel.add_child(icon_rect)

	var desc_lbl := Label.new()
	desc_lbl.text = entry.get("description") if entry.get("description") != null else ""
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var cost: int = entry.get("cost") if entry.get("cost") != null and entry.get("cost") > 0 else 50
	var buy_btn := Button.new()
	buy_btn.text = "Comprar (%d C) [%d]" % [cost, index + 1]
	UIFocusHelper.apply_cyber_focus(buy_btn)

	buy_btn.pressed.connect(func():
		if current_credits >= cost:
			current_credits -= cost
			_update_credits_display()
			buy_btn.disabled = true
			buy_btn.text = "¡Adquirido!"
			item_purchased.emit(entry, cost)
			# Si aún hay créditos y otros botones, enfocar el siguiente disponible
			_focus_next_available_buy_button()
	)

	vbox.add_child(hotkey_lbl)
	vbox.add_child(name_lbl)
	vbox.add_child(icon_panel)
	vbox.add_child(desc_lbl)
	vbox.add_child(buy_btn)
	card.add_child(vbox)
	items_container.add_child(card)

	buy_buttons.append(buy_btn)

func _get_rarity_color(rarity: Enums.Rarity) -> Color:
	match rarity:
		Enums.Rarity.COMMON:
			return Color(0.5, 0.8, 1.0, 0.95)
		Enums.Rarity.UNCOMMON:
			return Color(0.2, 0.95, 0.4, 0.95)
		Enums.Rarity.RARE:
			return Color(1.0, 0.8, 0.15, 1.0)
		Enums.Rarity.LEGENDARY:
			return Color(0.9, 0.3, 1.0, 1.0)
		_:
			return Color.WHITE

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

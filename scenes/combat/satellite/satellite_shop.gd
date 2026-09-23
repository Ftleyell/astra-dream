class_name SatelliteShop
extends CanvasLayer

const UIFocusHelper := preload("res://core/utils/ui_focus_helper.gd")

signal item_purchased(item: Resource, cost: int)
signal shop_closed()

@export var available_items_pool: Array[Resource] = []
@export var player: Player

var current_credits: int = 100
var reroll_cost: int = 15
var current_offered_items: Array[Resource] = []
var buy_buttons: Array[Button] = []

@onready var panel: Panel = $ShopPanel
@onready var items_container: HBoxContainer = find_child("ItemsContainer", true, false) as HBoxContainer
@onready var credits_label: Label = find_child("CreditsLabel", true, false) as Label
@onready var reroll_btn: Button = find_child("RerollButton", true, false) as Button
@onready var close_btn: Button = find_child("CloseButton", true, false) as Button
@onready var inventory_side_panel: PanelContainer = find_child("InventorySidePanel", true, false) as PanelContainer
@onready var inventory_summary_label: Label = find_child("InventorySummary", true, false) as Label
@onready var weapons_list: VBoxContainer = find_child("WeaponsList", true, false) as VBoxContainer
@onready var items_list: VBoxContainer = find_child("ItemsList", true, false) as VBoxContainer

const STAT_ICON_MAP = {
	&"base_damage": "res://assets/icons/items/icon_sword.svg",
	&"attack_speed": "res://assets/icons/items/icon_gauntlet.svg",
	&"crit_chance": "res://assets/icons/items/icon_glasses.svg",
	&"crit_damage": "res://assets/icons/items/icon_lens.svg",
	&"max_health": "res://assets/icons/items/icon_heart.svg",
	&"move_speed": "res://assets/icons/items/icon_boots.svg",
	&"luck": "res://assets/icons/items/icon_clover.svg",
	&"projectile_count": "res://assets/icons/items/icon_quiver.svg",
	&"armor": "res://assets/icons/items/icon_shield.svg",
	&"health_regen": "res://assets/icons/items/icon_apple.svg",
	&"pickup_radius": "res://assets/icons/items/icon_magnet.svg",
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()

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
		UIFocusHelper.apply_cyber_focus(close_btn)
		close_btn.pressed.connect(close_shop)
	if reroll_btn:
		UIFocusHelper.apply_cyber_focus(reroll_btn)
		reroll_btn.pressed.connect(_on_reroll_pressed)

	if available_items_pool.is_empty():
		_generate_default_shop_items()

func _ensure_player() -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Player
	if not is_instance_valid(player) and get_parent():
		player = get_parent().get_node_or_null("Player") as Player

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
	_ensure_player()
	_update_credits_display()
	_roll_shop_items()
	_refresh_inventory_display()
	get_tree().paused = true
	show()
	call_deferred("_setup_focus_and_grab")

func restore_focus() -> void:
	_setup_focus_and_grab()

func close_shop() -> void:
	_ensure_player()
	if is_instance_valid(player) and player.has_method("suppress_bomb_input"):
		player.suppress_bomb_input(0.4)
	hide()
	var parent_game = get_parent()
	if parent_game and parent_game.has_method("notify_menu_closed"):
		parent_game.notify_menu_closed(0.4)
	if parent_game and parent_game.has_method("is_any_combat_modal_active") and parent_game.is_any_combat_modal_active():
		get_tree().paused = true
		if parent_game.has_method("restore_combat_modal_focus"):
			parent_game.restore_combat_modal_focus()
	else:
		get_tree().paused = false
	shop_closed.emit()

func _refresh_inventory_display() -> void:
	_ensure_player()
	if not is_instance_valid(player):
		return

	# 1. Armas Equipadas
	var weapons_count: int = 0
	if weapons_list:
		for child in weapons_list.get_children():
			child.queue_free()

		var w_ctrl := player.get_node_or_null("WeaponController") as WeaponController
		if w_ctrl and not w_ctrl.equipped_weapons.is_empty():
			weapons_count = w_ctrl.equipped_weapons.size()
			for w_inst in w_ctrl.equipped_weapons:
				var w_data: WeaponData = w_inst.weapon_data if ("weapon_data" in w_inst) else (w_inst.get("data") as WeaponData)
				if not w_data:
					continue
				var w_lvl: int = w_inst.level if ("level" in w_inst) else 1
				var w_card := _create_inventory_weapon_card(w_data, w_lvl)
				weapons_list.add_child(w_card)
		else:
			var default_lbl := Label.new()
			default_lbl.text = "• Sistema de Armas Básico"
			default_lbl.add_theme_font_size_override("font_size", 11)
			default_lbl.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75))
			weapons_list.add_child(default_lbl)
			weapons_count = 1

	# 2. Ítems Pasivos
	var items_count: int = 0
	if items_list:
		for child in items_list.get_children():
			child.queue_free()

		var all_items: Array[Dictionary] = []
		if player.inventory:
			all_items = player.inventory.get_all_items()

		items_count = all_items.size()
		if all_items.is_empty():
			var empty_lbl := Label.new()
			empty_lbl.text = "Sin ítems adquiridos en esta misión."
			empty_lbl.add_theme_font_size_override("font_size", 11)
			empty_lbl.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65))
			empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
			items_list.add_child(empty_lbl)
		else:
			for entry in all_items:
				var it_data: ItemData = entry.get("data")
				var it_count: int = entry.get("count", 1)
				if not it_data:
					continue
				var it_card := _create_inventory_item_card(it_data, it_count)
				items_list.add_child(it_card)

	# 3. Resumen
	if inventory_summary_label:
		inventory_summary_label.text = "Armas: %d/6  |  Ítems Pasivos: %d" % [weapons_count, items_count]

func _create_inventory_weapon_card(w_data: WeaponData, w_level: int = 1) -> PanelContainer:
	var panel_item := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.08, 0.12, 0.9)
	sb.border_color = Color(1.0, 0.8, 0.2, 0.7)
	sb.set_border_width_all(1)
	sb.border_width_left = 3
	sb.set_corner_radius_all(4)
	panel_item.add_theme_stylebox_override("panel", sb)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	panel_item.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	margin.add_child(hbox)

	var tex_rect := TextureRect.new()
	tex_rect.custom_minimum_size = Vector2(24, 24)
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var icon_tex: Texture2D = w_data.icon
	if not icon_tex and ResourceLoader.exists("res://assets/icons/items/icon_sword.svg"):
		icon_tex = load("res://assets/icons/items/icon_sword.svg") as Texture2D
	tex_rect.texture = icon_tex
	tex_rect.modulate = Color(1.0, 0.85, 0.3)
	hbox.add_child(tex_rect)

	var lbl := Label.new()
	lbl.text = "%s [Nv. %d]" % [w_data.weapon_name, w_level] if w_level > 1 else w_data.weapon_name
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.7))
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(lbl)

	var dmg_lbl := Label.new()
	dmg_lbl.text = "%.0f Dmg" % w_data.base_damage
	dmg_lbl.add_theme_font_size_override("font_size", 10)
	dmg_lbl.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9, 0.8))
	hbox.add_child(dmg_lbl)

	return panel_item

func _create_inventory_item_card(it_data: ItemData, count: int) -> PanelContainer:
	var rarity_col := _get_rarity_color(it_data.rarity)
	var panel_item := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.07, 0.11, 0.85)
	sb.border_color = rarity_col * Color(1.0, 1.0, 1.0, 0.6)
	sb.set_border_width_all(1)
	sb.border_width_left = 3
	sb.set_corner_radius_all(4)
	panel_item.add_theme_stylebox_override("panel", sb)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	panel_item.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	margin.add_child(hbox)

	var tex_rect := TextureRect.new()
	tex_rect.custom_minimum_size = Vector2(24, 24)
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var icon_tex: Texture2D = it_data.icon
	if not icon_tex and STAT_ICON_MAP.has(it_data.stat_name) and ResourceLoader.exists(STAT_ICON_MAP[it_data.stat_name]):
		icon_tex = load(STAT_ICON_MAP[it_data.stat_name]) as Texture2D
	if not icon_tex and ResourceLoader.exists("res://assets/icons/items/icon_heart.svg"):
		icon_tex = load("res://assets/icons/items/icon_heart.svg") as Texture2D
	tex_rect.texture = icon_tex
	tex_rect.modulate = rarity_col
	hbox.add_child(tex_rect)

	var lbl := Label.new()
	lbl.text = it_data.item_name
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(lbl)

	var stack_lbl := Label.new()
	stack_lbl.text = "x%d" % count
	stack_lbl.add_theme_font_size_override("font_size", 11)
	stack_lbl.add_theme_color_override("font_color", Color("#00FF9D"))
	hbox.add_child(stack_lbl)

	return panel_item

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
				_ensure_player()
				if is_instance_valid(player) and player.has_method("suppress_bomb_input"):
					player.suppress_bomb_input(0.4)
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
		elif close_btn and is_instance_valid(close_btn):
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
	if credits_label:
		credits_label.text = "Créditos: %d" % current_credits
	if reroll_btn:
		reroll_btn.text = "Re-roll (%d C) [R]" % reroll_cost
	if close_btn:
		close_btn.text = "Cerrar y Continuar [ESC / ESPACIO]"

func _roll_shop_items() -> void:
	if not items_container:
		return

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
			# Actualizar inventario en tiempo real
			call_deferred("_refresh_inventory_display")
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
	if close_btn and is_instance_valid(close_btn):
		close_btn.grab_focus()

func _on_reroll_pressed() -> void:
	if current_credits >= reroll_cost:
		current_credits -= reroll_cost
		reroll_cost += 10
		_update_credits_display()
		_roll_shop_items()

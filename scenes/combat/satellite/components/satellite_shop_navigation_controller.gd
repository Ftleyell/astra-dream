class_name SatelliteShopNavigationController
extends RefCounted

## SatelliteShopNavigationController.gd
## Manejador desacoplado de inputs, atajos de teclado y navegación direccional para SatelliteShop.

static func handle_unhandled_input(event: InputEvent, shop: SatelliteShop) -> void:
	if not shop.visible:
		return

	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		shop.close_shop()
		shop.get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_select") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE):
		var focus_owner: Control = shop.get_viewport().gui_get_focus_owner()
		if focus_owner is Button and not focus_owner.disabled:
			focus_owner.emit_signal("pressed")
			shop.get_viewport().set_input_as_handled()
			return
		shop.restore_focus()
		var new_focus: Control = shop.get_viewport().gui_get_focus_owner()
		if new_focus is Button and not new_focus.disabled:
			new_focus.emit_signal("pressed")
		else:
			shop.close_shop()
		shop.get_viewport().set_input_as_handled()
		return

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				buy_item_by_index(0, shop)
				shop.get_viewport().set_input_as_handled()
			KEY_2:
				buy_item_by_index(1, shop)
				shop.get_viewport().set_input_as_handled()
			KEY_3:
				buy_item_by_index(2, shop)
				shop.get_viewport().set_input_as_handled()
			KEY_R:
				if shop.can_reroll():
					shop._on_reroll_pressed()
					shop.get_viewport().set_input_as_handled()

	if event.is_action_pressed("ui_up") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_W or event.keycode == KEY_UP)):
		navigate_vertical(-1, shop)
		shop.get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_S or event.keycode == KEY_DOWN)):
		navigate_vertical(1, shop)
		shop.get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_left") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_A or event.keycode == KEY_LEFT)):
		navigate_horizontal(-1, shop)
		shop.get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_D or event.keycode == KEY_RIGHT)):
		navigate_horizontal(1, shop)
		shop.get_viewport().set_input_as_handled()


static func navigate_vertical(dir: int, shop: SatelliteShop) -> void:
	var focus_owner: Control = shop.get_viewport().gui_get_focus_owner()
	var current_idx: int = shop.buy_buttons.find(focus_owner as Button)

	if current_idx != -1:
		var target_idx: int = current_idx + dir
		if target_idx < 0:
			if shop.close_btn and is_instance_valid(shop.close_btn):
				shop.close_btn.grab_focus()
		elif target_idx >= shop.buy_buttons.size():
			if shop.reroll_btn and is_instance_valid(shop.reroll_btn) and not shop.reroll_btn.disabled:
				shop.reroll_btn.grab_focus()
			elif shop.close_btn and is_instance_valid(shop.close_btn):
				shop.close_btn.grab_focus()
		else:
			var target_btn: Button = shop.buy_buttons[target_idx]
			if is_instance_valid(target_btn):
				target_btn.grab_focus()
	elif focus_owner == shop.reroll_btn or focus_owner == shop.close_btn:
		if dir < 0:
			for i in range(shop.buy_buttons.size() - 1, -1, -1):
				var b: Button = shop.buy_buttons[i]
				if is_instance_valid(b) and not b.disabled:
					b.grab_focus()
					return
			if not shop.buy_buttons.is_empty():
				shop.buy_buttons[-1].grab_focus()
	else:
		shop.restore_focus()


static func navigate_horizontal(dir: int, shop: SatelliteShop) -> void:
	var focus_owner: Control = shop.get_viewport().gui_get_focus_owner()
	if focus_owner == shop.reroll_btn:
		if shop.close_btn and is_instance_valid(shop.close_btn):
			shop.close_btn.grab_focus()
	elif focus_owner == shop.close_btn:
		if shop.reroll_btn and is_instance_valid(shop.reroll_btn) and not shop.reroll_btn.disabled:
			shop.reroll_btn.grab_focus()
	else:
		navigate_vertical(dir, shop)


static func buy_item_by_index(index: int, shop: SatelliteShop) -> void:
	if index >= 0 and index < shop.buy_buttons.size():
		var btn: Button = shop.buy_buttons[index]
		if is_instance_valid(btn) and not btn.disabled:
			btn.emit_signal("pressed")

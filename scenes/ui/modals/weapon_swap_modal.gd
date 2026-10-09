class_name WeaponSwapModal
extends BaseModal

## WeaponSwapModal.gd
## Modal in-run para reemplazar armas cuando el inventario de ranuras está lleno.
## Delega la construcción y estilos de las tarjetas a WeaponSwapCardBuilder.

const WeaponSwapCardBuilderClass = preload("res://scenes/ui/modals/weapon_swap_card_builder.gd")

signal weapon_swapped(slot_index: int, new_weapon: WeaponData)
signal weapon_discarded(weapon: WeaponData)
signal modal_closed()

var current_player: Player = null
var incoming_weapon: WeaponData = null
var on_replaced_callback: Callable = Callable()
var on_discarded_callback: Callable = Callable()

var _panel: PanelContainer
var _title_label: Label
var _subtitle_label: Label
var _weapons_container: HBoxContainer
var _incoming_box: PanelContainer
var _discard_button: Button


func _ready() -> void:
	modal_token = &"weapon_swap"
	layer = 130
	add_to_group("weapon_swap_modal")
	_build_ui()
	super._ready()


func _input(event: InputEvent) -> void:
	if not visible:
		return

	var root_pm = get_tree().root.find_child("PauseMenu", true, false) if get_tree() and get_tree().root else null
	if root_pm and root_pm.visible:
		return

	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		var key_event := event as InputEventKey
		match key_event.keycode:
			KEY_1:
				# Tecla 1 ignorada silenciosamente (arma insignia bloqueada)
				get_viewport().set_input_as_handled()
				return
			KEY_2:
				_handle_slot_hotkey(1)
				get_viewport().set_input_as_handled()
				return
			KEY_3:
				_handle_slot_hotkey(2)
				get_viewport().set_input_as_handled()
				return
			KEY_4:
				_handle_slot_hotkey(3)
				get_viewport().set_input_as_handled()
				return
			KEY_ESCAPE:
				_on_discard_pressed()
				get_viewport().set_input_as_handled()
				return

	var is_left: bool = event.is_action_pressed("ui_left") or event.is_action_pressed("move_left")
	var is_right: bool = event.is_action_pressed("ui_right") or event.is_action_pressed("move_right")
	var is_down: bool = event.is_action_pressed("ui_down") or event.is_action_pressed("move_down")
	var is_up: bool = event.is_action_pressed("ui_up") or event.is_action_pressed("move_up")

	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		var key_event := event as InputEventKey
		var k: Key = key_event.keycode
		var pk: Key = key_event.physical_keycode
		if k == KEY_A or pk == KEY_A or k == KEY_LEFT or pk == KEY_LEFT:
			is_left = true
		elif k == KEY_D or pk == KEY_D or k == KEY_RIGHT or pk == KEY_RIGHT:
			is_right = true
		elif k == KEY_S or pk == KEY_S or k == KEY_DOWN or pk == KEY_DOWN:
			is_down = true
		elif k == KEY_W or pk == KEY_W or k == KEY_UP or pk == KEY_UP:
			is_up = true

	if is_left:
		_navigate_horizontal(-1)
		get_viewport().set_input_as_handled()
	elif is_right:
		_navigate_horizontal(1)
		get_viewport().set_input_as_handled()
	elif is_down:
		if _discard_button and is_instance_valid(_discard_button):
			_discard_button.grab_focus()
		get_viewport().set_input_as_handled()
	elif is_up:
		_navigate_horizontal(0)
		get_viewport().set_input_as_handled()


func _navigate_horizontal(dir: int) -> void:
	var replaceable_buttons: Array[Button] = []
	for i in range(1, _weapons_container.get_child_count()):
		var card = _weapons_container.get_child(i)
		var btn: Button = card.find_child("ReplaceBtn", true, false) as Button
		if btn and is_instance_valid(btn) and not btn.disabled:
			replaceable_buttons.append(btn)

	if replaceable_buttons.is_empty():
		return

	var current_focus = get_viewport().gui_get_focus_owner()
	var cur_idx: int = replaceable_buttons.find(current_focus)

	if cur_idx == -1:
		replaceable_buttons[0].grab_focus()
	else:
		var next_idx: int = posmod(cur_idx + dir, replaceable_buttons.size())
		replaceable_buttons[next_idx].grab_focus()


func _handle_slot_hotkey(slot_idx: int) -> void:
	if slot_idx <= 0:
		return
	if not is_instance_valid(current_player):
		return
	var w_ctrl := current_player.get_node_or_null("WeaponController") as WeaponController
	if w_ctrl and slot_idx < w_ctrl.equipped_weapons.size():
		_on_replace_slot_pressed(slot_idx)


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.05, 0.88)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(880, 560)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.06, 0.12, 0.98)
	sb.border_color = Color(0.2, 0.8, 1.0, 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 20
	sb.content_margin_bottom = 20
	_panel.add_theme_stylebox_override("panel", sb)
	center.add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	_panel.add_child(vbox)

	_title_label = Label.new()
	_title_label.text = "⚠️ CAPACIDAD DE ARSENAL AL MÁXIMO (4/4)"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 18)
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	vbox.add_child(_title_label)

	_subtitle_label = Label.new()
	_subtitle_label.text = "Selecciona qué arma sustituir para heredar su nivel más alto y reciclarla en créditos, o descarta la nueva adquisición."
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_subtitle_label.add_theme_font_size_override("font_size", 12)
	_subtitle_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	vbox.add_child(_subtitle_label)

	# Caja de arma entrante
	_incoming_box = PanelContainer.new()
	var in_sb := StyleBoxFlat.new()
	in_sb.bg_color = Color(0.05, 0.14, 0.18, 0.95)
	in_sb.border_color = Color(0.0, 0.95, 0.55, 0.9)
	in_sb.set_border_width_all(2)
	in_sb.set_corner_radius_all(8)
	in_sb.content_margin_left = 14
	in_sb.content_margin_right = 14
	in_sb.content_margin_top = 10
	in_sb.content_margin_bottom = 10
	_incoming_box.add_theme_stylebox_override("panel", in_sb)
	vbox.add_child(_incoming_box)

	var list_lbl := Label.new()
	list_lbl.text = "SELECCIONA EL ARMA A SUSTITUIR [Teclas 2, 3 o 4]:"
	list_lbl.add_theme_font_size_override("font_size", 12)
	list_lbl.add_theme_color_override("font_color", Color(0.3, 0.85, 1.0))
	vbox.add_child(list_lbl)

	_weapons_container = HBoxContainer.new()
	_weapons_container.add_theme_constant_override("separation", 12)
	_weapons_container.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(_weapons_container)

	_discard_button = Button.new()
	_discard_button.text = "✖ Descartar Nueva Arma [ESC]"
	_discard_button.custom_minimum_size = Vector2(0, 38)
	UIFocusHelper.apply_cyber_focus(_discard_button)
	_discard_button.pressed.connect(_on_discard_pressed)
	vbox.add_child(_discard_button)


func prompt_swap(p_player: Player, p_incoming: WeaponData, on_replaced: Callable = Callable(), on_discarded: Callable = Callable()) -> void:
	current_player = p_player
	incoming_weapon = p_incoming
	on_replaced_callback = on_replaced
	on_discarded_callback = on_discarded

	_refresh_display()
	open_modal()
	call_deferred("_grab_default_focus")


func _grab_default_focus() -> void:
	# Enfocar la ranura 2 (la primera sustituible) por defecto
	if _weapons_container.get_child_count() > 1:
		var second_card := _weapons_container.get_child(1)
		var btn: Button = second_card.find_child("ReplaceBtn", true, false) as Button
		if btn and is_instance_valid(btn):
			btn.grab_focus()
			return
	if _discard_button and is_instance_valid(_discard_button):
		_discard_button.grab_focus()


func _refresh_display() -> void:
	for child in _incoming_box.get_children():
		_incoming_box.remove_child(child)
		child.queue_free()
	for child in _weapons_container.get_children():
		_weapons_container.remove_child(child)
		child.queue_free()

	if incoming_weapon:
		var incoming_card := WeaponSwapCardBuilderClass.build_incoming_card(incoming_weapon)
		_incoming_box.add_child(incoming_card)

	if not is_instance_valid(current_player):
		return

	var w_ctrl := current_player.get_node_or_null("WeaponController") as WeaponController
	if not w_ctrl:
		return

	for i in range(w_ctrl.equipped_weapons.size()):
		var inst: WeaponInstanceData = w_ctrl.equipped_weapons[i]
		var card := WeaponSwapCardBuilderClass.build_slot_card(
			i,
			inst,
			incoming_weapon,
			Callable(self, "_on_replace_slot_pressed")
		)
		_weapons_container.add_child(card)

	_setup_focus_neighbors()


func _setup_focus_neighbors() -> void:
	var replaceable_buttons: Array[Button] = []
	for i in range(1, _weapons_container.get_child_count()):
		var card = _weapons_container.get_child(i)
		var btn: Button = card.find_child("ReplaceBtn", true, false) as Button
		if btn and is_instance_valid(btn) and not btn.disabled:
			replaceable_buttons.append(btn)

	var count: int = replaceable_buttons.size()
	for i in range(count):
		var cur_btn: Button = replaceable_buttons[i]
		var prev_btn: Button = replaceable_buttons[posmod(i - 1, count)]
		var next_btn: Button = replaceable_buttons[posmod(i + 1, count)]
		cur_btn.focus_neighbor_left = prev_btn.get_path()
		cur_btn.focus_neighbor_right = next_btn.get_path()
		if _discard_button and is_instance_valid(_discard_button):
			cur_btn.focus_neighbor_bottom = _discard_button.get_path()

	if _discard_button and is_instance_valid(_discard_button) and not replaceable_buttons.is_empty():
		_discard_button.focus_neighbor_top = replaceable_buttons[0].get_path()


func _on_replace_slot_pressed(slot_idx: int) -> void:
	if slot_idx <= 0:
		return
	if is_instance_valid(current_player) and incoming_weapon:
		var w_ctrl := current_player.get_node_or_null("WeaponController") as WeaponController
		if w_ctrl:
			w_ctrl.replace_weapon(slot_idx, incoming_weapon, true)
		weapon_swapped.emit(slot_idx, incoming_weapon)
		if on_replaced_callback.is_valid():
			on_replaced_callback.call(slot_idx, incoming_weapon)
	_close()


func _on_discard_pressed() -> void:
	if incoming_weapon:
		weapon_discarded.emit(incoming_weapon)
		if on_discarded_callback.is_valid():
			on_discarded_callback.call(incoming_weapon)
	_close()


func _close() -> void:
	close_modal()
	modal_closed.emit()

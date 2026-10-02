class_name WeaponSwapModal
extends CanvasLayer

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
	layer = 130
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("weapon_swap_modal")
	_build_ui()
	hide()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		var key_event := event as InputEventKey
		match key_event.keycode:
			KEY_1:
				_handle_slot_hotkey(0)
				get_viewport().set_input_as_handled()
			KEY_2:
				_handle_slot_hotkey(1)
				get_viewport().set_input_as_handled()
			KEY_3:
				_handle_slot_hotkey(2)
				get_viewport().set_input_as_handled()
			KEY_4:
				_handle_slot_hotkey(3)
				get_viewport().set_input_as_handled()
			KEY_ESCAPE:
				_on_discard_pressed()
				get_viewport().set_input_as_handled()

func _handle_slot_hotkey(slot_idx: int) -> void:
	if not is_instance_valid(current_player):
		return
	var w_ctrl := current_player.get_node_or_null("WeaponController") as WeaponController
	if w_ctrl and slot_idx >= 0 and slot_idx < w_ctrl.equipped_weapons.size():
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
	_panel.custom_minimum_size = Vector2(780, 520)

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
	list_lbl.text = "SELECCIONA EL ARMA A SUSTITUIR [Teclas 1, 2, 3 o 4]:"
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
	get_tree().paused = true
	show()
	call_deferred("_grab_default_focus")

func _grab_default_focus() -> void:
	if _weapons_container.get_child_count() > 0:
		var first_card := _weapons_container.get_child(0)
		var btn: Button = first_card.find_child("ReplaceBtn", true, false) as Button
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
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 14)

		var icon_rect := TextureRect.new()
		icon_rect.custom_minimum_size = Vector2(44, 44)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if incoming_weapon.icon:
			icon_rect.texture = incoming_weapon.icon
		hbox.add_child(icon_rect)

		var info_vbox := VBoxContainer.new()
		info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var name_lbl := Label.new()
		name_lbl.text = "NUEVA ADQUISICIÓN: %s" % incoming_weapon.weapon_name
		name_lbl.add_theme_font_size_override("font_size", 14)
		name_lbl.add_theme_color_override("font_color", Color(0.2, 1.0, 0.6))
		info_vbox.add_child(name_lbl)

		var stat_lbl := Label.new()
		stat_lbl.text = "Daño Base: %.0f | Enfriamiento: %.2fs | %s" % [
			incoming_weapon.base_damage,
			incoming_weapon.base_cooldown,
			incoming_weapon.description
		]
		stat_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		stat_lbl.add_theme_font_size_override("font_size", 11)
		stat_lbl.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0))
		info_vbox.add_child(stat_lbl)

		hbox.add_child(info_vbox)
		_incoming_box.add_child(hbox)

	if not is_instance_valid(current_player):
		return

	var w_ctrl := current_player.get_node_or_null("WeaponController") as WeaponController
	if not w_ctrl:
		return

	for i in range(w_ctrl.equipped_weapons.size()):
		var inst: WeaponInstanceData = w_ctrl.equipped_weapons[i]
		var card := _create_slot_card(i, inst)
		_weapons_container.add_child(card)

func _create_slot_card(slot_idx: int, inst: WeaponInstanceData) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(170, 230)
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var w_rarity := inst.weapon_data.rarity if inst.weapon_data else Enums.Rarity.COMMON
	var border_col := _get_rarity_color(w_rarity)

	var csb := StyleBoxFlat.new()
	csb.bg_color = Color(0.04, 0.06, 0.11, 0.95)
	csb.border_color = border_col
	csb.set_border_width_all(2)
	csb.set_corner_radius_all(8)
	csb.content_margin_left = 10
	csb.content_margin_right = 10
	csb.content_margin_top = 10
	csb.content_margin_bottom = 10
	pc.add_theme_stylebox_override("panel", csb)

	var card_vbox := VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 6)
	pc.add_child(card_vbox)

	var slot_title := Label.new()
	slot_title.text = "[Tecla %d] RANURA #%d" % [slot_idx + 1, slot_idx + 1]
	slot_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot_title.add_theme_font_size_override("font_size", 12)
	slot_title.add_theme_color_override("font_color", Color(0.2, 0.9, 1.0))
	card_vbox.add_child(slot_title)

	var icon_center := CenterContainer.new()
	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(40, 40)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if inst.weapon_data and inst.weapon_data.icon:
		icon_rect.texture = inst.weapon_data.icon
		icon_rect.modulate = border_col
	icon_center.add_child(icon_rect)
	card_vbox.add_child(icon_center)

	var w_name := inst.weapon_data.weapon_name if inst.weapon_data else "Arma"
	var name_lbl := Label.new()
	name_lbl.text = w_name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.add_theme_color_override("font_color", Color.WHITE)
	card_vbox.add_child(name_lbl)

	var level_lbl := Label.new()
	level_lbl.text = "Nivel Actual: ★%d" % inst.level
	level_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_lbl.add_theme_font_size_override("font_size", 11)
	level_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	card_vbox.add_child(level_lbl)

	var inherit_lbl := Label.new()
	inherit_lbl.text = "➔ Heredará Nivel: ★%d" % inst.level
	inherit_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inherit_lbl.add_theme_font_size_override("font_size", 11)
	inherit_lbl.add_theme_color_override("font_color", Color(0.2, 1.0, 0.6))
	card_vbox.add_child(inherit_lbl)

	var recycle_credits: int = WeaponController.calculate_recycle_credits(inst.level)
	var recycle_lbl := Label.new()
	recycle_lbl.text = "Reciclaje: +%d 🪙" % recycle_credits
	recycle_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	recycle_lbl.add_theme_font_size_override("font_size", 11)
	recycle_lbl.add_theme_color_override("font_color", Color(1.0, 0.75, 0.15))
	card_vbox.add_child(recycle_lbl)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_vbox.add_child(spacer)

	var rep_btn := Button.new()
	rep_btn.name = "ReplaceBtn"
	rep_btn.text = "Sustituir [%d]" % [slot_idx + 1]
	rep_btn.custom_minimum_size = Vector2(0, 32)
	UIFocusHelper.apply_cyber_focus(rep_btn)
	rep_btn.pressed.connect(func(): _on_replace_slot_pressed(slot_idx))
	card_vbox.add_child(rep_btn)

	return pc

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
			return Color(0.6, 0.7, 0.8, 0.95)

func _on_replace_slot_pressed(slot_idx: int) -> void:
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
	hide()
	get_tree().paused = false
	modal_closed.emit()

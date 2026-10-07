class_name WeaponSwapModal
extends BaseModal

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
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 16)
		hbox.alignment = BoxContainer.ALIGNMENT_BEGIN

		var in_icon_panel := PanelContainer.new()
		in_icon_panel.custom_minimum_size = Vector2(88, 88)
		in_icon_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var in_icon_sb := StyleBoxFlat.new()
		in_icon_sb.bg_color = Color(0.02, 0.04, 0.08, 0.95)
		in_icon_sb.border_color = Color(0.2, 1.0, 0.6, 0.9)
		in_icon_sb.set_border_width_all(2)
		in_icon_sb.set_corner_radius_all(6)
		in_icon_panel.add_theme_stylebox_override("panel", in_icon_sb)

		var icon_rect := TextureRect.new()
		icon_rect.custom_minimum_size = Vector2(80, 80)
		icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if incoming_weapon.icon:
			icon_rect.texture = incoming_weapon.icon
		in_icon_panel.add_child(icon_rect)
		hbox.add_child(in_icon_panel)

		var info_vbox := VBoxContainer.new()
		info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		info_vbox.set("theme_override_constants/separation", 4)

		var name_lbl := Label.new()
		name_lbl.text = "★ NUEVA ADQUISICIÓN: %s" % incoming_weapon.weapon_name.to_upper()
		name_lbl.add_theme_font_size_override("font_size", 14)
		name_lbl.add_theme_color_override("font_color", Color(0.2, 1.0, 0.6))
		info_vbox.add_child(name_lbl)

		var stat_lbl := Label.new()
		stat_lbl.text = "⚡ Daño Base: %.0f   |   ⏱️ Enfriamiento: %.2fs" % [
			incoming_weapon.base_damage,
			incoming_weapon.base_cooldown
		]
		stat_lbl.add_theme_font_size_override("font_size", 12)
		stat_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
		info_vbox.add_child(stat_lbl)

		var desc_lbl := Label.new()
		desc_lbl.text = incoming_weapon.description
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		desc_lbl.add_theme_font_size_override("font_size", 11)
		desc_lbl.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0, 0.9))
		info_vbox.add_child(desc_lbl)

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

func _create_slot_card(slot_idx: int, inst: WeaponInstanceData) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(195, 290)
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
	card_vbox.add_theme_constant_override("separation", 5)
	pc.add_child(card_vbox)

	var is_base_weapon: bool = (slot_idx == 0)

	var slot_title := Label.new()
	slot_title.text = "🔒 RANURA #1 (FIJA)" if is_base_weapon else ("[Tecla %d] RANURA #%d" % [slot_idx + 1, slot_idx + 1])
	slot_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot_title.add_theme_font_size_override("font_size", 12)
	slot_title.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2) if is_base_weapon else Color(0.2, 0.9, 1.0))
	card_vbox.add_child(slot_title)

	# Marco de icono grande 80x80
	var icon_panel := PanelContainer.new()
	icon_panel.custom_minimum_size = Vector2(88, 88)
	icon_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var icon_sb := StyleBoxFlat.new()
	icon_sb.bg_color = Color(0.02, 0.04, 0.07, 0.95)
	icon_sb.border_color = border_col
	icon_sb.set_border_width_all(2)
	icon_sb.set_corner_radius_all(6)
	icon_panel.add_theme_stylebox_override("panel", icon_sb)

	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(80, 80)
	icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if inst.weapon_data and inst.weapon_data.icon:
		icon_rect.texture = inst.weapon_data.icon
	icon_panel.add_child(icon_rect)
	card_vbox.add_child(icon_panel)

	var w_name := inst.weapon_data.weapon_name if inst.weapon_data else "Arma"
	var name_lbl := Label.new()
	name_lbl.text = w_name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.add_theme_color_override("font_color", Color.WHITE)
	card_vbox.add_child(name_lbl)

	# Stats e información métrica comparativa
	var stats_p_vbox := VBoxContainer.new()
	stats_p_vbox.set("theme_override_constants/separation", 2)

	var cur_dmg: float = inst.get_effective_damage()
	var cur_cd: float = inst.get_effective_cooldown()

	var stat_dmg_lbl := Label.new()
	stat_dmg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stat_dmg_lbl.add_theme_font_size_override("font_size", 10)
	if incoming_weapon and not is_base_weapon:
		var in_dmg: float = incoming_weapon.base_damage
		if in_dmg > cur_dmg:
			stat_dmg_lbl.text = "⚡ Daño: %.0f (➔ %.0f ▲)" % [cur_dmg, in_dmg]
			stat_dmg_lbl.add_theme_color_override("font_color", Color("#00FF9D"))
		elif in_dmg < cur_dmg:
			stat_dmg_lbl.text = "⚡ Daño: %.0f (➔ %.0f ▼)" % [cur_dmg, in_dmg]
			stat_dmg_lbl.add_theme_color_override("font_color", Color("#FF6677"))
		else:
			stat_dmg_lbl.text = "⚡ Daño: %.0f (=)" % cur_dmg
			stat_dmg_lbl.add_theme_color_override("font_color", Color.WHITE)
	else:
		stat_dmg_lbl.text = "⚡ Daño Actual: %.0f" % cur_dmg
		stat_dmg_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	stats_p_vbox.add_child(stat_dmg_lbl)

	var stat_cd_lbl := Label.new()
	stat_cd_lbl.text = "⏱️ Enfriamiento: %.2fs" % cur_cd
	stat_cd_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stat_cd_lbl.add_theme_font_size_override("font_size", 10)
	stat_cd_lbl.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	stats_p_vbox.add_child(stat_cd_lbl)

	var level_lbl := Label.new()
	level_lbl.text = "★ Nivel: %d %s" % [inst.level, ("" if is_base_weapon else "(➔ Hereda: ★%d)" % inst.level)]
	level_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_lbl.add_theme_font_size_override("font_size", 10)
	level_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
	stats_p_vbox.add_child(level_lbl)

	var recycle_credits: int = WeaponController.calculate_recycle_credits(inst.level)
	var recycle_lbl := Label.new()
	recycle_lbl.text = "◈ NO SUSTITUIBLE ◈" if is_base_weapon else ("Reciclaje: +%d 🪙" % recycle_credits)
	recycle_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	recycle_lbl.add_theme_font_size_override("font_size", 10)
	recycle_lbl.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7) if is_base_weapon else Color(1.0, 0.78, 0.2))
	stats_p_vbox.add_child(recycle_lbl)

	card_vbox.add_child(stats_p_vbox)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_vbox.add_child(spacer)

	var rep_btn := Button.new()
	rep_btn.name = "ReplaceBtn"
	rep_btn.text = "BLOQUEADA" if is_base_weapon else ("Sustituir [%d]" % [slot_idx + 1])
	rep_btn.custom_minimum_size = Vector2(0, 32)
	rep_btn.disabled = is_base_weapon
	if is_base_weapon:
		rep_btn.focus_mode = Control.FOCUS_NONE
		rep_btn.modulate = Color(0.6, 0.6, 0.6, 0.7)
	else:
		rep_btn.focus_mode = Control.FOCUS_ALL
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

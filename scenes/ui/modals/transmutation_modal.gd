class_name TransmutationModal
extends BaseModal

## TransmutationModal.gd
## Interfaz de usuario para la Forja Cuántica (Microondas espacial).
## Permite duplicar ítems mediante sacrificio molecular de misma rareza.

signal modal_closed()

const TransmutationRewardChestClass = preload("res://scenes/combat/satellite/transmutation_reward_chest.gd")

@export var transmutation_cost: int = 50

var current_player: Player = null
var current_station: TransmutationStation = null

var _panel: PanelContainer
var _title_label: Label
var _desc_label: Label
var _uses_label: Label
var _feedback_label: Label
var _scroll_container: ScrollContainer
var _items_container: VBoxContainer
var _choice_container: VBoxContainer
var _close_btn: Button
var _item_buttons: Array[Button] = []
var _last_focused_item_btn: Button = null

func _ready() -> void:
	layer = 126
	modal_token = &"transmutation"
	add_to_group("transmutation_modal")
	_build_ui()
	super._ready()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if not (_choice_container and _choice_container.visible):
		var is_side_nav: bool = false
		if event is InputEventKey and event.is_pressed() and not event.is_echo():
			if event.keycode == KEY_A or event.keycode == KEY_D or event.keycode == KEY_LEFT or event.keycode == KEY_RIGHT:
				is_side_nav = true
		elif event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
			is_side_nav = true

		if is_side_nav:
			var focused := get_viewport().gui_get_focus_owner()
			if focused == _close_btn:
				var target_btn: Button = _last_focused_item_btn if (is_instance_valid(_last_focused_item_btn) and not _last_focused_item_btn.disabled) else (_item_buttons[0] if not _item_buttons.is_empty() else null)
				if target_btn and is_instance_valid(target_btn):
					target_btn.grab_focus()
					get_viewport().set_input_as_handled()
					return
			elif focused is Button and _item_buttons.has(focused):
				if _close_btn and is_instance_valid(_close_btn):
					_last_focused_item_btn = focused as Button
					_close_btn.grab_focus()
					get_viewport().set_input_as_handled()
					return

	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_ESCAPE:
			close_modal()
			get_viewport().set_input_as_handled()
			return
		elif _choice_container and _choice_container.visible:
			if event.keycode == KEY_1 or event.keycode == KEY_KP_1:
				if _choice_container.has_meta("choice_take_btn"):
					var b: Button = _choice_container.get_meta("choice_take_btn") as Button
					if is_instance_valid(b) and not b.disabled:
						b.emit_signal("pressed")
						get_viewport().set_input_as_handled()
						return
			elif event.keycode == KEY_2 or event.keycode == KEY_KP_2:
				if _choice_container.has_meta("choice_reject_btn"):
					var b: Button = _choice_container.get_meta("choice_reject_btn") as Button
					if is_instance_valid(b) and not b.disabled:
						b.emit_signal("pressed")
						get_viewport().set_input_as_handled()
						return

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.01, 0.04, 0.88)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(620, 680)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.04, 0.12, 0.96)
	style.set_border_width_all(2)
	style.border_color = Color(0.7, 0.3, 1.0, 0.8)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(18.0)
	_panel.add_theme_stylebox_override("panel", style)
	center.add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	_panel.add_child(vbox)

	_title_label = Label.new()
	_title_label.text = "FORJA CUÁNTICA DE TRANSMUTACIÓN"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 16)
	_title_label.modulate = Color(0.85, 0.5, 1.0, 1.0)
	vbox.add_child(_title_label)

	_desc_label = Label.new()
	_desc_label.text = "Selecciona un ítem para clonar (+1 copia). Coste: %dc. Consume 1 ítem al azar de la misma rareza como sacrificio molecular." % transmutation_cost
	_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_label.add_theme_font_size_override("font_size", 11)
	_desc_label.modulate = Color(0.75, 0.75, 0.85, 0.8)
	vbox.add_child(_desc_label)

	_uses_label = Label.new()
	_uses_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_uses_label.add_theme_font_size_override("font_size", 13)
	_uses_label.modulate = Color(1.0, 0.85, 0.3, 1.0)
	vbox.add_child(_uses_label)

	_feedback_label = Label.new()
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_label.add_theme_font_size_override("font_size", 12)
	_feedback_label.modulate = Color(0.4, 1.0, 0.6, 1.0)
	vbox.add_child(_feedback_label)

	_scroll_container = ScrollContainer.new()
	_scroll_container.custom_minimum_size = Vector2(580, 460)
	_scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(_scroll_container)

	var scroll_margin := MarginContainer.new()
	scroll_margin.add_theme_constant_override("margin_left", 18)
	scroll_margin.add_theme_constant_override("margin_right", 24)
	scroll_margin.add_theme_constant_override("margin_top", 4)
	scroll_margin.add_theme_constant_override("margin_bottom", 6)
	scroll_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll_container.add_child(scroll_margin)

	_items_container = VBoxContainer.new()
	_items_container.add_theme_constant_override("separation", 10)
	_items_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_margin.add_child(_items_container)

	_choice_container = VBoxContainer.new()
	_choice_container.add_theme_constant_override("separation", 14)
	_choice_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_choice_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_choice_container.hide()
	vbox.add_child(_choice_container)

	_close_btn = Button.new()
	_close_btn.text = "CERRAR FORJA [ESC]"
	_close_btn.custom_minimum_size = Vector2(200, 36)
	_close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_close_btn.pressed.connect(close_modal)
	vbox.add_child(_close_btn)
	UIFocusHelper.apply_cyber_focus(_close_btn)

func open_for_station(player: Player, station: TransmutationStation) -> void:
	current_player = player
	current_station = station
	open_modal()
	_title_label.text = "FORJA CUÁNTICA DE TRANSMUTACIÓN"
	_title_label.modulate = Color(0.85, 0.5, 1.0, 1.0)
	if _desc_label:
		_desc_label.show()
	if _scroll_container:
		_scroll_container.show()
	if _choice_container:
		_choice_container.hide()
	if _close_btn:
		_close_btn.show()
	_feedback_label.text = ""
	_refresh_ui()
	var initial_btn: Button = null
	for b in _item_buttons:
		if is_instance_valid(b) and not b.disabled:
			initial_btn = b
			break
	if not initial_btn and not _item_buttons.is_empty() and is_instance_valid(_item_buttons[0]):
		initial_btn = _item_buttons[0]

	if initial_btn:
		_last_focused_item_btn = initial_btn
		initial_btn.grab_focus()
	elif _close_btn:
		_close_btn.grab_focus()

func close_modal() -> void:
	if _choice_container:
		_choice_container.hide()
	if _scroll_container:
		_scroll_container.show()
	if _close_btn:
		_close_btn.show()
	super.close_modal()
	modal_closed.emit()

static func is_item_eligible_for_transmutation(it: ItemData) -> bool:
	if not it:
		return false
	if it.item_id == &"quantum_key":
		return false
	if it.tags.has(&"consumable") or it.tags.has(&"key"):
		return false
	return true

func _refresh_ui() -> void:
	if not current_station:
		return
	_uses_label.text = "USOS DISPONIBLES: %d / %d" % [current_station.uses_remaining, current_station.max_uses]

	# Limpiar catálogo anterior
	_item_buttons.clear()
	for child in _items_container.get_children():
		child.queue_free()

	if not is_instance_valid(current_player) or not current_player.inventory:
		return

	var all_items := current_player.inventory.get_all_items()
	var eligible_items: Array[Dictionary] = []
	for entry in all_items:
		var it: ItemData = entry["data"]
		if is_item_eligible_for_transmutation(it):
			eligible_items.append(entry)

	if eligible_items.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No posees ítems transmutables en tu inventario."
		empty_lbl.modulate = Color(0.8, 0.8, 0.8, 0.7)
		_items_container.add_child(empty_lbl)
		return

	# Agrupar ítems por rareza
	var rarity_order: Array[Enums.Rarity] = [
		Enums.Rarity.COMMON,
		Enums.Rarity.UNCOMMON,
		Enums.Rarity.RARE,
		Enums.Rarity.EPIC,
		Enums.Rarity.LEGENDARY
	]

	var items_by_rarity: Dictionary = {}
	for r in rarity_order:
		items_by_rarity[r] = []

	for entry in eligible_items:
		var it: ItemData = entry["data"]
		var r: Enums.Rarity = it.rarity
		if not items_by_rarity.has(r):
			items_by_rarity[r] = []
		items_by_rarity[r].append(entry)

	for r in rarity_order:
		var group: Array = items_by_rarity[r]
		if group.is_empty():
			continue

		var r_color := _get_rarity_color(r)
		var r_name := _get_rarity_short_name(r).to_upper()

		# Encabezado de la categoría de rareza
		var header_lbl := Label.new()
		header_lbl.text = "─── %s (%d) ───" % [r_name, group.size()]
		header_lbl.add_theme_font_size_override("font_size", 12)
		header_lbl.modulate = r_color
		header_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_items_container.add_child(header_lbl)

		# Sub-lista de filas horizontales para los ítems de esta rareza
		var group_vbox := VBoxContainer.new()
		group_vbox.add_theme_constant_override("separation", 8)
		group_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_items_container.add_child(group_vbox)

		for entry in group:
			var it: ItemData = entry["data"]
			var count: int = entry["count"]

			# Comprobar si existe al menos otro ítem (o copia adicional) de esta misma rareza para sacrificar
			var has_sacrifice: bool = false
			for other_entry in eligible_items:
				var other_it: ItemData = other_entry["data"]
				var other_count: int = other_entry["count"]
				if other_it.rarity == it.rarity:
					if other_it.item_id != it.item_id or other_count > 1:
						has_sacrifice = true
						break

			var btn := _create_item_card_button(it, count, has_sacrifice)
			group_vbox.add_child(btn)
			_item_buttons.append(btn)

	_setup_forge_navigation()

func _setup_forge_navigation() -> void:
	if _item_buttons.is_empty():
		return

	var count: int = _item_buttons.size()
	for i in range(count):
		var btn := _item_buttons[i]
		var prev_btn := _item_buttons[(i - 1 + count) % count]
		var next_btn := _item_buttons[(i + 1) % count]

		# Navegación vertical: recorre todos los ítems secuencialmente sin saltar a salir
		btn.focus_neighbor_top = prev_btn.get_path()
		btn.focus_neighbor_bottom = next_btn.get_path()

		# Navegación horizontal: saltar directamente a salir
		if _close_btn:
			btn.focus_neighbor_left = _close_btn.get_path()
			btn.focus_neighbor_right = _close_btn.get_path()

		btn.focus_entered.connect(func():
			_last_focused_item_btn = btn
			if _scroll_container:
				_scroll_container.ensure_control_visible(btn)
		)

	if _close_btn:
		var target_item: Button = _last_focused_item_btn if (is_instance_valid(_last_focused_item_btn) and not _last_focused_item_btn.disabled) else _item_buttons[0]
		_close_btn.focus_neighbor_left = target_item.get_path()
		_close_btn.focus_neighbor_right = target_item.get_path()
		_close_btn.focus_neighbor_top = target_item.get_path()
		_close_btn.focus_neighbor_bottom = target_item.get_path()

func _create_item_card_button(item: ItemData, count: int, has_sacrifice: bool = true) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 74)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.focus_mode = Control.FOCUS_ALL

	var r_col := _get_rarity_color(item.rarity)
	if not has_sacrifice:
		btn.disabled = true
		btn.modulate = Color(0.6, 0.6, 0.6, 0.45)
		btn.tooltip_text = "Sin material de sacrificio disponible (se requiere otro ítem de esta rareza)"
	else:
		btn.tooltip_text = "%s (x%d)\n%s" % [item.item_name, count, item.description]

	# Borde con el color de rareza
	var normal_box := StyleBoxFlat.new()
	normal_box.bg_color = Color(0.08, 0.08, 0.14, 0.9) if has_sacrifice else Color(0.05, 0.05, 0.08, 0.7)
	normal_box.border_color = r_col if has_sacrifice else Color(0.3, 0.3, 0.3, 0.5)
	normal_box.set_border_width_all(2)
	normal_box.set_corner_radius_all(6)
	normal_box.set_content_margin_all(8.0)
	btn.add_theme_stylebox_override("normal", normal_box)

	if has_sacrifice:
		var hover_box := normal_box.duplicate() as StyleBoxFlat
		hover_box.bg_color = Color(r_col.r * 0.25, r_col.g * 0.25, r_col.b * 0.25, 0.95)
		hover_box.border_color = Color.WHITE
		btn.add_theme_stylebox_override("hover", hover_box)
		UIFocusHelper.apply_cyber_focus(btn)
		btn.pressed.connect(func(): _on_item_selected_to_clone(item))

	# Estructura interna visual en fila horizontal
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.set("theme_override_constants/separation", 12)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(hbox)

	# 1. Icono con marco de rareza (56x56 px)
	var icon_panel := PanelContainer.new()
	icon_panel.custom_minimum_size = Vector2(62, 62)
	icon_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var icon_style := StyleBoxFlat.new()
	icon_style.bg_color = Color(0.02, 0.04, 0.08, 0.95)
	icon_style.set_border_width_all(1)
	icon_style.border_color = r_col
	icon_style.set_corner_radius_all(6)
	icon_panel.add_theme_stylebox_override("panel", icon_style)

	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(56, 56)
	icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if item.icon:
		icon_rect.texture = item.icon
	icon_panel.add_child(icon_rect)
	hbox.add_child(icon_panel)

	# 2. Información central
	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info_vbox.add_theme_constant_override("separation", 2)
	info_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var title_lbl := Label.new()
	title_lbl.text = "%s  (x%d)" % [item.item_name, count]
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.add_theme_color_override("font_color", r_col if has_sacrifice else Color(0.6, 0.6, 0.6))
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_vbox.add_child(title_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = item.description
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9, 0.85) if has_sacrifice else Color(0.5, 0.5, 0.5, 0.6))
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_vbox.add_child(desc_lbl)

	hbox.add_child(info_vbox)

	# 3. Badge indicador de acción a la derecha
	var action_lbl := Label.new()
	action_lbl.text = "[ CLONAR ]" if has_sacrifice else "[ BLOQUEADO ]"
	action_lbl.add_theme_font_size_override("font_size", 12)
	action_lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.6) if has_sacrifice else Color(0.8, 0.4, 0.4))
	action_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	action_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(action_lbl)

	return btn

func _on_item_selected_to_clone(target_item: ItemData) -> void:
	if not current_player or not current_station or current_station.uses_remaining <= 0:
		return

	if current_player.run_credits < transmutation_cost:
		_show_feedback("¡Créditos insuficientes! Se requieren %dc." % transmutation_cost, Color(1.0, 0.3, 0.3, 1.0))
		return

	# Buscar material de sacrificio de la misma rareza
	var all_items := current_player.inventory.get_all_items()
	var sacrifice_candidates: Array[ItemData] = []

	for entry in all_items:
		var it: ItemData = entry["data"]
		var cnt: int = entry["count"]
		if not is_item_eligible_for_transmutation(it):
			continue
		if it.rarity == target_item.rarity:
			if it.item_id != target_item.item_id:
				sacrifice_candidates.append(it)
			elif cnt > 1:
				# Si es el mismo ítem pero tiene múltiples copias, se puede usar
				sacrifice_candidates.append(it)

	if sacrifice_candidates.is_empty():
		_show_feedback("¡Sin material de sacrificio! Necesitas otro ítem de rareza %s." % _get_rarity_short_name(target_item.rarity), Color(1.0, 0.3, 0.3, 1.0))
		return

	# Iniciar proceso de transmutación autónomo en la estación
	var sacrifice_item: ItemData = sacrifice_candidates.pick_random()
	current_player.run_credits -= transmutation_cost
	if current_player.has_signal("credits_changed"):
		current_player.credits_changed.emit(current_player.run_credits)

	current_player.inventory.remove_item_stacks(sacrifice_item.item_id, 1)

	var station_ref := current_station
	var player_ref := current_player
	close_modal()

	if is_instance_valid(station_ref) and station_ref.has_method("start_processing"):
		station_ref.start_processing(target_item, player_ref)

## Abre el diálogo interactivo para Aceptar o Rechazar el ítem forjado por créditos (idéntico a SlotMachineRewardModal)
func open_choice(item: ItemData, on_decision: Callable) -> void:
	open_modal()
	if _close_btn:
		_close_btn.hide()
	if _desc_label:
		_desc_label.hide()
	if _scroll_container:
		_scroll_container.hide()

	_title_label.text = "🎁 RESULTADO DE LA TRANSMUTACIÓN"
	_title_label.modulate = Color(1.0, 0.88, 0.2, 1.0)
	_uses_label.text = "La forja cuántica ha culminado el proceso molecular con éxito."
	_uses_label.modulate = Color(0.75, 0.75, 0.85, 1.0)
	_feedback_label.text = ""

	for child in _choice_container.get_children():
		child.queue_free()

	_choice_container.show()

	# Item Card Frame idéntico a SlotMachineRewardModal
	var card_frame := PanelContainer.new()
	var csb := StyleBoxFlat.new()
	csb.bg_color = Color(0.12, 0.09, 0.22, 0.9)
	csb.border_color = Color(0.8, 0.6, 1.0, 0.6)
	csb.set_border_width_all(2)
	csb.set_corner_radius_all(8)
	csb.content_margin_left = 20
	csb.content_margin_right = 20
	csb.content_margin_top = 16
	csb.content_margin_bottom = 16
	card_frame.add_theme_stylebox_override("panel", csb)
	_choice_container.add_child(card_frame)

	var card_vbox := VBoxContainer.new()
	card_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card_vbox.add_theme_constant_override("separation", 8)
	card_frame.add_child(card_vbox)

	var icon_center := CenterContainer.new()
	card_vbox.add_child(icon_center)

	var item_icon := TextureRect.new()
	item_icon.custom_minimum_size = Vector2(110, 110)
	item_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	item_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	item_icon.texture = item.icon
	icon_center.add_child(item_icon)

	var item_name_label := Label.new()
	item_name_label.text = item.item_name
	item_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	item_name_label.add_theme_font_size_override("font_size", 18)
	item_name_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	card_vbox.add_child(item_name_label)

	var rarity_label := Label.new()
	var r_text: String = "COMÚN"
	var r_color: Color = Color(0.7, 0.7, 0.7, 1.0)
	match item.rarity:
		Enums.Rarity.UNCOMMON:
			r_text = "POCO COMÚN"
			r_color = Color(0.2, 0.8, 0.4, 1.0)
		Enums.Rarity.RARE:
			r_text = "RARO"
			r_color = Color(0.2, 0.6, 1.0, 1.0)
		Enums.Rarity.EPIC:
			r_text = "ÉPICO"
			r_color = Color(0.8, 0.3, 1.0, 1.0)
		Enums.Rarity.LEGENDARY:
			r_text = "LEGENDARIO"
			r_color = Color(1.0, 0.8, 0.1, 1.0)
	rarity_label.text = r_text
	rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_label.add_theme_font_size_override("font_size", 12)
	rarity_label.add_theme_color_override("font_color", r_color)
	card_vbox.add_child(rarity_label)

	var item_desc_label := Label.new()
	item_desc_label.text = item.description
	item_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	item_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item_desc_label.add_theme_font_size_override("font_size", 14)
	item_desc_label.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95, 1.0))
	card_vbox.add_child(item_desc_label)

	# Fila de botones Aceptar y Rechazar
	var refund: int = TransmutationRewardChestClass.get_refund_credits_for_rarity(item.rarity)
	var btn_box := HBoxContainer.new()
	btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_box.add_theme_constant_override("separation", 20)

	var take_button := Button.new()
	take_button.text = "✨ [1] TOMAR ÍTEM"
	take_button.custom_minimum_size = Vector2(200, 46)
	UIFocusHelper.apply_cyber_focus(take_button)
	take_button.pressed.connect(func():
		close_modal()
		on_decision.call(true)
	)
	btn_box.add_child(take_button)

	var reject_button := Button.new()
	reject_button.text = "♻️ [2] RECHAZAR (+%d Créditos)" % refund
	reject_button.custom_minimum_size = Vector2(230, 46)
	UIFocusHelper.apply_cyber_focus(reject_button)
	reject_button.pressed.connect(func():
		close_modal()
		on_decision.call(false)
	)
	btn_box.add_child(reject_button)

	_choice_container.set_meta("choice_take_btn", take_button)
	_choice_container.set_meta("choice_reject_btn", reject_button)

	_choice_container.add_child(btn_box)

	show()
	take_button.grab_focus()

func _show_feedback(msg: String, col: Color) -> void:
	_feedback_label.text = msg
	_feedback_label.modulate = col

func _get_rarity_short_name(rarity: Enums.Rarity) -> String:
	match rarity:
		Enums.Rarity.COMMON: return "Común"
		Enums.Rarity.UNCOMMON: return "Poco Común"
		Enums.Rarity.RARE: return "Raro"
		Enums.Rarity.EPIC: return "Épico"
		Enums.Rarity.LEGENDARY: return "Legendario"
		_: return "Base"

func _get_rarity_color(rarity: Enums.Rarity) -> Color:
	match rarity:
		Enums.Rarity.COMMON: return Color(0.6, 0.9, 0.6)
		Enums.Rarity.UNCOMMON: return Color(0.3, 0.7, 1.0)
		Enums.Rarity.RARE: return Color(0.8, 0.4, 1.0)
		Enums.Rarity.EPIC: return Color(1.0, 0.3, 0.8)
		Enums.Rarity.LEGENDARY: return Color(1.0, 0.85, 0.2)
		_: return Color.WHITE



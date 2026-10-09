class_name TransmutationModal
extends BaseModal

## TransmutationModal.gd
## Orquestador desacoplado de la interfaz de usuario para la Forja Cuántica.
## Permite duplicar ítems mediante sacrificio molecular de la misma rareza.

signal modal_closed()

const TransmutationDataControllerClass = preload("res://scenes/ui/modals/transmutation_data_controller.gd")
const TransmutationChoiceViewClass = preload("res://scenes/ui/modals/transmutation_choice_view.gd")
const TransmutationCardBuilderClass = preload("res://scenes/ui/modals/transmutation_card_builder.gd")

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


# Compatibilidad directa con suites de test
static func is_item_eligible_for_transmutation(it: ItemData) -> bool:
	return TransmutationDataControllerClass.is_item_eligible_for_transmutation(it)


func _refresh_ui() -> void:
	if not current_station:
		return
	_uses_label.text = "USOS DISPONIBLES: %d / %d" % [current_station.uses_remaining, current_station.max_uses]

	_item_buttons.clear()
	for child in _items_container.get_children():
		child.queue_free()

	if not is_instance_valid(current_player) or not current_player.inventory:
		return

	var eligible_items := TransmutationDataControllerClass.get_eligible_items(current_player.inventory)
	if eligible_items.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No posees ítems transmutables en tu inventario."
		empty_lbl.modulate = Color(0.8, 0.8, 0.8, 0.7)
		_items_container.add_child(empty_lbl)
		return

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

		var r_color: Color = TransmutationCardBuilderClass.get_rarity_color(r)
		var r_name: String = TransmutationCardBuilderClass.get_rarity_short_name(r).to_upper()

		var header_lbl := Label.new()
		header_lbl.text = "─── %s (%d) ───" % [r_name, group.size()]
		header_lbl.add_theme_font_size_override("font_size", 12)
		header_lbl.modulate = r_color
		header_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_items_container.add_child(header_lbl)

		var group_vbox := VBoxContainer.new()
		group_vbox.add_theme_constant_override("separation", 8)
		group_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_items_container.add_child(group_vbox)

		for entry in group:
			var it: ItemData = entry["data"]
			var count: int = entry["count"]
			var has_sac: bool = TransmutationDataControllerClass.has_sacrifice_available(it, eligible_items)

			var btn: Button = TransmutationCardBuilderClass.create_item_card_button(
				it, count, has_sac, func(): _on_item_selected_to_clone(it)
			)
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

		btn.focus_neighbor_top = prev_btn.get_path()
		btn.focus_neighbor_bottom = next_btn.get_path()
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


func _on_item_selected_to_clone(target_item: ItemData) -> void:
	if not current_player or not current_station or current_station.uses_remaining <= 0:
		return

	var result := TransmutationDataControllerClass.execute_transmutation(current_player, target_item, transmutation_cost)
	if not result["success"]:
		_show_feedback(result["error"], Color(1.0, 0.3, 0.3, 1.0))
		return

	var station_ref := current_station
	var player_ref := current_player
	close_modal()

	if is_instance_valid(station_ref) and station_ref.has_method("start_processing"):
		station_ref.start_processing(target_item, player_ref)


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

	var take_btn: Button = TransmutationChoiceViewClass.build_choice_panel(
		_choice_container,
		item,
		func():
			close_modal()
			on_decision.call(true),
		func():
			close_modal()
			on_decision.call(false)
	)

	show()
	take_btn.grab_focus()


func _show_feedback(msg: String, col: Color) -> void:
	_feedback_label.text = msg
	_feedback_label.modulate = col

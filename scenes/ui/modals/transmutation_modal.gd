class_name TransmutationModal
extends CanvasLayer

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
var _uses_label: Label
var _feedback_label: Label
var _items_container: GridContainer
var _close_btn: Button

func _ready() -> void:
	layer = 126
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("transmutation_modal")
	_build_ui()
	hide()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.is_pressed() and event.keycode == KEY_ESCAPE:
		close_modal()
		get_viewport().set_input_as_handled()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.01, 0.04, 0.88)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(560, 480)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.04, 0.12, 0.96)
	style.set_border_width_all(2)
	style.border_color = Color(0.7, 0.3, 1.0, 0.8)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(20.0)
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

	var desc := Label.new()
	desc.text = "Selecciona un ítem para clonar (+1 copia). Coste: %dc. Consume 1 ítem al azar de la misma rareza como sacrificio molecular." % transmutation_cost
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 11)
	desc.modulate = Color(0.75, 0.75, 0.85, 0.8)
	vbox.add_child(desc)

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

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(520, 260)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	_items_container = GridContainer.new()
	_items_container.columns = 3
	_items_container.add_theme_constant_override("h_separation", 8)
	_items_container.add_theme_constant_override("v_separation", 8)
	_items_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_items_container)

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
	get_tree().paused = true
	_feedback_label.text = ""
	_refresh_ui()
	show()
	var first_btn: Control = null
	for child in _items_container.get_children():
		if child is Button and not child.is_queued_for_deletion():
			first_btn = child as Control
			break
	if first_btn:
		first_btn.grab_focus()
	else:
		_close_btn.grab_focus()

func close_modal() -> void:
	if _close_btn:
		_close_btn.show()
	hide()
	get_tree().paused = false
	modal_closed.emit()

func _refresh_ui() -> void:
	if not current_station:
		return
	_uses_label.text = "USOS DISPONIBLES: %d / %d" % [current_station.uses_remaining, current_station.max_uses]

	# Limpiar catálogo anterior
	for child in _items_container.get_children():
		child.queue_free()

	if not is_instance_valid(current_player) or not current_player.inventory:
		return

	var all_items := current_player.inventory.get_all_items()
	if all_items.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No posees ítems transmutables en tu inventario."
		empty_lbl.modulate = Color(0.8, 0.8, 0.8, 0.7)
		_items_container.add_child(empty_lbl)
		return

	for entry in all_items:
		var it: ItemData = entry["data"]
		var count: int = entry["count"]
		var btn := _create_item_card_button(it, count)
		_items_container.add_child(btn)

func _create_item_card_button(item: ItemData, count: int) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(165, 58)
	btn.text = "%s (x%d)\n[%s]" % [item.item_name, count, _get_rarity_short_name(item.rarity)]
	btn.icon = item.icon
	btn.expand_icon = true
	btn.clip_text = true
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	UIFocusHelper.apply_cyber_focus(btn)
	btn.pressed.connect(func(): _on_item_selected_to_clone(item))
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
	get_tree().paused = true
	if _close_btn:
		_close_btn.hide()
	_title_label.text = "🎁 RESULTADO DE LA TRANSMUTACIÓN"
	_title_label.modulate = Color(1.0, 0.88, 0.2, 1.0)
	_uses_label.text = "La forja cuántica ha culminado el proceso molecular con éxito."
	_uses_label.modulate = Color(0.75, 0.75, 0.85, 1.0)
	_feedback_label.text = ""

	for child in _items_container.get_children():
		child.queue_free()

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
	_items_container.add_child(card_frame)

	var card_vbox := VBoxContainer.new()
	card_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card_vbox.add_theme_constant_override("separation", 8)
	card_frame.add_child(card_vbox)

	var icon_center := CenterContainer.new()
	card_vbox.add_child(icon_center)

	var item_icon := TextureRect.new()
	item_icon.custom_minimum_size = Vector2(64, 64)
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
	take_button.text = "✨ TOMAR ÍTEM"
	take_button.custom_minimum_size = Vector2(200, 46)
	UIFocusHelper.apply_cyber_focus(take_button)
	take_button.pressed.connect(func():
		close_modal()
		on_decision.call(true)
	)
	btn_box.add_child(take_button)

	var reject_button := Button.new()
	reject_button.text = "♻️ RECHAZAR (+%d Créditos)" % refund
	reject_button.custom_minimum_size = Vector2(230, 46)
	UIFocusHelper.apply_cyber_focus(reject_button)
	reject_button.pressed.connect(func():
		close_modal()
		on_decision.call(false)
	)
	btn_box.add_child(reject_button)

	_items_container.add_child(btn_box)

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


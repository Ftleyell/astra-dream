class_name TransmutationChoiceView
extends RefCounted

## TransmutationChoiceView.gd
## Controlador desacoplado de la vista de decisión ("Tomar Ítem" / "Rechazar (+Créditos)")
## tras finalizar la transmutación.

const TransmutationRewardChestClass = preload("res://scenes/combat/satellite/transmutation_reward_chest.gd")
const ItemDataScript = preload("res://data/items/item_data.gd")


static func build_choice_panel(
	container: VBoxContainer,
	item: ItemData,
	on_take: Callable,
	on_reject: Callable
) -> Button:
	for child in container.get_children():
		child.queue_free()

	container.show()

	# Card Frame
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
	container.add_child(card_frame)

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
	take_button.pressed.connect(on_take)
	btn_box.add_child(take_button)

	var reject_button := Button.new()
	reject_button.text = "♻️ [2] RECHAZAR (+%d Créditos)" % refund
	reject_button.custom_minimum_size = Vector2(230, 46)
	UIFocusHelper.apply_cyber_focus(reject_button)
	reject_button.pressed.connect(on_reject)
	btn_box.add_child(reject_button)

	container.set_meta("choice_take_btn", take_button)
	container.set_meta("choice_reject_btn", reject_button)
	container.add_child(btn_box)

	return take_button

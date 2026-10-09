class_name CharacterRosterGridBuilder
extends RefCounted

## CharacterRosterGridBuilder.gd
## Componente desacoplado para la construcción procedural de las tarjetas
## de héroes en el dock inferior de selección de personajes.
## - Configura estilos, dimensiones y bordes por estado de desbloqueo.
## - Aplica texturas de avatar y conectividad con callbacks de selección.
## - Conecta animaciones suaves de hover con Tween.

static func populate_roster(
	container: Container,
	roster_ordered: Array[CharacterData],
	dock_card_buttons: Dictionary[StringName, Button],
	on_character_selected: Callable
) -> void:
	if not is_instance_valid(container):
		return

	for child: Node in container.get_children():
		child.queue_free()
	dock_card_buttons.clear()

	for char_data: CharacterData in roster_ordered:
		var cid: StringName = char_data.character_id
		var is_unlocked: bool = SaveManager.is_character_unlocked(cid)

		var card_btn := Button.new()
		card_btn.name = "PilotCard_%s" % cid
		card_btn.custom_minimum_size = Vector2(76, 76)
		card_btn.focus_mode = Control.FOCUS_NONE

		var card_style := StyleBoxFlat.new()
		card_style.bg_color = Color(0.025, 0.04, 0.07, 0.92)
		card_style.border_width_left = 2
		card_style.border_width_top = 2
		card_style.border_width_right = 2
		card_style.border_width_bottom = 2
		card_style.border_color = char_data.color if is_unlocked else Color(0.3, 0.35, 0.4, 0.5)
		card_style.set_corner_radius_all(6)
		card_style.content_margin_left = 4
		card_style.content_margin_top = 4
		card_style.content_margin_right = 4
		card_style.content_margin_bottom = 4
		card_btn.add_theme_stylebox_override("normal", card_style)
		card_btn.add_theme_stylebox_override("hover", card_style)
		card_btn.add_theme_stylebox_override("pressed", card_style)

		# Icono del avatar con expand_icon = true
		card_btn.icon = char_data.get_avatar_texture()
		card_btn.expand_icon = true
		card_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card_btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		card_btn.tooltip_text = char_data.display_name.to_upper()
		card_btn.text = ""
		card_btn.pivot_offset = Vector2(38, 38)

		if on_character_selected.is_valid():
			card_btn.pressed.connect(func() -> void:
				on_character_selected.call(cid)
			)

		# Hover feedback: escala suave 1.08x centrada
		card_btn.mouse_entered.connect(func() -> void:
			if is_instance_valid(card_btn):
				card_btn.pivot_offset = card_btn.size * 0.5
				var tw: Tween = card_btn.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
				tw.tween_property(card_btn, "scale", Vector2(1.08, 1.08), 0.12)
		)
		card_btn.mouse_exited.connect(func() -> void:
			if is_instance_valid(card_btn):
				card_btn.pivot_offset = card_btn.size * 0.5
				var tw: Tween = card_btn.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
				tw.tween_property(card_btn, "scale", Vector2(1.0, 1.0), 0.12)
		)

		UIFocusHelper.apply_cyber_focus(card_btn)
		container.add_child(card_btn)
		dock_card_buttons[cid] = card_btn

class_name PetSelectionModal
extends CanvasLayer

signal pet_selected(pet_id: StringName)
signal closed()

@onready var pets_container: VBoxContainer = $DimOverlay/CenterContainer/MainPanel/Margin/VBox/Scroll/PetsList
@onready var close_btn: Button = $DimOverlay/CenterContainer/MainPanel/Margin/VBox/CloseButton

var is_open: bool = false
var _pet_buttons: Array[Button] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 125
	hide()
	if close_btn:
		close_btn.pressed.connect(close_modal)
		UIFocusHelper.apply_cyber_focus(close_btn)

func open_modal() -> void:
	is_open = true
	show()
	_populate_pets()
	if not _pet_buttons.is_empty():
		_pet_buttons[0].grab_focus()
	elif close_btn:
		close_btn.grab_focus()

func close_modal() -> void:
	if not is_open: return
	is_open = false
	hide()
	closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not is_open: return
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		get_viewport().set_input_as_handled()
		close_modal()

func _populate_pets() -> void:
	for child in pets_container.get_children():
		pets_container.remove_child(child)
		child.queue_free()
	_pet_buttons.clear()

	var all_pets := PetData.load_roster_ordered()
	var selected_pid := SaveManager.get_selected_pet()

	for p_data in all_pets:
		var pid := p_data.pet_id
		var is_unlocked := SaveManager.is_pet_unlocked(pid)

		# Mascota secreta (Cosmo): no debe verse hasta desbloquearse
		if pid == &"cosmo" and not is_unlocked:
			continue

		var is_selected := (pid == selected_pid)

		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(620, 94)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.05, 0.08, 0.14, 0.95)
		style.border_color = p_data.theme_color if (is_selected or is_unlocked) else Color(0.3, 0.35, 0.45, 0.6)
		style.set_border_width_all(2 if is_selected else 1)
		style.set_corner_radius_all(8)
		style.set_content_margin_all(10.0)
		if is_selected:
			style.shadow_color = Color(p_data.theme_color.r, p_data.theme_color.g, p_data.theme_color.b, 0.4)
			style.shadow_size = 8
		card.add_theme_stylebox_override("panel", style)

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 14)

		# Icono
		var icon_rect := TextureRect.new()
		icon_rect.custom_minimum_size = Vector2(72, 72)
		icon_rect.texture = p_data.icon
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if not is_unlocked:
			icon_rect.modulate = Color(0.3, 0.3, 0.4, 0.6)
		hbox.add_child(icon_rect)

		# VBox información
		var vbox := VBoxContainer.new()
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 2)

		var title_row := HBoxContainer.new()
		var name_lbl := Label.new()
		name_lbl.text = p_data.display_name.to_upper() + " — " + p_data.title
		name_lbl.add_theme_font_size_override("font_size", 15)
		name_lbl.add_theme_color_override("font_color", p_data.theme_color if is_unlocked else Color(0.6, 0.6, 0.7))
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_row.add_child(name_lbl)

		var status_lbl := Label.new()
		if is_selected:
			status_lbl.text = "✓ EQUIPADO"
			status_lbl.add_theme_color_override("font_color", Color(0.2, 1.0, 0.6))
		elif is_unlocked:
			status_lbl.text = "DISPONIBLE"
			status_lbl.add_theme_color_override("font_color", Color(0.5, 0.85, 1.0))
		else:
			status_lbl.text = "🔒 BLOQUEADO (10 MIN)"
			status_lbl.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
		status_lbl.add_theme_font_size_override("font_size", 12)
		title_row.add_child(status_lbl)
		vbox.add_child(title_row)

		var desc_lbl := Label.new()
		desc_lbl.text = p_data.power_description if is_unlocked else "Sobrevive 10 minutos en una run para despertar al Gatito Astral."
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.add_theme_font_size_override("font_size", 12)
		desc_lbl.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0, 0.85) if is_unlocked else Color(0.5, 0.55, 0.65))
		vbox.add_child(desc_lbl)
		hbox.add_child(vbox)

		# Botón de selección invisible sobre la tarjeta
		var btn := Button.new()
		btn.flat = true
		btn.set_anchors_preset(Control.PRESET_FULL_RECT)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if is_unlocked else Control.CURSOR_FORBIDDEN
		btn.disabled = not is_unlocked

		btn.pressed.connect(func():
			if is_unlocked:
				SaveManager.set_selected_pet(pid)
				pet_selected.emit(pid)
				var audio_mgr := get_node_or_null("/root/AudioManager")
				if audio_mgr and audio_mgr.has_method("play_sfx"):
					audio_mgr.play_sfx("ui_click", 0.0, 1.2)
				close_modal()
		)
		UIFocusHelper.apply_cyber_focus(btn)
		_pet_buttons.append(btn)

		card.add_child(hbox)
		card.add_child(btn)
		pets_container.add_child(card)

	# Cadena de navegación
	for i in range(_pet_buttons.size()):
		var b := _pet_buttons[i]
		if i > 0:
			b.focus_neighbor_top = _pet_buttons[i - 1].get_path()
		if i < _pet_buttons.size() - 1:
			b.focus_neighbor_bottom = _pet_buttons[i + 1].get_path()
		else:
			b.focus_neighbor_bottom = close_btn.get_path()
	if close_btn and not _pet_buttons.is_empty():
		close_btn.focus_neighbor_top = _pet_buttons[-1].get_path()

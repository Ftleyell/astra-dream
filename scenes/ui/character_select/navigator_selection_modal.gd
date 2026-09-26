class_name NavigatorSelectionModal
extends CanvasLayer

signal navigator_selected(nav_id: StringName)
signal closed()

@onready var navs_container: VBoxContainer = $DimOverlay/CenterContainer/MainPanel/Margin/VBox/Scroll/NavigatorsList
@onready var close_btn: Button = $DimOverlay/CenterContainer/MainPanel/Margin/VBox/CloseButton

var is_open: bool = false
var _nav_buttons: Array[Button] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 126
	hide()
	if close_btn:
		close_btn.pressed.connect(close_modal)
		UIFocusHelper.apply_cyber_focus(close_btn)

func open_modal() -> void:
	is_open = true
	show()
	_populate_navigators()
	if not _nav_buttons.is_empty():
		_nav_buttons[0].grab_focus()
	elif close_btn:
		close_btn.grab_focus()

func close_modal() -> void:
	if not is_open:
		return
	is_open = false
	hide()
	closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		get_viewport().set_input_as_handled()
		close_modal()

func _populate_navigators() -> void:
	for child in navs_container.get_children():
		navs_container.remove_child(child)
		child.queue_free()
	_nav_buttons.clear()

	const NavigatorDataScript := preload("res://data/navigators/navigator_data.gd")
	var all_navs: Array = NavigatorDataScript.load_roster_ordered()
	var selected_nid := SaveManager.get_selected_navigator()

	for n_data in all_navs:
		var nid: StringName = n_data.navigator_id
		var is_unlocked: bool = SaveManager.is_navigator_unlocked(nid)
		var is_selected: bool = (nid == selected_nid)

		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(660, 108)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.04, 0.07, 0.12, 0.95)
		style.border_color = n_data.theme_color if (is_selected or is_unlocked) else Color(0.3, 0.35, 0.45, 0.6)
		style.set_border_width_all(2 if is_selected else 1)
		style.set_corner_radius_all(8)
		style.set_content_margin_all(10.0)
		if is_selected:
			style.shadow_color = Color(n_data.theme_color.r, n_data.theme_color.g, n_data.theme_color.b, 0.45)
			style.shadow_size = 10
		card.add_theme_stylebox_override("panel", style)

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 14)

		# Retrato de la Navegante
		var portrait_frame := PanelContainer.new()
		portrait_frame.custom_minimum_size = Vector2(80, 80)
		var frame_style := StyleBoxFlat.new()
		frame_style.bg_color = Color(0.02, 0.04, 0.08, 1.0)
		frame_style.border_color = n_data.theme_color if is_unlocked else Color(0.25, 0.25, 0.35)
		frame_style.set_border_width_all(2)
		frame_style.set_corner_radius_all(6)
		portrait_frame.add_theme_stylebox_override("panel", frame_style)

		var icon_rect := TextureRect.new()
		icon_rect.custom_minimum_size = Vector2(76, 76)
		icon_rect.texture = n_data.get_portrait_texture()
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if not is_unlocked:
			icon_rect.modulate = Color(0.3, 0.3, 0.4, 0.6)
		portrait_frame.add_child(icon_rect)
		hbox.add_child(portrait_frame)

		# VBox con información táctica
		var vbox := VBoxContainer.new()
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 2)

		var title_row := HBoxContainer.new()
		var name_lbl := Label.new()
		name_lbl.text = "%s — %s" % [n_data.display_name.to_upper(), n_data.title.to_upper()]
		name_lbl.add_theme_font_size_override("font_size", 15)
		name_lbl.add_theme_color_override("font_color", n_data.theme_color if is_unlocked else Color(0.6, 0.6, 0.7))
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_row.add_child(name_lbl)

		var status_lbl := Label.new()
		if is_selected:
			status_lbl.text = "✓ ENLACE ACTIVO"
			status_lbl.add_theme_color_override("font_color", Color(0.2, 1.0, 0.6))
		elif is_unlocked:
			status_lbl.text = "DISPONIBLE"
			status_lbl.add_theme_color_override("font_color", Color(0.5, 0.85, 1.0))
		else:
			status_lbl.text = "🔒 BLOQUEADA (FINAL CÓSMICO)"
			status_lbl.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
		status_lbl.add_theme_font_size_override("font_size", 12)
		title_row.add_child(status_lbl)
		vbox.add_child(title_row)

		var spec_lbl := Label.new()
		spec_lbl.text = "Radar: %s" % n_data.specialty_desc if is_unlocked else "Alcanza cualquiera de los 3 finales del juego (Pacifista, Genocida o Neutral) para sincronizarla."
		spec_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		spec_lbl.add_theme_font_size_override("font_size", 12)
		spec_lbl.add_theme_color_override("font_color", Color(0.85, 0.9, 0.98, 0.9) if is_unlocked else Color(0.5, 0.55, 0.65))
		vbox.add_child(spec_lbl)

		var buff_lbl := Label.new()
		buff_lbl.text = "✦ Buff: %s (%s)" % [n_data.buff_name, n_data.buff_desc] if is_unlocked else "✦ Buff: ???"
		buff_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		buff_lbl.add_theme_font_size_override("font_size", 11)
		buff_lbl.add_theme_color_override("font_color", n_data.theme_color.lerp(Color.WHITE, 0.25) if is_unlocked else Color(0.4, 0.45, 0.55))
		vbox.add_child(buff_lbl)

		hbox.add_child(vbox)

		# Botón transparente que cubre la tarjeta para selección táctil/ratón
		var btn := Button.new()
		btn.flat = true
		btn.set_anchors_preset(Control.PRESET_FULL_RECT)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if is_unlocked else Control.CURSOR_FORBIDDEN
		btn.disabled = not is_unlocked

		btn.pressed.connect(func():
			if is_unlocked:
				SaveManager.set_selected_navigator(nid)
				navigator_selected.emit(nid)
				var audio_mgr := get_node_or_null("/root/AudioManager")
				if audio_mgr and audio_mgr.has_method("play_sfx"):
					audio_mgr.play_sfx(&"ui_click", 0.0, 1.25)
				close_modal()
		)
		UIFocusHelper.apply_cyber_focus(btn)
		_nav_buttons.append(btn)

		card.add_child(hbox)
		card.add_child(btn)
		navs_container.add_child(card)

	# Cadena de navegación con gamepad / teclado
	for i in range(_nav_buttons.size()):
		var b := _nav_buttons[i]
		if i > 0:
			b.focus_neighbor_top = _nav_buttons[i - 1].get_path()
		if i < _nav_buttons.size() - 1:
			b.focus_neighbor_bottom = _nav_buttons[i + 1].get_path()
		else:
			b.focus_neighbor_bottom = close_btn.get_path()
	if close_btn and not _nav_buttons.is_empty():
		close_btn.focus_neighbor_top = _nav_buttons[-1].get_path()

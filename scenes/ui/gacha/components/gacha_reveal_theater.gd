class_name GachaRevealTheater
extends Control

## GachaRevealTheater.gd
## Capa interactiva de revelación cinematográfica de cápsulas Gacha:
## - Botón táctil de cápsula con animación de rebote y glow según rareza.
## - Apertura interactiva, display de carta con VFX y escala desde el centro.
## - Botón de salto rápido (ESC / Click) y pantalla de resumen final con cuadrícula.

const CosmeticsManager = preload("res://core/systems/cosmetics_manager.gd")

signal sequence_finished()

var is_animating: bool = false
var _current_pull_queue: Array[Dictionary] = []
var _current_pull_idx: int = 0

var _reveal_overlay: PanelContainer
var _reveal_vbox: VBoxContainer
var _reveal_capsule_display: CenterContainer
var _reveal_title_label: Label
var _reveal_subtitle_label: Label
var _reveal_capsule_btn: Button
var _reveal_cards_container: HBoxContainer
var _reveal_skip_btn: Button

var _results_layer: PanelContainer
var _results_grid: GridContainer

func setup(parent_panel: Control) -> void:
	_build_reveal_overlay(parent_panel)
	_build_results_layer(parent_panel)

func start_sequence(pull_queue: Array[Dictionary]) -> void:
	if pull_queue.is_empty():
		return
	_current_pull_queue = pull_queue
	_current_pull_idx = 0
	is_animating = true
	_reveal_overlay.show()
	_show_next_capsule()

func is_theater_active() -> bool:
	return is_animating or (_reveal_overlay != null and _reveal_overlay.visible) or (_results_layer != null and _results_layer.visible)

func skip_sequence() -> void:
	if _reveal_overlay and _reveal_overlay.visible:
		_on_skip_reveal_pressed()
	elif _results_layer and _results_layer.visible:
		_on_results_closed()

func _build_reveal_overlay(parent_panel: Control) -> void:
	_reveal_overlay = PanelContainer.new()
	_reveal_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var rev_sb := StyleBoxFlat.new()
	rev_sb.bg_color = Color(0.03, 0.02, 0.08, 0.98)
	rev_sb.border_color = Color(0.0, 0.94, 1.0, 0.9)
	rev_sb.set_border_width_all(2)
	rev_sb.set_corner_radius_all(14)
	rev_sb.content_margin_left = 32
	rev_sb.content_margin_right = 32
	rev_sb.content_margin_top = 28
	rev_sb.content_margin_bottom = 28
	_reveal_overlay.add_theme_stylebox_override("panel", rev_sb)
	_reveal_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_reveal_overlay.gui_input.connect(_on_reveal_overlay_gui_input)
	parent_panel.add_child(_reveal_overlay)
	_reveal_overlay.hide()

	_reveal_vbox = VBoxContainer.new()
	_reveal_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_reveal_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reveal_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_reveal_vbox.add_theme_constant_override("separation", 24)
	_reveal_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	_reveal_overlay.add_child(_reveal_vbox)

	_reveal_title_label = Label.new()
	_reveal_title_label.text = "✨ ¡CÁPSULA EXPULSADA!"
	_reveal_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reveal_title_label.add_theme_font_size_override("font_size", 26)
	_reveal_title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0))
	_reveal_title_label.mouse_filter = Control.MOUSE_FILTER_PASS
	_reveal_vbox.add_child(_reveal_title_label)

	_reveal_subtitle_label = Label.new()
	_reveal_subtitle_label.text = "[ HAZ CLIC EN LA CÁPSULA PARA ABRIR ]"
	_reveal_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reveal_subtitle_label.add_theme_font_size_override("font_size", 15)
	_reveal_subtitle_label.add_theme_color_override("font_color", Color(0.0, 0.94, 1.0, 1.0))
	_reveal_subtitle_label.mouse_filter = Control.MOUSE_FILTER_PASS
	_reveal_vbox.add_child(_reveal_subtitle_label)

	_reveal_capsule_display = CenterContainer.new()
	_reveal_capsule_display.custom_minimum_size = Vector2(300, 240)
	_reveal_capsule_display.mouse_filter = Control.MOUSE_FILTER_PASS
	_reveal_vbox.add_child(_reveal_capsule_display)

	_reveal_capsule_btn = Button.new()
	_reveal_capsule_btn.text = "🔮\nABRIR"
	_reveal_capsule_btn.custom_minimum_size = Vector2(160, 160)
	_reveal_capsule_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_reveal_capsule_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_reveal_capsule_btn.add_theme_font_size_override("font_size", 24)
	var cap_sb := StyleBoxFlat.new()
	cap_sb.bg_color = Color(0.08, 0.06, 0.22, 0.95)
	cap_sb.border_color = Color(0.0, 0.94, 1.0, 1.0)
	cap_sb.set_border_width_all(4)
	cap_sb.set_corner_radius_all(80)
	_reveal_capsule_btn.add_theme_stylebox_override("normal", cap_sb)

	var cap_hover: StyleBoxFlat = cap_sb.duplicate() as StyleBoxFlat
	cap_hover.bg_color = Color(0.15, 0.10, 0.35, 0.98)
	cap_hover.border_color = Color(0.3, 1.0, 1.0, 1.0)
	_reveal_capsule_btn.add_theme_stylebox_override("hover", cap_hover)

	var cap_pressed: StyleBoxFlat = cap_sb.duplicate() as StyleBoxFlat
	cap_pressed.bg_color = Color(0.25, 0.18, 0.5, 1.0)
	cap_pressed.border_color = Color(1.0, 1.0, 1.0, 1.0)
	_reveal_capsule_btn.add_theme_stylebox_override("pressed", cap_pressed)

	_reveal_capsule_btn.pressed.connect(_on_capsule_opened)
	UIFocusHelper.apply_cyber_focus(_reveal_capsule_btn)
	_reveal_capsule_display.add_child(_reveal_capsule_btn)

	_reveal_cards_container = HBoxContainer.new()
	_reveal_cards_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_reveal_cards_container.custom_minimum_size = Vector2(200, 240)
	_reveal_cards_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reveal_cards_container.hide()
	_reveal_capsule_display.add_child(_reveal_cards_container)

	_reveal_skip_btn = Button.new()
	_reveal_skip_btn.text = "⏩ SALTAR TODO [ESC]"
	_reveal_skip_btn.custom_minimum_size = Vector2(240, 44)
	_reveal_skip_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_reveal_skip_btn.pressed.connect(_on_skip_reveal_pressed)
	UIFocusHelper.apply_cyber_focus(_reveal_skip_btn)
	_reveal_vbox.add_child(_reveal_skip_btn)

func _build_results_layer(parent_panel: Control) -> void:
	_results_layer = PanelContainer.new()
	_results_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	var rsb := StyleBoxFlat.new()
	rsb.bg_color = Color(0.03, 0.02, 0.08, 0.98)
	rsb.border_color = Color(0.0, 0.94, 1.0, 0.9)
	rsb.set_border_width_all(2)
	rsb.set_corner_radius_all(14)
	rsb.content_margin_left = 28
	rsb.content_margin_right = 28
	rsb.content_margin_top = 24
	rsb.content_margin_bottom = 24
	_results_layer.add_theme_stylebox_override("panel", rsb)
	parent_panel.add_child(_results_layer)
	_results_layer.hide()

	var res_vbox := VBoxContainer.new()
	res_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	res_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	res_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	res_vbox.add_theme_constant_override("separation", 18)
	_results_layer.add_child(res_vbox)

	var res_title := Label.new()
	res_title.text = "🎉 ¡RECOMPENSAS DEL GACHA OBTENIDAS! 🎉"
	res_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	res_title.add_theme_font_size_override("font_size", 22)
	res_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0))
	res_vbox.add_child(res_title)

	var res_scroll := ScrollContainer.new()
	res_scroll.custom_minimum_size = Vector2(920, 480)
	res_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	res_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	res_vbox.add_child(res_scroll)

	var res_center := CenterContainer.new()
	res_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	res_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	res_scroll.add_child(res_center)

	_results_grid = GridContainer.new()
	_results_grid.columns = 5
	_results_grid.add_theme_constant_override("h_separation", 18)
	_results_grid.add_theme_constant_override("v_separation", 18)
	res_center.add_child(_results_grid)

	var res_close_btn := Button.new()
	res_close_btn.text = "✨ RECLAMAR Y CONTINUAR"
	res_close_btn.custom_minimum_size = Vector2(280, 50)
	res_close_btn.pressed.connect(_on_results_closed)
	UIFocusHelper.apply_cyber_focus(res_close_btn)
	res_vbox.add_child(res_close_btn)

func _show_next_capsule() -> void:
	if _current_pull_idx >= _current_pull_queue.size():
		_reveal_overlay.hide()
		_display_pull_results(_current_pull_queue)
		is_animating = false
		return

	var pull_item: Dictionary = _current_pull_queue[_current_pull_idx]
	var skin: Dictionary = pull_item.get("skin_data", {})
	var rarity: String = skin.get("rarity", "common")

	for child: Node in _reveal_cards_container.get_children():
		child.queue_free()
	_reveal_cards_container.hide()
	_reveal_cards_container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_reveal_capsule_btn.show()
	_reveal_capsule_btn.scale = Vector2.ONE
	_reveal_capsule_btn.move_to_front()
	_reveal_capsule_btn.grab_focus()
	_reveal_title_label.text = "✨ ¡CÁPSULA [%d / %d] EXPULSADA!" % [_current_pull_idx + 1, _current_pull_queue.size()]
	_reveal_subtitle_label.text = "[ HAZ CLIC EN LA CÁPSULA PARA ABRIR ]"

	var glow_color: Color = Color(0.0, 0.94, 1.0, 1.0)
	match rarity:
		"epic":
			glow_color = Color(1.0, 0.85, 0.2, 1.0)
			_reveal_capsule_btn.text = "🌟\nÉPICA"
		"rare":
			glow_color = Color(0.85, 0.3, 1.0, 1.0)
			_reveal_capsule_btn.text = "🔮\nRARA"
		_:
			glow_color = Color(0.0, 0.94, 1.0, 1.0)
			_reveal_capsule_btn.text = "⚪\nCOMÚN"

	_reveal_capsule_btn.modulate = glow_color
	_reveal_capsule_btn.pivot_offset = _reveal_capsule_btn.size * 0.5 if _reveal_capsule_btn.size != Vector2.ZERO else Vector2(80, 80)

	var tw: Tween = create_tween()
	if tw:
		tw.tween_property(_reveal_capsule_btn, "scale", Vector2(1.15, 1.15), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(_reveal_capsule_btn, "scale", Vector2.ONE, 0.15)

func _on_capsule_opened() -> void:
	if not _reveal_capsule_btn.visible:
		return
	if _current_pull_idx >= _current_pull_queue.size():
		return

	var pull_item: Dictionary = _current_pull_queue[_current_pull_idx]
	var skin: Dictionary = pull_item.get("skin_data", {})
	var upg: Dictionary = pull_item.get("upgrade_data", {})

	var audio_mgr: Node = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("ui_click")

	_reveal_capsule_btn.hide()
	_reveal_cards_container.show()
	_reveal_cards_container.mouse_filter = Control.MOUSE_FILTER_PASS

	var card: Control = _create_reward_card(skin, upg)
	card.pivot_offset = Vector2(85, 115)
	card.scale = Vector2(0.3, 0.3)
	_reveal_cards_container.add_child(card)

	var tw: Tween = create_tween()
	if tw:
		tw.tween_property(card, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	_reveal_subtitle_label.text = "[ PULSA ESPACIO O HAZ CLIC PARA CONTINUAR ]"

	_current_pull_idx += 1
	get_tree().create_timer(1.3).timeout.connect(func():
		if _reveal_overlay.visible and not _reveal_capsule_btn.visible:
			_show_next_capsule()
	)

func _on_reveal_overlay_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _reveal_capsule_btn.visible:
			_on_capsule_opened()
		else:
			_show_next_capsule()

func _on_skip_reveal_pressed() -> void:
	_reveal_overlay.hide()
	_display_pull_results(_current_pull_queue)
	is_animating = false

func _display_pull_results(results: Array[Dictionary]) -> void:
	for child: Node in _results_grid.get_children():
		child.queue_free()

	for res: Dictionary in results:
		var skin: Dictionary = res.get("skin_data", {})
		var upg: Dictionary = res.get("upgrade_data", {})
		var card: Control = _create_reward_card(skin, upg)
		_results_grid.add_child(card)

	_results_layer.show()

func _on_results_closed() -> void:
	_results_layer.hide()
	_reveal_overlay.hide()
	is_animating = false
	sequence_finished.emit()

func _create_reward_card(skin: Dictionary, upg: Dictionary) -> Control:
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(170, 230)

	var stars: int = int(upg.get("new_stars", 1))
	var status: String = str(upg.get("status", "new"))
	var glow_hex: String = skin.get("glow_hex", "#00F0FF")

	var csb := StyleBoxFlat.new()
	csb.bg_color = Color(0.08, 0.06, 0.18, 0.96)
	csb.border_color = Color.from_string(glow_hex, Color.CYAN)
	csb.set_border_width_all(2)
	csb.set_corner_radius_all(10)
	csb.content_margin_left = 14
	csb.content_margin_right = 14
	csb.content_margin_top = 12
	csb.content_margin_bottom = 12
	frame.add_theme_stylebox_override("panel", csb)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 6)
	frame.add_child(vbox)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(84, 84)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var tex: Texture2D = CosmeticsManager.get_skin_texture(skin)
	if tex:
		icon.texture = tex
	CosmeticsManager.apply_skin_to_canvas_item(icon, skin.get("id", ""), stars, false)
	vbox.add_child(icon)

	var t_name := Label.new()
	t_name.text = skin.get("target_name", "")
	t_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t_name.add_theme_font_size_override("font_size", 13)
	t_name.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	vbox.add_child(t_name)

	var s_name := Label.new()
	s_name.text = skin.get("skin_name", "")
	s_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	s_name.add_theme_font_size_override("font_size", 11)
	s_name.add_theme_color_override("font_color", Color(0.8, 0.85, 0.95, 1.0))
	vbox.add_child(s_name)

	var star_str: String = ""
	for i: int in range(stars):
		star_str += "⭐"
	var stars_lbl := Label.new()
	stars_lbl.text = star_str
	stars_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stars_lbl.add_theme_font_size_override("font_size", 12)
	vbox.add_child(stars_lbl)

	var tag := Label.new()
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_font_size_override("font_size", 11)
	match status:
		"new":
			tag.text = "¡NUEVO DESBLOQUEO!"
			tag.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4, 1.0))
		"upgraded":
			tag.text = "¡MEJORA A %d★!" % stars
			tag.add_theme_color_override("font_color", Color(0.2, 0.9, 1.0, 1.0))
		"max_converted":
			tag.text = "+150 POLVO ESTELAR"
			tag.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0))
	vbox.add_child(tag)

	return frame

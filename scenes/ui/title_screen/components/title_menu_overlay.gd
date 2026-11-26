class_name TitleMenuOverlay
extends Control

## Menú de navegación limpio debajo del logotipo de Stela Galactica.
## Soporta mouse, teclado y gamepad en estilo Astral Pop-Ink.

signal continue_requested()
signal play_requested()
signal settings_requested()
signal quit_requested()
signal patch_notes_requested()

const COLOR_PANEL_BG := Color(0.038, 0.052, 0.115, 0.86)
const COLOR_PANEL_HOVER := Color(0.095, 0.145, 0.285, 0.96)
const COLOR_GOLD := Color(0.95, 0.80, 0.34, 1.0)
const COLOR_CYAN := Color(0.18, 0.92, 1.0, 1.0)
const COLOR_TEXT := Color(0.94, 0.96, 1.0, 1.0)

var _menu_vbox: VBoxContainer = null
var _btn_continue: Button = null
var _btn_play: Button = null
var _btn_settings: Button = null
var _btn_quit: Button = null
var _btn_notes: Button = null
var _version_label: Label = null
var _active_tween: Tween = null
var _show_continue: bool = false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()


func _build_ui() -> void:
	if _menu_vbox != null:
		return

	var center_holder := VBoxContainer.new()
	center_holder.name = "MenuCenterHolder"
	center_holder.anchor_left = 0.5
	center_holder.anchor_right = 0.5
	center_holder.anchor_top = 1.0
	center_holder.anchor_bottom = 1.0
	center_holder.offset_left = -165.0
	center_holder.offset_right = 165.0
	center_holder.offset_top = -310.0
	center_holder.offset_bottom = -52.0
	center_holder.alignment = BoxContainer.ALIGNMENT_CENTER
	center_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center_holder)

	_menu_vbox = VBoxContainer.new()
	_menu_vbox.name = "MenuButtonsVBox"
	_menu_vbox.add_theme_constant_override("separation", 10)
	_menu_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_menu_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_holder.add_child(_menu_vbox)

	_btn_continue = _make_menu_button("ContinueButton", "CONTINUAR", true)
	_btn_continue.visible = _show_continue
	_btn_continue.pressed.connect(func() -> void:
		_play_ui_sfx("ui_click")
		continue_requested.emit()
	)
	_menu_vbox.add_child(_btn_continue)

	_btn_play = _make_menu_button("PlayButton", "JUGAR", true)
	_btn_play.pressed.connect(func() -> void:
		_play_ui_sfx("ui_click")
		play_requested.emit()
	)
	_menu_vbox.add_child(_btn_play)

	_btn_settings = _make_menu_button("SettingsButton", "AJUSTES", false)
	_btn_settings.pressed.connect(func() -> void:
		_play_ui_sfx("ui_click")
		settings_requested.emit()
	)
	_menu_vbox.add_child(_btn_settings)

	_btn_quit = _make_menu_button("QuitButton", "SALIR", false)
	_btn_quit.pressed.connect(func() -> void:
		_play_ui_sfx("ui_click")
		quit_requested.emit()
	)
	_menu_vbox.add_child(_btn_quit)

	_btn_notes = Button.new()
	_btn_notes.name = "PatchNotesButton"
	_btn_notes.text = "Notas del Parche"
	_btn_notes.anchor_left = 0.0
	_btn_notes.anchor_top = 1.0
	_btn_notes.anchor_bottom = 1.0
	_btn_notes.offset_left = 24.0
	_btn_notes.offset_top = -48.0
	_btn_notes.offset_right = 178.0
	_btn_notes.offset_bottom = -16.0
	_btn_notes.focus_mode = Control.FOCUS_NONE
	_btn_notes.add_theme_font_size_override("font_size", 12)
	_apply_button_style(_btn_notes, false, true)
	_btn_notes.pressed.connect(func() -> void:
		_play_ui_sfx("ui_click")
		patch_notes_requested.emit()
	)
	add_child(_btn_notes)

	_version_label = Label.new()
	_version_label.name = "VersionLabel"
	_version_label.text = "Stela Galactica · Alpha 0.1"
	_version_label.anchor_left = 1.0
	_version_label.anchor_right = 1.0
	_version_label.anchor_top = 1.0
	_version_label.anchor_bottom = 1.0
	_version_label.offset_left = -260.0
	_version_label.offset_top = -38.0
	_version_label.offset_right = -24.0
	_version_label.offset_bottom = -14.0
	_version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_version_label.add_theme_font_size_override("font_size", 12)
	_version_label.add_theme_color_override("font_color", Color(0.65, 0.76, 0.90, 0.72))
	add_child(_version_label)

	_wire_focus_chain()


func _make_menu_button(node_name: String, label_text: String, is_primary: bool) -> Button:
	var btn := Button.new()
	btn.name = node_name
	btn.text = label_text
	btn.custom_minimum_size = Vector2(310.0, 48.0 if is_primary else 42.0)
	btn.focus_mode = Control.FOCUS_ALL
	btn.add_theme_font_size_override("font_size", 20 if is_primary else 17)
	_apply_button_style(btn, is_primary, false)
	btn.mouse_entered.connect(func() -> void:
		_play_ui_sfx("ui_hover")
	)
	btn.focus_entered.connect(func() -> void:
		btn.text = "▸ %s" % label_text
	)
	btn.focus_exited.connect(func() -> void:
		btn.text = label_text
	)
	return btn


func _apply_button_style(btn: Button, is_primary: bool, compact: bool) -> void:
	var accent: Color = COLOR_GOLD if is_primary else COLOR_CYAN
	var normal_sb := StyleBoxFlat.new()
	normal_sb.bg_color = COLOR_PANEL_BG
	normal_sb.border_color = Color(accent.r, accent.g, accent.b, 0.65 if is_primary else 0.40)
	normal_sb.set_border_width_all(2 if not compact else 1)
	normal_sb.set_corner_radius_all(8)
	normal_sb.set_content_margin_all(8)

	var hover_sb := StyleBoxFlat.new()
	hover_sb.bg_color = COLOR_PANEL_HOVER
	hover_sb.border_color = accent
	hover_sb.set_border_width_all(2)
	hover_sb.set_corner_radius_all(8)
	hover_sb.set_content_margin_all(8)

	btn.add_theme_stylebox_override("normal", normal_sb)
	btn.add_theme_stylebox_override("hover", hover_sb)
	btn.add_theme_stylebox_override("focus", hover_sb)
	btn.add_theme_stylebox_override("pressed", hover_sb)
	btn.add_theme_color_override("font_color", COLOR_GOLD if is_primary else COLOR_TEXT)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_focus_color", Color.WHITE)


func set_continue_available(available: bool) -> void:
	_show_continue = available
	if _btn_continue != null:
		_btn_continue.visible = available
	_wire_focus_chain()


func _wire_focus_chain() -> void:
	if _btn_play == null:
		return
	var ordered: Array[Button] = []
	if _btn_continue != null and _btn_continue.visible:
		ordered.append(_btn_continue)
	ordered.append(_btn_play)
	if _btn_settings != null:
		ordered.append(_btn_settings)
	if _btn_quit != null:
		ordered.append(_btn_quit)

	for i: int in range(ordered.size()):
		var cur: Button = ordered[i]
		var prev_b: Button = ordered[(i - 1 + ordered.size()) % ordered.size()]
		var next_b: Button = ordered[(i + 1) % ordered.size()]
		cur.focus_neighbor_top = cur.get_path_to(prev_b)
		cur.focus_neighbor_bottom = cur.get_path_to(next_b)


func focus_primary_button() -> void:
	if _btn_continue != null and _btn_continue.visible:
		_btn_continue.grab_focus()
	elif _btn_play != null:
		_btn_play.grab_focus()


func show_menu(animated: bool = true) -> void:
	visible = true
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	if not animated:
		modulate.a = 1.0
		focus_primary_button()
		return
	modulate.a = 0.0
	_active_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_active_tween.tween_property(self, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_active_tween.tween_callback(focus_primary_button)


func hide_menu(animated: bool = true) -> void:
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	if not animated:
		modulate.a = 0.0
		visible = false
		return
	_active_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_active_tween.tween_property(self, "modulate:a", 0.0, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_active_tween.tween_callback(func() -> void:
		visible = false
	)


func get_play_button() -> Button:
	return _btn_play


func get_continue_button() -> Button:
	return _btn_continue


func _play_ui_sfx(key: String) -> void:
	var am: Node = get_node_or_null("/root/AudioManager")
	if am != null and am.has_method("play_sfx"):
		am.play_sfx(key)

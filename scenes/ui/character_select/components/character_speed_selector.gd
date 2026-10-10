class_name CharacterSpeedSelector
extends RefCounted

## CharacterSpeedSelector.gd
## Controlador modular del selector de velocidad de juego para CharacterSelectUI.
## Gestiona los botones 1x, 2x, 4x, su persistencia en SaveManager y sus estilos Psycho-Pop.

var speed_1x_btn: Button = null
var speed_2x_btn: Button = null
var speed_4x_btn: Button = null
var current_game_speed: float = 1.0


func setup_from_root(root: Control) -> void:
	var base_path: String = "MarginContainer/RootVBox/MainWorkspace/LeftCommandPanel/TabContentPanel/TabMargin/TwoColumnWorkspace/LoadoutView/SpeedCard/SpeedMargin/SpeedVBox/SpeedRow/"
	var b1: Button = root.get_node_or_null(base_path + "Speed1xBtn") as Button
	var b2: Button = root.get_node_or_null(base_path + "Speed2xBtn") as Button
	var b4: Button = root.get_node_or_null(base_path + "Speed4xBtn") as Button
	setup(b1, b2, b4)


func setup(p_1x: Button, p_2x: Button, p_4x: Button) -> void:
	speed_1x_btn = p_1x
	speed_2x_btn = p_2x
	speed_4x_btn = p_4x

	if not speed_1x_btn or not speed_2x_btn or not speed_4x_btn:
		return

	current_game_speed = SaveManager.get_game_speed()
	UIFocusHelper.apply_cyber_focus(speed_1x_btn)
	UIFocusHelper.apply_cyber_focus(speed_2x_btn)
	UIFocusHelper.apply_cyber_focus(speed_4x_btn)

	speed_1x_btn.pressed.connect(func(): set_game_speed(1.0))
	speed_2x_btn.pressed.connect(func(): set_game_speed(2.0))
	speed_4x_btn.pressed.connect(func(): set_game_speed(4.0))

	refresh_ui()


func set_game_speed(speed: float) -> void:
	current_game_speed = speed
	SaveManager.set_game_speed(speed)
	refresh_ui()


func refresh_ui() -> void:
	_style_speed_button(speed_1x_btn, is_equal_approx(current_game_speed, 1.0), "1.0x")
	_style_speed_button(speed_2x_btn, is_equal_approx(current_game_speed, 2.0), "2.0x")
	_style_speed_button(speed_4x_btn, is_equal_approx(current_game_speed, 4.0), "4.0x")


func handle_shortcut(keycode: int) -> bool:
	match keycode:
		KEY_1:
			set_game_speed(1.0)
			return true
		KEY_2:
			set_game_speed(2.0)
			return true
		KEY_3:
			set_game_speed(4.0)
			return true
	return false


func _style_speed_button(btn: Button, is_active: bool, base_text: String) -> void:
	if not btn:
		return
	var sb := StyleBoxFlat.new()
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	if is_active:
		btn.text = "[ %s ]" % base_text
		sb.bg_color = Color(0.06, 0.26, 0.32, 1.0)
		sb.border_width_left = 2
		sb.border_width_top = 2
		sb.border_width_right = 2
		sb.border_width_bottom = 2
		sb.border_color = Color(0, 0.94, 1, 1)
		sb.shadow_color = Color(0, 0.94, 1, 0.35)
		sb.shadow_size = 3
		btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	else:
		btn.text = base_text
		sb.bg_color = Color(0.03, 0.05, 0.08, 0.75)
		sb.border_width_left = 1
		sb.border_width_top = 1
		sb.border_width_right = 1
		sb.border_width_bottom = 1
		sb.border_color = Color(0.2, 0.28, 0.38, 0.7)
		btn.add_theme_color_override("font_color", Color(0.65, 0.75, 0.85, 0.85))

	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_right = 4
	sb.corner_radius_bottom_left = 4
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	btn.add_theme_stylebox_override("pressed", sb)

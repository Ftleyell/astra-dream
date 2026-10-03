class_name CharacterSpeedSelector
extends RefCounted

## CharacterSpeedSelector.gd
## Controlador modular del selector de velocidad de juego para CharacterSelectUI.
## Gestiona los botones 1x, 2x, 4x, su persistencia en SaveManager y sus estilos Psycho-Pop.

var speed_1x_btn: Button = null
var speed_2x_btn: Button = null
var speed_4x_btn: Button = null
var current_game_speed: float = 1.0


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
	_style_speed_button(speed_1x_btn, is_equal_approx(current_game_speed, 1.0), "1x NORMAL")
	_style_speed_button(speed_2x_btn, is_equal_approx(current_game_speed, 2.0), "2x RÁPIDO")
	_style_speed_button(speed_4x_btn, is_equal_approx(current_game_speed, 4.0), "4x TURBO")


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
	if is_active:
		btn.text = "● %s" % base_text
		sb.bg_color = Color(0.06, 0.22, 0.28, 1.0)
		sb.border_width_left = 3
		sb.border_width_top = 3
		sb.border_width_right = 3
		sb.border_width_bottom = 3
		sb.border_color = Color(0, 0.94, 1, 1)
		sb.shadow_color = Color(0, 0.94, 1, 0.35)
		sb.shadow_size = 4
		btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	else:
		btn.text = "○ %s" % base_text
		sb.bg_color = Color(0.04, 0.04, 0.06, 0.8)
		sb.border_width_left = 1
		sb.border_width_top = 1
		sb.border_width_right = 1
		sb.border_width_bottom = 1
		sb.border_color = Color(0.25, 0.28, 0.35, 1.0)
		btn.add_theme_color_override("font_color", Color(0.65, 0.7, 0.78, 1))

	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_right = 4
	sb.corner_radius_bottom_left = 4
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	btn.add_theme_stylebox_override("pressed", sb)

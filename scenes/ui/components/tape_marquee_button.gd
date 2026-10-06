class_name TapeMarqueeButton
extends Control

## TapeMarqueeButton.gd
## Botón de cinta de advertencia perimetral continua tipo hazard/arcade (WAITING / LAUNCH).
## Genera texturas dinámicas con SystemFont de alto impacto sin distorsión óptica,
## calculando repeticiones 1:1 en función del ancho de pantalla / contenedor.

signal pressed

const SHADER_TAPE: Shader = preload("res://shaders/ui/tape_marquee.gdshader")

@export var color_waiting: Color = Color(0.92, 0.12, 0.12, 1.0) # Rojo reposo
@export var color_launch: Color = Color(0.08, 0.90, 0.35, 1.0)  # Verde táctico
@export var color_disabled: Color = Color(0.35, 0.38, 0.42, 0.8) # Gris inactivo
@export var tape_height: float = 90.0
@export var is_disabled: bool = false:
	set(val):
		is_disabled = val
		_update_disabled_state()

var _tape_rect: ColorRect = null
var _tape_mat: ShaderMaterial = null

var _current_color: Color = Color(0.92, 0.12, 0.12, 1.0)
var _target_color: Color = Color(0.92, 0.12, 0.12, 1.0)
var _target_scale_y: float = 1.0

var _tex_waiting: Texture2D = null
var _tex_launch: Texture2D = null
var _width_waiting: float = 320.0
var _width_launch: float = 300.0
var _repetitions_waiting: float = 6.0
var _repetitions_launch: float = 6.4
var _last_rendered_width: float = 0.0
var _is_focused_or_hovered: bool = false


func _ready() -> void:
	custom_minimum_size = Vector2(0.0, tape_height)
	pivot_offset = Vector2(size.x * 0.5, tape_height * 0.5)

	focus_mode = FOCUS_ALL
	mouse_filter = MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	mouse_entered.connect(_on_focus_entered)
	mouse_exited.connect(_on_focus_exited)
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)

	_setup_textures()
	_setup_visuals()
	_update_repetitions()
	_update_disabled_state()


func _setup_textures() -> void:
	var data_waiting: Dictionary = _create_text_module("WAITING")
	_tex_waiting = data_waiting.get("texture", null)
	_width_waiting = float(data_waiting.get("width", 320.0))

	var data_launch: Dictionary = _create_text_module("LAUNCH")
	_tex_launch = data_launch.get("texture", null)
	_width_launch = float(data_launch.get("width", 300.0))


func _setup_visuals() -> void:
	_tape_mat = ShaderMaterial.new()
	_tape_mat.shader = SHADER_TAPE
	_tape_mat.set_shader_parameter("text_mask", _tex_waiting)
	_tape_mat.set_shader_parameter("repetitions_x", _repetitions_waiting)
	_tape_mat.set_shader_parameter("scroll_speed", 0.4)
	_tape_mat.set_shader_parameter("tape_color", color_waiting)

	_tape_rect = ColorRect.new()
	_tape_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tape_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tape_rect.material = _tape_mat
	add_child(_tape_rect)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		pivot_offset = Vector2(size.x * 0.5, tape_height * 0.5)
		_update_repetitions()


func _update_repetitions() -> void:
	var current_w: float = size.x
	if current_w <= 10.0 and is_inside_tree():
		current_w = get_viewport_rect().size.x
	if current_w <= 10.0:
		current_w = 1920.0

	_last_rendered_width = current_w
	_repetitions_waiting = current_w / maxf(1.0, _width_waiting)
	_repetitions_launch = current_w / maxf(1.0, _width_launch)

	if _tape_mat:
		var rep: float = _repetitions_launch if _is_focused_or_hovered else _repetitions_waiting
		_tape_mat.set_shader_parameter("repetitions_x", rep)


func _process(delta: float) -> void:
	if not is_equal_approx(size.x, _last_rendered_width) and size.x > 10.0:
		_update_repetitions()

	_current_color = _current_color.lerp(_target_color, 12.0 * delta)
	if _tape_mat:
		_tape_mat.set_shader_parameter("tape_color", _current_color)

	scale.y = lerpf(scale.y, _target_scale_y, 12.0 * delta)


func _gui_input(event: InputEvent) -> void:
	if is_disabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		pressed.emit()
		accept_event()
	elif event.is_action_pressed("ui_accept"):
		pressed.emit()
		accept_event()


func _on_focus_entered() -> void:
	if is_disabled:
		return
	_is_focused_or_hovered = true
	_target_color = color_launch
	_target_scale_y = 1.15
	if _tape_mat:
		_tape_mat.set_shader_parameter("text_mask", _tex_launch)
		_tape_mat.set_shader_parameter("repetitions_x", _repetitions_launch)
		_tape_mat.set_shader_parameter("scroll_speed", 0.9)


func _on_focus_exited() -> void:
	if is_disabled:
		return
	_is_focused_or_hovered = false
	_target_color = color_waiting
	_target_scale_y = 1.0
	if _tape_mat:
		_tape_mat.set_shader_parameter("text_mask", _tex_waiting)
		_tape_mat.set_shader_parameter("repetitions_x", _repetitions_waiting)
		_tape_mat.set_shader_parameter("scroll_speed", 0.4)


func _update_disabled_state() -> void:
	focus_mode = FOCUS_NONE if is_disabled else FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_ARROW if is_disabled else Control.CURSOR_POINTING_HAND
	if is_disabled:
		_target_color = color_disabled
		_target_scale_y = 1.0
		if _tape_mat:
			_tape_mat.set_shader_parameter("scroll_speed", 0.15)
	else:
		if _is_focused_or_hovered:
			_on_focus_entered()
		else:
			_on_focus_exited()


func _create_text_module(word: String) -> Dictionary:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Impact", "Arial Black", "Trebuchet MS", "sans-serif"])
	font.font_weight = 900
	font.font_stretch = 75

	var font_size: int = 58
	var text_size: Vector2 = font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)

	var dash_width: float = 36.0
	var dash_height: float = 12.0
	var spacing: float = 20.0

	var total_w: int = int(ceil(text_size.x + spacing + dash_width + spacing))
	var total_h: int = int(tape_height)

	var vp := SubViewport.new()
	vp.size = Vector2i(total_w, total_h)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	var root := Control.new()
	root.size = Vector2(float(total_w), float(total_h))
	vp.add_child(root)

	# Label del texto
	var label := Label.new()
	label.text = word
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.position = Vector2(0.0, (float(total_h) - text_size.y) * 0.5 + 2.0)
	root.add_child(label)

	# Guión delimitador horizontal centrado
	var dash := ColorRect.new()
	dash.color = Color.WHITE
	dash.size = Vector2(dash_width, dash_height)
	dash.position = Vector2(text_size.x + spacing, (float(total_h) - dash_height) * 0.5)
	root.add_child(dash)

	add_child(vp)

	return {
		"texture": vp.get_texture(),
		"width": float(total_w)
	}

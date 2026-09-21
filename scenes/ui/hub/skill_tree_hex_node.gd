class_name SkillTreeHexNode
extends Control

## SkillTreeHexNode.gd
## Nodo hexagonal procedimental para el Árbol de Habilidades en constelación radial.
## Renderiza un hexágono cibernético con estados (Locked, Available, Unlocked, Selected),
## biseles de luz, icono temático y respuesta a clics del ratón.

signal selected(node_ref: SkillTreeHexNode)
signal hovered(node_ref: SkillTreeHexNode, is_hovered: bool)

enum State {
	LOCKED,
	AVAILABLE,
	UNLOCKED
}

@export var node_id: StringName = &"speed_1"
@export var title: String = "IMPULSO CINÉTICO I"
@export var branch_name: String = "VELOCIDAD"
@export var stat_bonus_text: String = "+20% Velocidad de Movimiento"
@export var glyph_icon: String = "⚡"
@export var cost: int = 25
@export var req_node_id: StringName = &"core"

var hex_radius: float = 34.0
var state: State = State.LOCKED
var is_selected: bool = false
var theme_color: Color = Color("#00F0FF") # Color insignia de la piloto

var _is_hovered: bool = false
var _pulse_timer: float = 0.0


func _init() -> void:
	custom_minimum_size = Vector2(76, 76)
	size = Vector2(76, 76)
	pivot_offset = Vector2(38, 38)
	mouse_filter = MOUSE_FILTER_STOP


func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func _process(delta: float) -> void:
	if state == State.AVAILABLE:
		_pulse_timer += delta * 4.0
		queue_redraw()


func set_node_state(new_state: State, selected_flag: bool = false) -> void:
	state = new_state
	is_selected = selected_flag
	queue_redraw()


func set_theme_color(col: Color) -> void:
	theme_color = col
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var pts := _calculate_hex_points(center, hex_radius)
	var closed_pts := pts.duplicate()
	closed_pts.append(pts[0])

	# 1. Relleno y borde base según estado
	match state:
		State.UNLOCKED:
			var fill_col := Color(theme_color.r, theme_color.g, theme_color.b, 0.45)
			draw_colored_polygon(pts, fill_col)
			draw_polyline(closed_pts, theme_color, 3.0, true)

			# Anillo interno de circuito brillante
			var inner_pts := _calculate_hex_points(center, hex_radius * 0.72)
			inner_pts.append(inner_pts[0])
			draw_polyline(inner_pts, theme_color.lightened(0.4), 1.5, true)

		State.AVAILABLE:
			# Efecto pulsante para indicar que se puede activar
			var pulse := (sin(_pulse_timer) + 1.0) * 0.5
			var fill_col := Color(theme_color.r * 0.18, theme_color.g * 0.18, theme_color.b * 0.18, 0.85)
			draw_colored_polygon(pts, fill_col)
			var border_col := theme_color.lerp(Color.WHITE, pulse * 0.5)
			draw_polyline(closed_pts, border_col, 2.5, true)

		State.LOCKED:
			var fill_col := Color(0.05, 0.06, 0.08, 0.9)
			draw_colored_polygon(pts, fill_col)
			draw_polyline(closed_pts, Color(0.22, 0.25, 0.3, 0.7), 1.5, true)

	# 2. Resaltado de selección activa
	if is_selected:
		var sel_pts := _calculate_hex_points(center, hex_radius + 6.0)
		sel_pts.append(sel_pts[0])
		draw_polyline(sel_pts, Color.WHITE, 2.0, true)

	# 3. Dibujar glifo / icono central
	var font := ThemeDB.fallback_font
	var font_size: int = 24 if node_id == &"core" else 18
	var text_col: Color
	match state:
		State.UNLOCKED:
			text_col = Color.WHITE
		State.AVAILABLE:
			text_col = theme_color.lightened(0.5)
		State.LOCKED:
			text_col = Color(0.4, 0.45, 0.5, 0.6)

	var text_str := glyph_icon
	if state == State.LOCKED and node_id != &"core":
		text_str = "🔒"

	var text_size := font.get_string_size(text_str, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var text_pos := center - Vector2(text_size.x * 0.5, -text_size.y * 0.32)
	draw_string(font, text_pos, text_str, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, text_col)


func _calculate_hex_points(center: Vector2, radius: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	# Hexágono con orientación simétrica vertical (flat top: 30° de desfase)
	for i in range(6):
		var angle: float = (PI / 3.0) * float(i) + (PI / 6.0)
		pts.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return pts


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var audio_mgr := get_node_or_null("/root/AudioManager")
		if audio_mgr and audio_mgr.has_method("play_sfx"):
			audio_mgr.play_sfx("ui_click")
		selected.emit(self)
		accept_event()


func _on_mouse_entered() -> void:
	_is_hovered = true
	var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2(1.12, 1.12), 0.14)
	hovered.emit(self, true)


func _on_mouse_exited() -> void:
	_is_hovered = false
	var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2.ONE, 0.14)
	hovered.emit(self, false)

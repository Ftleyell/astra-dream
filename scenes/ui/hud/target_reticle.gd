class_name TargetReticle
extends Node2D

## TargetReticle.gd
## Retícula sutil de fijación de objetivo (Lock-On Reticle) estilo arcade / cyberpunk.
## Sigue la posición del objetivo fijado actualmente por el auto-apuntado pasivo.

@export var reticle_color: Color = Color(0.2, 0.9, 1.0, 0.85)
@export var reticle_size: float = 24.0

var target: Node2D = null
var pulse_time: float = 0.0

func _ready() -> void:
	z_index = 30
	visible = false

func set_target(p_target: Node2D) -> void:
	target = p_target
	if is_instance_valid(target) and not target.get("is_dying"):
		visible = true
		global_position = target.global_position
	else:
		visible = false

func _process(delta: float) -> void:
	if not is_instance_valid(target) or target.get("is_dying"):
		visible = false
		target = null
		return

	visible = true
	# Seguir suavemente al objetivo
	global_position = global_position.lerp(target.global_position, 28.0 * delta)

	pulse_time += delta * 6.0
	queue_redraw()

func _draw() -> void:
	var r := reticle_size + sin(pulse_time) * 2.0
	var col := reticle_color
	var line_w := 2.0
	var corner_len := r * 0.45

	# Cuatro esquinas / corchetes de lock-on táctico
	# Esquina Superior-Izquierda
	draw_line(Vector2(-r, -r), Vector2(-r + corner_len, -r), col, line_w)
	draw_line(Vector2(-r, -r), Vector2(-r, -r + corner_len), col, line_w)

	# Esquina Superior-Derecha
	draw_line(Vector2(r, -r), Vector2(r - corner_len, -r), col, line_w)
	draw_line(Vector2(r, -r), Vector2(r, -r + corner_len), col, line_w)

	# Esquina Inferior-Izquierda
	draw_line(Vector2(-r, r), Vector2(-r + corner_len, r), col, line_w)
	draw_line(Vector2(-r, r), Vector2(-r, -r + corner_len), col, line_w)

	# Esquina Inferior-Derecha
	draw_line(Vector2(r, r), Vector2(r - corner_len, r), col, line_w)
	draw_line(Vector2(r, r), Vector2(r, r - corner_len), col, line_w)

	# Punto central sutil
	draw_circle(Vector2.ZERO, 2.5, Color(col.r, col.g, col.b, 0.6))

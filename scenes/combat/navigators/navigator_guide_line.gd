class_name NavigatorGuideLine
extends Node2D

## Línea holográfica y retícula de radar entre el jugador y el objetivo marcado.

signal target_reached(target_node: Node2D)
signal expired()

var player: Node2D = null
var target_node: Node2D = null
var target_position: Vector2 = Vector2.ZERO
var theme_color: Color = Color(0, 0.94, 1, 1)

var lifetime: float = 28.0
var pulse_time: float = 0.0
var is_active: bool = true
var is_fading: bool = false
var fade_alpha: float = 1.0

const REACH_RADIUS: float = 140.0
const DASH_LENGTH: float = 28.0
const GAP_LENGTH: float = 14.0

func setup(p_player: Node2D, p_target: Node2D, p_color: Color, p_lifetime: float = 28.0) -> void:
	player = p_player
	target_node = p_target
	theme_color = p_color
	lifetime = p_lifetime
	z_index = 25 # Encima del fondo y proyectiles normales, debajo de HUD
	if is_instance_valid(target_node):
		target_position = target_node.global_position

func _process(delta: float) -> void:
	if not is_active:
		return

	pulse_time += delta
	lifetime -= delta

	if lifetime <= 0.0 and not is_fading:
		fade_out()

	if is_fading:
		fade_alpha = maxf(0.0, fade_alpha - delta * 3.0)
		if fade_alpha <= 0.0:
			is_active = false
			expired.emit()
			queue_free()
			return

	if not is_instance_valid(player):
		queue_free()
		return

	# Si el nodo objetivo sigue vivo, actualizar su posición
	if is_instance_valid(target_node):
		target_position = target_node.global_position
	else:
		# Si el nodo fue destruido / recogido por el jugador mientras nos acercábamos, cuenta como alcanzado
		if player.global_position.distance_to(target_position) <= 900.0:
			_on_reached()
			return
		elif not is_fading:
			fade_out()
			return

	# Comprobar distancia de proximidad al objetivo
	var dist := player.global_position.distance_to(target_position)
	if dist <= REACH_RADIUS:
		_on_reached()
		return

	queue_redraw()

func _on_reached() -> void:
	is_active = false
	var valid_target: Node2D = target_node if is_instance_valid(target_node) else null
	target_reached.emit(valid_target)
	_play_reached_effect()

func _play_reached_effect() -> void:
	var tw := create_tween()
	tw.tween_method(func(v: float):
		fade_alpha = v
		queue_redraw()
	, 1.0, 0.0, 0.35)
	tw.finished.connect(queue_free)

func fade_out() -> void:
	is_fading = true

func _draw() -> void:
	if not is_instance_valid(player) or fade_alpha <= 0.0:
		return

	var start_pos := to_local(player.global_position)
	var end_pos := to_local(target_position)

	var dir := end_pos - start_pos
	var total_dist := dir.length()
	if total_dist < 10.0:
		return

	var unit_dir := dir.normalized()
	var pulse_glow := (0.65 + 0.35 * sin(pulse_time * 7.0)) * fade_alpha
	var main_col := Color(theme_color.r, theme_color.g, theme_color.b, pulse_glow * 0.85)
	var glow_col := Color(theme_color.r, theme_color.g, theme_color.b, pulse_glow * 0.35)

	# 1. Dibujar línea discontinua con animación de flujo cuántico hacia el objetivo
	var offset_anim := fmod(pulse_time * 60.0, DASH_LENGTH + GAP_LENGTH)
	var current_dist := offset_anim
	while current_dist < total_dist:
		var seg_start := start_pos + unit_dir * current_dist
		var seg_end := start_pos + unit_dir * minf(current_dist + DASH_LENGTH, total_dist)
		# Glow ancho
		draw_line(seg_start, seg_end, glow_col, 5.0, true)
		# Centro nítido
		draw_line(seg_start, seg_end, main_col, 2.0, true)
		current_dist += DASH_LENGTH + GAP_LENGTH

	# 2. Retícula / anillo pulsante en el objetivo
	var reticle_radius := (28.0 + 4.0 * sin(pulse_time * 5.0))
	draw_arc(end_pos, reticle_radius, 0.0, TAU, 32, main_col, 2.5, true)
	draw_arc(end_pos, reticle_radius + 8.0, 0.0, TAU, 32, glow_col, 1.5, true)

	# 4 miras cardinales en la retícula del objetivo
	var cross_len := 12.0
	draw_line(end_pos + Vector2(reticle_radius, 0), end_pos + Vector2(reticle_radius + cross_len, 0), main_col, 2.0)
	draw_line(end_pos - Vector2(reticle_radius, 0), end_pos - Vector2(reticle_radius + cross_len, 0), main_col, 2.0)
	draw_line(end_pos + Vector2(0, reticle_radius), end_pos + Vector2(0, reticle_radius + cross_len), main_col, 2.0)
	draw_line(end_pos - Vector2(0, reticle_radius), end_pos - Vector2(0, reticle_radius + cross_len), main_col, 2.0)

	# Anillo suave de origen en el jugador
	draw_arc(start_pos, 22.0, 0.0, TAU, 24, glow_col, 1.5, true)

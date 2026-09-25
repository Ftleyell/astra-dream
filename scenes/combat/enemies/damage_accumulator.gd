class_name DamageAccumulator
extends Node2D

@export var window_duration: float = 0.85
@export var base_vertical_offset: float = -28.0
@export var max_float_offset: float = -10.0
@export var death_linger_duration: float = 0.75

const COLOR_TERMINAL_GREEN := Color(0.2, 1.0, 0.35, 1.0) # Verde fósforo terminal clásico
const COLOR_TERMINAL_CRIT := Color(0.8, 1.0, 0.2, 1.0)   # Verde terminal lima brillante para críticos

@onready var label: Label = $Label

var current_accumulated_damage: float = 0.0
var window_timer: float = 0.0
var parent_node: Node2D = null
var is_active: bool = false
var is_dying_linger: bool = false
var _punch_tween: Tween = null
var _linger_tween: Tween = null

func _ready() -> void:
	visible = false
	top_level = true
	z_index = 20
	parent_node = get_parent() as Node2D
	if not label:
		label = get_node_or_null("Label") as Label
	if label:
		label.text = ""
		label.add_theme_color_override("font_color", COLOR_TERMINAL_GREEN)

func register_hit(damage: float, is_crit: bool = false) -> void:
	if is_dying_linger:
		return

	if not is_instance_valid(parent_node):
		return

	current_accumulated_damage += damage
	window_timer = window_duration
	is_active = true
	visible = true
	modulate.a = 1.0

	if label:
		label.text = str(int(roundf(current_accumulated_damage)))
		if is_crit:
			label.add_theme_color_override("font_color", COLOR_TERMINAL_CRIT)
			label.add_theme_font_size_override("font_size", 16)
		else:
			label.add_theme_color_override("font_color", COLOR_TERMINAL_GREEN)
			label.add_theme_font_size_override("font_size", 14)

	# Fijar posición sobre el enemigo con rotación neutral
	global_position = parent_node.global_position + Vector2(0.0, base_vertical_offset)
	global_rotation = 0.0

	# Animación de rebote elástico (Punch Pop)
	if _punch_tween and _punch_tween.is_valid():
		_punch_tween.kill()

	var pop_scale := Vector2(1.4, 1.4) if is_crit else Vector2(1.22, 1.22)
	scale = pop_scale
	_punch_tween = create_tween()
	_punch_tween.tween_property(self, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _process(delta: float) -> void:
	if is_dying_linger:
		return

	if not is_active or not visible:
		return

	if not is_instance_valid(parent_node) or parent_node.get("is_dying") == true:
		clear_on_death()
		return

	window_timer -= delta

	# Flotar sutilmente hacia arriba durante la ventana de acumulación
	var progress: float = 1.0 - clampf(window_timer / window_duration, 0.0, 1.0)
	var float_y := lerpf(base_vertical_offset, base_vertical_offset + max_float_offset, progress)
	global_position = parent_node.global_position + Vector2(0.0, float_y)
	global_rotation = 0.0

	# Desvanecimiento en los últimos 0.25s
	if window_timer <= 0.25:
		modulate.a = maxf(0.0, window_timer / 0.25)

	if window_timer <= 0.0:
		is_active = false
		visible = false
		current_accumulated_damage = 0.0
		modulate.a = 1.0
		if label:
			label.text = ""

func clear_on_death() -> void:
	if is_dying_linger:
		return

	# Si no estaba activo o no tenía daño acumulado, destruir de inmediato
	if not is_active or current_accumulated_damage <= 0.0 or not is_inside_tree():
		is_active = false
		visible = false
		queue_free()
		return

	is_dying_linger = true
	is_active = false

	# Desacoplar del enemigo para no ser eliminado cuando el enemigo ejecute queue_free()
	var new_parent: Node = null
	if is_instance_valid(parent_node) and is_instance_valid(parent_node.get_parent()):
		new_parent = parent_node.get_parent()
	elif get_tree() and get_tree().current_scene:
		new_parent = get_tree().current_scene

	if new_parent and get_parent() != new_parent and is_inside_tree():
		reparent(new_parent, true)

	parent_node = null

	if _punch_tween and _punch_tween.is_valid():
		_punch_tween.kill()

	# Animación de supervivencia en pantalla (Linger):
	# Flota hacia arriba suavemente y se desvanece tras permanecer visible unos instantes
	if _linger_tween and _linger_tween.is_valid():
		_linger_tween.kill()

	_linger_tween = create_tween()
	_linger_tween.set_parallel(true)
	_linger_tween.tween_property(self, "global_position:y", global_position.y - 24.0, death_linger_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_linger_tween.tween_property(self, "modulate:a", 0.0, death_linger_duration * 0.45).set_delay(death_linger_duration * 0.55)
	_linger_tween.chain().tween_callback(queue_free)

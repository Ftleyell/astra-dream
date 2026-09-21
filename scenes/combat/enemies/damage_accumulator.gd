class_name DamageAccumulator
extends Node2D

@export var window_duration: float = 0.85
@export var base_vertical_offset: float = -28.0
@export var max_float_offset: float = -10.0

@onready var label: Label = $Label

var current_accumulated_damage: float = 0.0
var window_timer: float = 0.0
var parent_node: Node2D = null
var is_active: bool = false
var _punch_tween: Tween = null

func _ready() -> void:
	visible = false
	top_level = true
	z_index = 20
	parent_node = get_parent() as Node2D
	if not label:
		label = get_node_or_null("Label") as Label
	if label:
		label.text = ""

func register_hit(damage: float, is_crit: bool = false) -> void:
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
			label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0))
			label.add_theme_font_size_override("font_size", 16)
		else:
			label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
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
	is_active = false
	visible = false
	current_accumulated_damage = 0.0
	window_timer = 0.0
	if _punch_tween and _punch_tween.is_valid():
		_punch_tween.kill()
	if label:
		label.text = ""

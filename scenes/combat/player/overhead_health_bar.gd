class_name OverheadHealthBar
extends Node2D

## Anillo Diegético de Salud: Se renderiza por debajo de la nave como un anillo verde continuo de 360°.
## Se vacía en sentido horario con suavizado al perder vida, destella al recibir daño y pulsa en rojo con poca vida.

@export var player: Player

@onready var health_bar: ProgressBar = get_node_or_null("ProgressBar")
@onready var percent_label: Label = get_node_or_null("PercentLabel")

const HEALTH_RING_RADIUS: float = 46.0
const RING_WIDTH: float = 6.5

var current_health: float = 100.0
var max_health: float = 100.0
var target_ratio: float = 1.0
var displayed_ratio: float = 1.0

var flash_timer: float = 0.0
var pulse_time: float = 0.0
var hp_numeric_label: Label = null

func _ready() -> void:
	z_index = -1
	if get_parent() is Player:
		position = Vector2.ZERO

	# Ocultar las antiguas barras rectangulares si existen en la escena
	if health_bar:
		health_bar.visible = false
	if percent_label:
		percent_label.visible = false

	_setup_hp_numeric_label()

	if not player and get_parent() is Player:
		player = get_parent() as Player

	if player:
		player.health_changed.connect(_on_health_changed)
		if player.stats:
			_update_display(player.current_health, player.stats.get_stat(&"max_health"))
		else:
			_update_display(player.current_health, 100.0)

func _setup_hp_numeric_label() -> void:
	if not hp_numeric_label:
		hp_numeric_label = Label.new()
		hp_numeric_label.name = "HPNumericLabel"
		hp_numeric_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hp_numeric_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		# Color CRT retro verde consola
		hp_numeric_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4, 0.95))
		hp_numeric_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.15, 0.05, 0.9))
		hp_numeric_label.add_theme_constant_override("shadow_offset_x", 1)
		hp_numeric_label.add_theme_constant_override("shadow_offset_y", 1)
		hp_numeric_label.add_theme_font_size_override("font_size", 12)
		hp_numeric_label.custom_minimum_size = Vector2(120, 20)
		hp_numeric_label.size = Vector2(120, 20)
		hp_numeric_label.pivot_offset = Vector2(60, 10)
		hp_numeric_label.position = Vector2(-60, 52)
		add_child(hp_numeric_label)

func _process(delta: float) -> void:
	pulse_time += delta
	if flash_timer > 0.0:
		flash_timer = maxf(0.0, flash_timer - delta)

	# Interpolación suave del arco
	if absf(displayed_ratio - target_ratio) > 0.001:
		displayed_ratio = lerpf(displayed_ratio, target_ratio, 14.0 * delta)
	else:
		displayed_ratio = target_ratio

	queue_redraw()

func _on_health_changed(current: float, max_val: float) -> void:
	if current < current_health:
		flash_timer = 0.14
	_update_display(current, max_val)

func _update_display(current: float, max_val: float) -> void:
	current_health = current
	max_health = maxf(1.0, max_val)
	target_ratio = clampf(current_health / max_health, 0.0, 1.0)
	if hp_numeric_label:
		hp_numeric_label.text = "%d / %d" % [int(ceil(current_health)), int(ceil(max_health))]
		if displayed_ratio <= 0.25:
			hp_numeric_label.modulate = Color(1.0, 0.3, 0.35, 1.0)
		elif displayed_ratio <= 0.5:
			hp_numeric_label.modulate = Color(1.0, 0.85, 0.25, 1.0)
		else:
			hp_numeric_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
	queue_redraw()

func _draw() -> void:
	# 1. Halo de fondo oscuro transparente (indica la capacidad total máxima)
	var bg_col := Color(0.04, 0.14, 0.08, 0.45)
	draw_arc(Vector2.ZERO, HEALTH_RING_RADIUS, 0, TAU, 48, bg_col, RING_WIDTH, true)

	if displayed_ratio <= 0.001:
		return

	# 2. Color reactivo del anillo
	var ring_col := Color(0.18, 0.95, 0.45, 0.92)
	if flash_timer > 0.0:
		ring_col = Color(1.8, 1.8, 1.8, 1.0)
	elif displayed_ratio <= 0.25:
		var p := 0.65 + sin(pulse_time * 8.0) * 0.35
		ring_col = Color(1.0, 0.2, 0.25, p)
	elif displayed_ratio <= 0.5:
		ring_col = Color(1.0, 0.8, 0.2, 0.95)

	# 3. Dibujar arco activo de vida en sentido horario desde la cima (-PI / 2)
	var start_angle := -PI / 2.0
	var end_angle := start_angle + (TAU * displayed_ratio)
	var point_count := maxi(8, int(48 * displayed_ratio))
	draw_arc(Vector2.ZERO, HEALTH_RING_RADIUS, start_angle, end_angle, point_count, ring_col, RING_WIDTH, true)

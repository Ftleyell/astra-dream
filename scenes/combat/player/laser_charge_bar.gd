class_name LaserChargeBar
extends Node2D

@export var weapon_controller: WeaponController

var is_charging: bool = false
var charge_ratio: float = 0.0
var is_full: bool = false
var is_memorized: bool = false
var pulse_time: float = 0.0

const BAR_WIDTH: float = 46.0
const BAR_HEIGHT: float = 5.0

func _ready() -> void:
	z_index = 25
	visible = false
	if not weapon_controller and get_parent():
		weapon_controller = get_parent().get_node_or_null("WeaponController") as WeaponController
	if weapon_controller:
		weapon_controller.laser_charge_updated.connect(_on_charge_updated)
		weapon_controller.laser_charge_ended.connect(_on_charge_ended)

func _process(delta: float) -> void:
	if is_charging:
		if is_full or is_memorized:
			pulse_time += delta * 14.0
		queue_redraw()

func _on_charge_updated(current: float, max_val: float, p_is_full: bool, p_is_memorized: bool = false) -> void:
	is_charging = true
	visible = true
	charge_ratio = clampf(current / maxf(0.001, max_val), 0.0, 1.0)
	is_full = p_is_full
	is_memorized = p_is_memorized
	queue_redraw()

func _on_charge_ended() -> void:
	is_charging = false
	is_full = false
	is_memorized = false
	charge_ratio = 0.0
	pulse_time = 0.0
	visible = false
	queue_redraw()

func _draw() -> void:
	if not is_charging:
		return

	var half_w := BAR_WIDTH / 2.0
	var rect_bg := Rect2(-half_w, -BAR_HEIGHT / 2.0, BAR_WIDTH, BAR_HEIGHT)

	# Borde exterior oscuro
	draw_rect(rect_bg.grow(1.0), Color(0.02, 0.04, 0.12, 0.95), false, 1.0)
	# Fondo azul oscuro espacial
	draw_rect(rect_bg, Color(0.04, 0.08, 0.22, 0.88), true)

	# Relleno de carga: gradiente visual de azul oscuro/medio a celeste neón brillante
	var fill_w := BAR_WIDTH * charge_ratio
	if fill_w > 0.0:
		var fill_rect := Rect2(-half_w, -BAR_HEIGHT / 2.0, fill_w, BAR_HEIGHT)
		var fill_color: Color
		if is_full:
			# Resplandor/destello de máxima carga entre celeste brillante y blanco puro
			var pulse := (sin(pulse_time) + 1.0) * 0.5
			fill_color = Color(0.35, 0.9, 1.0).lerp(Color(1.0, 1.0, 1.0), pulse * 0.9)
		elif is_memorized:
			# Modo memoria: pulso eléctrico celeste indicando carga retenida tras pausa
			var pulse := (sin(pulse_time) + 1.0) * 0.5
			fill_color = Color(0.2, 0.75, 1.0).lerp(Color(0.7, 0.95, 1.0), pulse * 0.7)
		else:
			# Interpolación estándar de azul a celeste eléctrico
			fill_color = Color(0.08, 0.32, 0.82).lerp(Color(0.2, 0.88, 1.0), charge_ratio)

		draw_rect(fill_rect, fill_color, true)

		if is_full:
			# Halo luminoso perimetral al completar la carga
			draw_rect(rect_bg.grow(1.5), Color(0.4, 0.92, 1.0, 0.6), false, 1.0)
		elif is_memorized:
			# Borde brillante sutil en modo memoria retenida
			var pulse := (sin(pulse_time) + 1.0) * 0.5
			draw_rect(rect_bg.grow(1.2), Color(0.3, 0.85, 1.0, 0.3 + pulse * 0.4), false, 1.0)

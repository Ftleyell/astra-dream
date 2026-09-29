class_name LaserChargeBar
extends Node2D

## Anillo Diegético de Carga de Láser: Anillo azul eléctrico exterior concéntrico que abraza al anillo verde de vida.
## Solo se muestra mientras se carga el láser, relumbra con destellos al 100% (listo) y se desvanece suavemente al disparar.

@export var weapon_controller: WeaponController

const LASER_RING_RADIUS: float = 57.0
const LASER_RING_WIDTH: float = 5.0

var is_charging: bool = false
var charge_ratio: float = 0.0
var displayed_ratio: float = 0.0
var is_full: bool = false
var is_memorized: bool = false
var pulse_time: float = 0.0
var fade_alpha: float = 0.0

func _ready() -> void:
	z_index = -1
	if get_parent() is Player:
		position = Vector2.ZERO
	visible = false

	if not weapon_controller and get_parent():
		weapon_controller = get_parent().get_node_or_null("WeaponController") as WeaponController
	if weapon_controller:
		weapon_controller.laser_charge_updated.connect(_on_charge_updated)
		weapon_controller.laser_charge_ended.connect(_on_charge_ended)

func _process(delta: float) -> void:
	if is_charging:
		fade_alpha = move_toward(fade_alpha, 1.0, delta * 6.0)
		if is_full or is_memorized:
			pulse_time += delta * 14.0
		else:
			pulse_time += delta * 6.0
	else:
		fade_alpha = move_toward(fade_alpha, 0.0, delta * 4.5)
		if fade_alpha <= 0.001:
			visible = false

	# Interpolación de ratio de carga
	if absf(displayed_ratio - charge_ratio) > 0.001:
		displayed_ratio = lerpf(displayed_ratio, charge_ratio, 16.0 * delta)
	else:
		displayed_ratio = charge_ratio

	if visible:
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
	queue_redraw()

func _draw() -> void:
	if fade_alpha <= 0.01:
		return

	# 1. Halo de fondo espacial azul oscuro
	var bg_col := Color(0.03, 0.10, 0.24, 0.38 * fade_alpha)
	draw_arc(Vector2.ZERO, LASER_RING_RADIUS, 0, TAU, 56, bg_col, LASER_RING_WIDTH, true)

	if displayed_ratio <= 0.001:
		return

	# 2. Color del arco según estado de carga
	var laser_col: Color
	if is_full:
		# Sobrecarga máxima: resplandor pulsante entre celeste brillante y blanco eléctrico
		var pulse := (sin(pulse_time) + 1.0) * 0.5
		laser_col = Color(0.4, 0.92, 1.0).lerp(Color(1.0, 1.0, 1.0), pulse * 0.85)
		laser_col.a *= fade_alpha
	elif is_memorized:
		# Modo memoria: pulso eléctrico celeste
		var pulse := (sin(pulse_time) + 1.0) * 0.5
		laser_col = Color(0.2, 0.78, 1.0, (0.7 + pulse * 0.3) * fade_alpha)
	else:
		# Azul eléctrico a cian neón progresivo
		laser_col = Color(0.12, 0.45, 0.95).lerp(Color(0.2, 0.88, 1.0), displayed_ratio)
		laser_col.a *= (0.85 * fade_alpha)

	# 3. Dibujar arco concéntrico de carga en sentido horario desde arriba (-PI / 2)
	var start_angle := -PI / 2.0
	var end_angle := start_angle + (TAU * displayed_ratio)
	var point_count := maxi(8, int(56 * displayed_ratio))
	draw_arc(Vector2.ZERO, LASER_RING_RADIUS, start_angle, end_angle, point_count, laser_col, LASER_RING_WIDTH, true)

	# 4. Halo extra radiante al 100% de carga
	if is_full and fade_alpha > 0.5:
		var p_halo := (sin(pulse_time * 1.2) + 1.0) * 0.5
		var halo_col := Color(0.5, 0.95, 1.0, (0.35 + p_halo * 0.35) * fade_alpha)
		draw_arc(Vector2.ZERO, LASER_RING_RADIUS + 2.2, 0, TAU, 56, halo_col, 2.0, true)

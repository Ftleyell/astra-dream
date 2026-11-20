class_name PlanarLabStar
extends Node2D
## Estrella luminosa procedural para el Planar Combat Rig Lab.
## Emite luz dinámica que cambia de color suavemente a lo largo de un espectro
## estelar mientras el personaje orbita a su alrededor.

const SPECTRAL_PALETTE: Array[Color] = [
	Color(1.00, 0.84, 0.42, 1.0), # Sol dorado
	Color(0.30, 0.86, 1.00, 1.0), # Gigante azul cian
	Color(0.80, 0.38, 1.00, 1.0), # Púlsar violeta
	Color(1.00, 0.30, 0.48, 1.0), # Supergigante carmesí
	Color(0.30, 1.00, 0.66, 1.0), # Nova esmeralda
]

@export var orbit_radius: float = 165.0
@export var color_cycle_speed: float = 0.28

var _time: float = 0.0
var _current_color: Color = SPECTRAL_PALETTE[0]
var _target_world_pos: Vector2 = Vector2(165.0, 0.0)


func _ready() -> void:
	z_index = 5
	_update_color()
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	_update_color()
	queue_redraw()


func set_target_world_pos(pos: Vector2) -> void:
	_target_world_pos = pos


func get_star_color() -> Color:
	return _current_color


func get_key_light_tint(base_tint: Color) -> Color:
	# Tinta la luz clave del shader cel con el color estelar sin oscurecer la luminancia base.
	var vivid := Color(
		lerpf(1.0, _current_color.r, 0.72) * 1.18,
		lerpf(1.0, _current_color.g, 0.72) * 1.18,
		lerpf(1.0, _current_color.b, 0.72) * 1.18,
		1.0
	)
	return base_tint.lerp(vivid, 0.78)


func get_rim_key_color() -> Color:
	# Rim-light vibrante HDR para Pasada 1 y Pasada 2.
	return Color(
		lerpf(_current_color.r, 1.0, 0.22) * 1.30,
		lerpf(_current_color.g, 1.0, 0.22) * 1.30,
		lerpf(_current_color.b, 1.0, 0.22) * 1.30,
		1.0
	)


func _update_color() -> void:
	var count: int = SPECTRAL_PALETTE.size()
	if count == 0:
		return
	var phase: float = fposmod(_time * color_cycle_speed, float(count))
	var idx_a: int = int(floor(phase)) % count
	var idx_b: int = (idx_a + 1) % count
	var frac: float = smoothstep(0.0, 1.0, phase - floor(phase))
	_current_color = SPECTRAL_PALETTE[idx_a].lerp(SPECTRAL_PALETTE[idx_b], frac)


func _draw() -> void:
	var pulse: float = 1.0 + 0.06 * sin(_time * 3.4)
	var col: Color = _current_color

	# Guía sutil de la órbita del personaje
	var ring_col := Color(col.r, col.g, col.b, 0.16)
	draw_arc(Vector2.ZERO, orbit_radius, 0.0, TAU, 72, ring_col, 1.25, true)

	# Halo atmosférico exterior (capas suaves para bloom HDR)
	draw_circle(Vector2.ZERO, 96.0 * pulse, Color(col.r, col.g, col.b, 0.045))
	draw_circle(Vector2.ZERO, 62.0 * pulse, Color(col.r, col.g, col.b, 0.10))
	draw_circle(Vector2.ZERO, 38.0 * pulse, Color(col.r, col.g, col.b, 0.22))
	draw_circle(Vector2.ZERO, 22.0 * pulse, Color(col.r * 1.35, col.g * 1.35, col.b * 1.35, 0.45))

	# Destellos de corona giratorios (4 puntas largas + 4 puntas cortas)
	var rot_a: float = _time * 0.35
	for i: int in range(8):
		var ang: float = rot_a + float(i) * (TAU / 8.0)
		var is_major: bool = (i % 2) == 0
		var ray_len: float = (52.0 if is_major else 30.0) * pulse
		var ray_w: float = 2.6 if is_major else 1.5
		var ray_col := Color(col.r * 1.45, col.g * 1.45, col.b * 1.45, 0.65 if is_major else 0.42)
		var dir := Vector2(cos(ang), sin(ang))
		draw_line(dir * 6.0, dir * ray_len, ray_col, ray_w, true)

	# Núcleo HDR incandescente
	var core_mid := Color(
		lerpf(col.r, 1.0, 0.55) * 1.75,
		lerpf(col.g, 1.0, 0.55) * 1.75,
		lerpf(col.b, 1.0, 0.55) * 1.75,
		1.0
	)
	draw_circle(Vector2.ZERO, 13.5 * pulse, core_mid)
	draw_circle(Vector2.ZERO, 7.5 * pulse, Color(2.1, 2.1, 2.1, 1.0))

	# Indicador sutil del rayo de luz hacia el personaje
	var to_target: Vector2 = _target_world_pos - global_position
	var dist: float = to_target.length()
	if dist > 28.0:
		var dir_t: Vector2 = to_target / dist
		var ray_end: Vector2 = dir_t * minf(dist - 24.0, 82.0)
		draw_line(dir_t * 20.0, ray_end, Color(col.r, col.g, col.b, 0.30), 1.6, true)

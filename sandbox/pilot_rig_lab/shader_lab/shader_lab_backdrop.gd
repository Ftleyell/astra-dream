class_name ShaderLabBackdrop
extends Node2D
## Fondo intercambiable de estudio (oscuro, claro, grilla, espacio) y gizmo de dirección de luz.

enum BackdropMode {
	DARK_STUDIO = 0,
	LIGHT_STUDIO = 1,
	CHECKER_GRID = 2,
	SPACE_NEBULA = 3,
}

const BACKDROP_EXTENT: float = 3600.0
const GRID_STEP: float = 48.0

var mode: int = BackdropMode.DARK_STUDIO
var light_dir_2d: Vector2 = Vector2(-0.58, -0.81).normalized()
var light_gizmo_origin: Vector2 = Vector2(165.0, 0.0)
var show_light_gizmo: bool = true

var _stars: PackedVector2Array = PackedVector2Array()
var _star_sizes: PackedFloat32Array = PackedFloat32Array()


func _ready() -> void:
	z_index = -100
	_generate_starfield()
	queue_redraw()


func set_mode(new_mode: int) -> void:
	mode = clampi(new_mode, 0, 3)
	queue_redraw()


func set_light_gizmo(origin: Vector2, dir_2d: Vector2, visible_flag: bool = true) -> void:
	light_gizmo_origin = origin
	light_dir_2d = dir_2d.normalized() if dir_2d.length_squared() > 0.0001 else Vector2(-0.58, -0.81).normalized()
	show_light_gizmo = visible_flag
	queue_redraw()


func _generate_starfield() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260419
	_stars.resize(260)
	_star_sizes.resize(260)
	for i: int in range(260):
		_stars[i] = Vector2(
			rng.randf_range(-1400.0, 1400.0),
			rng.randf_range(-900.0, 900.0)
		)
		_star_sizes[i] = rng.randf_range(0.9, 2.6)


func _draw() -> void:
	var full_rect := Rect2(-BACKDROP_EXTENT, -BACKDROP_EXTENT, BACKDROP_EXTENT * 2.0, BACKDROP_EXTENT * 2.0)
	match mode:
		BackdropMode.DARK_STUDIO:
			draw_rect(full_rect, Color(0.085, 0.095, 0.125, 1.0))
			_draw_subtle_grid(Color(0.16, 0.19, 0.25, 0.35), 96.0)
		BackdropMode.LIGHT_STUDIO:
			draw_rect(full_rect, Color(0.84, 0.86, 0.89, 1.0))
			_draw_subtle_grid(Color(0.68, 0.71, 0.76, 0.45), 96.0)
		BackdropMode.CHECKER_GRID:
			draw_rect(full_rect, Color(0.18, 0.20, 0.24, 1.0))
			var cols: int = 28
			var rows: int = 18
			var start_x: float = -cols * 0.5 * GRID_STEP
			var start_y: float = -rows * 0.5 * GRID_STEP
			for gx: int in range(cols):
				for gy: int in range(rows):
					if ((gx + gy) & 1) == 0:
						draw_rect(
							Rect2(start_x + gx * GRID_STEP, start_y + gy * GRID_STEP, GRID_STEP, GRID_STEP),
							Color(0.24, 0.26, 0.31, 1.0)
						)
		BackdropMode.SPACE_NEBULA:
			draw_rect(full_rect, Color(0.025, 0.028, 0.055, 1.0))
			draw_circle(Vector2(-260.0, -140.0), 420.0, Color(0.22, 0.07, 0.32, 0.14))
			draw_circle(Vector2(280.0, 120.0), 460.0, Color(0.05, 0.20, 0.36, 0.14))
			draw_circle(Vector2(40.0, -40.0), 260.0, Color(0.35, 0.08, 0.18, 0.09))
			for i: int in range(_stars.size()):
				var alpha: float = 0.45 + 0.55 * float(i % 5) / 4.0
				var col: Color = Color(0.82, 0.90, 1.0, alpha) if (i % 3 != 0) else Color(1.0, 0.85, 0.78, alpha)
				draw_circle(_stars[i], _star_sizes[i], col)

	# Cruz central de referencia sutil
	var cross_col: Color = Color(0.30, 0.36, 0.45, 0.35) if mode != BackdropMode.LIGHT_STUDIO else Color(0.45, 0.48, 0.55, 0.45)
	draw_line(Vector2(-1200.0, 0.0), Vector2(1200.0, 0.0), cross_col, 1.0)
	draw_line(Vector2(0.0, -800.0), Vector2(0.0, 800.0), cross_col, 1.0)

	if show_light_gizmo:
		_draw_light_gizmo()


func _draw_subtle_grid(line_col: Color, step: float) -> void:
	var limit_x: float = 1248.0
	var limit_y: float = 864.0
	var x: float = -limit_x
	while x <= limit_x:
		draw_line(Vector2(x, -limit_y), Vector2(x, limit_y), line_col, 1.0)
		x += step
	var y: float = -limit_y
	while y <= limit_y:
		draw_line(Vector2(-limit_x, y), Vector2(limit_x, y), line_col, 1.0)
		y += step


func _draw_light_gizmo() -> void:
	# La luz viene DESDE light_dir_2d hacia el personaje
	var radius: float = 132.0
	var sun_pos: Vector2 = light_gizmo_origin + light_dir_2d * radius
	var arrow_end: Vector2 = light_gizmo_origin + light_dir_2d * (radius - 32.0)
	var ring_col: Color = Color(1.0, 0.86, 0.35, 0.22) if mode != BackdropMode.LIGHT_STUDIO else Color(0.75, 0.48, 0.05, 0.30)
	var sun_col: Color = Color(1.0, 0.88, 0.38, 0.92) if mode != BackdropMode.LIGHT_STUDIO else Color(0.88, 0.52, 0.05, 0.95)
	draw_arc(light_gizmo_origin, radius, 0.0, TAU, 48, ring_col, 1.5, true)
	draw_line(sun_pos, arrow_end, sun_col, 2.2, true)
	draw_circle(sun_pos, 7.0, sun_col)
	draw_circle(sun_pos, 3.0, Color(1.0, 1.0, 0.92, 1.0))

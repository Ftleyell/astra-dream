class_name BombShockwaveVFX
extends Node2D

## Visual Effect for Screen Bomb Detonation.
## Generates an energetic multi-layered shockwave ring that expands rapidly
## from the detonation origin outward beyond the camera's field of view.

@export var duration: float = 0.75
@export var max_radius: float = 2200.0
@export var primary_color: Color = Color(0.15, 0.9, 1.0, 1.0)
@export var core_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var secondary_color: Color = Color(0.0, 0.7, 1.0, 0.8)
@export var inner_color: Color = Color(0.35, 0.45, 1.0, 0.5)

var _timer: float = 0.0
var _ray_count: int = 24
var _ray_angles: PackedFloat32Array = PackedFloat32Array()

func setup(pos: Vector2) -> void:
	global_position = pos

func _ready() -> void:
	z_index = 40
	z_as_relative = false
	
	# Precalculate radial ray angles for the energetic discharge lattice
	_ray_angles.resize(_ray_count)
	for i in range(_ray_count):
		_ray_angles[i] = (float(i) / float(_ray_count)) * TAU
	
	queue_redraw()

func _process(delta: float) -> void:
	_timer += delta
	if _timer >= duration:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var t := clampf(_timer / duration, 0.0, 1.0)
	# Cubic ease-out: explosive initial blast that swiftly expands outward
	var ease_progress := 1.0 - pow(1.0 - t, 3.0)
	var current_radius := ease_progress * max_radius
	var alpha := 1.0 - t
	
	# 1. Initial detonation flash flare at the center
	if t < 0.3:
		var flash_t := t / 0.3
		var flash_radius := lerpf(20.0, 220.0, flash_t)
		var flash_alpha := (1.0 - flash_t) * 0.85
		draw_circle(Vector2.ZERO, flash_radius, Color(core_color.r, core_color.g, core_color.b, flash_alpha * 0.4))
		draw_circle(Vector2.ZERO, flash_radius * 0.5, Color(primary_color.r, primary_color.g, primary_color.b, flash_alpha * 0.6))
		draw_circle(Vector2.ZERO, flash_radius * 0.25, Color(1.0, 1.0, 1.0, flash_alpha))
	
	# If wave is still very small, don't draw negative rings
	if current_radius < 5.0:
		return
	
	# 2. Outer Primary Shockwave Ring (Bright Cyan Electric Glow + White Core)
	var main_width := lerpf(12.0, 4.0, ease_progress)
	var main_col := Color(primary_color.r, primary_color.g, primary_color.b, alpha * 0.95)
	draw_arc(Vector2.ZERO, current_radius, 0.0, TAU, 72, main_col, main_width, true)
	
	# White core highlight
	var core_width := lerpf(5.0, 1.5, ease_progress)
	var core_col := Color(core_color.r, core_color.g, core_color.b, alpha * 0.9)
	draw_arc(Vector2.ZERO, current_radius, 0.0, TAU, 72, core_col, core_width, true)
	
	# 3. Secondary Trailing Ring (Neon Cyan/Azure)
	var sec_radius := current_radius * 0.93
	if sec_radius > 5.0:
		var sec_width := lerpf(7.0, 2.5, ease_progress)
		var sec_col := Color(secondary_color.r, secondary_color.g, secondary_color.b, alpha * 0.75)
		draw_arc(Vector2.ZERO, sec_radius, 0.0, TAU, 64, sec_col, sec_width, true)
	
	# 4. Third Harmonic Ring (Energetic Plasma Blue)
	var inner_radius := current_radius * 0.84
	if inner_radius > 5.0:
		var in_width := lerpf(4.0, 1.5, ease_progress)
		var in_col := Color(inner_color.r, inner_color.g, inner_color.b, alpha * 0.45)
		draw_arc(Vector2.ZERO, inner_radius, 0.0, TAU, 56, in_col, in_width, true)
		
		# 5. Radial Discharge Lightning Sparks between inner and outer rings
		var rot_offset := ease_progress * 0.45
		var spark_alpha := alpha * 0.6
		var spark_col := Color(0.7, 0.95, 1.0, spark_alpha)
		for base_angle in _ray_angles:
			var angle := base_angle + rot_offset
			var dir := Vector2(cos(angle), sin(angle))
			var p_start := dir * inner_radius
			var p_end := dir * current_radius
			draw_line(p_start, p_end, spark_col, 2.0, true)

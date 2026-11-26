class_name HubLandingRippleVFX
extends Node2D

## Ondas luminosas sutiles en la cubierta del Hub 3D al aterrizar cada Moon Hop.
## Usa un pool fijo sin asignaciones por pisada y persiste sobre z_index = 4 (sobre Hub3D, bajo Player).

const MAX_POOL: int = 6
const ELLIPSE_SCALE_Y: float = 0.54

var _active: Array[bool] = []
var _positions: Array[Vector2] = []
var _ages: Array[float] = []
var _durations: Array[float] = []
var _max_radii: Array[float] = []
var _colors: Array[Color] = []
var _intensities: Array[float] = []
var _spark_counts: Array[int] = []
var _next_overwrite_idx: int = 0


func _init() -> void:
	top_level = true
	z_as_relative = false
	z_index = 4
	_active.resize(MAX_POOL)
	_positions.resize(MAX_POOL)
	_ages.resize(MAX_POOL)
	_durations.resize(MAX_POOL)
	_max_radii.resize(MAX_POOL)
	_colors.resize(MAX_POOL)
	_intensities.resize(MAX_POOL)
	_spark_counts.resize(MAX_POOL)
	for i: int in range(MAX_POOL):
		_active[i] = false
		_positions[i] = Vector2.ZERO
		_ages[i] = 0.0
		_durations[i] = 0.36
		_max_radii[i] = 28.0
		_colors[i] = Color(0.55, 0.92, 1.0, 1.0)
		_intensities[i] = 1.15
		_spark_counts[i] = 5


func spawn_ripple(
	world_pos: Vector2,
	accent_color: Color,
	max_radius_px: float = 28.0,
	duration_sec: float = 0.36,
	intensity: float = 1.15,
	spark_count: int = 5
) -> void:
	var slot_idx: int = -1
	for i: int in range(MAX_POOL):
		if not _active[i]:
			slot_idx = i
			break
	if slot_idx < 0:
		slot_idx = _next_overwrite_idx
		_next_overwrite_idx = (_next_overwrite_idx + 1) % MAX_POOL

	_active[slot_idx] = true
	_positions[slot_idx] = world_pos
	_ages[slot_idx] = 0.0
	_durations[slot_idx] = maxf(duration_sec, 0.08)
	_max_radii[slot_idx] = maxf(max_radius_px, 8.0)
	_colors[slot_idx] = Color(0.72, 0.96, 1.0, 1.0).lerp(accent_color, 0.42)
	_intensities[slot_idx] = clampf(intensity, 0.2, 2.4)
	_spark_counts[slot_idx] = clampi(spark_count, 0, 8)
	queue_redraw()


func clear_ripples() -> void:
	for i: int in range(MAX_POOL):
		_active[i] = false
	queue_redraw()


func get_active_ripple_count() -> int:
	var count: int = 0
	for i: int in range(MAX_POOL):
		if _active[i]:
			count += 1
	return count


func _process(delta: float) -> void:
	var any_active: bool = false
	for i: int in range(MAX_POOL):
		if not _active[i]:
			continue
		_ages[i] += delta
		if _ages[i] >= _durations[i]:
			_active[i] = false
		else:
			any_active = true
	if any_active:
		queue_redraw()


func _draw() -> void:
	for i: int in range(MAX_POOL):
		if not _active[i]:
			continue
		var dur: float = maxf(_durations[i], 0.01)
		var t: float = clampf(_ages[i] / dur, 0.0, 1.0)
		var ease_out: float = 1.0 - pow(1.0 - t, 2.35)
		var ease_inner: float = 1.0 - pow(1.0 - t, 1.85)
		var inten: float = clampf(_intensities[i], 0.2, 2.4)
		var r_outer: float = lerpf(_max_radii[i] * 0.22, _max_radii[i], ease_out)
		var r_inner: float = lerpf(_max_radii[i] * 0.14, _max_radii[i] * 0.54, ease_inner)
		var alpha_outer: float = (1.0 - smoothstep(0.28, 1.0, t)) * 0.56 * minf(inten, 1.4)
		var alpha_inner: float = (1.0 - smoothstep(0.14, 0.88, t)) * 0.72 * minf(inten, 1.4)
		var width_outer: float = lerpf(2.2, 0.8, t)
		var base_c: Color = _colors[i]

		draw_set_transform(_positions[i], 0.0, Vector2(1.0, ELLIPSE_SCALE_Y))
		if t < 0.38:
			var flash_u: float = 1.0 - (t / 0.38)
			draw_circle(Vector2.ZERO, lerpf(6.0, 12.0, 1.0 - flash_u), Color(base_c.r, base_c.g, base_c.b, 0.26 * flash_u * minf(inten, 1.4)))
		draw_arc(Vector2.ZERO, r_outer, 0.0, TAU, 36, Color(base_c.r, base_c.g, base_c.b, alpha_outer * 0.38), width_outer * 2.4, true)
		draw_arc(Vector2.ZERO, r_outer, 0.0, TAU, 36, Color(base_c.r, base_c.g, base_c.b, alpha_outer), width_outer, true)
		draw_arc(Vector2.ZERO, r_inner, 0.0, TAU, 28, Color(0.95, 0.98, 1.0, alpha_inner), lerpf(1.8, 0.7, t), true)

		var sp_cnt: int = _spark_counts[i]
		if sp_cnt > 0 and t < 0.75:
			var sp_t: float = t / 0.75
			var sp_fade: float = (1.0 - sp_t) * 0.75 * minf(inten, 1.3)
			draw_set_transform(_positions[i], 0.0, Vector2.ONE)
			for s_idx: int in range(sp_cnt):
				var ang: float = (float(s_idx) / float(sp_cnt)) * TAU + float(i) * 0.7
				var rad_s: float = lerpf(5.0, _max_radii[i] * 0.52, ease_out)
				var sp_pos := Vector2(cos(ang) * rad_s, sin(ang) * rad_s * ELLIPSE_SCALE_Y - lerpf(1.0, 11.0, sp_t))
				draw_circle(sp_pos, lerpf(2.1, 0.5, sp_t), Color(0.95, 0.98, 1.0, sp_fade).lerp(base_c, 0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

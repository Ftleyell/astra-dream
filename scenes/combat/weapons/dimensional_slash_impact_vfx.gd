class_name DimensionalSlashImpactVFX
extends Node2D

@export var duration: float = 0.16
var impact_color: Color = Color(1.0, 0.25, 0.95, 1.0)
var slash_angle: float = 0.0
var slash_length: float = 46.0
var current_time: float = 0.0

class AstralSpark:
	var pos: Vector2 = Vector2.ZERO
	var vel: Vector2 = Vector2.ZERO
	var length: float = 8.0

var sparks: Array[AstralSpark] = []

func setup(p_pos: Vector2, p_angle: float, p_color: Color = Color(1.0, 0.25, 0.95, 1.0), p_length: float = 46.0) -> void:
	global_position = p_pos
	slash_angle = p_angle
	rotation = p_angle
	impact_color = p_color
	slash_length = p_length

func _ready() -> void:
	z_index = 26
	z_as_relative = false

	var count := randi_range(5, 7)
	for i in range(count):
		var sp := AstralSpark.new()
		# Chispas expulsadas hacia adelante en el cono del corte
		var a := randf_range(-0.6, 0.6)
		var spd := randf_range(120.0, 260.0)
		sp.vel = Vector2(cos(a), sin(a)) * spd
		sp.length = randf_range(6.0, 12.0)
		sparks.append(sp)

func _process(delta: float) -> void:
	current_time += delta
	if current_time >= duration:
		queue_free()
		return

	for sp in sparks:
		sp.pos += sp.vel * delta
		sp.vel = sp.vel.move_toward(Vector2.ZERO, 400.0 * delta)

	queue_redraw()

func _draw() -> void:
	var t := clampf(current_time / duration, 0.0, 1.0)
	var alpha := 1.0 - t

	# 1. Incisión dimensional diagonal (corte lineal que atraviesa la entidad)
	var half_len := (slash_length * 0.5) * (0.8 + 0.3 * (1.0 - t))
	var p_start := Vector2(-half_len, 0.0)
	var p_end := Vector2(half_len, 0.0)

	var outer_glow_col := Color(impact_color.r, impact_color.g, impact_color.b, alpha * 0.85)
	var core_white_col := Color(1.0, 0.95, 1.0, alpha)

	var outer_w := 6.0 * (1.0 - t * 0.7)
	var core_w := 2.5 * (1.0 - t * 0.7)

	draw_line(p_start, p_end, outer_glow_col, outer_w)
	draw_line(p_start * 0.8, p_end * 0.8, core_white_col, core_w)

	# 2. Destello central estelar (cross sparkle)
	var flash_size := 14.0 * (1.0 - t)
	draw_line(Vector2(0.0, -flash_size), Vector2(0.0, flash_size), core_white_col, 2.0)
	draw_line(Vector2(-flash_size, 0.0), Vector2(flash_size, 0.0), core_white_col, 2.0)
	draw_circle(Vector2.ZERO, flash_size * 0.5, outer_glow_col)

	# 3. Micro-esquirlas astrales expulsadas
	for sp in sparks:
		var sp_col := Color(impact_color.r, impact_color.g, impact_color.b, alpha * 0.9)
		var sp_tail := sp.pos - sp.vel.normalized() * (sp.length * (1.0 - t * 0.5))
		draw_line(sp.pos, sp_tail, sp_col, 2.0)

class_name KineticImpactSparkVFX
extends Node2D

@export var duration: float = 0.14
var impact_color: Color = Color(0.3, 0.9, 1.0)
var core_radius: float = 16.0
var current_time: float = 0.0

class SparkParticle:
	var pos: Vector2 = Vector2.ZERO
	var vel: Vector2 = Vector2.ZERO
	var length: float = 6.0

var sparks: Array[SparkParticle] = []

func setup(p_pos: Vector2, p_color: Color = Color(0.3, 0.9, 1.0), p_radius: float = 16.0) -> void:
	global_position = p_pos
	impact_color = p_color
	core_radius = p_radius

func _ready() -> void:
	z_index = 25
	z_as_relative = false
	
	var count := randi_range(6, 8)
	for i in range(count):
		var sp := SparkParticle.new()
		var a := randf() * TAU
		var spd := randf_range(90.0, 240.0)
		sp.vel = Vector2(cos(a), sin(a)) * spd
		sp.length = randf_range(4.0, 9.0)
		sparks.append(sp)

func _process(delta: float) -> void:
	current_time += delta
	if current_time >= duration:
		queue_free()
		return

	for sp in sparks:
		sp.pos += sp.vel * delta
		sp.vel = sp.vel.move_toward(Vector2.ZERO, 350.0 * delta)

	queue_redraw()

func _draw() -> void:
	var t := clampf(current_time / duration, 0.0, 1.0)
	var alpha := 1.0 - t

	# 1. Destello circular central suave con desvanecimiento
	var cur_r := core_radius * (1.0 + t * 0.4)
	var glow_col := Color(impact_color.r, impact_color.g, impact_color.b, alpha * 0.75)
	draw_circle(Vector2.ZERO, cur_r, glow_col)
	
	# Núcleo blanco caliente
	var white_col := Color(1.0, 1.0, 1.0, alpha * 0.9)
	draw_circle(Vector2.ZERO, cur_r * 0.45, white_col)

	# 2. Chispas radiales incisivas
	for sp in sparks:
		var dir := sp.vel.normalized() if sp.vel.length_squared() > 0.01 else Vector2.RIGHT
		var p1 := sp.pos
		var p2 := sp.pos - dir * sp.length
		var spark_col := Color(impact_color.r, impact_color.g, impact_color.b, alpha)
		draw_line(p2, p1, spark_col, 1.8, true)

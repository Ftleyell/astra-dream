class_name CinematicMicroExplosion
extends Node2D

## Micro-explosión procedural de alto impacto para la fase de aceleración crítica de jefes.
## Se ejecuta con process_mode = Node.PROCESS_MODE_ALWAYS para operar durante la pausa cinematográfica.

@export var duration: float = 0.26
@export var max_radius: float = 38.0
@export var blast_color: Color = Color(0.2, 0.9, 1.0, 1.0)
@export var core_color: Color = Color(1.0, 1.0, 1.0, 1.0)

var _timer: float = 0.0
var _spark_dirs: PackedVector2Array = PackedVector2Array()
var _spark_speeds: PackedFloat32Array = PackedFloat32Array()

func setup(pos: Vector2, radius: float = 38.0, accent_color: Color = Color(0.2, 0.9, 1.0, 1.0)) -> void:
	global_position = pos
	max_radius = radius
	blast_color = accent_color

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 60
	z_as_relative = false

	var spark_count := randi_range(6, 10)
	_spark_dirs.resize(spark_count)
	_spark_speeds.resize(spark_count)
	for i in range(spark_count):
		var angle := randf() * TAU
		_spark_dirs[i] = Vector2(cos(angle), sin(angle))
		_spark_speeds[i] = randf_range(40.0, 140.0)

	queue_redraw()

func _process(delta: float) -> void:
	_timer += delta
	if _timer >= duration:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var t := clampf(_timer / duration, 0.0, 1.0)
	var ease_expand := 1.0 - pow(1.0 - t, 2.5)
	var radius := ease_expand * max_radius
	var alpha := 1.0 - t

	# Núcleo fulgurante de detonación blanca
	if t < 0.45:
		var core_alpha := (1.0 - (t / 0.45)) * 0.95
		draw_circle(Vector2.ZERO, radius * 0.45, Color(core_color.r, core_color.g, core_color.b, core_alpha))

	# Anillo de corte de energía expansivo
	draw_arc(
		Vector2.ZERO,
		radius,
		0.0,
		TAU,
		24,
		Color(blast_color.r, blast_color.g, blast_color.b, alpha * 0.9),
		maxf(1.5, 3.5 * (1.0 - t))
	)

	# Micro-chispas radiales
	for i in range(_spark_dirs.size()):
		var spark_pos := _spark_dirs[i] * (_spark_speeds[i] * t)
		var spark_alpha := alpha * 0.8
		draw_circle(spark_pos, maxf(1.0, 2.5 * (1.0 - t)), Color(core_color.r, core_color.g, core_color.b, spark_alpha))

class_name CinematicMicroExplosion
extends Node2D

## Micro-explosión procedural de alto impacto para la fase de aceleración crítica de jefes.
## Se ejecuta con process_mode = Node.PROCESS_MODE_ALWAYS para operar durante la pausa cinematográfica.

@export var duration: float = 0.32
@export var max_radius: float = 75.0
@export var blast_color: Color = Color(0.2, 0.9, 1.0, 1.0)
@export var core_color: Color = Color(1.0, 1.0, 1.0, 1.0)

var _timer: float = 0.0
var _spark_dirs: PackedVector2Array = PackedVector2Array()
var _spark_speeds: PackedFloat32Array = PackedFloat32Array()

func setup(pos: Vector2, radius: float = 75.0, accent_color: Color = Color(0.2, 0.9, 1.0, 1.0)) -> void:
	global_position = pos
	max_radius = radius
	blast_color = accent_color

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 120
	z_as_relative = false

	var spark_count := randi_range(8, 14)
	_spark_dirs.resize(spark_count)
	_spark_speeds.resize(spark_count)
	for i in range(spark_count):
		var angle := randf() * TAU
		_spark_dirs[i] = Vector2(cos(angle), sin(angle))
		_spark_speeds[i] = randf_range(60.0, 180.0)

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

	# Halo luminoso con tinte de energía
	draw_circle(Vector2.ZERO, radius * 0.75, Color(blast_color.r, blast_color.g, blast_color.b, alpha * 0.45))

	# Núcleo fulgurante de detonación blanca
	if t < 0.6:
		var core_alpha := (1.0 - (t / 0.6)) * 0.98
		draw_circle(Vector2.ZERO, radius * 0.42, Color(core_color.r, core_color.g, core_color.b, core_alpha))

	# Anillo de corte de energía expansivo grueso
	draw_arc(
		Vector2.ZERO,
		radius,
		0.0,
		TAU,
		32,
		Color(blast_color.r, blast_color.g, blast_color.b, alpha * 0.95),
		maxf(2.5, 5.5 * (1.0 - t))
	)

	# Micro-chispas radiales luminosas
	for i in range(_spark_dirs.size()):
		var spark_pos := _spark_dirs[i] * (_spark_speeds[i] * t)
		var spark_alpha := alpha * 0.9
		draw_circle(spark_pos, maxf(1.5, 3.5 * (1.0 - t)), Color(core_color.r, core_color.g, core_color.b, spark_alpha))

class_name CinematicResidualDebris
extends Node2D

## Materia residual post-supernova: esquirlas metálicas humeantes y brasas de energía
## que se dispersan en el vacío espacial con rozamiento/inercia y desvanecimiento progresivo.

@export var duration: float = 3.0
@export var ember_color: Color = Color(0.25, 0.9, 1.0, 1.0)
@export var shard_color: Color = Color(0.85, 0.9, 1.0, 0.8)

class SpaceDebris:
	var position: Vector2 = Vector2.ZERO
	var velocity: Vector2 = Vector2.ZERO
	var rotation: float = 0.0
	var rot_speed: float = 0.0
	var size: float = 3.0
	var is_shard: bool = false
	var points: PackedVector2Array = PackedVector2Array()

var _items: Array[SpaceDebris] = []
var _timer: float = 0.0

func setup(pos: Vector2, count: int = 24, accent_color: Color = Color(0.25, 0.9, 1.0, 1.0)) -> void:
	global_position = pos
	ember_color = accent_color
	_items.clear()
	
	for i in range(count):
		var d := SpaceDebris.new()
		var angle := randf() * TAU
		var speed := randf_range(40.0, 260.0)
		d.velocity = Vector2(cos(angle), sin(angle)) * speed
		d.rotation = randf() * TAU
		d.rot_speed = randf_range(-6.0, 6.0)
		d.is_shard = (i % 2 == 0)
		
		if d.is_shard:
			d.size = randf_range(4.0, 9.0)
			var s := d.size
			d.points = PackedVector2Array([
				Vector2(-s, -s * 0.5),
				Vector2(s * 0.8, -s * 0.2),
				Vector2(s * 0.2, s),
				Vector2(-s * 0.6, s * 0.6)
			])
		else:
			d.size = randf_range(2.0, 4.5)
		
		_items.append(d)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 45
	z_as_relative = false
	queue_redraw()

func _process(delta: float) -> void:
	_timer += delta
	if _timer >= duration:
		queue_free()
		return

	# Arrastre espacial (drag inercial simulando desaceleración en el éter cósmico)
	var drag := exp(-1.2 * delta)
	for item in _items:
		item.position += item.velocity * delta
		item.velocity *= drag
		item.rotation += item.rot_speed * delta

	queue_redraw()

func _draw() -> void:
	var alpha := clampf(1.0 - (_timer / duration), 0.0, 1.0)
	
	for item in _items:
		var col := ember_color if not item.is_shard else shard_color
		var current_color := Color(col.r, col.g, col.b, col.a * alpha)
		
		if item.is_shard:
			var xform := Transform2D(item.rotation, item.position)
			var transformed_points := PackedVector2Array()
			transformed_points.resize(item.points.size())
			for i in range(item.points.size()):
				transformed_points[i] = xform * item.points[i]
			draw_colored_polygon(transformed_points, current_color)
		else:
			# Brasa de plasma brillante
			draw_circle(item.position, item.size * alpha, current_color)
			draw_circle(item.position, (item.size * 0.45) * alpha, Color(1.0, 1.0, 1.0, alpha * 0.9))

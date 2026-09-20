class_name StarfieldLayer
extends Node2D

@export var star_count: int = 140
@export var seed_number: int = 42
@export var min_star_radius: float = 1.0
@export var max_star_radius: float = 2.4
@export var base_color: Color = Color(0.9, 0.95, 1.0, 0.8)
@export var color_tint: Color = Color(0.3, 0.7, 1.0, 0.2)
@export var bounds: Vector2 = Vector2(1920.0, 1080.0)

var _stars: Array[Dictionary] = []

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_number

	_stars.clear()
	for i in range(star_count):
		var pos := Vector2(rng.randf_range(0.0, bounds.x), rng.randf_range(0.0, bounds.y))
		var r := rng.randf_range(min_star_radius, max_star_radius)
		var alpha := rng.randf_range(0.3, 0.95)
		var col := base_color
		if rng.randf() < 0.25:
			col = col.lerp(color_tint, rng.randf_range(0.3, 0.8))
		col.a = alpha
		_stars.append({ "pos": pos, "radius": r, "color": col })

	queue_redraw()

func _draw() -> void:
	for s in _stars:
		draw_circle(s.pos, s.radius, s.color)

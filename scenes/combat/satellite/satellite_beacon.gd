class_name SatelliteBeacon
extends Node2D

@export var satellite_index: int = 1
@export var activation_radius: float = 180.0

var is_planted: bool = false
var player_inside: bool = false

signal planted(index: int, pos: Vector2)
signal exited_perimeter(index: int)

@onready var area: Area2D = $PerimeterArea
@onready var visual_core: Polygon2D = $VisualCore
@onready var radius_visual: Line2D = $RadiusVisual

func _ready() -> void:
	add_to_group("satellite_beacon")
	_draw_radius_circle()
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)

func _draw_radius_circle() -> void:
	radius_visual.clear_points()
	var points: int = 36
	for i in range(points + 1):
		var angle := float(i) * TAU / float(points)
		radius_visual.add_point(Vector2(cos(angle), sin(angle)) * activation_radius)

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		player_inside = true
		if not is_planted:
			plant_satellite()

func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		player_inside = false
		if is_planted:
			exited_perimeter.emit(satellite_index)

func plant_satellite() -> void:
	is_planted = true
	visual_core.color = Color(0.2, 1.0, 0.4, 1.0) # Verde activo
	radius_visual.default_color = Color(0.2, 1.0, 0.4, 0.4)
	planted.emit(satellite_index, global_position)

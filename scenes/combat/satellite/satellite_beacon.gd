class_name SatelliteBeacon
extends Node2D

@export var satellite_index: int = 1
@export var activation_radius: float = 180.0

var is_planted: bool = false
var player_inside: bool = false
var _is_tearing_down: bool = false
var ping_timer: float = 0.0
const PING_INTERVAL: float = 10.0
var _ping_line: Line2D = null

signal planted(index: int, pos: Vector2)
signal exited_perimeter(index: int)

@onready var area: Area2D = $PerimeterArea
@onready var visual_core: Polygon2D = $VisualCore
@onready var radius_visual: Line2D = $RadiusVisual

func _ready() -> void:
	add_to_group("satellite_beacon")
	_draw_radius_circle()
	_setup_ping_line()
	trigger_beacon_ping()
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)

func _setup_ping_line() -> void:
	_ping_line = Line2D.new()
	_ping_line.width = 3.0
	_ping_line.default_color = Color(0.0, 0.95, 1.0, 0.0)
	add_child(_ping_line)

func trigger_beacon_ping() -> void:
	if is_planted or _is_tearing_down or not _ping_line:
		return
	_ping_line.clear_points()
	var points: int = 36
	for i in range(points + 1):
		var angle := float(i) * TAU / float(points)
		_ping_line.add_point(Vector2(cos(angle), sin(angle)) * 20.0)
	_ping_line.default_color = Color(0.0, 0.95, 1.0, 0.9)
	_ping_line.scale = Vector2.ONE
	var tw := create_tween()
	tw.tween_property(_ping_line, "scale", Vector2(activation_radius / 20.0, activation_radius / 20.0), 1.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_ping_line, "default_color:a", 0.0, 1.2)

func _process(delta: float) -> void:
	if is_planted or _is_tearing_down:
		return
	ping_timer += delta
	if ping_timer >= PING_INTERVAL:
		ping_timer = 0.0
		trigger_beacon_ping()

func _exit_tree() -> void:
	_is_tearing_down = true
	if is_instance_valid(area):
		if area.body_entered.is_connected(_on_body_entered):
			area.body_entered.disconnect(_on_body_entered)
		if area.body_exited.is_connected(_on_body_exited):
			area.body_exited.disconnect(_on_body_exited)

func _draw_radius_circle() -> void:
	radius_visual.clear_points()
	var points: int = 36
	for i in range(points + 1):
		var angle := float(i) * TAU / float(points)
		radius_visual.add_point(Vector2(cos(angle), sin(angle)) * activation_radius)

func _on_body_entered(body: Node2D) -> void:
	if _is_tearing_down or not is_inside_tree() or is_queued_for_deletion():
		return
	if body != null and (not body.is_inside_tree() or body.is_queued_for_deletion()):
		return
	if body is Player:
		player_inside = true
		if not is_planted:
			plant_satellite()

func _on_body_exited(body: Node2D) -> void:
	if _is_tearing_down or not is_inside_tree() or is_queued_for_deletion():
		return
	if body != null and (not body.is_inside_tree() or body.is_queued_for_deletion()):
		return
	var tree := get_tree()
	if tree != null:
		var scene_root := tree.current_scene
		if scene_root != null and (not scene_root.is_inside_tree() or scene_root.is_queued_for_deletion()):
			return
	if body is Player:
		player_inside = false
		if is_planted:
			exited_perimeter.emit(satellite_index)

func plant_satellite() -> void:
	is_planted = true
	visual_core.color = Color(0.2, 1.0, 0.4, 1.0) # Verde activo
	radius_visual.default_color = Color(0.2, 1.0, 0.4, 0.4)
	planted.emit(satellite_index, global_position)

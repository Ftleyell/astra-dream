class_name SlotMachineBeacon
extends Node2D

signal interacted(beacon: SlotMachineBeacon)
signal exploded(pos: Vector2)

@export var interaction_radius: float = 160.0

var remaining_uses: int = 3
var current_spin_cost: int = 50
const COST_INCREMENT: int = 25

var player_inside: bool = false
var is_exploded: bool = false
var _is_tearing_down: bool = false

var _visual_core: Polygon2D
var _radius_visual: Line2D
var _area: Area2D
var _label: Label

func _ready() -> void:
	add_to_group("slot_machine_beacon")
	remaining_uses = randi_range(2, 5)
	_setup_visuals()
	_setup_area()

func _setup_visuals() -> void:
	# Core casino pedestal
	_visual_core = Polygon2D.new()
	var core_pts := PackedVector2Array([
		Vector2(-24, -32), Vector2(24, -32), Vector2(32, -16),
		Vector2(28, 32), Vector2(-28, 32), Vector2(-32, -16)
	])
	_visual_core.polygon = core_pts
	_visual_core.color = Color(0.95, 0.75, 0.1, 1.0) # Gold
	add_child(_visual_core)
	
	# Inner screen polygon
	var screen_poly := Polygon2D.new()
	screen_poly.polygon = PackedVector2Array([
		Vector2(-16, -20), Vector2(16, -20), Vector2(16, 4), Vector2(-16, 4)
	])
	screen_poly.color = Color(0.1, 0.05, 0.25, 1.0) # Neon dark
	add_child(screen_poly)
	
	# Floating title label
	_label = Label.new()
	_label.text = "🎰 TRAGAMONEDAS"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.position = Vector2(-100, -56)
	_label.custom_minimum_size = Vector2(200, 24)
	_label.add_theme_font_size_override("font_size", 14)
	_label.modulate = Color(1.0, 0.85, 0.2, 1.0)
	add_child(_label)

	# Radius circle
	_radius_visual = Line2D.new()
	_radius_visual.width = 2.5
	_radius_visual.default_color = Color(1.0, 0.8, 0.1, 0.4)
	var points: int = 36
	for i in range(points + 1):
		var angle := float(i) * TAU / float(points)
		_radius_visual.add_point(Vector2(cos(angle), sin(angle)) * interaction_radius)
	add_child(_radius_visual)

func _setup_area() -> void:
	_area = Area2D.new()
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = interaction_radius
	col.shape = shape
	_area.add_child(col)
	add_child(_area)

	_area.body_entered.connect(_on_body_entered)
	_area.body_exited.connect(_on_body_exited)

func _process(delta: float) -> void:
	if is_exploded or _is_tearing_down:
		return
	# Gentle hover/bobbing animation
	position.y += sin(Time.get_ticks_msec() * 0.003) * 0.35 * delta * 60.0
	if _visual_core:
		var pulse := 0.85 + 0.15 * sin(Time.get_ticks_msec() * 0.005)
		_visual_core.color = Color(0.95 * pulse, 0.75 * pulse, 0.1, 1.0)

func _on_body_entered(body: Node2D) -> void:
	if _is_tearing_down or is_exploded:
		return
	if body is Player:
		player_inside = true
		interacted.emit(self)

func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		player_inside = false

func get_current_cost() -> int:
	return current_spin_cost

func has_uses_remaining() -> bool:
	return remaining_uses > 0

func record_use() -> void:
	consume_spin()

func consume_spin() -> void:
	remaining_uses -= 1
	current_spin_cost += COST_INCREMENT

func trigger_explosion() -> void:
	if is_exploded:
		return
	is_exploded = true
	var exp_pos := position if position != Vector2.ZERO else global_position
	
	# Spawn explosion particles / screen shake
	exploded.emit(exp_pos)
	queue_free()

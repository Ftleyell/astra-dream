class_name SlotMachineChest
extends Node2D

signal chest_opened(chest: SlotMachineChest)

@export var interaction_radius: float = 90.0

var player_inside: bool = false
var is_opened: bool = false
var _visual: Polygon2D
var _glow: Line2D
var _area: Area2D
var _label: Label

func _ready() -> void:
	add_to_group("slot_machine_chest")
	_setup_visuals()
	_setup_area()

func _setup_visuals() -> void:
	# Gold Chest Box
	_visual = Polygon2D.new()
	_visual.polygon = PackedVector2Array([
		Vector2(-20, -14), Vector2(20, -14),
		Vector2(24, 14), Vector2(-24, 14)
	])
	_visual.color = Color(1.0, 0.84, 0.0, 1.0) # Gold
	add_child(_visual)

	# Chest Lid / Gem
	var gem := Polygon2D.new()
	gem.polygon = PackedVector2Array([
		Vector2(0, -18), Vector2(8, -10), Vector2(0, -2), Vector2(-8, -10)
	])
	gem.color = Color(0.2, 0.9, 1.0, 1.0) # Diamond cyan
	add_child(gem)

	# Glow Ring
	_glow = Line2D.new()
	_glow.width = 2.0
	_glow.default_color = Color(1.0, 0.84, 0.0, 0.5)
	for i in range(25):
		var a := float(i) * TAU / 24.0
		_glow.add_point(Vector2(cos(a), sin(a)) * interaction_radius)
	add_child(_glow)

	# Label
	_label = Label.new()
	_label.text = "🎁 COFRE MISTERIOSO (Acércate)"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.position = Vector2(-120, -42)
	_label.custom_minimum_size = Vector2(240, 20)
	_label.add_theme_font_size_override("font_size", 13)
	_label.modulate = Color(1.0, 0.9, 0.4, 1.0)
	add_child(_label)

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
	if is_opened:
		return
	var pulse := 0.8 + 0.2 * sin(Time.get_ticks_msec() * 0.006)
	_visual.scale = Vector2(pulse, pulse)

func _on_body_entered(body: Node2D) -> void:
	if is_opened:
		return
	if body is Player:
		player_inside = true
		chest_opened.emit(self)

func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		player_inside = false

func open_and_destroy() -> void:
	if is_opened:
		return
	is_opened = true
	queue_free()

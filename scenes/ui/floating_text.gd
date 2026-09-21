class_name FloatingText
extends Node2D

@onready var label: Label = $Label

func setup(text: String, color: Color = Color.WHITE) -> void:
	if not label:
		label = $Label
	label.text = text
	label.modulate = color
	
	# Animación pop-up hacia arriba con fade-out suave
	scale = Vector2(0.6, 0.6)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y - 40.0, 0.75).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.3).set_delay(0.45)
	tween.chain().tween_callback(queue_free)

static func spawn(parent: Node, spawn_pos: Vector2, text: String, color: Color = Color.WHITE) -> FloatingText:
	if not parent:
		return null
	var scene: PackedScene = load("res://scenes/ui/floating_text.tscn")
	if not scene:
		return null
	var ft: FloatingText = scene.instantiate() as FloatingText
	ft.position = spawn_pos
	parent.add_child(ft)
	ft.setup(text, color)
	return ft

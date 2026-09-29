class_name TargetReticle
extends Node2D

## TargetReticle.gd
## Retícula de fijación de objetivo (Lock-On) cibernética de alta resolución generada con Gemini.
## Sigue fluidamente al objetivo fijado por el auto-apuntado pasivo.

@export var reticle_color: Color = Color(0.2, 0.95, 1.0, 0.9)

var target: Node2D = null
var pulse_time: float = 0.0
var sprite: Sprite2D = null

func _ready() -> void:
	z_index = 30
	visible = false
	_setup_sprite()

func _setup_sprite() -> void:
	if not sprite:
		sprite = Sprite2D.new()
		sprite.name = "ReticleSprite"
		var tex_path := "res://assets/sprites/ui/target_reticle.png"
		var tex: Texture2D = null
		if ResourceLoader.exists(tex_path):
			tex = load(tex_path) as Texture2D
		if not tex:
			var global_path := ProjectSettings.globalize_path(tex_path)
			if FileAccess.file_exists(global_path):
				var img := Image.new()
				if img.load(global_path) == OK:
					tex = ImageTexture.create_from_image(img)
		sprite.texture = tex
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		sprite.material = mat
		sprite.scale = Vector2(0.24, 0.24)
		sprite.modulate = reticle_color
		add_child(sprite)

func set_target(p_target: Node2D) -> void:
	target = p_target
	if is_instance_valid(target) and not target.get("is_dying"):
		visible = true
		global_position = target.global_position
	else:
		visible = false

func _process(delta: float) -> void:
	if not is_instance_valid(target) or target.get("is_dying"):
		visible = false
		target = null
		return

	visible = true
	# Seguir suavemente al objetivo
	global_position = global_position.lerp(target.global_position, 28.0 * delta)

	pulse_time += delta * 6.0
	if sprite:
		sprite.rotation += delta * 0.65
		var p := 1.0 + sin(pulse_time) * 0.05
		sprite.scale = Vector2(0.24 * p, 0.24 * p)

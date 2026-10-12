extends Camera2D

## Controlador de cámara libre para validación interactiva de paralaje y frustum.

@export var move_speed: float = 1200.0
@export var boost_multiplier: float = 3.0

func _process(delta: float) -> void:
	var move_dir: Vector2 = Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		move_dir.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		move_dir.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		move_dir.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		move_dir.y += 1.0

	var current_speed: float = move_speed
	if Input.is_key_pressed(KEY_SHIFT):
		current_speed *= boost_multiplier

	global_position += move_dir.normalized() * current_speed * delta

	if Input.is_key_pressed(KEY_EQUAL) or Input.is_key_pressed(KEY_PLUS):
		zoom = (zoom + Vector2(0.2, 0.2) * delta).clamp(Vector2(0.25, 0.25), Vector2(3.0, 3.0))
	elif Input.is_key_pressed(KEY_MINUS):
		zoom = (zoom - Vector2(0.2, 0.2) * delta).clamp(Vector2(0.25, 0.25), Vector2(3.0, 3.0))

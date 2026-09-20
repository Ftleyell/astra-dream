class_name GameCamera2D
extends Camera2D

@export var target: Node2D = null
@export var smooth_speed: float = 8.0
@export var max_shake_offset: Vector2 = Vector2(22.0, 22.0)
@export var shake_decay: float = 3.0

var trauma: float = 0.0

func _ready() -> void:
	add_to_group("camera")
	position_smoothing_enabled = false # Usamos nuestro propio suavizado frame-rate independent
	if not target:
		target = get_tree().get_first_node_in_group("player") as Node2D
	if target:
		global_position = target.global_position

func _process(delta: float) -> void:
	_update_follow(delta)
	_update_shake(delta)

func _update_follow(delta: float) -> void:
	if not is_instance_valid(target):
		target = get_tree().get_first_node_in_group("player") as Node2D
		if not target:
			return

	var factor: float = 1.0 - exp(-smooth_speed * delta)
	global_position = global_position.lerp(target.global_position, factor)

func _update_shake(delta: float) -> void:
	if trauma > 0.0:
		trauma = maxf(0.0, trauma - shake_decay * delta)
		var shake := trauma * trauma
		offset = Vector2(
			randf_range(-max_shake_offset.x, max_shake_offset.x) * shake,
			randf_range(-max_shake_offset.y, max_shake_offset.y) * shake
		)
	else:
		offset = Vector2.ZERO

func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)

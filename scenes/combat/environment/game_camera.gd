class_name GameCamera2D
extends Camera2D

@export var target: Node2D = null
@export var smooth_speed: float = 8.0
@export var max_shake_offset: Vector2 = Vector2(22.0, 22.0)
@export var shake_decay: float = 3.0

@export var min_zoom: float = 1.0
@export var max_zoom: float = 2.0
@export var zoom_step: float = 0.1
@export var zoom_smooth_speed: float = 10.0

var trauma: float = 0.0
var focus_override: Node2D = null
var target_zoom: float = 1.0
var zoom_override: float = 0.0
var custom_focus_point: Vector2 = Vector2.INF

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("camera")
	position_smoothing_enabled = false # Usamos nuestro propio suavizado frame-rate independent
	if not target:
		target = get_tree().get_first_node_in_group("player") as Node2D
	if target:
		global_position = target.global_position
	zoom = Vector2(1.0, 1.0)
	target_zoom = 1.0

func _unhandled_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if not mouse_event or not mouse_event.is_pressed():
		return

	# Si hay un modal de combate o diálogo activo, proteger la UI del scroll
	var main_game := get_tree().current_scene
	if main_game and main_game.has_method("is_any_combat_modal_active") and main_game.is_any_combat_modal_active():
		return

	if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
		target_zoom = clampf(target_zoom + zoom_step, min_zoom, max_zoom)
		get_viewport().set_input_as_handled()
	elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		target_zoom = clampf(target_zoom - zoom_step, min_zoom, max_zoom)
		get_viewport().set_input_as_handled()
	elif mouse_event.button_index == MOUSE_BUTTON_MIDDLE:
		target_zoom = 1.0
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	_update_follow(delta)
	_update_shake(delta)
	_update_zoom(delta)

func _update_follow(delta: float) -> void:
	var follow_pos: Vector2 = Vector2.INF
	if custom_focus_point != Vector2.INF:
		follow_pos = custom_focus_point
	elif is_instance_valid(focus_override):
		follow_pos = focus_override.global_position
	elif is_instance_valid(target):
		follow_pos = target.global_position
	else:
		target = get_tree().get_first_node_in_group("player") as Node2D
		if is_instance_valid(target):
			follow_pos = target.global_position

	if follow_pos == Vector2.INF:
		return

	var factor: float = 1.0 - exp(-smooth_speed * delta)
	global_position = global_position.lerp(follow_pos, factor)

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

func _update_zoom(delta: float) -> void:
	var final_target_zoom: float = zoom_override if zoom_override > 0.0 else target_zoom
	var target_vec := Vector2(final_target_zoom, final_target_zoom)
	var factor: float = 1.0 - exp(-zoom_smooth_speed * delta)
	zoom = zoom.lerp(target_vec, factor)

func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)

func set_cinematic_focus(focus_pos: Vector2, cin_zoom: float = 1.25) -> void:
	custom_focus_point = focus_pos
	zoom_override = cin_zoom

func clear_cinematic_focus() -> void:
	custom_focus_point = Vector2.INF
	zoom_override = 0.0

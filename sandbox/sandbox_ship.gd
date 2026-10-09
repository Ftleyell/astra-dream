class_name SandboxShip
extends CharacterBody2D

## sandbox_ship.gd
## Nave autónoma ligera para pruebas de pilotaje e inmersión en biomas espaciales.
## Vuelo omnidireccional con aceleración suave, inercia espacial y giro progresivo.

@export var max_speed: float = 750.0
@export var boost_speed: float = 1600.0
@export var acceleration: float = 1200.0
@export var friction: float = 600.0
@export var turn_speed: float = 12.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var camera: Camera2D = $Camera2D

var _target_zoom: float = 1.0


func _process(delta: float) -> void:
	if is_instance_valid(camera):
		var cur_zoom: float = camera.zoom.x
		var next_zoom: float = lerpf(cur_zoom, _target_zoom, clampf(delta * 8.0, 0.0, 1.0))
		camera.zoom = Vector2(next_zoom, next_zoom)


func _physics_process(delta: float) -> void:
	var input_vec: Vector2 = Vector2.ZERO
	input_vec.x = Input.get_axis("ui_left", "ui_right")
	input_vec.y = Input.get_axis("ui_up", "ui_down")

	if input_vec.length_squared() > 1.0:
		input_vec = input_vec.normalized()

	var effective_max: float = boost_speed if Input.is_key_pressed(KEY_SHIFT) else max_speed

	if input_vec != Vector2.ZERO:
		velocity = velocity.move_toward(input_vec * effective_max, acceleration * delta)
		# Orientar la visual de la nave hacia la dirección de avance
		var target_angle: float = input_vec.angle() + PI * 0.5
		rotation = rotate_toward(rotation, target_angle, turn_speed * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	move_and_slide()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_pressed():
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_target_zoom = clampf(_target_zoom * 1.15, 0.35, 3.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_target_zoom = clampf(_target_zoom / 1.15, 0.35, 3.0)

	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_R:
			global_position = Vector2.ZERO
			velocity = Vector2.ZERO
			_target_zoom = 1.0
		elif event.keycode == KEY_1:
			_target_zoom = 0.5
		elif event.keycode == KEY_2:
			_target_zoom = 1.0
		elif event.keycode == KEY_3:
			_target_zoom = 1.75
		elif event.keycode == KEY_ESCAPE:
			get_tree().quit()

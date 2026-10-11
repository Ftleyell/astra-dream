class_name OrbitalBody2D
extends Node2D

## Representa un cuerpo astronómico en 2D (estrella, planeta o luna) con cinemática kepleriana analítica.
## La posición orbital se deriva directamente de t_global * omega, garantizando cero deriva numérica.

@export var body_name: StringName = &"CelestialBody"
@export var orbit_radius: float = 0.0
@export var angular_velocity: float = 0.0
@export var initial_theta: float = 0.0
@export var axial_rotation_velocity: float = 0.0
@export var initial_axial_rotation: float = 0.0
@export var show_orbit_lines: bool = true
@export var orbit_line_color: Color = Color(1.0, 1.0, 1.0, 0.12)
@export var orbit_line_width: float = 1.5

var _sprite: Sprite2D = null
var _orbital_children: Array[OrbitalBody2D] = []

func _draw() -> void:
	if not show_orbit_lines or _orbital_children.is_empty():
		return
	for child_body: OrbitalBody2D in _orbital_children:
		if is_instance_valid(child_body) and child_body.orbit_radius > 1.0:
			var point_count: int = 64 if child_body.orbit_radius > 500.0 else 32
			draw_arc(Vector2.ZERO, child_body.orbit_radius, 0.0, TAU, point_count, orbit_line_color, orbit_line_width)

func _ready() -> void:
	_discover_orbital_children()

func _discover_orbital_children() -> void:
	_orbital_children.clear()
	for child: Node in get_children():
		if child is OrbitalBody2D:
			_orbital_children.append(child as OrbitalBody2D)
		elif child is Sprite2D and _sprite == null:
			_sprite = child as Sprite2D

func set_sprite_reference(sprite: Sprite2D) -> void:
	_sprite = sprite

func get_sprite() -> Sprite2D:
	return _sprite

func add_orbital_child(child_body: OrbitalBody2D) -> void:
	if not _orbital_children.has(child_body):
		_orbital_children.append(child_body)
	if child_body.get_parent() != self:
		add_child(child_body)
	queue_redraw()

## Evalúa la posición orbital y rotación propia de forma puramente analítica.
## Si orbit_radius == 0, permanece en su origen (usado para la estrella central).
func evaluate_orbital_position(global_time: float) -> void:
	if orbit_radius > 0.0001:
		var current_theta: float = initial_theta + (angular_velocity * global_time)
		position = Vector2(
			orbit_radius * cos(current_theta),
			orbit_radius * sin(current_theta)
		)
	else:
		position = Vector2.ZERO

	if _sprite != null and axial_rotation_velocity != 0.0:
		_sprite.rotation = initial_axial_rotation + (axial_rotation_velocity * global_time)
	elif axial_rotation_velocity != 0.0:
		rotation = initial_axial_rotation + (axial_rotation_velocity * global_time)

	# Evaluar recursivamente cuerpos secundarios (lunas/satélites)
	for child_body: OrbitalBody2D in _orbital_children:
		child_body.evaluate_orbital_position(global_time)

func get_orbital_children() -> Array[OrbitalBody2D]:
	return _orbital_children

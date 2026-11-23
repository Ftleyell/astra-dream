class_name CosmosOrbitalBody2D
extends Node2D

## Representa un cuerpo astronómico en 2.5D/3D (estrella, planeta o luna) con cinemática kepleriana analítica.
## La posición orbital se deriva directamente de t_global * omega, garantizando cero deriva numérica y cero asignaciones.

@export var body_name: StringName = &"CelestialBody"
@export var orbit_radius: float = 0.0
@export var angular_velocity: float = 0.0
@export var initial_theta: float = 0.0
@export var orbit_eccentricity: float = 0.0
@export var orbit_periapsis_angle: float = 0.0
@export var orbit_plane_tilt: float = 0.0
@export var orbit_plane_squash: float = 1.0
@export var depth_scale_amplitude: float = 0.0
@export var enable_depth_z_swap: bool = false
@export var base_visual_scale: Vector2 = Vector2.ONE
@export var tangent_align: bool = false
@export var tangent_angle_offset: float = 0.0
@export var axial_rotation_velocity: float = 0.0
@export var initial_axial_rotation: float = 0.0
@export var show_orbit_lines: bool = true
@export var orbit_line_color: Color = Color(1.0, 1.0, 1.0, 0.12)
@export var orbit_line_width: float = 1.5

var current_depth_z: float = 0.0
var _sprite: Sprite2D = null
var _orbital_children: Array[CosmosOrbitalBody2D] = []
var _orbit_draw_points: PackedVector2Array = PackedVector2Array()

func _draw() -> void:
	if not show_orbit_lines or _orbital_children.is_empty():
		return
	for child_body: CosmosOrbitalBody2D in _orbital_children:
		if is_instance_valid(child_body) and child_body.orbit_radius > 1.0:
			var point_count: int = 64 if child_body.orbit_radius > 500.0 else 32
			var needed: int = point_count + 1
			if _orbit_draw_points.size() != needed:
				_orbit_draw_points.resize(needed)
			var inv_count: float = TAU / float(point_count)
			for i: int in range(needed):
				var phase_i: float = float(i) * inv_count
				var state_i: Vector3 = CosmosKeplerOrbitMath.calculate_orbit_state_3d(
					child_body.orbit_radius,
					phase_i,
					0.0,
					0.0,
					child_body.orbit_eccentricity,
					child_body.orbit_periapsis_angle,
					child_body.orbit_plane_tilt,
					child_body.orbit_plane_squash
				)
				_orbit_draw_points[i] = Vector2(state_i.x, state_i.y)
			draw_polyline(_orbit_draw_points, orbit_line_color, orbit_line_width, true)

func _ready() -> void:
	_discover_orbital_children()

func _discover_orbital_children() -> void:
	_orbital_children.clear()
	for child: Node in get_children():
		if child is CosmosOrbitalBody2D:
			_orbital_children.append(child as CosmosOrbitalBody2D)
		elif child is Sprite2D and _sprite == null:
			_sprite = child as Sprite2D

func set_sprite_reference(sprite: Sprite2D) -> void:
	_sprite = sprite

func get_sprite() -> Sprite2D:
	return _sprite

func add_orbital_child(child_body: CosmosOrbitalBody2D) -> void:
	if not _orbital_children.has(child_body):
		_orbital_children.append(child_body)
	if child_body.get_parent() != self:
		add_child(child_body)
	queue_redraw()

## Evalúa la posición orbital 2.5D/3D, escala perspectiva, Z-order dinámico y rotación propia de forma puramente analítica.
## Si orbit_radius == 0, permanece en su origen (usado para la estrella central).
func evaluate_orbital_position(global_time: float) -> void:
	if orbit_radius > 0.0001:
		var state: Vector3 = CosmosKeplerOrbitMath.calculate_orbit_state_3d(
			orbit_radius,
			initial_theta,
			angular_velocity,
			global_time,
			orbit_eccentricity,
			orbit_periapsis_angle,
			orbit_plane_tilt,
			orbit_plane_squash
		)
		position = Vector2(state.x, state.y)
		current_depth_z = state.z
		if depth_scale_amplitude > 0.0001:
			scale = base_visual_scale * maxf(1.0 + (current_depth_z * depth_scale_amplitude), 0.35)
		else:
			scale = base_visual_scale
		if enable_depth_z_swap:
			z_index = -1 if current_depth_z < 0.0 else 1
		if tangent_align:
			var vel: Vector2 = CosmosKeplerOrbitMath.calculate_orbit_velocity_2d(
				orbit_radius,
				initial_theta,
				angular_velocity,
				global_time,
				orbit_eccentricity,
				orbit_periapsis_angle,
				orbit_plane_tilt,
				orbit_plane_squash
			)
			if vel.length_squared() > 0.000001:
				var target_rot: float = vel.angle() + tangent_angle_offset
				if _sprite != null:
					_sprite.rotation = target_rot
				else:
					rotation = target_rot
	else:
		position = Vector2.ZERO
		current_depth_z = 0.0

	if not tangent_align:
		if _sprite != null and axial_rotation_velocity != 0.0:
			_sprite.rotation = initial_axial_rotation + (axial_rotation_velocity * global_time)
		elif axial_rotation_velocity != 0.0:
			rotation = initial_axial_rotation + (axial_rotation_velocity * global_time)

	# Evaluar recursivamente cuerpos secundarios (lunas/satélites)
	for child_body: CosmosOrbitalBody2D in _orbital_children:
		child_body.evaluate_orbital_position(global_time)

func get_orbital_children() -> Array[CosmosOrbitalBody2D]:
	return _orbital_children

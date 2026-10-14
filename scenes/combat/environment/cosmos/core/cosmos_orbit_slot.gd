class_name CosmosOrbitSlot
extends RefCounted

## CosmosOrbitSlot.gd
## Representa un slot orbital analítico tipado (alrededor de una estrella central o un planeta de fondo).
## Proporciona todos los parámetros necesarios para proyectar la posición orbital sincronizada al mundo de gameplay.

enum SlotCenterType {
	STAR,
	PLANET,
}

var center_type: SlotCenterType = SlotCenterType.STAR
var orbit_center_cell: Vector2i = Vector2i.ZERO
var center_layer_position: Vector2 = Vector2.ZERO
var orbit_radius: float = 0.0
var angular_velocity: float = 0.0
var initial_phase: float = 0.0
var body_reference: Node2D = null
var slot_name: StringName = &""
var layer_scroll_scale: Vector2 = Vector2(0.20, 0.20)
var host_orbit_radius: float = 0.0
var host_initial_theta: float = 0.0
var host_angular_velocity: float = 0.0

func _init(
	p_type: SlotCenterType = SlotCenterType.STAR,
	p_cell: Vector2i = Vector2i.ZERO,
	p_center_pos: Vector2 = Vector2.ZERO,
	p_radius: float = 0.0,
	p_ang_vel: float = 0.0,
	p_phase: float = 0.0,
	p_body: Node2D = null,
	p_name: StringName = &"",
	p_scroll_scale: Vector2 = Vector2(0.20, 0.20),
	p_host_radius: float = 0.0,
	p_host_theta: float = 0.0,
	p_host_ang_vel: float = 0.0
) -> void:
	center_type = p_type
	orbit_center_cell = p_cell
	center_layer_position = p_center_pos
	orbit_radius = p_radius
	angular_velocity = p_ang_vel
	initial_phase = p_phase
	body_reference = p_body
	slot_name = p_name
	layer_scroll_scale = p_scroll_scale
	host_orbit_radius = p_host_radius
	host_initial_theta = p_host_theta
	host_angular_velocity = p_host_ang_vel

## Evalúa la posición analítica local en la capa cósmica en el instante t_global de forma determinista O(1)
func calculate_layer_position(global_time: float) -> Vector2:
	var rel_orbit: Vector2 = CosmosKeplerOrbitMath.calculate_orbit_position(
		orbit_radius, initial_phase, angular_velocity, global_time
	)
	if center_type == SlotCenterType.PLANET:
		var host_planet_orbit: Vector2 = CosmosKeplerOrbitMath.calculate_orbit_position(
			host_orbit_radius, host_initial_theta, host_angular_velocity, global_time
		)
		return center_layer_position + host_planet_orbit + rel_orbit
	return center_layer_position + rel_orbit


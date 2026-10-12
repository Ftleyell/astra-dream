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

func _init(
	p_type: SlotCenterType = SlotCenterType.STAR,
	p_cell: Vector2i = Vector2i.ZERO,
	p_center_pos: Vector2 = Vector2.ZERO,
	p_radius: float = 0.0,
	p_ang_vel: float = 0.0,
	p_phase: float = 0.0,
	p_body: Node2D = null,
	p_name: StringName = &"",
	p_scroll_scale: Vector2 = Vector2(0.20, 0.20)
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

## Evalúa la posición analítica local en la capa cósmica en el instante t_global
func calculate_layer_position(global_time: float) -> Vector2:
	if is_instance_valid(body_reference):
		var rel_pos: Vector2 = CosmosKeplerOrbitMath.calculate_orbit_position(orbit_radius, initial_phase, angular_velocity, global_time)
		var parent_node: Node = body_reference.get_parent()
		var parent_pos: Vector2 = (parent_node as Node2D).position if parent_node is Node2D else Vector2.ZERO
		return parent_pos + body_reference.position + rel_pos
	
	# Fallback puramente matemático si el nodo fue liberado o está fuera del pool
	var rel_orbit: Vector2 = CosmosKeplerOrbitMath.calculate_orbit_position(orbit_radius, initial_phase, angular_velocity, global_time)
	return center_layer_position + rel_orbit

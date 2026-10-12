class_name CosmosKeplerOrbitMath
extends RefCounted

## Utilidad matemática pura sin dependencias de nodo para cálculos de cinemática orbital kepleriana 2D determinista.
## Garantiza cero asignaciones en runtime, cálculos analíticos en t_global sin deriva numérica.

## Calcula la posición cartesiana orbital 2D para una órbita circular analítica en el instante de tiempo dado.
static func calculate_orbit_position(orbit_radius: float, initial_theta: float, angular_velocity: float, global_time: float) -> Vector2:
	if orbit_radius <= 0.0001:
		return Vector2.ZERO
	var current_theta: float = initial_theta + (angular_velocity * global_time)
	return Vector2(
		orbit_radius * cos(current_theta),
		orbit_radius * sin(current_theta)
	)

## Calcula la velocidad angular kepleriana a partir del radio orbital y el semieje mínimo de referencia (Tercera Ley de Kepler: w proportional to r^(-1.5)).
static func calculate_keplerian_angular_velocity(base_angular_vel: float, ref_orbit_min: float, actual_radius: float, dir_sign: float = 1.0) -> float:
	var safe_r: float = maxf(actual_radius, 1.0)
	var kepler_scale: float = pow(ref_orbit_min / safe_r, 1.5)
	return base_angular_vel * kepler_scale * dir_sign

## Evalúa la oclusión por eclipse entre un cuerpo oclusor interior y un cuerpo receptor exterior.
## Retorna un factor [0.0, 1.0] donde 1.0 representa sombra de umbra total.
static func calculate_interplanetary_eclipse(
	receiver_pos: Vector2,
	receiver_radius: float,
	occluder_pos: Vector2,
	occluder_radius: float,
	expansion_factor: float,
	penumbra_ratio: float,
	light_field_radius: float
) -> float:
	var rec_dist: float = receiver_pos.length()
	var occ_dist: float = occluder_pos.length()
	if occ_dist >= rec_dist:
		return 0.0

	var occ_outward: Vector2 = occluder_pos.normalized() if occ_dist > 1.0 else Vector2(1.0, 0.0)
	var rel_v: Vector2 = receiver_pos - occluder_pos
	var proj_d: float = rel_v.dot(occ_outward)
	if proj_d <= 0.0:
		return 0.0

	var perp_d: float = (rel_v - (occ_outward * proj_d)).length()
	var proj_norm: float = clampf(proj_d / maxf(light_field_radius, 1.0), 0.0, 1.0)
	var cone_r_at_dist: float = occluder_radius * lerpf(1.0, expansion_factor, proj_norm)
	var umbra_r: float = cone_r_at_dist * (1.0 - penumbra_ratio)
	var penumbra_r: float = cone_r_at_dist + (receiver_radius * 0.4)

	if perp_d <= umbra_r:
		return 1.0
	elif perp_d < penumbra_r:
		return 1.0 - smoothstep(umbra_r, penumbra_r, perp_d)
	return 0.0

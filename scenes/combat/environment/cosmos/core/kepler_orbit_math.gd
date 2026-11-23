class_name CosmosKeplerOrbitMath
extends RefCounted

## Utilidad matemática pura sin dependencias de nodo para cálculos de cinemática orbital kepleriana 2.5D/3D determinista.
## Garantiza cero asignaciones en runtime, cálculos analíticos en t_global sin deriva numérica.

static func _solve_eccentric_anomaly(mean_anomaly: float, eccentricity: float) -> float:
	var e: float = clampf(eccentricity, 0.0, 0.85)
	var m_wrapped: float = wrapf(mean_anomaly, -PI, PI)
	var ecc_anom: float = m_wrapped + (e * sin(m_wrapped))
	if e > 0.0001:
		for _iter: int in range(3):
			var denom: float = maxf(1.0 - (e * cos(ecc_anom)), 0.1)
			ecc_anom -= (ecc_anom - (e * sin(ecc_anom)) - m_wrapped) / denom
	return ecc_anom

## Calcula la posición proyectada 2.5D/3D (x, y, depth_z) con depth_z en [-1.0, +1.0] para una órbita elíptica inclinada.
## Convención de profundidad: +Y en plano orbital proyecta hacia adelante (+depth_z), -Y hacia atrás (-depth_z).
static func calculate_orbit_state_3d(
	semi_major_axis: float,
	initial_theta: float,
	angular_velocity: float,
	global_time: float,
	eccentricity: float = 0.0,
	periapsis_angle: float = 0.0,
	plane_tilt: float = 0.0,
	plane_squash: float = 1.0
) -> Vector3:
	if semi_major_axis <= 0.0001:
		return Vector3.ZERO
	var mean_anomaly: float = initial_theta + (angular_velocity * global_time)
	if (
		absf(eccentricity) <= 0.0001
		and absf(plane_squash - 1.0) <= 0.0001
		and absf(plane_tilt) <= 0.0001
		and absf(periapsis_angle) <= 0.0001
	):
		return Vector3(
			semi_major_axis * cos(mean_anomaly),
			semi_major_axis * sin(mean_anomaly),
			0.0
		)

	var e: float = clampf(eccentricity, 0.0, 0.85)
	var ecc_anom: float = _solve_eccentric_anomaly(mean_anomaly, e)
	var b_factor: float = sqrt(maxf(1.0 - (e * e), 0.01))
	var x_orb: float = semi_major_axis * (cos(ecc_anom) - e)
	var y_orb: float = semi_major_axis * b_factor * sin(ecc_anom)

	var cw: float = cos(periapsis_angle)
	var sw: float = sin(periapsis_angle)
	var x_p: float = (x_orb * cw) - (y_orb * sw)
	var y_p: float = (x_orb * sw) + (y_orb * cw)

	var squash: float = clampf(plane_squash, 0.15, 1.0)
	var sin_inc: float = sqrt(maxf(1.0 - (squash * squash), 0.0))
	var y_proj: float = y_p * squash
	var norm_denom: float = maxf(semi_major_axis * (1.0 + e), 1.0)
	var depth_z: float = clampf((y_p / norm_denom) * sin_inc, -1.0, 1.0)

	var ct: float = cos(plane_tilt)
	var st: float = sin(plane_tilt)
	var screen_x: float = (x_p * ct) - (y_proj * st)
	var screen_y: float = (x_p * st) + (y_proj * ct)
	return Vector3(screen_x, screen_y, depth_z)

## Calcula la velocidad tangencial instantánea proyectada en 2D siguiendo la 2.ª Ley de Kepler (sin asignaciones).
static func calculate_orbit_velocity_2d(
	semi_major_axis: float,
	initial_theta: float,
	angular_velocity: float,
	global_time: float,
	eccentricity: float = 0.0,
	periapsis_angle: float = 0.0,
	plane_tilt: float = 0.0,
	plane_squash: float = 1.0
) -> Vector2:
	if semi_major_axis <= 0.0001 or absf(angular_velocity) <= 0.000001:
		return Vector2.ZERO
	var e: float = clampf(eccentricity, 0.0, 0.85)
	var mean_anomaly: float = initial_theta + (angular_velocity * global_time)
	var ecc_anom: float = _solve_eccentric_anomaly(mean_anomaly, e)
	var de_dt: float = angular_velocity / maxf(1.0 - (e * cos(ecc_anom)), 0.1)
	var b_factor: float = sqrt(maxf(1.0 - (e * e), 0.01))
	var vx_orb: float = -semi_major_axis * sin(ecc_anom) * de_dt
	var vy_orb: float = semi_major_axis * b_factor * cos(ecc_anom) * de_dt

	var cw: float = cos(periapsis_angle)
	var sw: float = sin(periapsis_angle)
	var vx_p: float = (vx_orb * cw) - (vy_orb * sw)
	var vy_p: float = (vx_orb * sw) + (vy_orb * cw)

	var squash: float = clampf(plane_squash, 0.15, 1.0)
	var vy_proj: float = vy_p * squash

	var ct: float = cos(plane_tilt)
	var st: float = sin(plane_tilt)
	return Vector2(
		(vx_p * ct) - (vy_proj * st),
		(vx_p * st) + (vy_proj * ct)
	)

## Calcula la posición cartesiana orbital 2D proyectada para el instante dado (100% retrocompatible con llamadas circulares).
static func calculate_orbit_position(
	orbit_radius: float,
	initial_theta: float,
	angular_velocity: float,
	global_time: float,
	eccentricity: float = 0.0,
	periapsis_angle: float = 0.0,
	plane_tilt: float = 0.0,
	plane_squash: float = 1.0
) -> Vector2:
	var state: Vector3 = calculate_orbit_state_3d(
		orbit_radius,
		initial_theta,
		angular_velocity,
		global_time,
		eccentricity,
		periapsis_angle,
		plane_tilt,
		plane_squash
	)
	return Vector2(state.x, state.y)

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

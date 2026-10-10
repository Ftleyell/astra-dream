class_name KeplerOrbitalSolver
extends RefCounted

## KeplerOrbitalSolver
## Solver analítico determinista de órbitas keplerianas 2D en O(1).
## Resuelve la Ecuación de Kepler (M = E - e*sin(E)) utilizando el método de Newton-Raphson.
## Calcula posición en el plano orbital y aplica rotación de periapsis (argumento de periapsis / periastrón).

const MAX_NEWTON_ITERATIONS: int = 8
const NEWTON_EPSILON: float = 1e-6


## Parámetros de configuración orbital elíptica.
class OrbitalElements:
	var semi_major_axis: float = 1000.0  ## a: semieje mayor (distancia promedio)
	var eccentricity: float = 0.0        ## e: excentricidad [0.0 = circular, < 1.0 = elíptica]
	var orbital_period: float = 60.0     ## T: período orbital completo en segundos
	var periapsis_angle: float = 0.0     ## omega: argumento del periapsis en radianes
	var initial_mean_anomaly: float = 0.0 ## M0: anomalía media inicial en radianes a t = 0

	func _init(
		p_semi_major_axis: float = 1000.0,
		p_eccentricity: float = 0.0,
		p_orbital_period: float = 60.0,
		p_periapsis_angle: float = 0.0,
		p_initial_mean_anomaly: float = 0.0
	) -> void:
		semi_major_axis = maxf(p_semi_major_axis, 1.0)
		eccentricity = clampf(p_eccentricity, 0.0, 0.999)
		orbital_period = maxf(p_orbital_period, 0.001)
		periapsis_angle = p_periapsis_angle
		initial_mean_anomaly = p_initial_mean_anomaly


## Resuelve la Anomalía Excéntrica (E) a partir de la Anomalía Media (M) y excentricidad (e).
## Ecuación de Kepler: f(E) = E - e * sin(E) - M = 0
## Derivada: f'(E) = 1 - e * cos(E)
static func solve_eccentric_anomaly(mean_anomaly: float, eccentricity: float) -> float:
	var e: float = clampf(eccentricity, 0.0, 0.999)
	# Normalizar M al intervalo [-PI, PI] para mejor convergencia inicial
	var m: float = fposmod(mean_anomaly + PI, TAU) - PI

	# Estimación inicial inteligente según excentricidad
	var eccentric_anomaly: float = m
	if e > 0.8:
		eccentric_anomaly = PI if m >= 0.0 else -PI
	else:
		eccentric_anomaly = m + e * sin(m)

	# Iteraciones Newton-Raphson: E_{n+1} = E_n - f(E_n) / f'(E_n)
	for _i in range(MAX_NEWTON_ITERATIONS):
		var f_val: float = eccentric_anomaly - e * sin(eccentric_anomaly) - m
		var f_deriv: float = 1.0 - e * cos(eccentric_anomaly)
		if absf(f_deriv) < 1e-9:
			break
		var delta_e: float = f_val / f_deriv
		eccentric_anomaly -= delta_e
		if absf(delta_e) < NEWTON_EPSILON:
			break

	return eccentric_anomaly


## Resuelve la posición 2D relativa respecto al foco (cuerpo central) para un instante de tiempo t.
static func solve_position_at_time(elements: OrbitalElements, time_sec: float) -> Vector2:
	var mean_motion: float = TAU / elements.orbital_period
	var mean_anomaly: float = elements.initial_mean_anomaly + (mean_motion * time_sec)
	return solve_position_from_mean_anomaly(elements, mean_anomaly)


## Resuelve la posición 2D relativa directamente dada la anomalía media M.
static func solve_position_from_mean_anomaly(elements: OrbitalElements, mean_anomaly: float) -> Vector2:
	var e: float = elements.eccentricity
	var a: float = elements.semi_major_axis
	var ecc_anomaly: float = solve_eccentric_anomaly(mean_anomaly, e)

	# Coordenadas en el plano orbital canónico (foco en (0,0), periapsis a lo largo de +X)
	# x = a * (cos(E) - e)
	# y = a * sqrt(1 - e^2) * sin(E)
	var semi_minor_axis: float = a * sqrt(maxf(1.0 - (e * e), 0.0))
	var local_x: float = a * (cos(ecc_anomaly) - e)
	var local_y: float = semi_minor_axis * sin(ecc_anomaly)

	# Aplicar rotación del periapsis (omega)
	var cos_w: float = cos(elements.periapsis_angle)
	var sin_w: float = sin(elements.periapsis_angle)

	var world_x: float = (local_x * cos_w) - (local_y * sin_w)
	var world_y: float = (local_x * sin_w) + (local_y * cos_w)

	return Vector2(world_x, world_y)


## Calcula la velocidad orbital tangencial aproximada en 2D en el instante t.
static func solve_velocity_at_time(elements: OrbitalElements, time_sec: float, dt: float = 0.01) -> Vector2:
	var pos_a: Vector2 = solve_position_at_time(elements, time_sec - (dt * 0.5))
	var pos_b: Vector2 = solve_position_at_time(elements, time_sec + (dt * 0.5))
	return (pos_b - pos_a) / dt

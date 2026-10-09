class_name CosmicOrbitalSystem
extends RefCounted

## cosmic_orbital_system.gd
## Motor cinemático orbital y coherencia de iluminación radial para cuerpos celestes.
## Calcula la traslación kepleriana circular/elíptica con periodos continuos de 3 a 8 minutos,
## rotación axial y el vector unitario del terminador lumínico dirigido al Sol anfitrión:
## L_dir = normalize(P_sun - P_body).

class CelestialOrbitState:
	var body_id: StringName = &""
	var center_sun_pos: Vector2 = Vector2.ZERO
	var orbit_radius: float = 2400.0
	var orbit_period: float = 300.0
	var initial_phase: float = 0.0
	var clockwise: bool = true
	var current_world_pos: Vector2 = Vector2.ZERO
	var light_direction: Vector2 = Vector2(-0.707106, -0.707106)
	var axial_spin: float = 0.006


## Calcula la posición en el plano de un cuerpo que orbita alrededor de un centro.
static func calculate_orbit_position(
	center_pos: Vector2,
	orbit_radius: float,
	orbit_period: float,
	initial_phase: float,
	time_sec: float,
	clockwise: bool = true
) -> Vector2:
	var safe_period: float = maxf(orbit_period, 1.0)
	var dir_sign: float = -1.0 if clockwise else 1.0
	var angular_speed: float = (TAU / safe_period) * dir_sign
	var angle: float = initial_phase + angular_speed * time_sec
	return center_pos + Vector2(cos(angle), sin(angle)) * orbit_radius


## Calcula el vector de dirección de luz que apunta desde el cuerpo hacia la estrella.
## L_dir = normalize(P_sun - P_body)
static func calculate_light_direction(sun_pos: Vector2, body_pos: Vector2) -> Vector2:
	var diff: Vector2 = sun_pos - body_pos
	if diff.length_squared() < 0.001:
		return Vector2(-0.707106, -0.707106)
	return diff.normalized()


## Evalúa el estado cinemático y lumínico completo para un instante temporal dado.
static func evaluate_orbit(
	center_sun_pos: Vector2,
	orbit_radius: float,
	orbit_period: float,
	initial_phase: float,
	time_sec: float,
	clockwise: bool = true
) -> Dictionary:
	var pos: Vector2 = calculate_orbit_position(
		center_sun_pos,
		orbit_radius,
		orbit_period,
		initial_phase,
		time_sec,
		clockwise
	)
	var l_dir: Vector2 = calculate_light_direction(center_sun_pos, pos)
	return {
		"position": pos,
		"light_direction": l_dir,
	}

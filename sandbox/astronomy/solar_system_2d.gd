class_name SolarSystem2D
extends Node2D

## Representa un sistema solar completo procedural (estrella central + planetas + lunas).
## Genera y orquesta la jerarquía kepleriana determinista a partir de una semilla numérica.

@export var system_profile: CelestialSystemProfile
@export var system_seed: int = 1337

var star_body: OrbitalBody2D = null
var planets: Array[OrbitalBody2D] = []
var _is_built: bool = false
var _bounding_radius: float = 0.0

func _ready() -> void:
	if not _is_built and system_profile != null:
		build_system(system_seed)

## Construye la jerarquía física y visual del sistema solar a partir de la semilla dada.
func build_system(p_seed: int) -> void:
	system_seed = p_seed
	_clear_existing_system()
	if system_profile == null:
		return

	_build_system_hierarchy()
	_is_built = true

## Actualiza el estado astronómico evaluando analíticamente toda la jerarquía en t_global.
func update_astronomical_state(global_time: float) -> void:
	if star_body != null:
		star_body.evaluate_orbital_position(global_time)

func get_bounding_radius() -> float:
	return _bounding_radius

func _clear_existing_system() -> void:
	for child: Node in get_children():
		child.queue_free()
	planets.clear()
	star_body = null
	_bounding_radius = 0.0
	_is_built = false

const STATION_BEACON_SHADER: Shader = preload("res://scenes/combat/environment/space_station_beacon.gdshader")

func _build_system_hierarchy() -> void:
	# 1. Estrella Central
	star_body = OrbitalBody2D.new()
	star_body.name = "CentralStar"
	star_body.body_name = StringName(system_profile.star_name_prefix + "_" + str(system_seed % 1000))
	star_body.orbit_radius = 0.0
	star_body.angular_velocity = 0.0
	star_body.initial_theta = 0.0
	star_body.axial_rotation_velocity = system_profile.star_axial_rotation_speed
	star_body.initial_axial_rotation = CosmicHasher.hash_2d_float(system_seed, 101, 11) * TAU
	star_body.show_orbit_lines = system_profile.show_orbit_lines
	star_body.orbit_line_color = system_profile.orbit_line_color
	star_body.orbit_line_width = system_profile.orbit_line_width

	var star_sprite: Sprite2D = Sprite2D.new()
	star_sprite.name = "StarVisual"
	star_sprite.centered = true
	if not system_profile.star_textures.is_empty():
		var s_idx: int = int(CosmicHasher.hash_2d_float(system_seed, 55, 5) * float(system_profile.star_textures.size()))
		s_idx = clampi(s_idx, 0, system_profile.star_textures.size() - 1)
		star_sprite.texture = system_profile.star_textures[s_idx]
	elif system_profile.star_texture != null:
		star_sprite.texture = system_profile.star_texture

	star_sprite.modulate = system_profile.star_emission_color
	var star_scale: float = system_profile.star_base_radius / 128.0
	star_sprite.scale = Vector2.ONE * maxf(star_scale, 0.5)
	star_body.add_child(star_sprite)
	star_body.set_sprite_reference(star_sprite)
	add_child(star_body)

	# 2. Planetas Primarios
	var planet_count_range: int = system_profile.max_planets - system_profile.min_planets
	var num_planets: int = system_profile.min_planets
	if planet_count_range > 0:
		var planet_rnd: float = CosmicHasher.hash_2d_float(system_seed, 202, 22)
		num_planets += int(planet_rnd * float(planet_count_range + 1))
		num_planets = clampi(num_planets, system_profile.min_planets, system_profile.max_planets)

	var radius_step: float = (system_profile.orbit_radius_max - system_profile.orbit_radius_min) / float(maxi(num_planets, 1))
	var current_orbit_radius: float = system_profile.orbit_radius_min

	for i: int in range(num_planets):
		var p_seed: int = system_seed + ((i + 1) * 733)
		var radius_jitter: float = (CosmicHasher.hash_2d_float(p_seed, 303, 33) - 0.5) * (radius_step * 0.4)
		var actual_radius: float = current_orbit_radius + radius_jitter

		# Tercera ley de Kepler aproximada: v_ang proporcional a r^(-1.5)
		var kepler_scale: float = pow(system_profile.orbit_radius_min / maxf(actual_radius, 1.0), 1.5)
		var dir_sign: float = 1.0 if CosmicHasher.hash_2d_float(p_seed, 404, 44) > 0.1 else -1.0
		var ang_vel: float = system_profile.base_angular_velocity * kepler_scale * dir_sign
		var init_theta: float = CosmicHasher.hash_2d_float(p_seed, 505, 55) * TAU

		var planet_body: OrbitalBody2D = OrbitalBody2D.new()
		planet_body.name = "Planet_" + str(i + 1)
		planet_body.body_name = StringName("Planet_" + str(i + 1))
		planet_body.orbit_radius = actual_radius
		planet_body.angular_velocity = ang_vel
		planet_body.initial_theta = init_theta
		planet_body.axial_rotation_velocity = (CosmicHasher.hash_2d_float(p_seed, 606, 66) - 0.5) * 0.05
		planet_body.initial_axial_rotation = CosmicHasher.hash_2d_float(p_seed, 707, 77) * TAU
		planet_body.show_orbit_lines = system_profile.show_orbit_lines
		planet_body.orbit_line_color = system_profile.orbit_line_color
		planet_body.orbit_line_width = system_profile.orbit_line_width * 0.75

		var planet_sprite: Sprite2D = Sprite2D.new()
		planet_sprite.name = "PlanetVisual"
		planet_sprite.centered = true
		if not system_profile.planet_textures.is_empty():
			var tex_idx: int = int(CosmicHasher.hash_2d_float(p_seed, 808, 88) * float(system_profile.planet_textures.size()))
			tex_idx = clampi(tex_idx, 0, system_profile.planet_textures.size() - 1)
			planet_sprite.texture = system_profile.planet_textures[tex_idx]
		var p_scale_factor: float = lerpf(0.5, 1.1, CosmicHasher.hash_2d_float(p_seed, 909, 99))
		planet_sprite.scale = Vector2.ONE * p_scale_factor
		planet_body.add_child(planet_sprite)
		planet_body.set_sprite_reference(planet_sprite)

		# 3. Estructuras Secundarias (Lunas y Estaciones Espaciales)
		var max_sub_reach: float = 0.0
		var spawn_moon: bool = CosmicHasher.hash_2d_float(p_seed, 1010, 101) <= system_profile.moon_spawn_probability
		var moon_radius: float = 0.0

		if spawn_moon:
			var moon_seed: int = p_seed + 1999
			moon_radius = lerpf(
				system_profile.moon_orbit_radius_range.x,
				system_profile.moon_orbit_radius_range.y,
				CosmicHasher.hash_2d_float(moon_seed, 1111, 111)
			)
			max_sub_reach = maxf(max_sub_reach, moon_radius)
			var moon_ang_vel: float = (system_profile.base_angular_velocity * 4.0) * (1.0 if CosmicHasher.hash_2d_float(moon_seed, 1212, 121) > 0.5 else -1.0)
			var moon_init_theta: float = CosmicHasher.hash_2d_float(moon_seed, 1313, 131) * TAU

			var moon_body: OrbitalBody2D = OrbitalBody2D.new()
			moon_body.name = "Moon_" + str(i + 1)
			moon_body.body_name = StringName("Moon_" + str(i + 1))
			moon_body.orbit_radius = moon_radius
			moon_body.angular_velocity = moon_ang_vel
			moon_body.initial_theta = moon_init_theta
			moon_body.axial_rotation_velocity = (CosmicHasher.hash_2d_float(moon_seed, 1414, 141) - 0.5) * 0.1
			moon_body.initial_axial_rotation = CosmicHasher.hash_2d_float(moon_seed, 1515, 151) * TAU
			moon_body.show_orbit_lines = false

			var moon_sprite: Sprite2D = Sprite2D.new()
			moon_sprite.name = "MoonVisual"
			moon_sprite.centered = true
			if not system_profile.moon_textures.is_empty():
				var moon_tex_idx: int = int(CosmicHasher.hash_2d_float(moon_seed, 1616, 161) * float(system_profile.moon_textures.size()))
				moon_tex_idx = clampi(moon_tex_idx, 0, system_profile.moon_textures.size() - 1)
				moon_sprite.texture = system_profile.moon_textures[moon_tex_idx]
			moon_sprite.scale = Vector2.ONE * 0.25
			moon_body.add_child(moon_sprite)
			moon_body.set_sprite_reference(moon_sprite)

			planet_body.add_orbital_child(moon_body)

		# Estación Espacial diegética con balizas de navegación
		var spawn_station: bool = CosmicHasher.hash_2d_float(p_seed, 2020, 202) <= system_profile.station_spawn_probability
		if spawn_station and not system_profile.space_station_textures.is_empty():
			var station_seed: int = p_seed + 3333
			var station_radius: float = lerpf(
				system_profile.station_orbit_radius_range.x,
				system_profile.station_orbit_radius_range.y,
				CosmicHasher.hash_2d_float(station_seed, 2121, 212)
			)
			if spawn_moon and absf(station_radius - moon_radius) < 50.0:
				station_radius = moon_radius + 75.0

			max_sub_reach = maxf(max_sub_reach, station_radius)
			var st_ang_vel: float = (system_profile.base_angular_velocity * 2.8) * (1.0 if CosmicHasher.hash_2d_float(station_seed, 2222, 222) > 0.5 else -1.0)
			var st_init_theta: float = CosmicHasher.hash_2d_float(station_seed, 2323, 233) * TAU

			var station_body: OrbitalBody2D = OrbitalBody2D.new()
			station_body.name = "Station_" + str(i + 1)
			station_body.body_name = StringName("Station_" + str(i + 1))
			station_body.orbit_radius = station_radius
			station_body.angular_velocity = st_ang_vel
			station_body.initial_theta = st_init_theta
			station_body.axial_rotation_velocity = 0.004
			station_body.initial_axial_rotation = CosmicHasher.hash_2d_float(station_seed, 2424, 244) * TAU
			station_body.show_orbit_lines = false

			var st_sprite: Sprite2D = Sprite2D.new()
			st_sprite.name = "StationVisual"
			st_sprite.centered = true
			var st_tex_idx: int = int(CosmicHasher.hash_2d_float(station_seed, 2525, 255) * float(system_profile.space_station_textures.size()))
			st_tex_idx = clampi(st_tex_idx, 0, system_profile.space_station_textures.size() - 1)
			st_sprite.texture = system_profile.space_station_textures[st_tex_idx]
			st_sprite.scale = Vector2.ONE * 0.35

			# Asignar shader de balizas estroboscópicas
			if STATION_BEACON_SHADER != null:
				var st_mat: ShaderMaterial = ShaderMaterial.new()
				st_mat.shader = STATION_BEACON_SHADER
				st_mat.set_shader_parameter("beacon_intensity", 2.2)
				st_sprite.material = st_mat

			station_body.add_child(st_sprite)
			station_body.set_sprite_reference(st_sprite)

			planet_body.add_orbital_child(station_body)

		star_body.add_orbital_child(planet_body)
		planets.append(planet_body)

		var total_reach: float = actual_radius + max_sub_reach + 100.0
		if total_reach > _bounding_radius:
			_bounding_radius = total_reach

		current_orbit_radius += radius_step

	if _bounding_radius <= 0.0:
		_bounding_radius = system_profile.orbit_radius_max + 500.0

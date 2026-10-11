class_name SolarSystem2D
extends Node2D

## Representa un sistema solar completo procedural (estrella central + planetas + lunas).
## Genera y orquesta la jerarquía kepleriana determinista a partir de una semilla numérica.
## Aplica zonificación térmica por distancia orbital y vector de iluminación día/noche en tiempo real.

enum PlanetZone {
	INTERIOR,
	HABITABLE,
	EXTERIOR,
}

@export var system_profile: CelestialSystemProfile
@export var system_seed: int = 1337

var star_body: OrbitalBody2D = null
var planets: Array[OrbitalBody2D] = []
var active_archetype: StarArchetype = null
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
	update_astronomical_state(0.0)
	_is_built = true

## Actualiza el estado astronómico evaluando analíticamente toda la jerarquía en t_global.
func update_astronomical_state(global_time: float) -> void:
	if star_body != null:
		star_body.evaluate_orbital_position(global_time)
		_update_lighting_vectors()

func get_bounding_radius() -> float:
	return _bounding_radius

func _clear_existing_system() -> void:
	for child: Node in get_children():
		child.queue_free()
	planets.clear()
	star_body = null
	active_archetype = null
	_bounding_radius = 0.0
	_is_built = false

const STAR_CORONA_SHADER: Shader = preload("res://sandbox/shaders/star_corona.gdshader")
const STAR_LIGHT_FIELD_SHADER: Shader = preload("res://sandbox/shaders/star_light_field.gdshader")
const STATION_BEACON_SHADER: Shader = preload("res://scenes/combat/environment/space_station_beacon.gdshader")
const CELESTIAL_BODY_SHADER: Shader = preload("res://sandbox/shaders/celestial_body.gdshader")

static var _light_quad_texture: ImageTexture = null

static func _get_light_quad_texture() -> ImageTexture:
	if _light_quad_texture == null:
		var img: Image = Image.create(2, 2, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_light_quad_texture = ImageTexture.create_from_image(img)
	return _light_quad_texture

func _build_system_hierarchy() -> void:
	active_archetype = system_profile.get_archetype_for_seed(system_seed)

	# 1. Configuración data-driven según arquetipo estelar (o fallback a system_profile)
	var star_prefix: String = system_profile.star_name_prefix
	var star_radius: float = system_profile.star_base_radius
	var star_color: Color = system_profile.star_emission_color
	var axial_speed: float = system_profile.star_axial_rotation_speed
	var heat_distortion: float = 0.045
	var pulse_spd: float = 1.5
	var corona_mult: float = 1.35
	var effective_orbit_min: float = system_profile.orbit_radius_min
	var effective_orbit_max: float = system_profile.orbit_radius_max
	var light_field_mult: float = 1.25
	var light_intensity: float = 0.32
	var heliosphere_noise: float = 0.35
	var heliosphere_feather: float = 0.22
	var day_tint_strength: float = 0.40
	var atmo_tint_strength: float = 0.50
	var effective_min_spacing: float = system_profile.min_orbital_spacing
	var effective_theta_jitter_deg: float = system_profile.planet_theta_jitter_degrees
	var star_tex_list: Array[Texture2D] = system_profile.star_textures

	if active_archetype != null:
		if not active_archetype.name_prefixes.is_empty():
			var p_idx: int = int(CosmicHasher.hash_2d_float(system_seed, 888, 88) * float(active_archetype.name_prefixes.size()))
			p_idx = clampi(p_idx, 0, active_archetype.name_prefixes.size() - 1)
			star_prefix = active_archetype.name_prefixes[p_idx]
		star_radius = active_archetype.star_core_radius
		star_color = active_archetype.star_color
		axial_speed = active_archetype.axial_rotation_speed
		heat_distortion = active_archetype.heat_distortion_strength
		pulse_spd = active_archetype.pulse_speed
		corona_mult = active_archetype.corona_size_multiplier
		effective_orbit_min = active_archetype.orbit_radius_min
		effective_orbit_max = active_archetype.orbit_radius_max
		light_field_mult = active_archetype.light_field_radius_multiplier
		light_intensity = active_archetype.light_field_intensity
		heliosphere_noise = active_archetype.heliosphere_noise_strength
		heliosphere_feather = active_archetype.heliosphere_edge_feather
		day_tint_strength = active_archetype.planet_day_tint_strength
		atmo_tint_strength = active_archetype.planet_atmo_tint_strength
		effective_min_spacing = active_archetype.min_orbital_spacing
		effective_theta_jitter_deg = active_archetype.planet_theta_jitter_degrees
		if not active_archetype.star_textures.is_empty():
			star_tex_list = active_archetype.star_textures

	# 2. Estrella Central
	star_body = OrbitalBody2D.new()
	star_body.name = "CentralStar"
	star_body.body_name = StringName(star_prefix + "_" + str(system_seed % 1000))
	star_body.orbit_radius = 0.0
	star_body.angular_velocity = 0.0
	star_body.initial_theta = 0.0
	star_body.axial_rotation_velocity = axial_speed
	star_body.initial_axial_rotation = CosmicHasher.hash_2d_float(system_seed, 101, 11) * TAU
	star_body.show_orbit_lines = system_profile.show_orbit_lines
	star_body.orbit_line_color = system_profile.orbit_line_color
	star_body.orbit_line_width = system_profile.orbit_line_width

	# 2.1 Campo de Luz Orbital y Bioma Estelar (Heliosfera)
	var light_field_radius: float = effective_orbit_max * light_field_mult
	var light_sprite: Sprite2D = Sprite2D.new()
	light_sprite.name = "SolarSystemLightField"
	light_sprite.centered = true
	light_sprite.texture = _get_light_quad_texture()
	# Quad de 2x2 px: con scale = light_field_radius, su diámetro total es 2 * light_field_radius (radio efectivo = light_field_radius)
	light_sprite.scale = Vector2.ONE * light_field_radius
	if STAR_LIGHT_FIELD_SHADER != null:
		var light_mat: ShaderMaterial = ShaderMaterial.new()
		light_mat.shader = STAR_LIGHT_FIELD_SHADER
		light_mat.set_shader_parameter("light_color", star_color)
		light_mat.set_shader_parameter("intensity", light_intensity)
		light_mat.set_shader_parameter("falloff_exponent", 0.85)
		light_mat.set_shader_parameter("pulse_speed", pulse_spd * 0.4)
		light_mat.set_shader_parameter("heliosphere_noise_strength", heliosphere_noise)
		light_mat.set_shader_parameter("heliosphere_edge_feather", heliosphere_feather)
		light_mat.set_shader_parameter("noise_scale", 8.0)
		light_sprite.material = light_mat
	light_sprite.z_index = -1
	star_body.add_child(light_sprite)

	# 2.2 Visual de la Estrella
	var star_sprite: Sprite2D = Sprite2D.new()
	star_sprite.name = "StarVisual"
	star_sprite.centered = true
	var selected_tex: Texture2D = null
	if not star_tex_list.is_empty():
		var s_idx: int = int(CosmicHasher.hash_2d_float(system_seed, 55, 5) * float(star_tex_list.size()))
		s_idx = clampi(s_idx, 0, star_tex_list.size() - 1)
		selected_tex = star_tex_list[s_idx]
	elif system_profile.star_texture != null:
		selected_tex = system_profile.star_texture

	star_sprite.texture = selected_tex
	var corona_int: float = 0.95
	if active_archetype != null:
		corona_int = active_archetype.corona_intensity

	if STAR_CORONA_SHADER != null:
		var star_mat: ShaderMaterial = ShaderMaterial.new()
		star_mat.shader = STAR_CORONA_SHADER
		star_mat.set_shader_parameter("star_texture", selected_tex)
		star_mat.set_shader_parameter("star_tint", star_color)
		star_mat.set_shader_parameter("heat_distortion_strength", heat_distortion)
		star_mat.set_shader_parameter("pulse_speed", pulse_spd)
		star_mat.set_shader_parameter("corona_intensity", corona_int)
		star_mat.set_shader_parameter("black_threshold", 0.05)
		star_sprite.material = star_mat
	else:
		star_sprite.modulate = star_color

	var tex_w: float = float(selected_tex.get_width()) if selected_tex != null and selected_tex.get_width() > 0 else 512.0
	var star_diameter: float = star_radius * corona_mult * 2.0
	star_sprite.scale = Vector2.ONE * (star_diameter / tex_w)
	star_body.add_child(star_sprite)
	star_body.set_sprite_reference(star_sprite)
	add_child(star_body)

	# 3. Planetas Primarios
	var planet_count_range: int = system_profile.max_planets - system_profile.min_planets
	var num_planets: int = system_profile.min_planets
	if planet_count_range > 0:
		var planet_rnd: float = CosmicHasher.hash_2d_float(system_seed, 202, 22)
		num_planets += int(planet_rnd * float(planet_count_range + 1))
		num_planets = clampi(num_planets, system_profile.min_planets, system_profile.max_planets)

	var base_system_theta: float = CosmicHasher.hash_2d_float(system_seed, 505, 55) * TAU
	var theta_step: float = TAU / float(maxi(num_planets, 1))
	var theta_jitter_rad: float = deg_to_rad(effective_theta_jitter_deg)

	var prev_orbit_radius: float = 0.0

	for i: int in range(num_planets):
		var p_seed: int = system_seed + ((i + 1) * 733)

		# 3.1 Progresión expansiva y espaciado orbital
		var t_norm: float = float(i) / float(maxi(num_planets - 1, 1))
		var expansion_curve: float = pow(t_norm, 1.15)
		var ideal_radius: float = lerpf(effective_orbit_min, effective_orbit_max, expansion_curve)

		var radius_jitter: float = (CosmicHasher.hash_2d_float(p_seed, 303, 33) - 0.5) * (effective_min_spacing * 0.35)
		var actual_radius: float = ideal_radius + radius_jitter

		if i > 0:
			actual_radius = maxf(actual_radius, prev_orbit_radius + effective_min_spacing)
		prev_orbit_radius = actual_radius

		var kepler_scale: float = pow(effective_orbit_min / maxf(actual_radius, 1.0), 1.5)
		var dir_sign: float = 1.0 if CosmicHasher.hash_2d_float(p_seed, 404, 44) > 0.1 else -1.0
		var ang_vel: float = system_profile.base_angular_velocity * kepler_scale * dir_sign

		var planet_theta_jitter: float = (CosmicHasher.hash_2d_float(p_seed, 515, 51) - 0.5) * 2.0 * theta_jitter_rad
		var init_theta: float = fposmod(base_system_theta + (float(i) * theta_step) + planet_theta_jitter, TAU)
		var dist_norm: float = clampf(actual_radius / maxf(effective_orbit_max, 1.0), 0.0, 1.0)
		var dist_tint_attenuation: float = 1.0 - (dist_norm * 0.45) # 1.0 cerca del sol, ~0.55 en la órbita más lejana

		# 3.2 Clasificación de Zona Astrofísica (Interior, Habitable, Exterior)
		var zone: PlanetZone = PlanetZone.HABITABLE
		if num_planets <= 2:
			zone = PlanetZone.HABITABLE
		elif i == 0:
			zone = PlanetZone.INTERIOR
		elif i == num_planets - 1:
			zone = PlanetZone.EXTERIOR
		else:
			if num_planets == 4:
				zone = PlanetZone.HABITABLE if i == 1 else PlanetZone.EXTERIOR
			elif num_planets == 5:
				zone = PlanetZone.INTERIOR if i == 1 else (PlanetZone.HABITABLE if i == 2 else PlanetZone.EXTERIOR)
			elif num_planets >= 6:
				zone = PlanetZone.INTERIOR if i == 1 else (PlanetZone.HABITABLE if (i == 2 or i == 3) else PlanetZone.EXTERIOR)
			else:
				zone = PlanetZone.HABITABLE

		# 3.3 Selección de Textura y Propiedades Físicas según Zona
		var p_tex: Texture2D = null
		var target_diameter: float = 260.0
		var is_gas: bool = false
		var atmo_color: Color = Color(0.35, 0.75, 1.0, 1.0)
		var atmo_intensity: float = 1.6
		var outer_thick: float = 0.026

		match zone:
			PlanetZone.INTERIOR:
				var int_list: Array[Texture2D] = system_profile.interior_planet_textures if not system_profile.interior_planet_textures.is_empty() else system_profile.planet_textures
				if not int_list.is_empty():
					var idx: int = int(CosmicHasher.hash_2d_float(p_seed, 808, 88) * float(int_list.size()))
					p_tex = int_list[clampi(idx, 0, int_list.size() - 1)]
				is_gas = (p_tex != null and p_tex.resource_path.to_lower().contains("gas"))
				if is_gas:
					target_diameter = 260.0
					atmo_color = Color(0.88, 0.72, 0.52, 0.9)
					atmo_intensity = 1.4
					outer_thick = 0.032
				else:
					target_diameter = 180.0
					atmo_color = Color(0.85, 0.65, 0.45, 0.5)
					atmo_intensity = 0.35
					outer_thick = 0.008

			PlanetZone.HABITABLE:
				var hab_list: Array[Texture2D] = system_profile.habitable_planet_textures if not system_profile.habitable_planet_textures.is_empty() else system_profile.planet_textures
				if not hab_list.is_empty():
					var idx: int = int(CosmicHasher.hash_2d_float(p_seed, 808, 88) * float(hab_list.size()))
					p_tex = hab_list[clampi(idx, 0, hab_list.size() - 1)]
				target_diameter = 220.0
				atmo_color = Color(0.35, 0.75, 1.0, 1.0)
				atmo_intensity = 1.6
				outer_thick = 0.026

			PlanetZone.EXTERIOR:
				var ext_list: Array[Texture2D] = system_profile.exterior_planet_textures if not system_profile.exterior_planet_textures.is_empty() else system_profile.planet_textures
				if not ext_list.is_empty():
					var idx: int = int(CosmicHasher.hash_2d_float(p_seed, 808, 88) * float(ext_list.size()))
					p_tex = ext_list[clampi(idx, 0, ext_list.size() - 1)]
				is_gas = (p_tex != null and p_tex.resource_path.to_lower().contains("gas"))
				if is_gas:
					target_diameter = 280.0
					atmo_color = Color(0.7, 0.85, 1.0, 0.9)
					atmo_intensity = 1.3
					outer_thick = 0.03
				else:
					target_diameter = 190.0
					atmo_color = Color(0.65, 0.88, 1.0, 0.8)
					atmo_intensity = 0.75
					outer_thick = 0.015

		if p_tex == null and not system_profile.planet_textures.is_empty():
			p_tex = system_profile.planet_textures[0]

		target_diameter *= system_profile.planet_size_multiplier

		var planet_body: OrbitalBody2D = OrbitalBody2D.new()
		planet_body.name = "Planet_" + str(i + 1)
		planet_body.body_name = StringName("Planet_" + str(i + 1))
		planet_body.orbit_radius = actual_radius
		planet_body.angular_velocity = ang_vel
		planet_body.initial_theta = init_theta
		planet_body.axial_rotation_velocity = 0.0 # Desacoplado: el shader maneja la rotación axial visual
		planet_body.initial_axial_rotation = 0.0
		planet_body.show_orbit_lines = system_profile.show_orbit_lines
		planet_body.orbit_line_color = system_profile.orbit_line_color
		planet_body.orbit_line_width = system_profile.orbit_line_width * 0.75

		var planet_sprite: Sprite2D = Sprite2D.new()
		planet_sprite.name = "PlanetVisual"
		planet_sprite.centered = true
		planet_sprite.texture = p_tex

		var p_tex_w: float = float(p_tex.get_width()) if p_tex != null and p_tex.get_width() > 0 else 2048.0
		var p_scale_factor: float = target_diameter / p_tex_w
		planet_sprite.scale = Vector2.ONE * p_scale_factor

		var planet_visual_diameter: float = target_diameter
		var planet_visual_radius: float = planet_visual_diameter * 0.5

		# 3.4 Asignación de Shader Universal de Cuerpos Celestes
		if CELESTIAL_BODY_SHADER != null:
			var p_mat: ShaderMaterial = ShaderMaterial.new()
			p_mat.shader = CELESTIAL_BODY_SHADER
			p_mat.set_shader_parameter("axial_spin_speed", (CosmicHasher.hash_2d_float(p_seed, 606, 66) - 0.5) * 0.02)
			p_mat.set_shader_parameter("night_ambient", 0.08)
			p_mat.set_shader_parameter("planet_radius", 0.485)
			p_mat.set_shader_parameter("edge_crop_margin", 0.012)
			p_mat.set_shader_parameter("rim_edge_feather", 0.007)
			p_mat.set_shader_parameter("atmosphere_color", atmo_color)
			p_mat.set_shader_parameter("atmosphere_intensity", atmo_intensity)
			p_mat.set_shader_parameter("outer_atmosphere_thickness", outer_thick)
			p_mat.set_shader_parameter("emission_glow", 0.0)

			# Tinte de luz estelar con atenuación física suave según distancia orbital
			p_mat.set_shader_parameter("star_light_color", star_color)
			p_mat.set_shader_parameter("star_light_tint_strength", day_tint_strength * dist_tint_attenuation)
			p_mat.set_shader_parameter("star_atmo_tint_strength", atmo_tint_strength * dist_tint_attenuation)
			planet_sprite.material = p_mat

		planet_body.add_child(planet_sprite)
		planet_body.set_sprite_reference(planet_sprite)

		# 4. Estructuras Secundarias (Lunas Diegéticas y Estaciones Espaciales)
		var max_sub_reach: float = 0.0

		# 4.1 Generación de Lunas según Zona
		var num_moons: int = 0
		match zone:
			PlanetZone.INTERIOR:
				if CosmicHasher.hash_2d_float(p_seed, 1010, 101) <= (system_profile.moon_spawn_probability * 0.6):
					num_moons = 1
			PlanetZone.HABITABLE:
				num_moons = 1 if CosmicHasher.hash_2d_float(p_seed, 1010, 101) > 0.4 else 2
			PlanetZone.EXTERIOR:
				if CosmicHasher.hash_2d_float(p_seed, 1010, 101) <= (system_profile.moon_spawn_probability * 0.7):
					num_moons = 1

		for m_idx: int in range(num_moons):
			var moon_seed: int = p_seed + 1999 + (m_idx * 431)
			var is_magma: bool = (zone == PlanetZone.INTERIOR)

			var moon_tex: Texture2D = null
			if is_magma:
				moon_tex = system_profile.magma_moon_texture if system_profile.magma_moon_texture != null else (system_profile.moon_textures[1] if system_profile.moon_textures.size() > 1 else null)
			else:
				moon_tex = system_profile.normal_moon_texture if system_profile.normal_moon_texture != null else (system_profile.moon_textures[0] if not system_profile.moon_textures.is_empty() else null)

			if moon_tex == null and not system_profile.moon_textures.is_empty():
				moon_tex = system_profile.moon_textures[0]

			# Radio orbital ordenado concéntricamente
			var base_orbit_dist: float = planet_visual_radius * (1.75 + float(m_idx) * 0.85)
			var moon_radius: float = base_orbit_dist + (CosmicHasher.hash_2d_float(moon_seed, 1111, 111) - 0.5) * 30.0
			max_sub_reach = maxf(max_sub_reach, moon_radius + (planet_visual_diameter * 0.15 * 0.5))

			var moon_ang_vel: float = (system_profile.base_angular_velocity * (3.8 + float(m_idx) * 1.2)) * (1.0 if CosmicHasher.hash_2d_float(moon_seed, 1212, 121) > 0.5 else -1.0)
			var moon_init_theta: float = CosmicHasher.hash_2d_float(moon_seed, 1313, 131) * TAU

			var moon_body: OrbitalBody2D = OrbitalBody2D.new()
			moon_body.name = "Moon_" + str(i + 1) + "_" + str(m_idx + 1)
			moon_body.body_name = StringName(moon_body.name)
			moon_body.orbit_radius = moon_radius
			moon_body.angular_velocity = moon_ang_vel
			moon_body.initial_theta = moon_init_theta
			moon_body.axial_rotation_velocity = 0.0
			moon_body.initial_axial_rotation = 0.0
			moon_body.show_orbit_lines = false

			var moon_sprite: Sprite2D = Sprite2D.new()
			moon_sprite.name = "MoonVisual"
			moon_sprite.centered = true
			moon_sprite.texture = moon_tex

			var m_tex_w: float = float(moon_tex.get_width()) if moon_tex != null and moon_tex.get_width() > 0 else 2048.0
			var moon_target_diam: float = planet_visual_diameter * system_profile.moon_size_ratio
			var moon_scale: float = moon_target_diam / m_tex_w
			moon_sprite.scale = Vector2.ONE * moon_scale

			if CELESTIAL_BODY_SHADER != null:
				var m_mat: ShaderMaterial = ShaderMaterial.new()
				m_mat.shader = CELESTIAL_BODY_SHADER
				m_mat.set_shader_parameter("axial_spin_speed", (CosmicHasher.hash_2d_float(moon_seed, 1414, 141) - 0.5) * 0.03)
				m_mat.set_shader_parameter("night_ambient", 0.07)
				m_mat.set_shader_parameter("planet_radius", 0.485)
				m_mat.set_shader_parameter("edge_crop_margin", 0.012)
				m_mat.set_shader_parameter("rim_edge_feather", 0.007)
				m_mat.set_shader_parameter("atmosphere_intensity", 0.0)
				m_mat.set_shader_parameter("outer_atmosphere_thickness", 0.0)
				if is_magma:
					m_mat.set_shader_parameter("emission_glow", 0.45)
					m_mat.set_shader_parameter("emission_color", Color(1.0, 0.35, 0.1, 1.0))
				else:
					m_mat.set_shader_parameter("emission_glow", 0.0)
				m_mat.set_shader_parameter("star_light_color", star_color)
				m_mat.set_shader_parameter("star_light_tint_strength", day_tint_strength * dist_tint_attenuation)
				m_mat.set_shader_parameter("star_atmo_tint_strength", 0.0)
				moon_sprite.material = m_mat

			moon_body.add_child(moon_sprite)
			moon_body.set_sprite_reference(moon_sprite)
			planet_body.add_orbital_child(moon_body)

		# 4.2 Estaciones Espaciales Diegéticas
		var spawn_station: bool = false
		if zone == PlanetZone.HABITABLE or system_profile.station_spawn_probability >= 1.0:
			spawn_station = true # Garantizada en planetas habitables o cuando el perfil exige 1.0
		else:
			spawn_station = CosmicHasher.hash_2d_float(p_seed, 2020, 202) <= (system_profile.station_spawn_probability * 0.3)

		if spawn_station and not system_profile.space_station_textures.is_empty():
			var station_seed: int = p_seed + 3333
			var st_orbit_mult: float = lerpf(1.9, 2.5, CosmicHasher.hash_2d_float(station_seed, 2121, 212))
			var station_radius: float = planet_visual_radius * st_orbit_mult

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
			var st_texture: Texture2D = system_profile.space_station_textures[st_tex_idx]
			st_sprite.texture = st_texture

			var st_tex_w: float = float(st_texture.get_width()) if st_texture != null and st_texture.get_width() > 0 else 128.0
			var station_target_diameter: float = planet_visual_diameter * system_profile.station_size_ratio
			var st_scale_factor: float = station_target_diameter / st_tex_w
			st_sprite.scale = Vector2.ONE * st_scale_factor

			max_sub_reach = maxf(max_sub_reach, station_radius + (station_target_diameter * 0.5))

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

	if _bounding_radius <= 0.0:
		_bounding_radius = effective_orbit_max + 500.0
	_bounding_radius = maxf(_bounding_radius, light_field_radius)

## Actualiza dinámicamente los vectores de luz (terminador día/noche) apuntando a la estrella central.
func _update_lighting_vectors() -> void:
	for planet_body: OrbitalBody2D in planets:
		if not is_instance_valid(planet_body):
			continue
		var p_pos: Vector2 = planet_body.position
		var light_dir_planet: Vector2 = -p_pos.normalized() if p_pos.length_squared() > 1.0 else Vector2(-1.0, 0.0)
		var p_sprite: Sprite2D = planet_body.get_sprite()
		if p_sprite != null and p_sprite.material is ShaderMaterial:
			(p_sprite.material as ShaderMaterial).set_shader_parameter("light_direction", light_dir_planet)

		for sub_body: OrbitalBody2D in planet_body.get_orbital_children():
			if not is_instance_valid(sub_body):
				continue
			var sub_sprite: Sprite2D = sub_body.get_sprite()
			if sub_sprite != null and sub_sprite.material is ShaderMaterial:
				var moon_world_in_system: Vector2 = p_pos + sub_body.position
				var light_dir_moon: Vector2 = -moon_world_in_system.normalized() if moon_world_in_system.length_squared() > 1.0 else light_dir_planet
				(sub_sprite.material as ShaderMaterial).set_shader_parameter("light_direction", light_dir_moon)

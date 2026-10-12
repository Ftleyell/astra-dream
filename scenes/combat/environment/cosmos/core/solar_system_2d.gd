class_name CosmosSolarSystem2D
extends Node2D

const CosmicPoiConfig = preload("res://scenes/combat/environment/cosmos/resources/cosmic_poi_config.gd")

## Representa un sistema solar completo procedural (estrella central + planetas + lunas).
## Genera y orquesta la jerarquía kepleriana determinista a partir de una semilla numérica.
## Aplica zonificación térmica por distancia orbital y vector de iluminación día/noche en tiempo real.

enum PlanetZone {
	INTERIOR,
	HABITABLE,
	EXTERIOR,
}

@export var system_profile: CosmosCelestialSystemProfile
@export var system_seed: int = 1337

var star_body: CosmosOrbitalBody2D = null
var planets: Array[CosmosOrbitalBody2D] = []
var active_archetype: CosmosStarArchetype = null
var current_poi_config: CosmicPoiConfig = null
var shadow_projector: CosmosPlanetaryShadowProjector2D = null
var _is_built: bool = false
var _bounding_radius: float = 0.0
var _light_field_radius: float = 0.0
var _effective_orbit_max: float = 3000.0
var _planet_day_exposure: float = 1.30
var _star_core_brightness: float = 1.25

func _ready() -> void:
	if not _is_built and system_profile != null:
		build_system(system_seed)

## Construye la jerarquía física y visual del sistema solar a partir de la semilla dada y POI opcional.
func build_system(p_seed: int, p_poi_config: CosmicPoiConfig = null) -> void:
	system_seed = p_seed
	current_poi_config = p_poi_config
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
		remove_child(child)
		child.queue_free()
	planets.clear()
	star_body = null
	active_archetype = null
	if shadow_projector != null:
		shadow_projector.clear_projector()
	shadow_projector = null
	_bounding_radius = 0.0
	_light_field_radius = 0.0
	_is_built = false

const STAR_CORONA_SHADER: Shader = preload("res://scenes/combat/environment/cosmos/shaders/star_corona.gdshader")
const STAR_FLAT_CORE_SHADER: Shader = preload("res://scenes/combat/environment/cosmos/shaders/star_flat_core.gdshader")
const STAR_LIGHT_FIELD_SHADER: Shader = preload("res://scenes/combat/environment/cosmos/shaders/star_light_field.gdshader")
const STATION_BEACON_SHADER: Shader = preload("res://scenes/combat/environment/space_station_beacon.gdshader")
const CELESTIAL_BODY_SHADER: Shader = preload("res://scenes/combat/environment/cosmos/shaders/celestial_body.gdshader")
const PLANETARY_SHADOW_CONE_SHADER: Shader = preload("res://scenes/combat/environment/cosmos/shaders/planetary_shadow_cone.gdshader")
const COSMIC_SHADOW_GROUP_SHADER: Shader = preload("res://scenes/combat/environment/cosmos/shaders/cosmic_shadow_group.gdshader")

static var _light_quad_texture: ImageTexture = null

static func _get_light_quad_texture() -> ImageTexture:
	if _light_quad_texture == null:
		var img: Image = Image.create(2, 2, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_light_quad_texture = ImageTexture.create_from_image(img)
	return _light_quad_texture

func _build_system_hierarchy() -> void:
	if current_poi_config != null and current_poi_config.star_archetype != null:
		active_archetype = current_poi_config.star_archetype
	else:
		active_archetype = system_profile.get_archetype_for_seed(system_seed)
	var shadow_cfg: CosmosShadowSystemConfig = system_profile.get_effective_shadow_config()
	var planetary_cfg: CosmosPlanetarySystemConfig = system_profile.get_effective_planetary_config()
	var star_vis_cfg: CosmosStarVisualConfig = active_archetype.get_effective_visual_config() if active_archetype != null else system_profile.get_effective_star_visual_config()

	# 1. Configuración data-driven según arquetipo estelar (o fallback a sub-recursos)
	var star_prefix: String = star_vis_cfg.star_name_prefix
	var star_radius: float = star_vis_cfg.star_core_radius
	var star_color: Color = star_vis_cfg.star_color
	var star_flat_core_col: Color = star_vis_cfg.flat_core_color
	var star_flat_core_rad: float = star_vis_cfg.flat_core_radius
	var star_flat_core_feat: float = star_vis_cfg.flat_core_feather
	var axial_speed: float = star_vis_cfg.axial_rotation_speed
	var heat_distortion: float = star_vis_cfg.heat_distortion_strength
	var pulse_spd: float = star_vis_cfg.pulse_speed
	var corona_mult: float = star_vis_cfg.corona_size_multiplier
	var corona_int: float = star_vis_cfg.corona_intensity
	var effective_orbit_min: float = active_archetype.orbit_radius_min if active_archetype != null else planetary_cfg.orbit_radius_min
	var effective_orbit_max: float = active_archetype.orbit_radius_max if active_archetype != null else planetary_cfg.orbit_radius_max
	var light_field_mult: float = star_vis_cfg.light_field_radius_multiplier
	var light_intensity: float = star_vis_cfg.light_field_intensity
	var heliosphere_noise: float = star_vis_cfg.heliosphere_noise_strength
	var heliosphere_feather: float = star_vis_cfg.heliosphere_edge_feather
	var day_tint_strength: float = star_vis_cfg.planet_day_tint_strength
	var atmo_tint_strength: float = star_vis_cfg.planet_atmo_tint_strength
	var effective_min_spacing: float = active_archetype.min_orbital_spacing if active_archetype != null else planetary_cfg.min_orbital_spacing
	var effective_theta_jitter_deg: float = active_archetype.planet_theta_jitter_degrees if active_archetype != null else planetary_cfg.planet_theta_jitter_degrees
	var star_tex_list: Array[Texture2D] = star_vis_cfg.star_textures

	if active_archetype != null:
		if not active_archetype.name_prefixes.is_empty():
			var p_idx: int = int(CosmosHasher.hash_2d_float(system_seed, 888, 88) * float(active_archetype.name_prefixes.size()))
			p_idx = clampi(p_idx, 0, active_archetype.name_prefixes.size() - 1)
			star_prefix = active_archetype.name_prefixes[p_idx]

	if star_flat_core_col.a <= 0.0:
		star_flat_core_col = star_color

	# 2. Estrella Central
	star_body = CosmosOrbitalBody2D.new()
	star_body.name = "CentralStar"
	var final_star_name: StringName = StringName(star_prefix + "_" + str(system_seed % 1000))
	if current_poi_config != null and current_poi_config.custom_label != &"":
		final_star_name = current_poi_config.custom_label
	star_body.body_name = final_star_name
	star_body.orbit_radius = 0.0
	star_body.angular_velocity = 0.0
	star_body.initial_theta = 0.0
	star_body.axial_rotation_velocity = axial_speed
	star_body.initial_axial_rotation = CosmosHasher.hash_2d_float(system_seed, 101, 11) * TAU
	star_body.show_orbit_lines = system_profile.show_orbit_lines
	star_body.orbit_line_color = system_profile.orbit_line_color
	star_body.orbit_line_width = system_profile.orbit_line_width

	# 2.1 Campo de Luz Orbital y Bioma Estelar (Heliosfera)
	var light_field_radius: float = effective_orbit_max * light_field_mult
	_light_field_radius = light_field_radius
	_effective_orbit_max = effective_orbit_max
	_planet_day_exposure = planetary_cfg.planet_day_exposure
	_star_core_brightness = star_vis_cfg.core_brightness

	# Inicializar CosmosPlanetaryShadowProjector2D modular
	shadow_projector = CosmosPlanetaryShadowProjector2D.new(_get_light_quad_texture())
	add_child(shadow_projector)
	shadow_projector.setup_config(shadow_cfg)

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

	var star_diameter: float = star_radius * corona_mult * 2.0

	# 2.2 Fondo Plano Sólido del Núcleo (Anti-agujeros y oclusión de fondo)
	var flat_core_sprite: Sprite2D = Sprite2D.new()
	flat_core_sprite.name = "StarFlatCore"
	flat_core_sprite.centered = true
	flat_core_sprite.texture = _get_light_quad_texture()
	flat_core_sprite.scale = Vector2.ONE * (star_diameter * 0.5)
	if STAR_FLAT_CORE_SHADER != null:
		var core_mat: ShaderMaterial = ShaderMaterial.new()
		core_mat.shader = STAR_FLAT_CORE_SHADER
		core_mat.set_shader_parameter("flat_color", star_flat_core_col)
		core_mat.set_shader_parameter("core_radius", star_flat_core_rad)
		core_mat.set_shader_parameter("edge_feather", star_flat_core_feat)
		flat_core_sprite.material = core_mat
	else:
		flat_core_sprite.modulate = star_flat_core_col
	star_body.add_child(flat_core_sprite)

	# 2.3 Visual de la Estrella (Corona y Textura Animada)
	var star_sprite: Sprite2D = Sprite2D.new()
	star_sprite.name = "StarVisual"
	star_sprite.centered = true
	var selected_tex: Texture2D = null
	if not star_tex_list.is_empty():
		var s_idx: int = int(CosmosHasher.hash_2d_float(system_seed, 55, 5) * float(star_tex_list.size()))
		s_idx = clampi(s_idx, 0, star_tex_list.size() - 1)
		selected_tex = star_tex_list[s_idx]
	elif system_profile.star_texture != null:
		selected_tex = system_profile.star_texture

	star_sprite.texture = selected_tex

	if STAR_CORONA_SHADER != null:
		var star_mat: ShaderMaterial = ShaderMaterial.new()
		star_mat.shader = STAR_CORONA_SHADER
		star_mat.set_shader_parameter("star_texture", selected_tex)
		star_mat.set_shader_parameter("star_tint", star_color)
		star_mat.set_shader_parameter("heat_distortion_strength", heat_distortion)
		star_mat.set_shader_parameter("pulse_speed", pulse_spd)
		star_mat.set_shader_parameter("corona_intensity", corona_int)
		star_mat.set_shader_parameter("core_brightness", star_vis_cfg.core_brightness)
		star_mat.set_shader_parameter("black_threshold", 0.05)
		star_sprite.material = star_mat
	else:
		star_sprite.modulate = star_color

	var tex_w: float = float(selected_tex.get_width()) if selected_tex != null and selected_tex.get_width() > 0 else 512.0
	star_sprite.scale = Vector2.ONE * (star_diameter / tex_w)
	star_body.add_child(star_sprite)
	star_body.set_sprite_reference(star_sprite)
	add_child(star_body)

	# 3. Planetas Primarios
	var num_planets: int = planetary_cfg.min_planets
	if current_poi_config != null and current_poi_config.planet_count >= 0:
		num_planets = current_poi_config.planet_count
	else:
		var planet_count_range: int = planetary_cfg.max_planets - planetary_cfg.min_planets
		if planet_count_range > 0:
			var planet_rnd: float = CosmosHasher.hash_2d_float(system_seed, 202, 22)
			num_planets += int(planet_rnd * float(planet_count_range + 1))
			num_planets = clampi(num_planets, planetary_cfg.min_planets, planetary_cfg.max_planets)

	var base_system_theta: float = CosmosHasher.hash_2d_float(system_seed, 505, 55) * TAU
	var theta_step: float = TAU / float(maxi(num_planets, 1))
	var theta_jitter_rad: float = deg_to_rad(effective_theta_jitter_deg)

	var prev_orbit_radius: float = 0.0

	for i: int in range(num_planets):
		var p_seed: int = system_seed + ((i + 1) * 733)

		# 3.1 Progresión expansiva y espaciado orbital
		var t_norm: float = float(i) / float(maxi(num_planets - 1, 1))
		var expansion_curve: float = pow(t_norm, 1.15)
		var ideal_radius: float = lerpf(effective_orbit_min, effective_orbit_max, expansion_curve)

		var radius_jitter: float = (CosmosHasher.hash_2d_float(p_seed, 303, 33) - 0.5) * (effective_min_spacing * 0.35)
		var actual_radius: float = ideal_radius + radius_jitter

		if i > 0:
			actual_radius = maxf(actual_radius, prev_orbit_radius + effective_min_spacing)
		prev_orbit_radius = actual_radius

		var kepler_scale: float = pow(effective_orbit_min / maxf(actual_radius, 1.0), 1.5)
		var dir_sign: float = 1.0 if CosmosHasher.hash_2d_float(p_seed, 404, 44) > 0.1 else -1.0
		var ang_vel: float = CosmosKeplerOrbitMath.calculate_keplerian_angular_velocity(system_profile.base_angular_velocity, effective_orbit_min, actual_radius, dir_sign)

		var planet_theta_jitter: float = (CosmosHasher.hash_2d_float(p_seed, 515, 51) - 0.5) * 2.0 * theta_jitter_rad
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
				var int_list: Array[Texture2D] = planetary_cfg.interior_planet_textures if not planetary_cfg.interior_planet_textures.is_empty() else planetary_cfg.planet_textures
				if not int_list.is_empty():
					var idx: int = int(CosmosHasher.hash_2d_float(p_seed, 808, 88) * float(int_list.size()))
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
				var hab_list: Array[Texture2D] = planetary_cfg.habitable_planet_textures if not planetary_cfg.habitable_planet_textures.is_empty() else planetary_cfg.planet_textures
				if not hab_list.is_empty():
					var idx: int = int(CosmosHasher.hash_2d_float(p_seed, 808, 88) * float(hab_list.size()))
					p_tex = hab_list[clampi(idx, 0, hab_list.size() - 1)]
				target_diameter = 220.0
				atmo_color = Color(0.35, 0.75, 1.0, 1.0)
				atmo_intensity = 1.6
				outer_thick = 0.026

			PlanetZone.EXTERIOR:
				var ext_list: Array[Texture2D] = planetary_cfg.exterior_planet_textures if not planetary_cfg.exterior_planet_textures.is_empty() else planetary_cfg.planet_textures
				if not ext_list.is_empty():
					var idx: int = int(CosmosHasher.hash_2d_float(p_seed, 808, 88) * float(ext_list.size()))
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

		if p_tex == null and not planetary_cfg.planet_textures.is_empty():
			p_tex = planetary_cfg.planet_textures[0]

		target_diameter *= planetary_cfg.planet_size_multiplier

		var planet_body: CosmosOrbitalBody2D = CosmosOrbitalBody2D.new()
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
		# Radio del disco sólido visible tras el recorte analítico del shader (0.485 - 0.012 = 0.473)
		var planet_visual_radius: float = planet_visual_diameter * 0.473

		# 3.4 Asignación de Shader Universal de Cuerpos Celestes
		if CELESTIAL_BODY_SHADER != null:
			var p_mat: ShaderMaterial = ShaderMaterial.new()
			p_mat.shader = CELESTIAL_BODY_SHADER
			p_mat.set_shader_parameter("axial_spin_speed", (CosmosHasher.hash_2d_float(p_seed, 606, 66) - 0.5) * 0.02)
			p_mat.set_shader_parameter("night_ambient", planetary_cfg.planet_night_ambient)
			p_mat.set_shader_parameter("day_exposure_boost", planetary_cfg.planet_day_exposure)
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
		planet_body.set_meta(&"visual_radius", planet_visual_radius)

		# 3.5 Registro en el proyector de sombras planetarias modular
		if shadow_projector != null:
			shadow_projector.register_planet(planet_body, i + 1)

		# 4. Estructuras Secundarias (Lunas Diegéticas y Estaciones Espaciales)
		var max_sub_reach: float = 0.0

		# 4.1 Generación de Lunas según Zona
		var num_moons: int = 0
		match zone:
			PlanetZone.INTERIOR:
				if CosmosHasher.hash_2d_float(p_seed, 1010, 101) <= (planetary_cfg.moon_spawn_probability * 0.6):
					num_moons = 1
			PlanetZone.HABITABLE:
				num_moons = 1 if CosmosHasher.hash_2d_float(p_seed, 1010, 101) > 0.4 else 2
			PlanetZone.EXTERIOR:
				if CosmosHasher.hash_2d_float(p_seed, 1010, 101) <= (planetary_cfg.moon_spawn_probability * 0.7):
					num_moons = 1

		for m_idx: int in range(num_moons):
			var moon_seed: int = p_seed + 1999 + (m_idx * 431)
			var is_magma: bool = (zone == PlanetZone.INTERIOR)

			var moon_tex: Texture2D = null
			if is_magma:
				moon_tex = planetary_cfg.magma_moon_texture if planetary_cfg.magma_moon_texture != null else (planetary_cfg.moon_textures[1] if planetary_cfg.moon_textures.size() > 1 else null)
			else:
				moon_tex = planetary_cfg.normal_moon_texture if planetary_cfg.normal_moon_texture != null else (planetary_cfg.moon_textures[0] if not planetary_cfg.moon_textures.is_empty() else null)

			if moon_tex == null and not planetary_cfg.moon_textures.is_empty():
				moon_tex = planetary_cfg.moon_textures[0]

			# Radio orbital ordenado concéntricamente
			var base_orbit_dist: float = planet_visual_radius * (1.75 + float(m_idx) * 0.85)
			var moon_radius: float = base_orbit_dist + (CosmosHasher.hash_2d_float(moon_seed, 1111, 111) - 0.5) * 30.0
			max_sub_reach = maxf(max_sub_reach, moon_radius + (planet_visual_diameter * 0.15 * 0.5))

			var moon_ang_vel: float = (system_profile.base_angular_velocity * (3.8 + float(m_idx) * 1.2)) * (1.0 if CosmosHasher.hash_2d_float(moon_seed, 1212, 121) > 0.5 else -1.0)
			var moon_init_theta: float = CosmosHasher.hash_2d_float(moon_seed, 1313, 131) * TAU

			var moon_body: CosmosOrbitalBody2D = CosmosOrbitalBody2D.new()
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
			var moon_target_diam: float = planet_visual_diameter * planetary_cfg.moon_size_ratio
			var moon_scale: float = moon_target_diam / m_tex_w
			moon_sprite.scale = Vector2.ONE * moon_scale

			if CELESTIAL_BODY_SHADER != null:
				var m_mat: ShaderMaterial = ShaderMaterial.new()
				m_mat.shader = CELESTIAL_BODY_SHADER
				m_mat.set_shader_parameter("axial_spin_speed", (CosmosHasher.hash_2d_float(moon_seed, 1414, 141) - 0.5) * 0.03)
				m_mat.set_shader_parameter("night_ambient", planetary_cfg.planet_night_ambient * 0.9)
				m_mat.set_shader_parameter("day_exposure_boost", planetary_cfg.planet_day_exposure)
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

			var moon_visual_radius: float = moon_target_diam * 0.473
			moon_body.add_child(moon_sprite)
			moon_body.set_sprite_reference(moon_sprite)
			moon_body.set_meta(&"visual_radius", moon_visual_radius)
			planet_body.add_orbital_child(moon_body)

			if shadow_projector != null:
				shadow_projector.register_body(moon_body, str(i + 1) + "_Moon_" + str(m_idx + 1))

		# 4.2 Estaciones Espaciales Diegéticas (sin sombra proyectada)
		var spawn_station: bool = false
		if zone == PlanetZone.HABITABLE or planetary_cfg.station_spawn_probability >= 1.0:
			spawn_station = true # Garantizada en planetas habitables o cuando el perfil exige 1.0
		else:
			spawn_station = CosmosHasher.hash_2d_float(p_seed, 2020, 202) <= (planetary_cfg.station_spawn_probability * 0.3)

		if spawn_station and not planetary_cfg.space_station_textures.is_empty():
			var station_seed: int = p_seed + 3333
			var st_orbit_mult: float = lerpf(1.9, 2.5, CosmosHasher.hash_2d_float(station_seed, 2121, 212))
			var station_radius: float = planet_visual_radius * st_orbit_mult

			var st_ang_vel: float = (system_profile.base_angular_velocity * 2.8) * (1.0 if CosmosHasher.hash_2d_float(station_seed, 2222, 222) > 0.5 else -1.0)
			var st_init_theta: float = CosmosHasher.hash_2d_float(station_seed, 2323, 233) * TAU

			var station_body: CosmosOrbitalBody2D = CosmosOrbitalBody2D.new()
			station_body.name = "Station_" + str(i + 1)
			station_body.body_name = StringName("Station_" + str(i + 1))
			station_body.orbit_radius = station_radius
			station_body.angular_velocity = st_ang_vel
			station_body.initial_theta = st_init_theta
			station_body.axial_rotation_velocity = 0.004
			station_body.initial_axial_rotation = CosmosHasher.hash_2d_float(station_seed, 2424, 244) * TAU
			station_body.show_orbit_lines = false

			var st_sprite: Sprite2D = Sprite2D.new()
			st_sprite.name = "StationVisual"
			st_sprite.centered = true
			var st_tex_idx: int = int(CosmosHasher.hash_2d_float(station_seed, 2525, 255) * float(planetary_cfg.space_station_textures.size()))
			st_tex_idx = clampi(st_tex_idx, 0, planetary_cfg.space_station_textures.size() - 1)
			var st_texture: Texture2D = planetary_cfg.space_station_textures[st_tex_idx]
			st_sprite.texture = st_texture

			var st_tex_w: float = float(st_texture.get_width()) if st_texture != null and st_texture.get_width() > 0 else 128.0
			var station_target_diameter: float = planet_visual_diameter * planetary_cfg.station_size_ratio
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

## Actualiza dinámicamente los vectores de luz (terminador día/noche), conos de sombra y eclipses.
func _update_lighting_vectors() -> void:
	# 1. Proyectar conos de sombra y evaluar eclipses interplanetarios de forma modular
	if shadow_projector != null:
		shadow_projector.update_projections(planets, _light_field_radius)
		shadow_projector.evaluate_eclipses(planets, _light_field_radius)

	# 2. Actualizar iluminación día/noche en planetas, lunas y estaciones
	for planet_body: CosmosOrbitalBody2D in planets:
		if not is_instance_valid(planet_body):
			continue
		var p_pos: Vector2 = planet_body.position
		var p_dist: float = p_pos.length()
		var light_dir_planet: Vector2 = -p_pos.normalized() if p_dist > 1.0 else Vector2(-1.0, 0.0)
		var outward_dir: Vector2 = -light_dir_planet
		var p_radius: float = float(planet_body.get_meta(&"visual_radius", 130.0))

		var p_sprite: Sprite2D = planet_body.get_sprite()
		if p_sprite != null and p_sprite.material is ShaderMaterial:
			(p_sprite.material as ShaderMaterial).set_shader_parameter("light_direction", light_dir_planet)
		var inter_eclipse: float = 0.0
		if p_sprite != null and p_sprite.material is ShaderMaterial:
			inter_eclipse = float((p_sprite.material as ShaderMaterial).get_shader_parameter("eclipse_shadow"))

		for sub_body: CosmosOrbitalBody2D in planet_body.get_orbital_children():
			if not is_instance_valid(sub_body):
				continue
			var sub_sprite: Sprite2D = sub_body.get_sprite()
			if sub_sprite != null and sub_sprite.material is ShaderMaterial:
				var moon_world_in_system: Vector2 = p_pos + sub_body.position
				var light_dir_moon: Vector2 = -moon_world_in_system.normalized() if moon_world_in_system.length_squared() > 1.0 else light_dir_planet
				var sub_mat: ShaderMaterial = sub_sprite.material as ShaderMaterial
				sub_mat.set_shader_parameter("light_direction", light_dir_moon)

				var m_rel_pos: Vector2 = sub_body.position
				var proj_dist: float = m_rel_pos.dot(outward_dir)
				var moon_eclipse_val: float = inter_eclipse
				if proj_dist > 0.0:
					var perp_dist: float = (m_rel_pos - (outward_dir * proj_dist)).length()
					var penumbra_ratio: float = shadow_projector.shadow_penumbra_ratio if shadow_projector != null else 0.45
					var umbra_r: float = p_radius * (1.0 - penumbra_ratio)
					var penumbra_r: float = p_radius * 1.35
					var local_e: float = 0.0
					if perp_dist <= umbra_r:
						local_e = 1.0
					elif perp_dist < penumbra_r:
						local_e = 1.0 - smoothstep(umbra_r, penumbra_r, perp_dist)
					local_e *= clampf(proj_dist / maxf(p_radius * 0.6, 1.0), 0.0, 1.0)
					moon_eclipse_val = maxf(moon_eclipse_val, local_e)
				sub_mat.set_shader_parameter("eclipse_shadow", moon_eclipse_val)

## Habilita o deshabilita los conos de sombra en runtime.
func set_shadows_enabled(p_enabled: bool) -> void:
	if shadow_projector != null:
		shadow_projector.set_shadows_enabled(p_enabled)

## Modifica la opacidad de los conos de sombra en runtime.
func set_shadow_opacity(p_opacity: float) -> void:
	if shadow_projector != null:
		shadow_projector.set_shadow_opacity(p_opacity)

## Modifica el ratio de penumbra lateral en runtime.
func set_shadow_penumbra_ratio(p_ratio: float) -> void:
	if shadow_projector != null:
		shadow_projector.set_shadow_penumbra_ratio(p_ratio)

## Modifica el factor de expansión cónica hacia la heliopausa en runtime.
func set_shadow_expansion_factor(p_factor: float) -> void:
	if shadow_projector != null:
		shadow_projector.set_shadow_expansion_factor(p_factor)
	_update_lighting_vectors()

## Modifica el desvanecimiento perimétrico de la heliopausa en runtime.
func set_shadow_heliopause_fade(p_fade: float) -> void:
	if shadow_projector != null:
		shadow_projector.set_shadow_heliopause_fade(p_fade)

var _shadows_enabled: bool:
	get:
		return shadow_projector.shadows_enabled if shadow_projector != null else true
	set(val):
		set_shadows_enabled(val)

var _shadow_opacity: float:
	get:
		return shadow_projector.shadow_opacity if shadow_projector != null else 0.75
	set(val):
		set_shadow_opacity(val)

var _shadow_penumbra_ratio: float:
	get:
		return shadow_projector.shadow_penumbra_ratio if shadow_projector != null else 0.45
	set(val):
		set_shadow_penumbra_ratio(val)

var _shadow_expansion_factor: float:
	get:
		return shadow_projector.shadow_expansion_factor if shadow_projector != null else 1.85
	set(val):
		set_shadow_expansion_factor(val)

var _shadow_heliopause_fade: float:
	get:
		return shadow_projector.shadow_heliopause_fade if shadow_projector != null else 0.22
	set(val):
		set_shadow_heliopause_fade(val)

var _shadow_group: CanvasGroup:
	get:
		return shadow_projector.get_shadow_group() if shadow_projector != null else null

# --- Setters de compatibilidad legacy ---
func set_shadow_longitudinal_fade(p_fade: float) -> void:
	set_shadow_heliopause_fade(p_fade)

func set_shadow_length_multiplier(_p_mult: float) -> void:
	_update_lighting_vectors()

func set_shadow_base_width_scale(_p_scale: float) -> void:
	_update_lighting_vectors()

func set_shadow_tip_curvature(_p_curv: float) -> void:
	pass

## Ajusta el factor de exposición diurna de planetas y lunas en runtime.
func set_planet_day_exposure(p_exp: float) -> void:
	_planet_day_exposure = p_exp
	for planet_body: CosmosOrbitalBody2D in planets:
		if not is_instance_valid(planet_body):
			continue
		var p_sprite: Sprite2D = planet_body.get_sprite()
		if p_sprite != null and p_sprite.material is ShaderMaterial:
			(p_sprite.material as ShaderMaterial).set_shader_parameter("day_exposure_boost", p_exp)
		for sub_body: CosmosOrbitalBody2D in planet_body.get_orbital_children():
			if is_instance_valid(sub_body):
				var sub_spr: Sprite2D = sub_body.get_sprite()
				if sub_spr != null and sub_spr.material is ShaderMaterial:
					(sub_spr.material as ShaderMaterial).set_shader_parameter("day_exposure_boost", p_exp)

## Ajusta el brillo del núcleo solar en runtime.
func set_star_core_brightness(p_core: float) -> void:
	_star_core_brightness = p_core
	if star_body != null:
		var s_sprite: Sprite2D = star_body.get_sprite()
		if s_sprite != null and s_sprite.material is ShaderMaterial:
			(s_sprite.material as ShaderMaterial).set_shader_parameter("core_brightness", p_core)

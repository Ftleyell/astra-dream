class_name CosmosSolarSystem2D
extends Node2D

const CosmicPoiConfig = preload("res://scenes/combat/environment/cosmos/resources/cosmic_poi_config.gd")
const CosmosOrbitalTrailScript = preload("res://scenes/combat/environment/cosmos/core/cosmos_orbital_trail_2d.gd")
const CosmosCometControllerScript = preload("res://scenes/combat/environment/cosmos/core/cosmos_comet_controller.gd")
const CosmosMinorBodiesControllerScript = preload("res://scenes/combat/environment/cosmos/core/cosmos_minor_bodies_controller.gd")
const CosmosOrbitGuidesOverlayScript = preload("res://scenes/combat/environment/cosmos/core/cosmos_orbit_guides_overlay_2d.gd")

## Representa un sistema solar completo procedural (estrella central + planetas + lunas + cometas + micro-cuerpos).
## Genera y orquesta la jerarquía kepleriana 2.5D/3D determinista a partir de una semilla numérica.
## Aplica zonificación térmica por distancia orbital y vector de iluminación día/noche 3D en tiempo real.

enum PlanetZone {
	INTERIOR,
	HABITABLE,
	EXTERIOR,
}

enum SystemOrbitalArchetype {
	CLASSIC_ECLIPTIC,
	ECCENTRIC_DRIFT,
	RESONANT_DYNAMIC,
}

@export var system_profile: CosmosCelestialSystemProfile
@export var system_seed: int = 1337

var star_body: CosmosOrbitalBody2D = null
var planets: Array[CosmosOrbitalBody2D] = []
var active_archetype: CosmosStarArchetype = null
var current_poi_config: CosmicPoiConfig = null
var shadow_projector: CosmosPlanetaryShadowProjector2D = null
var system_orbital_archetype: int = SystemOrbitalArchetype.CLASSIC_ECLIPTIC
var system_ecliptic_tilt: float = 0.0
var system_ecliptic_squash: float = 1.0
var destructible_orbit_radius: float = 0.0
var destructible_initial_theta: float = 0.0
var destructible_angular_velocity: float = 0.0
var destructible_eccentricity: float = 0.0
var destructible_periapsis_angle: float = 0.0
var destructible_plane_tilt: float = 0.0
var destructible_plane_squash: float = 1.0
var _is_built: bool = false
var _bounding_radius: float = 0.0
var _light_field_radius: float = 0.0
var _effective_orbit_max: float = 3000.0
var _planet_day_exposure: float = 1.30
var _star_core_brightness: float = 1.25
var _light_field_mat: ShaderMaterial = null
var _lens_sprite: Sprite2D = null
var _lens_mat: ShaderMaterial = null
var _star_core_visual_radius: float = 220.0
var _last_global_time: float = 0.0
var _occluder_uniform_buf: Array[Vector4] = []
var _graphics_quality: int = 2
var _comet_controller: CosmosCometController2D = null
var _minor_bodies_controller: CosmosMinorBodiesController2D = null
var _satellite_trails: Array[CosmosOrbitalTrail2D] = []
var _orbit_guides_overlay: CosmosOrbitGuidesOverlay2D = null
var _orbit_guides_visible: bool = false
var _star_exclusion_radius: float = 0.0

func _ready() -> void:
	_ensure_occluder_buf()
	if not _is_built and system_profile != null:
		build_system(system_seed)

func _ensure_occluder_buf() -> void:
	if _occluder_uniform_buf.size() == 8:
		return
	_occluder_uniform_buf.resize(8)
	for i: int in range(8):
		_occluder_uniform_buf[i] = Vector4.ZERO

## Construye la jerarquía física y visual del sistema solar a partir de la semilla dada y POI opcional.
func build_system(p_seed: int, p_poi_config: CosmicPoiConfig = null) -> void:
	_ensure_occluder_buf()
	system_seed = p_seed
	current_poi_config = p_poi_config
	_clear_existing_system()
	if system_profile == null:
		return

	_build_system_hierarchy()
	update_astronomical_state(0.0)
	_is_built = true

## Actualiza el estado astronómico evaluando analíticamente toda la jerarquía 2.5D/3D en t_global.
func update_astronomical_state(global_time: float) -> void:
	_last_global_time = global_time
	if _lens_mat != null:
		_lens_mat.set_shader_parameter("global_time", global_time)
	if _light_field_mat != null:
		_light_field_mat.set_shader_parameter("global_time", global_time)
	if star_body != null:
		star_body.evaluate_orbital_position(global_time)
		for trail: CosmosOrbitalTrail2D in _satellite_trails:
			if is_instance_valid(trail) and trail.visible:
				trail.update_trail(global_time)
		if is_instance_valid(_comet_controller):
			_comet_controller.update_comets(global_time)
		if is_instance_valid(_minor_bodies_controller):
			_minor_bodies_controller.update_minor_bodies(global_time)
		_update_lighting_vectors()
		if is_instance_valid(_orbit_guides_overlay):
			_orbit_guides_overlay.refresh_if_visible()

func set_orbit_guides_visible(p_visible: bool) -> void:
	_orbit_guides_visible = p_visible
	if is_instance_valid(_orbit_guides_overlay):
		_orbit_guides_overlay.visible = p_visible
		if p_visible:
			_orbit_guides_overlay.queue_redraw()

func is_orbit_guides_visible() -> bool:
	return _orbit_guides_visible

func get_comet_entries() -> Array[Dictionary]:
	if is_instance_valid(_comet_controller):
		return _comet_controller.get_comet_entries()
	return []

func get_shepherd_entries() -> Array[Dictionary]:
	if is_instance_valid(_minor_bodies_controller):
		return _minor_bodies_controller.get_shepherd_entries()
	return []

func get_bounding_radius() -> float:
	return _bounding_radius

func _clear_existing_system() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	planets.clear()
	_satellite_trails.clear()
	if is_instance_valid(_comet_controller):
		_comet_controller.clear_comets()
	_comet_controller = null
	if is_instance_valid(_minor_bodies_controller):
		_minor_bodies_controller.clear_minor_bodies()
	_minor_bodies_controller = null
	_orbit_guides_overlay = null
	star_body = null
	active_archetype = null
	if shadow_projector != null:
		shadow_projector.clear_projector()
	shadow_projector = null
	_light_field_mat = null
	_lens_sprite = null
	_lens_mat = null
	_bounding_radius = 0.0
	_light_field_radius = 0.0
	_star_exclusion_radius = 0.0
	system_orbital_archetype = SystemOrbitalArchetype.CLASSIC_ECLIPTIC
	system_ecliptic_tilt = 0.0
	system_ecliptic_squash = 1.0
	destructible_orbit_radius = 0.0
	destructible_initial_theta = 0.0
	destructible_angular_velocity = 0.0
	destructible_eccentricity = 0.0
	destructible_periapsis_angle = 0.0
	destructible_plane_tilt = 0.0
	destructible_plane_squash = 1.0
	_is_built = false

const STAR_CORONA_SHADER: Shader = preload("res://scenes/combat/environment/cosmos/shaders/star_corona.gdshader")
const STAR_ANOMALY_SHADER: Shader = preload("res://scenes/combat/environment/cosmos/shaders/star_anomaly_halo.gdshader")
const STAR_FLAT_CORE_SHADER: Shader = preload("res://scenes/combat/environment/cosmos/shaders/star_flat_core.gdshader")
const STAR_LIGHT_FIELD_SHADER: Shader = preload("res://scenes/combat/environment/cosmos/shaders/star_light_field.gdshader")
const STAR_LENS_SHADER: Shader = preload("res://scenes/combat/environment/cosmos/shaders/star_gravitational_lens.gdshader")
const STATION_BEACON_SHADER: Shader = preload("res://scenes/combat/environment/space_station_beacon.gdshader")
const CELESTIAL_BODY_SHADER: Shader = preload("res://scenes/combat/environment/cosmos/shaders/celestial_body.gdshader")
const PLANETARY_RING_SHADER: Shader = preload("res://scenes/combat/environment/cosmos/shaders/planetary_ring.gdshader")
const PLANETARY_SHADOW_CONE_SHADER: Shader = preload("res://scenes/combat/environment/cosmos/shaders/planetary_shadow_cone.gdshader")
const COSMIC_SHADOW_GROUP_SHADER: Shader = preload("res://scenes/combat/environment/cosmos/shaders/cosmic_shadow_group.gdshader")

static var _light_quad_texture: ImageTexture = null

static func _get_light_quad_texture() -> ImageTexture:
	if _light_quad_texture == null:
		var img: Image = Image.create(2, 2, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_light_quad_texture = ImageTexture.create_from_image(img)
	return _light_quad_texture

static func _compute_safe_slot_semi_major_axis(
	ideal_r: float,
	r_jitter: float,
	star_excl_r: float,
	curr_reach: float,
	slot_ecc: float,
	slot_peri: float,
	slot_squash: float,
	prev_a: float,
	prev_ecc: float,
	prev_peri: float,
	prev_squash: float,
	prev_reach: float,
	min_spacing: float,
	safe_outer_cap: float
) -> Vector2:
	var eff_ecc: float = clampf(slot_ecc, 0.0, 0.16)
	var min_star_a: float = (star_excl_r + curr_reach + 210.0) / maxf((1.0 - eff_ecc) * slot_squash, 0.50)
	var cand_a: float = maxf(ideal_r + r_jitter, min_star_a)

	if prev_a > 0.0:
		cand_a = maxf(cand_a, prev_a + min_spacing)
		var v_prev: Vector2 = Vector2(cos(prev_peri), sin(prev_peri)) * (prev_a * prev_ecc)
		var squash_penalty: float = prev_a * maxf(prev_squash - slot_squash, 0.0) * 1.15
		for _iter: int in range(2):
			var v_curr: Vector2 = Vector2(cos(slot_peri), sin(slot_peri)) * (cand_a * eff_ecc)
			var ecc_gap: float = v_prev.distance_to(v_curr)
			var req_sep: float = maxf(min_spacing, prev_reach + curr_reach + 140.0 + ecc_gap + squash_penalty)
			cand_a = maxf(cand_a, prev_a + req_sep)

	if (cand_a * (1.0 + eff_ecc)) + curr_reach > safe_outer_cap:
		eff_ecc = minf(eff_ecc, 0.02)
		min_star_a = (star_excl_r + curr_reach + 200.0) / maxf((1.0 - eff_ecc) * slot_squash, 0.50)
		cand_a = maxf(ideal_r + r_jitter, min_star_a)
		if prev_a > 0.0:
			var v_prev_c: Vector2 = Vector2(cos(prev_peri), sin(prev_peri)) * (prev_a * prev_ecc)
			var v_curr_c: Vector2 = Vector2(cos(slot_peri), sin(slot_peri)) * (cand_a * eff_ecc)
			var squash_pen_c: float = prev_a * maxf(prev_squash - slot_squash, 0.0) * 1.15
			var compact_sep: float = maxf(min_spacing, prev_reach + curr_reach + 95.0 + v_prev_c.distance_to(v_curr_c) + squash_pen_c)
			cand_a = maxf(cand_a, prev_a + compact_sep)
		var hard_cap_a: float = (safe_outer_cap - curr_reach) / (1.0 + eff_ecc)
		if cand_a > hard_cap_a:
			var floor_a: float = maxf(min_star_a, prev_a + min_spacing) if prev_a > 0.0 else min_star_a
			cand_a = maxf(minf(cand_a, hard_cap_a), minf(floor_a, hard_cap_a))

	return Vector2(cand_a, eff_ecc)

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
	var biome_tint_color: Color = Color(0.15, 0.08, 0.25, 1.0)
	if active_archetype != null and active_archetype.biome_config != null:
		biome_tint_color = active_archetype.biome_config.color_gas_primary
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
	var lock_dipole_axis: bool = (star_vis_cfg.star_signature_mode == 1 or star_vis_cfg.star_signature_mode == 3)
	star_body.axial_rotation_velocity = 0.0 if lock_dipole_axis else axial_speed
	star_body.initial_axial_rotation = 0.0 if lock_dipole_axis else (CosmosHasher.hash_2d_float(system_seed, 101, 11) * TAU)
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

	# Inicializar arquetipo orbital y plano eclíptico del sistema antes de construir el campo de luz y planetas
	var arch_roll: float = CosmosHasher.hash_2d_float(system_seed, 271, 27)
	if arch_roll < 0.50:
		system_orbital_archetype = SystemOrbitalArchetype.CLASSIC_ECLIPTIC
	elif arch_roll < 0.80:
		system_orbital_archetype = SystemOrbitalArchetype.ECCENTRIC_DRIFT
	else:
		system_orbital_archetype = SystemOrbitalArchetype.RESONANT_DYNAMIC
	system_ecliptic_tilt = CosmosHasher.hash_2d_float(system_seed, 272, 28) * TAU
	system_ecliptic_squash = clampf(
		lerpf(
			planetary_cfg.system_ecliptic_squash_range.x,
			planetary_cfg.system_ecliptic_squash_range.y,
			CosmosHasher.hash_2d_float(system_seed, 273, 29)
		),
		0.72,
		0.98
	)

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
		light_mat.set_shader_parameter("god_rays_strength", 0.14 if star_vis_cfg.star_signature_mode == 3 else 0.30)
		light_mat.set_shader_parameter("star_signature_mode", star_vis_cfg.star_signature_mode)
		var domain_col: Color = star_vis_cfg.anomaly_secondary_color if star_vis_cfg.star_signature_mode > 0 else star_color.lerp(biome_tint_color, 0.28)
		light_mat.set_shader_parameter("domain_accent_color", domain_col)
		light_mat.set_shader_parameter("heliopause_aura_strength", 0.56 if _graphics_quality >= 1 else 0.26)
		light_mat.set_shader_parameter("astro_compass_strength", 0.22 if _graphics_quality >= 1 else 0.0)
		light_mat.set_shader_parameter("ecliptic_tilt_rad", system_ecliptic_tilt)
		light_mat.set_shader_parameter("ecliptic_squash", system_ecliptic_squash)
		light_mat.set_shader_parameter("global_time", _last_global_time)
		light_sprite.material = light_mat
		_light_field_mat = light_mat
	light_sprite.z_index = -3
	star_body.add_child(light_sprite)

	var star_diameter: float = star_radius * corona_mult * 2.0
	var is_black_hole: bool = (star_vis_cfg.star_signature_mode == 3)
	var anomaly_tilt: float = (CosmosHasher.hash_2d_float(system_seed, 77, 7) - 0.5) * (0.45 if star_vis_cfg.star_signature_mode == 1 else 0.85)
	_star_core_visual_radius = star_diameter * 0.14 if is_black_hole else star_radius * clampf(corona_mult, 0.7, 1.35) * 0.72
	shadow_projector.set_star_visual_context(star_color, _star_core_visual_radius)
	shadow_projector.set_crepuscular_enabled(_graphics_quality >= 1)

	# 2.15 Lente Gravitacional (Agujero Negro) o Espejismo Térmico Local detrás del núcleo solar
	if STAR_LENS_SHADER != null:
		var lens_spr: Sprite2D = Sprite2D.new()
		lens_spr.name = "StarGravitationalLens"
		lens_spr.centered = true
		lens_spr.texture = _get_light_quad_texture()
		var lens_diam: float = star_diameter * (0.98 if is_black_hole else 0.72)
		lens_spr.scale = Vector2.ONE * (lens_diam * 0.5)
		lens_spr.z_index = -1
		lens_spr.visible = (_graphics_quality >= 2)
		var l_mat: ShaderMaterial = ShaderMaterial.new()
		l_mat.shader = STAR_LENS_SHADER
		l_mat.set_shader_parameter("lens_mode", 1 if is_black_hole else 2)
		l_mat.set_shader_parameter("lens_strength", 0.048 if is_black_hole else 0.0018)
		l_mat.set_shader_parameter("horizon_radius", 0.106 if is_black_hole else 0.16)
		var lens_tint: Color = star_vis_cfg.anomaly_primary_color if star_vis_cfg.star_signature_mode > 0 else star_color
		l_mat.set_shader_parameter("tint_color", lens_tint)
		l_mat.set_shader_parameter("global_time", _last_global_time)
		lens_spr.material = l_mat
		star_body.add_child(lens_spr)
		_lens_sprite = lens_spr
		_lens_mat = l_mat

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
		star_mat.set_shader_parameter("dark_core_mode", star_vis_cfg.star_signature_mode == 3)
		star_sprite.material = star_mat
	else:
		star_sprite.modulate = star_color

	var tex_w: float = float(selected_tex.get_width()) if selected_tex != null and selected_tex.get_width() > 0 else 512.0
	star_sprite.scale = Vector2.ONE * (star_diameter / tex_w)
	if lock_dipole_axis:
		star_sprite.rotation = anomaly_tilt
	star_body.add_child(star_sprite)
	star_body.set_sprite_reference(star_sprite)

	# 2.4 Firma Visual Única (Magnetar / Enana Blanca / Agujero Negro / Nova Esmeralda)
	if star_vis_cfg.star_signature_mode > 0 and STAR_ANOMALY_SHADER != null:
		var anomaly_sprite: Sprite2D = Sprite2D.new()
		anomaly_sprite.name = "StarAnomalyOverlay"
		anomaly_sprite.centered = true
		anomaly_sprite.texture = _get_light_quad_texture()
		var overlay_scale_mult: float = 0.70
		match star_vis_cfg.star_signature_mode:
			1:
				overlay_scale_mult = 0.725
			3:
				overlay_scale_mult = 0.90
			4:
				overlay_scale_mult = 0.86
		anomaly_sprite.scale = Vector2.ONE * (star_diameter * overlay_scale_mult)
		anomaly_sprite.z_index = 1
		var anomaly_mat: ShaderMaterial = ShaderMaterial.new()
		anomaly_mat.shader = STAR_ANOMALY_SHADER
		anomaly_mat.set_shader_parameter("anomaly_mode", star_vis_cfg.star_signature_mode)
		anomaly_mat.set_shader_parameter("primary_color", star_vis_cfg.anomaly_primary_color)
		anomaly_mat.set_shader_parameter("secondary_color", star_vis_cfg.anomaly_secondary_color)
		anomaly_mat.set_shader_parameter("tilt_angle", anomaly_tilt)
		anomaly_mat.set_shader_parameter("intensity", 1.25)
		anomaly_mat.set_shader_parameter("pulse_speed", maxf(pulse_spd * 0.75, 1.2))
		anomaly_sprite.material = anomaly_mat
		star_body.add_child(anomaly_sprite)

	add_child(star_body)

	var star_exclusion_radius: float = star_diameter * 0.5
	if star_vis_cfg.star_signature_mode > 0:
		var anom_mult: float = 0.70
		match star_vis_cfg.star_signature_mode:
			1:
				anom_mult = 0.725
			3:
				anom_mult = 0.90
			4:
				anom_mult = 0.86
		star_exclusion_radius = maxf(star_exclusion_radius, star_diameter * anom_mult * 0.52)

	# 3. Planetas Primarios y Reserva de Slot Destructible
	var num_planets: int = planetary_cfg.min_planets
	if current_poi_config != null and current_poi_config.planet_count >= 0:
		num_planets = current_poi_config.planet_count
	else:
		var planet_count_range: int = planetary_cfg.max_planets - planetary_cfg.min_planets
		if planet_count_range > 0:
			var planet_rnd: float = CosmosHasher.hash_2d_float(system_seed, 202, 22)
			num_planets += int(planet_rnd * float(planet_count_range + 1))
			num_planets = clampi(num_planets, planetary_cfg.min_planets, planetary_cfg.max_planets)

	var total_slots: int = num_planets + 1
	var destructible_slot_index: int = 0
	if total_slots >= 3:
		var slot_offset: int = int(CosmosHasher.hash_2d_float(system_seed, 707, 77) * float(total_slots - 2))
		destructible_slot_index = 1 + clampi(slot_offset, 0, total_slots - 3)
	else:
		destructible_slot_index = clampi(int(CosmosHasher.hash_2d_float(system_seed, 707, 77) * float(total_slots)), 0, total_slots - 1)

	var base_system_theta: float = CosmosHasher.hash_2d_float(system_seed, 505, 55) * TAU
	var theta_step: float = TAU / float(maxi(total_slots, 1))
	var theta_jitter_rad: float = deg_to_rad(effective_theta_jitter_deg)

	var system_periapsis_base: float = CosmosHasher.hash_2d_float(system_seed, 274, 30) * TAU
	var half_safe: float = (system_profile.cell_size * 0.5) - system_profile.cell_boundary_padding
	var safe_outer_cap: float = maxf(half_safe - 160.0, effective_orbit_max + 900.0)
	if half_safe > 2000.0:
		safe_outer_cap = half_safe - 160.0
	var prev_orbit_a: float = 0.0
	var prev_slot_ecc: float = 0.0
	var prev_slot_peri: float = system_periapsis_base
	var prev_slot_squash: float = system_ecliptic_squash
	var prev_slot_reach: float = 0.0
	var used_planet_ids: Array[StringName] = []

	_minor_bodies_controller = CosmosMinorBodiesControllerScript.new()
	_minor_bodies_controller.name = "MinorBodiesController"
	star_body.add_child(_minor_bodies_controller)

	for slot_idx: int in range(total_slots):
		var p_seed: int = system_seed + ((slot_idx + 1) * 733)

		# 3.1 Progresión expansiva y parámetros orbitales 2.5D/3D por arquetipo
		var t_norm: float = float(slot_idx) / float(maxi(total_slots - 1, 1))
		var expansion_curve: float = pow(t_norm, 1.15)
		var ideal_radius: float = lerpf(effective_orbit_min, effective_orbit_max, expansion_curve)

		var radius_jitter: float = (CosmosHasher.hash_2d_float(p_seed, 303, 33) - 0.5) * (effective_min_spacing * 0.25)
		var dir_sign: float = 1.0 if CosmosHasher.hash_2d_float(p_seed, 404, 44) > 0.1 else -1.0
		if (
			system_orbital_archetype == SystemOrbitalArchetype.ECCENTRIC_DRIFT
			and slot_idx >= total_slots - 2
			and CosmosHasher.hash_2d_float(p_seed, 405, 45) < planetary_cfg.retrograde_outer_planet_chance
		):
			dir_sign = -1.0

		var raw_ecc_range: Vector2 = planetary_cfg.eccentric_archetype_ecc_range if system_orbital_archetype == SystemOrbitalArchetype.ECCENTRIC_DRIFT else planetary_cfg.planet_eccentricity_range
		var raw_ecc: float = lerpf(raw_ecc_range.x, raw_ecc_range.y, CosmosHasher.hash_2d_float(p_seed, 305, 35))
		var slot_ecc: float = clampf(lerpf(raw_ecc, minf(raw_ecc, 0.06), t_norm), 0.0, 0.16)
		var peri_jitter_rad: float = deg_to_rad(52.0 if system_orbital_archetype == SystemOrbitalArchetype.ECCENTRIC_DRIFT else 32.0)
		var slot_peri: float = fposmod(system_periapsis_base + (CosmosHasher.hash_2d_float(p_seed, 306, 36) - 0.5) * 2.0 * peri_jitter_rad, TAU)
		var scatter_lim: float = minf(planetary_cfg.planet_tilt_scatter_rad, 0.12)
		var slot_tilt: float = system_ecliptic_tilt + ((CosmosHasher.hash_2d_float(p_seed, 307, 37) - 0.5) * 2.0 * scatter_lim)
		var slot_squash: float = clampf(system_ecliptic_squash + ((CosmosHasher.hash_2d_float(p_seed, 308, 38) - 0.5) * 0.045), 0.78, 0.94)

		var planet_theta_jitter: float = (CosmosHasher.hash_2d_float(p_seed, 515, 51) - 0.5) * 2.0 * theta_jitter_rad
		var init_theta: float = fposmod(base_system_theta + (float(slot_idx) * theta_step) + planet_theta_jitter, TAU)

		# Reserva dedicada para el planeta interactuable destructible:
		# Garantiza periapsis libre de estrella, separación semieje y delta vectorial de excentricidad.
		if slot_idx == destructible_slot_index:
			var d_reach: float = 150.0
			var d_solved: Vector2 = _compute_safe_slot_semi_major_axis(
				ideal_radius,
				radius_jitter,
				star_exclusion_radius,
				d_reach,
				slot_ecc,
				slot_peri,
				slot_squash,
				prev_orbit_a,
				prev_slot_ecc,
				prev_slot_peri,
				prev_slot_squash,
				prev_slot_reach,
				effective_min_spacing,
				safe_outer_cap
			)
			var d_actual_radius: float = d_solved.x
			slot_ecc = d_solved.y
			var d_ang_vel: float = CosmosKeplerOrbitMath.calculate_keplerian_angular_velocity(system_profile.base_angular_velocity, effective_orbit_min, d_actual_radius, dir_sign)
			destructible_orbit_radius = d_actual_radius
			destructible_angular_velocity = d_ang_vel
			destructible_initial_theta = init_theta
			destructible_eccentricity = slot_ecc
			destructible_periapsis_angle = slot_peri
			destructible_plane_tilt = slot_tilt
			destructible_plane_squash = slot_squash
			prev_orbit_a = d_actual_radius
			prev_slot_ecc = slot_ecc
			prev_slot_peri = slot_peri
			prev_slot_squash = slot_squash
			prev_slot_reach = d_reach
			_effective_orbit_max = maxf(_effective_orbit_max, (d_actual_radius * (1.0 + slot_ecc)) + d_reach)
			_bounding_radius = maxf(_bounding_radius, (d_actual_radius * (1.0 + slot_ecc)) + 300.0)
			continue

		var visual_idx: int = planets.size()
		var dist_norm: float = clampf(ideal_radius / maxf(effective_orbit_max, 1.0), 0.0, 1.0)
		var dist_tint_attenuation: float = 1.0 - (dist_norm * 0.45) # 1.0 cerca del sol, ~0.55 en la órbita más lejana

		# 3.2 Clasificación de Zona Astrofísica (Interior, Habitable, Exterior)
		var zone: PlanetZone = PlanetZone.HABITABLE
		if num_planets <= 2:
			zone = PlanetZone.HABITABLE
		elif visual_idx == 0:
			zone = PlanetZone.INTERIOR
		elif visual_idx == num_planets - 1:
			zone = PlanetZone.EXTERIOR
		else:
			if num_planets == 4:
				zone = PlanetZone.HABITABLE if visual_idx == 1 else PlanetZone.EXTERIOR
			elif num_planets == 5:
				zone = PlanetZone.INTERIOR if visual_idx == 1 else (PlanetZone.HABITABLE if visual_idx == 2 else PlanetZone.EXTERIOR)
			elif num_planets >= 6:
				zone = PlanetZone.INTERIOR if visual_idx == 1 else (PlanetZone.HABITABLE if (visual_idx == 2 or visual_idx == 3) else PlanetZone.EXTERIOR)
			else:
				zone = PlanetZone.HABITABLE

		var planet_body: CosmosOrbitalBody2D = CosmosOrbitalBody2D.new()
		planet_body.name = "Planet_" + str(visual_idx + 1)
		planet_body.body_name = StringName("Planet_" + str(visual_idx + 1))
		planet_body.orbit_radius = ideal_radius
		planet_body.angular_velocity = 0.0
		planet_body.initial_theta = init_theta
		planet_body.base_visual_scale = Vector2.ONE
		planet_body.depth_scale_amplitude = planetary_cfg.planet_depth_scale_amp
		planet_body.enable_depth_z_swap = false
		planet_body.z_index = 0
		planet_body.axial_rotation_velocity = 0.0 # Desacoplado: el shader maneja la rotación axial visual
		planet_body.initial_axial_rotation = 0.0
		planet_body.show_orbit_lines = system_profile.show_orbit_lines
		planet_body.orbit_line_color = system_profile.orbit_line_color
		planet_body.orbit_line_width = system_profile.orbit_line_width * 0.75

		var lighting_ctx: Dictionary = {
			"night_ambient": planetary_cfg.planet_night_ambient,
			"day_exposure": planetary_cfg.planet_day_exposure,
			"star_color": star_color,
			"day_tint_strength": day_tint_strength,
			"atmo_tint_strength": atmo_tint_strength,
			"dist_tint_attenuation": dist_tint_attenuation,
			"biome_tint_color": biome_tint_color,
			"biome_tint_intensity": 0.22,
		}

		var orbit_size_mult: float = planetary_cfg.planet_size_multiplier * lerpf(0.88, 1.08, t_norm)
		var planet_visual_diameter: float = 240.0 * orbit_size_mult
		var planet_visual_radius: float = planet_visual_diameter * 0.473
		var ring_outer_px: float = 0.0
		var has_rings: bool = false
		var ring_roll_rad: float = 0.0
		var ring_tilt_x_rad: float = 0.0
		var v2_arch: CosmosPlanetArchetype = null
		if not planetary_cfg.planet_archetypes.is_empty():
			v2_arch = CosmosPlanetVisualBuilder.pick_planet_archetype(planetary_cfg.planet_archetypes, int(zone), p_seed, used_planet_ids)
			if v2_arch != null:
				used_planet_ids.append(v2_arch.archetype_id)

		if v2_arch != null:
			var v2_info: Dictionary = CosmosPlanetVisualBuilder.configure_planet_visual(
				planet_body,
				v2_arch,
				p_seed,
				orbit_size_mult,
				_get_light_quad_texture(),
				CELESTIAL_BODY_SHADER,
				PLANETARY_RING_SHADER,
				lighting_ctx
			)
			planet_visual_diameter = float(v2_info.get("visual_diameter", planet_visual_diameter))
			planet_visual_radius = float(v2_info.get("visual_radius", planet_visual_radius))
			ring_outer_px = float(v2_info.get("ring_outer_radius_px", 0.0))
			has_rings = bool(v2_info.get("has_rings", false))
			ring_roll_rad = float(v2_info.get("ring_roll_rad", 0.0))
			ring_tilt_x_rad = float(v2_info.get("ring_tilt_x_rad", 0.0))
		else:
			# 3.3 Selección de Textura y Propiedades Físicas según Zona (Fallback Legacy)
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

			target_diameter *= orbit_size_mult

			var planet_sprite: Sprite2D = Sprite2D.new()
			planet_sprite.name = "PlanetVisual"
			planet_sprite.centered = true
			planet_sprite.texture = p_tex

			var p_tex_w: float = float(p_tex.get_width()) if p_tex != null and p_tex.get_width() > 0 else 2048.0
			var p_scale_factor: float = target_diameter / p_tex_w
			planet_sprite.scale = Vector2.ONE * p_scale_factor

			planet_visual_diameter = target_diameter
			planet_visual_radius = planet_visual_diameter * 0.473

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

				p_mat.set_shader_parameter("star_light_color", star_color)
				p_mat.set_shader_parameter("star_light_tint_strength", day_tint_strength * dist_tint_attenuation)
				p_mat.set_shader_parameter("star_atmo_tint_strength", atmo_tint_strength * dist_tint_attenuation)
				p_mat.set_shader_parameter("biome_tint_color", biome_tint_color)
				planet_sprite.material = p_mat

			planet_body.add_child(planet_sprite)
			planet_body.set_sprite_reference(planet_sprite)
			planet_body.set_meta(&"visual_radius", planet_visual_radius)

		# 3.5 Registro en el proyector de sombras planetarias modular
		if shadow_projector != null:
			shadow_projector.register_planet(planet_body, visual_idx + 1)

		# 4. Estructuras Secundarias 2.5D/3D (Lunas y Estaciones Espaciales en planos inclinados)
		var max_sub_reach: float = ring_outer_px
		var ref_sat_tilt: float = ring_roll_rad if has_rings else (CosmosHasher.hash_2d_float(p_seed, 1009, 99) * TAU)

		# 4.1 Generación de Lunas según Zona y Arquetipo
		var num_moons: int = 0
		var resonant_bonus: float = 0.18 if system_orbital_archetype == SystemOrbitalArchetype.RESONANT_DYNAMIC else 0.0
		match zone:
			PlanetZone.INTERIOR:
				if CosmosHasher.hash_2d_float(p_seed, 1010, 101) <= (planetary_cfg.moon_spawn_probability * 0.65):
					num_moons = 1
			PlanetZone.HABITABLE:
				num_moons = 1 if CosmosHasher.hash_2d_float(p_seed, 1010, 101) > (0.45 - resonant_bonus) else 2
			PlanetZone.EXTERIOR:
				var ext_roll: float = CosmosHasher.hash_2d_float(p_seed, 1010, 101)
				if ext_roll <= (planetary_cfg.moon_spawn_probability * 0.85):
					num_moons = 2 if (has_rings or ext_roll < 0.25 + resonant_bonus) else 1

		for m_idx: int in range(num_moons):
			var moon_seed: int = p_seed + 1999 + (m_idx * 431)
			var is_magma: bool = (zone == PlanetZone.INTERIOR)

			# Semieje extendido para que las órbitas 3D inclinadas salgan claramente a los costados y crucen por delante/detrás
			var base_orbit_dist: float = planet_visual_radius * (1.72 + float(m_idx) * 0.56)
			if ring_outer_px > 1.0:
				base_orbit_dist = maxf(base_orbit_dist, ring_outer_px + 34.0 + float(m_idx) * 48.0)
			var moon_radius: float = base_orbit_dist + (CosmosHasher.hash_2d_float(moon_seed, 1111, 111) - 0.5) * 24.0
			var moon_target_diam: float = planet_visual_diameter * planetary_cfg.moon_size_ratio * (1.0 if m_idx == 0 else 0.86)
			max_sub_reach = maxf(max_sub_reach, moon_radius + (moon_target_diam * 0.5))

			var moon_retro_sign: float = -1.0 if CosmosHasher.hash_2d_float(moon_seed, 1212, 121) < planetary_cfg.moon_retrograde_chance else 1.0
			var moon_speed_mult: float = 3.8 + (float(m_idx) * 1.45)
			var moon_ang_vel: float = (system_profile.base_angular_velocity * moon_speed_mult) * moon_retro_sign
			var moon_init_theta: float = CosmosHasher.hash_2d_float(moon_seed, 1313, 131) * TAU

			var moon_ecc: float = lerpf(
				planetary_cfg.moon_eccentricity_range.x,
				planetary_cfg.moon_eccentricity_range.y,
				CosmosHasher.hash_2d_float(moon_seed, 1314, 132)
			)
			var moon_peri: float = CosmosHasher.hash_2d_float(moon_seed, 1315, 133) * TAU
			var moon_tilt: float = ref_sat_tilt
			var moon_squash: float = lerpf(
				planetary_cfg.moon_squash_range.x,
				planetary_cfg.moon_squash_range.y,
				CosmosHasher.hash_2d_float(moon_seed, 1316, 134)
			)
			if has_rings and m_idx == 0:
				moon_tilt = ring_roll_rad
				moon_squash = clampf(cos(ring_tilt_x_rad), planetary_cfg.moon_squash_range.x, 0.62)
			elif m_idx > 0 or not has_rings:
				var cross_sign: float = 1.0 if (m_idx % 2 == 0) else -1.0
				var cross_offset: float = deg_to_rad(lerpf(46.0, 86.0, CosmosHasher.hash_2d_float(moon_seed, 1317, 135)))
				moon_tilt = wrapf(ref_sat_tilt + (cross_offset * cross_sign), -PI, PI)

			var moon_body: CosmosOrbitalBody2D = CosmosOrbitalBody2D.new()
			moon_body.name = "Moon_" + str(visual_idx + 1) + "_" + str(m_idx + 1)
			moon_body.body_name = StringName(moon_body.name)
			moon_body.orbit_radius = moon_radius
			moon_body.angular_velocity = moon_ang_vel
			moon_body.initial_theta = moon_init_theta
			moon_body.orbit_eccentricity = moon_ecc
			moon_body.orbit_periapsis_angle = moon_peri
			moon_body.orbit_plane_tilt = moon_tilt
			moon_body.orbit_plane_squash = moon_squash
			moon_body.depth_scale_amplitude = planetary_cfg.moon_depth_scale_amp
			moon_body.enable_depth_z_swap = true
			moon_body.base_visual_scale = Vector2.ONE
			moon_body.axial_rotation_velocity = 0.0
			moon_body.initial_axial_rotation = 0.0
			moon_body.show_orbit_lines = false
			moon_body.set_meta(&"is_moon", true)

			var m_arch: CosmosPlanetArchetype = null
			if not planetary_cfg.moon_archetypes.is_empty():
				m_arch = CosmosPlanetVisualBuilder.pick_moon_archetype(planetary_cfg.moon_archetypes, int(zone), moon_seed)

			if m_arch != null:
				CosmosPlanetVisualBuilder.configure_moon_visual(
					moon_body,
					m_arch,
					moon_seed,
					moon_target_diam,
					_get_light_quad_texture(),
					CELESTIAL_BODY_SHADER,
					lighting_ctx
				)
			else:
				var moon_tex: Texture2D = null
				if is_magma:
					moon_tex = planetary_cfg.magma_moon_texture if planetary_cfg.magma_moon_texture != null else (planetary_cfg.moon_textures[1] if planetary_cfg.moon_textures.size() > 1 else null)
				else:
					moon_tex = planetary_cfg.normal_moon_texture if planetary_cfg.normal_moon_texture != null else (planetary_cfg.moon_textures[0] if not planetary_cfg.moon_textures.is_empty() else null)

				if moon_tex == null and not planetary_cfg.moon_textures.is_empty():
					moon_tex = planetary_cfg.moon_textures[0]

				var moon_sprite: Sprite2D = Sprite2D.new()
				moon_sprite.name = "MoonVisual"
				moon_sprite.centered = true
				moon_sprite.texture = moon_tex

				var m_tex_w: float = float(moon_tex.get_width()) if moon_tex != null and moon_tex.get_width() > 0 else 2048.0
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

			if planetary_cfg.enable_orbital_trails:
				var m_trail: CosmosOrbitalTrail2D = CosmosOrbitalTrailScript.new()
				m_trail.name = "MoonTrail_" + str(visual_idx + 1) + "_" + str(m_idx + 1)
				var base_m_col: Color = Color(1.0, 0.60, 0.32, planetary_cfg.trail_base_opacity) if is_magma else Color(0.76, 0.90, 1.0, planetary_cfg.trail_base_opacity).lerp(star_color, 0.25)
				base_m_col.a = planetary_cfg.trail_base_opacity
				m_trail.configure_from_body(
					moon_body,
					planetary_cfg.moon_trail_arc_radians,
					clampf(moon_target_diam * 0.14, 3.6, 6.8),
					base_m_col,
					Color(base_m_col.r * 0.65, base_m_col.g * 0.72, base_m_col.b, 0.0),
					16,
					true
				)
				m_trail.visible = (_graphics_quality >= 1)
				planet_body.add_child(m_trail)
				_satellite_trails.append(m_trail)

			planet_body.add_orbital_child(moon_body)

			if shadow_projector != null:
				shadow_projector.register_body(moon_body, str(visual_idx + 1) + "_Moon_" + str(m_idx + 1))

		# 4.2 Estaciones Espaciales Diegéticas 3D (orientación tangencial viva, sin sombra proyectada)
		var spawn_station: bool = false
		if zone == PlanetZone.HABITABLE or planetary_cfg.station_spawn_probability >= 1.0:
			spawn_station = true # Garantizada en planetas habitables o cuando el perfil exige 1.0
		else:
			spawn_station = CosmosHasher.hash_2d_float(p_seed, 2020, 202) <= (planetary_cfg.station_spawn_probability * 0.3)

		if spawn_station and not planetary_cfg.space_station_textures.is_empty():
			var station_seed: int = p_seed + 3333
			var st_orbit_mult: float = lerpf(1.56, 1.98, CosmosHasher.hash_2d_float(station_seed, 2121, 212))
			var station_radius: float = planet_visual_radius * st_orbit_mult
			if ring_outer_px > 1.0:
				station_radius = maxf(station_radius, ring_outer_px + 36.0)

			var st_ang_vel: float = (system_profile.base_angular_velocity * 3.1) * (1.0 if CosmosHasher.hash_2d_float(station_seed, 2222, 222) > 0.35 else -1.0)
			var st_init_theta: float = CosmosHasher.hash_2d_float(station_seed, 2323, 233) * TAU
			var st_ecc: float = lerpf(
				planetary_cfg.station_eccentricity_range.x,
				planetary_cfg.station_eccentricity_range.y,
				CosmosHasher.hash_2d_float(station_seed, 2324, 234)
			)
			var st_peri: float = CosmosHasher.hash_2d_float(station_seed, 2325, 235) * TAU
			var st_cross_sign: float = -1.0 if (visual_idx % 2 == 0) else 1.0
			var st_tilt: float = wrapf(ref_sat_tilt + (deg_to_rad(lerpf(42.0, 84.0, CosmosHasher.hash_2d_float(station_seed, 2326, 236))) * st_cross_sign), -PI, PI)
			var st_squash: float = lerpf(
				planetary_cfg.station_squash_range.x,
				planetary_cfg.station_squash_range.y,
				CosmosHasher.hash_2d_float(station_seed, 2327, 237)
			)

			var station_body: CosmosOrbitalBody2D = CosmosOrbitalBody2D.new()
			station_body.name = "Station_" + str(visual_idx + 1)
			station_body.body_name = StringName("Station_" + str(visual_idx + 1))
			station_body.orbit_radius = station_radius
			station_body.angular_velocity = st_ang_vel
			station_body.initial_theta = st_init_theta
			station_body.orbit_eccentricity = st_ecc
			station_body.orbit_periapsis_angle = st_peri
			station_body.orbit_plane_tilt = st_tilt
			station_body.orbit_plane_squash = st_squash
			station_body.depth_scale_amplitude = planetary_cfg.station_depth_scale_amp
			station_body.enable_depth_z_swap = true
			station_body.base_visual_scale = Vector2.ONE
			station_body.tangent_align = true
			station_body.axial_rotation_velocity = 0.0
			station_body.initial_axial_rotation = 0.0
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
				st_mat.set_shader_parameter("star_light_color", star_color)
				st_mat.set_shader_parameter("biome_tint_color", biome_tint_color)
				st_sprite.material = st_mat

			station_body.add_child(st_sprite)
			station_body.set_sprite_reference(st_sprite)

			if planetary_cfg.enable_orbital_trails:
				var st_trail: CosmosOrbitalTrail2D = CosmosOrbitalTrailScript.new()
				st_trail.name = "StationTrail_" + str(visual_idx + 1)
				var st_head_col: Color = Color(0.36, 0.94, 1.0, planetary_cfg.trail_base_opacity * 1.1)
				st_trail.configure_from_body(
					station_body,
					planetary_cfg.station_trail_arc_radians,
					clampf(station_target_diameter * 0.12, 2.8, 5.0),
					st_head_col,
					Color(0.22, 0.58, 0.95, 0.0),
					16,
					true
				)
				st_trail.visible = (_graphics_quality >= 1)
				planet_body.add_child(st_trail)
				_satellite_trails.append(st_trail)

			planet_body.add_orbital_child(station_body)

		var curr_radial_reach: float = maxf(planet_visual_radius, ring_outer_px) + 20.0
		var solved: Vector2 = _compute_safe_slot_semi_major_axis(
			ideal_radius,
			radius_jitter,
			star_exclusion_radius,
			curr_radial_reach,
			slot_ecc,
			slot_peri,
			slot_squash,
			prev_orbit_a,
			prev_slot_ecc,
			prev_slot_peri,
			prev_slot_squash,
			prev_slot_reach,
			effective_min_spacing,
			safe_outer_cap
		)
		var actual_radius: float = solved.x
		slot_ecc = solved.y

		var ang_vel: float = CosmosKeplerOrbitMath.calculate_keplerian_angular_velocity(system_profile.base_angular_velocity, effective_orbit_min, actual_radius, dir_sign)
		planet_body.orbit_radius = actual_radius
		planet_body.angular_velocity = ang_vel
		planet_body.orbit_eccentricity = slot_ecc
		planet_body.orbit_periapsis_angle = slot_peri
		planet_body.orbit_plane_tilt = slot_tilt
		planet_body.orbit_plane_squash = slot_squash
		prev_orbit_a = actual_radius
		prev_slot_ecc = slot_ecc
		prev_slot_peri = slot_peri
		prev_slot_squash = slot_squash
		prev_slot_reach = curr_radial_reach

		star_body.add_orbital_child(planet_body)
		planets.append(planet_body)

		if zone == PlanetZone.EXTERIOR or has_rings or planet_visual_radius >= 145.0:
			_minor_bodies_controller.register_trojan_cluster_for_planet(
				planet_body,
				p_seed,
				planetary_cfg,
				star_color,
				CELESTIAL_BODY_SHADER,
				_get_light_quad_texture(),
				planetary_cfg.moon_archetypes
			)
		if has_rings:
			_minor_bodies_controller.register_shepherd_moonlets_for_planet(
				planet_body,
				p_seed,
				ring_outer_px,
				ring_roll_rad,
				ring_tilt_x_rad,
				planetary_cfg,
				star_color,
				CELESTIAL_BODY_SHADER,
				_get_light_quad_texture(),
				planetary_cfg.moon_archetypes
			)

		_effective_orbit_max = maxf(_effective_orbit_max, (actual_radius * (1.0 + slot_ecc)) + curr_radial_reach)
		var total_reach: float = (actual_radius * (1.0 + slot_ecc)) + maxf(curr_radial_reach, max_sub_reach) + 120.0
		if total_reach > _bounding_radius:
			_bounding_radius = total_reach

	if _bounding_radius <= 0.0:
		_bounding_radius = effective_orbit_max + 500.0
	_light_field_radius = maxf(_light_field_radius, _effective_orbit_max * light_field_mult)
	light_sprite.scale = Vector2.ONE * _light_field_radius
	_bounding_radius = maxf(_bounding_radius, _light_field_radius)

	_star_exclusion_radius = star_exclusion_radius
	_comet_controller = CosmosCometControllerScript.new()
	_comet_controller.name = "CometController"
	star_body.add_child(_comet_controller)
	_comet_controller.set_trails_visible(_graphics_quality >= 1)
	_comet_controller.build_comets(
		system_seed,
		planetary_cfg,
		star_exclusion_radius,
		_light_field_radius,
		system_profile.base_angular_velocity,
		effective_orbit_min,
		star_color,
		_get_light_quad_texture(),
		system_ecliptic_tilt
	)

	_orbit_guides_overlay = CosmosOrbitGuidesOverlayScript.new()
	star_body.add_child(_orbit_guides_overlay)
	_orbit_guides_overlay.setup(self, _star_exclusion_radius)
	_orbit_guides_overlay.visible = _orbit_guides_visible

## Actualiza dinámicamente los vectores de luz (terminador día/noche), conos de sombra y eclipses.
func _update_lighting_vectors() -> void:
	# 1. Proyectar conos de sombra y evaluar eclipses interplanetarios de forma modular
	if shadow_projector != null:
		shadow_projector.update_projections(planets, _light_field_radius, _star_core_visual_radius, _last_global_time)
		shadow_projector.evaluate_eclipses(planets, _light_field_radius)

	# 1.5 Sincronizar oclusores planetarios al campo de luz estelar ("catedral de luz")
	if _light_field_mat != null and _light_field_radius > 1.0:
		_ensure_occluder_buf()
		var inv_diam: float = 0.5 / _light_field_radius
		var occ_count: int = mini(planets.size(), 8)
		for i: int in range(occ_count):
			var p_occ: CosmosOrbitalBody2D = planets[i]
			if is_instance_valid(p_occ):
				var pr: float = float(p_occ.get_meta(&"visual_radius", 130.0)) * p_occ.scale.x
				_occluder_uniform_buf[i] = Vector4(p_occ.position.x * inv_diam, p_occ.position.y * inv_diam, pr * inv_diam, 0.0)
			else:
				_occluder_uniform_buf[i] = Vector4.ZERO
		for i: int in range(occ_count, 8):
			_occluder_uniform_buf[i] = Vector4.ZERO
		_light_field_mat.set_shader_parameter("occluder_count", occ_count)
		_light_field_mat.set_shader_parameter("occluders", _occluder_uniform_buf)

	# 2. Actualizar iluminación 3D día/noche en planetas, lunas, tránsitos lunares y estaciones
	for planet_body: CosmosOrbitalBody2D in planets:
		if not is_instance_valid(planet_body):
			continue
		var p_pos: Vector2 = planet_body.position
		var p_dist: float = p_pos.length()
		var light_dir_planet: Vector2 = -p_pos.normalized() if p_dist > 1.0 else Vector2(-1.0, 0.0)
		var outward_dir: Vector2 = -light_dir_planet
		var p_radius: float = float(planet_body.get_meta(&"visual_radius", 130.0)) * planet_body.scale.x
		var dyn_planet_lz: float = clampf(0.30 - (planet_body.current_depth_z * 0.22), 0.08, 0.56)

		var p_sprite: Sprite2D = planet_body.get_sprite()
		var p_mat: ShaderMaterial = p_sprite.material as ShaderMaterial if (p_sprite != null and p_sprite.material is ShaderMaterial) else null
		if p_mat != null:
			p_mat.set_shader_parameter("light_direction", light_dir_planet)
			p_mat.set_shader_parameter("light_depth", dyn_planet_lz)
		var inter_eclipse: float = float(p_mat.get_shader_parameter("eclipse_shadow")) if p_mat != null else 0.0
		CosmosPlanetVisualBuilder.update_ring_lighting(planet_body, light_dir_planet, inter_eclipse, dyn_planet_lz)

		var has_sunward_moon_transit: bool = false
		var best_transit_uv: Vector2 = Vector2.ZERO
		var best_transit_r: float = 0.25
		var best_transit_str: float = 0.0

		for sub_body: CosmosOrbitalBody2D in planet_body.get_orbital_children():
			if not is_instance_valid(sub_body):
				continue
			var m_rel_pos: Vector2 = sub_body.position * planet_body.scale
			var proj_dist: float = m_rel_pos.dot(outward_dir)

			if bool(sub_body.get_meta(&"is_moon", false)):
				var moon_r: float = float(sub_body.get_meta(&"visual_radius", 24.0)) * sub_body.scale.x * planet_body.scale.x
				var front_gate: float = smoothstep(-0.18, 0.15, sub_body.current_depth_z)
				if front_gate > 0.01:
					var m_perp_2d: Vector2 = m_rel_pos - (outward_dir * proj_dist)
					var m_str: float = 0.0
					var m_uv: Vector2 = Vector2.ZERO
					if proj_dist < -p_radius * 0.15 and m_perp_2d.length() < p_radius * 1.25:
						m_str = clampf((-proj_dist) / maxf(p_radius * 0.75, 1.0), 0.0, 1.0) * 0.92 * front_gate
						m_uv = m_perp_2d / maxf(p_radius, 1.0)
					elif sub_body.current_depth_z > 0.20 and m_rel_pos.length() < p_radius * 0.98 and m_rel_pos.dot(light_dir_planet) > -p_radius * 0.15:
						m_str = clampf((sub_body.current_depth_z - 0.15) * 1.1, 0.0, 0.85)
						m_uv = m_rel_pos / maxf(p_radius, 1.0)
					if m_str > best_transit_str:
						best_transit_str = m_str
						best_transit_uv = m_uv
						best_transit_r = clampf((moon_r / maxf(p_radius, 1.0)) * 1.25, 0.12, 0.45)
						has_sunward_moon_transit = true

			var sub_sprite: Sprite2D = sub_body.get_sprite()
			if sub_sprite != null and sub_sprite.material is ShaderMaterial:
				var moon_world_in_system: Vector2 = p_pos + m_rel_pos
				var light_dir_moon: Vector2 = -moon_world_in_system.normalized() if moon_world_in_system.length_squared() > 1.0 else light_dir_planet
				var sub_mat: ShaderMaterial = sub_sprite.material as ShaderMaterial
				sub_mat.set_shader_parameter("light_direction", light_dir_moon)
				if bool(sub_body.get_meta(&"is_moon", false)):
					var dyn_moon_lz: float = clampf(0.30 - (planet_body.current_depth_z * 0.14 + sub_body.current_depth_z * 0.24), 0.06, 0.62)
					sub_mat.set_shader_parameter("light_depth", dyn_moon_lz)

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
					var z_eclipse_atten: float = 1.0 - (smoothstep(0.55, 0.95, absf(sub_body.current_depth_z)) * 0.45)
					local_e *= clampf(proj_dist / maxf(p_radius * 0.6, 1.0), 0.0, 1.0) * z_eclipse_atten
					moon_eclipse_val = maxf(moon_eclipse_val, local_e)
				sub_mat.set_shader_parameter("eclipse_shadow", moon_eclipse_val)

		if p_mat != null:
			p_mat.set_shader_parameter("transit_shadow_strength", best_transit_str if has_sunward_moon_transit else 0.0)
			if has_sunward_moon_transit:
				p_mat.set_shader_parameter("transit_shadow_uv", best_transit_uv)
				p_mat.set_shader_parameter("transit_shadow_radius", best_transit_r)

func apply_graphics_quality(quality_level: int) -> void:
	_graphics_quality = clampi(quality_level, 0, 2)
	if is_instance_valid(_lens_sprite):
		_lens_sprite.visible = (_graphics_quality >= 2)
	if shadow_projector != null:
		shadow_projector.set_crepuscular_enabled(_graphics_quality >= 1)
	if _light_field_mat != null:
		_light_field_mat.set_shader_parameter("heliopause_aura_strength", 0.56 if _graphics_quality >= 1 else 0.26)
		_light_field_mat.set_shader_parameter("astro_compass_strength", 0.22 if _graphics_quality >= 1 else 0.0)
	for trail: CosmosOrbitalTrail2D in _satellite_trails:
		if is_instance_valid(trail):
			trail.visible = (_graphics_quality >= 1)
	if is_instance_valid(_comet_controller):
		_comet_controller.set_trails_visible(_graphics_quality >= 1)

func get_light_field_radius() -> float:
	return _light_field_radius

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

class_name CosmicLightingSampler
extends RefCounted

## Muestreador analítico zero-allocation que traduce el estado de CosmosRootNode
## (estrella dominante, bioma interpolado y conos de sombra planetaria) a un CosmicLightingSample.

const LightingSampleScript = preload("res://scenes/combat/environment/cosmos/core/cosmic_lighting_sample.gd")
const LightingConfigScript = preload("res://scenes/combat/environment/cosmos/resources/cosmic_rig_lighting_config.gd")
const KeplerMathScript = preload("res://scenes/combat/environment/cosmos/core/kepler_orbit_math.gd")

static var _default_config: LightingConfigScript = null


static func _get_default_config() -> LightingConfigScript:
	if _default_config == null:
		var loaded: Resource = load("res://scenes/combat/environment/cosmos/resources/data/default_rig_lighting.tres")
		if loaded is LightingConfigScript:
			_default_config = loaded as LightingConfigScript
		else:
			_default_config = LightingConfigScript.new()
	return _default_config


static func sample_at(
	cosmos_root: CosmosRootNode,
	world_pos: Vector2,
	config: LightingConfigScript = null,
	out_sample: LightingSampleScript = null
) -> LightingSampleScript:
	var cfg: LightingConfigScript = config if config != null else _get_default_config()
	var sample: LightingSampleScript = out_sample if out_sample != null else LightingSampleScript.new()
	sample.reset_defaults(cfg.fallback_light_dir_2d, cfg.light_z_3d)
	sample.visibility_floor = cfg.eclipse_min_visibility_floor

	if cosmos_root == null or not is_instance_valid(cosmos_root):
		return sample

	_sample_biome_tints(cosmos_root, cfg, sample)
	_sample_dominant_star_and_eclipse(cosmos_root, world_pos, cfg, sample)
	return sample


static func _sample_biome_tints(
	cosmos_root: CosmosRootNode,
	cfg: LightingConfigScript,
	sample: LightingSampleScript
) -> void:
	var biome_a: CosmosBiomeConfig = null
	var biome_b: CosmosBiomeConfig = null
	var blend: float = 0.0

	if cosmos_root.nebula_controller != null and is_instance_valid(cosmos_root.nebula_controller):
		biome_a = cosmos_root.nebula_controller.biome_a
		biome_b = cosmos_root.nebula_controller.biome_b
		blend = clampf(cosmos_root.nebula_controller.biome_blend_factor, 0.0, 1.0)

	if biome_a == null and cosmos_root.environment_profile != null:
		biome_a = cosmos_root.environment_profile.biome_a_profile
		if biome_b == null:
			biome_b = cosmos_root.environment_profile.biome_b_profile
			blend = clampf(cosmos_root.environment_profile.biome_blend_factor, 0.0, 1.0)

	if biome_a == null:
		return

	var sh_a: Color = _derive_biome_shadow_tint(biome_a)
	var sh_final: Color = sh_a
	if biome_b != null and blend > 0.001:
		var sh_b: Color = _derive_biome_shadow_tint(biome_b)
		sh_final = sh_a.lerp(sh_b, blend)

	sample.shadow_tint = sh_final
	sample.ao_tint = Color(
		clampf(sh_final.r * 0.52, 0.03, 0.55),
		clampf(sh_final.g * 0.50, 0.03, 0.55),
		clampf(sh_final.b * 0.56, 0.05, 0.65),
		1.0
	)
	sample.biome_shadow_weight = cfg.max_biome_shadow_mix


static func _derive_biome_shadow_tint(biome: CosmosBiomeConfig) -> Color:
	var gas_mix: Color = biome.color_gas_primary.lerp(biome.color_gas_secondary, 0.35)
	var base: Color = biome.color_deep_space.lerp(gas_mix, 0.72)
	var max_c: float = maxf(base.r, maxf(base.g, maxf(base.b, 0.001)))
	var target_val: float = 0.34
	var scale: float = target_val / max_c
	return Color(
		clampf(base.r * scale, 0.07, 0.48),
		clampf(base.g * scale, 0.07, 0.48),
		clampf(base.b * scale, 0.12, 0.56),
		1.0
	)


static func _sample_dominant_star_and_eclipse(
	cosmos_root: CosmosRootNode,
	world_pos: Vector2,
	cfg: LightingConfigScript,
	sample: LightingSampleScript
) -> void:
	var streamer: CosmosSolarSystemStreamer = cosmos_root.solar_streamer
	if streamer == null or not is_instance_valid(streamer):
		return

	var active_systems: Dictionary = streamer.get_active_systems()
	if active_systems.is_empty():
		return

	var p_layer: Parallax2D = streamer.parallax_layer
	var scroll_scale: Vector2 = p_layer.scroll_scale if p_layer != null else Vector2.ONE
	var scroll_offset: Vector2 = p_layer.scroll_offset if p_layer != null else Vector2.ZERO
	var same_scroll: bool = scroll_scale.is_equal_approx(Vector2.ONE)

	var cam_pos: Vector2 = world_pos
	if not same_scroll:
		if cosmos_root.viewport_tracker != null:
			cam_pos = cosmos_root.viewport_tracker.current_center
		elif cosmos_root.camera != null and is_instance_valid(cosmos_root.camera):
			cam_pos = cosmos_root.camera.global_position

	var best_sys: CosmosSolarSystem2D = null
	var best_star_world: Vector2 = Vector2.ZERO
	var best_dist: float = INF
	var best_score: float = -1.0
	var best_light_rad: float = 2400.0

	for cell_v: Variant in active_systems.keys():
		var sys: CosmosSolarSystem2D = active_systems[cell_v] as CosmosSolarSystem2D
		if sys == null or not is_instance_valid(sys) or not sys.visible or sys.star_body == null:
			continue

		var layer_pos: Vector2 = sys.position + sys.star_body.position
		var star_world: Vector2 = (layer_pos + scroll_offset) if same_scroll else ((cam_pos * (Vector2.ONE - scroll_scale)) + layer_pos + scroll_offset)
		var dist: float = world_pos.distance_to(star_world)

		var arch: CosmosStarArchetype = sys.active_archetype
		var orbit_max: float = arch.orbit_radius_max if arch != null else 2760.0
		var light_rad: float = maxf(orbit_max * cfg.star_influence_radius_multiplier, 600.0)
		var proximity: float = clampf(1.0 - (dist / light_rad), 0.0, 1.0)
		var score: float = proximity if proximity > 0.0 else (-dist * 0.00001)

		if best_sys == null or score > best_score:
			best_sys = sys
			best_star_world = star_world
			best_dist = dist
			best_score = score
			best_light_rad = light_rad

	if best_sys == null:
		return

	sample.has_active_star = true
	sample.dominant_star_distance = best_dist
	if best_sys.star_body != null:
		sample.dominant_star_name = best_sys.star_body.body_name

	var to_star: Vector2 = best_star_world - world_pos
	var dir_2d: Vector2 = to_star.normalized() if to_star.length_squared() > 1.0 else cfg.fallback_light_dir_2d.normalized()
	sample.light_dir_2d = dir_2d
	sample.light_dir_3d = Vector3(dir_2d.x, -dir_2d.y, cfg.light_z_3d).normalized()

	var star_col: Color = Color(1.0, 0.88, 0.55, 1.0)
	if best_sys.active_archetype != null:
		star_col = best_sys.active_archetype.star_color
	elif best_sys.system_profile != null:
		star_col = best_sys.system_profile.star_emission_color

	var proximity_norm: float = clampf(1.0 - (best_dist / best_light_rad), 0.0, 1.0)
	sample.star_proximity = proximity_norm
	sample.key_light_tint = Color.WHITE.lerp(star_col, 0.72)
	sample.rim_key_color = star_col.lightened(0.24)
	sample.star_tint_weight = cfg.max_star_tint_mix * maxf(proximity_norm, 0.15)
	sample.rim_tint_weight = cfg.max_rim_tint_mix * maxf(proximity_norm, 0.25)

	var eclipse: float = _evaluate_system_eclipse(best_sys, world_pos - best_star_world, cfg, best_light_rad)
	sample.eclipse_factor = eclipse
	sample.emissive_boost_mult = lerpf(1.0, cfg.eclipse_emissive_boost, eclipse)


static func _evaluate_system_eclipse(
	sys: CosmosSolarSystem2D,
	rel_world_pos: Vector2,
	cfg: LightingConfigScript,
	fallback_light_rad: float
) -> float:
	var proj: CosmosPlanetaryShadowProjector2D = sys.shadow_projector
	if proj != null and (not proj.shadows_enabled or proj.shadow_opacity <= 0.001):
		return 0.0

	var expansion: float = proj.shadow_expansion_factor if proj != null else 1.85
	var penumbra: float = proj.shadow_penumbra_ratio if proj != null else 0.45
	var helio_feather: float = proj.shadow_heliopause_fade if proj != null else 0.22
	var light_field_rad: float = sys._light_field_radius if sys._light_field_radius > 0.0 else fallback_light_rad

	var rec_dist: float = rel_world_pos.length()
	if rec_dist >= light_field_rad:
		return 0.0

	var edge_fade: float = 1.0
	if helio_feather > 0.001:
		var norm_r: float = rec_dist / maxf(light_field_rad, 1.0)
		var fade_start: float = maxf(1.0 - helio_feather, 0.0)
		if norm_r > fade_start:
			var t: float = clampf((norm_r - fade_start) / maxf(1.0 - fade_start, 0.001), 0.0, 1.0)
			edge_fade = 1.0 - (t * t * (3.0 - 2.0 * t))

	var max_eclipse: float = 0.0
	for planet_body: CosmosOrbitalBody2D in sys.planets:
		if not is_instance_valid(planet_body):
			continue
		var p_pos: Vector2 = planet_body.position
		var p_rad: float = float(planet_body.get_meta(&"visual_radius", 130.0))
		var e_planet: float = KeplerMathScript.calculate_interplanetary_eclipse(
			rel_world_pos,
			cfg.rig_eclipse_receiver_radius,
			p_pos,
			p_rad,
			expansion,
			penumbra,
			light_field_rad
		)
		max_eclipse = maxf(max_eclipse, e_planet)

		for sub_body: CosmosOrbitalBody2D in planet_body.get_orbital_children():
			if not is_instance_valid(sub_body) or not sub_body.has_meta(&"visual_radius"):
				continue
			var m_pos: Vector2 = p_pos + sub_body.position
			var m_rad: float = float(sub_body.get_meta(&"visual_radius", 25.0))
			var e_moon: float = KeplerMathScript.calculate_interplanetary_eclipse(
				rel_world_pos,
				cfg.rig_eclipse_receiver_radius,
				m_pos,
				m_rad,
				expansion,
				penumbra,
				light_field_rad
			)
			max_eclipse = maxf(max_eclipse, e_moon)

	return clampf(max_eclipse * edge_fade, 0.0, 1.0)

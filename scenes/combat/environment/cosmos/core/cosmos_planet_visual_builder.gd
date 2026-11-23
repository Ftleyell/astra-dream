class_name CosmosPlanetVisualBuilder
extends RefCounted

## Constructor modular sin estado para cuerpos celestes v2 (planetas 2:1, lunas y anillos 2.5D).
## Configura shaders de proyección esférica real y mantiene invariante el orden de árbol:
## RingBack -> PlanetVisual (Sprite principal en CosmosOrbitalBody2D) -> RingFront.


static func _weighted_pick(
	candidates: Array[CosmosPlanetArchetype],
	seed_val: int,
	salt_x: int,
	salt_y: int
) -> CosmosPlanetArchetype:
	if candidates.is_empty():
		return null
	var total_weight: float = 0.0
	for arch: CosmosPlanetArchetype in candidates:
		total_weight += maxf(arch.spawn_weight, 0.01)
	var roll: float = CosmosHasher.hash_2d_float(seed_val, salt_x, salt_y) * total_weight
	var acc: float = 0.0
	for arch: CosmosPlanetArchetype in candidates:
		acc += maxf(arch.spawn_weight, 0.01)
		if roll <= acc:
			return arch
	return candidates[candidates.size() - 1]


## Selecciona un arquetipo planetario determinista según la zona astrofísica, evitando repeticiones.
static func pick_planet_archetype(
	archetypes: Array[CosmosPlanetArchetype],
	zone: int,
	seed_val: int,
	excluded_ids: Array[StringName] = []
) -> CosmosPlanetArchetype:
	if archetypes.is_empty():
		return null
	var matching: Array[CosmosPlanetArchetype] = []
	var fallback_unused: Array[CosmosPlanetArchetype] = []
	var fallback_all: Array[CosmosPlanetArchetype] = []
	for arch: CosmosPlanetArchetype in archetypes:
		if arch == null or arch.zone == CosmosPlanetArchetype.ZoneType.MOON:
			continue
		fallback_all.append(arch)
		if excluded_ids.has(arch.archetype_id):
			continue
		fallback_unused.append(arch)
		if arch.zone == zone:
			matching.append(arch)
	if not matching.is_empty():
		return _weighted_pick(matching, seed_val, 808, 88)
	if not fallback_unused.is_empty():
		return _weighted_pick(fallback_unused, seed_val, 808, 88)
	return _weighted_pick(fallback_all, seed_val, 808, 88)


## Selecciona un arquetipo de luna determinista (prefiere magma en interior, crío en exterior, cráter en habitable).
static func pick_moon_archetype(
	archetypes: Array[CosmosPlanetArchetype],
	zone: int,
	seed_val: int
) -> CosmosPlanetArchetype:
	if archetypes.is_empty():
		return null
	var all_moons: Array[CosmosPlanetArchetype] = []
	var preferred: Array[CosmosPlanetArchetype] = []
	for arch: CosmosPlanetArchetype in archetypes:
		if arch == null:
			continue
		all_moons.append(arch)
		if zone == CosmosPlanetArchetype.ZoneType.INTERIOR and arch.is_magma_moon:
			preferred.append(arch)
		elif zone == CosmosPlanetArchetype.ZoneType.EXTERIOR and arch.is_cryo_moon:
			preferred.append(arch)
		elif zone == CosmosPlanetArchetype.ZoneType.HABITABLE and not arch.is_magma_moon and not arch.is_cryo_moon:
			preferred.append(arch)
	if not preferred.is_empty():
		return _weighted_pick(preferred, seed_val, 909, 99)
	return _weighted_pick(all_moons, seed_val, 909, 99)


static func _build_body_material(
	archetype: CosmosPlanetArchetype,
	body_shader: Shader,
	body_seed: int,
	tilt_rad: float,
	lighting_ctx: Dictionary
) -> ShaderMaterial:
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = body_shader

	mat.set_shader_parameter("use_spherical_projection", true)
	mat.set_shader_parameter("surface_albedo_tex", archetype.albedo_texture)
	mat.set_shader_parameter("surface_maps_tex", archetype.surface_maps_texture)
	mat.set_shader_parameter("use_normal_ao_map", archetype.normal_ao_texture != null)
	if archetype.normal_ao_texture != null:
		mat.set_shader_parameter("surface_normal_ao_tex", archetype.normal_ao_texture)
	mat.set_shader_parameter("ao_strength", archetype.ao_strength)
	mat.set_shader_parameter("planet_radius", 0.485)
	mat.set_shader_parameter("edge_crop_margin", 0.012)
	mat.set_shader_parameter("rim_edge_feather", 0.007)
	mat.set_shader_parameter("axial_tilt_rad", tilt_rad)
	mat.set_shader_parameter("lon_phase", CosmosHasher.hash_2d_float(body_seed, 604, 64) * TAU)

	var spin_dir: float = 1.0 if CosmosHasher.hash_2d_float(body_seed, 606, 66) > 0.35 else -1.0
	var spin_spd: float = lerpf(
		archetype.spin_speed_range.x,
		archetype.spin_speed_range.y,
		CosmosHasher.hash_2d_float(body_seed, 607, 67)
	)
	mat.set_shader_parameter("axial_spin_speed", spin_spd * spin_dir)

	mat.set_shader_parameter("cloud_coverage", archetype.cloud_coverage)
	mat.set_shader_parameter("cloud_spin_speed_offset", archetype.cloud_spin_speed_offset * spin_dir)
	mat.set_shader_parameter("cloud_tint", archetype.cloud_tint)
	mat.set_shader_parameter("cloud_shadow_offset", archetype.cloud_shadow_offset)
	mat.set_shader_parameter("cloud_height_parallax", archetype.cloud_height_parallax)
	mat.set_shader_parameter("gas_band_shear", archetype.gas_band_shear * spin_dir)

	mat.set_shader_parameter("night_emissive_color", archetype.night_emissive_color)
	mat.set_shader_parameter("night_emissive_strength", archetype.night_emissive_strength)
	mat.set_shader_parameter("night_emissive_day_keep", archetype.night_emissive_day_keep)
	mat.set_shader_parameter("night_emissive_albedo_mix", archetype.night_emissive_albedo_mix)
	mat.set_shader_parameter("specular_strength", archetype.specular_strength)
	mat.set_shader_parameter("specular_shininess", archetype.specular_shininess)
	mat.set_shader_parameter("bump_strength", archetype.bump_strength)
	mat.set_shader_parameter("aurora_color", archetype.aurora_color)
	mat.set_shader_parameter("aurora_strength", archetype.aurora_strength)

	mat.set_shader_parameter("atmosphere_color", archetype.atmosphere_color)
	mat.set_shader_parameter("atmosphere_intensity", archetype.atmosphere_intensity)
	mat.set_shader_parameter("outer_atmosphere_thickness", archetype.outer_atmosphere_thickness)
	mat.set_shader_parameter("terminator_scatter_color", archetype.twilight_scatter_color)
	mat.set_shader_parameter("terminator_scatter_strength", archetype.twilight_scatter_strength)
	mat.set_shader_parameter("emission_glow", 0.0)

	var night_amb: float = float(lighting_ctx.get("night_ambient", 0.22))
	var day_exp: float = float(lighting_ctx.get("day_exposure", 1.34))
	var star_col: Color = lighting_ctx.get("star_color", Color(1.0, 0.9, 0.65, 1.0))
	var day_tint: float = float(lighting_ctx.get("day_tint_strength", 0.40))
	var atmo_tint: float = float(lighting_ctx.get("atmo_tint_strength", 0.50))
	var atten: float = float(lighting_ctx.get("dist_tint_attenuation", 1.0))
	var biome_col: Color = lighting_ctx.get("biome_tint_color", Color(0.15, 0.08, 0.25, 1.0))
	var biome_int: float = float(lighting_ctx.get("biome_tint_intensity", 0.16))

	mat.set_shader_parameter("night_ambient", night_amb)
	mat.set_shader_parameter("day_exposure_boost", day_exp)
	mat.set_shader_parameter("star_light_color", star_col)
	mat.set_shader_parameter("star_light_tint_strength", day_tint * atten)
	mat.set_shader_parameter("star_atmo_tint_strength", atmo_tint * atten)
	mat.set_shader_parameter("biome_tint_color", biome_col)
	mat.set_shader_parameter("biome_tint_intensity", biome_int)
	return mat


static func _build_ring_sprite(
	node_name: String,
	ring_pass: int,
	archetype: CosmosPlanetArchetype,
	quad_tex: Texture2D,
	ring_shader: Shader,
	ring_quad_half: float,
	roll_rad: float,
	lighting_ctx: Dictionary
) -> Sprite2D:
	var r_spr: Sprite2D = Sprite2D.new()
	r_spr.name = node_name
	r_spr.centered = true
	r_spr.texture = quad_tex
	# Sprite quad de 2x2 px => ancho total = 2 * ring_quad_half
	r_spr.scale = Vector2.ONE * ring_quad_half
	r_spr.z_index = 0

	var r_mat: ShaderMaterial = ShaderMaterial.new()
	r_mat.shader = ring_shader
	r_mat.set_shader_parameter("ring_texture", archetype.ring_texture)
	r_mat.set_shader_parameter("ring_pass", ring_pass)
	r_mat.set_shader_parameter("outer_r_norm", 0.485)
	r_mat.set_shader_parameter("inner_r_norm", 0.485 * (archetype.ring_inner_radius / maxf(archetype.ring_outer_radius, 0.01)))
	r_mat.set_shader_parameter("planet_r_norm", 0.485 / maxf(archetype.ring_outer_radius, 0.01))
	r_mat.set_shader_parameter("tilt_x_rad", deg_to_rad(archetype.ring_tilt_x_deg))
	r_mat.set_shader_parameter("roll_rad", roll_rad)
	r_mat.set_shader_parameter("ring_spin_speed", archetype.ring_spin_speed)
	r_mat.set_shader_parameter("ring_tint", archetype.ring_tint)
	r_mat.set_shader_parameter("ring_opacity", archetype.ring_opacity)

	var star_col: Color = lighting_ctx.get("star_color", Color(1.0, 0.9, 0.65, 1.0))
	var day_tint: float = float(lighting_ctx.get("day_tint_strength", 0.40))
	var atten: float = float(lighting_ctx.get("dist_tint_attenuation", 1.0))
	var biome_col: Color = lighting_ctx.get("biome_tint_color", Color(0.15, 0.08, 0.25, 1.0))
	var biome_int: float = float(lighting_ctx.get("biome_tint_intensity", 0.16))

	r_mat.set_shader_parameter("star_light_color", star_col)
	r_mat.set_shader_parameter("star_light_tint_strength", day_tint * atten)
	r_mat.set_shader_parameter("biome_tint_color", biome_col)
	r_mat.set_shader_parameter("biome_tint_intensity", biome_int)

	r_spr.material = r_mat
	return r_spr


## Construye visual completo v2 para un planeta (y anillos 2.5D si aplican) respetando orden RingBack -> PlanetVisual -> RingFront.
static func configure_planet_visual(
	planet_body: CosmosOrbitalBody2D,
	archetype: CosmosPlanetArchetype,
	p_seed: int,
	size_multiplier: float,
	quad_tex: Texture2D,
	body_shader: Shader,
	ring_shader: Shader,
	lighting_ctx: Dictionary
) -> Dictionary:
	var diam_t: float = CosmosHasher.hash_2d_float(p_seed, 809, 89)
	var target_diameter: float = lerpf(archetype.diameter_range.x, archetype.diameter_range.y, diam_t) * size_multiplier
	var planet_visual_radius: float = target_diameter * 0.473

	var spawn_ring: bool = (
		archetype.ring_texture != null
		and ring_shader != null
		and archetype.ring_probability > 0.0
		and CosmosHasher.hash_2d_float(p_seed, 811, 91) <= archetype.ring_probability
	)

	var roll_rad: float = 0.0
	var tilt_rad: float = deg_to_rad(archetype.axial_tilt_deg) * (1.0 if CosmosHasher.hash_2d_float(p_seed, 812, 92) > 0.5 else -1.0)
	var ring_outer_px: float = 0.0
	var ring_back_spr: Sprite2D = null
	var ring_front_spr: Sprite2D = null
	var ring_mats: Array[ShaderMaterial] = []

	if spawn_ring:
		roll_rad = deg_to_rad(lerpf(
			archetype.ring_roll_deg_range.x,
			archetype.ring_roll_deg_range.y,
			CosmosHasher.hash_2d_float(p_seed, 813, 93)
		))
		# Alinear inclinación ecuatorial del planeta con sus anillos 2.5D
		tilt_rad = roll_rad
		ring_outer_px = planet_visual_radius * archetype.ring_outer_radius
		# Quad de 2x2 px => ancho total = ring_outer_px / 0.485 => half_scale = ring_outer_px / 0.97
		var ring_quad_half: float = ring_outer_px / 0.97

		ring_back_spr = _build_ring_sprite("RingBack", 0, archetype, quad_tex, ring_shader, ring_quad_half, roll_rad, lighting_ctx)
		ring_front_spr = _build_ring_sprite("RingFront", 1, archetype, quad_tex, ring_shader, ring_quad_half, roll_rad, lighting_ctx)
		ring_mats.append(ring_back_spr.material as ShaderMaterial)
		ring_mats.append(ring_front_spr.material as ShaderMaterial)

	# Orden estricto: RingBack -> PlanetVisual (y set_sprite_reference inmediato) -> RingFront
	if ring_back_spr != null:
		planet_body.add_child(ring_back_spr)

	var planet_sprite: Sprite2D = Sprite2D.new()
	planet_sprite.name = "PlanetVisual"
	planet_sprite.centered = true
	planet_sprite.texture = quad_tex
	planet_sprite.scale = Vector2.ONE * (target_diameter * 0.5)
	planet_sprite.z_index = 0
	if body_shader != null:
		var body_mat: ShaderMaterial = _build_body_material(archetype, body_shader, p_seed, tilt_rad, lighting_ctx)
		if spawn_ring:
			body_mat.set_shader_parameter("has_ring_shadow", true)
			body_mat.set_shader_parameter("ring_shadow_tex", archetype.ring_texture)
			body_mat.set_shader_parameter("ring_shadow_inner_r", archetype.ring_inner_radius)
			body_mat.set_shader_parameter("ring_shadow_outer_r", archetype.ring_outer_radius)
			body_mat.set_shader_parameter("ring_shadow_tilt_x_rad", deg_to_rad(archetype.ring_tilt_x_deg))
			body_mat.set_shader_parameter("ring_shadow_roll_rad", roll_rad)
			body_mat.set_shader_parameter("ring_shadow_opacity", clampf(archetype.ring_opacity * 0.78, 0.25, 0.85))
			body_mat.set_shader_parameter("ring_shadow_spin_speed", archetype.ring_spin_speed)
		planet_sprite.material = body_mat

	planet_body.add_child(planet_sprite)
	planet_body.set_sprite_reference(planet_sprite)
	planet_body.set_meta(&"visual_radius", planet_visual_radius)
	planet_body.set_meta(&"atmosphere_color", archetype.atmosphere_color)

	if ring_front_spr != null:
		planet_body.add_child(ring_front_spr)

	if not ring_mats.is_empty():
		planet_body.set_meta(&"ring_materials", ring_mats)
		planet_body.set_meta(&"ring_outer_radius", ring_outer_px)
		planet_body.set_meta(&"ring_roll_rad", roll_rad)
		planet_body.set_meta(&"ring_tilt_x_rad", deg_to_rad(archetype.ring_tilt_x_deg))

	return {
		"visual_diameter": target_diameter,
		"visual_radius": planet_visual_radius,
		"ring_outer_radius_px": ring_outer_px,
		"has_rings": spawn_ring,
		"ring_roll_rad": roll_rad,
		"ring_tilt_x_rad": deg_to_rad(archetype.ring_tilt_x_deg) if spawn_ring else 0.0,
	}


## Construye visual v2 para una luna esférica 3D.
static func configure_moon_visual(
	moon_body: CosmosOrbitalBody2D,
	archetype: CosmosPlanetArchetype,
	moon_seed: int,
	target_diameter: float,
	quad_tex: Texture2D,
	body_shader: Shader,
	lighting_ctx: Dictionary
) -> float:
	var tilt_rad: float = deg_to_rad(archetype.axial_tilt_deg) * (1.0 if CosmosHasher.hash_2d_float(moon_seed, 1412, 42) > 0.5 else -1.0)
	var moon_sprite: Sprite2D = Sprite2D.new()
	moon_sprite.name = "MoonVisual"
	moon_sprite.centered = true
	moon_sprite.texture = quad_tex
	moon_sprite.scale = Vector2.ONE * (target_diameter * 0.5)
	moon_sprite.z_index = 0
	if body_shader != null:
		var moon_ctx: Dictionary = lighting_ctx.duplicate()
		moon_ctx["day_exposure"] = float(lighting_ctx.get("day_exposure", 1.30)) * 0.86
		moon_ctx["night_ambient"] = float(lighting_ctx.get("night_ambient", 0.22)) * 0.9
		moon_ctx["atmo_tint_strength"] = 0.0
		moon_ctx["biome_tint_intensity"] = clampf(float(lighting_ctx.get("biome_tint_intensity", 0.20)) * 1.35, 0.0, 0.45)
		moon_sprite.material = _build_body_material(archetype, body_shader, moon_seed, tilt_rad, moon_ctx)

	var moon_visual_radius: float = target_diameter * 0.473
	moon_body.add_child(moon_sprite)
	moon_body.set_sprite_reference(moon_sprite)
	moon_body.set_meta(&"visual_radius", moon_visual_radius)
	return moon_visual_radius


## Actualiza iluminación solar 3D y sombra de eclipse en anillos sin asignar memoria.
static func update_ring_lighting(
	planet_body: CosmosOrbitalBody2D,
	light_dir: Vector2,
	eclipse_shadow: float,
	p_light_depth: float = 0.30
) -> void:
	if not planet_body.has_meta(&"ring_materials"):
		return
	var mats_var: Variant = planet_body.get_meta(&"ring_materials")
	if not (mats_var is Array):
		return
	var mats: Array = mats_var as Array
	for item: Variant in mats:
		if item is ShaderMaterial:
			var r_mat: ShaderMaterial = item as ShaderMaterial
			r_mat.set_shader_parameter("light_direction", light_dir)
			r_mat.set_shader_parameter("light_depth", p_light_depth)
			r_mat.set_shader_parameter("eclipse_shadow", eclipse_shadow)

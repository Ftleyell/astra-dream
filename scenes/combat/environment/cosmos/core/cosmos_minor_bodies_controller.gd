class_name CosmosMinorBodiesController2D
extends Node2D

## CosmosMinorBodiesController2D.gd
## Administra micro-cuerpos orgánicos sin contaminar planet_body.get_orbital_children():
## 1) Cúmulos troyanos en puntos de Lagrange L4/L5 (+-60 deg) de gigantes/planetas exteriores.
## 2) Lunas pastoras (shepherd moonlets) orbitando en el plano exacto de anillos planetarios 2.5D.

var _trojans: Array[Dictionary] = []
var _shepherds: Array[Dictionary] = []

func get_shepherd_entries() -> Array[Dictionary]:
	return _shepherds

func clear_minor_bodies() -> void:
	for entry: Dictionary in _trojans:
		var spr: Node2D = entry.get("node", null) as Node2D
		if is_instance_valid(spr):
			spr.queue_free()
	for entry: Dictionary in _shepherds:
		var spr: Node2D = entry.get("node", null) as Node2D
		if is_instance_valid(spr):
			spr.queue_free()
	_trojans.clear()
	_shepherds.clear()

func register_trojan_cluster_for_planet(
	planet_body: CosmosOrbitalBody2D,
	planet_seed: int,
	planetary_cfg: CosmosPlanetarySystemConfig,
	star_color: Color,
	body_shader: Shader,
	quad_tex: Texture2D,
	moon_archetypes: Array[CosmosPlanetArchetype]
) -> void:
	if planet_body == null or planetary_cfg == null or quad_tex == null or body_shader == null:
		return
	if planetary_cfg.trojan_cluster_probability <= 0.0:
		return
	if CosmosHasher.hash_2d_float(planet_seed, 5101, 51) > planetary_cfg.trojan_cluster_probability:
		return

	var base_dir_sign: float = 1.0 if planet_body.angular_velocity >= 0.0 else -1.0
	var min_n: int = maxi(planetary_cfg.trojan_bodies_per_pocket.x, 1)
	var max_n: int = maxi(planetary_cfg.trojan_bodies_per_pocket.y, min_n)

	# Crear L4 (+60 deg) y L5 (-60 deg) respecto al planeta
	for pocket_idx: int in range(2):
		var pocket_angle: float = (PI / 3.0) * (1.0 if pocket_idx == 0 else -1.0) * base_dir_sign
		var count: int = min_n + int(CosmosHasher.hash_2d_float(planet_seed, 5110 + pocket_idx, 52) * float(max_n - min_n + 1))
		count = clampi(count, min_n, max_n)

		for j: int in range(count):
			var t_seed: int = planet_seed + (pocket_idx * 313) + (j * 97)
			var theta_off: float = (CosmosHasher.hash_2d_float(t_seed, 5120, 53) - 0.5) * deg_to_rad(11.0)
			var radial_mult: float = 1.0 + ((CosmosHasher.hash_2d_float(t_seed, 5121, 54) - 0.5) * 0.08)
			var diam: float = lerpf(16.0, 30.0, CosmosHasher.hash_2d_float(t_seed, 5122, 55))
			var t_tilt: float = planet_body.orbit_plane_tilt + ((CosmosHasher.hash_2d_float(t_seed, 5123, 56) - 0.5) * 0.05)
			var t_squash: float = clampf(planet_body.orbit_plane_squash + ((CosmosHasher.hash_2d_float(t_seed, 5124, 57) - 0.5) * 0.04), 0.72, 0.96)

			var spr: Sprite2D = _create_minor_sphere_sprite(
				"Trojan_%s_%d_%d" % [String(planet_body.name), pocket_idx, j],
				diam,
				t_seed,
				star_color,
				body_shader,
				quad_tex,
				moon_archetypes,
				false
			)
			add_child(spr)
			_trojans.append({
				"node": spr,
				"mat": spr.material as ShaderMaterial,
				"a": planet_body.orbit_radius * radial_mult,
				"init_theta": fposmod(planet_body.initial_theta + pocket_angle + theta_off, TAU),
				"ang_vel": planet_body.angular_velocity,
				"ecc": planet_body.orbit_eccentricity,
				"peri": planet_body.orbit_periapsis_angle,
				"tilt": t_tilt,
				"squash": t_squash,
				"base_scale": Vector2.ONE * (diam * 0.5),
				"depth_amp": maxf(planetary_cfg.planet_depth_scale_amp, 0.08),
			})

func register_shepherd_moonlets_for_planet(
	planet_body: CosmosOrbitalBody2D,
	planet_seed: int,
	ring_outer_px: float,
	ring_roll_rad: float,
	ring_tilt_x_rad: float,
	planetary_cfg: CosmosPlanetarySystemConfig,
	star_color: Color,
	body_shader: Shader,
	quad_tex: Texture2D,
	moon_archetypes: Array[CosmosPlanetArchetype]
) -> void:
	if planet_body == null or planetary_cfg == null or ring_outer_px <= 1.0 or quad_tex == null or body_shader == null:
		return
	if planetary_cfg.shepherd_moonlet_probability <= 0.0:
		return
	if CosmosHasher.hash_2d_float(planet_seed, 5201, 61) > planetary_cfg.shepherd_moonlet_probability:
		return

	var ring_squash: float = clampf(cos(ring_tilt_x_rad), 0.20, 0.60)
	var count: int = 2 if CosmosHasher.hash_2d_float(planet_seed, 5202, 62) > 0.45 else 1
	for s_idx: int in range(count):
		var s_seed: int = planet_seed + 6100 + (s_idx * 271)
		var ring_mult: float = 1.03 if s_idx == 0 else 0.72
		var s_radius: float = ring_outer_px * ring_mult
		var s_diam: float = lerpf(11.0, 17.5, CosmosHasher.hash_2d_float(s_seed, 5210, 63))
		var s_ang_vel: float = absf(planet_body.angular_velocity) * (14.5 if s_idx == 0 else 21.0)
		s_ang_vel = maxf(s_ang_vel, 0.11)
		if CosmosHasher.hash_2d_float(s_seed, 5211, 64) < 0.2:
			s_ang_vel = -s_ang_vel
		var s_init: float = CosmosHasher.hash_2d_float(s_seed, 5212, 65) * TAU

		var spr: Sprite2D = _create_minor_sphere_sprite(
			"Shepherd_" + str(s_idx + 1),
			s_diam,
			s_seed,
			star_color,
			body_shader,
			quad_tex,
			moon_archetypes,
			true
		)
		# Hijo directo del planeta para compartir transform + pases -1/+1 alrededor del anillo
		planet_body.add_child(spr)
		_shepherds.append({
			"node": spr,
			"mat": spr.material as ShaderMaterial,
			"host": planet_body,
			"a": s_radius,
			"init_theta": s_init,
			"ang_vel": s_ang_vel,
			"ecc": 0.03,
			"peri": s_init,
			"tilt": ring_roll_rad,
			"squash": ring_squash,
			"base_scale": Vector2.ONE * (s_diam * 0.5),
			"depth_amp": 0.22,
		})

func _create_minor_sphere_sprite(
	p_name: String,
	diam: float,
	seed_val: int,
	star_color: Color,
	body_shader: Shader,
	quad_tex: Texture2D,
	moon_archetypes: Array[CosmosPlanetArchetype],
	is_icy: bool
) -> Sprite2D:
	var spr: Sprite2D = Sprite2D.new()
	spr.name = p_name
	spr.centered = true
	spr.texture = quad_tex
	spr.scale = Vector2.ONE * (diam * 0.5)

	var arch: CosmosPlanetArchetype = null
	if not moon_archetypes.is_empty():
		var idx: int = int(CosmosHasher.hash_2d_float(seed_val, 5301, 71) * float(moon_archetypes.size()))
		arch = moon_archetypes[clampi(idx, 0, moon_archetypes.size() - 1)]

	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = body_shader
	if arch != null:
		mat.set_shader_parameter("use_spherical_projection", true)
		mat.set_shader_parameter("surface_albedo_tex", arch.albedo_texture)
		mat.set_shader_parameter("surface_maps_tex", arch.surface_maps_texture)
		mat.set_shader_parameter("bump_strength", arch.bump_strength)
		mat.set_shader_parameter("lon_phase", CosmosHasher.hash_2d_float(seed_val, 5302, 72) * TAU)
	mat.set_shader_parameter("planet_radius", 0.485)
	mat.set_shader_parameter("edge_crop_margin", 0.012)
	mat.set_shader_parameter("rim_edge_feather", 0.008)
	mat.set_shader_parameter("axial_spin_speed", (CosmosHasher.hash_2d_float(seed_val, 5303, 73) - 0.5) * 0.04)
	mat.set_shader_parameter("night_ambient", 0.24 if is_icy else 0.18)
	mat.set_shader_parameter("day_exposure_boost", 1.38 if is_icy else 1.24)
	mat.set_shader_parameter("atmosphere_intensity", 0.45 if is_icy else 0.15)
	mat.set_shader_parameter("atmosphere_color", Color(0.72, 0.92, 1.0, 1.0) if is_icy else Color(0.75, 0.70, 0.65, 1.0))
	mat.set_shader_parameter("star_light_color", star_color)
	mat.set_shader_parameter("star_light_tint_strength", 0.42)
	spr.material = mat
	return spr

func update_minor_bodies(global_time: float) -> void:
	for entry: Dictionary in _trojans:
		var spr: Sprite2D = entry["node"] as Sprite2D
		if not is_instance_valid(spr):
			continue
		var state: Vector3 = CosmosKeplerOrbitMath.calculate_orbit_state_3d(
			float(entry["a"]),
			float(entry["init_theta"]),
			float(entry["ang_vel"]),
			global_time,
			float(entry["ecc"]),
			float(entry["peri"]),
			float(entry["tilt"]),
			float(entry["squash"])
		)
		var pos_2d: Vector2 = Vector2(state.x, state.y)
		spr.position = pos_2d
		var z_val: float = state.z
		spr.scale = (entry["base_scale"] as Vector2) * maxf(1.0 + (z_val * float(entry["depth_amp"])), 0.45)
		spr.z_index = -1 if z_val < 0.0 else 1
		var mat: ShaderMaterial = entry["mat"] as ShaderMaterial
		if mat != null:
			var l_dir: Vector2 = -pos_2d.normalized() if pos_2d.length_squared() > 1.0 else Vector2(-1.0, 0.0)
			mat.set_shader_parameter("light_direction", l_dir)
			mat.set_shader_parameter("light_depth", clampf(0.30 - (z_val * 0.22), 0.08, 0.56))

	for entry: Dictionary in _shepherds:
		var spr: Sprite2D = entry["node"] as Sprite2D
		var host: CosmosOrbitalBody2D = entry["host"] as CosmosOrbitalBody2D
		if not is_instance_valid(spr) or not is_instance_valid(host):
			continue
		var state: Vector3 = CosmosKeplerOrbitMath.calculate_orbit_state_3d(
			float(entry["a"]),
			float(entry["init_theta"]),
			float(entry["ang_vel"]),
			global_time,
			float(entry["ecc"]),
			float(entry["peri"]),
			float(entry["tilt"]),
			float(entry["squash"])
		)
		var rel_2d: Vector2 = Vector2(state.x, state.y)
		spr.position = rel_2d
		var z_val: float = state.z
		spr.scale = (entry["base_scale"] as Vector2) * maxf(1.0 + (z_val * float(entry["depth_amp"])), 0.40)
		spr.z_index = -1 if z_val < 0.0 else 1
		var mat: ShaderMaterial = entry["mat"] as ShaderMaterial
		if mat != null:
			var world_in_sys: Vector2 = host.position + (rel_2d * host.scale)
			var l_dir: Vector2 = -world_in_sys.normalized() if world_in_sys.length_squared() > 1.0 else Vector2(-1.0, 0.0)
			mat.set_shader_parameter("light_direction", l_dir)
			mat.set_shader_parameter("light_depth", clampf(0.30 - (host.current_depth_z * 0.14 + z_val * 0.24), 0.06, 0.62))

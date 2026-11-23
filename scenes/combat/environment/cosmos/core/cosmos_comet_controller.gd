class_name CosmosCometController2D
extends Node2D

## CosmosCometController2D.gd
## Orquesta cometas elípticos inclinados de forma puramente analítica y sin asignaciones en runtime.
## Cada cometa posee cola iónica/de polvo reactiva a su proximidad solar, escala perspectiva,
## z_index dinámico (-1/+1) y una estela orbital curva 3D.

const COMET_TAIL_SHADER: Shader = preload("res://scenes/combat/environment/cosmos/shaders/comet_tail.gdshader")
const CosmosOrbitalTrailScript = preload("res://scenes/combat/environment/cosmos/core/cosmos_orbital_trail_2d.gd")

var _comets: Array[Dictionary] = []
var _trails_visible: bool = true

func get_comet_entries() -> Array[Dictionary]:
	return _comets

func clear_comets() -> void:
	for entry: Dictionary in _comets:
		var root_node: Node2D = entry.get("root", null) as Node2D
		if is_instance_valid(root_node):
			root_node.queue_free()
		var trail: CosmosOrbitalTrail2D = entry.get("trail", null) as CosmosOrbitalTrail2D
		if is_instance_valid(trail):
			trail.queue_free()
	_comets.clear()

func build_comets(
	system_seed: int,
	planetary_cfg: CosmosPlanetarySystemConfig,
	star_exclusion_radius: float,
	light_field_radius: float,
	base_angular_vel: float,
	orbit_min_ref: float,
	star_color: Color,
	quad_tex: Texture2D,
	ecliptic_tilt: float
) -> void:
	clear_comets()
	if planetary_cfg == null or COMET_TAIL_SHADER == null or quad_tex == null:
		return
	if planetary_cfg.max_comets_per_system <= 0 or planetary_cfg.comet_spawn_probability <= 0.0:
		return

	var spawn_roll: float = CosmosHasher.hash_2d_float(system_seed, 3131, 31)
	if spawn_roll > planetary_cfg.comet_spawn_probability:
		return

	var count: int = 1
	if planetary_cfg.max_comets_per_system > 1 and CosmosHasher.hash_2d_float(system_seed, 3132, 32) > 0.45:
		count = clampi(2, 1, planetary_cfg.max_comets_per_system)

	var max_safe_ap: float = maxf(light_field_radius * 0.90, star_exclusion_radius + 1100.0)
	var min_safe_pe: float = star_exclusion_radius + 200.0

	for c_idx: int in range(count):
		var c_seed: int = system_seed + ((c_idx + 1) * 4177)
		var ecc_t: float = CosmosHasher.hash_2d_float(c_seed, 3201, 11)
		var ecc: float = clampf(lerpf(planetary_cfg.comet_eccentricity_range.x, planetary_cfg.comet_eccentricity_range.y, ecc_t), 0.25, 0.72)

		var target_pe: float = min_safe_pe + CosmosHasher.hash_2d_float(c_seed, 3202, 12) * 260.0
		var target_ap: float = max_safe_ap * lerpf(0.68, 0.92, CosmosHasher.hash_2d_float(c_seed, 3203, 13))
		var semi_major_a: float = clampf((target_pe + target_ap) * 0.5, min_safe_pe / maxf(1.0 - ecc, 0.2), max_safe_ap / (1.0 + ecc))
		if semi_major_a * (1.0 - ecc) < min_safe_pe:
			semi_major_a = min_safe_pe / maxf(1.0 - ecc, 0.2)

		var squash_t: float = CosmosHasher.hash_2d_float(c_seed, 3204, 14)
		var squash: float = clampf(lerpf(planetary_cfg.comet_squash_range.x, planetary_cfg.comet_squash_range.y, squash_t), 0.30, 0.92)
		var plane_tilt: float = ecliptic_tilt + ((CosmosHasher.hash_2d_float(c_seed, 3205, 15) - 0.5) * 1.45)
		var periapsis_ang: float = CosmosHasher.hash_2d_float(c_seed, 3206, 16) * TAU
		var init_theta: float = CosmosHasher.hash_2d_float(c_seed, 3207, 17) * TAU
		var dir_sign: float = 1.0 if CosmosHasher.hash_2d_float(c_seed, 3208, 18) > 0.45 else -1.0
		var ang_vel: float = CosmosKeplerOrbitMath.calculate_keplerian_angular_velocity(base_angular_vel * 1.35, orbit_min_ref, semi_major_a, dir_sign)

		var min_dist: float = semi_major_a * (1.0 - ecc) * squash
		var max_dist: float = semi_major_a * (1.0 + ecc)

		var ion_col: Color = Color(0.44, 0.88, 1.0, 1.0).lerp(star_color, 0.28)
		var dust_col: Color = Color(1.0, 0.80, 0.55, 1.0).lerp(star_color, 0.35)

		# Estela orbital curva antes del cuerpo del cometa en árbol para que no tape la coma
		var trail: CosmosOrbitalTrail2D = null
		if planetary_cfg.enable_orbital_trails:
			trail = CosmosOrbitalTrailScript.new()
			trail.name = "CometTrail_" + str(c_idx + 1)
			trail.visible = _trails_visible
			trail.setup_orbit(
				semi_major_a,
				init_theta,
				ang_vel,
				ecc,
				periapsis_ang,
				plane_tilt,
				squash,
				0.72,
				3.4,
				Color(ion_col.r, ion_col.g, ion_col.b, planetary_cfg.trail_base_opacity * 0.85),
				Color(dust_col.r, dust_col.g, dust_col.b, 0.0),
				20,
				true
			)
			add_child(trail)

		var root_node: Node2D = Node2D.new()
		root_node.name = "Comet_" + str(c_idx + 1)
		add_child(root_node)

		var c_sprite: Sprite2D = Sprite2D.new()
		c_sprite.name = "CometVisual"
		c_sprite.centered = false
		c_sprite.offset = Vector2(-0.36, -1.0)
		c_sprite.texture = quad_tex
		var base_scale_x: float = lerpf(155.0, 235.0, CosmosHasher.hash_2d_float(c_seed, 3209, 19))
		var base_scale_y: float = base_scale_x * 0.46
		c_sprite.scale = Vector2(base_scale_x, base_scale_y)

		var c_mat: ShaderMaterial = ShaderMaterial.new()
		c_mat.shader = COMET_TAIL_SHADER
		c_mat.set_shader_parameter("ion_color", ion_col)
		c_mat.set_shader_parameter("dust_color", dust_col)
		c_sprite.material = c_mat
		root_node.add_child(c_sprite)

		_comets.append({
			"root": root_node,
			"sprite": c_sprite,
			"mat": c_mat,
			"trail": trail,
			"a": semi_major_a,
			"init_theta": init_theta,
			"ang_vel": ang_vel,
			"ecc": ecc,
			"peri": periapsis_ang,
			"tilt": plane_tilt,
			"squash": squash,
			"depth_amp": planetary_cfg.comet_depth_scale_amp,
			"base_sx": base_scale_x,
			"base_sy": base_scale_y,
			"min_dist": min_dist,
			"max_dist": maxf(max_dist, min_dist + 1.0),
		})

func set_trails_visible(p_visible: bool) -> void:
	_trails_visible = p_visible
	for entry: Dictionary in _comets:
		var trail: CosmosOrbitalTrail2D = entry.get("trail", null) as CosmosOrbitalTrail2D
		if is_instance_valid(trail):
			trail.visible = p_visible

func update_comets(global_time: float) -> void:
	for entry: Dictionary in _comets:
		var root_node: Node2D = entry["root"] as Node2D
		if not is_instance_valid(root_node):
			continue
		var a: float = float(entry["a"])
		var init_theta: float = float(entry["init_theta"])
		var ang_vel: float = float(entry["ang_vel"])
		var ecc: float = float(entry["ecc"])
		var peri: float = float(entry["peri"])
		var tilt: float = float(entry["tilt"])
		var squash: float = float(entry["squash"])

		var state: Vector3 = CosmosKeplerOrbitMath.calculate_orbit_state_3d(
			a, init_theta, ang_vel, global_time, ecc, peri, tilt, squash
		)
		var pos_2d: Vector2 = Vector2(state.x, state.y)
		var depth_z: float = state.z
		root_node.position = pos_2d

		var depth_amp: float = float(entry["depth_amp"])
		var p_scale: float = maxf(1.0 + (depth_z * depth_amp), 0.45)
		root_node.scale = Vector2.ONE * p_scale
		root_node.z_index = -1 if depth_z < 0.0 else 1

		var dist: float = pos_2d.length()
		var outward_dir: Vector2 = pos_2d / dist if dist > 1.0 else Vector2.RIGHT
		var min_d: float = float(entry["min_dist"])
		var max_d: float = float(entry["max_dist"])
		var solar_prox: float = clampf(1.0 - ((dist - min_d) / maxf(max_d - min_d, 1.0)), 0.0, 1.0)
		solar_prox = pow(solar_prox, 0.75)

		var vel: Vector2 = CosmosKeplerOrbitMath.calculate_orbit_velocity_2d(
			a, init_theta, ang_vel, global_time, ecc, peri, tilt, squash
		)
		var tail_dir: Vector2 = outward_dir
		var ion_deflect: float = 0.0
		if vel.length_squared() > 0.0001:
			tail_dir = -vel.normalized()
			var sin_a: float = (tail_dir.x * outward_dir.y) - (tail_dir.y * outward_dir.x)
			var cos_a: float = tail_dir.dot(outward_dir)
			var rel_solar_ang: float = atan2(sin_a, cos_a)
			ion_deflect = clampf(rel_solar_ang * 0.22, -0.34, 0.34)

		var c_sprite: Sprite2D = entry["sprite"] as Sprite2D
		if is_instance_valid(c_sprite):
			c_sprite.rotation = tail_dir.angle()
			var len_mult: float = lerpf(0.70, 1.45, solar_prox)
			c_sprite.scale = Vector2(float(entry["base_sx"]) * len_mult, float(entry["base_sy"]))
			c_sprite.modulate.a = lerpf(0.62, 1.0, (depth_z * 0.5) + 0.5)

		var c_mat: ShaderMaterial = entry["mat"] as ShaderMaterial
		if c_mat != null:
			c_mat.set_shader_parameter("solar_proximity", solar_prox)
			c_mat.set_shader_parameter("dust_curve_angle", ion_deflect)
			c_mat.set_shader_parameter("global_time", global_time)

		var trail: CosmosOrbitalTrail2D = entry.get("trail", null) as CosmosOrbitalTrail2D
		if is_instance_valid(trail) and trail.visible:
			trail.update_trail(global_time)

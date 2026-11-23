class_name TestKepler3DOrbits
extends BaseTestSuite

## Suite unitaria y de integración para Cosmos Engine v3.1 (Cinemática Orbital 2.5D/3D).
## Valida paridad circular legacy, 2.ª Ley de Kepler, convención Z, reversibilidad sin deriva,
## presupuesto z_index, holgura en 15 semillas reales y sincronización de CosmosOrbitSlot.

const PROFILE_PATH: String = "res://scenes/combat/environment/cosmos/resources/data/default_celestial_system.tres"

func _ready() -> void:
	super._ready()
	_test_legacy_circular_parity()
	_test_kepler_second_law_speed()
	_test_3d_depth_z_convention()
	_test_analytical_reversibility_and_15_seeds()
	_test_comet_velocity_alignment()
	pass_suite("TestKepler3DOrbits completado (paridad, Kepler 2.ª Ley, Z-order, 15 semillas, cometas y slots).")

func _test_legacy_circular_parity() -> void:
	var r: float = 1450.0
	var th: float = 0.75
	var w: float = 0.08
	var times: Array[float] = [0.0, 12.5, 400.0, 10000.0]
	for t: float in times:
		var pos: Vector2 = CosmosKeplerOrbitMath.calculate_orbit_position(r, th, w, t)
		var expected: Vector2 = Vector2(r * cos(th + w * t), r * sin(th + w * t))
		var err: float = pos.distance_to(expected)
		assert_true(err < 0.0001, "Paridad circular legacy rota en t=%.1f (err=%.6f)." % [t, err])

func _test_kepler_second_law_speed() -> void:
	var a: float = 1200.0
	var e: float = 0.45
	var w: float = 0.1
	var v_pe: Vector2 = CosmosKeplerOrbitMath.calculate_orbit_velocity_2d(a, 0.0, w, 0.0, e, 0.0, 0.0, 1.0)
	var v_ap: Vector2 = CosmosKeplerOrbitMath.calculate_orbit_velocity_2d(a, PI, w, 0.0, e, 0.0, 0.0, 1.0)
	var speed_pe: float = v_pe.length()
	var speed_ap: float = v_ap.length()
	var expected_ratio: float = (1.0 + e) / (1.0 - e)
	var actual_ratio: float = speed_pe / maxf(speed_ap, 0.0001)
	assert_true(speed_pe > speed_ap * 2.0, "La rapidez en periapsis debe superar ampliamente la de apoapsis.")
	assert_true(absf(actual_ratio - expected_ratio) < 0.01, "Razón periapsis/apoapsis debe respetar 2.ª Ley de Kepler (esp=%.3f, obt=%.3f)." % [expected_ratio, actual_ratio])

func _test_3d_depth_z_convention() -> void:
	var s_front: Vector3 = CosmosKeplerOrbitMath.calculate_orbit_state_3d(500.0, PI * 0.5, 0.0, 0.0, 0.0, 0.0, 0.0, 0.35)
	assert_true(s_front.z > 0.5, "En +Y (lado inferior/RingFront), depth_z debe ser positivo (obt=%.3f)." % s_front.z)
	var s_back: Vector3 = CosmosKeplerOrbitMath.calculate_orbit_state_3d(500.0, PI * 1.5, 0.0, 0.0, 0.0, 0.0, 0.0, 0.35)
	assert_true(s_back.z < -0.5, "En -Y (lado superior/RingBack), depth_z debe ser negativo (obt=%.3f)." % s_back.z)
	var s_flat: Vector3 = CosmosKeplerOrbitMath.calculate_orbit_state_3d(500.0, PI * 0.5, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0)
	assert_true(is_equal_approx(s_flat.z, 0.0), "Con plane_squash = 1.0, depth_z debe ser 0.0.")

func _test_analytical_reversibility_and_15_seeds() -> void:
	var profile: CosmosCelestialSystemProfile = load(PROFILE_PATH) as CosmosCelestialSystemProfile
	assert_true(profile != null, "Debe cargar default_celestial_system.tres.")

	var sys: CosmosSolarSystem2D = CosmosSolarSystem2D.new()
	sys.name = "TestKepler3DSystem"
	sys.system_profile = profile
	add_child(sys)

	var half_safe: float = (profile.cell_size * 0.5) - profile.cell_boundary_padding
	var saw_z_neg: bool = false
	var saw_z_pos: bool = false
	var saw_scale_mod: bool = false
	var seen_archetypes: Dictionary = {}

	var seeds: Array[int] = [101, 202, 303, 404, 505, 606, 707, 808, 909, 1010, 1111, 1212, 1313, 1414, 1515]
	for s_idx: int in range(seeds.size()):
		var seed_val: int = seeds[s_idx]
		sys.build_system(seed_val)
		seen_archetypes[sys.system_orbital_archetype] = true
		assert_true(sys.planets.size() >= 3, "Semilla %d debe generar >= 3 planetas." % seed_val)

		sys.update_astronomical_state(0.0)
		var init_pos: Array[Vector2] = []
		var init_scale: Array[Vector2] = []
		for p: CosmosOrbitalBody2D in sys.planets:
			init_pos.append(p.position)
			init_scale.append(p.scale)
			assert_true(p.z_index == 0, "Todo planet_body.z_index debe permanecer en 0.")

			for ch: CosmosOrbitalBody2D in p.get_orbital_children():
				var is_valid_child: bool = ch.name.begins_with("Moon_") or ch.name.begins_with("Station_")
				assert_true(is_valid_child, "planet_body.get_orbital_children() solo debe contener lunas/estaciones (hallado: %s)." % ch.name)

		# Reversibilidad exacta tras salto cósmico t = 100000 -> 0
		if s_idx == 0:
			sys.update_astronomical_state(100000.0)
			sys.update_astronomical_state(0.0)
			for i: int in range(sys.planets.size()):
				var pos_err: float = sys.planets[i].position.distance_to(init_pos[i])
				var sc_err: float = sys.planets[i].scale.distance_to(init_scale[i])
				assert_true(pos_err < 0.01, "Reversibilidad de posición rota tras t=100000 (err=%.5f)." % pos_err)
				assert_true(sc_err < 0.0001, "Reversibilidad de escala rota tras t=100000 (err=%.6f)." % sc_err)

		# Estrellado seguro de exclusión vs 32 fases orbitales
		var star_vis_cfg: CosmosStarVisualConfig = sys.active_archetype.get_effective_visual_config() if sys.active_archetype != null else profile.get_effective_star_visual_config()
		var min_star_safe: float = star_vis_cfg.star_core_radius * clampf(star_vis_cfg.corona_size_multiplier, 0.8, 1.5) * 0.55

		for step: int in range(32):
			var sample_t: float = float(step) * 9.5
			sys.update_astronomical_state(sample_t)
			for p: CosmosOrbitalBody2D in sys.planets:
				var p_dist: float = p.position.length()
				var p_vis_r: float = float(p.get_meta(&"visual_radius", 120.0)) * p.scale.x
				var ring_r: float = float(p.get_meta(&"ring_outer_radius", 0.0)) * p.scale.x
				var body_reach: float = maxf(p_vis_r, ring_r)
				assert_true(p_dist - body_reach > min_star_safe + 120.0, "Semilla %d invade estrella en t=%.1f (gap=%.1f)." % [seed_val, sample_t, p_dist - body_reach - min_star_safe])
				assert_true(p_dist + body_reach <= half_safe, "Semilla %d excede half_safe (dist=%.1f > %.1f)." % [seed_val, p_dist + body_reach, half_safe])
				assert_true(p.z_index == 0, "planet_body.z_index nunca debe cambiar de 0.")

				for sub: CosmosOrbitalBody2D in p.get_orbital_children():
					if sub.z_index == -1:
						saw_z_neg = true
					elif sub.z_index == 1:
						saw_z_pos = true
					if absf(sub.scale.x - sub.base_visual_scale.x) > 0.04:
						saw_scale_mod = true

		# Sincronización CosmosOrbitSlot destructible
		var d_slot: CosmosOrbitSlot = CosmosOrbitSlot.new(
			CosmosOrbitSlot.SlotCenterType.STAR,
			Vector2i.ZERO,
			Vector2.ZERO,
			sys.destructible_orbit_radius,
			sys.destructible_angular_velocity,
			sys.destructible_initial_theta,
			sys.star_body,
			&"TestDestructible",
			Vector2(0.2, 0.2)
		)
		d_slot.configure_3d_orbit(
			sys.destructible_eccentricity,
			sys.destructible_periapsis_angle,
			sys.destructible_plane_tilt,
			sys.destructible_plane_squash
		)
		for check_t: float in [0.0, 50.0, 200.0]:
			var slot_p: Vector2 = d_slot.calculate_layer_position(check_t)
			var direct_p: Vector2 = CosmosKeplerOrbitMath.calculate_orbit_position(
				sys.destructible_orbit_radius,
				sys.destructible_initial_theta,
				sys.destructible_angular_velocity,
				check_t,
				sys.destructible_eccentricity,
				sys.destructible_periapsis_angle,
				sys.destructible_plane_tilt,
				sys.destructible_plane_squash
			)
			assert_true(slot_p.distance_to(direct_p) < 0.01, "Slot destructible debe coincidir exactamente con órbita 3D.")

	assert_true(saw_z_neg and saw_z_pos, "Satélites deben alternar realmente z_index = -1 (atrás) y +1 (adelante).")
	assert_true(saw_scale_mod, "Satélites deben modular su escala por perspectiva según depth_z.")
	assert_true(seen_archetypes.size() >= 2, "Múltiples semillas deben ejercer variedad de arquetipos orbitales.")

	# Validar toggle de guías orbitales sin contaminar jerarquía
	assert_true(not sys.is_orbit_guides_visible(), "Las guías orbitales deben iniciar desactivadas por defecto.")
	sys.set_orbit_guides_visible(true)
	assert_true(sys.is_orbit_guides_visible(), "set_orbit_guides_visible(true) debe activar el estado del overlay.")
	sys.update_astronomical_state(12.0)
	for p: CosmosOrbitalBody2D in sys.planets:
		for ch: CosmosOrbitalBody2D in p.get_orbital_children():
			assert_true(ch.name.begins_with("Moon_") or ch.name.begins_with("Station_"), "Guías visibles no deben contaminar get_orbital_children().")
	sys.set_orbit_guides_visible(false)
	assert_true(not sys.is_orbit_guides_visible(), "set_orbit_guides_visible(false) debe restaurar el estado apagado.")

	sys.queue_free()


func _test_comet_velocity_alignment() -> void:
	var profile: CosmosCelestialSystemProfile = load(PROFILE_PATH) as CosmosCelestialSystemProfile
	var sys := CosmosSolarSystem2D.new()
	sys.name = "TestCometAlignmentSys"
	sys.system_profile = profile
	add_child(sys)

	var verified_comets: int = 0
	for s_i: int in range(10):
		sys.build_system(2020 + s_i * 137)
		var comets: Array[Dictionary] = sys.get_comet_entries()
		if comets.is_empty():
			continue
		for sample_t: float in [0.0, 6.0, 18.5, 42.0]:
			sys.update_astronomical_state(sample_t)
			for ce: Dictionary in comets:
				var c_spr: Sprite2D = ce["sprite"] as Sprite2D
				var vel: Vector2 = CosmosKeplerOrbitMath.calculate_orbit_velocity_2d(
					float(ce["a"]),
					float(ce["init_theta"]),
					float(ce["ang_vel"]),
					sample_t,
					float(ce["ecc"]),
					float(ce["peri"]),
					float(ce["tilt"]),
					float(ce["squash"])
				)
				if vel.length_squared() > 0.0001 and is_instance_valid(c_spr):
					var expected_rot: float = (-vel).angle()
					var err: float = absf(wrapf(c_spr.rotation - expected_rot, -PI, PI))
					assert_true(err < 0.05, "Cometa debe alinear su eje con -vel.normalized() (err=%.4f)." % err)
					verified_comets += 1

	assert_true(verified_comets >= 4, "Debe validar alineación tangencial en múltiples fases de cometas reales.")
	sys.queue_free()

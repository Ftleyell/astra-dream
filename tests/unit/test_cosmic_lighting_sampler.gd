class_name TestCosmicLightingSampler
extends BaseTestSuite

const CosmosRootScene = preload("res://scenes/combat/environment/cosmos/scenes/cosmos_root.tscn")
const CosmosHostControllerScript = preload("res://scenes/combat/environment/cosmos/core/cosmos_host_controller.gd")
const CosmicLightingSampleScript = preload("res://scenes/combat/environment/cosmos/core/cosmic_lighting_sample.gd")
const CosmicPoiConfigScript = preload("res://scenes/combat/environment/cosmos/resources/cosmic_poi_config.gd")
const PlanarRigScript = preload("res://sandbox/pilot_rig_lab/proto/planar_combat_rig.gd")
const RingCtrlScript = preload("res://sandbox/pilot_rig_lab/guns_lab/orbital_weapon_ring_controller.gd")
const OrbitalConfigScript = preload("res://sandbox/pilot_rig_lab/data/pilot_orbital_weapon_config.gd")

const PROFILE_PATH: String = "res://sandbox/pilot_rig_lab/pilots/valentina_v2/valentina_v2_profile.tres"
const STYLE_PATH: String = "res://sandbox/pilot_rig_lab/data/styles/02_valentina_razor_sharp.tres"
const BLUE_GIANT_ARCH_PATH: String = "res://scenes/combat/environment/cosmos/resources/data/star_archetypes/blue_giant.tres"

var _scene_root: Node2D = null
var _cosmos_root: CosmosRootNode = null
var _host: CosmosHostControllerScript = null
var _camera: Camera2D = null
var _active_sys: CosmosSolarSystem2D = null


func _ready() -> void:
	super._ready()
	_run_suite()


func _run_suite() -> void:
	_setup_cosmos()
	await get_tree().process_frame
	_test_star_direction_2d_and_3d()
	_test_biome_shadow_tint_update()
	_test_eclipse_and_dayside()
	_test_rig_and_orbital_ring_application()
	_test_zero_allocation_sample_reuse()
	_teardown()
	pass_suite("TestCosmicLightingSampler: 5/5 pruebas superadas (Sol, Bioma, Eclipse, Rig/Armas 3D y Zero-Alloc).")


func _setup_cosmos() -> void:
	_scene_root = Node2D.new()
	add_child(_scene_root)

	_camera = Camera2D.new()
	_camera.position = Vector2.ZERO
	_scene_root.add_child(_camera)

	_cosmos_root = CosmosRootScene.instantiate() as CosmosRootNode
	_scene_root.add_child(_cosmos_root)

	_host = CosmosHostControllerScript.new()
	_host.cosmos_root = _cosmos_root
	_host.default_region_id = &"perseus_rift"
	_scene_root.add_child(_host)

	var poi := CosmicPoiConfigScript.new()
	poi.poi_type = CosmicPoiConfigScript.PoiType.SOLAR_SYSTEM
	poi.planet_count = 3
	poi.seed_override = 12345
	poi.custom_label = &"RIGEL_TEST"
	poi.star_archetype = load(BLUE_GIANT_ARCH_PATH) as CosmosStarArchetype
	_host.inject_poi_at_virtual_coords(Vector2i(0, 0), poi)

	_cosmos_root.camera = _camera
	_cosmos_root.bind_camera_to_streamers()
	if _cosmos_root.solar_streamer != null:
		_cosmos_root.solar_streamer._update_streaming_and_orbits(0.0)

	var systems: Dictionary = _host.get_active_solar_systems()
	assert_true(not systems.is_empty(), "Debe existir al menos un sistema solar activo en el test.")
	if systems.has(Vector2i(0, 0)):
		_active_sys = systems[Vector2i(0, 0)] as CosmosSolarSystem2D
	else:
		_active_sys = systems.values()[0] as CosmosSolarSystem2D
	assert_true(_active_sys != null and _active_sys.star_body != null, "El sistema solar activo debe tener star_body.")
	assert_true(not _active_sys.planets.is_empty(), "El sistema solar activo debe tener planetas para probar eclipse.")


func _get_star_world_pos(sys: CosmosSolarSystem2D) -> Vector2:
	var layer_pos: Vector2 = sys.position + sys.star_body.position
	var p_layer: Parallax2D = _cosmos_root.solar_streamer.parallax_layer if _cosmos_root.solar_streamer != null else null
	var s_scale: Vector2 = p_layer.scroll_scale if p_layer != null else Vector2.ONE
	var s_offset: Vector2 = p_layer.scroll_offset if p_layer != null else Vector2.ZERO
	if s_scale.is_equal_approx(Vector2.ONE):
		return layer_pos + s_offset
	return (_camera.global_position * (Vector2.ONE - s_scale)) + layer_pos + s_offset


func _test_star_direction_2d_and_3d() -> void:
	var star_world: Vector2 = _get_star_world_pos(_active_sys)
	var probe_pos: Vector2 = star_world + Vector2(600.0, 400.0)
	var expected_2d: Vector2 = (star_world - probe_pos).normalized()

	var sample: CosmicLightingSampleScript = _host.sample_lighting_at(probe_pos)
	assert_true(sample.has_active_star, "La muestra debe detectar la estrella dominante activa.")
	assert_true(sample.light_dir_2d.distance_to(expected_2d) < 0.01, "light_dir_2d debe apuntar desde probe_pos hacia la estrella.")
	assert_true(signf(sample.light_dir_3d.y) == signf(-sample.light_dir_2d.y), "light_dir_3d.y debe invertir signo respecto a light_dir_2d.y.")
	assert_true(sample.star_proximity > 0.2, "Cerca de la estrella star_proximity debe ser significativa.")


func _test_biome_shadow_tint_update() -> void:
	_host.change_region(&"perseus_rift", 0.0)
	var sample_perseus: CosmicLightingSampleScript = _host.sample_lighting_at(Vector2.ZERO)
	var perseus_shadow: Color = sample_perseus.shadow_tint

	_host.change_region(&"hyperion_forge", 0.0)
	var sample_hyperion: CosmicLightingSampleScript = _host.sample_lighting_at(Vector2.ZERO)
	var hyperion_shadow: Color = sample_hyperion.shadow_tint

	assert_true(not perseus_shadow.is_equal_approx(hyperion_shadow), "El cambio de bioma debe actualizar shadow_tint.")
	assert_true(hyperion_shadow.r > perseus_shadow.r, "Hyperion Forge debe aportar mayor componente cálida roja en sombra que Perseus Rift.")
	_host.change_region(&"perseus_rift", 0.0)


func _test_eclipse_and_dayside() -> void:
	var star_world: Vector2 = _get_star_world_pos(_active_sys)
	var planet: CosmosOrbitalBody2D = _active_sys.planets[0]
	var p_rad: float = float(planet.get_meta(&"visual_radius", 130.0))
	var outward: Vector2 = planet.position.normalized()

	var eclipse_pos: Vector2 = star_world + planet.position + outward * (p_rad + 90.0)
	var sample_eclipse: CosmicLightingSampleScript = _host.sample_lighting_at(eclipse_pos)
	assert_true(sample_eclipse.eclipse_factor > 0.85, "Detrás del planeta en el eje star->planet eclipse_factor debe ser > 0.85 (obtenido: %.3f)." % sample_eclipse.eclipse_factor)
	assert_true(sample_eclipse.emissive_boost_mult > 1.2, "En eclipse emissive_boost_mult debe superar 1.2 (obtenido: %.3f)." % sample_eclipse.emissive_boost_mult)

	var day_pos: Vector2 = star_world + planet.position - outward * (p_rad + 120.0)
	var sample_day: CosmicLightingSampleScript = _host.sample_lighting_at(day_pos)
	assert_true(is_zero_approx(sample_day.eclipse_factor), "En la cara diurna del planeta eclipse_factor debe ser 0.0 (obtenido: %.3f)." % sample_day.eclipse_factor)


func _test_rig_and_orbital_ring_application() -> void:
	var profile: PilotRigProfile = ResourceLoader.load(PROFILE_PATH) as PilotRigProfile
	var style: RigStyleProfile = ResourceLoader.load(STYLE_PATH) as RigStyleProfile
	assert_true(profile != null and style != null, "Perfil y estilo de Valentina v2 deben cargar.")

	var orig_boost: float = style.key_light_boost
	var orig_emissive: float = style.emissive_glow_strength

	var rig := PlanarRigScript.new()
	rig.pilot_profile = profile
	rig.enable_base_propulsion_wings = true
	_scene_root.add_child(rig)
	rig.apply_style_profile(style)

	var ring_cfg := OrbitalConfigScript.new()
	ring_cfg.ensure_defaults()
	var ring := RingCtrlScript.new()
	ring.set_config(ring_cfg)
	ring.set_weapon_3d_enabled(true)
	_scene_root.add_child(ring)

	var star_world: Vector2 = _get_star_world_pos(_active_sys)
	var planet: CosmosOrbitalBody2D = _active_sys.planets[0]
	var p_rad: float = float(planet.get_meta(&"visual_radius", 130.0))
	var eclipse_pos: Vector2 = star_world + planet.position + planet.position.normalized() * (p_rad + 90.0)
	var eclipse_sample: CosmicLightingSampleScript = _host.sample_lighting_at(eclipse_pos)

	rig.apply_cosmic_lighting(eclipse_sample, 0.0)
	ring.apply_cosmic_lighting(eclipse_sample)
	ring.step(0.016)

	var applied_dir: Variant = rig.get_shader_param("light_dir_2d", Vector2.ZERO)
	var applied_boost: float = float(rig.get_shader_param("key_light_boost", 0.0))
	var applied_emissive: float = float(rig.get_shader_param("emissive_glow_strength", 0.0))

	assert_true((applied_dir as Vector2).distance_to(eclipse_sample.light_dir_2d) < 0.01, "PlanarCombatRig debe reflejar light_dir_2d de la muestra.")
	assert_true(applied_boost >= eclipse_sample.visibility_floor - 0.001, "key_light_boost debe respetar el piso mínimo de visibilidad.")
	assert_true(applied_boost < orig_boost, "En eclipse key_light_boost debe atenuarse respecto al estilo iluminado.")
	assert_true(applied_emissive > orig_emissive, "En eclipse emissive_glow_strength debe realzarse.")
	assert_true(is_equal_approx(style.key_light_boost, orig_boost), "El recurso .tres RigStyleProfile no debe mutar.")
	assert_true(is_equal_approx(style.emissive_glow_strength, orig_emissive), "emissive_glow_strength del .tres no debe mutar.")

	var slot0_renderer: Node = ring.get_node_or_null("OrbitalWeaponSlot_0/Weapon3DRenderer")
	assert_true(slot0_renderer != null, "OrbitalWeaponSlot_0 debe tener Weapon3DRenderer.")
	var mesh_inst: MeshInstance3D = slot0_renderer.get_node_or_null("WeaponPivot3D/WeaponBody3D/RailLanceMesh3D") as MeshInstance3D
	assert_true(mesh_inst != null, "Debe existir RailLanceMesh3D en el renderer 3D.")
	var mat0: ShaderMaterial = mesh_inst.get_surface_override_material(0) as ShaderMaterial
	assert_true(mat0 != null, "El material Toon 3D de superficie 0 debe existir.")
	var dir_3d: Vector3 = mat0.get_shader_parameter("key_light_dir") as Vector3
	var em_3d: float = float(mat0.get_shader_parameter("emissive_boost"))
	assert_true(dir_3d.distance_to(eclipse_sample.light_dir_3d) < 0.02, "El arma 3D debe mantener key_light_dir cósmico tras ring.step().")
	assert_true(em_3d > 1.2, "El arma 3D debe conservar emissive_boost > 1.2 en eclipse tras ring.step().")


func _test_zero_allocation_sample_reuse() -> void:
	var prealloc := CosmicLightingSampleScript.new()
	var ret: CosmicLightingSampleScript = _host.sample_lighting_at(Vector2(350.0, -220.0), prealloc)
	assert_true(ret == prealloc, "sample_lighting_at debe reutilizar exactamente la instancia out_sample (zero-allocation).")


func _teardown() -> void:
	if _scene_root != null and is_instance_valid(_scene_root):
		_scene_root.queue_free()

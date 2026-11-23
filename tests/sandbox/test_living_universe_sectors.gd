class_name TestLivingUniverseSectors
extends BaseTestSuite

## Suite unitaria y de integración para Cosmos Engine v3.2 (Universo Vivo: Sectores No Estelares).
## Valida configuración data-driven 65%/35%, exclusión mutua SSOT del macro-grid, invariante Vector2i.ZERO,
## los 4 arquetipos (Rogue World, Derelict Armada, Warp Relay, Ion Nursery), reversibilidad analítica,
## pooling sin fugas, override de POIs y continuidad de CosmosOrbitalSlotTracker.

const COSMOS_ROOT_SCENE: PackedScene = preload("res://scenes/combat/environment/cosmos/scenes/cosmos_root.tscn")
const CELESTIAL_PATH: String = "res://scenes/combat/environment/cosmos/resources/data/default_celestial_system.tres"
const ENV_PROFILE_PATH: String = "res://scenes/combat/environment/cosmos/resources/data/default_cosmos_environment.tres"
const LIVING_CFG_PATH: String = "res://scenes/combat/environment/cosmos/resources/data/default_living_universe.tres"


func _ready() -> void:
	super._ready()
	_test_config_and_profiles()
	_test_four_archetypes_reversibility_and_guides()
	_test_macro_grid_streaming_pool_and_slots()
	pass_suite("TestLivingUniverseSectors completado (65/35 SSOT, 4 arquetipos, reversibilidad, pool y slots).")


func _test_config_and_profiles() -> void:
	var celestial: CosmosCelestialSystemProfile = load(CELESTIAL_PATH) as CosmosCelestialSystemProfile
	assert_true(celestial != null, "Debe cargar default_celestial_system.tres.")
	assert_true(is_equal_approx(celestial.spawn_chance, 0.65), "spawn_chance debe ser 0.65 (obtenido %.3f)." % celestial.spawn_chance)

	var env_prof: CosmosEnvProfile = load(ENV_PROFILE_PATH) as CosmosEnvProfile
	assert_true(env_prof != null, "Debe cargar default_cosmos_environment.tres.")
	assert_true(env_prof.living_universe_profile != null, "CosmosEnvProfile debe enlazar living_universe_profile.")

	var living: CosmosLivingUniverseConfig = load(LIVING_CFG_PATH) as CosmosLivingUniverseConfig
	assert_true(living != null, "Debe cargar default_living_universe.tres.")
	var w_sum: float = living.weight_rogue_world + living.weight_derelict_armada + living.weight_warp_relay + living.weight_ion_nursery
	assert_true(absf(w_sum - 1.0) < 0.01, "Suma de pesos de arquetipos debe ser ~1.0 (obt=%.3f)." % w_sum)


func _test_four_archetypes_reversibility_and_guides() -> void:
	var celestial: CosmosCelestialSystemProfile = load(CELESTIAL_PATH) as CosmosCelestialSystemProfile
	var living: CosmosLivingUniverseConfig = load(LIVING_CFG_PATH) as CosmosLivingUniverseConfig
	var env_prof: CosmosEnvProfile = load(ENV_PROFILE_PATH) as CosmosEnvProfile
	var debris_prof: CosmosDebrisLayerProfile = env_prof.debris_profile if env_prof != null else null

	for arch_idx: int in range(4):
		var sector := CosmosDeepSpaceSector2D.new()
		sector.name = "TestSector_%d" % arch_idx
		sector.system_profile = celestial
		sector.living_config = living
		sector.debris_profile = debris_prof
		add_child(sector)

		var nb_angles := PackedFloat32Array([0.35, -1.85])
		sector.build_sector(428175 + arch_idx * 919, Vector2i(arch_idx + 1, 2), arch_idx, nb_angles)
		assert_true(not sector.sector_name.is_empty(), "Arquetipo %d debe asignar sector_name." % arch_idx)
		assert_true(sector.bounding_radius > 300.0, "Arquetipo %d debe tener bounding_radius > 300." % arch_idx)
		assert_true(sector.orbiting_bodies.size() >= 1, "Arquetipo %d debe tener al menos 1 cuerpo orbital." % arch_idx)

		sector.apply_biome_harmony(Color(0.28, 0.08, 0.54, 1.0), Color(0.05, 0.42, 0.68, 1.0))
		for q: int in range(3):
			sector.apply_graphics_quality(q)
		sector.set_orbit_guides_visible(true)
		sector.set_orbit_guides_visible(false)

		sector.update_sector_state(0.0)
		var pos_t0: Array[Vector2] = []
		var rot_t0: Array[float] = []
		for body: CosmosOrbitalBody2D in sector.orbiting_bodies:
			pos_t0.append(body.position)
		for rot_node: Node2D in sector._rotating_nodes:
			rot_t0.append(rot_node.rotation)

		sector.update_sector_state(50000.0)
		var moved_any: bool = false
		for i: int in range(sector.orbiting_bodies.size()):
			if sector.orbiting_bodies[i].position.distance_to(pos_t0[i]) > 1.0:
				moved_any = true
				break
		assert_true(moved_any, "Arquetipo %d debe mover órbitas al avanzar t=50000." % arch_idx)

		sector.update_sector_state(0.0)
		for i: int in range(sector.orbiting_bodies.size()):
			var err: float = sector.orbiting_bodies[i].position.distance_to(pos_t0[i])
			assert_true(err < 0.1, "Arquetipo %d reversibilidad rota en órbita %d (err=%.4f)." % [arch_idx, i, err])
		for i: int in range(sector._rotating_nodes.size()):
			var r_err: float = absf(wrapf(sector._rotating_nodes[i].rotation - rot_t0[i], -PI, PI))
			assert_true(r_err < 0.001, "Arquetipo %d rotación reversible rota en nodo %d (err=%.5f)." % [arch_idx, i, r_err])

		remove_child(sector)
		sector.queue_free()


func _test_macro_grid_streaming_pool_and_slots() -> void:
	var root := COSMOS_ROOT_SCENE.instantiate() as CosmosRootNode
	assert_true(root != null, "Debe instanciar cosmos_root.tscn.")
	assert_true(root.non_stellar_streamer != null, "CosmosRootNode debe referenciar non_stellar_streamer.")

	var cam := Camera2D.new()
	cam.name = "TestCam"
	cam.zoom = Vector2(0.45, 0.45)
	add_child(cam)
	root.camera = cam
	add_child(root)
	root.is_frozen = true
	root.bind_camera_to_streamers()

	var solar: CosmosSolarSystemStreamer = root.solar_streamer
	var non_solar: CosmosNonStellarStreamer2D = root.non_stellar_streamer
	var grid: CosmosMacroGrid = solar.get_macro_grid()
	assert_true(grid != null, "MacroGrid debe existir.")
	var eff_chance: float = solar.system_profile.spawn_chance

	# 1. Invariante Vector2i.ZERO siempre solar
	assert_true(CosmosSolarSystemStreamer.is_cell_solar(Vector2i.ZERO, grid, eff_chance, root.poi_registry), "Vector2i.ZERO siempre debe ser solar.")
	assert_true(not non_solar.is_cell_non_stellar(Vector2i.ZERO), "Vector2i.ZERO jamás debe ser sector no estelar.")

	# 2. Exclusión mutua perfecta 9x9 y cobertura de 4 arquetipos
	var non_solar_count: int = 0
	var arch_mask: int = 0
	var cfg: CosmosLivingUniverseConfig = non_solar.living_config
	for ox: int in range(-5, 6):
		for oy: int in range(-5, 6):
			var c := Vector2i(ox, oy)
			var is_sol: bool = CosmosSolarSystemStreamer.is_cell_solar(c, grid, eff_chance, root.poi_registry)
			var is_ns: bool = non_solar.is_cell_non_stellar(c)
			assert_true(is_sol != is_ns, "Celda %s viola exclusión mutua solar=%s no_solar=%s." % [str(c), str(is_sol), str(is_ns)])
			if ox >= -4 and ox <= 4 and oy >= -4 and oy <= 4 and c != Vector2i.ZERO and is_ns:
				non_solar_count += 1
			if is_ns:
				var a: int = cfg.pick_sector_archetype(non_solar.get_sector_seed_for_cell(c))
				arch_mask |= (1 << a)

	assert_true(non_solar_count >= 16 and non_solar_count <= 44, "Proporción no estelar en 80 celdas debe rondar ~35%% (obt=%d)." % non_solar_count)
	assert_true(arch_mask == 15, "Los 4 arquetipos (mask=15) deben aparecer en la grilla procedural (obt=%d)." % arch_mask)

	# 3. Streaming real sobre un sector no estelar, pool sin fugas y CosmosOrbitalSlotTracker
	var found: Dictionary = non_solar.find_nearby_sector_cell(Vector2.ZERO, -1, 4)
	assert_true(bool(found["found"]), "Debe encontrar al menos un sector no estelar cerca del origen.")
	var target_cell: Vector2i = found["cell"] as Vector2i
	var target_pos: Vector2 = found["position"] as Vector2

	cam.global_position = target_pos
	solar.set_camera_override(target_pos, Vector2(0.45, 0.45))
	non_solar.set_camera_override(target_pos, Vector2(0.45, 0.45))
	solar._update_streaming_and_orbits(0.0)
	non_solar._update_streaming_and_sectors(0.0)

	assert_true(non_solar.get_active_sectors().has(target_cell), "Streamer no estelar debe activar la celda %s." % str(target_cell))
	assert_true(not solar.get_active_systems().has(target_cell), "Streamer solar NO debe activar la celda no estelar %s." % str(target_cell))
	assert_true(
		non_solar.get_active_sectors_count() + non_solar.get_pool_available_count() == non_solar.pool_size,
		"Conteo activo+pool debe igualar pool_size (%d + %d == %d)." % [non_solar.get_active_sectors_count(), non_solar.get_pool_available_count(), non_solar.pool_size]
	)

	var tracker := CosmosOrbitalSlotTracker.new(root)
	var fallback_slots: Array[CosmosOrbitSlot] = tracker.get_star_orbit_slots(target_pos, 45000.0)
	assert_true(not fallback_slots.is_empty(), "CosmosOrbitalSlotTracker debe resolver un slot estelar vecino desde un sector no estelar.")

	# 4. Prioridad de POI narrativo sobre sector no estelar
	var poi := CosmicPoiConfig.new()
	poi.poi_type = CosmicPoiConfig.PoiType.SOLAR_SYSTEM
	root.register_poi(target_cell, poi)
	assert_true(not non_solar.is_cell_non_stellar(target_cell), "POI SOLAR_SYSTEM debe deshabilitar sector no estelar en %s." % str(target_cell))
	assert_true(CosmosSolarSystemStreamer.is_cell_solar(target_cell, grid, eff_chance, root.poi_registry), "POI SOLAR_SYSTEM debe activar sol en %s." % str(target_cell))
	root.clear_poi_overrides()

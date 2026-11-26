extends BaseTestSuite

## Suite de integración — Hub 3D Integrado Seamless dentro de MainGame.
## Verifica:
## 1. Rol de seed AUTO fresca en cada entrada al Hub y sincronización con MainGame.run_seed.
## 2. Único Player 2D real + PlayerRigV2Controller en modo pacífico estricto (armas/barras/pet ocultos) y zoom 1.0.
## 3. Puente ortográfico 2D↔3D (Hub3DDisplaySprite z=3, proyección lineal exacta) y locomoción híbrida (islas↔espacio).
## 4. Retune de seed en vivo desde Consola Táctica y SettingsModal lock/unlock.
## 5. Despegue radial zero-rail sin Dialogic ni pausa, activando combate y liberando SubViewport 3D tras demat.
## 6. Entrada directa a MainGame saltea el Hub y arranca combate directo.

const MAIN_GAME_SCENE: PackedScene = preload("res://scenes/combat/main_game.tscn")
const RunLaunchRequestScript = preload("res://core/systems/run_launch_request.gd")
const CombatHubSessionControllerScript = preload("res://scenes/combat/controllers/combat_hub_session_controller.gd")
const HubEmbeddedViewportBridgeScript = preload("res://scenes/ui/hub/astral_station/components/hub_embedded_viewport_bridge.gd")


func _ready() -> void:
	timeout_seconds = 30.0
	super._ready()
	await _run_tests()


func _run_tests() -> void:
	await _test_embedded_hub_fresh_seed_and_parity()
	await _test_direct_combat_entry_skips_hub()
	pass_suite("Hub 3D integrado en MainGame verificado: seed fresca, Player 2D único pacífico, paridad 2D↔3D, despegue zero-rail y cleanup.")


func _test_embedded_hub_fresh_seed_and_parity() -> void:
	# 1. Primera entrada en modo Hub
	RunLaunchRequestScript.request_hub_entry()
	var game1: MainGame = MAIN_GAME_SCENE.instantiate() as MainGame
	assert_true(game1 != null, "Debe instanciar MainGame")
	add_child(game1)
	await get_tree().process_frame
	await get_tree().physics_frame

	assert_true(game1.is_hub_mode_active(), "MainGame debe iniciar en Hub Mode cuando se solicita HUB entry")
	assert_true(not get_tree().paused, "Hub Mode no debe pausar el árbol")
	assert_true(game1.active_launch_request != null, "Debe existir RunLaunchRequest activa")
	assert_true(game1.active_launch_request.seed_mode == RunLaunchRequestScript.SeedMode.AUTO, "Entrada al Hub debe usar SeedMode.AUTO")
	var seed1: int = game1.run_seed
	assert_true(seed1 > 0 and seed1 == game1.active_launch_request.cosmos_seed, "MainGame.run_seed debe coincidir con active_launch_request.cosmos_seed")

	# Verificar modo pacífico estricto y Player 2D único
	var p: Player = game1.player
	assert_true(p != null and p.is_hub_mode, "Player 2D debe estar en modo Hub")
	assert_true(p.weapon_controller != null and p.weapon_controller.is_hub_suppressed, "WeaponController debe estar suprimido en el Hub")
	assert_true(game1.hud != null and not game1.hud.visible, "HUD de combate debe estar oculto en el Hub")
	assert_true(game1.active_pet == null, "CompanionPet no debe spawnear hasta despegar")
	assert_true(game1.enemy_spawner != null and game1.enemy_spawner.is_spawning_paused, "EnemySpawner debe permanecer pausado en el Hub")
	assert_true(get_tree().get_nodes_in_group(&"enemies").is_empty(), "No deben existir enemigos en el Hub")
	assert_true(game1.camera != null and is_equal_approx(game1.camera.zoom.x, 1.0), "GameCamera2D debe iniciar con zoom 1.0 exacto en el Hub")

	var rig_v2: PlayerRigV2Controller = p.get_rig_v2_controller()
	assert_true(rig_v2 != null and rig_v2.is_hub_mode(), "PlayerRigV2Controller debe estar en Hub Mode")
	assert_true(not rig_v2.is_hub_flying(), "Al spawnear sobre la isla central debe iniciar caminando (no volando)")
	var ring_ctrl: OrbitalWeaponRingController = rig_v2.get_ring_controller()
	assert_true(ring_ctrl != null and not ring_ctrl.visible, "Anillo orbital debe permanecer oculto en el Hub")

	var hub_ctrl: CombatHubSessionControllerScript = game1.hub_session_controller
	assert_true(hub_ctrl != null and hub_ctrl.display_sprite != null and hub_ctrl.display_sprite.z_index == 3, "Hub3DDisplaySprite debe renderizar en z_index = 3 detrás del Player (z=5)")
	assert_true(is_equal_approx(p.locomotion_controller.hub_speed_override_px, hub_ctrl._layout.embedded_walk_speed_px), "Sobre plataformas la velocidad del Hub debe usar embedded_walk_speed_px (440 px/s)")
	var ripples_vfx: Node2D = rig_v2.get("_hub_landing_ripples") as Node2D
	assert_true(ripples_vfx != null and ripples_vfx.visible, "HubLandingRippleVFX debe estar activo en Hub Mode")
	var hop_rig: PlanarCombatRig = rig_v2.get("_rig") as PlanarCombatRig
	var contact_sh: Sprite2D = rig_v2.get("_hub_contact_shadow") as Sprite2D
	var cg: CanvasGroup = hop_rig.get_unified_canvas_group() if hop_rig != null else null
	assert_true(hop_rig != null and contact_sh != null and cg != null, "Rig, CanvasGroup y sombra de contacto deben existir en Hub Mode")
	var g_cfg: PilotGroundedLocomotionConfig = hop_rig.get_grounded_locomotion_config()
	var active_stride: float = PlanarRigGroundedEvaluator.get_active_stride_length_m(g_cfg)
	var contact_duty_u: float = g_cfg.glide_contact_duty if (g_cfg != null and g_cfg.gait_style == PilotGroundedLocomotionConfig.GaitStyle.ASTRAL_GLIDE_HOP) else (g_cfg.hop_contact_duty if g_cfg != null else 0.28)
	var contact_step_m: float = (minf(0.045, contact_duty_u * 0.30) * active_stride) / 3.0
	for _hop_contact: int in range(3):
		p.velocity = Vector2(hub_ctrl._layout.embedded_walk_speed_px, 0.0)
		rig_v2.feed_hub_walk_displacement(contact_step_m)
		await get_tree().process_frame
	assert_true(hop_rig.get_grounded_pelvis_lift_norm() <= 0.02, "Durante la fase de contacto/push-off debe mantenerse apoyada en el piso (got %.2f)" % hop_rig.get_grounded_pelvis_lift_norm())
	assert_true(cg.position.y >= -1.0, "Durante la fase de contacto el CanvasGroup no debe flotar (y=%.2f)" % cg.position.y)

	var apex_u: float = 0.64
	if g_cfg != null and g_cfg.gait_style == PilotGroundedLocomotionConfig.GaitStyle.ASTRAL_GLIDE_HOP:
		apex_u = g_cfg.glide_contact_duty + (1.0 - g_cfg.glide_contact_duty) * g_cfg.glide_arc_peak_shift
	var apex_rem_m: float = maxf(active_stride * (apex_u * 0.5) - contact_step_m * 3.0, 0.25)
	for _hop_up: int in range(10):
		p.velocity = Vector2(hub_ctrl._layout.embedded_walk_speed_px, 0.0)
		rig_v2.feed_hub_walk_displacement(apex_rem_m / 10.0)
		await get_tree().process_frame
	assert_true(hop_rig.get_grounded_pelvis_lift_norm() > 0.70, "Al avanzar al ápice del arco debe elevarse (got %.2f)" % hop_rig.get_grounded_pelvis_lift_norm())
	assert_true(cg.position.y < -30.0, "En el ápice del Astral Glide-Hop UnifiedCharacterGroup debe elevarse < -30 rig px (got %.2f)" % cg.position.y)
	assert_true(contact_sh.modulate.a < 0.90 and contact_sh.scale.x < 1.30, "La sombra de contacto debe achicarse y suavizarse en el ápice del arco")
	var land_rem_m: float = maxf(active_stride * 0.54 - active_stride * (apex_u * 0.5), 0.30)
	for _hop_land: int in range(14):
		p.velocity = Vector2(hub_ctrl._layout.embedded_walk_speed_px, 0.0)
		rig_v2.feed_hub_walk_displacement(land_rem_m / 14.0)
		await get_tree().process_frame
	assert_true(int(ripples_vfx.call("get_active_ripple_count")) >= 1, "Al aterrizar y rebotar debe emitirse onda luminosa en el piso")
	p.velocity = Vector2.ZERO

	var bridge: HubEmbeddedViewportBridgeScript = hub_ctrl.get_viewport_bridge()
	assert_true(bridge != null, "Debe existir HubEmbeddedViewportBridge")
	var sample_3d := Vector3(5.0, 0.0, -7.5)
	var mapped_2d: Vector2 = bridge.hub_3d_to_world_2d(sample_3d)
	var roundtrip_xz: Vector2 = bridge.world_2d_to_hub_xz(mapped_2d)
	assert_true(roundtrip_xz.distance_to(Vector2(sample_3d.x, sample_3d.z)) < 0.01, "Proyección ortográfica 2D↔3D debe ser exactamente invertible")

	# Verificar estabilidad de sombras direccionales (ORTHOGONAL sin rotación dinámica)
	var hub_stage: AstralStationHub = hub_ctrl.get_hub_stage()
	assert_true(hub_stage != null and hub_stage.embedded_mode, "AstralStationHub debe correr en embedded_mode")
	var dir_light: DirectionalLight3D = hub_stage.get("_dir_light") as DirectionalLight3D
	assert_true(dir_light != null and dir_light.directional_shadow_mode == DirectionalLight3D.SHADOW_ORTHOGONAL, "DirectionalLight3D del Hub debe usar SHADOW_ORTHOGONAL")
	assert_true(is_equal_approx(dir_light.directional_shadow_pancake_size, 0.0), "directional_shadow_pancake_size debe ser 0.0 para evitar cortes en pozos")
	var initial_light_rot: Vector3 = dir_light.rotation_degrees

	# Verificar locomoción híbrida (espacio abierto -> vuelo ágil) y Dash pacífico en Hub
	var space_2d: Vector2 = bridge.hub_3d_to_world_2d(Vector3(0.0, 0.0, -22.0)) - Vector2(0.0, hub_ctrl._layout.embedded_feet_offset_y_px)
	p.global_position = space_2d
	for _i: int in range(10):
		await get_tree().physics_frame
	assert_true(rig_v2.is_hub_flying(), "Al salir de las islas hacia el vacío debe activar vuelo Zero-G con alas 3D")
	assert_true(cg.position.is_equal_approx(Vector2.ZERO) and cg.scale.is_equal_approx(Vector2.ONE), "En vuelo Zero-G UnifiedCharacterGroup debe restaurar position=0 y scale=1")
	assert_true(is_equal_approx(p.locomotion_controller.hub_speed_override_px, hub_ctrl._layout.embedded_flight_speed_px), "En el perímetro abierto debe aplicar embedded_flight_speed_px (760 px/s)")
	assert_true(dir_light.rotation_degrees.is_equal_approx(initial_light_rot), "La luz direccional no debe rotar al moverse por el Hub")

	var did_hub_dash: bool = p.locomotion_controller.trigger_hub_dash(Vector2.RIGHT, p)
	assert_true(did_hub_dash and p.is_hub_dashing(), "Debe poder ejecutarse el Dash pacífico de travesía en Hub Mode")
	await get_tree().physics_frame
	assert_true(is_equal_approx(Engine.time_scale, 1.0), "El Dash de travesía en Hub nunca debe activar slow-mo de combate")
	p.locomotion_controller.cancel_hub_dash()

	# Verificar retune en vivo de seed desde el Hub
	var custom_req: RunLaunchRequestScript = RunLaunchRequestScript.create(777123, RunLaunchRequestScript.SeedMode.CUSTOM)
	hub_stage.apply_launch_request(custom_req, true)
	assert_true(game1.run_seed == custom_req.cosmos_seed, "Cambiar la seed en la Consola Táctica debe actualizar MainGame.run_seed en vivo")
	assert_true(dir_light.rotation_degrees.is_equal_approx(initial_light_rot), "El ángulo de sombras direccionales debe permanecer fijo tras retune de cosmos")

	# Verificar zoom cercano exclusivo para Cambio de Piloto (2.60x > max_zoom 2.0x) y Espejo de Skins (2.50x)
	hub_stage.trigger_capsule_focus(true)
	await get_tree().process_frame
	assert_true(game1.camera.zoom_override >= 2.55 and game1.camera.zoom_override > game1.camera.max_zoom, "Cambio de Piloto debe forzar zoom exclusivo más cercano (> 2.0x)")
	assert_true(game1.camera.custom_focus_point != Vector2.INF and absf(game1.camera.custom_focus_point.x - p.global_position.x) < 120.0, "Encuadre en Cambio de Piloto debe compensarse por zoom para centrar en el tercio izquierdo")
	hub_stage.exit_capsule_focus()
	await get_tree().process_frame
	assert_true(is_equal_approx(game1.camera.zoom_override, 0.0), "Cerrar Cápsula debe restaurar zoom_override = 0.0")

	hub_stage.apply_progression_preset(&"all_online")
	hub_stage.open_station_by_id(&"skins_mirror")
	await get_tree().process_frame
	assert_true(is_equal_approx(game1.camera.zoom_override, hub_ctrl._layout.embedded_skins_closeup_zoom) and game1.camera.zoom_override > game1.camera.max_zoom, "Espejo de Skins debe forzar zoom exclusivo más cercano (2.50x)")
	assert_true(absf(game1.camera.custom_focus_point.x - p.global_position.x) < 120.0, "Encuadre en Espejo de Skins debe compensarse por zoom")
	hub_stage.exit_capsule_focus()
	await get_tree().process_frame

	# Verificar supresión total de entidades jugables en Hub Mode (caminar > 1500px + crisis cooldown bajo)
	var patrol_2d: Vector2 = bridge.hub_3d_to_world_2d(Vector3(19.0, 0.0, 0.0)) - Vector2(0.0, hub_ctrl._layout.embedded_feet_offset_y_px)
	p.global_position = patrol_2d
	if game1.crisis_manager != null and "crisis_cooldown" in game1.crisis_manager:
		game1.crisis_manager.crisis_cooldown = 0.05
	for _j: int in range(8):
		await get_tree().physics_frame
		await get_tree().process_frame
	assert_true(game1.satellite_coordinator != null and game1.satellite_coordinator.is_hub_suppressed, "CombatSatelliteCoordinator debe permanecer suprimido en el Hub")
	assert_true(game1.current_satellite == null and get_tree().get_nodes_in_group(&"satellites").is_empty(), "No deben spawnear satélites ni balizas dentro del Hub")
	assert_true(game1.space_debris_manager != null and game1.space_debris_manager.planet_spawner == null, "PlanetSpawner no debe existir en Hub Mode")
	assert_true(get_tree().get_nodes_in_group(&"planets").is_empty(), "No deben spawnear planetas destructibles dentro del Hub")
	assert_true(game1.chest_director != null and game1.chest_director.is_hub_suppressed, "ChestDirector debe permanecer suprimido en Hub Mode")
	assert_true(get_tree().get_nodes_in_group(&"spatial_chests").is_empty(), "No deben spawnear cofres dentro del Hub")
	assert_true(game1.space_debris_manager.asteroid_spawner == null and get_tree().get_nodes_in_group(&"asteroids").is_empty(), "No deben spawnear asteroides dentro del Hub")
	assert_true(get_tree().get_nodes_in_group(&"supply_pods").is_empty() and get_tree().get_nodes_in_group(&"astral_geodes").is_empty() and get_tree().get_nodes_in_group(&"bio_cocoons").is_empty() and get_tree().get_nodes_in_group(&"monoliths").is_empty(), "No deben spawnear macro-objetos espaciales dentro del Hub")
	assert_true(game1.crisis_manager != null and game1.crisis_manager.is_hub_suppressed and game1.crisis_manager.current_active_crisis == "", "CrisisEventManager no debe disparar crisis en Hub Mode")
	assert_true(game1.is_position_in_hub_exclusion_zone(hub_ctrl.hub_origin_2d), "El origen del Hub debe estar protegido por la zona de exclusión")

	# Verificar SettingsModal en modo embebido
	hub_stage.open_settings_modal()
	assert_true(p.is_movement_suppressed, "Abrir SettingsModal en Hub embebido debe bloquear movimiento del Player")
	hub_stage.close_settings_modal()
	assert_true(not p.is_movement_suppressed, "Cerrar SettingsModal debe devolver movimiento al Player")

	# Posicionar al borde Norte de despegue y verificar despegue seamless zero-rail + sesgo frontal
	var north_perimeter_2d: Vector2 = bridge.hub_3d_to_world_2d(Vector3(0.0, 0.0, -30.5)) - Vector2(0.0, hub_ctrl._layout.embedded_feet_offset_y_px)
	p.global_position = north_perimeter_2d
	var launch_pos: Vector2 = p.global_position
	var pre_credits: int = p.run_credits
	hub_ctrl.launch_combat_seamlessly(Vector2(0.0, -30.5))
	await get_tree().process_frame
	await get_tree().process_frame

	assert_true(not game1.is_hub_mode_active(), "Tras despegar is_hub_mode_active() debe ser false inmediatamente")
	assert_true(not p.is_hub_mode, "Player debe salir del modo Hub inmediatamente al despegar")
	assert_true(cg.position.is_equal_approx(Vector2.ZERO) and cg.scale.is_equal_approx(Vector2.ONE), "Al despegar a combate UnifiedCharacterGroup debe restaurar position=0 y scale=1")
	assert_true(not p.is_movement_suppressed, "Despegue zero-rail nunca debe bloquear movimiento del jugador")
	assert_true(not game1.is_briefing_active and not get_tree().paused, "Despegue fluido no debe pausar ni lanzar Dialogic")
	assert_true(not p.weapon_controller.is_hub_suppressed, "WeaponController debe reactivarse al despegar")
	assert_true(not ripples_vfx.visible and int(ripples_vfx.call("get_active_ripple_count")) == 0, "HubLandingRippleVFX debe limpiarse y ocultarse al despegar")
	assert_true(ring_ctrl.visible, "Anillo orbital debe desplegarse al despegar")
	assert_true(game1.hud.visible, "HUD de combate debe mostrarse al despegar")
	assert_true(is_instance_valid(game1.active_pet), "CompanionPet debe spawnear al despegar")
	assert_true(p.run_credits >= pre_credits + 50, "Debe otorgar los +50 créditos iniciales al despegar")
	assert_true(not game1.enemy_spawner.is_spawning_paused, "EnemySpawner debe reactivarse al despegar")
	assert_true(not game1.satellite_coordinator.is_hub_suppressed, "CombatSatelliteCoordinator debe reactivarse al despegar")
	assert_true(not game1.crisis_manager.is_hub_suppressed, "CrisisEventManager debe reactivarse al despegar")
	assert_true(not game1.chest_director.is_hub_suppressed, "ChestDirector debe reactivarse al despegar")
	assert_true(game1.is_position_in_hub_exclusion_zone(hub_ctrl.hub_origin_2d), "La zona de exclusión del Hub debe permanecer activa durante la desmaterialización")
	assert_true(game1.get_hub_launch_departure_direction().dot(Vector2.UP) > 0.99, "La dirección de despegue hacia el Norte debe proyectarse hacia Vector2.UP")
	assert_true(game1.run_seed == custom_req.cosmos_seed, "MainGame.run_seed debe conservar la seed al despegar")

	var spawned_chests: Array[Node] = get_tree().get_nodes_in_group(&"spatial_chests")
	assert_true(spawned_chests.size() >= 2, "Deben spawnear los cofres iniciales de la oleada al despegar")
	var spawned_enemies: Array[Node] = get_tree().get_nodes_in_group(&"enemies")
	assert_true(spawned_enemies.size() >= 4, "Debe spawnear el escuadrón inicial de drones al despegar")
	var spawned_planets: Array[Node] = get_tree().get_nodes_in_group(&"planets")
	var spawned_sats: Array[Node] = get_tree().get_nodes_in_group(&"satellites")
	var all_post_launch_nodes: Array[Node] = []
	all_post_launch_nodes.append_array(spawned_chests)
	all_post_launch_nodes.append_array(spawned_enemies)
	all_post_launch_nodes.append_array(spawned_planets)
	all_post_launch_nodes.append_array(spawned_sats)
	for spawned_node: Node in all_post_launch_nodes:
		if not is_instance_valid(spawned_node) or not (spawned_node is Node2D):
			continue
		var s_pos: Vector2 = (spawned_node as Node2D).global_position
		assert_true(not game1.is_position_in_hub_exclusion_zone(s_pos), "Ninguna entidad post-despegue debe aparecer dentro de la zona de exclusión del Hub: %s" % spawned_node.name)
		var forward_dot: float = (s_pos - launch_pos).normalized().dot(Vector2.UP)
		assert_true(forward_dot > 0.0, "Las entidades iniciales post-despegue deben spawnear por delante de la dirección de salida: %s (dot=%.2f)" % [spawned_node.name, forward_dot])

	# Esperar fin de desmaterialización 3D y verificar cleanup
	await get_tree().create_timer(hub_ctrl._layout.demat_duration_sec + 0.25, true).timeout
	assert_true(hub_ctrl.get_hub_stage() == null, "El SubViewport 3D y AstralStationHub deben liberarse al finalizar demat")

	game1.queue_free()
	await get_tree().process_frame

	# 2. Segunda entrada al Hub: debe rolear una seed nueva diferente
	RunLaunchRequestScript.request_hub_entry()
	var game2: MainGame = MAIN_GAME_SCENE.instantiate() as MainGame
	add_child(game2)
	await get_tree().process_frame
	var seed2: int = game2.run_seed
	assert_true(seed2 > 0 and seed2 != seed1, "Cada nueva entrada al Hub debe rolear una seed diferente (%d vs %d)" % [seed1, seed2])
	game2.queue_free()
	await get_tree().process_frame


func _test_direct_combat_entry_skips_hub() -> void:
	RunLaunchRequestScript.request_direct_combat_entry()
	var game: MainGame = MAIN_GAME_SCENE.instantiate() as MainGame
	add_child(game)
	await get_tree().process_frame
	assert_true(not game.is_hub_mode_active(), "Entrada directa a MainGame no debe activar Hub Mode")
	assert_true(game.player != null and not game.player.is_hub_mode, "Player no debe estar en Hub Mode en entrada directa")
	game.queue_free()
	await get_tree().process_frame

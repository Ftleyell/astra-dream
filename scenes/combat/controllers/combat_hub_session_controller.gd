class_name CombatHubSessionController
extends Node

## Orquestador del Hub 3D integrado dentro de MainGame sobre el Cosmos vivo.
## Controla el ciclo de vida: HUB_ACTIVE -> DEPARTING_DISSOLVE (zero-rail) -> COMBAT_LIVE.

enum SessionState {
	INACTIVE = 0,
	HUB_ACTIVE = 1,
	DEPARTING_DISSOLVE = 2,
	COMBAT_LIVE = 3,
	TITLE_STANDBY = 4,
}

const AstralStationHubScript = preload("res://scenes/ui/hub/astral_station/astral_station_hub.gd")
const ViewportBridgeScript = preload("res://scenes/ui/hub/astral_station/components/hub_embedded_viewport_bridge.gd")
const CameraRigScript = preload("res://scenes/ui/hub/astral_station/components/hub_lab_camera_rig.gd")
const ConfigScript = preload("res://scenes/ui/hub/astral_station/resources/hub_art_lab_config.gd")
const LayoutConfigScript = preload("res://scenes/ui/hub/astral_station/resources/hub_floating_layout_config.gd")
const RunLaunchRequestScript = preload("res://core/systems/run_launch_request.gd")
const CombatBootstrapperScript = preload("res://scenes/combat/systems/combat_bootstrapper.gd")
const CombatSceneAssemblerScript = preload("res://scenes/combat/systems/combat_scene_assembler.gd")
const HubTutorialDirectorScript = preload("res://scenes/ui/hub/astral_station/components/hub_tutorial_director.gd")

const HUB_DISPLAY_Z_INDEX: int = 3
const DEFAULT_HUB_ORIGIN_2D := Vector2(960.0, 540.0)

var state: SessionState = SessionState.INACTIVE
var main_game: MainGame = null
var hub_stage: AstralStationHub = null
var bridge: ViewportBridgeScript = null
var display_sprite: Sprite2D = null
var tutorial_director: HubTutorialDirectorScript = null
var active_launch_request: RunLaunchRequestScript = null
var hub_origin_2d: Vector2 = DEFAULT_HUB_ORIGIN_2D

var _config: ConfigScript = null
var _layout: LayoutConfigScript = null
var _is_flying: bool = false
var _pending_fly_target: bool = false
var _hysteresis_timer: float = 0.0
var _prev_player_pos_2d: Vector2 = Vector2.ZERO
var _has_prev_pos: bool = false
var _px_per_m_x: float = 84.0
var _px_per_m_z: float = 60.424
var _post_launch_exclusion_timer: float = 0.0
var _departure_dir_2d: Vector2 = Vector2.ZERO
var _auto_tutorial_token: int = 0


func is_hub_mode_active() -> bool:
	return state == SessionState.HUB_ACTIVE


func is_departing_dissolve() -> bool:
	return state == SessionState.DEPARTING_DISSOLVE


func is_hub_tutorial_active() -> bool:
	return tutorial_director != null and is_instance_valid(tutorial_director) and tutorial_director.is_active()


func get_tutorial_director() -> HubTutorialDirectorScript:
	return tutorial_director if is_instance_valid(tutorial_director) else null


func is_any_hub_modal_active() -> bool:
	if state != SessionState.HUB_ACTIVE or hub_stage == null or not is_instance_valid(hub_stage):
		return false
	return hub_stage.is_any_hub_modal_or_panel_open() or is_hub_tutorial_active()


func get_hub_stage() -> AstralStationHub:
	return hub_stage if is_instance_valid(hub_stage) else null


func get_active_launch_request() -> RunLaunchRequestScript:
	return active_launch_request


func get_viewport_bridge() -> ViewportBridgeScript:
	return bridge if is_instance_valid(bridge) else null


func is_hub_exclusion_active() -> bool:
	return state == SessionState.HUB_ACTIVE or state == SessionState.DEPARTING_DISSOLVE or _post_launch_exclusion_timer > 0.0


func is_position_in_hub_exclusion_zone(world_pos: Vector2, extra_padding_px: float = 0.0) -> bool:
	if not is_hub_exclusion_active():
		return false
	var excl_r_m: float = _layout.embedded_hub_exclusion_radius_m if _layout != null else 29.5
	var dx_m: float = (world_pos.x - hub_origin_2d.x) / maxf(_px_per_m_x, 1.0)
	var dz_m: float = (world_pos.y - hub_origin_2d.y) / maxf(_px_per_m_z, 1.0)
	var pad_m: float = maxf(extra_padding_px, 0.0) / maxf(_px_per_m_x, 1.0)
	var eff_r: float = excl_r_m + pad_m
	return (dx_m * dx_m + dz_m * dz_m) < (eff_r * eff_r)


func has_launch_forward_bias() -> bool:
	return state != SessionState.HUB_ACTIVE and _post_launch_exclusion_timer > 0.0 and _departure_dir_2d.length_squared() > 0.001


func get_launch_departure_direction() -> Vector2:
	return _departure_dir_2d if has_launch_forward_bias() else Vector2.ZERO


func get_launch_forward_cone_half_angle_rad() -> float:
	return deg_to_rad(_layout.embedded_launch_forward_cone_half_angle_deg if _layout != null else 65.0)


func get_launch_min_forward_dot() -> float:
	return _layout.embedded_launch_min_forward_dot if _layout != null else 0.15


func is_position_allowed_for_combat_spawn(world_pos: Vector2, player_pos: Vector2, extra_padding_px: float = 0.0, require_forward_bias: bool = true) -> bool:
	if state == SessionState.HUB_ACTIVE:
		return false
	if is_position_in_hub_exclusion_zone(world_pos, extra_padding_px):
		return false
	if require_forward_bias and has_launch_forward_bias():
		var rel: Vector2 = world_pos - player_pos
		if rel.length_squared() > 1.0 and rel.normalized().dot(_departure_dir_2d) < get_launch_min_forward_dot():
			return false
	return true


func push_position_outside_hub_exclusion(world_pos: Vector2, fallback_dir: Vector2, extra_padding_px: float = 0.0) -> Vector2:
	if not is_position_in_hub_exclusion_zone(world_pos, extra_padding_px):
		return world_pos
	var excl_r_m: float = _layout.embedded_hub_exclusion_radius_m if _layout != null else 29.5
	var pad_m: float = maxf(extra_padding_px, 0.0) / maxf(_px_per_m_x, 1.0)
	var target_r_m: float = excl_r_m + pad_m + 1.5
	var rel_m := Vector2(
		(world_pos.x - hub_origin_2d.x) / maxf(_px_per_m_x, 1.0),
		(world_pos.y - hub_origin_2d.y) / maxf(_px_per_m_z, 1.0)
	)
	var out_dir_m: Vector2
	if rel_m.length_squared() > 0.001:
		out_dir_m = rel_m.normalized()
	else:
		var raw_fb: Vector2 = fallback_dir if fallback_dir.length_squared() > 0.001 else (_departure_dir_2d if _departure_dir_2d.length_squared() > 0.001 else Vector2.UP)
		out_dir_m = Vector2(raw_fb.x / maxf(_px_per_m_x, 1.0), raw_fb.y / maxf(_px_per_m_z, 1.0)).normalized()
	return hub_origin_2d + Vector2(out_dir_m.x * target_r_m * _px_per_m_x, out_dir_m.y * target_r_m * _px_per_m_z)


func _apply_title_or_hub_suppression(p_main_game: MainGame, p_initial_request: RunLaunchRequestScript) -> bool:
	main_game = p_main_game
	if main_game == null:
		return false

	hub_origin_2d = DEFAULT_HUB_ORIGIN_2D
	active_launch_request = p_initial_request.duplicate_request() if p_initial_request != null else RunLaunchRequestScript.create_random_auto()
	_is_flying = false
	_pending_fly_target = false
	_hysteresis_timer = 0.0
	_has_prev_pos = false
	_post_launch_exclusion_timer = 0.0
	_departure_dir_2d = Vector2.ZERO
	_auto_tutorial_token += 1

	PauseArbitrator.force_unpause_all()
	Engine.time_scale = 1.0
	SaveManager.set_game_speed(1.0)

	if main_game.enemy_spawner != null:
		main_game.enemy_spawner.set_spawning_paused(true)
	if main_game.space_debris_manager != null and main_game.space_debris_manager.space_object_spawner != null:
		main_game.space_debris_manager.space_object_spawner.set_hub_suppressed(true)
	if main_game.active_navigator_controller != null and main_game.active_navigator_controller.has_method("set_hub_suppressed"):
		main_game.active_navigator_controller.set_hub_suppressed(true)
	if main_game.satellite_coordinator != null and main_game.satellite_coordinator.has_method("set_hub_suppressed"):
		main_game.satellite_coordinator.set_hub_suppressed(true)
	if main_game.crisis_manager != null and main_game.crisis_manager.has_method("set_hub_suppressed"):
		main_game.crisis_manager.set_hub_suppressed(true)
	if main_game.chest_director != null and main_game.chest_director.has_method("set_hub_suppressed"):
		main_game.chest_director.set_hub_suppressed(true)
	if main_game.loot_coordinator != null and main_game.loot_coordinator.has_method("set_hub_suppressed"):
		main_game.loot_coordinator.set_hub_suppressed(true)
	_set_combat_hud_suppressed(true)
	return true


func _set_combat_hud_suppressed(suppressed: bool) -> void:
	if main_game == null:
		return
	if is_instance_valid(main_game.hud):
		if main_game.hud.has_method("set_hud_visible"):
			main_game.hud.set_hud_visible(not suppressed)
		else:
			main_game.hud.visible = not suppressed
	if is_instance_valid(main_game.skip_badge_layer):
		if suppressed:
			main_game.skip_badge_layer.hide()
			main_game.skip_badge_layer.process_mode = Node.PROCESS_MODE_DISABLED
		else:
			main_game.skip_badge_layer.process_mode = Node.PROCESS_MODE_ALWAYS


func reapply_title_suppression() -> void:
	if main_game == null:
		return
	if main_game.enemy_spawner != null:
		main_game.enemy_spawner.set_spawning_paused(true)
	if main_game.space_debris_manager != null and main_game.space_debris_manager.space_object_spawner != null:
		main_game.space_debris_manager.space_object_spawner.set_hub_suppressed(true)
	if main_game.active_navigator_controller != null and main_game.active_navigator_controller.has_method("set_hub_suppressed"):
		main_game.active_navigator_controller.set_hub_suppressed(true)
	if main_game.satellite_coordinator != null and main_game.satellite_coordinator.has_method("set_hub_suppressed"):
		main_game.satellite_coordinator.set_hub_suppressed(true)
	if main_game.crisis_manager != null and main_game.crisis_manager.has_method("set_hub_suppressed"):
		main_game.crisis_manager.set_hub_suppressed(true)
	if main_game.chest_director != null and main_game.chest_director.has_method("set_hub_suppressed"):
		main_game.chest_director.set_hub_suppressed(true)
	if main_game.loot_coordinator != null and main_game.loot_coordinator.has_method("set_hub_suppressed"):
		main_game.loot_coordinator.set_hub_suppressed(true)
	_set_combat_hud_suppressed(true)


func _build_embedded_hub_nodes() -> bool:
	if main_game == null:
		return false
	if hub_stage != null and is_instance_valid(hub_stage) and bridge != null and is_instance_valid(bridge):
		return true

	var cosmos_root: CosmosRootNode = _resolve_cosmos_root()
	var player_rig_v2: Node = main_game.player.get_rig_v2_controller() if is_instance_valid(main_game.player) else null

	hub_stage = AstralStationHubScript.new() as AstralStationHub
	hub_stage.name = "EmbeddedAstralStationHub"
	hub_stage.configure_embedded(active_launch_request, player_rig_v2, cosmos_root)
	if hub_stage.has_method("set_embedded_cosmos_anchor_2d"):
		hub_stage.set_embedded_cosmos_anchor_2d(hub_origin_2d)
	main_game.add_child(hub_stage)

	_config = hub_stage.config
	_layout = hub_stage.layout_config

	var feet_off_y: float = _layout.embedded_feet_offset_y_px if _layout != null else 54.0
	if is_instance_valid(main_game.player):
		main_game.player.set_hub_mode(true, feet_off_y)
		if _layout != null:
			main_game.player.set_hub_walk_speed_override(_layout.embedded_walk_speed_px)
			main_game.player.configure_hub_motion(
				_layout.embedded_hub_accel,
				_layout.embedded_hub_friction,
				_layout.embedded_hub_pivot_brake_mul,
				_layout.embedded_hub_dash_speed_px,
				_layout.embedded_hub_dash_duration_sec,
				_layout.embedded_hub_dash_cooldown_sec
			)
		var init_rig_v2: PlayerRigV2Controller = main_game.player.get_rig_v2_controller()
		if init_rig_v2 != null and _layout != null:
			init_rig_v2.set_hub_speed_refs(_layout.embedded_walk_speed_px, _layout.embedded_flight_speed_px)

	display_sprite = Sprite2D.new()
	display_sprite.name = "Hub3DDisplaySprite"
	display_sprite.centered = true
	display_sprite.z_as_relative = false
	display_sprite.z_index = HUB_DISPLAY_Z_INDEX
	var vp_3d: SubViewport = hub_stage.get_world_3d_viewport()
	if vp_3d != null:
		display_sprite.texture = vp_3d.get_texture()
	main_game.add_child(display_sprite)

	bridge = ViewportBridgeScript.new() as ViewportBridgeScript
	bridge.name = "HubEmbeddedViewportBridge"
	add_child(bridge)
	bridge.setup(
		hub_origin_2d,
		_config,
		_layout,
		main_game.camera,
		hub_stage.get_camera_3d(),
		vp_3d,
		display_sprite
	)
	_px_per_m_x = bridge.get_px_per_meter_x()
	var pitch_deg: float = absf(_config.free_roam_pitch_deg) if _config != null else 46.0
	_px_per_m_z = _px_per_m_x * maxf(sin(deg_to_rad(pitch_deg)), 0.1)

	if is_instance_valid(main_game.player) and _config != null:
		var spawn_2d: Vector2 = bridge.hub_3d_to_world_2d(_config.player_spawn_pos) - Vector2(0.0, feet_off_y)
		main_game.player.global_position = spawn_2d
		_prev_player_pos_2d = spawn_2d
		_has_prev_pos = true
		CombatSceneAssemblerScript.spawn_companion_pet(main_game, main_game.player)
		if is_instance_valid(main_game.active_pet):
			main_game.active_pet.global_position = spawn_2d + Vector2(-46.0, -18.0)
			main_game.active_pet.set_hub_mode(true)

	bridge.sync_camera_and_sprite()
	_connect_hub_signals()

	if _config != null:
		hub_stage.sync_embedded_player_3d(_config.player_spawn_pos, main_game.player.global_position if is_instance_valid(main_game.player) else hub_origin_2d, false)

	tutorial_director = HubTutorialDirectorScript.new() as HubTutorialDirectorScript
	tutorial_director.name = "HubTutorialDirector"
	add_child(tutorial_director)
	tutorial_director.setup(hub_stage, bridge, main_game.camera)
	tutorial_director.tutorial_started.connect(func() -> void:
		if hub_stage != null and is_instance_valid(hub_stage):
			hub_stage.set_embedded_input_suppressed(true)
	)
	tutorial_director.tutorial_finished.connect(func(_skipped: bool) -> void:
		if hub_stage != null and is_instance_valid(hub_stage) and state == SessionState.HUB_ACTIVE:
			hub_stage.set_embedded_input_suppressed(false)
		SaveManager.set_hub_tutorial_completed(true)
	)
	return true


func enter_hub_mode(p_main_game: MainGame, p_initial_request: RunLaunchRequestScript) -> void:
	if not _apply_title_or_hub_suppression(p_main_game, p_initial_request):
		return
	if not _build_embedded_hub_nodes():
		return
	state = SessionState.HUB_ACTIVE
	_set_combat_hud_suppressed(true)
	hub_stage.set_embedded_input_suppressed(false)
	if is_instance_valid(main_game.camera) and is_instance_valid(main_game.player):
		main_game.camera.clear_cinematic_focus()
		main_game.camera.global_position = main_game.player.global_position
		main_game.camera.zoom = Vector2.ONE
		main_game.camera.target_zoom = 1.0

	var audio_mgr: Node = get_node_or_null("/root/AudioManager")
	if audio_mgr != null:
		if audio_mgr.has_method("play_music"):
			audio_mgr.play_music("menu")
		if audio_mgr.has_method("set_ambience"):
			audio_mgr.set_ambience("hub")

	schedule_first_time_tutorial_if_needed(0.55)


func prepare_hidden_for_title(p_main_game: MainGame, p_initial_request: RunLaunchRequestScript) -> void:
	if not _apply_title_or_hub_suppression(p_main_game, p_initial_request):
		return
	state = SessionState.TITLE_STANDBY
	if is_instance_valid(main_game.player):
		main_game.player.visible = false
		main_game.player.is_movement_suppressed = true
		main_game.player.velocity = Vector2.ZERO


func ensure_embedded_hub_built_hidden() -> bool:
	if main_game == null:
		return false
	var already_built: bool = (hub_stage != null and is_instance_valid(hub_stage) and bridge != null and is_instance_valid(bridge))
	if not already_built:
		if not _build_embedded_hub_nodes():
			return false
		if state == SessionState.TITLE_STANDBY:
			if display_sprite != null:
				display_sprite.visible = false
			if hub_stage != null:
				hub_stage.set_embedded_hidden_for_materialization()
				hub_stage.set_embedded_input_suppressed(true)
			if is_instance_valid(main_game.player):
				main_game.player.visible = false
				main_game.player.is_movement_suppressed = true
				main_game.player.velocity = Vector2.ZERO
	return true


func activate_hub_from_title(allow_auto_tutorial: bool = true) -> void:
	if main_game == null or hub_stage == null:
		return
	state = SessionState.HUB_ACTIVE
	_set_combat_hud_suppressed(true)
	_is_flying = false
	_pending_fly_target = false
	_hysteresis_timer = 0.0
	if is_instance_valid(main_game.player):
		_prev_player_pos_2d = main_game.player.global_position
		_has_prev_pos = true
	hub_stage.set_embedded_input_suppressed(false)
	if hub_stage.hud != null:
		hub_stage.hud.set_clean_hud_visible(true)
	if allow_auto_tutorial:
		schedule_first_time_tutorial_if_needed(0.45)


func suspend_hub_for_title() -> void:
	_auto_tutorial_token += 1
	if is_hub_tutorial_active():
		tutorial_director.finish_tutorial(true)
	state = SessionState.TITLE_STANDBY
	_set_combat_hud_suppressed(true)
	if display_sprite != null:
		display_sprite.visible = false
	if hub_stage != null:
		hub_stage.set_embedded_hidden_for_materialization()
		hub_stage.set_embedded_input_suppressed(true)
	if main_game != null and is_instance_valid(main_game.player):
		main_game.player.visible = false
		main_game.player.is_movement_suppressed = true
		main_game.player.velocity = Vector2.ZERO


func start_hub_tutorial(pet_id_override: StringName = &"") -> void:
	if state != SessionState.HUB_ACTIVE or tutorial_director == null or hub_stage == null:
		return
	if is_hub_tutorial_active() or hub_stage.is_any_hub_modal_or_panel_open():
		return
	tutorial_director.start_tutorial(pet_id_override)


func schedule_first_time_tutorial_if_needed(delay_sec: float = 0.45) -> void:
	if SaveManager.is_hub_tutorial_completed() or state != SessionState.HUB_ACTIVE:
		return
	_auto_tutorial_token += 1
	var my_token: int = _auto_tutorial_token
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	tree.create_timer(maxf(delay_sec, 0.05), true, false, true).timeout.connect(func() -> void:
		if not is_inside_tree() or my_token != _auto_tutorial_token:
			return
		if state != SessionState.HUB_ACTIVE or SaveManager.is_hub_tutorial_completed():
			return
		if is_any_hub_modal_active():
			return
		start_hub_tutorial()
	)


func _resolve_cosmos_root() -> CosmosRootNode:
	if main_game == null:
		return null
	if main_game.environment_host != null and is_instance_valid(main_game.environment_host.active_environment):
		var env: BaseSpaceEnvironment = main_game.environment_host.active_environment
		if env is CosmosCombatEnvironment:
			return (env as CosmosCombatEnvironment).get_cosmos_root()
	var bg: Node = main_game.get_node_or_null("SpaceBackground")
	if bg is CosmosCombatEnvironment:
		return (bg as CosmosCombatEnvironment).get_cosmos_root()
	return null


func _connect_hub_signals() -> void:
	if hub_stage == null:
		return
	hub_stage.embedded_launch_request_changed.connect(_on_embedded_launch_request_changed)
	hub_stage.embedded_camera_focus_changed.connect(_on_embedded_camera_focus_changed)
	hub_stage.embedded_movement_lock_changed.connect(_on_embedded_movement_lock_changed)
	hub_stage.embedded_player_reposition_requested.connect(_on_embedded_player_reposition_requested)
	hub_stage.embedded_pilot_selected.connect(_on_embedded_pilot_selected)
	hub_stage.embedded_companions_updated.connect(_on_embedded_companions_updated)
	hub_stage.embedded_gacha_skin_equipped.connect(_on_embedded_gacha_skin_equipped)
	hub_stage.embedded_tutorial_requested.connect(_on_embedded_tutorial_requested)
	hub_stage.embedded_return_to_title_requested.connect(_on_embedded_return_to_title_requested)
	hub_stage.embedded_demat_finished.connect(_on_hub_demat_finished)


func _on_embedded_tutorial_requested() -> void:
	_auto_tutorial_token += 1
	start_hub_tutorial()


func _on_embedded_return_to_title_requested() -> void:
	if state != SessionState.HUB_ACTIVE or is_any_hub_modal_active():
		return
	if main_game != null and main_game.has_method("return_from_hub_to_title"):
		main_game.return_from_hub_to_title()


func _on_embedded_launch_request_changed(req: RunLaunchRequestScript, trigger_flash: bool) -> void:
	if req == null or main_game == null:
		return
	active_launch_request = req.duplicate_request()
	main_game.active_launch_request = active_launch_request
	main_game.run_director_seed = active_launch_request.run_director_seed
	main_game.run_loot_seed = active_launch_request.run_loot_seed
	main_game.run_seed = active_launch_request.cosmos_seed
	if trigger_flash and bridge != null:
		var dur: float = _config.cosmos_retune_duration if _config != null else 0.32
		bridge.trigger_retune_flash(dur)


func _on_embedded_camera_focus_changed(mode: int, focus_3d: Vector3) -> void:
	if main_game == null or not is_instance_valid(main_game.camera) or bridge == null:
		return
	if mode == CameraRigScript.Mode.FREE_ROAM:
		main_game.camera.clear_cinematic_focus()
		main_game.camera.target_zoom = 1.0
		return

	var feet_off_y: float = _layout.embedded_feet_offset_y_px if _layout != null else 54.0
	var is_pilot_showcase: bool = (mode == CameraRigScript.Mode.CAPSULE_PILOT_FOCUS or mode == CameraRigScript.Mode.SKINS_MIRROR_FOCUS)
	var feet_ratio: float = (_layout.embedded_showcase_focus_feet_ratio if _layout != null else 0.92) if is_pilot_showcase else 0.65
	var focus_2d: Vector2 = bridge.hub_3d_to_world_2d(focus_3d) - Vector2(0.0, feet_off_y * feet_ratio)
	var zoom_val: float = 1.4
	var side_screen_off := Vector2.ZERO
	if _layout != null:
		var panel_screen := Vector2(_layout.embedded_side_panel_camera_offset_x_px, _layout.embedded_side_panel_camera_offset_y_px)
		match mode:
			CameraRigScript.Mode.CAPSULE_PILOT_FOCUS:
				zoom_val = _layout.embedded_capsule_closeup_zoom
				side_screen_off = panel_screen
			CameraRigScript.Mode.SKINS_MIRROR_FOCUS:
				zoom_val = _layout.embedded_skins_closeup_zoom
				side_screen_off = panel_screen
			CameraRigScript.Mode.STATION_FOCUS:
				zoom_val = _layout.embedded_station_closeup_zoom
				side_screen_off = panel_screen
			CameraRigScript.Mode.GACHA_SUMMON_CINEMATIC:
				zoom_val = _layout.embedded_gacha_closeup_zoom
				side_screen_off = Vector2(-panel_screen.x * 0.45, panel_screen.y)
			CameraRigScript.Mode.TROPHY_FOCUS:
				zoom_val = _layout.embedded_trophy_closeup_zoom
			_:
				zoom_val = 1.0
	var world_side_offset: Vector2 = side_screen_off / maxf(zoom_val, 0.5)
	main_game.camera.set_cinematic_focus(focus_2d + world_side_offset, zoom_val)


func _on_embedded_movement_lock_changed(locked: bool) -> void:
	if main_game == null or not is_instance_valid(main_game.player):
		return
	main_game.player.is_movement_suppressed = locked
	if locked:
		main_game.player.velocity = Vector2.ZERO
	else:
		var rig_v2: PlayerRigV2Controller = main_game.player.get_rig_v2_controller()
		if rig_v2 != null:
			rig_v2.set_hub_pose_override(false)
			rig_v2.set_hub_shadow_suppressed(false)


func _on_embedded_player_reposition_requested(world_3d: Vector3, face_dir: Vector2, suppress_shadow: bool) -> void:
	if main_game == null or not is_instance_valid(main_game.player) or bridge == null:
		return
	var feet_off_y: float = _layout.embedded_feet_offset_y_px if _layout != null else 54.0
	var target_2d: Vector2 = bridge.hub_3d_to_world_2d(world_3d) - Vector2(0.0, feet_off_y)
	main_game.player.global_position = target_2d
	main_game.player.velocity = Vector2.ZERO
	_prev_player_pos_2d = target_2d
	var rig_v2: PlayerRigV2Controller = main_game.player.get_rig_v2_controller()
	if rig_v2 != null:
		rig_v2.set_hub_pose_override(true, face_dir, true)
		rig_v2.set_hub_shadow_suppressed(suppress_shadow)


func _on_embedded_pilot_selected(char_id: StringName, _accent_color: Color) -> void:
	if main_game == null or not is_instance_valid(main_game.player):
		return
	main_game.player.reload_character_for_hub(char_id)
	if _layout != null:
		main_game.player.configure_hub_motion(
			_layout.embedded_hub_accel,
			_layout.embedded_hub_friction,
			_layout.embedded_hub_pivot_brake_mul,
			_layout.embedded_hub_dash_speed_px,
			_layout.embedded_hub_dash_duration_sec,
			_layout.embedded_hub_dash_cooldown_sec
		)
	var new_rig_v2: PlayerRigV2Controller = main_game.player.get_rig_v2_controller()
	if new_rig_v2 != null:
		if _layout != null:
			new_rig_v2.set_hub_speed_refs(_layout.embedded_walk_speed_px, _layout.embedded_flight_speed_px)
		if main_game.player.is_movement_suppressed:
			new_rig_v2.set_hub_pose_override(true, Vector2.DOWN, true)
			new_rig_v2.set_hub_shadow_suppressed(true)
	if hub_stage != null:
		hub_stage.set_embedded_player_rig_v2(new_rig_v2)


func _on_embedded_companions_updated() -> void:
	if main_game != null and is_instance_valid(main_game.active_pet):
		main_game.active_pet.refresh_from_save()


func _on_embedded_gacha_skin_equipped(equip_res: Dictionary) -> void:
	if main_game == null or not is_instance_valid(main_game.player):
		return
	var cat: String = str(equip_res.get("category", "pilot"))
	if cat == "pet":
		if is_instance_valid(main_game.active_pet):
			main_game.active_pet.refresh_from_save()
		return
	var rig_v2: PlayerRigV2Controller = main_game.player.get_rig_v2_controller()
	if rig_v2 == null:
		return
	var preset: PilotSkinPreset = equip_res.get("preset", null) as PilotSkinPreset
	if preset == null:
		return
	var stars: int = int(equip_res.get("star_level", 1))
	rig_v2.apply_live_gacha_skin(cat, preset, stars)


func _physics_process(delta: float) -> void:
	if state != SessionState.HUB_ACTIVE:
		if _post_launch_exclusion_timer > 0.0:
			_post_launch_exclusion_timer = maxf(0.0, _post_launch_exclusion_timer - delta)
			if _post_launch_exclusion_timer <= 0.0 and state == SessionState.COMBAT_LIVE:
				_departure_dir_2d = Vector2.ZERO
		return
	if main_game == null or not is_instance_valid(main_game.player) or bridge == null or hub_stage == null or _layout == null:
		return

	var player_ref: Player = main_game.player
	var feet_off_y: float = _layout.embedded_feet_offset_y_px
	var feet_2d: Vector2 = player_ref.global_position + Vector2(0.0, feet_off_y)
	var hub_xz: Vector2 = bridge.world_2d_to_hub_xz(feet_2d)

	var on_platform: bool = _layout.is_point_on_platform(hub_xz)
	if on_platform and not player_ref.is_movement_suppressed:
		var pushed_xz: Vector2 = _resolve_grounded_prop_collisions(hub_xz)
		if pushed_xz.distance_squared_to(hub_xz) > 0.00001:
			hub_xz = pushed_xz
			var corrected_feet_2d: Vector2 = bridge.hub_3d_to_world_2d(Vector3(hub_xz.x, 0.0, hub_xz.y))
			player_ref.global_position = corrected_feet_2d - Vector2(0.0, feet_off_y)

	var want_fly: bool = not on_platform
	if want_fly != _pending_fly_target:
		_pending_fly_target = want_fly
		_hysteresis_timer = 0.0
	elif want_fly != _is_flying:
		_hysteresis_timer += delta
		if _hysteresis_timer >= _layout.traversal_hysteresis_sec:
			_is_flying = want_fly
			var rig_v2: PlayerRigV2Controller = player_ref.get_rig_v2_controller()
			if rig_v2 != null:
				rig_v2.set_hub_traversal_state(_is_flying, false)

	var target_spd: float = _layout.embedded_flight_speed_px if _is_flying else _layout.embedded_walk_speed_px
	player_ref.set_hub_walk_speed_override(target_spd)

	var is_dashing_hub: bool = player_ref.has_method("is_hub_dashing") and bool(player_ref.call("is_hub_dashing"))
	if _has_prev_pos and not _is_flying and not is_dashing_hub and not player_ref.is_movement_suppressed:
		var delta_2d: Vector2 = player_ref.global_position - _prev_player_pos_2d
		var delta_xz_m := Vector2(delta_2d.x / maxf(_px_per_m_x, 1.0), delta_2d.y / maxf(_px_per_m_z, 1.0))
		var dist_m_step: float = delta_xz_m.length()
		if dist_m_step > 0.0005:
			var rig_v2: PlayerRigV2Controller = player_ref.get_rig_v2_controller()
			if rig_v2 != null:
				rig_v2.feed_hub_walk_displacement(dist_m_step)
	_prev_player_pos_2d = player_ref.global_position
	_has_prev_pos = true

	var hover_y: float = _layout.flight_hover_y if _is_flying else _layout.platform_hover_y
	hub_stage.sync_embedded_player_3d(Vector3(hub_xz.x, hover_y, hub_xz.y), player_ref.global_position, _is_flying)

	if hub_stage.is_any_hub_modal_or_panel_open() or is_hub_tutorial_active():
		hub_stage.update_embedded_perimeter_warning(Vector3(hub_xz.x, 0.08, hub_xz.y), Vector2.UP, 0.0, {})
		return

	var dist_m: float = hub_xz.length()
	if dist_m >= _layout.launch_radius:
		launch_combat_seamlessly(hub_xz)
		return

	if dist_m >= _layout.warning_radius:
		var prog: float = clampf((dist_m - _layout.warning_radius) / maxf(_layout.launch_radius - _layout.warning_radius, 0.1), 0.0, 1.0)
		var dir_xz: Vector2 = hub_xz.normalized() if dist_m > 0.001 else Vector2.UP
		var sector: Dictionary = _layout.quantize_departure_sector(dir_xz)
		hub_stage.update_embedded_perimeter_warning(Vector3(hub_xz.x, 0.08, hub_xz.y), dir_xz, prog, sector)
	else:
		hub_stage.update_embedded_perimeter_warning(Vector3(hub_xz.x, 0.08, hub_xz.y), Vector2.UP, 0.0, {})


func _resolve_grounded_prop_collisions(xz: Vector2) -> Vector2:
	var p: Vector2 = xz
	if _config == null:
		return p
	# Capsule rear arch box at (0, -1.16)
	var arch_c: Vector2 = Vector2(_config.capsule_pos.x, _config.capsule_pos.z - 1.16)
	p = _push_out_box_xz(p, arch_c, Vector2(1.75, 0.34))
	# Talents nexus solid monolith at console_left_far_pos
	p = _push_out_box_xz(p, Vector2(_config.console_left_far_pos.x, _config.console_left_far_pos.z), Vector2(1.50, 1.50))
	# Companions & Tactical consoles
	p = _push_out_circle_xz(p, Vector2(_config.console_right_pos.x, _config.console_right_pos.z), 0.72)
	p = _push_out_circle_xz(p, Vector2(_config.console_right_far_pos.x, _config.console_right_far_pos.z), 0.92)
	# Gacha summoner & Telemetry totem
	p = _push_out_circle_xz(p, Vector2(_config.gacha_summoner_pos.x, _config.gacha_summoner_pos.z), 1.62)
	p = _push_out_circle_xz(p, Vector2(_config.telemetry_totem_pos.x, _config.telemetry_totem_pos.z), 0.85)
	return p


static func _push_out_circle_xz(pt: Vector2, center: Vector2, min_r: float) -> Vector2:
	var diff: Vector2 = pt - center
	var d_sq: float = diff.length_squared()
	if d_sq < min_r * min_r:
		var dir: Vector2 = diff.normalized() if d_sq > 0.0001 else Vector2.DOWN
		return center + dir * min_r
	return pt


static func _push_out_box_xz(pt: Vector2, center: Vector2, half_ext: Vector2) -> Vector2:
	var rel: Vector2 = pt - center
	var ox: float = half_ext.x - absf(rel.x)
	var oz: float = half_ext.y - absf(rel.y)
	if ox > 0.0 and oz > 0.0:
		if ox < oz:
			return Vector2(center.x + (half_ext.x if rel.x >= 0.0 else -half_ext.x), pt.y)
		return Vector2(pt.x, center.y + (half_ext.y if rel.y >= 0.0 else -half_ext.y))
	return pt


func launch_combat_seamlessly(departure_hub_xz: Vector2 = Vector2(0.0, -30.5)) -> void:
	if state != SessionState.HUB_ACTIVE or main_game == null:
		return

	_auto_tutorial_token += 1
	if is_hub_tutorial_active():
		tutorial_director.finish_tutorial(true)
	if main_game.has_method("cleanup_title_session_for_combat"):
		main_game.cleanup_title_session_for_combat()

	state = SessionState.DEPARTING_DISSOLVE

	if is_instance_valid(main_game.camera):
		main_game.camera.clear_cinematic_focus()
		main_game.camera.target_zoom = 1.0

	var dir_2d: Vector2 = Vector2(departure_hub_xz.x * _px_per_m_x, departure_hub_xz.y * _px_per_m_z).normalized() if departure_hub_xz.length_squared() > 0.001 else Vector2.UP
	_departure_dir_2d = dir_2d
	_post_launch_exclusion_timer = _layout.embedded_hub_exclusion_post_launch_sec if _layout != null else 6.0
	if active_launch_request == null:
		active_launch_request = RunLaunchRequestScript.create_random_auto()
	if _layout != null:
		var sector_dir_xz: Vector2 = departure_hub_xz.normalized() if departure_hub_xz.length_squared() > 0.001 else Vector2.UP
		var sec_info: Dictionary = _layout.quantize_departure_sector(sector_dir_xz)
		active_launch_request.departure_sector = sec_info.get("id", &"N") as StringName
	active_launch_request.departure_direction = dir_2d
	active_launch_request.seamless_entry = true
	RunLaunchRequestScript.set_last_launched(active_launch_request)

	main_game.active_launch_request = active_launch_request
	main_game.run_director_seed = active_launch_request.run_director_seed
	main_game.run_loot_seed = active_launch_request.run_loot_seed
	main_game.run_seed = active_launch_request.cosmos_seed

	CombatBootstrapperScript.sync_character_loadout()
	if is_instance_valid(main_game.player):
		var player_ref: Player = main_game.player
		player_ref.reapply_meta_progression_for_launch()
		player_ref.is_movement_suppressed = false
		player_ref.set_hub_mode(false)
		var burst_spd: float = _layout.embedded_departure_burst_speed_px if _layout != null else 420.0
		player_ref.velocity = dir_2d * maxf(player_ref.velocity.length(), burst_spd)

		if main_game.chest_director != null and main_game.chest_director.item_pool_manager != null:
			var sel_char_id: StringName = SaveManager.get_selected_character()
			var banned_items: Array[StringName] = SaveManager.get_character_banlist(sel_char_id)
			var unlocked_items: Array[StringName] = SaveManager.get_unlocked_items()
			main_game.chest_director.item_pool_manager.rebuild_run_pool(player_ref.character_data, unlocked_items, banned_items)

		if is_instance_valid(main_game.active_pet):
			main_game.active_pet.set_hub_mode(false)
			main_game.active_pet.refresh_from_save()
		else:
			CombatSceneAssemblerScript.spawn_companion_pet(main_game, player_ref)
			if is_instance_valid(main_game.active_pet):
				main_game.active_pet.global_position = player_ref.global_position + Vector2(-56.0, 36.0)

		player_ref.run_credits += 50

	if main_game.active_navigator_controller != null:
		if main_game.active_navigator_controller.has_method("refresh_navigator_selection"):
			main_game.active_navigator_controller.refresh_navigator_selection()
		if main_game.active_navigator_controller.has_method("set_hub_suppressed"):
			main_game.active_navigator_controller.set_hub_suppressed(false)

	main_game.prologue_bonus_chosen = true
	main_game.is_briefing_active = false
	PauseArbitrator.force_unpause_all()
	Engine.time_scale = SaveManager.get_game_speed()

	CombatBootstrapperScript.initialize_session(main_game, main_game.player, main_game.hud)

	if is_instance_valid(main_game.hud):
		_set_combat_hud_suppressed(false)
		if is_instance_valid(main_game.player) and main_game.player.character_data != null and main_game.hud.has_method("update_pilot_abilities"):
			main_game.hud.update_pilot_abilities(main_game.player.character_data)
		main_game.hud.offset = Vector2(0.0, -24.0)
		var tw: Tween = main_game.create_tween()
		tw.set_parallel(true)
		tw.tween_property(main_game.hud, "offset", Vector2.ZERO, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		for child: Node in main_game.hud.get_children():
			if child is CanvasItem:
				var ci := child as CanvasItem
				var orig_a: float = ci.modulate.a
				ci.modulate.a = 0.0
				tw.tween_property(ci, "modulate:a", orig_a, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	var audio_mgr: Node = get_node_or_null("/root/AudioManager")
	if audio_mgr != null:
		if audio_mgr.has_method("play_music"):
			audio_mgr.play_music("combat")
		if audio_mgr.has_method("set_ambience"):
			audio_mgr.set_ambience("cosmos")

	if is_instance_valid(main_game.player):
		main_game.last_anchor_pos = main_game.player.global_position
	if main_game.crisis_manager != null and main_game.crisis_manager.has_method("set_hub_suppressed"):
		main_game.crisis_manager.set_hub_suppressed(false)
	if main_game.chest_director != null and main_game.chest_director.has_method("set_hub_suppressed"):
		main_game.chest_director.set_hub_suppressed(false)
	if main_game.loot_coordinator != null and main_game.loot_coordinator.has_method("set_hub_suppressed"):
		main_game.loot_coordinator.set_hub_suppressed(false)
	if main_game.satellite_coordinator != null:
		if main_game.satellite_coordinator.has_method("set_hub_suppressed"):
			main_game.satellite_coordinator.set_hub_suppressed(false)
		if is_instance_valid(main_game.player) and main_game.satellite_coordinator.has_method("reset_for_hub_launch"):
			main_game.satellite_coordinator.reset_for_hub_launch(main_game.player.global_position)
	if main_game.space_debris_manager != null:
		if main_game.space_debris_manager.space_object_spawner != null:
			main_game.space_debris_manager.space_object_spawner.set_hub_suppressed(false)
		main_game.space_debris_manager.spawn_environment_actors(main_game)
	main_game._spawn_next_satellite_for_wave()
	if main_game.chest_director != null and is_instance_valid(main_game.player):
		var green_cards: int = main_game.player.inventory.get_item_count(&"credit_card_green") if main_game.player.inventory != null else 0
		main_game.chest_director.on_new_wave(main_game.current_wave, green_cards)
	main_game._spawn_wave_chests()
	if main_game.enemy_spawner != null:
		main_game.enemy_spawner.set_spawning_paused(false)
		main_game.enemy_spawner.trigger_initial_batch()

	if hub_stage != null and is_instance_valid(hub_stage):
		hub_stage.start_embedded_dematerialization(Vector3(departure_hub_xz.x, 0.2, departure_hub_xz.y))
	else:
		_on_hub_demat_finished()


func _on_hub_demat_finished() -> void:
	state = SessionState.COMBAT_LIVE
	if tutorial_director != null and is_instance_valid(tutorial_director):
		tutorial_director.queue_free()
	tutorial_director = null
	if bridge != null and is_instance_valid(bridge):
		bridge.queue_free()
	bridge = null
	if display_sprite != null and is_instance_valid(display_sprite):
		display_sprite.queue_free()
	display_sprite = null
	if hub_stage != null and is_instance_valid(hub_stage):
		hub_stage.queue_free()
	hub_stage = null

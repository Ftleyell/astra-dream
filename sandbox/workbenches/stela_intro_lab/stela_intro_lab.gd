class_name StelaIntroLab
extends Node2D

## Lab Interactivo de Identidad Stela Galactica (Sandbox):
## Reúne sobre UNA única instancia viva de Cosmos Engine:
## 1) Title Screen vivo (StelaLogoStage 4 capas + Normal Map + luz Cosmos + TitleMenuOverlay)
## 2) Transición Singularidad (Big Crunch -> Punto Blanco Vivo -> Big Bang con cambio de universo)
## 3) Secuencia inmersiva Title -> Hub 3D (paneo Cosmos + materialización hexagonal + aterrizaje Valentina)
## 4) Tutorial/Debrief de Mascota en Hub 3D (10 pasos horarios + glow titilante minimalista)

const CosmosEnvScene: PackedScene = preload("res://scenes/combat/environment/cosmos_combat_environment.tscn")
const GameCameraScript = preload("res://scenes/combat/environment/game_camera.gd")
const PlayerScript = preload("res://scenes/combat/player/player.gd")
const WeaponCtrlScript = preload("res://scenes/combat/player/weapon_controller.gd")
const AstralStationHubScript = preload("res://scenes/ui/hub/astral_station/astral_station_hub.gd")
const ViewportBridgeScript = preload("res://scenes/ui/hub/astral_station/components/hub_embedded_viewport_bridge.gd")
const ConfigScript = preload("res://scenes/ui/hub/astral_station/resources/hub_art_lab_config.gd")
const LayoutConfigScript = preload("res://scenes/ui/hub/astral_station/resources/hub_floating_layout_config.gd")
const StationNodeScript = preload("res://scenes/ui/hub/astral_station/components/hub_lab_station_node.gd")
const RunLaunchRequestScript = preload("res://core/systems/run_launch_request.gd")
const CosmicLightingSampleScript = preload("res://scenes/combat/environment/cosmos/core/cosmic_lighting_sample.gd")
const CosmicLightingSamplerScript = preload("res://scenes/combat/environment/cosmos/core/cosmic_lighting_sampler.gd")

const StelaLogoStageScript = preload("res://scenes/ui/title_screen/components/stela_logo_stage.gd")
const TitleMenuOverlayScript = preload("res://scenes/ui/title_screen/components/title_menu_overlay.gd")
const SingularityPresenterScript = preload("res://core/systems/singularity_transition_presenter.gd")
const HubTutorialDirectorScript = preload("res://scenes/ui/hub/astral_station/components/hub_tutorial_director.gd")

const LogoVfxConfigScript = preload("res://data/ui/stela_logo_vfx_config.gd")
const DEFAULT_LOGO_CFG_PATH: String = "res://data/ui/default_stela_logo_vfx_config.tres"
const SingularityConfigScript = preload("res://data/ui/singularity_transition_config.gd")
const DEFAULT_SING_CFG_PATH: String = "res://data/ui/default_singularity_transition_config.tres"
const DEFAULT_TUT_CFG_PATH: String = "res://data/hub/default_hub_tutorial_sequence.tres"
const SeqConfigScript = preload("res://data/ui/title_to_hub_sequence_config.gd")
const DEFAULT_SEQ_CFG: SeqConfigScript = preload("res://data/ui/default_title_to_hub_sequence_config.tres")
const SettingsModalScene: PackedScene = preload("res://scenes/ui/settings_modal/settings_modal.tscn")
const WORKBENCH_HUB_PATH: String = "res://sandbox/workbenches/workbench_hub.tscn"

enum LabMode {
	TITLE_ACTIVE = 0,
	TRANSITIONING_TO_HUB = 1,
	HUB_ACTIVE = 2,
}

const HUB_ORIGIN_2D := Vector2(960.0, 540.0)

var mode: LabMode = LabMode.TITLE_ACTIVE
var cosmos_env: CosmosCombatEnvironment = null
var cosmos_root: CosmosRootNode = null
var camera: GameCamera2D = null
var player: Player = null
var hub_stage: AstralStationHub = null
var bridge: HubEmbeddedViewportBridge = null
var display_sprite: Sprite2D = null

var title_layer: CanvasLayer = null
var logo_stage: StelaLogoStageScript = null
var title_menu: TitleMenuOverlayScript = null
var settings_modal: SettingsModal = null
var singularity_presenter: SingularityPresenterScript = null
var tutorial_director: HubTutorialDirectorScript = null

var logo_config: LogoVfxConfigScript = null
var singularity_config: SingularityConfigScript = null
var sequence_config: SeqConfigScript = DEFAULT_SEQ_CFG

var _hub_config: ConfigScript = null
var _hub_layout: LayoutConfigScript = null
var _lighting_sample: CosmicLightingSampleScript = CosmicLightingSampleScript.new()
var _title_cam_anchor: Vector2 = HUB_ORIGIN_2D + Vector2(-520.0, -280.0)
var _current_seed: int = 428175
var _is_flying_hub: bool = false
var _pending_fly_hub: bool = false
var _hyst_timer: float = 0.0
var _prev_player_pos: Vector2 = Vector2.ZERO
var _has_prev_pos: bool = false
var _px_per_m_x: float = 84.0
var _px_per_m_z: float = 60.424
var _stations_calibrating: bool = false
var _selected_pet_id: StringName = &"mochi"

# Dev Panel UI
var _dev_layer: CanvasLayer = null
var _dev_panel: PanelContainer = null
var _status_lbl: Label = null
var _logo_sliders: Dictionary = {}
var _sing_sliders: Dictionary = {}
var _active_transition_tween: Tween = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	PauseArbitrator.force_unpause_all()
	Engine.time_scale = 1.0

	logo_config = (load(DEFAULT_LOGO_CFG_PATH) as LogoVfxConfigScript).duplicate(true) as LogoVfxConfigScript
	singularity_config = (load(DEFAULT_SING_CFG_PATH) as SingularityConfigScript).duplicate(true) as SingularityConfigScript
	if sequence_config == null:
		sequence_config = SeqConfigScript.new()

	_build_world_stack()
	_build_title_ui()
	_build_singularity_and_tutorial()
	_build_dev_panel()
	enter_title_mode(true)


func _build_world_stack() -> void:
	cosmos_env = CosmosEnvScene.instantiate() as CosmosCombatEnvironment
	cosmos_env.name = "SpaceBackground"
	add_child(cosmos_env)
	cosmos_root = cosmos_env.get_cosmos_root()

	camera = GameCameraScript.new() as GameCamera2D
	camera.name = "GameCamera2D"
	camera.position = HUB_ORIGIN_2D
	add_child(camera)
	camera.make_current()

	if cosmos_root != null:
		cosmos_root.camera = camera
		cosmos_root.bind_camera_to_streamers()
		cosmos_env.set_environment_seed(_current_seed)

	# Jugador real Valentina v2 en modo Hub
	player = PlayerScript.new() as Player
	player.name = "Player"
	player.position = HUB_ORIGIN_2D + Vector2(0.0, 210.0)
	var col_shape := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 5.0
	col_shape.shape = circ
	player.add_child(col_shape)
	var w_ctrl := WeaponCtrlScript.new() as WeaponController
	w_ctrl.name = "WeaponController"
	w_ctrl.player = player
	player.add_child(w_ctrl)
	add_child(player)

	var req: RunLaunchRequestScript = RunLaunchRequestScript.create(_current_seed, RunLaunchRequestScript.SeedMode.AUTO)
	var rig_v2: Node = player.get_rig_v2_controller()

	hub_stage = AstralStationHubScript.new() as AstralStationHub
	hub_stage.name = "EmbeddedAstralStationHub"
	hub_stage.configure_embedded(req, rig_v2, cosmos_root)
	hub_stage.set_embedded_cosmos_anchor_2d(HUB_ORIGIN_2D)
	add_child(hub_stage)

	_hub_config = hub_stage.config
	_hub_layout = hub_stage.layout_config

	var feet_off_y: float = _hub_layout.embedded_feet_offset_y_px if _hub_layout != null else 54.0
	player.set_hub_mode(true, feet_off_y)
	if _hub_layout != null:
		player.set_hub_walk_speed_override(_hub_layout.embedded_walk_speed_px)
		player.configure_hub_motion(
			_hub_layout.embedded_hub_accel,
			_hub_layout.embedded_hub_friction,
			_hub_layout.embedded_hub_pivot_brake_mul,
			_hub_layout.embedded_hub_dash_speed_px,
			_hub_layout.embedded_hub_dash_duration_sec,
			_hub_layout.embedded_hub_dash_cooldown_sec
		)
		if rig_v2 != null:
			rig_v2.set_hub_speed_refs(_hub_layout.embedded_walk_speed_px, _hub_layout.embedded_flight_speed_px)

	display_sprite = Sprite2D.new()
	display_sprite.name = "Hub3DDisplaySprite"
	display_sprite.centered = true
	display_sprite.z_as_relative = false
	display_sprite.z_index = 3
	var vp_3d: SubViewport = hub_stage.get_world_3d_viewport()
	if vp_3d != null:
		display_sprite.texture = vp_3d.get_texture()
	add_child(display_sprite)

	bridge = ViewportBridgeScript.new() as HubEmbeddedViewportBridge
	bridge.name = "HubEmbeddedViewportBridge"
	add_child(bridge)
	bridge.setup(HUB_ORIGIN_2D, _hub_config, _hub_layout, camera, hub_stage.get_camera_3d(), vp_3d, display_sprite)
	_px_per_m_x = bridge.get_px_per_meter_x()
	var pitch_deg: float = absf(_hub_config.free_roam_pitch_deg) if _hub_config != null else 46.0
	_px_per_m_z = _px_per_m_x * maxf(sin(deg_to_rad(pitch_deg)), 0.1)

	_connect_hub_signals()


func _connect_hub_signals() -> void:
	hub_stage.embedded_launch_request_changed.connect(func(req: RunLaunchRequestScript, trigger_flash: bool) -> void:
		if req != null:
			_current_seed = req.cosmos_seed
			cosmos_env.set_environment_seed(_current_seed)
			if trigger_flash and bridge != null:
				bridge.trigger_retune_flash(0.32)
	)
	hub_stage.embedded_camera_focus_changed.connect(func(cam_mode: int, focus_3d: Vector3) -> void:
		if cam_mode == 0:
			camera.clear_cinematic_focus()
			camera.target_zoom = 1.0
		else:
			var feet_off_y: float = _hub_layout.embedded_feet_offset_y_px if _hub_layout != null else 54.0
			var focus_2d: Vector2 = bridge.hub_3d_to_world_2d(focus_3d) - Vector2(0.0, feet_off_y * 0.65)
			camera.set_cinematic_focus(focus_2d, 1.45)
	)
	hub_stage.embedded_movement_lock_changed.connect(func(locked: bool) -> void:
		player.is_movement_suppressed = locked
		if locked:
			player.velocity = Vector2.ZERO
	)
	hub_stage.embedded_player_reposition_requested.connect(func(world_3d: Vector3, face_dir: Vector2, suppress_shadow: bool) -> void:
		var feet_off_y: float = _hub_layout.embedded_feet_offset_y_px if _hub_layout != null else 54.0
		var target_2d: Vector2 = bridge.hub_3d_to_world_2d(world_3d) - Vector2(0.0, feet_off_y)
		player.global_position = target_2d
		player.velocity = Vector2.ZERO
		_prev_player_pos = target_2d
		var rv2: PlayerRigV2Controller = player.get_rig_v2_controller()
		if rv2 != null:
			rv2.set_hub_pose_override(true, face_dir, true)
			rv2.set_hub_shadow_suppressed(suppress_shadow)
	)
	hub_stage.embedded_pilot_selected.connect(func(char_id: StringName, _col: Color) -> void:
		player.reload_character_for_hub(char_id)
		hub_stage.set_embedded_player_rig_v2(player.get_rig_v2_controller())
	)
	hub_stage.embedded_gacha_skin_equipped.connect(func(equip_res: Dictionary) -> void:
		var rv2: PlayerRigV2Controller = player.get_rig_v2_controller()
		var preset: PilotSkinPreset = equip_res.get("preset", null) as PilotSkinPreset
		if rv2 != null and preset != null:
			rv2.apply_live_gacha_skin(str(equip_res.get("category", "pilot")), preset, int(equip_res.get("star_level", 1)))
	)


func _build_title_ui() -> void:
	title_layer = CanvasLayer.new()
	title_layer.name = "TitleScreenLayer"
	title_layer.layer = 20
	add_child(title_layer)

	logo_stage = StelaLogoStageScript.new() as StelaLogoStageScript
	logo_stage.name = "StelaLogoStage"
	logo_stage.set_anchors_preset(Control.PRESET_CENTER)
	logo_stage.offset_left = -420.0
	logo_stage.offset_top = -390.0
	logo_stage.offset_right = 420.0
	logo_stage.offset_bottom = 180.0
	logo_stage.apply_config(logo_config)
	title_layer.add_child(logo_stage)

	title_menu = TitleMenuOverlayScript.new() as TitleMenuOverlayScript
	title_menu.name = "TitleMenuOverlay"
	title_menu.set_continue_available(false)
	title_layer.add_child(title_menu)

	title_menu.play_requested.connect(func() -> void:
		play_title_to_hub_sequence()
	)
	title_menu.settings_requested.connect(_open_settings_modal)
	title_menu.quit_requested.connect(return_to_workbench_hub)
	title_menu.patch_notes_requested.connect(func() -> void:
		if hub_stage != null and hub_stage.hud != null:
			hub_stage.hud.show_toast("STELA GALACTICA // ALPHA 0.1", "Lab de Identidad: Logo Cel + Singularidad + Hub 3D + Guía Mochi", Color(0.24, 0.94, 1.0, 1.0))
	)


func _open_settings_modal() -> void:
	if settings_modal == null and SettingsModalScene != null:
		var layer_s := CanvasLayer.new()
		layer_s.layer = 65
		add_child(layer_s)
		settings_modal = SettingsModalScene.instantiate() as SettingsModal
		layer_s.add_child(settings_modal)
		settings_modal.visible = false
	if settings_modal != null:
		settings_modal.visible = true
		if settings_modal.has_method("open"):
			settings_modal.call("open")


func _build_singularity_and_tutorial() -> void:
	singularity_presenter = SingularityPresenterScript.new() as SingularityPresenterScript
	singularity_presenter.name = "SingularityTransitionPresenter"
	singularity_presenter.apply_config(singularity_config)
	add_child(singularity_presenter)

	tutorial_director = HubTutorialDirectorScript.new() as HubTutorialDirectorScript
	tutorial_director.name = "HubTutorialDirector"
	add_child(tutorial_director)
	tutorial_director.setup(hub_stage, bridge, camera)
	tutorial_director.step_changed.connect(func(_idx: int, _step: Resource) -> void:
		_update_status_text()
	)
	tutorial_director.tutorial_finished.connect(func(_skipped: bool) -> void:
		_update_status_text()
	)


func enter_title_mode(play_reveal: bool = true) -> void:
	if _active_transition_tween != null and _active_transition_tween.is_valid():
		_active_transition_tween.kill()
	if tutorial_director != null and tutorial_director.is_active():
		tutorial_director.finish_tutorial(true)

	mode = LabMode.TITLE_ACTIVE
	_title_cam_anchor = HUB_ORIGIN_2D + sequence_config.title_camera_offset_px
	camera.target = null
	camera.set_cinematic_focus(_title_cam_anchor, sequence_config.title_camera_zoom)
	camera.global_position = _title_cam_anchor
	camera.zoom = Vector2(sequence_config.title_camera_zoom, sequence_config.title_camera_zoom)

	player.visible = false
	player.is_movement_suppressed = true
	player.velocity = Vector2.ZERO
	display_sprite.visible = false
	hub_stage.set_embedded_hidden_for_materialization()

	title_layer.visible = true
	if play_reveal:
		logo_stage.play_entrance()
		title_menu.show_menu(true)
	else:
		logo_stage.reset_visible()
		title_menu.show_menu(false)
	_update_status_text()


func play_title_to_hub_sequence() -> void:
	if mode == LabMode.TRANSITIONING_TO_HUB:
		return
	if tutorial_director != null and tutorial_director.is_active():
		tutorial_director.finish_tutorial(true)

	mode = LabMode.TRANSITIONING_TO_HUB
	_update_status_text()

	title_menu.hide_menu(true)
	logo_stage.play_dissolve_to_hub()

	if _active_transition_tween != null and _active_transition_tween.is_valid():
		_active_transition_tween.kill()

	var spawn_3d: Vector3 = _hub_config.player_spawn_pos if _hub_config != null else Vector3(0.0, 0.02, 4.35)
	var feet_off_y: float = _hub_layout.embedded_feet_offset_y_px if _hub_layout != null else 54.0
	var spawn_2d: Vector2 = bridge.hub_3d_to_world_2d(spawn_3d) - Vector2(0.0, feet_off_y)
	var fly_start_2d: Vector2 = spawn_2d + sequence_config.pilot_flyin_start_offset_px

	player.visible = false
	player.is_movement_suppressed = true
	player.velocity = Vector2.ZERO
	player.global_position = fly_start_2d

	_active_transition_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	# 1. Deslizar cámara por el Cosmos hacia el Hub
	_active_transition_tween.tween_callback(func() -> void:
		camera.set_cinematic_focus(spawn_2d, 1.0)
	).set_delay(0.18)

	# 2. Materializar Estación Astral del centro hacia afuera
	_active_transition_tween.tween_callback(func() -> void:
		display_sprite.visible = true
		hub_stage.play_embedded_materialization(sequence_config.station_materialize_duration_sec)
	).set_delay(sequence_config.station_materialize_delay_sec)

	# 3. Valentina entra volando con Alas 3D y aterriza en plataforma central con ripple
	_active_transition_tween.tween_callback(func() -> void:
		player.visible = true
		var rv2: PlayerRigV2Controller = player.get_rig_v2_controller()
		if rv2 != null:
			rv2.set_hub_traversal_state(true, true)
			rv2.set_hub_pose_override(true, Vector2.DOWN, true)
		var fly_tw: Tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		fly_tw.tween_property(player, "global_position", spawn_2d, sequence_config.pilot_flyin_duration_sec) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		fly_tw.tween_callback(_on_pilot_landed_in_hub)
	).set_delay(sequence_config.pilot_flyin_delay_sec)


func _on_pilot_landed_in_hub() -> void:
	mode = LabMode.HUB_ACTIVE
	_is_flying_hub = false
	_pending_fly_hub = false
	_prev_player_pos = player.global_position
	_has_prev_pos = true

	var rv2: PlayerRigV2Controller = player.get_rig_v2_controller()
	if rv2 != null:
		rv2.set_hub_pose_override(false)
		rv2.set_hub_traversal_state(false, false)
		var ripples: Node = rv2.get_node_or_null("HubLandingRippleVFX")
		if ripples != null and ripples.has_method("spawn_ripple"):
			var feet_off_y: float = _hub_layout.embedded_feet_offset_y_px if _hub_layout != null else 54.0
			ripples.call("spawn_ripple", player.global_position + Vector2(0.0, feet_off_y), Color(0.24, 0.94, 1.0, 1.0), 86.0, 0.55, 1.25, 14)

	player.is_movement_suppressed = false
	camera.target = player
	camera.clear_cinematic_focus()
	camera.target_zoom = 1.0
	if hub_stage.hud != null:
		hub_stage.hud.set_clean_hud_visible(true)
	_update_status_text()


func play_materialization_only() -> void:
	if mode == LabMode.TITLE_ACTIVE:
		title_layer.visible = false
	mode = LabMode.HUB_ACTIVE
	display_sprite.visible = true
	player.visible = true
	player.is_movement_suppressed = false
	var spawn_3d: Vector3 = _hub_config.player_spawn_pos if _hub_config != null else Vector3(0.0, 0.02, 4.35)
	var feet_off_y: float = _hub_layout.embedded_feet_offset_y_px if _hub_layout != null else 54.0
	player.global_position = bridge.hub_3d_to_world_2d(spawn_3d) - Vector2(0.0, feet_off_y)
	camera.target = player
	camera.clear_cinematic_focus()
	hub_stage.set_embedded_hidden_for_materialization()
	hub_stage.play_embedded_materialization(sequence_config.station_materialize_duration_sec)
	_update_status_text()


func trigger_singularity_test(hold_sec: float) -> void:
	if singularity_presenter == null or singularity_presenter.is_transition_active():
		return
	singularity_presenter.apply_config(singularity_config)
	singularity_presenter.play_custom_transition(func() -> void:
		_reroll_cosmos_seed()
		if is_inside_tree():
			await get_tree().create_timer(hold_sec, true, false, true).timeout
	, hold_sec)


func _reroll_cosmos_seed() -> void:
	_current_seed = maxi(1, int(randi()) & 0x7FFFFFFF)
	if cosmos_env != null:
		cosmos_env.set_environment_seed(_current_seed)
	if hub_stage != null:
		hub_stage.apply_launch_request(RunLaunchRequestScript.create(_current_seed, RunLaunchRequestScript.SeedMode.AUTO), false)
	_update_status_text()


func _process(delta: float) -> void:
	if mode == LabMode.TITLE_ACTIVE:
		_title_cam_anchor += sequence_config.title_cosmos_drift_speed * delta
		camera.set_cinematic_focus(_title_cam_anchor, sequence_config.title_camera_zoom)
		if cosmos_root != null and logo_stage != null:
			_lighting_sample = CosmicLightingSamplerScript.sample_at(cosmos_root, _title_cam_anchor, null, _lighting_sample)
			logo_stage.sync_cosmic_lighting(_lighting_sample)


func _physics_process(delta: float) -> void:
	if mode != LabMode.HUB_ACTIVE or not is_instance_valid(player) or bridge == null or hub_stage == null or _hub_layout == null:
		return
	var feet_off_y: float = _hub_layout.embedded_feet_offset_y_px
	var feet_2d: Vector2 = player.global_position + Vector2(0.0, feet_off_y)
	var hub_xz: Vector2 = bridge.world_2d_to_hub_xz(feet_2d)

	var on_platform: bool = _hub_layout.is_point_on_platform(hub_xz)
	var want_fly: bool = not on_platform
	if want_fly != _pending_fly_hub:
		_pending_fly_hub = want_fly
		_hyst_timer = 0.0
	elif want_fly != _is_flying_hub:
		_hyst_timer += delta
		if _hyst_timer >= _hub_layout.traversal_hysteresis_sec:
			_is_flying_hub = want_fly
			var rv2: PlayerRigV2Controller = player.get_rig_v2_controller()
			if rv2 != null:
				rv2.set_hub_traversal_state(_is_flying_hub, false)

	var target_spd: float = _hub_layout.embedded_flight_speed_px if _is_flying_hub else _hub_layout.embedded_walk_speed_px
	player.set_hub_walk_speed_override(target_spd)

	var is_dashing_hub: bool = player.has_method("is_hub_dashing") and bool(player.call("is_hub_dashing"))
	if _has_prev_pos and not _is_flying_hub and not is_dashing_hub and not player.is_movement_suppressed:
		var delta_2d: Vector2 = player.global_position - _prev_player_pos
		var dist_m: float = Vector2(delta_2d.x / maxf(_px_per_m_x, 1.0), delta_2d.y / maxf(_px_per_m_z, 1.0)).length()
		if dist_m > 0.0005:
			var rv2: PlayerRigV2Controller = player.get_rig_v2_controller()
			if rv2 != null:
				rv2.feed_hub_walk_displacement(dist_m)
	_prev_player_pos = player.global_position
	_has_prev_pos = true

	var hover_y: float = _hub_layout.flight_hover_y if _is_flying_hub else _hub_layout.platform_hover_y
	hub_stage.sync_embedded_player_3d(Vector3(hub_xz.x, hover_y, hub_xz.y), player.global_position, _is_flying_hub)


func _unhandled_input(event: InputEvent) -> void:
	var key_ev := event as InputEventKey
	if key_ev != null and key_ev.pressed and not key_ev.echo:
		if key_ev.keycode == KEY_H and _dev_panel != null:
			_dev_panel.visible = not _dev_panel.visible
			get_viewport().set_input_as_handled()
		elif key_ev.keycode == KEY_F1 and mode == LabMode.HUB_ACTIVE:
			_start_tutorial_from_lab()
			get_viewport().set_input_as_handled()


func _start_tutorial_from_lab(start_step: int = 0) -> void:
	if mode != LabMode.HUB_ACTIVE:
		play_materialization_only()
	tutorial_director.start_tutorial(_selected_pet_id)
	if start_step > 0:
		tutorial_director.go_to_step(start_step)
	_update_status_text()


func _build_dev_panel() -> void:
	_dev_layer = CanvasLayer.new()
	_dev_layer.name = "StelaIntroLabDevLayer"
	_dev_layer.layer = 55
	add_child(_dev_layer)

	_dev_panel = PanelContainer.new()
	_dev_panel.name = "DevLabPanel"
	_dev_panel.anchor_left = 1.0
	_dev_panel.anchor_right = 1.0
	_dev_panel.offset_left = -396.0
	_dev_panel.offset_top = 14.0
	_dev_panel.offset_right = -14.0
	_dev_panel.offset_bottom = 680.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.038, 0.052, 0.112, 0.92)
	sb.border_color = Color(0.95, 0.80, 0.34, 0.90)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(12)
	_dev_panel.add_theme_stylebox_override("panel", sb)
	_dev_layer.add_child(_dev_panel)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dev_panel.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(vbox)

	var header := Label.new()
	header.text = "STELA INTRO & IDENTITY LAB  ([H] Ocultar)"
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", Color(0.95, 0.80, 0.34, 1.0))
	vbox.add_child(header)

	_status_lbl = Label.new()
	_status_lbl.add_theme_font_size_override("font_size", 11)
	_status_lbl.add_theme_color_override("font_color", Color(0.24, 0.94, 1.0, 1.0))
	vbox.add_child(_status_lbl)

	# --- Sección 1: Logo & Cosmos ---
	_add_sec_title(vbox, "1. Logo Cel + Normal + Cosmos")
	var row1 := HBoxContainer.new()
	vbox.add_child(row1)
	_add_btn(row1, "Replay Reveal", func() -> void:
		if mode != LabMode.TITLE_ACTIVE:
			enter_title_mode(true)
		else:
			logo_stage.play_entrance()
	)
	_add_btn(row1, "Reroll Cosmos", _reroll_cosmos_seed)
	_add_btn(row1, "Guardar .tres", func() -> void:
		ResourceSaver.save(logo_config, DEFAULT_LOGO_CFG_PATH)
	)

	_add_logo_slider(vbox, "normal_strength", "Normal Strength", 0.0, 2.0, 0.05)
	_add_logo_slider(vbox, "cel_shadow_threshold", "Cel Shadow Thresh", -0.3, 0.6, 0.02)
	_add_logo_slider(vbox, "cel_spec_threshold", "Cel Spec Thresh", 0.3, 0.96, 0.02)
	_add_logo_slider(vbox, "cosmos_light_mix", "Cosmos Light Mix", 0.0, 1.0, 0.05)
	_add_logo_slider(vbox, "slash_intensity", "Slash Glow", 0.0, 2.5, 0.05)
	_add_logo_slider(vbox, "slash_flow_speed", "Slash Speed", 0.0, 6.0, 0.1)
	_add_logo_slider(vbox, "medallion_rotation_speed", "Medallion Spin", -0.5, 0.5, 0.02)
	_add_logo_slider(vbox, "astrolabe_alpha", "Rings Alpha", 0.0, 1.0, 0.05)

	# --- Sección 2: Singularidad ---
	_add_sec_title(vbox, "2. Transición Singularidad (Reinicio Universo)")
	var row2 := HBoxContainer.new()
	vbox.add_child(row2)
	_add_btn(row2, "Carga 0.3s", func() -> void: trigger_singularity_test(0.3))
	_add_btn(row2, "Carga 1.5s", func() -> void: trigger_singularity_test(1.5))
	_add_btn(row2, "Carga 3.0s", func() -> void: trigger_singularity_test(3.0))
	_add_btn(row2, "Guardar .tres", func() -> void:
		ResourceSaver.save(singularity_config, DEFAULT_SING_CFG_PATH)
	)
	_add_sing_slider(vbox, "crunch_duration_sec", "Crunch Dur (s)", 0.15, 1.2, 0.02)
	_add_sing_slider(vbox, "big_bang_duration_sec", "BigBang Dur (s)", 0.2, 1.5, 0.02)
	_add_sing_slider(vbox, "swirl_strength", "Swirl", 0.0, 6.0, 0.1)
	_add_sing_slider(vbox, "chromatic_aberration", "Chromatic Ab.", 0.0, 0.1, 0.005)
	_add_sing_slider(vbox, "anamorphic_flare_intensity", "Flare", 0.0, 2.8, 0.05)

	# --- Sección 3: Title -> Hub ---
	_add_sec_title(vbox, "3. Secuencia Inmersiva Title → Hub 3D")
	var row3 := HBoxContainer.new()
	vbox.add_child(row3)
	_add_btn(row3, "Reset Title", func() -> void: enter_title_mode(true))
	_add_btn(row3, "Play Title→Hub", play_title_to_hub_sequence)
	_add_btn(row3, "Materializar Solo", play_materialization_only)

	# --- Sección 4: Tutorial Pet ---
	_add_sec_title(vbox, "4. Tutorial Mascota en Hub 3D [F1]")
	var row4 := HBoxContainer.new()
	vbox.add_child(row4)
	_add_btn(row4, "Tour Completo", func() -> void: _start_tutorial_from_lab(0))
	_add_btn(row4, "Saltar", func() -> void: tutorial_director.finish_tutorial(true))
	_add_btn(row4, "Toggle Calibr.", func() -> void:
		_stations_calibrating = not _stations_calibrating
		var st: int = StationNodeScript.StationState.CALIBRATING if _stations_calibrating else StationNodeScript.StationState.ONLINE
		hub_stage.set_all_stations_state_override(st as StationNodeScript.StationState)
		_update_status_text()
	)

	var pet_row := HBoxContainer.new()
	vbox.add_child(pet_row)
	var pet_lbl := Label.new()
	pet_lbl.text = "Pet:"
	pet_lbl.add_theme_font_size_override("font_size", 11)
	pet_row.add_child(pet_lbl)
	var pet_opt := OptionButton.new()
	pet_opt.focus_mode = Control.FOCUS_NONE
	pet_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pets: Array[StringName] = [&"mochi", &"kuro", &"luna", &"pip", &"cosmo"]
	for p: StringName in pets:
		pet_opt.add_item(String(p).capitalize())
	pet_opt.item_selected.connect(func(idx: int) -> void:
		_selected_pet_id = pets[clampi(idx, 0, pets.size() - 1)]
		if tutorial_director != null:
			tutorial_director.set_pet_id(_selected_pet_id)
	)
	pet_row.add_child(pet_opt)

	var steps_grid := GridContainer.new()
	steps_grid.columns = 5
	vbox.add_child(steps_grid)
	for i: int in range(10):
		var step_idx: int = i
		var sb_btn := Button.new()
		sb_btn.text = "%d" % (i + 1)
		sb_btn.focus_mode = Control.FOCUS_NONE
		sb_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sb_btn.pressed.connect(func() -> void: _start_tutorial_from_lab(step_idx))
		steps_grid.add_child(sb_btn)

	_add_tut_slider(vbox, "spotlight_blur_strength", "Foco Blur", 0.0, 5.0, 0.1)
	_add_tut_slider(vbox, "spotlight_dim_strength", "Foco Oscuridad", 0.0, 0.90, 0.02)
	_add_tut_slider(vbox, "spotlight_softness", "Foco Suavidad", 0.04, 0.35, 0.01)

	var tut_save_row := HBoxContainer.new()
	vbox.add_child(tut_save_row)
	_add_btn(tut_save_row, "Guardar Tutorial .tres", func() -> void:
		if tutorial_director != null and tutorial_director.sequence_config != null:
			ResourceSaver.save(tutorial_director.sequence_config, DEFAULT_TUT_CFG_PATH)
			_update_status_text()
	)

	var back_btn := Button.new()
	back_btn.text = "← Volver a WorkbenchHub"
	back_btn.focus_mode = Control.FOCUS_NONE
	back_btn.pressed.connect(return_to_workbench_hub)
	vbox.add_child(back_btn)

	_update_status_text()


func _add_sec_title(parent: Control, txt: String) -> void:
	var lbl := Label.new()
	lbl.text = txt
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.95, 0.80, 0.34, 1.0))
	parent.add_child(lbl)


func _add_btn(parent: Control, txt: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = txt
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 11)
	b.pressed.connect(cb)
	parent.add_child(b)


func _add_logo_slider(parent: Control, prop: String, label_txt: String, min_v: float, max_v: float, step_v: float) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var lbl := Label.new()
	lbl.text = label_txt
	lbl.custom_minimum_size = Vector2(130.0, 0.0)
	lbl.add_theme_font_size_override("font_size", 11)
	row.add_child(lbl)
	var sl := HSlider.new()
	sl.min_value = min_v
	sl.max_value = max_v
	sl.step = step_v
	sl.value = float(logo_config.get(prop))
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.focus_mode = Control.FOCUS_NONE
	sl.value_changed.connect(func(v: float) -> void:
		logo_config.set(prop, v)
		logo_stage.apply_config(logo_config)
	)
	row.add_child(sl)
	_logo_sliders[prop] = sl


func _add_sing_slider(parent: Control, prop: String, label_txt: String, min_v: float, max_v: float, step_v: float) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var lbl := Label.new()
	lbl.text = label_txt
	lbl.custom_minimum_size = Vector2(130.0, 0.0)
	lbl.add_theme_font_size_override("font_size", 11)
	row.add_child(lbl)
	var sl := HSlider.new()
	sl.min_value = min_v
	sl.max_value = max_v
	sl.step = step_v
	sl.value = float(singularity_config.get(prop))
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.focus_mode = Control.FOCUS_NONE
	sl.value_changed.connect(func(v: float) -> void:
		singularity_config.set(prop, v)
		singularity_presenter.apply_config(singularity_config)
	)
	row.add_child(sl)
	_sing_sliders[prop] = sl


func _add_tut_slider(parent: Control, prop: String, label_txt: String, min_v: float, max_v: float, step_v: float) -> void:
	if tutorial_director == null or tutorial_director.sequence_config == null:
		return
	var row := HBoxContainer.new()
	parent.add_child(row)
	var lbl := Label.new()
	lbl.text = label_txt
	lbl.custom_minimum_size = Vector2(130.0, 0.0)
	lbl.add_theme_font_size_override("font_size", 11)
	row.add_child(lbl)
	var sl := HSlider.new()
	sl.min_value = min_v
	sl.max_value = max_v
	sl.step = step_v
	sl.value = float(tutorial_director.sequence_config.get(prop))
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.focus_mode = Control.FOCUS_NONE
	sl.value_changed.connect(func(v: float) -> void:
		if tutorial_director != null and tutorial_director.sequence_config != null:
			tutorial_director.sequence_config.set(prop, v)
			tutorial_director.refresh_spotlight_style()
	)
	row.add_child(sl)


func _update_status_text() -> void:
	if _status_lbl == null:
		return
	var m_names: Array[String] = ["TITLE_ACTIVE", "TRANSITIONING_TO_HUB", "HUB_ACTIVE"]
	var tut_txt: String = ("TUTORIAL %d/%d" % [tutorial_director.get_current_step_index() + 1, tutorial_director.get_step_count()]) if (tutorial_director != null and tutorial_director.is_active()) else "IDLE"
	var st_txt: String = "CALIBRATING" if _stations_calibrating else "ONLINE"
	_status_lbl.text = "Modo: %s · Seed: %d · Est: %s · Guía: %s" % [m_names[int(mode)], _current_seed, st_txt, tut_txt]


func return_to_workbench_hub() -> void:
	if is_inside_tree() and ResourceLoader.exists(WORKBENCH_HUB_PATH):
		get_tree().change_scene_to_file(WORKBENCH_HUB_PATH)

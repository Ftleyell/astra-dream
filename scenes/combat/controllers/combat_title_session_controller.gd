class_name CombatTitleSessionController
extends Node

## Orquestador desacoplado de la Pantalla de Título viva (StelaLogoStage + TitleMenuOverlay)
## y de la secuencia inmersiva Title -> Hub 3D sobre la misma instancia de Cosmos Engine en MainGame.

enum TitleState {
	INACTIVE = 0,
	TITLE_ACTIVE = 1,
	HUB_MATERIALIZING = 2,
}

const StelaLogoStageScript = preload("res://scenes/ui/title_screen/components/stela_logo_stage.gd")
const TitleMenuOverlayScript = preload("res://scenes/ui/title_screen/components/title_menu_overlay.gd")
const LogoVfxConfigScript = preload("res://data/ui/stela_logo_vfx_config.gd")
const DEFAULT_LOGO_CFG: LogoVfxConfigScript = preload("res://data/ui/default_stela_logo_vfx_config.tres")
const SeqConfigScript = preload("res://data/ui/title_to_hub_sequence_config.gd")
const DEFAULT_SEQ_CFG: SeqConfigScript = preload("res://data/ui/default_title_to_hub_sequence_config.tres")
const CosmicLightingSampleScript = preload("res://scenes/combat/environment/cosmos/core/cosmic_lighting_sample.gd")
const CosmicLightingSamplerScript = preload("res://scenes/combat/environment/cosmos/core/cosmic_lighting_sampler.gd")
const RunLaunchRequestScript = preload("res://core/systems/run_launch_request.gd")
const SaveManagerScript = preload("res://core/autoloads/save_manager.gd")
const CombatHubSessionControllerScript = preload("res://scenes/combat/controllers/combat_hub_session_controller.gd")
const ViewportBridgeScript = preload("res://scenes/ui/hub/astral_station/components/hub_embedded_viewport_bridge.gd")
const ConfigScript = preload("res://scenes/ui/hub/astral_station/resources/hub_art_lab_config.gd")
const LayoutConfigScript = preload("res://scenes/ui/hub/astral_station/resources/hub_floating_layout_config.gd")

const SettingsModalScene: PackedScene = preload("res://scenes/ui/settings_modal/settings_modal.tscn")
const PatchNotesScene: PackedScene = preload("res://scenes/ui/title_screen/patch_notes_panel.tscn")

var state: TitleState = TitleState.INACTIVE
var main_game: MainGame = null
var hub_ctrl: CombatHubSessionControllerScript = null
var sequence_config: SeqConfigScript = DEFAULT_SEQ_CFG

var title_layer: CanvasLayer = null
var logo_stage: StelaLogoStageScript = null
var title_menu: TitleMenuOverlayScript = null

var _settings_layer: CanvasLayer = null
var _settings_modal: SettingsModal = null
var _patch_notes_layer: CanvasLayer = null
var _lighting_sample: CosmicLightingSampleScript = CosmicLightingSampleScript.new()
var _title_cam_anchor: Vector2 = Vector2(960.0, 540.0)
var _time_acc: float = 0.0
var _active_transition_tween: Tween = null


func is_active() -> bool:
	return state == TitleState.TITLE_ACTIVE or state == TitleState.HUB_MATERIALIZING


func is_title_active() -> bool:
	return state == TitleState.TITLE_ACTIVE


func is_materializing_hub() -> bool:
	return state == TitleState.HUB_MATERIALIZING


func get_logo_stage() -> StelaLogoStageScript:
	return logo_stage if is_instance_valid(logo_stage) else null


func get_title_menu() -> TitleMenuOverlayScript:
	return title_menu if is_instance_valid(title_menu) else null


func setup(p_main_game: MainGame, p_hub_ctrl: CombatHubSessionControllerScript) -> void:
	main_game = p_main_game
	hub_ctrl = p_hub_ctrl
	if sequence_config == null:
		sequence_config = SeqConfigScript.new()
	_ensure_title_ui()


func _ensure_title_ui() -> void:
	if title_layer != null and is_instance_valid(title_layer):
		return
	title_layer = CanvasLayer.new()
	title_layer.name = "TitleScreenLayer"
	title_layer.layer = 20
	title_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(title_layer)

	logo_stage = StelaLogoStageScript.new() as StelaLogoStageScript
	logo_stage.name = "StelaLogoStage"
	logo_stage.set_anchors_preset(Control.PRESET_CENTER)
	logo_stage.offset_left = -420.0
	logo_stage.offset_top = -390.0
	logo_stage.offset_right = 420.0
	logo_stage.offset_bottom = 180.0
	logo_stage.apply_config(DEFAULT_LOGO_CFG)
	title_layer.add_child(logo_stage)

	title_menu = TitleMenuOverlayScript.new() as TitleMenuOverlayScript
	title_menu.name = "TitleMenuOverlay"
	title_menu.set_continue_available(SaveManagerScript.has_active_run())
	title_layer.add_child(title_menu)

	title_menu.continue_requested.connect(_on_continue_requested)
	title_menu.play_requested.connect(play_title_to_hub_sequence)
	title_menu.settings_requested.connect(_open_settings_modal)
	title_menu.patch_notes_requested.connect(_toggle_patch_notes_modal)
	title_menu.quit_requested.connect(_on_quit_requested)


func enter_title_mode(play_reveal: bool = true) -> void:
	if main_game == null or hub_ctrl == null:
		return
	_ensure_title_ui()
	_kill_active_tween()
	_close_title_modals()

	state = TitleState.TITLE_ACTIVE
	_time_acc = 0.0
	title_menu.set_continue_available(SaveManagerScript.has_active_run())

	var off_px: Vector2 = sequence_config.title_camera_offset_px if sequence_config != null else Vector2(-520.0, -280.0)
	var zoom_v: float = sequence_config.title_camera_zoom if sequence_config != null else 0.86
	_title_cam_anchor = hub_ctrl.hub_origin_2d + off_px
	if is_instance_valid(main_game.camera):
		main_game.camera.target = null
		main_game.camera.set_cinematic_focus(_title_cam_anchor, zoom_v)
		main_game.camera.global_position = _title_cam_anchor
		main_game.camera.zoom = Vector2(zoom_v, zoom_v)

	title_layer.visible = true
	if play_reveal:
		logo_stage.play_entrance()
		title_menu.show_menu(true)
	else:
		logo_stage.reset_visible()
		title_menu.show_menu(false)

	var audio_mgr: Node = get_node_or_null("/root/AudioManager")
	if audio_mgr != null and audio_mgr.has_method("play_music"):
		audio_mgr.play_music("menu")


func enter_title_mode_from_hub() -> void:
	if hub_ctrl == null:
		return
	hub_ctrl.suspend_hub_for_title()
	enter_title_mode(true)


func play_title_to_hub_sequence() -> void:
	if state != TitleState.TITLE_ACTIVE or main_game == null or hub_ctrl == null:
		return
	var bridge: ViewportBridgeScript = hub_ctrl.get_viewport_bridge()
	var hub_stage: AstralStationHub = hub_ctrl.get_hub_stage()
	var player_ref: Player = main_game.player
	if bridge == null or hub_stage == null or not is_instance_valid(player_ref):
		return

	_close_title_modals()
	state = TitleState.HUB_MATERIALIZING
	title_menu.hide_menu(true)
	logo_stage.play_dissolve_to_hub()
	_kill_active_tween()

	var hub_cfg: ConfigScript = hub_stage.config
	var hub_layout: LayoutConfigScript = hub_stage.layout_config
	var spawn_3d: Vector3 = hub_cfg.player_spawn_pos if hub_cfg != null else Vector3(0.0, 0.02, 4.35)
	var feet_off_y: float = hub_layout.embedded_feet_offset_y_px if hub_layout != null else 54.0
	var spawn_2d: Vector2 = bridge.hub_3d_to_world_2d(spawn_3d) - Vector2(0.0, feet_off_y)
	var start_off: Vector2 = sequence_config.pilot_flyin_start_offset_px if sequence_config != null else Vector2(0.0, -480.0)
	var fly_start_2d: Vector2 = spawn_2d + start_off

	player_ref.visible = false
	player_ref.is_movement_suppressed = true
	player_ref.velocity = Vector2.ZERO
	player_ref.global_position = fly_start_2d

	var mat_delay: float = sequence_config.station_materialize_delay_sec if sequence_config != null else 0.42
	var mat_dur: float = sequence_config.station_materialize_duration_sec if sequence_config != null else 1.15
	var fly_delay: float = sequence_config.pilot_flyin_delay_sec if sequence_config != null else 1.05
	var fly_dur: float = sequence_config.pilot_flyin_duration_sec if sequence_config != null else 0.65

	_active_transition_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_active_transition_tween.tween_callback(func() -> void:
		if is_instance_valid(main_game.camera):
			main_game.camera.set_cinematic_focus(spawn_2d, 1.0)
	).set_delay(0.18)

	_active_transition_tween.tween_callback(func() -> void:
		if is_instance_valid(hub_ctrl.display_sprite):
			hub_ctrl.display_sprite.visible = true
		if is_instance_valid(hub_stage):
			hub_stage.play_embedded_materialization(mat_dur)
	).set_delay(mat_delay)

	_active_transition_tween.tween_callback(func() -> void:
		if not is_instance_valid(player_ref):
			return
		player_ref.visible = true
		var rv2: PlayerRigV2Controller = player_ref.get_rig_v2_controller()
		if rv2 != null:
			rv2.set_hub_traversal_state(true, true)
			rv2.set_hub_pose_override(true, Vector2.DOWN, true)
		var fly_tw: Tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		fly_tw.tween_property(player_ref, "global_position", spawn_2d, fly_dur) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		fly_tw.tween_callback(_on_pilot_landed_in_hub)
	).set_delay(fly_delay)


func _on_pilot_landed_in_hub() -> void:
	if main_game == null or hub_ctrl == null:
		return
	var player_ref: Player = main_game.player
	var hub_stage: AstralStationHub = hub_ctrl.get_hub_stage()
	var hub_layout: LayoutConfigScript = hub_stage.layout_config if hub_stage != null else null
	var feet_off_y: float = hub_layout.embedded_feet_offset_y_px if hub_layout != null else 54.0

	if is_instance_valid(player_ref):
		var rv2: PlayerRigV2Controller = player_ref.get_rig_v2_controller()
		if rv2 != null:
			rv2.set_hub_pose_override(false)
			rv2.set_hub_traversal_state(false, false)
			var ripples: Node = rv2.get_node_or_null("HubLandingRippleVFX")
			if ripples != null and ripples.has_method("spawn_ripple"):
				ripples.call("spawn_ripple", player_ref.global_position + Vector2(0.0, feet_off_y), Color(0.24, 0.94, 1.0, 1.0), 86.0, 0.55, 1.25, 14)
		player_ref.is_movement_suppressed = false

	if is_instance_valid(main_game.camera):
		main_game.camera.target = player_ref
		main_game.camera.clear_cinematic_focus()
		main_game.camera.target_zoom = 1.0

	if title_layer != null:
		title_layer.visible = false
	state = TitleState.INACTIVE
	hub_ctrl.activate_hub_from_title(true)


func _process(delta: float) -> void:
	if state != TitleState.TITLE_ACTIVE or main_game == null:
		return
	_time_acc += delta

	if is_instance_valid(main_game.camera) and sequence_config != null:
		_title_cam_anchor += sequence_config.title_cosmos_drift_speed * delta
		main_game.camera.set_cinematic_focus(_title_cam_anchor, sequence_config.title_camera_zoom)

	var cosmos_root: CosmosRootNode = _resolve_cosmos_root()
	if cosmos_root != null and logo_stage != null:
		_lighting_sample = CosmicLightingSamplerScript.sample_at(cosmos_root, _title_cam_anchor, null, _lighting_sample)
		logo_stage.sync_cosmic_lighting(_lighting_sample)


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


func _unhandled_input(event: InputEvent) -> void:
	if state != TitleState.TITLE_ACTIVE:
		return
	var key_ev := event as InputEventKey
	if key_ev == null or not key_ev.pressed or key_ev.echo:
		return
	if key_ev.keycode == KEY_ESCAPE:
		if _patch_notes_layer != null and _patch_notes_layer.visible:
			_patch_notes_layer.visible = false
			if title_menu != null:
				title_menu.focus_primary_button()
			get_viewport().set_input_as_handled()
		elif _settings_modal != null and _settings_modal.visible:
			if _settings_modal.has_method("close_settings"):
				_settings_modal.close_settings()
			else:
				_settings_modal.visible = false
			get_viewport().set_input_as_handled()


func _on_continue_requested() -> void:
	if state != TitleState.TITLE_ACTIVE or not SaveManagerScript.has_active_run():
		return
	state = TitleState.INACTIVE
	SaveManagerScript.is_resuming_run = true
	RunLaunchRequestScript.request_direct_combat_entry()
	var st: Node = get_node_or_null("/root/SceneTransition")
	if st != null and st.has_method("change_scene_to_file"):
		st.call("change_scene_to_file", RunLaunchRequestScript.MAIN_GAME_SCENE_PATH)
	elif get_tree() != null:
		get_tree().change_scene_to_file(RunLaunchRequestScript.MAIN_GAME_SCENE_PATH)


func _open_settings_modal() -> void:
	if _settings_modal == null and SettingsModalScene != null:
		_settings_layer = CanvasLayer.new()
		_settings_layer.name = "TitleSettingsLayer"
		_settings_layer.layer = 65
		_settings_layer.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(_settings_layer)

		_settings_modal = SettingsModalScene.instantiate() as SettingsModal
		if _settings_modal != null:
			_settings_modal.visible = false
			if _settings_modal.has_signal("closed"):
				_settings_modal.closed.connect(func() -> void:
					if title_menu != null and state == TitleState.TITLE_ACTIVE:
						title_menu.focus_primary_button()
				)
			_settings_layer.add_child(_settings_modal)

	if _settings_modal != null:
		if _settings_modal.has_method("open_settings"):
			_settings_modal.open_settings()
		else:
			_settings_modal.visible = true


func _toggle_patch_notes_modal() -> void:
	if _patch_notes_layer == null:
		_build_patch_notes_modal()
	if _patch_notes_layer != null:
		_patch_notes_layer.visible = not _patch_notes_layer.visible
		if not _patch_notes_layer.visible and title_menu != null and state == TitleState.TITLE_ACTIVE:
			title_menu.focus_primary_button()


func _build_patch_notes_modal() -> void:
	if PatchNotesScene == null:
		return
	_patch_notes_layer = CanvasLayer.new()
	_patch_notes_layer.name = "TitlePatchNotesLayer"
	_patch_notes_layer.layer = 65
	_patch_notes_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	_patch_notes_layer.visible = false
	add_child(_patch_notes_layer)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.015, 0.02, 0.055, 0.72)
	backdrop.gui_input.connect(func(ev: InputEvent) -> void:
		var mb := ev as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_patch_notes_layer.visible = false
			if title_menu != null and state == TitleState.TITLE_ACTIVE:
				title_menu.focus_primary_button()
	)
	_patch_notes_layer.add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_patch_notes_layer.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	center.add_child(vbox)

	var notes_panel: Control = PatchNotesScene.instantiate() as Control
	if notes_panel != null:
		notes_panel.custom_minimum_size = Vector2(840.0, 520.0)
		notes_panel.visible = true
		vbox.add_child(notes_panel)

	var close_btn := Button.new()
	close_btn.text = "Cerrar [ESC]"
	close_btn.custom_minimum_size = Vector2(160.0, 36.0)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.pressed.connect(func() -> void:
		_patch_notes_layer.visible = false
		if title_menu != null and state == TitleState.TITLE_ACTIVE:
			title_menu.focus_primary_button()
	)
	vbox.add_child(close_btn)


func _close_title_modals() -> void:
	if _patch_notes_layer != null:
		_patch_notes_layer.visible = false
	if _settings_modal != null and _settings_modal.visible:
		if _settings_modal.has_method("close_settings"):
			_settings_modal.close_settings()
		else:
			_settings_modal.visible = false


func _on_quit_requested() -> void:
	if get_tree() != null:
		get_tree().quit()


func _kill_active_tween() -> void:
	if _active_transition_tween != null and _active_transition_tween.is_valid():
		_active_transition_tween.kill()
	_active_transition_tween = null


func cleanup_for_combat() -> void:
	_kill_active_tween()
	state = TitleState.INACTIVE
	if title_layer != null and is_instance_valid(title_layer):
		title_layer.queue_free()
	title_layer = null
	logo_stage = null
	title_menu = null
	if _settings_layer != null and is_instance_valid(_settings_layer):
		_settings_layer.queue_free()
	_settings_layer = null
	_settings_modal = null
	if _patch_notes_layer != null and is_instance_valid(_patch_notes_layer):
		_patch_notes_layer.queue_free()
	_patch_notes_layer = null

class_name HubLocomotionLab
extends Node3D
## Laboratorio 3D dedicado para calibrar la locomoción Grounded del Hub 3D (Astral Glide-Hop + Ripple Astral).
## Consume HubArtLabPlayer, HubRigAvatar3D y HubGroundedMotor3D reales de producción sobre una pista métrica 3D.

const PlayerScript = preload("res://scenes/ui/hub/astral_station/components/hub_art_lab_player.gd")
const LayoutConfigScript = preload("res://scenes/ui/hub/astral_station/resources/hub_floating_layout_config.gd")
const DEFAULT_LAYOUT_CONFIG: LayoutConfigScript = preload("res://data/hub/default_astral_floating_layout.tres")
const GroundedConfigScript = preload("res://data/pilots/schemas/pilot_grounded_locomotion_config.gd")
const DEFAULT_GROUNDED_PATH: String = "res://data/pilots/valentina_v2/valentina_v2_grounded_locomotion.tres"
const PilotLabSelectorScript = preload("res://sandbox/pilot_rig_lab/shared/pilot_lab_selector.gd")
const LabHudScript = preload("res://sandbox/hub_art_lab/hub_locomotion_lab/hub_locomotion_lab_hud.gd")
const DeckShader: Shader = preload("res://sandbox/hub_art_lab/hub_locomotion_lab/hub_locomotion_lab_deck_shader.gdshader")
const WORKBENCH_HUB_PATH: String = "res://sandbox/workbenches/workbench_hub.tscn"

enum CamMode {
	HUB_REAL = 0,
	CLOSEUP_34 = 1,
	SIDE_PROFILE = 2,
	TOP_OVERVIEW = 3,
}

enum MotionMode {
	FREE_WASD = 0,
	AUTO_8DIR_OCTAGON = 1,
	AUTO_PROFILE_EW = 2,
	AUTO_FRONT_BACK_SN = 3,
	TREADMILL_SCRUB = 4,
}

const CAM_PRESETS: Array[Dictionary] = [
	{"fov": 26.0, "pitch": -46.0, "offset": Vector3(0.0, 18.8, 18.0)},
	{"fov": 25.0, "pitch": -30.0, "offset": Vector3(0.0, 5.2, 8.2)},
	{"fov": 24.0, "pitch": -11.0, "offset": Vector3(0.0, 1.9, 9.6)},
	{"fov": 28.0, "pitch": -62.0, "offset": Vector3(0.0, 16.0, 8.2)},
]

const SLOWMO_SCALES: Array[float] = [1.0, 0.5, 0.25, 0.12]

const DIR_8_VECTORS: Array[Vector2] = [
	Vector2(1.0, 0.0),
	Vector2(0.7071, 0.7071),
	Vector2(0.0, 1.0),
	Vector2(-0.7071, 0.7071),
	Vector2(-1.0, 0.0),
	Vector2(-0.7071, -0.7071),
	Vector2(0.0, -1.0),
	Vector2(0.7071, -0.7071),
]

var player: PlayerScript = null
var camera: Camera3D = null
var hud: LabHudScript = null

var _world_env: WorldEnvironment = null
var _dir_light: DirectionalLight3D = null
var _profile: PilotRigProfile = null
var _grounded_cfg: GroundedConfigScript = null
var _active_profile_path: String = ""
var _active_grounded_path: String = DEFAULT_GROUNDED_PATH

var _cam_mode: int = CamMode.CLOSEUP_34
var _cam_zoom_mult: float = 1.0
var _motion_mode: int = MotionMode.AUTO_PROFILE_EW
var _slowmo_idx: int = 0
var _treadmill_dir_idx: int = 0
var _scrub_enabled: bool = false
var _scrub_deg: float = 0.0
var _auto_timer: float = 0.0
var _ew_sign: float = 1.0
var _sn_sign: float = 1.0


func _ready() -> void:
	_load_pilot_and_config()
	_build_environment_and_deck()
	_spawn_player()
	_setup_camera()
	_build_hud()
	_apply_motion_mode(_motion_mode)
	_apply_camera_state(true, 0.0)


func _exit_tree() -> void:
	Engine.time_scale = 1.0


func _load_pilot_and_config() -> void:
	_active_profile_path = PilotLabSelectorScript.resolve_profile_path()
	if ResourceLoader.exists(_active_profile_path):
		_profile = ResourceLoader.load(_active_profile_path) as PilotRigProfile
	_active_grounded_path = PilotLabSelectorScript.resolve_sibling_config_path(
		_active_profile_path, "grounded_locomotion", DEFAULT_GROUNDED_PATH
	)
	_grounded_cfg = _load_grounded_cfg_from_disk()


func _load_grounded_cfg_from_disk() -> GroundedConfigScript:
	var loaded: GroundedConfigScript = null
	if ResourceLoader.exists(_active_grounded_path):
		var res: Resource = ResourceLoader.load(_active_grounded_path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if res is GroundedConfigScript:
			loaded = res.duplicate(true) as GroundedConfigScript
	if loaded == null:
		loaded = GroundedConfigScript.new()
	loaded.ensure_initialized()
	return loaded


func _build_environment_and_deck() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.018, 0.024, 0.052, 1.0)
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.glow_enabled = true
	env.glow_hdr_threshold = 1.1
	env.glow_intensity = 0.60
	env.glow_bloom = 0.14
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.52, 0.72, 1.0)
	env.ambient_light_energy = 0.65

	_world_env = WorldEnvironment.new()
	_world_env.name = "LabWorldEnvironment"
	_world_env.environment = env
	add_child(_world_env)

	_dir_light = DirectionalLight3D.new()
	_dir_light.name = "LabDirectionalLight"
	_dir_light.rotation_degrees = Vector3(-45.0, 30.0, 0.0)
	_dir_light.light_energy = 1.25
	add_child(_dir_light)

	var floor_body := StaticBody3D.new()
	floor_body.name = "LabMetricFloor"
	floor_body.collision_layer = 1
	floor_body.collision_mask = 0
	add_child(floor_body)

	var col := CollisionShape3D.new()
	var box_sh := BoxShape3D.new()
	box_sh.size = Vector3(64.0, 0.4, 64.0)
	col.shape = box_sh
	col.position = Vector3(0.0, -0.2, 0.0)
	floor_body.add_child(col)

	var deck_mesh := MeshInstance3D.new()
	deck_mesh.name = "LabDeckMesh"
	var plane := PlaneMesh.new()
	plane.size = Vector2(56.0, 56.0)
	deck_mesh.mesh = plane
	var deck_mat := ShaderMaterial.new()
	deck_mat.shader = DeckShader
	deck_mesh.material_override = deck_mat
	floor_body.add_child(deck_mesh)

	var compass_labels: Array[Array] = [
		["N", Vector3(0.0, 0.12, -10.5), Color(0.25, 0.92, 1.0)],
		["S", Vector3(0.0, 0.12, 10.5), Color(0.95, 0.80, 0.34)],
		["E", Vector3(10.5, 0.12, 0.0), Color(1.0, 0.32, 0.64)],
		["W", Vector3(-10.5, 0.12, 0.0), Color(0.62, 0.38, 1.0)],
	]
	for item: Array in compass_labels:
		var lbl3d := Label3D.new()
		lbl3d.text = str(item[0])
		lbl3d.position = item[1] as Vector3
		lbl3d.modulate = item[2] as Color
		lbl3d.pixel_size = 0.015
		lbl3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(lbl3d)


func _spawn_player() -> void:
	var wide_layout: LayoutConfigScript = DEFAULT_LAYOUT_CONFIG.duplicate(true) as LayoutConfigScript
	wide_layout.central_island_radius = 60.0
	wide_layout.platform_hover_y = 0.02

	player = PlayerScript.new() as PlayerScript
	player.name = "LabPlayer"
	player.position = Vector3(0.0, 0.02, 0.0)
	add_child(player)
	player.setup(6.2, _dir_light, wide_layout)

	if player.rig_avatar != null:
		if _profile != null:
			player.rig_avatar.load_pilot_profile(_profile)
		player.rig_avatar.set_grounded_config_override(_grounded_cfg)


func _setup_camera() -> void:
	camera = Camera3D.new()
	camera.name = "LabCamera3D"
	camera.current = true
	add_child(camera)


func _build_hud() -> void:
	var skin_names: Array[String] = []
	if _profile != null:
		for sk: PilotSkinPreset in _profile.skins:
			if sk != null:
				skin_names.append(sk.label if not sk.label.is_empty() else sk.id)
	hud = LabHudScript.new()
	hud.build(self, _grounded_cfg, skin_names, {
		"on_back": Callable(self, "_go_back_to_workbench"),
		"on_cam_changed": Callable(self, "set_camera_mode"),
		"on_motion_changed": Callable(self, "set_motion_mode"),
		"on_gait_changed": Callable(self, "set_gait_style"),
		"on_slowmo_changed": Callable(self, "set_slowmo_index"),
		"on_skin_changed": Callable(self, "_on_skin_selected"),
		"on_treadmill_dir_changed": Callable(self, "_on_treadmill_dir_changed"),
		"on_scrub_toggled": Callable(self, "set_scrub_enabled"),
		"on_scrub_changed": Callable(self, "_on_scrub_deg_changed"),
		"on_test_ripple": Callable(self, "trigger_test_ripple"),
		"on_recenter": Callable(self, "recenter_player"),
		"on_param_changed": Callable(self, "_on_param_changed"),
		"on_bool_changed": Callable(self, "_on_bool_changed"),
		"on_int_changed": Callable(self, "_on_int_changed"),
		"on_save": Callable(self, "save_grounded_tres"),
		"on_reload": Callable(self, "reload_grounded_tres"),
		"on_reset": Callable(self, "reset_grounded_defaults"),
	})
	hud.sync_controls_state(_cam_mode, _motion_mode, _grounded_cfg.gait_style, _slowmo_idx, _scrub_enabled, _scrub_deg)


func _process(delta: float) -> void:
	_step_auto_motion(delta)
	_apply_camera_state(false, delta)
	_refresh_telemetry()


func _step_auto_motion(delta: float) -> void:
	if player == null:
		return
	if _scrub_enabled:
		player.external_input_override_enabled = true
		player.external_input_dir = Vector3.ZERO
		player.is_movement_locked = true
		var t_dir: Vector2 = DIR_8_VECTORS[clampi(_treadmill_dir_idx, 0, DIR_8_VECTORS.size() - 1)]
		player.set_pose_override(t_dir, 1.0, t_dir, false)
		if player.rig_avatar != null:
			player.rig_avatar.set_grounded_manual_scrub(true, deg_to_rad(_scrub_deg), 1.0)
		return

	player.is_movement_locked = false
	if player.rig_avatar != null:
		player.rig_avatar.set_grounded_manual_scrub(false, 0.0, 1.0)

	match _motion_mode:
		MotionMode.FREE_WASD:
			player.external_input_override_enabled = false
			player.external_input_dir = Vector3.ZERO
		MotionMode.AUTO_8DIR_OCTAGON:
			_auto_timer += delta
			player.external_input_override_enabled = true
			var idx: int = int(floor(_auto_timer / 2.2)) % DIR_8_VECTORS.size()
			var d8: Vector2 = DIR_8_VECTORS[idx]
			if Vector2(player.global_position.x, player.global_position.z).length() > 13.0:
				var pull_in: Vector2 = -Vector2(player.global_position.x, player.global_position.z).normalized()
				d8 = (d8 * 0.55 + pull_in * 0.45).normalized()
			player.external_input_dir = Vector3(d8.x, 0.0, d8.y)
		MotionMode.AUTO_PROFILE_EW:
			player.external_input_override_enabled = true
			if player.global_position.x >= 7.0:
				_ew_sign = -1.0
			elif player.global_position.x <= -7.0:
				_ew_sign = 1.0
			var z_corr: float = clampf(-player.global_position.z * 0.35, -0.3, 0.3)
			player.external_input_dir = Vector3(_ew_sign, 0.0, z_corr).normalized()
		MotionMode.AUTO_FRONT_BACK_SN:
			player.external_input_override_enabled = true
			if player.global_position.z >= 6.5:
				_sn_sign = -1.0
			elif player.global_position.z <= -6.5:
				_sn_sign = 1.0
			var x_corr: float = clampf(-player.global_position.x * 0.35, -0.3, 0.3)
			player.external_input_dir = Vector3(x_corr, 0.0, _sn_sign).normalized()
		MotionMode.TREADMILL_SCRUB:
			player.external_input_override_enabled = true
			player.external_input_dir = Vector3.ZERO
			player.global_position = Vector3(0.0, 0.02, 0.0)
			var tm_dir: Vector2 = DIR_8_VECTORS[clampi(_treadmill_dir_idx, 0, DIR_8_VECTORS.size() - 1)]
			player.set_pose_override(tm_dir, 1.0, tm_dir, false)
			var spd_m: float = _grounded_cfg.hub_move_speed if _grounded_cfg != null else 6.2
			if player.rig_avatar != null:
				player.rig_avatar.feed_world_displacement(spd_m * delta)


func _apply_camera_state(snap: bool, delta: float) -> void:
	if camera == null or player == null:
		return
	var preset: Dictionary = CAM_PRESETS[clampi(_cam_mode, 0, CAM_PRESETS.size() - 1)]
	var target_fov: float = float(preset["fov"])
	var target_pitch: float = float(preset["pitch"])
	var base_off: Vector3 = preset["offset"] as Vector3
	var target_pos: Vector3 = player.global_position + base_off * _cam_zoom_mult

	if snap or delta <= 0.0:
		camera.global_position = target_pos
		camera.rotation_degrees = Vector3(target_pitch, 0.0, 0.0)
		camera.fov = target_fov
	else:
		var w: float = clampf(7.5 * delta, 0.0, 1.0)
		camera.global_position = camera.global_position.lerp(target_pos, w)
		camera.rotation_degrees = Vector3(lerpf(camera.rotation_degrees.x, target_pitch, w), 0.0, 0.0)
		camera.fov = lerpf(camera.fov, target_fov, w)

	if player.rig_avatar != null:
		player.rig_avatar.set_camera_pitch_alignment(camera.rotation_degrees.x, snap)


func _refresh_telemetry() -> void:
	if hud == null or player == null or player.rig_avatar == null:
		return
	var rig: PlanarCombatRig = player.rig_avatar.get_rig()
	if rig == null:
		return
	var info: Dictionary = rig.get_grounded_telemetry()
	info["view_key"] = rig.get_active_view_key()
	hud.update_telemetry(info)


func _unhandled_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed:
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cam_zoom_mult = clampf(_cam_zoom_mult - 0.08, 0.50, 1.65)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cam_zoom_mult = clampf(_cam_zoom_mult + 0.08, 0.50, 1.65)

	var key_ev := event as InputEventKey
	if key_ev == null or not key_ev.pressed or key_ev.echo:
		return
	match key_ev.keycode:
		KEY_1:
			set_camera_mode(CamMode.HUB_REAL)
		KEY_2:
			set_camera_mode(CamMode.CLOSEUP_34)
		KEY_3:
			set_camera_mode(CamMode.SIDE_PROFILE)
		KEY_4:
			set_camera_mode(CamMode.TOP_OVERVIEW)
		KEY_M:
			set_slowmo_index((_slowmo_idx + 1) % SLOWMO_SCALES.size())
		KEY_G:
			var next_g: int = ((_grounded_cfg.gait_style if _grounded_cfg != null else 2) + 1) % 3
			set_gait_style(next_g)
		KEY_SPACE:
			set_scrub_enabled(not _scrub_enabled)
		KEY_R:
			recenter_player()
		KEY_H:
			if hud != null:
				hud.toggle_panel_visibility()
		KEY_ESCAPE:
			_go_back_to_workbench()


func set_camera_mode(mode_idx: int) -> void:
	_cam_mode = clampi(mode_idx, 0, CAM_PRESETS.size() - 1)
	if hud != null:
		hud.sync_controls_state(_cam_mode, _motion_mode, _grounded_cfg.gait_style if _grounded_cfg != null else 2, _slowmo_idx, _scrub_enabled, _scrub_deg)


func set_motion_mode(mode_idx: int) -> void:
	_motion_mode = clampi(mode_idx, 0, MotionMode.TREADMILL_SCRUB)
	_apply_motion_mode(_motion_mode)
	if hud != null:
		hud.sync_controls_state(_cam_mode, _motion_mode, _grounded_cfg.gait_style if _grounded_cfg != null else 2, _slowmo_idx, _scrub_enabled, _scrub_deg)


func _apply_motion_mode(mode_idx: int) -> void:
	_auto_timer = 0.0
	if player == null:
		return
	player.is_pose_override_active = (mode_idx == MotionMode.TREADMILL_SCRUB)
	if mode_idx != MotionMode.TREADMILL_SCRUB and not _scrub_enabled:
		player.external_input_override_enabled = (mode_idx != MotionMode.FREE_WASD)


func set_gait_style(style_idx: int) -> void:
	if _grounded_cfg == null:
		return
	_grounded_cfg.gait_style = clampi(style_idx, 0, 2)
	if player != null and player.rig_avatar != null:
		player.rig_avatar.set_grounded_config_override(_grounded_cfg)
	if hud != null:
		hud.sync_controls_state(_cam_mode, _motion_mode, _grounded_cfg.gait_style, _slowmo_idx, _scrub_enabled, _scrub_deg)


func set_slowmo_index(idx: int) -> void:
	_slowmo_idx = clampi(idx, 0, SLOWMO_SCALES.size() - 1)
	Engine.time_scale = SLOWMO_SCALES[_slowmo_idx]
	if hud != null:
		hud.sync_controls_state(_cam_mode, _motion_mode, _grounded_cfg.gait_style if _grounded_cfg != null else 2, _slowmo_idx, _scrub_enabled, _scrub_deg)


func set_scrub_enabled(enabled: bool) -> void:
	_scrub_enabled = enabled
	if player != null:
		player.is_pose_override_active = enabled or (_motion_mode == MotionMode.TREADMILL_SCRUB)
	if hud != null:
		hud.sync_controls_state(_cam_mode, _motion_mode, _grounded_cfg.gait_style if _grounded_cfg != null else 2, _slowmo_idx, _scrub_enabled, _scrub_deg)


func _on_scrub_deg_changed(deg: float) -> void:
	_scrub_deg = clampf(deg, 0.0, 360.0)
	if not _scrub_enabled:
		set_scrub_enabled(true)


func _on_treadmill_dir_changed(idx: int) -> void:
	_treadmill_dir_idx = clampi(idx, 0, DIR_8_VECTORS.size() - 1)


func _on_skin_selected(idx: int) -> void:
	if _profile == null or player == null or player.rig_avatar == null:
		return
	if idx >= 0 and idx < _profile.skins.size():
		var sk: PilotSkinPreset = _profile.skins[idx]
		if sk != null:
			player.rig_avatar.apply_skin_preset(sk, 1)


func trigger_test_ripple() -> void:
	if player == null or player._grounded_motor == null:
		return
	player._grounded_motor.spawn_astral_ripple(player, 1.0, player.rig_avatar, _grounded_cfg)


func recenter_player() -> void:
	if player == null:
		return
	player.global_position = Vector3(0.0, 0.02, 0.0)
	player.velocity = Vector3.ZERO
	_ew_sign = 1.0
	_sn_sign = 1.0


func _on_param_changed(key: String, val: float) -> void:
	if _grounded_cfg == null or not (key in _grounded_cfg):
		return
	_grounded_cfg.set(key, val)
	if player != null and player.rig_avatar != null:
		player.rig_avatar.set_grounded_config_override(_grounded_cfg)


func _on_bool_changed(key: String, val: bool) -> void:
	if _grounded_cfg == null or not (key in _grounded_cfg):
		return
	_grounded_cfg.set(key, val)


func _on_int_changed(key: String, val: int) -> void:
	if _grounded_cfg == null or not (key in _grounded_cfg):
		return
	_grounded_cfg.set(key, val)


func save_grounded_tres() -> void:
	if _grounded_cfg == null:
		return
	var err: Error = ResourceSaver.save(_grounded_cfg, _active_grounded_path)
	if hud != null:
		if err == OK:
			hud.set_feedback("Guardado OK en %s" % _active_grounded_path.get_file(), true)
		else:
			hud.set_feedback("Error al guardar (%d)" % err, false)


func reload_grounded_tres() -> void:
	_grounded_cfg = _load_grounded_cfg_from_disk()
	if player != null and player.rig_avatar != null:
		player.rig_avatar.set_grounded_config_override(_grounded_cfg)
	if hud != null:
		hud.sync_from_config(_grounded_cfg)
		hud.set_feedback("Recargado desde %s" % _active_grounded_path.get_file(), true)


func reset_grounded_defaults() -> void:
	if _grounded_cfg == null:
		return
	_grounded_cfg.reset_defaults()
	if player != null and player.rig_avatar != null:
		player.rig_avatar.set_grounded_config_override(_grounded_cfg)
	if hud != null:
		hud.sync_from_config(_grounded_cfg)
		hud.set_feedback("Defaults Astral Glide-Hop restaurados.", true)


func _go_back_to_workbench() -> void:
	Engine.time_scale = 1.0
	if ResourceLoader.exists(WORKBENCH_HUB_PATH) and get_tree() != null:
		get_tree().change_scene_to_file(WORKBENCH_HUB_PATH)

extends Node2D
## Laboratorio Interactivo de Pose Base, Idle Zero-G y Locomoción/Freno — Valentina v2 (8 Direcciones en Brújula).

const PlanarRigScript = preload("res://scenes/pilots/rig/planar_combat_rig.gd")
const ViewRouterScript = preload("res://scenes/pilots/rig/planar_rig_view_router.gd")
const BasePoseConfigScript = preload("res://data/pilots/schemas/pilot_base_pose_config.gd")
const IdleAnimConfigScript = preload("res://data/pilots/schemas/pilot_idle_anim_config.gd")
const LocomotionAnimConfigScript = preload("res://data/pilots/schemas/pilot_locomotion_anim_config.gd")
const GroundedConfigScript = preload("res://data/pilots/schemas/pilot_grounded_locomotion_config.gd")
const KitingAnimConfigScript = preload("res://data/pilots/schemas/pilot_kiting_anim_config.gd")
const TurnAnimConfigScript = preload("res://data/pilots/schemas/pilot_turn_anim_config.gd")
const JigglePhysicsConfigScript = preload("res://data/pilots/schemas/pilot_jiggle_physics_config.gd")
const FaceAnimConfigScript = preload("res://data/pilots/schemas/pilot_face_anim_config.gd")
const BasePoseEvaluatorScript = preload("res://scenes/pilots/rig/planar_rig_base_pose_evaluator.gd")
const GroundedEvaluatorScript = preload("res://scenes/pilots/rig/planar_rig_grounded_evaluator.gd")
const KitingEvaluatorScript = preload("res://scenes/pilots/rig/planar_rig_kiting_evaluator.gd")
const PoseLabHudScript = preload("res://sandbox/pilot_rig_lab/proto/planar_pose_lab_hud.gd")
const PilotLabSelectorScript = preload("res://sandbox/pilot_rig_lab/shared/pilot_lab_selector.gd")

const PROFILE_PATH: String = "res://data/pilots/valentina_v2/valentina_v2_profile.tres"
const BASE_POSE_PATH: String = "res://data/pilots/valentina_v2/valentina_v2_base_pose.tres"
const IDLE_ANIM_PATH: String = "res://data/pilots/valentina_v2/valentina_v2_idle_anim.tres"
const LOCO_ANIM_PATH: String = "res://data/pilots/valentina_v2/valentina_v2_locomotion_anim.tres"
const GROUNDED_LOCO_PATH: String = "res://data/pilots/valentina_v2/valentina_v2_grounded_locomotion.tres"
const KITING_ANIM_PATH: String = "res://data/pilots/valentina_v2/valentina_v2_kiting_anim.tres"
const TURN_ANIM_PATH: String = "res://data/pilots/valentina_v2/valentina_v2_turn_anim.tres"
const JIGGLE_PHYSICS_PATH: String = "res://data/pilots/valentina_v2/valentina_v2_jiggle_physics.tres"
const FACE_ANIM_PATH: String = "res://data/pilots/valentina_v2/valentina_v2_face_anim.tres"
const STYLE_SHARP_PATH: String = "res://data/pilots/styles/02_valentina_razor_sharp.tres"

const ALL_VIEWS: Array[String] = ["n", "ne", "e", "se", "s", "sw", "w", "nw"]
const COMPASS_RADIUS: float = 290.0
const HEAD_CYCLE_SEC: float = 1.4
const DEFAULT_CAM_POS := Vector2(-120.0, 0.0)
const DEFAULT_CAM_ZOOM: float = 0.85
const SLOWMO_SCALES: Array[float] = [1.0, 0.5, 0.25, 0.12]

@export var pilot_profile_override: String = ""

var _active_profile_path: String = PROFILE_PATH
var _active_base_pose_path: String = BASE_POSE_PATH
var _active_idle_anim_path: String = IDLE_ANIM_PATH
var _active_loco_anim_path: String = LOCO_ANIM_PATH
var _active_grounded_loco_path: String = GROUNDED_LOCO_PATH
var _active_kiting_anim_path: String = KITING_ANIM_PATH
var _active_turn_anim_path: String = TURN_ANIM_PATH
var _active_jiggle_physics_path: String = JIGGLE_PHYSICS_PATH
var _active_face_anim_path: String = FACE_ANIM_PATH

var _profile: PilotRigProfile = null
var _style_profile: RigStyleProfile = null
var _pose_cfg: BasePoseConfigScript = null
var _idle_cfg: IdleAnimConfigScript = null
var _loco_cfg: LocomotionAnimConfigScript = null
var _grounded_cfg: GroundedConfigScript = null
var _kiting_cfg: KitingAnimConfigScript = null
var _turn_cfg: TurnAnimConfigScript = null
var _jiggle_cfg: JigglePhysicsConfigScript = null
var _face_cfg: FaceAnimConfigScript = null
var _evaluator: BasePoseEvaluatorScript = null
var _grounded_eval: GroundedEvaluatorScript = null
var _hud: PoseLabHudScript = null
var _face_live_enabled: bool = true

var _rig_entries: Array[Dictionary] = []
var _camera: Camera2D = null
var _world_env: WorldEnvironment = null

var _layer_mode: int = BasePoseEvaluatorScript.PoseLayerMode.COMBINED_BONES_AND_25D
var _last_active_pose_mode: int = BasePoseEvaluatorScript.PoseLayerMode.COMBINED_BONES_AND_25D
var _selected_family: String = "s"
var _pose_scale: float = 1.0
var _micro_hover_enabled: bool = true
var _loco_preview_enabled: bool = false
var _loco_preview_mode: int = LocomotionAnimConfigScript.PreviewMode.AUTO_CYCLE
var _kiting_preview_enabled: bool = true
var _kiting_preview_mode: int = KitingAnimConfigScript.PreviewMode.AUTO_KITING_360
var _kiting_edit_phase: String = "rev_"
var _grounded_preview_enabled: bool = false
var _grounded_preview_mode: int = GroundedConfigScript.PreviewMode.AUTO_DEMO_CYCLE
var _grounded_demo_timer: float = 0.0
var _turn_preview_enabled: bool = false
var _turn_preview_mode: int = TurnAnimConfigScript.PreviewMode.AUTO_BODY_AND_HEAD_CYCLE
var _turn_step_timer: float = 0.0
var _turn_step_counter: int = 0
var _jiggle_preview_enabled: bool = false
var _jiggle_preview_mode: int = JigglePhysicsConfigScript.PreviewMode.AUTO_CHOREO_CYCLE
var _jiggle_pulse_timer: float = 0.0
var _jiggle_pulse_counter: int = 0
var _head_cycle_enabled: bool = false
var _anim_time: float = 0.0
var _q_time: float = 0.0
var _slowmo_idx: int = 0
var _time_scale: float = 1.0
var _dragging: bool = false


func _ready() -> void:
	_load_resources()
	_build_backdrop()
	_build_world_environment()

	_camera = Camera2D.new()
	_camera.position = DEFAULT_CAM_POS
	_camera.zoom = Vector2(DEFAULT_CAM_ZOOM, DEFAULT_CAM_ZOOM)
	add_child(_camera)

	_evaluator = BasePoseEvaluatorScript.new()
	_evaluator.ensure_assets_loaded()
	_grounded_eval = GroundedEvaluatorScript.new()

	for v_key: String in ALL_VIEWS:
		var dir_vec: Vector2 = ViewRouterScript.get_body_dir_vector(v_key)
		var pos: Vector2 = dir_vec * COMPASS_RADIUS
		var allowed_heads: Array = (ViewRouterScript.ALLOWED_HEADS_BY_BODY_8DIR.get(v_key, [ViewRouterScript.get_default_head_for_body(v_key)]) as Array).duplicate()
		var rig: PlanarCombatRig = PlanarRigScript.new()
		rig.name = "PilotRig_%s" % v_key.to_upper()
		rig.pilot_profile = _profile
		rig.position = pos
		add_child(rig)
		rig.set_static_inspection(true, v_key, str(allowed_heads[0]))
		rig.calibration_manual_pose = true
		_apply_razor_sharp_style(rig)
		rig.set_external_face_step(true)
		rig.set_face_live_enabled(_face_live_enabled, _face_cfg.duplicate(true) as FaceAnimConfigScript)

		var tag := Label.new()
		tag.text = v_key.to_upper()
		tag.position = pos + Vector2(-14.0, -116.0)
		add_child(tag)

		_rig_entries.append({
			"view": v_key,
			"home_view": v_key,
			"cur_view": v_key,
			"rig": rig,
			"tag": tag,
			"pos": pos,
			"heads": allowed_heads,
			"head_idx": 0,
			"turn_state": {},
		})

	_hud = PoseLabHudScript.new()
	_hud.build(self, _pose_cfg, _idle_cfg, _loco_cfg, _turn_cfg, _jiggle_cfg, _selected_family, _micro_hover_enabled, {
		"on_tab_changed": Callable(self, "_on_tab_changed"),
		"on_toggle_hover": Callable(self, "_toggle_hover"),
		"on_toggle_ab": Callable(self, "_toggle_ab_pose"),
		"on_mode_changed": Callable(self, "_on_mode_changed"),
		"on_scale_changed": Callable(self, "_on_scale_changed"),
		"on_head_cycle_toggled": Callable(self, "_on_head_cycle_toggled"),
		"on_face_live_toggled": Callable(self, "_on_face_live_toggled"),
		"on_slowmo_changed": Callable(self, "_on_slowmo_changed"),
		"on_reset_camera": Callable(self, "_reset_camera"),
		"on_family_selected": Callable(self, "_on_family_selected"),
		"on_param_changed": Callable(self, "_on_param_changed"),
		"on_save_tres": Callable(self, "_save_pose_tres"),
		"on_reload_tres": Callable(self, "_reload_pose_tres"),
		"on_reset_family": Callable(self, "_reset_selected_family"),
		"on_idle_layer_toggled": Callable(self, "_on_idle_layer_toggled"),
		"on_idle_cadence_changed": Callable(self, "_on_idle_cadence_changed"),
		"on_idle_param_changed": Callable(self, "_on_idle_param_changed"),
		"on_idle_family_mul_changed": Callable(self, "_on_idle_family_mul_changed"),
		"on_save_idle_tres": Callable(self, "_save_idle_tres"),
		"on_reload_idle_tres": Callable(self, "_reload_idle_tres"),
		"on_reset_idle": Callable(self, "_reset_idle_defaults"),
		"on_loco_preview_toggled": Callable(self, "_on_loco_preview_toggled"),
		"on_loco_mode_changed": Callable(self, "_on_loco_mode_changed"),
		"on_loco_global_changed": Callable(self, "_on_loco_global_changed"),
		"on_loco_param_changed": Callable(self, "_on_loco_param_changed"),
		"on_save_loco_tres": Callable(self, "_save_loco_tres"),
		"on_reload_loco_tres": Callable(self, "_reload_loco_tres"),
		"on_reset_loco_family": Callable(self, "_reset_loco_family"),
		"on_turn_preview_toggled": Callable(self, "_on_turn_preview_toggled"),
		"on_turn_mode_changed": Callable(self, "_on_turn_mode_changed"),
		"on_trigger_turn_now": Callable(self, "_trigger_turn_step_now"),
		"on_turn_param_changed": Callable(self, "_on_turn_param_changed"),
		"on_turn_family_mul_changed": Callable(self, "_on_turn_family_mul_changed"),
		"on_save_turn_tres": Callable(self, "_save_turn_tres"),
		"on_reload_turn_tres": Callable(self, "_reload_turn_tres"),
		"on_reset_turn_defaults": Callable(self, "_reset_turn_defaults"),
		"on_jiggle_preview_toggled": Callable(self, "_on_jiggle_preview_toggled"),
		"on_jiggle_mode_changed": Callable(self, "_on_jiggle_mode_changed"),
		"on_trigger_jiggle_now": Callable(self, "_trigger_jiggle_impulse_now"),
		"on_jiggle_part_toggled": Callable(self, "_on_jiggle_part_toggled"),
		"on_jiggle_param_changed": Callable(self, "_on_jiggle_param_changed"),
		"on_jiggle_family_mul_changed": Callable(self, "_on_jiggle_family_mul_changed"),
		"on_save_jiggle_tres": Callable(self, "_save_jiggle_tres"),
		"on_reload_jiggle_tres": Callable(self, "_reload_jiggle_tres"),
		"on_reset_jiggle_defaults": Callable(self, "_reset_jiggle_defaults"),
		"on_kiting_preview_toggled": Callable(self, "_on_kiting_preview_toggled"),
		"on_kiting_mode_changed": Callable(self, "_on_kiting_mode_changed"),
		"on_kiting_edit_phase_changed": Callable(self, "_on_kiting_edit_phase_changed"),
		"on_kiting_global_changed": Callable(self, "_on_kiting_global_changed"),
		"on_kiting_param_changed": Callable(self, "_on_kiting_param_changed"),
		"on_save_kiting_tres": Callable(self, "_save_kiting_tres"),
		"on_reload_kiting_tres": Callable(self, "_reload_kiting_tres"),
		"on_reset_kiting_family": Callable(self, "_reset_kiting_family"),
		"on_grounded_preview_toggled": Callable(self, "_on_grounded_preview_toggled"),
		"on_grounded_mode_changed": Callable(self, "_on_grounded_mode_changed"),
		"on_trigger_grounded_pivot": Callable(self, "_on_trigger_grounded_pivot"),
		"on_grounded_param_changed": Callable(self, "_on_grounded_param_changed"),
		"on_grounded_family_mul_changed": Callable(self, "_on_grounded_family_mul_changed"),
		"on_save_grounded_tres": Callable(self, "_save_grounded_tres"),
		"on_reload_grounded_tres": Callable(self, "_reload_grounded_tres"),
		"on_reset_grounded_defaults": Callable(self, "_reset_grounded_defaults"),
	}, _kiting_cfg, _grounded_cfg)

	_refresh_compass_highlights()
	_turn_step_timer = 0.72
	_apply_all_poses()
	if _face_live_enabled:
		_step_compass_faces(0.016)


func _load_resources() -> void:
	var resolved: Dictionary = PilotLabSelectorScript.resolve_active_paths(pilot_profile_override, PROFILE_PATH, {
		"base_pose": BASE_POSE_PATH,
		"idle_anim": IDLE_ANIM_PATH,
		"locomotion_anim": LOCO_ANIM_PATH,
		"grounded_locomotion": GROUNDED_LOCO_PATH,
		"kiting_anim": KITING_ANIM_PATH,
		"turn_anim": TURN_ANIM_PATH,
		"jiggle_physics": JIGGLE_PHYSICS_PATH,
		"face_anim": FACE_ANIM_PATH,
	})
	_active_profile_path = str(resolved.get("profile_path", PROFILE_PATH))
	var cfgs: Dictionary = resolved.get("configs", {}) as Dictionary
	_active_base_pose_path = str(cfgs.get("base_pose", BASE_POSE_PATH))
	_active_idle_anim_path = str(cfgs.get("idle_anim", IDLE_ANIM_PATH))
	_active_loco_anim_path = str(cfgs.get("locomotion_anim", LOCO_ANIM_PATH))
	_active_grounded_loco_path = str(cfgs.get("grounded_locomotion", GROUNDED_LOCO_PATH))
	_active_kiting_anim_path = str(cfgs.get("kiting_anim", KITING_ANIM_PATH))
	_active_turn_anim_path = str(cfgs.get("turn_anim", TURN_ANIM_PATH))
	_active_jiggle_physics_path = str(cfgs.get("jiggle_physics", JIGGLE_PHYSICS_PATH))
	_active_face_anim_path = str(cfgs.get("face_anim", FACE_ANIM_PATH))

	if ResourceLoader.exists(_active_profile_path):
		_profile = ResourceLoader.load(_active_profile_path) as PilotRigProfile
	if ResourceLoader.exists(STYLE_SHARP_PATH):
		_style_profile = ResourceLoader.load(STYLE_SHARP_PATH) as RigStyleProfile
	elif _profile != null and not _profile.style_profiles.is_empty():
		_style_profile = _profile.style_profiles[_profile.style_profiles.size() - 1]

	_pose_cfg = _load_pose_cfg_from_disk()
	_idle_cfg = _load_idle_cfg_from_disk()
	_loco_cfg = _load_loco_cfg_from_disk()
	_grounded_cfg = _load_grounded_cfg_from_disk()
	_kiting_cfg = _load_kiting_cfg_from_disk()
	_turn_cfg = _load_turn_cfg_from_disk()
	_jiggle_cfg = _load_jiggle_cfg_from_disk()
	_face_cfg = _load_face_cfg_from_disk()


func _load_face_cfg_from_disk() -> FaceAnimConfigScript:
	var cfg: FaceAnimConfigScript = null
	if ResourceLoader.exists(_active_face_anim_path):
		var loaded: Resource = ResourceLoader.load(_active_face_anim_path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if loaded is FaceAnimConfigScript:
			cfg = (loaded as FaceAnimConfigScript).duplicate(true) as FaceAnimConfigScript
	if cfg == null:
		cfg = FaceAnimConfigScript.new()
	return cfg


func _load_pose_cfg_from_disk() -> BasePoseConfigScript:
	var cfg: BasePoseConfigScript = null
	if ResourceLoader.exists(_active_base_pose_path):
		var loaded: Resource = ResourceLoader.load(_active_base_pose_path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if loaded is BasePoseConfigScript:
			cfg = (loaded as BasePoseConfigScript).duplicate(true) as BasePoseConfigScript
	if cfg == null:
		cfg = BasePoseConfigScript.new()
	cfg.ensure_initialized()
	return cfg


func _load_idle_cfg_from_disk() -> IdleAnimConfigScript:
	var cfg: IdleAnimConfigScript = null
	if ResourceLoader.exists(_active_idle_anim_path):
		var loaded: Resource = ResourceLoader.load(_active_idle_anim_path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if loaded is IdleAnimConfigScript:
			cfg = (loaded as IdleAnimConfigScript).duplicate(true) as IdleAnimConfigScript
	if cfg == null:
		cfg = IdleAnimConfigScript.new()
	cfg.ensure_initialized()
	return cfg


func _load_loco_cfg_from_disk() -> LocomotionAnimConfigScript:
	var cfg: LocomotionAnimConfigScript = null
	if ResourceLoader.exists(_active_loco_anim_path):
		var loaded: Resource = ResourceLoader.load(_active_loco_anim_path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if loaded is LocomotionAnimConfigScript:
			cfg = (loaded as LocomotionAnimConfigScript).duplicate(true) as LocomotionAnimConfigScript
	if cfg == null:
		cfg = LocomotionAnimConfigScript.new()
	cfg.ensure_initialized()
	return cfg


func _load_grounded_cfg_from_disk() -> GroundedConfigScript:
	var cfg: GroundedConfigScript = null
	if ResourceLoader.exists(_active_grounded_loco_path):
		var loaded: Resource = ResourceLoader.load(_active_grounded_loco_path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if loaded is GroundedConfigScript:
			cfg = (loaded as GroundedConfigScript).duplicate(true) as GroundedConfigScript
	if cfg == null:
		cfg = GroundedConfigScript.new()
	cfg.ensure_initialized()
	return cfg


func _load_kiting_cfg_from_disk() -> KitingAnimConfigScript:
	var cfg: KitingAnimConfigScript = null
	if ResourceLoader.exists(_active_kiting_anim_path):
		var loaded: Resource = ResourceLoader.load(_active_kiting_anim_path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if loaded is KitingAnimConfigScript:
			cfg = (loaded as KitingAnimConfigScript).duplicate(true) as KitingAnimConfigScript
	if cfg == null:
		cfg = KitingAnimConfigScript.new()
	cfg.ensure_initialized()
	return cfg


func _load_turn_cfg_from_disk() -> TurnAnimConfigScript:
	var cfg: TurnAnimConfigScript = null
	if ResourceLoader.exists(_active_turn_anim_path):
		var loaded: Resource = ResourceLoader.load(_active_turn_anim_path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if loaded is TurnAnimConfigScript:
			cfg = (loaded as TurnAnimConfigScript).duplicate(true) as TurnAnimConfigScript
	if cfg == null:
		cfg = TurnAnimConfigScript.new()
	cfg.ensure_initialized()
	return cfg


func _load_jiggle_cfg_from_disk() -> JigglePhysicsConfigScript:
	var cfg: JigglePhysicsConfigScript = null
	if ResourceLoader.exists(_active_jiggle_physics_path):
		var loaded: Resource = ResourceLoader.load(_active_jiggle_physics_path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if loaded is JigglePhysicsConfigScript:
			cfg = (loaded as JigglePhysicsConfigScript).duplicate(true) as JigglePhysicsConfigScript
	if cfg == null:
		cfg = JigglePhysicsConfigScript.new()
	cfg.ensure_initialized()
	return cfg


func _apply_razor_sharp_style(rig: PlanarCombatRig) -> void:
	if rig == null:
		return
	if _style_profile != null:
		rig.apply_style_profile(_style_profile)
	if _profile != null and not _profile.skins.is_empty():
		rig.apply_skin_preset(_profile.skins[0])
	rig.set_recolor_method(1)
	rig.set_hair_style_mode(0)
	rig.set_shader_param_all("enable_inward_outline", false)
	var use_nd: bool = _style_profile.use_normal_depth if _style_profile != null else true
	var rim_str: float = (_style_profile.normal_rim_strength if use_nd else 0.0) if _style_profile != null else 0.88
	var hdr_cap: float = _style_profile.hdr_cap if _style_profile != null else 1.78
	rig.set_normal_depth_options(use_nd, Vector2(-0.58, -0.81).normalized(), rim_str, hdr_cap)
	if _camera != null:
		rig.set_zoom_scale(_camera.zoom.x)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_zoom_camera(1.12)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom_camera(1.0 / 1.12)
		elif mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_MIDDLE or mb.button_index == MOUSE_BUTTON_RIGHT:
			_dragging = mb.pressed
	elif event is InputEventMouseMotion and _dragging and _camera != null:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		_camera.position -= mm.relative / maxf(_camera.zoom.x, 0.05)
	elif event is InputEventKey:
		var kev: InputEventKey = event as InputEventKey
		if kev.pressed and not kev.echo:
			if kev.keycode == KEY_TAB:
				_toggle_ab_pose()
				get_viewport().set_input_as_handled()
			elif kev.keycode == KEY_SPACE:
				_toggle_hover()
				get_viewport().set_input_as_handled()
			elif kev.keycode == KEY_R:
				_reset_camera()
				get_viewport().set_input_as_handled()
			elif kev.keycode == KEY_M:
				_on_slowmo_changed((_slowmo_idx + 1) % SLOWMO_SCALES.size())
				get_viewport().set_input_as_handled()


func _zoom_camera(factor: float) -> void:
	if _camera == null:
		return
	var mouse_before: Vector2 = get_global_mouse_position()
	var z: float = clampf(_camera.zoom.x * factor, 0.40, 12.0)
	_camera.zoom = Vector2(z, z)
	var mouse_after: Vector2 = get_global_mouse_position()
	_camera.position += (mouse_before - mouse_after)
	for entry: Dictionary in _rig_entries:
		var rig: PlanarCombatRig = entry["rig"] as PlanarCombatRig
		if rig != null:
			rig.set_zoom_scale(z)


func _on_slowmo_changed(idx: int) -> void:
	_slowmo_idx = clampi(idx, 0, SLOWMO_SCALES.size() - 1)
	_time_scale = SLOWMO_SCALES[_slowmo_idx]
	if _hud != null:
		_hud.sync_slowmo_index(_slowmo_idx)
		_hud.set_feedback("Velocidad de animación: %.2fx" % _time_scale, true)


func _is_jiggle_turn_choreo_active() -> bool:
	return _jiggle_preview_enabled and (_jiggle_preview_mode == JigglePhysicsConfigScript.PreviewMode.AUTO_CHOREO_CYCLE or _jiggle_preview_mode == JigglePhysicsConfigScript.PreviewMode.BRAKE_BOUNCE_PULSE)


func _is_jiggle_loco_choreo_active() -> bool:
	return _jiggle_preview_enabled and (_jiggle_preview_mode == JigglePhysicsConfigScript.PreviewMode.AUTO_CHOREO_CYCLE or _jiggle_preview_mode == JigglePhysicsConfigScript.PreviewMode.LATERAL_TURN_WHIP)


func _process(delta: float) -> void:
	var eff_delta: float = delta * _time_scale
	_q_time += eff_delta
	for entry: Dictionary in _rig_entries:
		var rig: PlanarCombatRig = entry["rig"] as PlanarCombatRig
		if rig != null:
			rig.set_q_time(_q_time)

	var turns_live: bool = _turn_preview_enabled or _is_jiggle_turn_choreo_active()
	var cycle_playing: bool = _micro_hover_enabled or (_loco_preview_enabled and _loco_preview_mode == LocomotionAnimConfigScript.PreviewMode.AUTO_CYCLE) or (_kiting_preview_enabled and _kiting_preview_mode == KitingAnimConfigScript.PreviewMode.AUTO_KITING_360) or _grounded_preview_enabled
	if cycle_playing or _head_cycle_enabled or turns_live or _jiggle_preview_enabled:
		_anim_time += eff_delta
	if _grounded_preview_enabled:
		_step_grounded_preview(eff_delta)
	if turns_live:
		_step_turn_previews(eff_delta)
	if _jiggle_preview_enabled:
		_step_jiggle_preview(eff_delta)
	if _head_cycle_enabled and not turns_live:
		_update_head_cycles()
	if _micro_hover_enabled or turns_live or _jiggle_preview_enabled or _kiting_preview_enabled or _grounded_preview_enabled:
		_apply_all_poses()
	if _face_live_enabled:
		_step_compass_faces(eff_delta)


func _update_head_cycles() -> void:
	var step_idx: int = int(floor(_anim_time / HEAD_CYCLE_SEC))
	var loco_weights: Dictionary = _get_active_loco_weights()
	var kiting_weights: Dictionary = _get_active_kiting_weights()
	var kiting_cfg_eff: KitingAnimConfigScript = _kiting_cfg if _kiting_preview_enabled else null
	var jiggle_cfg_eff: JigglePhysicsConfigScript = _jiggle_cfg if _jiggle_preview_enabled else null
	for i: int in range(_rig_entries.size()):
		var entry: Dictionary = _rig_entries[i]
		var heads: Array = entry["heads"] as Array
		if heads.size() <= 1:
			continue
		var target_idx: int = (step_idx + i) % heads.size()
		if int(entry["head_idx"]) != target_idx:
			entry["head_idx"] = target_idx
			var rig: PlanarCombatRig = entry["rig"] as PlanarCombatRig
			var v_key: String = str(entry.get("cur_view", entry["view"]))
			rig.set_static_inspection(true, v_key, str(heads[target_idx]))
			_evaluator.apply_pose_to_rig_view(rig, v_key, _pose_cfg, _layer_mode, _pose_scale, _micro_hover_enabled, _anim_time, _idle_cfg, _loco_cfg, loco_weights, _turn_cfg, entry.get("turn_state", {}) as Dictionary, jiggle_cfg_eff, kiting_cfg_eff, kiting_weights)


func _get_active_loco_weights() -> Dictionary:
	if _loco_cfg == null:
		return {}
	if _loco_preview_enabled:
		return BasePoseEvaluatorScript.compute_preview_locomotion_weights(_loco_preview_mode, _anim_time, _loco_cfg.auto_cycle_duration_sec)
	if _is_jiggle_loco_choreo_active():
		return BasePoseEvaluatorScript.compute_preview_locomotion_weights(LocomotionAnimConfigScript.PreviewMode.AUTO_CYCLE, _anim_time, _loco_cfg.auto_cycle_duration_sec)
	return {}


func _get_active_kiting_weights() -> Dictionary:
	if _kiting_cfg == null or not _kiting_preview_enabled:
		return {}
	return KitingEvaluatorScript.compute_preview_weights(_kiting_preview_mode, _anim_time, _kiting_cfg.auto_cycle_duration_sec)


func _get_grounded_preview_speed_norm() -> float:
	if not _grounded_preview_enabled or _grounded_cfg == null:
		return 0.0
	match _grounded_preview_mode:
		GroundedConfigScript.PreviewMode.GROUNDED_IDLE:
			return 0.0
		GroundedConfigScript.PreviewMode.WALK_STEADY:
			return 1.0
		GroundedConfigScript.PreviewMode.START_STOP_CYCLE:
			var cyc: float = fposmod(_grounded_demo_timer, 3.0)
			return 1.0 if cyc < 1.8 else 0.0
		GroundedConfigScript.PreviewMode.PIVOT_TURN:
			return 0.85
		_:
			var dur: float = maxf(_grounded_cfg.auto_demo_cycle_sec, 2.5)
			var u: float = fposmod(_grounded_demo_timer, dur) / dur
			if u < 0.22:
				return 0.0
			if u < 0.80:
				return 1.0
			return 0.0


func _step_grounded_preview(delta: float) -> void:
	if _grounded_eval == null or _grounded_cfg == null:
		return
	var prev_t: float = _grounded_demo_timer
	_grounded_demo_timer += delta
	var dur: float = maxf(_grounded_cfg.auto_demo_cycle_sec, 2.5)
	if _grounded_preview_mode == GroundedConfigScript.PreviewMode.AUTO_DEMO_CYCLE:
		var u_prev: float = fposmod(prev_t, dur) / dur
		var u_now: float = fposmod(_grounded_demo_timer, dur) / dur
		if u_prev < 0.52 and u_now >= 0.52:
			_grounded_eval.trigger_pivot(1.0)
	elif _grounded_preview_mode == GroundedConfigScript.PreviewMode.PIVOT_TURN:
		if int(floor(prev_t / 1.15)) != int(floor(_grounded_demo_timer / 1.15)):
			_grounded_eval.trigger_pivot(1.0 if (int(floor(_grounded_demo_timer / 1.15)) % 2 == 0) else -1.0)
	var sim_spd: float = _get_grounded_preview_speed_norm()
	_grounded_eval.step_gait(delta, sim_spd, -1.0, _grounded_cfg)
	_grounded_eval.consume_step_event()


func _apply_all_poses() -> void:
	if _evaluator == null:
		return
	var turns_live: bool = _turn_preview_enabled or _is_jiggle_turn_choreo_active()
	var turn_cfg_eff: TurnAnimConfigScript = _turn_cfg if turns_live else null
	var jiggle_cfg_eff: JigglePhysicsConfigScript = _jiggle_cfg if _jiggle_preview_enabled else null
	if _grounded_preview_enabled and _grounded_eval != null and _grounded_cfg != null:
		for entry: Dictionary in _rig_entries:
			var v_key_g: String = str(entry.get("cur_view", entry["view"]))
			var rig_g: PlanarCombatRig = entry["rig"] as PlanarCombatRig
			var turn_st_g: Dictionary = (entry.get("turn_state", {}) as Dictionary) if turns_live else {}
			var fam_g: String = BasePoseConfigScript.canonical_family_for_view(v_key_g)
			var fam_dict_g: Dictionary = _grounded_cfg.get_standing_family(fam_g)
			var motion_g: Dictionary = _grounded_eval.evaluate_motion_for_view(v_key_g, _grounded_cfg, _pose_scale)
			_evaluator.apply_composed_pose_to_view(rig_g, v_key_g, fam_dict_g, motion_g, _layer_mode, _pose_scale, turn_cfg_eff, turn_st_g, jiggle_cfg_eff, false, _anim_time, null)
		return
	var loco_weights: Dictionary = _get_active_loco_weights()
	var kiting_weights: Dictionary = _get_active_kiting_weights()
	var kiting_cfg_eff: KitingAnimConfigScript = _kiting_cfg if _kiting_preview_enabled else null
	for entry: Dictionary in _rig_entries:
		var v_key: String = str(entry.get("cur_view", entry["view"]))
		var rig: PlanarCombatRig = entry["rig"] as PlanarCombatRig
		var turn_st: Dictionary = (entry.get("turn_state", {}) as Dictionary) if turns_live else {}
		_evaluator.apply_pose_to_rig_view(rig, v_key, _pose_cfg, _layer_mode, _pose_scale, _micro_hover_enabled, _anim_time, _idle_cfg, _loco_cfg, loco_weights, turn_cfg_eff, turn_st, jiggle_cfg_eff, kiting_cfg_eff, kiting_weights)


func _on_tab_changed(tab_idx: int) -> void:
	_loco_preview_enabled = (tab_idx == 2)
	_turn_preview_enabled = (tab_idx == 3)
	_jiggle_preview_enabled = (tab_idx == 4)
	_kiting_preview_enabled = (tab_idx == 5)
	_grounded_preview_enabled = (tab_idx == 6)
	if _grounded_preview_enabled and _grounded_eval != null:
		_grounded_eval.reset_state()
		_grounded_demo_timer = 0.0
	if not (_turn_preview_enabled or _is_jiggle_turn_choreo_active()):
		_reset_all_rigs_to_home_views()
	elif _is_jiggle_turn_choreo_active():
		_turn_step_timer = 0.72
	if not _jiggle_preview_enabled and _evaluator != null:
		_evaluator.reset_jiggle_physics_state()
	if _hud != null:
		_hud.sync_loco_preview_checkbox(_loco_preview_enabled)
		_hud.sync_turn_preview_checkbox(_turn_preview_enabled)
		_hud.sync_jiggle_preview_checkbox(_jiggle_preview_enabled)
		_hud.sync_kiting_preview_checkbox(_kiting_preview_enabled)
		_hud.sync_grounded_preview_checkbox(_grounded_preview_enabled)
	_apply_all_poses()


func _toggle_hover() -> void:
	_on_hover_toggled(not _micro_hover_enabled)


func _on_hover_toggled(enabled: bool) -> void:
	_micro_hover_enabled = enabled
	if not enabled:
		_anim_time = 0.0
	if _hud != null:
		_hud.sync_hover_button(_micro_hover_enabled)
	_apply_all_poses()


func _toggle_ab_pose() -> void:
	if _layer_mode == BasePoseEvaluatorScript.PoseLayerMode.DEFAULT_RIG_REST:
		_layer_mode = _last_active_pose_mode
	else:
		_last_active_pose_mode = _layer_mode
		_layer_mode = BasePoseEvaluatorScript.PoseLayerMode.DEFAULT_RIG_REST
	if _hud != null:
		_hud.sync_ab_state(_layer_mode)
	_apply_all_poses()


func _on_mode_changed(idx: int) -> void:
	_layer_mode = clampi(idx, 0, 3)
	if _layer_mode != BasePoseEvaluatorScript.PoseLayerMode.DEFAULT_RIG_REST:
		_last_active_pose_mode = _layer_mode
	if _hud != null:
		_hud.sync_ab_state(_layer_mode)
	_apply_all_poses()


func _on_scale_changed(val: float) -> void:
	_pose_scale = val
	_apply_all_poses()


func _on_head_cycle_toggled(enabled: bool) -> void:
	_head_cycle_enabled = enabled
	if not enabled:
		for entry: Dictionary in _rig_entries:
			entry["head_idx"] = 0
			var rig: PlanarCombatRig = entry["rig"] as PlanarCombatRig
			var v_key: String = entry["view"] as String
			var heads: Array = entry["heads"] as Array
			if rig != null and not heads.is_empty():
				rig.set_static_inspection(true, v_key, str(heads[0]))
		_apply_all_poses()


func _on_face_live_toggled(enabled: bool) -> void:
	_face_live_enabled = enabled
	for entry: Dictionary in _rig_entries:
		var rig: PlanarCombatRig = entry["rig"] as PlanarCombatRig
		if rig != null:
			rig.set_face_live_enabled(enabled, _face_cfg.duplicate(true) as FaceAnimConfigScript if enabled else null)
	if not enabled:
		_apply_all_poses()


func _step_compass_faces(delta: float) -> void:
	var loco_w: Dictionary = _get_active_loco_weights()
	var kite_w: Dictionary = _get_active_kiting_weights()
	var w_fwd: float = float(loco_w.get("fwd", 0.0))
	var w_rev: float = float(loco_w.get("rev", 0.0))
	var w_brk: float = float(loco_w.get("brk", 0.0))
	var w_krev: float = float(kite_w.get("rev", 0.0))
	var w_rbrk: float = float(kite_w.get("rbrk", 0.0))
	var lat_signed: float = float(kite_w.get("lat_signed", 0.0))
	var kite_tot: float = float(kite_w.get("kiting_total", 0.0))
	var eff_loco: Dictionary = loco_w.duplicate()
	if _grounded_preview_enabled and _grounded_eval != null:
		eff_loco = {"fwd": _grounded_eval.walk_blend, "brk": _grounded_eval.stop_weight}
		w_fwd = _grounded_eval.walk_blend
		w_brk = _grounded_eval.stop_weight
	elif not kite_w.is_empty():
		eff_loco["brk"] = maxf(w_brk, w_rbrk)
	var turns_live: bool = _turn_preview_enabled or _is_jiggle_turn_choreo_active()
	var mouse_world: Vector2 = get_global_mouse_position() if (is_inside_tree() and get_viewport() != null) else Vector2.ZERO

	for entry: Dictionary in _rig_entries:
		var rig: PlanarCombatRig = entry["rig"] as PlanarCombatRig
		if rig == null or not rig.is_face_live_enabled():
			continue
		var v_key: String = str(entry.get("cur_view", entry["view"]))
		var heads: Array = entry.get("heads", [ViewRouterScript.get_default_head_for_body(v_key)]) as Array
		var h_idx: int = clampi(int(entry.get("head_idx", 0)), 0, maxi(heads.size() - 1, 0))
		var h_key: String = str(heads[h_idx])
		var h_fwd: Vector2 = ViewRouterScript.HEAD_DIR_VECTORS.get(h_key, Vector2.DOWN) as Vector2
		var to_mouse: Vector2 = (mouse_world - rig.global_position) / 360.0 if (is_inside_tree() and not _dragging) else Vector2.ZERO
		to_mouse = to_mouse.limit_length(0.75)
		var aim_dir: Vector2 = (h_fwd + to_mouse * 0.65).normalized()
		var body_fwd: Vector2 = ViewRouterScript.get_body_dir_vector(v_key)
		var mirror_sign: float = -1.0 if v_key in ["sw", "w", "nw"] else 1.0
		var body_lat := Vector2(-body_fwd.y, body_fwd.x)
		var sim_vel: Vector2 = body_fwd * (w_fwd * 1.05 - maxf(w_rev, w_krev) * 0.90 + maxf(w_brk, w_rbrk) * 0.25) + body_lat * (lat_signed * mirror_sign * 0.95)
		var sim_spd: float = maxf(sim_vel.length(), maxf(w_fwd, maxf(w_rev, kite_tot)))
		var t_st: Dictionary = (entry.get("turn_state", {}) as Dictionary) if turns_live else {}
		rig.step_face_live(delta, {
			"head_key": h_key,
			"aim_dir": aim_dir,
			"vel_norm": sim_vel,
			"speed_norm": sim_spd,
			"is_backpedaling": (w_rev > 0.25 or w_krev > 0.20 or absf(lat_signed) > 0.25),
			"loco_weights": eff_loco,
			"turn_state": t_st,
			"head_rot_rad": rig.get_manual_head_rot(),
			"head_offset_du": rig.get_manual_head_offset(),
			"sync_q_time": false,
		})


func _reset_camera() -> void:
	if _camera != null:
		_camera.position = DEFAULT_CAM_POS
		_camera.zoom = Vector2(DEFAULT_CAM_ZOOM, DEFAULT_CAM_ZOOM)
	for entry: Dictionary in _rig_entries:
		var rig: PlanarCombatRig = entry["rig"] as PlanarCombatRig
		if rig != null:
			rig.set_zoom_scale(DEFAULT_CAM_ZOOM)


func _on_family_selected(fam_key: String) -> void:
	_selected_family = BasePoseConfigScript.canonical_family_for_view(fam_key)
	_sync_hud_all()
	_refresh_compass_highlights()


func _on_param_changed(param_key: String, val: float) -> void:
	if _pose_cfg == null:
		return
	_pose_cfg.set_param(_selected_family, param_key, val)
	_apply_all_poses()


func _on_idle_layer_toggled(prop_name: String, enabled: bool) -> void:
	if _idle_cfg == null or not (prop_name in _idle_cfg):
		return
	_idle_cfg.set(prop_name, enabled)
	_apply_all_poses()


func _on_idle_cadence_changed(idx: int) -> void:
	if _idle_cfg == null:
		return
	_idle_cfg.cadence_mode = clampi(idx, 0, 3)
	_apply_all_poses()


func _on_idle_param_changed(param_key: String, val: float) -> void:
	if _idle_cfg == null:
		return
	_idle_cfg.set_global_param(param_key, val)
	_apply_all_poses()


func _on_idle_family_mul_changed(mul_key: String, val: float) -> void:
	if _idle_cfg == null:
		return
	_idle_cfg.set_family_mul(_selected_family, mul_key, val)
	_apply_all_poses()


func _on_loco_preview_toggled(enabled: bool) -> void:
	_loco_preview_enabled = enabled
	_apply_all_poses()


func _on_loco_mode_changed(idx: int) -> void:
	_loco_preview_mode = clampi(idx, 0, 3)
	_apply_all_poses()


func _on_loco_global_changed(param_key: String, val: float) -> void:
	if _loco_cfg == null:
		return
	_loco_cfg.set_global_param(param_key, val)
	_apply_all_poses()


func _on_loco_param_changed(param_key: String, val: float) -> void:
	if _loco_cfg == null:
		return
	_loco_cfg.set_family_param(_selected_family, param_key, val)
	_apply_all_poses()


func _on_kiting_preview_toggled(enabled: bool) -> void:
	_kiting_preview_enabled = enabled
	_apply_all_poses()


func _on_kiting_mode_changed(idx: int) -> void:
	_kiting_preview_mode = clampi(idx, 0, 4)
	_apply_all_poses()


func _on_kiting_edit_phase_changed(idx: int) -> void:
	var phases: Array[String] = KitingAnimConfigScript.PHASE_PREFIXES
	_kiting_edit_phase = str(phases[clampi(idx, 0, phases.size() - 1)])
	_sync_hud_all()


func _on_kiting_global_changed(param_key: String, val: float) -> void:
	if _kiting_cfg == null:
		return
	_kiting_cfg.set_global_param(param_key, val)
	_apply_all_poses()


func _on_kiting_param_changed(param_key: String, val: float) -> void:
	if _kiting_cfg == null:
		return
	_kiting_cfg.set_family_param(_selected_family, _kiting_edit_phase + param_key, val)
	_apply_all_poses()


func _on_turn_preview_toggled(enabled: bool) -> void:
	_turn_preview_enabled = enabled
	_turn_step_timer = 0.0
	if not enabled:
		_reset_all_rigs_to_home_views()
	_apply_all_poses()


func _on_turn_mode_changed(idx: int) -> void:
	_turn_preview_mode = clampi(idx, 0, 3)
	_turn_step_counter = 0
	_turn_step_timer = 0.0
	_reset_all_rigs_to_home_views()
	_apply_all_poses()


func _trigger_turn_step_now() -> void:
	if not _turn_preview_enabled and not _is_jiggle_turn_choreo_active():
		_turn_preview_enabled = true
		if _hud != null:
			_hud.sync_turn_preview_checkbox(true)
	_turn_step_timer = 0.0
	_turn_step_counter += 1
	var eff_turn_mode: int = _turn_preview_mode
	if not _turn_preview_enabled and _is_jiggle_turn_choreo_active():
		if _jiggle_preview_mode == JigglePhysicsConfigScript.PreviewMode.BRAKE_BOUNCE_PULSE:
			eff_turn_mode = TurnAnimConfigScript.PreviewMode.BODY_WHIP_90_CYCLE if ((_turn_step_counter - 1) / 2) % 2 == 1 else TurnAnimConfigScript.PreviewMode.BODY_STEP_45_CYCLE
		else:
			eff_turn_mode = TurnAnimConfigScript.PreviewMode.AUTO_BODY_AND_HEAD_CYCLE
	var phase: int = _turn_step_counter % 4
	var body_dur: float = _turn_cfg.body_turn_duration_sec if _turn_cfg != null else 0.135
	var swap_pt: float = _turn_cfg.body_swap_point if _turn_cfg != null else 0.34
	var head_dur: float = _turn_cfg.head_turn_duration_sec if _turn_cfg != null else 0.085

	for entry: Dictionary in _rig_entries:
		var home_v: String = str(entry.get("home_view", entry["view"]))
		var from_v: String = str(entry.get("cur_view", home_v))
		var heads_cur: Array = entry.get("heads", [ViewRouterScript.get_default_head_for_body(from_v)]) as Array
		var cur_h_idx: int = clampi(int(entry.get("head_idx", 0)), 0, maxi(heads_cur.size() - 1, 0))
		var from_h: String = str(heads_cur[cur_h_idx])

		var to_v: String = from_v
		var do_body: bool = false
		var do_head: bool = false
		var to_h_idx: int = cur_h_idx
		var to_h: String = from_h

		match eff_turn_mode:
			TurnAnimConfigScript.PreviewMode.BODY_STEP_45_CYCLE:
				do_body = true
				var home_idx1: int = ALL_VIEWS.find(home_v)
				var alt_v1: String = ALL_VIEWS[(home_idx1 + 1) % ALL_VIEWS.size()]
				to_v = alt_v1 if from_v == home_v else home_v
				var next_heads1: Array = _allowed_heads_for(to_v)
				to_h_idx = 0
				to_h = str(next_heads1[0])
				do_head = (from_h != to_h)
			TurnAnimConfigScript.PreviewMode.BODY_WHIP_90_CYCLE:
				do_body = true
				var home_idx2: int = ALL_VIEWS.find(home_v)
				var alt_v2: String = ALL_VIEWS[(home_idx2 + 2) % ALL_VIEWS.size()]
				to_v = alt_v2 if from_v == home_v else home_v
				var next_heads2: Array = _allowed_heads_for(to_v)
				to_h_idx = 0
				to_h = str(next_heads2[0])
				do_head = (from_h != to_h)
			TurnAnimConfigScript.PreviewMode.HEAD_ONLY_WHIP_CYCLE:
				to_v = home_v
				var home_heads: Array = _allowed_heads_for(home_v)
				if from_v != home_v:
					do_body = true
				elif home_heads.size() > 1:
					do_head = true
					to_h_idx = (cur_h_idx + 1) % home_heads.size()
					to_h = str(home_heads[to_h_idx])
			_:
				var home_idx0: int = ALL_VIEWS.find(home_v)
				var alt_v0: String = ALL_VIEWS[(home_idx0 + 1) % ALL_VIEWS.size()]
				if phase == 1:
					do_body = true
					to_v = alt_v0
					var next_h0: Array = _allowed_heads_for(to_v)
					to_h_idx = 0
					to_h = str(next_h0[0])
					do_head = (from_h != to_h)
				elif phase == 2 or phase == 0:
					if heads_cur.size() > 1:
						do_head = true
						to_h_idx = (cur_h_idx + 1) % heads_cur.size()
						to_h = str(heads_cur[to_h_idx])
				else:
					do_body = true
					to_v = home_v
					var home_h0: Array = _allowed_heads_for(home_v)
					to_h_idx = 0
					to_h = str(home_h0[0])
					do_head = (from_h != to_h)

		var from_vec: Vector2 = ViewRouterScript.get_body_dir_vector(from_v)
		var to_vec: Vector2 = ViewRouterScript.get_body_dir_vector(to_v)
		var dx_b: float = to_vec.x - from_vec.x
		var ang_b: float = from_vec.angle_to(to_vec)
		var b_dir: float = signf(dx_b) if absf(dx_b) > 0.08 else (signf(ang_b) if absf(ang_b) > 0.05 else 1.0)
		var b_mag: float = clampf(absf(ang_b) / (PI * 0.25), 0.85, 1.45)

		var hf_v: Vector2 = ViewRouterScript.HEAD_DIR_VECTORS.get(from_h, Vector2.DOWN) as Vector2
		var ht_v: Vector2 = ViewRouterScript.HEAD_DIR_VECTORS.get(to_h, Vector2.DOWN) as Vector2
		var dx_h: float = ht_v.x - hf_v.x
		var h_dir: float = signf(dx_h) if absf(dx_h) > 0.05 else (signf(hf_v.angle_to(ht_v)) if absf(hf_v.angle_to(ht_v)) > 0.05 else b_dir)

		entry["turn_state"] = {
			"body_active": do_body,
			"body_t": 0.0,
			"body_dur": body_dur,
			"body_swap_pt": swap_pt,
			"body_swapped": false,
			"body_turn_dir": b_dir,
			"body_turn_mag": b_mag,
			"to_view": to_v,
			"to_head": to_h,
			"to_head_idx": to_h_idx,
			"head_active": do_head,
			"head_t": 0.0,
			"head_dur": head_dur,
			"head_turn_dir": h_dir,
			"head_swapped": false,
		}


func _step_turn_previews(delta: float) -> void:
	_turn_step_timer += delta
	var interval: float = maxf(_turn_cfg.preview_step_interval_sec if _turn_cfg != null else 0.95, 0.25)
	if _turn_step_timer >= interval:
		_turn_step_timer = fmod(_turn_step_timer, interval)
		_trigger_turn_step_now()

	for entry: Dictionary in _rig_entries:
		var st: Dictionary = entry.get("turn_state", {}) as Dictionary
		if st.is_empty():
			continue
		var rig: PlanarCombatRig = entry["rig"] as PlanarCombatRig
		if bool(st.get("body_active", false)):
			var b_t: float = float(st["body_t"]) + delta / maxf(float(st["body_dur"]), 0.03)
			var swap_pt: float = float(st["body_swap_pt"])
			if not bool(st["body_swapped"]) and b_t >= swap_pt:
				st["body_swapped"] = true
				var next_v: String = str(st["to_view"])
				var next_h: String = str(st["to_head"])
				entry["cur_view"] = next_v
				entry["heads"] = _allowed_heads_for(next_v)
				entry["head_idx"] = int(st["to_head_idx"])
				st["head_swapped"] = true
				if rig != null:
					rig.set_static_inspection(true, next_v, next_h)
			if b_t >= 1.0:
				b_t = 1.0
				st["body_active"] = false
			st["body_t"] = b_t

		if bool(st.get("head_active", false)):
			var h_t: float = float(st["head_t"]) + delta / maxf(float(st["head_dur"]), 0.02)
			if not bool(st["head_swapped"]) and not bool(st.get("body_active", false)) and h_t >= 0.28:
				st["head_swapped"] = true
				var cur_v: String = str(entry.get("cur_view", entry["view"]))
				var next_h: String = str(st["to_head"])
				entry["head_idx"] = int(st["to_head_idx"])
				if rig != null:
					rig.set_static_inspection(true, cur_v, next_h)
			if h_t >= 1.0:
				h_t = 1.0
				st["head_active"] = false
			st["head_t"] = h_t


func _allowed_heads_for(v_key: String) -> Array:
	return (ViewRouterScript.ALLOWED_HEADS_BY_BODY_8DIR.get(v_key, [ViewRouterScript.get_default_head_for_body(v_key)]) as Array).duplicate()


func _reset_all_rigs_to_home_views() -> void:
	for entry: Dictionary in _rig_entries:
		var home_v: String = str(entry.get("home_view", entry["view"]))
		var heads: Array = _allowed_heads_for(home_v)
		entry["cur_view"] = home_v
		entry["heads"] = heads
		entry["head_idx"] = 0
		entry["turn_state"] = {}
		var rig: PlanarCombatRig = entry["rig"] as PlanarCombatRig
		if rig != null and not heads.is_empty():
			rig.set_static_inspection(true, home_v, str(heads[0]))


func _on_turn_param_changed(param_key: String, val: float) -> void:
	if _turn_cfg == null:
		return
	_turn_cfg.set_global_param(param_key, val)
	_apply_all_poses()


func _on_turn_family_mul_changed(mul_key: String, val: float) -> void:
	if _turn_cfg == null:
		return
	_turn_cfg.set_family_mul(_selected_family, mul_key, val)
	_apply_all_poses()


func _sample_active_turn_state() -> Dictionary:
	for entry: Dictionary in _rig_entries:
		var st: Dictionary = entry.get("turn_state", {}) as Dictionary
		if bool(st.get("body_active", false)) or bool(st.get("head_active", false)):
			return st
	if not _rig_entries.is_empty():
		return _rig_entries[0].get("turn_state", {}) as Dictionary
	return {}


func _step_jiggle_preview(delta: float) -> void:
	if _evaluator == null or _jiggle_cfg == null:
		return
	if _jiggle_preview_mode != JigglePhysicsConfigScript.PreviewMode.IDLE_BREATH_ONLY:
		_jiggle_pulse_timer += delta
		var interval: float = maxf(_jiggle_cfg.preview_pulse_interval_sec, 0.4)
		if _jiggle_pulse_timer >= interval:
			_jiggle_pulse_timer = fmod(_jiggle_pulse_timer, interval)
			_trigger_jiggle_impulse_now()
	var loco_w: Dictionary = _get_active_loco_weights()
	var kite_w: Dictionary = _get_active_kiting_weights()
	var turn_st: Dictionary = _sample_active_turn_state() if _is_jiggle_turn_choreo_active() else {}
	_evaluator.step_live_jiggle_physics(delta, loco_w, turn_st, _jiggle_cfg, kite_w)


func _on_jiggle_preview_toggled(enabled: bool) -> void:
	_jiggle_preview_enabled = enabled
	_jiggle_pulse_timer = 0.0
	if not (_turn_preview_enabled or _is_jiggle_turn_choreo_active()):
		_reset_all_rigs_to_home_views()
	elif _is_jiggle_turn_choreo_active():
		_turn_step_timer = 0.72
	if not enabled and _evaluator != null:
		_evaluator.reset_jiggle_physics_state()
	_apply_all_poses()


func _on_jiggle_mode_changed(idx: int) -> void:
	_jiggle_preview_mode = clampi(idx, 0, 3)
	_jiggle_pulse_timer = 0.0
	_jiggle_pulse_counter = 0
	if not _turn_preview_enabled:
		_reset_all_rigs_to_home_views()
	if _is_jiggle_turn_choreo_active():
		_turn_step_timer = 0.72
		_turn_step_counter = 0
	if _evaluator != null:
		_evaluator.reset_jiggle_physics_state()
	_apply_all_poses()


func _trigger_jiggle_impulse_now() -> void:
	if _evaluator == null or _jiggle_cfg == null:
		return
	if not _jiggle_preview_enabled:
		_jiggle_preview_enabled = true
		if _hud != null:
			_hud.sync_jiggle_preview_checkbox(true)
	_jiggle_pulse_counter += 1
	var side: float = 1.0 if (_jiggle_pulse_counter % 2 == 1) else -1.0
	var b_gain: float = _jiggle_cfg.bust_inertia_gain
	var g_gain: float = _jiggle_cfg.glute_inertia_gain
	var do_brake: bool = (_jiggle_preview_mode == JigglePhysicsConfigScript.PreviewMode.LATERAL_TURN_WHIP) or (_jiggle_preview_mode == JigglePhysicsConfigScript.PreviewMode.AUTO_CHOREO_CYCLE and (_jiggle_pulse_counter % 2 == 1))
	if do_brake:
		_evaluator.trigger_jiggle_impulse(Vector2(10.0 * side, 56.0) * b_gain, Vector2(8.0 * side, -48.0) * g_gain, side)
	elif _jiggle_preview_mode != JigglePhysicsConfigScript.PreviewMode.IDLE_BREATH_ONLY:
		_evaluator.trigger_jiggle_impulse(Vector2(52.0 * side, 18.0) * b_gain, Vector2(44.0 * side, -14.0) * g_gain, side)


func _on_jiggle_part_toggled(prop_name: String, enabled: bool) -> void:
	if _jiggle_cfg == null or not (prop_name in _jiggle_cfg):
		return
	_jiggle_cfg.set(prop_name, enabled)
	_apply_all_poses()


func _on_jiggle_param_changed(param_key: String, val: float) -> void:
	if _jiggle_cfg == null:
		return
	_jiggle_cfg.set_global_param(param_key, val)
	_apply_all_poses()


func _on_jiggle_family_mul_changed(mul_key: String, val: float) -> void:
	if _jiggle_cfg == null:
		return
	_jiggle_cfg.set_family_mul(_selected_family, mul_key, val)
	_apply_all_poses()


func _sync_hud_all() -> void:
	if _hud != null:
		_hud.sync_from_config(_pose_cfg, _selected_family, _layer_mode, _micro_hover_enabled, _idle_cfg, _loco_cfg, _loco_preview_enabled, _loco_preview_mode, _turn_cfg, _turn_preview_enabled, _turn_preview_mode, _jiggle_cfg, _jiggle_preview_enabled, _jiggle_preview_mode, _kiting_cfg, _kiting_preview_enabled, _kiting_preview_mode, _kiting_edit_phase, _grounded_cfg, _grounded_preview_enabled, _grounded_preview_mode)
		_hud.sync_face_live_checkbox(_face_live_enabled)


func _on_grounded_preview_toggled(enabled: bool) -> void:
	_grounded_preview_enabled = enabled
	if enabled and _grounded_eval != null:
		_grounded_eval.reset_state()
		_grounded_demo_timer = 0.0
	_apply_all_poses()


func _on_grounded_mode_changed(idx: int) -> void:
	_grounded_preview_mode = clampi(idx, 0, 4)
	_grounded_demo_timer = 0.0
	if _grounded_eval != null:
		_grounded_eval.reset_state()
	_apply_all_poses()


func _on_trigger_grounded_pivot() -> void:
	if _grounded_eval != null:
		_grounded_eval.trigger_pivot(1.0)
	_apply_all_poses()


func _on_grounded_param_changed(param_key: String, val: float) -> void:
	if _grounded_cfg == null or not (param_key in _grounded_cfg):
		return
	_grounded_cfg.set(param_key, val)
	_apply_all_poses()


func _on_grounded_family_mul_changed(mul_key: String, val: float) -> void:
	if _grounded_cfg == null:
		return
	_grounded_cfg.ensure_initialized()
	if _grounded_cfg.family_multipliers.has(_selected_family):
		var fm: Dictionary = _grounded_cfg.family_multipliers[_selected_family] as Dictionary
		fm[mul_key] = val
	_apply_all_poses()


func _save_grounded_tres() -> void:
	_save_resource_tres(_grounded_cfg, _active_grounded_loco_path, _active_grounded_loco_path.get_file())


func _reload_grounded_tres() -> void:
	if not ResourceLoader.exists(_active_grounded_loco_path):
		if _hud != null:
			_hud.set_feedback("No existe %s" % _active_grounded_loco_path.get_file(), false)
		return
	_grounded_cfg = _load_grounded_cfg_from_disk()
	_sync_hud_all()
	if _hud != null:
		_hud.set_feedback("Recargado desde %s" % _active_grounded_loco_path.get_file(), true)
	_apply_all_poses()


func _reset_grounded_defaults() -> void:
	if _grounded_cfg == null:
		return
	_grounded_cfg.reset_defaults()
	if _grounded_eval != null:
		_grounded_eval.reset_state()
	_sync_hud_all()
	if _hud != null:
		_hud.set_feedback("Hub Walk Grounded restaurado a defaults AAA.", true)
	_apply_all_poses()


func _save_resource_tres(res: Resource, path: String, label: String) -> void:
	if res == null:
		return
	var err: Error = ResourceSaver.save(res, path)
	if _hud != null:
		if err == OK:
			_hud.set_feedback("Guardado OK en %s" % label, true)
		else:
			_hud.set_feedback("Error al guardar %s (code %d)" % [label, err], false)


func _save_pose_tres() -> void:
	_save_resource_tres(_pose_cfg, _active_base_pose_path, _active_base_pose_path.get_file())


func _reload_pose_tres() -> void:
	if not ResourceLoader.exists(_active_base_pose_path):
		if _hud != null:
			_hud.set_feedback("No existe %s" % _active_base_pose_path.get_file(), false)
		return
	_pose_cfg = _load_pose_cfg_from_disk()
	_face_cfg = _load_face_cfg_from_disk()
	for entry: Dictionary in _rig_entries:
		var rig: PlanarCombatRig = entry["rig"] as PlanarCombatRig
		if rig != null:
			rig.set_face_anim_config(_face_cfg.duplicate(true) as FaceAnimConfigScript)
	_sync_hud_all()
	if _hud != null:
		_hud.set_feedback("Recargado desde %s" % _active_base_pose_path.get_file(), true)
	_apply_all_poses()


func _reset_selected_family() -> void:
	if _pose_cfg == null:
		return
	_pose_cfg.reset_family_to_defaults(_selected_family)
	_sync_hud_all()
	if _hud != null:
		_hud.set_feedback("Familia %s restaurada al preset táctico." % _selected_family.to_upper(), true)
	_apply_all_poses()


func _save_idle_tres() -> void:
	_save_resource_tres(_idle_cfg, _active_idle_anim_path, _active_idle_anim_path.get_file())


func _reload_idle_tres() -> void:
	if not ResourceLoader.exists(_active_idle_anim_path):
		if _hud != null:
			_hud.set_feedback("No existe %s" % _active_idle_anim_path.get_file(), false)
		return
	_idle_cfg = _load_idle_cfg_from_disk()
	_sync_hud_all()
	if _hud != null:
		_hud.set_feedback("Recargado desde %s" % _active_idle_anim_path.get_file(), true)
	_apply_all_poses()


func _reset_idle_defaults() -> void:
	if _idle_cfg == null:
		return
	_idle_cfg.reset_to_defaults()
	_sync_hud_all()
	if _hud != null:
		_hud.set_feedback("Idle Zero-G restaurado al preset táctico.", true)
	_apply_all_poses()


func _save_loco_tres() -> void:
	_save_resource_tres(_loco_cfg, _active_loco_anim_path, _active_loco_anim_path.get_file())


func _reload_loco_tres() -> void:
	if not ResourceLoader.exists(_active_loco_anim_path):
		if _hud != null:
			_hud.set_feedback("No existe %s" % _active_loco_anim_path.get_file(), false)
		return
	_loco_cfg = _load_loco_cfg_from_disk()
	_sync_hud_all()
	if _hud != null:
		_hud.set_feedback("Recargado desde %s" % _active_loco_anim_path.get_file(), true)
	_apply_all_poses()


func _reset_loco_family() -> void:
	if _loco_cfg == null:
		return
	_loco_cfg.reset_family_to_defaults(_selected_family)
	_sync_hud_all()
	if _hud != null:
		_hud.set_feedback("Vuelo/Freno %s restaurado al preset táctico." % _selected_family.to_upper(), true)
	_apply_all_poses()


func _save_turn_tres() -> void:
	_save_resource_tres(_turn_cfg, _active_turn_anim_path, _active_turn_anim_path.get_file())


func _reload_turn_tres() -> void:
	if not ResourceLoader.exists(_active_turn_anim_path):
		if _hud != null:
			_hud.set_feedback("No existe %s" % _active_turn_anim_path.get_file(), false)
		return
	_turn_cfg = _load_turn_cfg_from_disk()
	_sync_hud_all()
	if _hud != null:
		_hud.set_feedback("Recargado desde %s" % _active_turn_anim_path.get_file(), true)
	_apply_all_poses()


func _reset_turn_defaults() -> void:
	if _turn_cfg == null:
		return
	_turn_cfg.reset_to_defaults()
	_sync_hud_all()
	if _hud != null:
		_hud.set_feedback("Giros Snappy restaurado al preset táctico.", true)
	_apply_all_poses()


func _save_jiggle_tres() -> void:
	_save_resource_tres(_jiggle_cfg, _active_jiggle_physics_path, _active_jiggle_physics_path.get_file())


func _reload_jiggle_tres() -> void:
	if not ResourceLoader.exists(_active_jiggle_physics_path):
		if _hud != null:
			_hud.set_feedback("No existe %s" % _active_jiggle_physics_path.get_file(), false)
		return
	_jiggle_cfg = _load_jiggle_cfg_from_disk()
	_sync_hud_all()
	if _hud != null:
		_hud.set_feedback("Recargado desde %s" % _active_jiggle_physics_path.get_file(), true)
	_apply_all_poses()


func _reset_jiggle_defaults() -> void:
	if _jiggle_cfg == null:
		return
	_jiggle_cfg.reset_to_defaults()
	if _evaluator != null:
		_evaluator.reset_jiggle_physics_state()
	_sync_hud_all()
	if _hud != null:
		_hud.set_feedback("Jiggle Physics restaurado al preset sutil.", true)
	_apply_all_poses()


func _save_kiting_tres() -> void:
	_save_resource_tres(_kiting_cfg, _active_kiting_anim_path, _active_kiting_anim_path.get_file())


func _reload_kiting_tres() -> void:
	if not ResourceLoader.exists(_active_kiting_anim_path):
		if _hud != null:
			_hud.set_feedback("No existe %s" % _active_kiting_anim_path.get_file(), false)
		return
	_kiting_cfg = _load_kiting_cfg_from_disk()
	_sync_hud_all()
	if _hud != null:
		_hud.set_feedback("Recargado desde %s" % _active_kiting_anim_path.get_file(), true)
	_apply_all_poses()


func _reset_kiting_family() -> void:
	if _kiting_cfg == null:
		return
	_kiting_cfg.reset_family_to_defaults(_selected_family)
	_sync_hud_all()
	if _hud != null:
		_hud.set_feedback("Kiting 360° %s restaurado al preset táctico." % _selected_family.to_upper(), true)
	_apply_all_poses()


func _refresh_compass_highlights() -> void:
	for entry: Dictionary in _rig_entries:
		var v_key: String = entry["view"] as String
		var tag: Label = entry.get("tag", null) as Label
		if tag == null:
			continue
		var matches: bool = BasePoseConfigScript.canonical_family_for_view(v_key) == _selected_family
		tag.modulate = Color(0.45, 0.96, 1.0, 1.0) if matches else Color(0.72, 0.80, 0.95, 0.78)
	queue_redraw()


func _draw() -> void:
	var col := Color(0.28, 0.34, 0.48, 0.45)
	draw_arc(Vector2.ZERO, COMPASS_RADIUS, 0.0, TAU, 72, col, 1.5)
	draw_line(Vector2(-COMPASS_RADIUS - 30.0, 0.0), Vector2(COMPASS_RADIUS + 30.0, 0.0), col, 1.0)
	draw_line(Vector2(0.0, -COMPASS_RADIUS - 30.0), Vector2(0.0, COMPASS_RADIUS + 30.0), col, 1.0)
	for entry: Dictionary in _rig_entries:
		var v_key: String = entry["view"] as String
		if BasePoseConfigScript.canonical_family_for_view(v_key) == _selected_family:
			var p: Vector2 = entry["pos"] as Vector2
			draw_arc(p, 92.0, 0.0, TAU, 48, Color(0.32, 0.86, 1.0, 0.55), 2.0)


func _build_backdrop() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.10, 0.14, 1.0)
	bg.position = Vector2(-2400.0, -1600.0)
	bg.size = Vector2(4800.0, 3200.0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.z_index = -100
	add_child(bg)


func _build_world_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.glow_enabled = true
	env.glow_hdr_threshold = 1.25
	env.glow_intensity = 0.50
	env.glow_bloom = 0.08
	_world_env = WorldEnvironment.new()
	_world_env.name = "PoseLabWorldEnvironment"
	_world_env.environment = env
	add_child(_world_env)

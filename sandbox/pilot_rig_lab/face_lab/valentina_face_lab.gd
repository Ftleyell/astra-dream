extends Node2D
## Escena independiente de laboratorio para probar, calibrar y auditar las animaciones
## faciales, cervicales, parallax 2.5D Live2D, cabello en 3 zonas y monóculo de Valentina v2.

const FaceConfigScript = preload("res://sandbox/pilot_rig_lab/data/pilot_face_anim_config.gd")
const FaceRigScript = preload("res://sandbox/pilot_rig_lab/face_lab/valentina_face_rig.gd")
const FaceAnimatorScript = preload("res://sandbox/pilot_rig_lab/face_lab/valentina_face_animator.gd")
const FaceHudScript = preload("res://sandbox/pilot_rig_lab/face_lab/valentina_face_lab_hud.gd")
const ViewRouterScript = preload("res://sandbox/pilot_rig_lab/proto/planar_rig_view_router.gd")

const PROFILE_PATH: String = "res://sandbox/pilot_rig_lab/pilots/valentina_v2/valentina_v2_profile.tres"
const FACE_ANIM_PATH: String = "res://sandbox/pilot_rig_lab/pilots/valentina_v2/valentina_v2_face_anim.tres"

const HERO_POS := Vector2(160.0, 20.0)
const HERO_SCALE: float = 4.0
const GALLERY_SCALE: float = 1.65
const DEFAULT_CAM_POS := Vector2(-30.0, 0.0)
const DEFAULT_CAM_ZOOM: float = 1.0
const SLOWMO_SCALES: Array[float] = [1.0, 0.5, 0.25, 0.12]

const GALLERY_HEADS: Array[String] = [
	"head_front",
	"head_front_r",
	"head_front_l",
	"head_side_r",
	"head_side_l",
	"head_back_r",
	"head_back_l",
	"head_back",
]

const KEY_TO_HEAD: Dictionary = {
	KEY_1: "head_front",
	KEY_2: "head_front_r",
	KEY_3: "head_side_r",
	KEY_4: "head_back_r",
	KEY_5: "head_back",
	KEY_6: "head_back_l",
	KEY_7: "head_side_l",
	KEY_8: "head_front_l",
}

var _profile: PilotRigProfile = null
var _face_cfg: FaceConfigScript = null
var _animator: FaceAnimatorScript = null
var _hud: FaceHudScript = null
var _camera: Camera2D = null
var _world_env: WorldEnvironment = null

var _hero_container: Node2D = null
var _hero_rig: FaceRigScript = null
var _gallery_container: Node2D = null
var _gallery_rigs: Array[FaceRigScript] = []

var _view_mode: int = FaceConfigScript.LabViewMode.HERO_CLOSEUP
var _active_head_key: String = "head_front"
var _show_torso_ref: bool = true
var _auto_dir_cursor: bool = false
var _ab_static: bool = false
var _debug_view_mode: int = 0
var _slowmo_idx: int = 0
var _time_scale: float = 1.0
var _dragging: bool = false
var _whip_dir: float = 1.0


func _ready() -> void:
	_load_resources()
	_build_backdrop()
	_build_world_environment()

	_camera = Camera2D.new()
	_camera.name = "FaceLabCamera"
	_camera.position = DEFAULT_CAM_POS
	_camera.zoom = Vector2(DEFAULT_CAM_ZOOM, DEFAULT_CAM_ZOOM)
	add_child(_camera)

	_animator = FaceAnimatorScript.new()

	_hero_container = Node2D.new()
	_hero_container.name = "HeroStage"
	add_child(_hero_container)
	_hero_rig = FaceRigScript.new()
	_hero_rig.name = "HeroFaceRig"
	_hero_rig.position = HERO_POS
	_hero_rig.scale = Vector2(HERO_SCALE, HERO_SCALE)
	_hero_container.add_child(_hero_rig)
	_hero_rig.set_active_head(_active_head_key)
	_hero_rig.set_show_torso_ref(_show_torso_ref)

	_gallery_container = Node2D.new()
	_gallery_container.name = "Gallery8DirStage"
	_gallery_container.visible = false
	add_child(_gallery_container)
	_build_gallery_8dir()

	_hud = FaceHudScript.new()
	var skins: Array = _profile.skins if _profile != null else []
	var hair_presets: Array = _profile.hair_presets if _profile != null else []
	_hud.build(self, _face_cfg, skins, hair_presets, {
		"on_bool_changed": Callable(self, "_on_bool_changed"),
		"on_preset_changed": Callable(self, "_on_preset_changed"),
		"on_gaze_mode_changed": Callable(self, "_on_gaze_mode_changed"),
		"on_trigger_blink": Callable(self, "_on_trigger_blink"),
		"on_trigger_whip": Callable(self, "_on_trigger_whip"),
		"on_param_changed": Callable(self, "_on_param_changed"),
		"on_view_mode_changed": Callable(self, "set_view_mode"),
		"on_head_selected": Callable(self, "set_hero_head"),
		"on_lab_toggle": Callable(self, "_on_lab_toggle"),
		"on_skin_selected": Callable(self, "_on_skin_selected"),
		"on_hair_selected": Callable(self, "_on_hair_selected"),
		"on_debug_mode_changed": Callable(self, "set_debug_view_mode"),
		"on_slowmo_changed": Callable(self, "_on_slowmo_changed"),
		"on_ab_toggled": Callable(self, "_on_ab_toggled"),
		"on_reset_camera": Callable(self, "_reset_camera"),
		"on_save_tres": Callable(self, "_save_face_tres"),
		"on_reload_tres": Callable(self, "_reload_face_tres"),
		"on_reset_defaults": Callable(self, "_reset_face_defaults"),
	})

	_apply_zoom_to_rigs()
	_step_and_apply(0.016, Vector2.ZERO)


func _build_gallery_8dir() -> void:
	var spacing := Vector2(210.0, 290.0)
	var origin := Vector2(-130.0, -140.0)
	for i: int in range(GALLERY_HEADS.size()):
		var r: int = i / 4
		var c: int = i % 4
		var hk: String = GALLERY_HEADS[i]
		var pos := origin + Vector2(float(c) * spacing.x, float(r) * spacing.y)

		var rig := FaceRigScript.new()
		rig.name = "GalleryRig_%s" % hk
		rig.position = pos
		rig.scale = Vector2(GALLERY_SCALE, GALLERY_SCALE)
		_gallery_container.add_child(rig)
		rig.set_active_head(hk)
		rig.set_show_torso_ref(_show_torso_ref)
		_gallery_rigs.append(rig)

		var lbl := Label.new()
		lbl.text = hk
		lbl.position = pos + Vector2(-46.0, -148.0)
		lbl.modulate = Color(0.75, 0.85, 0.98, 0.88)
		_gallery_container.add_child(lbl)


func _load_resources() -> void:
	if ResourceLoader.exists(PROFILE_PATH):
		_profile = ResourceLoader.load(PROFILE_PATH) as PilotRigProfile
	_face_cfg = _load_face_cfg_from_disk()


func _load_face_cfg_from_disk() -> FaceConfigScript:
	var cfg: FaceConfigScript = null
	if ResourceLoader.exists(FACE_ANIM_PATH):
		var loaded: Resource = ResourceLoader.load(FACE_ANIM_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
		if loaded is FaceConfigScript:
			cfg = (loaded as FaceConfigScript).duplicate(true) as FaceConfigScript
	if cfg == null:
		cfg = FaceConfigScript.new()
	return cfg


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_zoom_camera(1.12)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom_camera(1.0 / 1.12)
		elif mb.button_index == MOUSE_BUTTON_RIGHT or mb.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = mb.pressed
	elif event is InputEventMouseMotion and _dragging and _camera != null:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		_camera.position -= mm.relative / maxf(_camera.zoom.x, 0.05)
	elif event is InputEventKey:
		var kev: InputEventKey = event as InputEventKey
		if kev.pressed and not kev.echo:
			if kev.keycode == KEY_B:
				_on_trigger_blink()
				get_viewport().set_input_as_handled()
			elif kev.keycode == KEY_W:
				_on_trigger_whip()
				get_viewport().set_input_as_handled()
			elif kev.keycode == KEY_V:
				var next_mode: int = 1 if _view_mode == FaceConfigScript.LabViewMode.HERO_CLOSEUP else 0
				set_view_mode(next_mode)
				get_viewport().set_input_as_handled()
			elif kev.keycode == KEY_T:
				set_show_torso_ref(not _show_torso_ref)
				get_viewport().set_input_as_handled()
			elif kev.keycode == KEY_TAB:
				_on_ab_toggled(not _ab_static)
				get_viewport().set_input_as_handled()
			elif kev.keycode == KEY_M:
				_on_slowmo_changed((_slowmo_idx + 1) % SLOWMO_SCALES.size())
				get_viewport().set_input_as_handled()
			elif kev.keycode == KEY_R:
				_reset_camera()
				get_viewport().set_input_as_handled()
			elif KEY_TO_HEAD.has(kev.keycode):
				set_hero_head(str(KEY_TO_HEAD[kev.keycode]))
				get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	var eff_delta: float = delta * _time_scale
	var ref_center: Vector2 = _hero_rig.get_active_head_screen_center() if (_view_mode == FaceConfigScript.LabViewMode.HERO_CLOSEUP and _hero_rig != null) else (_camera.position if _camera != null else Vector2.ZERO)
	var m_pos: Vector2 = get_global_mouse_position()
	var norm_radius: float = 340.0 / maxf(_camera.zoom.x if _camera != null else 1.0, 0.25)
	var raw_c: Vector2 = (m_pos - ref_center) / norm_radius
	var cursor_norm := Vector2(clampf(raw_c.x, -1.0, 1.0), clampf(raw_c.y, -1.0, 1.0))

	if _auto_dir_cursor and _view_mode == FaceConfigScript.LabViewMode.HERO_CLOSEUP and raw_c.length() > 0.14:
		var best_head: String = _pick_head_for_dir(raw_c.normalized())
		if best_head != _active_head_key:
			set_hero_head(best_head)

	_step_and_apply(eff_delta, cursor_norm)


func _step_and_apply(eff_delta: float, cursor_norm: Vector2) -> void:
	if _animator == null or _face_cfg == null:
		return
	var eval_head: String = "head_front" if _view_mode == FaceConfigScript.LabViewMode.GALLERY_8DIR else _active_head_key
	var state: Dictionary = _animator.step(eff_delta, _face_cfg, cursor_norm, eval_head, _ab_static)
	if _view_mode == FaceConfigScript.LabViewMode.HERO_CLOSEUP:
		if _hero_rig != null:
			_hero_rig.apply_face_state(state)
	else:
		for rig: FaceRigScript in _gallery_rigs:
			if rig != null:
				rig.apply_face_state(state)


func _pick_head_for_dir(dir_v: Vector2) -> String:
	var best_key: String = _active_head_key
	var best_dot: float = -2.0
	for hk: String in ViewRouterScript.HEAD_DIR_VECTORS.keys():
		var hv: Vector2 = ViewRouterScript.HEAD_DIR_VECTORS[hk] as Vector2
		var d: float = dir_v.dot(hv)
		if d > best_dot:
			best_dot = d
			best_key = hk
	return best_key


func _zoom_camera(factor: float) -> void:
	if _camera == null:
		return
	var mouse_before: Vector2 = get_global_mouse_position()
	var z: float = clampf(_camera.zoom.x * factor, 0.50, 10.0)
	_camera.zoom = Vector2(z, z)
	var mouse_after: Vector2 = get_global_mouse_position()
	_camera.position += (mouse_before - mouse_after)
	_apply_zoom_to_rigs()


func _apply_zoom_to_rigs() -> void:
	var cam_z: float = _camera.zoom.x if _camera != null else 1.0
	if _hero_rig != null:
		_hero_rig.set_zoom_scale(clampf(cam_z * HERO_SCALE * 0.45, 0.35, 4.0))
	for rig: FaceRigScript in _gallery_rigs:
		if rig != null:
			rig.set_zoom_scale(clampf(cam_z * GALLERY_SCALE * 0.6, 0.35, 4.0))


func _reset_camera() -> void:
	if _camera != null:
		_camera.position = DEFAULT_CAM_POS
		_camera.zoom = Vector2(DEFAULT_CAM_ZOOM, DEFAULT_CAM_ZOOM)
	_apply_zoom_to_rigs()


func set_view_mode(mode_idx: int) -> void:
	_view_mode = clampi(mode_idx, 0, 1)
	if _hero_container != null:
		_hero_container.visible = (_view_mode == FaceConfigScript.LabViewMode.HERO_CLOSEUP)
	if _gallery_container != null:
		_gallery_container.visible = (_view_mode == FaceConfigScript.LabViewMode.GALLERY_8DIR)
	_sync_hud()


func set_hero_head(head_key: String) -> void:
	_active_head_key = head_key
	if _hero_rig != null:
		_hero_rig.set_active_head(head_key)
	_sync_hud()


func set_show_torso_ref(enabled: bool) -> void:
	_show_torso_ref = enabled
	if _hero_rig != null:
		_hero_rig.set_show_torso_ref(enabled)
	for rig: FaceRigScript in _gallery_rigs:
		if rig != null:
			rig.set_show_torso_ref(enabled)
	_sync_hud()


func set_debug_view_mode(mode_id: int) -> void:
	_debug_view_mode = mode_id
	if _hero_rig != null:
		_hero_rig.set_debug_view_mode(mode_id)
	for rig: FaceRigScript in _gallery_rigs:
		if rig != null:
			rig.set_debug_view_mode(mode_id)
	if _hud != null:
		_hud.sync_debug_mode_id(mode_id)


func _on_bool_changed(prop_key: String, val: bool) -> void:
	if _face_cfg != null and prop_key in _face_cfg:
		_face_cfg.set(prop_key, val)


func _on_preset_changed(idx: int) -> void:
	if _face_cfg != null:
		_face_cfg.expression_preset = idx
		if _hud != null:
			_hud.set_feedback("Expresión: %s" % FaceConfigScript.PRESET_LABELS[clampi(idx, 0, FaceConfigScript.PRESET_LABELS.size() - 1)], true)


func _on_gaze_mode_changed(idx: int) -> void:
	if _face_cfg != null:
		_face_cfg.gaze_mode = idx


func _on_trigger_blink() -> void:
	if _animator != null:
		_animator.trigger_blink(false)


func _on_trigger_whip() -> void:
	if _animator != null:
		_whip_dir = -_whip_dir
		_animator.trigger_whip(_whip_dir)


func _on_param_changed(param_key: String, val: float) -> void:
	if _face_cfg != null:
		_face_cfg.set_param(param_key, val)


func _on_lab_toggle(key: String, val: bool) -> void:
	if key == "show_torso_ref":
		set_show_torso_ref(val)
	elif key == "auto_dir_cursor":
		_auto_dir_cursor = val


func _on_skin_selected(idx: int) -> void:
	if _profile == null or idx < 0 or idx >= _profile.skins.size():
		return
	var sk: PilotSkinPreset = _profile.skins[idx]
	if _hero_rig != null:
		_hero_rig.apply_skin_preset(sk)
	for rig: FaceRigScript in _gallery_rigs:
		if rig != null:
			rig.apply_skin_preset(sk)


func _on_hair_selected(idx: int) -> void:
	if _profile == null or idx < 0 or idx >= _profile.hair_presets.size():
		return
	var hp: PilotHairPreset = _profile.hair_presets[idx]
	var fb: Color = _profile.skins[0].hair_color if not _profile.skins.is_empty() else Color(0.86, 0.89, 0.96, 1.0)
	if _hero_rig != null:
		_hero_rig.apply_hair_preset(hp, fb)
	for rig: FaceRigScript in _gallery_rigs:
		if rig != null:
			rig.apply_hair_preset(hp, fb)


func _on_slowmo_changed(idx: int) -> void:
	_slowmo_idx = clampi(idx, 0, SLOWMO_SCALES.size() - 1)
	_time_scale = SLOWMO_SCALES[_slowmo_idx]
	_sync_hud()
	if _hud != null:
		_hud.set_feedback("Velocidad: %.2fx" % _time_scale, true)


func _on_ab_toggled(pressed: bool) -> void:
	_ab_static = pressed
	_sync_hud()
	if _hud != null:
		_hud.set_feedback("Modo A/B: %s" % ("ESTÁTICO ORIGINAL" if _ab_static else "RIG FACIAL VIVO"), true)


func _save_face_tres() -> void:
	if _face_cfg == null:
		return
	var err: Error = _face_cfg.save_to_path(FACE_ANIM_PATH)
	if _hud != null:
		if err == OK:
			_hud.set_feedback("Guardado OK en valentina_v2_face_anim.tres", true)
		else:
			_hud.set_feedback("Error guardando .tres (code %d)" % err, false)


func _reload_face_tres() -> void:
	_face_cfg = _load_face_cfg_from_disk()
	_sync_hud()
	if _hud != null:
		_hud.set_feedback("Recargado valentina_v2_face_anim.tres", true)


func _reset_face_defaults() -> void:
	if _face_cfg != null:
		_face_cfg.reset_to_defaults()
	if _animator != null:
		_animator.reset()
	_sync_hud()
	if _hud != null:
		_hud.set_feedback("Parámetros restaurados a valores por defecto.", true)


func _sync_hud() -> void:
	if _hud != null:
		_hud.sync_from_config(_face_cfg, _active_head_key, _show_torso_ref, _auto_dir_cursor, _ab_static, _view_mode, _slowmo_idx)


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
	_world_env.name = "FaceLabWorldEnvironment"
	_world_env.environment = env
	add_child(_world_env)


func get_hero_rig() -> FaceRigScript:
	return _hero_rig


func get_gallery_rigs() -> Array[FaceRigScript]:
	return _gallery_rigs


func get_animator() -> FaceAnimatorScript:
	return _animator


func get_face_config() -> FaceConfigScript:
	return _face_cfg

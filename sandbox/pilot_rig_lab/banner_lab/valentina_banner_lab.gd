extends Node2D
## Laboratorio aislado de Live Banner 2.5D para Selección de Personajes (Valentina v2).
## Calibra en tiempo real respiración, jiggle en hover, cabello Zero-G, parpadeo,
## parallax 2.5D por profundidad, rim-light y recolor de skins desde .tres.

const BannerCtrlScript = preload("res://scenes/pilots/banner/pilot_live_banner_controller.gd")
const ConfigScript = preload("res://data/pilots/schemas/pilot_live_banner_config.gd")
const HUDScript = preload("res://sandbox/pilot_rig_lab/banner_lab/valentina_banner_lab_hud.gd")

const PROFILE_PATH: String = "res://data/pilots/valentina_v2/valentina_v2_profile.tres"
const CONFIG_PATH: String = "res://data/pilots/valentina_v2/valentina_v2_live_banner.tres"

var _profile: PilotRigProfile = null
var _config: ConfigScript = null
var _camera: Camera2D = null
var _banner_ctrl: BannerCtrlScript = null
var _hud_refs: Dictionary = {}
var _target_zoom: float = 1.0


func _ready() -> void:
	_load_resources()
	_build_environment()
	_build_scene_nodes()

	var skin_labels: Array[String] = []
	if _profile != null:
		for s: PilotSkinPreset in _profile.skins:
			skin_labels.append(s.label if s != null else "Skin")
	if skin_labels.is_empty():
		skin_labels.append("Base Original")

	_hud_refs = HUDScript.build_hud(self, _config, skin_labels, {
		"on_select_pilot": Callable(self, "_on_select_pilot"),
		"on_reset_select": Callable(self, "_on_reset_select"),
		"on_debug_view_selected": Callable(self, "_on_debug_view_selected"),
		"on_skin_selected": Callable(self, "_on_skin_selected"),
		"on_trigger_blink": Callable(self, "_on_trigger_blink"),
		"on_trigger_impulse": Callable(self, "_on_trigger_impulse"),
		"on_auto_mouse_toggled": Callable(self, "_on_auto_mouse_toggled"),
		"on_save_config": Callable(self, "_on_save_config"),
		"on_reload_config": Callable(self, "_on_reload_config"),
	})


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var kev: InputEventKey = event as InputEventKey
		if kev.pressed and not kev.echo:
			if kev.keycode == KEY_B:
				_on_trigger_blink()
			elif kev.keycode == KEY_SPACE:
				_on_trigger_impulse()
			elif kev.keycode == KEY_ENTER or kev.keycode == KEY_KP_ENTER or kev.keycode == KEY_E:
				_on_select_pilot()
			elif kev.keycode == KEY_R:
				_on_reset_select()
	elif event is InputEventMouseButton:
		var mev: InputEventMouseButton = event as InputEventMouseButton
		if mev.pressed:
			if mev.button_index == MOUSE_BUTTON_WHEEL_UP:
				_target_zoom = clampf(_target_zoom * 1.1, 0.55, 2.4)
			elif mev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_target_zoom = clampf(_target_zoom / 1.1, 0.55, 2.4)
			elif mev.button_index == MOUSE_BUTTON_LEFT:
				_on_trigger_impulse()


func _process(delta: float) -> void:
	if _banner_ctrl != null:
		_banner_ctrl.step(delta)

	if _camera != null:
		var cur_z: float = _camera.zoom.x
		var punch_mul: float = 1.0 + (_banner_ctrl.get_camera_zoom_punch() if _banner_ctrl != null else 0.0)
		var desired_z: float = _target_zoom * punch_mul
		var next_z: float = lerpf(cur_z, desired_z, clampf(delta * 14.0, 0.0, 1.0))
		_camera.zoom = Vector2(next_z, next_z)
		var shake_off: Vector2 = _banner_ctrl.get_camera_shake_offset() if _banner_ctrl != null else Vector2.ZERO
		_camera.position = Vector2(-140.0, 0.0) + shake_off
		if _banner_ctrl != null:
			_banner_ctrl.set_zoom_scale(next_z)


func get_banner_controller() -> BannerCtrlScript:
	return _banner_ctrl


func get_config() -> ConfigScript:
	return _config


func _load_resources() -> void:
	if ResourceLoader.exists(PROFILE_PATH):
		_profile = ResourceLoader.load(PROFILE_PATH) as PilotRigProfile
	if ResourceLoader.exists(CONFIG_PATH):
		_config = ResourceLoader.load(CONFIG_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as ConfigScript
	if _config == null:
		_config = ConfigScript.new()
	_config.ensure_defaults()


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.glow_enabled = true
	env.glow_hdr_threshold = 1.25
	env.glow_intensity = 0.45
	env.glow_bloom = 0.0
	var we := WorldEnvironment.new()
	we.name = "BannerLabWorldEnvironment"
	we.environment = env
	add_child(we)


func _build_scene_nodes() -> void:
	RenderingServer.set_default_clear_color(Color(0.05, 0.055, 0.08, 1.0))

	_camera = Camera2D.new()
	_camera.name = "BannerLabCamera"
	_camera.position = Vector2(-140.0, 0.0) # Compensa el panel lateral izquierdo
	_camera.zoom = Vector2(_target_zoom, _target_zoom)
	add_child(_camera)

	_banner_ctrl = BannerCtrlScript.new()
	_banner_ctrl.name = "PilotLiveBannerController"
	_banner_ctrl.set_config(_config)
	add_child(_banner_ctrl)


func _on_select_pilot() -> void:
	if _banner_ctrl != null:
		_banner_ctrl.trigger_select_sequence()


func _on_reset_select() -> void:
	if _banner_ctrl != null:
		_banner_ctrl.reset_select_sequence()


func _on_debug_view_selected(idx: int) -> void:
	if _banner_ctrl != null:
		_banner_ctrl.set_debug_view_mode(idx)


func _on_skin_selected(idx: int) -> void:
	if _banner_ctrl == null or _profile == null:
		return
	if idx >= 0 and idx < _profile.skins.size():
		_banner_ctrl.apply_skin_preset(_profile.skins[idx])


func _on_trigger_blink() -> void:
	if _banner_ctrl != null:
		_banner_ctrl.trigger_blink()


func _on_trigger_impulse() -> void:
	if _banner_ctrl != null:
		_banner_ctrl.trigger_hover_impulse(1.0)


func _on_auto_mouse_toggled(enabled: bool) -> void:
	if _banner_ctrl != null:
		_banner_ctrl.set_auto_mouse_demo(enabled)


func _on_save_config() -> void:
	if _config == null:
		return
	var err: Error = ResourceSaver.save(_config, CONFIG_PATH)
	var status: Label = _hud_refs.get("status_label", null) as Label
	if is_instance_valid(status):
		status.text = "Guardado OK: valentina_v2_live_banner.tres" if err == OK else ("Error al guardar: %d" % err)


func _on_reload_config() -> void:
	if not ResourceLoader.exists(CONFIG_PATH):
		return
	var reloaded: ConfigScript = ResourceLoader.load(CONFIG_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as ConfigScript
	if reloaded != null:
		_config = reloaded
		_config.ensure_defaults()
		if _banner_ctrl != null:
			_banner_ctrl.set_config(_config)
		HUDScript.sync_sliders(_hud_refs, _config)
		var status: Label = _hud_refs.get("status_label", null) as Label
		if is_instance_valid(status):
			status.text = "Recargado desde .tres"

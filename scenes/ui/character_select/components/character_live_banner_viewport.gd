class_name CharacterLiveBannerViewport
extends SubViewportContainer
## Contenedor SubViewport HDR reutilizable para renderizar PilotLiveBannerController
## dentro de CharacterSelectUI y HeroPickerModal, pausándose cuando está oculto.

const BannerControllerScript = preload("res://scenes/pilots/banner/pilot_live_banner_controller.gd")

const FRAMED_HEIGHT_PX: float = 720.0
const FRAMED_WIDTH_PX: float = 560.0

var _subviewport: SubViewport = null
var _camera: Camera2D = null
var _banner_ctrl: PilotLiveBannerController = null
var _loaded_config: PilotLiveBannerConfig = null
var _base_zoom: float = 1.0


func _init() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_viewport_nodes()


func _ready() -> void:
	if not resized.is_connected(_update_camera_fit):
		resized.connect(_update_camera_fit)
	_update_camera_fit()
	_sync_update_mode()


func _build_viewport_nodes() -> void:
	if _subviewport != null:
		return
	_subviewport = SubViewport.new()
	_subviewport.name = "LiveBannerSubViewport"
	_subviewport.transparent_bg = true
	_subviewport.use_hdr_2d = true
	_subviewport.msaa_2d = Viewport.MSAA_4X
	_subviewport.handle_input_locally = false
	_subviewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_subviewport)

	_camera = Camera2D.new()
	_camera.name = "LiveBannerCamera"
	_camera.enabled = true
	_camera.position = Vector2.ZERO
	_camera.zoom = Vector2.ONE
	_subviewport.add_child(_camera)


func load_banner(cfg: PilotLiveBannerConfig, _profile: PilotRigProfile = null) -> void:
	if cfg == null:
		return
	if _banner_ctrl == null:
		_banner_ctrl = BannerControllerScript.new() as PilotLiveBannerController
		_banner_ctrl.name = "PilotLiveBannerController"
		_banner_ctrl.set_config(cfg)
		_subviewport.add_child(_banner_ctrl)
		_loaded_config = cfg
	elif _loaded_config != cfg:
		_banner_ctrl.set_config(cfg)
		_loaded_config = cfg
	_update_camera_fit()
	_sync_update_mode()


func apply_skin_preset(preset: PilotSkinPreset, star_level: int = 1) -> void:
	if _banner_ctrl != null:
		_banner_ctrl.apply_skin_preset(preset, star_level)


func apply_wings_skin_preset(preset: PilotSkinPreset, star_level: int = 1) -> void:
	if _banner_ctrl != null:
		_banner_ctrl.apply_wings_skin_preset(preset, star_level)


func trigger_hover_impulse(strength: float = 0.85) -> void:
	if _banner_ctrl != null:
		_banner_ctrl.trigger_hover_impulse(strength)


func trigger_select_sequence() -> void:
	if _banner_ctrl != null:
		_banner_ctrl.trigger_select_sequence()


func reset_select_sequence() -> void:
	if _banner_ctrl != null:
		_banner_ctrl.reset_select_sequence()


func get_banner_controller() -> PilotLiveBannerController:
	return _banner_ctrl


func get_subviewport() -> SubViewport:
	return _subviewport


func _sync_update_mode() -> void:
	if _subviewport == null:
		return
	var active: bool = is_visible_in_tree() and _banner_ctrl != null
	_subviewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED


func _update_camera_fit() -> void:
	if _camera == null:
		return
	if size.x < 4.0 or size.y < 4.0:
		_base_zoom = 1.0
		_camera.zoom = Vector2.ONE
		return
	_base_zoom = maxf(0.1, minf(size.y / FRAMED_HEIGHT_PX, size.x / FRAMED_WIDTH_PX))
	_camera.zoom = Vector2(_base_zoom, _base_zoom)
	if _banner_ctrl != null:
		_banner_ctrl.set_zoom_scale(_base_zoom)


func _process(delta: float) -> void:
	if _subviewport == null:
		return
	if not is_visible_in_tree() or _banner_ctrl == null:
		if _subviewport.render_target_update_mode != SubViewport.UPDATE_DISABLED:
			_subviewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return

	if _subviewport.render_target_update_mode != SubViewport.UPDATE_ALWAYS:
		_subviewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		_update_camera_fit()

	var rect: Rect2 = get_global_rect()
	if rect.size.x > 1.0 and rect.size.y > 1.0 and DisplayServer.get_name() != "headless":
		var mouse_pos: Vector2 = get_global_mouse_position()
		var norm: Vector2 = ((mouse_pos - rect.position) / rect.size) * 2.0 - Vector2.ONE
		_banner_ctrl.set_mouse_normalized(Vector2(clampf(norm.x, -1.0, 1.0), clampf(norm.y, -1.0, 1.0)))

	_banner_ctrl.step(delta)
	if _camera != null:
		var punch_zoom: float = _base_zoom * (1.0 + _banner_ctrl.get_camera_zoom_punch())
		_camera.zoom = Vector2(punch_zoom, punch_zoom)
		_camera.position = _banner_ctrl.get_camera_shake_offset()
		_banner_ctrl.set_zoom_scale(punch_zoom)

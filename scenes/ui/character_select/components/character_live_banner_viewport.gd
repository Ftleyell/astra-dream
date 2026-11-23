class_name CharacterLiveBannerViewport
extends SubViewportContainer
## Contenedor SubViewport HDR reutilizable para renderizar PilotLiveBannerController
## dentro de CharacterSelectUI y HeroPickerModal, pausándose cuando está oculto.

signal framing_changed()

const BannerControllerScript = preload("res://scenes/pilots/banner/pilot_live_banner_controller.gd")

const FRAMED_HEIGHT_PX: float = 720.0
const FRAMED_WIDTH_PX: float = 560.0

@export_group("Framing")
@export var framing_offset: Vector2 = Vector2.ZERO:
	set(value):
		framing_offset = value
		_update_camera_fit()
@export_range(0.4, 2.0, 0.01) var framing_zoom_mult: float = 1.0:
	set(value):
		framing_zoom_mult = clampf(value, 0.4, 2.0)
		_update_camera_fit()

@export_group("Background Integration")
@export_range(0.4, 0.98, 0.01) var bg_bottom_fade_start: float = 0.72:
	set(value):
		bg_bottom_fade_start = value
		_sync_integration_uniforms()
@export var bg_ambient_tint: Color = Color(0.05, 0.08, 0.16, 1.0):
	set(value):
		bg_ambient_tint = value
		_sync_integration_uniforms()
@export_range(0.0, 0.5, 0.01) var bg_ambient_mix: float = 0.14:
	set(value):
		bg_ambient_mix = value
		_sync_integration_uniforms()

var _subviewport: SubViewport = null
var _camera: Camera2D = null
var _banner_ctrl: PilotLiveBannerController = null
var _loaded_config: PilotLiveBannerConfig = null
var _base_zoom: float = 1.0
var _showcase_rim_boost: float = 0.0
var _showcase_rim_color: Color = Color(0.82, 0.96, 1.0, 1.0)
var _showcase_light_wrap_boost: float = 0.0


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
	_subviewport.disable_3d = true
	_subviewport.transparent_bg = true
	_subviewport.use_hdr_2d = true
	_subviewport.msaa_2d = Viewport.MSAA_4X
	_subviewport.handle_input_locally = false
	_subviewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_subviewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_subviewport)

	_camera = Camera2D.new()
	_camera.name = "LiveBannerCamera"
	_camera.enabled = true
	_camera.position = framing_offset
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
	if _showcase_rim_boost > 0.0 or _showcase_light_wrap_boost > 0.0:
		_banner_ctrl.set_showcase_rim_boost(_showcase_rim_boost, _showcase_rim_color, _showcase_light_wrap_boost)
	_update_camera_fit()
	_sync_update_mode()


func set_showcase_lighting(rim_boost: float, rim_color: Color = Color(0.82, 0.96, 1.0, 1.0), light_wrap_boost: float = 0.14) -> void:
	_showcase_rim_boost = maxf(rim_boost, 0.0)
	_showcase_rim_color = rim_color
	_showcase_light_wrap_boost = clampf(light_wrap_boost, 0.0, 0.6)
	if _banner_ctrl != null:
		_banner_ctrl.set_showcase_rim_boost(_showcase_rim_boost, _showcase_rim_color, _showcase_light_wrap_boost)


func get_character_local_center(world_offset: Vector2 = Vector2.ZERO) -> Vector2:
	return size * 0.5 + (world_offset - framing_offset) * _base_zoom


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


func set_framing(offset_px: Vector2, zoom_mult: float = 1.0) -> void:
	framing_offset = offset_px
	framing_zoom_mult = clampf(zoom_mult, 0.4, 2.0)
	_update_camera_fit()


func set_background_integration(
	enabled: bool,
	bottom_fade_start: float = 0.72,
	ambient_tint: Color = Color(0.05, 0.08, 0.16, 1.0),
	ambient_mix: float = 0.14
) -> void:
	if not enabled:
		material = null
		return
	bg_bottom_fade_start = bottom_fade_start
	bg_ambient_tint = ambient_tint
	bg_ambient_mix = ambient_mix
	if not (material is ShaderMaterial):
		var shader := Shader.new()
		shader.code = """shader_type canvas_item;
uniform float bottom_fade_start : hint_range(0.4, 0.99) = 0.78;
uniform vec4 ambient_tint : source_color = vec4(0.05, 0.08, 0.16, 1.0);
uniform float ambient_mix : hint_range(0.0, 0.5) = 0.0;
void fragment() {
	vec4 col = texture(TEXTURE, UV) * COLOR;
	float bottom_mask = smoothstep(0.995, bottom_fade_start, UV.y);
	float lower_blend = smoothstep(bottom_fade_start, 0.99, UV.y);
	col.rgb = mix(col.rgb, ambient_tint.rgb, lower_blend * ambient_mix);
	col.a *= bottom_mask;
	COLOR = col;
}
"""
		var mat := ShaderMaterial.new()
		mat.shader = shader
		material = mat
	_sync_integration_uniforms()


func _sync_integration_uniforms() -> void:
	var mat := material as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter("bottom_fade_start", bg_bottom_fade_start)
	mat.set_shader_parameter("ambient_tint", bg_ambient_tint)
	mat.set_shader_parameter("ambient_mix", bg_ambient_mix)


func _update_camera_fit() -> void:
	if _camera == null:
		return
	if size.x < 4.0 or size.y < 4.0:
		_base_zoom = 1.0
		_camera.zoom = Vector2.ONE
		_camera.position = framing_offset
		return
	_base_zoom = maxf(0.1, minf(size.y / FRAMED_HEIGHT_PX, size.x / FRAMED_WIDTH_PX) * framing_zoom_mult)
	_camera.zoom = Vector2(_base_zoom, _base_zoom)
	_camera.position = framing_offset
	if _banner_ctrl != null:
		_banner_ctrl.set_zoom_scale(_base_zoom)
	framing_changed.emit()


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
		_camera.position = framing_offset + _banner_ctrl.get_camera_shake_offset()
		_banner_ctrl.set_zoom_scale(punch_zoom)

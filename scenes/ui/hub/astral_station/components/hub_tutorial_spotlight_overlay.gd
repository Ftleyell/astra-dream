class_name HubTutorialSpotlightOverlay
extends CanvasLayer

## Full-screen radial spotlight blur + cosmic dim overlay for the Hub 3D tutorial.
## Sits at layer 38 (above Hub 3D/Cosmos/Player, below Dialogic at layer 42 and Dev Panel at 55)
## so Mochi's Dialogic portrait and textbox stay crisp while the background around the
## highlighted station smoothly blurs and dims.

const SPOTLIGHT_SHADER: Shader = preload("res://shaders/ui/hub_tutorial_spotlight_blur.gdshader")
const LAYER_INDEX: int = 38
const FADE_SPEED: float = 6.5
const TRACK_SPEED: float = 10.0
const RADIUS_SPEED: float = 7.0

var _rect: ColorRect = null
var _mat: ShaderMaterial = null
var _active: bool = false
var _target_enabled: bool = false
var _target_world_2d: Vector2 = Vector2.ZERO
var _has_focus_uv: bool = false
var _current_focus_uv: Vector2 = Vector2(0.5, 0.5)
var _current_alpha: float = 0.0
var _current_radius: float = 0.18
var _target_radius: float = 0.18
var _blur_strength: float = 2.4
var _dim_strength: float = 0.56
var _softness: float = 0.16
var _dim_color: Color = Color(0.035, 0.045, 0.11, 1.0)


func _ready() -> void:
	layer = LAYER_INDEX
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_rect()


func _ensure_rect() -> void:
	if is_instance_valid(_rect):
		return
	_rect = ColorRect.new()
	_rect.name = "TutorialSpotlightRect"
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.color = Color(1.0, 1.0, 1.0, 1.0)
	_rect.visible = false
	_mat = ShaderMaterial.new()
	_mat.shader = SPOTLIGHT_SHADER
	_rect.material = _mat
	add_child(_rect)
	_push_uniforms(1.7777778)


func configure_style(blur_strength: float, dim_strength: float, softness: float, dim_color: Color) -> void:
	_ensure_rect()
	_blur_strength = clampf(blur_strength, 0.0, 6.0)
	_dim_strength = clampf(dim_strength, 0.0, 0.95)
	_softness = clampf(softness, 0.02, 0.6)
	_dim_color = dim_color
	_push_uniforms(_compute_aspect_ratio())


func set_target(world_pos_2d: Vector2, enabled: bool, radius: float) -> void:
	_ensure_rect()
	var was_visible: bool = _active and _target_enabled and _current_alpha > 0.02
	_active = true
	_target_enabled = enabled
	_target_world_2d = world_pos_2d
	_target_radius = clampf(radius, 0.05, 0.65)
	if enabled:
		if not was_visible:
			_current_radius = _target_radius
			_has_focus_uv = false
		_rect.visible = true


func deactivate(instant: bool = false) -> void:
	_active = false
	_target_enabled = false
	_has_focus_uv = false
	if instant:
		_current_alpha = 0.0
		if is_instance_valid(_rect):
			_rect.visible = false
		_push_uniforms(_compute_aspect_ratio())


func _process(delta: float) -> void:
	if not is_instance_valid(_rect) or _mat == null:
		return
	var desired_alpha: float = 1.0 if (_active and _target_enabled) else 0.0
	var dt: float = minf(delta, 0.05)
	var fade_t: float = 1.0 - exp(-FADE_SPEED * dt)
	_current_alpha = lerpf(_current_alpha, desired_alpha, fade_t)
	if desired_alpha <= 0.0 and _current_alpha <= 0.004:
		_current_alpha = 0.0
		_rect.visible = false
		_mat.set_shader_parameter("effect_alpha", 0.0)
		return
	if _current_alpha > 0.001 or desired_alpha > 0.0:
		_rect.visible = true

	var aspect: float = _compute_aspect_ratio()
	var target_uv: Vector2 = _project_world_to_uv(_target_world_2d)
	if not _has_focus_uv:
		_current_focus_uv = target_uv
		_has_focus_uv = true
	else:
		var track_t: float = 1.0 - exp(-TRACK_SPEED * dt)
		_current_focus_uv = _current_focus_uv.lerp(target_uv, track_t)

	var radius_t: float = 1.0 - exp(-RADIUS_SPEED * dt)
	_current_radius = lerpf(_current_radius, _target_radius, radius_t)
	_push_uniforms(aspect)


func _compute_aspect_ratio() -> float:
	var vp: Viewport = get_viewport()
	if vp == null:
		return 1.7777778
	var vp_size: Vector2 = vp.get_visible_rect().size
	if vp_size.y <= 1.0:
		return 1.7777778
	return maxf(vp_size.x / vp_size.y, 0.5)


func _project_world_to_uv(world_pos_2d: Vector2) -> Vector2:
	var vp: Viewport = get_viewport()
	if vp == null:
		return Vector2(0.5, 0.5)
	var vp_size: Vector2 = vp.get_visible_rect().size
	if vp_size.x <= 1.0 or vp_size.y <= 1.0:
		return Vector2(0.5, 0.5)
	var screen_pos: Vector2 = vp.get_canvas_transform() * world_pos_2d
	return Vector2(
		clampf(screen_pos.x / vp_size.x, 0.0, 1.0),
		clampf(screen_pos.y / vp_size.y, 0.0, 1.0)
	)


func _push_uniforms(aspect: float) -> void:
	if _mat == null:
		return
	_mat.set_shader_parameter("focus_uv", _current_focus_uv)
	_mat.set_shader_parameter("aspect_ratio", aspect)
	_mat.set_shader_parameter("inner_radius", _current_radius)
	_mat.set_shader_parameter("outer_radius", _current_radius + _softness)
	_mat.set_shader_parameter("blur_strength", _blur_strength)
	_mat.set_shader_parameter("dim_strength", _dim_strength)
	_mat.set_shader_parameter("dim_color", _dim_color)
	_mat.set_shader_parameter("effect_alpha", _current_alpha)


func get_effect_alpha() -> float:
	return _current_alpha


func get_focus_uv() -> Vector2:
	return _current_focus_uv


func get_shader_material() -> ShaderMaterial:
	return _mat


func is_spotlight_visible() -> bool:
	return is_instance_valid(_rect) and _rect.visible

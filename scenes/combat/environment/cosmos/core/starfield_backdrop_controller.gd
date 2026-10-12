class_name CosmosStarfieldBackdropController
extends ColorRect

## Controlador de fondo óptico para el buffer estelar 8K (deep_starfield.gdshader).
## Proyecta el lecho estelar infinito en un CanvasLayer (-105) inmune al zoom de la cámara.
## Mantiene tamaño de píxel óptico constante y actualiza scroll_scale y cámara en runtime.

@export var camera: Camera2D
@export var scroll_scale: Vector2 = Vector2(0.0015, 0.0015):
	set(v):
		scroll_scale = v
		if _shader_mat != null:
			_shader_mat.set_shader_parameter("scroll_scale", scroll_scale)

@export var auto_sync_viewport: bool = true

var _shader_mat: ShaderMaterial = null
var accumulated_origin_shift: Vector2 = Vector2.ZERO

func _ready() -> void:
	if material is ShaderMaterial:
		_shader_mat = material as ShaderMaterial
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_update_uniforms()

func _process(_delta: float) -> void:
	_update_uniforms()

func _update_uniforms() -> void:
	if _shader_mat == null:
		return

	_shader_mat.set_shader_parameter("scroll_scale", scroll_scale)

	if auto_sync_viewport:
		var vp_rect: Rect2 = get_viewport_rect()
		var res: Vector2 = vp_rect.size if vp_rect.size != Vector2.ZERO else Vector2(1920.0, 1080.0)
		_shader_mat.set_shader_parameter("viewport_resolution", res)

	if camera != null:
		var cam_pos: Vector2 = camera.get_screen_center_position()
		if cam_pos == Vector2.ZERO and camera.global_position != Vector2.ZERO:
			cam_pos = camera.global_position
		var world_cam: Vector2 = cam_pos + accumulated_origin_shift
		_shader_mat.set_shader_parameter("camera_world_position", world_cam)

func on_origin_shifted(shift: Vector2) -> void:
	accumulated_origin_shift += shift

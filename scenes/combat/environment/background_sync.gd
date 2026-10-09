class_name BackgroundSync
extends ColorRect

## background_sync.gd
## Sincroniza la posición global de la cámara activa y las dimensiones del viewport
## con el shader procedural del fondo espacial continuo.

@export var target_camera: Camera2D

var _mat: ShaderMaterial


func _ready() -> void:
	if material is ShaderMaterial:
		_mat = material as ShaderMaterial
	_sync_viewport_dimensions()
	var vp: Viewport = get_viewport()
	if is_instance_valid(vp):
		vp.size_changed.connect(_sync_viewport_dimensions)


func _process(_delta: float) -> void:
	if not is_instance_valid(target_camera):
		var vp: Viewport = get_viewport()
		if is_instance_valid(vp):
			target_camera = vp.get_camera_2d()
		if not is_instance_valid(target_camera):
			return

	var cam_pos: Vector2 = target_camera.get_screen_center_position()
	if is_instance_valid(_mat):
		_mat.set_shader_parameter("camera_world_position", cam_pos)
		_mat.set_shader_parameter("camera_zoom", target_camera.zoom)


func _sync_viewport_dimensions() -> void:
	var vp_rect: Vector2 = get_viewport_rect().size
	if is_instance_valid(_mat):
		_mat.set_shader_parameter("viewport_size", vp_rect)

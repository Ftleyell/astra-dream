class_name CosmicParallaxQuad
extends Node2D

## cosmic_parallax_quad.gd
## Nodo CanvasItem / Mesh centrado permanentemente en la cámara de la vista.
## Alimenta los uniforms de los shaders cósmicos sin mover geometría ni generar coste en CPU.

@export var camera_path: NodePath
@export var viewport_margin: Vector2 = Vector2(512.0, 512.0)

var _deep_rect: ColorRect
var _nebula_rect: ColorRect
var _target_camera: Camera2D
var _origin_tracker: FloatingOriginTracker


func _ready() -> void:
	_setup_layers()
	if not camera_path.is_empty():
		_target_camera = get_node_or_null(camera_path) as Camera2D


func configure(camera_node: Camera2D, tracker: FloatingOriginTracker = null) -> void:
	_target_camera = camera_node
	_origin_tracker = tracker


func _setup_layers() -> void:
	z_index = -100
	z_as_relative = false

	# Capa Profunda (Estrellas + Textura Base)
	_deep_rect = ColorRect.new()
	_deep_rect.name = "DeepSpaceRect"
	_deep_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var deep_mat: ShaderMaterial = ShaderMaterial.new()
	deep_mat.shader = load("res://sandbox/shaders/space_deep_quad.gdshader")
	var deep_tex: Texture2D = load("res://assets/environments/space_parallax/space_parallax_layer0_deep.png")
	if is_instance_valid(deep_tex):
		deep_mat.set_shader_parameter("deep_space_texture", deep_tex)
	_deep_rect.material = deep_mat
	add_child(_deep_rect)

	# Capa Media (Nebulosa)
	_nebula_rect = ColorRect.new()
	_nebula_rect.name = "NebulaSpaceRect"
	_nebula_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var nebula_mat: ShaderMaterial = ShaderMaterial.new()
	nebula_mat.shader = load("res://sandbox/shaders/space_nebula_quad.gdshader")
	var mid_tex: Texture2D = load("res://assets/environments/space_parallax/space_parallax_layer1_mid.png")
	if is_instance_valid(mid_tex):
		nebula_mat.set_shader_parameter("nebula_texture", mid_tex)
	_nebula_rect.material = nebula_mat
	add_child(_nebula_rect)


func _process(_delta: float) -> void:
	if not is_instance_valid(_target_camera):
		var viewport: Viewport = get_viewport()
		if is_instance_valid(viewport):
			_target_camera = viewport.get_camera_2d()

	if not is_instance_valid(_target_camera):
		return

	var cam_pos: Vector2 = _target_camera.global_position
	var zoom: Vector2 = _target_camera.zoom
	var vp_size: Vector2 = get_viewport_rect().size / zoom + viewport_margin * 2.0
	var half_size: Vector2 = vp_size * 0.5

	# Anclar el quad a la cámara
	global_position = cam_pos - half_size

	if is_instance_valid(_deep_rect):
		_deep_rect.size = vp_size
	if is_instance_valid(_nebula_rect):
		_nebula_rect.size = vp_size

	# Calcular coordenadas mundiales lógicas (incorporando floating origin si existe)
	var world_logical_pos: Vector2 = cam_pos
	if _origin_tracker != null:
		world_logical_pos = _origin_tracker.get_origin() + cam_pos

	_update_uniforms(world_logical_pos)


func _update_uniforms(logical_pos: Vector2) -> void:
	if is_instance_valid(_deep_rect) and _deep_rect.material is ShaderMaterial:
		var mat: ShaderMaterial = _deep_rect.material as ShaderMaterial
		mat.set_shader_parameter("camera_world_pos", logical_pos)

	if is_instance_valid(_nebula_rect) and _nebula_rect.material is ShaderMaterial:
		var mat: ShaderMaterial = _nebula_rect.material as ShaderMaterial
		mat.set_shader_parameter("camera_world_pos", logical_pos)


func get_deep_material() -> ShaderMaterial:
	if is_instance_valid(_deep_rect):
		return _deep_rect.material as ShaderMaterial
	return null


func get_nebula_material() -> ShaderMaterial:
	if is_instance_valid(_nebula_rect):
		return _nebula_rect.material as ShaderMaterial
	return null

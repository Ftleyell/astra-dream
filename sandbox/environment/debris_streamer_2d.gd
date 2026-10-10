class_name DebrisStreamer2D
extends Node2D

## Cinturón y campos de escombros espaciales renderizados por GPU mediante MultiMeshInstance2D.
## Proporciona hasta 2000+ fragmentos en 1 único draw call con posicionamiento determinista
## por cuadrante espacial mediante CosmicHasher. Absorbe floating origin y shifts de paralaje.

@export var profile: DebrisLayerProfile
@export var parallax_layer: Parallax2D
@export var camera: Camera2D
@export var run_seed: int = 771239
@export var cell_size: float = 8192.0

var _multimesh_instance: MultiMeshInstance2D = null
var _multimesh: MultiMesh = null
var _macro_grid: CosmicMacroGrid = null
var _current_cell: Vector2i = Vector2i(2147483647, 2147483647)
var _last_instance_count: int = 0

func _ready() -> void:
	if profile == null:
		var default_res: Resource = load("res://sandbox/resources/data/default_debris_layer.tres")
		if default_res is DebrisLayerProfile:
			profile = default_res
	_initialize_macro_grid()
	_initialize_multimesh()
	if camera != null and parallax_layer != null:
		_evaluate_and_stream()

func _initialize_macro_grid() -> void:
	_macro_grid = CosmicMacroGrid.new(cell_size, run_seed)

func _initialize_multimesh() -> void:
	_multimesh_instance = MultiMeshInstance2D.new()
	_multimesh_instance.name = "DebrisMultiMeshInstance"
	
	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_2D
	_multimesh.use_colors = true
	_multimesh.use_custom_data = true
	
	var count: int = profile.instance_count if profile != null else 600
	_multimesh.instance_count = count
	_multimesh.visible_instance_count = count
	_last_instance_count = count

	# Quad unitario centrado de 32x32 para cada fragmento
	var quad_mesh: QuadMesh = QuadMesh.new()
	quad_mesh.size = Vector2(32.0, 32.0)
	_multimesh.mesh = quad_mesh
	
	_multimesh_instance.multimesh = _multimesh

	# Asignar material con shader de debris si existe
	var shader_res: Shader = load("res://sandbox/shaders/debris_cutout.gdshader") as Shader
	if shader_res != null:
		var mat: ShaderMaterial = ShaderMaterial.new()
		mat.shader = shader_res
		if profile != null and profile.mesh_texture != null:
			mat.set_shader_parameter("atlas_texture", profile.mesh_texture)
		_multimesh_instance.material = mat

	add_child(_multimesh_instance)

func _process(_delta: float) -> void:
	_evaluate_and_stream()

## Obtiene la posición lógica en el plano del estrato de paralaje
func get_layer_focal_position() -> Vector2:
	if camera == null or parallax_layer == null:
		return global_position
	var cam_pos: Vector2 = camera.get_screen_center_position()
	if cam_pos == Vector2.ZERO and camera.global_position != Vector2.ZERO:
		cam_pos = camera.global_position
	# Coordenadas relativas en la capa de paralaje
	return (cam_pos * parallax_layer.scroll_scale) - parallax_layer.scroll_offset

func _evaluate_and_stream() -> void:
	if _macro_grid == null or _multimesh == null:
		return

	var focal_pos: Vector2 = get_layer_focal_position()
	var cell: Vector2i = _macro_grid.world_to_grid_coords(focal_pos)

	if cell != _current_cell:
		regenerate_cell(cell)

## Regenera deterministamente el búfer de instancias GPU para la celda dada
func regenerate_cell(cell: Vector2i) -> void:
	_current_cell = cell
	if _multimesh == null:
		return

	var count: int = profile.instance_count if profile != null else 600
	if _multimesh.instance_count != count:
		_multimesh.instance_count = count
		_multimesh.visible_instance_count = count
		_last_instance_count = count

	var cell_center: Vector2 = _macro_grid.grid_to_world_center(cell)
	# Ubicamos el contenedor del MultiMesh en el centro de la celda
	_multimesh_instance.position = cell_center

	var half_size: float = cell_size * 0.5
	var min_scale: float = profile.scale_range.x if profile != null else 0.3
	var max_scale: float = profile.scale_range.y if profile != null else 1.4
	var max_rot: float = profile.max_initial_rotation if profile != null else TAU
	var base_color: Color = profile.alpha_modulation if profile != null else Color(0.85, 0.9, 0.95, 0.6)

	# Llenado determinista del búfer de instancias
	for i: int in range(count):
		# Muestreo pseudoaleatorio determinista derivado de la celda e índice con dispersión espacial
		var cell_hash_seed: int = (cell.x * 73856093) ^ (cell.y * 19349663) ^ (i * 83492791) ^ run_seed
		var rx: float = CosmicHasher.hash_2d_float(cell.x + i, cell.y - i, cell_hash_seed)
		var ry: float = CosmicHasher.hash_2d_float(cell.x - i, cell.y + i, cell_hash_seed + 1984913)
		var r_rot: float = CosmicHasher.hash_2d_float(cell.x + 3 * i, cell.y + 5 * i, cell_hash_seed + 554401)
		var r_scale: float = CosmicHasher.hash_2d_float(cell.x - 7 * i, cell.y + 2 * i, cell_hash_seed + 992811)
		var r_lum: float = CosmicHasher.hash_2d_float(cell.x + 11 * i, cell.y - 13 * i, cell_hash_seed + 12345)

		var pos_local: Vector2 = Vector2(
			(rx - 0.5) * cell_size,
			(ry - 0.5) * cell_size
		)
		var rotation_angle: float = r_rot * max_rot
		var scale_val: float = lerpf(min_scale, max_scale, r_scale)
		var scale_vec: Vector2 = Vector2(scale_val, scale_val)

		var xform: Transform2D = Transform2D(rotation_angle, scale_vec, 0.0, pos_local)
		_multimesh.set_instance_transform_2d(i, xform)

		# Color determinista con variación sutil de brillo y alfa
		var lum_mult: float = lerpf(0.7, 1.3, r_lum)
		var inst_color: Color = Color(
			base_color.r * lum_mult,
			base_color.g * lum_mult,
			base_color.b * lum_mult,
			base_color.a * lerpf(0.6, 1.0, r_lum)
		)
		_multimesh.set_instance_color(i, inst_color)

		# Custom data para el shader atlas (UV offset x, y, UV size z, w)
		# Por defecto atlas subdividido en cuadrícula 2x2: (0 o 0.5)
		var atlas_sub_x: float = 0.5 if (i % 2 == 1) else 0.0
		var atlas_sub_y: float = 0.5 if ((i / 2) % 2 == 1) else 0.0
		_multimesh.set_instance_custom_data(i, Color(atlas_sub_x, atlas_sub_y, 0.5, 0.5))

func get_current_cell() -> Vector2i:
	return _current_cell

func get_multimesh() -> MultiMesh:
	return _multimesh

func get_instance_layer_position(index: int) -> Vector2:
	if _multimesh == null or _multimesh_instance == null:
		return Vector2.ZERO
	return _multimesh_instance.position + _multimesh.get_instance_transform_2d(index).origin

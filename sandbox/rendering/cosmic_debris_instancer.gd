class_name CosmicDebrisInstancer
extends Node2D

## cosmic_debris_instancer.gd
## Instanciador masivo de restos espaciales (debris) en GPU mediante MultiMeshInstance2D.
## Utiliza celdas toroidales virtuales centradas en la posición lógica de la nave,
## dispersión espacial determinista en O(1) con CosmicHasher y zero-allocations en tiempo de ejecución.

const ATLAS_MANIFEST_PATH: String = "res://assets/environments/parallax_space/atlas_textures/debris_manifest.json"
const DEFAULT_ATLAS_PATH: String = "res://assets/environments/parallax_space/debris_atlas_0.png"
const SHADER_PATH: String = "res://sandbox/shaders/debris_cutout.gdshader"

@export var cell_size: float = 1200.0
@export var grid_radius: int = 2 # Grilla de (2*r + 1)^2 celdas: 5x5 = 25 celdas
@export var debris_per_cell: int = 16
@export var parallax_factor: float = 0.5
@export var base_seed: int = 133742
@export var alpha_cutoff: float = 0.05

var _multimesh_instance: MultiMeshInstance2D
var _multimesh: MultiMesh
var _material: ShaderMaterial
var _quad_mesh: ArrayMesh

# Lista de rectángulos normalizados UV para cada sprite del atlas
var _uv_rects: Array[Rect2] = []
var _total_instances: int = 0
var _active_cells: Dictionary = {} # Vector2i -> int (offset en buffer de instancias)

var _current_center_cell: Vector2i = Vector2i(-999999, -999999)
var _camera_target: Node2D
var _origin_tracker: FloatingOriginTracker


func _ready() -> void:
	_load_atlas_metadata()
	_create_quad_mesh()
	_setup_multimesh()


func configure(camera_node: Node2D, tracker: FloatingOriginTracker = null) -> void:
	_camera_target = camera_node
	_origin_tracker = tracker


func _load_atlas_metadata() -> void:
	_uv_rects.clear()
	var texture_ref: Texture2D = load(DEFAULT_ATLAS_PATH)
	var atlas_size: Vector2 = Vector2(2048.0, 2048.0)
	if is_instance_valid(texture_ref):
		atlas_size = texture_ref.get_size()

	var file: FileAccess = FileAccess.open(ATLAS_MANIFEST_PATH, FileAccess.READ)
	if is_instance_valid(file):
		var json_str: String = file.get_as_text()
		var parsed = JSON.parse_string(json_str)
		if parsed is Array:
			for res_path in parsed:
				var path_str: String = str(res_path)
				# Cargamos el recurso AtlasTexture o extraemos su region
				if ResourceLoader.exists(path_str):
					var atlas_sub: AtlasTexture = load(path_str) as AtlasTexture
					if is_instance_valid(atlas_sub):
						var reg: Rect2 = atlas_sub.region
						var norm_rect: Rect2 = Rect2(
							reg.position.x / atlas_size.x,
							reg.position.y / atlas_size.y,
							reg.size.x / atlas_size.x,
							reg.size.y / atlas_size.y
						)
						_uv_rects.append(norm_rect)

	# Fallback si el manifest estuviera vacío o fallara
	if _uv_rects.is_empty():
		_uv_rects.append(Rect2(0.0, 0.0, 1.0, 1.0))


func _create_quad_mesh() -> void:
	_quad_mesh = ArrayMesh.new()
	var verts: PackedVector2Array = PackedVector2Array([
		Vector2(-0.5, -0.5),
		Vector2(0.5, -0.5),
		Vector2(0.5, 0.5),
		Vector2(-0.5, 0.5)
	])
	var uvs: PackedVector2Array = PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(1.0, 0.0),
		Vector2(1.0, 1.0),
		Vector2(0.0, 1.0)
	])
	var indices: PackedInt32Array = PackedInt32Array([0, 1, 2, 0, 2, 3])

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	_quad_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)


func _setup_multimesh() -> void:
	var grid_side: int = grid_radius * 2 + 1
	var cell_count: int = grid_side * grid_side
	_total_instances = cell_count * debris_per_cell

	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_2D
	_multimesh.use_colors = true
	_multimesh.use_custom_data = true
	_multimesh.mesh = _quad_mesh
	_multimesh.instance_count = _total_instances

	_multimesh_instance = MultiMeshInstance2D.new()
	_multimesh_instance.multimesh = _multimesh
	_multimesh_instance.z_index = -50
	_multimesh_instance.z_as_relative = false

	_material = ShaderMaterial.new()
	var shader_res: Shader = load(SHADER_PATH)
	_material.shader = shader_res
	var atlas_tex: Texture2D = load(DEFAULT_ATLAS_PATH)
	if is_instance_valid(atlas_tex):
		_material.set_shader_parameter("atlas_texture", atlas_tex)
	_material.set_shader_parameter("alpha_cutoff", alpha_cutoff)
	_multimesh_instance.material = _material

	add_child(_multimesh_instance)


func _process(_delta: float) -> void:
	var camera_world_pos: Vector2 = Vector2.ZERO
	if is_instance_valid(_origin_tracker):
		camera_world_pos = _origin_tracker.get_logical_position()
	elif is_instance_valid(_camera_target):
		camera_world_pos = _camera_target.global_position
	else:
		var vp: Viewport = get_viewport()
		if is_instance_valid(vp):
			var cam: Camera2D = vp.get_camera_2d()
			if is_instance_valid(cam):
				camera_world_pos = cam.global_position

	update_grid(camera_world_pos)


func update_grid(logical_pos: Vector2) -> void:
	# Ajuste del centro según el factor de parallax
	var effective_pos: Vector2 = logical_pos * parallax_factor
	var center_cell_x: int = int(floor(effective_pos.x / cell_size))
	var center_cell_y: int = int(floor(effective_pos.y / cell_size))
	var target_cell: Vector2i = Vector2i(center_cell_x, center_cell_y)

	if target_cell == _current_center_cell:
		_apply_floating_offset(logical_pos)
		return

	_current_center_cell = target_cell
	_populate_all_cells()
	_apply_floating_offset(logical_pos)


func _populate_all_cells() -> void:
	var slot_index: int = 0
	var rect_count: int = _uv_rects.size()

	for dx in range(-grid_radius, grid_radius + 1):
		for dy in range(-grid_radius, grid_radius + 1):
			var cell_coord: Vector2i = _current_center_cell + Vector2i(dx, dy)
			var cell_origin: Vector2 = Vector2(cell_coord.x * cell_size, cell_coord.y * cell_size)

			for i in range(debris_per_cell):
				var inst_idx: int = slot_index
				slot_index += 1

				# Hash espacial determinista O(1) para este debris
				var sub_seed: int = base_seed + i * 1013
				var rel_x: float = CosmicHasher.hash_2d_float(cell_coord.x, cell_coord.y, sub_seed) * cell_size
				var rel_y: float = CosmicHasher.hash_2d_float(cell_coord.x, cell_coord.y, sub_seed + 1) * cell_size
				var debris_pos: Vector2 = cell_origin + Vector2(rel_x, rel_y)

				# Escala, rotación y variación
				var scale_factor: float = CosmicHasher.hash_2d_range(cell_coord.x, cell_coord.y, 48.0, 140.0, sub_seed + 2)
				var rotation_rad: float = CosmicHasher.hash_2d_range(cell_coord.x, cell_coord.y, -PI, PI, sub_seed + 3)

				# Transform 2D
				var xform: Transform2D = Transform2D(rotation_rad, debris_pos)
				xform = xform.scaled_local(Vector2(scale_factor, scale_factor))
				_multimesh.set_instance_transform_2d(inst_idx, xform)

				# Selección determinista de sprite del atlas
				var sprite_idx: int = CosmicHasher.hash_2d(cell_coord.x, cell_coord.y, sub_seed + 4) % rect_count
				var uv_rect: Rect2 = _uv_rects[sprite_idx]

				# Guardar UV offset (xy) y scale (zw) en custom data
				var custom_data: Color = Color(
					uv_rect.position.x,
					uv_rect.position.y,
					uv_rect.size.x,
					uv_rect.size.y
				)
				_multimesh.set_instance_custom_data(inst_idx, custom_data)

				# Tinte sutil con variación de brillo
				var brightness: float = CosmicHasher.hash_2d_range(cell_coord.x, cell_coord.y, 0.7, 1.0, sub_seed + 5)
				_multimesh.set_instance_color(inst_idx, Color(brightness, brightness, brightness, 1.0))


func _apply_floating_offset(logical_pos: Vector2) -> void:
	# El nodo se reposiciona para que los fragmentos respondan al parallax relativo a la cámara
	# debris_world_render = debris_pos - logical_pos * (1.0 - parallax_factor)
	var parallax_shift: Vector2 = logical_pos * (1.0 - parallax_factor)
	if is_instance_valid(_origin_tracker):
		# Compensa el origen local respecto a la cámara
		_multimesh_instance.global_position = -parallax_shift + _origin_tracker.get_actor_position()
	elif is_instance_valid(_camera_target):
		_multimesh_instance.global_position = -parallax_shift + _camera_target.global_position
	else:
		_multimesh_instance.global_position = -parallax_shift


func get_instance_count() -> int:
	return _total_instances


func get_current_center_cell() -> Vector2i:
	return _current_center_cell

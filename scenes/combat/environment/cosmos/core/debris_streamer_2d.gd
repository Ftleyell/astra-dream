class_name CosmosDebrisStreamer2D
extends Node2D

## Cinturón y campos de escombros espaciales renderizados por GPU mediante MultiMeshInstance2D.
## Proporciona hasta 2000+ fragmentos en 1 o 2 draw calls con posicionamiento determinista
## por cuadrante espacial mediante CosmosHasher. Soporta atlas dual (rocas + chatarra),
## estratificación de tamaños (micro 70%, medio 25%, macro 5%) y mapeo 1:1 de AtlasTextures.

const METADATA_PATH: String = "res://assets/environments/parallax_space/atlas_textures/debris_metadata.json"
const ATLAS_MANIFEST_PATH: String = "res://assets/environments/parallax_space/atlas_textures/debris_manifest.json"
const ATLAS_DIR_PATH: String = "res://assets/environments/parallax_space/atlas_textures/"
const ATLAS_SIZE: Vector2 = Vector2(2048.0, 2048.0)
const SHADER_PATH: String = "res://scenes/combat/environment/cosmos/shaders/debris_cutout.gdshader"

# Caché estática compartida en memoria para evitar I/O redundante entre instancias (latencia <1ms)
static var _cached_metadata_ready: bool = false
static var _cached_rock_micro: Array[Dictionary] = []
static var _cached_rock_medium: Array[Dictionary] = []
static var _cached_rock_macro: Array[Dictionary] = []
static var _cached_scrap_micro: Array[Dictionary] = []
static var _cached_scrap_medium: Array[Dictionary] = []
static var _cached_scrap_macro: Array[Dictionary] = []

class DebrisCellChunk:
	var root: Node2D = null
	var rock_multimesh_instance: MultiMeshInstance2D = null
	var rock_multimesh: MultiMesh = null
	var scrap_multimesh_instance: MultiMeshInstance2D = null
	var scrap_multimesh: MultiMesh = null
	var cell: Vector2i = Vector2i(2147483647, 2147483647)
	var is_active: bool = false
	var rock_items: Array[CosmosDebrisLayoutGenerator.DebrisInstanceData] = []
	var scrap_items: Array[CosmosDebrisLayoutGenerator.DebrisInstanceData] = []

@export var profile: CosmosDebrisLayerProfile
@export var parallax_layer: Parallax2D
@export var camera: Camera2D
@export var run_seed: int = 771239
@export var cell_size: float = 12000.0
@export var celestial_profile: CosmosCelestialSystemProfile
@export var solar_streamer: CosmosSolarSystemStreamer = null
@export var pool_size: int = 9

var _global_time: float = 0.0
var _multimesh_instance: MultiMeshInstance2D = null
var _multimesh: MultiMesh = null
var _scrap_multimesh_instance: MultiMeshInstance2D = null
var _scrap_multimesh: MultiMesh = null

var _pool: Array[DebrisCellChunk] = []
var _active_chunks: Dictionary = {} # Vector2i -> DebrisCellChunk

var _macro_grid: CosmosMacroGrid = null
var _current_cell: Vector2i = Vector2i(2147483647, 2147483647)
var _last_instance_count: int = 0
var _last_scrap_instance_count: int = 0

# Fragmentos clasificados por tamaño y material
var _rock_micro: Array[Dictionary] = []
var _rock_medium: Array[Dictionary] = []
var _rock_macro: Array[Dictionary] = []

var _scrap_micro: Array[Dictionary] = []
var _scrap_medium: Array[Dictionary] = []
var _scrap_macro: Array[Dictionary] = []

func _ready() -> void:
	process_priority = 0
	if profile == null:
		var default_res: Resource = load("res://scenes/combat/environment/cosmos/resources/data/default_debris_layer.tres")
		if default_res is CosmosDebrisLayerProfile:
			profile = default_res
	if profile != null and profile.field_bounding_box.x > 0.0:
		cell_size = profile.field_bounding_box.x
	_initialize_macro_grid()
	_load_atlas_metadata()
	_initialize_multimesh()
	if camera != null and parallax_layer != null:
		_evaluate_and_stream()

func _initialize_macro_grid() -> void:
	_macro_grid = CosmosMacroGrid.new(cell_size, run_seed)

## Carga los metadatos de los recursos AtlasTexture y los clasifica en estratos de tamaño
func _load_atlas_metadata() -> void:
	_rock_micro.clear()
	_rock_medium.clear()
	_rock_macro.clear()
	_scrap_micro.clear()
	_scrap_medium.clear()
	_scrap_macro.clear()

	# Usar caché estática si ya fue computada en esta sesión
	if _cached_metadata_ready:
		_rock_micro.append_array(_cached_rock_micro)
		_rock_medium.append_array(_cached_rock_medium)
		_rock_macro.append_array(_cached_rock_macro)
		_scrap_micro.append_array(_cached_scrap_micro)
		_scrap_medium.append_array(_cached_scrap_medium)
		_scrap_macro.append_array(_cached_scrap_macro)
		return

	var rock_micro_max: float = profile.rock_micro_max_area if profile != null else 7000.0
	var rock_med_max: float = profile.rock_medium_max_area if profile != null else 25000.0
	var scrap_micro_max: float = profile.scrap_micro_max_area if profile != null else 9000.0
	var scrap_med_max: float = profile.scrap_medium_max_area if profile != null else 28000.0

	# 1. Ruta rápida: leer debris_metadata.json pre-extraído en un solo archivo (0.2 ms)
	if FileAccess.file_exists(METADATA_PATH):
		var meta_file: FileAccess = FileAccess.open(METADATA_PATH, FileAccess.READ)
		if meta_file != null:
			var json_content: String = meta_file.get_as_text()
			var parsed_meta: Variant = JSON.parse_string(json_content)
			if parsed_meta is Array:
				for entry_var: Variant in parsed_meta:
					if entry_var is Dictionary:
						var entry_dict: Dictionary = entry_var
						var rect_arr: Array = entry_dict.get("rect", [])
						if rect_arr.size() >= 4:
							var rx: float = float(rect_arr[0])
							var ry: float = float(rect_arr[1])
							var rw: float = float(rect_arr[2])
							var rh: float = float(rect_arr[3])
							var area: float = rw * rh
							var item: Dictionary = {
								"uv_rect": Rect2(rx / ATLAS_SIZE.x, ry / ATLAS_SIZE.y, rw / ATLAS_SIZE.x, rh / ATLAS_SIZE.y),
								"pixel_size": Vector2(rw, rh),
								"area": area
							}
							var prefix: String = str(entry_dict.get("prefix", ""))
							if prefix == "debris_0":
								if area < rock_micro_max:
									_rock_micro.append(item)
								elif area < rock_med_max:
									_rock_medium.append(item)
								else:
									_rock_macro.append(item)
							else:
								if area < scrap_micro_max:
									_scrap_micro.append(item)
								elif area < scrap_med_max:
									_scrap_medium.append(item)
								else:
									_scrap_macro.append(item)

	# Si se cargó exitosamente desde metadata.json, guardar en caché estática y finalizar
	if not _rock_micro.is_empty() or not _rock_medium.is_empty() or not _rock_macro.is_empty():
		_finalize_and_cache_metadata()
		return

	var loaded_paths: Array[String] = []

	# 1. Intentar cargar desde el manifiesto JSON
	if FileAccess.file_exists(ATLAS_MANIFEST_PATH):
		var file: FileAccess = FileAccess.open(ATLAS_MANIFEST_PATH, FileAccess.READ)
		if file != null:
			var json_str: String = file.get_as_text()
			var parsed: Variant = JSON.parse_string(json_str)
			if parsed is Array:
				for p: Variant in parsed:
					loaded_paths.append(str(p))

	# 2. Fallback: escanear el directorio si el manifiesto no estaba disponible
	if loaded_paths.is_empty():
		var dir: DirAccess = DirAccess.open(ATLAS_DIR_PATH)
		if dir != null:
			dir.list_dir_begin()
			var file_name: String = dir.get_next()
			while file_name != "":
				if not dir.current_is_dir() and file_name.ends_with(".tres"):
					loaded_paths.append(ATLAS_DIR_PATH + file_name)
				file_name = dir.get_next()

	for res_path: String in loaded_paths:
		if ResourceLoader.exists(res_path):
			var atlas_sub: AtlasTexture = load(res_path) as AtlasTexture
			if atlas_sub != null:
				var reg: Rect2 = atlas_sub.region
				var area: float = reg.size.x * reg.size.y
				var item: Dictionary = {
					"uv_rect": Rect2(
						reg.position.x / ATLAS_SIZE.x,
						reg.position.y / ATLAS_SIZE.y,
						reg.size.x / ATLAS_SIZE.x,
						reg.size.y / ATLAS_SIZE.y
					),
					"pixel_size": reg.size,
					"area": area
				}

				if res_path.contains("debris_0"):
					if area < rock_micro_max:
						_rock_micro.append(item)
					elif area < rock_med_max:
						_rock_medium.append(item)
					else:
						_rock_macro.append(item)
				else:
					if area < scrap_micro_max:
						_scrap_micro.append(item)
					elif area < scrap_med_max:
						_scrap_medium.append(item)
					else:
						_scrap_macro.append(item)

	_finalize_and_cache_metadata()

func _finalize_and_cache_metadata() -> void:
	var fallback_item: Dictionary = {
		"uv_rect": Rect2(0.0, 0.0, 1.0, 1.0),
		"pixel_size": Vector2(32.0, 32.0),
		"area": 1024.0
	}
	if _rock_micro.is_empty():
		_rock_micro.append(fallback_item)
	if _rock_medium.is_empty():
		_rock_medium.append(fallback_item)
	if _rock_macro.is_empty():
		_rock_macro.append(fallback_item)
	if _scrap_micro.is_empty():
		_scrap_micro.append(fallback_item)
	if _scrap_medium.is_empty():
		_scrap_medium.append(fallback_item)
	if _scrap_macro.is_empty():
		_scrap_macro.append(fallback_item)

	_cached_rock_micro.clear()
	_cached_rock_micro.append_array(_rock_micro)
	_cached_rock_medium.clear()
	_cached_rock_medium.append_array(_rock_medium)
	_cached_rock_macro.clear()
	_cached_rock_macro.append_array(_rock_macro)

	_cached_scrap_micro.clear()
	_cached_scrap_micro.append_array(_scrap_micro)
	_cached_scrap_medium.clear()
	_cached_scrap_medium.append_array(_scrap_medium)
	_cached_scrap_macro.clear()
	_cached_scrap_macro.append_array(_scrap_macro)

	_cached_metadata_ready = true

func _initialize_multimesh() -> void:
	# Quad unitario normalizado de 1.0 x 1.0 para respetar píxeles exactos en Transform2D
	var quad_mesh: QuadMesh = QuadMesh.new()
	quad_mesh.size = Vector2(1.0, 1.0)

	var shader_res: Shader = load(SHADER_PATH) as Shader
	var rock_tex: Texture2D = profile.get_effective_rock_texture() if profile != null else null
	var scrap_tex: Texture2D = profile.get_effective_scrap_texture() if profile != null else null
	var rock_count: int = profile.instance_count if profile != null else 600
	var scrap_count: int = profile.scrap_instance_count if profile != null else 0

	_last_instance_count = rock_count
	_last_scrap_instance_count = scrap_count
	_pool.clear()
	_active_chunks.clear()

	for i: int in range(maxi(pool_size, 1)):
		var chunk: DebrisCellChunk = DebrisCellChunk.new()
		chunk.root = Node2D.new()
		chunk.root.name = "DebrisCellChunk_" + str(i)
		chunk.root.visible = false
		add_child(chunk.root)

		# 1. MultiMesh Principal (Rocas)
		chunk.rock_multimesh_instance = MultiMeshInstance2D.new()
		chunk.rock_multimesh_instance.name = "RockMultiMesh"
		chunk.rock_multimesh = MultiMesh.new()
		chunk.rock_multimesh.transform_format = MultiMesh.TRANSFORM_2D
		chunk.rock_multimesh.use_colors = true
		chunk.rock_multimesh.use_custom_data = true
		chunk.rock_multimesh.mesh = quad_mesh
		chunk.rock_multimesh.instance_count = rock_count
		chunk.rock_multimesh.visible_instance_count = rock_count
		chunk.rock_multimesh_instance.multimesh = chunk.rock_multimesh

		if shader_res != null:
			var mat_rock: ShaderMaterial = ShaderMaterial.new()
			mat_rock.shader = shader_res
			if rock_tex != null:
				mat_rock.set_shader_parameter("atlas_texture", rock_tex)
			chunk.rock_multimesh_instance.material = mat_rock

		chunk.root.add_child(chunk.rock_multimesh_instance)

		# 2. MultiMesh Secundario (Chatarra)
		if scrap_tex != null and scrap_count > 0:
			chunk.scrap_multimesh_instance = MultiMeshInstance2D.new()
			chunk.scrap_multimesh_instance.name = "ScrapMultiMesh"
			chunk.scrap_multimesh = MultiMesh.new()
			chunk.scrap_multimesh.transform_format = MultiMesh.TRANSFORM_2D
			chunk.scrap_multimesh.use_colors = true
			chunk.scrap_multimesh.use_custom_data = true
			chunk.scrap_multimesh.mesh = quad_mesh
			chunk.scrap_multimesh.instance_count = scrap_count
			chunk.scrap_multimesh.visible_instance_count = scrap_count
			chunk.scrap_multimesh_instance.multimesh = chunk.scrap_multimesh

			if shader_res != null:
				var mat_scrap: ShaderMaterial = ShaderMaterial.new()
				mat_scrap.shader = shader_res
				mat_scrap.set_shader_parameter("atlas_texture", scrap_tex)
				chunk.scrap_multimesh_instance.material = mat_scrap

			chunk.root.add_child(chunk.scrap_multimesh_instance)

		_pool.append(chunk)

	if not _pool.is_empty():
		_multimesh_instance = _pool[0].rock_multimesh_instance
		_multimesh = _pool[0].rock_multimesh
		_scrap_multimesh_instance = _pool[0].scrap_multimesh_instance
		_scrap_multimesh = _pool[0].scrap_multimesh

func _process(delta: float) -> void:
	_global_time += delta
	_update_shader_time()
	_evaluate_and_stream()

func _update_shader_time() -> void:
	for chunk: DebrisCellChunk in _pool:
		if chunk.rock_multimesh_instance != null and chunk.rock_multimesh_instance.material is ShaderMaterial:
			(chunk.rock_multimesh_instance.material as ShaderMaterial).set_shader_parameter("global_time", _global_time)
		if chunk.scrap_multimesh_instance != null and chunk.scrap_multimesh_instance.material is ShaderMaterial:
			(chunk.scrap_multimesh_instance.material as ShaderMaterial).set_shader_parameter("global_time", _global_time)

## Obtiene la posición lógica en el plano del estrato de paralaje
func get_layer_focal_position() -> Vector2:
	if camera == null or parallax_layer == null:
		return global_position
	var cam_pos: Vector2 = camera.get_screen_center_position()
	if cam_pos == Vector2.ZERO and camera.global_position != Vector2.ZERO:
		cam_pos = camera.global_position
	return (cam_pos * parallax_layer.scroll_scale) - parallax_layer.scroll_offset

## Streaming analítico continuo: mantiene activo un vecindario 3x3 alrededor de la cámara eliminando popping
func _evaluate_and_stream() -> void:
	if _macro_grid == null or _pool.is_empty():
		return

	var focal_pos: Vector2 = get_layer_focal_position()
	var center_cell: Vector2i = _macro_grid.world_to_grid_coords(focal_pos)
	_current_cell = center_cell

	var required_cells: Array[Vector2i] = []
	for ox: int in range(-1, 2):
		for oy: int in range(-1, 2):
			required_cells.append(center_cell + Vector2i(ox, oy))

	# 1. Desactivar y reciclar celdas que ya salieron del vecindario
	var cells_to_release: Array[Vector2i] = []
	for active_cell: Vector2i in _active_chunks.keys():
		if not required_cells.has(active_cell):
			cells_to_release.append(active_cell)

	for rel_cell: Vector2i in cells_to_release:
		var chunk: DebrisCellChunk = _active_chunks[rel_cell]
		chunk.root.visible = false
		chunk.is_active = false
		_active_chunks.erase(rel_cell)

	# 2. Asignar slots del pool y poblar las nuevas celdas requeridas
	for req_cell: Vector2i in required_cells:
		if _active_chunks.has(req_cell):
			continue
		var free_chunk: DebrisCellChunk = _get_available_chunk()
		if free_chunk != null:
			_populate_chunk(free_chunk, req_cell)
			_active_chunks[req_cell] = free_chunk

func _get_available_chunk() -> DebrisCellChunk:
	for chunk: DebrisCellChunk in _pool:
		if not chunk.is_active:
			return chunk

	# Fallback si todos están activos: reciclar el más distante de la celda focal
	var farthest_chunk: DebrisCellChunk = null
	var max_dist_sq: int = -1
	for active_cell: Vector2i in _active_chunks.keys():
		var d: Vector2i = active_cell - _current_cell
		var dist_sq: int = d.x * d.x + d.y * d.y
		if dist_sq > max_dist_sq:
			max_dist_sq = dist_sq
			farthest_chunk = _active_chunks[active_cell]

	if farthest_chunk != null:
		_active_chunks.erase(farthest_chunk.cell)
		farthest_chunk.is_active = false
		return farthest_chunk

	return _pool[0] if not _pool.is_empty() else null

## Regenera deterministamente el búfer de instancias GPU para la celda dada
func regenerate_cell(cell: Vector2i) -> void:
	_current_cell = cell
	if _macro_grid == null:
		_initialize_macro_grid()
	if _pool.is_empty():
		_initialize_multimesh()

	if _pool.is_empty():
		return

	if camera != null and parallax_layer != null:
		_evaluate_and_stream()
	else:
		# Modo aislado / test unitario sin escena completa
		var primary_chunk: DebrisCellChunk = _pool[0]
		_populate_chunk(primary_chunk, cell)
		_active_chunks.clear()
		_active_chunks[cell] = primary_chunk

func _populate_chunk(chunk: DebrisCellChunk, cell: Vector2i) -> void:
	chunk.cell = cell
	chunk.is_active = true
	var cell_center: Vector2 = _macro_grid.grid_to_world_center(cell)
	chunk.root.position = cell_center
	chunk.root.visible = true

	var rock_count: int = profile.instance_count if profile != null else 600
	if chunk.rock_multimesh.instance_count != rock_count:
		chunk.rock_multimesh.instance_count = rock_count
		chunk.rock_multimesh.visible_instance_count = rock_count

	chunk.rock_items = _fill_multimesh_buffer(chunk.rock_multimesh, rock_count, cell, false, cell_center)

	if chunk.scrap_multimesh != null:
		var scrap_count: int = profile.scrap_instance_count if profile != null else 0
		if chunk.scrap_multimesh.instance_count != scrap_count:
			chunk.scrap_multimesh.instance_count = scrap_count
			chunk.scrap_multimesh.visible_instance_count = scrap_count

		if scrap_count > 0:
			chunk.scrap_items = _fill_multimesh_buffer(chunk.scrap_multimesh, scrap_count, cell, true, cell_center)

## Población determinista de instancias MultiMesh delegada en CosmosDebrisLayoutGenerator
func _fill_multimesh_buffer(
	mesh_buffer: MultiMesh,
	count: int,
	cell: Vector2i,
	is_scrap: bool,
	cell_center: Vector2
) -> Array[CosmosDebrisLayoutGenerator.DebrisInstanceData]:
	# Consultar el estado estelar (SSOT con solar_streamer si está disponible)
	var cell_has_star: bool = false
	var star_offset: Vector2 = Vector2.ZERO
	var kuiper_r_inner: float = profile.kuiper_default_radius if profile != null else 4600.0
	var kuiper_pad: float = profile.kuiper_inner_padding if profile != null else 300.0

	if solar_streamer != null:
		var sys_rnd: float = _macro_grid.get_cell_pseudorandom_float(cell, 9091)
		var spawn_chance: float = celestial_profile.spawn_chance if celestial_profile != null else 0.75
		if sys_rnd <= spawn_chance:
			cell_has_star = true
			var sys_world_pos: Vector2 = solar_streamer.get_system_position_for_cell(cell)
			star_offset = sys_world_pos - cell_center
			var cell_seed: int = run_seed ^ CosmosHasher.hash_2d(cell.x, cell.y, 777)
			var arch: CosmosStarArchetype = celestial_profile.get_archetype_for_seed(cell_seed) if celestial_profile != null else null
			var base_max_orbit: float = arch.orbit_radius_max if arch != null else (celestial_profile.orbit_radius_max if celestial_profile != null else 4400.0)
			kuiper_r_inner = base_max_orbit + kuiper_pad
	elif celestial_profile != null:
		var sys_rnd: float = _macro_grid.get_cell_pseudorandom_float(cell, 9091)
		if sys_rnd <= celestial_profile.spawn_chance:
			cell_has_star = true
			var cell_seed: int = run_seed ^ CosmosHasher.hash_2d(cell.x, cell.y, 777)
			var arch: CosmosStarArchetype = celestial_profile.get_archetype_for_seed(cell_seed)
			var base_max_orbit: float = arch.orbit_radius_max if arch != null else celestial_profile.orbit_radius_max
			kuiper_r_inner = base_max_orbit + kuiper_pad

			var sys_reach: float = base_max_orbit + 400.0
			var padding: float = celestial_profile.cell_boundary_padding
			var safe_half: float = (cell_size * 0.5) - padding
			var max_jitter_dist: float = maxf(safe_half - sys_reach, 0.0)
			var offset_norm: Vector2 = _macro_grid.get_cell_normalized_offset(cell, 4321)
			star_offset = (offset_norm - Vector2(0.5, 0.5)) * 2.0 * max_jitter_dist
	else:
		cell_has_star = true

	var micro_list: Array[Dictionary] = _scrap_micro if is_scrap else _rock_micro
	var medium_list: Array[Dictionary] = _scrap_medium if is_scrap else _rock_medium
	var macro_list: Array[Dictionary] = _scrap_macro if is_scrap else _rock_macro

	var items: Array[CosmosDebrisLayoutGenerator.DebrisInstanceData] = CosmosDebrisLayoutGenerator.generate_cell_layout(
		cell,
		cell_size,
		count,
		run_seed,
		is_scrap,
		profile,
		_macro_grid,
		micro_list,
		medium_list,
		macro_list,
		cell_has_star,
		star_offset,
		kuiper_r_inner
	)

	for i: int in range(items.size()):
		var data: CosmosDebrisLayoutGenerator.DebrisInstanceData = items[i]
		var col_x: Vector2 = Vector2(cos(data.rotation), sin(data.rotation)) * data.scale.x
		var col_y: Vector2 = Vector2(-sin(data.rotation), cos(data.rotation)) * data.scale.y
		var xform: Transform2D = Transform2D(col_x, col_y, data.position)
		mesh_buffer.set_instance_transform_2d(i, xform)
		mesh_buffer.set_instance_color(i, data.color)
		mesh_buffer.set_instance_custom_data(i, Color(
			data.uv_rect.position.x,
			data.uv_rect.position.y,
			data.uv_rect.size.x,
			data.uv_rect.size.y
		))

	return items

func get_current_cell() -> Vector2i:
	return _current_cell

func get_multimesh() -> MultiMesh:
	return _multimesh

func get_scrap_multimesh() -> MultiMesh:
	return _scrap_multimesh

func get_total_instance_count() -> int:
	var total: int = _multimesh.instance_count if _multimesh != null else 0
	if _scrap_multimesh != null:
		total += _scrap_multimesh.instance_count
	return total

func get_instance_local_position(index: int) -> Vector2:
	var chunk: DebrisCellChunk = _active_chunks.get(_current_cell, null)
	if chunk == null and not _pool.is_empty():
		chunk = _pool[0]
	if chunk != null and index >= 0 and index < chunk.rock_items.size():
		return chunk.rock_items[index].position
	return Vector2.ZERO

func get_instance_layer_position(index: int) -> Vector2:
	var chunk: DebrisCellChunk = _active_chunks.get(_current_cell, null)
	if chunk == null and not _pool.is_empty():
		chunk = _pool[0]
	if chunk == null:
		return Vector2.ZERO
	return chunk.root.position + get_instance_local_position(index)

## Determina si una celda espacial contiene un sistema estelar según el perfil celestial activo
func has_star_in_cell(cell: Vector2i) -> bool:
	if celestial_profile == null:
		return true
	if _macro_grid == null:
		_initialize_macro_grid()
	var sys_rnd: float = _macro_grid.get_cell_pseudorandom_float(cell, 9091)
	return sys_rnd <= celestial_profile.spawn_chance

## Devuelve el desplazamiento determinista de la estrella en la celda indicada respecto al centro (0, 0)
func get_star_offset_for_cell(cell: Vector2i) -> Vector2:
	if not has_star_in_cell(cell) or celestial_profile == null:
		return Vector2.ZERO
	if _macro_grid == null:
		_initialize_macro_grid()
	var cell_seed: int = run_seed ^ CosmosHasher.hash_2d(cell.x, cell.y, 777)
	var arch: CosmosStarArchetype = celestial_profile.get_archetype_for_seed(cell_seed)
	var base_max_orbit: float = arch.orbit_radius_max if arch != null else celestial_profile.orbit_radius_max
	var sys_reach: float = base_max_orbit + 400.0
	var padding: float = celestial_profile.cell_boundary_padding
	var safe_half: float = (cell_size * 0.5) - padding
	var max_jitter_dist: float = maxf(safe_half - sys_reach, 0.0)
	var offset_norm: Vector2 = _macro_grid.get_cell_normalized_offset(cell, 4321)
	return (offset_norm - Vector2(0.5, 0.5)) * 2.0 * max_jitter_dist

## Devuelve la cantidad de instancias asignadas al cinturón de Kuiper para la celda indicada
func get_kuiper_count_for_cell(cell: Vector2i) -> int:
	if not has_star_in_cell(cell):
		return 0
	var count: int = profile.instance_count if profile != null else 500
	var kuiper_ratio: float = profile.kuiper_belt_ratio if profile != null else 0.50
	return int(round(float(count) * kuiper_ratio))


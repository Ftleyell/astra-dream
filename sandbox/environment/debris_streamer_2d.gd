class_name DebrisStreamer2D
extends Node2D

## Cinturón y campos de escombros espaciales renderizados por GPU mediante MultiMeshInstance2D.
## Proporciona hasta 2000+ fragmentos en 1 o 2 draw calls con posicionamiento determinista
## por cuadrante espacial mediante CosmicHasher. Soporta atlas dual (rocas + chatarra),
## estratificación de tamaños (micro 70%, medio 25%, macro 5%) y mapeo 1:1 de AtlasTextures.

const METADATA_PATH: String = "res://assets/environments/parallax_space/atlas_textures/debris_metadata.json"
const ATLAS_MANIFEST_PATH: String = "res://assets/environments/parallax_space/atlas_textures/debris_manifest.json"
const ATLAS_DIR_PATH: String = "res://assets/environments/parallax_space/atlas_textures/"
const ATLAS_SIZE: Vector2 = Vector2(2048.0, 2048.0)
const SHADER_PATH: String = "res://sandbox/shaders/debris_cutout.gdshader"

# Caché estática compartida en memoria para evitar I/O redundante entre instancias (latencia <1ms)
static var _cached_metadata_ready: bool = false
static var _cached_rock_micro: Array[Dictionary] = []
static var _cached_rock_medium: Array[Dictionary] = []
static var _cached_rock_macro: Array[Dictionary] = []
static var _cached_scrap_micro: Array[Dictionary] = []
static var _cached_scrap_medium: Array[Dictionary] = []
static var _cached_scrap_macro: Array[Dictionary] = []

@export var profile: DebrisLayerProfile
@export var parallax_layer: Parallax2D
@export var camera: Camera2D
@export var run_seed: int = 771239
@export var cell_size: float = 12000.0
@export var celestial_profile: CelestialSystemProfile
@export var solar_streamer: SolarSystemStreamer = null

var _global_time: float = 0.0
var _multimesh_instance: MultiMeshInstance2D = null
var _multimesh: MultiMesh = null
var _scrap_multimesh_instance: MultiMeshInstance2D = null
var _scrap_multimesh: MultiMesh = null

var _macro_grid: CosmicMacroGrid = null
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
		var default_res: Resource = load("res://sandbox/resources/data/default_debris_layer.tres")
		if default_res is DebrisLayerProfile:
			profile = default_res
	if profile != null and profile.field_bounding_box.x > 0.0:
		cell_size = profile.field_bounding_box.x
	_initialize_macro_grid()
	_load_atlas_metadata()
	_initialize_multimesh()
	if camera != null and parallax_layer != null:
		_evaluate_and_stream()

func _initialize_macro_grid() -> void:
	_macro_grid = CosmicMacroGrid.new(cell_size, run_seed)

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

	# 1. MultiMesh Principal (Rocas / Asteroides)
	_multimesh_instance = MultiMeshInstance2D.new()
	_multimesh_instance.name = "RockDebrisMultiMeshInstance"
	
	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_2D
	_multimesh.use_colors = true
	_multimesh.use_custom_data = true
	_multimesh.mesh = quad_mesh
	
	var rock_count: int = profile.instance_count if profile != null else 600
	_multimesh.instance_count = rock_count
	_multimesh.visible_instance_count = rock_count
	_last_instance_count = rock_count
	_multimesh_instance.multimesh = _multimesh

	if shader_res != null:
		var mat_rock: ShaderMaterial = ShaderMaterial.new()
		mat_rock.shader = shader_res
		var rock_tex: Texture2D = profile.get_effective_rock_texture() if profile != null else null
		if rock_tex != null:
			mat_rock.set_shader_parameter("atlas_texture", rock_tex)
		_multimesh_instance.material = mat_rock

	add_child(_multimesh_instance)

	# 2. MultiMesh Secundario (Chatarra / Restos Mecánicos) si está configurado
	var scrap_tex: Texture2D = profile.get_effective_scrap_texture() if profile != null else null
	var scrap_count: int = profile.scrap_instance_count if profile != null else 0

	if scrap_tex != null and scrap_count > 0:
		_scrap_multimesh_instance = MultiMeshInstance2D.new()
		_scrap_multimesh_instance.name = "ScrapDebrisMultiMeshInstance"
		
		_scrap_multimesh = MultiMesh.new()
		_scrap_multimesh.transform_format = MultiMesh.TRANSFORM_2D
		_scrap_multimesh.use_colors = true
		_scrap_multimesh.use_custom_data = true
		_scrap_multimesh.mesh = quad_mesh
		
		_scrap_multimesh.instance_count = scrap_count
		_scrap_multimesh.visible_instance_count = scrap_count
		_last_scrap_instance_count = scrap_count
		_scrap_multimesh_instance.multimesh = _scrap_multimesh

		if shader_res != null:
			var mat_scrap: ShaderMaterial = ShaderMaterial.new()
			mat_scrap.shader = shader_res
			mat_scrap.set_shader_parameter("atlas_texture", scrap_tex)
			_scrap_multimesh_instance.material = mat_scrap

		add_child(_scrap_multimesh_instance)

func _process(delta: float) -> void:
	_global_time += delta
	_update_shader_time()
	_evaluate_and_stream()

func _update_shader_time() -> void:
	if _multimesh_instance != null and _multimesh_instance.material is ShaderMaterial:
		(_multimesh_instance.material as ShaderMaterial).set_shader_parameter("global_time", _global_time)
	if _scrap_multimesh_instance != null and _scrap_multimesh_instance.material is ShaderMaterial:
		(_scrap_multimesh_instance.material as ShaderMaterial).set_shader_parameter("global_time", _global_time)

## Obtiene la posición lógica en el plano del estrato de paralaje
func get_layer_focal_position() -> Vector2:
	if camera == null or parallax_layer == null:
		return global_position
	var cam_pos: Vector2 = camera.get_screen_center_position()
	if cam_pos == Vector2.ZERO and camera.global_position != Vector2.ZERO:
		cam_pos = camera.global_position
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
	if _macro_grid == null:
		_initialize_macro_grid()
	if _multimesh == null:
		return

	var rock_count: int = profile.instance_count if profile != null else 600
	if _multimesh.instance_count != rock_count:
		_multimesh.instance_count = rock_count
		_multimesh.visible_instance_count = rock_count
		_last_instance_count = rock_count

	_populate_buffer(_multimesh, _multimesh_instance, rock_count, cell, false)

	if _scrap_multimesh != null and _scrap_multimesh_instance != null:
		var scrap_count: int = profile.scrap_instance_count if profile != null else 0
		if _scrap_multimesh.instance_count != scrap_count:
			_scrap_multimesh.instance_count = scrap_count
			_scrap_multimesh.visible_instance_count = scrap_count
			_last_scrap_instance_count = scrap_count

		if scrap_count > 0:
			_populate_buffer(_scrap_multimesh, _scrap_multimesh_instance, scrap_count, cell, true)

## Población determinista de instancias MultiMesh delegada en DebrisLayoutGenerator
func _populate_buffer(
	mesh_buffer: MultiMesh,
	mesh_inst: MultiMeshInstance2D,
	count: int,
	cell: Vector2i,
	is_scrap: bool
) -> void:
	var cell_center: Vector2 = _macro_grid.grid_to_world_center(cell)
	mesh_inst.position = cell_center

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
			var cell_seed: int = run_seed ^ CosmicHasher.hash_2d(cell.x, cell.y, 777)
			var arch: StarArchetype = celestial_profile.get_archetype_for_seed(cell_seed) if celestial_profile != null else null
			var base_max_orbit: float = arch.orbit_radius_max if arch != null else (celestial_profile.orbit_radius_max if celestial_profile != null else 4400.0)
			kuiper_r_inner = base_max_orbit + kuiper_pad
	elif celestial_profile != null:
		var sys_rnd: float = _macro_grid.get_cell_pseudorandom_float(cell, 9091)
		if sys_rnd <= celestial_profile.spawn_chance:
			cell_has_star = true
			var cell_seed: int = run_seed ^ CosmicHasher.hash_2d(cell.x, cell.y, 777)
			var arch: StarArchetype = celestial_profile.get_archetype_for_seed(cell_seed)
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

	var items: Array[DebrisLayoutGenerator.DebrisInstanceData] = DebrisLayoutGenerator.generate_cell_layout(
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
		var data: DebrisLayoutGenerator.DebrisInstanceData = items[i]
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

func get_instance_layer_position(index: int) -> Vector2:
	if _multimesh == null or _multimesh_instance == null:
		return Vector2.ZERO
	return _multimesh_instance.position + _multimesh.get_instance_transform_2d(index).origin

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
	var cell_seed: int = run_seed ^ CosmicHasher.hash_2d(cell.x, cell.y, 777)
	var arch: StarArchetype = celestial_profile.get_archetype_for_seed(cell_seed)
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


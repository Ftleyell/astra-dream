class_name SolarSystemStreamer
extends Node2D

## Orquestador y streamer determinista de sistemas solares bajo capas de Parallax2D.
## Utiliza CosmicMacroGrid y un Object Pool pre-asignado de SolarSystem2D para cero-asignaciones dinámicas.

@export var system_profile: CelestialSystemProfile
@export var parallax_layer: Parallax2D
@export var camera: Camera2D
@export var run_seed: int = 428175
@export var pool_size: int = 4
@export var cell_size: float = 30000.0

var _macro_grid: CosmicMacroGrid
var _pool: Array[SolarSystem2D] = []
var _active_systems: Dictionary = {} # Vector2i -> SolarSystem2D
var _global_time: float = 0.0

func _ready() -> void:
	assert(system_profile != null, "CelestialSystemProfile no asignado en SolarSystemStreamer.")
	_initialize_macro_grid()
	_initialize_system_pool()

func _initialize_macro_grid() -> void:
	_macro_grid = CosmicMacroGrid.new(cell_size, run_seed)

func _initialize_system_pool() -> void:
	for i: int in range(pool_size):
		var sys: SolarSystem2D = SolarSystem2D.new()
		sys.name = "PooledSolarSystem_" + str(i)
		sys.system_profile = system_profile
		sys.visible = false
		add_child(sys)
		_pool.append(sys)

func _process(delta: float) -> void:
	_global_time += delta
	_update_streaming_and_orbits(_global_time)

## Ejecuta la lógica de streaming analítico y evaluación orbital determinista
func _update_streaming_and_orbits(current_time: float) -> void:
	if camera == null or parallax_layer == null or _macro_grid == null:
		# Si no hay cámara/parallax, actualizar al menos los sistemas ya construidos
		for sys: SolarSystem2D in _active_systems.values():
			sys.update_astronomical_state(current_time)
		return

	var zoom: Vector2 = camera.zoom
	if zoom.x <= 0.0001 or zoom.y <= 0.0001:
		zoom = Vector2.ONE

	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size == Vector2.ZERO:
		viewport_size = Vector2(1920.0, 1080.0)

	var viewport_half: Vector2 = (viewport_size * 0.5) / zoom
	var cam_pos: Vector2 = camera.get_screen_center_position()
	if cam_pos == Vector2.ZERO and camera.global_position != Vector2.ZERO:
		cam_pos = camera.global_position

	var layer_center: Vector2 = (cam_pos * parallax_layer.scroll_scale) - parallax_layer.scroll_offset
	var current_cell: Vector2i = _macro_grid.world_to_grid_coords(layer_center)

	# Identificar celdas candidatas visibles
	var required_cells: Array[Vector2i] = []
	for ox: int in range(-1, 2):
		for oy: int in range(-1, 2):
			var candidate_cell: Vector2i = current_cell + Vector2i(ox, oy)
			# Probabilidad de spawn de sistema solar en la celda (ej. 40%)
			if _macro_grid.get_cell_pseudorandom_float(candidate_cell, 9091) > 0.40:
				continue

			var cell_center: Vector2 = _macro_grid.grid_to_world_center(candidate_cell)
			var offset_norm: Vector2 = _macro_grid.get_cell_normalized_offset(candidate_cell, 4321)
			var jitter: Vector2 = (offset_norm - Vector2(0.5, 0.5)) * (cell_size * 0.5)
			var system_pos: Vector2 = cell_center + jitter

			var max_bound: float = system_profile.orbit_radius_max + 1000.0
			if _intersects_frustum(system_pos, layer_center, viewport_half, max_bound):
				required_cells.append(candidate_cell)

	# Desactivar celdas que salieron del frustum
	var cells_to_release: Array[Vector2i] = []
	for active_cell: Vector2i in _active_systems.keys():
		if not required_cells.has(active_cell):
			cells_to_release.append(active_cell)

	for release_cell: Vector2i in cells_to_release:
		var sys_to_return: SolarSystem2D = _active_systems[release_cell]
		sys_to_return.visible = false
		_active_systems.erase(release_cell)
		_pool.append(sys_to_return)

	# Activar o posicionar nuevas celdas usando el pool
	for req_cell: Vector2i in required_cells:
		if not _active_systems.has(req_cell):
			if not _pool.is_empty():
				var sys_to_acquire: SolarSystem2D = _pool.pop_back()
				var cell_seed: int = run_seed ^ CosmicHasher.hash_2d(req_cell.x, req_cell.y, 777)
				sys_to_acquire.build_system(cell_seed)
				
				var cell_center: Vector2 = _macro_grid.grid_to_world_center(req_cell)
				var offset_norm: Vector2 = _macro_grid.get_cell_normalized_offset(req_cell, 4321)
				var jitter: Vector2 = (offset_norm - Vector2(0.5, 0.5)) * (cell_size * 0.5)
				sys_to_acquire.position = cell_center + jitter
				sys_to_acquire.visible = true
				_active_systems[req_cell] = sys_to_acquire

	# Evaluar orbitalmente todos los sistemas activos en t_global
	for sys: SolarSystem2D in _active_systems.values():
		sys.update_astronomical_state(current_time)

func _intersects_frustum(pos: Vector2, center: Vector2, half_extents: Vector2, bound_radius: float) -> bool:
	var delta_pos: Vector2 = (pos - center).abs()
	var boundary: Vector2 = half_extents + Vector2.ONE * bound_radius
	return delta_pos.x <= boundary.x and delta_pos.y <= boundary.y

func get_pool_available_count() -> int:
	return _pool.size()

func get_active_systems_count() -> int:
	return _active_systems.size()

func get_macro_grid() -> CosmicMacroGrid:
	return _macro_grid

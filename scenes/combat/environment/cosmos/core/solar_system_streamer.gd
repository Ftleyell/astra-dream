class_name CosmosSolarSystemStreamer
extends Node2D

## Orquestador y streamer determinista de sistemas solares bajo capas de Parallax2D.
## Utiliza CosmosMacroGrid y un Object Pool pre-asignado de CosmosSolarSystem2D para cero-asignaciones dinámicas.

@export var system_profile: CosmosCelestialSystemProfile
@export var parallax_layer: Parallax2D
@export var camera: Camera2D
@export var run_seed: int = 428175
@export var pool_size: int = 8
@export var cell_size: float = 16000.0

var _macro_grid: CosmosMacroGrid
var _pool: Array[CosmosSolarSystem2D] = []
var _active_systems: Dictionary = {} # Vector2i -> CosmosSolarSystem2D
var _global_time: float = 0.0

var _shadows_enabled: bool = true
var _shadow_opacity: float = 0.85
var _shadow_penumbra_ratio: float = 0.15
var _shadow_expansion_factor: float = 1.05
var _shadow_heliopause_fade: float = 0.70
var _planet_day_exposure: float = 1.30
var _star_core_brightness: float = 1.25

func _ready() -> void:
	assert(system_profile != null, "CosmosCelestialSystemProfile no asignado en CosmosSolarSystemStreamer.")
	if system_profile != null:
		if system_profile.cell_size > 0.0:
			cell_size = system_profile.cell_size
		var s_cfg: CosmosShadowSystemConfig = system_profile.get_effective_shadow_config()
		var p_cfg: CosmosPlanetarySystemConfig = system_profile.get_effective_planetary_config()
		_shadows_enabled = s_cfg.enable_planetary_shadows
		_shadow_opacity = s_cfg.shadow_intensity
		_shadow_penumbra_ratio = s_cfg.shadow_penumbra_ratio
		_shadow_expansion_factor = s_cfg.shadow_expansion_factor
		_shadow_heliopause_fade = s_cfg.shadow_heliopause_fade
		_planet_day_exposure = p_cfg.planet_day_exposure
	_initialize_macro_grid()
	_initialize_system_pool()

func _initialize_macro_grid() -> void:
	_macro_grid = CosmosMacroGrid.new(cell_size, run_seed)

func _initialize_system_pool() -> void:
	for i: int in range(pool_size):
		var sys: CosmosSolarSystem2D = CosmosSolarSystem2D.new()
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
		for sys: CosmosSolarSystem2D in _active_systems.values():
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

	var effective_spawn_chance: float = system_profile.spawn_chance if system_profile != null else 0.75

	# Identificar celdas candidatas visibles
	var required_cells: Array[Vector2i] = []
	for ox: int in range(-1, 2):
		for oy: int in range(-1, 2):
			var candidate_cell: Vector2i = current_cell + Vector2i(ox, oy)
			# Probabilidad determinista de spawn de sistema solar en la celda
			if _macro_grid.get_cell_pseudorandom_float(candidate_cell, 9091) > effective_spawn_chance:
				continue

			var system_pos: Vector2 = get_system_position_for_cell(candidate_cell)

			var max_bound: float = (system_profile.get_maximum_orbital_bound() if system_profile != null else 6000.0) + 1500.0
			if _intersects_frustum(system_pos, layer_center, viewport_half, max_bound):
				required_cells.append(candidate_cell)

	# Desactivar celdas que salieron del frustum
	var cells_to_release: Array[Vector2i] = []
	for active_cell: Vector2i in _active_systems.keys():
		if not required_cells.has(active_cell):
			cells_to_release.append(active_cell)

	for release_cell: Vector2i in cells_to_release:
		var sys_to_return: CosmosSolarSystem2D = _active_systems[release_cell]
		sys_to_return.visible = false
		_active_systems.erase(release_cell)
		_pool.append(sys_to_return)

	# Activar o posicionar nuevas celdas usando el pool
	for req_cell: Vector2i in required_cells:
		if not _active_systems.has(req_cell):
			if not _pool.is_empty():
				var sys_to_acquire: CosmosSolarSystem2D = _pool.pop_back()
				var cell_seed: int = run_seed ^ CosmosHasher.hash_2d(req_cell.x, req_cell.y, 777)
				sys_to_acquire.build_system(cell_seed)
				sys_to_acquire.set_shadows_enabled(_shadows_enabled)
				sys_to_acquire.set_shadow_opacity(_shadow_opacity)
				sys_to_acquire.set_planet_day_exposure(_planet_day_exposure)
				sys_to_acquire.set_star_core_brightness(_star_core_brightness)
				
				sys_to_acquire.position = get_system_position_for_cell(req_cell)
				sys_to_acquire.visible = true
				_active_systems[req_cell] = sys_to_acquire

	# Evaluar orbitalmente todos los sistemas activos en t_global
	for sys: CosmosSolarSystem2D in _active_systems.values():
		sys.update_astronomical_state(current_time)

## Calcula la posición analítica del sistema estelar dentro de la celda,
## acotando el jitter de forma adaptativa para garantizar que las órbitas jamás crucen el margen periférico (cell_boundary_padding).
func get_system_position_for_cell(cell_coords: Vector2i) -> Vector2:
	var cell_center: Vector2 = _macro_grid.grid_to_world_center(cell_coords)
	var cell_seed: int = run_seed ^ CosmosHasher.hash_2d(cell_coords.x, cell_coords.y, 777)
	var arch: CosmosStarArchetype = system_profile.get_archetype_for_seed(cell_seed) if system_profile != null else null
	var sys_reach: float = (arch.orbit_radius_max if arch != null else (system_profile.orbit_radius_max if system_profile != null else 4400.0)) + 400.0
	var padding: float = system_profile.cell_boundary_padding if system_profile != null else 250.0
	var safe_half: float = (cell_size * 0.5) - padding
	var max_jitter_dist: float = maxf(safe_half - sys_reach, 0.0)

	var offset_norm: Vector2 = _macro_grid.get_cell_normalized_offset(cell_coords, 4321)
	var jitter: Vector2 = (offset_norm - Vector2(0.5, 0.5)) * 2.0 * max_jitter_dist
	return cell_center + jitter

func _intersects_frustum(pos: Vector2, center: Vector2, half_extents: Vector2, bound_radius: float) -> bool:
	var delta_pos: Vector2 = (pos - center).abs()
	var boundary: Vector2 = half_extents + Vector2.ONE * bound_radius
	return delta_pos.x <= boundary.x and delta_pos.y <= boundary.y

func get_pool_available_count() -> int:
	return _pool.size()

func get_active_systems_count() -> int:
	return _active_systems.size()

func get_active_systems() -> Dictionary:
	return _active_systems

func get_macro_grid() -> CosmosMacroGrid:
	return _macro_grid


func set_shadows_enabled(p_enabled: bool) -> void:
	_shadows_enabled = p_enabled
	for sys: CosmosSolarSystem2D in _active_systems.values():
		sys.set_shadows_enabled(p_enabled)
	for sys: CosmosSolarSystem2D in _pool:
		sys.set_shadows_enabled(p_enabled)

func set_shadow_opacity(p_opacity: float) -> void:
	_shadow_opacity = p_opacity
	for sys: CosmosSolarSystem2D in _active_systems.values():
		sys.set_shadow_opacity(p_opacity)
	for sys: CosmosSolarSystem2D in _pool:
		sys.set_shadow_opacity(p_opacity)

func set_shadow_penumbra_ratio(p_ratio: float) -> void:
	_shadow_penumbra_ratio = p_ratio
	for sys: CosmosSolarSystem2D in _active_systems.values():
		sys.set_shadow_penumbra_ratio(p_ratio)
	for sys: CosmosSolarSystem2D in _pool:
		sys.set_shadow_penumbra_ratio(p_ratio)

func set_shadow_expansion_factor(p_factor: float) -> void:
	_shadow_expansion_factor = p_factor
	for sys: CosmosSolarSystem2D in _active_systems.values():
		sys.set_shadow_expansion_factor(p_factor)
	for sys: CosmosSolarSystem2D in _pool:
		sys.set_shadow_expansion_factor(p_factor)

func set_shadow_heliopause_fade(p_fade: float) -> void:
	_shadow_heliopause_fade = p_fade
	for sys: CosmosSolarSystem2D in _active_systems.values():
		sys.set_shadow_heliopause_fade(p_fade)
	for sys: CosmosSolarSystem2D in _pool:
		sys.set_shadow_heliopause_fade(p_fade)

# Setters legacy
func set_shadow_longitudinal_fade(p_fade: float) -> void:
	set_shadow_heliopause_fade(p_fade)

func set_shadow_length_multiplier(_p_mult: float) -> void:
	pass

func set_shadow_base_width_scale(_p_scale: float) -> void:
	pass

func set_shadow_tip_curvature(_p_curv: float) -> void:
	pass

func set_planet_day_exposure(p_exp: float) -> void:
	_planet_day_exposure = p_exp
	for sys: CosmosSolarSystem2D in _active_systems.values():
		sys.set_planet_day_exposure(p_exp)
	for sys: CosmosSolarSystem2D in _pool:
		sys.set_planet_day_exposure(p_exp)

func set_star_core_brightness(p_core: float) -> void:
	_star_core_brightness = p_core
	for sys: CosmosSolarSystem2D in _active_systems.values():
		sys.set_star_core_brightness(p_core)
	for sys: CosmosSolarSystem2D in _pool:
		sys.set_star_core_brightness(p_core)

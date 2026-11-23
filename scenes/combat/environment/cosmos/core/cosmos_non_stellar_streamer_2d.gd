class_name CosmosNonStellarStreamer2D
extends Node2D

## Orquestador y streamer determinista de sectores no estelares (Cosmos Engine v3.2).
## Ocupa exactamente las parcelas del macro-grid descartadas por CosmosSolarSystemStreamer
## (exclusión mutua SSOT vía CosmosSolarSystemStreamer.is_cell_solar), usando Object Pooling cero-alloc.

const CosmicPoiRegistry = preload("res://scenes/combat/environment/cosmos/core/cosmic_poi_registry.gd")

signal sector_streamed(sector: CosmosDeepSpaceSector2D, cell: Vector2i)
signal sector_unstreamed(sector: CosmosDeepSpaceSector2D, cell: Vector2i)

@export var system_profile: CosmosCelestialSystemProfile
@export var living_config: CosmosLivingUniverseConfig
@export var debris_profile: CosmosDebrisLayerProfile
@export var solar_streamer: CosmosSolarSystemStreamer = null
@export var parallax_layer: Parallax2D
@export var camera: Camera2D
var poi_registry: CosmicPoiRegistry = null

@export var is_frozen: bool = false
@export var time_scale: float = 1.0
@export var run_seed: int = 428175
@export var pool_size: int = 8
@export var cell_size: float = 16000.0

var _macro_grid: CosmosMacroGrid = null
var _pool: Array[CosmosDeepSpaceSector2D] = []
var _active_sectors: Dictionary = {} # Vector2i -> CosmosDeepSpaceSector2D
var _global_time: float = 0.0

var _graphics_quality: int = 2
var _orbit_guides_visible: bool = false
var _biome_primary: Color = Color(0.28, 0.06, 0.52, 1.0)
var _biome_secondary: Color = Color(0.03, 0.38, 0.62, 1.0)

var _has_camera_override: bool = false
var _override_cam_pos: Vector2 = Vector2.ZERO
var _override_zoom: Vector2 = Vector2.ONE


func set_camera_override(cam_pos: Vector2, zoom: Vector2) -> void:
	_has_camera_override = true
	_override_cam_pos = cam_pos
	_override_zoom = zoom


func clear_camera_override() -> void:
	_has_camera_override = false


func _ready() -> void:
	if system_profile != null and system_profile.cell_size > 0.0:
		cell_size = system_profile.cell_size
	if living_config != null and living_config.sector_pool_size > 0:
		pool_size = living_config.sector_pool_size
	_initialize_macro_grid()
	_initialize_sector_pool()


func _initialize_macro_grid() -> void:
	_macro_grid = CosmosMacroGrid.new(cell_size, run_seed)


func _initialize_sector_pool() -> void:
	if not _pool.is_empty():
		return
	for i: int in range(pool_size):
		var sector := CosmosDeepSpaceSector2D.new()
		sector.name = "PooledNonStellarSector_%d" % i
		sector.system_profile = system_profile
		sector.living_config = living_config
		sector.debris_profile = debris_profile
		sector.visible = false
		add_child(sector)
		_pool.append(sector)


func set_run_seed(p_seed: int) -> void:
	if run_seed == p_seed and _macro_grid != null:
		return
	run_seed = p_seed
	_initialize_macro_grid()
	for cell: Vector2i in _active_sectors.keys():
		var sec: CosmosDeepSpaceSector2D = _active_sectors[cell]
		sec.visible = false
		_pool.append(sec)
		sector_unstreamed.emit(sec, cell)
	_active_sectors.clear()


func _get_effective_spawn_chance() -> float:
	return system_profile.spawn_chance if system_profile != null else 0.65


## Regla de exclusión mutua: verdadera únicamente en celdas sin sol ni POI explícito.
func is_cell_non_stellar(cell: Vector2i) -> bool:
	if poi_registry != null and poi_registry.has_poi(cell):
		return false
	if _macro_grid == null:
		_initialize_macro_grid()
	return not CosmosSolarSystemStreamer.is_cell_solar(
		cell,
		_macro_grid,
		_get_effective_spawn_chance(),
		poi_registry
	)


func get_sector_seed_for_cell(cell: Vector2i) -> int:
	return run_seed ^ CosmosHasher.hash_2d(cell.x, cell.y, 793)


func get_sector_position_for_cell(cell_coords: Vector2i) -> Vector2:
	if _macro_grid == null:
		_initialize_macro_grid()
	var cell_center: Vector2 = _macro_grid.grid_to_world_center(cell_coords)
	var padding: float = system_profile.cell_boundary_padding if system_profile != null else 260.0
	var jitter_margin: float = living_config.sector_jitter_margin if living_config != null else 2800.0
	var safe_half: float = (cell_size * 0.5) - padding
	var max_jitter_dist: float = maxf(safe_half - jitter_margin, 0.0)
	var offset_norm: Vector2 = _macro_grid.get_cell_normalized_offset(cell_coords, 4327)
	var jitter: Vector2 = (offset_norm - Vector2(0.5, 0.5)) * 2.0 * max_jitter_dist
	return cell_center + jitter


func _compute_neighbor_solar_angles(cell: Vector2i, sector_pos: Vector2) -> PackedFloat32Array:
	var angles: PackedFloat32Array = PackedFloat32Array()
	if _macro_grid == null:
		return angles
	var eff_chance: float = _get_effective_spawn_chance()
	var best_d1: float = INF
	var best_a1: float = 0.0
	var best_d2: float = INF
	var best_a2: float = 0.0

	for ox: int in range(-1, 2):
		for oy: int in range(-1, 2):
			if ox == 0 and oy == 0:
				continue
			var nb: Vector2i = cell + Vector2i(ox, oy)
			if not CosmosSolarSystemStreamer.is_cell_solar(nb, _macro_grid, eff_chance, poi_registry):
				continue
			var nb_pos: Vector2 = solar_streamer.get_system_position_for_cell(nb) if solar_streamer != null else _macro_grid.grid_to_world_center(nb)
			var delta_v: Vector2 = nb_pos - sector_pos
			var dist_sq: float = delta_v.length_squared()
			var ang: float = delta_v.angle()
			if dist_sq < best_d1:
				best_d2 = best_d1
				best_a2 = best_a1
				best_d1 = dist_sq
				best_a1 = ang
			elif dist_sq < best_d2:
				best_d2 = dist_sq
				best_a2 = ang

	if best_d1 < INF:
		angles.append(best_a1)
	if best_d2 < INF:
		angles.append(best_a2)
	return angles


func _process(delta: float) -> void:
	if is_frozen:
		return
	_global_time += delta * time_scale
	_update_streaming_and_sectors(_global_time)


func _update_streaming_and_sectors(current_time: float) -> void:
	if (camera == null and not _has_camera_override) or parallax_layer == null or _macro_grid == null:
		for sec: CosmosDeepSpaceSector2D in _active_sectors.values():
			sec.update_sector_state(current_time)
		return

	var zoom: Vector2 = _override_zoom if _has_camera_override else (camera.zoom if camera != null else Vector2.ONE)
	if zoom.x <= 0.0001 or zoom.y <= 0.0001:
		zoom = Vector2.ONE

	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size == Vector2.ZERO:
		viewport_size = Vector2(1920.0, 1080.0)

	var viewport_half: Vector2 = (viewport_size * 0.5) / zoom
	var cam_pos: Vector2 = _override_cam_pos if _has_camera_override else (camera.get_screen_center_position() if camera != null else Vector2.ZERO)
	if not _has_camera_override and cam_pos == Vector2.ZERO and camera != null and camera.global_position != Vector2.ZERO:
		cam_pos = camera.global_position

	var layer_center: Vector2 = (cam_pos * parallax_layer.scroll_scale) - parallax_layer.scroll_offset
	var current_cell: Vector2i = _macro_grid.world_to_grid_coords(layer_center)
	var max_bound: float = living_config.sector_bound_radius if living_config != null else 4200.0

	var required_cells: Array[Vector2i] = []
	for ox: int in range(-1, 2):
		for oy: int in range(-1, 2):
			var candidate_cell: Vector2i = current_cell + Vector2i(ox, oy)
			if not is_cell_non_stellar(candidate_cell):
				continue
			var sec_pos: Vector2 = get_sector_position_for_cell(candidate_cell)
			if _intersects_frustum(sec_pos, layer_center, viewport_half, max_bound):
				required_cells.append(candidate_cell)

	var cells_to_release: Array[Vector2i] = []
	for active_cell: Vector2i in _active_sectors.keys():
		if not required_cells.has(active_cell):
			cells_to_release.append(active_cell)

	for release_cell: Vector2i in cells_to_release:
		var sec_to_return: CosmosDeepSpaceSector2D = _active_sectors[release_cell]
		sec_to_return.visible = false
		_active_sectors.erase(release_cell)
		_pool.append(sec_to_return)
		sector_unstreamed.emit(sec_to_return, release_cell)

	for req_cell: Vector2i in required_cells:
		if not _active_sectors.has(req_cell) and not _pool.is_empty():
			var sec: CosmosDeepSpaceSector2D = _pool.pop_back()
			sec.system_profile = system_profile
			sec.living_config = living_config
			sec.debris_profile = debris_profile
			var sec_pos: Vector2 = get_sector_position_for_cell(req_cell)
			var sec_seed: int = get_sector_seed_for_cell(req_cell)
			var nb_angles: PackedFloat32Array = _compute_neighbor_solar_angles(req_cell, sec_pos)
			sec.apply_biome_harmony(_biome_primary, _biome_secondary)
			sec.apply_graphics_quality(_graphics_quality)
			sec.set_orbit_guides_visible(_orbit_guides_visible)
			sec.build_sector(sec_seed, req_cell, -1, nb_angles)
			sec.position = sec_pos
			sec.visible = true
			_active_sectors[req_cell] = sec
			sector_streamed.emit(sec, req_cell)

	for sec: CosmosDeepSpaceSector2D in _active_sectors.values():
		sec.update_sector_state(current_time)


func _intersects_frustum(pos: Vector2, center: Vector2, half_extents: Vector2, bound_radius: float) -> bool:
	var delta_pos: Vector2 = (pos - center).abs()
	var boundary: Vector2 = half_extents + Vector2.ONE * bound_radius
	return delta_pos.x <= boundary.x and delta_pos.y <= boundary.y


## Localiza la celda no estelar más cercana que coincida opcionalmente con un arquetipo dado.
func find_nearby_sector_cell(origin_layer_pos: Vector2, target_archetype: int = -1, max_ring: int = 5) -> Dictionary:
	var empty_res: Dictionary = {"found": false, "cell": Vector2i.ZERO, "position": Vector2.ZERO, "archetype": 0}
	if _macro_grid == null:
		_initialize_macro_grid()
	var origin_cell: Vector2i = _macro_grid.world_to_grid_coords(origin_layer_pos)
	var cfg: CosmosLivingUniverseConfig = living_config if living_config != null else CosmosLivingUniverseConfig.new()
	var best_dist_sq: float = INF
	var best_res: Dictionary = empty_res

	for ring: int in range(0, max_ring + 1):
		for ox: int in range(-ring, ring + 1):
			for oy: int in range(-ring, ring + 1):
				if ring > 0 and absi(ox) < ring and absi(oy) < ring:
					continue
				var c: Vector2i = origin_cell + Vector2i(ox, oy)
				if not is_cell_non_stellar(c):
					continue
				var sec_seed: int = get_sector_seed_for_cell(c)
				var arch: int = cfg.pick_sector_archetype(sec_seed)
				if target_archetype >= 0 and arch != target_archetype:
					continue
				var pos: Vector2 = get_sector_position_for_cell(c)
				var d_sq: float = pos.distance_squared_to(origin_layer_pos)
				if d_sq < best_dist_sq:
					best_dist_sq = d_sq
					best_res = {"found": true, "cell": c, "position": pos, "archetype": arch}
		if bool(best_res["found"]):
			return best_res
	return best_res


func update_biome_harmony(b_primary: Color, b_secondary: Color) -> void:
	apply_biome_harmony(b_primary, b_secondary)


func apply_biome_harmony(b_primary: Color, b_secondary: Color) -> void:
	_biome_primary = b_primary
	_biome_secondary = b_secondary
	for sec: CosmosDeepSpaceSector2D in _active_sectors.values():
		sec.apply_biome_harmony(b_primary, b_secondary)


func apply_graphics_quality(quality_level: int) -> void:
	_graphics_quality = clampi(quality_level, 0, 2)
	for sec: CosmosDeepSpaceSector2D in _active_sectors.values():
		sec.apply_graphics_quality(_graphics_quality)
	for sec: CosmosDeepSpaceSector2D in _pool:
		sec.apply_graphics_quality(_graphics_quality)


func set_orbit_guides_visible(p_visible: bool) -> void:
	_orbit_guides_visible = p_visible
	for sec: CosmosDeepSpaceSector2D in _active_sectors.values():
		sec.set_orbit_guides_visible(p_visible)
	for sec: CosmosDeepSpaceSector2D in _pool:
		sec.set_orbit_guides_visible(p_visible)


func get_active_sectors() -> Dictionary:
	return _active_sectors


func get_active_sectors_count() -> int:
	return _active_sectors.size()


func get_pool_available_count() -> int:
	return _pool.size()


func get_macro_grid() -> CosmosMacroGrid:
	return _macro_grid

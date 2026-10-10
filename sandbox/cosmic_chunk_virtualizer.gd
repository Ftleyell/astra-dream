class_name CosmicChunkVirtualizer
extends Node2D

## cosmic_chunk_virtualizer.gd
## Virtualizador Jerárquico Bi-Capa del Cosmos:
## 1. Macro-Grid (18.000px): Fenómenos colosales y profundos (Galaxias, Agujeros Negros, Púlsares).
##    - Garantiza presencia de galaxias lejanas aisladas y singularidades sin amontonamiento.
##    - Supresión de singularidades entre celdas macro vecinas.
## 2. Micro-Grid (3.200px): Cuerpos estelares locales (Planetas, lunas, estaciones espaciales).
##    - Rellena densamente el campo visual permanente (siempre hay 2-4 cuerpos en horizonte visual).
##    - Supresión en el radio de atracción del agujero negro.
## 3. Curva de lejanía no lineal continua z: t = pow(rand, 2.2).
## 4. Zero-allocation permanente contra CosmicObjectPool.

# --- Parámetros de Macro-Grid ---
const SpaceEnvironmentConfigScript = preload("res://core/resources/space_environment_config.gd")
@export var env_config: Resource = preload("res://data/environment/default_space_environment_config.tres")
@export var macro_cell_size: float = 4800.0
@export var macro_view_radius: int = 2 # 5x5 celdas macro alrededor de la nave
@export var macro_singularity_chance: float = 0.16 # 16% singularidad por celda macro
@export var macro_galaxy_chance: float = 0.85      # 85% galaxia profunda

# --- Parámetros de Micro-Grid ---
@export var micro_cell_size: float = 3200.0
@export var micro_view_radius: int = 2 # 5x5 celdas micro alrededor de la nave
@export var micro_occupancy_chance: float = 0.78 # 78% probabilidad de contener cuerpo
@export var micro_station_chance: float = 0.75   # Jerarquía 3:1: 75% estación táctica, 25% planeta colosal

@export var world_seed: int = 42
@export var pool_node: CosmicObjectPool

# Registros de celdas activas
# Map[Vector2i, int] (cell -> pool_index)
var _active_macro_cells: Dictionary = {}
var _active_micro_cells: Dictionary = {}

# Caches
var _macro_singularity_cache: Dictionary = {}
var _last_macro_cell: Vector2i = Vector2i(999999, 999999)
var _last_micro_cell: Vector2i = Vector2i(999999, 999999)

func _ready() -> void:
	if not is_instance_valid(pool_node):
		pool_node = get_node_or_null("CosmicObjectPool") as CosmicObjectPool

func update_camera_position(cam_pos: Vector2) -> void:
	if not is_instance_valid(pool_node):
		return

	# 1. Macro Grid Update
	var cur_macro: Vector2i = get_macro_cell_coord(cam_pos)
	if cur_macro != _last_macro_cell:
		_last_macro_cell = cur_macro
		_rebuild_macro_cells(cur_macro)

	# 2. Micro Grid Update
	var cur_micro: Vector2i = get_micro_cell_coord(cam_pos)
	if cur_micro != _last_micro_cell:
		_last_micro_cell = cur_micro
		_rebuild_micro_cells(cur_micro)

# --- Coordinadas y Centros ---
func get_macro_cell_coord(pos: Vector2) -> Vector2i:
	return Vector2i(int(floor(pos.x / macro_cell_size)), int(floor(pos.y / macro_cell_size)))

func get_macro_cell_center(coord: Vector2i) -> Vector2:
	return Vector2((float(coord.x) + 0.5) * macro_cell_size, (float(coord.y) + 0.5) * macro_cell_size)

func get_micro_cell_coord(pos: Vector2) -> Vector2i:
	return Vector2i(int(floor(pos.x / micro_cell_size)), int(floor(pos.y / micro_cell_size)))

func get_micro_cell_center(coord: Vector2i) -> Vector2:
	return Vector2((float(coord.x) + 0.5) * micro_cell_size, (float(coord.y) + 0.5) * micro_cell_size)

# Compatibilidad con contrato anterior
func get_cell_coord(pos: Vector2) -> Vector2i:
	return get_macro_cell_coord(pos)

# --- Ciclo de Reconstrucción de Macro Celdas ---
func _rebuild_macro_cells(center_macro: Vector2i) -> void:
	var needed: Dictionary = {}
	for dy: int in range(-macro_view_radius, macro_view_radius + 1):
		for dx: int in range(-macro_view_radius, macro_view_radius + 1):
			needed[Vector2i(center_macro.x + dx, center_macro.y + dy)] = true

	# Liberar salientes
	var to_remove: Array[Vector2i] = []
	for c: Vector2i in _active_macro_cells.keys():
		if not needed.has(c):
			to_remove.append(c)

	for c: Vector2i in to_remove:
		var pool_idx: int = _active_macro_cells[c]
		if pool_idx >= 0:
			pool_node.release_item(pool_idx)
		_active_macro_cells.erase(c)

	# Adquirir entrantes
	for c: Vector2i in needed.keys():
		if not _active_macro_cells.has(c):
			var desc: Dictionary = generate_macro_descriptor(c)
			if desc.is_empty():
				_active_macro_cells[c] = -1
			else:
				var idx: int = pool_node.acquire_item(desc)
				_active_macro_cells[c] = idx

# --- Ciclo de Reconstrucción de Micro Celdas ---
func _rebuild_micro_cells(center_micro: Vector2i) -> void:
	var needed: Dictionary = {}
	for dy: int in range(-micro_view_radius, micro_view_radius + 1):
		for dx: int in range(-micro_view_radius, micro_view_radius + 1):
			needed[Vector2i(center_micro.x + dx, center_micro.y + dy)] = true

	# Liberar salientes
	var to_remove: Array[Vector2i] = []
	for c: Vector2i in _active_micro_cells.keys():
		if not needed.has(c):
			to_remove.append(c)

	for c: Vector2i in to_remove:
		var pool_idx: int = _active_micro_cells[c]
		if pool_idx >= 0:
			pool_node.release_item(pool_idx)
		_active_micro_cells.erase(c)

	# Adquirir entrantes
	for c: Vector2i in needed.keys():
		if not _active_micro_cells.has(c):
			var desc: Dictionary = generate_micro_descriptor(c)
			if desc.is_empty():
				_active_micro_cells[c] = -1
			else:
				var idx: int = pool_node.acquire_item(desc)
				_active_micro_cells[c] = idx

# --- Lógica Macro (Galaxias, Singularidades) ---
func is_cell_singularity_host(macro_coord: Vector2i) -> bool:
	if _macro_singularity_cache.has(macro_coord):
		return _macro_singularity_cache[macro_coord]

	var rng := RandomNumberGenerator.new()
	rng.seed = _get_hash(macro_coord, 101)
	var is_singularity: bool = rng.randf() < macro_singularity_chance
	_macro_singularity_cache[macro_coord] = is_singularity
	return is_singularity

func has_neighbor_singularity(macro_coord: Vector2i) -> bool:
	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var neighbor := Vector2i(macro_coord.x + dx, macro_coord.y + dy)
			if is_cell_singularity_host(neighbor):
				return true
	return false

func generate_macro_descriptor(coord: Vector2i) -> Dictionary:
	var is_singularity: bool = is_cell_singularity_host(coord)
	var neighbor_singularity: bool = has_neighbor_singularity(coord)

	# Regla de supresión: si un macro-vecino tiene singularidad, suprimir otros macro-fenómenos
	if neighbor_singularity and not is_singularity:
		return {}

	var rng := RandomNumberGenerator.new()
	rng.seed = _get_hash(coord, 777)

	var itype: String = ""
	var base_scale: float = 1.0
	var rot_speed: float = 0.0

	if is_singularity:
		if rng.randf() < 0.5:
			itype = "black_hole"
			base_scale = 0.95
			rot_speed = 0.02
		else:
			itype = "pulsar"
			base_scale = 1.25
			rot_speed = 0.04
	else:
		var gal_chance: float = env_config.galaxy_macro_chance if is_instance_valid(env_config) else macro_galaxy_chance
		if rng.randf() < gal_chance:
			itype = "galaxy"
			var min_s: float = env_config.galaxy_scale_min if is_instance_valid(env_config) else 1.0
			var max_s: float = env_config.galaxy_scale_max if is_instance_valid(env_config) else 1.8
			base_scale = rng.randf_range(min_s, max_s)
			rot_speed = 0.012
		else:
			return {}

	var center: Vector2 = get_macro_cell_center(coord)
	var jitter := Vector2(
		rng.randf_range(-0.35, 0.35) * macro_cell_size,
		rng.randf_range(-0.35, 0.35) * macro_cell_size
	)

	var gal_scroll: float = env_config.galaxy_scroll_scale if is_instance_valid(env_config) else 0.02

	return {
		"layer": "macro",
		"cell_coord": coord,
		"world_pos": center + jitter,
		"type": itype,
		"type_variant": 0,
		"scale": base_scale,
		"scroll_scale": gal_scroll, # Fondo ultra lejano Z
		"alpha": 0.95,
		"haze_depth": 0.35,
		"base_rotation": rng.randf_range(0.0, TAU),
		"rotation_speed": rot_speed,
	}

# --- Lógica Micro (Planetas, Estaciones) ---
func generate_micro_descriptor(coord: Vector2i) -> Dictionary:
	var micro_center: Vector2 = get_micro_cell_center(coord)

	# Comprobar si cae dentro de la zona de exclusión de un agujero negro
	var macro_coord: Vector2i = get_macro_cell_coord(micro_center)
	if is_cell_singularity_host(macro_coord):
		var macro_center: Vector2 = get_macro_cell_center(macro_coord)
		if micro_center.distance_to(macro_center) < 1800.0:
			# El horizonte del agujero negro consume y limpia su entorno inmediato
			return {}

	var rng := RandomNumberGenerator.new()
	rng.seed = _get_hash(coord, 999)

	if rng.randf() > micro_occupancy_chance:
		return {}

	# Curva de lejanía z no lineal: t = pow(rand, 2.2)
	var t: float = pow(rng.randf(), 2.2)
	var scroll_scale: float = lerpf(0.14, 0.035, t)
	var alpha_val: float = lerpf(1.0, 0.45, t)
	var haze_val: float = lerpf(0.20, 0.85, t)
	var scale_factor: float = lerpf(1.0, 0.28, t)
	var rot_speed_factor: float = lerpf(1.0, 0.25, t)

	var itype: String = "planet"
	var variant: int = 0
	var base_scale: float = 1.0
	var rot_speed: float = 0.0

	if rng.randf() < micro_station_chance:
		itype = "station"
		variant = rng.randi_range(0, 2)
		base_scale = 0.52
		rot_speed = rng.randf_range(-0.02, 0.02) * rot_speed_factor
	else:
		itype = "planet"
		variant = rng.randi_range(0, 3)
		base_scale = rng.randf_range(2.0, 3.4)
		rot_speed = rng.randf_range(-0.005, 0.005) * rot_speed_factor

	var jitter := Vector2(
		rng.randf_range(-0.38, 0.38) * micro_cell_size,
		rng.randf_range(-0.38, 0.38) * micro_cell_size
	)

	return {
		"layer": "micro",
		"cell_coord": coord,
		"world_pos": micro_center + jitter,
		"type": itype,
		"type_variant": variant,
		"scale": base_scale * scale_factor,
		"scroll_scale": scroll_scale,
		"alpha": alpha_val,
		"haze_depth": haze_val,
		"base_rotation": rng.randf_range(0.0, TAU),
		"rotation_speed": rot_speed,
		"depth_t": t,
	}

# Compatibilidad con tests previos
func generate_cell_descriptor(macro_coord: Vector2i) -> Dictionary:
	return generate_macro_descriptor(macro_coord)

func find_nearest_phenomenon(target_type: String, from_macro_cell: Vector2i, max_radius: int = 25) -> Vector2:
	for r: int in range(0, max_radius + 1):
		for dy: int in range(-r, r + 1):
			for dx: int in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var coord := Vector2i(from_macro_cell.x + dx, from_macro_cell.y + dy)
				if target_type == "galaxy" or is_cell_singularity_host(coord):
					var desc: Dictionary = generate_macro_descriptor(coord)
					if desc.get("type", "") == target_type:
						return desc.get("world_pos", get_macro_cell_center(coord))
	return Vector2.ZERO

func _get_hash(coord: Vector2i, salt: int) -> int:
	var h: int = world_seed
	h = (h ^ (coord.x * 73856093)) ^ (coord.y * 19349663) ^ (salt * 83492791)
	return absi(h)

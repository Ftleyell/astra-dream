class_name CosmicSocketDirector
extends Node2D

## cosmic_socket_director.gd
## Director de Zócalos Solares y Sistemas Planetarios Orgánicos en Astra Dream.
## Reemplaza las grillas ortogonales discretas por zócalos compositivos jerárquicos:
## - 80% Sistemas de 1 Sol / 20% Sistemas Binarios (2 Soles).
## - 1 a 3 planetas por Sol en radios escalonados (1.800px a 4.200px) con separación >= 60°.
## - 1 a 2 estaciones tácticas en órbitas locales.
## - Galaxias colosales y singularidades desacopladas en planos ultra profundos (Z = 0.02 - 0.05).
## - Cinemática orbital kepleriana en tiempo real con luz dinámica radial coherente.
## - Integración con CosmicViewportArbiter para garantizar la regla anti-duplicados (+20% frustum).

const SpaceEnvironmentConfigScript = preload("res://core/resources/space_environment_config.gd")
const CosmicOrbitalSystemScript = preload("res://sandbox/cosmic_orbital_system.gd")
const CosmicViewportArbiterScript = preload("res://sandbox/cosmic_viewport_arbiter.gd")
@export var env_config: Resource = preload("res://data/environment/default_space_environment_config.tres")

@export var pool_node: CosmicObjectPool
@export var world_seed: int = 42

var _arbiter: RefCounted = null
var _sim_time: float = 0.0

# Registro de zócalos activos: socket_coord (Vector2i) -> Array[Dictionary de orbitales]
var _active_sockets: Dictionary = {}
var _active_deep_phenomena: Dictionary = {} # coord -> pool_index
var _last_socket_center: Vector2i = Vector2i(999999, 999999)

# Estructura interna de cuerpo orbitante activo
# { "pool_index": int, "type": String, "variant": int, "center_sun_pos": Vector2, "radius": float,
#   "period": float, "phase": float, "clockwise": bool, "scroll": float }
var _active_orbiters: Array[Dictionary] = []


func _ready() -> void:
	if not is_instance_valid(pool_node):
		pool_node = get_node_or_null("CosmicObjectPool") as CosmicObjectPool

	var cfg: SpaceEnvironmentConfig = env_config as SpaceEnvironmentConfig
	_arbiter = CosmicViewportArbiterScript.new(cfg)



func _process(delta: float) -> void:
	_sim_time += delta

	# Actualizar cinemática viva orbital y vectores dinámicos de luz hacia el Sol
	if not is_instance_valid(pool_node):
		return

	var count: int = _active_orbiters.size()
	for i: int in range(count):
		var orb: Dictionary = _active_orbiters[i]
		var pool_idx: int = orb["pool_index"]
		var center_pos: Vector2 = orb["center_sun_pos"]
		var radius: float = orb["radius"]
		var period: float = orb["period"]
		var phase: float = orb["phase"]
		var clockwise: bool = orb["clockwise"]

		# Evaluar posición y vector de luz
		var state: Dictionary = CosmicOrbitalSystemScript.evaluate_orbit(
			center_pos,
			radius,
			period,
			phase,
			_sim_time,
			clockwise
		)

		var new_pos: Vector2 = state["position"]
		var l_dir: Vector2 = state["light_direction"]

		pool_node.update_item_world_pos(pool_idx, new_pos)
		pool_node.update_item_light_direction(pool_idx, l_dir)


## Aplica las restricciones anti-duplicado en el viewport de la cámara (+20% frustum).
func apply_viewport_arbitration(
	camera_pos: Vector2,
	viewport_size: Vector2,
	zoom: Vector2 = Vector2.ONE
) -> void:
	if _arbiter == null or not is_instance_valid(pool_node):
		return

	_arbiter.reset_frame()
	var active_items: Array[Dictionary] = pool_node.get_active_items()
	for item: Dictionary in active_items:
		var sprite: Sprite2D = item.get("sprite") as Sprite2D
		if not is_instance_valid(sprite):
			continue
		var render_pos: Vector2 = sprite.position
		var itype: String = item.get("type", "")
		var ivariant: int = item.get("type_variant", 0)
		var is_allowed: bool = _arbiter.evaluate_item(
			itype, ivariant, render_pos, camera_pos, viewport_size, zoom
		)
		sprite.visible = is_allowed


## Actualiza la posición de la cámara y orquesta la activación/reciclado de zócalos.
func update_camera_position(cam_pos: Vector2) -> void:

	if not is_instance_valid(pool_node):
		return

	var spacing: float = _get_socket_spacing()
	var cur_coord: Vector2i = get_socket_coord(cam_pos)

	if cur_coord != _last_socket_center:
		_last_socket_center = cur_coord
		_rebuild_surrounding_sockets(cur_coord)
		_rebuild_deep_phenomena(cur_coord)


func get_socket_coord(pos: Vector2) -> Vector2i:
	var spacing: float = _get_socket_spacing()
	return Vector2i(int(floor(pos.x / spacing)), int(floor(pos.y / spacing)))


func get_socket_center_pos(coord: Vector2i) -> Vector2:
	var spacing: float = _get_socket_spacing()
	var raw_center := Vector2((float(coord.x) + 0.5) * spacing, (float(coord.y) + 0.5) * spacing)
	# Jitter pseudoaleatorio determinista para composición orgánica (±2800px)
	var jitter_hash: float = _hash_2d(coord, 1101)
	var jitter_angle: float = jitter_hash * TAU
	var jitter_dist: float = _hash_2d(coord, 2203) * 2800.0
	return raw_center + Vector2(cos(jitter_angle), sin(jitter_angle)) * jitter_dist


func get_active_sockets_count() -> int:
	return _active_sockets.size()


# --- Orquestación de Zócalos y Descriptores ---

func _rebuild_surrounding_sockets(center_coord: Vector2i) -> void:
	var needed_coords: Array[Vector2i] = []
	for y: int in range(center_coord.y - 1, center_coord.y + 2):
		for x: int in range(center_coord.x - 1, center_coord.x + 2):
			needed_coords.append(Vector2i(x, y))

	# 1. Despawn de zócalos fuera del radio
	var active_keys: Array = _active_sockets.keys()
	for coord_var in active_keys:
		var coord: Vector2i = coord_var as Vector2i
		if not needed_coords.has(coord):
			_despawn_socket(coord)

	# 2. Spawn de zócalos nuevos
	for coord in needed_coords:
		if not _active_sockets.has(coord):
			_spawn_socket(coord)


func _spawn_socket(coord: Vector2i) -> void:
	# Determinismo del zócalo
	var presence_hash: float = _hash_2d(coord, 101)
	if presence_hash > 0.88:
		# 12% de zócalos vacíos (vacío cósmico profundo para respiro)
		_active_sockets[coord] = []
		return

	var center: Vector2 = get_socket_center_pos(coord)
	var is_binary: bool = _hash_2d(coord, 202) < _get_binary_chance()
	var socket_pool_indices: Array[int] = []

	var primary_sun_pos: Vector2 = center
	var sun_var_0: int = int(_hash_2d(coord, 303) * 3.0) % 3

	# Spawn Sol Primario
	var sun_desc: Dictionary = {
		"type": "sun",
		"type_variant": sun_var_0,
		"world_pos": primary_sun_pos,
		"scroll_scale": _get_sun_z_depth(),
		"scale": lerpf(_get_sun_scale_min(), _get_sun_scale_max(), _hash_2d(coord, 404)),
		"base_rotation": _hash_2d(coord, 505) * TAU,
		"rotation_speed": 0.0,
		"socket_id": coord.x * 10007 + coord.y,
	}
	var sun_idx: int = pool_node.acquire_item(sun_desc)
	socket_pool_indices.append(sun_idx)

	# Si es binario, spawn Sol Secundario a 1400px
	if is_binary:
		var binary_angle: float = _hash_2d(coord, 606) * TAU
		var binary_offset: Vector2 = Vector2(cos(binary_angle), sin(binary_angle)) * 1400.0
		var secondary_sun_pos: Vector2 = center + binary_offset
		var sun_var_1: int = (sun_var_0 + 1 + int(_hash_2d(coord, 707) * 2.0)) % 3
		var sun_sec_desc: Dictionary = {
			"type": "sun",
			"type_variant": sun_var_1,
			"world_pos": secondary_sun_pos,
			"scroll_scale": _get_sun_z_depth(),
			"scale": lerpf(_get_sun_scale_min(), _get_sun_scale_max(), _hash_2d(coord, 808)) * 0.85,
			"base_rotation": _hash_2d(coord, 909) * TAU,
			"rotation_speed": 0.0,
			"socket_id": coord.x * 10007 + coord.y,
		}
		var sec_idx: int = pool_node.acquire_item(sun_sec_desc)
		socket_pool_indices.append(sec_idx)

	# Generación de 1 a 3 planetas en órbitas escalonadas
	var planet_count: int = clampi(int(lerpf(1.0, 3.99, _hash_2d(coord, 1001))), 1, 3)
	var base_orbit_angle: float = _hash_2d(coord, 1102) * TAU
	var angle_sep: float = deg_to_rad(_get_planet_min_angular_separation())

	for p in range(planet_count):
		var p_hash: float = _hash_2d(coord, 2000 + p * 100)
		var t_norm: float = (float(p) + 0.35 + p_hash * 0.3) / float(planet_count)
		var orbit_r: float = lerpf(_get_planet_orbit_min(), _get_planet_orbit_max(), t_norm)
		var orbit_phase: float = base_orbit_angle + float(p) * angle_sep + p_hash * 0.5
		var orbit_period: float = lerpf(_get_orbit_period_min(), _get_orbit_period_max(), _hash_2d(coord, 2100 + p * 100))
		var clockwise: bool = _hash_2d(coord, 2200 + p * 100) > 0.5

		var p_variant: int = int(_hash_2d(coord, 2300 + p * 100) * 4.0) % 4
		var p_scale: float = lerpf(_get_planet_scale_min(), _get_planet_scale_max(), _hash_2d(coord, 2400 + p * 100))
		var p_z: float = lerpf(_get_planet_z_min(), _get_planet_z_max(), _hash_2d(coord, 2500 + p * 100))

		var init_state: Dictionary = CosmicOrbitalSystemScript.evaluate_orbit(
			primary_sun_pos, orbit_r, orbit_period, orbit_phase, _sim_time, clockwise
		)

		var planet_desc: Dictionary = {
			"type": "planet",
			"type_variant": p_variant,
			"world_pos": init_state["position"],
			"scroll_scale": p_z,
			"scale": p_scale,
			"base_rotation": _hash_2d(coord, 2600 + p * 100) * TAU,
			"rotation_speed": 0.0,
			"socket_id": coord.x * 10007 + coord.y,
			"light_direction": init_state["light_direction"],
		}
		var p_idx: int = pool_node.acquire_item(planet_desc)
		socket_pool_indices.append(p_idx)

		_active_orbiters.append({
			"pool_index": p_idx,
			"type": "planet",
			"variant": p_variant,
			"center_sun_pos": primary_sun_pos,
			"radius": orbit_r,
			"period": orbit_period,
			"phase": orbit_phase,
			"clockwise": clockwise,
			"scroll": p_z,
		})

	# Generación de 1 a 2 estaciones tácticas
	var station_count: int = clampi(int(lerpf(1.0, 2.99, _hash_2d(coord, 3001))), 1, 2)
	for s in range(station_count):
		var s_hash: float = _hash_2d(coord, 4000 + s * 100)
		var st_orbit_r: float = lerpf(_get_station_orbit_min(), _get_station_orbit_max(), s_hash)
		var st_phase: float = base_orbit_angle + PI + float(s) * 1.2
		var st_period: float = lerpf(_get_orbit_period_min() * 0.75, _get_orbit_period_max() * 0.75, _hash_2d(coord, 4100 + s * 100))
		var st_clockwise: bool = _hash_2d(coord, 4200 + s * 100) < 0.5
		var st_var: int = int(_hash_2d(coord, 4300 + s * 100) * 3.0) % 3
		var st_scale: float = lerpf(_get_station_scale_min(), _get_station_scale_max(), _hash_2d(coord, 4400 + s * 100))
		var st_z: float = lerpf(_get_station_z_min(), _get_station_z_max(), _hash_2d(coord, 4500 + s * 100))

		var init_st_state: Dictionary = CosmicOrbitalSystemScript.evaluate_orbit(
			primary_sun_pos, st_orbit_r, st_period, st_phase, _sim_time, st_clockwise
		)


		var st_desc: Dictionary = {
			"type": "station",
			"type_variant": st_var,
			"world_pos": init_st_state["position"],
			"scroll_scale": st_z,
			"scale": st_scale,
			"base_rotation": _hash_2d(coord, 4600 + s * 100) * TAU,
			"rotation_speed": 0.003 * (-1.0 if st_clockwise else 1.0),
			"socket_id": coord.x * 10007 + coord.y,
			"light_direction": init_st_state["light_direction"],
		}
		var st_idx: int = pool_node.acquire_item(st_desc)
		socket_pool_indices.append(st_idx)

		_active_orbiters.append({
			"pool_index": st_idx,
			"type": "station",
			"variant": st_var,
			"center_sun_pos": primary_sun_pos,
			"radius": st_orbit_r,
			"period": st_period,
			"phase": st_phase,
			"clockwise": st_clockwise,
			"scroll": st_z,
		})

	_active_sockets[coord] = socket_pool_indices


func _despawn_socket(coord: Vector2i) -> void:
	if not _active_sockets.has(coord):
		return

	var indices: Array = _active_sockets[coord]
	for idx_var in indices:
		var p_idx: int = idx_var as int
		# Remover de _active_orbiters
		for i in range(_active_orbiters.size() - 1, -1, -1):
			if _active_orbiters[i]["pool_index"] == p_idx:
				_active_orbiters.remove_at(i)
				break
		pool_node.release_item(p_idx)

	_active_sockets.erase(coord)


# --- Fenómenos Profundos (Galaxias y Singularidades Desacopladas) ---

func _rebuild_deep_phenomena(center_coord: Vector2i) -> void:
	var deep_spacing: float = _get_socket_spacing() * 1.5
	var cur_deep_coord := Vector2i(
		int(floor(float(center_coord.x) * _get_socket_spacing() / deep_spacing)),
		int(floor(float(center_coord.y) * _get_socket_spacing() / deep_spacing))
	)

	var needed_deep: Array[Vector2i] = []
	for y in range(cur_deep_coord.y - 1, cur_deep_coord.y + 2):
		for x in range(cur_deep_coord.x - 1, cur_deep_coord.x + 2):
			needed_deep.append(Vector2i(x, y))

	# Despawn de fenómenos fuera de rango
	var current_deep_keys: Array = _active_deep_phenomena.keys()
	for deep_c_var in current_deep_keys:
		var deep_c: Vector2i = deep_c_var as Vector2i
		if not needed_deep.has(deep_c):
			var pool_idx: int = _active_deep_phenomena[deep_c]
			pool_node.release_item(pool_idx)
			_active_deep_phenomena.erase(deep_c)

	# Spawn de fenómenos en rango
	for deep_c in needed_deep:
		if not _active_deep_phenomena.has(deep_c):
			_spawn_deep_phenomenon(deep_c, deep_spacing)


func _spawn_deep_phenomenon(coord: Vector2i, spacing: float) -> void:
	var center := Vector2((float(coord.x) + 0.5) * spacing, (float(coord.y) + 0.5) * spacing)
	var j_angle: float = _hash_2d(coord, 7701) * TAU
	var j_dist: float = _hash_2d(coord, 7702) * (spacing * 0.35)
	var pos: Vector2 = center + Vector2(cos(j_angle), sin(j_angle)) * j_dist

	var roll: float = _hash_2d(coord, 8801)
	var desc: Dictionary = {}

	if roll < 0.14:
		# Singularidad: 50% Agujero Negro / 50% Púlsar
		var is_bh: bool = _hash_2d(coord, 8802) < 0.50
		var sing_type: String = "black_hole" if is_bh else "pulsar"
		var s_scale: float = lerpf(_get_singularity_scale_min(), _get_singularity_scale_max(), _hash_2d(coord, 8803))
		var s_z: float = lerpf(_get_singularity_z_min(), _get_singularity_z_max(), _hash_2d(coord, 8804))
		desc = {
			"type": sing_type,
			"type_variant": 0,
			"world_pos": pos,
			"scroll_scale": s_z,
			"scale": s_scale,
			"base_rotation": _hash_2d(coord, 8805) * TAU,
			"rotation_speed": 0.001 if is_bh else 0.005,
			"socket_id": -999,
		}
	elif roll < 0.85:
		# Galaxia Colosal de Fondo Ultra Profundo
		var g_scale: float = lerpf(2.5, 4.0, _hash_2d(coord, 9901))
		desc = {
			"type": "galaxy",
			"type_variant": 0,
			"world_pos": pos,
			"scroll_scale": _get_galaxy_z_depth(),
			"scale": g_scale,
			"base_rotation": _hash_2d(coord, 9902) * TAU,
			"rotation_speed": 0.0004,
			"socket_id": -999,
		}

	if not desc.is_empty():
		var idx: int = pool_node.acquire_item(desc)
		_active_deep_phenomena[coord] = idx


# --- Búsqueda de Fenómenos y Compatibilidad ---

func find_nearest_phenomenon(phenom_type: String, origin: Vector2, search_radius: int = 25) -> Vector2:
	var spacing: float = _get_socket_spacing() * 1.5
	var center_coord := Vector2i(int(floor(origin.x / spacing)), int(floor(origin.y / spacing)))

	var nearest_pos: Vector2 = Vector2.ZERO
	var min_dist_sq: float = INF

	for r in range(1, search_radius + 1):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(abs(dx), abs(dy)) != r:
					continue
				var c := Vector2i(center_coord.x + dx, center_coord.y + dy)
				var roll: float = _hash_2d(c, 8801)
				var matches: bool = false
				if phenom_type == "galaxy" and roll >= 0.14 and roll < 0.85:
					matches = true
				elif phenom_type == "black_hole" and roll < 0.14:
					if _hash_2d(c, 8802) < 0.50:
						matches = true
				elif phenom_type == "pulsar" and roll < 0.14:
					if _hash_2d(c, 8802) >= 0.50:
						matches = true

				if matches:
					var center := Vector2((float(c.x) + 0.5) * spacing, (float(c.y) + 0.5) * spacing)
					var j_angle: float = _hash_2d(c, 7701) * TAU
					var j_dist: float = _hash_2d(c, 7702) * (spacing * 0.35)
					var cand_pos: Vector2 = center + Vector2(cos(j_angle), sin(j_angle)) * j_dist
					var d_sq: float = origin.distance_squared_to(cand_pos)
					if d_sq < min_dist_sq:
						min_dist_sq = d_sq
						nearest_pos = cand_pos

		if nearest_pos != Vector2.ZERO:
			return nearest_pos

	return Vector2.ZERO


# Backward compatibility con tests y sandbox
func get_macro_cell_coord(pos: Vector2) -> Vector2i:
	return get_socket_coord(pos)

func get_micro_cell_coord(pos: Vector2) -> Vector2i:
	var sub_spacing: float = _get_socket_spacing() * 0.25
	return Vector2i(int(floor(pos.x / sub_spacing)), int(floor(pos.y / sub_spacing)))

func get_cell_coord(pos: Vector2) -> Vector2i:
	return get_socket_coord(pos)


# --- Parámetros Data-Driven Helpers ---

func _get_socket_spacing() -> float:
	if is_instance_valid(env_config):
		return (env_config as SpaceEnvironmentConfig).solar_socket_spacing
	return 12000.0

func _get_binary_chance() -> float:
	if is_instance_valid(env_config):
		return (env_config as SpaceEnvironmentConfig).binary_system_chance
	return 0.20

func _get_planet_orbit_min() -> float:
	if is_instance_valid(env_config):
		return (env_config as SpaceEnvironmentConfig).planet_orbit_min_radius
	return 1800.0

func _get_planet_orbit_max() -> float:
	if is_instance_valid(env_config):
		return (env_config as SpaceEnvironmentConfig).planet_orbit_max_radius
	return 4200.0

func _get_planet_min_angular_separation() -> float:
	if is_instance_valid(env_config):
		return (env_config as SpaceEnvironmentConfig).planet_min_angular_separation_deg
	return 60.0

func _get_station_orbit_min() -> float:
	if is_instance_valid(env_config):
		return (env_config as SpaceEnvironmentConfig).station_orbit_min_radius
	return 800.0

func _get_station_orbit_max() -> float:
	if is_instance_valid(env_config):
		return (env_config as SpaceEnvironmentConfig).station_orbit_max_radius
	return 1600.0

func _get_orbit_period_min() -> float:
	if is_instance_valid(env_config):
		return (env_config as SpaceEnvironmentConfig).orbit_period_min_sec
	return 180.0

func _get_orbit_period_max() -> float:
	if is_instance_valid(env_config):
		return (env_config as SpaceEnvironmentConfig).orbit_period_max_sec
	return 480.0

func _get_sun_scale_min() -> float:
	if is_instance_valid(env_config):
		return (env_config as SpaceEnvironmentConfig).sun_scale_min
	return 2.0

func _get_sun_scale_max() -> float:
	if is_instance_valid(env_config):
		return (env_config as SpaceEnvironmentConfig).sun_scale_max
	return 3.0

func _get_sun_z_depth() -> float:
	if is_instance_valid(env_config):
		return (env_config as SpaceEnvironmentConfig).sun_z_depth
	return 0.15

func _get_planet_scale_min() -> float:
	if is_instance_valid(env_config):
		return (env_config as SpaceEnvironmentConfig).planet_scale_min
	return 1.6

func _get_planet_scale_max() -> float:
	if is_instance_valid(env_config):
		return (env_config as SpaceEnvironmentConfig).planet_scale_max
	return 2.6

func _get_planet_z_min() -> float:
	if is_instance_valid(env_config):
		return (env_config as SpaceEnvironmentConfig).planet_z_depth_min
	return 0.20

func _get_planet_z_max() -> float:
	if is_instance_valid(env_config):
		return (env_config as SpaceEnvironmentConfig).planet_z_depth_max
	return 0.35

func _get_station_scale_min() -> float:
	if is_instance_valid(env_config):
		return (env_config as SpaceEnvironmentConfig).station_scale_min
	return 0.45

func _get_station_scale_max() -> float:
	if is_instance_valid(env_config):
		return (env_config as SpaceEnvironmentConfig).station_scale_max
	return 0.65

func _get_station_z_min() -> float:
	if is_instance_valid(env_config):
		return (env_config as SpaceEnvironmentConfig).station_z_depth_min
	return 0.45

func _get_station_z_max() -> float:
	if is_instance_valid(env_config):
		return (env_config as SpaceEnvironmentConfig).station_z_depth_max
	return 0.65

func _get_singularity_scale_min() -> float:
	if is_instance_valid(env_config):
		return (env_config as SpaceEnvironmentConfig).singularity_scale_min
	return 0.30

func _get_singularity_scale_max() -> float:
	if is_instance_valid(env_config):
		return (env_config as SpaceEnvironmentConfig).singularity_scale_max
	return 0.48

func _get_singularity_z_min() -> float:
	if is_instance_valid(env_config):
		return (env_config as SpaceEnvironmentConfig).singularity_z_depth_min
	return 0.03

func _get_singularity_z_max() -> float:
	if is_instance_valid(env_config):
		return (env_config as SpaceEnvironmentConfig).singularity_z_depth_max
	return 0.05

func _get_galaxy_z_depth() -> float:
	if is_instance_valid(env_config):
		return (env_config as SpaceEnvironmentConfig).galaxy_z_depth
	return 0.02


# Hash determinista de alta dispersión pseudoaleatoria
func _hash_2d(c: Vector2i, salt: int) -> float:
	var n: int = c.x * 73856093 ^ c.y * 19349663 ^ world_seed * 83492791 ^ salt * 39916801
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return float(abs(n) % 1000000) / 1000000.0

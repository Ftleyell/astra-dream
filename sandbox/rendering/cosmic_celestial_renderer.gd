class_name CosmicCelestialRenderer
extends Node2D

## CosmicCelestialRenderer
## Renderizador determinista O(1) de sistemas estelares, planetas y satélites keplerianos.
## Vincula sectores espaciales generados proceduralmente con CosmicHasher y KeplerOrbitalSolver.
## Mantiene precisión con FloatingOriginTracker y dibuja órbitas + sprites celestes.

const TEXTURE_PATHS: Dictionary = {
	"star_0": "res://assets/environments/parallax_space/Star 0.jpg",
	"star_1": "res://assets/environments/parallax_space/Star 1.jpg",
	"planet_0": "res://assets/environments/parallax_space/planet_0.png",
	"planet_1": "res://assets/environments/parallax_space/planet_1.png",
	"planet_2": "res://assets/environments/parallax_space/planet_2.png",
	"planet_3": "res://assets/environments/parallax_space/planet_3.png",
	"station_0": "res://assets/environments/parallax_space/space_station_0.png",
	"station_1": "res://assets/environments/parallax_space/space_station_1.png",
	"station_2": "res://assets/environments/parallax_space/space_station_2.png",
}

class CelestialMoonData:
	var name: String = ""
	var texture_key: String = ""
	var scale: float = 0.5
	var orbit: KeplerOrbitalSolver.OrbitalElements = null
	var node: Sprite2D = null

class CelestialPlanetData:
	var name: String = ""
	var texture_key: String = ""
	var scale: float = 1.0
	var orbit: KeplerOrbitalSolver.OrbitalElements = null
	var node: Sprite2D = null
	var moons: Array[CelestialMoonData] = []

class CelestialStarSystemData:
	var sector_coords: Vector2i = Vector2i.ZERO
	var logical_center: Vector2 = Vector2.ZERO
	var star_texture_key: String = ""
	var star_scale: float = 2.0
	var star_node: Sprite2D = null
	var root_node: Node2D = null
	var planets: Array[CelestialPlanetData] = []

var universe_seed: int = 1337
var simulation_time: float = 0.0

var _cached_textures: Dictionary = {} # String -> Texture2D
var _active_systems: Dictionary = {}  # Vector2i -> CelestialStarSystemData
var _origin_tracker: FloatingOriginTracker = null


func _ready() -> void:
	_preload_textures()


func configure(tracker: FloatingOriginTracker, p_seed: int = 1337) -> void:
	_origin_tracker = tracker
	universe_seed = p_seed
	if _origin_tracker != null and not _origin_tracker.rebased.is_connected(_on_origin_rebased):
		_origin_tracker.rebased.connect(_on_origin_rebased)


func _preload_textures() -> void:
	for key in TEXTURE_PATHS.keys():
		var path: String = TEXTURE_PATHS[key]
		if ResourceLoader.exists(path):
			_cached_textures[key] = load(path) as Texture2D


func _process(delta: float) -> void:
	simulation_time += delta
	_update_celestial_positions()


## Llamado por el CosmicSectorStreamer cuando un sector entra al rango visible
func on_sector_entered(sector: Vector2i, streamer: CosmicSectorStreamer) -> void:
	if _active_systems.has(sector):
		return

	# Comprobar si el sector alberga un sistema estelar usando CosmicHasher
	var has_star: float = CosmicHasher.hash_2d_float(sector.x, sector.y, universe_seed)
	if has_star < 0.35: # 35% de probabilidad de tener un sistema estelar
		var sys_data: CelestialStarSystemData = _generate_star_system(sector, streamer)
		_active_systems[sector] = sys_data


## Llamado por el CosmicSectorStreamer cuando un sector sale del rango de histéresis
func on_sector_exited(sector: Vector2i) -> void:
	if not _active_systems.has(sector):
		return

	var sys_data: CelestialStarSystemData = _active_systems[sector]
	if sys_data.root_node != null and is_instance_valid(sys_data.root_node):
		sys_data.root_node.queue_free()

	_active_systems.erase(sector)


func _generate_star_system(sector: Vector2i, streamer: CosmicSectorStreamer) -> CelestialStarSystemData:
	var sys: CelestialStarSystemData = CelestialStarSystemData.new()
	sys.sector_coords = sector

	var base_center: Vector2 = streamer.sector_to_world_center(sector)
	var jitter_x: float = CosmicHasher.hash_2d_range(sector.x, sector.y, -1500.0, 1500.0, universe_seed + 1)
	var jitter_y: float = CosmicHasher.hash_2d_range(sector.x, sector.y, -1500.0, 1500.0, universe_seed + 2)
	sys.logical_center = base_center + Vector2(jitter_x, jitter_y)

	var sys_root: Node2D = Node2D.new()
	sys_root.name = "System_%d_%d" % [sector.x, sector.y]
	add_child(sys_root)
	sys.root_node = sys_root

	# Estrella central
	var star_sprite: Sprite2D = Sprite2D.new()
	var star_tex_idx: int = int(CosmicHasher.hash_2d_range(sector.x, sector.y, 0.0, 2.0, universe_seed + 3))
	sys.star_texture_key = "star_%d" % star_tex_idx
	if _cached_textures.has(sys.star_texture_key):
		star_sprite.texture = _cached_textures[sys.star_texture_key]
	sys.star_scale = CosmicHasher.hash_2d_range(sector.x, sector.y, 1.8, 2.8, universe_seed + 4)
	star_sprite.scale = Vector2(sys.star_scale, sys.star_scale)
	sys_root.add_child(star_sprite)
	sys.star_node = star_sprite

	# Planetas (entre 1 y 3 por sistema)
	var num_planets: int = int(CosmicHasher.hash_2d_range(sector.x, sector.y, 1.0, 4.0, universe_seed + 5))
	for p_idx in range(num_planets):
		var p_seed: int = universe_seed + 10 + (p_idx * 17)
		var p_data: CelestialPlanetData = CelestialPlanetData.new()
		p_data.name = "Planet_%d" % p_idx

		var tex_idx: int = int(CosmicHasher.hash_2d_range(sector.x + p_idx, sector.y, 0.0, 4.0, p_seed))
		p_data.texture_key = "planet_%d" % tex_idx
		p_data.scale = CosmicHasher.hash_2d_range(sector.x, sector.y + p_idx, 0.8, 1.4, p_seed + 1)

		# Elementos orbitales keplerianos
		var semi_major: float = 700.0 + (float(p_idx) * 650.0) + CosmicHasher.hash_2d_range(sector.x, sector.y, -100.0, 100.0, p_seed + 2)
		var ecc: float = CosmicHasher.hash_2d_range(sector.x, sector.y, 0.02, 0.35, p_seed + 3)
		var period: float = 40.0 + (float(p_idx) * 45.0)
		var periapsis: float = CosmicHasher.hash_2d_range(sector.x, sector.y, 0.0, TAU, p_seed + 4)
		var m0: float = CosmicHasher.hash_2d_range(sector.x, sector.y, 0.0, TAU, p_seed + 5)

		p_data.orbit = KeplerOrbitalSolver.OrbitalElements.new(semi_major, ecc, period, periapsis, m0)

		var p_sprite: Sprite2D = Sprite2D.new()
		if _cached_textures.has(p_data.texture_key):
			p_sprite.texture = _cached_textures[p_data.texture_key]
		p_sprite.scale = Vector2(p_data.scale, p_data.scale)
		sys_root.add_child(p_sprite)
		p_data.node = p_sprite

		# Lunas / Estaciones orbitales secundarias (0 a 2 por planeta)
		var num_moons: int = int(CosmicHasher.hash_2d_range(sector.x + p_idx, sector.y + p_idx, 0.0, 3.0, p_seed + 6))
		for m_idx in range(num_moons):
			var m_seed: int = p_seed + 50 + (m_idx * 13)
			var moon: CelestialMoonData = CelestialMoonData.new()
			moon.name = "Moon_%d" % m_idx

			var is_station: bool = CosmicHasher.hash_2d_float(sector.x + m_idx, sector.y + p_idx, m_seed) > 0.5
			if is_station:
				var st_idx: int = int(CosmicHasher.hash_2d_range(sector.x, sector.y, 0.0, 3.0, m_seed + 1))
				moon.texture_key = "station_%d" % st_idx
				moon.scale = 0.4
			else:
				var pl_idx: int = int(CosmicHasher.hash_2d_range(sector.x, sector.y, 0.0, 4.0, m_seed + 1))
				moon.texture_key = "planet_%d" % pl_idx
				moon.scale = 0.35

			var m_semi_major: float = 120.0 + (float(m_idx) * 90.0)
			var m_ecc: float = CosmicHasher.hash_2d_range(sector.x, sector.y, 0.0, 0.15, m_seed + 2)
			var m_period: float = 12.0 + (float(m_idx) * 8.0)
			var m_periapsis: float = CosmicHasher.hash_2d_range(sector.x, sector.y, 0.0, TAU, m_seed + 3)
			var m_m0: float = CosmicHasher.hash_2d_range(sector.x, sector.y, 0.0, TAU, m_seed + 4)

			moon.orbit = KeplerOrbitalSolver.OrbitalElements.new(m_semi_major, m_ecc, m_period, m_periapsis, m_m0)

			var m_sprite: Sprite2D = Sprite2D.new()
			if _cached_textures.has(moon.texture_key):
				m_sprite.texture = _cached_textures[moon.texture_key]
			m_sprite.scale = Vector2(moon.scale, moon.scale)
			sys_root.add_child(m_sprite)
			moon.node = m_sprite

			p_data.moons.append(moon)

		sys.planets.append(p_data)

	return sys


func _update_celestial_positions() -> void:
	var origin_offset: Vector2 = Vector2.ZERO
	if _origin_tracker != null:
		origin_offset = _origin_tracker.get_origin()

	for sys in _active_systems.values():
		var sys_data: CelestialStarSystemData = sys as CelestialStarSystemData
		if sys_data.root_node == null or not is_instance_valid(sys_data.root_node):
			continue

		# Posición local del sistema respecto al floating origin
		var sys_local_pos: Vector2 = sys_data.logical_center - origin_offset
		if sys_data.star_node != null:
			sys_data.star_node.position = sys_local_pos

		for planet in sys_data.planets:
			var planet_rel_pos: Vector2 = KeplerOrbitalSolver.solve_position_at_time(planet.orbit, simulation_time)
			var planet_world_pos: Vector2 = sys_local_pos + planet_rel_pos
			if planet.node != null:
				planet.node.position = planet_world_pos

			# Actualizar lunas respecto a su planeta anfitrión
			for moon in planet.moons:
				var moon_rel_pos: Vector2 = KeplerOrbitalSolver.solve_position_at_time(moon.orbit, simulation_time)
				var moon_world_pos: Vector2 = planet_world_pos + moon_rel_pos
				if moon.node != null:
					moon.node.position = moon_world_pos


func _on_origin_rebased(_offset: Vector2) -> void:
	_update_celestial_positions()


func get_active_systems_count() -> int:
	return _active_systems.size()


func get_system(sector: Vector2i) -> CelestialStarSystemData:
	return _active_systems.get(sector, null)

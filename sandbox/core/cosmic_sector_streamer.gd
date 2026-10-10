class_name CosmicSectorStreamer
extends RefCounted

## CosmicSectorStreamer
## Gestor de streaming de sectores espaciales con ventana toroidal e histéresis.
## Evita churn y tirones de carga/descarga usando dos radios concéntricos:
## - inner_radius: distancia de celdas/sectores donde un sector DEBE activarse/cargarse.
## - outer_radius: distancia de celdas/sectores donde un sector permanece activo antes de descartarse.

signal sector_entered(coords: Vector2i)
signal sector_exited(coords: Vector2i)

var sector_size: float = 8000.0
var inner_radius: int = 1   # Radio de activación (ej: 1 -> 3x3 sectores inmediatos)
var outer_radius: int = 2   # Radio de histéresis (ej: 2 -> 5x5 sectores de permanencia)

var _active_sectors: Dictionary = {} # Vector2i -> bool
var _current_center_sector: Vector2i = Vector2i(999999, 999999)


func _init(p_sector_size: float = 8000.0, p_inner_radius: int = 1, p_outer_radius: int = 2) -> void:
	sector_size = maxf(p_sector_size, 1000.0)
	inner_radius = maxi(p_inner_radius, 0)
	outer_radius = maxi(p_outer_radius, inner_radius)


## Convierte posición del mundo lógico a coordenadas de sector entero
func world_to_sector(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		int(floor(world_pos.x / sector_size)),
		int(floor(world_pos.y / sector_size))
	)


## Retorna la posición lógica central de un sector
func sector_to_world_center(coords: Vector2i) -> Vector2:
	return Vector2(
		(float(coords.x) + 0.5) * sector_size,
		(float(coords.y) + 0.5) * sector_size
	)


## Actualiza la ventana de streaming según la posición del observador.
## Emite señales sector_entered y sector_exited solo cuando cambia el conjunto de sectores activos.
func update_streamer(world_pos: Vector2) -> void:
	var center_coords: Vector2i = world_to_sector(world_pos)
	_current_center_sector = center_coords

	# 1. Detectar sectores a activar dentro del inner_radius
	for x in range(center_coords.x - inner_radius, center_coords.x + inner_radius + 1):
		for y in range(center_coords.y - inner_radius, center_coords.y + inner_radius + 1):
			var sector: Vector2i = Vector2i(x, y)
			if not _active_sectors.has(sector):
				_active_sectors[sector] = true
				sector_entered.emit(sector)

	# 2. Desactivar sectores que han salido más allá del outer_radius (banda de histéresis)
	var sectors_to_remove: Array[Vector2i] = []
	for sector in _active_sectors.keys():
		var dx: int = absi(sector.x - center_coords.x)
		var dy: int = absi(sector.y - center_coords.y)
		var chebyshev_dist: int = maxi(dx, dy)
		if chebyshev_dist > outer_radius:
			sectors_to_remove.append(sector)

	for sector in sectors_to_remove:
		_active_sectors.erase(sector)
		sector_exited.emit(sector)


func is_sector_active(coords: Vector2i) -> bool:
	return _active_sectors.has(coords)


func get_active_sectors() -> Array:
	return _active_sectors.keys()


func get_active_sector_count() -> int:
	return _active_sectors.size()


func get_current_center_sector() -> Vector2i:
	return _current_center_sector

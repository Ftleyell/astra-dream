class_name CosmicPoiRegistry
extends RefCounted

## Registro de Overrides y Puntos de Interés (POI) para Cosmos Engine.
## Almacenamiento O(1) indexado por celda Vector2i para inyección en tiempo real
## de eventos narrativos, jefes de sector o sistemas fijos.

signal poi_registered(cell_coord: Vector2i, config: CosmicPoiConfig)
signal poi_unregistered(cell_coord: Vector2i)
signal registry_cleared

var _poi_by_cell: Dictionary = {} # Vector2i -> CosmicPoiConfig

## Registra un POI en una celda absoluta del macro-grid.
func register_poi(coord: Vector2i, config: CosmicPoiConfig) -> void:
	assert(config != null, "CosmicPoiConfig no puede ser nulo.")
	_poi_by_cell[coord] = config
	poi_registered.emit(coord, config)

## Registra un POI relativo al origen de una celda actual.
## Retorna la coordenada absoluta en el macro-grid.
func register_relative_poi(offset: Vector2i, config: CosmicPoiConfig, current_origin: Vector2i) -> Vector2i:
	var abs_coord: Vector2i = current_origin + offset
	register_poi(abs_coord, config)
	return abs_coord

## Desregistra el POI de una celda específica.
func unregister_poi(coord: Vector2i) -> void:
	if _poi_by_cell.erase(coord):
		poi_unregistered.emit(coord)

## Retorna si existe un POI registrado para la coordenada dada.
func has_poi(coord: Vector2i) -> bool:
	return _poi_by_cell.has(coord)

## Retorna la configuración del POI registrado o null si no existe.
func get_poi(coord: Vector2i) -> CosmicPoiConfig:
	return _poi_by_cell.get(coord, null) as CosmicPoiConfig

## Limpia todos los POIs registrados.
func clear_overrides() -> void:
	_poi_by_cell.clear()
	registry_cleared.emit()

## Retorna el número de POIs actualmente registrados.
func get_poi_count() -> int:
	return _poi_by_cell.size()

## Retorna todas las celdas con POIs activos.
func get_registered_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for k: Variant in _poi_by_cell.keys():
		if k is Vector2i:
			result.append(k as Vector2i)
	return result

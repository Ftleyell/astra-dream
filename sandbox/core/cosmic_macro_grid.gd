class_name CosmicMacroGrid
extends RefCounted

## Gestor determinista de macro-cuadrícula espacial infinita para streaming celulizado sin estado.

var cell_size: float
var global_seed: int

func _init(p_cell_size: float, p_seed: int) -> void:
	cell_size = p_cell_size
	global_seed = p_seed

func world_to_grid_coords(world_position: Vector2) -> Vector2i:
	return Vector2i(
		int(floor(world_position.x / cell_size)),
		int(floor(world_position.y / cell_size))
	)

func grid_to_world_center(grid_coords: Vector2i) -> Vector2:
	return Vector2(
		(float(grid_coords.x) + 0.5) * cell_size,
		(float(grid_coords.y) + 0.5) * cell_size
	)

func get_cell_normalized_offset(grid_coords: Vector2i, stream_salt: int) -> Vector2:
	return CosmicHasher.hash_2d_vector(grid_coords.x, grid_coords.y, global_seed ^ stream_salt)

func get_cell_pseudorandom_float(grid_coords: Vector2i, stream_salt: int) -> float:
	return CosmicHasher.hash_2d_float(grid_coords.x, grid_coords.y, global_seed ^ stream_salt)

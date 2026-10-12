class_name TestCosmicMath
extends BaseTestSuite

## Suite de pruebas para la validación matemática determinista de CosmicHasher y CosmicMacroGrid.

func _ready() -> void:
	super._ready()
	_run_cosmic_math_tests()

func _run_cosmic_math_tests() -> void:
	_test_hasher_determinism()
	_test_hasher_bounds_and_dispersion()
	_test_hasher_negative_coordinates()
	_test_macro_grid_coordinate_transforms()
	_test_macro_grid_negative_coordinates()
	_test_macro_grid_pseudorandom_helpers()
	pass_suite("TestCosmicMath completado con éxito (100% assertions pasadas).")

func _test_hasher_determinism() -> void:
	var seed_val: int = 133742
	var h1: int = CosmicHasher.hash_2d(15, 29, seed_val)
	var h2: int = CosmicHasher.hash_2d(15, 29, seed_val)
	assert_true(h1 == h2, "CosmicHasher.hash_2d debe ser estrictamente determinista para los mismos inputs.")

	var f1: float = CosmicHasher.hash_2d_float(15, 29, seed_val)
	var f2: float = CosmicHasher.hash_2d_float(15, 29, seed_val)
	assert_true(is_equal_approx(f1, f2), "CosmicHasher.hash_2d_float debe retornar exactamente el mismo valor.")

	var v1: Vector2 = CosmicHasher.hash_2d_vector(15, 29, seed_val)
	var v2: Vector2 = CosmicHasher.hash_2d_vector(15, 29, seed_val)
	assert_true(v1.is_equal_approx(v2), "CosmicHasher.hash_2d_vector debe ser estrictamente determinista.")

func _test_hasher_bounds_and_dispersion() -> void:
	var seed_val: int = 987654321
	var min_val: float = 1.0
	var max_val: float = 0.0

	# Evaluar 200 puntos muestreados
	for i in range(200):
		var val: float = CosmicHasher.hash_2d_float(i * 17, i * 31, seed_val)
		assert_true(val >= 0.0 and val < 1.0, "hash_2d_float debe estar acotado estrictamente en [0.0, 1.0). Valor obtenido: %f" % val)
		if val < min_val:
			min_val = val
		if val > max_val:
			max_val = val

		var vec: Vector2 = CosmicHasher.hash_2d_vector(i * 13, i * 23, seed_val)
		assert_true(vec.x >= 0.0 and vec.x < 1.0, "Vector2.x debe estar en [0.0, 1.0)")
		assert_true(vec.y >= 0.0 and vec.y < 1.0, "Vector2.y debe estar en [0.0, 1.0)")

	# Comprobar dispersión elemental: el rango cubierto debe ser amplio
	assert_true(min_val < 0.2, "El valor mínimo en 200 muestras debería estar por debajo de 0.2")
	assert_true(max_val > 0.8, "El valor máximo en 200 muestras debería superar 0.8")

func _test_hasher_negative_coordinates() -> void:
	var seed_val: int = 424242
	var h_pos: int = CosmicHasher.hash_2d(10, 20, seed_val)
	var h_neg: int = CosmicHasher.hash_2d(-10, -20, seed_val)
	assert_true(h_pos != h_neg, "Coordenadas positivas y negativas deben producir hashes diferenciados.")

	var f_neg: float = CosmicHasher.hash_2d_float(-55, -89, seed_val)
	assert_true(f_neg >= 0.0 and f_neg < 1.0, "Coordenadas negativas deben mantenerse en [0.0, 1.0)")

	var v_neg: Vector2 = CosmicHasher.hash_2d_vector(-123, -456, seed_val)
	assert_true(v_neg.x >= 0.0 and v_neg.x < 1.0, "Vector X con coordenadas negativas en rango [0.0, 1.0)")
	assert_true(v_neg.y >= 0.0 and v_neg.y < 1.0, "Vector Y con coordenadas negativas en rango [0.0, 1.0)")

func _test_macro_grid_coordinate_transforms() -> void:
	var cell_size: float = 1000.0
	var grid: CosmicMacroGrid = CosmicMacroGrid.new(cell_size, 12345)

	# Positivo estándar
	var coords_origin: Vector2i = grid.world_to_grid_coords(Vector2(500.0, 500.0))
	assert_true(coords_origin == Vector2i(0, 0), "Punto (500, 500) debe pertenecer a la celda (0, 0)")

	var coords_cell1: Vector2i = grid.world_to_grid_coords(Vector2(1500.0, 2500.0))
	assert_true(coords_cell1 == Vector2i(1, 2), "Punto (1500, 2500) debe pertenecer a la celda (1, 2)")

	var center_origin: Vector2 = grid.grid_to_world_center(Vector2i(0, 0))
	assert_true(center_origin.is_equal_approx(Vector2(500.0, 500.0)), "Centro de (0, 0) debe ser (500, 500)")

	var center_cell1: Vector2 = grid.grid_to_world_center(Vector2i(1, 2))
	assert_true(center_cell1.is_equal_approx(Vector2(1500.0, 2500.0)), "Centro de (1, 2) debe ser (1500, 2500)")

func _test_macro_grid_negative_coordinates() -> void:
	var cell_size: float = 1000.0
	var grid: CosmicMacroGrid = CosmicMacroGrid.new(cell_size, 12345)

	# En coordenadas negativas, floor(-500 / 1000) = -1
	var coords_neg: Vector2i = grid.world_to_grid_coords(Vector2(-500.0, -500.0))
	assert_true(coords_neg == Vector2i(-1, -1), "Punto (-500, -500) debe pertenecer a celda (-1, -1)")

	var center_neg: Vector2 = grid.grid_to_world_center(Vector2i(-1, -1))
	assert_true(center_neg.is_equal_approx(Vector2(-500.0, -500.0)), "Centro de (-1, -1) debe ser (-500, -500)")

	var coords_neg2: Vector2i = grid.world_to_grid_coords(Vector2(-1001.0, -2001.0))
	assert_true(coords_neg2 == Vector2i(-2, -3), "Punto (-1001, -2001) debe pertenecer a celda (-2, -3)")

func _test_macro_grid_pseudorandom_helpers() -> void:
	var grid: CosmicMacroGrid = CosmicMacroGrid.new(1000.0, 99999)
	var coords: Vector2i = Vector2i(3, -7)
	var salt: int = 5555

	var offset: Vector2 = grid.get_cell_normalized_offset(coords, salt)
	assert_true(offset.x >= 0.0 and offset.x < 1.0, "get_cell_normalized_offset.x en [0.0, 1.0)")
	assert_true(offset.y >= 0.0 and offset.y < 1.0, "get_cell_normalized_offset.y en [0.0, 1.0)")

	var rnd_float: float = grid.get_cell_pseudorandom_float(coords, salt)
	assert_true(rnd_float >= 0.0 and rnd_float < 1.0, "get_cell_pseudorandom_float en [0.0, 1.0)")
	assert_true(is_equal_approx(rnd_float, offset.x), "Por definición hash_2d_float coincide con el componente X de hash_2d_vector.")

class_name TestCosmicMathSuite
extends BaseTestSuite

## TestCosmicMathSuite
## Prueba unitaria headless para verificar determinismo de CosmicHasher y convergencia de KeplerOrbitalSolver.


const CosmicHasherClass = preload("res://sandbox/math/cosmic_hasher.gd")
const KeplerOrbitalSolverClass = preload("res://sandbox/math/kepler_orbital_solver.gd")


func _ready() -> void:
	super._ready()
	_run_hasher_tests()
	_run_kepler_tests()
	pass_suite("Pruebas matemáticas de CosmicHasher y KeplerOrbitalSolver completadas con éxito.")


func _run_hasher_tests() -> void:
	# 1. Determinismo absoluto: Mismas entradas deben producir idénticos hashes
	var h1: int = CosmicHasherClass.hash_2d(1045, -9923, 1337)
	var h2: int = CosmicHasherClass.hash_2d(1045, -9923, 1337)
	assert_true(h1 == h2, "CosmicHasher debe ser determinista para idéntica entrada 2D y semilla.")

	# 2. Sensibilidad ante cambio de coordenadas o semilla (efecto avalancha)
	var h_diff_x: int = CosmicHasherClass.hash_2d(1046, -9923, 1337)
	var h_diff_seed: int = CosmicHasherClass.hash_2d(1045, -9923, 1338)
	assert_true(h1 != h_diff_x, "CosmicHasher debe variar notablemente al modificar x.")
	assert_true(h1 != h_diff_seed, "CosmicHasher debe variar al modificar la semilla.")

	# 3. Rangos normalizados flotantes [0.0, 1.0)
	for i in range(100):
		var f_val: float = CosmicHasherClass.hash_1d_float(i * 17, 42)
		assert_true(f_val >= 0.0 and f_val < 1.0, "hash_1d_float debe estar estrictamente en [0.0, 1.0). Valor: %f" % f_val)

	# 4. Rango mapeado
	for i in range(50):
		var r_val: float = CosmicHasherClass.hash_2d_range(i, -i, -50.0, 50.0, 99)
		assert_true(r_val >= -50.0 and r_val <= 50.0, "hash_2d_range debe respetar los límites [min, max]. Valor: %f" % r_val)

	# 5. Vectores direccionales unitarios
	for i in range(20):
		var dir: Vector2 = CosmicHasherClass.hash_2d_direction(i, i * 3, 77)
		assert_true(absf(dir.length() - 1.0) < 0.001, "hash_2d_direction debe retornar vectores unitarios.")


func _run_kepler_tests() -> void:
	# 1. Órbita circular simple (e = 0, a = 1000, T = 100s)
	var circular_elems = KeplerOrbitalSolverClass.OrbitalElements.new(
		1000.0, 0.0, 100.0, 0.0, 0.0
	)
	var pos_t0: Vector2 = KeplerOrbitalSolverClass.solve_position_at_time(circular_elems, 0.0)
	var pos_t25: Vector2 = KeplerOrbitalSolverClass.solve_position_at_time(circular_elems, 25.0)
	var pos_t50: Vector2 = KeplerOrbitalSolverClass.solve_position_at_time(circular_elems, 50.0)
	var pos_t100: Vector2 = KeplerOrbitalSolverClass.solve_position_at_time(circular_elems, 100.0)

	# En t=0, debe estar en (1000, 0)
	assert_true(absf(pos_t0.x - 1000.0) < 1.0 and absf(pos_t0.y) < 1.0, "En t=0 posición circular debe ser (1000, 0).")
	# En t=25 (1/4 período), debe estar cerca de (0, 1000)
	assert_true(absf(pos_t25.x) < 2.0 and absf(pos_t25.y - 1000.0) < 2.0, "En t=25s posición circular debe ser (0, 1000).")
	# En t=50 (1/2 período), debe estar en (-1000, 0)
	assert_true(absf(pos_t50.x + 1000.0) < 2.0 and absf(pos_t50.y) < 2.0, "En t=50s posición circular debe ser (-1000, 0).")
	# En t=100 (1 período completo), debe cerrar ciclo exactamente en t0
	assert_true(pos_t0.distance_to(pos_t100) < 0.01, "La órbita debe ser cerrada y periódica tras 1 período T.")

	# 2. Órbita elíptica con excentricidad y rotación (e = 0.5, a = 2000, omega = PI/2)
	var ecc_elems = KeplerOrbitalSolverClass.OrbitalElements.new(
		2000.0, 0.5, 60.0, PI * 0.5, 0.0
	)
	# Distancia en periapsis r_min = a * (1 - e) = 2000 * 0.5 = 1000
	var peri_pos: Vector2 = KeplerOrbitalSolverClass.solve_position_at_time(ecc_elems, 0.0)
	assert_true(absf(peri_pos.length() - 1000.0) < 5.0, "Distancia de periapsis debe coincidir con a*(1-e).")

	# Distancia en apoapsis (t = T/2 = 30s): r_max = a * (1 + e) = 2000 * 1.5 = 3000
	var apo_pos: Vector2 = KeplerOrbitalSolverClass.solve_position_at_time(ecc_elems, 30.0)
	assert_true(absf(apo_pos.length() - 3000.0) < 5.0, "Distancia de apoapsis debe coincidir con a*(1+e).")

	# 3. Comprobación de convergencia para excentricidad extrema (e = 0.95)
	var high_e: float = 0.95
	var ecc_anom: float = KeplerOrbitalSolverClass.solve_eccentric_anomaly(0.75, high_e)
	var kepler_residual: float = absf(ecc_anom - high_e * sin(ecc_anom) - 0.75)
	assert_true(kepler_residual < 1e-5, "Newton-Raphson debe converger con residuo despreciable incluso con alta excentricidad.")

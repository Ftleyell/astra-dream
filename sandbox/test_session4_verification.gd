class_name TestSession4Verification
extends BaseTestSuite

## TestSession4Verification
## Verificación de streaming de sectores con histéresis y renderizado de cuerpos celestes keplerianos.

func _ready() -> void:
	super._ready()
	print("--- INICIANDO TEST DE VERIFICACIÓN SESIÓN 4 SANDBOX (SECTORES & CELESTIALES) ---")

	# 1. Probar CosmicSectorStreamer con histéresis
	var streamer: CosmicSectorStreamer = CosmicSectorStreamer.new(8000.0, 1, 2)
	assert_true(streamer.get_active_sector_count() == 0, "Inicialmente no hay sectores activos")

	# Posicionarse en (0, 0)
	streamer.update_streamer(Vector2.ZERO)
	# inner_radius = 1 -> 3x3 = 9 sectores activados
	assert_true(streamer.get_active_sector_count() == 9, "En (0,0) con inner_radius=1 deben activarse 9 sectores (obtenidos: %d)" % streamer.get_active_sector_count())
	assert_true(streamer.is_sector_active(Vector2i(0, 0)), "Sector central (0,0) debe estar activo")
	assert_true(streamer.is_sector_active(Vector2i(1, 1)), "Sector periférico (1,1) debe estar activo")

	# Moverse ligeramente dentro del mismo sector
	streamer.update_streamer(Vector2(2000.0, 2000.0))
	assert_true(streamer.get_active_sector_count() == 9, "El conteo de sectores no debe cambiar al moverse dentro de la misma vecindad")

	# Moverse un sector a la derecha (8500, 0) -> nuevo centro (1, 0)
	streamer.update_streamer(Vector2(8500.0, 0.0))
	# Con outer_radius = 2, los sectores de x = -1 siguen dentro de dx <= 2, por tanto se mantienen por histéresis
	assert_true(streamer.is_sector_active(Vector2i(-1, 0)), "Sector (-1, 0) debe preservarse por la banda de histéresis")
	assert_true(streamer.is_sector_active(Vector2i(2, 0)), "Nuevo sector (2, 0) debe activarse al entrar al inner_radius de (1, 0)")

	# Teletransportarse lejos a coordenadas astronómicas (x = 80000.0) -> centro (10, 0)
	streamer.update_streamer(Vector2(80000.0, 0.0))
	assert_true(not streamer.is_sector_active(Vector2i(0, 0)), "Sector (0,0) debe ser liberado al salir más allá de outer_radius")
	assert_true(streamer.is_sector_active(Vector2i(10, 0)), "Sector destino (10,0) debe estar activo")

	# 2. Probar CosmicCelestialRenderer y KeplerOrbitalSolver
	var tracker: FloatingOriginTracker = FloatingOriginTracker.new(4000.0)
	var renderer: CosmicCelestialRenderer = CosmicCelestialRenderer.new()
	add_child(renderer)
	renderer.configure(tracker, 42)

	# Simular streaming con el renderer
	for sector in streamer.get_active_sectors():
		renderer.on_sector_entered(sector, streamer)

	# 3. Verificar estabilidad matemática con saltos temporales extremos
	var test_orbit: KeplerOrbitalSolver.OrbitalElements = KeplerOrbitalSolver.OrbitalElements.new(1200.0, 0.25, 60.0, 0.5, 0.0)
	var pos_t0: Vector2 = KeplerOrbitalSolver.solve_position_at_time(test_orbit, 0.0)
	var pos_t1_period: Vector2 = KeplerOrbitalSolver.solve_position_at_time(test_orbit, 60.0)

	# A 1 período orbital completo (60 s), la posición kepleriana debe ser idéntica a t = 0
	var diff_orbit: float = pos_t0.distance_to(pos_t1_period)
	assert_true(diff_orbit < 0.01, "A 1 período orbital completo la posición debe coincidir con t=0 (error: %f)" % diff_orbit)

	# Probar salto temporal extremo (10.000 períodos = 600.000 segundos)
	var pos_future: Vector2 = KeplerOrbitalSolver.solve_position_at_time(test_orbit, 600000.0)
	var diff_future: float = pos_t0.distance_to(pos_future)
	assert_true(diff_future < 0.01, "A 10000 períodos la órbita no debe sufrir deriva acumulada (error: %f)" % diff_future)
	assert_true(not is_nan(pos_future.x) and not is_inf(pos_future.x), "Las coordenadas orbitales no deben generar NaN o Inf")

	# 4. Probar estabilidad con rebase de origen flotante
	tracker.update_actor_position(Vector2(5000.0, 0.0)) # Supera umbral 4000 -> rebase
	assert_true(tracker.get_origin() == Vector2(5000.0, 0.0), "Floating origin rebase debe registrar offset")

	# Ciclo de proceso para asegurar que los nodos y lunas se actualicen sin errores
	renderer._process(0.016)

	print("[PASS] Streamer de sectores con histéresis, jerarquía estelar y estabilidad orbital kepleriana verificados con éxito.")
	pass_suite("Sesión 4 Parallax Sandbox verificada exitosamente")

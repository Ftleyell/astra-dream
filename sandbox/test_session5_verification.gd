class_name TestSession5Verification
extends BaseTestSuite

## TestSession5Verification
## Verificación integral de estrés de vuelo a alta velocidad, integración de subsistemas,
## estabilidad de floating origin y ausencia de NaN/Inf o tirones en el ensamblado sandbox.

func _ready() -> void:
	super._ready()
	print("--- INICIANDO TEST DE INTEGRACIÓN Y ESTRÉS SESIÓN 5 SANDBOX ---")

	# 1. Instanciar la escena principal del sandbox
	var sandbox_scene_res: PackedScene = load("res://sandbox/sandbox_space_view.tscn")
	assert_true(sandbox_scene_res != null, "La escena sandbox_space_view.tscn debe ser cargable")

	var sandbox_view: Node2D = sandbox_scene_res.instantiate() as Node2D
	assert_true(sandbox_view != null, "Instanciación de SandboxSpaceView exitosa")
	add_child(sandbox_view)

	var host: SandboxHost = sandbox_view as SandboxHost
	assert_true(host != null, "El nodo raíz debe ser de tipo SandboxHost")

	# Verificar componentes ensamblados
	assert_true(is_instance_valid(host.ship), "SandboxShip debe estar presente y referenciado")
	assert_true(is_instance_valid(host.parallax_quad), "CosmicParallaxQuad debe estar presente")
	assert_true(is_instance_valid(host.debris_instancer), "CosmicDebrisInstancer debe estar presente")
	assert_true(is_instance_valid(host.celestial_renderer), "CosmicCelestialRenderer debe estar presente")
	assert_true(is_instance_valid(host.telemetry_hud), "SandboxTelemetryHud debe estar presente")

	# 2. Simulación inicial de varios cuadros de proceso
	for i in range(10):
		host._physics_process(0.016)
		host.parallax_quad._process(0.016)
		host.debris_instancer._process(0.016)
		host.celestial_renderer._process(0.016)
		host.telemetry_hud._process(0.016)

	assert_true(host.debris_instancer.get_instance_count() > 0, "MultiMesh de debris debe tener instancias activas en GPU")

	# 3. Test de Estrés: Vuelo a velocidad extrema (100.000 unidades en ráfagas)
	# Esto debe gatillar múltiples eventos de floating origin rebase y streaming de sectores
	var tracker: FloatingOriginTracker = host._origin_tracker
	var streamer: CosmicSectorStreamer = host._sector_streamer
	var initial_rebase_count: int = 0

	# Viajar hacia adelante simulando movimiento a alta velocidad
	for step in range(50):
		# Mover la nave 2500 unidades por frame
		host.ship.global_position += Vector2(2500.0, 1800.0)
		host._physics_process(0.016)
		host.parallax_quad._process(0.016)
		host.debris_instancer._process(0.016)
		host.celestial_renderer._process(0.016)
		host.telemetry_hud._process(0.016)

	var final_logical_pos: Vector2 = tracker.get_logical_position()
	print("Posición lógica alcanzada tras prueba de estrés: %s" % final_logical_pos)

	# Comprobar que no hubo NaN o Inf
	assert_true(not is_nan(final_logical_pos.x) and not is_inf(final_logical_pos.x), "Coordenadas lógicas X válidas sin NaN/Inf")
	assert_true(not is_nan(final_logical_pos.y) and not is_inf(final_logical_pos.y), "Coordenadas lógicas Y válidas sin NaN/Inf")

	# Comprobar que el rebase mantuvo la posición local dentro del umbral
	var local_actor_dist: float = host.ship.global_position.length()
	assert_true(local_actor_dist <= tracker.get_threshold(), "La posición local de la nave debe permanecer acotada por el umbral de rebase (distancia actual: %f, umbral: %f)" % [local_actor_dist, tracker.get_threshold()])

	# Comprobar que los sectores se actualizaron acordemente
	var expected_sector: Vector2i = streamer.world_to_sector(final_logical_pos)
	assert_true(streamer.get_current_center_sector() == expected_sector, "El sector actual del streamer debe coincidir con la posición lógica final")
	assert_true(streamer.is_sector_active(expected_sector), "El sector actual debe encontrarse activo")

	# 4. Teletransporte masivo a coordenadas ultra-lejanas (10^7 unidades)
	print("Ejecutando teletransporte a coordenadas astronómicas ultra-lejanas (10.000.000)...")
	host.ship.global_position = Vector2(10000000.0, -10000000.0)
	host._physics_process(0.016)
	host.parallax_quad._process(0.016)
	host.debris_instancer._process(0.016)
	host.celestial_renderer._process(0.016)
	host.telemetry_hud._process(0.016)

	var ultra_logical_pos: Vector2 = tracker.get_logical_position()
	assert_true(not is_nan(ultra_logical_pos.x) and not is_nan(ultra_logical_pos.y), "Sin desbordamiento o NaN tras teletransporte astronómico")
	assert_true(host.ship.global_position.length() <= tracker.get_threshold(), "El rebase tras teletransporte debe mantener la nave acotada localmente")

	print("[PASS] Escena SandboxSpaceView, HUD y estrés de vuelo a velocidad astronómica verificados con éxito.")
	pass_suite("Sesión 5 Parallax Sandbox verificada exitosamente")

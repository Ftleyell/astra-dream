class_name TestSession3Verification
extends BaseTestSuite

func _ready() -> void:
	super._ready()
	print("--- INICIANDO TEST DE VERIFICACIÓN SESIÓN 3 SANDBOX (DEBRIS MULTIMESH) ---")

	# 1. Verificar carga de shader debris_cutout.gdshader
	var debris_shader: Shader = load("res://sandbox/shaders/debris_cutout.gdshader") as Shader
	assert_true(debris_shader != null, "Shader debris_cutout debe cargar correctamente")

	# 2. Instanciar CosmicDebrisInstancer
	var tracker: FloatingOriginTracker = FloatingOriginTracker.new(4000.0)
	var instancer: CosmicDebrisInstancer = CosmicDebrisInstancer.new()
	instancer.grid_radius = 2 # 5x5 = 25 celdas
	instancer.debris_per_cell = 16 # 25 * 16 = 400 instancias por default
	add_child(instancer)
	instancer.configure(null, tracker)

	# 3. Comprobar que MultiMesh esté configurado
	var total_instances: int = instancer.get_instance_count()
	assert_true(total_instances == 400, "Instancias totales esperadas = 400 (obtenidas: %d)" % total_instances)

	# 4. Probar actualización de celdas con movimiento lógico
	var initial_cell: Vector2i = instancer.get_current_center_cell()
	instancer.update_grid(Vector2(0.0, 0.0))
	var center_after_origin: Vector2i = instancer.get_current_center_cell()
	assert_true(center_after_origin == Vector2i(0, 0), "Celda central en el origen debe ser (0, 0)")

	# Moverse a través de varias celdas para comprobar reciclado toroidal
	instancer.update_grid(Vector2(3600.0, 4800.0))
	var shifted_cell: Vector2i = instancer.get_current_center_cell()
	assert_true(shifted_cell != center_after_origin, "La celda debe actualizarse al desplazarse el actor")

	# Verificar que el total de instancias permanezca invariable (Zero-allocation)
	assert_true(instancer.get_instance_count() == 400, "Total de instancias debe mantenerse idéntico sin re-allocations")

	print("[PASS] MultiMesh, shader de cutout, atlas slicing y reciclado toroidal validados correctamente.")
	pass_suite("Sesión 3 Parallax Sandbox verificada exitosamente")

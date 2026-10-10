class_name TestSession2Verification
extends BaseTestSuite

var _test_rebased_called: bool = false
var _test_rebase_offset: Vector2 = Vector2.ZERO

func _on_rebased(offset: Vector2) -> void:
	_test_rebased_called = true
	_test_rebase_offset = offset

func _ready() -> void:
	super._ready()
	print("--- INICIANDO TEST DE VERIFICACIÓN SESIÓN 2 SANDBOX ---")
	
	# 1. Test FloatingOriginTracker
	var tracker: FloatingOriginTracker = FloatingOriginTracker.new(4000.0)
	assert_true(tracker.get_origin() == Vector2.ZERO, "Origen inicial debe ser (0,0)")
	assert_true(tracker.get_threshold() == 4000.0, "Threshold debe ser 4000")
	
	_test_rebased_called = false
	_test_rebase_offset = Vector2.ZERO
	tracker.rebased.connect(_on_rebased)
	
	# Movimiento bajo umbral
	var triggered: bool = tracker.update_actor_position(Vector2(2000.0, 1000.0))
	assert_true(!triggered, "No debe disparar rebase bajo umbral")
	assert_true(!_test_rebased_called, "Señal rebased no debió emitirse")
	assert_true(tracker.get_logical_position() == Vector2(2000.0, 1000.0), "Pos lógica correcta")
	
	# Movimiento sobre umbral (3000^2 + 3000^2 = 18,000,000 > 16,000,000)
	triggered = tracker.update_actor_position(Vector2(3000.0, 3000.0))
	assert_true(triggered, "Debe disparar rebase al superar umbral")
	assert_true(_test_rebased_called, "Señal rebased debió emitirse")
	assert_true(_test_rebase_offset == Vector2(3000.0, 3000.0), "Offset emitido debe coincidir con posición del actor")
	assert_true(tracker.get_origin() == Vector2(3000.0, 3000.0), "Nuevo origen acumulado")
	assert_true(tracker.get_actor_position() == Vector2.ZERO, "Actor reseteado a origen local")
	assert_true(tracker.get_logical_position() == Vector2(3000.0, 3000.0), "Pos lógica preservada exactamente")
	print("[PASS] FloatingOriginTracker verificado exitosamente.")

	# 2. Test shaders y CosmicParallaxQuad
	var deep_shader: Shader = load("res://sandbox/shaders/space_deep_quad.gdshader") as Shader
	assert_true(deep_shader != null, "Shader deep debe cargar sin errores de sintaxis")
	
	var nebula_shader: Shader = load("res://sandbox/shaders/space_nebula_quad.gdshader") as Shader
	assert_true(nebula_shader != null, "Shader nebula debe cargar sin errores de sintaxis")

	var quad: CosmicParallaxQuad = CosmicParallaxQuad.new()
	add_child(quad)
	quad.configure(null, tracker)
	
	assert_true(quad.get_deep_material() != null, "Deep material inicializado")
	assert_true(quad.get_nebula_material() != null, "Nebula material inicializado")
	
	print("[PASS] Shaders y CosmicParallaxQuad validados en runtime.")
	pass_suite("Sesión 2 Parallax Sandbox verificada exitosamente")

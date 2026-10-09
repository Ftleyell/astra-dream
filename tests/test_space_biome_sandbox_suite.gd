class_name TestSpaceBiomeSandboxSuite
extends BaseTestSuite

## Test automatizado para verificar el sistema de fondos cósmicos,
## atlas estelar 8K, proyección espacial de biomas y reactividad de chatarra.

const SANDBOX_SCENE: PackedScene = preload("res://sandbox/space_biome_sandbox.tscn")

func _ready() -> void:
	super._ready()
	_run_verification()


func _run_verification() -> void:
	var sandbox: SpaceBiomeSandbox = SANDBOX_SCENE.instantiate() as SpaceBiomeSandbox
	assert_true(sandbox != null, "La escena space_biome_sandbox.tscn debe instanciarse correctamente.")
	add_child(sandbox)

	await get_tree().process_frame
	await get_tree().process_frame

	var sm: SectorManager = sandbox.sector_manager
	assert_true(is_instance_valid(sm), "SectorManager debe ser un nodo válido.")

	# 1. En el origen (0, 0), la influencia del Cementerio Mecánico debe ser 0.0
	var initial_gy_inf: float = sm.get_graveyard_influence()
	assert_true(initial_gy_inf < 0.01, "En el origen (0, 0), la influencia del cementerio debe ser ~0.0 (obtenido: %.3f)" % initial_gy_inf)

	# 2. Verificar que los uniformes espaciales se hayan cargado en el quad
	var quad: ColorRect = sandbox.cosmic_quad
	assert_true(is_instance_valid(quad), "CosmicBackgroundQuad debe ser válido.")
	var mat: ShaderMaterial = quad.material as ShaderMaterial
	assert_true(is_instance_valid(mat), "El material del fondo debe ser ShaderMaterial.")
	var sector_cnt: Variant = mat.get_shader_parameter("sector_count")
	assert_true(sector_cnt == 4, "Debe haber 4 sectores subidos al shader (obtenido: %s)" % str(sector_cnt))

	# 3. Mover la nave simulada al centro del Cementerio Mecánico (-6500, 4200)
	var ship_node: Node2D = sandbox.ship
	assert_true(is_instance_valid(ship_node), "La nave del sandbox debe ser válida.")
	ship_node.global_position = Vector2(-6500.0, 4200.0)

	# Procesar varios frames para que las interpolaciones suaves reaccionen
	for _i in range(15):
		await get_tree().process_frame

	var graveyard_gy_inf: float = sm.get_graveyard_influence()
	assert_true(graveyard_gy_inf >= 0.99, "En el centro del Cementerio Mecánico, la influencia debe ser 1.0 (obtenido: %.3f)" % graveyard_gy_inf)

	# Verificar que el alpha de la chatarra haya aumentado significativamente
	if is_instance_valid(sandbox.parallax_debris_deep):
		assert_true(sandbox.parallax_debris_deep.modulate.a > 0.35, "El alpha de la chatarra profunda debe haber aumentado dentro del cementerio (actual: %.3f)" % sandbox.parallax_debris_deep.modulate.a)

	sandbox.queue_free()
	pass_suite("TestSpaceBiomeSandboxSuite completada con éxito. Proyección de biomas y reactividad validadas.")

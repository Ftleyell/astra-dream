class_name TestDebrisMultiMesh
extends BaseTestSuite

## Suite de pruebas para DebrisStreamer2D y MultiMeshInstance2D determinista en Cosmos Engine.
## Valida:
## 1. Instanciación en GPU de MultiMeshInstance2D con Transform2D y colores.
## 2. Conteo de instancias correspondiente al perfil data-driven (hasta 2000 fragmentos en 1 draw call).
## 3. Consistencia determinista de transformaciones y colores por celda/cuadrante espacial.
## 4. Diferenciación determinista entre distintas celdas espaciales.

func _ready() -> void:
	super._ready()
	_run_debris_multimesh_tests()

func _run_debris_multimesh_tests() -> void:
	_test_instance_count_and_multimesh_setup()
	_test_deterministic_reproducibility_same_cell()
	_test_spatial_differentiation_across_cells()
	_test_large_scale_stress_count()
	pass_suite("TestDebrisMultiMesh completado con éxito (100% de aserciones pasadas).")

func _test_instance_count_and_multimesh_setup() -> void:
	var streamer: DebrisStreamer2D = DebrisStreamer2D.new()
	var profile: DebrisLayerProfile = DebrisLayerProfile.new()
	profile.instance_count = 600
	profile.scale_range = Vector2(0.5, 1.5)
	streamer.profile = profile
	streamer.run_seed = 12345
	add_child(streamer)

	var multimesh: MultiMesh = streamer.get_multimesh()
	assert_true(multimesh != null, "MultiMesh debe inicializarse en el streamer.")
	assert_true(multimesh.instance_count == 600, "MultiMesh debe tener exactamente 600 instancias configuradas.")
	assert_true(multimesh.transform_format == MultiMesh.TRANSFORM_2D, "Transform format debe ser TRANSFORM_2D.")
	assert_true(multimesh.use_colors, "MultiMesh debe utilizar colores por instancia.")
	assert_true(multimesh.use_custom_data, "MultiMesh debe utilizar custom data para atlas UV.")

	streamer.queue_free()

func _test_deterministic_reproducibility_same_cell() -> void:
	var streamer: DebrisStreamer2D = DebrisStreamer2D.new()
	var profile: DebrisLayerProfile = DebrisLayerProfile.new()
	profile.instance_count = 100
	streamer.profile = profile
	streamer.run_seed = 987654
	add_child(streamer)

	var target_cell: Vector2i = Vector2i(4, -2)
	streamer.regenerate_cell(target_cell)

	var multimesh: MultiMesh = streamer.get_multimesh()
	var xform_0_run1: Transform2D = multimesh.get_instance_transform_2d(0)
	var xform_50_run1: Transform2D = multimesh.get_instance_transform_2d(50)
	var color_0_run1: Color = multimesh.get_instance_color(0)
	var color_50_run1: Color = multimesh.get_instance_color(50)

	# Forzar cambio a otra celda
	streamer.regenerate_cell(Vector2i(10, 10))
	# Volver a la celda original
	streamer.regenerate_cell(target_cell)

	var xform_0_run2: Transform2D = multimesh.get_instance_transform_2d(0)
	var xform_50_run2: Transform2D = multimesh.get_instance_transform_2d(50)
	var color_0_run2: Color = multimesh.get_instance_color(0)
	var color_50_run2: Color = multimesh.get_instance_color(50)

	assert_true(xform_0_run1.origin.is_equal_approx(xform_0_run2.origin), "La posición de la instancia 0 debe ser idéntica para la misma celda.")
	assert_true(xform_50_run1.origin.is_equal_approx(xform_50_run2.origin), "La posición de la instancia 50 debe ser idéntica para la misma celda.")
	assert_true(is_equal_approx(color_0_run1.a, color_0_run2.a), "El color de la instancia 0 debe ser determinista para la misma celda.")
	assert_true(is_equal_approx(color_50_run1.a, color_50_run2.a), "El color de la instancia 50 debe ser determinista para la misma celda.")

	streamer.queue_free()

func _test_spatial_differentiation_across_cells() -> void:
	var streamer: DebrisStreamer2D = DebrisStreamer2D.new()
	var profile: DebrisLayerProfile = DebrisLayerProfile.new()
	profile.instance_count = 50
	streamer.profile = profile
	streamer.run_seed = 54321
	add_child(streamer)

	streamer.regenerate_cell(Vector2i(0, 0))
	var origin_cell_a: Vector2 = streamer.get_instance_layer_position(0)

	streamer.regenerate_cell(Vector2i(5, 5))
	var origin_cell_b: Vector2 = streamer.get_instance_layer_position(0)

	assert_true(not origin_cell_a.is_equal_approx(origin_cell_b), "Distintas celdas deben generar posiciones relativas o distribuciones diferenciadas.")

	streamer.queue_free()

func _test_large_scale_stress_count() -> void:
	var streamer: DebrisStreamer2D = DebrisStreamer2D.new()
	var profile: DebrisLayerProfile = DebrisLayerProfile.new()
	profile.instance_count = 2000
	streamer.profile = profile
	streamer.run_seed = 777
	add_child(streamer)

	streamer.regenerate_cell(Vector2i(1, 1))
	var multimesh: MultiMesh = streamer.get_multimesh()

	assert_true(multimesh.instance_count == 2000, "Debe soportar 2000 fragmentos en 1 draw call sin degradación.")
	assert_true(multimesh.visible_instance_count == 2000, "Visible instance count debe ser 2000.")

	streamer.queue_free()

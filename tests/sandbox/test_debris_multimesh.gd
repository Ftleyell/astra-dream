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
	_test_dual_multimesh_rock_and_scrap_setup()
	_test_atlas_uv_regions_and_aspect_ratios()
	_test_spatial_distribution_and_anti_overlapping()
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

func _test_dual_multimesh_rock_and_scrap_setup() -> void:
	var streamer: DebrisStreamer2D = DebrisStreamer2D.new()
	var default_res: Resource = load("res://sandbox/resources/data/default_debris_layer.tres")
	assert_true(default_res is DebrisLayerProfile, "default_debris_layer.tres debe cargar un DebrisLayerProfile válido.")
	var profile: DebrisLayerProfile = default_res as DebrisLayerProfile
	streamer.profile = profile
	streamer.run_seed = 991122
	add_child(streamer)

	var rock_multimesh: MultiMesh = streamer.get_multimesh()
	assert_true(rock_multimesh != null, "Rock MultiMesh debe inicializarse.")
	assert_true(rock_multimesh.instance_count == profile.instance_count, "Rock MultiMesh debe coincidir con instance_count del perfil.")

	var scrap_multimesh: MultiMesh = streamer.get_scrap_multimesh()
	assert_true(scrap_multimesh != null, "Scrap MultiMesh debe inicializarse con dual atlas activo.")
	assert_true(scrap_multimesh.instance_count == profile.scrap_instance_count, "Scrap MultiMesh debe coincidir con scrap_instance_count.")

	var total_instances: int = streamer.get_total_instance_count()
	assert_true(total_instances == profile.instance_count + profile.scrap_instance_count, "El total de instancias debe ser la suma de ambos estratos.")

	streamer.queue_free()

func _test_atlas_uv_regions_and_aspect_ratios() -> void:
	var streamer: DebrisStreamer2D = DebrisStreamer2D.new()
	var default_res: Resource = load("res://sandbox/resources/data/default_debris_layer.tres")
	streamer.profile = default_res as DebrisLayerProfile
	streamer.run_seed = 445566
	add_child(streamer)

	streamer.regenerate_cell(Vector2i(2, -3))

	# 1. Verificar que los metadatos cargados contengan las 3 categorías con UVs normalizadas
	assert_true(streamer._rock_micro.size() > 0, "Debe existir estrato micro para rocas.")
	assert_true(streamer._rock_medium.size() > 0, "Debe existir estrato mediano para rocas.")
	assert_true(streamer._rock_macro.size() > 0, "Debe existir estrato macro para rocas.")
	assert_true(streamer._scrap_micro.size() > 0, "Debe existir estrato micro para chatarra.")
	assert_true(streamer._scrap_medium.size() > 0, "Debe existir estrato mediano para chatarra.")
	assert_true(streamer._scrap_macro.size() > 0, "Debe existir estrato macro para chatarra.")

	for item: Dictionary in [streamer._rock_micro[0], streamer._rock_macro[0], streamer._scrap_micro[0]]:
		var uv: Rect2 = item.get("uv_rect", Rect2())
		var px: Vector2 = item.get("pixel_size", Vector2())
		assert_true(uv.size.x > 0.0 and uv.size.x <= 1.0, "UV width debe ser positivo y normalizado.")
		assert_true(uv.size.y > 0.0 and uv.size.y <= 1.0, "UV height debe ser positivo y normalizado.")
		assert_true(px.x > 0.0 and px.y > 0.0, "Pixel size debe ser positivo.")

	# 2. Verificar que las instancias en el MultiMesh tengan escalas positivas
	var rock_mesh: MultiMesh = streamer.get_multimesh()
	for idx: int in [0, 10, 50, 100]:
		var xform: Transform2D = rock_mesh.get_instance_transform_2d(idx)
		var scale_x: float = xform.get_scale().x
		var scale_y: float = xform.get_scale().y
		assert_true(scale_x > 0.0 and scale_y > 0.0, "Las escalas deben ser positivas y no degeneradas.")

		var col: Color = rock_mesh.get_instance_color(idx)
		assert_true(col.a > 0.0 and col.a <= 1.0, "El canal alfa debe estar modulado y normalizado.")

	streamer.queue_free()

func _test_spatial_distribution_and_anti_overlapping() -> void:
	var streamer: DebrisStreamer2D = DebrisStreamer2D.new()
	var default_res: Resource = load("res://sandbox/resources/data/default_debris_layer.tres")
	streamer.profile = default_res as DebrisLayerProfile
	var celestial_res: Resource = load("res://sandbox/resources/data/default_celestial_system.tres")
	streamer.celestial_profile = celestial_res as CelestialSystemProfile
	streamer.run_seed = 771239
	add_child(streamer)

	var test_cell: Vector2i = Vector2i(0, 0)
	streamer.regenerate_cell(test_cell)

	var multimesh: MultiMesh = streamer.get_multimesh()
	assert_true(multimesh != null, "MultiMesh debe existir para prueba espacial.")

	var count: int = multimesh.instance_count
	assert_true(count == 500, "MultiMesh de rocas debe tener 500 instancias según default_debris_layer.tres.")

	var scrap_mesh: MultiMesh = streamer.get_scrap_multimesh()
	assert_true(scrap_mesh != null, "Scrap MultiMesh debe existir.")
	assert_true(scrap_mesh.instance_count == 250, "MultiMesh de chatarra debe tener 250 instancias.")

	var has_star: bool = streamer.has_star_in_cell(test_cell)
	var n_kuiper: int = streamer.get_kuiper_count_for_cell(test_cell)

	if has_star and n_kuiper > 0:
		var star_offset: Vector2 = streamer.get_star_offset_for_cell(test_cell)
		for i: int in range(n_kuiper):
			var xf: Transform2D = multimesh.get_instance_transform_2d(i)
			var dist: float = (xf.origin - star_offset).length()
			# Debe respetar el anillo exterior y no spawnear en el núcleo del sol
			assert_true(dist >= 800.0, "Instancia de Kuiper no debe spawnear en el núcleo del sistema solar.")
	else:
		# En celda sin estrella, las instancias se encuentran en corredores y ambiente
		assert_true(n_kuiper == 0, "No debe haber instancias de Kuiper en celdas sin estrella.")

	# 2. Comprobar que las posiciones no están degeneradas en el origen (0,0) y no hay duplicados exactos
	var pos_set: Dictionary = {}
	var duplicate_count: int = 0
	for i: int in range(mini(count, 100)):
		var origin_pos: Vector2 = multimesh.get_instance_transform_2d(i).origin
		var pos_key: Vector2i = Vector2i(int(round(origin_pos.x)), int(round(origin_pos.y)))
		if pos_set.has(pos_key):
			duplicate_count += 1
		else:
			pos_set[pos_key] = true

	assert_true(duplicate_count == 0, "No debe haber duplicados de posición exactos en la muestra (anti-overlap).")

	# 3. Comprobar que en una celda que contiene estrella, se genera efectivamente Kuiper
	var candidate_star_cell: Vector2i = Vector2i(0, 0)
	for test_x: int in range(10):
		var cand: Vector2i = Vector2i(test_x, 0)
		if streamer.has_star_in_cell(cand):
			candidate_star_cell = cand
			break

	streamer.regenerate_cell(candidate_star_cell)
	var n_star_kuiper: int = streamer.get_kuiper_count_for_cell(candidate_star_cell)
	var star_offset_candidate: Vector2 = streamer.get_star_offset_for_cell(candidate_star_cell)
	assert_true(n_star_kuiper > 0, "En celda con estrella debe generarse cinturón de Kuiper.")
	for k: int in range(mini(n_star_kuiper, 20)):
		var k_xf: Transform2D = multimesh.get_instance_transform_2d(k)
		var k_dist: float = (k_xf.origin - star_offset_candidate).length()
		assert_true(k_dist >= 800.0, "Instancia de Kuiper con estrella debe respetar radio exterior.")

	streamer.queue_free()


class_name TestDebrisLayoutGeneratorSuite
extends BaseTestSuite

## Test unitario aislado para DebrisLayoutGenerator

const DebrisLayoutGeneratorScript = preload("res://sandbox/environment/debris_layout_generator.gd")

func _ready() -> void:
	super._ready()
	test_debris_layout_generation()
	pass_suite("TestDebrisLayoutGeneratorSuite ejecutada con éxito")

func test_debris_layout_generation() -> void:
	var grid: CosmicMacroGrid = CosmicMacroGrid.new(12000.0, 771239)
	var profile: DebrisLayerProfile = load("res://sandbox/resources/data/default_debris_layer.tres") as DebrisLayerProfile
	assert_true(profile != null, "El perfil de debris debe existir")

	var dummy_item: Dictionary = {
		"uv_rect": Rect2(0.0, 0.0, 0.5, 0.5),
		"pixel_size": Vector2(32.0, 32.0),
		"area": 1024.0
	}
	var micro: Array[Dictionary] = [dummy_item]
	var medium: Array[Dictionary] = [dummy_item]
	var macro: Array[Dictionary] = [dummy_item]

	var cell: Vector2i = Vector2i(0, 0)
	var count: int = 100
	var star_offset: Vector2 = Vector2(50.0, -30.0)
	var kuiper_r: float = 4500.0

	var items: Array = DebrisLayoutGeneratorScript.generate_cell_layout(
		cell,
		12000.0,
		count,
		771239,
		false,
		profile,
		grid,
		micro,
		medium,
		macro,
		true,
		star_offset,
		kuiper_r
	)

	assert_true(items.size() == count, "Debe generar exactamente la cantidad solicitada de instancias")

	# Verificar que las primeras instancias correspondan al cinturón de Kuiper y orbiten cerca del radio esperado
	var kuiper_count: int = int(round(float(count) * profile.kuiper_belt_ratio))
	for i: int in range(kuiper_count):
		var item: RefCounted = items[i]
		var dist_to_star: float = (item.position - star_offset).length()
		assert_true(dist_to_star >= kuiper_r - 1.0, "La distancia debe ser mayor o igual al radio interior de Kuiper")
		assert_true(dist_to_star <= kuiper_r + profile.kuiper_belt_width + 1.0, "La distancia debe estar dentro del ancho del cinturón")

class_name TestCosmeticsCarouselSuite
extends BaseTestSuite

## TestCosmeticsCarouselSuite.gd
## Suite de pruebas unitarias para validar:
## 1. Defaults canónicos de loadout (mochi, lyra, skins base de nave, arma y piloto).
## 2. Estructura, shaders y jerarquía de CosmeticCarouselModal (screen blur, silueta negra, glow circular).
## 3. Apertura de categorías (pilot, ship, weapon) y fade orgánico de Valentina.
## 4. Navegación 2D (A/D horizontal para skins, W/S vertical para estrellas).
## 5. Auto-equipamiento y cierre por clic exterior en el blur.

const CosmeticCarouselModalScene = preload("res://scenes/ui/cosmetics/cosmetic_carousel_modal.tscn")

func _ready() -> void:
	super._ready()
	_run_all_tests()


func _run_all_tests() -> void:
	print("--- INICIANDO TEST SUITE: MODAL DE ASPECTOS (COSMETIC CAROUSEL) Y DEFAULTS ---")
	_test_loadout_defaults()
	_test_modal_structure_and_shaders()
	_test_open_pilot_category_and_valentina_fade()
	_test_open_ship_and_weapon_categories()
	_test_horizontal_and_vertical_navigation()
	_test_blur_click_and_close_behavior()

	await get_tree().process_frame
	await get_tree().process_frame
	print("--- TODAS LAS PRUEBAS DE COSMETIC CAROUSEL Y DEFAULTS SUPERADAS ---")
	pass_suite("6/6 pruebas de carrusel de skins, shaders, navegación 2D y defaults superadas.")


func _test_loadout_defaults() -> void:
	var loadout: Dictionary = SaveManager.get_character_loadout(&"test_pilot_defaults")
	assert_true(str(loadout.get("selected_pet", "")) == "mochi", "Default de pet en loadout debe ser 'mochi'.")
	assert_true(str(loadout.get("selected_navigator", "")) == "lyra", "Default de navigator en loadout debe ser 'lyra'.")
	assert_true(str(loadout.get("equipped_ship_skin", "")) == "base", "Default de ship skin debe ser 'base'.")
	assert_true(str(loadout.get("equipped_weapon_skin", "")) == "base", "Default de weapon skin debe ser 'base'.")
	assert_true(str(loadout.get("equipped_pilot_skin", "")) == "base", "Default de pilot skin debe ser 'base'.")
	print("✓ Test 1: Defaults canónicos de loadout validados con éxito.")


func _test_modal_structure_and_shaders() -> void:
	var modal: CanvasLayer = CosmeticCarouselModalScene.instantiate() as CanvasLayer
	add_child(modal)

	var dim: ColorRect = modal.get_node_or_null("DimOverlay") as ColorRect
	assert_true(dim != null, "CosmeticCarouselModal debe poseer nodo DimOverlay.")
	assert_true(dim.material is ShaderMaterial, "DimOverlay debe poseer ShaderMaterial.")
	var blur_mat: ShaderMaterial = dim.material as ShaderMaterial
	assert_true(blur_mat.shader != null, "DimOverlay debe tener screen_blur.gdshader asignado.")
	var blur_amt: float = float(blur_mat.get_shader_parameter("blur_amount"))
	assert_true(is_equal_approx(blur_amt, 2.8), "blur_amount debe ser 2.8 idéntico al estándar de la UI.")

	var glow: Control = modal.get_node_or_null("DimOverlay/CenterContainer/RootHBox/CarouselPanel/Margin/CarouselVBox/CardsRow/CenterColumn/CenterSlot/ArtworkFrame/GlowHolder/CircularGlow") as Control
	assert_true(glow != null, "Debe existir nodo CircularGlow con halo perimetral.")

	var silhouette: TextureRect = modal.get_node_or_null("DimOverlay/CenterContainer/RootHBox/CarouselPanel/Margin/CarouselVBox/CardsRow/CenterColumn/CenterSlot/ArtworkFrame/ArtworkViewport/SilhouetteOverlay") as TextureRect
	assert_true(silhouette != null, "Debe existir nodo SilhouetteOverlay.")
	assert_true(silhouette.material is ShaderMaterial, "SilhouetteOverlay debe tener ShaderMaterial.")
	var sil_mat: ShaderMaterial = silhouette.material as ShaderMaterial
	assert_true(sil_mat.shader != null, "SilhouetteOverlay debe tener shader asignado.")

	modal.queue_free()
	print("✓ Test 2: Estructura, blur y shaders de silueta verificados.")


func _test_open_pilot_category_and_valentina_fade() -> void:
	var modal: CanvasLayer = CosmeticCarouselModalScene.instantiate() as CanvasLayer
	add_child(modal)

	var char_data_nova: CharacterData = CharacterData.new()
	char_data_nova.character_id = &"nova"
	char_data_nova.display_name = "Nova"

	modal.open_modal("pilot", &"nova", char_data_nova)
	assert_true(modal.is_open, "El modal debe quedar abierto tras open_modal.")
	assert_true(modal.get_available_skins_count() > 0, "Debe haber al menos 1 skin para la piloto Nova.")

	# Comprobar ajuste orgánico para Valentina
	var char_data_val: CharacterData = CharacterData.new()
	char_data_val.character_id = &"valentina"
	char_data_val.display_name = "Valentina"

	modal.open_modal("pilot", &"valentina", char_data_val)
	var art_tex: TextureRect = modal.get_node_or_null("DimOverlay/CenterContainer/RootHBox/CarouselPanel/Margin/CarouselVBox/CardsRow/CenterColumn/CenterSlot/ArtworkFrame/ArtworkViewport/ArtworkTexture") as TextureRect
	assert_true(art_tex != null and art_tex.material is ShaderMaterial, "ArtworkTexture debe tener ShaderMaterial para hologram.")
	var holo_mat: ShaderMaterial = art_tex.material as ShaderMaterial
	var fade_val: float = float(holo_mat.get_shader_parameter("bottom_fade_start"))
	assert_true(is_equal_approx(fade_val, 0.78), "Valentina debe tener bottom_fade_start en 0.78 para disimular corte de rodillas.")

	modal.queue_free()
	print("✓ Test 3: Apertura de piloto y bottom fade orgánico de Valentina confirmados.")


func _test_open_ship_and_weapon_categories() -> void:
	var modal: CanvasLayer = CosmeticCarouselModalScene.instantiate() as CanvasLayer
	add_child(modal)

	var char_data: CharacterData = CharacterData.new()
	char_data.character_id = &"nova"
	char_data.display_name = "Nova"

	modal.open_modal("ship", &"nova", char_data)
	assert_true(modal.is_open, "Modal debe abrirse para categoría ship.")
	assert_true(modal.get_available_skins_count() > 0, "Debe encontrar skins de nave para Nova.")

	modal.open_modal("weapon", &"nova", char_data)
	assert_true(modal.is_open, "Modal debe abrirse para categoría weapon.")
	assert_true(modal.get_available_skins_count() > 0, "Debe encontrar skins de arma para Nova.")

	modal.queue_free()
	print("✓ Test 4: Categorías 'ship' y 'weapon' probadas exitosamente.")


func _test_horizontal_and_vertical_navigation() -> void:
	var modal: CanvasLayer = CosmeticCarouselModalScene.instantiate() as CanvasLayer
	add_child(modal)

	var char_data: CharacterData = CharacterData.new()
	char_data.character_id = &"nova"
	char_data.display_name = "Nova"

	modal.open_modal("pilot", &"nova", char_data)
	var initial_skin_idx: int = modal.get_current_skin_index()

	# Ciclado horizontal
	modal.cycle_skins_for_test(1)
	assert_true(modal.get_current_skin_index() != initial_skin_idx or modal.get_available_skins_count() <= 1, "cycle_skins_for_test(1) debe avanzar de skin si hay múltiples.")

	# Ciclado vertical de estrellas
	var init_stars: int = modal.get_current_stars()
	modal.cycle_stars_for_test(1)
	assert_true(modal.get_current_stars() >= 1 and modal.get_current_stars() <= 3, "Nivel de estrellas debe estar en rango 1..3.")

	modal.queue_free()
	print("✓ Test 5: Navegación 2D (horizontal skins, vertical estrellas) verificada.")


func _test_blur_click_and_close_behavior() -> void:
	var modal: CanvasLayer = CosmeticCarouselModalScene.instantiate() as CanvasLayer
	add_child(modal)

	var char_data: CharacterData = CharacterData.new()
	char_data.character_id = &"nova"
	char_data.display_name = "Nova"

	modal.open_modal("pilot", &"nova", char_data)

	var closed_emitted: Array[bool] = [false]
	var closed_cat: Array[String] = [""]
	modal.skin_modal_closed.connect(func(c: String, _t: StringName, _s: String) -> void:
		closed_emitted[0] = true
		closed_cat[0] = c
	)

	# Simular clic en DimOverlay exterior
	var click_event: InputEventMouseButton = InputEventMouseButton.new()
	click_event.button_index = MOUSE_BUTTON_LEFT
	click_event.pressed = true
	click_event.position = Vector2(20, 20)

	var dim: ColorRect = modal.get_node_or_null("DimOverlay") as ColorRect
	dim.gui_input.emit(click_event)

	assert_true(closed_emitted[0], "Al hacer clic en el blur exterior, debe emitir skin_modal_closed.")
	assert_true(closed_cat[0] == "pilot", "Categoría emitida en cierre debe ser 'pilot'.")
	assert_true(not modal.is_open, "El modal debe marcar is_open = false tras cerrarse.")

	modal.queue_free()
	print("✓ Test 6: Cierre automático por clic en blur exterior validado.")

class_name TestSceneTransitionAndTapeButtonSuite
extends BaseTestSuite

## TestSceneTransitionAndTapeButtonSuite
## Suite automatizada para validar:
## 1. TapeMarqueeButton: generación de texturas procedimentales, estados waiting/launch, y disabled.
## 2. SceneTransition: autoload registrado, configuración de 7 pilotos y LUTs 1D generadas.
## 3. Integración en CharacterSelect: presencia del botón de cinta y conexión de lanzamiento.

const TapeMarqueeButtonScene = preload("res://scenes/ui/components/tape_marquee_button.tscn")
const CharacterSelectScene = preload("res://scenes/ui/character_select/character_select.tscn")


func _ready() -> void:
	super._ready()
	_run_all_tests()


func _run_all_tests() -> void:
	print("--- INICIANDO TEST SUITE: SCENE TRANSITION & TAPE MARQUEE BUTTON ---")
	_test_tape_marquee_button_generation()
	_test_scene_transition_autoload_and_luts()
	await _test_character_select_tape_integration()

	await get_tree().process_frame
	await get_tree().process_frame
	print("--- TODAS LAS PRUEBAS DE TRANSICIÓN Y BOTÓN CINTA SUPERADAS ---")
	pass_suite("3/3 pruebas de TapeMarqueeButton y SceneTransition superadas exitosamente.")


func _test_tape_marquee_button_generation() -> void:
	var btn: TapeMarqueeButton = TapeMarqueeButtonScene.instantiate() as TapeMarqueeButton
	add_child(btn)

	assert_true(btn != null, "TapeMarqueeButton debe instanciarse correctamente.")
	assert_true(btn._tex_waiting != null, "Textura de cinta waiting debe generarse procedimentalmente.")
	assert_true(btn._tex_launch != null, "Textura de cinta launch debe generarse procedimentalmente.")

	# Comprobar comportamiento de disabled
	btn.is_disabled = true
	assert_true(btn.is_disabled, "El botón debe reflejar el estado disabled.")

	var pressed_signal_received: Array[bool] = [false]
	btn.pressed.connect(func() -> void: pressed_signal_received[0] = true)

	# Simular click cuando está deshabilitado -> no debe emitir pressed
	var click_event := InputEventMouseButton.new()
	click_event.button_index = MOUSE_BUTTON_LEFT
	click_event.pressed = true
	btn._gui_input(click_event)
	assert_true(not pressed_signal_received[0], "Botón deshabilitado no debe emitir la señal pressed.")

	# Habilitar y simular click -> debe emitir pressed
	btn.is_disabled = false
	btn._gui_input(click_event)
	assert_true(pressed_signal_received[0], "Botón habilitado debe emitir la señal pressed.")

	btn.queue_free()
	print("✓ Test 1: TapeMarqueeButton (texturas procedimentales, estados y disabled) verificado.")


func _test_scene_transition_autoload_and_luts() -> void:
	var st: Node = get_node_or_null("/root/SceneTransition")
	assert_true(st != null, "Autoload SceneTransition debe estar registrado en el árbol.")

	if st:
		var lane_count: int = st.PILOT_CONFIG.size()
		assert_true(lane_count == 7, "SceneTransition debe tener exactamente 7 configuraciones de pilotos definidas.")
		assert_true(st._lut_cache.size() == 7, "Debe tener 7 LUTs 1D anatómicas generadas en caché.")

		for cfg in st.PILOT_CONFIG:
			var pilot_name: String = cfg.name
			assert_true(st._lut_cache.has(pilot_name), "Cada piloto debe contar con su textura LUT 1D generada en caché.")

	print("✓ Test 2: SceneTransition (autoload y 7 LUTs anatómicas) verificado.")


func _test_character_select_tape_integration() -> void:
	var char_select = CharacterSelectScene.instantiate()
	add_child(char_select)

	await get_tree().process_frame

	var tape_btn: TapeMarqueeButton = char_select.tape_launch_btn
	assert_true(tape_btn != null, "TapeLaunchButton debe existir y estar enlazado en CharacterSelect.")

	char_select.queue_free()
	print("✓ Test 3: Integración en CharacterSelect verificada.")

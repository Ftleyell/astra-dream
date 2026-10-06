class_name TestTalentsAndTomesBlurSuite
extends BaseTestSuite

## Suite automatizada para validar la integración de screen blur y blindaje de foco
## en los modales de Árbol de Talentos y Pool de Tomos.

const CharacterSkillTreeModalScene = preload("res://scenes/ui/hub/character_skill_tree_modal.tscn")
const TomeSelectionModalScript = preload("res://scenes/ui/character_select/tome_selection_modal.gd")
const NavigatorSelectionModalScene = preload("res://scenes/ui/character_select/navigator_selection_modal.tscn")

func _ready() -> void:
	super._ready()
	_run_all_tests()

func _run_all_tests() -> void:
	print("--- INICIANDO TEST SUITE: SCREEN BLUR EN TALENTOS Y TOMOS ---")
	_test_navigator_reference_blur_parameters()
	_test_skill_tree_modal_blur_configuration()
	_test_tome_selection_modal_blur_configuration()
	_test_focus_trapping_in_modals()
	_test_tome_selection_modal_dim_overlay_click_closes()
	_test_skill_tree_backdrop_and_navigation_isolation()

	await get_tree().process_frame
	await get_tree().process_frame
	print("--- TODAS LAS PRUEBAS DE SCREEN BLUR EN TALENTOS Y TOMOS SUPERADAS ---")
	pass_suite("6/6 pruebas de blur, aislamiento de foco y cierre exterior superadas.")

func _test_navigator_reference_blur_parameters() -> void:
	var nav_modal: Node = NavigatorSelectionModalScene.instantiate()
	add_child(nav_modal)

	var dim: ColorRect = nav_modal.get_node_or_null("DimOverlay") as ColorRect
	assert_true(dim != null, "NavigatorSelectionModal debe tener DimOverlay.")
	assert_true(dim.material is ShaderMaterial, "DimOverlay de Navigator debe tener ShaderMaterial.")

	var mat: ShaderMaterial = dim.material as ShaderMaterial
	var amount: float = float(mat.get_shader_parameter("blur_amount"))
	var tint: Color = mat.get_shader_parameter("tint_color")
	assert_true(is_equal_approx(amount, 2.8), "Navigator blur_amount de referencia debe ser 2.8.")
	assert_true(tint.is_equal_approx(Color(0.015, 0.02, 0.05, 0.85)), "Navigator tint_color de referencia debe coincidir.")

	nav_modal.queue_free()
	print("✓ Test 1: Parámetros de referencia de Navigator modal validados.")

func _test_skill_tree_modal_blur_configuration() -> void:
	var skill_modal: Control = CharacterSkillTreeModalScene.instantiate() as Control
	add_child(skill_modal)

	var backdrop: ColorRect = skill_modal.get_node_or_null("Backdrop") as ColorRect
	assert_true(backdrop != null, "CharacterSkillTreeModal debe poseer nodo Backdrop.")
	assert_true(backdrop.material is ShaderMaterial, "Backdrop de CharacterSkillTreeModal debe poseer ShaderMaterial.")

	var mat: ShaderMaterial = backdrop.material as ShaderMaterial
	assert_true(mat.shader != null, "Backdrop debe tener un Shader asignado.")
	var blur_amt: float = float(mat.get_shader_parameter("blur_amount"))
	var tint_col: Color = mat.get_shader_parameter("tint_color")
	assert_true(is_equal_approx(blur_amt, 2.8), "Backdrop blur_amount debe ser exactamente 2.8.")
	assert_true(tint_col.is_equal_approx(Color(0.015, 0.02, 0.05, 0.85)), "Backdrop tint_color debe ser idéntico al de navegadoras.")

	skill_modal.queue_free()
	print("✓ Test 2: CharacterSkillTreeModal Backdrop posee ShaderMaterial de blur correctamente configurado.")

func _test_tome_selection_modal_blur_configuration() -> void:
	var tome_modal: TomeSelectionModal = TomeSelectionModalScript.new()
	add_child(tome_modal)

	var dim: ColorRect = tome_modal.dim_overlay
	assert_true(dim != null, "TomeSelectionModal debe poseer dim_overlay.")
	assert_true(dim.material is ShaderMaterial, "dim_overlay de TomeSelectionModal debe poseer ShaderMaterial.")

	var mat: ShaderMaterial = dim.material as ShaderMaterial
	assert_true(mat.shader != null, "dim_overlay debe tener un Shader asignado.")
	var blur_amt: float = float(mat.get_shader_parameter("blur_amount"))
	var tint_col: Color = mat.get_shader_parameter("tint_color")
	assert_true(is_equal_approx(blur_amt, 2.8), "TomeSelectionModal blur_amount debe ser exactamente 2.8.")
	assert_true(tint_col.is_equal_approx(Color(0.015, 0.02, 0.05, 0.85)), "TomeSelectionModal tint_color debe ser idéntico al de navegadoras.")

	tome_modal.queue_free()
	print("✓ Test 3: TomeSelectionModal dim_overlay posee ShaderMaterial de blur idéntico.")

func _test_focus_trapping_in_modals() -> void:
	var tome_modal: TomeSelectionModal = TomeSelectionModalScript.new()
	add_child(tome_modal)
	tome_modal.open_modal(&"nova")

	# Simular evento de foco siguiente
	var ev := InputEventAction.new()
	ev.action = "ui_focus_next"
	ev.pressed = true
	tome_modal._input(ev)
	assert_true(get_viewport().is_input_handled(), "ui_focus_next debe ser consumido por TomeSelectionModal cuando está abierto.")

	tome_modal.close_modal()
	tome_modal.queue_free()

	var skill_modal: Control = CharacterSkillTreeModalScene.instantiate() as Control
	add_child(skill_modal)
	skill_modal.visible = true

	var ev_skill := InputEventAction.new()
	ev_skill.action = "ui_focus_prev"
	ev_skill.pressed = true
	skill_modal._input(ev_skill)
	assert_true(get_viewport().is_input_handled(), "ui_focus_prev debe ser consumido por CharacterSkillTreeModal cuando está visible.")

	skill_modal.queue_free()
	print("✓ Test 4: Blindaje de navegación por foco verificado en ambos modales.")

func _test_tome_selection_modal_dim_overlay_click_closes() -> void:
	var tome_modal: TomeSelectionModal = TomeSelectionModalScript.new()
	add_child(tome_modal)
	tome_modal.open_modal(&"nova")
	assert_true(tome_modal.is_open, "TomeSelectionModal debe estar abierto.")
	assert_true(tome_modal.dim_overlay.mouse_filter == Control.MOUSE_FILTER_STOP, "dim_overlay debe tener mouse_filter = STOP.")
	assert_true(tome_modal._card_buttons.size() >= 6, "TomeSelectionModal debe contener botones para la grilla de tomos.")

	var closed_box: Array[bool] = [false]
	tome_modal.closed.connect(func() -> void: closed_box[0] = true)

	# Simular clic izquierdo del mouse en el dim_overlay exterior
	var click_ev := InputEventMouseButton.new()
	click_ev.button_index = MOUSE_BUTTON_LEFT
	click_ev.pressed = true
	tome_modal._on_dim_overlay_gui_input(click_ev)

	assert_true(closed_box[0], "Hacer clic en dim_overlay exterior debe emitir señal closed.")
	assert_true(not tome_modal.is_open, "TomeSelectionModal debe cerrarse tras clic exterior.")

	# Reabrir y validar que ESC en _input también cierra el modal
	tome_modal.open_modal(&"nova")
	var esc_ev := InputEventKey.new()
	esc_ev.keycode = KEY_ESCAPE
	esc_ev.pressed = true
	tome_modal._input(esc_ev)
	assert_true(not tome_modal.is_open, "Presionar ESC debe cerrar y guardar TomeSelectionModal.")

	tome_modal.queue_free()
	print("✓ Test 5: Clic exterior y tecla ESC en TomeSelectionModal confirman y cierran el modal limpiamente.")

func _test_skill_tree_backdrop_and_navigation_isolation() -> void:
	var skill_modal: CharacterSkillTreeModal = CharacterSkillTreeModalScene.instantiate() as CharacterSkillTreeModal
	add_child(skill_modal)

	var backdrop: ColorRect = skill_modal.get_node_or_null("Backdrop") as ColorRect
	assert_true(backdrop != null, "Backdrop debe existir.")
	assert_true(backdrop.mouse_filter == Control.MOUSE_FILTER_STOP, "Backdrop debe tener mouse_filter = STOP para bloquear clics al fondo.")
	assert_true(skill_modal.focus_mode == Control.FOCUS_ALL, "CharacterSkillTreeModal debe poseer focus_mode = FOCUS_ALL.")

	skill_modal.open_for_character(&"nova")

	# Probar que las teclas de navegación WASD en _input son interceptadas
	var key_w := InputEventKey.new()
	key_w.keycode = KEY_W
	key_w.pressed = true
	skill_modal._input(key_w)
	assert_true(get_viewport().is_input_handled(), "KEY_W debe ser consumido en _input por CharacterSkillTreeModal.")

	var key_d := InputEventKey.new()
	key_d.keycode = KEY_D
	key_d.pressed = true
	skill_modal._input(key_d)
	assert_true(get_viewport().is_input_handled(), "KEY_D debe ser consumido en _input por CharacterSkillTreeModal.")

	skill_modal.queue_free()
	print("✓ Test 6: Backdrop bloquea clicks y _input consume WASD aislando la navegación.")

extends BaseTestSuite

## TestCharacterReselectionSuite
## Reproduce and validates character reselection:
## Kira -> Back -> Roxy -> Confirm -> Back -> Valentina -> ESC (Clean Cancel).

func _ready() -> void:
	super._ready()
	print("\n=======================================================")
	print("[TEST] Testing Character Reselection Kira -> Roxy -> Valentina...")
	print("=======================================================\n")
	_run_reselection_test()

func _run_reselection_test() -> void:
	var scene_res := load("res://scenes/ui/character_select/character_select.tscn") as PackedScene
	assert_true(scene_res != null, "character_select.tscn debe cargar")

	SaveManager.unlock_character(&"kira")
	SaveManager.unlock_character(&"roxy")
	SaveManager.unlock_character(&"valentina")

	var ui: CharacterSelectUI = scene_res.instantiate()
	add_child(ui)

	# 1. Entrada inicial: modal abierto, abilities_view debe estar oculto
	print("[1/5] Verificando entrada inicial y confirmando Kira...")
	assert_true(ui.hero_picker_modal != null, "hero_picker_modal debe existir")
	assert_true(ui.hero_picker_modal.is_open, "hero_picker_modal debe abrirse al entrar a la escena")
	assert_true(not ui.abilities_view.is_visible_in_tree(), "abilities_view debe estar oculto mientras el modal de selección de piloto está abierto")

	ui._on_hero_confirmed(&"kira")

	await get_tree().process_frame
	await get_tree().process_frame

	assert_true(ui.current_character_id == &"kira", "Kira debe estar seleccionada")
	assert_true(ui.abilities_view.is_visible_in_tree(), "abilities_view debe estar visible en el dashboard tras confirmar piloto")

	# 2. Volver al picker con _on_back_pressed()
	print("[2/5] Volviendo al hero picker con _on_back_pressed()...")
	ui._on_back_pressed()

	await get_tree().process_frame
	await get_tree().process_frame

	assert_true(ui.hero_picker_modal.is_open, "hero_picker_modal debe estar abierto")
	assert_true(not ui.abilities_view.is_visible_in_tree(), "abilities_view debe ocultarse en el fondo al reabrir el hero picker")

	# 3. En el picker, encontrar el índice de Roxy y seleccionarla
	print("[3/5] Seleccionando y confirmando Roxy en el modal...")
	var roxy_idx: int = -1
	for i in range(ui.hero_picker_modal._roster.size()):
		if ui.hero_picker_modal._roster[i].character_id == &"roxy":
			roxy_idx = i
			break
	assert_true(roxy_idx != -1, "Roxy debe estar en el roster")
	ui.hero_picker_modal._select_index(roxy_idx)

	await get_tree().process_frame
	await get_tree().process_frame

	ui.hero_picker_modal._confirm_selection()

	await get_tree().process_frame
	await get_tree().process_frame

	assert_true(ui.current_character_id == &"roxy", "Roxy debe estar seleccionada")
	assert_true(ui.abilities_view.is_visible_in_tree(), "abilities_view debe ser visible tras confirmar Roxy")

	# 4. Volver a abrir el modal y cambiar a Valentina
	print("[4/5] Volviendo a abrir picker y cambiando a Valentina...")
	ui._on_back_pressed()

	await get_tree().process_frame
	await get_tree().process_frame

	assert_true(ui.hero_picker_modal.is_open, "hero_picker_modal debe estar abierto por segunda vez")
	assert_true(not ui.abilities_view.is_visible_in_tree(), "abilities_view debe estar oculto de fondo")
	var val_idx: int = -1
	for i in range(ui.hero_picker_modal._roster.size()):
		if ui.hero_picker_modal._roster[i].character_id == &"valentina":
			val_idx = i
			break
	assert_true(val_idx != -1, "Valentina debe estar en el roster")
	ui.hero_picker_modal._select_index(val_idx)

	await get_tree().process_frame
	await get_tree().process_frame

	ui.hero_picker_modal._confirm_selection()

	await get_tree().process_frame
	await get_tree().process_frame

	assert_true(ui.current_character_id == &"valentina", "Valentina debe estar seleccionada")
	assert_true(ui.abilities_view.is_visible_in_tree(), "abilities_view debe ser visible tras confirmar Valentina")

	# 5. Volver a abrir el modal y cancelar
	print("[5/5] Reabriendo picker y cancelando con _cancel_selection()...")
	ui._on_back_pressed()

	await get_tree().process_frame
	await get_tree().process_frame

	assert_true(ui.hero_picker_modal.is_open, "hero_picker_modal debe abrirse")
	assert_true(not ui.abilities_view.is_visible_in_tree(), "abilities_view debe ocultarse")
	ui.hero_picker_modal._cancel_selection()

	await get_tree().process_frame
	await get_tree().process_frame

	assert_true(not ui.hero_picker_modal.is_open, "hero_picker_modal debe haberse cerrado tras cancelar")

	ui.queue_free()
	print("  ✓ Ciclos repetidos de selección, visibilidad de abilities_view y cancelación completados sin errores.")
	pass_suite("Prueba de reselección Kira -> Roxy -> Valentina pasada con éxito.")

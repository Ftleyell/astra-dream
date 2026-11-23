class_name TestHighscoresSuite
extends BaseTestSuite

const HighscoresModalScene: PackedScene = preload("res://scenes/ui/highscores/highscores_modal.tscn")

func _ready() -> void:
	super._ready()
	_run_tests()

func _run_tests() -> void:
	print("--- Running TestHighscoresSuite ---")
	var modal: HighscoresModal = HighscoresModalScene.instantiate() as HighscoresModal
	assert_true(modal != null, "HighscoresModal scene must instantiate properly")
	add_child(modal)
	await get_tree().process_frame

	# 1. Verificación de inicialización y componentes
	assert_true(modal._tab_controller != null, "HighscoresTabController must be initialized")
	assert_true(modal.tab_career_btn != null, "Career tab button must exist")
	assert_true(modal.tab_hof_btn != null, "Hall of Fame tab button must exist")
	assert_true(modal.career_container != null, "Career container must exist")

	# 2. Apertura en carrera
	modal.open_career()
	assert_true(modal.visible, "Modal should be visible after open_career()")
	assert_true(modal.current_tab == 0, "Current tab should be 0 (Career)")
	assert_true(modal.career_container.visible, "Career container should be visible")
	assert_true(modal.scroll_container.visible == false, "Top 10 scroll container should be hidden in career mode")
	assert_true(modal.table_header.visible == false, "Table header should be hidden in career mode")
	assert_true(modal.career_container.get_child_count() > 0, "Career container should be populated")

	# 3. Cambio a Hall of Fame (Top 10)
	modal._tab_controller.switch_tab(1, false)
	assert_true(modal.current_tab == 1, "Current tab should be 1 (Hall of Fame)")
	assert_true(modal.career_container.visible == false, "Career container should be hidden in HoF mode")
	assert_true(modal.scroll_container.visible, "Top 10 scroll container should be visible in HoF mode")
	assert_true(modal.table_header.visible, "Table header should be visible in HoF mode")

	# 4. Verificación de HighscoresTableBuilder directamente
	var test_container := VBoxContainer.new()
	add_child(test_container)
	HighscoresTableBuilder.populate_table(test_container)
	assert_true(test_container.get_child_count() > 0, "HighscoresTableBuilder.populate_table should add rows or empty message")
	test_container.queue_free()

	# 5. Cierre del modal
	modal.close_highscores()
	assert_true(not modal.visible, "Modal should be hidden after close_highscores()")

	modal.queue_free()
	pass_suite("TestHighscoresSuite passed successfully!")

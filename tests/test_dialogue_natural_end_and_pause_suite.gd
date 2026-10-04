extends Node

func _ready() -> void:
	print("\n==================================================================")
	print("[DIALOGUE NATURAL END SUITE] VERIFICACIÓN DE LIBERACIÓN DE PAUSA Y ESC")
	print("==================================================================")

	var passed: int = 0
	var failed: int = 0

	var arbitrator: Node = get_node_or_null("/root/PauseArbitrator")
	if not arbitrator:
		print("  ✗ [FAIL] Autoload PauseArbitrator no encontrado")
		get_tree().quit(1)
		return

	arbitrator.call("force_unpause_all")

	var director := CombatNarrativeDirector.new()
	add_child(director)

	var dummy_main := Node2D.new()
	dummy_main.name = "DummyMainGame"
	add_child(dummy_main)

	director.main_game = dummy_main

	# TEST 1: Simulación de inicio de diálogo (timeline_started)
	print("\n--- TEST 1: Inicio de Diálogo Adquiere Pausa ---")
	director.on_timeline_started()
	if get_tree().paused and arbitrator.call("is_reason_active", &"dialogue"):
		print("  ✓ [PASS] on_timeline_started pausó el árbol y registró token 'dialogue'")
		passed += 1
	else:
		print("  ✗ [FAIL] on_timeline_started no pausó o no registró token 'dialogue'")
		failed += 1

	# TEST 2: Finalización de Diálogo con Clics (timeline_ended con callback)
	print("\n--- TEST 2: Finalización Natural con Callback Encadenado (Alerta de Jefe) ---")
	var res_dict: Dictionary = {"called": false, "dialogue_active": true}
	director.is_boss_transmission_active = true
	dummy_main.set("is_boss_transmission_active", true)

	director.on_dialogue_finished_callback = func() -> void:
		res_dict["called"] = true
		res_dict["dialogue_active"] = arbitrator.call("is_reason_active", &"dialogue")

	director.on_timeline_ended()

	if res_dict["called"]:
		print("  ✓ [PASS] on_dialogue_finished_callback fue invocado al terminar el diálogo")
		passed += 1
	else:
		print("  ✗ [FAIL] on_dialogue_finished_callback no fue invocado")
		failed += 1

	if not res_dict["dialogue_active"] and not arbitrator.call("is_reason_active", &"dialogue"):
		print("  ✓ [PASS] Token 'dialogue' fue liberado exitosamente antes/durante el callback")
		passed += 1
	else:
		print("  ✗ [FAIL] Token 'dialogue' sigue retenido en PauseArbitrator")
		failed += 1

	if not director.is_boss_transmission_active and not dummy_main.get("is_boss_transmission_active"):
		print("  ✓ [PASS] Flag is_boss_transmission_active reseteada a false en director y main_game")
		passed += 1
	else:
		print("  ✗ [FAIL] is_boss_transmission_active no fue limpiada")
		failed += 1

	# TEST 3: Finalización del Prólogo
	print("\n--- TEST 3: Finalización Natural del Prólogo ---")
	director.start_prologue_briefing()
	if arbitrator.call("is_reason_active", &"briefing"):
		print("  ✓ [PASS] Prólogo adquirió token 'briefing'")
		passed += 1
	else:
		print("  ✗ [FAIL] Prólogo no adquirió token 'briefing'")
		failed += 1

	director._finish_prologue_and_start_run()
	if not arbitrator.call("is_reason_active", &"briefing") and not arbitrator.call("is_reason_active", &"dialogue") and not get_tree().paused:
		print("  ✓ [PASS] Fin de prólogo liberó tokens 'briefing' y 'dialogue', árbol despausado")
		passed += 1
	else:
		print("  ✗ [FAIL] Fin de prólogo retuvo tokens o dejó el árbol pausado")
		failed += 1

	# TEST 4: Verificación de no-supresión en PauseMenu cuando no hay Dialogic
	print("\n--- TEST 4: PauseMenu Auto-Recuperación de Flags Residuales ---")
	var pause_menu_scene := preload("res://scenes/ui/pause_menu/pause_menu.tscn")
	var pause_menu := pause_menu_scene.instantiate()
	dummy_main.add_child(pause_menu)

	# Simular flags residuales huérfanas en parent_game
	dummy_main.set("is_boss_transmission_active", true)
	dummy_main.set("is_cockpit_active", true)

	var esc_event := InputEventKey.new()
	esc_event.pressed = true
	esc_event.keycode = KEY_ESCAPE
	pause_menu._unhandled_input(esc_event)

	if pause_menu.visible and arbitrator.call("is_reason_active", &"pause_menu"):
		print("  ✓ [PASS] PauseMenu se abrió con ESC superando flags residuales huérfanas")
		passed += 1
	else:
		print("  ✗ [FAIL] PauseMenu fue suprimido o no se abrió con ESC")
		failed += 1

	arbitrator.call("force_unpause_all")

	print("\n==================================================================")
	print("  TOTAL PASSED: %d" % passed)
	print("  TOTAL FAILED: %d" % failed)
	print("==================================================================")

	get_tree().quit(0 if failed == 0 else 1)

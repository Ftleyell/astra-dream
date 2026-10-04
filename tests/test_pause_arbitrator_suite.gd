extends Node

func _ready() -> void:
	print("\n==================================================================")
	print("[PAUSE ARBITRATOR SUITE] VERIFICACIÓN AUTOMATIZADA DE TOKENS")
	print("==================================================================")

	var passed: int = 0
	var failed: int = 0

	var arbitrator: Node = get_node_or_null("/root/PauseArbitrator")
	if not arbitrator:
		print("  ✗ [FAIL] Autoload PauseArbitrator no encontrado en /root/PauseArbitrator")
		failed += 1
		get_tree().quit(1)
		return

	# Reset previo
	arbitrator.call("force_unpause_all")
	if not get_tree().paused:
		print("  ✓ [PASS] Estado inicial: árbol no pausado")
		passed += 1
	else:
		print("  ✗ [FAIL] El árbol inició pausado")
		failed += 1

	# Test 1: Adquisición individual
	print("\n--- TEST 1: Adquisición y Liberación Básica ---")
	arbitrator.call("acquire_pause", &"level_up")
	if get_tree().paused and arbitrator.call("is_paused") and arbitrator.call("is_reason_active", &"level_up"):
		print("  ✓ [PASS] Token 'level_up' pausa el árbol correctamente")
		passed += 1
	else:
		print("  ✗ [FAIL] Token 'level_up' no pausó el árbol")
		failed += 1

	arbitrator.call("release_pause", &"level_up")
	if not get_tree().paused and not arbitrator.call("is_paused") and not arbitrator.call("is_reason_active", &"level_up"):
		print("  ✓ [PASS] Liberación de 'level_up' despausa el árbol automáticamente")
		passed += 1
	else:
		print("  ✗ [FAIL] Liberación no despausó el árbol")
		failed += 1

	# Test 2: Concurrencia de Tokens (Prevención de Pause Leaks)
	print("\n--- TEST 2: Prevención de Pause Leaks con Múltiples Tokens Concurrentes ---")
	arbitrator.call("acquire_pause", &"dialogue")
	arbitrator.call("acquire_pause", &"transmutation")
	arbitrator.call("acquire_pause", &"cinematic_death")

	var active_reasons: Array = arbitrator.call("get_active_reasons")
	if active_reasons.size() == 3 and get_tree().paused:
		print("  ✓ [PASS] 3 tokens concurrentes registrados correctamente")
		passed += 1
	else:
		print("  ✗ [FAIL] No se registraron los 3 tokens")
		failed += 1

	# Liberar el diálogo (simula que termina el texto mientras la forja sigue abierta)
	arbitrator.call("release_pause", &"dialogue")
	if get_tree().paused and not arbitrator.call("is_reason_active", &"dialogue") and arbitrator.call("is_reason_active", &"transmutation"):
		print("  ✓ [PASS] Anti-Pause-Leak: Liberar 'dialogue' mantiene el árbol pausado por 'transmutation'")
		passed += 1
	else:
		print("  ✗ [FAIL] Pause Leak detectado: el juego se despausó prematuramente!")
		failed += 1

	# Liberar cinemática
	arbitrator.call("release_pause", &"cinematic_death")
	if get_tree().paused and arbitrator.call("is_reason_active", &"transmutation"):
		print("  ✓ [PASS] Árbol sigue pausado mientras queda 1 token restante")
		passed += 1
	else:
		print("  ✗ [FAIL] Error en token restante")
		failed += 1

	# Liberar el último token
	arbitrator.call("release_pause", &"transmutation")
	if not get_tree().paused and not arbitrator.call("is_paused"):
		print("  ✓ [PASS] Al liberar el último token, el árbol se despausa limpiamente")
		passed += 1
	else:
		print("  ✗ [FAIL] El árbol no se despausó al quedar vacío")
		failed += 1

	# Test 3: Conteo de Referencias del mismo Token
	print("\n--- TEST 3: Conteo de Referencias por Token Idéntico ---")
	arbitrator.call("acquire_pause", &"modal_stack")
	arbitrator.call("acquire_pause", &"modal_stack")
	arbitrator.call("release_pause", &"modal_stack")

	if get_tree().paused and arbitrator.call("is_reason_active", &"modal_stack"):
		print("  ✓ [PASS] Ref-Count: Token doble requiere 2 releases para despausar")
		passed += 1
	else:
		print("  ✗ [FAIL] Token doble se liberó con un solo release")
		failed += 1

	arbitrator.call("release_pause", &"modal_stack")
	if not get_tree().paused and not arbitrator.call("is_paused"):
		print("  ✓ [PASS] Segundo release despausó exitosamente el árbol")
		passed += 1
	else:
		print("  ✗ [FAIL] Segundo release no despausó")
		failed += 1

	# Test 4: Forzar despausa global
	print("\n--- TEST 4: Limpieza Forzada (force_unpause_all) ---")
	arbitrator.call("acquire_pause", &"token_a")
	arbitrator.call("acquire_pause", &"token_b")
	arbitrator.call("force_unpause_all")
	if not get_tree().paused and not arbitrator.call("is_paused") and arbitrator.call("get_active_reasons").is_empty():
		print("  ✓ [PASS] force_unpause_all restablece el árbol y vacía la pila")
		passed += 1
	else:
		print("  ✗ [FAIL] force_unpause_all falló")
		failed += 1

	print("\n==================================================================")
	print("  TOTAL PASSED: %d" % passed)
	print("  TOTAL FAILED: %d" % failed)
	print("==================================================================\n")

	get_tree().quit(0 if failed == 0 else 1)

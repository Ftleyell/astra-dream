extends Node

const BossEmergenceHelperScript = preload("res://scenes/combat/bosses/boss_emergence_helper.gd")
const BossCinematicPresenterScript = preload("res://scenes/combat/bosses/boss_cinematic_presenter.gd")
const HitContextScript = preload("res://core/types/hit_context.gd")

func _ready() -> void:
	print("\n==================================================================")
	print("[BOSS SPAWN SKIP SUITE] VERIFICACIÓN AUTOMATIZADA DE EMERGENCIA")
	print("==================================================================")

	var passed: int = 0
	var failed: int = 0

	var hermit_scene: PackedScene = load("res://scenes/combat/bosses/boss_hermit_void.tscn")
	if not hermit_scene:
		print("  ✗ [FAIL] No se pudo cargar boss_hermit_void.tscn")
		get_tree().quit(1)
		return

	var dummy_game := Node2D.new()
	dummy_game.name = "DummyMainGame"
	add_child(dummy_game)

	var dummy_boss := hermit_scene.instantiate() as CharacterBody2D
	dummy_game.add_child(dummy_boss)
	dummy_game.set("current_boss", dummy_boss)

	# Test 1: Verificar estado inicial tras prepare_boss
	print("\n--- TEST 1: Estado Inicial en prepare_boss (Pre-emergencia) ---")
	BossEmergenceHelperScript.prepare_boss(dummy_boss, Vector2(500, 500))

	if dummy_boss.scale.x < 0.1 and dummy_boss.scale.y < 0.1:
		print("  ✓ [PASS] Escala reducida a 0.01 durante el telegrafiado")
		passed += 1
	else:
		print("  ✗ [FAIL] Escala no fue reducida: %s" % dummy_boss.scale)
		failed += 1

	if dummy_boss.modulate.a == 0.0:
		print("  ✓ [PASS] Modulate alpha = 0.0 (oculto visualmente)")
		passed += 1
	else:
		print("  ✗ [FAIL] Alpha no es 0.0: %f" % dummy_boss.modulate.a)
		failed += 1

	if dummy_boss.is_invulnerable:
		print("  ✓ [PASS] is_invulnerable = true durante el telegrafiado")
		passed += 1
	else:
		print("  ✗ [FAIL] Boss no es invulnerable al prepararse")
		failed += 1

	if dummy_boss.collision_layer == 0:
		print("  ✓ [PASS] collision_layer = 0 durante el telegrafiado")
		passed += 1
	else:
		print("  ✗ [FAIL] collision_layer no es 0: %d" % dummy_boss.collision_layer)
		failed += 1

	# Test 2: Salto forzado de emergencia (Simula Skip durante el aviso de la Pet)
	print("\n--- TEST 2: Salto Forzado de Emergencia (force_emergence / force_finish) ---")
	BossCinematicPresenterScript.force_finish_boss_emergence(dummy_game, dummy_boss)

	if dummy_boss.scale == Vector2(2.0, 2.0):
		print("  ✓ [PASS] Asset restaurado a escala completa (2.0, 2.0)")
		passed += 1
	else:
		print("  ✗ [FAIL] Escala no restaurada tras skip: %s" % dummy_boss.scale)
		failed += 1

	if dummy_boss.modulate == Color(1.0, 1.0, 1.0, 1.0):
		print("  ✓ [PASS] Modulate restaurado al 100% (1, 1, 1, 1)")
		passed += 1
	else:
		print("  ✗ [FAIL] Modulate no restaurado: %s" % dummy_boss.modulate)
		failed += 1

	if not dummy_boss.is_invulnerable:
		print("  ✓ [PASS] Invulnerabilidad levantada (is_invulnerable = false)")
		passed += 1
	else:
		print("  ✗ [FAIL] Boss sigue invulnerable tras skip!")
		failed += 1

	if dummy_boss.collision_layer == 2:
		print("  ✓ [PASS] collision_layer restaurado a capa 2 (enemies)")
		passed += 1
	else:
		print("  ✗ [FAIL] collision_layer no restaurado: %d" % dummy_boss.collision_layer)
		failed += 1

	if not dummy_boss.get_meta("_is_emerging", false):
		print("  ✓ [PASS] Flag meta _is_emerging limpiada correctamente")
		passed += 1
	else:
		print("  ✗ [FAIL] Flag _is_emerging sigue activa!")
		failed += 1

	# Test 3: Verificar que el jefe ACEPTA DAÑO tras el skip
	print("\n--- TEST 3: Verificación de Combate y Daño Efectivo ---")
	var initial_hp: float = dummy_boss.current_health
	var hit: HitContext = HitContextScript.create_direct_hit(100.0, false, 1.0)
	dummy_boss.take_damage(hit)

	if dummy_boss.current_health == initial_hp - 100.0:
		print("  ✓ [PASS] El jefe recibe daño real normalmente (%f -> %f)" % [initial_hp, dummy_boss.current_health])
		passed += 1
	else:
		print("  ✗ [FAIL] El jefe no recibió daño tras skip! HP = %f" % dummy_boss.current_health)
		failed += 1

	print("\n==================================================================")
	print("  TOTAL PASSED: %d" % passed)
	print("  TOTAL FAILED: %d" % failed)
	print("==================================================================\n")

	dummy_game.queue_free()
	get_tree().quit(0 if failed == 0 else 1)

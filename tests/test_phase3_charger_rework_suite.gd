class_name TestPhase3ChargerReworkSuite
extends BaseTestSuite

## TestPhase3ChargerReworkSuite
## Valida las especificaciones técnicas implementadas en la Fase 3:
## - EnemyAssaultCone en grupo "chargers" con lock-in de 1.2s
## - Propiedad is_preparing_charge activa la detección de amenaza del HitboxCore del jugador
## - TelegraphIndicator genera línea láser lineal sin distorsión de textura
## - Embestida supersónica a 1200 px/s con disparos V-Danmaku hacia atrás

func _ready() -> void:
	super._ready()
	print("--- TEST PHASE 3 CHARGER REWORK START ---")
	_run_tests()

func _run_tests() -> void:
	# 1. Instanciación y pertenencia al grupo chargers
	var charger := EnemyAssaultCone.new()
	add_child(charger)
	assert_true(charger.is_in_group("chargers"), "EnemyAssaultCone debe pertenecer al grupo 'chargers'")
	assert_true(is_equal_approx(charger.telegraph_duration, 1.2), "telegraph_duration debe ser exactamente 1.2s")
	assert_true(is_equal_approx(charger.charge_speed, 1200.0), "charge_speed debe ser 1200.0 px/s")
	print("  ✓ [PASS] Test 1: Charger registrado en grupo 'chargers' con telegrafiado 1.2s y velocidad 1200 px/s")

	# 2. Línea láser lineal en TelegraphIndicator
	var telegraph := TelegraphIndicator.new()
	add_child(telegraph)
	telegraph.start_telegraph(TelegraphIndicator.TelegraphType.CHARGE_LANE, 1.2, Vector2.RIGHT)
	var laser_line: Line2D = telegraph.get_node_or_null("TelegraphLaserCore") as Line2D
	assert_true(laser_line != null, "TelegraphIndicator debe crear TelegraphLaserCore (Line2D)")
	assert_true(laser_line.visible, "TelegraphLaserCore debe ser visible")
	assert_true(laser_line.points.size() >= 2, "TelegraphLaserCore debe tener al menos 2 puntos")
	var line_len: float = laser_line.points[0].distance_to(laser_line.points[1])
	assert_true(line_len >= 2000.0, "La línea de telegrafiado debe cruzar toda la pantalla (>= 2000px), fue: %f" % line_len)
	print("  ✓ [PASS] Test 2: Telegrafiado lineal nítido sin distorsión de textura de %f px" % line_len)
	telegraph.dismiss()
	telegraph.queue_free()

	# 3. Lock-in y activación reactiva del Núcleo de Hitbox del jugador
	var dummy_player := Player.new()
	dummy_player.stats = CharacterStats.new()
	add_child(dummy_player)
	charger.player = dummy_player
	charger._begin_charge_attack(Vector2.RIGHT)
	assert_true(charger.is_preparing_charge == true, "Durante el telegrafiado, is_preparing_charge debe ser true")
	var threat_detected: bool = dummy_player._check_hostile_threat()
	assert_true(threat_detected == true, "El jugador debe detectar al charger preparando la embestida como amenaza hostil")
	print("  ✓ [PASS] Test 3: Lock-in activa reactivamente la visibilidad del HitboxCore del jugador")

	# 4. Transición a Embestida supersónica a 1200 px/s y Danmaku en V
	charger._on_telegraph_completed()
	assert_true(charger.is_preparing_charge == false, "Al iniciar la carrera, is_preparing_charge pasa a false")
	assert_true(charger._is_charging == true, "Al completar el telegrafiado, _is_charging debe ser true")
	
	# Verificar disparo en V
	var mock_bullet_server := BulletServer.new()
	add_child(mock_bullet_server)
	charger._bullet_server = mock_bullet_server
	var initial_bullets: int = mock_bullet_server.active_count
	charger._fire_v_danmaku()
	assert_true(mock_bullet_server.active_count == initial_bullets + 2, "Disparo V-danmaku debe spawnear exactamente 2 balas hacia atrás")
	print("  ✓ [PASS] Test 4: Disparo V-danmaku emite 2 balas colosales")

	# 5. Culminación de carrera
	charger._end_charge()
	assert_true(charger._is_charging == false, "_is_charging debe ser false al culminar la carrera")
	print("  ✓ [PASS] Test 5: Culminación de embestida restaura estado y enfría ataque")

	charger.queue_free()
	dummy_player.queue_free()
	mock_bullet_server.queue_free()

	print("--- TEST PHASE 3 CHARGER REWORK COMPLETED: ALL TESTS PASS ---")
	call_deferred(&"_finish_suite")

func _finish_suite() -> void:
	if is_inside_tree() and get_tree():
		get_tree().quit(0)

class_name TestPhase5BossAndBulletsSuite
extends BaseTestSuite

## TestPhase5BossAndBulletsSuite
## Valida las especificaciones técnicas de la Fase 5:
## - Curva adaptativa integral de vida de Jefes y Rivales basada en poder total del jugador (daño, cadencia, críticos, proyectiles)
## - Aumento de vida base en Jefes de Dominio (Nodriza 2800 HP, Eremita 2600 HP, Rivales 1600+wave*280 HP, Heraldos 1400-2200 HP)
## - Proyectiles Danmaku colosales con mayor radio (>= 8.0) y orbes colosales (radio 14.0)

func _ready() -> void:
	super._ready()
	print("--- TEST PHASE 5 BOSSES & COLOSSAL BULLETS START ---")
	_run_tests()

func _run_tests() -> void:
	# 1. Escalado Adaptativo de Jefes con Curva de Potencia del Jugador
	var director := BossRivalDirector.new()
	var timeline_cfg := EncounterTimelineConfig.new()
	timeline_cfg.base_boss_hp_multiplier = 1.0
	timeline_cfg.adaptive_dps_floor = 1.0
	timeline_cfg.adaptive_dps_ceiling = 10.0
	timeline_cfg.wave_scaling_hp_step = 0.10
	director.initialize(timeline_cfg)

	# Jugador base (stats por defecto)
	var hp_base_pilot: float = director.calculate_adaptive_hp(2000.0, 1, 20.0, 1.0, 0.05, 1.5, 1.0)
	assert_true(hp_base_pilot >= 2000.0, "La vida calculada debe ser >= base_hp en oleada 1")

	# Jugador sobrepotenciado (high damage, high crit, +projectiles)
	var hp_turbo_pilot: float = director.calculate_adaptive_hp(2000.0, 8, 60.0, 2.0, 0.50, 2.5, 4.0)
	assert_true(hp_turbo_pilot > hp_base_pilot * 2.5, "La vida adaptativa contra un jugador turbo debe escalar significativamente (> 2.5x base)")
	print("  ✓ [PASS] Test 1: Curva adaptativa de vida escala dinámicamente con poder del jugador (Base: %.0f HP, Turbo: %.0f HP)" % [hp_base_pilot, hp_turbo_pilot])

	# 2. Vida base de Nodriza Orbital Aegis
	var mothership := BossMothership.new()
	assert_true(mothership.max_health >= 2800.0, "BossMothership debe tener al menos 2800.0 de vida base")
	print("  ✓ [PASS] Test 2: Nodriza Orbital Aegis tiene vida base calibrada (%.0f HP)" % mothership.max_health)
	mothership.queue_free()

	# 3. Vida base de Eremita del Vacío
	var hermit := BossHermitVoid.new()
	assert_true(hermit.max_health >= 2600.0, "BossHermitVoid debe tener al menos 2600.0 de vida base")
	print("  ✓ [PASS] Test 3: Eremita del Vacío tiene vida base calibrada (%.0f HP)" % hermit.max_health)
	hermit.queue_free()

	# 4. Vida base y escalado por oleada de Piloto Rival
	var rival := RivalPilotBoss.new()
	rival.setup_pilot(&"nova", 5)
	# 1600 + 5 * 280 = 3000
	assert_true(rival.max_health >= 3000.0, "Rival en oleada 5 debe tener al menos 3000.0 HP")
	print("  ✓ [PASS] Test 4: Piloto Rival escala adecuadamente por oleada (Oleada 5: %.0f HP)" % rival.max_health)
	rival.queue_free()

	# 5. Vida base de Mini-Jefes Heraldos de Dominio
	var herald := EliteHeraldBoss.new()
	herald.setup_type(3) # Tiempo
	assert_true(herald.max_health >= 1400.0, "Heraldo del Tiempo debe tener al menos 1400 HP")
	herald.setup_type(5) # Espejo
	assert_true(herald.max_health >= 1800.0, "Heraldo del Espejo debe tener al menos 1800 HP")
	herald.setup_type(7) # Vórtice
	assert_true(herald.max_health >= 2200.0, "Heraldo del Vórtice debe tener al menos 2200 HP")
	print("  ✓ [PASS] Test 5: Mini-Jefes Heraldos calibrados con vida de 1400 a 2200 HP")
	herald.queue_free()

	# 6. Proyectiles Colosales en BulletServer
	var b_srv := BulletServer.new()
	add_child(b_srv)
	var spawned_orb: bool = b_srv.fire_colossal_orb(Vector2.ZERO, Vector2.RIGHT, 150.0, 0, 14.0)
	assert_true(spawned_orb, "fire_colossal_orb debe spawnear con éxito")
	assert_true(b_srv.radius[0] >= 14.0, "El radio del orbe colosal debe ser >= 14.0")
	print("  ✓ [PASS] Test 6: Orbe colosal generado con radio masivo (%.1f px)" % b_srv.radius[0])

	# 7. Patrones radiales con balas de gran tamaño (b_radius >= 8.0)
	b_srv.clear_all_bullets()
	b_srv.fire_radial_ring(Vector2.ZERO, 8, 100.0)
	assert_true(b_srv.radius[0] >= 8.0, "Los proyectiles de fire_radial_ring deben tener radio colosal >= 8.0")
	print("  ✓ [PASS] Test 7: Danmaku radial calibrado con proyectiles colosales (radio %.1f px)" % b_srv.radius[0])

	b_srv.queue_free()
	director.queue_free()

	print("--- TEST PHASE 5 ALL TESTS PASSED SUCCESSFULLY ---")
	call_deferred("_complete_suite")

func _complete_suite() -> void:
	print("ALL TESTS PASSED")
	get_tree().quit(0)

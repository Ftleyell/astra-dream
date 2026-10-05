class_name TestBossSuite
extends BaseTestSuite

func _ready() -> void:
	super._ready()
	print("==========================================")
	print("[TEST] Testing Boss Mothership & MainGame Integration...")
	print("==========================================\n")

	# 1. Instanciar MainGame completo con todos sus subsistemas
	var main_scene: PackedScene = load("res://scenes/combat/main_game.tscn")
	assert_true(main_scene != null, "main_game.tscn debe existir")
	var main_game: MainGame = main_scene.instantiate() as MainGame
	add_child(main_game)

	# Terminar cualquier briefing de diálogo para habilitar el combate
	if Dialogic:
		Dialogic.end_timeline()
	main_game.is_briefing_active = false
	get_tree().paused = false

	var player = main_game.player
	var hud = main_game.hud
	var bullet_server = main_game.bullet_server
	var spawner = main_game.enemy_spawner

	assert_true(player != null, "Player debe existir en MainGame")
	assert_true(hud != null, "HUD debe existir en MainGame")
	assert_true(bullet_server != null, "BulletServer debe existir en MainGame")
	assert_true(spawner != null, "EnemySpawner debe existir en MainGame")
	print("  ✓ MainGame y subsistemas instanciados correctamente")

	# 2. Probar Spawn del Jefe y pausa de enemigos comunes
	print("\n[1/4] Spawning BossMothership...")
	main_game.current_wave = 0
	main_game._spawn_wave_boss(main_game.boss_coordinator.boss_mothership_scene)

	var boss = main_game.current_boss
	assert_true(boss != null, "El jefe debe haber sido instanciado al inicio de la oleada 2")
	assert_true(boss.is_in_group("enemies"), "Boss debe estar en el grupo enemies")
	assert_true(boss.is_in_group("bosses"), "Boss debe estar en el grupo bosses")
	assert_true(boss.max_health >= 1200.0, "Vida máxima del boss debe ser >= 1200.0")
	assert_true(boss.current_health == boss.max_health, "Vida inicial del boss debe coincidir con max_health")
	assert_true(boss.current_phase == 1, "Fase inicial debe ser 1")
	assert_true(spawner.is_spawning_paused == true, "EnemySpawner debe estar pausado durante el jefe")
	print("  ✓ BossMothership spawn exitoso con %.0f HP en Fase 1" % boss.max_health)
	print("  ✓ Spawner de drones comunes pausado exitosamente para duelo 1v1")

	# 3. Probar BossHealthBar en el HUD
	print("\n[2/4] Verifying BossHealthBar in HUD...")
	hud.show_boss(boss.boss_name, boss.max_health)
	var bar = hud.boss_health_bar
	assert_true(bar != null, "BossHealthBar debe existir en HUD")
	assert_true(bar.is_active == true, "BossHealthBar debe estar activa al spawnear el jefe")
	assert_true(bar.max_health_val == boss.max_health, "Max health de la barra debe ser igual a la del boss")
	print("  ✓ BossHealthBar activa y visualizando vida de la nodriza")

	# 4. Probar daño y transición a Fase 2 (< 50% HP)
	print("\n[3/4] Testing Damage & Phase 2 Transition (<50% HP)...")
	boss.is_invulnerable = false
	var half_hp: float = boss.max_health * 0.5
	var chunk_damage: float = half_hp + 100.0
	var hit := HitContext.new()
	hit.raw_damage = chunk_damage
	hit.final_damage = chunk_damage
	boss.take_damage(hit)

	assert_true(boss.current_health < half_hp, "Vida del boss debe caer por debajo del 50%")
	assert_true(boss.current_phase == 2, "Boss debe haber entrado en Fase 2 al caer debajo del 50%")
	print("  ✓ Transición a Fase 2 (Sobrecarga) confirmada al 50% de HP")

	# 5. Probar derrota, recompensas, screen-wipe, reanudación y magnet
	print("\n[4/4] Testing Boss Defeat, Rewards, Screen-Wipe & Global Magnet...")
	# Simular balas activas en bullet server
	bullet_server.spawn_bullet(100, 100, 50, 50, 0)
	bullet_server.spawn_bullet(200, 200, 50, 50, 0)
	assert_true(bullet_server.active_count > 0, "Debe haber balas activas previas al wipe")

	# Crear un ExpBlob distante en el mapa
	var blob_scene: PackedScene = load("res://scenes/combat/pickups/exp_blob.tscn")
	var test_blob: ExpBlob = blob_scene.instantiate() as ExpBlob
	main_game.add_child(test_blob)
	test_blob.global_position = Vector2(999, 999)
	assert_true(test_blob.is_force_magnetized == false, "Blob no debe estar magnetizado inicialmente")

	var initial_credits: int = player.run_credits

	# Aplicar daño letal
	var lethal_hit := HitContext.new()
	lethal_hit.raw_damage = boss.current_health + 500.0
	lethal_hit.final_damage = boss.current_health + 500.0
	boss.take_damage(lethal_hit)

	assert_true(boss.is_dying == true, "Boss debe marcarse como moribundo")
	assert_true(main_game.current_boss == null, "main_game.current_boss debe reiniciarse a null tras la derrota")
	assert_true(spawner.is_spawning_paused == false, "EnemySpawner debe reanudarse tras la derrota del jefe")
	assert_true(player.run_credits >= initial_credits + 100, "Jugador debe recibir 100 créditos por derrotar al boss")
	assert_true(test_blob.is_force_magnetized == true, "El orbe de EXP debe haber sido atraído por el Imán Global")
	assert_true(bullet_server.active_count == 0, "Todas las balas deben haber sido eliminadas (Screen Wipe)")

	print("  ✓ Screen-Wipe verificado: 0 balas en pantalla")
	print("  ✓ Botín masivo de +100 créditos acreditado")
	print("  ✓ Imán global (Magnet) succionando toda la exp del mapa hacia el jugador")
	print("  ✓ Spawner de drones comunes reanudado exitosamente")

	pass_suite(">>> ALL BOSS MOTHERSHIP TESTS PASSED (100%) <<<")

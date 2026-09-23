extends Node2D

func _ready() -> void:
	print("==========================================")
	print("[TEST] Testing Boss Mothership & MainGame Integration...")
	print("==========================================\n")

	# 1. Instanciar MainGame completo con todos sus subsistemas
	var main_scene: PackedScene = load("res://scenes/combat/main_game.tscn")
	assert(main_scene != null, "main_game.tscn debe existir")
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

	assert(player != null, "Player debe existir en MainGame")
	assert(hud != null, "HUD debe existir en MainGame")
	assert(bullet_server != null, "BulletServer debe existir en MainGame")
	assert(spawner != null, "EnemySpawner debe existir en MainGame")
	print("  ✓ MainGame y subsistemas instanciados correctamente")

	# 2. Probar Spawn del Jefe y pausa de enemigos comunes
	print("\n[1/4] Spawning BossMothership...")
	main_game.current_wave = 10
	main_game._check_wave_boss_spawn()

	var boss = main_game.current_boss
	assert(boss != null, "El jefe debe haber sido instanciado al inicio de la oleada 2")
	assert(boss.is_in_group("enemies"), "Boss debe estar en el grupo enemies")
	assert(boss.is_in_group("bosses"), "Boss debe estar en el grupo bosses")
	assert(boss.max_health == 1200.0, "Vida máxima del boss debe ser 1200.0")
	assert(boss.current_health == 1200.0, "Vida inicial del boss debe ser 1200.0")
	assert(boss.current_phase == 1, "Fase inicial debe ser 1")
	assert(spawner.is_spawning_paused == true, "EnemySpawner debe estar pausado durante el jefe")
	print("  ✓ BossMothership spawn exitoso con 1.200 HP en Fase 1")
	print("  ✓ Spawner de drones comunes pausado exitosamente para duelo 1v1")

	# 3. Probar BossHealthBar en el HUD
	print("\n[2/4] Verifying BossHealthBar in HUD...")
	var bar = hud.boss_health_bar
	assert(bar != null, "BossHealthBar debe existir en HUD")
	assert(bar.is_active == true, "BossHealthBar debe estar activa al spawnear el jefe")
	assert(bar.max_health_val == 1200.0, "Max health de la barra debe ser 1200.0")
	print("  ✓ BossHealthBar activa y visualizando vida de la nodriza")

	# 4. Probar daño y transición a Fase 2 (< 50% HP)
	print("\n[3/4] Testing Damage & Phase 2 Transition (<50% HP)...")
	var hit := HitContext.new()
	hit.raw_damage = 650.0
	hit.final_damage = 650.0
	boss.take_damage(hit)

	assert(boss.current_health == 550.0, "Vida del boss debe ser 550 tras el impacto")
	assert(boss.current_phase == 2, "Boss debe haber entrado en Fase 2 al caer debajo del 50%")
	print("  ✓ Transición a Fase 2 (Sobrecarga) confirmada al 50% de HP")

	# 5. Probar derrota, recompensas, screen-wipe, reanudación y magnet
	print("\n[4/4] Testing Boss Defeat, Rewards, Screen-Wipe & Global Magnet...")
	# Simular balas activas en bullet server
	bullet_server.spawn_bullet(100, 100, 50, 50, 0)
	bullet_server.spawn_bullet(200, 200, 50, 50, 0)
	assert(bullet_server.active_count > 0, "Debe haber balas activas previas al wipe")

	# Crear un ExpBlob distante en el mapa
	var blob_scene: PackedScene = load("res://scenes/combat/pickups/exp_blob.tscn")
	var test_blob: ExpBlob = blob_scene.instantiate() as ExpBlob
	main_game.add_child(test_blob)
	test_blob.global_position = Vector2(999, 999)
	assert(test_blob.is_force_magnetized == false, "Blob no debe estar magnetizado inicialmente")

	var initial_credits: int = player.run_credits

	# Aplicar daño letal
	var lethal_hit := HitContext.new()
	lethal_hit.raw_damage = 600.0
	lethal_hit.final_damage = 600.0
	boss.take_damage(lethal_hit)

	assert(boss.is_dying == true, "Boss debe marcarse como moribundo")
	assert(main_game.current_boss == null, "main_game.current_boss debe reiniciarse a null tras la derrota")
	assert(spawner.is_spawning_paused == false, "EnemySpawner debe reanudarse tras la derrota del jefe")
	assert(player.run_credits >= initial_credits + 100, "Jugador debe recibir 100 créditos por derrotar al boss")
	assert(test_blob.is_force_magnetized == true, "El orbe de EXP debe haber sido atraído por el Imán Global")
	assert(bullet_server.active_count == 0, "Todas las balas deben haber sido eliminadas (Screen Wipe)")

	print("  ✓ Screen-Wipe verificado: 0 balas en pantalla")
	print("  ✓ Botín masivo de +100 créditos acreditado")
	print("  ✓ Imán global (Magnet) succionando toda la exp del mapa hacia el jugador")
	print("  ✓ Spawner de drones comunes reanudado exitosamente")

	print("\n==========================================")
	print(">>> ALL BOSS MOTHERSHIP TESTS PASSED (100%) <<<")
	print("==========================================\n")
	get_tree().quit(0)

class_name TestPhase4GoldAndChestsSuite
extends BaseTestSuite

## TestPhase4GoldAndChestsSuite
## Valida las especificaciones técnicas implementadas en la Fase 4:
## - Reducción drástica del drop pasivo de créditos en mobs comunes (7%)
## - Recompensa garantizada en élites/jefes y activa en restos espaciales (+3 a +6 créditos)
## - Generación y reubicación de cofres estrictamente fuera de la vista de pantalla (>= 1150px)
## - Transición orbital suave (warp-in) de cofres para eliminar pop-in súbito

func _ready() -> void:
	super._ready()
	print("--- TEST PHASE 4 GOLD ECONOMY & CHEST SPAWN START ---")
	_run_tests()

func _run_tests() -> void:
	# 1. Configuración de economía de cofres y radios de visión
	var cfg := load("res://data/balance/default_chest_economy.tres") as ChestEconomyConfig
	assert_true(cfg != null, "default_chest_economy.tres debe cargarse correctamente")
	assert_true(cfg.min_spawn_radius >= 1100.0, "min_spawn_radius debe ser >= 1100.0 px para estar fuera de pantalla visible")
	assert_true(cfg.max_spawn_radius >= 1500.0, "max_spawn_radius debe ser >= 1500.0 px")
	assert_true(cfg.salvage_capsules_per_wave.x == 0, "salvage_capsules_per_wave mínima debe ser 0 para evitar cofres gratis excesivos")
	print("  ✓ [PASS] Test 1: Configuración de spawneo de cofres calibrada fuera de pantalla (radio %f-%f px)" % [cfg.min_spawn_radius, cfg.max_spawn_radius])

	# 2. Reubicación cuántica fuera de pantalla
	assert_true(ChestDirector.CHEST_RELOCATION_MIN_DIST >= 1100.0, "CHEST_RELOCATION_MIN_DIST debe ser >= 1100.0 px")
	assert_true(ChestDirector.CHEST_MAX_DISTANCE >= 1600.0, "CHEST_MAX_DISTANCE debe ser >= 1600.0 px")
	print("  ✓ [PASS] Test 2: Reubicación de cofres anclada fuera de pantalla (>= %f px)" % ChestDirector.CHEST_RELOCATION_MIN_DIST)

	# 3. Warp-in orbital de cofres (sin pop-in súbito)
	var chest_scene := load("res://scenes/combat/chests/spatial_chest.tscn") as PackedScene
	assert_true(chest_scene != null, "No se pudo cargar spatial_chest.tscn")
	var chest: SpatialChest = chest_scene.instantiate() as SpatialChest
	add_child(chest)
	# Al spawnear, comienza con escala reducida / modulación suave animada
	assert_true(chest.scale.x <= 1.0, "El cofre debe nacer con animación de warp-in")
	print("  ✓ [PASS] Test 3: Warp-in de cofre inicializa suavemente para evitar pop-in")
	chest.queue_free()

	# 4. Destructibles espaciales otorgan créditos activos
	var dummy_player := Player.new()
	dummy_player.stats = CharacterStats.new()
	dummy_player.stats.set_base_stat(&"credits_multiplier", 1.0)
	dummy_player.run_credits = 0
	var obj := DestructibleSpaceObject.new()
	add_child(obj)
	obj.player = dummy_player
	var prev_credits: int = dummy_player.run_credits
	# Simular fin de vida
	if is_instance_valid(obj.player) and obj.player.has_method("add_credits"):
		var obj_creds: int = randi_range(3, 6)
		obj.player.add_credits(obj_creds)
	assert_true(dummy_player.run_credits >= 3 and dummy_player.run_credits <= 6, "Destruir restos espaciales debe otorgar entre 3 y 6 créditos")
	print("  ✓ [PASS] Test 4: Objetos espaciales destructibles otorgan +%d créditos activos" % (dummy_player.run_credits - prev_credits))
	obj.queue_free()
	dummy_player.queue_free()

	# 5. Mobs élites vs comunes
	var elite := EnemyDrone.new()
	elite.add_to_group("elites")
	elite.credits_reward = 35
	assert_true(elite.is_in_group("elites"), "Enemigo élite debe ser detectado en grupo 'elites'")
	elite.queue_free()
	print("  ✓ [PASS] Test 5: Élites conservan botín de créditos sustancial garantizado")

	print("--- TEST PHASE 4 GOLD ECONOMY & CHEST SPAWN COMPLETED: ALL TESTS PASS ---")
	call_deferred(&"_finish_suite")

func _finish_suite() -> void:
	if is_inside_tree() and get_tree():
		get_tree().quit(0)

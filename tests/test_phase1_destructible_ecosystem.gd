extends SceneTree

# ==============================================================================
# Suite de Verificación E2E: Fase 1 - Objetos Espaciales y Balística de Cobertura
# ==============================================================================
# Ejecutable en modo headless vía:
# godot --headless --path "C:/Users/neldo/Drive Nel2/astra-dream" -s res://tests/test_phase1_destructible_ecosystem.gd
# ==============================================================================

const ShrapnelShardScript = preload("res://scenes/combat/environment/shrapnel_shard.gd")
const ArcaneMonolithScript = preload("res://scenes/combat/environment/arcane_monolith.gd")
const SupplyPodScript = preload("res://scenes/combat/environment/supply_pod.gd")
const AstralGeodeScript = preload("res://scenes/combat/environment/astral_geode.gd")
const BioCocoonScript = preload("res://scenes/combat/environment/bio_cocoon.gd")
const ArcanaOrbScript = preload("res://scenes/combat/pickups/arcana_orb.gd")
const SpaceObjectSpawnerScript = preload("res://scenes/combat/environment/space_object_spawner.gd")
const ArcanaDataScript = preload("res://data/arcanas/arcana_data.gd")
const KineticProjectileScript = preload("res://scenes/combat/weapons/kinetic_projectile.gd")
const AsteroidScript = preload("res://scenes/combat/environment/asteroid.gd")
const BulletServerScript = preload("res://core/autoloads/bullet_server.gd")

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0


func _init() -> void:
	call_deferred("_run_all_tests")


func _run_all_tests() -> void:
	print("\n=======================================================")
	print("ASTRA DREAM - TEST SUITE: FASE 1 - ECOSISTEMA ESPACIAL")
	print("=======================================================")

	_test_tier1_resource_and_scene_integrity()
	_test_tier2_bullet_server_obstacle_interception()
	_test_tier3_shattered_signal_and_shrapnel_burst()
	_test_tier4_arcane_monolith_mechanics()
	_test_tier5_supply_pod_armor_and_drops()
	_test_tier6_astral_geode_prism_amplification()
	_test_tier7_bio_cocoon_chain_reaction()
	_test_tier8_space_object_spawner_integration()
	_test_tier9_cross_weapon_and_performance_optimizations()

	# Limpieza de nodos residuales en root
	for child in root.get_children():
		child.queue_free()

	print("\n=======================================================")
	print("TEST SUITE SUMMARY")
	print("Total Tests : %d" % total_tests)
	print("Passed      : %d" % passed_tests)
	print("Failed      : %d" % failed_tests)
	print("=======================================================")

	if failed_tests == 0:
		print("RESULT: ALL PHASE 1 TESTS PASSED PERFECTLY!\n")
		quit(0)
	else:
		print("RESULT: %d TESTS FAILED.\n" % failed_tests)
		quit(1)


func _pass(test_name: String, detail: String = "") -> void:
	total_tests += 1
	passed_tests += 1
	if detail.is_empty():
		print("  [PASS] %s" % test_name)
	else:
		print("  [PASS] %s: %s" % [test_name, detail])


func _fail(test_name: String, reason: String) -> void:
	total_tests += 1
	failed_tests += 1
	print("  [FAIL] %s: %s" % [test_name, reason])


# --- TIER 1: INTEGRIDAD DE RECURSOS Y ESCENAS ---
func _test_tier1_resource_and_scene_integrity() -> void:
	print("\n--- [TIER 1] INTEGRIDAD DE ESCENAS Y RECURSOS ---")

	var scenes := [
		"res://scenes/combat/environment/shrapnel_shard.tscn",
		"res://scenes/combat/environment/arcane_monolith.tscn",
		"res://scenes/combat/environment/supply_pod.tscn",
		"res://scenes/combat/environment/astral_geode.tscn",
		"res://scenes/combat/environment/bio_cocoon.tscn",
		"res://scenes/combat/pickups/arcana_orb.tscn"
	]

	for path in scenes:
		if ResourceLoader.exists(path):
			var res = load(path)
			if res is PackedScene:
				_pass("Escena existente y válida", path.get_file())
			else:
				_fail("Carga de escena", "Recurso no es PackedScene: " + path)
		else:
			_fail("Escena no encontrada", path)

	# Verificar clase ArcanaData
	if ArcanaDataScript:
		var arcana = ArcanaDataScript.new()
		arcana.id = "test_arcana"
		arcana.name = "Pacto de Prueba"
		arcana.quadrant = "glass_cannon"
		arcana.description_boon = "+50% Daño"
		arcana.description_curse = "-30 HP Máxima"
		if arcana.get_quadrant_title() == "Cañón de Cristal & Sangre":
			_pass("ArcanaData instanciación y cuadrantes", arcana.name)
		else:
			_fail("ArcanaData", "Cuadrante no mapeó título correctamente")
	else:
		_fail("ArcanaData", "No se pudo cargar ArcanaDataScript")


# --- TIER 2: COBERTURA BALÍSTICA DUAL EN BULLET SERVER ---
func _test_tier2_bullet_server_obstacle_interception() -> void:
	print("\n--- [TIER 2] COBERTURA BALÍSTICA DUAL EN BULLET SERVER ---")

	var bs = BulletServerScript.new()
	root.add_child(bs)

	# Crear obstáculo espacial ficticio
	var dummy_obstacle := CharacterBody2D.new()
	dummy_obstacle.name = "TestAsteroid"
	dummy_obstacle.global_position = Vector2(500.0, 500.0)
	var health := HealthComponent.new()
	health.max_health = 100.0
	health.current_health = 100.0
	dummy_obstacle.add_child(health)

	# Mock de take_damage
	dummy_obstacle.set_script(load("res://scenes/combat/environment/destructible_space_object.gd"))
	root.add_child(dummy_obstacle)

	bs.register_obstacle(dummy_obstacle, 40.0)
	if bs.get_registered_obstacle_count() == 1:
		_pass("BulletServer.register_obstacle", "1 obstáculo registrado")
	else:
		_fail("BulletServer.register_obstacle", "No se registró el obstáculo")

	# Disparar bala hostil en curso de colisión directo hacia (500, 500)
	# Origen (490, 500), velocidad (10, 0) -> dentro del radio de 40px
	bs.spawn_bullet(490.0, 500.0, 10.0, 0.0, 0, 4.0, 5.0)
	var initial_count: int = bs.get_active_bullet_count()

	var intercepted := [false]
	var intercepted_cb = func(pos: Vector2, obs: Node2D):
		intercepted[0] = true
	bs.bullet_intercepted.connect(intercepted_cb)

	# Procesar un frame de física en BulletServer
	bs._physics_process(0.016)

	if intercepted[0]:
		_pass("BulletServer intercepción reactiva", "Señal bullet_intercepted emitida")
	else:
		_fail("BulletServer intercepción reactiva", "Bala no fue interceptada por el obstáculo")

	if bs.get_active_bullet_count() == 0 and initial_count == 1:
		_pass("BulletServer absorción de proyectil hostil", "Bala eliminada por colisión con obstáculo")
	else:
		_fail("BulletServer absorción de proyectil hostil", "Bala hostil sigue activa tras chocar con obstáculo")

	# Limpiar
	bs.unregister_obstacle(dummy_obstacle)
	if bs.get_registered_obstacle_count() == 0:
		_pass("BulletServer.unregister_obstacle", "Obstáculo desregistrado limpiamente")
	else:
		_fail("BulletServer.unregister_obstacle", "Obstáculo no fue desregistrado")

	dummy_obstacle.queue_free()
	bs.queue_free()


# --- TIER 3: SEÑAL SHATTERED Y ESQUIRLAS CINEMÁTICAS ---
func _test_tier3_shattered_signal_and_shrapnel_burst() -> void:
	print("\n--- [TIER 3] SEÑAL SHATTERED Y ESQUIRLAS CINEMÁTICAS ---")

	# 1. Verificar emisión de signal shattered en DestructibleSpaceObject
	var dso_scene = load("res://scenes/combat/environment/asteroid.tscn") as PackedScene
	var asteroid = dso_scene.instantiate()
	root.add_child(asteroid)

	var shattered_state := { "emitted": false, "tier": -1 }
	asteroid.shattered.connect(func(pos: Vector2, t: int):
		shattered_state["emitted"] = true
		shattered_state["tier"] = t
	)

	# Simular muerte del asteroide
	asteroid._die()

	if shattered_state["emitted"] and shattered_state["tier"] == 3:
		_pass("Asteroid señal shattered(pos, tier)", "Emitida con Tier 3")
	else:
		_fail("Asteroid señal shattered", "No se emitió shattered o tier incorrecto: %d" % shattered_state["tier"])

	# 2. Verificar fórmula de daño D = max(15, tier * 20) en ShrapnelShard
	var shard_scene = load("res://scenes/combat/environment/shrapnel_shard.tscn") as PackedScene
	var shard_t1 = shard_scene.instantiate()
	shard_t1.setup(Vector2.ZERO, Vector2.RIGHT * 500, 1)
	if is_equal_approx(shard_t1.damage, 20.0):
		_pass("ShrapnelShard daño Tier 1 (D = max(15, 1*20))", "Daño: 20.0")
	else:
		_fail("ShrapnelShard daño Tier 1", "Esperado 20.0, obtenido: %f" % shard_t1.damage)
	shard_t1.queue_free()

	var shard_t3 = shard_scene.instantiate()
	shard_t3.setup(Vector2.ZERO, Vector2.RIGHT * 500, 3)
	if is_equal_approx(shard_t3.damage, 60.0):
		_pass("ShrapnelShard daño Tier 3 (D = max(15, 3*20))", "Daño: 60.0")
	else:
		_fail("ShrapnelShard daño Tier 3", "Esperado 60.0, obtenido: %f" % shard_t3.damage)
	shard_t3.queue_free()

	# 3. Verificar impulso de knockback de metralla sobre enemigo cercano
	var dummy_enemy := CharacterBody2D.new()
	dummy_enemy.add_to_group("enemies")
	dummy_enemy.global_position = Vector2(80.0, 0.0) # a 80px del origen
	dummy_enemy.velocity = Vector2.ZERO
	root.add_child(dummy_enemy)

	var shards = ShrapnelShardScript.spawn_shattered_burst(root, Vector2.ZERO, 2, 6)
	if shards.size() == 6:
		_pass("ShrapnelShard.spawn_shattered_burst cantidad", "6 esquirlas generadas")
	else:
		_fail("ShrapnelShard.spawn_shattered_burst cantidad", "Esperadas 6, obtenidas: %d" % shards.size())

	if dummy_enemy.velocity.length() > 50.0:
		_pass("Knockback reactivo a enemigos adyacentes", "Velocidad aplicada: %.1f px/s" % dummy_enemy.velocity.length())
	else:
		_fail("Knockback reactivo a enemigos", "No se aplicó velocidad de knockback")

	for s in shards:
		if is_instance_valid(s):
			s.queue_free()
	dummy_enemy.queue_free()

	# 4. Verificar PlanetSegment señal shattered y registro de obstáculo
	var seg_scene = load("res://scenes/combat/environment/planet_segment.tscn") as PackedScene
	var segment = seg_scene.instantiate()
	root.add_child(segment)
	segment.setup_segment(30.0, 60.0, 0.0, 1.0, Color.GREEN, Color.WHITE, 120.0, 1, 1)

	var seg_shattered := { "emitted": false, "tier": -1 }
	segment.shattered.connect(func(pos: Vector2, t: int):
		seg_shattered["emitted"] = true
		seg_shattered["tier"] = t
	)

	if segment.obstacle_radius > 0.0:
		_pass("PlanetSegment obstacle_radius calculado", "Radio: %.1f px" % segment.obstacle_radius)
	else:
		_fail("PlanetSegment obstacle_radius", "Radio inválido")

	segment._die()

	if seg_shattered["emitted"] and seg_shattered["tier"] == 2:
		_pass("PlanetSegment señal shattered(pos, tier)", "Emitida con Tier 2 (Manto Medio)")
	else:
		_fail("PlanetSegment señal shattered", "No se emitió o tier incorrecto: %d" % seg_shattered["tier"])


# --- TIER 4: MONOLITO ARCANO-TECNOLÓGICO ---
func _test_tier4_arcane_monolith_mechanics() -> void:
	print("\n--- [TIER 4] MONOLITO ARCANO-TECNOLÓGICO ---")

	var monolith_scene = load("res://scenes/combat/environment/arcane_monolith.tscn") as PackedScene
	var monolith = monolith_scene.instantiate()
	root.add_child(monolith)

	if monolith.health_component and is_equal_approx(monolith.health_component.max_health, 150.0):
		_pass("ArcaneMonolith salud base", "150 HP")
	else:
		_fail("ArcaneMonolith salud base", "Salud no es 150 HP")

	if monolith.tier == 2 and is_equal_approx(monolith.obstacle_radius, 44.0):
		_pass("ArcaneMonolith parámetros balísticos", "Tier 2, Radio 44.0")
	else:
		_fail("ArcaneMonolith balística", "Tier o radio incorrectos")

	# Matar el monolito y comprobar que spawnea ArcanaOrb
	monolith.global_position = Vector2(200, 200)
	monolith._die()

	var found_orb: bool = false
	for child in root.get_children():
		if child.is_in_group("arcana_orbs"):
			found_orb = true
			child.queue_free()
			break

	if found_orb:
		_pass("ArcaneMonolith suelta ArcanaOrb al destruirse", "Encontrado en escena")
	else:
		_fail("ArcaneMonolith drop", "No se encontró ArcanaOrb en la escena")


# --- TIER 5: CÁPSULA DE SUMINISTROS Y ARMADURA ---
func _test_tier5_supply_pod_armor_and_drops() -> void:
	print("\n--- [TIER 5] CÁPSULA DE SUMINISTROS Y ARMADURA ---")

	var pod_scene = load("res://scenes/combat/environment/supply_pod.tscn") as PackedScene
	var pod = pod_scene.instantiate()
	root.add_child(pod)

	if pod.health_component and is_equal_approx(pod.health_component.max_health, 220.0):
		_pass("SupplyPod salud base", "220 HP")
	else:
		_fail("SupplyPod salud base", "Salud no es 220 HP")

	# Test de armadura plana (-3 de daño)
	var prev_hp: float = pod.health_component.current_health
	var ctx := HitContext.new()
	ctx.final_damage = 10.0
	ctx.raw_damage = 10.0
	pod.take_damage(ctx)

	var damage_taken: float = prev_hp - pod.health_component.current_health
	if is_equal_approx(damage_taken, 7.0): # 10 - 3 = 7
		_pass("SupplyPod mitigación de armadura plana", "10 dmg entrante -> 7 dmg aplicado")
	else:
		_fail("SupplyPod armadura plana", "Esperado 7.0, aplicado: %f" % damage_taken)

	# Matar la cápsula y comprobar drop de consumibles
	pod._die()

	var found_consumables: int = 0
	for child in root.get_children():
		if child.is_in_group("consumables") or child.name.begins_with("FieldConsumable"):
			found_consumables += 1
			child.queue_free()

	if found_consumables >= 1:
		_pass("SupplyPod suelta consumibles de supervivencia", "%d consumible(s) soltado(s)" % found_consumables)
	else:
		_fail("SupplyPod consumibles", "No soltó consumibles de supervivencia")


# --- TIER 6: GEODA DE CUARZO ASTRAL Y AMPLIFICACIÓN ---
func _test_tier6_astral_geode_prism_amplification() -> void:
	print("\n--- [TIER 6] GEODA DE CUARZO ASTRAL Y AMPLIFICACIÓN ---")

	var geode_scene = load("res://scenes/combat/environment/astral_geode.tscn") as PackedScene
	var geode = geode_scene.instantiate()
	geode.global_position = Vector2(400, 400)
	root.add_child(geode)

	if geode.health_component and is_equal_approx(geode.health_component.max_health, 300.0):
		_pass("AstralGeode salud base", "300 HP")
	else:
		_fail("AstralGeode salud base", "Salud no es 300 HP")

	# Crear un proyectil cinético del jugador que pasa por la geoda
	var proj_scene = load("res://scenes/combat/weapons/kinetic_projectile.tscn") as PackedScene
	var proj = proj_scene.instantiate()
	var pctx := HitContext.new()
	pctx.raw_damage = 20.0
	pctx.final_damage = 20.0
	pctx.is_crit = false
	proj.setup(Vector2(400, 400), Vector2.RIGHT, pctx)
	root.add_child(proj)

	geode._try_amplify_projectile(proj)

	if proj.hit_context.final_damage >= 30.0 and proj.hit_context.is_crit == true:
		_pass("AstralGeode amplificación de proyectil aliado", "+50%% daño (20 -> %.1f) y crítico" % proj.hit_context.final_damage)
	else:
		_fail("AstralGeode amplificación", "Proyectil no fue amplificado correctamente")

	proj.queue_free()
	geode.queue_free()


# --- TIER 7: CAPULLO BIOMECÁNICO Y DETONACIÓN EN CADENA ---
func _test_tier7_bio_cocoon_chain_reaction() -> void:
	print("\n--- [TIER 7] CAPULLO BIOMECÁNICO Y DETONACIÓN EN CADENA ---")

	var cocoon_scene = load("res://scenes/combat/environment/bio_cocoon.tscn") as PackedScene
	var cocoon = cocoon_scene.instantiate()
	cocoon.global_position = Vector2(600, 600)
	root.add_child(cocoon)

	if cocoon.health_component and is_equal_approx(cocoon.health_component.max_health, 180.0):
		_pass("BioCocoon salud base", "180 HP")
	else:
		_fail("BioCocoon salud base", "Salud no es 180 HP")

	# Spawnear un esbirro hijo real para verificar cadena biológica
	var minion_scene = load("res://scenes/combat/enemies/enemy_kamikaze.tscn") as PackedScene
	var minion = minion_scene.instantiate() as CharacterBody2D
	root.add_child(minion)
	cocoon.spawned_minions.append(minion)

	# Matar el capullo
	cocoon._die()

	if minion.is_dying or minion.current_health <= 0.0:
		_pass("BioCocoon detonación biológica en cadena", "Esbirros hijos eliminados en cascada")
	else:
		_fail("BioCocoon cadena biológica", "Esbirro hijo no fue eliminado")

	minion.queue_free()


# --- TIER 8: SPAWNER DE MACRO-OBJETOS ---
func _test_tier8_space_object_spawner_integration() -> void:
	print("\n--- [TIER 8] SPAWNER DE MACRO-OBJETOS Y MAIN GAME ---")

	var spawner = SpaceObjectSpawnerScript.new()
	root.add_child(spawner)

	if spawner.monolith_scene and spawner.supply_pod_scene and spawner.astral_geode_scene and spawner.bio_cocoon_scene:
		_pass("SpaceObjectSpawner referencias prealmacenadas", "Las 4 macro-escenas configuradas")
	else:
		_fail("SpaceObjectSpawner referencias", "Faltan PackedScenes en el spawner")

	# Simular spawn
	spawner._spawn_single_object(Vector2(1000, 1000))
	var active_macro: int = (
		root.get_tree().get_nodes_in_group("monoliths").size() +
		root.get_tree().get_nodes_in_group("supply_pods").size() +
		root.get_tree().get_nodes_in_group("astral_geodes").size() +
		root.get_tree().get_nodes_in_group("bio_cocoons").size()
	)

	if active_macro >= 1:
		_pass("SpaceObjectSpawner instanciación autónoma", "Macro-objeto instanciado en escena")
	else:
		_fail("SpaceObjectSpawner instanciación", "No se instanció ningún macro-objeto")

	for g in ["monoliths", "supply_pods", "astral_geodes", "bio_cocoons"]:
		for n in root.get_tree().get_nodes_in_group(g):
			n.queue_free()

	spawner.queue_free()


# --- TIER 9: ARMAS MULTIPROCESO, PENETRACIÓN Y RENDIMIENTO MASIVO ---
func _test_tier9_cross_weapon_and_performance_optimizations() -> void:
	print("\n--- [TIER 9] ARMAS MULTIPROCESO, PENETRACIÓN Y RENDIMIENTO MASIVO ---")

	# 1. Penetración (Piercing) sin repetición de daño por frame en el mismo obstáculo
	var dummy_obs := CharacterBody2D.new()
	var d_health := HealthComponent.new()
	d_health.max_health = 100.0
	d_health.current_health = 100.0
	dummy_obs.add_child(d_health)
	dummy_obs.set_script(load("res://scenes/combat/environment/destructible_space_object.gd"))
	dummy_obs.global_position = Vector2(300.0, 300.0)
	dummy_obs.set("obstacle_radius", 40.0)
	root.add_child(dummy_obs)

	var proj_scene = load("res://scenes/combat/weapons/kinetic_projectile.tscn") as PackedScene
	var proj = proj_scene.instantiate() as KineticProjectile
	var pctx := HitContext.new()
	pctx.raw_damage = 25.0
	pctx.final_damage = 25.0
	proj.pierces_max = 2
	proj.setup(Vector2(300.0, 300.0), Vector2.RIGHT, pctx)
	root.add_child(proj)

	# Simular detección frame 1
	proj._check_collisions()
	var hp_after_f1: float = d_health.current_health
	var pierces_after_f1: int = proj.pierces_left

	# Simular detección frame 2 en la misma posición (debe ignorar el obstáculo ya impactado)
	proj._check_collisions()
	var hp_after_f2: float = d_health.current_health
	var pierces_after_f2: int = proj.pierces_left

	if is_equal_approx(hp_after_f1, 75.0) and is_equal_approx(hp_after_f2, 75.0) and pierces_after_f1 == 1 and pierces_after_f2 == 1:
		_pass("KineticProjectile piercing", "Impacta una sola vez y conserva pierces restantes")
	else:
		_fail("KineticProjectile piercing", "Daño repetido por frame o pierces agotados incorrectamente (HP f1: %.1f, HP f2: %.1f)" % [hp_after_f1, hp_after_f2])

	proj.queue_free()
	dummy_obs.queue_free()

	# 2. Armas no lineales (HomingMissile y ClusterGrenade) en player_projectiles y amplificación
	var missile_scene = load("res://scenes/combat/weapons/homing_missile.tscn") as PackedScene
	var missile = missile_scene.instantiate()
	var mctx := HitContext.new()
	mctx.raw_damage = 30.0
	mctx.final_damage = 30.0
	missile.setup(Vector2(600.0, 600.0), Vector2.RIGHT, mctx)
	root.add_child(missile)

	var grenade_scene = load("res://scenes/combat/weapons/cluster_grenade.tscn") as PackedScene
	var grenade = grenade_scene.instantiate()
	var gctx := HitContext.new()
	gctx.raw_damage = 40.0
	gctx.final_damage = 40.0
	grenade.setup(Vector2(600.0, 600.0), Vector2(700.0, 600.0), gctx)
	root.add_child(grenade)

	var groups_ok: bool = missile.is_in_group("player_projectiles") and grenade.is_in_group("player_projectiles")
	if groups_ok:
		_pass("Armas secundarias en player_projectiles", "HomingMissile y ClusterGrenade registradas")
	else:
		_fail("Armas secundarias en player_projectiles", "Missile o Grenade no están en el grupo")

	# Probar amplificación de geoda sobre HomingMissile
	var geode_scene = load("res://scenes/combat/environment/astral_geode.tscn") as PackedScene
	var geode = geode_scene.instantiate()
	geode.global_position = Vector2(600.0, 600.0)
	root.add_child(geode)

	geode._try_amplify_projectile(missile)
	if missile.hit_context.final_damage >= 45.0 and missile.hit_context.is_crit == true:
		_pass("AstralGeode amplifica proyectiles no lineales", "+50%% daño en HomingMissile (30 -> %.1f)" % missile.hit_context.final_damage)
	else:
		_fail("AstralGeode amplificación no lineal", "Missile no fue amplificado correctamente")

	missile.queue_free()
	grenade.queue_free()
	geode.queue_free()

	# 3. Benchmark de rendimiento masivo en BulletServer (500 balas, 10 obstáculos)
	var bs = BulletServerScript.new()
	root.add_child(bs)

	var test_obs_list: Array[Node2D] = []
	for o in range(10):
		var obs_node := Node2D.new()
		obs_node.global_position = Vector2(200.0 + float(o) * 80.0, 300.0)
		root.add_child(obs_node)
		bs.register_obstacle(obs_node, 30.0)
		test_obs_list.append(obs_node)

	for b in range(500):
		bs.spawn_bullet(100.0 + randf_range(0.0, 800.0), 300.0 + randf_range(-10.0, 10.0), 200.0, 0.0, 0, 4.0, 5.0)

	var t_start := Time.get_ticks_usec()
	for f in range(5):
		bs._physics_process(0.016)
	var elapsed_ms := float(Time.get_ticks_usec() - t_start) / 1000.0

	if elapsed_ms < 100.0:
		_pass("BulletServer rendimiento balístico masivo", "5 frames x 500 balas procesados en %.2f ms" % elapsed_ms)
	else:
		_fail("BulletServer rendimiento balístico", "Demasiado lento: %.2f ms" % elapsed_ms)

	for obs_node in test_obs_list:
		bs.unregister_obstacle(obs_node)
		obs_node.queue_free()
	bs.queue_free()

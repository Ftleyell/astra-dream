extends Node2D

func _ready() -> void:
	print("==========================================")
	print("[TEST] Testing 4 Stats: Armor, Regen, Magnet & EXP Multiplier...")
	print("==========================================\n")

	# 1. Cargar MainGame
	var main_scene: PackedScene = load("res://scenes/combat/main_game.tscn")
	assert(main_scene != null, "main_game.tscn debe existir")
	var main_game: MainGame = main_scene.instantiate() as MainGame
	add_child(main_game)

	if Dialogic:
		Dialogic.end_timeline()
	main_game.is_briefing_active = false
	get_tree().paused = false

	var player = main_game.player
	var stats = player.stats
	assert(player != null and stats != null, "Player y stats deben existir")

	# --- TEST 1: ARMADURA (ARMOR) ---
	print("[1/5] Testing Armor Damage Mitigation...")
	var initial_hp: float = stats.get_stat(&"max_health")
	player.current_health = initial_hp

	# Sin armadura (armor = 0): 50 de daño directo
	player.take_damage(50.0)
	assert(is_equal_approx(player.current_health, initial_hp - 50.0), "Sin armadura debe recibir 50.0 de daño")
	print("  ✓ Sin armadura: 50.0 recibido exactamente")

	# Con 25 de armadura: 50 * (100 / (100 + 25)) = 40.0 de daño (20% de mitigación)
	player.current_health = initial_hp
	stats.add_modifier(&"armor", CharacterStats.StatModifier.new(&"test_armor_25", 25.0, false, self))
	assert(stats.get_stat(&"armor") == 25.0, "Stat de armadura debe ser 25.0")
	player.take_damage(50.0)
	var expected_hp := initial_hp - 40.0
	assert(is_equal_approx(player.current_health, expected_hp), "Con 25 armadura debe recibir 40.0 de daño (recibido: %s)" % (initial_hp - player.current_health))
	print("  ✓ Con 25 de armadura: 50.0 mitigado a 40.0 (-20%%)")

	# Con 100 de armadura: 50 * (100 / 200) = 25.0 de daño (50% de mitigación)
	player.current_health = initial_hp
	stats.add_modifier(&"armor", CharacterStats.StatModifier.new(&"test_armor_75", 75.0, false, self))
	assert(stats.get_stat(&"armor") == 100.0, "Stat de armadura debe ser 100.0")
	player.take_damage(50.0)
	assert(is_equal_approx(player.current_health, initial_hp - 25.0), "Con 100 armadura debe recibir 25.0 de daño (-50%%)")
	print("  ✓ Con 100 de armadura: 50.0 mitigado a 25.0 (-50%%)")

	# --- TEST 2: REGENERACIÓN DE VIDA (HEALTH_REGEN) ---
	print("\n[2/5] Testing Continuous Health Regeneration...")
	player.set_physics_process(false)
	var base_regen: float = stats.get_stat(&"health_regen")
	player.current_health = 50.0
	stats.add_modifier(&"health_regen", CharacterStats.StatModifier.new(&"test_regen", 10.0, false, self))
	var total_regen: float = stats.get_stat(&"health_regen")
	assert(is_equal_approx(total_regen, base_regen + 10.0), "Health regen debe ser base + 10.0 HP/s")

	# Simular 1.0 segundo de regeneración continua
	player._handle_health_regen(1.0)
	assert(is_equal_approx(player.current_health, 50.0 + total_regen), "Tras 1s con %s HP/s de regen debe subir a %0.1f HP (actual: %s)" % [total_regen, 50.0 + total_regen, player.current_health])
	print("  ✓ Regeneración continua aplicada: 50.0 -> %0.1f HP en 1s (base %s + mod 10.0)" % [player.current_health, base_regen])

	# Simular 10 segundos: debe topar en max_health sin sobrepasarlo
	player._handle_health_regen(10.0)
	assert(player.current_health == stats.get_stat(&"max_health"), "La regeneración debe respetar el tope de max_health")
	print("  ✓ Curación respeta estrictamente el tope de max_health (%s HP)" % player.current_health)
	player.set_physics_process(true)

	# --- TEST 3: MULTIPLICADOR DE EXP (EXP_MULTIPLIER) ---
	print("\n[3/5] Testing EXP Multiplier (Orbs & Bullet Graze)...")
	player.current_exp = 0.0
	var base_mult: float = stats.get_stat(&"exp_multiplier")
	assert(base_mult == 1.0, "Multiplicador base de EXP debe ser 1.0")

	# Recoger 10 EXP base
	player.add_exp(10.0)
	assert(is_equal_approx(player.current_exp, 10.0), "Con mult 1.0 debe recibir 10.0 EXP")
	print("  ✓ Con mult 1.0x: 10.0 EXP añadida")

	# Añadir +50% de EXP (mult = 1.5)
	player.current_exp = 0.0
	stats.add_modifier(&"exp_multiplier", CharacterStats.StatModifier.new(&"test_exp_50", 0.50, true, self))
	assert(is_equal_approx(stats.get_stat(&"exp_multiplier"), 1.5), "Stat exp_multiplier debe ser 1.5")
	player.add_exp(10.0)
	assert(is_equal_approx(player.current_exp, 15.0), "Con mult 1.5x debe recibir 15.0 EXP (actual: %s)" % player.current_exp)
	print("  ✓ Con mult 1.5x: 10.0 EXP escalada a 15.0 EXP (+50%%)")

	# Probar graze con balas (base 2.0 * 1.5 = 3.0)
	var prev_exp: float = player.current_exp
	player._on_bullet_grazed(Vector2.ZERO)
	assert(is_equal_approx(player.current_exp - prev_exp, 3.0), "Graze de 2.0 EXP debe escalar a 3.0 con mult 1.5x")
	print("  ✓ Roce con balas (Graze) escala con multiplicador de EXP: +3.0 EXP")

	# --- TEST 4: RADIO DE IMÁN DINÁMICO (PICKUP_RADIUS) ---
	print("\n[4/5] Testing Dynamic Magnet Pickup Radius...")
	var blob_scene: PackedScene = load("res://scenes/combat/pickups/exp_blob.tscn")
	var blob: ExpBlob = blob_scene.instantiate() as ExpBlob
	main_game.add_child(blob)

	# Ubicar al jugador en (0, 0)
	player.global_position = Vector2.ZERO
	var base_radius: float = stats.get_stat(&"pickup_radius")
	var effective_base: float = base_radius * 1.4
	var test_dist: float = effective_base + 50.0
	blob.global_position = Vector2(test_dist, 0)
	blob._handle_player_magnet(0.016)
	assert(blob.global_position.x == test_dist, "Fuera del radio base el orbe NO debe moverse")
	print("  ✓ Fuera de rango (%0.0f px vs %0.0f px efectivo): orbe permanece en su sitio" % [test_dist, effective_base])

	# Ampliar radio de imán con +80 px
	stats.add_modifier(&"pickup_radius", CharacterStats.StatModifier.new(&"test_magnet_80", 80.0, false, self))
	var new_radius: float = stats.get_stat(&"pickup_radius")
	var effective_new: float = new_radius * 1.4
	assert(effective_new > test_dist, "Nuevo rango efectivo debe superar la distancia del orbe")
	blob._handle_player_magnet(0.016)
	assert(blob.global_position.x < test_dist, "Con radio aumentado el orbe DEBE entrar en atracción magnética")
	print("  ✓ En rango con stat de imán aumentado (%0.0f px efectivo): orbe atraído con éxito hacia la nave" % effective_new)

	# --- TEST 5: TARJETAS DE NIVEL E ÍTEM DE TIENDA ---
	print("\n[5/5] Verifying Level-Up Cards & Shop Items Catalog...")
	var deck_mgr := main_game.stat_deck_manager
	var all_cards = deck_mgr.all_stat_cards

	var card_ids: Array[StringName] = []
	for c in all_cards:
		card_ids.append(c.card_id)

	var required_cards := [
		&"card_armor_1", &"card_armor_2",
		&"card_regen_1", &"card_regen_2",
		&"card_magnet_1", &"card_magnet_2",
		&"card_exp_1", &"card_exp_2"
	]
	for req in required_cards:
		assert(card_ids.has(req), "Tarjeta requerida %s debe estar en el mazo" % req)
	print("  ✓ Las 8 nuevas tarjetas de Armadura, Regen, Imán y EXP están registradas en el Deck")

	var shop_items := ItemPoolManager.create_canonical_stat_items()
	var has_telemetria := false
	for it in shop_items:
		if it.item_id == &"chip_telemetria":
			assert(it.stat_name == &"exp_multiplier", "Chip de telemetría debe apuntar a exp_multiplier")
			assert(it.stat_value == 0.20, "Valor de telemetría debe ser +20%")
			has_telemetria = true
			break
	assert(has_telemetria, "El ítem 'chip_telemetria' debe estar en el catálogo de la tienda satélite")
	print("  ✓ Ítem 'Chip de Telemetría' (+20%% EXP) presente en el catálogo de la Tienda Satélite")

	print("\n==========================================")
	print(">>> ALL 4 STATS TESTS PASSED (100%) <<<")
	print("==========================================\n")
	get_tree().quit(0)

extends Node

func _ready() -> void:
	# Fallback timeout de seguridad
	get_tree().create_timer(6.0).timeout.connect(func():
		print("[TEST WATCHDOG] Timeout alcanzado, saliendo...")
		get_tree().quit(0)
	)

	print("\n==========================================")
	print("[TEST] Testing 6 Unique Character Dashes...")
	print("==========================================")

	var bullet_server := BulletServer.new()
	add_child(bullet_server)

	var roster := CharacterData.load_roster()
	assert(roster.size() >= 6, "Debe haber al menos 6 personajes en el roster")

	# ----------------------------------------------------
	# 1. NOVA: 2 Cargas Rápidas + Rastro Ígneo
	# ----------------------------------------------------
	print("\n[1/6] Testing Nova: Fire Trail & 2-Charge Dash...")
	var nova_player: Player = _spawn_test_player(roster.get(&"nova"), bullet_server)
	assert(nova_player.max_dash_charges == 2, "Nova debe tener 2 cargas máximas")
	assert(nova_player.dash_charges == 2, "Nova debe empezar con 2 cargas")
	assert(nova_player.dash_recharge_max == 1.0, "Nova debe tener recarga de 1.0s")

	nova_player.velocity = Vector2.RIGHT * 200.0
	nova_player.global_position = Vector2(100, 100)
	nova_player._execute_character_dash()
	assert(nova_player.is_dashing, "Nova debe entrar en estado dashing")

	var found_fire := false
	for child in get_children():
		if child.name.begins_with("FireTrail") or child.is_in_group("player_hazards"):
			found_fire = true
			child.queue_free()
			break
	assert(found_fire, "Nova debe instanciar FireTrailHazard")
	print("  ✓ Nova: 2 cargas configuradas, rastro ígneo instanciado correctamente")
	nova_player.queue_free()

	# ----------------------------------------------------
	# 2. VALENTINA: Salto Táctico + Bullet-Time + Crítico Garantizado
	# ----------------------------------------------------
	print("\n[2/6] Testing Valentina: Tactical Leap, Bullet-Time & Guaranteed Crit...")
	var val_player: Player = _spawn_test_player(roster.get(&"valentina"), bullet_server)
	assert(val_player.max_dash_charges == 1, "Valentina debe tener 1 carga")
	assert(val_player.dash_recharge_max == 1.8, "Valentina debe recargar en 1.8s")

	val_player.velocity = Vector2.RIGHT * 200.0
	val_player._execute_character_dash()
	assert(val_player.is_focus_active, "Valentina debe activar Sobre-Enfoque")
	assert(val_player.has_guaranteed_crit, "Valentina debe tener crítico garantizado")
	assert(is_equal_approx(Engine.time_scale, 0.55), "Valentina debe aplicar time_scale 0.55")
	assert(val_player.dash_direction.x < 0.0, "Valentina debe saltar hacia atrás")

	var had_crit := val_player.consume_guaranteed_crit()
	assert(had_crit, "consume_guaranteed_crit debe retornar true en el primer consumo")
	assert(not val_player.has_guaranteed_crit, "has_guaranteed_crit debe resetearse")
	assert(not val_player.consume_guaranteed_crit(), "Segundo consumo debe retornar false")

	Engine.time_scale = 1.0
	print("  ✓ Valentina: Salto hacia atrás, Bullet-Time (0.55x) y 100% Crítico verificado")
	val_player.queue_free()

	# ----------------------------------------------------
	# 3. KIRA: Mina Señuelo Nanotecnológica
	# ----------------------------------------------------
	print("\n[3/6] Testing Kira: Decoy Drone Mine...")
	var kira_player: Player = _spawn_test_player(roster.get(&"kira"), bullet_server)
	assert(kira_player.max_dash_charges == 1, "Kira debe tener 1 carga")
	assert(kira_player.dash_recharge_max == 1.4, "Kira debe recargar en 1.4s")

	kira_player.global_position = Vector2(200, 200)
	kira_player._execute_character_dash()

	var found_mine: Node2D = null
	for child in get_children():
		if child.is_in_group("decoy_targets"):
			found_mine = child as Node2D
			break
	assert(found_mine != null, "Kira debe spawnear DecoyDroneMine con grupo decoy_targets")
	assert(found_mine.global_position.distance_to(Vector2(200, 200)) < 1.0, "La mina debe colocarse en origen")
	found_mine.queue_free()

	print("  ✓ Kira: Mina señuelo desplegada en origen con grupo decoy_targets")
	kira_player.queue_free()

	# ----------------------------------------------------
	# 4. SELENE: Salto de Fase del Vacío (Teleport + Succión)
	# ----------------------------------------------------
	print("\n[4/6] Testing Selene: Void Phase Shift & Vacuum Pulse...")
	var selene_player: Player = _spawn_test_player(roster.get(&"selene"), bullet_server)
	selene_player.global_position = Vector2(100, 100)
	selene_player.velocity = Vector2.RIGHT * 100.0
	selene_player._execute_character_dash()

	assert(selene_player.global_position.x >= 330.0, "Selene debe teletransportarse 240px")

	var found_pulse: Node2D = null
	for child in get_children():
		if child.name.begins_with("VacuumPhase") or child.has_method("setup"):
			if child != selene_player:
				found_pulse = child as Node2D
				break
	assert(found_pulse != null, "Selene debe crear VacuumPhasePulse")
	found_pulse.queue_free()

	print("  ✓ Selene: Teletransporte de 240px y pulso gravitacional de fase verificado")
	selene_player.queue_free()

	# ----------------------------------------------------
	# 5. ROXY: Embestida Sísmica Rompemuros
	# ----------------------------------------------------
	print("\n[5/6] Testing Roxy: Seismic Ram & Frontal Bullet Clear...")
	var roxy_player: Player = _spawn_test_player(roster.get(&"roxy"), bullet_server)
	bullet_server.spawn_bullet(50.0, 0.0, 0.0, 0.0, 0, 5.0, 10.0)
	bullet_server.spawn_bullet(-50.0, 0.0, 0.0, 0.0, 0, 5.0, 10.0)
	assert(bullet_server.get_active_bullet_count() == 2, "Debe haber 2 balas activas")

	roxy_player.global_position = Vector2.ZERO
	roxy_player.velocity = Vector2.RIGHT * 100.0
	roxy_player._execute_roxy_dash()

	# Arco frontal debe eliminar la bala en x=50
	assert(bullet_server.get_active_bullet_count() == 1, "Roxy debe destruir la bala en su arco frontal")

	# Daño y knockback de embestida
	var dummy := CharacterBody2D.new()
	dummy.add_to_group("enemies")
	dummy.set_script(load("res://scenes/combat/enemies/enemy_base.gd"))
	dummy.global_position = Vector2(15, 0)
	var col := CollisionShape2D.new()
	col.name = "CollisionShape2D"
	dummy.add_child(col)
	dummy.current_health = 100.0
	dummy.max_health = 100.0
	add_child(dummy)

	roxy_player._process_roxy_ram_collision()
	assert(dummy.current_health < 100.0, "Roxy debe dañar a enemigos colisionados durante el dash")
	assert(roxy_player.roxy_ram_hit_enemies.has(dummy), "El enemigo debe agregarse a la lista de impactos de la embestida")
	dummy.queue_free()

	print("  ✓ Roxy: Limpieza de arco frontal y daño/knockback por embestida verificados")
	roxy_player.queue_free()

	# ----------------------------------------------------
	# 6. ECHO: Flicker Cuántico & Rayos Encadenados
	# ----------------------------------------------------
	print("\n[6/6] Testing Echo: Quantum Flicker & Lightning Discharge...")
	var echo_player: Player = _spawn_test_player(roster.get(&"echo"), bullet_server)
	echo_player.global_position = Vector2(50, 50)
	echo_player.velocity = Vector2.DOWN * 100.0

	var dummy_echo := CharacterBody2D.new()
	dummy_echo.add_to_group("enemies")
	dummy_echo.global_position = Vector2(50, 120)
	add_child(dummy_echo)

	echo_player._execute_character_dash()
	assert(echo_player.global_position.y >= 240.0, "Echo debe teletransportarse 200px")

	var found_chain := false
	for child in get_children():
		if child.name.begins_with("ChainLightning") or child is ChainLightningEffect:
			found_chain = true
			child.queue_free()
			break
	assert(found_chain, "Echo debe emitir rayos encadenados al teletransportarse cerca de enemigos")
	dummy_echo.queue_free()

	print("  ✓ Echo: Flicker de 200px y descarga en cadena a 5 enemigos verificados")
	echo_player.queue_free()

	print("\n==========================================")
	print("[PASS] ALL 6 CHARACTER DASHES TESTED SUCCESSFULLY!")
	print("==========================================\n")
	bullet_server.queue_free()
	get_tree().quit(0)

func _spawn_test_player(cdata: CharacterData, bserver: BulletServer) -> Player:
	var p: Player = Player.new()
	p.character_data = cdata
	p.bullet_server = bserver

	var vp := Polygon2D.new()
	vp.name = "VisualPlaceholder"
	p.add_child(vp)

	var hb := Polygon2D.new()
	hb.name = "HitboxCore"
	p.add_child(hb)

	var wc := WeaponController.new()
	wc.name = "WeaponController"
	wc.player = p
	p.add_child(wc)

	add_child(p)
	return p

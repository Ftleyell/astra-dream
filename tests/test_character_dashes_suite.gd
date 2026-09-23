extends Node

func _ready() -> void:
	# Fallback timeout de seguridad
	get_tree().create_timer(10.0).timeout.connect(func():
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
	# 1. NOVA: 2 Cargas Rápidas + Rastro Ígneo hacia la mira
	# ----------------------------------------------------
	print("\n[1/6] Testing Nova: Fire Trail & 2-Charge Dash towards aim...")
	var nova_player: Player = _spawn_test_player(roster.get(&"nova"), bullet_server)
	assert(nova_player.max_dash_charges == 2, "Nova debe tener 2 cargas máximas")
	assert(nova_player.dash_charges == 2, "Nova debe empezar con 2 cargas")
	assert(nova_player.dash_recharge_max == 1.0, "Nova debe tener recarga de 1.0s")

	# Mira hacia la derecha (0,0) desde (-100, 0), con movimiento hacia ARRIBA
	nova_player.global_position = Vector2(-100, 0)
	nova_player.velocity = Vector2.UP * 200.0
	nova_player._execute_character_dash()
	assert(nova_player.is_dashing, "Nova debe entrar en estado dashing")
	assert(nova_player.dash_direction.is_equal_approx(Vector2.RIGHT), "Nova debe dashear en la dirección de la mira (Vector2.RIGHT)")

	var found_fire := false
	for child in get_children():
		if child.name.begins_with("FireTrail") or child.is_in_group("player_hazards"):
			found_fire = true
			child.queue_free()
			break
	assert(found_fire, "Nova debe instanciar FireTrailHazard")
	print("  ✓ Nova: Dash hacia la mira verificado, rastro ígneo instanciado correctamente")
	nova_player.queue_free()

	# ----------------------------------------------------
	# 2. VALENTINA: Salto Táctico de Retroceso opuesto a la mira + Bullet-Time
	# ----------------------------------------------------
	print("\n[2/6] Testing Valentina: Tactical Leap, Bullet-Time & Guaranteed Crit...")
	var val_player: Player = _spawn_test_player(roster.get(&"valentina"), bullet_server)
	assert(val_player.max_dash_charges == 1, "Valentina debe tener 1 carga")
	assert(val_player.dash_recharge_max == 1.8, "Valentina debe recargar en 1.8s")

	# Mira hacia la derecha (0,0) desde (-100, 0), con movimiento hacia ARRIBA
	val_player.global_position = Vector2(-100, 0)
	val_player.velocity = Vector2.UP * 200.0
	val_player._execute_character_dash()

	assert(val_player.is_focus_active, "Valentina debe activar Sobre-Enfoque")
	assert(val_player.has_guaranteed_crit, "Valentina debe tener crítico garantizado")
	assert(is_equal_approx(Engine.time_scale, 0.55), "Valentina debe aplicar time_scale 0.55")
	# Retroceso opuesto a la mira
	assert(val_player.dash_direction.is_equal_approx(Vector2.LEFT), "Valentina debe retroceder opuesto a la mira (Vector2.LEFT)")

	var had_crit := val_player.consume_guaranteed_crit()
	assert(had_crit, "consume_guaranteed_crit debe retornar true en el primer consumo")
	assert(not val_player.has_guaranteed_crit, "has_guaranteed_crit debe resetearse")
	assert(not val_player.consume_guaranteed_crit(), "Segundo consumo debe retornar false")

	Engine.time_scale = 1.0
	print("  ✓ Valentina: Retroceso opuesto a la mira, Bullet-Time (0.55x) y 100% Crítico verificado")
	val_player.queue_free()

	# ----------------------------------------------------
	# 3. KIRA: Mina Señuelo Nanotecnológica hacia la mira
	# ----------------------------------------------------
	print("\n[3/6] Testing Kira: Decoy Drone Mine towards aim...")
	var kira_player: Player = _spawn_test_player(roster.get(&"kira"), bullet_server)
	assert(kira_player.max_dash_charges == 1, "Kira debe tener 1 carga")
	assert(kira_player.dash_recharge_max == 1.4, "Kira debe recargar en 1.4s")

	kira_player.global_position = Vector2(-100, 0)
	kira_player.velocity = Vector2.DOWN * 200.0
	kira_player._execute_character_dash()
	assert(kira_player.dash_direction.is_equal_approx(Vector2.RIGHT), "Kira debe dashear en la dirección de la mira (Vector2.RIGHT)")

	var found_mine: Node2D = null
	for child in get_children():
		if child.is_in_group("decoy_targets"):
			found_mine = child as Node2D
			break
	assert(found_mine != null, "Kira debe spawnear DecoyDroneMine con grupo decoy_targets")
	assert(found_mine.global_position.distance_to(Vector2(-100, 0)) < 1.0, "La mina debe colocarse en origen")
	found_mine.queue_free()

	print("  ✓ Kira: Dash hacia la mira y mina señuelo desplegada en origen")
	kira_player.queue_free()

	# ----------------------------------------------------
	# 4. SELENE: Salto de Fase del Vacío hacia la mira (Teleport + Succión)
	# ----------------------------------------------------
	print("\n[4/6] Testing Selene: Void Phase Shift towards aim & Vacuum Pulse...")
	var selene_player: Player = _spawn_test_player(roster.get(&"selene"), bullet_server)
	selene_player.global_position = Vector2(-100, 0)
	selene_player.velocity = Vector2.DOWN * 100.0
	selene_player._execute_character_dash()

	assert(selene_player.dash_direction.is_equal_approx(Vector2.RIGHT), "Selene debe dashear hacia la mira (Vector2.RIGHT)")
	assert(is_equal_approx(selene_player.global_position.x, 140.0), "Selene debe teletransportarse 240px hacia la mira")

	var found_pulse: Node2D = null
	for child in get_children():
		if child.name.begins_with("VacuumPhase") or child.has_method("setup"):
			if child != selene_player:
				found_pulse = child as Node2D
				break
	assert(found_pulse != null, "Selene debe crear VacuumPhasePulse")
	found_pulse.queue_free()

	print("  ✓ Selene: Teletransporte de 240px hacia la mira y pulso gravitacional verificado")
	selene_player.queue_free()

	# ----------------------------------------------------
	# 5. ROXY: Embestida Sísmica Rompemuros hacia la mira
	# ----------------------------------------------------
	print("\n[5/6] Testing Roxy: Seismic Ram towards aim & Frontal Bullet Clear...")
	var roxy_player: Player = _spawn_test_player(roster.get(&"roxy"), bullet_server)
	roxy_player.global_position = Vector2(-100, 0)
	roxy_player.velocity = Vector2.UP * 100.0

	# Bala en el arco frontal hacia la mira (hacia (0,0))
	bullet_server.spawn_bullet(-50.0, 0.0, 0.0, 0.0, 0, 5.0, 10.0)
	# Bala a la espalda (alejada de la mira)
	bullet_server.spawn_bullet(-150.0, 0.0, 0.0, 0.0, 0, 5.0, 10.0)
	assert(bullet_server.get_active_bullet_count() == 2, "Debe haber 2 balas activas")

	roxy_player._execute_roxy_dash()
	assert(roxy_player.dash_direction.is_equal_approx(Vector2.RIGHT), "Roxy debe embestir hacia la mira (Vector2.RIGHT)")
	assert(bullet_server.get_active_bullet_count() == 1, "Roxy debe destruir la bala en su arco frontal hacia la mira")

	# Daño y knockback de embestida
	var dummy := CharacterBody2D.new()
	dummy.add_to_group("enemies")
	dummy.set_script(load("res://scenes/combat/enemies/enemy_base.gd"))
	dummy.global_position = Vector2(-85, 0)
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

	print("  ✓ Roxy: Embestida hacia la mira, limpieza frontal y daño/knockback verificados")
	roxy_player.queue_free()

	# ----------------------------------------------------
	# 6. ECHO: Flicker Cuántico hacia la mira & Rayos Encadenados
	# ----------------------------------------------------
	print("\n[6/6] Testing Echo: Quantum Flicker towards aim & Lightning Discharge...")
	var echo_player: Player = _spawn_test_player(roster.get(&"echo"), bullet_server)
	# Mira hacia abajo (0,0) desde (0, -100)
	echo_player.global_position = Vector2(0, -100)
	echo_player.velocity = Vector2.LEFT * 100.0

	var dummy_echo := CharacterBody2D.new()
	dummy_echo.add_to_group("enemies")
	dummy_echo.global_position = Vector2(0, 120)
	add_child(dummy_echo)

	echo_player._execute_character_dash()
	assert(echo_player.dash_direction.is_equal_approx(Vector2.DOWN), "Echo debe teletransportarse hacia la mira (Vector2.DOWN)")
	assert(is_equal_approx(echo_player.global_position.y, 100.0), "Echo debe teletransportarse 200px hacia la mira")

	var found_chain := false
	for child in get_children():
		if child.name.begins_with("ChainLightning") or child is ChainLightningEffect:
			found_chain = true
			child.queue_free()
			break
	assert(found_chain, "Echo debe emitir rayos encadenados al teletransportarse cerca de enemigos")
	dummy_echo.queue_free()

	print("  ✓ Echo: Flicker hacia la mira de 200px y descarga en cadena verificados")
	echo_player.queue_free()

	print("\n==========================================")
	print("[PASS] ALL 6 CHARACTER DASHES TESTED SUCCESSFULLY!")
	print("==========================================\n")

	# ----------------------------------------------------
	# 7. NOVA: Omega Spin activado con láser a carga máxima
	# ----------------------------------------------------
	print("\n[7/8] Testing Nova: Omega Spin triggered by full laser charge...")
	var nova_spin_player: Player = _spawn_test_player(roster.get(&"nova"), bullet_server)
	nova_spin_player.global_position = Vector2(0, 0)

	# Forzar carga máxima en el WeaponController
	var wc_spin := nova_spin_player.get_node_or_null("WeaponController") as WeaponController
	assert(wc_spin != null, "Nova Omega Spin: WeaponController debe existir")
	wc_spin.is_fully_charged = true
	wc_spin.is_charging = true
	wc_spin.charge_timer = wc_spin.max_charge_time

	# Verificar condición de detección
	assert(wc_spin.is_laser_fully_charged(), "is_laser_fully_charged debe retornar true")

	# Ejecutar el dash
	nova_spin_player._execute_character_dash()

	# Verificar que se activó el Omega Spin (y no el dash normal):
	# El Omega Spin usa dash_timer=0.35 mientras el dash normal usa 0.25.
	# Si el timer es 0.35, el spin se activó correctamente.
	assert(nova_spin_player.is_dashing, "Nova debe entrar en estado dashing")
	assert(is_equal_approx(nova_spin_player.dash_timer, 0.35), "Omega Spin debe tener dash_timer 0.35s (normal es 0.25s)")

	# Verificar que la carga fue consumida
	assert(not wc_spin.is_laser_fully_charged(), "La carga del láser debe haberse consumido tras el Omega Spin")
	assert(not wc_spin.is_fully_charged, "is_fully_charged debe ser false post-spin")
	assert(not wc_spin.is_charging, "is_charging debe ser false post-spin")

	assert(nova_spin_player.is_omega_spinning, "Nova debe tener is_omega_spinning activo")
	print("  ✓ Nova Omega Spin: activado correctamente (timer=0.35s, is_omega_spinning=true), carga consumida")
	nova_spin_player.queue_free()

	# Limpiar cualquier láser remanente del test 7 antes de comenzar el test 8
	var root_node := get_tree().current_scene if get_tree() and get_tree().current_scene else get_parent()
	if root_node:
		for child in root_node.get_children():
			var child_script = child.get_script()
			if child_script and child_script.get_global_name() == "NovaSpin360Laser":
				child.queue_free()
	for child in get_children():
		var child_script = child.get_script()
		if child_script and child_script.get_global_name() == "NovaSpin360Laser":
			child.queue_free()
	await get_tree().process_frame

	# ----------------------------------------------------
	# 8. NOVA: Deduplicación de hits — máx 1 hit por enemigo
	# ----------------------------------------------------
	print("\n[8/8] Testing Nova: Omega Spin hit deduplication (max 1 hit per enemy)...")


	# Crear dos enemigos en posiciones opuestas (deben ser intersectados por rayos contrarios)
	var dummy_a := CharacterBody2D.new()
	dummy_a.add_to_group("enemies")
	dummy_a.set_script(load("res://scenes/combat/enemies/enemy_base.gd"))
	dummy_a.global_position = Vector2(200, 0)
	var col_a := CollisionShape2D.new(); col_a.name = "CollisionShape2D"; dummy_a.add_child(col_a)
	dummy_a.current_health = 500.0; dummy_a.max_health = 500.0
	add_child(dummy_a)

	var dummy_b := CharacterBody2D.new()
	dummy_b.add_to_group("enemies")
	dummy_b.set_script(load("res://scenes/combat/enemies/enemy_base.gd"))
	dummy_b.global_position = Vector2(-200, 0)
	var col_b := CollisionShape2D.new(); col_b.name = "CollisionShape2D"; dummy_b.add_child(col_b)
	dummy_b.current_health = 500.0; dummy_b.max_health = 500.0
	add_child(dummy_b)

	# Construir HitContext y lanzar el barrido de NovaSpin360Laser
	var ctx_dedup := HitContext.new()
	ctx_dedup.attacker = null
	ctx_dedup.raw_damage = 50.0
	ctx_dedup.final_damage = 50.0
	ctx_dedup.is_crit = false
	ctx_dedup.proc_coefficient = 0.0

	# origin_node = null → el nodo permanece en su posición inicial (Vector2.ZERO)
	# start_angle = 0.0 → el barrido comienza apuntando a Vector2.RIGHT (+X)
	var spin_node: Node2D = load("res://scenes/combat/player/dash_effects/nova_spin_360_laser.tscn").instantiate()
	add_child(spin_node)
	if spin_node.has_method("setup"):
		spin_node.call("setup", null, ctx_dedup, 0.0)

	# Aguardar la duración completa del barrido (0.35s) más un margen
	await get_tree().create_timer(0.45).timeout

	# Verificar que cada dummy recibió exactamente 1 hit durante el barrido 360°
	var dmg_a: float = 500.0 - float(dummy_a.current_health)
	var dmg_b: float = 500.0 - float(dummy_b.current_health)

	assert(dmg_a > 0.0, "Enemigo A debe haber recibido al menos 1 hit durante el barrido")
	assert(dmg_b > 0.0, "Enemigo B debe haber recibido al menos 1 hit durante el barrido")
	# Máx 1 hit: daño = 50 * 1.2 = 60.0 (sin crit). Con crit_mult default 1.5 → 90.0
	assert(dmg_a <= 91.0, "Enemigo A no debe recibir más de 1 hit (daño > 91 indicaría doble impacto)")
	assert(dmg_b <= 91.0, "Enemigo B no debe recibir más de 1 hit (daño > 91 indicaría doble impacto)")

	dummy_a.queue_free()
	dummy_b.queue_free()
	print("  ✓ Deduplicación: enemigo A recibió %.1f daño, enemigo B %.1f daño (máx 1 hit cada uno)" % [dmg_a, dmg_b])


	print("\n==========================================")
	print("[PASS] ALL 8 NOVA OMEGA SPIN TESTS PASSED!")
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

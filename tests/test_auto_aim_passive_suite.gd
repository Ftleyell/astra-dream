extends Node2D

## test_auto_aim_passive_suite.gd
## Suite de pruebas para verificar el sistema de ataque pasivo auto-aimed estilo Picayune Dreams.

func _ready() -> void:
	# Watchdog de seguridad (10 segundos)
	get_tree().create_timer(10.0).timeout.connect(func():
		print("[TEST WATCHDOG] Timeout alcanzado, saliendo...")
		get_tree().quit(1)
	)

	print("\n==========================================")
	print("[TEST] Running Auto-Aimed Passive Attacks Suite...")
	print("==========================================")

	# ----------------------------------------------------
	# TEST 1: Registro de Acción y Remapeo
	# ----------------------------------------------------
	print("\n[1/5] Testing InputMap and SettingsModal action registration...")
	assert(InputMap.has_action("toggle_aim_mode"), "InputMap debe tener registrada la acción 'toggle_aim_mode'")
	var events := InputMap.action_get_events("toggle_aim_mode")
	assert(not events.is_empty(), "La acción 'toggle_aim_mode' debe tener al menos un evento asignado (tecla E)")

	var settings := SettingsModal.new()
	var found_rebind := false
	for entry in settings.actions_to_rebind:
		if entry.get("action") == &"toggle_aim_mode":
			found_rebind = true
			break
	assert(found_rebind, "SettingsModal.actions_to_rebind debe contener 'toggle_aim_mode'")
	settings.queue_free()
	print("  ✓ InputMap y SettingsModal: acción 'toggle_aim_mode' registrada correctamente")

	# ----------------------------------------------------
	# TEST 2: Toggle de Modo Auto / Manual en WeaponController
	# ----------------------------------------------------
	print("\n[2/5] Testing WeaponController aim mode toggle & signal...")
	var player := _create_test_player()
	add_child(player)
	var wc := player.get_node("WeaponController") as WeaponController

	assert(not wc.is_manual_aim, "El modo por defecto de WeaponController debe ser Auto (is_manual_aim == false)")

	var signal_data := { "received": false, "val": false }
	wc.aim_mode_changed.connect(func(val: bool):
		signal_data["received"] = true
		signal_data["val"] = val
	)

	wc.toggle_aim_mode()
	assert(wc.is_manual_aim == true, "toggle_aim_mode debe activar is_manual_aim = true")
	assert(signal_data["received"] and signal_data["val"] == true, "Debe emitirse aim_mode_changed(true)")

	signal_data["received"] = false
	wc.toggle_aim_mode()
	assert(wc.is_manual_aim == false, "toggle_aim_mode debe volver a is_manual_aim = false")
	assert(signal_data["received"] and signal_data["val"] == false, "Debe emitirse aim_mode_changed(false)")

	# Verificar indicador visual debajo del personaje (AimModeIndicator)
	var indicator := player.get_node_or_null("AimModeIndicator")
	assert(indicator != null, "AimModeIndicator debe existir como hijo de Player")
	assert(indicator.position.y >= 20.0, "AimModeIndicator debe estar posicionado debajo del personaje (y >= 20)")
	var ind_label := indicator.get_node_or_null("PanelContainer/Label") as Label
	assert(ind_label != null, "AimModeIndicator debe tener un Label interno")
	assert(ind_label.text == "AUTOAIM: ON", "En modo Auto, el indicador debajo del personaje debe decir 'AUTOAIM: ON'")

	wc.toggle_aim_mode()
	assert(ind_label.text == "AUTOAIM: OFF", "En modo Manual, el indicador debajo del personaje debe decir 'AUTOAIM: OFF'")
	wc.toggle_aim_mode()
	assert(ind_label.text == "AUTOAIM: ON", "Al regresar a Auto, el indicador debajo del personaje debe decir 'AUTOAIM: ON'")

	print("  ✓ WeaponController & AimModeIndicator: alternancia Auto/Manual e indicador 'AUTOAIM: ON/OFF' debajo del personaje verificados")



	# ----------------------------------------------------
	# TEST 3: Rango de Autoaim (2x Base + escalado 1 a 1)
	# ----------------------------------------------------
	print("\n[3/5] Testing autoaim range (2x base pickup, 1:1 scaling)...")
	# Configurar base pickup = 100.0 -> autoaim inicial debe ser 200.0 (doble de la base)
	player.character_data.pickup_radius = 100.0
	player.stats.initialize(player.character_data)

	assert(is_equal_approx(wc.get_autoaim_range(), 200.0), "El rango inicial de autoaim debe ser el doble de la base (2 * 100 = 200px)")

	# Enemigo A a 150px (dentro del rango de 200px)
	var enemy_a := _create_test_enemy(Vector2(150, 0))
	add_child(enemy_a)

	# Enemigo B a 230px (fuera del rango inicial de 200px)
	var enemy_b := _create_test_enemy(Vector2(230, 0))
	add_child(enemy_b)

	wc.is_manual_aim = false
	wc._update_locked_target()
	assert(wc.current_locked_target == enemy_a, "current_locked_target debe ser el enemigo A (150px < 200px)")

	# Ahora aumentamos el pickup en +40px con un modificador (simulando carta Imán)
	player.stats.add_modifier(&"pickup_radius", CharacterStats.StatModifier.new(&"iman_card", 40.0, false, null))
	assert(is_equal_approx(player.stats.get_stat(&"pickup_radius"), 140.0), "El pickup radius actual debe ser 140px")
	# El autoaim debe escalar 1 a 1: 200 + 40 = 240px
	assert(is_equal_approx(wc.get_autoaim_range(), 240.0), "El autoaim debe escalar 1 a 1: 200 + 40 = 240px")

	# Con 240px de rango, el Enemigo B (a 230px) ahora sí entra en rango si eliminamos a A
	enemy_a.queue_free()
	await get_tree().process_frame

	wc._update_locked_target()
	assert(wc.current_locked_target == enemy_b, "Con el bono de 40px (rango 240px), el enemigo B (230px) ahora es fijado")

	enemy_b.queue_free()
	await get_tree().process_frame
	print("  ✓ Rango de autoaim: base = 2x pickup (200px) y escalado exacto 1:1 (+40px -> 240px) verificado")



	# ----------------------------------------------------
	# TEST 4: Fallback de Disparo sin Enemigos en Rango
	# ----------------------------------------------------
	print("\n[4/5] Testing blind-fire fallback (ship movement direction)...")
	wc.is_manual_aim = false
	wc._update_locked_target()
	assert(wc.current_locked_target == null, "Sin enemigos, no debe haber objetivo fijado")

	# Nave desplazándose hacia abajo
	player.velocity = Vector2(0, 300)
	var fallback_info := wc._get_passive_aim_info()
	assert(fallback_info.target == null, "No debe haber target en fallback")
	assert(fallback_info.direction.is_equal_approx(Vector2.DOWN), "La dirección debe ser la del movimiento de la nave (Vector2.DOWN)")
	print("  ✓ Fallback: disparo en dirección del movimiento de la nave verificado")

	# ----------------------------------------------------
	# TEST 5: Misil Auto-Aimed en Línea Recta (Picayune Style)
	# ----------------------------------------------------
	print("\n[5/5] Testing straight-line missile flight and impact...")
	var missile_scene := preload("res://scenes/combat/weapons/homing_missile.tscn")
	var missile: HomingMissile = missile_scene.instantiate() as HomingMissile
	add_child(missile)

	var dummy_target := _create_test_enemy(Vector2(200, 0))
	add_child(dummy_target)

	var ctx := HitContext.new()
	ctx.attacker = player
	ctx.raw_damage = 50.0
	ctx.final_damage = 50.0

	missile.setup(Vector2.ZERO, Vector2.RIGHT, ctx, dummy_target)
	assert(missile.flight_direction.is_equal_approx(Vector2.RIGHT), "El misil debe iniciar orientado hacia el target")

	# Simulamos que el enemigo esquiva moviéndose a (200, 300)
	dummy_target.global_position = Vector2(200, 300)

	# Procesar un frame de vuelo
	missile._process(0.1)

	# El misil NO debe haber cambiado de dirección hacia la nueva posición del enemigo (vuelo recto estricto)
	assert(missile.current_velocity.normalized().is_equal_approx(Vector2.RIGHT), "El misil debe mantener estrictamente su trayectoria recta (turn_rate = 0.0)")

	# Colocar un obstáculo/enemigo en la trayectoria recta (en x = 120)
	var obstacle_enemy := _create_test_enemy(Vector2(120, 0))
	add_child(obstacle_enemy)

	# El misil avanza hasta impactar al obstáculo
	missile.global_position = Vector2(115, 0)
	missile._process(0.02)

	assert(missile.has_exploded, "El misil debe haber detonado al colisionar con el obstáculo en su trayectoria")
	assert(obstacle_enemy.current_health < 500.0, "El enemigo en la trayectoria debe haber recibido daño de la explosión")

	dummy_target.queue_free()
	obstacle_enemy.queue_free()
	player.queue_free()

	print("  ✓ Misil: vuelo recto estricto y detonación por impacto verificado")

	print("\n==========================================")
	print("[PASS] ALL 5 AUTO-AIMED PASSIVE TESTS PASSED!")
	print("==========================================\n")
	get_tree().quit(0)

func _create_test_player() -> Player:
	var p: Player = Player.new()
	var cdata := CharacterData.new()
	cdata.character_id = &"nova"
	cdata.pickup_radius = 120.0
	p.character_data = cdata
	p.stats.initialize(cdata)

	var vp := Polygon2D.new(); vp.name = "VisualPlaceholder"; p.add_child(vp)
	var hb := Polygon2D.new(); hb.name = "HitboxCore"; p.add_child(hb)
	var wc := WeaponController.new(); wc.name = "WeaponController"; p.add_child(wc)
	wc.player = p
	return p



func _create_test_enemy(pos: Vector2) -> CharacterBody2D:
	var e := CharacterBody2D.new()
	e.add_to_group("enemies")
	e.set_script(load("res://scenes/combat/enemies/enemy_base.gd"))
	e.global_position = pos
	var col := CollisionShape2D.new(); col.name = "CollisionShape2D"; e.add_child(col)
	e.current_health = 500.0
	e.max_health = 500.0
	return e

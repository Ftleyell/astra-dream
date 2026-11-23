extends Node2D

func _ready() -> void:
	print("\n=======================================================")
	print("🟢 TEST SUITE: DAMAGE ACCUMULATOR & TERMINAL GREEN")
	print("=======================================================\n")

	test_terminal_green_colors()
	test_oneshot_survival_and_linger()

	print("\n=======================================================")
	print("🎉 TODOS LOS TESTS DE DAMAGE ACCUMULATOR PASARON EXITOSAMENTE!")
	print("=======================================================\n")
	get_tree().quit(0)

func test_assert(cond: bool, msg: String) -> void:
	if not cond:
		push_error("FALLÓ: " + msg)
		print("  ✗ " + msg)
		get_tree().quit(1)
	else:
		print("  ✓ " + msg)

func test_terminal_green_colors() -> void:
	print("[1/2] Verificando colores verde terminal y acumulación...")
	var acc_scene := preload("res://scenes/combat/enemies/damage_accumulator.tscn")
	var dummy_enemy := Node2D.new()
	add_child(dummy_enemy)
	
	var acc: DamageAccumulator = acc_scene.instantiate() as DamageAccumulator
	dummy_enemy.add_child(acc)
	
	test_assert(DamageAccumulator.COLOR_TERMINAL_GREEN.g > 0.9 and DamageAccumulator.COLOR_TERMINAL_GREEN.r < 0.4, "Color base debe ser verde terminal")
	test_assert(DamageAccumulator.COLOR_TERMINAL_CRIT.g > 0.9, "Color crítico debe ser verde terminal brillante")
	
	acc.register_hit(45.0, false)
	test_assert(acc.visible, "Debe ser visible tras impacto")
	test_assert(acc.label.text == "45", "Debe mostrar '45' de daño acumulado")
	var normal_color: Color = acc.label.get_theme_color("font_color")
	test_assert(normal_color == DamageAccumulator.COLOR_TERMINAL_GREEN, "Color de fuente normal debe ser verde terminal")
	
	acc.register_hit(55.0, true)
	test_assert(acc.label.text == "100", "Debe acumular daño a '100'")
	var crit_color: Color = acc.label.get_theme_color("font_color")
	test_assert(crit_color == DamageAccumulator.COLOR_TERMINAL_CRIT, "Color de fuente crítico debe ser verde terminal lima")

	dummy_enemy.queue_free()

func test_oneshot_survival_and_linger() -> void:
	print("[2/2] Verificando supervivencia (linger) en caso de Oneshot...")
	var drone_scene := preload("res://scenes/combat/enemies/enemy_drone.tscn")
	var enemy = drone_scene.instantiate()
	add_child(enemy)

	var acc: DamageAccumulator = enemy.get_node_or_null("DamageAccumulator") as DamageAccumulator
	test_assert(acc != null, "Enemy drone debe poseer DamageAccumulator")

	# Oneshot fatal de 500 de daño
	enemy.take_damage(500.0)
	
	test_assert(enemy.is_dying, "El enemigo debe estar muriendo tras oneshot")
	test_assert(acc.is_dying_linger, "DamageAccumulator debe entrar en modo is_dying_linger")
	test_assert(acc.visible, "DamageAccumulator debe PERMANECER VISIBLE tras oneshot")
	test_assert(acc.label.text == "500", "DamageAccumulator debe mostrar el número de daño '500' en pantalla")
	test_assert(acc.modulate.a > 0.8, "Opacidad debe mantenerse visible para que el jugador lo lea")
	test_assert(acc.get_parent() != enemy, "DamageAccumulator debe desacoplarse del enemigo para no morir con él")

	enemy.queue_free()

extends Node

func _assert_check(cond: bool, msg: String) -> void:
	if not cond:
		printerr("[FAIL] Assertion failed: " + msg)
		get_tree().quit(1)
		assert(false, msg)

func _ready() -> void:
	print("\n==========================================")
	print("[TEST] Testing Planet Spawner Separation & Respecting Space...")
	print("==========================================")

	var spawner := PlanetSpawner.new()
	spawner.initial_discovery_bonus = false
	add_child(spawner)

	# 1. Verificar configuración de distancia mínima
	_assert_check(spawner.min_planet_distance >= 2000.0, "La distancia mínima de separación debe ser al menos 2000 px")
	print("  ✓ min_planet_distance = %f px verificado" % spawner.min_planet_distance)

	# 2. Verificar función de validación de posición con planeta existente
	var planet_a: Planet = spawner._instantiate_planet_at(Vector2(5000.0, 5000.0))
	_assert_check(is_instance_valid(planet_a), "El planeta A debe ser instanciado correctamente")
	_assert_check(spawner.active_planets.has(planet_a), "Planeta A debe registrarse en active_planets")

	# Posición a 500 px (solapado directo) -> inválida
	var close_pos := Vector2(5000.0, 5500.0)
	_assert_check(not spawner._is_position_valid_for_planet(close_pos), "Posición a 500px de un planeta debe ser inválida")

	# Posición a 1950 px (< 2000 px) -> inválida
	var border_close_pos := Vector2(5000.0, 6950.0)
	_assert_check(not spawner._is_position_valid_for_planet(border_close_pos), "Posición a 1950px (<2000px) debe ser inválida")

	# Posición a 2050 px (> 2000 px) -> válida
	var valid_pos := Vector2(5000.0, 7050.0)
	_assert_check(spawner._is_position_valid_for_planet(valid_pos), "Posición a 2050px (>2000px) debe ser válida")
	print("  ✓ Validación de distancias espaciales con _is_position_valid_for_planet verificada")

	# 3. Probar redirección por abanico angular cuando el frente está bloqueado
	var dummy_player := CharacterBody2D.new()
	dummy_player.name = "DummyPlayer"
	dummy_player.add_to_group("player")
	dummy_player.global_position = Vector2(0.0, 0.0)
	dummy_player.velocity = Vector2(200.0, 0.0) # Avanzando hacia la derecha (0 rad)
	add_child(dummy_player)
	spawner.player = dummy_player

	# Colocar un planeta de bloqueo justo adelante en la proyección directa (1600 px a la derecha)
	var obstacle_planet: Planet = spawner._instantiate_planet_at(Vector2(1600.0, 0.0))
	_assert_check(is_instance_valid(obstacle_planet), "Planeta obstáculo debe existir")

	# Invocar _spawn_planet_ahead(): debe usar un ángulo del abanico alternativo para no solapar
	var spawned := spawner._spawn_planet_ahead()
	_assert_check(spawned, "El generador debe encontrar un ángulo libre alternativo en el abanico")

	var new_planet: Node2D = spawner.active_planets.back()
	_assert_check(is_instance_valid(new_planet) and new_planet != obstacle_planet, "Debe haberse creado un nuevo planeta")
	var dist_to_obstacle := new_planet.global_position.distance_to(obstacle_planet.global_position)
	_assert_check(dist_to_obstacle >= spawner.min_planet_distance, "El nuevo planeta (%s) debe estar a >= 2000 px del obstáculo (dist: %f)" % [new_planet.global_position, dist_to_obstacle])
	print("  ✓ Abanico de ángulos alternativos resolvió el spawn evitando el planeta frontal (distancia: %.1f px >= 2000 px)" % dist_to_obstacle)

	# 4. Probar que si todos los ángulos están bloqueados, se aplaza sin generar solapamiento
	var blocking_planets: Array[Planet] = []
	var dist_steps: Array[float] = [1600.0, 2000.0, 2400.0]
	for i: int in range(16):
		var ang: float = (TAU / 16.0) * float(i)
		for d: float in dist_steps:
			var b_pos: Vector2 = dummy_player.global_position + Vector2(cos(ang), sin(ang)) * d
			var bp: Planet = spawner._instantiate_planet_at(b_pos)
			if bp:
				blocking_planets.append(bp)

	# Limpiar active_planets para no exceder max_active_planets pero mantener los nodos en el árbol (grupo "planets")
	spawner.active_planets.clear()

	var blocked_spawn := spawner._spawn_planet_ahead()
	_assert_check(not blocked_spawn, "No debe spawnear cuando todo el entorno está saturado de planetas dentro de 2000px")
	print("  ✓ Entorno saturado aplaza correctamente el spawn sin generar planetas solapados")

	print("\n==========================================")
	print("[PASS] ALL PLANET SPACING TESTS PASSED!")
	print("==========================================\n")
	get_tree().quit(0)

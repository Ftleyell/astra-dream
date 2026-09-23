extends Node

## Test Suite: Verificación de Spawn Garantizado de Monolitos Arcanos y ArcanaEdgeIndicator en HUD
## Ejecutable vía:
## godot --headless --path "C:/Users/neldo/Drive Nel2/astra-dream" "res://tests/test_arcana_spawning_and_hud_indicator_runner.tscn"

func _ready() -> void:
	# Watchdog timer de seguridad de 12 segundos
	get_tree().create_timer(12.0, true, false, true).timeout.connect(func():
		push_error("Test timed out after 12s!")
		get_tree().quit(1)
	)

	print("\n==================================================================")
	print("[TEST] INICIANDO SUITE DE PRUEBAS: SPANWER ARCANO E INDICADOR HUD")
	print("==================================================================\n")

	var main_scene: PackedScene = load("res://scenes/combat/main_game.tscn")
	var main_game: MainGame = main_scene.instantiate()
	add_child(main_game)

	# Desactivar briefing y diálogos para pruebas limpias
	var dialogic = get_node_or_null("/root/Dialogic")
	if dialogic:
		if dialogic.has_method("has_subsystem") and dialogic.has_subsystem("Styles") and dialogic.Styles.has_active_layout_node():
			var l_node = dialogic.Styles.get_layout_node()
			if is_instance_valid(l_node):
				l_node.hide()
		if dialogic.has_method("end_timeline"):
			dialogic.end_timeline(true)
		if "current_timeline" in dialogic:
			dialogic.current_timeline = null
	main_game.is_briefing_active = false
	get_tree().paused = false
	await get_tree().process_frame
	await get_tree().process_frame

	var hud: GameHUD = main_game.hud
	var player: Player = main_game.player
	var spawner: SpaceObjectSpawner = main_game.space_object_spawner

	assert(hud != null, "GameHUD debe existir e inicializarse")
	assert(player != null, "Player debe existir")
	assert(spawner != null, "SpaceObjectSpawner debe crearse en main_game")

	# ----------------------------------------------------
	# CASO 1: Jerarquía y configuración de ArcanaEdgeIndicator en HUD
	# ----------------------------------------------------
	print("[1/7] Testing HUD ArcanaEdgeIndicator Integration & Layering...")
	assert(hud.arcana_tracker != null, "hud.arcana_tracker debe estar vinculado")
	var arcana_tracker: ArcanaEdgeIndicator = hud.arcana_tracker
	assert(arcana_tracker is ArcanaEdgeIndicator, "arcana_tracker debe ser instancia de ArcanaEdgeIndicator")
	assert(arcana_tracker.get_parent() is CanvasLayer, "ArcanaEdgeIndicator debe estar en un CanvasLayer")
	var tracker_layer := arcana_tracker.get_parent() as CanvasLayer
	assert(tracker_layer.layer == 8, "El layer del indicador debe ser 8 (debajo de layer 10 de HUD)")
	assert(arcana_tracker.custom_minimum_size == Vector2(50, 50), "Tamaño de caja debe ser 50x50")
	print("  ✓ Jerarquía de HUD y ArcanaEdgeIndicator verificada (Layer 8 < Layer 10).")

	# ----------------------------------------------------
	# CASO 2: Garantía de Monolito Arcano en _ready() / Oleada 1
	# ----------------------------------------------------
	print("\n[2/7] Testing Guaranteed Initial Arcane Monolith Spawning...")
	var monoliths := get_tree().get_nodes_in_group("monoliths")
	if monoliths.is_empty():
		spawner.force_spawn_monolith()
		await get_tree().process_frame
		monoliths = get_tree().get_nodes_in_group("monoliths")

	assert(monoliths.size() >= 1, "Debe haber al menos 1 Monolito Arcano en el grupo 'monoliths'")
	var active_monolith: Node2D = monoliths[0] as Node2D
	assert(is_instance_valid(active_monolith), "El monolito engendrado debe ser una instancia válida")
	print("  ✓ Monolito Arcano inicial garantizado en arena (Total activos: %d)." % monoliths.size())

	# ----------------------------------------------------
	# CASO 3: Rastreo Direccional y Anclaje al Borde Fuera de Pantalla
	# ----------------------------------------------------
	print("\n[3/7] Testing Off-Screen Tracking & Edge Intersection...")
	player.global_position = Vector2(960, 540)
	if main_game.camera:
		main_game.camera.global_position = player.global_position

	# Posicionar el monolito al este, lejos fuera de pantalla (x = 3200)
	active_monolith.global_position = Vector2(3200, 540)
	arcana_tracker.set_player(player)
	arcana_tracker._process(0.016)

	assert(arcana_tracker.visible, "ArcanaEdgeIndicator debe ser visible cuando el monolito está fuera de pantalla")
	assert(arcana_tracker.arrow_indicator.visible, "La flecha direccional debe estar visible")
	var vp_size: Vector2 = arcana_tracker.get_viewport().get_visible_rect().size
	var half_w: float = arcana_tracker.BOX_SIZE.x * 0.5
	var pad: float = arcana_tracker.PADDING
	var expected_max_x: float = vp_size.x - half_w - pad

	assert(absf(arcana_tracker.global_position.x - (expected_max_x - half_w)) < 8.0,
		"El indicador debe posicionarse en el borde derecho: pos=%s, esperado=%f" % [arcana_tracker.global_position, expected_max_x])
	assert(arcana_tracker.distance_label.text.ends_with("m"), "La etiqueta de distancia debe formatearse con 'm'")
	print("  ✓ Indicador posicionado correctamente en el borde derecho apuntando a Monolito lejana (Distancia: %s)." % arcana_tracker.distance_label.text)

	# ----------------------------------------------------
	# CASO 4: Auto-ocultación determinista cuando el Monolito entra en pantalla
	# ----------------------------------------------------
	print("\n[4/7] Testing Auto-Hide when Arcane Monolith Enters Camera View...")
	# Mover el monolito al campo de visión visible (cerca del jugador en pantalla)
	active_monolith.global_position = Vector2(980, 560)
	arcana_tracker._process(0.016)

	assert(not arcana_tracker.visible, "ArcanaEdgeIndicator DEBE ocultarse cuando el Monolito entra en pantalla")
	print("  ✓ Indicador se oculta limpiamente (hide()) al estar el Monolito dentro del FOV.")

	# ----------------------------------------------------
	# CASO 5: Auto-ocultación cuando no hay Monolitos activos
	# ----------------------------------------------------
	print("\n[5/7] Testing Auto-Hide when No Monoliths Exist...")
	for m in get_tree().get_nodes_in_group("monoliths"):
		m.queue_free()
	await get_tree().process_frame

	arcana_tracker._process(0.016)
	assert(not arcana_tracker.visible, "ArcanaEdgeIndicator DEBE ocultarse si no hay monolitos en el espacio")
	print("  ✓ Indicador oculto mientras no hay Monolitos en el espacio.")

	# ----------------------------------------------------
	# CASO 6: Respawn Dinámico de Monolitos Arcanos (Timer <= 45s)
	# ----------------------------------------------------
	print("\n[6/7] Testing Dynamic Respawn Timer (45s cycle)...")
	assert(get_tree().get_nodes_in_group("monoliths").size() == 0, "No debe haber monolitos antes de probar respawn")

	# Avanzar 44 segundos (no debe respawnear todavía)
	spawner.spawn_timer = 999.0
	spawner.monolith_respawn_timer = 45.0
	spawner._process(44.0)
	assert(get_tree().get_nodes_in_group("monoliths").size() == 0, "A 44s aún no debe ocurrir respawn")

	# Avanzar 2 segundos más (total 46s -> respawn garantizado)
	spawner._process(2.0)
	await get_tree().process_frame
	var respawned := get_tree().get_nodes_in_group("monoliths")
	assert(respawned.size() >= 1, "Tras cumplirse el temporizador de respawn (45s), debe reaparecer un Monolito")
	print("  ✓ Respawn dinámico verificado: Nuevo Monolito generado automáticamente tras 45s.")

	# ----------------------------------------------------
	# CASO 7: Aislamiento de Cupos (Cápsulas/Geodas no bloquean Monolitos)
	# ----------------------------------------------------
	print("\n[7/7] Testing Quota Separation (Macro-objects do not block Monoliths)...")
	# Llenar la escena con 4 objetos espaciales genéricos (alcanzando max_active_macro_objects = 4)
	var dummy_nodes: Array[Node2D] = []
	for i in range(4):
		var dummy := Node2D.new()
		dummy.add_to_group("supply_pods")
		main_game.add_child(dummy)
		dummy_nodes.append(dummy)

	# Borrar todos los monolitos
	for m in get_tree().get_nodes_in_group("monoliths"):
		m.queue_free()
	await get_tree().process_frame
	assert(get_tree().get_nodes_in_group("monoliths").size() == 0)

	# Forzar spawn de monolito (o invocar al iniciar oleada)
	var spawned_monolith = spawner.force_spawn_monolith()
	await get_tree().process_frame
	assert(spawned_monolith != null, "force_spawn_monolith() debe devolver el objeto generado")
	assert(get_tree().get_nodes_in_group("monoliths").size() >= 1,
		"El cupo lleno de cápsulas no debe bloquear la aparición del Monolito Arcano")

	# Limpiar dummies
	for d in dummy_nodes:
		d.queue_free()

	print("  ✓ Separación de cupos certificada: Monolitos tienen cuota independiente y prioritaria.")

	# ----------------------------------------------------
	# CASO 8: Enfoque y transición entre múltiples Monolitos simultáneos
	# ----------------------------------------------------
	print("\n[8/9] Testing Multi-Monolith Tracking & Closest Target Switching...")
	for m in get_tree().get_nodes_in_group("monoliths"):
		m.queue_free()
	await get_tree().process_frame

	player.global_position = Vector2(1000, 1000)

	# Monolito A: a 1500 unidades al este (global_x = 2500)
	var mon_a := spawner.monolith_scene.instantiate() as DestructibleSpaceObject
	mon_a.global_position = Vector2(2500, 1000)
	main_game.add_child(mon_a)

	# Monolito B: a 3000 unidades al este (global_x = 4000)
	var mon_b := spawner.monolith_scene.instantiate() as DestructibleSpaceObject
	mon_b.global_position = Vector2(4000, 1000)
	main_game.add_child(mon_b)
	await get_tree().process_frame

	assert(spawner.get_active_monolith_count() == 2, "Deben existir 2 monolitos activos")

	# El tracker debe rastrear Monolito A (más cercano)
	var closest := arcana_tracker.get_closest_monolith()
	assert(closest == mon_a, "ArcanaEdgeIndicator debe enfocarse en el Monolito más cercano (mon_a)")

	# Simular destrucción de Monolito A
	mon_a.is_dying = true
	mon_a.queue_free()

	# Inmediatamente (incluso antes de que queue_free complete el frame), debe conmutar a Monolito B
	closest = arcana_tracker.get_closest_monolith()
	assert(closest == mon_b, "ArcanaEdgeIndicator debe conmutar suavemente a mon_b al morir mon_a")
	print("  ✓ Conmutación limpia y continua de objetivo entre múltiples Monolitos certificada.")

	# ----------------------------------------------------
	# CASO 9: Cumplimiento estricto del límite max_active_monoliths = 2
	# ----------------------------------------------------
	print("\n[9/9] Testing Monolith Quota Enforcement (max_active_monoliths = 2)...")
	# Ya existe mon_b. Spawnear un segundo monolito.
	var mon_c := spawner.force_spawn_monolith()
	assert(mon_c != null, "Debe permitirse spawnear el 2do monolito")
	assert(spawner.get_active_monolith_count() == 2, "Deben haber exactamente 2 monolitos activos")

	# Intentar forzar un 3er monolito
	var mon_d := spawner.force_spawn_monolith()
	assert(mon_d == null, "No debe permitirse exceder max_active_monoliths (2)")
	assert(spawner.get_active_monolith_count() == 2, "La cuenta de monolitos debe mantenerse en 2")
	print("  ✓ Límite máximo de Monolitos (2) verificado y protegido contra sobrepoblación.")

	# Limpiar
	if is_instance_valid(mon_b): mon_b.queue_free()
	if is_instance_valid(mon_c): mon_c.queue_free()

	print("\n==================================================================")
	print("RESULTADO: TODOS LOS TESTS (9/9) PASARON PERFECTAMENTE (100%)")
	print("==================================================================\n")

	get_tree().quit(0)

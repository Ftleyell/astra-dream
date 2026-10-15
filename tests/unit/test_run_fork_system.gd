class_name TestRunForkSystemSuite
extends BaseTestSuite

## TestRunForkSystemSuite.gd
## Suite de pruebas unitarias para el Sistema de Bifurcaciones de Run (In-Run Decisions).

const RunEffectScript = preload("res://core/data/run_forks/run_effect.gd")
const RunForkOptionDataScript = preload("res://core/data/run_forks/run_fork_option_data.gd")
const BiomeChangeRunEffectScript = preload("res://core/data/run_forks/effects/biome_change_run_effect.gd")
const EnemySpawnRunEffectScript = preload("res://core/data/run_forks/effects/enemy_spawn_run_effect.gd")
const PlayerStatRunEffectScript = preload("res://core/data/run_forks/effects/player_stat_run_effect.gd")
const SatelliteSpawnRunEffectScript = preload("res://core/data/run_forks/effects/satellite_spawn_run_effect.gd")
const GenericPropertyRunEffectScript = preload("res://core/data/run_forks/effects/generic_property_run_effect.gd")

const RunModifierManagerScript = preload("res://scenes/combat/systems/run_modifier_manager.gd")
const CombatForkDirectorScript = preload("res://scenes/combat/directors/combat_fork_director.gd")
const RunForkOverlayScript = preload("res://scenes/combat/ui/run_fork_overlay.gd")
const ForkChoiceCardScript = preload("res://scenes/combat/ui/components/fork_choice_card.gd")
const CombatContextScript = preload("res://scenes/combat/systems/combat_context.gd")

class MockPlayerWithStats extends CharacterBody2D:
	var stats: CharacterStats = null


func _ready() -> void:
	super._ready()
	call_deferred("_run_all_tests")


func _run_all_tests() -> void:
	print("--- INICIANDO TEST SUITE: RUN FORK SYSTEM ---")

	test_fork_choice_draw_weighted()
	test_distance_threshold_speed_normalization()
	test_run_modifier_manager_lifecycle()
	test_biome_change_effect_execution()
	test_culling_offscreen_enemies()
	test_quadrant_vector_mapping()
	test_fork_choice_card_focus_scaling()
	test_generic_property_effect()
	test_player_stat_run_effect_application()
	test_wave_pipeline_drain_and_fork_integration()
	test_starter_tres_resources_validity()
	test_duplicate_card_independent_lifecycle()
	test_null_choice_safe_fallback()
	test_cinematic_brake_with_locomotion_controller()

	print("--- TODAS LAS PRUEBAS DE RUN FORK SYSTEM COMPLETADAS EXITOSAMENTE ---")
	pass_suite("TestRunForkSystem completado con 14/14 pruebas exitosas.")



func test_fork_choice_draw_weighted() -> void:
	var director := CombatForkDirectorScript.new()
	add_child(director)

	var opt1 := RunForkOptionDataScript.new()
	opt1.id = &"early_opt"
	opt1.min_wave = 1
	opt1.max_wave = 3
	opt1.weight = 100.0

	var opt2 := RunForkOptionDataScript.new()
	opt2.id = &"late_opt"
	opt2.min_wave = 5
	opt2.max_wave = 10
	opt2.weight = 50.0

	var opt3 := RunForkOptionDataScript.new()
	opt3.id = &"anytime_opt"
	opt3.min_wave = 1
	opt3.max_wave = 999
	opt3.weight = 80.0

	director.available_forks = [opt1, opt2, opt3]

	# En oleada 2, opt2 no debe aparecer
	var wave2_draw: Array[RunForkOptionData] = director.draw_fork_choices(2, 2)
	assert_true(wave2_draw.size() == 2, "El sorteo de 2 opciones debe retornar 2 cartas.")
	for drawn in wave2_draw:
		assert_true(drawn.id != &"late_opt", "late_opt no debe aparecer en oleada 2 (min_wave=5).")

	# En oleada 7, opt1 no debe aparecer
	var wave7_draw: Array[RunForkOptionData] = director.draw_fork_choices(2, 7)
	assert_true(wave7_draw.size() == 2, "El sorteo de 2 opciones en oleada 7 debe retornar 2 cartas.")
	for drawn in wave7_draw:
		assert_true(drawn.id != &"early_opt", "early_opt no debe aparecer en oleada 7 (max_wave=3).")

	director.queue_free()
	print("[OK] test_fork_choice_draw_weighted")


func test_distance_threshold_speed_normalization() -> void:
	var director := CombatForkDirectorScript.new()
	director.decision_time = 0.8

	# D_threshold = T_decision * V_player_speed
	var dist_200: float = director.calculate_threshold_distance(200.0)
	assert_true(is_equal_approx(dist_200, 160.0), "Velocidad 200 con T=0.8 debe dar D=160. Obtenido: %f" % dist_200)

	var dist_350: float = director.calculate_threshold_distance(350.0)
	assert_true(is_equal_approx(dist_350, 280.0), "Velocidad 350 con T=0.8 debe dar D=280. Obtenido: %f" % dist_350)

	var dist_500: float = director.calculate_threshold_distance(500.0)
	assert_true(is_equal_approx(dist_500, 400.0), "Velocidad 500 con T=0.8 debe dar D=400. Obtenido: %f" % dist_500)

	director.queue_free()
	print("[OK] test_distance_threshold_speed_normalization")


func test_run_modifier_manager_lifecycle() -> void:
	var rmm := RunModifierManagerScript.new()
	add_child(rmm)

	var context := CombatContextScript.new()
	rmm.setup_subsystem(context)

	# 1. Modificador permanente: +40% spawns (-1 waves)
	var perm_opt := RunForkOptionDataScript.new()
	perm_opt.id = &"perm_spawn"
	var perm_eff := EnemySpawnRunEffectScript.new()
	perm_eff.duration_waves = -1
	perm_eff.spawn_multiplier = 1.4
	perm_opt.effects = [perm_eff]

	# 2. Modificador temporal: +50% oro por 2 oleadas
	var temp_opt := RunForkOptionDataScript.new()
	temp_opt.id = &"temp_gold"
	var temp_eff := EnemySpawnRunEffectScript.new()
	temp_eff.duration_waves = 2
	temp_eff.gold_multiplier = 1.5
	temp_opt.effects = [temp_eff]

	rmm.register_fork_choice(perm_opt)
	rmm.register_fork_choice(temp_opt)

	assert_true(is_equal_approx(rmm.get_total_float_modifier(&"spawn_multiplier", 1.0), 1.4), "Spawn multiplier debe ser 1.4.")
	assert_true(is_equal_approx(rmm.get_total_float_modifier(&"gold_multiplier", 1.0), 1.5), "Gold multiplier debe ser 1.5.")

	# Oleada 1 completada: el temporal debe tener 1 oleada restante
	rmm.on_wave_completed(1)
	assert_true(is_equal_approx(rmm.get_total_float_modifier(&"spawn_multiplier", 1.0), 1.4), "Spawn multiplier permanente debe seguir 1.4 tras oleada 1.")
	assert_true(is_equal_approx(rmm.get_total_float_modifier(&"gold_multiplier", 1.0), 1.5), "Gold multiplier temporal debe seguir activo tras oleada 1.")

	# Oleada 2 completada: el temporal expira
	rmm.on_wave_completed(2)
	assert_true(is_equal_approx(rmm.get_total_float_modifier(&"spawn_multiplier", 1.0), 1.4), "Spawn multiplier permanente debe seguir activo.")
	assert_true(is_equal_approx(rmm.get_total_float_modifier(&"gold_multiplier", 1.0), 1.0), "Gold multiplier debe haberse revertido a 1.0 tras expirar.")

	# Test de serialización y preservación de resource_path tras duplicate(false)
	var disk_fork: RunForkOptionData = load("res://resources/run_forks/starter/fork_hostile_storm.tres") as RunForkOptionData
	if disk_fork:
		rmm.register_fork_choice(disk_fork)
	var serialized: Array[Dictionary] = rmm.serialize_active_modifiers()
	assert_true(serialized.size() >= 2, "Debe serializar los modificadores activos.")
	var found_disk_path: bool = false
	for entry: Dictionary in serialized:
		if str(entry.get("resource_path", "")) == "res://resources/run_forks/starter/fork_hostile_storm.tres":
			found_disk_path = true
			break
	assert_true(found_disk_path, "serialize_active_modifiers debe preservar resource_path del recurso .tres original tras duplicate(false).")

	rmm.queue_free()
	print("[OK] test_run_modifier_manager_lifecycle")


func test_biome_change_effect_execution() -> void:
	var eff := BiomeChangeRunEffectScript.new()
	eff.target_region_id = &"hyperion_forge"
	eff.blend_duration = 2.5

	# Mock de SpaceEnvironmentHost
	var mock_host := Node.new()
	var region_called: Array[Variant] = []
	mock_host.set_script(load("res://tests/unit/mock_env_host.gd") if ResourceLoader.exists("res://tests/unit/mock_env_host.gd") else null)

	var context := CombatContextScript.new()
	# Si no hay script mock, usar Object dinámico
	var mock_caller := RefCounted.new()
	var test_node := Node.new()
	test_node.set_meta(&"region_id", &"")
	test_node.set_meta(&"duration", 0.0)
	
	# Usar context.environment_host dinámico
	var env_dummy := Node.new()
	# Añadir método dinámico usando un script inline simple si es necesario
	context.environment_host = env_dummy

	# Ejecutar apply_effect: no debe generar errores ni crasheos
	eff.apply_effect(context)
	eff.apply_effect(null) # Null safety

	env_dummy.queue_free()
	print("[OK] test_biome_change_effect_execution")


func test_culling_offscreen_enemies() -> void:
	var spawner_scene := Node2D.new()
	add_child(spawner_scene)

	var e_inside := Node2D.new()
	e_inside.add_to_group(&"enemies")
	e_inside.global_position = Vector2(100.0, 100.0)
	spawner_scene.add_child(e_inside)

	var e_outside := Node2D.new()
	e_outside.add_to_group(&"enemies")
	e_outside.global_position = Vector2(5000.0, 5000.0)
	spawner_scene.add_child(e_outside)

	var cam_rect := Rect2(Vector2.ZERO, Vector2(1920.0, 1080.0))
	var margin := 120.0
	var expanded := cam_rect.grow(margin)

	assert_true(expanded.has_point(e_inside.global_position), "e_inside debe estar dentro del viewport expandido.")
	assert_true(not expanded.has_point(e_outside.global_position), "e_outside debe estar fuera del viewport expandido.")

	# Simular culling
	var culled: int = 0
	for enemy in [e_inside, e_outside]:
		if not expanded.has_point(enemy.global_position):
			enemy.queue_free()
			culled += 1

	assert_true(culled == 1, "Debe haberse purgado exactamente 1 enemigo fuera de pantalla.")
	assert_true(not e_inside.is_queued_for_deletion(), "e_inside no debe ser purgado.")
	assert_true(e_outside.is_queued_for_deletion(), "e_outside debe quedar marcado para borrado.")

	spawner_scene.queue_free()
	print("[OK] test_culling_offscreen_enemies")


func test_quadrant_vector_mapping() -> void:
	# Q0: Top-Right (x > 0, y < 0)
	var q0: int = RunForkOverlayScript.get_quadrant_index_for_vector(Vector2(100.0, -80.0))
	assert_true(q0 == 0, "Vector (100, -80) debe pertenecer al Cuadrante 0 (Top-Right). Obtenido: %d" % q0)

	# Q1: Top-Left (x < 0, y < 0)
	var q1: int = RunForkOverlayScript.get_quadrant_index_for_vector(Vector2(-120.0, -90.0))
	assert_true(q1 == 1, "Vector (-120, -90) debe pertenecer al Cuadrante 1 (Top-Left). Obtenido: %d" % q1)

	# Q2: Bottom-Left (x < 0, y > 0)
	var q2: int = RunForkOverlayScript.get_quadrant_index_for_vector(Vector2(-70.0, 140.0))
	assert_true(q2 == 2, "Vector (-70, 140) debe pertenecer al Cuadrante 2 (Bottom-Left). Obtenido: %d" % q2)

	# Q3: Bottom-Right (x > 0, y > 0)
	var q3: int = RunForkOverlayScript.get_quadrant_index_for_vector(Vector2(60.0, 110.0))
	assert_true(q3 == 3, "Vector (60, 110) debe pertenecer al Cuadrante 3 (Bottom-Right). Obtenido: %d" % q3)

	print("[OK] test_quadrant_vector_mapping")


func test_fork_choice_card_focus_scaling() -> void:
	var card := ForkChoiceCardScript.new()
	add_child(card)

	# Neutral
	card.set_focus_ratio(0.0)
	assert_true(is_equal_approx(card.scale.x, 1.0) and is_equal_approx(card.scale.y, 1.0), "Ratio 0 debe fijar escala 1.0.")

	# Enfoque máximo: 1.25x
	card.set_focus_ratio(1.0)
	assert_true(is_equal_approx(card.scale.x, 1.25) and is_equal_approx(card.scale.y, 1.25), "Ratio 1.0 debe fijar escala 1.25. Obtenido: %f" % card.scale.x)
	assert_true(is_equal_approx(card.modulate.a, 1.0), "Ratio 1.0 debe mantener opacidad 1.0.")

	# Desvío máximo: 0.70x y opacidad 0.40
	card.set_focus_ratio(-1.0)
	assert_true(is_equal_approx(card.scale.x, 0.70) and is_equal_approx(card.scale.y, 0.70), "Ratio -1.0 debe fijar escala 0.70. Obtenido: %f" % card.scale.x)
	assert_true(is_equal_approx(card.modulate.a, 0.40), "Ratio -1.0 debe reducir opacidad a 0.40. Obtenido: %f" % card.modulate.a)

	card.queue_free()
	print("[OK] test_fork_choice_card_focus_scaling")


func test_generic_property_effect() -> void:
	var target_obj := Node2D.new()
	target_obj.name = "TestTarget"
	target_obj.set_meta(&"test_stat", 10.0)
	add_child(target_obj)

	var eff1: GenericPropertyRunEffect = GenericPropertyRunEffectScript.new()
	eff1.system_tag = &"main_game"
	eff1.property_key = &"rotation_degrees"
	eff1.value = 45.0
	eff1.operation = GenericPropertyRunEffectScript.Operation.ADD

	var eff2: GenericPropertyRunEffect = GenericPropertyRunEffectScript.new()
	eff2.system_tag = &"main_game"
	eff2.property_key = &"rotation_degrees"
	eff2.value = 2.0
	eff2.operation = GenericPropertyRunEffectScript.Operation.MULTIPLY

	var context := CombatContextScript.new()
	context.main_game = target_obj
	target_obj.rotation_degrees = 15.0

	# Aplicar eff1: rotation_degrees = 15 + 45 = 60
	eff1.apply_effect(context)
	assert_true(is_equal_approx(target_obj.rotation_degrees, 60.0), "GenericProperty ADD debe sumar valor a 60.0. Obtenido: %f" % target_obj.rotation_degrees)

	# Aplicar eff2 superpuesto: (15 + 45) * 2 = 120
	eff2.apply_effect(context)
	assert_true(is_equal_approx(target_obj.rotation_degrees, 120.0), "GenericProperty MULTIPLY superpuesto debe dar 120.0. Obtenido: %f" % target_obj.rotation_degrees)

	# Revertir fuera de orden (eff1 expira primero mientras eff2 sigue activo): 15 * 2 = 30
	eff1.revert_effect(context)
	assert_true(is_equal_approx(target_obj.rotation_degrees, 30.0), "Expiración fuera de orden de eff1 debe recomputar base*2 = 30.0. Obtenido: %f" % target_obj.rotation_degrees)

	# Revertir eff2: vuelve limpiamente al valor base original 15.0
	eff2.revert_effect(context)
	assert_true(is_equal_approx(target_obj.rotation_degrees, 15.0), "GenericProperty revert final debe restaurar a 15.0. Obtenido: %f" % target_obj.rotation_degrees)

	target_obj.queue_free()
	print("[OK] test_generic_property_effect")


func test_player_stat_run_effect_application() -> void:
	var stats := CharacterStats.new()
	stats.set_base_stat(&"move_speed", 200.0)

	var dummy_player := MockPlayerWithStats.new()
	dummy_player.stats = stats

	var context := CombatContextScript.new()
	context.player = dummy_player

	var eff := PlayerStatRunEffectScript.new()
	eff.stat_key = &"move_speed"
	eff.multiplier_bonus = 0.3

	eff.apply_effect(context)
	var buffed_speed: float = stats.get_stat(&"move_speed")
	assert_true(is_equal_approx(buffed_speed, 260.0), "Velocidad buffeada debe ser 260.0 (+30%%). Obtenido: %f" % buffed_speed)

	eff.revert_effect(context)
	var reverted_speed: float = stats.get_stat(&"move_speed")
	assert_true(is_equal_approx(reverted_speed, 200.0), "Velocidad revertida debe ser 200.0. Obtenido: %f" % reverted_speed)

	dummy_player.free()
	print("[OK] test_player_stat_run_effect_application")


func test_wave_pipeline_drain_and_fork_integration() -> void:
	var pipeline := preload("res://scenes/combat/directors/combat_wave_pipeline.gd").new()
	add_child(pipeline)

	var director := CombatForkDirectorScript.new()
	add_child(director)

	var context := CombatContextScript.new()
	var player := CharacterBody2D.new()
	context.player = player
	context.wave_duration = 30.0

	pipeline.setup_pipeline(context, Callable())
	pipeline.register_subsystem(director)
	pipeline.is_pre_round = false
	pipeline.wave_timer = 0.0

	var drain_requested: Array[bool] = [false]
	pipeline.wave_completed_drain_requested.connect(func(_w: int): drain_requested[0] = true)

	pipeline.tick(0.016, false)

	assert_true(drain_requested[0], "CombatWavePipeline debe emitir wave_completed_drain_requested.")
	assert_true(director.current_state == CombatForkDirectorScript.State.DRAINING_WAVE, "Director debe estar en DRAINING_WAVE.")
	assert_true(director.is_blocking_combat(), "Director debe bloquear avance de combate durante wave drain.")

	pipeline.queue_free()
	director.queue_free()
	player.queue_free()
	print("[OK] test_wave_pipeline_drain_and_fork_integration")


func test_starter_tres_resources_validity() -> void:
	var paths: Array[String] = [
		"res://resources/run_forks/starter/fork_hostile_storm.tres",
		"res://resources/run_forks/starter/fork_sector_jump.tres",
		"res://resources/run_forks/starter/fork_hyper_propulsion.tres",
		"res://resources/run_forks/starter/fork_orbital_beacon.tres",
	]
	for p in paths:
		assert_true(ResourceLoader.exists(p), "Recurso %s debe existir." % p)
		var res: RunForkOptionData = load(p) as RunForkOptionData
		assert_true(res != null, "Recurso %s debe cargarse como RunForkOptionData." % p)
		assert_true(res.id != &"", "Recurso %s debe tener un ID válido." % p)
		assert_true(not res.title.is_empty(), "Recurso %s debe tener un título." % p)
		assert_true(res.weight > 0.0, "Recurso %s debe tener peso > 0." % p)
		assert_true(not res.effects.is_empty(), "Recurso %s debe tener al menos un efecto." % p)
	print("[OK] test_starter_tres_resources_validity")


func test_duplicate_card_independent_lifecycle() -> void:
	var rmm := RunModifierManagerScript.new()
	add_child(rmm)

	var context := CombatContextScript.new()
	var stats := CharacterStats.new()
	stats.set_base_stat(&"move_speed", 200.0)
	var player_mock := MockPlayerWithStats.new()
	player_mock.stats = stats
	context.player = player_mock
	rmm.setup_subsystem(context)

	# Carta temporal con 2 oleadas de duracion: +30% velocidad
	var card := RunForkOptionDataScript.new()
	card.id = &"speed_boost"
	var eff := PlayerStatRunEffectScript.new()
	eff.stat_key = &"move_speed"
	eff.multiplier_bonus = 0.3
	eff.duration_waves = 2
	card.effects = [eff]

	# Oleada 1: El jugador elige la carta (duracion: 2 oleadas)
	rmm.register_fork_choice(card)
	var speed_w1: float = stats.get_stat(&"move_speed")
	assert_true(is_equal_approx(speed_w1, 260.0), "Tras pick 1 en W1, velocidad debe ser 260.0 (+30%%). Obtenido: %f" % speed_w1)

	# Final de Oleada 1: pick 1 baja de 2 a 1 oleada restante
	rmm.on_wave_completed(1)
	var speed_after_w1: float = stats.get_stat(&"move_speed")
	assert_true(is_equal_approx(speed_after_w1, 260.0), "Tras completar W1, pick 1 sigue activo (+30%%). Obtenido: %f" % speed_after_w1)

	# Oleada 2: El jugador vuelve a elegir la MISMA carta (duracion: 2 oleadas)
	rmm.register_fork_choice(card)
	# 200 * (1 + 0.3 + 0.3) = 320.0
	var speed_w2: float = stats.get_stat(&"move_speed")
	assert_true(is_equal_approx(speed_w2, 320.0), "Tras pick 2 en W2, velocidad debe acumularse a 320.0 (+60%%). Obtenido: %f" % speed_w2)

	# Final de Oleada 2: pick 1 expira (1 -> 0), pick 2 baja de 2 a 1
	rmm.on_wave_completed(2)
	var speed_after_w2: float = stats.get_stat(&"move_speed")
	assert_true(is_equal_approx(speed_after_w2, 260.0), "Tras expirar pick 1 al fin de W2, pick 2 debe persistir (260.0). Obtenido: %f" % speed_after_w2)

	# Final de Oleada 3: pick 2 expira (1 -> 0)
	rmm.on_wave_completed(3)
	var speed_after_w3: float = stats.get_stat(&"move_speed")
	assert_true(is_equal_approx(speed_after_w3, 200.0), "Tras expirar pick 2 al fin de W3, velocidad debe volver a 200.0. Obtenido: %f" % speed_after_w3)

	player_mock.free()
	rmm.queue_free()
	print("[OK] test_duplicate_card_independent_lifecycle")


func test_null_choice_safe_fallback() -> void:
	var director := CombatForkDirectorScript.new()
	add_child(director)

	var signal_emitted: Array[bool] = [false]
	var received_option: Array[Variant] = [null]
	director.fork_selection_completed.connect(func(opt: RunForkOptionData) -> void:
		signal_emitted[0] = true
		received_option[0] = opt
	)

	# Simular confirmacion con lista vacia
	director.current_choices = []
	director._confirm_choice(0)
	director._process_confirming(0.6)

	assert_true(signal_emitted[0], "fork_selection_completed debe emitirse incluso si choice es null.")
	assert_true(director.current_state == CombatForkDirectorScript.State.IDLE, "Director debe regresar a IDLE tras confirmar.")

	director.queue_free()
	print("[OK] test_null_choice_safe_fallback")


func test_cinematic_brake_with_locomotion_controller() -> void:
	var director := CombatForkDirectorScript.new()
	add_child(director)

	var context := CombatContextScript.new()
	var player := CharacterBody2D.new()
	player.set("locomotion_controller", PlayerLocomotionController.new())
	player.velocity = Vector2(150.0, -100.0)
	context.player = player

	director.setup_director(context)
	director.force_fork_selection()

	assert_true(director.current_state == CombatForkDirectorScript.State.CINEMATIC_BRAKE, "Director debe entrar en CINEMATIC_BRAKE sin crashear.")
	assert_true(player.velocity == Vector2.ZERO, "Velocidad de jugador debe frenarse a Vector2.ZERO.")
	assert_true(director.anchor_position == player.global_position, "Punto de ancla P0 debe coincidir con global_position.")

	director.queue_free()
	player.queue_free()
	print("[OK] test_cinematic_brake_with_locomotion_controller")


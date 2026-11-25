extends BaseTestSuite

## Suite unitaria de producción para RunLaunchRequest y HubProgressionEvaluator.
## Valida biyección de coordenadas ASTR-XXXXXX, sub-semillas aisladas por dominio,
## consumo único de pending request, políticas .tres y máquina de estados de progresión.

const ConfigScript = preload("res://scenes/ui/hub/resources/hub_progression_config.gd")
const DEFAULT_PROGRESSION_CFG: ConfigScript = preload("res://data/hub/default_hub_progression_config.tres")
const EvaluatorScript = preload("res://scenes/ui/hub/components/hub_progression_evaluator.gd")
const RunLaunchRequestScript = preload("res://core/systems/run_launch_request.gd")
const SaveManagerScript = preload("res://core/autoloads/save_manager.gd")


func _ready() -> void:
	timeout_seconds = 10.0
	super._ready()
	_run_tests()


func _run_tests() -> void:
	_test_coordinate_code_bijection()
	_test_subseed_isolation_and_determinism()
	_test_pending_consume_once_and_last_launched()
	_test_progression_config_and_seed_policies()
	_test_progression_evaluator_state_transitions()
	pass_suite("RunLaunchRequest y HubProgressionEvaluator verificados (biyección, sub-semillas, políticas y progresión).")


func _test_coordinate_code_bijection() -> void:
	var samples: Array[int] = [1, 42, 428175, 999999, 123456789, RunLaunchRequestScript.MAX_SEED]
	for s: int in samples:
		var code: String = RunLaunchRequestScript.encode_coordinate_code(s)
		assert_true(code.begins_with("ASTR-") and code.length() == 11, "Código de coordenada debe tener formato ASTR-XXXXXX (%s)" % code)
		var decoded: int = RunLaunchRequestScript.decode_coordinate_code(code)
		assert_true(decoded == s, "Decodificación biyectiva debe devolver %d (obtenido %d)" % [s, decoded])

	assert_true(RunLaunchRequestScript.decode_coordinate_code("  astr-000001  ") == 1, "Debe aceptar minúsculas y espacios")
	assert_true(RunLaunchRequestScript.decode_coordinate_code("428175") == 428175, "Debe aceptar enteros decimales directos")
	assert_true(RunLaunchRequestScript.decode_coordinate_code("INVALIDO!!") == 0, "Debe rechazar códigos inválidos devolviendo 0")
	assert_true(RunLaunchRequestScript.decode_coordinate_code("") == 0, "Debe rechazar texto vacío")


func _test_subseed_isolation_and_determinism() -> void:
	var r1: RunLaunchRequestScript = RunLaunchRequestScript.create(428175, RunLaunchRequestScript.SeedMode.CUSTOM)
	var r2: RunLaunchRequestScript = RunLaunchRequestScript.create(428175, RunLaunchRequestScript.SeedMode.CUSTOM)
	assert_true(r1.cosmos_seed == r2.cosmos_seed, "cosmos_seed debe ser determinista")
	assert_true(r1.run_director_seed == r2.run_director_seed, "run_director_seed debe ser determinista")
	assert_true(r1.run_loot_seed == r2.run_loot_seed, "run_loot_seed debe ser determinista")
	assert_true(r1.cosmos_seed != r1.run_director_seed and r1.cosmos_seed != r1.run_loot_seed and r1.run_director_seed != r1.run_loot_seed, "Las 3 sub-semillas deben estar aisladas por salt distinto")
	assert_true(r1.is_custom_seeded() and r1.get_seed_badge_text() == "[SEEDED]", "CUSTOM debe exponer badge [SEEDED]")

	var auto_req: RunLaunchRequestScript = RunLaunchRequestScript.create(428175, RunLaunchRequestScript.SeedMode.AUTO)
	assert_true(not auto_req.is_custom_seeded() and auto_req.get_seed_badge_text().is_empty(), "AUTO no debe mostrar badge [SEEDED]")


func _test_pending_consume_once_and_last_launched() -> void:
	RunLaunchRequestScript.clear_pending()
	var req: RunLaunchRequestScript = RunLaunchRequestScript.create_from_code("ASTR-0096D3", RunLaunchRequestScript.SeedMode.CUSTOM)
	assert_true(req != null, "create_from_code válido debe construir RunLaunchRequest")
	RunLaunchRequestScript.set_pending(req)
	assert_true(RunLaunchRequestScript.peek_pending() != null, "peek_pending debe ver la solicitud pendiente")

	var consumed: RunLaunchRequestScript = RunLaunchRequestScript.consume_pending()
	assert_true(consumed != null and consumed.master_seed == req.master_seed, "consume_pending debe entregar la solicitud")
	assert_true(RunLaunchRequestScript.consume_pending() == null, "consume_pending debe ser de consumo único")
	var last: RunLaunchRequestScript = RunLaunchRequestScript.get_last_launched()
	assert_true(last != null and last.master_seed == req.master_seed, "get_last_launched debe conservar la última coordenada lanzada")


func _test_progression_config_and_seed_policies() -> void:
	assert_true(DEFAULT_PROGRESSION_CFG != null, "Debe cargar default_hub_progression_config.tres")
	assert_true(DEFAULT_PROGRESSION_CFG.module_rules.size() == 9, "default_hub_progression_config.tres debe definir los 9 módulos")
	assert_true(not DEFAULT_PROGRESSION_CFG.allow_highscores_on_custom_seed, "allow_highscores_on_custom_seed debe ser false por defecto")
	assert_true(not DEFAULT_PROGRESSION_CFG.allow_trophies_on_custom_seed, "allow_trophies_on_custom_seed debe ser false por defecto")

	var auto_req: RunLaunchRequestScript = RunLaunchRequestScript.create(100, RunLaunchRequestScript.SeedMode.AUTO)
	var custom_req: RunLaunchRequestScript = RunLaunchRequestScript.create(100, RunLaunchRequestScript.SeedMode.CUSTOM)
	assert_true(RunLaunchRequestScript.can_record_highscores(auto_req, DEFAULT_PROGRESSION_CFG), "AUTO debe permitir highscores")
	assert_true(RunLaunchRequestScript.can_unlock_trophies(auto_req, DEFAULT_PROGRESSION_CFG), "AUTO debe permitir trofeos")
	assert_true(not RunLaunchRequestScript.can_record_highscores(custom_req, DEFAULT_PROGRESSION_CFG), "CUSTOM debe respetar policy allow_highscores_on_custom_seed=false")
	assert_true(not RunLaunchRequestScript.can_unlock_trophies(custom_req, DEFAULT_PROGRESSION_CFG), "CUSTOM debe respetar policy allow_trophies_on_custom_seed=false")


func _test_progression_evaluator_state_transitions() -> void:
	var bio_before: int = SaveManagerScript.get_biomass()
	var runs_before: int = int(SaveManagerScript.get_career_stats().get("total_runs_played", 0))

	var ev := EvaluatorScript.new() as EvaluatorScript
	ev.setup(DEFAULT_PROGRESSION_CFG)

	ev.evaluate_snapshot(EvaluatorScript.build_preset_snapshot(&"run1"))
	assert_true(ev.get_module_state(&"ignition_ring") == EvaluatorScript.ModuleState.ONLINE, "ignition_ring siempre ONLINE en Run 1")
	assert_true(ev.get_module_state(&"pilot_capsule") == EvaluatorScript.ModuleState.ONLINE, "pilot_capsule siempre ONLINE en Run 1")
	assert_true(ev.get_module_state(&"skins_mirror") == EvaluatorScript.ModuleState.CALIBRATING, "skins_mirror debe iniciar CALIBRATING en Run 1")
	assert_true(ev.get_module_state(&"talents_nexus") == EvaluatorScript.ModuleState.CALIBRATING, "talents_nexus debe iniciar CALIBRATING en Run 1")
	assert_true(ev.get_module_state(&"companions_projector") == EvaluatorScript.ModuleState.CALIBRATING, "companions_projector debe iniciar CALIBRATING en Run 1")
	assert_true(not ev.is_tactical_console_online(), "Consola táctica debe iniciar CALIBRATING en Run 1")

	ev.evaluate_snapshot(EvaluatorScript.build_preset_snapshot(&"post_run1"))
	assert_true(ev.get_module_state(&"skins_mirror") == EvaluatorScript.ModuleState.NEWLY_UNLOCKED, "skins_mirror debe pasar a NEWLY_UNLOCKED al desbloquear skin")
	assert_true(ev.get_module_state(&"talents_nexus") == EvaluatorScript.ModuleState.NEWLY_UNLOCKED, "talents_nexus debe pasar a NEWLY_UNLOCKED tras Run 1")
	assert_true(ev.get_module_state(&"companions_projector") == EvaluatorScript.ModuleState.NEWLY_UNLOCKED, "companions_projector debe pasar a NEWLY_UNLOCKED")
	assert_true(ev.get_tactical_console_state() == EvaluatorScript.ModuleState.NEWLY_UNLOCKED, "Consola táctica debe pasar a NEWLY_UNLOCKED con banlist/seed")
	assert_true(ev.get_module_state(&"tactical_tomes") == EvaluatorScript.ModuleState.CALIBRATING, "tactical_tomes sigue CALIBRATING hasta derrotar 1 Jefe")

	ev.acknowledge_module(&"skins_mirror")
	ev.acknowledge_tactical_console()
	assert_true(ev.get_module_state(&"skins_mirror") == EvaluatorScript.ModuleState.ONLINE, "acknowledge_module debe pasar NEWLY_UNLOCKED -> ONLINE")
	assert_true(ev.get_tactical_console_state() == EvaluatorScript.ModuleState.ONLINE, "acknowledge_tactical_console debe pasar sub-módulos desbloqueados a ONLINE")
	assert_true(ev.get_module_state(&"tactical_tomes") == EvaluatorScript.ModuleState.CALIBRATING, "tactical_tomes bloqueado no debe ser afectado por acknowledge")

	ev.evaluate_snapshot(EvaluatorScript.build_preset_snapshot(&"debug_unlock"))
	assert_true(ev.is_module_unlocked(&"tactical_tomes") and ev.is_module_unlocked(&"tactical_speed"), "debug_force_unlock debe desbloquear todos los módulos sin alterar guardado")

	assert_true(SaveManagerScript.get_biomass() == bio_before, "Evaluator no debe mutar SaveManager.biomass")
	assert_true(int(SaveManagerScript.get_career_stats().get("total_runs_played", 0)) == runs_before, "Evaluator no debe mutar career_stats")

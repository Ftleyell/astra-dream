class_name TestGachaBannerEngineSuite
extends BaseTestSuite

## Suite de micro-pruebas unitarias para GachaBannerEngine.
## Valida filtrado de pools temáticos, resolución de Pity garantizado y distribución de rarezas.

const GachaBannerEngineScript = preload("res://scenes/ui/gacha/components/gacha_banner_engine.gd")

func _ready() -> void:
	super._ready()
	print("==========================================================")
	print("[TEST] Running GachaBannerEngine Micro-Unit Suite")
	print("==========================================================\n")

	_test_banner_config_and_ids()
	_test_pity_trigger_logic()
	_test_skin_category_filtering()
	_test_pull_resolution_and_pity_reset()

	pass_suite("GachaBannerEngine unit tests PASSED successfully")

func _test_banner_config_and_ids() -> void:
	print("[1/4] Testing banner configs and available banner IDs...")
	var ids: Array[String] = GachaBannerEngineScript.get_available_banner_ids()
	assert_true(ids.has("general"), "Should contain general banner")
	assert_true(ids.has("ships"), "Should contain ships banner")
	assert_true(ids.has("pilots"), "Should contain pilots banner")

	var gen_cfg: Dictionary = GachaBannerEngineScript.get_banner_config("general")
	assert_true(gen_cfg.has("title"), "General banner should have title")
	assert_true(gen_cfg.has("featured_badge"), "General banner should have featured_badge")

func _test_pity_trigger_logic() -> void:
	print("[2/4] Testing pity trigger conditions...")
	assert_true(not GachaBannerEngineScript.is_pity_triggered(0), "Pity 0 should not trigger")
	assert_true(not GachaBannerEngineScript.is_pity_triggered(8), "Pity 8 should not trigger")
	assert_true(GachaBannerEngineScript.is_pity_triggered(9), "Pity 9 (next pull 10) must trigger guaranteed epic")
	assert_true(GachaBannerEngineScript.is_pity_triggered(10), "Pity >= 10 must trigger guaranteed epic")

func _test_skin_category_filtering() -> void:
	print("[3/4] Testing category filtering per thematic banner...")
	var dummy_skins: Dictionary = {
		"s1": {"id": "s1", "category": "ship", "rarity": "common"},
		"w1": {"id": "w1", "category": "weapon", "rarity": "rare"},
		"p1": {"id": "p1", "category": "pilot", "rarity": "epic"},
		"n1": {"id": "n1", "category": "navigator", "rarity": "common"},
		"pet1": {"id": "pet1", "category": "pet", "rarity": "epic"}
	}

	var ship_pool: Array[Dictionary] = GachaBannerEngineScript.filter_skins_for_banner(dummy_skins, "ships")
	assert_true(ship_pool.size() == 2, "Ships banner should only include ship and weapon skins")

	var pilot_pool: Array[Dictionary] = GachaBannerEngineScript.filter_skins_for_banner(dummy_skins, "pilots")
	assert_true(pilot_pool.size() == 2, "Pilots banner should only include pilot and navigator skins")

	var general_pool: Array[Dictionary] = GachaBannerEngineScript.filter_skins_for_banner(dummy_skins, "general")
	assert_true(general_pool.size() == 5, "General banner should include all 5 skins")

func _test_pull_resolution_and_pity_reset() -> void:
	print("[4/4] Testing pull resolution and pity resets on epic...")
	var test_skins: Array[Dictionary] = [
		{"id": "skin_c", "rarity": "common"},
		{"id": "skin_e", "rarity": "epic"}
	]

	# Pull común forzado (roll 0.8 > 0.15 y pity 0)
	var common_res: Dictionary = GachaBannerEngineScript.resolve_pull("general", 0, test_skins, 0.8)
	assert_true(str(common_res.get("rarity", "")) == "common", "Should resolve to common on high roll")
	assert_true(int(common_res.get("new_pity", 0)) == 1, "Pity should increment to 1 on common")

	# Pull con Pity garantizado (pity 9 -> is_pity true)
	var pity_res: Dictionary = GachaBannerEngineScript.resolve_pull("general", 9, test_skins, 0.9)
	assert_true(pity_res.get("is_pity", false) == true, "Must flag is_pity on 10th pull")
	assert_true(str(pity_res.get("rarity", "")) == "epic", "Guaranteed pity must be epic")
	assert_true(int(pity_res.get("new_pity", 0)) == 0, "Pity must reset to 0 after epic")

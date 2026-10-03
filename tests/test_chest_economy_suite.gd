extends Node

## ==============================================================================
## TEST SUITE: Chest Economy, Transmutation Station & Satellite Integration
## ==============================================================================

const CHEST_SCENE_PATH := "res://scenes/combat/chests/spatial_chest.tscn"
const TRANSMUTATION_SCENE_PATH := "res://scenes/combat/satellite/transmutation_station.tscn"
const CHEST_REWARD_MODAL_PATH := "res://scenes/ui/modals/chest_reward_modal.tscn"
const TRANSMUTATION_MODAL_PATH := "res://scenes/ui/modals/transmutation_modal.tscn"
const CHEST_ECONOMY_CONFIG_PATH := "res://data/balance/default_chest_economy.tres"

const SpatialChestScript := preload("res://scenes/combat/chests/spatial_chest.gd")
const ChestDirectorScript := preload("res://scenes/combat/chests/chest_director.gd")
const TransmutationStationScript := preload("res://scenes/combat/satellite/transmutation_station.gd")

var _passed_count: int = 0
var _failed_count: int = 0
var _test_log: Array[String] = []

func _ready() -> void:
	get_tree().create_timer(25.0).timeout.connect(func():
		_log_fail("WATCHDOG", "Test suite execution timed out after 25 seconds!")
		_finish_and_quit()
	)

	print("\n==================================================================")
	print("[CHEST ECONOMY SUITE] STARTING AUTOMATED VERIFICATION")
	print("==================================================================")

	await _run_suite_1_economy_config_and_math()
	await _run_suite_2_economic_items_and_effects()
	await _run_suite_3_spatial_chest_entity_and_textures()
	await _run_suite_4_transmutation_station_and_modal()
	await _run_suite_5_chest_director_lifecycle_and_inflation()

	_finish_and_quit()

func _finish_and_quit() -> void:
	print("\n==================================================================")
	print("  CHEST ECONOMY VERIFICATION SUMMARY")
	print("  TOTAL TESTS:  %d" % (_passed_count + _failed_count))
	print("  PASSED:       %d" % _passed_count)
	print("  FAILED:       %d" % _failed_count)
	if _failed_count == 0:
		print("  STATUS:       [PASS] ALL CHEST ECONOMY TESTS CONFIRMED!")
	else:
		print("  STATUS:       [DEFECT_FOUND] %d TESTS FAILED!" % _failed_count)
	print("==================================================================\n")

	get_tree().quit(0 if _failed_count == 0 else 1)

func _assert_true(condition: bool, test_name: String, error_msg: String) -> void:
	if condition:
		_passed_count += 1
		print("  ✓ %s" % test_name)
	else:
		_failed_count += 1
		_log_fail(test_name, error_msg)

func _log_fail(test_name: String, reason: String) -> void:
	var msg := "  ✗ [FAIL] %s: %s" % [test_name, reason]
	_test_log.append(msg)
	push_error(msg)
	print(msg)

func _create_dummy_player() -> Player:
	var p: Player = Player.new()
	var roster := CharacterData.load_roster()
	p.character_data = roster.get(&"nova") if roster.has(&"nova") else null
	p.character_stats = CharacterStats.new()
	p.inventory = InventoryComponent.new()
	p.inventory.character_stats = p.character_stats
	p.add_child(p.inventory)
	p.run_credits = 500
	add_child(p)
	return p

# ==============================================================================
# SUITE 1: Configuración Data-Driven y Fórmulas Matemáticas
# ==============================================================================
func _run_suite_1_economy_config_and_math() -> void:
	print("\n--- SUITE 1: Economy Config & Formulas ---")
	var cfg = load(CHEST_ECONOMY_CONFIG_PATH) as ChestEconomyConfig
	_assert_true(cfg != null, "Config .tres cargado correctamente", "No se pudo cargar default_chest_economy.tres")
	if not cfg:
		return

	# Comprobar coste base regular (n = 0)
	var cost_0 := cfg.calculate_regular_chest_cost(0)
	_assert_true(cost_0 == 25, "Coste regular base es 25c", "Esperado 25, obtenido %d" % cost_0)

	# Comprobar escalado cuadrático (n = 5: 25 + 8*5 + 1.5*25 = 102.5 -> 103)
	var cost_5 := cfg.calculate_regular_chest_cost(5)
	_assert_true(cost_5 == 103, "Coste regular tras 5 compras es 103c", "Esperado 103, obtenido %d" % cost_5)

	# Comprobar recargo de Tarjeta Verde (+10% por stack: 103 * 1.1 = 113.3 -> 113)
	var cost_5_card := cfg.calculate_regular_chest_cost(5, 1)
	_assert_true(cost_5_card == 113, "Recargo de Tarjeta Verde aplicado correctamente", "Esperado 113, obtenido %d" % cost_5_card)

	# Comprobar fórmula hiperbólica de Llave Cuántica: n / (10 + n)
	var p_0 := cfg.calculate_key_free_chance(0)
	var p_10 := cfg.calculate_key_free_chance(10)
	var p_90 := cfg.calculate_key_free_chance(90)
	_assert_true(is_equal_approx(p_0, 0.0), "0 Llaves = 0% apertura gratis", "Esperado 0.0, obtenido %f" % p_0)
	_assert_true(is_equal_approx(p_10, 0.50), "10 Llaves = 50% apertura gratis", "Esperado 0.50, obtenido %f" % p_10)
	_assert_true(is_equal_approx(p_90, 0.90), "90 Llaves = 90% apertura gratis", "Esperado 0.90, obtenido %f" % p_90)

# ==============================================================================
# SUITE 2: Ítems Económicos y Procs
# ==============================================================================
func _run_suite_2_economic_items_and_effects() -> void:
	print("\n--- SUITE 2: Economic Items & Procs ---")
	var p := _create_dummy_player()
	var cat := ItemPoolManager.create_canonical_stat_items()

	var key_item: ItemData = null
	var green_card: ItemData = null
	var red_card: ItemData = null

	for it in cat:
		if it.item_id == &"quantum_key": key_item = it
		elif it.item_id == &"credit_card_green": green_card = it
		elif it.item_id == &"credit_card_red": red_card = it

	_assert_true(key_item != null, "Ítem 'quantum_key' registrado en el catálogo", "Falta quantum_key")
	_assert_true(green_card != null, "Ítem 'credit_card_green' registrado en el catálogo", "Falta credit_card_green")
	_assert_true(red_card != null, "Ítem 'credit_card_red' registrado en el catálogo", "Falta credit_card_red")

	if green_card and red_card:
		p.inventory.add_item(green_card, 1)
		p.inventory.add_item(red_card, 1)

		# Disparar proc de apertura de cofre
		p.inventory.process_chest_opened_procs(p)

		var luck_mod = p.character_stats.get_stat_modifier(&"luck", &"credit_card_green_proc")
		var dmg_mod = p.character_stats.get_stat_modifier(&"base_damage", &"credit_card_red_proc")

		_assert_true(luck_mod != null and luck_mod.value > 0.04, "Tarjeta Verde otorgó +5% Suerte permanente tras cofre", "Modificador de Suerte no aplicado")
		_assert_true(dmg_mod != null and dmg_mod.value > 0.019, "Tarjeta Roja otorgó +2% Daño permanente tras cofre", "Modificador de Daño no aplicado")

	p.queue_free()

# ==============================================================================
# SUITE 3: Entidad SpatialChest y Texturas
# ==============================================================================
func _run_suite_3_spatial_chest_entity_and_textures() -> void:
	print("\n--- SUITE 3: SpatialChest Entity & Textures ---")
	var chest_scene := load(CHEST_SCENE_PATH) as PackedScene
	_assert_true(chest_scene != null, "Escena spatial_chest.tscn cargada", "No se encontró spatial_chest.tscn")

	var chest := chest_scene.instantiate()
	add_child(chest)

	chest.chest_type = SpatialChestScript.ChestType.SALVAGE_CAPSULE
	chest.update_price_display(0)
	_assert_true(chest.current_cost == 0, "Cápsula de Chatarra tiene coste 0", "Coste no es 0")

	chest.chest_type = SpatialChestScript.ChestType.REGULAR
	chest.update_price_display(3)
	_assert_true(chest.current_cost > 25, "Cofre regular escala precio tras 3 compras", "Coste no escaló")

	chest.chest_type = SpatialChestScript.ChestType.GOLDEN
	chest.update_price_display(0)
	_assert_true(chest.current_cost == 150, "Cofre dorado tiene coste base de 150c", "Coste esperado 150")

	chest.queue_free()

# ==============================================================================
# SUITE 4: Estación de Forja (TransmutationStation) y Modal
# ==============================================================================
func _run_suite_4_transmutation_station_and_modal() -> void:
	print("\n--- SUITE 4: Transmutation Station & Modal ---")
	var trans_scene := load(TRANSMUTATION_SCENE_PATH) as PackedScene
	_assert_true(trans_scene != null, "Escena transmutation_station.tscn cargada", "Falta transmutation_station.tscn")

	var station := trans_scene.instantiate()
	add_child(station)

	_assert_true(station.uses_remaining == 3, "Estación inicia con 3 usos disponibles", "Usos esperados 3, obtenido %d" % station.uses_remaining)

	station.consume_use()
	station.consume_use()
	_assert_true(station.uses_remaining == 1, "Consumo de usos decrementa correctamente", "Esperado 1, obtenido %d" % station.uses_remaining)

	station.consume_use()
	_assert_true(station.is_depleted, "Estación pasa a estado agotado al llegar a 0 usos", "No se agotó")

	station.queue_free()

# ==============================================================================
# SUITE 5: ChestDirector Lifecycle & Inflación en Tiempo Real
# ==============================================================================
func _run_suite_5_chest_director_lifecycle_and_inflation() -> void:
	print("\n--- SUITE 5: ChestDirector Lifecycle & Inflation ---")
	var director = ChestDirectorScript.new()
	add_child(director)
	var cfg = load(CHEST_ECONOMY_CONFIG_PATH) as ChestEconomyConfig
	director.initialize(cfg, 0)

	var spawn_parent := Node2D.new()
	add_child(spawn_parent)

	director.spawn_wave_chests(Vector2.ZERO, spawn_parent, 1)
	_assert_true(director.active_chests.size() > 0, "Director pobló cofres en el espacio", "No se generaron cofres")

	var initial_cost: int = cfg.calculate_regular_chest_cost(director.paid_chests_count)

	# Simular apertura pagada de un cofre regular
	var first_regular = null
	for c in director.active_chests:
		if c.chest_type == SpatialChestScript.ChestType.REGULAR:
			first_regular = c
			break

	if first_regular:
		var it := ItemData.new()
		it.item_id = &"test_item"
		first_regular.chest_opened.emit(it, false, first_regular.current_cost)

		_assert_true(director.paid_chests_count == 1, "Contador de compras incrementó a 1 tras apertura pagada", "Contador no incrementó")
		var new_cost: int = cfg.calculate_regular_chest_cost(director.paid_chests_count)
		_assert_true(new_cost > initial_cost, "Inflación aumentó el coste de los cofres restantes", "El coste no subió tras compra")

	director.cleanup_all_chests()
	_assert_true(director.active_chests.is_empty(), "cleanup_all_chests liberó todos los cofres activos", "Aún quedan cofres activos")

	spawn_parent.queue_free()
	director.queue_free()

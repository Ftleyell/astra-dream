extends Node

## ==============================================================================
## TEST SUITE: Hybrid Chest Economy & Quantum Keys Verification
## ==============================================================================

const CHEST_SCENE_PATH := "res://scenes/combat/chests/spatial_chest.tscn"
const CHEST_ECONOMY_CONFIG_PATH := "res://data/balance/default_chest_economy.tres"

const SpatialChestScript := preload("res://scenes/combat/chests/spatial_chest.gd")
const ChestDirectorScript := preload("res://scenes/combat/chests/chest_director.gd")

var _passed_count: int = 0
var _failed_count: int = 0
var _test_log: Array[String] = []

func _ready() -> void:
	get_tree().create_timer(20.0).timeout.connect(func() -> void:
		_log_fail("WATCHDOG", "Hybrid chest economy suite execution timed out after 20 seconds!")
		_finish_and_quit()
	)

	print("\n==================================================================")
	print("[HYBRID CHEST ECONOMY SUITE] STARTING AUTOMATED VERIFICATION")
	print("==================================================================")

	await _run_test_1_formula_validation()
	await _run_test_2_wave_reset()
	await _run_test_3_quantum_key_active_consumption()
	await _run_test_4_quantum_key_passive_discount()
	await _run_test_5_golden_chest_immunity_to_keys()
	await _run_test_6_director_free_key_opening_no_inflation()
	await _run_test_7_director_credit_purchase_applies_inflation()
	await _run_test_8_insufficient_credits_rejection()
	await _run_test_9_multiple_quantum_keys_consumption()
	await _run_test_10_hud_key_label_formatting()

	_finish_and_quit()

func _finish_and_quit() -> void:
	print("\n==================================================================")
	print("  HYBRID CHEST ECONOMY VERIFICATION SUMMARY")
	print("  TOTAL TESTS:  %d" % (_passed_count + _failed_count))
	print("  PASSED:       %d" % _passed_count)
	print("  FAILED:       %d" % _failed_count)
	if _failed_count == 0:
		print("  STATUS:       [PASS] ALL HYBRID CHEST ECONOMY TESTS PASSED!")
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
	var msg: String = "  ✗ [FAIL] %s: %s" % [test_name, reason]
	_test_log.append(msg)
	push_error(msg)
	print(msg)

func _create_test_player(starting_credits: int = 200) -> Player:
	var p: Player = Player.new()
	var roster: Dictionary = CharacterData.load_roster()
	p.character_data = roster.get(&"nova") if roster.has(&"nova") else null
	p.character_stats = CharacterStats.new()
	p.inventory = InventoryComponent.new()
	p.inventory.character_stats = p.character_stats
	p.add_child(p.inventory)
	p.run_credits = starting_credits
	p.add_to_group("player")
	add_child(p)
	return p

func _get_quantum_key_item() -> ItemData:
	var canonical_items: Array[ItemData] = ItemPoolManager.create_canonical_stat_items()
	for it in canonical_items:
		if it.item_id == &"quantum_key":
			return it
	var fallback_key: ItemData = ItemData.new()
	fallback_key.item_id = &"quantum_key"
	fallback_key.item_name = "Llave Cuántica"
	return fallback_key

func _create_deterministic_pool() -> ItemPoolManager:
	var pool := ItemPoolManager.new()
	var test_item := ItemData.new()
	test_item.item_id = &"botas"
	test_item.item_name = "Botas"
	test_item.rarity = Enums.Rarity.COMMON
	pool.master_catalog = [test_item]
	add_child(pool)
	return pool

# ------------------------------------------------------------------------------
# Test 1: Validate C(w, k) formula
# Wave 1 k=0 is 24c; Wave 1 k=3 is 34c; Wave 8 k=0 is 52c; Wave 16 k=0 is 84c
# ------------------------------------------------------------------------------
func _run_test_1_formula_validation() -> void:
	print("\n--- TEST 1: Formula Validation C(w, k) ---")
	var cfg: ChestEconomyConfig = load(CHEST_ECONOMY_CONFIG_PATH) as ChestEconomyConfig
	_assert_true(cfg != null, "ChestEconomyConfig cargado", "No se pudo cargar default_chest_economy.tres")
	if not cfg:
		return

	var c_w1_k0: int = cfg.calculate_regular_chest_cost(1, 0, 0, false)
	_assert_true(c_w1_k0 == 24, "Wave 1, k=0 -> 24c", "Esperado 24c, obtenido %dc" % c_w1_k0)

	var c_w1_k3: int = cfg.calculate_regular_chest_cost(1, 3, 0, false)
	_assert_true(c_w1_k3 == 34, "Wave 1, k=3 -> 34c", "Esperado 34c, obtenido %dc" % c_w1_k3)

	var c_w8_k0: int = cfg.calculate_regular_chest_cost(8, 0, 0, false)
	_assert_true(c_w8_k0 == 52, "Wave 8, k=0 -> 52c", "Esperado 52c, obtenido %dc" % c_w8_k0)

	var c_w16_k0: int = cfg.calculate_regular_chest_cost(16, 0, 0, false)
	_assert_true(c_w16_k0 == 84, "Wave 16, k=0 -> 84c", "Esperado 84c, obtenido %dc" % c_w16_k0)

# ------------------------------------------------------------------------------
# Test 2: Wave reset: Calling on_new_wave resets k and updates chest costs
# ------------------------------------------------------------------------------
func _run_test_2_wave_reset() -> void:
	print("\n--- TEST 2: Wave Reset & Inflation Reset ---")
	var cfg: ChestEconomyConfig = load(CHEST_ECONOMY_CONFIG_PATH) as ChestEconomyConfig
	var director: ChestDirector = ChestDirectorScript.new()
	add_child(director)
	director.initialize(cfg, 0)

	var spawn_parent: Node2D = Node2D.new()
	add_child(spawn_parent)
	director.spawn_wave_chests(Vector2.ZERO, spawn_parent, 1)

	# Simular 3 compras locales en oleada 1
	director.local_chests_opened_this_wave = 3
	director.refresh_all_chest_prices(0)

	var reg_chest: SpatialChest = null
	for c in director.active_chests:
		if c.chest_type == SpatialChestScript.ChestType.REGULAR:
			reg_chest = c
			break

	if reg_chest:
		_assert_true(reg_chest.current_cost == 34, "Cofre en Oleada 1 con k=3 cuesta 34c", "Esperado 34c, obtenido %dc" % reg_chest.current_cost)

	# Notificar cambio a Oleada 2
	director.on_new_wave(2, 0)
	_assert_true(director.current_wave == 2, "director.current_wave se actualizó a 2", "Esperado 2, obtenido %d" % director.current_wave)
	_assert_true(director.local_chests_opened_this_wave == 0, "director.local_chests_opened_this_wave se reinició a 0", "Esperado 0, obtenido %d" % director.local_chests_opened_this_wave)

	if reg_chest:
		# En oleada 2, k=0: base = 20 + 4*2 = 28c
		_assert_true(reg_chest.current_cost == 28, "Precio de cofre activo se reseteó a coste de Oleada 2 (28c)", "Esperado 28c, obtenido %dc" % reg_chest.current_cost)

	director.cleanup_all_chests()
	spawn_parent.queue_free()
	director.queue_free()

# ------------------------------------------------------------------------------
# Test 3: Quantum key active consumption: Opening regular chest consumes 1 key and costs 0 credits
# ------------------------------------------------------------------------------
func _run_test_3_quantum_key_active_consumption() -> void:
	print("\n--- TEST 3: Quantum Key Active Consumption ---")
	var p: Player = _create_test_player(100)
	var key_item: ItemData = _get_quantum_key_item()
	p.inventory.add_item(key_item, 1)

	_assert_true(p.inventory.get_item_count(&"quantum_key") == 1, "Jugador tiene 1 Llave Cuántica en inventario", "No tiene la llave")

	var chest_scene: PackedScene = load(CHEST_SCENE_PATH) as PackedScene
	var chest: SpatialChest = chest_scene.instantiate() as SpatialChest
	add_child(chest)
	chest.chest_type = SpatialChestScript.ChestType.REGULAR
	chest.update_price_display(1, 0, 0)

	var det_pool: ItemPoolManager = _create_deterministic_pool()
	var opened_success: bool = chest.try_open(p, det_pool)
	_assert_true(opened_success, "try_open con Llave Cuántica exitoso", "try_open falló")
	_assert_true(chest.is_opened, "Cofre regular quedó en estado is_opened", "Cofre no abierto")
	_assert_true(p.inventory.get_item_count(&"quantum_key") == 0, "Llave Cuántica fue consumida (quedan 0)", "Llave no consumida")
	_assert_true(p.run_credits == 100, "Créditos no fueron reducidos (apertura gratis: 0c)", "Créditos alterados: %d" % p.run_credits)

	det_pool.queue_free()
	chest.queue_free()
	p.queue_free()

# ------------------------------------------------------------------------------
# Test 4: Quantum key passive discount: Having keys gives 20% discount on credit purchase price
# ------------------------------------------------------------------------------
func _run_test_4_quantum_key_passive_discount() -> void:
	print("\n--- TEST 4: Quantum Key Passive Discount (20%) ---")
	var cfg: ChestEconomyConfig = load(CHEST_ECONOMY_CONFIG_PATH) as ChestEconomyConfig

	# Validación en fórmula:
	var price_without_key: int = cfg.calculate_regular_chest_cost(1, 0, 0, false)
	var price_with_key: int = cfg.calculate_regular_chest_cost(1, 0, 0, true)
	_assert_true(price_without_key == 24, "Precio base Oleada 1 sin llave es 24c", "Esperado 24c, obtenido %dc" % price_without_key)
	_assert_true(price_with_key == 19, "Precio Oleada 1 con descuento de llave (-20%%) es 19c (floor(24 * 0.8))", "Esperado 19c, obtenido %dc" % price_with_key)

	# Validación en entidad SpatialChest con jugador portador en escena:
	var p: Player = _create_test_player(100)
	var key_item: ItemData = _get_quantum_key_item()
	p.inventory.add_item(key_item, 1)

	var chest_scene: PackedScene = load(CHEST_SCENE_PATH) as PackedScene
	var chest: SpatialChest = chest_scene.instantiate() as SpatialChest
	add_child(chest)
	chest.chest_type = SpatialChestScript.ChestType.REGULAR
	chest.update_price_display(1, 0, 0)

	_assert_true(chest.current_cost == 19, "SpatialChest detectó llave y aplicó coste descontado de 19c", "Esperado 19c, obtenido %dc" % chest.current_cost)

	chest.queue_free()
	p.queue_free()

# ------------------------------------------------------------------------------
# Test 5: Golden chest costs 120c and is immune to key consumption
# ------------------------------------------------------------------------------
func _run_test_5_golden_chest_immunity_to_keys() -> void:
	print("\n--- TEST 5: Golden Chest Immunity to Keys ---")
	var p: Player = _create_test_player(200)
	var key_item: ItemData = _get_quantum_key_item()
	p.inventory.add_item(key_item, 1)

	var chest_scene: PackedScene = load(CHEST_SCENE_PATH) as PackedScene
	var golden_chest: SpatialChest = chest_scene.instantiate() as SpatialChest
	add_child(golden_chest)
	golden_chest.chest_type = SpatialChestScript.ChestType.GOLDEN
	golden_chest.update_price_display(1, 0, 0)

	_assert_true(golden_chest.current_cost == 120, "Cofre dorado tiene coste fijo de 120c", "Esperado 120c, obtenido %dc" % golden_chest.current_cost)

	var opened_success: bool = golden_chest.try_open(p, null)
	_assert_true(opened_success, "Apertura de cofre dorado exitosa", "try_open falló")
	_assert_true(golden_chest.is_opened, "Cofre dorado en estado is_opened", "No se abrió")
	_assert_true(p.inventory.get_item_count(&"quantum_key") == 1, "Llave Cuántica NO fue consumida (inmune a llaves)", "La llave fue consumida erróneamente")
	_assert_true(p.run_credits == 80, "Créditos deducidos correctamente: 200 - 120 = 80c", "Créditos esperados 80c, obtenido %dc" % p.run_credits)

	golden_chest.queue_free()
	p.queue_free()

# ------------------------------------------------------------------------------
# Test 6: Director: Opening with Quantum Key preserves k=0 and paid_chests=0
# ------------------------------------------------------------------------------
func _run_test_6_director_free_key_opening_no_inflation() -> void:
	print("\n--- TEST 6: Director Free Key Opening Preserves k=0 ---")
	var cfg: ChestEconomyConfig = load(CHEST_ECONOMY_CONFIG_PATH) as ChestEconomyConfig
	var director: ChestDirector = ChestDirectorScript.new()
	add_child(director)
	director.initialize(cfg, 0)

	var p: Player = _create_test_player(100)
	var key_item: ItemData = _get_quantum_key_item()
	p.inventory.add_item(key_item, 1)

	var spawn_parent: Node2D = Node2D.new()
	add_child(spawn_parent)
	director.spawn_wave_chests(Vector2.ZERO, spawn_parent, 1)

	var reg_chest: SpatialChest = null
	for c in director.active_chests:
		if c.chest_type == SpatialChestScript.ChestType.REGULAR:
			reg_chest = c
			break

	_assert_true(reg_chest != null, "Director generó cofre regular para prueba de llave", "No hay cofre regular")
	if reg_chest:
		var det_pool: ItemPoolManager = _create_deterministic_pool()
		var opened: bool = reg_chest.try_open(p, det_pool)
		_assert_true(opened, "Cofre de director abierto exitosamente con llave", "try_open falló")
		_assert_true(p.inventory.get_item_count(&"quantum_key") == 0, "Llave fue consumida por el cofre", "Llave no consumida")
		_assert_true(director.local_chests_opened_this_wave == 0, "Inflación local k se mantuvo en 0 tras apertura con llave", "k incrementó: %d" % director.local_chests_opened_this_wave)
		_assert_true(director.paid_chests_count == 0, "Contador de compras pagadas se mantuvo en 0 tras apertura con llave", "paid_chests incrementó: %d" % director.paid_chests_count)
		det_pool.queue_free()

	director.cleanup_all_chests()
	spawn_parent.queue_free()
	director.queue_free()
	p.queue_free()

# ------------------------------------------------------------------------------
# Test 7: Director: Paid credit purchase applies local inflation k+1
# ------------------------------------------------------------------------------
func _run_test_7_director_credit_purchase_applies_inflation() -> void:
	print("\n--- TEST 7: Director Paid Credit Purchase Applies Inflation ---")
	var cfg: ChestEconomyConfig = load(CHEST_ECONOMY_CONFIG_PATH) as ChestEconomyConfig
	var director: ChestDirector = ChestDirectorScript.new()
	add_child(director)
	director.initialize(cfg, 0)

	var p: Player = _create_test_player(100)
	var spawn_parent: Node2D = Node2D.new()
	add_child(spawn_parent)
	director.spawn_wave_chests(Vector2.ZERO, spawn_parent, 1)

	var reg_chests: Array[SpatialChest] = []
	for c in director.active_chests:
		if c.chest_type == SpatialChestScript.ChestType.REGULAR:
			reg_chests.append(c)

	_assert_true(reg_chests.size() >= 1, "Al menos 1 cofre regular disponible", "No hay suficientes cofres")
	if reg_chests.size() >= 1:
		var det_pool: ItemPoolManager = _create_deterministic_pool()
		var first: SpatialChest = reg_chests[0]
		_assert_true(first.current_cost == 24, "Coste inicial es 24c", "Coste inicial incorrecto: %dc" % first.current_cost)
		var opened: bool = first.try_open(p, det_pool)
		_assert_true(opened, "Apertura pagada con créditos exitosa", "try_open falló")
		_assert_true(p.run_credits == 76, "Créditos deducidos: 100 - 24 = 76c", "Créditos erróneos: %dc" % p.run_credits)
		_assert_true(director.local_chests_opened_this_wave == 1, "k local incrementó a 1 tras compra pagada", "k erróneo: %d" % director.local_chests_opened_this_wave)
		_assert_true(director.paid_chests_count == 1, "paid_chests incrementó a 1 tras compra pagada", "paid_chests erróneo: %d" % director.paid_chests_count)
		det_pool.queue_free()

	director.cleanup_all_chests()
	spawn_parent.queue_free()
	director.queue_free()
	p.queue_free()

# ------------------------------------------------------------------------------
# Test 8: Insufficient credits rejection
# ------------------------------------------------------------------------------
func _run_test_8_insufficient_credits_rejection() -> void:
	print("\n--- TEST 8: Insufficient Credits Rejection ---")
	var p: Player = _create_test_player(10)
	var chest_scene: PackedScene = load(CHEST_SCENE_PATH) as PackedScene
	var chest: SpatialChest = chest_scene.instantiate() as SpatialChest
	add_child(chest)
	chest.chest_type = SpatialChestScript.ChestType.REGULAR
	chest.update_price_display(1, 0, 0)

	var opened: bool = chest.try_open(p, null)
	_assert_true(not opened, "try_open rechazado por créditos insuficientes (10 < 24)", "try_open permitió apertura indebida")
	_assert_true(not chest.is_opened, "Cofre sigue cerrado (is_opened == false)", "Cofre marcado como abierto")
	_assert_true(p.run_credits == 10, "Créditos intactos (10c)", "Créditos alterados: %dc" % p.run_credits)

	chest.queue_free()
	p.queue_free()

# ------------------------------------------------------------------------------
# Test 9: Multiple Quantum Keys: consumes exactly 1 key, leaves remainder
# ------------------------------------------------------------------------------
func _run_test_9_multiple_quantum_keys_consumption() -> void:
	print("\n--- TEST 9: Multiple Quantum Keys Consumption ---")
	var p: Player = _create_test_player(50)
	var key_item: ItemData = _get_quantum_key_item()
	p.inventory.add_item(key_item, 2)
	_assert_true(p.inventory.get_item_count(&"quantum_key") == 2, "Jugador tiene 2 Llaves Cuánticas", "No tiene 2 llaves")

	var chest_scene: PackedScene = load(CHEST_SCENE_PATH) as PackedScene
	var chest: SpatialChest = chest_scene.instantiate() as SpatialChest
	add_child(chest)
	chest.chest_type = SpatialChestScript.ChestType.REGULAR
	chest.update_price_display(1, 0, 0)

	var det_pool: ItemPoolManager = _create_deterministic_pool()
	var opened: bool = chest.try_open(p, det_pool)
	_assert_true(opened, "Apertura con llaves exitosa", "try_open falló")
	_assert_true(p.inventory.get_item_count(&"quantum_key") == 1, "Consumió exactamente 1 llave (queda 1)", "Conteo de llaves erróneo: %d" % p.inventory.get_item_count(&"quantum_key"))
	_assert_true(p.run_credits == 50, "Créditos no fueron cobrados (50c intactos)", "Créditos alterados: %dc" % p.run_credits)
	det_pool.queue_free()

	chest.queue_free()
	p.queue_free()

# ------------------------------------------------------------------------------
# Test 10: HUD KeyLabel text format: 'x0', 'x1 (-20% Desc.)', 'x3 (-20% Desc.)'
# ------------------------------------------------------------------------------
func _run_test_10_hud_key_label_formatting() -> void:
	print("\n--- TEST 10: HUD KeyLabel Formatting ---")
	var hud_scene: PackedScene = load("res://scenes/ui/hud/hud.tscn") as PackedScene
	_assert_true(hud_scene != null, "Escena hud.tscn cargada exitosamente", "No se pudo cargar hud.tscn")
	if not hud_scene:
		return

	var hud_inst: GameHUD = hud_scene.instantiate() as GameHUD
	add_child(hud_inst)

	var key_lbl: Label = hud_inst.find_child("KeyLabel", true, false) as Label
	_assert_true(key_lbl != null, "KeyLabel encontrado en HUD", "KeyLabel no existe en hud.tscn")

	if key_lbl:
		hud_inst.update_quantum_keys(0)
		_assert_true(key_lbl.text == "x0", "0 Llaves -> 'x0'", "Esperado 'x0', obtenido '%s'" % key_lbl.text)

		hud_inst.update_quantum_keys(1)
		_assert_true(key_lbl.text == "x1 (-20% Desc.)", "1 Llave -> 'x1 (-20% Desc.)'", "Esperado 'x1 (-20%% Desc.)', obtenido '%s'" % key_lbl.text)

		hud_inst.update_quantum_keys(3)
		_assert_true(key_lbl.text == "x3 (-20% Desc.)", "3 Llaves -> 'x3 (-20% Desc.)'", "Esperado 'x3 (-20%% Desc.)', obtenido '%s'" % key_lbl.text)

	hud_inst.queue_free()


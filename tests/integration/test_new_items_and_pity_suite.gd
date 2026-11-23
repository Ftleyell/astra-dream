extends Node

## TestNewItemsAndPitySuite.gd
## Batería automatizada de pruebas para la Fase 4:
## 12 Nuevos Ítems Estratégicos, Corrección Nanotitanio, Pity System PRD,
## Relé Orbital, Recompilador Cuántico, Banco Cronos y Recuperador Pesado.

const MainGameClass := preload("res://scenes/combat/main_game.gd")
const SatelliteBeaconClass := preload("res://scenes/combat/satellite/satellite_beacon.gd")
const TransmutationStationClass := preload("res://scenes/combat/satellite/transmutation_station.gd")
const CombatSatelliteCoordinatorClass := preload("res://scenes/combat/systems/combat_satellite_coordinator.gd")

var _passed_count: int = 0
var _failed_count: int = 0

func _ready() -> void:
	# Watchdog de seguridad (15s)
	get_tree().create_timer(15.0).timeout.connect(func() -> void:
		push_error("[WATCHDOG TIMEOUT] TestNewItemsAndPitySuite no finalizó en 15s.")
		get_tree().quit(1)
	)

	print("\n==================================================================")
	print("[NEW ITEMS & PITY SUITE] STARTING AUTOMATED VERIFICATION")
	print("==================================================================")

	_run_test_1_catalog_and_items()
	_run_test_2_nanotitanium_plating_armor()
	_run_test_3_abyssal_contract_curse_and_damage()
	_run_test_4_pity_system_15_rolls()
	_run_test_5_pity_luck_discount()
	_run_test_6_orbital_relay_and_quantum_recompiler()
	_run_test_7_chronos_bank_and_heavy_salvager()

	print("\n==================================================================")
	print("  VERIFICATION SUMMARY")
	print("  TOTAL TESTS: %d" % (_passed_count + _failed_count))
	print("  PASSED:      %d" % _passed_count)
	print("  FAILED:      %d" % _failed_count)
	if _failed_count == 0:
		print("  STATUS:      [PASS] ALL PHASE 4 TESTS PASSED PERFECTLY!")
		print("==================================================================\n")
		get_tree().quit(0)
	else:
		print("  STATUS:      [FAIL] SOME TESTS FAILED!")
		print("==================================================================\n")
		get_tree().quit(1)

func _assert_test(condition: bool, test_name: String, details: String = "") -> void:
	if condition:
		_passed_count += 1
		print("  ✓ [PASS] %s%s" % [test_name, " (" + details + ")" if details != "" else ""])
	else:
		_failed_count += 1
		push_error("  ✗ [FAIL] %s: %s" % [test_name, details])


## ─── TEST 1: Catálogo de los 12 nuevos ítems estratégicos ─────────────────────
func _run_test_1_catalog_and_items() -> void:
	print("\n--- TEST 1: Verificar instanciación, master_catalog, iconos y tags de los 12 ítems ---")

	var mgr := ItemPoolManager.new()
	mgr._populate_default_catalog()

	var expected_items: Dictionary = {
		&"abyssal_contract": {
			"rarity": Enums.Rarity.RARE,
			"cost": 85,
			"tags": [&"offense", &"curse", &"tradeoff"],
			"stat": &"base_damage",
			"val": 0.35,
			"mod_type": Enums.ModifierType.MULTIPLICATIVE,
			"sec_stat": &"curse",
			"sec_val": 20.0,
			"sec_mod_type": Enums.ModifierType.FLAT
		},
		&"antimatter_core": {
			"rarity": Enums.Rarity.EPIC,
			"cost": 110,
			"tags": [&"crit", &"curse", &"proc"],
			"stat": &"health_regen",
			"val": -0.50,
			"mod_type": Enums.ModifierType.MULTIPLICATIVE,
			"sec_stat": &"curse",
			"sec_val": 10.0,
			"sec_mod_type": Enums.ModifierType.FLAT
		},
		&"blood_capacitor": {
			"rarity": Enums.Rarity.RARE,
			"cost": 80,
			"tags": [&"mobility", &"dash", &"tradeoff"],
			"stat": &"max_health",
			"val": -0.10,
			"mod_type": Enums.ModifierType.MULTIPLICATIVE
		},
		&"entropy_engine": {
			"rarity": Enums.Rarity.EPIC,
			"cost": 115,
			"tags": [&"offense", &"curse", &"scaling"],
			"stat": &"curse",
			"val": 15.0,
			"mod_type": Enums.ModifierType.FLAT
		},
		&"bifocal_lens": {
			"rarity": Enums.Rarity.RARE,
			"cost": 80,
			"tags": [&"offense", &"crit", &"conversion"]
		},
		&"inertial_thruster": {
			"rarity": Enums.Rarity.UNCOMMON,
			"cost": 60,
			"tags": [&"mobility", &"damage", &"kinetic"]
		},
		&"chain_battery": {
			"rarity": Enums.Rarity.RARE,
			"cost": 75,
			"tags": [&"defense", &"proc", &"shield"]
		},
		&"photonic_prism": {
			"rarity": Enums.Rarity.UNCOMMON,
			"cost": 65,
			"tags": [&"offense", &"projectiles", &"bifurcation"]
		},
		&"orbital_relay": {
			"rarity": Enums.Rarity.RARE,
			"cost": 85,
			"tags": [&"utility", &"satellite", &"chest"]
		},
		&"quantum_recompiler": {
			"rarity": Enums.Rarity.UNCOMMON,
			"cost": 60,
			"tags": [&"utility", &"transmutation"]
		},
		&"heavy_salvager": {
			"rarity": Enums.Rarity.COMMON,
			"cost": 45,
			"tags": [&"utility", &"salvage", &"health"]
		},
		&"chronos_bank": {
			"rarity": Enums.Rarity.RARE,
			"cost": 75,
			"tags": [&"utility", &"economy", &"interest"]
		}
	}

	for item_id: StringName in expected_items.keys():
		var data: ItemData = null
		for it in mgr.master_catalog:
			if it.item_id == item_id:
				data = it
				break

		_assert_test(data != null, "Item registrado en master_catalog", String(item_id))
		if data:
			var spec: Dictionary = expected_items[item_id]
			_assert_test(data.rarity == spec["rarity"], "Rareza correcta para " + String(item_id))
			_assert_test(data.cost == spec["cost"], "Coste correcto para " + String(item_id), "%d vs %d" % [data.cost, spec["cost"]])
			_assert_test(data.icon != null, "Icono asignado válidamente para " + String(item_id))
			for t in spec["tags"]:
				_assert_test(data.tags.has(t), "Tag presente: " + String(t), String(item_id))

			if spec.has("stat"):
				_assert_test(data.stat_name == spec["stat"], "stat_name correcto", String(data.stat_name))
				_assert_test(is_equal_approx(data.stat_value, spec["val"]), "stat_value correcto", "%.2f" % data.stat_value)
				_assert_test(data.modifier_type == spec["mod_type"], "modifier_type correcto")
			if spec.has("sec_stat"):
				_assert_test(data.secondary_stat_name == spec["sec_stat"], "secondary_stat_name correcto", String(data.secondary_stat_name))
				_assert_test(is_equal_approx(data.secondary_stat_value, spec["sec_val"]), "secondary_stat_value correcto", "%.2f" % data.secondary_stat_value)
				_assert_test(data.secondary_modifier_type == spec["sec_mod_type"], "secondary_modifier_type correcto")

	mgr.queue_free()


## ─── TEST 2: Revestimiento Nanotitanio otorga +3 armadura plana con 0 base ───
func _run_test_2_nanotitanium_plating_armor() -> void:
	print("\n--- TEST 2: nanotitanium_plating otorga +3 armadura FLAT a piloto con 0 base ---")

	var char_data := CharacterData.new()
	char_data.armor = 0.0
	char_data.move_speed = 200.0

	var stats := CharacterStats.new()
	stats.initialize(char_data)

	var inv := InventoryComponent.new()
	inv.character_stats = stats

	var sat_items := ItemPoolManager.create_satellite_shop_items()
	var plating: ItemData = null
	for it in sat_items:
		if it.item_id == &"nanotitanium_plating":
			plating = it
			break

	_assert_test(plating != null, "nanotitanium_plating encontrado")
	if plating:
		_assert_test(plating.modifier_type == Enums.ModifierType.FLAT, "nanotitanium_plating tiene modifier_type FLAT")
		_assert_test(is_equal_approx(plating.stat_value, 3.0), "stat_value es 3.0")
		_assert_test(plating.secondary_modifier_type == Enums.ModifierType.MULTIPLICATIVE, "secondary_modifier_type es MULTIPLICATIVE (-12% speed)")

		inv.add_item(plating)
		var final_armor := stats.get_stat(&"armor")
		_assert_test(is_equal_approx(final_armor, 3.0), "Piloto con 0 armadura base ahora tiene +3.0 armadura", "got %.2f" % final_armor)

		var final_speed := stats.get_stat(&"move_speed")
		_assert_test(is_equal_approx(final_speed, 200.0 * 0.88), "Velocidad reducida en un 12%", "got %.2f" % final_speed)

	inv.queue_free()


## ─── TEST 3: Pacto Abisal otorga +20 Maldición y daño multiplicativo ─────────
func _run_test_3_abyssal_contract_curse_and_damage() -> void:
	print("\n--- TEST 3: abyssal_contract añade +20 Maldición y daño multiplicativo ---")

	var char_data := CharacterData.new()
	char_data.base_damage = 100.0

	var stats := CharacterStats.new()
	stats.initialize(char_data)

	var inv := InventoryComponent.new()
	inv.character_stats = stats

	var sat_items := ItemPoolManager.create_satellite_shop_items()
	var contract: ItemData = null
	for it in sat_items:
		if it.item_id == &"abyssal_contract":
			contract = it
			break

	_assert_test(contract != null, "abyssal_contract encontrado")
	if contract:
		inv.add_item(contract)
		var final_curse := stats.get_stat(&"curse")
		var final_damage := stats.get_stat(&"base_damage")

		_assert_test(is_equal_approx(final_curse, 20.0), "Maldición incrementada en +20 plana", "curse: %.2f" % final_curse)
		_assert_test(is_equal_approx(final_damage, 135.0), "Daño base escalado un +35% multiplicativo", "damage: %.2f" % final_damage)

	inv.queue_free()


## ─── TEST 4: Pity System: 15 tiradas consecutivas sin legendario ─────────────
func _run_test_4_pity_system_15_rolls() -> void:
	print("\n--- TEST 4: Simulación de Pity System (15 tiradas consecutivas sin Legendario) ---")

	var mgr := ItemPoolManager.new()
	mgr._populate_default_catalog()

	# Pesos regulares donde Legendary tiene 0% base
	var regular_weights: Dictionary = {
		Enums.Rarity.COMMON: 75.0,
		Enums.Rarity.UNCOMMON: 20.0,
		Enums.Rarity.RARE: 4.5,
		Enums.Rarity.EPIC: 0.5,
		Enums.Rarity.LEGENDARY: 0.0,
	}

	mgr.reset_pity_counters()
	_assert_test(mgr.chests_since_last_legendary == 0, "Contador de pity legendario inicializado en 0")

	# Realizar 14 tiradas de cofre regular sin suerte extra (player_luck = 1.0)
	var rolls_before_15_had_legendary: bool = false
	for i in range(1, 15):
		var draft := mgr.roll_chest_draft(1, regular_weights, 1.0, 3)
		for it in draft:
			if it.rarity == Enums.Rarity.LEGENDARY:
				rolls_before_15_had_legendary = true
		_assert_test(mgr.chests_since_last_legendary == i, "Pity legendario incrementado a %d tras tirada %d" % [i, i])

	_assert_test(not rolls_before_15_had_legendary, "No apareció legendario por azar antes del hard pity")

	# La tirada 15 DEBE forzar al menos un legendario
	var draft_15 := mgr.roll_chest_draft(1, regular_weights, 1.0, 3)
	var has_legendary_at_15: bool = false
	for it in draft_15:
		if it.rarity == Enums.Rarity.LEGENDARY:
			has_legendary_at_15 = true

	_assert_test(has_legendary_at_15, "La 15ª tirada forzó un ítem LEGENDARIO por hard pity")
	_assert_test(mgr.chests_since_last_legendary == 0, "Contador de pity legendario reseteado a 0 tras la tirada 15")

	mgr.queue_free()


## ─── TEST 5: Pity System: Descuento de umbral por Suerte (luck_discount) ─────
func _run_test_5_pity_luck_discount() -> void:
	print("\n--- TEST 5: Reducción del umbral de hard pity por suerte del jugador ---")

	var mgr := ItemPoolManager.new()
	mgr._populate_default_catalog()

	var regular_weights: Dictionary = {
		Enums.Rarity.COMMON: 75.0,
		Enums.Rarity.UNCOMMON: 20.0,
		Enums.Rarity.RARE: 4.5,
		Enums.Rarity.EPIC: 0.5,
		Enums.Rarity.LEGENDARY: 0.0,
	}

	# Con Suerte = 40.0, luck_discount = int(40 / 20) = 2. Umbral Legendario = 15 - 2 = 13.
	mgr.reset_pity_counters()
	for i in range(1, 13):
		mgr.roll_chest_draft(1, regular_weights, 40.0, 3)
		_assert_test(mgr.chests_since_last_legendary == i, "Contador en tirada %d" % i)

	# La tirada 13 debe activar el pity legendario
	var draft_13 := mgr.roll_chest_draft(1, regular_weights, 40.0, 3)
	var has_legendary_at_13: bool = false
	for it in draft_13:
		if it.rarity == Enums.Rarity.LEGENDARY:
			has_legendary_at_13 = true

	_assert_test(has_legendary_at_13, "Con Suerte=40, la 13ª tirada forzó LEGENDARIO (umbral 13)")
	_assert_test(mgr.chests_since_last_legendary == 0, "Contador reseteado a 0 tras pity con suerte")

	# Con Suerte extrema = 200.0, luck_discount = 10. Umbral piso = maxi(5, 15 - 10) = 5.
	mgr.reset_pity_counters()
	for i in range(1, 5):
		mgr.roll_chest_draft(1, regular_weights, 200.0, 3)

	var draft_5 := mgr.roll_chest_draft(1, regular_weights, 200.0, 3)
	var has_legendary_at_5: bool = false
	for it in draft_5:
		if it.rarity == Enums.Rarity.LEGENDARY:
			has_legendary_at_5 = true

	_assert_test(has_legendary_at_5, "Con Suerte=200, la 5ª tirada forzó LEGENDARIO (piso de 5 tiradas)")

	mgr.queue_free()


## ─── TEST 6: Efectos de orbital_relay y quantum_recompiler ────────────────────
func _run_test_6_orbital_relay_and_quantum_recompiler() -> void:
	print("\n--- TEST 6: Efectos de orbital_relay (10s satélite) y quantum_recompiler (+1 forja) ---")

	# 1. orbital_relay en SatelliteBeacon
	var beacon := SatelliteBeaconClass.new()
	_assert_test(is_equal_approx(beacon.plant_duration, 6.0), "Duración satelital base es 6.0s", "got %.1f" % beacon.plant_duration)

	var player := Player.new()
	player.inventory = InventoryComponent.new()
	var relay_item := ItemData.new()
	relay_item.item_id = &"orbital_relay"
	player.inventory.add_item(relay_item)

	beacon.check_orbital_relay(player)
	_assert_test(is_equal_approx(beacon.plant_duration, 4.0), "Con orbital_relay, duración satelital reducida a 4.0s", "got %.1f" % beacon.plant_duration)

	# 2. CombatSatelliteCoordinator.get_plant_duration()
	var coordinator := CombatSatelliteCoordinatorClass.new()
	var dummy_mg := MainGameClass.new()
	dummy_mg.player = player
	coordinator.setup(dummy_mg)
	_assert_test(is_equal_approx(coordinator.get_plant_duration(), 4.0), "Coordinator reporta 4.0s con jugador que posee orbital_relay")

	# Sin orbital_relay
	player.inventory.clear_items()
	_assert_test(is_equal_approx(coordinator.get_plant_duration(), 6.0), "Coordinator reporta 6.0s cuando jugador no tiene orbital_relay")

	# 3. quantum_recompiler en TransmutationStation
	var station := TransmutationStationClass.new()
	_assert_test(station.max_uses == 3 and station.uses_remaining == 3, "Forja Cuántica base tiene 3 usos", "max: %d, rem: %d" % [station.max_uses, station.uses_remaining])

	var recompiler_item := ItemData.new()
	recompiler_item.item_id = &"quantum_recompiler"
	player.inventory.add_item(recompiler_item)

	station.check_quantum_recompiler(player)
	_assert_test(station.max_uses == 4 and station.uses_remaining == 4, "Con quantum_recompiler, Forja Cuántica tiene 4 usos", "max: %d, rem: %d" % [station.max_uses, station.uses_remaining])

	# Consumir un uso y volver a entrar / verificar que check_quantum_recompiler no resetea
	station.consume_use()
	_assert_test(station.uses_remaining == 3, "Uso consumido correctamente (quedan 3)")
	station.check_quantum_recompiler(player)
	_assert_test(station.uses_remaining == 3, "check_quantum_recompiler no resetea usos restantes a 4 tras consumo")

	beacon.queue_free()
	station.queue_free()
	coordinator.queue_free()
	dummy_mg.queue_free()
	player.queue_free()


## ─── TEST 7: Interés de chronos_bank y recompensa de heavy_salvager ───────────
func _run_test_7_chronos_bank_and_heavy_salvager() -> void:
	print("\n--- TEST 7: Interés de chronos_bank (10% unspent, cap 50c) y heavy_salvager (+2HP, +3c) ---")

	var mg := MainGameClass.new()
	var player := Player.new()
	var char_data := CharacterData.new()
	char_data.max_health = 100.0
	player.stats = CharacterStats.new()
	player.stats.initialize(char_data)
	player.inventory = InventoryComponent.new()
	mg.player = player

	# 1. chronos_bank
	var bank_item := ItemData.new()
	bank_item.item_id = &"chronos_bank"
	player.inventory.add_item(bank_item)

	# 200 créditos -> 10% = 20c
	player.run_credits = 200
	mg.apply_chronos_bank_interest()
	_assert_test(player.run_credits == 220, "200c generó 20c de interés (total 220c)", "got %d" % player.run_credits)

	# 600 créditos -> 10% = 60c, pero tope 50c -> 650c
	player.run_credits = 600
	mg.apply_chronos_bank_interest()
	_assert_test(player.run_credits == 650, "600c generó tope de 50c de interés (total 650c)", "got %d" % player.run_credits)

	# 2. heavy_salvager
	var salvager_item := ItemData.new()
	salvager_item.item_id = &"heavy_salvager"
	player.inventory.add_item(salvager_item)

	var initial_hp := player.stats.get_stat(&"max_health")
	var initial_credits := player.run_credits

	mg.on_salvage_capsule_opened(player)

	var new_hp := player.stats.get_stat(&"max_health")
	var new_credits := player.run_credits

	_assert_test(is_equal_approx(new_hp, initial_hp + 2.0), "heavy_salvager otorgó +2.0 Vida Máxima", "got %.1f vs %.1f" % [new_hp, initial_hp + 2.0])
	_assert_test(new_credits == initial_credits + 3, "heavy_salvager otorgó +3 créditos", "got %d vs %d" % [new_credits, initial_credits + 3])

	# Verificar que modificadores existentes (ej. +20 HP flat) no se duplican indebidamente en la base
	var hp_mod := CharacterStats.StatModifier.new(&"mod_test_heart", 20.0, Enums.ModifierType.FLAT, self)
	player.stats.add_modifier(&"max_health", hp_mod)
	var hp_before_mod_test := player.stats.get_stat(&"max_health")
	var base_before_mod_test := player.stats.get_base_stat(&"max_health")
	mg.on_salvage_capsule_opened(player)
	var hp_after_mod_test := player.stats.get_stat(&"max_health")
	var base_after_mod_test := player.stats.get_base_stat(&"max_health")
	_assert_test(is_equal_approx(base_after_mod_test, base_before_mod_test + 2.0), "Base max_health subió exactamente +2.0 con modificadores presentes", "got %.1f vs %.1f" % [base_after_mod_test, base_before_mod_test + 2.0])
	_assert_test(is_equal_approx(hp_after_mod_test, hp_before_mod_test + 2.0), "Efectivo max_health subió exactamente +2.0 sin duplicar modificadores", "got %.1f vs %.1f" % [hp_after_mod_test, hp_before_mod_test + 2.0])

	mg.queue_free()
	player.queue_free()

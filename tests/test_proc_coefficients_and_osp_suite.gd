extends Node

## TestProcCoefficientsAndOspSuite.gd
## Batería automatizada de verificación para la Fase 3:
## Proc Coefficients, Rule Zero, Protocol OSP (One-Shot Protection) y Balística de Armas Lentas.

var _passed_count: int = 0
var _failed_count: int = 0

func _ready() -> void:
	# Watchdog de seguridad
	get_tree().create_timer(10.0).timeout.connect(func() -> void:
		push_error("[WATCHDOG TIMEOUT] TestProcCoefficientsAndOspSuite no finalizó en 10s.")
		get_tree().quit(1)
	)

	print("\n==================================================================")
	print("[PROC COEFFICIENTS & OSP SUITE] STARTING AUTOMATED VERIFICATION")
	print("==================================================================")

	_run_test_1_weapon_proc_coefficients()
	_run_test_2_rule_zero_child_procs()
	_run_test_3_osp_triggers_at_high_hp()
	_run_test_4_osp_does_not_trigger_below_threshold()
	_run_test_5_point_blank_pulse()
	_run_test_6_osp_with_shield()
	_run_test_7_osp_with_negative_armor()
	_run_test_8_point_blank_pulse_no_double_hit()
	_run_test_9_high_frequency_beam_icd()

	print("\n==================================================================")
	print("  VERIFICATION SUMMARY")
	print("  TOTAL TESTS: %d" % (_passed_count + _failed_count))
	print("  PASSED:      %d" % _passed_count)
	print("  FAILED:      %d" % _failed_count)
	if _failed_count == 0:
		print("  STATUS:      [PASS] ALL PHASE 3 TESTS PASSED PERFECTLY!")
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


## ─── TEST 1: Proc Coefficients across weapons ──────────────────────────────
func _run_test_1_weapon_proc_coefficients() -> void:
	print("\n--- TEST 1: Validate proc_coefficient values across weapons ---")

	var weapon_expectations: Dictionary = {
		"res://data/weapons/roster/rail_launcher.tres": 0.60,
		"res://data/weapons/roster/scatter_laser.tres": 0.25,
		"res://data/weapons/roster/sniper_rifle.tres": 0.25,
		"res://data/weapons/roster/swarm_missiles.tres": 0.40,
		"res://data/weapons/roster/hive_cannon.tres": 0.40,
		"res://data/weapons/roster/void_siphon.tres": 0.15,
		"res://data/weapons/roster/singularity_pulsar.tres": 0.15,
		"res://data/weapons/roster/plasma_flak.tres": 0.35,
		"res://data/weapons/roster/titan_shotgun.tres": 0.35,
		"res://data/weapons/roster/crescent_blade.tres": 1.00,
		"res://data/weapons/roster/tachyon_beam.tres": 0.10,
		"res://data/weapons/roster/singularity_cannon.tres": 0.20,
		"res://data/weapons/roster/solar_flare.tres": 0.20
	}

	for path: String in weapon_expectations.keys():
		var expected: float = weapon_expectations[path]
		_assert_test(ResourceLoader.exists(path), "Weapon file exists", path)
		if ResourceLoader.exists(path):
			var w := load(path) as WeaponData
			_assert_test(w != null, "Loads as WeaponData", path)
			if w:
				var is_match := is_equal_approx(w.proc_coefficient, expected)
				_assert_test(is_match, "proc_coefficient matches expected", "%s: got %.2f, expected %.2f" % [w.weapon_id, w.proc_coefficient, expected])


## ─── TEST 2: Rule Zero: Secondary effects have proc_coeff == 0.0 ──────────
func _run_test_2_rule_zero_child_procs() -> void:
	print("\n--- TEST 2: Rule Zero: secondary effect contexts have proc_coefficient == 0.0 ---")

	var parent_ctx := HitContext.create_direct_hit(50.0, true, 0.60)
	parent_ctx.source_weapon_id = &"rail_launcher"

	# Fork child hit as secondary effect
	var child_ctx := parent_ctx.fork_child_hit(25.0, 0.0, &"tesla_coil")
	_assert_test(is_equal_approx(child_ctx.proc_coefficient, 0.0), "Child proc coefficient is 0.0", "got %.2f" % child_ctx.proc_coefficient)
	_assert_test(child_ctx.can_proc(&"tesla_coil") == false, "can_proc returns false for triggering item")
	_assert_test(child_ctx.can_proc(&"pyroclastic_battery") == false, "can_proc returns false for ANY item when proc_coeff <= 0.0")

	# Test InventoryComponent with child_ctx
	var inventory := InventoryComponent.new()
	var test_item := ItemData.new()
	test_item.item_id = &"test_proc_item"
	var test_effect := ItemEffect.new()
	test_effect.trigger = Enums.TriggerType.ON_HIT
	test_effect.base_chance = 1.0
	test_item.effects = [test_effect]
	inventory.add_item(test_item, 1)

	# Execute hit procs with child_ctx (proc_coeff == 0.0) -> must NEVER trigger
	var dummy_node := Node.new()
	add_child(dummy_node)
	inventory.process_hit_procs(child_ctx, dummy_node)
	_assert_test(inventory.is_proc_on_cooldown(&"test_proc_item") == false, "Rule Zero prevents secondary hit from triggering new item procs")
	dummy_node.queue_free()


## ─── TEST 3: OSP triggers at >= 90% combined HP/Shield on lethal damage ────
func _run_test_3_osp_triggers_at_high_hp() -> void:
	print("\n--- TEST 3: OSP triggers when player >= 90% HP and takes lethal damage ---")

	var player := Player.new()
	add_child(player)
	player.stats.set_base_stat(&"armor", 0.0)
	var max_hp := player.stats.get_stat(&"max_health")
	player.current_health = max_hp # 100% HP (>= 90% threshold)
	player.is_invulnerable = false

	var osp_signal_received := [false]
	var remaining_hp_reported := [0.0]
	player.osp_triggered.connect(func(rem_hp: float) -> void:
		osp_signal_received[0] = true
		remaining_hp_reported[0] = rem_hp
	)

	# Deal massive lethal damage (1000.0)
	player.take_damage(1000.0)

	_assert_test(osp_signal_received[0], "OSP signal was emitted")
	_assert_test(is_equal_approx(player.current_health, 1.0), "Player survives with exactly 1 HP", "current_health = %.1f" % player.current_health)
	_assert_test(is_equal_approx(remaining_hp_reported[0], 1.0), "OSP signal passed remaining HP >= 1", "reported = %.1f" % remaining_hp_reported[0])
	_assert_test(player.is_invulnerable == true, "Player granted 0.5s I-frames after OSP trigger")

	player.free()


## ─── TEST 4: OSP does NOT trigger below 90% HP ─────────────────────────────
func _run_test_4_osp_does_not_trigger_below_threshold() -> void:
	print("\n--- TEST 4: OSP does NOT trigger when player is below 90% HP ---")

	var player := Player.new()
	add_child(player)
	player.stats.set_base_stat(&"armor", 0.0)
	var max_hp := player.stats.get_stat(&"max_health")
	player.current_health = max_hp * 0.50 # 50% HP (< 90% threshold)
	player.is_invulnerable = false

	var osp_signal_received := [false]
	player.osp_triggered.connect(func(_rem_hp: float) -> void:
		osp_signal_received[0] = true
	)

	# Deal lethal damage (1000.0)
	player.take_damage(1000.0)

	_assert_test(osp_signal_received[0] == false, "OSP signal was NOT emitted when below 90% HP")
	_assert_test(player.current_health <= 0.0 or player.is_dead == true, "Player dies from lethal hit without OSP")

	player.free()


class TestDummyEnemy extends CharacterBody2D:
	var current_health: float = 100.0
	var max_health: float = 100.0
	func take_damage(ctx: Variant) -> void:
		if ctx is HitContext:
			current_health -= ctx.final_damage
		elif ctx is float or ctx is int:
			current_health -= float(ctx)

## ─── TEST 5: Innate Point-Blank Pulse for slow weapons (CD > 1.1s) ──────────
func _run_test_5_point_blank_pulse() -> void:
	print("\n--- TEST 5: Innate Point-Blank Pulse for slow weapons when enemies < 80px ---")

	var factory := WeaponProjectileFactory.new()
	var player := Player.new()
	add_child(player)
	player.global_position = Vector2(500, 500)

	# Create a dummy enemy at distance 50px (< 80px)
	var enemy := TestDummyEnemy.new()
	enemy.add_to_group("enemies")
	enemy.global_position = player.global_position + Vector2(50.0, 0.0)
	add_child(enemy)

	# Fire point blank pulse check
	var pulse_triggered := factory.check_and_trigger_point_blank_pulse(player.global_position, 100.0, player, self)
	_assert_test(pulse_triggered, "Point-blank pulse triggered when enemy within 80px")

	# Verify enemy took damage: 30% of base damage (30.0)
	_assert_test(is_equal_approx(enemy.current_health, 70.0), "Enemy took 30% base damage from pulse", "enemy_hp = %.1f" % enemy.current_health)

	# Clean up enemy
	enemy.free()

	# Test with distant enemy at 150px (> 80px)
	var distant_enemy := TestDummyEnemy.new()
	distant_enemy.add_to_group("enemies")
	distant_enemy.global_position = player.global_position + Vector2(150.0, 0.0)
	add_child(distant_enemy)

	var pulse_triggered_distant := factory.check_and_trigger_point_blank_pulse(player.global_position, 100.0, player, self)
	_assert_test(pulse_triggered_distant == false, "Point-blank pulse does NOT trigger when enemy > 80px")

	distant_enemy.free()
	player.free()


## ─── TEST 6: OSP with Combined Shield & Health ──────────────────────────────
func _run_test_6_osp_with_shield() -> void:
	print("\n--- TEST 6: OSP with Combined Shield & Health ---")
	var player := Player.new()
	add_child(player)
	player.stats.set_base_stat(&"armor", 0.0)
	var max_hp := player.stats.get_stat(&"max_health")
	player.current_health = max_hp
	player.shield_controller.max_shield = 50.0
	player.shield_controller.current_shield = 50.0

	# Total combined = max_hp + 50.0, max_combined = max_hp + 50.0 (100% >= 90%)
	player.take_damage(max_hp + 500.0)
	_assert_test(not player.is_dead, "Player survived lethal hit with OSP while carrying shield")
	_assert_test(player.current_health >= 1.0, "Player preserved with at least 1 HP (current_health = %.1f)" % player.current_health)
	_assert_test(player.shield_controller.current_shield == 0.0, "Shield was completely depleted absorbing blow")
	player.free()


## ─── TEST 7: OSP with Negative Armor (Curse) ───────────────────────────────
func _run_test_7_osp_with_negative_armor() -> void:
	print("\n--- TEST 7: OSP with Negative Armor (Curse) ---")
	var player := Player.new()
	add_child(player)
	player.stats.set_base_stat(&"armor", -50.0) # Negative armor amplifies damage
	var max_hp := player.stats.get_stat(&"max_health")
	player.current_health = max_hp
	player.take_damage(max_hp + 500.0)
	_assert_test(not player.is_dead, "Player survived lethal hit under OSP despite -50 negative armor")
	_assert_test(player.current_health >= 1.0, "Player health remained >= 1 HP under negative armor (current_health = %.1f)" % player.current_health)
	player.free()


## ─── TEST 8: Point-Blank Pulse prevents double damage ──────────────────────
func _run_test_8_point_blank_pulse_no_double_hit() -> void:
	print("\n--- TEST 8: Point-Blank Pulse shockwave does not double-hit enemies ---")
	# Clean up any lingering shockwaves
	for child in get_children():
		if child is ShockwaveArea:
			child.free()

	var factory := WeaponProjectileFactory.new()
	var player := Player.new()
	add_child(player)
	player.global_position = Vector2(500, 500)

	var enemy := TestDummyEnemy.new()
	enemy.add_to_group("enemies")
	enemy.global_position = player.global_position + Vector2(40.0, 0.0)
	add_child(enemy)

	var pulse_triggered := factory.check_and_trigger_point_blank_pulse(player.global_position, 100.0, player, self)
	_assert_test(pulse_triggered, "Pulse triggered for point blank enemy")
	_assert_test(is_equal_approx(enemy.current_health, 70.0), "Initial health after innate pulse is 70.0")

	var shockwave: ShockwaveArea = null
	for child in get_children():
		if child is ShockwaveArea:
			shockwave = child as ShockwaveArea
			break
	_assert_test(shockwave != null, "ShockwaveArea child was spawned")
	if shockwave:
		_assert_test(shockwave.damaged_nodes.has(enemy), "Shockwave registered enemy in damaged_nodes to prevent double-hit")
		shockwave._process(0.05)
		_assert_test(is_equal_approx(enemy.current_health, 70.0), "Enemy did not take duplicate damage during shockwave update (hp = %.1f)" % enemy.current_health)
		shockwave.free()

	enemy.free()
	player.free()


## ─── TEST 9: Dynamic ICD throttling on high-frequency beams ────────────────
func _run_test_9_high_frequency_beam_icd() -> void:
	print("\n--- TEST 9: Dynamic ICD throttling on high-frequency beams ---")
	var inv := InventoryComponent.new()
	add_child(inv)

	var item := ItemData.new()
	item.item_id = &"test_beam_item"
	item.item_name = "Test Item"
	var eff := ItemEffect.new()
	eff.trigger = Enums.TriggerType.ON_HIT
	eff.base_chance = 1.0 # 100% base chance
	item.effects.append(eff)
	inv.add_item(item, 1)

	# Using proc_coefficient = 1.0 to ensure 100% deterministic roll for test
	var ctx := HitContext.create_direct_hit(10.0, false, 1.0)
	ctx.source_weapon_id = &"tachyon_beam"

	inv.process_hit_procs(ctx, self)
	var cd: float = inv.get_proc_cooldown(&"test_beam_item")
	_assert_test(cd > 0.0, "ICD was applied for high frequency weapon (cd = %.2fs)" % cd)
	_assert_test(is_equal_approx(cd, 0.15), "ICD matches Tachyon Beam threshold (0.15s)")
	_assert_test(inv.is_proc_on_cooldown(&"test_beam_item"), "Item is on cooldown")

	inv.tick_proc_cooldowns(0.20)
	_assert_test(not inv.is_proc_on_cooldown(&"test_beam_item"), "Cooldown expired after tick")
	inv.free()



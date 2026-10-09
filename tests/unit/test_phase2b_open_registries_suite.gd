extends BaseTestSuite

const CrisisEventDefinitionClass = preload("res://scenes/combat/events/definitions/crisis_event_definition.gd")
const WeaponProjectileFactoryClass = preload("res://scenes/combat/weapons/weapon_projectile_factory.gd")
const CrisisEventManagerClass = preload("res://scenes/combat/events/crisis_event_manager.gd")

func _ready() -> void:
	super._ready()
	print("==========================================================")
	print("[TEST] Running Phase 2.B Open Registries & Mod-Friendly Factories Unit Test")
	print("==========================================================\n")

	# 1. WeaponProjectileFactory extensible
	print("[1/3] Testing WeaponProjectileFactory custom strategy registration...")
	var factory = WeaponProjectileFactoryClass.new()

	var custom_called: Array[bool] = [false]
	var custom_behavior := CustomActiveTestBehavior.new(custom_called)
	factory.register_active_behavior(&"modded_plasma", custom_behavior)

	var dummy_inst := WeaponInstanceData.new()
	var dummy_wdata := WeaponData.new()
	dummy_wdata.weapon_id = &"modded_weapon"
	dummy_wdata.active_behavior_type = &"modded_plasma"
	dummy_inst.weapon_data = dummy_wdata

	var player := CharacterBody2D.new()
	var mock_script := GDScript.new()
	mock_script.source_code = "extends CharacterBody2D\nvar stats: CharacterStats = null\n"
	mock_script.reload()
	player.set_script(mock_script)
	var char_stats := CharacterStats.new()
	var dummy_char := CharacterData.new()
	dummy_char.attack_speed = 1.0
	dummy_char.max_health = 100.0
	char_stats.initialize(dummy_char)
	player.stats = char_stats
	add_child(player)

	var spawn_parent := Node2D.new()
	add_child(spawn_parent)

	factory.dispatch_active_fire(
		dummy_inst, Vector2.RIGHT, false, 0.0, 1.0, player,
		Vector2.ZERO, Vector2.RIGHT * 100.0, spawn_parent
	)
	assert_true(custom_called[0], "Custom ProjectileBehavior must be invoked through open registry")
	print("  ✓ Custom ProjectileBehavior registered and executed dynamically without modifying core factory")

	# 2. CrisisEventManager extensible
	print("\n[2/3] Testing CrisisEventManager custom crisis registration...")
	var crisis_mgr = CrisisEventManagerClass.new()
	add_child(crisis_mgr)
	crisis_mgr.auto_crisis_enabled = false

	var custom_crisis_executed: Array[bool] = [false]
	var def = CrisisEventDefinitionClass.new()
	def.id = "meteor_shower"
	def.title = "LLUVIA DE METEORITOS"
	def.subtitle = "Impactos cinéticos inminentes."
	def.tint = Color(1.0, 0.2, 0.2)
	def.on_execute = func() -> void:
		custom_crisis_executed[0] = true

	crisis_mgr.register_crisis(def)
	crisis_mgr._execute_crisis("meteor_shower")
	assert_true(custom_crisis_executed[0], "Custom CrisisEventDefinition must execute through open registry")
	assert_true(crisis_mgr.current_active_crisis == "meteor_shower", "Active crisis ID must match custom crisis")
	print("  ✓ Custom CrisisEventDefinition registered and executed without touching core manager code")

	# 3. CosmeticsManager dynamic discovery
	print("\n[3/3] Testing CosmeticsManager category file discovery...")
	var discovered := CosmeticsManager.discover_category_files()
	assert_true(discovered.has("ship"), "Discovered categories must contain 'ship'")
	assert_true(discovered.has("pilot"), "Discovered categories must contain 'pilot'")
	assert_true(discovered.has("weapon"), "Discovered categories must contain 'weapon'")
	assert_true(discovered.has("pet"), "Discovered categories must contain 'pet'")
	assert_true(discovered.has("navigator"), "Discovered categories must contain 'navigator'")
	print("  ✓ CosmeticsManager dynamically discovers all JSON categories from filesystem (%d found)" % discovered.size())

	player.queue_free()
	spawn_parent.queue_free()
	crisis_mgr.queue_free()

	pass_suite("Phase 2.B Open Registries unit tests PASSED successfully!")

const ProjectileBehaviorClass = preload("res://scenes/combat/weapons/behaviors/projectile_behavior.gd")

class CustomActiveTestBehavior extends ProjectileBehaviorClass:
	var call_flag: Array[bool]
	func _init(flag: Array[bool]) -> void:
		call_flag = flag
	func execute(
		_wdata: WeaponData, _inst: WeaponInstanceData, _ctx: HitContext,
		_aim_dir: Vector2, _is_focused: bool, _charge_ratio: float,
		_max_charge_time: float, _player: CharacterBody2D, _origin: Vector2,
		_mouse_pos: Vector2, _spawn_parent: Node, _count: int,
		_proj_speed: float, _size_stat: float
	) -> void:
		call_flag[0] = true

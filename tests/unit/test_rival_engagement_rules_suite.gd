class_name TestRivalEngagementRulesSuite
extends BaseTestSuite

## Suite de micro-pruebas unitarias para RivalEngagementBehavior.
## Valida transiciones de estado, zonas de proximidad y reglas de desafío vs perdón.

const RivalEngagementBehaviorScript = preload("res://scenes/combat/bosses/components/rival_engagement_behavior.gd")

func _ready() -> void:
	super._ready()
	print("==========================================================")
	print("[TEST] Running RivalEngagementBehavior Micro-Unit Suite")
	print("==========================================================\n")

	_test_initial_state_and_setup()
	_test_challenge_accumulation_and_combat_engagement()
	_test_spared_accumulation_and_peaceful_escape()
	_test_decay_outside_zones()

	pass_suite("RivalEngagementBehavior unit tests PASSED successfully")

func _test_initial_state_and_setup() -> void:
	print("[1/4] Testing initial state, setup and peaceful status...")
	var behavior: RefCounted = RivalEngagementBehaviorScript.new()
	behavior.setup(&"valentina", "Valentina")

	assert_true(behavior.current_state == RivalEngagementBehaviorScript.State.WARPING_IN, "State should be WARPING_IN initially")
	assert_true(behavior.is_peaceful(), "Must be peaceful initially")
	assert_true(behavior.spared_timer == 0.0, "Spared timer starts at 0.0")
	assert_true(behavior.challenge_timer == 0.0, "Challenge timer starts at 0.0")

	behavior.start_encounter()
	assert_true(behavior.current_state == RivalEngagementBehaviorScript.State.PEACEFUL_WARN, "State should be PEACEFUL_WARN after start_encounter")
	assert_true(behavior.is_peaceful(), "Must still be peaceful in PEACEFUL_WARN")

func _test_challenge_accumulation_and_combat_engagement() -> void:
	print("[2/4] Testing challenge timer accumulation and combat trigger...")
	var behavior: RefCounted = RivalEngagementBehaviorScript.new()
	behavior.setup(&"kira", "Kira")
	behavior.start_encounter()

	var engaged_called: Array[bool] = [false]
	behavior.combat_engaged.connect(func(_pid: StringName) -> void: engaged_called[0] = true)

	# Simular permanencia dentro del radio de reto (400 px <= COMBAT_TRIGGER_RADIUS 480 px)
	behavior.process_peaceful_warn(0.5, 400.0)
	assert_true(behavior.challenge_timer == 0.5, "Challenge timer should increment to 0.5")
	assert_true(behavior.current_state == RivalEngagementBehaviorScript.State.PEACEFUL_WARN, "Should not trigger combat prematurely")
	assert_true(not engaged_called[0], "combat_engaged signal should not fire yet")

	# Simular paso de tiempo restante hasta superar CHALLENGE_REQUIRED_TIME (2.0s)
	behavior.process_peaceful_warn(1.6, 400.0)
	assert_true(behavior.current_state == RivalEngagementBehaviorScript.State.DOGFIGHT, "Should transition to DOGFIGHT after 2.0s of challenge")
	assert_true(not behavior.is_peaceful(), "Should not be peaceful in DOGFIGHT")
	assert_true(engaged_called[0], "combat_engaged signal must have fired")

func _test_spared_accumulation_and_peaceful_escape() -> void:
	print("[3/4] Testing spared timer accumulation and peaceful warp-out...")
	var behavior: RefCounted = RivalEngagementBehaviorScript.new()
	behavior.setup(&"selene", "Selene")
	behavior.start_encounter()

	var escape_called: Array[bool] = [false]
	behavior.warped_out_peacefully.connect(func(_pid: StringName, _name: String) -> void: escape_called[0] = true)

	# Simular alejamiento masivo (> ESCAPE_RADIUS 1450 px)
	for i in range(25):
		behavior.process_peaceful_warn(0.2, 1500.0)

	assert_true(behavior.current_state == RivalEngagementBehaviorScript.State.WARPING_OUT, "Should transition to WARPING_OUT after 5.0s spared time")
	assert_true(escape_called[0], "warped_out_peacefully signal must have fired")

func _test_decay_outside_zones() -> void:
	print("[4/4] Testing timer decay when leaving threshold zones...")
	var behavior: RefCounted = RivalEngagementBehaviorScript.new()
	behavior.setup(&"roxy", "Roxy")
	behavior.start_encounter()

	# Acumular algo de reto
	behavior.process_peaceful_warn(1.0, 400.0)
	assert_true(behavior.challenge_timer > 0.0, "Challenge timer accumulated")

	# Alejarse a zona media (800 px: > 480 px pero < 1450 px)
	behavior.process_peaceful_warn(1.0, 800.0)
	assert_true(behavior.challenge_timer < 1.0, "Challenge timer should decay when player is outside combat radius")

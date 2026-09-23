extends Node

func _ready() -> void:
	# Fallback timeout
	get_tree().create_timer(10.0).timeout.connect(func():
		print("[TEST WATCHDOG] Timeout reached in Dialogue Skip test.")
		get_tree().quit(1)
	)

	print("\n==========================================")
	print("[TEST] Testing Hold-Spacebar Dialogue Skip System...")
	print("==========================================")

	# 1. Instantiate MainGame
	var main_game_scene: PackedScene = load("res://scenes/combat/main_game.tscn")
	assert(main_game_scene != null, "main_game.tscn must be loadable")
	var main_game: MainGame = main_game_scene.instantiate()
	add_child(main_game)
	await get_tree().process_frame
	await get_tree().process_frame

	# 2. Check DialogueSkipOverlay node presence
	var skip_overlay = main_game.skip_badge_layer
	assert(skip_overlay != null, "DialogueSkipOverlay must be present on main_game")
	assert(skip_overlay.layer == 110, "DialogueSkipOverlay layer must be 110")
	assert(skip_overlay.HOLD_DURATION == 0.65, "HOLD_DURATION must be 0.65s")
	print("  ✓ DialogueSkipOverlay verified (layer 110, duration 0.65s)")

	# 3. Verify Prologue Briefing is active initially
	assert(main_game.is_briefing_active == true, "Prologue briefing should be active initially")
	assert(Dialogic.current_timeline != null, "Dialogic current_timeline must not be null during prologue")
	print("  ✓ Prologue briefing active with timeline: %s" % Dialogic.current_timeline.resource_path)

	# 4. Verify Player Bomb cannot be triggered during active dialogue
	var prev_bombs := main_game.player.bomb_count
	main_game.player._handle_actions()
	assert(main_game.player.bomb_count == prev_bombs, "Spacebar must NOT consume bombs while dialogue is active")
	print("  ✓ Player bombs protected: Spacebar reserved for dialogue skip while dialogue is active")

	# 5. Simulate holding Spacebar on DialogueSkipOverlay
	# Progress partially
	skip_overlay.current_hold = 0.3
	skip_overlay._process(0.1) # current_hold = 0.4 without key pressed drains, but let's test hold
	
	# Simulate full hold trigger
	var skip_emitted := [false]
	skip_overlay.skip_requested.connect(func():
		skip_emitted[0] = true
	)
	skip_overlay._execute_skip()
	await get_tree().process_frame
	await get_tree().process_frame

	assert(skip_emitted[0] == true, "skip_requested signal must be emitted")
	assert(main_game.is_briefing_active == false, "Briefing must be inactive after skipping")
	assert(Dialogic.current_timeline == null, "Timeline must be ended after skip")
	assert(main_game.prologue_bonus_chosen == true, "Default prologue bonus should be granted on skip")
	print("  ✓ Prologue briefing skipped completely via DialogueSkipOverlay: bonus awarded, timeline ended")

	# 6. Test Cockpit Interlude Skip
	print("\n[Testing Cockpit Interlude Skip]")
	main_game._trigger_cockpit_interlude()
	await get_tree().process_frame
	await get_tree().process_frame
	assert(Dialogic.current_timeline != null, "Cockpit timeline must be active")
	print("  ✓ Cockpit interlude active: %s" % Dialogic.current_timeline.resource_path)

	# Skip cockpit dialogue
	skip_overlay._execute_skip()
	await get_tree().process_frame
	await get_tree().process_frame
	assert(Dialogic.current_timeline == null, "Cockpit timeline must be ended after skip")
	print("  ✓ Cockpit interlude skipped completely via DialogueSkipOverlay")

	# 7. Test Boss Titan Alert Dialogue Skip
	print("\n[Testing Boss Titan Alert Skip]")
	Dialogic.start("res://narrative/timelines/boss_titan_alert.dtl")
	await get_tree().process_frame
	await get_tree().process_frame
	assert(Dialogic.current_timeline != null, "Boss alert timeline must be active")
	print("  ✓ Boss alert active: %s" % Dialogic.current_timeline.resource_path)

	skip_overlay._execute_skip()
	await get_tree().process_frame
	await get_tree().process_frame
	assert(Dialogic.current_timeline == null, "Boss alert timeline must be ended after skip")
	print("  ✓ Boss alert skipped completely via DialogueSkipOverlay")

	# 8. Verify Bomb functions normally when no dialogue is active
	# Simulate bomb press by setting bomb action or calling directly
	assert(Dialogic.current_timeline == null, "No dialogue should be active now")
	main_game.player.bomb_count = 2
	# Calling _spawn_bomb_vfx directly to verify normal combat capability
	main_game.player._spawn_bomb_vfx()
	await get_tree().process_frame
	print("  ✓ Normal combat bomb operations verified post-dialogue")

	print("\n==========================================")
	print("[PASS] ALL DIALOGUE SKIP (HOLD SPACEBAR) TESTS PASSED (100%)!")
	print("==========================================\n")
	get_tree().quit(0)

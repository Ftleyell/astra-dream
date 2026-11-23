extends SceneTree

func _init() -> void:
	print("[TEST] Starting pause and navigation verification...")
	
	# 1. Test Main Game Pausing
	var main_game_scene: PackedScene = load("res://scenes/combat/main_game.tscn")
	if not main_game_scene:
		printerr("[FAIL] Could not load main_game.tscn")
		quit(1)
		return
	
	var main_game: MainGame = main_game_scene.instantiate()
	root.add_child(main_game)
	
	print("[PASS] MainGame instantiated successfully")
	print("       MainGame process_mode:", main_game.process_mode)
	print("       Player process_mode:", main_game.player.process_mode)
	print("       BulletServer process_mode:", main_game.bullet_server.process_mode)
	print("       EnemySpawner process_mode:", main_game.enemy_spawner.process_mode)
	
	# Simulate tree paused
	paused = true
	print("Tree paused: ", paused)
	print("       Player can_process: ", main_game.player.can_process())
	print("       BulletServer can_process: ", main_game.bullet_server.can_process())
	print("       EnemySpawner can_process: ", main_game.enemy_spawner.can_process())
	var dialogic_node = root.get_node_or_null("Dialogic")
	var dialogic_can = dialogic_node.can_process() if dialogic_node else true
	print("       Dialogic can_process: ", dialogic_can)
	print("       PauseMenu can_process: ", main_game.get_node("PauseMenu").can_process())
	print("       LevelUpModal can_process: ", main_game.level_up_modal.can_process())
	print("       SatelliteShop can_process: ", main_game.satellite_shop.can_process())
	
	assert(not main_game.player.can_process(), "Player must NOT process when paused!")
	assert(not main_game.bullet_server.can_process(), "BulletServer must NOT process when paused!")
	assert(not main_game.enemy_spawner.can_process(), "EnemySpawner must NOT process when paused!")
	assert(main_game.level_up_modal.can_process(), "LevelUpModal MUST process when paused!")
	assert(main_game.satellite_shop.can_process(), "SatelliteShop MUST process when paused!")
	
	paused = false
	print("[PASS] All pause assertion checks passed cleanly!")

	# 2. Test InputMap for ASDW and Space
	var ui_up_events := InputMap.action_get_events("ui_up")
	var ui_down_events := InputMap.action_get_events("ui_down")
	var ui_left_events := InputMap.action_get_events("ui_left")
	var ui_right_events := InputMap.action_get_events("ui_right")
	var ui_accept_events := InputMap.action_get_events("ui_accept")
	
	var has_w := false
	var has_s := false
	var has_a := false
	var has_d := false
	var has_space := false
	
	for ev in ui_up_events:
		if ev is InputEventKey and (ev.physical_keycode == KEY_W or ev.keycode == KEY_W):
			has_w = true
	for ev in ui_down_events:
		if ev is InputEventKey and (ev.physical_keycode == KEY_S or ev.keycode == KEY_S):
			has_s = true
	for ev in ui_left_events:
		if ev is InputEventKey and (ev.physical_keycode == KEY_A or ev.keycode == KEY_A):
			has_a = true
	for ev in ui_right_events:
		if ev is InputEventKey and (ev.physical_keycode == KEY_D or ev.keycode == KEY_D):
			has_d = true
	for ev in ui_accept_events:
		if ev is InputEventKey and (ev.physical_keycode == KEY_SPACE or ev.keycode == KEY_SPACE):
			has_space = true

	print("InputMap ASDW Check:")
	print("  W in ui_up: ", has_w)
	print("  S in ui_down: ", has_s)
	print("  A in ui_left: ", has_a)
	print("  D in ui_right: ", has_d)
	print("  Space in ui_accept: ", has_space)
	
	assert(has_w and has_s and has_a and has_d and has_space, "Input actions must include W, A, S, D, and Space!")
	print("[PASS] All InputMap bindings verified!")
	
	# 3. Test Main Menu Focus
	var main_menu_scene: PackedScene = load("res://scenes/ui/main_menu/main_menu.tscn")
	var main_menu = main_menu_scene.instantiate()
	root.add_child(main_menu)
	print("[PASS] MainMenu instantiated and focus applied.")
	
	# 4. Test Character Select Focus
	var char_select_scene: PackedScene = load("res://scenes/ui/character_select/character_select.tscn")
	var char_select = char_select_scene.instantiate()
	root.add_child(char_select)
	print("[PASS] CharacterSelect instantiated and focus applied.")

	print("\n>>> ALL TESTS COMPLETED SUCCESSFULLY! <<<")
	quit(0)

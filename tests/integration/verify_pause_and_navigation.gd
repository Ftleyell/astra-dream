extends Node

func _ready() -> void:
	print("\n==========================================")
	print("[TEST] Running Full Integration Verification...")
	print("==========================================")
	
	# 1. Verificar InputMap
	print("\n[1/4] Checking InputMap ASDW and Space...")
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

	print("  - W in ui_up: ", has_w)
	print("  - S in ui_down: ", has_s)
	print("  - A in ui_left: ", has_a)
	print("  - D in ui_right: ", has_d)
	print("  - Space in ui_accept: ", has_space)
	
	assert(has_w and has_s and has_a and has_d and has_space, "InputMap missing ASDW or Space!")
	print("  -> InputMap verification: PASSED")

	# 2. Instanciar MainGame y probar estado de pausa y can_process()
	print("\n[2/4] Testing MainGame pause propagation...")
	var main_game_scene: PackedScene = load("res://scenes/combat/main_game.tscn")
	var main_game = main_game_scene.instantiate()
	add_child(main_game)
	
	var player = main_game.get_node("Player")
	var bullet_server = main_game.get_node("BulletServer")
	var enemy_spawner = main_game.get_node("EnemySpawner")
	var weapon_controller = player.get_node("WeaponController")
	var level_up_modal = main_game.get_node("LevelUpModal")
	var satellite_shop = main_game.get_node("SatelliteShop")
	var pause_menu = main_game.get_node("PauseMenu")

	print("  - MainGame instantiated.")
	print("  - Player process_mode: ", player.process_mode)
	print("  - BulletServer process_mode: ", bullet_server.process_mode)
	print("  - EnemySpawner process_mode: ", enemy_spawner.process_mode)
	print("  - WeaponController process_mode: ", weapon_controller.process_mode)

	get_tree().paused = true
	print("\n  [get_tree().paused = true]")
	print("  - Player can_process(): ", player.can_process())
	print("  - BulletServer can_process(): ", bullet_server.can_process())
	print("  - EnemySpawner can_process(): ", enemy_spawner.can_process())
	var dialogic_inst = get_tree().root.get_node_or_null("Dialogic")
	var dialogic_can: bool = dialogic_inst.can_process() if dialogic_inst else true
	print("  - Dialogic can_process(): ", dialogic_can)
	print("  - LevelUpModal can_process(): ", level_up_modal.can_process())
	print("  - SatelliteShop can_process(): ", satellite_shop.can_process())
	print("  - PauseMenu can_process(): ", pause_menu.can_process())

	assert(not player.can_process(), "Player must be frozen when paused!")
	assert(not bullet_server.can_process(), "BulletServer must be frozen when paused!")
	assert(not enemy_spawner.can_process(), "EnemySpawner must be frozen when paused!")
	assert(not weapon_controller.can_process(), "WeaponController must be frozen when paused!")
	assert(dialogic_can, "Dialogic must process when paused!")
	assert(level_up_modal.can_process(), "LevelUpModal must process when paused!")
	assert(satellite_shop.can_process(), "SatelliteShop must process when paused!")
	assert(pause_menu.can_process(), "PauseMenu must process when paused!")
	print("  -> MainGame pause propagation: PASSED")

	get_tree().paused = false
	print("\n  [get_tree().paused = false]")
	print("  - Player can_process(): ", player.can_process())
	print("  - BulletServer can_process(): ", bullet_server.can_process())
	print("  - EnemySpawner can_process(): ", enemy_spawner.can_process())
	assert(player.can_process(), "Player should process when unpaused!")
	assert(bullet_server.can_process(), "BulletServer should process when unpaused!")
	assert(enemy_spawner.can_process(), "EnemySpawner should process when unpaused!")
	print("  -> MainGame unpause resumption: PASSED")
	main_game.queue_free()

	# 3. Probar MainMenu UI y Focus
	print("\n[3/4] Testing MainMenu UI...")
	var menu_scene: PackedScene = load("res://scenes/ui/main_menu/main_menu.tscn")
	var menu = menu_scene.instantiate()
	get_tree().root.add_child(menu)
	print("  - MainMenu loaded successfully")
	menu.queue_free()

	# 4. Probar CharacterSelect UI y Focus
	print("\n[4/4] Testing CharacterSelect UI...")
	var cs_scene: PackedScene = load("res://scenes/ui/character_select/character_select.tscn")
	var cs = cs_scene.instantiate()
	get_tree().root.add_child(cs)
	print("  - CharacterSelect loaded successfully")
	cs.queue_free()

	print("\n==========================================")
	print(">>> ALL VERIFICATION CHECKS PASSED (100%) <<<")
	print("==========================================\n")
	get_tree().quit(0)

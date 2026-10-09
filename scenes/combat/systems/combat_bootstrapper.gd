class_name CombatBootstrapper
extends RefCounted

## Inicializador desacoplado de loadout, entidades y atajos de debug al arrancar la partida.
## Extraído de MainGame para modularidad y separación de responsabilidades.

static func sync_character_loadout() -> void:
	var sel_char: StringName = SaveManager.get_selected_character()
	if sel_char.is_empty():
		return

	var loadout: Dictionary = SaveManager.get_character_loadout(sel_char)
	if loadout.has("selected_pet") and not str(loadout["selected_pet"]).is_empty():
		SaveManager.set_selected_pet(StringName(str(loadout["selected_pet"])))
	if loadout.has("selected_navigator") and not str(loadout["selected_navigator"]).is_empty():
		SaveManager.set_selected_navigator(StringName(str(loadout["selected_navigator"])))

	var cur_p_str: String = String(SaveManager.get_selected_pet()).to_lower()
	var p_skin: String = str(loadout.get("equipped_pet_skin", ""))
	if not p_skin.is_empty():
		SaveManager.equip_skin("pet:" + cur_p_str, p_skin)
	else:
		SaveManager.unequip_skin("pet:" + cur_p_str)

	var cur_n_str: String = String(SaveManager.get_selected_navigator()).to_lower()
	var n_skin: String = str(loadout.get("equipped_navigator_skin", ""))
	if not n_skin.is_empty():
		SaveManager.equip_skin("navigator:" + cur_n_str, n_skin)
	else:
		SaveManager.unequip_skin("navigator:" + cur_n_str)

static func handle_debug_jump_requests(main_game: Node2D) -> bool:
	if not is_instance_valid(main_game):
		return false

	var skip_badge_layer: CanvasLayer = main_game.get("skip_badge_layer") as CanvasLayer

	# 1. Debug directo a jefe
	var debug_boss: String = DebugManager.consume_pending_debug_boss() if (DebugManager and DebugManager.has_method("consume_pending_debug_boss")) else ""
	var auto_die: bool = DebugManager.consume_pending_auto_trigger_death() if (DebugManager and DebugManager.has_method("consume_pending_auto_trigger_death")) else false
	if debug_boss != "":
		main_game.set("is_briefing_active", false)
		main_game.set("prologue_bonus_chosen", true)
		PauseArbitrator.force_unpause_all()
		if skip_badge_layer:
			skip_badge_layer.hide()
		if main_game.has_method("jump_to_boss"):
			main_game.jump_to_boss(debug_boss)
		if auto_die:
			var tw := main_game.create_tween()
			tw.tween_interval(0.35)
			tw.tween_callback(func():
				var cur_b: Node2D = main_game.get("current_boss") as Node2D
				if is_instance_valid(cur_b) and cur_b.has_method("_die"):
					cur_b._die()
			)
		return true

	# 2. Debug directo a oleada 16 (Rutas)
	var debug_route: String = DebugManager.consume_pending_debug_route() if (DebugManager and DebugManager.has_method("consume_pending_debug_route")) else ""
	if debug_route != "":
		main_game.set("is_briefing_active", false)
		main_game.set("prologue_bonus_chosen", true)
		PauseArbitrator.force_unpause_all()
		if skip_badge_layer:
			skip_badge_layer.hide()
		if main_game.has_method("jump_to_wave_16"):
			main_game.jump_to_wave_16(debug_route)
		return true

	# 3. Debug directo a piloto rival
	var debug_rival: bool = DebugManager.consume_pending_rival_spawn() if (DebugManager and DebugManager.has_method("consume_pending_rival_spawn")) else false
	if debug_rival:
		main_game.set("is_briefing_active", false)
		main_game.set("prologue_bonus_chosen", true)
		main_game.set("is_pre_round", false)
		PauseArbitrator.force_unpause_all()
		if skip_badge_layer:
			skip_badge_layer.hide()
		main_game.get_tree().create_timer(0.5, false).timeout.connect(func() -> void:
			if main_game.has_method("spawn_next_rival_pilot"):
				main_game.spawn_next_rival_pilot()
		)
		return true

	# 4. Mid-run resume
	if SaveManager.is_resuming_run:
		SaveManager.is_resuming_run = false
		var active_data := SaveManager.load_active_run()
		if not active_data.is_empty():
			if main_game.has_method("restore_run_state"):
				main_game.restore_run_state(active_data)
			return true

	# 5. Debug tragamonedas
	var is_slot_test: bool = DebugManager.consume_pending_slot_machine_test() if (DebugManager and DebugManager.has_method("consume_pending_slot_machine_test")) else false
	if is_slot_test:
		main_game.set("is_briefing_active", false)
		main_game.set("prologue_bonus_chosen", true)
		PauseArbitrator.force_unpause_all()
		if skip_badge_layer:
			skip_badge_layer.hide()
		var player: Player = main_game.get("player") as Player
		if is_instance_valid(player):
			player.run_credits = maxi(int(player.run_credits), 25000)
			var hud: GameHUD = main_game.get("hud") as GameHUD
			if hud:
				hud.update_credits(player.run_credits)
			if main_game.has_method("_spawn_next_satellite_for_wave"):
				main_game._spawn_next_satellite_for_wave()
			main_game.call_deferred("_spawn_slot_machine", player.global_position + Vector2(0, -35.0))
		return true

	# 6. Debug planetas
	var is_planet_test: bool = DebugManager.consume_pending_planet_test() if (DebugManager and DebugManager.has_method("consume_pending_planet_test")) else false
	if is_planet_test:
		main_game.set("is_briefing_active", false)
		main_game.set("prologue_bonus_chosen", true)
		PauseArbitrator.force_unpause_all()
		if skip_badge_layer:
			skip_badge_layer.hide()
		var enemy_spawner = main_game.get("enemy_spawner")
		if enemy_spawner:
			enemy_spawner.process_mode = Node.PROCESS_MODE_DISABLED
		var player: Player = main_game.get("player") as Player
		if is_instance_valid(player) and player.stats:
			player.stats.add_modifier(&"move_speed", CharacterStats.StatModifier.new(&"planet_test_speed", 150.0, false, main_game))
		var sdm = main_game.get("space_debris_manager")
		if sdm:
			sdm.call_deferred("spawn_debug_planets", main_game, player)
		return true

	return false

static func initialize_session(main_game: Node2D, player: Player, hud: GameHUD) -> void:
	var debug_mgr: Node = main_game.get_node_or_null("/root/DebugManager")
	if debug_mgr and debug_mgr.has_method("is_infinite_credits_active") and debug_mgr.is_infinite_credits_active():
		player.run_credits = 999999
	if hud:
		hud.update_credits(player.run_credits)
		hud.update_exp(player.current_exp, player.exp_to_next, player.current_level)
		hud.update_wave_status(main_game.get("current_wave"), main_game.get("wave_timer"), main_game.get("wave_satellites_spawned"), 1)

static func launch_session(main_game: MainGame, player: Player, hud: GameHUD) -> void:
	var ctx_script := load("res://scenes/combat/systems/combat_context.gd")
	var pipeline_script := load("res://scenes/combat/directors/combat_wave_pipeline.gd")

	main_game.combat_context = ctx_script.new()
	main_game.combat_context.initialize(player, main_game.camera, hud, main_game.bullet_server, main_game.enemy_spawner, main_game.space_object_spawner, main_game.chest_director, main_game.satellite_shop, main_game)

	var pipe = pipeline_script.new()
	pipe.name = "CombatWavePipeline"
	main_game.add_child(pipe)
	main_game.wave_pipeline = pipe
	pipe.setup_pipeline(
		main_game.combat_context,
		Callable(main_game, "_on_wave_pipeline_advanced"),
		Callable(main_game, "_on_wave_pipeline_hud_update")
	)
	pipe.wave_completed.connect(func(_idx: int) -> void:
		main_game._on_wave_completed()
	)

	pipe.register_subsystem(main_game.boss_coordinator)
	pipe.register_subsystem(main_game.satellite_coordinator)
	pipe.register_subsystem(main_game.loot_coordinator)
	pipe.register_subsystem(main_game.narrative_director)

	main_game.last_anchor_pos = player.global_position
	main_game.process_mode = Node.PROCESS_MODE_ALWAYS
	initialize_session(main_game, player, hud)

	if main_game.space_debris_manager:
		main_game.space_debris_manager.spawn_environment_actors(main_game)

	if handle_debug_jump_requests(main_game):
		return

	main_game._spawn_next_satellite_for_wave()

	if main_game.chest_director:
		var green_cards: int = player.inventory.get_item_count(&"credit_card_green") if (player and player.inventory) else 0
		main_game.chest_director.on_new_wave(main_game.current_wave, green_cards)
	main_game._spawn_wave_chests()
	main_game._start_prologue_briefing()



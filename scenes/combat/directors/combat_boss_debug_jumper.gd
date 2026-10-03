class_name CombatBossDebugJumper
extends RefCounted

## Utilidad desacoplada para saltos de prueba/debug a encuentros de colosos y oleadas finales.
## Prepara estado del jugador, créditos, nivel, ruta y limpia entidades activas.

static func jump_to_boss(main_game: Node2D, coordinator: Node, boss_id: String) -> void:
	if not main_game or not is_instance_valid(main_game) or not coordinator:
		return
	main_game.set("is_pre_round", false)
	main_game.set("is_briefing_active", false)
	main_game.set("is_cockpit_active", false)
	main_game.set("is_boss_transmission_active", false)
	main_game.set("is_victory_dialogue_active", false)
	main_game.set("is_rival_cinematic_active", false)
	main_game.set("prologue_bonus_chosen", true)

	var backdrop: Node = main_game.get_node_or_null("DialogueBackdropLayer")
	if backdrop:
		if "hold_dimmer" in backdrop:
			backdrop.set("hold_dimmer", false)
		if backdrop.has_method("fade_out"):
			backdrop.fade_out(0.0)

	var skip_badge: CanvasLayer = main_game.get("skip_badge_layer") as CanvasLayer
	if skip_badge:
		skip_badge.hide()

	main_game.set("wave_timer", 30.0)
	main_game.set("_wave_encounter_pending", false)

	var cb: Node2D = main_game.get("current_boss") as Node2D
	if cb and is_instance_valid(cb):
		cb.queue_free()
		main_game.set("current_boss", null)

	var cr: Node2D = main_game.get("current_rival") as Node2D
	if cr and is_instance_valid(cr):
		cr.queue_free()
		main_game.set("current_rival", null)

	var cs = main_game.get("current_satellite")
	if cs and is_instance_valid(cs):
		cs.queue_free()
		main_game.set("current_satellite", null)

	main_game.set("wave_satellites_spawned", 1)
	var hud: GameHUD = main_game.get("hud") as GameHUD
	if hud and hud.has_method("clear_satellite"):
		hud.clear_satellite()

	if boss_id == "boss_astra_prime":
		jump_to_wave_16(main_game, coordinator, "neutral")
		return

	var target_scene: PackedScene = coordinator.boss_mothership_scene
	var target_wave: int = 14
	match boss_id:
		"boss_hermit_void":
			target_scene = coordinator.boss_hermit_scene
			target_wave = 2
		"boss_broken_mirror":
			target_scene = coordinator.boss_broken_mirror_scene
			target_wave = 5
		"boss_ash_clock":
			target_scene = coordinator.boss_ash_clock_scene
			target_wave = 8
		"boss_overflow_vortex":
			target_scene = coordinator.boss_overflow_vortex_scene
			target_wave = 11
		"boss_mothership":
			target_scene = coordinator.boss_mothership_scene
			target_wave = 14
		_:
			target_scene = coordinator.boss_mothership_scene
			target_wave = 14

	main_game.set("current_wave", target_wave)
	main_game.set("_wave_encounter_checked_for_wave", target_wave)
	main_game.set("_wave_encounter_spawned_for_wave", 0)
	main_game.set("_wave_encounter_pending", false)

	var player: Node2D = main_game.get("player") as Node2D
	if is_instance_valid(player):
		player.set("velocity", Vector2.ZERO)
		var p_lvl: int = int(player.get("current_level"))
		if p_lvl < (target_wave * 2):
			player.set("current_level", maxi(target_wave * 2, 6))
			if hud:
				hud.update_exp(0, 100, int(player.get("current_level")))
		var cur_cred: int = int(player.get("run_credits"))
		player.set("run_credits", maxi(cur_cred, 1200))
		if hud:
			hud.update_credits(int(player.get("run_credits")))

	if hud:
		hud.update_wave_status(target_wave, 30.0, 1, 1)

	coordinator.spawn_wave_boss(target_scene)

static func jump_to_wave_16(main_game: Node2D, coordinator: Node, route: String = "neutral") -> void:
	if not main_game or not is_instance_valid(main_game) or not coordinator:
		return
	main_game.set("is_pre_round", false)
	main_game.set("is_briefing_active", false)
	main_game.set("is_cockpit_active", false)
	main_game.set("is_boss_transmission_active", false)
	main_game.set("is_victory_dialogue_active", false)
	main_game.set("is_rival_cinematic_active", false)
	main_game.set("prologue_bonus_chosen", true)

	var backdrop: Node = main_game.get_node_or_null("DialogueBackdropLayer")
	if backdrop:
		if "hold_dimmer" in backdrop:
			backdrop.set("hold_dimmer", false)
		if backdrop.has_method("fade_out"):
			backdrop.fade_out(0.0)

	var skip_badge: CanvasLayer = main_game.get("skip_badge_layer") as CanvasLayer
	if skip_badge:
		skip_badge.hide()

	main_game.set("current_wave", 16)
	main_game.set("wave_timer", 30.0)
	main_game.set("_wave_encounter_checked_for_wave", 16)
	main_game.set("_wave_encounter_spawned_for_wave", 0)
	main_game.set("_wave_encounter_pending", false)

	var cb: Node2D = main_game.get("current_boss") as Node2D
	if cb and is_instance_valid(cb):
		cb.queue_free()
		main_game.set("current_boss", null)

	var cr: Node2D = main_game.get("current_rival") as Node2D
	if cr and is_instance_valid(cr):
		cr.queue_free()
		main_game.set("current_rival", null)

	var cs = main_game.get("current_satellite")
	if cs and is_instance_valid(cs):
		cs.queue_free()
		main_game.set("current_satellite", null)

	main_game.set("wave_satellites_spawned", 1)
	var hud: GameHUD = main_game.get("hud") as GameHUD
	if hud and hud.has_method("clear_satellite"):
		hud.clear_satellite()

	var player: Node2D = main_game.get("player") as Node2D
	if is_instance_valid(player):
		player.set("velocity", Vector2.ZERO)
		var cam: Camera2D = main_game.get_tree().get_first_node_in_group("camera") as Camera2D
		if cam:
			cam.global_position = player.global_position

	var r_spared: Array[StringName] = []
	var r_killed: Array[StringName] = []
	if route == "pacifist":
		r_spared = [&"nova", &"valentina", &"kira", &"selene", &"roxy"]
	elif route == "slayer" or route == "genocida":
		r_killed = [&"nova", &"valentina", &"kira", &"selene", &"roxy"]
	else:
		r_spared = [&"nova", &"valentina"]
		r_killed = [&"kira", &"selene"]
	main_game.set("rivals_spared", r_spared)
	main_game.set("rivals_killed", r_killed)

	if is_instance_valid(player):
		var p_lvl: int = int(player.get("current_level"))
		if p_lvl < 15:
			player.set("current_level", 15)
			var p_stats = player.get("stats")
			if p_stats:
				p_stats.add_modifier(&"max_health", CharacterStats.StatModifier.new(&"debug_w16_hull", 100.0, false, main_game))
				player.set("current_health", p_stats.get_stat(&"max_health"))
			if hud:
				hud.update_exp(0, 100, 15)
		if route == "slayer" or route == "genocida":
			var w_ctrl := player.get_node_or_null("WeaponController") as WeaponController
			if w_ctrl:
				var rival_weapons: Array[String] = [
					"res://data/weapons/roster/crescent_blade.tres",
					"res://data/weapons/roster/sonic_burst.tres",
					"res://data/weapons/roster/plasma_spear.tres"
				]
				for w_path in rival_weapons:
					if ResourceLoader.exists(w_path):
						var w_res := load(w_path) as WeaponData
						if w_res:
							w_ctrl.add_weapon(w_res)

	if hud:
		hud.update_wave_status(16, 30.0, 1, 1)

	coordinator.spawn_final_boss(true)

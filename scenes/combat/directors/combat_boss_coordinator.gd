class_name CombatBossCoordinator
extends Node

## Coordinador especializado de colosos, jefes de dominio, Astra Prime y pilotos rivales.
## Gestiona la puesta en escena cinemática horizontal (1920x1080), telemetría de duelos,
## fracturas de realidad cósmicas (CosmicRealityTear) y secuencias de salto warp.

const CosmicRealityTearScript := preload("res://scenes/combat/bosses/cosmic_reality_tear.gd")
const BossEmergenceHelperScript := preload("res://scenes/combat/bosses/boss_emergence_helper.gd")

var boss_mothership_scene: PackedScene = preload("res://scenes/combat/bosses/boss_mothership.tscn")
var boss_hermit_scene: PackedScene = preload("res://scenes/combat/bosses/boss_hermit_void.tscn")
var boss_ash_clock_scene: PackedScene = preload("res://scenes/combat/bosses/boss_ash_clock.tscn")
var boss_broken_mirror_scene: PackedScene = preload("res://scenes/combat/bosses/boss_broken_mirror.tscn")
var boss_overflow_vortex_scene: PackedScene = preload("res://scenes/combat/bosses/boss_overflow_vortex.tscn")
var boss_astra_prime_scene: PackedScene = preload("res://scenes/combat/bosses/boss_astra_prime.tscn")
var rival_pilot_scene: PackedScene = preload("res://scenes/combat/bosses/rival_pilot_boss.tscn")
var allied_wingman_scene: PackedScene = preload("res://scenes/combat/allies/allied_wingman.tscn")
var nyx_boss_escort_scene: PackedScene = preload("res://scenes/combat/bosses/nyx_boss_escort.tscn")
var elite_herald_scene: PackedScene = preload("res://scenes/combat/bosses/elite_herald_boss.tscn")

var main_game: Node2D = null

func setup(game: Node2D) -> void:
	main_game = game

func spawn_wave_boss(target_scene_override: PackedScene = null) -> void:
	if not main_game or not is_instance_valid(main_game):
		return
	var player: Node2D = main_game.get("player")
	if not is_instance_valid(player):
		return

	if main_game.get("_wave_encounter_spawned_for_wave") == main_game.get("current_wave") and target_scene_override == null:
		main_game.set("_wave_encounter_pending", false)
		return

	if target_scene_override == null and (main_game.call("is_any_combat_modal_active") or main_game.call("has_pending_upgrades")):
		main_game.set("_wave_encounter_pending", true)
		main_game.set("_wave_encounter_timer", 0.5)
		return

	if target_scene_override == null and main_game.call("_has_active_boss_or_rival"):
		if main_game.get("_wave_encounter_spawned_for_wave") != main_game.get("current_wave"):
			main_game.set("_wave_encounter_pending", true)
			main_game.set("_wave_encounter_timer", 1.0)
		return

	var enemy_spawner: Node = main_game.get("enemy_spawner")
	if enemy_spawner and enemy_spawner.has_method("set_spawning_paused"):
		enemy_spawner.set_spawning_paused(true)

	var bullet_srv: BulletServer = main_game.get_node_or_null("/root/BulletServer") as BulletServer
	if not bullet_srv and main_game.get_parent():
		bullet_srv = main_game.get_parent().get_node_or_null("BulletServer") as BulletServer
	if bullet_srv:
		bullet_srv.bomb_clear_all()

	var target_scene: PackedScene = target_scene_override
	var current_wave: int = int(main_game.get("current_wave"))
	if not target_scene:
		match current_wave:
			2:
				target_scene = boss_hermit_scene
			5:
				target_scene = boss_broken_mirror_scene
			8:
				target_scene = boss_ash_clock_scene
			11:
				target_scene = boss_overflow_vortex_scene
			14:
				target_scene = boss_mothership_scene
			_:
				target_scene = boss_mothership_scene

	var cin_zoom: float = 1.0
	var half_width_world: float = 480.0 / cin_zoom
	var separation_world: float = 960.0 / cin_zoom

	if is_instance_valid(player):
		if player.has_method("set_cinematic_duel_facing"):
			player.set_cinematic_duel_facing()
		else:
			player.set("velocity", Vector2.ZERO)
			if "current_facing_angle" in player:
				player.set("current_facing_angle", 0.0)
		if player.has_method("suppress_bomb_input"):
			player.suppress_bomb_input(999.0)

	var p_pos: Vector2 = player.global_position
	var cam_pos: Vector2 = p_pos + Vector2(half_width_world, 0.0)
	var boss_target_pos: Vector2 = p_pos + Vector2(separation_world, 0.0)

	var cam: GameCamera2D = main_game.get_tree().get_first_node_in_group("camera") as GameCamera2D
	if cam and cam.has_method("set_cinematic_focus"):
		cam.set_cinematic_focus(cam_pos, cin_zoom)

	var boss_node: Node2D = target_scene.instantiate() as Node2D
	boss_node.global_position = boss_target_pos
	boss_node.rotation = PI
	boss_node.process_mode = Node.PROCESS_MODE_ALWAYS
	boss_node.set("is_invulnerable", true)
	boss_node.set_meta("_is_emerging", true)
	if boss_node.has_method("prepare_emergence"):
		boss_node.prepare_emergence(boss_target_pos)
	else:
		BossEmergenceHelperScript.prepare_boss(boss_node, boss_target_pos)
	main_game.add_child(boss_node)
	main_game.set("current_boss", boss_node)
	main_game.set("_wave_encounter_spawned_for_wave", current_wave)
	main_game.set("_wave_encounter_pending", false)

	if "max_health" in boss_node:
		var base_hp: float = float(boss_node.get("max_health"))
		var dmg_val: float = 20.0
		var spd_val: float = 1.0
		var p_stats = player.get("stats")
		if is_instance_valid(player) and p_stats:
			dmg_val = float(p_stats.get_stat(&"base_damage"))
			spd_val = float(p_stats.get_stat(&"attack_speed"))
		var adaptive_hp: float = base_hp
		var enc_dir = main_game.get("encounter_director")
		if enc_dir and enc_dir.get("boss_rival_director"):
			adaptive_hp = enc_dir.boss_rival_director.calculate_adaptive_hp(base_hp, current_wave, dmg_val, spd_val)
		else:
			var wave_factor: float = 1.0 + float(current_wave) * 0.08
			var p_dps_factor: float = clampf((dmg_val / 20.0) * (spd_val / 1.0), 0.85, 2.5)
			adaptive_hp = base_hp * wave_factor * p_dps_factor
		boss_node.set("max_health", adaptive_hp)
		boss_node.set("current_health", adaptive_hp)

	var b_name: String = String(boss_node.get("boss_name")) if "boss_name" in boss_node else "JEFE DE DOMINIO"
	var b_hp: float = float(boss_node.get("max_health")) if "max_health" in boss_node else 1500.0
	var b_id: String = String(boss_node.get("boss_id")) if "boss_id" in boss_node else "boss_wave"

	var hud = main_game.get("hud")
	if boss_node.has_signal("health_changed") and hud:
		boss_node.connect("health_changed", hud.update_boss_health)
	if boss_node.has_signal("phase_changed") and hud:
		boss_node.connect("phase_changed", hud.set_boss_phase)
	if boss_node.has_signal("boss_defeated"):
		boss_node.connect("boss_defeated", Callable(main_game, "_on_boss_defeated"))

	var domain_col: Color = CosmicRealityTearScript.get_boss_domain_color(b_id)
	var tear = CosmicRealityTearScript.new()
	tear.setup(boss_target_pos, domain_col, 250.0, 750.0)
	tear.auto_collapse = false
	tear.process_mode = Node.PROCESS_MODE_ALWAYS
	main_game.add_child(tear)

	main_game.get_tree().create_timer(0.40, true, false, true).timeout.connect(func() -> void:
		if not is_instance_valid(boss_node):
			return
		tear.shockwave_completed.connect(func() -> void:
			main_game.call("_trigger_pet_boss_alert", b_name, func() -> void:
				main_game.get_tree().create_timer(0.25, true, false, true).timeout.connect(func() -> void:
					if not is_instance_valid(boss_node):
						if is_instance_valid(tear):
							tear.queue_free()
						return
					var on_emerge_finished := func() -> void:
						if is_instance_valid(boss_node):
							boss_node.set("is_invulnerable", false)
							boss_node.set_meta("_is_emerging", false)
						if is_instance_valid(tear):
							tear.start_collapse()
						if hud:
							hud.show_boss(b_name, b_hp)
							if hud.has_method("track_boss"):
								hud.track_boss(boss_node, "JEFE")
						if cam and cam.has_method("clear_cinematic_focus"):
							cam.clear_cinematic_focus()
						if is_instance_valid(player) and player.has_method("resume_movement_control"):
							player.resume_movement_control()
						main_game.set("is_boss_transmission_active", false)
						main_game.get_tree().paused = false
						main_game.call("notify_menu_closed", 0.4)
						main_game.call("_resume_pending_systems_after_cinematics")

					if boss_node.has_method("emerge_from_tear"):
						boss_node.emerge_from_tear(on_emerge_finished)
					else:
						BossEmergenceHelperScript.emerge_boss(boss_node, tear, on_emerge_finished)
				)
			)
		, CONNECT_ONE_SHOT)
	)

func spawn_final_boss(force_spawn: bool = false) -> void:
	if not main_game or not is_instance_valid(main_game):
		return
	var player: Node2D = main_game.get("player")
	if not is_instance_valid(player):
		return

	var current_wave: int = int(main_game.get("current_wave"))
	if not force_spawn and main_game.get("_wave_encounter_spawned_for_wave") == current_wave:
		main_game.set("_wave_encounter_pending", false)
		return

	if not force_spawn and main_game.call("is_any_combat_modal_active"):
		main_game.set("_wave_encounter_pending", true)
		main_game.set("_wave_encounter_timer", 0.5)
		return

	if not force_spawn and main_game.call("_has_active_boss_or_rival"):
		if main_game.get("_wave_encounter_spawned_for_wave") != current_wave:
			main_game.set("_wave_encounter_pending", true)
			main_game.set("_wave_encounter_timer", 1.0)
		return

	var enemy_spawner: Node = main_game.get("enemy_spawner")
	if enemy_spawner and enemy_spawner.has_method("set_spawning_paused"):
		enemy_spawner.set_spawning_paused(true)

	var bullet_srv: BulletServer = main_game.get_node_or_null("/root/BulletServer") as BulletServer
	if not bullet_srv and main_game.get_parent():
		bullet_srv = main_game.get_parent().get_node_or_null("BulletServer") as BulletServer
	if bullet_srv:
		bullet_srv.bomb_clear_all()

	var rivals_spared: Array = main_game.get("rivals_spared")
	var rivals_killed: Array = main_game.get("rivals_killed")
	var route := "neutral"
	if rivals_spared.size() >= 5:
		route = "pacifist"
	elif rivals_killed.size() >= 5:
		route = "slayer"

	var cin_zoom: float = 1.0
	var half_width_world: float = 480.0 / cin_zoom
	var separation_world: float = 960.0 / cin_zoom

	if is_instance_valid(player):
		if player.has_method("set_cinematic_duel_facing"):
			player.set_cinematic_duel_facing()
		else:
			player.set("velocity", Vector2.ZERO)
			if "current_facing_angle" in player:
				player.set("current_facing_angle", 0.0)
		if player.has_method("suppress_bomb_input"):
			player.suppress_bomb_input(999.0)

	var p_pos: Vector2 = player.global_position
	var cam_pos: Vector2 = p_pos + Vector2(half_width_world, 0.0)
	var boss_target_pos: Vector2 = p_pos + Vector2(separation_world, 0.0)

	var cam: GameCamera2D = main_game.get_tree().get_first_node_in_group("camera") as GameCamera2D
	if cam and cam.has_method("set_cinematic_focus"):
		cam.set_cinematic_focus(cam_pos, cin_zoom)

	var prime = boss_astra_prime_scene.instantiate()
	prime.global_position = boss_target_pos
	prime.rotation = PI
	prime.process_mode = Node.PROCESS_MODE_ALWAYS
	prime.set_route(route)
	prime.set("is_invulnerable", true)
	prime.set_meta("_is_emerging", true)
	if prime.has_method("prepare_emergence"):
		prime.prepare_emergence(boss_target_pos)
	else:
		BossEmergenceHelperScript.prepare_boss(prime, boss_target_pos)
	main_game.add_child(prime)
	main_game.set("current_boss", prime)
	main_game.set("_wave_encounter_spawned_for_wave", current_wave)
	main_game.set("_wave_encounter_pending", false)

	var hud = main_game.get("hud")
	if hud:
		prime.health_changed.connect(hud.update_boss_health)
		prime.phase_changed.connect(hud.set_boss_phase)
	prime.boss_defeated.connect(func(_b_id): main_game.call("_on_final_boss_defeated", route))

	var domain_col: Color = Color(1.0, 0.15, 0.25, 1.0) if route == "slayer" else CosmicRealityTearScript.get_boss_domain_color("boss_astra_prime")
	var tear = CosmicRealityTearScript.new()
	tear.setup(boss_target_pos, domain_col, 280.0, 850.0)
	tear.auto_collapse = false
	tear.process_mode = Node.PROCESS_MODE_ALWAYS
	main_game.add_child(tear)

	main_game.get_tree().create_timer(0.40, true, false, true).timeout.connect(func() -> void:
		if not is_instance_valid(prime):
			return
		tear.shockwave_completed.connect(func() -> void:
			main_game.call("_trigger_climax_dialogue", route, func() -> void:
				main_game.get_tree().create_timer(0.25, true, false, true).timeout.connect(func() -> void:
					if not is_instance_valid(prime):
						if is_instance_valid(tear):
							tear.queue_free()
						return
					var on_emerge_finished := func() -> void:
						if is_instance_valid(prime):
							prime.set("is_invulnerable", false)
							prime.set_meta("_is_emerging", false)
						if is_instance_valid(tear):
							tear.start_collapse()
						if hud:
							hud.show_boss(prime.boss_name, prime.max_health)
							if hud.has_method("track_boss"):
								hud.track_boss(prime, "JEFE FINAL")
						if cam and cam.has_method("clear_cinematic_focus"):
							cam.clear_cinematic_focus()
						if is_instance_valid(player) and player.has_method("resume_movement_control"):
							player.resume_movement_control()
						main_game.set("is_boss_transmission_active", false)
						main_game.get_tree().paused = false
						main_game.call("notify_menu_closed", 0.4)
						main_game.call("_resume_pending_systems_after_cinematics")

						if route == "pacifist":
							spawn_allied_wingmen()
						elif route == "slayer":
							var p_stats = player.get("stats")
							if p_stats:
								p_stats.add_modifier(&"base_damage", CharacterStats.StatModifier.new(&"slayer_overload", 0.35, true, main_game))
							var escort = nyx_boss_escort_scene.instantiate()
							var escort_pid: StringName = main_game.call("_get_genocide_escort_pilot_id")
							escort.global_position = boss_target_pos + Vector2(0.0, 110.0)
							escort.setup(escort_pid, prime)
							main_game.add_child(escort)
							main_game.set("current_genocide_escort", escort)

					if prime.has_method("emerge_from_tear"):
						prime.emerge_from_tear(on_emerge_finished)
					else:
						BossEmergenceHelperScript.emerge_boss(prime, tear, on_emerge_finished)
				)
			)
		, CONNECT_ONE_SHOT)
	)

func spawn_rival_pilot(override_id: StringName = &"") -> void:
	if not main_game or not is_instance_valid(main_game):
		return
	var current_wave: int = int(main_game.get("current_wave"))
	if main_game.get("_wave_encounter_spawned_for_wave") == current_wave and override_id == &"":
		main_game.set("_wave_encounter_pending", false)
		return

	if main_game.call("is_any_combat_modal_active") or (override_id == &"" and main_game.call("has_pending_upgrades")):
		main_game.set("_wave_encounter_pending", true)
		main_game.set("_wave_encounter_timer", 0.5)
		return

	if override_id == &"" and main_game.call("_has_active_boss_or_rival"):
		if main_game.get("_wave_encounter_spawned_for_wave") != current_wave:
			main_game.set("_wave_encounter_pending", true)
			main_game.set("_wave_encounter_timer", 1.0)
		return

	var player: Node2D = main_game.get("player")
	if not is_instance_valid(player):
		return

	var next_pid: StringName = override_id
	if next_pid == &"":
		var unencountered: Array[StringName] = []
		var r_queue: Array = main_game.get("rival_queue")
		var r_spared: Array = main_game.get("rivals_spared")
		var r_killed: Array = main_game.get("rivals_killed")
		for pid in r_queue:
			if not r_spared.has(pid) and not r_killed.has(pid):
				unencountered.append(pid)
		if unencountered.is_empty():
			return
		next_pid = unencountered[0]

	main_game.set("is_rival_cinematic_active", true)
	var enemy_spawner: Node = main_game.get("enemy_spawner")
	if enemy_spawner and enemy_spawner.has_method("set_spawning_paused"):
		enemy_spawner.set_spawning_paused(true)
	var bullet_srv: BulletServer = main_game.get_node_or_null("/root/BulletServer") as BulletServer
	if not bullet_srv and main_game.get_parent():
		bullet_srv = main_game.get_parent().get_node_or_null("BulletServer") as BulletServer
	if bullet_srv:
		bullet_srv.bomb_clear_all()

	var cin_zoom: float = 1.0
	var half_width_world: float = 480.0 / cin_zoom
	var separation_world: float = 960.0 / cin_zoom

	if is_instance_valid(player):
		if player.has_method("set_cinematic_duel_facing"):
			player.set_cinematic_duel_facing()
		else:
			player.set("velocity", Vector2.ZERO)
			if "current_facing_angle" in player:
				player.set("current_facing_angle", 0.0)
		if player.has_method("suppress_bomb_input"):
			player.suppress_bomb_input(999.0)

	var p_pos: Vector2 = player.global_position
	var cam_pos: Vector2 = p_pos + Vector2(half_width_world, 0.0)
	var rival_target_pos: Vector2 = p_pos + Vector2(separation_world, 0.0)

	var cam: GameCamera2D = main_game.get_tree().get_first_node_in_group("camera") as GameCamera2D
	if cam and cam.has_method("set_cinematic_focus"):
		cam.set_cinematic_focus(cam_pos, cin_zoom)

	var rival = rival_pilot_scene.instantiate()
	rival.global_position = rival_target_pos
	rival.rotation = -PI / 2.0
	rival.process_mode = Node.PROCESS_MODE_ALWAYS
	rival.setup_pilot(next_pid, current_wave)
	if rival.has_method("prepare_warp_in"):
		rival.prepare_warp_in(rival_target_pos)
	main_game.add_child(rival)
	main_game.set("current_rival", rival)
	main_game.set("_wave_encounter_spawned_for_wave", current_wave)
	main_game.set("_wave_encounter_pending", false)

	rival.rival_spared.connect(Callable(main_game, "_on_rival_spared"))
	rival.rival_engaged.connect(Callable(main_game, "_on_rival_engaged"))
	rival.rival_defeated.connect(Callable(main_game, "_on_rival_defeated"))

	var hud = main_game.get("hud")
	if hud and hud.has_method("track_boss"):
		hud.track_boss(rival, "RIVAL")

	main_game.get_tree().create_timer(0.45, true, false, true).timeout.connect(func() -> void:
		if not is_instance_valid(rival):
			return
		if rival.has_method("open_warp_portal"):
			rival.open_warp_portal(func() -> void:
				main_game.call("_trigger_pet_rival_jump_warning", rival, func() -> void:
					main_game.get_tree().create_timer(0.3, true, false, true).timeout.connect(func() -> void:
						if not is_instance_valid(rival):
							return
						rival.emerge_from_portal(func() -> void:
							main_game.call("_trigger_rival_face_to_face_dialogue", rival)
						)
					)
				)
			)
		else:
			main_game.call("_trigger_rival_face_to_face_dialogue", rival)
	)

	main_game.get_tree().create_timer(18.0, true, false, true).timeout.connect(func() -> void:
		if main_game.get("is_rival_cinematic_active") == true:
			push_warning("[CINEMATIC WATCHDOG] Rival cinematic sequence timed out; recovering and starting encounter.")
			main_game.call("_on_dialogue_skip_requested")
	)

func spawn_allied_wingmen() -> void:
	if not main_game or not is_instance_valid(main_game):
		return
	var player: Node2D = main_game.get("player")
	if not is_instance_valid(player):
		return
	var rivals_spared: Array = main_game.get("rivals_spared")
	for i in range(rivals_spared.size()):
		var pid: StringName = rivals_spared[i]
		var wingman = allied_wingman_scene.instantiate()
		wingman.global_position = player.global_position + Vector2(cos((TAU / 5.0) * float(i)), sin((TAU / 5.0) * float(i))) * 230.0
		wingman.setup(pid, (TAU / 5.0) * float(i))
		main_game.add_child(wingman)

func spawn_elite_herald() -> void:
	if not main_game or not is_instance_valid(main_game):
		return
	var player: Node2D = main_game.get("player")
	if not is_instance_valid(player) or not elite_herald_scene:
		return
	if main_game.get("current_boss") != null:
		return

	var current_wave: int = int(main_game.get("current_wave"))
	var p_vel: Vector2 = player.get("velocity") if "velocity" in player else Vector2.ZERO
	var forward: Vector2 = p_vel.normalized() if p_vel.length_squared() > 10.0 else Vector2.UP
	var elite_pos: Vector2 = player.global_position + forward * 580.0

	var herald: Node2D = elite_herald_scene.instantiate() as Node2D
	herald.global_position = elite_pos
	herald.setup_type(current_wave)
	main_game.set("current_boss", herald)
	main_game.add_child(herald)

	var hud = main_game.get("hud")
	var b_name: String = herald.boss_name
	var b_hp: float = herald.max_health
	if hud:
		hud.show_boss(b_name, b_hp)
	if herald.has_signal("health_changed") and hud:
		herald.connect("health_changed", hud.update_boss_health)
	if herald.has_signal("boss_defeated"):
		herald.connect("boss_defeated", Callable(main_game, "_on_boss_defeated"))

func jump_to_boss(boss_id: String) -> void:
	if not main_game or not is_instance_valid(main_game):
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

	var skip_badge = main_game.get("skip_badge_layer")
	if skip_badge:
		skip_badge.hide()

	main_game.set("wave_timer", 30.0)
	main_game.set("_wave_encounter_pending", false)

	var cb = main_game.get("current_boss")
	if cb and is_instance_valid(cb):
		cb.queue_free()
		main_game.set("current_boss", null)

	var cr = main_game.get("current_rival")
	if cr and is_instance_valid(cr):
		cr.queue_free()
		main_game.set("current_rival", null)

	var cs = main_game.get("current_satellite")
	if cs and is_instance_valid(cs):
		cs.queue_free()
		main_game.set("current_satellite", null)

	main_game.set("wave_satellites_spawned", 1)
	var hud = main_game.get("hud")
	if hud and hud.has_method("clear_satellite"):
		hud.clear_satellite()

	if boss_id == "boss_astra_prime":
		jump_to_wave_16("neutral")
		return

	var target_scene: PackedScene = boss_mothership_scene
	var target_wave: int = 14
	match boss_id:
		"boss_hermit_void":
			target_scene = boss_hermit_scene
			target_wave = 2
		"boss_broken_mirror":
			target_scene = boss_broken_mirror_scene
			target_wave = 5
		"boss_ash_clock":
			target_scene = boss_ash_clock_scene
			target_wave = 8
		"boss_overflow_vortex":
			target_scene = boss_overflow_vortex_scene
			target_wave = 11
		"boss_mothership":
			target_scene = boss_mothership_scene
			target_wave = 14
		_:
			target_scene = boss_mothership_scene
			target_wave = 14

	main_game.set("current_wave", target_wave)
	main_game.set("_wave_encounter_checked_for_wave", target_wave)
	main_game.set("_wave_encounter_spawned_for_wave", 0)
	main_game.set("_wave_encounter_pending", false)

	var player: Node2D = main_game.get("player")
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

	spawn_wave_boss(target_scene)

func jump_to_wave_16(route: String = "neutral") -> void:
	if not main_game or not is_instance_valid(main_game):
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

	var skip_badge = main_game.get("skip_badge_layer")
	if skip_badge:
		skip_badge.hide()

	main_game.set("current_wave", 16)
	main_game.set("wave_timer", 30.0)
	main_game.set("_wave_encounter_checked_for_wave", 16)
	main_game.set("_wave_encounter_spawned_for_wave", 0)
	main_game.set("_wave_encounter_pending", false)

	var cb = main_game.get("current_boss")
	if cb and is_instance_valid(cb):
		cb.queue_free()
		main_game.set("current_boss", null)

	var cr = main_game.get("current_rival")
	if cr and is_instance_valid(cr):
		cr.queue_free()
		main_game.set("current_rival", null)

	var cs = main_game.get("current_satellite")
	if cs and is_instance_valid(cs):
		cs.queue_free()
		main_game.set("current_satellite", null)

	main_game.set("wave_satellites_spawned", 1)
	var hud = main_game.get("hud")
	if hud and hud.has_method("clear_satellite"):
		hud.clear_satellite()

	var player: Node2D = main_game.get("player")
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
				var rival_weapons := [
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

	spawn_final_boss(true)

func on_rival_spared(p_id: StringName) -> void:
	if not main_game or not is_instance_valid(main_game):
		return
	var r_spared: Array = main_game.get("rivals_spared")
	if not r_spared.has(p_id):
		r_spared.append(p_id)
	var r_name: String = String(p_id).capitalize()
	var cur_rival: Node2D = main_game.get("current_rival")
	if cur_rival and "pilot_name" in cur_rival:
		r_name = cur_rival.pilot_name
	main_game.set("current_rival", null)

	var hud = main_game.get("hud")
	if hud and hud.has_method("hide_boss"):
		hud.hide_boss()
	if hud and hud.has_method("show_character_unlock_banner"):
		hud.show_character_unlock_banner(p_id, "PILOTO RESPETADA: " + r_name.to_upper(), "Has permitido que la piloto escape pacíficamente. Decisión registrada.")

	var spawner: Node = main_game.get("enemy_spawner")
	if spawner and spawner.has_method("set_spawning_paused"):
		spawner.set_spawning_paused(false)
	main_game.call("save_current_run_state")

func on_rival_engaged(p_id: StringName) -> void:
	if not main_game or not is_instance_valid(main_game):
		return
	var spawner: Node = main_game.get("enemy_spawner")
	if spawner and spawner.has_method("set_spawning_paused"):
		spawner.set_spawning_paused(true)
	var cur_rival: Node2D = main_game.get("current_rival")
	if cur_rival:
		var r_name: String = "DUELO: " + (cur_rival.pilot_name if "pilot_name" in cur_rival else String(p_id).to_upper())
		var r_hp: float = float(cur_rival.get("max_health")) if "max_health" in cur_rival else 950.0
		var hud = main_game.get("hud")
		if hud:
			hud.show_boss(r_name, r_hp)
		if cur_rival.has_signal("health_changed") and hud:
			cur_rival.connect("health_changed", hud.update_boss_health)

func on_rival_defeated(p_id: StringName, weapon: WeaponData) -> void:
	if not main_game or not is_instance_valid(main_game):
		return
	var r_killed: Array = main_game.get("rivals_killed")
	if not r_killed.has(p_id):
		r_killed.append(p_id)
	var r_name: String = String(p_id).capitalize()
	var cur_rival: Node2D = main_game.get("current_rival")
	if cur_rival and "pilot_name" in cur_rival:
		r_name = cur_rival.pilot_name
	main_game.set("current_rival", null)

	var hud = main_game.get("hud")
	if hud and hud.has_method("hide_boss"):
		hud.hide_boss()
	if hud and hud.has_method("show_character_unlock_banner"):
		var w_name: String = weapon.weapon_name if weapon else "Arma Insignia"
		hud.show_character_unlock_banner(p_id, "RIVAL ELIMINADA: " + r_name.to_upper(), "Has abatido a " + r_name + ". ¡Arma insignia " + w_name + " obtenida!")

	var spawner: Node = main_game.get("enemy_spawner")
	if spawner and spawner.has_method("set_spawning_paused"):
		spawner.set_spawning_paused(false)
	main_game.call("save_current_run_state")
	main_game.call("_resume_pending_systems_after_cinematics")

func on_boss_defeated(_boss_id: String) -> void:
	if not main_game or not is_instance_valid(main_game):
		return
	var b_def_count: int = int(main_game.get("bosses_defeated_count")) + 1
	main_game.set("bosses_defeated_count", b_def_count)
	main_game.set("current_boss", null)

	var hud = main_game.get("hud")
	if hud and hud.has_method("hide_boss"):
		hud.hide_boss()

	var just_unlocked_nyx: bool = SaveManager.record_boss_kill()
	if just_unlocked_nyx and hud and hud.has_method("show_character_unlock_banner"):
		hud.show_character_unlock_banner(&"nyx", "¡NUEVO PILOTO DESBLOQUEADO: NYX!", "Has derrotado a 10 Jefes Titanes en tu Carrera espacial.")

	var spawner: Node = main_game.get("enemy_spawner")
	if spawner and spawner.has_method("set_spawning_paused"):
		spawner.set_spawning_paused(false)
	main_game.call("save_current_run_state")
	main_game.call("_resume_pending_systems_after_cinematics")


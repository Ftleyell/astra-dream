class_name CombatBossCoordinator
extends Node

## Coordinador especializado de colosos, jefes de dominio, Astra Prime y pilotos rivales.
## Gestiona la puesta en escena cinemática horizontal (1920x1080), telemetría de duelos,
## fracturas de realidad cósmicas (CosmicRealityTear) y secuencias de salto warp.

const CosmicRealityTearScript := preload("res://scenes/combat/bosses/cosmic_reality_tear.gd")
const BossEmergenceHelperScript := preload("res://scenes/combat/bosses/boss_emergence_helper.gd")
const BossCinematicPresenterScript := preload("res://scenes/combat/bosses/boss_cinematic_presenter.gd")
const CombatBossDebugJumperScript := preload("res://scenes/combat/directors/combat_boss_debug_jumper.gd")

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

const MAX_BOSS_LEASH_DISTANCE: float = 1400.0
const BOSS_CATCHUP_COOLDOWN: float = 2.5

var main_game: Node2D = null
var _catchup_timer: float = 0.0

func setup(game: Node2D) -> void:
	main_game = game
	process_mode = Node.PROCESS_MODE_PAUSABLE

func _physics_process(delta: float) -> void:
	if not main_game or not is_instance_valid(main_game) or not main_game.is_inside_tree():
		return
	if get_tree().paused or (main_game.has_method("is_cinematic_or_death_active") and main_game.is_cinematic_or_death_active()):
		return

	if _catchup_timer > 0.0:
		_catchup_timer -= delta
		return

	_check_boss_leash_catchup()

func _check_boss_leash_catchup() -> void:
	var player: Node2D = main_game.get("player") as Node2D
	if not is_instance_valid(player):
		return

	var active_threat: Node2D = main_game.get("current_boss") as Node2D
	if not is_instance_valid(active_threat):
		active_threat = main_game.get("current_rival") as Node2D

	if not is_instance_valid(active_threat) or not active_threat.is_inside_tree():
		return

	if active_threat.get("is_dying") == true:
		return
	if active_threat.has_method("is_peaceful") and active_threat.is_peaceful():
		return
	if "current_state" in active_threat and active_threat.get("current_state") == 0:
		return

	var dist: float = active_threat.global_position.distance_to(player.global_position)
	if dist > MAX_BOSS_LEASH_DISTANCE:
		_execute_boss_tactical_teleport(active_threat, player)

func _execute_boss_tactical_teleport(threat: Node2D, player: Node2D) -> void:
	_catchup_timer = BOSS_CATCHUP_COOLDOWN

	var p_vel: Vector2 = player.get("velocity") if "velocity" in player else Vector2.ZERO
	var forward_dir: Vector2 = p_vel.normalized() if p_vel.length_squared() > 10.0 else (threat.global_position - player.global_position).normalized()
	if forward_dir.length_squared() < 0.001:
		forward_dir = Vector2.UP

	var target_pos: Vector2 = player.global_position + forward_dir * 720.0

	var tw := threat.create_tween()
	tw.tween_property(threat, "modulate:a", 0.1, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		if is_instance_valid(threat) and is_instance_valid(player):
			threat.global_position = target_pos
			if "velocity" in threat:
				threat.set("velocity", Vector2.ZERO)
	)
	tw.tween_property(threat, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

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

	var duel_ctx: Dictionary = BossCinematicPresenterScript.setup_cinematic_duel(main_game, 1.0)
	var cam: GameCamera2D = duel_ctx.get("cam") as GameCamera2D
	var boss_target_pos: Vector2 = duel_ctx.get("boss_target_pos", Vector2.ZERO)

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

	if target_scene_override == null:
		_apply_adaptive_hp(boss_node, player, current_wave)

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
	BossCinematicPresenterScript.play_reality_tear_emergence(
		main_game,
		boss_node,
		boss_target_pos,
		domain_col,
		250.0,
		750.0,
		func(next_step: Callable) -> void: main_game.call("_trigger_pet_boss_alert", b_name, next_step),
		func() -> void:
			if hud:
				hud.show_boss(b_name, b_hp)
				if hud.has_method("track_boss"):
					hud.track_boss(boss_node, "JEFE")
			BossCinematicPresenterScript.restore_combat_after_emergence(main_game, cam, player)
	)

func _apply_adaptive_hp(boss_node: Node2D, player: Node2D, current_wave: int) -> void:
	if not ("max_health" in boss_node):
		return
	var base_hp: float = float(boss_node.get("max_health"))
	var dmg_val: float = 20.0
	var spd_val: float = 1.0
	var p_stats = player.get("stats") if is_instance_valid(player) else null
	if p_stats:
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

	var duel_ctx: Dictionary = BossCinematicPresenterScript.setup_cinematic_duel(main_game, 1.0)
	var cam: GameCamera2D = duel_ctx.get("cam") as GameCamera2D
	var boss_target_pos: Vector2 = duel_ctx.get("boss_target_pos", Vector2.ZERO)

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
	BossCinematicPresenterScript.play_reality_tear_emergence(
		main_game,
		prime,
		boss_target_pos,
		domain_col,
		280.0,
		850.0,
		func(next_step: Callable) -> void: main_game.call("_trigger_climax_dialogue", route, next_step),
		func() -> void:
			if hud:
				hud.show_boss(prime.boss_name, prime.max_health)
				if hud.has_method("track_boss"):
					hud.track_boss(prime, "JEFE FINAL")
			BossCinematicPresenterScript.restore_combat_after_emergence(main_game, cam, player)

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

	var duel_ctx: Dictionary = BossCinematicPresenterScript.setup_cinematic_duel(main_game, 1.0)
	var rival_target_pos: Vector2 = duel_ctx.get("boss_target_pos", Vector2.ZERO)

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
		if not is_instance_valid(rival) or main_game.get("is_rival_cinematic_active") != true:
			return
		if rival.has_method("open_warp_portal"):
			rival.open_warp_portal(func() -> void:
				if not is_instance_valid(rival):
					return
				main_game.call("_trigger_pet_rival_jump_warning", rival, func() -> void:
					if not is_instance_valid(rival):
						return
					var pl: Node2D = main_game.get("player") as Node2D
					if is_instance_valid(pl) and "is_movement_suppressed" in pl:
						pl.set("is_movement_suppressed", true)
						pl.set("velocity", Vector2.ZERO)
					# Salir del portal directamente
					rival.emerge_from_portal(func() -> void:
						if not is_instance_valid(rival):
							return
						rival.process_mode = Node.PROCESS_MODE_PAUSABLE
						main_game.call("_trigger_rival_face_to_face_dialogue", rival)
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
	CombatBossDebugJumperScript.jump_to_boss(main_game, self, boss_id)

func spawn_boss_by_id(boss_id: String, play_intro: bool = true) -> void:
	if not main_game or not is_instance_valid(main_game):
		return
	var scene: PackedScene = boss_mothership_scene
	match boss_id:
		"boss_hermit_void":
			scene = boss_hermit_scene
		"boss_ash_clock":
			scene = boss_ash_clock_scene
		"boss_broken_mirror":
			scene = boss_broken_mirror_scene
		"boss_overflow_vortex":
			scene = boss_overflow_vortex_scene
		"boss_mothership":
			scene = boss_mothership_scene
		"boss_astra_prime":
			scene = boss_astra_prime_scene
		"elite_herald":
			spawn_elite_herald()
			return
		_:
			scene = boss_mothership_scene

	if play_intro:
		spawn_wave_boss(scene)
	else:
		var player: Node2D = main_game.get("player")
		if not is_instance_valid(player):
			return
		var p_vel: Vector2 = player.get("velocity") if "velocity" in player else Vector2.ZERO
		var forward: Vector2 = p_vel.normalized() if p_vel.length_squared() > 10.0 else Vector2.UP
		var target_pos: Vector2 = player.global_position + forward * 300.0
		var boss_node: Node2D = scene.instantiate() as Node2D
		boss_node.global_position = target_pos
		boss_node.rotation = PI
		boss_node.process_mode = Node.PROCESS_MODE_PAUSABLE
		main_game.add_child(boss_node)
		main_game.set("current_boss", boss_node)
		var b_name: String = String(boss_node.get("boss_name")) if "boss_name" in boss_node else "JEFE DE DOMINIO"
		var b_hp: float = float(boss_node.get("max_health")) if "max_health" in boss_node else 1500.0
		var hud = main_game.get("hud")
		if hud:
			hud.show_boss(b_name, b_hp)
			if hud.has_method("track_boss"):
				hud.track_boss(boss_node, "JEFE")
		if boss_node.has_signal("health_changed") and hud:
			boss_node.connect("health_changed", hud.update_boss_health)
		if boss_node.has_signal("phase_changed") and hud:
			boss_node.connect("phase_changed", hud.set_boss_phase)
		if boss_node.has_signal("boss_defeated"):
			boss_node.connect("boss_defeated", Callable(main_game, "_on_boss_defeated"))

func jump_to_wave_16(route: String = "neutral") -> void:
	CombatBossDebugJumperScript.jump_to_wave_16(main_game, self, route)

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

	# Descartar cualquier crisis o tormenta solar activa al iniciar duelo con rival
	var crisis_mgr: Node = main_game.get("crisis_manager")
	if not crisis_mgr:
		crisis_mgr = main_game.get_node_or_null("CrisisEventManager")
	if crisis_mgr and crisis_mgr.has_method("dismiss_for_boss_encounter"):
		crisis_mgr.dismiss_for_boss_encounter()

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


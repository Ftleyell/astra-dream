class_name BossEncounterSpawner
extends RefCounted

## BossEncounterSpawner.gd
## Manejador desacoplado de instanciación, escalado de vida adaptativo (DPS check)
## y puesta en escena para jefes de dominio, Astra Prime, pilotos rivales y heraldos de élite.

const BossEmergenceHelperScript := preload("res://scenes/combat/bosses/boss_emergence_helper.gd")
const BossCinematicSequenceScript := preload("res://scenes/combat/directors/boss_cinematic_sequence.gd")
const BossHealthBarManagerScript := preload("res://scenes/combat/directors/boss_health_bar_manager.gd")

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
var cinematic_sequence: BossCinematicSequenceScript = null
var health_bar_manager: BossHealthBarManagerScript = null

func setup(p_main_game: Node2D, p_cinematic: BossCinematicSequenceScript, p_health_bar: BossHealthBarManagerScript) -> void:
	main_game = p_main_game
	cinematic_sequence = p_cinematic
	health_bar_manager = p_health_bar

func apply_adaptive_hp(boss_node: Node2D, player: Node2D, current_wave: int) -> void:
	if not ("max_health" in boss_node):
		return
	var base_hp: float = float(boss_node.get("max_health"))
	var dmg_val: float = 20.0
	var spd_val: float = 1.0
	var crit_c_val: float = 0.05
	var crit_d_val: float = 1.5
	var proj_count_val: float = 1.0
	var p_stats = player.get("stats") if is_instance_valid(player) else null
	if p_stats:
		dmg_val = float(p_stats.get_stat(&"base_damage"))
		spd_val = float(p_stats.get_stat(&"attack_speed"))
		crit_c_val = float(p_stats.get_stat(&"crit_chance"))
		crit_d_val = float(p_stats.get_stat(&"crit_damage"))
		proj_count_val = float(p_stats.get_stat(&"projectile_count"))

	var adaptive_hp: float = base_hp
	var enc_dir = main_game.get("encounter_director") if main_game else null
	if enc_dir and enc_dir.get("boss_rival_director"):
		adaptive_hp = enc_dir.boss_rival_director.calculate_adaptive_hp(base_hp, current_wave, dmg_val, spd_val, crit_c_val, crit_d_val, proj_count_val)
	else:
		var wave_factor: float = 1.0 + float(current_wave) * 0.10
		var player_power: float = dmg_val * spd_val * (1.0 + clampf(crit_c_val, 0.0, 1.0) * maxf(0.0, crit_d_val)) * maxf(1.0, proj_count_val)
		var baseline_power: float = 20.0 * 1.0 * (1.0 + 0.05 * 1.5) * 1.0
		var p_dps_factor: float = clampf(pow(player_power / baseline_power, 0.65), 1.0, 10.0)
		adaptive_hp = base_hp * wave_factor * p_dps_factor
	boss_node.set("max_health", adaptive_hp)
	boss_node.set("current_health", adaptive_hp)

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
			2: target_scene = boss_hermit_scene
			5: target_scene = boss_broken_mirror_scene
			8: target_scene = boss_ash_clock_scene
			11: target_scene = boss_overflow_vortex_scene
			14: target_scene = boss_mothership_scene
			_: target_scene = boss_mothership_scene

	var duel_ctx: Dictionary = cinematic_sequence.setup_cinematic_duel(1.0)
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
		apply_adaptive_hp(boss_node, player, current_wave)

	var b_name: String = String(boss_node.get("boss_name")) if "boss_name" in boss_node else "JEFE DE DOMINIO"
	var b_hp: float = float(boss_node.get("max_health")) if "max_health" in boss_node else 1500.0
	var b_id: String = String(boss_node.get("boss_id")) if "boss_id" in boss_node else "boss_wave"

	health_bar_manager.bind_boss(boss_node)
	cinematic_sequence.play_wave_boss_sequence(boss_node, boss_target_pos, b_id, b_name, b_hp, cam, player)

func spawn_final_boss(force_spawn: bool = false, wingman_callback: Callable = Callable()) -> void:
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

	var duel_ctx: Dictionary = cinematic_sequence.setup_cinematic_duel(1.0)
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
	apply_adaptive_hp(prime, player, current_wave)

	health_bar_manager.bind_boss(prime, func(_b_id: String): main_game.call("_on_final_boss_defeated", route))
	cinematic_sequence.play_final_boss_sequence(
		prime,
		boss_target_pos,
		route,
		wingman_callback,
		cam,
		player
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
		for pid: StringName in r_queue:
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

	var duel_ctx: Dictionary = cinematic_sequence.setup_cinematic_duel(1.0)
	var rival_target_pos: Vector2 = duel_ctx.get("boss_target_pos", Vector2.ZERO)

	var rival = rival_pilot_scene.instantiate()
	rival.global_position = rival_target_pos
	rival.rotation = -PI / 2.0
	rival.process_mode = Node.PROCESS_MODE_ALWAYS
	rival.setup_pilot(next_pid, current_wave)
	apply_adaptive_hp(rival, player, current_wave)
	if rival.has_method("prepare_warp_in"):
		rival.prepare_warp_in(rival_target_pos)
	main_game.add_child(rival)
	main_game.set("current_rival", rival)
	main_game.set("_wave_encounter_spawned_for_wave", current_wave)
	main_game.set("_wave_encounter_pending", false)

	health_bar_manager.bind_rival(
		rival,
		Callable(main_game, "_on_rival_spared"),
		Callable(main_game, "_on_rival_engaged"),
		Callable(main_game, "_on_rival_defeated")
	)
	cinematic_sequence.play_rival_warp_sequence(rival)

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
	apply_adaptive_hp(herald, player, current_wave)
	main_game.set("current_boss", herald)
	main_game.add_child(herald)

	health_bar_manager.bind_boss(herald)
	health_bar_manager.show_boss_bar(herald, herald.boss_name, herald.max_health)

func spawn_boss_by_id(boss_id: String, play_intro: bool = true) -> void:
	if not main_game or not is_instance_valid(main_game):
		return
	var scene: PackedScene = boss_mothership_scene
	match boss_id:
		"boss_hermit_void": scene = boss_hermit_scene
		"boss_ash_clock": scene = boss_ash_clock_scene
		"boss_broken_mirror": scene = boss_broken_mirror_scene
		"boss_overflow_vortex": scene = boss_overflow_vortex_scene
		"boss_mothership": scene = boss_mothership_scene
		"boss_astra_prime": scene = boss_astra_prime_scene
		"elite_herald":
			spawn_elite_herald()
			return
		_: scene = boss_mothership_scene

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
		var cur_w: int = int(main_game.get("current_wave"))
		apply_adaptive_hp(boss_node, player, cur_w)
		main_game.add_child(boss_node)
		main_game.set("current_boss", boss_node)
		var b_name: String = String(boss_node.get("boss_name")) if "boss_name" in boss_node else "JEFE DE DOMINIO"
		var b_hp: float = float(boss_node.get("max_health")) if "max_health" in boss_node else 1500.0
		health_bar_manager.bind_boss(boss_node)
		health_bar_manager.show_boss_bar(boss_node, b_name, b_hp, "JEFE")

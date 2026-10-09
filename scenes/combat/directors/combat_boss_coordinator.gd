class_name CombatBossCoordinator
extends "res://scenes/combat/systems/combat_subsystem.gd"

## Coordinador especializado de colosos, jefes de dominio, Astra Prime y pilotos rivales.
## Orquesta la cinemática de duelos, telemetría de encuentros, leash catchup y
## delega el spawning y escalado en BossEncounterSpawner.

const CombatBossDebugJumperScript := preload("res://scenes/combat/directors/combat_boss_debug_jumper.gd")
const BossCinematicSequenceScript := preload("res://scenes/combat/directors/boss_cinematic_sequence.gd")
const BossHealthBarManagerScript := preload("res://scenes/combat/directors/boss_health_bar_manager.gd")
const BossEncounterSpawnerScript := preload("res://scenes/combat/directors/boss_encounter_spawner.gd")

const MAX_BOSS_LEASH_DISTANCE: float = 1400.0
const BOSS_CATCHUP_COOLDOWN: float = 2.5

var main_game: Node2D = null
var _catchup_timer: float = 0.0

var health_bar_manager: BossHealthBarManagerScript = BossHealthBarManagerScript.new()
var cinematic_sequence: BossCinematicSequenceScript = BossCinematicSequenceScript.new()
var spawner: BossEncounterSpawnerScript = BossEncounterSpawnerScript.new()

# Referencias públicas a escenas de jefes para tests y modding
var boss_mothership_scene: PackedScene:
	get: return spawner.boss_mothership_scene
	set(val): spawner.boss_mothership_scene = val

var boss_hermit_scene: PackedScene:
	get: return spawner.boss_hermit_scene
	set(val): spawner.boss_hermit_scene = val

var boss_ash_clock_scene: PackedScene:
	get: return spawner.boss_ash_clock_scene
	set(val): spawner.boss_ash_clock_scene = val

var boss_broken_mirror_scene: PackedScene:
	get: return spawner.boss_broken_mirror_scene
	set(val): spawner.boss_broken_mirror_scene = val

var boss_overflow_vortex_scene: PackedScene:
	get: return spawner.boss_overflow_vortex_scene
	set(val): spawner.boss_overflow_vortex_scene = val

var boss_astra_prime_scene: PackedScene:
	get: return spawner.boss_astra_prime_scene
	set(val): spawner.boss_astra_prime_scene = val

var rival_pilot_scene: PackedScene:
	get: return spawner.rival_pilot_scene
	set(val): spawner.rival_pilot_scene = val

var allied_wingman_scene: PackedScene:
	get: return spawner.allied_wingman_scene
	set(val): spawner.allied_wingman_scene = val

var nyx_boss_escort_scene: PackedScene:
	get: return spawner.nyx_boss_escort_scene
	set(val): spawner.nyx_boss_escort_scene = val

var elite_herald_scene: PackedScene:
	get: return spawner.elite_herald_scene
	set(val): spawner.elite_herald_scene = val

func setup_subsystem(p_context: CombatContextScript) -> void:
	super.setup_subsystem(p_context)
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if context and context.main_game:
		main_game = context.main_game as Node2D
		_setup_subcomponents()

func setup(game: Node2D) -> void:
	main_game = game
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_setup_subcomponents()

func _setup_subcomponents() -> void:
	health_bar_manager.setup(main_game)
	cinematic_sequence.setup(main_game, health_bar_manager)
	spawner.setup(main_game, cinematic_sequence, health_bar_manager)

func is_blocking_combat() -> bool:
	if not main_game or not is_instance_valid(main_game):
		return false
	if main_game.has_method("is_cinematic_or_death_active") and main_game.is_cinematic_or_death_active():
		return true
	var current_boss: Node2D = main_game.get("current_boss") as Node2D
	if is_instance_valid(current_boss) and not current_boss.is_queued_for_deletion():
		return true
	var current_rival: Node2D = main_game.get("current_rival") as Node2D
	if is_instance_valid(current_rival) and not current_rival.is_queued_for_deletion():
		return true
	if is_inside_tree():
		for b: Node in get_tree().get_nodes_in_group("bosses"):
			if is_instance_valid(b) and not b.is_queued_for_deletion():
				return true
	return false

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
	var tw: Tween = threat.create_tween()
	tw.tween_property(threat, "modulate:a", 0.1, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		if is_instance_valid(threat) and is_instance_valid(player):
			threat.global_position = target_pos
			if "velocity" in threat:
				threat.set("velocity", Vector2.ZERO)
	)
	tw.tween_property(threat, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func spawn_wave_boss(target_scene_override: PackedScene = null) -> void:
	spawner.spawn_wave_boss(target_scene_override)

func spawn_final_boss(force_spawn: bool = false) -> void:
	spawner.spawn_final_boss(force_spawn, Callable(self, "spawn_allied_wingmen"))

func spawn_rival_pilot(override_id: StringName = &"") -> void:
	spawner.spawn_rival_pilot(override_id)

func spawn_allied_wingmen() -> void:
	spawner.spawn_allied_wingmen()

func spawn_elite_herald() -> void:
	spawner.spawn_elite_herald()

func jump_to_boss(boss_id: String) -> void:
	CombatBossDebugJumperScript.jump_to_boss(main_game, self, boss_id)

func spawn_boss_by_id(boss_id: String, play_intro: bool = true) -> void:
	spawner.spawn_boss_by_id(boss_id, play_intro)

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

	health_bar_manager.hide_boss_bar()
	health_bar_manager.show_character_unlock_banner(p_id, "PILOTO RESPETADA: " + r_name.to_upper(), "Has permitido que la piloto escape pacíficamente. Decisión registrada.")

	var spawner_node: Node = main_game.get("enemy_spawner")
	if spawner_node and spawner_node.has_method("set_spawning_paused"):
		spawner_node.set_spawning_paused(false)
	main_game.call("save_current_run_state")

func on_rival_engaged(p_id: StringName) -> void:
	if not main_game or not is_instance_valid(main_game):
		return
	var spawner_node: Node = main_game.get("enemy_spawner")
	if spawner_node and spawner_node.has_method("set_spawning_paused"):
		spawner_node.set_spawning_paused(true)

	var crisis_mgr: Node = main_game.get("crisis_manager")
	if not crisis_mgr:
		crisis_mgr = main_game.get_node_or_null("CrisisEventManager")
	if crisis_mgr and crisis_mgr.has_method("dismiss_for_boss_encounter"):
		crisis_mgr.dismiss_for_boss_encounter()

	var cur_rival: Node2D = main_game.get("current_rival")
	if cur_rival:
		var r_name: String = "DUELO: " + (cur_rival.pilot_name if "pilot_name" in cur_rival else String(p_id).to_upper())
		var r_hp: float = float(cur_rival.get("max_health")) if "max_health" in cur_rival else 950.0
		health_bar_manager.show_rival_duel(cur_rival, r_name, r_hp)

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

	health_bar_manager.hide_boss_bar()
	health_bar_manager.show_rival_defeated_banner(p_id, r_name)

	var spawner_node: Node = main_game.get("enemy_spawner")
	if spawner_node and spawner_node.has_method("set_spawning_paused"):
		spawner_node.set_spawning_paused(false)
	main_game.call("save_current_run_state")
	main_game.call("_resume_pending_systems_after_cinematics")

func on_boss_defeated(_boss_id: String) -> void:
	if not main_game or not is_instance_valid(main_game):
		return
	var b_def_count: int = int(main_game.get("bosses_defeated_count")) + 1
	main_game.set("bosses_defeated_count", b_def_count)
	main_game.set("current_boss", null)

	health_bar_manager.hide_boss_bar()

	var just_unlocked_nyx: bool = SaveManager.record_boss_kill()
	if just_unlocked_nyx:
		health_bar_manager.show_character_unlock_banner(&"nyx", "¡NUEVO PILOTO DESBLOQUEADO: NYX!", "Has derrotado a 10 Jefes Titanes en tu Carrera espacial.")

	var spawner_node: Node = main_game.get("enemy_spawner")
	if spawner_node and spawner_node.has_method("set_spawning_paused"):
		spawner_node.set_spawning_paused(false)
	main_game.call("save_current_run_state")
	main_game.call("_resume_pending_systems_after_cinematics")

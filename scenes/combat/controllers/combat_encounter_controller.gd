class_name CombatEncounterController
extends Node

## Controller desacoplado para orquestación de encuentros de oleada y gestión de rivales.
## Extraído de MainGame para cumplir con Modularidad Radical (Anti God-Objects).

var main_game: Node2D = null

var rival_queue: Array[StringName] = []
var rivals_spared: Array[StringName] = []
var rivals_killed: Array[StringName] = []

var wave_encounter_checked_for_wave: int = 0
var wave_encounter_spawned_for_wave: int = 0
var wave_encounter_timer: float = 0.0
var wave_encounter_pending: bool = false
var pending_rival_for_dialogue: Node2D = null

func setup(p_main_game: Node2D) -> void:
	main_game = p_main_game

func setup_rival_queue(player_pid: StringName) -> void:
	rival_queue.clear()
	if player_pid == &"nyx":
		var base_6: Array[StringName] = [&"nova", &"valentina", &"kira", &"selene", &"roxy", &"echo"]
		base_6.shuffle()
		for i in range(5):
			rival_queue.append(base_6[i])
	else:
		var all_pilots: Array[StringName] = [&"nova", &"valentina", &"kira", &"selene", &"roxy", &"echo"]
		var available: Array[StringName] = []
		for pid in all_pilots:
			if pid != player_pid:
				available.append(pid)
		for pid in all_pilots:
			if available.has(pid) and rival_queue.size() < 5:
				rival_queue.append(pid)

func get_genocide_escort_pilot_id(player_pid: StringName) -> StringName:
	if player_pid == &"nyx":
		var base_6: Array[StringName] = [&"nova", &"valentina", &"kira", &"selene", &"roxy", &"echo"]
		for pid in base_6:
			if not rivals_killed.has(pid):
				return pid
		return &"nova"
	return &"nyx"

func on_wave_advanced(wave_idx: int) -> void:
	wave_encounter_checked_for_wave = wave_idx
	wave_encounter_pending = true
	wave_encounter_timer = 2.0

func process_tick(delta: float, is_pre_round: bool, current_wave: int) -> void:
	if not is_pre_round and wave_encounter_checked_for_wave != current_wave:
		wave_encounter_checked_for_wave = current_wave
		wave_encounter_pending = true
		wave_encounter_timer = 2.0

	if wave_encounter_pending:
		wave_encounter_timer -= delta
		if wave_encounter_timer <= 0.0:
			wave_encounter_pending = false
			check_wave_encounters(current_wave)

func check_wave_encounters(current_wave: int) -> void:
	if not is_instance_valid(main_game):
		return
	if wave_encounter_spawned_for_wave == current_wave:
		wave_encounter_pending = false
		return
	if main_game.has_method("is_any_combat_modal_active") and main_game.is_any_combat_modal_active():
		wave_encounter_pending = true
		wave_encounter_timer = 0.5
		return
	if main_game.has_method("has_pending_upgrades") and main_game.has_pending_upgrades():
		wave_encounter_pending = true
		wave_encounter_timer = 0.5
		return
	if (main_game.has_method("_has_active_boss_or_rival") and main_game._has_active_boss_or_rival()) or (main_game.has_method("is_cinematic_or_death_active") and main_game.is_cinematic_or_death_active()):
		wave_encounter_pending = true
		wave_encounter_timer = 1.0
		return

	if current_wave >= 16:
		var b_coord = main_game.get("boss_coordinator")
		if b_coord and b_coord.has_method("spawn_final_boss"):
			b_coord.spawn_final_boss()
		elif main_game.has_method("_spawn_final_boss"):
			main_game._spawn_final_boss()
	elif current_wave in [1, 4, 7, 10, 13]:
		var b_coord = main_game.get("boss_coordinator")
		if b_coord and b_coord.has_method("spawn_rival_pilot"):
			b_coord.spawn_rival_pilot()
		elif main_game.has_method("_spawn_rival_pilot"):
			main_game._spawn_rival_pilot()
	elif current_wave in [2, 5, 8, 11, 14]:
		var b_coord = main_game.get("boss_coordinator")
		if b_coord and b_coord.has_method("spawn_wave_boss"):
			b_coord.spawn_wave_boss()
		elif main_game.has_method("_spawn_wave_boss"):
			main_game._spawn_wave_boss()
	elif current_wave in [3, 6, 9, 12, 15]:
		evaluate_slot_machine_spawn(current_wave)

func evaluate_slot_machine_spawn(current_wave: int) -> void:
	if not is_instance_valid(main_game):
		return
	if wave_encounter_spawned_for_wave == current_wave:
		wave_encounter_pending = false
		return
	if (main_game.has_method("_has_active_boss_or_rival") and main_game._has_active_boss_or_rival()) or (main_game.has_method("is_cinematic_or_death_active") and main_game.is_cinematic_or_death_active()):
		wave_encounter_pending = true
		wave_encounter_timer = 1.0
		return
	var loot_coord = main_game.get("loot_coordinator")
	if loot_coord and loot_coord.has_method("evaluate_slot_machine_spawn"):
		loot_coord.evaluate_slot_machine_spawn(true)
		wave_encounter_spawned_for_wave = current_wave
		wave_encounter_pending = false

func resume_pending_encounters_after_modal() -> void:
	if not is_instance_valid(main_game):
		return
	if pending_rival_for_dialogue != null and is_instance_valid(pending_rival_for_dialogue):
		var target_rival: Node2D = pending_rival_for_dialogue
		pending_rival_for_dialogue = null
		main_game.get_tree().create_timer(0.5, true, false, true).timeout.connect(func() -> void:
			if is_instance_valid(target_rival) and main_game.has_method("is_upgrade_or_shop_modal_active") and not main_game.is_upgrade_or_shop_modal_active():
				if main_game.has_method("_trigger_pet_rival_encounter"):
					main_game._trigger_pet_rival_encounter(target_rival)
			elif is_instance_valid(target_rival):
				pending_rival_for_dialogue = target_rival
		)
	elif wave_encounter_pending:
		wave_encounter_timer = 0.5

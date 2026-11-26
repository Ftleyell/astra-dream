class_name MainGame
extends Node2D
## Orquestador central de combate y escena raíz de gameplay.
## Coordina subsistemas, ciclos de oleadas y eventos tácticos mediante delegación modular.


const RunStateSerializer = preload("res://scenes/combat/systems/run_state_serializer.gd")
const CombatModalCoordinator = preload("res://scenes/combat/ui/combat_modal_coordinator.gd")
const CombatNarrativeDirector = preload("res://scenes/combat/directors/combat_narrative_director.gd")
const CombatBossCoordinator = preload("res://scenes/combat/directors/combat_boss_coordinator.gd")
const CombatEndRunController = preload("res://scenes/combat/controllers/combat_end_run_controller.gd")
const CombatTelemetryCoordinatorScript = preload("res://scenes/combat/systems/combat_telemetry_coordinator.gd")
const CombatEncounterControllerScript = preload("res://scenes/combat/controllers/combat_encounter_controller.gd")
const CombatInputDispatcherScript = preload("res://scenes/combat/controllers/combat_input_dispatcher.gd")
const CombatTacticalInteractionsScript = preload("res://scenes/combat/systems/combat_tactical_interactions.gd")
const CombatBootstrapperScript = preload("res://scenes/combat/systems/combat_bootstrapper.gd")
const CombatSceneAssemblerScript = preload("res://scenes/combat/systems/combat_scene_assembler.gd")
const CombatContextScript = preload("res://scenes/combat/systems/combat_context.gd")
const CombatWavePipelineScript = preload("res://scenes/combat/directors/combat_wave_pipeline.gd")
const CombatSpaceDebrisManagerScript = preload("res://scenes/combat/systems/combat_space_debris_manager.gd")
const CombatPlayerFeedbackCoordinatorScript = preload("res://scenes/combat/systems/combat_player_feedback_coordinator.gd")
const CombatExpBatchOptimizerScript = preload("res://scenes/combat/systems/combat_exp_batch_optimizer.gd")
const CombatSatelliteCoordinator = preload("res://scenes/combat/systems/combat_satellite_coordinator.gd")
const CombatLootCoordinator = preload("res://scenes/combat/systems/combat_loot_coordinator.gd")
const SpaceEnvironmentHostScript = preload("res://scenes/combat/environment/space_environment_host.gd")
const RunLaunchRequestScript = preload("res://core/systems/run_launch_request.gd")
const CombatHubSessionControllerScript = preload("res://scenes/combat/controllers/combat_hub_session_controller.gd")

var modal_coordinator: CombatModalCoordinator = CombatModalCoordinator.new()
var narrative_director: CombatNarrativeDirector = CombatNarrativeDirector.new()
var boss_coordinator: CombatBossCoordinator = CombatBossCoordinator.new()
var end_run_controller: CombatEndRunController = CombatEndRunController.new()
var telemetry_coordinator: CombatTelemetryCoordinatorScript = CombatTelemetryCoordinatorScript.new()
var encounter_controller: CombatEncounterControllerScript = CombatEncounterControllerScript.new()
var input_dispatcher: CombatInputDispatcherScript = CombatInputDispatcherScript.new()
var space_debris_manager: RefCounted = CombatSpaceDebrisManagerScript.new()
var feedback_coordinator: RefCounted = CombatPlayerFeedbackCoordinatorScript.new()
var exp_batch_optimizer: RefCounted = CombatExpBatchOptimizerScript.new()
var satellite_coordinator: CombatSatelliteCoordinator = CombatSatelliteCoordinator.new()
var environment_host: SpaceEnvironmentHost = SpaceEnvironmentHostScript.new()
var hub_session_controller: CombatHubSessionControllerScript = null
var active_launch_request: RunLaunchRequestScript = null
var run_director_seed: int = 0
var run_loot_seed: int = 0
var run_seed: int = 0:
	set(val):
		run_seed = val
		if environment_host and is_instance_valid(environment_host.active_environment):
			environment_host.active_environment.set_environment_seed(run_seed)
var loot_coordinator: CombatLootCoordinator = null

var combat_context: CombatContextScript = null
var wave_pipeline: CombatWavePipelineScript = null
var run_modifier_manager: Node = null
var fork_director: Node = null
var fork_overlay: CanvasLayer = null


@onready var player: Player = $Player
@onready var bullet_server: BulletServer = $BulletServer
@onready var hud: GameHUD = $HUD
@onready var level_up_modal: LevelUpModal = $LevelUpModal
@onready var satellite_shop: SatelliteShop = $SatelliteShop
@onready var stat_deck_manager: StatDeckManager = $StatDeckManager
@onready var audio_duck_manager: AudioDuckManager = $AudioDuckManager
@onready var camera: GameCamera2D = $Camera2D
@onready var enemy_spawner: EnemySpawner = $EnemySpawner
@onready var pause_menu: PauseMenu = get_node_or_null("PauseMenu") as PauseMenu
@onready var skip_badge_layer: CanvasLayer = get_node_or_null("SkipBadgeLayer")
@onready var game_over_modal: GameOverModal = get_node_or_null("GameOverModal") as GameOverModal
var game_over_scene: PackedScene = preload("res://scenes/ui/game_over/game_over_modal.tscn")
var chest_director: ChestDirector = null
var chest_reward_modal: ChestRewardModal = null
var transmutation_modal: TransmutationModal = null
var arcana_modal: ArcanaSelectionModal = null

var current_boss: Node2D = null
var current_rival: Node2D = null
var current_genocide_escort: Node2D = null
var crisis_manager: Node2D = null
var crisis_banner: CanvasLayer = null
var crisis_event_manager_scene: PackedScene = preload("res://scenes/combat/events/crisis_event_manager.tscn")
var crisis_alert_banner_scene: PackedScene = preload("res://scenes/ui/hud/crisis_alert_banner.tscn")
var active_pet: CompanionPet = null
var active_navigator_controller = null
var encounter_director: EncounterDirector = null

const WAVE_DURATION: float = 30.0
const MAX_SATELLITES_PER_WAVE: int = 1
const PRE_ROUND_DURATION: float = 30.0
const AUTO_SAVE_INTERVAL: float = 5.0
const SATELLITE_DESPAWN_DISTANCE: float = 10000.0

var _last_quantum_keys_count: int = -1
var _last_green_cards_count: int = -1
var _auto_save_timer: float = 0.0
var is_exiting_run: bool = false
var is_wave_11_cleared: bool = false
var is_endless_mode: bool = false
var _on_dialogue_finished_callback: Callable = Callable()

# --- PROXIES COMPACTOS DE SUBSISTEMAS ---
var space_object_spawner: SpaceObjectSpawner:
	get: return space_debris_manager.space_object_spawner if space_debris_manager else null
	set(val): if space_debris_manager: space_debris_manager.space_object_spawner = val
var _pending_arcana_picks: int:
	get: return modal_coordinator.pending_arcana_picks if modal_coordinator else 0
	set(val): if modal_coordinator: modal_coordinator.pending_arcana_picks = val
var _pending_satellite_credits: int:
	get: return modal_coordinator.pending_satellite_credits if modal_coordinator else -1
	set(val): if modal_coordinator: modal_coordinator.pending_satellite_credits = val
var _pending_satellite_index: int:
	get: return modal_coordinator.pending_satellite_index if modal_coordinator else -1
	set(val): if modal_coordinator: modal_coordinator.pending_satellite_index = val
var bosses_defeated_count: int:
	get: return telemetry_coordinator.bosses_defeated_count if telemetry_coordinator else 0
	set(val):
		if telemetry_coordinator: telemetry_coordinator.bosses_defeated_count = val
		if combat_context: combat_context.bosses_defeated_count = val
var satellite_scene: PackedScene:
	get: return satellite_coordinator.satellite_scene if satellite_coordinator else null
	set(val): if satellite_coordinator: satellite_coordinator.satellite_scene = val
var current_satellite: Node2D:
	get: return satellite_coordinator.current_satellite if satellite_coordinator else null
	set(val): if satellite_coordinator: satellite_coordinator.current_satellite = val
var current_satellite_idx: int:
	get: return satellite_coordinator.current_satellite_idx if satellite_coordinator else 1
	set(val): if satellite_coordinator: satellite_coordinator.current_satellite_idx = val
var wave_satellites_spawned: int:
	get: return satellite_coordinator.wave_satellites_spawned if satellite_coordinator else 0
	set(val): if satellite_coordinator: satellite_coordinator.wave_satellites_spawned = val
var satellites_collected_total: int:
	get: return satellite_coordinator.satellites_collected_total if satellite_coordinator else 0
	set(val): if satellite_coordinator: satellite_coordinator.satellites_collected_total = val
var last_anchor_pos: Vector2:
	get: return satellite_coordinator.last_anchor_pos if satellite_coordinator else Vector2.ZERO
	set(val): if satellite_coordinator: satellite_coordinator.last_anchor_pos = val
var current_wave: int:
	get: return wave_pipeline.current_wave if wave_pipeline else 1
	set(val):
		if wave_pipeline: wave_pipeline.current_wave = val
		if combat_context: combat_context.current_wave = val
var is_pre_round: bool:
	get: return wave_pipeline.is_pre_round if wave_pipeline else false
	set(val): if wave_pipeline: wave_pipeline.is_pre_round = val
var pre_round_timer: float:
	get: return wave_pipeline.pre_round_timer if wave_pipeline else PRE_ROUND_DURATION
	set(val): if wave_pipeline: wave_pipeline.pre_round_timer = val
var wave_timer: float:
	get: return wave_pipeline.wave_timer if wave_pipeline else WAVE_DURATION
	set(val):
		if wave_pipeline: wave_pipeline.wave_timer = val
		if combat_context: combat_context.wave_timer = val
var rival_queue: Array[StringName]:
	get: return encounter_controller.rival_queue if encounter_controller else []
	set(val): if encounter_controller: encounter_controller.rival_queue = val
var rivals_spared: Array[StringName]:
	get: return encounter_controller.rivals_spared if encounter_controller else []
	set(val): if encounter_controller: encounter_controller.rivals_spared = val
var rivals_killed: Array[StringName]:
	get: return encounter_controller.rivals_killed if encounter_controller else []
	set(val): if encounter_controller: encounter_controller.rivals_killed = val
var is_briefing_active: bool:
	get: return narrative_director.is_briefing_active if narrative_director else false
	set(val): if narrative_director: narrative_director.is_briefing_active = val
var is_cockpit_active: bool:
	get: return narrative_director.is_cockpit_active if narrative_director else false
	set(val): if narrative_director: narrative_director.is_cockpit_active = val
var is_boss_transmission_active: bool:
	get: return narrative_director.is_boss_transmission_active if narrative_director else false
	set(val): if narrative_director: narrative_director.is_boss_transmission_active = val
var is_victory_dialogue_active: bool:
	get: return narrative_director.is_victory_dialogue_active if narrative_director else false
	set(val): if narrative_director: narrative_director.is_victory_dialogue_active = val
var is_rival_cinematic_active: bool:
	get: return narrative_director.is_rival_cinematic_active if narrative_director else false
	set(val): if narrative_director: narrative_director.is_rival_cinematic_active = val
var _pending_victory_data: Dictionary:
	get: return narrative_director.pending_victory_data if narrative_director else {}
	set(val): if narrative_director: narrative_director.pending_victory_data = val
var prologue_bonus_chosen: bool:
	get: return narrative_director.prologue_bonus_chosen if narrative_director else false
	set(val): if narrative_director: narrative_director.prologue_bonus_chosen = val
var run_time_elapsed: float:
	get: return telemetry_coordinator.run_time_elapsed if telemetry_coordinator else 0.0
	set(val): if telemetry_coordinator: telemetry_coordinator.run_time_elapsed = val
var enemies_killed_count: int:
	get: return telemetry_coordinator.enemies_killed_count if telemetry_coordinator else 0
	set(val):
		if telemetry_coordinator: telemetry_coordinator.enemies_killed_count = val
		if combat_context: combat_context.enemies_killed_count = val
var current_slot_machine: Node2D:
	get: return loot_coordinator.current_slot_machine if loot_coordinator else null
var slot_machine_modal: CanvasLayer:
	get: return loot_coordinator.slot_machine_modal if loot_coordinator else null
var slot_machine_reward_modal: CanvasLayer:
	get: return loot_coordinator.slot_machine_reward_modal if loot_coordinator else null


func _exit_tree() -> void:
	is_exiting_run = true
	Engine.time_scale = 1.0

func _ready() -> void:
	var entry_mode: int = RunLaunchRequestScript.consume_entry_mode()
	if entry_mode == RunLaunchRequestScript.EntryMode.HUB and not SaveManager.is_resuming_run:
		active_launch_request = RunLaunchRequestScript.create_random_auto()
		run_seed = active_launch_request.cosmos_seed
		run_director_seed = active_launch_request.run_director_seed
		run_loot_seed = active_launch_request.run_loot_seed
		Engine.time_scale = 1.0
		add_to_group("main_game")
		if enemy_spawner != null:
			enemy_spawner.set_spawning_paused(true)
		CombatBootstrapperScript.sync_character_loadout()
		_setup_rival_queue()
		CombatSceneAssemblerScript.assemble(self, player, hud, false)
		CombatBootstrapperScript.launch_session(self, player, hud, true)
		hub_session_controller = CombatHubSessionControllerScript.new() as CombatHubSessionControllerScript
		hub_session_controller.name = "CombatHubSessionController"
		add_child(hub_session_controller)
		hub_session_controller.enter_hub_mode(self, active_launch_request)
		return

	var pending_req: RunLaunchRequestScript = RunLaunchRequestScript.consume_pending()
	if pending_req != null:
		active_launch_request = pending_req
		run_seed = pending_req.cosmos_seed
		run_director_seed = pending_req.run_director_seed
		run_loot_seed = pending_req.run_loot_seed
	else:
		if run_seed == 0:
			run_seed = maxi(1, int(randi()) & 0x7FFFFFFF)
		active_launch_request = RunLaunchRequestScript.create(run_seed, RunLaunchRequestScript.SeedMode.AUTO)
		run_director_seed = active_launch_request.run_director_seed
		run_loot_seed = active_launch_request.run_loot_seed
	Engine.time_scale = SaveManager.get_game_speed()
	add_to_group("main_game")


	# Sincronización estricta del loadout del personaje seleccionado
	CombatBootstrapperScript.sync_character_loadout()

	_setup_rival_queue()

	# Ensamblado modular de directores, modales, controladores y cableado inicial
	CombatSceneAssemblerScript.assemble(self, player, hud)

	CombatBootstrapperScript.launch_session(self, player, hud)

	if active_launch_request != null and active_launch_request.seamless_entry:
		_apply_seamless_hub_entry()


func _apply_seamless_hub_entry() -> void:
	if active_launch_request == null:
		return
	var dir_2d: Vector2 = active_launch_request.departure_direction
	if dir_2d.length_squared() < 0.001:
		dir_2d = Vector2.UP
	dir_2d = dir_2d.normalized()
	if is_instance_valid(player):
		player.velocity = dir_2d * 340.0
	if is_instance_valid(hud):
		hud.offset = Vector2(0.0, -24.0)
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(hud, "offset", Vector2.ZERO, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		for child: Node in hud.get_children():
			if child is CanvasItem:
				var ci := child as CanvasItem
				var orig_a: float = ci.modulate.a
				ci.modulate.a = 0.0
				tw.tween_property(ci, "modulate:a", orig_a, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _setup_rival_queue() -> void:
	var player_pid: StringName = player.character_data.character_id if (player and player.character_data) else &"nova"
	if encounter_controller:
		encounter_controller.setup_rival_queue(player_pid)

func _get_genocide_escort_pilot_id() -> StringName:
	var player_pid: StringName = player.character_data.character_id if (player and player.character_data) else &"nova"
	if encounter_controller:
		return encounter_controller.get_genocide_escort_pilot_id(player_pid)
	return &"nyx"

func _get_rival_dialogue(rival_pid: StringName, player_pid: StringName) -> Dictionary:
	if narrative_director:
		return narrative_director.get_rival_dialogue(rival_pid, player_pid)
	return {}

func _trigger_post_boss_victory_dialogue(route: String, victory_data: Dictionary) -> void:
	if narrative_director:
		narrative_director.trigger_post_boss_victory_dialogue(route, victory_data)




func _start_prologue_briefing() -> void:
	if narrative_director: narrative_director.start_prologue_briefing()
	else:
		is_briefing_active = false
		PauseArbitrator.force_unpause_all()

func _on_dialogic_signal(arg: Variant) -> void: if narrative_director: narrative_director.on_dialogic_signal(arg)

func _on_dialogic_timeline_started() -> void: if narrative_director: narrative_director.on_timeline_started()
func _on_dialogue_skip_requested() -> void: if narrative_director: narrative_director.skip_dialogue()
func _on_dialogic_timeline_ended() -> void: if narrative_director: narrative_director.on_timeline_ended()
func _finish_prologue_and_start_run() -> void:
	if narrative_director: narrative_director._finish_prologue_and_start_run()
	else:
		is_briefing_active = false
		PauseArbitrator.force_unpause_all()

func _trigger_cockpit_interlude() -> void: if narrative_director: narrative_director.trigger_cockpit_interlude()


func _process(delta: float) -> void:
	if get_tree().paused or is_cinematic_or_death_active() or is_hub_mode_active(): return
	if telemetry_coordinator: telemetry_coordinator.tick(delta)
	else: run_time_elapsed += delta
	if encounter_controller: encounter_controller.process_tick(delta, is_pre_round, current_wave)
	_auto_save_timer += delta
	if _auto_save_timer >= AUTO_SAVE_INTERVAL:
		_auto_save_timer = 0.0
		save_current_run_state()
	if chest_director and is_instance_valid(player):
		var green_cards: int = player.inventory.get_item_count(&"credit_card_green") if player.inventory else 0
		chest_director.update_continuous_spawner(delta, player.global_position, self, green_cards)
	var counts: Array[int] = CombatTacticalInteractionsScript.handle_tactical_inventory_changes(player, hud, chest_director, _last_quantum_keys_count, _last_green_cards_count)
	_last_quantum_keys_count = counts[0]
	_last_green_cards_count = counts[1]
	if exp_batch_optimizer: exp_batch_optimizer.tick(delta, get_tree(), player)
	elif is_instance_valid(player): ExpBlob.batch_distant_blobs_if_needed(get_tree(), player.global_position)
	if wave_pipeline: wave_pipeline.tick(delta, _has_active_boss_or_rival())

func _check_satellite_despawn() -> void:
	if satellite_coordinator: satellite_coordinator.check_satellite_despawn()

func _despawn_current_satellite() -> void:
	if satellite_coordinator: satellite_coordinator.despawn_current_satellite()

func _spawn_next_satellite_for_wave() -> void:
	if satellite_coordinator: satellite_coordinator.spawn_next_satellite_for_wave()

func _has_active_boss_or_rival() -> bool:
	if is_instance_valid(current_boss) and not current_boss.is_queued_for_deletion():
		return true
	if is_instance_valid(current_rival) and not current_rival.is_queued_for_deletion():
		return true
	for b in get_tree().get_nodes_in_group("bosses"):
		if is_instance_valid(b) and not b.is_queued_for_deletion():
			return true
	for r in get_tree().get_nodes_in_group("rival_pilots"):
		if is_instance_valid(r) and not r.is_queued_for_deletion():
			return true
	return false


func _on_wave_pipeline_advanced(wave_idx: int) -> void:
	wave_satellites_spawned = 0
	if enemy_spawner and enemy_spawner.has_method("set_wave"):
		enemy_spawner.set_wave(wave_idx)
	if encounter_controller:
		encounter_controller.on_wave_advanced(wave_idx)
	save_current_run_state()
	_spawn_next_satellite_for_wave()
	if chest_director:
		var green_cards: int = player.inventory.get_item_count(&"credit_card_green") if (player and player.inventory) else 0
		chest_director.on_new_wave(wave_idx, green_cards)
	_spawn_wave_chests()
	if space_debris_manager:
		space_debris_manager.notify_wave_started(wave_idx)


func _on_wave_pipeline_hud_update(is_pre: bool, wave_idx: int, timer: float) -> void:
	if not is_instance_valid(hud):
		return
	if is_pre:
		hud.update_pre_round_status(timer)
	else:
		hud.update_wave_status(wave_idx, timer, wave_satellites_spawned, MAX_SATELLITES_PER_WAVE)


func _check_wave_encounters() -> void: if encounter_controller: encounter_controller.check_wave_encounters(current_wave)
func _evaluate_slot_machine_spawn() -> void: if encounter_controller: encounter_controller.evaluate_slot_machine_spawn(current_wave)
func _spawn_slot_machine(spawn_pos: Vector2 = Vector2.INF) -> void:
	if loot_coordinator:
		loot_coordinator.spawn_slot_machine(spawn_pos)
		if encounter_controller:
			encounter_controller.wave_encounter_spawned_for_wave = current_wave
			encounter_controller.wave_encounter_pending = false

func _spawn_elite_herald() -> void: if boss_coordinator: boss_coordinator.spawn_elite_herald()
func _spawn_rival_pilot(override_id: StringName = &"") -> void: if boss_coordinator: boss_coordinator.spawn_rival_pilot(override_id)
func _on_rival_spared(p_id: StringName) -> void: if boss_coordinator: boss_coordinator.on_rival_spared(p_id)
func _on_rival_engaged(p_id: StringName) -> void: if boss_coordinator: boss_coordinator.on_rival_engaged(p_id)
func _on_rival_defeated(p_id: StringName, weapon: WeaponData) -> void: if boss_coordinator: boss_coordinator.on_rival_defeated(p_id, weapon)
func _spawn_wave_boss(target_scene_override: PackedScene = null) -> void: if boss_coordinator: boss_coordinator.spawn_wave_boss(target_scene_override)
func _spawn_final_boss(force_spawn: bool = false) -> void: if boss_coordinator: boss_coordinator.spawn_final_boss(force_spawn)
func _spawn_allied_wingmen() -> void: if boss_coordinator: boss_coordinator.spawn_allied_wingmen()
func _on_boss_defeated(boss_id: String) -> void: if boss_coordinator: boss_coordinator.on_boss_defeated(boss_id)
func jump_to_boss(boss_id: String) -> void: if boss_coordinator: boss_coordinator.jump_to_boss(boss_id)
func jump_to_wave_11(route: String = "neutral") -> void: if boss_coordinator: boss_coordinator.jump_to_wave_16(route)
func jump_to_wave_16(route: String = "neutral") -> void: if boss_coordinator: boss_coordinator.jump_to_wave_16(route)
func spawn_next_rival_pilot() -> void: if boss_coordinator: boss_coordinator.spawn_rival_pilot()
func _input(event: InputEvent) -> void: if input_dispatcher: input_dispatcher.handle_input(event)
func _spawn_next_satellite(target_pos: Vector2) -> void: if satellite_coordinator: satellite_coordinator.spawn_next_satellite(target_pos)
func _on_satellite_planted(index: int, pos: Vector2) -> void: if satellite_coordinator: satellite_coordinator._on_satellite_planted(index, pos)
func _on_satellite_exited(index: int) -> void: if satellite_coordinator: satellite_coordinator._on_satellite_exited(index)
func trigger_boss_transmission(speaker: String = "CENTINELA TITÁN", _text: String = "") -> void:
	if narrative_director: narrative_director.trigger_pet_boss_alert(speaker if not speaker.is_empty() else "CENTINELA TITÁN")

func _on_item_purchased(item_or_weapon: Resource, cost: int) -> void:
	if satellite_coordinator: satellite_coordinator.on_item_purchased(item_or_weapon, cost)

func _on_level_up_requested(level: int) -> void: if modal_coordinator: modal_coordinator.on_level_up_requested(level)
func _on_satellite_shop_closed() -> void: if modal_coordinator: modal_coordinator.on_satellite_shop_closed()

func is_pause_menu_active() -> bool: return modal_coordinator.is_pause_menu_active() if modal_coordinator else (pause_menu != null and pause_menu.visible)
func is_satellite_shop_active() -> bool: return modal_coordinator.is_satellite_shop_active() if modal_coordinator else (satellite_shop != null and satellite_shop.visible)
func is_arcana_modal_active() -> bool: return modal_coordinator.is_arcana_modal_active() if modal_coordinator else false
func _on_arcana_orb_collected(orb: Node2D) -> void: if modal_coordinator: modal_coordinator.on_arcana_orb_collected(orb)
func _on_arcana_modal_closed() -> void: if modal_coordinator: modal_coordinator.on_arcana_modal_closed()
func _on_level_up_modal_closed() -> void: if modal_coordinator: modal_coordinator.on_level_up_modal_closed()

func _spawn_wave_chests() -> void:
	if chest_director and is_instance_valid(player):
		var green_cards: int = player.inventory.get_item_count(&"credit_card_green") if player.inventory else 0
		chest_director.spawn_wave_chests(player.global_position, self, current_wave, green_cards)

func _on_chest_opened_from_director(_item: ItemData, _was_free: bool, _cost: int) -> void: save_current_run_state()
func _on_wave_completed() -> void: apply_chronos_bank_interest()
func apply_chronos_bank_interest() -> void: CombatTacticalInteractionsScript.apply_chronos_bank_interest(player, hud)
func on_salvage_capsule_opened(player_ref: Player = null) -> void: CombatTacticalInteractionsScript.on_salvage_capsule_opened(player_ref if player_ref else player, hud)

func open_transmutation_modal(station: TransmutationStation) -> void:
	if transmutation_modal and is_instance_valid(player): transmutation_modal.open_for_station(player, station)

func _resume_pending_encounters_after_modal() -> void: if encounter_controller: encounter_controller.resume_pending_encounters_after_modal()
func is_level_up_modal_active() -> bool: return modal_coordinator.is_level_up_modal_active() if modal_coordinator else (level_up_modal != null and level_up_modal.visible)
func is_character_stats_active() -> bool: return modal_coordinator.is_character_stats_active() if modal_coordinator else false
func is_game_over_active() -> bool: return modal_coordinator.is_game_over_active() if modal_coordinator else false

func is_cinematic_or_death_active() -> bool:
	if CinematicDeathSequence.is_sequence_active: return true
	if is_rival_cinematic_active or is_briefing_active or is_cockpit_active or is_boss_transmission_active or is_victory_dialogue_active: return true
	if current_boss and is_instance_valid(current_boss) and current_boss.get("is_dying") == true: return true
	if current_rival and is_instance_valid(current_rival) and current_rival.get("is_dying") == true: return true
	if current_boss and is_instance_valid(current_boss) and current_boss.get("is_invulnerable") == true and current_boss.get_meta("_is_emerging", false) == true: return true
	return false

func is_dialogue_active() -> bool: return narrative_director.is_dialogue_active() if narrative_director else false
func is_upgrade_or_shop_modal_active() -> bool: return modal_coordinator.is_upgrade_or_shop_modal_active() if modal_coordinator else false
func has_pending_upgrades() -> bool: return modal_coordinator.has_pending_upgrades() if modal_coordinator else false
func is_hub_mode_active() -> bool:
	return hub_session_controller != null and is_instance_valid(hub_session_controller) and hub_session_controller.is_hub_mode_active()

func is_position_in_hub_exclusion_zone(world_pos: Vector2, extra_padding_px: float = 0.0) -> bool:
	if hub_session_controller == null or not is_instance_valid(hub_session_controller):
		return false
	return hub_session_controller.is_position_in_hub_exclusion_zone(world_pos, extra_padding_px)

func is_position_allowed_for_combat_spawn(world_pos: Vector2, player_pos: Vector2, extra_padding_px: float = 0.0, require_forward_bias: bool = true) -> bool:
	if hub_session_controller == null or not is_instance_valid(hub_session_controller):
		return true
	return hub_session_controller.is_position_allowed_for_combat_spawn(world_pos, player_pos, extra_padding_px, require_forward_bias)

func get_hub_launch_departure_direction() -> Vector2:
	if hub_session_controller == null or not is_instance_valid(hub_session_controller):
		return Vector2.ZERO
	return hub_session_controller.get_launch_departure_direction()

func get_hub_launch_forward_cone_half_angle_rad() -> float:
	if hub_session_controller == null or not is_instance_valid(hub_session_controller):
		return deg_to_rad(65.0)
	return hub_session_controller.get_launch_forward_cone_half_angle_rad()

func push_position_outside_hub_exclusion(world_pos: Vector2, fallback_dir: Vector2, extra_padding_px: float = 0.0) -> Vector2:
	if hub_session_controller == null or not is_instance_valid(hub_session_controller):
		return world_pos
	return hub_session_controller.push_position_outside_hub_exclusion(world_pos, fallback_dir, extra_padding_px)

func is_any_hub_modal_active() -> bool:
	return hub_session_controller != null and is_instance_valid(hub_session_controller) and hub_session_controller.is_any_hub_modal_active()

func is_any_combat_modal_active() -> bool:
	if is_hub_mode_active(): return false
	if ingame_debug_modal and ingame_debug_modal.is_open: return true
	return modal_coordinator.is_any_combat_modal_active() if modal_coordinator else false

func notify_menu_closed(duration: float = 0.35) -> void:
	if modal_coordinator: modal_coordinator.notify_menu_closed(duration)
	elif is_instance_valid(player) and player.has_method("suppress_bomb_input"): player.suppress_bomb_input(duration)

func restore_combat_modal_focus() -> void: if modal_coordinator: modal_coordinator.restore_combat_modal_focus()
func _open_next_pending_arcana() -> void: if modal_coordinator: modal_coordinator.open_next_pending_arcana()
func _resume_pending_systems_after_cinematics() -> void: if modal_coordinator: modal_coordinator._step_next_modal()

func _on_player_bomb_used(remaining: int) -> void:
	if feedback_coordinator: feedback_coordinator.on_player_bomb_used(remaining)
	elif camera: camera.add_trauma(0.6)

func _on_player_health_changed(current: float, max_val: float) -> void:
	if feedback_coordinator: feedback_coordinator.on_player_health_changed(current, max_val)

func _on_enemy_killed(_enemy_type: String) -> void:
	if telemetry_coordinator: telemetry_coordinator.record_enemy_killed(_enemy_type)
	else: enemies_killed_count += 1

func _on_player_died() -> void:
	if feedback_coordinator: feedback_coordinator.on_player_died()
	elif end_run_controller: end_run_controller.on_player_died()

func _show_game_over_screen(data: Dictionary) -> void: if end_run_controller: end_run_controller.show_game_over_screen(data)
func _on_game_over_endless() -> void: if end_run_controller: end_run_controller.handle_game_over_endless()
func _on_game_over_restart() -> void: if end_run_controller: end_run_controller.handle_game_over_restart()
func _on_game_over_hub() -> void: if end_run_controller: end_run_controller.handle_game_over_hub()


# ==============================================================================
# SERIALIZACIÓN Y RESTAURACIÓN DEL ESTADO DE LA RUN
# ==============================================================================

func get_current_run_state() -> Dictionary:
	return RunStateSerializer.get_run_state(self)

func save_current_run_state() -> void:
	RunStateSerializer.save_run_state(self)

func restore_run_state(run_data: Dictionary) -> void:
	RunStateSerializer.restore_run_state(self, run_data)

var ingame_debug_modal: CanvasLayer:
	get: return input_dispatcher.ingame_debug_modal if input_dispatcher else null
	set(val): if input_dispatcher: input_dispatcher.ingame_debug_modal = val

func _toggle_ingame_debug() -> void: if input_dispatcher: input_dispatcher.toggle_ingame_debug()

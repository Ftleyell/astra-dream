class_name MainGame
extends Node2D

const RunStateSerializer = preload("res://scenes/combat/systems/run_state_serializer.gd")
const CombatModalCoordinator = preload("res://scenes/combat/ui/combat_modal_coordinator.gd")
const CombatNarrativeDirector = preload("res://scenes/combat/directors/combat_narrative_director.gd")
const CombatBossCoordinator = preload("res://scenes/combat/directors/combat_boss_coordinator.gd")
const CombatTelemetryRecorder = preload("res://scenes/combat/systems/combat_telemetry_recorder.gd")
const PlanetSpawnerHelper = preload("res://scenes/combat/environment/planet_spawner_helper.gd")

var modal_coordinator: CombatModalCoordinator = CombatModalCoordinator.new()
var narrative_director: CombatNarrativeDirector = CombatNarrativeDirector.new()
var boss_coordinator: CombatBossCoordinator = CombatBossCoordinator.new()


@onready var player: Player = $Player
@onready var bullet_server: BulletServer = $BulletServer
@onready var hud: GameHUD = $HUD
@onready var level_up_modal: LevelUpModal = $LevelUpModal
var space_object_spawner: SpaceObjectSpawner = null
var arcana_modal: ArcanaSelectionModal = null
var _pending_arcana_picks: int = 0
var _pending_satellite_credits: int = -1
var _pending_satellite_index: int = -1
@onready var satellite_shop: SatelliteShop = $SatelliteShop
@onready var stat_deck_manager: StatDeckManager = $StatDeckManager
@onready var audio_duck_manager: AudioDuckManager = $AudioDuckManager
@onready var camera: GameCamera2D = $Camera2D
@onready var enemy_spawner: EnemySpawner = $EnemySpawner
@onready var pause_menu: PauseMenu = get_node_or_null("PauseMenu") as PauseMenu
@onready var skip_badge_layer: CanvasLayer = get_node_or_null("SkipBadgeLayer")
@onready var game_over_modal: GameOverModal = get_node_or_null("GameOverModal") as GameOverModal
var game_over_scene: PackedScene = preload("res://scenes/ui/game_over/game_over_modal.tscn")
var bosses_defeated_count: int = 0

var chest_director: ChestDirector = null
var chest_reward_modal: ChestRewardModal = null
var transmutation_modal: TransmutationModal = null
var _last_quantum_keys_count: int = -1
var _last_green_cards_count: int = -1

const CombatSatelliteCoordinator = preload("res://scenes/combat/systems/combat_satellite_coordinator.gd")
var satellite_coordinator: CombatSatelliteCoordinator = CombatSatelliteCoordinator.new()

const WAVE_DURATION: float = 30.0
const MAX_SATELLITES_PER_WAVE: int = 1
const BASE_SPAWN_DISTANCE: float = 600.0
const DISTANCE_INCREMENT_PER_SAT: float = 250.0
const SPAWN_AHEAD_DISTANCE: float = 1100.0

var satellite_scene: PackedScene:
	get:
		return satellite_coordinator.satellite_scene if satellite_coordinator else null
	set(val):
		if satellite_coordinator:
			satellite_coordinator.satellite_scene = val

var current_satellite: Node2D:
	get:
		return satellite_coordinator.current_satellite if satellite_coordinator else null
	set(val):
		if satellite_coordinator:
			satellite_coordinator.current_satellite = val

var current_satellite_idx: int:
	get:
		return satellite_coordinator.current_satellite_idx if satellite_coordinator else 1
	set(val):
		if satellite_coordinator:
			satellite_coordinator.current_satellite_idx = val

var wave_satellites_spawned: int:
	get:
		return satellite_coordinator.wave_satellites_spawned if satellite_coordinator else 0
	set(val):
		if satellite_coordinator:
			satellite_coordinator.wave_satellites_spawned = val

var satellites_collected_total: int:
	get:
		return satellite_coordinator.satellites_collected_total if satellite_coordinator else 0
	set(val):
		if satellite_coordinator:
			satellite_coordinator.satellites_collected_total = val

var last_anchor_pos: Vector2:
	get:
		return satellite_coordinator.last_anchor_pos if satellite_coordinator else Vector2.ZERO
	set(val):
		if satellite_coordinator:
			satellite_coordinator.last_anchor_pos = val

var crisis_event_manager_scene: PackedScene = preload("res://scenes/combat/events/crisis_event_manager.tscn")
var crisis_alert_banner_scene: PackedScene = preload("res://scenes/ui/hud/crisis_alert_banner.tscn")

var current_boss: Node2D = null
var current_rival: Node2D = null
var current_genocide_escort: Node2D = null
var crisis_manager: Node2D = null
var crisis_banner: CanvasLayer = null
var _last_player_hp: float = 100.0
var _exp_batch_timer: float = 0.0

var current_wave: int = 1
var is_pre_round: bool = true
const PRE_ROUND_DURATION: float = 30.0
var pre_round_timer: float = PRE_ROUND_DURATION
var wave_timer: float = WAVE_DURATION

var rival_queue: Array[StringName] = []
var rivals_spared: Array[StringName] = []
var rivals_killed: Array[StringName] = []
var is_wave_11_cleared: bool = false

var _fallback_briefing_active: bool = true
var is_briefing_active: bool:
	get:
		return narrative_director.is_briefing_active if narrative_director else _fallback_briefing_active
	set(val):
		_fallback_briefing_active = val
		if narrative_director:
			narrative_director.is_briefing_active = val

var is_cockpit_active: bool:
	get:
		return narrative_director.is_cockpit_active if narrative_director else false
	set(val):
		if narrative_director:
			narrative_director.is_cockpit_active = val

var is_boss_transmission_active: bool:
	get:
		return narrative_director.is_boss_transmission_active if narrative_director else false
	set(val):
		if narrative_director:
			narrative_director.is_boss_transmission_active = val

var is_victory_dialogue_active: bool:
	get:
		return narrative_director.is_victory_dialogue_active if narrative_director else false
	set(val):
		if narrative_director:
			narrative_director.is_victory_dialogue_active = val

var is_rival_cinematic_active: bool:
	get:
		return narrative_director.is_rival_cinematic_active if narrative_director else false
	set(val):
		if narrative_director:
			narrative_director.is_rival_cinematic_active = val
var _pending_victory_data: Dictionary:
	get:
		return narrative_director.pending_victory_data if narrative_director else {}
	set(val):
		if narrative_director:
			narrative_director.pending_victory_data = val
var _on_dialogue_finished_callback: Callable = Callable()
var prologue_bonus_chosen: bool:
	get:
		return narrative_director.prologue_bonus_chosen if narrative_director else false
	set(val):
		if narrative_director:
			narrative_director.prologue_bonus_chosen = val
var run_time_elapsed: float = 0.0
var enemies_killed_count: int = 0
var _auto_save_timer: float = 0.0
var is_exiting_run: bool = false
var active_pet: CompanionPet = null
var active_navigator_controller = null
const CombatLootCoordinator = preload("res://scenes/combat/systems/combat_loot_coordinator.gd")
const CosmicRealityTearScript := preload("res://scenes/combat/bosses/cosmic_reality_tear.gd")
const BossEmergenceHelperScript := preload("res://scenes/combat/bosses/boss_emergence_helper.gd")

var loot_coordinator: CombatLootCoordinator = null
var current_slot_machine: Node2D:
	get:
		return loot_coordinator.current_slot_machine if loot_coordinator else null
var slot_machine_modal: CanvasLayer:
	get:
		return loot_coordinator.slot_machine_modal if loot_coordinator else null
var slot_machine_reward_modal: CanvasLayer:
	get:
		return loot_coordinator.slot_machine_reward_modal if loot_coordinator else null
var _wave_encounter_checked_for_wave: int = 0
var _wave_encounter_spawned_for_wave: int = 0
var _wave_encounter_timer: float = 0.0
var _wave_encounter_pending: bool = false
var _pending_rival_for_dialogue: Node2D = null
var encounter_director: EncounterDirector = null

const AUTO_SAVE_INTERVAL: float = 5.0
const SATELLITE_DESPAWN_DISTANCE: float = 10000.0

func _exit_tree() -> void:
	is_exiting_run = true
	Engine.time_scale = 1.0

func _ready() -> void:
	Engine.time_scale = SaveManager.get_game_speed()
	add_to_group("main_game")
	encounter_director = get_node_or_null("EncounterDirector") as EncounterDirector
	if not encounter_director:
		encounter_director = EncounterDirector.new()
		encounter_director.name = "EncounterDirector"
		add_child(encounter_director)
	_setup_rival_queue()
	_spawn_companion_pet()
	_spawn_navigator_controller()

	if not modal_coordinator.is_inside_tree():
		modal_coordinator.name = "CombatModalCoordinator"
		add_child(modal_coordinator)
	modal_coordinator.setup(self, player)
	modal_coordinator.level_up_modal = level_up_modal
	modal_coordinator.satellite_shop = satellite_shop
	modal_coordinator.pause_menu = pause_menu
	modal_coordinator.game_over_modal = game_over_modal
	modal_coordinator.resume_encounters_requested.connect(_resume_pending_encounters_after_modal)

	# 1. Sistema de Cofres Espaciales
	chest_director = ChestDirector.new()
	chest_director.name = "ChestDirector"
	add_child(chest_director)
	var chest_cfg = load("res://data/balance/default_chest_economy.tres") as ChestEconomyConfig
	chest_director.initialize(chest_cfg, 0)
	chest_director.chest_opened.connect(_on_chest_opened_from_director)

	var c_modal_scene: PackedScene = preload("res://scenes/ui/modals/chest_reward_modal.tscn")
	chest_reward_modal = c_modal_scene.instantiate() as ChestRewardModal
	add_child(chest_reward_modal)
	modal_coordinator.chest_reward_modal = chest_reward_modal

	# 2. Forja Cuántica (Microondas)
	var t_modal_scene: PackedScene = preload("res://scenes/ui/modals/transmutation_modal.tscn")
	transmutation_modal = t_modal_scene.instantiate() as TransmutationModal
	add_child(transmutation_modal)
	modal_coordinator.transmutation_modal = transmutation_modal

	if not narrative_director.is_inside_tree():
		narrative_director.name = "CombatNarrativeDirector"
		add_child(narrative_director)
	narrative_director.setup(self, player, hud, skip_badge_layer, audio_duck_manager)
	narrative_director.active_navigator_controller = active_navigator_controller
	narrative_director.victory_screen_requested.connect(_show_game_over_screen)

	if not boss_coordinator.is_inside_tree():
		boss_coordinator.name = "CombatBossCoordinator"
		add_child(boss_coordinator)
	boss_coordinator.setup(self)
	# Conexión del HUD con el jugador
	if hud:
		player.exp_changed.connect(hud.update_exp)
		if not player.credits_changed.is_connected(hud.update_credits):
			player.credits_changed.connect(hud.update_credits)
		if not player.biomass_changed.is_connected(hud.update_biomass):
			player.biomass_changed.connect(hud.update_biomass)
	player.level_up_requested.connect(_on_level_up_requested)
	player.bomb_used.connect(_on_player_bomb_used)
	player.health_changed.connect(_on_player_health_changed)
	player.player_died.connect(_on_player_died)
	# Conexión con EventBus
	var bus := get_node_or_null("/root/EventBus")
	if bus:
		if bus.has_signal("enemy_killed"):
			bus.enemy_killed.connect(_on_enemy_killed)
		if bus.has_signal("arcana_orb_collected"):
			bus.arcana_orb_collected.connect(_on_arcana_orb_collected)

	# Instanciar modal de selección de Arcana si no existe en el árbol
	arcana_modal = get_node_or_null("ArcanaSelectionModal") as ArcanaSelectionModal
	if not arcana_modal:
		var arc_scene := load("res://scenes/ui/arcana/arcana_selection_modal.tscn") as PackedScene
		if arc_scene:
			arcana_modal = arc_scene.instantiate() as ArcanaSelectionModal
			add_child(arcana_modal)
	if arcana_modal:
		arcana_modal.modal_closed.connect(_on_arcana_modal_closed)
		if modal_coordinator:
			modal_coordinator.arcana_modal = arcana_modal

	# Inicializar coordinador de botín (máquina tragamonedas in-run y cofres)
	loot_coordinator = CombatLootCoordinator.new()
	loot_coordinator.name = "CombatLootCoordinator"
	add_child(loot_coordinator)
	loot_coordinator.initialize(self, player, camera)

	# Inicializar sistema de eventos de crisis dinámicas y banners
	if not crisis_banner and crisis_alert_banner_scene:
		crisis_banner = crisis_alert_banner_scene.instantiate() as CanvasLayer
		add_child(crisis_banner)

	if not crisis_manager and crisis_event_manager_scene:
		crisis_manager = crisis_event_manager_scene.instantiate() as Node2D
		add_child(crisis_manager)

	if not satellite_coordinator.is_inside_tree():
		satellite_coordinator.name = "CombatSatelliteCoordinator"
		add_child(satellite_coordinator)
	satellite_coordinator.setup(self)

	_last_player_hp = player.current_health

	# Conexión de la tienda
	satellite_shop.item_purchased.connect(_on_item_purchased)
	satellite_shop.shop_closed.connect(_on_satellite_shop_closed)

	# Inicializar ancla de distancia al spawn del jugador
	last_anchor_pos = player.global_position

	# Inicializar HUD
	var debug_mgr = get_node_or_null("/root/DebugManager")
	if debug_mgr and debug_mgr.has_method("is_infinite_credits_active") and debug_mgr.is_infinite_credits_active():
		player.run_credits = 999999
	if hud:
		hud.update_credits(player.run_credits)
		hud.update_exp(player.current_exp, player.exp_to_next, player.current_level)
		hud.update_wave_status(current_wave, wave_timer, wave_satellites_spawned, MAX_SATELLITES_PER_WAVE)

	# Asegurar que MainGame y Dialogic procesen durante la pausa
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dialogic_node: Node = narrative_director.get_dialogic() if narrative_director else null
	if dialogic_node:
		dialogic_node.process_mode = Node.PROCESS_MODE_ALWAYS
		if dialogic_node.has_signal("signal_event"):
			dialogic_node.signal_event.connect(_on_dialogic_signal)
		if dialogic_node.has_signal("timeline_ended"):
			dialogic_node.timeline_ended.connect(_on_dialogic_timeline_ended)
		if dialogic_node.has_signal("timeline_started"):
			dialogic_node.timeline_started.connect(_on_dialogic_timeline_started)

	# Instanciar capa cinematográfica de fondo y efectos para diálogos
	var backdrop_scene := preload("res://scenes/ui/dialogue/dialogue_backdrop_layer.tscn")
	if backdrop_scene:
		var backdrop := backdrop_scene.instantiate()
		backdrop.name = "DialogueBackdropLayer"
		if backdrop.has_method("set_hud_reference") and hud:
			backdrop.set_hud_reference(hud)
		add_child(backdrop)

	if skip_badge_layer and skip_badge_layer.has_signal("skip_requested"):
		skip_badge_layer.skip_requested.connect(_on_dialogue_skip_requested)

	# Iniciar música de combate
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_music"):
		audio_mgr.play_music("combat")

	# Inyección dinámica de objetos espaciales y asteroides periódicos
	var asteroid_spawner := AsteroidSpawner.new()
	asteroid_spawner.name = "AsteroidSpawner"
	add_child(asteroid_spawner)

	# Inyección dinámica de macro-planetas y nidos de exploración
	var planet_spawner := PlanetSpawner.new()
	planet_spawner.name = "PlanetSpawner"
	add_child(planet_spawner)

	# Inyección dinámica de macro-objetos espaciales tácticos (Monolitos, Cápsulas, Geodas, Capullos)
	space_object_spawner = SpaceObjectSpawner.new()
	space_object_spawner.name = "SpaceObjectSpawner"
	add_child(space_object_spawner)

	# Chequeo de inicio debug directo contra un jefe específico
	var debug_boss: String = DebugManager.consume_pending_debug_boss() if (DebugManager and DebugManager.has_method("consume_pending_debug_boss")) else ""
	var auto_die: bool = DebugManager.consume_pending_auto_trigger_death() if (DebugManager and DebugManager.has_method("consume_pending_auto_trigger_death")) else false
	if debug_boss != "":
		is_briefing_active = false
		prologue_bonus_chosen = true
		PauseArbitrator.force_unpause_all()
		if skip_badge_layer:
			skip_badge_layer.hide()
		jump_to_boss(debug_boss)
		if auto_die:
			var tw := create_tween()
			tw.tween_interval(0.35)
			tw.tween_callback(func():
				if current_boss and is_instance_valid(current_boss):
					current_boss._die()
			)
		return

	# Chequeo de inicio debug directo a Wave Final (Rutas Pacifista, Genocida, Neutral)
	var debug_route: String = DebugManager.consume_pending_debug_route() if (DebugManager and DebugManager.has_method("consume_pending_debug_route")) else ""
	if debug_route != "":
		is_briefing_active = false
		prologue_bonus_chosen = true
		PauseArbitrator.force_unpause_all()
		if skip_badge_layer:
			skip_badge_layer.hide()
		jump_to_wave_16(debug_route)
		return

	# Chequeo de inicio debug directo para encuentro de Piloto Rival
	var debug_rival: bool = DebugManager.consume_pending_rival_spawn() if (DebugManager and DebugManager.has_method("consume_pending_rival_spawn")) else false
	if debug_rival:
		is_briefing_active = false
		prologue_bonus_chosen = true
		is_pre_round = false
		PauseArbitrator.force_unpause_all()
		if skip_badge_layer:
			skip_badge_layer.hide()
		get_tree().create_timer(0.5, false).timeout.connect(func() -> void:
			spawn_next_rival_pilot()
		)
		return

	# Chequeo de reanudación de partida activa (Mid-Run Resume)
	if SaveManager.is_resuming_run:
		SaveManager.is_resuming_run = false
		var active_data := SaveManager.load_active_run()
		if not active_data.is_empty():
			restore_run_state(active_data)
			return

	# Chequeo de inicio debug para test de tragamonedas (arranque sobre la máquina con abundantes créditos)
	var is_slot_test: bool = DebugManager.consume_pending_slot_machine_test() if (DebugManager and DebugManager.has_method("consume_pending_slot_machine_test")) else false
	if is_slot_test:
		is_briefing_active = false
		prologue_bonus_chosen = true
		PauseArbitrator.force_unpause_all()
		if skip_badge_layer:
			skip_badge_layer.hide()
		player.run_credits = maxi(int(player.run_credits), 25000)
		if hud:
			hud.update_credits(player.run_credits)
		_spawn_next_satellite_for_wave()
		call_deferred("_spawn_slot_machine", player.global_position + Vector2(0, -35.0))
		return

	# Chequeo de inicio debug para test de planetas (run sin enemigos, 3 planetas inmediatos)
	var is_planet_test: bool = DebugManager.consume_pending_planet_test() if (DebugManager and DebugManager.has_method("consume_pending_planet_test")) else false
	if is_planet_test:
		is_briefing_active = false
		prologue_bonus_chosen = true
		get_tree().paused = false
		if skip_badge_layer:
			skip_badge_layer.hide()
		if enemy_spawner:
			enemy_spawner.process_mode = Node.PROCESS_MODE_DISABLED
		# Ajustar estadísticas del jugador para pruebas cómodas
		if player and player.stats:
			player.stats.add_modifier(&"move_speed", CharacterStats.StatModifier.new(&"planet_test_speed", 150.0, false, self))
			player.stats.add_modifier(&"base_damage", CharacterStats.StatModifier.new(&"planet_test_damage", 50.0, false, self))
		call_deferred("_spawn_debug_test_planets")
		return

	# Generar el primer satélite de la oleada para que el radar lo indique de inmediato
	_spawn_next_satellite_for_wave()

	# Generar los primeros cofres espaciales desde el segundo 0
	if chest_director:
		var green_cards: int = player.inventory.get_item_count(&"credit_card_green") if (player and player.inventory) else 0
		chest_director.on_new_wave(current_wave, green_cards)
	_spawn_wave_chests()

	# Si es una nueva partida, iniciar secuencia de briefing con Dialogic 2
	_start_prologue_briefing()

func _setup_rival_queue() -> void:
	rival_queue.clear()
	var player_pid: StringName = player.character_data.character_id if (player and player.character_data) else &"nova"
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

func _get_genocide_escort_pilot_id() -> StringName:
	var player_pid: StringName = player.character_data.character_id if (player and player.character_data) else &"nova"
	if player_pid == &"nyx":
		var base_6: Array[StringName] = [&"nova", &"valentina", &"kira", &"selene", &"roxy", &"echo"]
		for pid in base_6:
			if not rivals_killed.has(pid):
				return pid
		return &"nova"
	return &"nyx"


func _start_prologue_briefing() -> void:
	if narrative_director:
		narrative_director.start_prologue_briefing()
	else:
		is_briefing_active = false
		get_tree().paused = false

func _setup_dialogic_audio(layout: Node) -> void:
	if narrative_director:
		narrative_director._setup_dialogic_audio(layout)

func _on_dialogic_signal(arg: Variant) -> void:
	match str(arg):
		"briefing_credits":
			prologue_bonus_chosen = true
			player.run_credits += 50
			hud.update_credits(player.run_credits)
		"briefing_speed":
			prologue_bonus_chosen = true
			player.stats.add_modifier(&"move_speed", CharacterStats.StatModifier.new(&"briefing_speed", 0.15, true, self))
		"briefing_hull":
			prologue_bonus_chosen = true
			player.stats.add_modifier(&"max_health", CharacterStats.StatModifier.new(&"briefing_hull", 25.0, false, self))
			player.current_health = player.stats.get_stat(&"max_health")
			player.health_changed.emit(player.current_health, player.stats.get_stat(&"max_health"))

func _on_dialogic_timeline_started() -> void:
	if narrative_director:
		narrative_director.on_timeline_started()

func _on_dialogue_skip_requested() -> void:
	if narrative_director:
		narrative_director.skip_dialogue()

func _on_dialogic_timeline_ended() -> void:
	if narrative_director:
		narrative_director.on_timeline_ended()

func _finish_prologue_and_start_run() -> void:
	if narrative_director:
		narrative_director._finish_prologue_and_start_run()
	else:
		is_briefing_active = false
		get_tree().paused = false

func _get_rival_dialogue(rival_pid: StringName, player_pid: StringName) -> Dictionary:
	return narrative_director.get_rival_dialogue(rival_pid, player_pid)

func _trigger_pet_rival_jump_warning(rival: Node2D, on_finished: Callable = Callable()) -> void:
	narrative_director.trigger_pet_rival_jump_warning(rival, on_finished)

func _trigger_rival_face_to_face_dialogue(rival: Node2D) -> void:
	narrative_director.trigger_rival_face_to_face_dialogue(rival)

func _trigger_pet_rival_encounter(rival: Node2D) -> void:
	narrative_director.trigger_pet_rival_encounter(rival)

func _trigger_cockpit_interlude() -> void:
	narrative_director.trigger_cockpit_interlude()

func _trigger_pet_rival_alert(pilot_name: String) -> void:
	narrative_director.trigger_pet_rival_alert(pilot_name)

func _trigger_pet_boss_alert(boss_name: String, on_finished: Callable = Callable()) -> void:
	narrative_director.trigger_pet_boss_alert(boss_name, on_finished)

func _trigger_climax_dialogue(route: String, on_finished: Callable = Callable()) -> void:
	narrative_director.trigger_climax_dialogue(route, on_finished)

func _trigger_pet_climax_alert(route: String) -> void:
	narrative_director.trigger_pet_climax_alert(route)

func _trigger_post_boss_victory_dialogue(route: String, victory_data: Dictionary) -> void:
	narrative_director.trigger_post_boss_victory_dialogue(route, victory_data)


func _process(delta: float) -> void:
	if get_tree().paused or is_cinematic_or_death_active():
		return

	if not is_any_combat_modal_active():
		if level_up_modal and level_up_modal.has_pending_levels():
			level_up_modal.show_next_level_up()
			return
		elif arcana_modal and arcana_modal.has_method("has_pending_arcanas") and arcana_modal.pending_arcanas_queue > 0:
			arcana_modal.show_next_arcana()
			return
		elif _pending_arcana_picks > 0:
			_pending_arcana_picks -= 1
			_open_next_pending_arcana()
			return
		elif _pending_satellite_credits >= 0:
			var creds: int = _pending_satellite_credits
			var idx_to_open: int = _pending_satellite_index
			_pending_satellite_credits = -1
			_pending_satellite_index = -1
			satellite_shop.open_shop(creds, idx_to_open)
			return

	# Cronómetro de tiempo total de la run
	run_time_elapsed += delta

	# Chequeo de inicio de encuentro para la oleada (ej. Oleada 1 tras pre-ronda)
	if not is_pre_round and _wave_encounter_checked_for_wave != current_wave:
		_wave_encounter_checked_for_wave = current_wave
		_wave_encounter_pending = true
		_wave_encounter_timer = 2.0

	if _wave_encounter_pending:
		_wave_encounter_timer -= delta
		if _wave_encounter_timer <= 0.0:
			_wave_encounter_pending = false
			_check_wave_encounters()

	# Chequeo de desbloqueo de Mascota Secreta Cosmo (10 Minutos = 600s de supervivencia)
	if run_time_elapsed >= 600.0 and not SaveManager.is_pet_unlocked(&"cosmo"):
		var newly_unlocked := SaveManager.unlock_pet(&"cosmo")
		if newly_unlocked and hud and hud.has_method("show_character_unlock_banner"):
			hud.show_character_unlock_banner(&"cosmo", "¡NUEVA MASCOTA DESBLOQUEADA: COSMO!", "Has sobrevivido 10 minutos. El Gatito Astral se ha unido a tu flota.")

	# Temporizador de auto-guardado periódico en segundo plano
	_auto_save_timer += delta
	if _auto_save_timer >= AUTO_SAVE_INTERVAL:
		_auto_save_timer = 0.0
		save_current_run_state()

	# Invocación continua y gradual de cofres espaciales
	if chest_director and is_instance_valid(player):
		var green_cards: int = player.inventory.get_item_count(&"credit_card_green") if player.inventory else 0
		chest_director.update_continuous_spawner(delta, player.global_position, self, green_cards)

	# Chequeo reactivo de llaves cuánticas y tarjetas verdes para HUD y descuento/recargo en cofres
	if is_instance_valid(player) and player.inventory:
		var current_keys: int = player.inventory.get_item_count(&"quantum_key")
		var current_green_cards: int = player.inventory.get_item_count(&"credit_card_green")
		if current_keys != _last_quantum_keys_count or current_green_cards != _last_green_cards_count:
			var keys_changed: bool = (current_keys != _last_quantum_keys_count)
			_last_quantum_keys_count = current_keys
			_last_green_cards_count = current_green_cards
			if keys_changed and hud and hud.has_method("update_quantum_keys"):
				hud.update_quantum_keys(current_keys)
			if chest_director:
				chest_director.refresh_all_chest_prices(current_green_cards)

	# Compactación periódica de cristales de EXP lejanos en Mega-Cristales (Optimización)
	_exp_batch_timer -= delta
	if _exp_batch_timer <= 0.0:
		_exp_batch_timer = 2.5
		if is_instance_valid(player):
			ExpBlob.batch_distant_blobs_if_needed(get_tree(), player.global_position)

	# Lógica de Pre-Ronda (Fase de Despliegue de 30s) o Temporizador de Oleada regular
	if is_pre_round:
		pre_round_timer -= delta
		if hud and is_instance_valid(hud):
			hud.update_pre_round_status(pre_round_timer)
		if pre_round_timer <= 0.0:
			is_pre_round = false
			current_wave = 1
			wave_timer = WAVE_DURATION
			wave_satellites_spawned = 0
			_wave_encounter_checked_for_wave = 0
			if enemy_spawner and enemy_spawner.has_method("set_wave"):
				enemy_spawner.set_wave(1)
			_spawn_next_satellite_for_wave()
			if chest_director:
				var green_cards: int = player.inventory.get_item_count(&"credit_card_green") if (player and player.inventory) else 0
				chest_director.on_new_wave(current_wave, green_cards)
			_spawn_wave_chests()
			save_current_run_state()
	else:
		# Congelar el temporizador de oleada si hay un combate mayor activo (Jefe de Dominio o Rival en cualquier estado)
		var is_major_combat_active: bool = _has_active_boss_or_rival()

		if not is_major_combat_active:
			wave_timer -= delta
			if wave_timer <= 0.0:
				_on_wave_completed()
				current_wave += 1
				wave_timer = WAVE_DURATION
				wave_satellites_spawned = 0
				if enemy_spawner and enemy_spawner.has_method("set_wave"):
					enemy_spawner.set_wave(current_wave)
				_wave_encounter_checked_for_wave = current_wave
				_wave_encounter_pending = true
				_wave_encounter_timer = 2.0
				save_current_run_state()
				_spawn_next_satellite_for_wave()
				if chest_director:
					var green_cards: int = player.inventory.get_item_count(&"credit_card_green") if (player and player.inventory) else 0
					chest_director.on_new_wave(current_wave, green_cards)
				_spawn_wave_chests()
				if space_object_spawner and space_object_spawner.has_method("notify_wave_started"):
					space_object_spawner.notify_wave_started(current_wave)

		if is_instance_valid(hud):
			hud.update_wave_status(current_wave, wave_timer, wave_satellites_spawned, MAX_SATELLITES_PER_WAVE)

	if satellite_coordinator:
		satellite_coordinator.update_satellite_lifecycle()

func _check_satellite_despawn() -> void:
	if satellite_coordinator:
		satellite_coordinator.check_satellite_despawn()

func _despawn_current_satellite() -> void:
	if satellite_coordinator:
		satellite_coordinator.despawn_current_satellite()

func _spawn_next_satellite_for_wave() -> void:
	if satellite_coordinator:
		satellite_coordinator.spawn_next_satellite_for_wave()

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

func _check_wave_encounters() -> void:
	if _wave_encounter_spawned_for_wave == current_wave:
		_wave_encounter_pending = false
		return
	if is_any_combat_modal_active() or has_pending_upgrades():
		_wave_encounter_pending = true
		_wave_encounter_timer = 0.5
		return
	if _has_active_boss_or_rival() or is_cinematic_or_death_active():
		_wave_encounter_pending = true
		_wave_encounter_timer = 1.0
		return

	if current_wave >= 16:
		_spawn_final_boss()
	elif current_wave in [1, 4, 7, 10, 13]:
		_spawn_rival_pilot()
	elif current_wave in [2, 5, 8, 11, 14]:
		_spawn_wave_boss()
	elif current_wave in [3, 6, 9, 12, 15]:
		_evaluate_slot_machine_spawn()

func _evaluate_slot_machine_spawn() -> void:
	if _wave_encounter_spawned_for_wave == current_wave:
		_wave_encounter_pending = false
		return
	if _has_active_boss_or_rival() or is_cinematic_or_death_active():
		_wave_encounter_pending = true
		_wave_encounter_timer = 1.0
		return
	if loot_coordinator:
		loot_coordinator.evaluate_slot_machine_spawn(true)
		_wave_encounter_spawned_for_wave = current_wave
		_wave_encounter_pending = false

func _spawn_slot_machine(spawn_pos: Vector2 = Vector2.INF) -> void:
	if loot_coordinator:
		loot_coordinator.spawn_slot_machine(spawn_pos)
		_wave_encounter_spawned_for_wave = current_wave
		_wave_encounter_pending = false

func _spawn_elite_herald() -> void:
	if boss_coordinator:
		boss_coordinator.spawn_elite_herald()

func _spawn_rival_pilot(override_id: StringName = &"") -> void:
	if boss_coordinator:
		boss_coordinator.spawn_rival_pilot(override_id)

func _on_rival_spared(p_id: StringName) -> void:
	if boss_coordinator:
		boss_coordinator.on_rival_spared(p_id)

func _on_rival_engaged(p_id: StringName) -> void:
	if boss_coordinator:
		boss_coordinator.on_rival_engaged(p_id)

func _on_rival_defeated(p_id: StringName, weapon: WeaponData) -> void:
	if boss_coordinator:
		boss_coordinator.on_rival_defeated(p_id, weapon)

func _spawn_wave_boss(target_scene_override: PackedScene = null) -> void:
	if boss_coordinator:
		boss_coordinator.spawn_wave_boss(target_scene_override)

func _spawn_final_boss(force_spawn: bool = false) -> void:
	if boss_coordinator:
		boss_coordinator.spawn_final_boss(force_spawn)

func _spawn_allied_wingmen() -> void:
	if boss_coordinator:
		boss_coordinator.spawn_allied_wingmen()

func _on_boss_defeated(boss_id: String) -> void:
	if boss_coordinator:
		boss_coordinator.on_boss_defeated(boss_id)

func _on_final_boss_defeated(route: String) -> void:
	bosses_defeated_count += 1
	current_boss = null
	if current_genocide_escort and is_instance_valid(current_genocide_escort):
		current_genocide_escort.queue_free()
		current_genocide_escort = null
	hud.hide_boss()
	is_wave_11_cleared = true

	var victory_data: Dictionary = CombatTelemetryRecorder.build_end_of_run_data(self, true, route)
	get_tree().create_timer(1.2, true, false, true).timeout.connect(func():
		_show_game_over_screen(victory_data)
	)

func jump_to_boss(boss_id: String) -> void:
	if boss_coordinator:
		boss_coordinator.jump_to_boss(boss_id)

func jump_to_wave_11(route: String = "neutral") -> void:
	if boss_coordinator:
		boss_coordinator.jump_to_wave_16(route)

func jump_to_wave_16(route: String = "neutral") -> void:
	if boss_coordinator:
		boss_coordinator.jump_to_wave_16(route)

func spawn_next_rival_pilot() -> void:
	if boss_coordinator:
		boss_coordinator.spawn_rival_pilot()

func _input(event: InputEvent) -> void:
	# Durante secuencias cinemáticas o diálogos, consumir ESC para evitar desincronizar pausa
	if is_rival_cinematic_active or is_briefing_active or is_cockpit_active or is_boss_transmission_active or is_victory_dialogue_active:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			return

	if DebugManager.is_debug_enabled() and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1:
		get_viewport().set_input_as_handled()
		_toggle_ingame_debug()
		return

	if event is InputEventKey and event.pressed and not event.echo:
		# Tecla B para invocar al jefe de la oleada
		if event.keycode == KEY_B:
			if current_boss == null:
				_spawn_wave_boss()
		# Tecla R para invocar o testear a la siguiente piloto rival
		elif event.keycode == KEY_R:
			spawn_next_rival_pilot()
		# Tecla P para saltar a la Oleada Final en Ruta Pacifista (5 perdonadas)
		elif event.keycode == KEY_P:
			jump_to_wave_16("pacifist")
		# Tecla K para saltar a la Oleada Final en Ruta Exterminadora / Slayer (5 eliminadas)
		elif event.keycode == KEY_K:
			jump_to_wave_16("slayer")
		# Tecla N para saltar a la Oleada Final en Ruta Neutral
		elif event.keycode == KEY_N:
			jump_to_wave_16("neutral")
		# Tecla T para testear transmisión
		elif event.keycode == KEY_T:
			trigger_boss_transmission("CENTINELA TITÁN", "¡Alerta de distorsión! Tus armas no perforarán nuestro núcleo planetario. Prepárate para el impacto.")

func _spawn_next_satellite(target_pos: Vector2) -> void:
	if satellite_coordinator:
		satellite_coordinator.spawn_next_satellite(target_pos)

func _on_satellite_planted(index: int, pos: Vector2) -> void:
	if satellite_coordinator:
		satellite_coordinator._on_satellite_planted(index, pos)

func _on_satellite_exited(index: int) -> void:
	if satellite_coordinator:
		satellite_coordinator._on_satellite_exited(index)

func trigger_boss_transmission(speaker: String = "CENTINELA TITÁN", _text: String = "") -> void:
	var b_name := speaker if not speaker.is_empty() else "CENTINELA TITÁN"
	_trigger_pet_boss_alert(b_name)

func _on_item_purchased(item_or_weapon: Resource, cost: int) -> void:
	var debug_mgr = get_node_or_null("/root/DebugManager")
	if debug_mgr and debug_mgr.has_method("is_infinite_credits_active") and debug_mgr.is_infinite_credits_active():
		player.run_credits = 999999
	else:
		player.run_credits -= cost
	if item_or_weapon is WeaponData:
		var w_ctrl := player.get_node_or_null("WeaponController") as WeaponController
		if w_ctrl:
			w_ctrl.add_weapon(item_or_weapon as WeaponData)
	elif item_or_weapon is ItemData:
		player.inventory.add_item(item_or_weapon as ItemData, 1, "TIENDA DE SATÉLITE")
	hud.update_credits(player.run_credits)
	save_current_run_state()

func _on_level_up_requested(level: int) -> void:
	if modal_coordinator:
		modal_coordinator.on_level_up_requested(level)

func _on_satellite_shop_closed() -> void:
	if modal_coordinator:
		modal_coordinator.on_satellite_shop_closed()

func is_pause_menu_active() -> bool:
	return modal_coordinator.is_pause_menu_active() if modal_coordinator else (pause_menu != null and pause_menu.visible)

func is_satellite_shop_active() -> bool:
	return modal_coordinator.is_satellite_shop_active() if modal_coordinator else (satellite_shop != null and satellite_shop.visible)

func is_arcana_modal_active() -> bool:
	return modal_coordinator.is_arcana_modal_active() if modal_coordinator else false

func _on_arcana_orb_collected(orb: Node2D) -> void:
	if modal_coordinator:
		modal_coordinator.on_arcana_orb_collected(orb)

func _on_arcana_modal_closed() -> void:
	if modal_coordinator:
		modal_coordinator.on_arcana_modal_closed()

func _on_level_up_modal_closed() -> void:
	if modal_coordinator:
		modal_coordinator.on_level_up_modal_closed()

func _spawn_wave_chests() -> void:
	if chest_director and is_instance_valid(player):
		var green_cards: int = player.inventory.get_item_count(&"credit_card_green") if player.inventory else 0
		chest_director.spawn_wave_chests(player.global_position, self, current_wave, green_cards)

func _on_chest_opened_from_director(_item: ItemData, _was_free: bool, _cost: int) -> void:
	save_current_run_state()

func _on_wave_completed() -> void:
	apply_chronos_bank_interest()

func apply_chronos_bank_interest() -> void:
	if not is_instance_valid(player) or not player.inventory:
		return
	if player.inventory.get_item_count(&"chronos_bank") > 0:
		var unspent: int = player.run_credits
		if unspent > 0:
			var interest: int = mini(50, int(floor(float(unspent) * 0.10)))
			if interest > 0:
				player.run_credits += interest
				if player.has_signal("credits_changed"):
					player.credits_changed.emit(player.run_credits)
				if is_instance_valid(hud) and hud.has_method("show_tactical_alert"):
					hud.show_tactical_alert("⏳ BANCO CRONOS", "+%d créditos generados" % interest, Color(1.0, 0.85, 0.2))

func on_salvage_capsule_opened(player_ref: Player = null) -> void:
	var target_player: Player = player_ref if player_ref else player
	if is_instance_valid(target_player) and target_player.inventory and target_player.inventory.get_item_count(&"heavy_salvager") > 0:
		if target_player.character_stats:
			var cur_base_hp: float = target_player.character_stats.get_base_stat(&"max_health")
			target_player.character_stats.set_base_stat(&"max_health", cur_base_hp + 2.0)
		if target_player.has_method("heal"):
			target_player.heal(2.0)
		target_player.run_credits += 3
		if target_player.has_signal("credits_changed"):
			target_player.credits_changed.emit(target_player.run_credits)
		if is_instance_valid(hud) and hud.has_method("show_tactical_alert"):
			hud.show_tactical_alert("📦 RECUPERADOR PESADO", "+2 HP Máxima • +3 créditos", Color(0.4, 1.0, 0.6))


func open_transmutation_modal(station: TransmutationStation) -> void:
	if transmutation_modal and is_instance_valid(player):
		transmutation_modal.open_for_station(player, station)

func _resume_pending_encounters_after_modal() -> void:
	if _pending_rival_for_dialogue != null and is_instance_valid(_pending_rival_for_dialogue):
		var target_rival: Node2D = _pending_rival_for_dialogue
		_pending_rival_for_dialogue = null
		get_tree().create_timer(0.5, true, false, true).timeout.connect(func() -> void:
			if is_instance_valid(target_rival) and not is_upgrade_or_shop_modal_active():
				_trigger_pet_rival_encounter(target_rival)
			elif is_instance_valid(target_rival):
				_pending_rival_for_dialogue = target_rival
		)
	elif _wave_encounter_pending:
		_wave_encounter_timer = 0.5

func is_level_up_modal_active() -> bool:
	return modal_coordinator.is_level_up_modal_active() if modal_coordinator else (level_up_modal != null and level_up_modal.visible)

func is_character_stats_active() -> bool:
	return modal_coordinator.is_character_stats_active() if modal_coordinator else false

func is_game_over_active() -> bool:
	return modal_coordinator.is_game_over_active() if modal_coordinator else false

func is_cinematic_or_death_active() -> bool:
	if CinematicDeathSequence.is_sequence_active:
		return true
	if is_rival_cinematic_active or is_briefing_active or is_cockpit_active or is_boss_transmission_active or is_victory_dialogue_active:
		return true
	if current_boss and is_instance_valid(current_boss) and current_boss.get("is_dying") == true:
		return true
	if current_rival and is_instance_valid(current_rival) and current_rival.get("is_dying") == true:
		return true
	if current_boss and is_instance_valid(current_boss) and current_boss.get("is_invulnerable") == true and current_boss.get_meta("_is_emerging", false) == true:
		return true
	return false

func is_dialogue_active() -> bool:
	if narrative_director:
		return narrative_director.is_dialogue_active()
	return false

func is_upgrade_or_shop_modal_active() -> bool:
	return modal_coordinator.is_upgrade_or_shop_modal_active() if modal_coordinator else false

func has_pending_upgrades() -> bool:
	return modal_coordinator.has_pending_upgrades() if modal_coordinator else false

func is_any_combat_modal_active() -> bool:
	if ingame_debug_modal and ingame_debug_modal.is_open:
		return true
	return modal_coordinator.is_any_combat_modal_active() if modal_coordinator else false

func notify_menu_closed(duration: float = 0.35) -> void:
	if modal_coordinator:
		modal_coordinator.notify_menu_closed(duration)
	elif is_instance_valid(player) and player.has_method("suppress_bomb_input"):
		player.suppress_bomb_input(duration)

func restore_combat_modal_focus() -> void:
	if modal_coordinator:
		modal_coordinator.restore_combat_modal_focus()

func _open_next_pending_arcana() -> void:
	if modal_coordinator:
		modal_coordinator.open_next_pending_arcana()

func _resume_pending_systems_after_cinematics() -> void:
	if modal_coordinator:
		modal_coordinator._step_next_modal()

func _on_player_bomb_used(_remaining: int) -> void:
	if camera:
		camera.add_trauma(0.6)

func _on_player_health_changed(current: float, _max_val: float) -> void:
	if current < _last_player_hp:
		if camera:
			camera.add_trauma(0.4)
	_last_player_hp = current

func _on_enemy_killed(_enemy_type: String) -> void:
	enemies_killed_count += 1

func _on_player_died() -> void:
	if level_up_modal and level_up_modal.has_method("clear_pending_levels"):
		level_up_modal.clear_pending_levels()
	if arcana_modal and arcana_modal.has_method("clear_pending_arcanas"):
		arcana_modal.clear_pending_arcanas()
	_pending_arcana_picks = 0
	_pending_satellite_credits = -1
	_pending_satellite_index = -1

	# Pausar la generación de nuevos enemigos
	if enemy_spawner and enemy_spawner.has_method("set_spawning_paused"):
		enemy_spawner.set_spawning_paused(true)

	var game_over_data: Dictionary = CombatTelemetryRecorder.build_end_of_run_data(self, false)
	get_tree().create_timer(1.0, true, false, true).timeout.connect(func():
		_show_game_over_screen(game_over_data)
	)

func _show_game_over_screen(data: Dictionary) -> void:
	if not game_over_modal:
		game_over_modal = game_over_scene.instantiate() as GameOverModal
		add_child(game_over_modal)

	if not game_over_modal.restart_requested.is_connected(_on_game_over_restart):
		game_over_modal.restart_requested.connect(_on_game_over_restart)
	if not game_over_modal.hub_requested.is_connected(_on_game_over_hub):
		game_over_modal.hub_requested.connect(_on_game_over_hub)

	PauseArbitrator.acquire_pause(&"game_over")
	game_over_modal.show_game_over(data)

func _on_game_over_restart() -> void:
	is_exiting_run = true
	SaveManager.clear_active_run()
	PauseArbitrator.force_unpause_all()
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()

func _on_game_over_hub() -> void:
	is_exiting_run = true
	SaveManager.clear_active_run()
	PauseArbitrator.force_unpause_all()
	Engine.time_scale = 1.0
	SaveManager.set_game_speed(1.0)
	get_tree().change_scene_to_file("res://scenes/ui/hub/hub_world.tscn")


# ==============================================================================
# SERIALIZACIÓN Y RESTAURACIÓN DEL ESTADO DE LA RUN
# ==============================================================================

func get_current_run_state() -> Dictionary:
	return RunStateSerializer.get_run_state(self)

func save_current_run_state() -> void:
	RunStateSerializer.save_run_state(self)

func restore_run_state(run_data: Dictionary) -> void:
	RunStateSerializer.restore_run_state(self, run_data)

func _spawn_companion_pet() -> void:
	var pet_scene: PackedScene = preload("res://scenes/combat/pets/companion_pet.tscn")
	if not pet_scene or not is_instance_valid(player):
		return
	var pet_id := SaveManager.get_selected_pet()
	const PetDataScript := preload("res://data/pets/pet_data.gd")
	var p_data = PetDataScript.get_pet(pet_id)
	active_pet = pet_scene.instantiate() as CompanionPet
	add_child(active_pet)
	active_pet.setup(p_data, player)

func _spawn_navigator_controller() -> void:
	const NavControllerScript := preload("res://scenes/combat/navigators/navigator_controller.gd")
	if not NavControllerScript or not is_instance_valid(player):
		return
	active_navigator_controller = NavControllerScript.new()
	active_navigator_controller.name = "NavigatorController"
	add_child(active_navigator_controller)
	active_navigator_controller.setup(self, player, hud)

func _spawn_debug_test_planets() -> void:
	PlanetSpawnerHelper.spawn_debug_planets(self, player)

const IngameDebugModalScript := preload("res://scenes/ui/debug/ingame_debug_modal.gd")
var ingame_debug_modal: CanvasLayer = null

func _toggle_ingame_debug() -> void:
	if not DebugManager.is_debug_enabled():
		return
	if not ingame_debug_modal:
		var scene := load("res://scenes/ui/debug/ingame_debug_modal.tscn") as PackedScene
		if scene:
			ingame_debug_modal = scene.instantiate() as CanvasLayer
			add_child(ingame_debug_modal)
			if ingame_debug_modal.has_method("setup"):
				ingame_debug_modal.setup(self)

	if ingame_debug_modal:
		if ingame_debug_modal.is_open:
			ingame_debug_modal.close()
		else:
			ingame_debug_modal.open()

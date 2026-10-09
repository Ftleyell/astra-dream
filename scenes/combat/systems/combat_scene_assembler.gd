class_name CombatSceneAssembler
extends RefCounted

## Ensamblador de escena para el orquestador raíz de combate (MainGame).
## Instancia componentes, modales tácticos, directores y configura el cableado inicial
## de señales para desacoplar el método _ready() de MainGame.

const ChestRewardModalScene: PackedScene = preload("res://scenes/ui/modals/chest_reward_modal.tscn")
const TransmutationModalScene: PackedScene = preload("res://scenes/ui/modals/transmutation_modal.tscn")
const ArcanaSelectionModalScene: PackedScene = preload("res://scenes/ui/arcana/arcana_selection_modal.tscn")
const CompanionPetScene: PackedScene = preload("res://scenes/combat/pets/companion_pet.tscn")
const NavControllerScript = preload("res://scenes/combat/navigators/navigator_controller.gd")
const PetDataScript = preload("res://data/pets/pet_data.gd")
const DialogueBackdropScene: PackedScene = preload("res://scenes/ui/dialogue/dialogue_backdrop_layer.tscn")

static func assemble(game: MainGame, player: Player, hud: GameHUD) -> void:
	if not game:
		return

	# 1. Directores y controladores base
	_setup_directors_and_controllers(game, hud)

	# 2. Companion Pet y Navigator
	_spawn_companion_pet(game, player)
	_spawn_navigator_controller(game, player, hud)

	# 3. Setup de modales y coordinadores
	_setup_modals(game, player)

	# 4. Sistema de Cofres Espaciales
	_setup_chest_director(game, player)

	# 5. Eventos de crisis y banners
	_setup_crisis_system(game)

	# 6. Conexión de señales del jugador, HUD, tienda y eventos
	_setup_signals_and_wiring(game, player, hud)

	# 7. Diálogo y cinemáticas de narrativa
	_setup_dialogue_environment(game, hud)

static func _setup_directors_and_controllers(game: MainGame, hud: GameHUD) -> void:
	if not game.encounter_director:
		var enc_dir: EncounterDirector = game.get_node_or_null("EncounterDirector") as EncounterDirector
		if not enc_dir:
			enc_dir = EncounterDirector.new()
			enc_dir.name = "EncounterDirector"
			game.add_child(enc_dir)
		game.encounter_director = enc_dir

	if not game.encounter_controller.is_inside_tree():
		game.encounter_controller.name = "CombatEncounterController"
		game.add_child(game.encounter_controller)
	game.encounter_controller.setup(game)

	if not game.input_dispatcher.is_inside_tree():
		game.input_dispatcher.name = "CombatInputDispatcher"
		game.add_child(game.input_dispatcher)
	game.input_dispatcher.setup(game)

	if game.feedback_coordinator:
		game.feedback_coordinator.setup(game, game.camera, game.end_run_controller)

	if game.space_debris_manager:
		game.space_debris_manager.setup(game)

	if not game.boss_coordinator.is_inside_tree():
		game.boss_coordinator.name = "CombatBossCoordinator"
		game.add_child(game.boss_coordinator)
	game.boss_coordinator.setup(game)

	if not game.loot_coordinator:
		game.loot_coordinator = MainGame.CombatLootCoordinator.new()
		game.loot_coordinator.name = "CombatLootCoordinator"
		game.add_child(game.loot_coordinator)
		game.loot_coordinator.initialize(game, game.player, game.camera)

	if not game.satellite_coordinator.is_inside_tree():
		game.satellite_coordinator.name = "CombatSatelliteCoordinator"
		game.add_child(game.satellite_coordinator)
	game.satellite_coordinator.setup(game)

	if not game.telemetry_coordinator.is_inside_tree():
		game.telemetry_coordinator.name = "CombatTelemetryCoordinator"
		game.add_child(game.telemetry_coordinator)
	game.telemetry_coordinator.setup(game, hud)

static func _spawn_companion_pet(game: MainGame, player: Player) -> void:
	if not CompanionPetScene or not is_instance_valid(player):
		return
	var pet_id: StringName = SaveManager.get_selected_pet()
	var p_data: PetData = PetDataScript.get_pet(pet_id)
	game.active_pet = CompanionPetScene.instantiate() as CompanionPet
	game.add_child(game.active_pet)
	game.active_pet.setup(p_data, player)

static func _spawn_navigator_controller(game: MainGame, player: Player, hud: GameHUD) -> void:
	if not NavControllerScript or not is_instance_valid(player):
		return
	game.active_navigator_controller = NavControllerScript.new()
	game.active_navigator_controller.name = "NavigatorController"
	game.add_child(game.active_navigator_controller)
	game.active_navigator_controller.setup(game, player, hud)

static func _setup_modals(game: MainGame, player: Player) -> void:
	if not game.modal_coordinator.is_inside_tree():
		game.modal_coordinator.name = "CombatModalCoordinator"
		game.add_child(game.modal_coordinator)
	game.modal_coordinator.setup(game, player)
	game.modal_coordinator.level_up_modal = game.level_up_modal
	game.modal_coordinator.satellite_shop = game.satellite_shop
	game.modal_coordinator.pause_menu = game.pause_menu
	game.modal_coordinator.game_over_modal = game.game_over_modal
	game.end_run_controller.setup(game, game.game_over_modal)

	if not game.modal_coordinator.resume_encounters_requested.is_connected(game._resume_pending_encounters_after_modal):
		game.modal_coordinator.resume_encounters_requested.connect(game._resume_pending_encounters_after_modal)

	# Modal de Cofre
	if not game.chest_reward_modal:
		game.chest_reward_modal = ChestRewardModalScene.instantiate() as ChestRewardModal
		game.add_child(game.chest_reward_modal)
	game.modal_coordinator.chest_reward_modal = game.chest_reward_modal
	if game.chest_reward_modal and not game.chest_reward_modal.modal_closed.is_connected(game.modal_coordinator.on_chest_reward_modal_closed):
		game.chest_reward_modal.modal_closed.connect(game.modal_coordinator.on_chest_reward_modal_closed)

	# Modal de Transmutación
	if not game.transmutation_modal:
		game.transmutation_modal = TransmutationModalScene.instantiate() as TransmutationModal
		game.add_child(game.transmutation_modal)
	game.modal_coordinator.transmutation_modal = game.transmutation_modal
	if game.transmutation_modal and not game.transmutation_modal.modal_closed.is_connected(game.modal_coordinator.on_transmutation_modal_closed):
		game.transmutation_modal.modal_closed.connect(game.modal_coordinator.on_transmutation_modal_closed)

	# Modal de Selección de Arcana
	var arc_modal: ArcanaSelectionModal = game.get_node_or_null("ArcanaSelectionModal") as ArcanaSelectionModal
	if not arc_modal:
		if ArcanaSelectionModalScene:
			arc_modal = ArcanaSelectionModalScene.instantiate() as ArcanaSelectionModal
			game.add_child(arc_modal)
	game.arcana_modal = arc_modal
	if game.arcana_modal:
		if not game.arcana_modal.modal_closed.is_connected(game._on_arcana_modal_closed):
			game.arcana_modal.modal_closed.connect(game._on_arcana_modal_closed)
		game.modal_coordinator.arcana_modal = game.arcana_modal


static func _setup_chest_director(game: MainGame, player: Player) -> void:
	game.chest_director = ChestDirector.new()
	game.chest_director.name = "ChestDirector"
	game.add_child(game.chest_director)
	var chest_cfg: ChestEconomyConfig = load("res://data/balance/default_chest_economy.tres") as ChestEconomyConfig
	game.chest_director.initialize(chest_cfg, 0)
	game.chest_director.chest_opened.connect(game._on_chest_opened_from_director)

	var sel_char_id: StringName = SaveManager.get_selected_character()
	var banned_items: Array[StringName] = SaveManager.get_character_banlist(sel_char_id)
	var unlocked_items: Array[StringName] = SaveManager.get_unlocked_items()
	var char_data: CharacterData = player.character_data if is_instance_valid(player) else null
	if game.chest_director and game.chest_director.item_pool_manager:
		game.chest_director.item_pool_manager.rebuild_run_pool(char_data, unlocked_items, banned_items)

static func _setup_crisis_system(game: MainGame) -> void:
	if not game.crisis_banner and game.crisis_alert_banner_scene:
		game.crisis_banner = game.crisis_alert_banner_scene.instantiate() as CanvasLayer
		game.add_child(game.crisis_banner)

	if not game.crisis_manager and game.crisis_event_manager_scene:
		game.crisis_manager = game.crisis_event_manager_scene.instantiate() as Node2D
		game.add_child(game.crisis_manager)

static func _setup_signals_and_wiring(game: MainGame, player: Player, hud: GameHUD) -> void:
	if not is_instance_valid(player):
		return

	# Conexión del HUD con el jugador
	if hud:
		if not player.exp_changed.is_connected(hud.update_exp):
			player.exp_changed.connect(hud.update_exp)
		if not player.credits_changed.is_connected(hud.update_credits):
			player.credits_changed.connect(hud.update_credits)
		if not player.biomass_changed.is_connected(hud.update_biomass):
			player.biomass_changed.connect(hud.update_biomass)
		if player.character_data and hud.has_method("update_pilot_abilities"):
			hud.update_pilot_abilities(player.character_data)

	if not player.level_up_requested.is_connected(game._on_level_up_requested):
		player.level_up_requested.connect(game._on_level_up_requested)
	if not player.bomb_used.is_connected(game._on_player_bomb_used):
		player.bomb_used.connect(game._on_player_bomb_used)
	if not player.health_changed.is_connected(game._on_player_health_changed):
		player.health_changed.connect(game._on_player_health_changed)
	if not player.player_died.is_connected(game._on_player_died):
		player.player_died.connect(game._on_player_died)

	# Conexión con EventBus
	var bus: Node = game.get_node_or_null("/root/EventBus")
	if bus:
		if bus.has_signal("enemy_killed") and not bus.enemy_killed.is_connected(game._on_enemy_killed):
			bus.enemy_killed.connect(game._on_enemy_killed)
		if bus.has_signal("arcana_orb_collected") and not bus.arcana_orb_collected.is_connected(game._on_arcana_orb_collected):
			bus.arcana_orb_collected.connect(game._on_arcana_orb_collected)

	# Conexión de la tienda
	if game.satellite_shop:
		if not game.satellite_shop.item_purchased.is_connected(game._on_item_purchased):
			game.satellite_shop.item_purchased.connect(game._on_item_purchased)
		if not game.satellite_shop.shop_closed.is_connected(game._on_satellite_shop_closed):
			game.satellite_shop.shop_closed.connect(game._on_satellite_shop_closed)

	# Conexión de skip badges
	if game.skip_badge_layer and game.skip_badge_layer.has_signal("skip_requested"):
		if not game.skip_badge_layer.skip_requested.is_connected(game._on_dialogue_skip_requested):
			game.skip_badge_layer.skip_requested.connect(game._on_dialogue_skip_requested)

static func _setup_dialogue_environment(game: MainGame, hud: GameHUD) -> void:
	if not game.narrative_director.is_inside_tree():
		game.narrative_director.name = "CombatNarrativeDirector"
		game.add_child(game.narrative_director)
	game.narrative_director.setup(game, game.player, hud, game.skip_badge_layer, game.audio_duck_manager)
	game.narrative_director.active_navigator_controller = game.active_navigator_controller
	if not game.narrative_director.victory_screen_requested.is_connected(game._show_game_over_screen):
		game.narrative_director.victory_screen_requested.connect(game._show_game_over_screen)

	var dialogic_node: Node = game.narrative_director.get_dialogic() if game.narrative_director else null
	if dialogic_node:
		dialogic_node.process_mode = Node.PROCESS_MODE_ALWAYS
		if dialogic_node.has_signal("signal_event") and not dialogic_node.signal_event.is_connected(game._on_dialogic_signal):
			dialogic_node.signal_event.connect(game._on_dialogic_signal)
		if dialogic_node.has_signal("timeline_ended") and not dialogic_node.timeline_ended.is_connected(game._on_dialogic_timeline_ended):
			dialogic_node.timeline_ended.connect(game._on_dialogic_timeline_ended)
		if dialogic_node.has_signal("timeline_started") and not dialogic_node.timeline_started.is_connected(game._on_dialogic_timeline_started):
			dialogic_node.timeline_started.connect(game._on_dialogic_timeline_started)

	if DialogueBackdropScene:
		var backdrop: Node = DialogueBackdropScene.instantiate()
		backdrop.name = "DialogueBackdropLayer"
		if backdrop.has_method("set_hud_reference") and hud:
			backdrop.set_hud_reference(hud)
		game.add_child(backdrop)

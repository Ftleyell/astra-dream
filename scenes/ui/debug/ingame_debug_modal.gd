class_name IngameDebugModal
extends CanvasLayer

## IngameDebugModal.gd
## Modal de depuración in-game para Astra Dream activable con la tecla F1.
## Diseñado para pausar el juego completamente (PROCESS_MODE_ALWAYS) y permitir:
## [1] Spawns y Entidades (Monolitos directos a ~200px, Jefes con toggle de cinemática, Rivales, Tragaperras, Limpieza).
## [2] Cheats y Stats (God Mode, Créditos, Bombas, Multiplicadores de velocidad, Sliders en tiempo real).
## [3] Arsenal e Items (Inyección de armas, upgrades de nivel, selector de pactos de arcana).
## [4] Oleadas y Crisis (Saltos de oleada, disparo de Tormenta Solar y eventos de crisis).
##
## Desacoplable totalmente en producción mediante DebugManager.is_debug_enabled().

signal modal_closed()

@onready var dim_overlay: ColorRect = get_node_or_null("DimOverlay") as ColorRect
@onready var main_panel: PanelContainer = get_node_or_null("CenterContainer/MainPanel") as PanelContainer

# Tab buttons
@onready var tab_spawns_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/TabBarRow/TabSpawnsBtn") as Button
@onready var tab_cheats_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/TabBarRow/TabCheatsBtn") as Button
@onready var tab_arsenal_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/TabBarRow/TabArsenalBtn") as Button
@onready var tab_waves_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/TabBarRow/TabWavesBtn") as Button

# Tab contents
@onready var spawns_content: VBoxContainer = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/SpawnsContent") as VBoxContainer
@onready var cheats_content: VBoxContainer = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/CheatsContent") as VBoxContainer
@onready var arsenal_content: VBoxContainer = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/ArsenalContent") as VBoxContainer
@onready var waves_content: VBoxContainer = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/WavesContent") as VBoxContainer

# Spawns controls
@onready var spawn_monolith_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/SpawnsContent/MonolithRow/SpawnMonolithBtn") as Button
@onready var boss_select_option: OptionButton = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/SpawnsContent/BossRow/BossOption") as OptionButton
@onready var boss_intro_check: CheckBox = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/SpawnsContent/BossRow/BossIntroCheck") as CheckBox
@onready var spawn_boss_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/SpawnsContent/BossRow/SpawnBossBtn") as Button

@onready var rival_select_option: OptionButton = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/SpawnsContent/RivalRow/RivalOption") as OptionButton
@onready var rival_intro_check: CheckBox = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/SpawnsContent/RivalRow/RivalIntroCheck") as CheckBox
@onready var spawn_rival_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/SpawnsContent/RivalRow/SpawnRivalBtn") as Button

@onready var spawn_satellite_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/SpawnsContent/LootRow/SpawnSatelliteBtn") as Button
@onready var spawn_transmutation_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/SpawnsContent/LootRow/SpawnTransmutationBtn") as Button
@onready var spawn_slot_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/SpawnsContent/LootRow/SpawnSlotBtn") as Button
@onready var spawn_chest_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/SpawnsContent/LootRow/SpawnChestBtn") as Button
@onready var clear_bullets_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/SpawnsContent/ClearRow/ClearBulletsBtn") as Button
@onready var kill_enemies_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/SpawnsContent/ClearRow/KillEnemiesBtn") as Button
@onready var feedback_label: Label = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/FeedbackLabel") as Label

# Cheats controls
@onready var god_mode_check: CheckBox = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/CheatsContent/CheatsGrid/GodModeCheck") as CheckBox
@onready var inf_credits_check: CheckBox = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/CheatsContent/CheatsGrid/InfCreditsCheck") as CheckBox
@onready var inf_bombs_check: CheckBox = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/CheatsContent/CheatsGrid/InfBombsCheck") as CheckBox
@onready var restore_hp_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/CheatsContent/CheatsGrid/RestoreHpBtn") as Button
@onready var add_bombs_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/CheatsContent/CheatsGrid/AddBombsBtn") as Button
@onready var speed_1x_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/CheatsContent/SpeedRow/Speed1xBtn") as Button
@onready var speed_2x_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/CheatsContent/SpeedRow/Speed2xBtn") as Button
@onready var speed_3x_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/CheatsContent/SpeedRow/Speed3xBtn") as Button
@onready var stats_scroll_list: VBoxContainer = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/CheatsContent/StatsScroll/StatsList") as VBoxContainer

# Arsenal controls
@onready var weapons_grid: GridContainer = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/ArsenalContent/WeaponsGrid") as GridContainer
@onready var upgrade_all_weps_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/ArsenalContent/WeaponActions/UpgradeAllWepsBtn") as Button
@onready var max_all_weps_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/ArsenalContent/WeaponActions/MaxAllWepsBtn") as Button
@onready var open_arcana_modal_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/ArsenalContent/ArcanaActions/OpenArcanaModalBtn") as Button

# Waves controls
@onready var wave_btns_container: HBoxContainer = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/WavesContent/WaveJumpRow") as HBoxContainer
@onready var add_30s_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/WavesContent/TimeRow/Add30sBtn") as Button
@onready var finish_wave_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/WavesContent/TimeRow/FinishWaveBtn") as Button
@onready var crisis_solar_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/WavesContent/CrisisRow/CrisisSolarBtn") as Button
@onready var crisis_flock_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/WavesContent/CrisisRow/CrisisFlockBtn") as Button
@onready var crisis_mitosis_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/WavesContent/CrisisRow/CrisisMitosisBtn") as Button
@onready var crisis_contain_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/WavesContent/CrisisRow/CrisisContainBtn") as Button
@onready var crisis_stop_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/WavesContent/CrisisRow/CrisisStopBtn") as Button

# Bottom actions
@onready var resume_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/BottomRow/ResumeBtn") as Button

var main_game: Node2D = null
var is_open: bool = false
var active_tab_index: int = 0
var _stat_sliders: Dictionary = {}

const AVAILABLE_WEAPONS: Array[Dictionary] = [
	{ "id": &"rail_launcher", "name": "Rail Launcher (Vanguard)", "path": "res://data/weapons/roster/rail_launcher.tres" },
	{ "id": &"crescent_blade", "name": "Crescent Blade", "path": "res://data/weapons/roster/crescent_blade.tres" },
	{ "id": &"hive_cannon", "name": "Hive Cannon", "path": "res://data/weapons/roster/hive_cannon.tres" },
	{ "id": &"singularity_pulsar", "name": "Singularity Pulsar", "path": "res://data/weapons/roster/singularity_pulsar.tres" },
	{ "id": &"sniper_rifle", "name": "Sniper Rifle", "path": "res://data/weapons/roster/sniper_rifle.tres" },
	{ "id": &"tesla_arc", "name": "Tesla Arc", "path": "res://data/weapons/roster/tesla_arc.tres" },
	{ "id": &"titan_shotgun", "name": "Titan Shotgun", "path": "res://data/weapons/roster/titan_shotgun.tres" },
	{ "id": &"cluster_submunition", "name": "Cluster Submunition", "path": "res://data/weapons/shop/cluster_submunition.tres" },
	{ "id": &"dimensional_blade", "name": "Dimensional Blade", "path": "res://data/weapons/shop/dimensional_blade.tres" },
	{ "id": &"nova_flak", "name": "Nova Flak", "path": "res://data/weapons/shop/nova_flak.tres" },
	{ "id": &"solar_beam", "name": "Solar Beam", "path": "res://data/weapons/shop/solar_beam.tres" }
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 125
	hide()
	_setup_tab_buttons()
	_setup_spawns_tab()
	_setup_cheats_tab()
	_setup_arsenal_tab()
	_setup_waves_tab()
	if resume_btn:
		resume_btn.pressed.connect(close)
		UIFocusHelper.apply_cyber_focus(resume_btn)


func setup(game: Node2D) -> void:
	main_game = game


func open() -> void:
	if not DebugManager.is_debug_enabled():
		return
	is_open = true
	get_tree().paused = true
	show()
	_sync_toggles_with_state()
	_populate_stats_sliders()
	_switch_tab(active_tab_index)
	_set_feedback("Menú de depuración F1 abierto. Partida en pausa.")


func close() -> void:
	if not is_open:
		return
	is_open = false
	hide()
	if not _should_remain_paused():
		get_tree().paused = false
	modal_closed.emit()

func _should_remain_paused() -> bool:
	if not main_game or not is_instance_valid(main_game):
		return false
	if main_game.has_method("is_any_combat_modal_active") and main_game.is_any_combat_modal_active():
		return true
	if main_game.has_method("is_dialogue_active") and main_game.is_dialogue_active():
		return true
	if main_game.has_method("is_cinematic_or_death_active") and main_game.is_cinematic_or_death_active():
		return true
	if main_game.has_method("is_pause_menu_active") and main_game.is_pause_menu_active():
		return true
	return false

func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1 or event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			close()


func _setup_tab_buttons() -> void:
	if tab_spawns_btn:
		tab_spawns_btn.pressed.connect(func(): _switch_tab(0))
		UIFocusHelper.apply_cyber_focus(tab_spawns_btn)
	if tab_cheats_btn:
		tab_cheats_btn.pressed.connect(func(): _switch_tab(1))
		UIFocusHelper.apply_cyber_focus(tab_cheats_btn)
	if tab_arsenal_btn:
		tab_arsenal_btn.pressed.connect(func(): _switch_tab(2))
		UIFocusHelper.apply_cyber_focus(tab_arsenal_btn)
	if tab_waves_btn:
		tab_waves_btn.pressed.connect(func(): _switch_tab(3))
		UIFocusHelper.apply_cyber_focus(tab_waves_btn)


func _switch_tab(index: int) -> void:
	active_tab_index = index
	if spawns_content: spawns_content.visible = (index == 0)
	if cheats_content: cheats_content.visible = (index == 1)
	if arsenal_content: arsenal_content.visible = (index == 2)
	if waves_content: waves_content.visible = (index == 3)

	var tab_btns: Array[Button] = [tab_spawns_btn, tab_cheats_btn, tab_arsenal_btn, tab_waves_btn]
	for i in range(tab_btns.size()):
		var b := tab_btns[i]
		if b:
			b.modulate = Color(1.3, 1.3, 1.3) if i == index else Color(0.65, 0.65, 0.65)


func _set_feedback(msg: String) -> void:
	if feedback_label:
		feedback_label.text = ">> " + msg


# ─── PESTAÑA 1: SPAWNS & ENTIDADES ────────────────────────────────────────────

func _setup_spawns_tab() -> void:
	if spawn_monolith_btn:
		spawn_monolith_btn.pressed.connect(_on_spawn_monolith_pressed)
		UIFocusHelper.apply_cyber_focus(spawn_monolith_btn)

	IngameDebugLayoutBuilder.populate_boss_options(boss_select_option)

	if spawn_boss_btn:
		spawn_boss_btn.pressed.connect(_on_spawn_boss_pressed)
		UIFocusHelper.apply_cyber_focus(spawn_boss_btn)

	IngameDebugLayoutBuilder.populate_rival_options(rival_select_option)

	if spawn_rival_btn:
		spawn_rival_btn.pressed.connect(_on_spawn_rival_pressed)
		UIFocusHelper.apply_cyber_focus(spawn_rival_btn)

	if spawn_satellite_btn:
		spawn_satellite_btn.pressed.connect(_on_spawn_satellite_pressed)
		UIFocusHelper.apply_cyber_focus(spawn_satellite_btn)

	if spawn_transmutation_btn:
		spawn_transmutation_btn.pressed.connect(_on_spawn_transmutation_pressed)
		UIFocusHelper.apply_cyber_focus(spawn_transmutation_btn)

	if spawn_slot_btn:
		spawn_slot_btn.pressed.connect(_on_spawn_slot_pressed)
		UIFocusHelper.apply_cyber_focus(spawn_slot_btn)

	if spawn_chest_btn:
		spawn_chest_btn.pressed.connect(_on_spawn_chest_pressed)
		UIFocusHelper.apply_cyber_focus(spawn_chest_btn)

	if clear_bullets_btn:
		clear_bullets_btn.pressed.connect(_on_clear_bullets_pressed)
		UIFocusHelper.apply_cyber_focus(clear_bullets_btn)

	if kill_enemies_btn:
		kill_enemies_btn.pressed.connect(_on_kill_enemies_pressed)
		UIFocusHelper.apply_cyber_focus(kill_enemies_btn)


func _on_spawn_monolith_pressed() -> void:
	_set_feedback(IngameDebugActionExecutor.spawn_monolith(main_game))
	close()

func _on_spawn_boss_pressed() -> void:
	var selected_idx: int = boss_select_option.selected if boss_select_option else 0
	var boss_id: String = String(boss_select_option.get_item_metadata(selected_idx)) if boss_select_option else "boss_hermit_void"
	var play_intro: bool = boss_intro_check.button_pressed if boss_intro_check else true
	_set_feedback(IngameDebugActionExecutor.spawn_boss(main_game, boss_id, play_intro))
	close()

func _on_spawn_rival_pressed() -> void:
	var selected_idx: int = rival_select_option.selected if rival_select_option else 0
	var r_id_str: String = String(rival_select_option.get_item_metadata(selected_idx)) if rival_select_option else ""
	_set_feedback(IngameDebugActionExecutor.spawn_rival(main_game, r_id_str))
	close()

func _on_spawn_satellite_pressed() -> void:
	_set_feedback(IngameDebugActionExecutor.spawn_satellite(main_game))
	close()

func _on_spawn_transmutation_pressed() -> void:
	_set_feedback(IngameDebugActionExecutor.spawn_transmutation(main_game))
	close()

func _on_spawn_slot_pressed() -> void:
	_set_feedback(IngameDebugActionExecutor.spawn_slot_machine(main_game))
	close()

func _on_spawn_chest_pressed() -> void:
	_set_feedback(IngameDebugActionExecutor.spawn_chest(main_game))
	close()

func _on_clear_bullets_pressed() -> void:
	_set_feedback(IngameDebugActionExecutor.clear_all_bullets(get_tree()))

func _on_kill_enemies_pressed() -> void:
	_set_feedback(IngameDebugActionExecutor.kill_common_enemies(get_tree()))


# ─── PESTAÑA 2: CHEATS & STATS ────────────────────────────────────────────────

func _setup_cheats_tab() -> void:
	if god_mode_check:
		god_mode_check.toggled.connect(func(val: bool):
			DebugManager.infinite_hp = val
			DebugManager.is_enabled = true
			if val and main_game and is_instance_valid(main_game.get("player")):
				var p: Player = main_game.player
				p.current_health = p.stats.get_stat(&"max_health") if p.stats else 100.0
				p.health_changed.emit(p.current_health, p.stats.get_stat(&"max_health") if p.stats else 100.0)
			_set_feedback("God Mode: " + ("ACTIVO" if val else "INACTIVO"))
		)
		UIFocusHelper.apply_cyber_focus(god_mode_check)

	if inf_credits_check:
		inf_credits_check.toggled.connect(func(val: bool):
			DebugManager.infinite_credits = val
			DebugManager.is_enabled = true
			if val and main_game and is_instance_valid(main_game.get("player")):
				var p: Player = main_game.player
				p.run_credits = 999999
				p.credits_changed.emit(p.run_credits)
			_set_feedback("Créditos Infinitos: " + ("ACTIVO" if val else "INACTIVO"))
		)
		UIFocusHelper.apply_cyber_focus(inf_credits_check)

	if inf_bombs_check:
		inf_bombs_check.toggled.connect(func(val: bool):
			DebugManager.infinite_consumables = val
			DebugManager.is_enabled = true
			if val and main_game and is_instance_valid(main_game.get("player")):
				var p: Player = main_game.player
				p.bomb_count = 5
				p.bomb_used.emit(p.bomb_count)
			_set_feedback("Bombas Máximas Infinitas: " + ("ACTIVO" if val else "INACTIVO"))
		)
		UIFocusHelper.apply_cyber_focus(inf_bombs_check)

	if restore_hp_btn:
		restore_hp_btn.pressed.connect(func():
			if main_game and is_instance_valid(main_game.get("player")):
				var p: Player = main_game.player
				var max_h: float = p.stats.get_stat(&"max_health") if p.stats else 100.0
				p.current_health = max_h
				p.health_changed.emit(p.current_health, max_h)
				_set_feedback("Salud del jugador restaurada al 100%.")
		)
		UIFocusHelper.apply_cyber_focus(restore_hp_btn)

	if add_bombs_btn:
		add_bombs_btn.pressed.connect(func():
			if main_game and is_instance_valid(main_game.get("player")):
				var p: Player = main_game.player
				p.bomb_count = mini(5, p.bomb_count + 3)
				p.bomb_used.emit(p.bomb_count)
				_set_feedback("Añadidas +3 bombas tácticas.")
		)
		UIFocusHelper.apply_cyber_focus(add_bombs_btn)

	if speed_1x_btn:
		speed_1x_btn.pressed.connect(func(): Engine.time_scale = 1.0; _set_feedback("Velocidad de simulación: 1.0x"))
		UIFocusHelper.apply_cyber_focus(speed_1x_btn)
	if speed_2x_btn:
		speed_2x_btn.pressed.connect(func(): Engine.time_scale = 2.0; _set_feedback("Velocidad de simulación: 2.0x"))
		UIFocusHelper.apply_cyber_focus(speed_2x_btn)
	if speed_3x_btn:
		speed_3x_btn.pressed.connect(func(): Engine.time_scale = 3.0; _set_feedback("Velocidad de simulación: 3.0x"))
		UIFocusHelper.apply_cyber_focus(speed_3x_btn)


func _sync_toggles_with_state() -> void:
	if god_mode_check: god_mode_check.set_pressed_no_signal(DebugManager.infinite_hp)
	if inf_credits_check: inf_credits_check.set_pressed_no_signal(DebugManager.infinite_credits)
	if inf_bombs_check: inf_bombs_check.set_pressed_no_signal(DebugManager.infinite_consumables)


func _populate_stats_sliders() -> void:
	IngameDebugLayoutBuilder.populate_stats_sliders(
		stats_scroll_list,
		_stat_sliders,
		DebugManager.STAT_CONFIGS,
		_on_stat_slider_changed
	)


func _on_stat_slider_changed(current_stat: StringName, new_val: float) -> void:
	DebugManager.set_stat_override(current_stat, new_val)
	if main_game and is_instance_valid(main_game.get("player")):
		var p: Player = main_game.player
		if p.stats:
			p.stats._base_stats[current_stat] = new_val
			p.stats._is_dirty[current_stat] = true
			if current_stat == &"max_health":
				p.current_health = new_val
				p.health_changed.emit(p.current_health, new_val)


# ─── PESTAÑA 3: ARSENAL & ITEMS ───────────────────────────────────────────────

func _setup_arsenal_tab() -> void:
	IngameDebugLayoutBuilder.populate_weapon_buttons(
		weapons_grid,
		AVAILABLE_WEAPONS,
		_inject_weapon
	)

	if upgrade_all_weps_btn:
		upgrade_all_weps_btn.pressed.connect(_on_upgrade_all_weapons_pressed)
		UIFocusHelper.apply_cyber_focus(upgrade_all_weps_btn)

	if max_all_weps_btn:
		max_all_weps_btn.pressed.connect(_on_max_all_weapons_pressed)
		UIFocusHelper.apply_cyber_focus(max_all_weps_btn)

	if open_arcana_modal_btn:
		open_arcana_modal_btn.pressed.connect(_on_open_arcana_modal_pressed)
		UIFocusHelper.apply_cyber_focus(open_arcana_modal_btn)


func _inject_weapon(res_path: String, w_name: String) -> void:
	_set_feedback(IngameDebugActionExecutor.inject_weapon(main_game, res_path, w_name))

func _on_upgrade_all_weapons_pressed() -> void:
	_set_feedback(IngameDebugActionExecutor.upgrade_all_weapons(main_game))

func _on_max_all_weapons_pressed() -> void:
	_set_feedback(IngameDebugActionExecutor.max_all_weapons(main_game))

func _on_open_arcana_modal_pressed() -> void:
	if not main_game or not is_instance_valid(main_game.get("arcana_modal")):
		_set_feedback("Modal de Arcana no inicializado en la partida.")
		return
	close()
	var arc_modal = main_game.arcana_modal
	if arc_modal.has_method("open_modal"):
		arc_modal.open_modal(main_game.player)
	elif arc_modal.has_method("show_arcana_selection"):
		arc_modal.show_arcana_selection(main_game.player)


# ─── PESTAÑA 4: OLEADAS & CRISIS ──────────────────────────────────────────────

func _setup_waves_tab() -> void:
	var milestone_waves: Array[int] = [1, 3, 5, 8, 11, 14, 16, 20]
	IngameDebugLayoutBuilder.populate_wave_jump_buttons(
		wave_btns_container,
		milestone_waves,
		_jump_to_wave
	)

	if add_30s_btn:
		add_30s_btn.pressed.connect(func():
			if main_game:
				main_game.set("wave_timer", float(main_game.get("wave_timer")) + 30.0)
				_set_feedback("+30 segundos añadidos a la oleada actual.")
		)
		UIFocusHelper.apply_cyber_focus(add_30s_btn)

	if finish_wave_btn:
		finish_wave_btn.pressed.connect(func():
			if main_game:
				main_game.set("wave_timer", 0.1)
				_set_feedback("Tiempo de oleada forzado a 0.1s. Avanzando de fase.")
				close()
		)
		UIFocusHelper.apply_cyber_focus(finish_wave_btn)

	if crisis_solar_btn:
		crisis_solar_btn.pressed.connect(func(): _trigger_crisis("solar_storm"))
		UIFocusHelper.apply_cyber_focus(crisis_solar_btn)
	if crisis_flock_btn:
		crisis_flock_btn.pressed.connect(func(): _trigger_crisis("flock_rush"))
		UIFocusHelper.apply_cyber_focus(crisis_flock_btn)
	if crisis_mitosis_btn:
		crisis_mitosis_btn.pressed.connect(func(): _trigger_crisis("mitosis_invasion"))
		UIFocusHelper.apply_cyber_focus(crisis_mitosis_btn)
	if crisis_contain_btn:
		crisis_contain_btn.pressed.connect(func(): _trigger_crisis("containment_arena"))
		UIFocusHelper.apply_cyber_focus(crisis_contain_btn)
	if crisis_stop_btn:
		crisis_stop_btn.pressed.connect(_stop_crisis)
		UIFocusHelper.apply_cyber_focus(crisis_stop_btn)


func _jump_to_wave(target_wave: int) -> void:
	_set_feedback(IngameDebugActionExecutor.jump_to_wave(main_game, get_tree(), target_wave))
	close()


func _trigger_crisis(crisis_id: String) -> void:
	if not main_game or not is_instance_valid(main_game.get("crisis_manager")):
		_set_feedback("Error: CrisisEventManager no encontrado.")
		return
	var c_mgr = main_game.crisis_manager
	if c_mgr.has_method("trigger_crisis"):
		c_mgr.trigger_crisis(crisis_id)
		_set_feedback("Evento de Crisis disparado: " + crisis_id)
	close()


func _stop_crisis() -> void:
	if not main_game or not is_instance_valid(main_game.get("crisis_manager")):
		return
	var c_mgr = main_game.crisis_manager
	if c_mgr.has_method("dismiss_for_boss_encounter"):
		c_mgr.dismiss_for_boss_encounter()
		_set_feedback("Crisis activa finalizada forzosamente.")

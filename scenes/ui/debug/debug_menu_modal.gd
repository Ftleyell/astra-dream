class_name DebugMenuModal
extends CanvasLayer

## Modal de Depuración y Trampas para el Menú de Despliegue y Combate.
## Ahora con 2 Pestañas: [1] Combate & Stats | [2] Gacha & Cosméticos.
## Totalmente navegable con WASD y flechas.

const CosmeticsManager = preload("res://core/systems/cosmetics_manager.gd")
const GachaModalScript = preload("res://scenes/ui/gacha/gacha_modal.gd")
const SlotBeaconScript = preload("res://scenes/combat/satellite/slot_machine_beacon.gd")
const SlotChestScript = preload("res://scenes/combat/satellite/slot_machine_chest.gd")

signal closed()

@onready var modal_panel: PanelContainer = get_node_or_null("CenterContainer/MainPanel")
@onready var subtitle_label: Label = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/TitleBox/SubtitleLabel")

# Tabs
@onready var tab_combat_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/TabBarRow/TabCombatButton")
@onready var tab_bosses_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/TabBarRow/TabBossesButton")
@onready var tab_gacha_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/TabBarRow/TabGachaButton")
@onready var combat_content: VBoxContainer = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/CombatTabContent")
@onready var bosses_content: VBoxContainer = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/BossesTabContent")
@onready var gacha_content: VBoxContainer = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/GachaTabContent")

# Bosses Tab Controls
@onready var test_hermit_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/BossesTabContent/BossesGrid/TestHermitBtn")
@onready var test_ash_clock_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/BossesTabContent/BossesGrid/TestAshClockBtn")
@onready var test_broken_mirror_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/BossesTabContent/BossesGrid/TestBrokenMirrorBtn")
@onready var test_overflow_vortex_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/BossesTabContent/BossesGrid/TestOverflowVortexBtn")
@onready var test_mothership_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/BossesTabContent/BossesGrid/TestMothershipBtn")
@onready var test_astra_prime_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/BossesTabContent/BossesGrid/TestAstraPrimeBtn")
@onready var test_death_seq_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/BossesTabContent/TestDeathSequenceBtn")

# Combat Tab Controls
@onready var infinite_hp_check: CheckBox = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/CombatTabContent/CheatsBox/HpCheck")
@onready var infinite_credits_check: CheckBox = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/CombatTabContent/CheatsBox/CreditsCheck")
@onready var infinite_consumables_check: CheckBox = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/CombatTabContent/CheatsBox/ConsumablesCheck")
@onready var stats_container: VBoxContainer = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/CombatTabContent/StatsScroll/StatsList")

@onready var reset_career_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/CombatTabContent/CareerDebugRow/ResetCareerButton")
@onready var set_bosses_9_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/CombatTabContent/CareerDebugRow/SetBosses9Button")
@onready var simulate_10m_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/CombatTabContent/PetsDebugRow/Simulate10mButton")
@onready var lock_cosmo_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/CombatTabContent/PetsDebugRow/LockCosmoButton")
@onready var unlock_iris_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/CombatTabContent/NavigatorsDebugRow/UnlockIrisButton")
@onready var lock_iris_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/CombatTabContent/NavigatorsDebugRow/LockIrisButton")
@onready var jump_pacifist_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/CombatTabContent/NarrativeDebugRow/JumpPacifistButton")
@onready var jump_slayer_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/CombatTabContent/NarrativeDebugRow/JumpSlayerButton")
@onready var jump_neutral_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/CombatTabContent/NarrativeDebugRow/JumpNeutralButton")
@onready var spawn_rival_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/CombatTabContent/NarrativeDebugRow/SpawnRivalButton")
@onready var test_planets_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/CombatTabContent/PlanetDebugRow/TestPlanetsButton")

# Gacha Tab Controls
@onready var tokens_label: Label = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/GachaTabContent/GachaStatsPanel/GachaStatsHBox/TokensLabel")
@onready var biomass_label: Label = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/GachaTabContent/GachaStatsPanel/GachaStatsHBox/BiomassLabel")
@onready var skins_unlocked_label: Label = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/GachaTabContent/GachaStatsPanel/GachaStatsHBox/SkinsUnlockedLabel")

@onready var add_tokens_10_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/GachaTabContent/TokensRow/AddTokens10Btn")
@onready var add_tokens_50_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/GachaTabContent/TokensRow/AddTokens50Btn")
@onready var reset_tokens_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/GachaTabContent/TokensRow/ResetTokensBtn")

@onready var add_biomass_500_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/GachaTabContent/BiomassRow/AddBiomass500Btn")
@onready var add_biomass_2000_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/GachaTabContent/BiomassRow/AddBiomass2000Btn")
@onready var reset_biomass_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/GachaTabContent/BiomassRow/ResetBiomassBtn")

@onready var unlock_all_1star_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/GachaTabContent/SkinsRow/UnlockAll1StarBtn")
@onready var unlock_all_3star_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/GachaTabContent/SkinsRow/UnlockAll3StarBtn")
@onready var lock_all_skins_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/GachaTabContent/SkinsRow/LockAllSkinsBtn")

@onready var test_pull_1_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/GachaTabContent/SimulationRow/TestPull1Btn")
@onready var test_pull_5_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/GachaTabContent/SimulationRow/TestPull5Btn")
@onready var test_pull_10_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/GachaTabContent/SimulationRow/TestPull10Btn")
@onready var open_gacha_modal_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/GachaTabContent/SimulationRow/OpenGachaModalBtn")

@onready var spawn_slot_machine_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/GachaTabContent/InRunSlotsRow/SpawnSlotMachineBtn")
@onready var spawn_slot_chest_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/GachaTabContent/InRunSlotsRow/SpawnSlotChestBtn")

# Bottom Actions
@onready var reset_button: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/ActionsRow/ResetButton")
@onready var close_button: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/ActionsRow/CloseButton")

var current_pilot_data: CharacterData = null
var _stat_controls: Dictionary = {}
var is_open: bool = false
var active_tab_idx: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 120
	hide()

	# Tab Buttons
	if tab_combat_btn:
		tab_combat_btn.pressed.connect(func(): _switch_tab(0))
		UIFocusHelper.apply_cyber_focus(tab_combat_btn)
	if tab_bosses_btn:
		tab_bosses_btn.pressed.connect(func(): _switch_tab(1))
		UIFocusHelper.apply_cyber_focus(tab_bosses_btn)
	if tab_gacha_btn:
		tab_gacha_btn.pressed.connect(func(): _switch_tab(2))
		UIFocusHelper.apply_cyber_focus(tab_gacha_btn)

	# Bosses Tab Connects
	if test_hermit_btn:
		test_hermit_btn.pressed.connect(func(): _on_boss_test_pressed("boss_hermit_void"))
		UIFocusHelper.apply_cyber_focus(test_hermit_btn)
	if test_ash_clock_btn:
		test_ash_clock_btn.pressed.connect(func(): _on_boss_test_pressed("boss_ash_clock"))
		UIFocusHelper.apply_cyber_focus(test_ash_clock_btn)
	if test_broken_mirror_btn:
		test_broken_mirror_btn.pressed.connect(func(): _on_boss_test_pressed("boss_broken_mirror"))
		UIFocusHelper.apply_cyber_focus(test_broken_mirror_btn)
	if test_overflow_vortex_btn:
		test_overflow_vortex_btn.pressed.connect(func(): _on_boss_test_pressed("boss_overflow_vortex"))
		UIFocusHelper.apply_cyber_focus(test_overflow_vortex_btn)
	if test_mothership_btn:
		test_mothership_btn.pressed.connect(func(): _on_boss_test_pressed("boss_mothership"))
		UIFocusHelper.apply_cyber_focus(test_mothership_btn)
	if test_astra_prime_btn:
		test_astra_prime_btn.pressed.connect(func(): _on_boss_test_pressed("boss_astra_prime"))
		UIFocusHelper.apply_cyber_focus(test_astra_prime_btn)
	if test_death_seq_btn:
		test_death_seq_btn.pressed.connect(_on_test_death_sequence_pressed)
		UIFocusHelper.apply_cyber_focus(test_death_seq_btn)

	# Combat Tab Connects
	if infinite_hp_check:
		infinite_hp_check.toggled.connect(_on_infinite_hp_toggled)
		UIFocusHelper.apply_cyber_focus(infinite_hp_check)

	if infinite_credits_check:
		infinite_credits_check.toggled.connect(_on_infinite_credits_toggled)
		UIFocusHelper.apply_cyber_focus(infinite_credits_check)

	if infinite_consumables_check:
		infinite_consumables_check.toggled.connect(_on_infinite_consumables_toggled)
		UIFocusHelper.apply_cyber_focus(infinite_consumables_check)

	if reset_career_btn:
		reset_career_btn.pressed.connect(_on_reset_career_pressed)
		UIFocusHelper.apply_cyber_focus(reset_career_btn)

	if set_bosses_9_btn:
		set_bosses_9_btn.pressed.connect(_on_set_bosses_9_pressed)
		UIFocusHelper.apply_cyber_focus(set_bosses_9_btn)

	if simulate_10m_btn:
		simulate_10m_btn.pressed.connect(_on_simulate_10m_pressed)
		UIFocusHelper.apply_cyber_focus(simulate_10m_btn)

	if lock_cosmo_btn:
		lock_cosmo_btn.pressed.connect(_on_lock_cosmo_pressed)
		UIFocusHelper.apply_cyber_focus(lock_cosmo_btn)

	if unlock_iris_btn:
		unlock_iris_btn.pressed.connect(_on_unlock_iris_pressed)
		UIFocusHelper.apply_cyber_focus(unlock_iris_btn)

	if lock_iris_btn:
		lock_iris_btn.pressed.connect(_on_lock_iris_pressed)
		UIFocusHelper.apply_cyber_focus(lock_iris_btn)

	if jump_pacifist_btn:
		jump_pacifist_btn.pressed.connect(_on_jump_pacifist_pressed)
		UIFocusHelper.apply_cyber_focus(jump_pacifist_btn)

	if jump_slayer_btn:
		jump_slayer_btn.pressed.connect(_on_jump_slayer_pressed)
		UIFocusHelper.apply_cyber_focus(jump_slayer_btn)

	if jump_neutral_btn:
		jump_neutral_btn.pressed.connect(_on_jump_neutral_pressed)
		UIFocusHelper.apply_cyber_focus(jump_neutral_btn)

	if spawn_rival_btn:
		spawn_rival_btn.pressed.connect(_on_spawn_rival_pressed)
		UIFocusHelper.apply_cyber_focus(spawn_rival_btn)

	if test_planets_btn:
		test_planets_btn.pressed.connect(_on_test_planets_pressed)
		UIFocusHelper.apply_cyber_focus(test_planets_btn)

	# Gacha Tab Connects
	if add_tokens_10_btn:
		add_tokens_10_btn.pressed.connect(_on_add_tokens_10_pressed)
		UIFocusHelper.apply_cyber_focus(add_tokens_10_btn)

	if add_tokens_50_btn:
		add_tokens_50_btn.pressed.connect(_on_add_tokens_50_pressed)
		UIFocusHelper.apply_cyber_focus(add_tokens_50_btn)

	if reset_tokens_btn:
		reset_tokens_btn.pressed.connect(_on_reset_tokens_pressed)
		UIFocusHelper.apply_cyber_focus(reset_tokens_btn)

	if add_biomass_500_btn:
		add_biomass_500_btn.pressed.connect(_on_add_biomass_500_pressed)
		UIFocusHelper.apply_cyber_focus(add_biomass_500_btn)

	if add_biomass_2000_btn:
		add_biomass_2000_btn.pressed.connect(_on_add_biomass_2000_pressed)
		UIFocusHelper.apply_cyber_focus(add_biomass_2000_btn)

	if reset_biomass_btn:
		reset_biomass_btn.pressed.connect(_on_reset_biomass_pressed)
		UIFocusHelper.apply_cyber_focus(reset_biomass_btn)

	if unlock_all_1star_btn:
		unlock_all_1star_btn.pressed.connect(_on_unlock_all_1star_pressed)
		UIFocusHelper.apply_cyber_focus(unlock_all_1star_btn)

	if unlock_all_3star_btn:
		unlock_all_3star_btn.pressed.connect(_on_unlock_all_3star_pressed)
		UIFocusHelper.apply_cyber_focus(unlock_all_3star_btn)

	if lock_all_skins_btn:
		lock_all_skins_btn.pressed.connect(_on_lock_all_skins_pressed)
		UIFocusHelper.apply_cyber_focus(lock_all_skins_btn)

	if test_pull_1_btn:
		test_pull_1_btn.pressed.connect(func(): _simulate_direct_pulls(1))
		UIFocusHelper.apply_cyber_focus(test_pull_1_btn)

	if test_pull_5_btn:
		test_pull_5_btn.pressed.connect(func(): _simulate_direct_pulls(5))
		UIFocusHelper.apply_cyber_focus(test_pull_5_btn)

	if test_pull_10_btn:
		test_pull_10_btn.pressed.connect(func(): _simulate_direct_pulls(10))
		UIFocusHelper.apply_cyber_focus(test_pull_10_btn)

	if open_gacha_modal_btn:
		open_gacha_modal_btn.pressed.connect(_on_open_gacha_modal_pressed)
		UIFocusHelper.apply_cyber_focus(open_gacha_modal_btn)

	if spawn_slot_machine_btn:
		spawn_slot_machine_btn.text = "🎰 INICIAR RUN SOBRE TRAGAMONEDAS (+25.000 COINS)"
		spawn_slot_machine_btn.pressed.connect(_on_spawn_slot_machine_pressed)
		UIFocusHelper.apply_cyber_focus(spawn_slot_machine_btn)

	if spawn_slot_chest_btn:
		spawn_slot_chest_btn.pressed.connect(_on_spawn_slot_chest_pressed)
		UIFocusHelper.apply_cyber_focus(spawn_slot_chest_btn)

	# Bottom Actions
	if reset_button:
		reset_button.pressed.connect(reset_to_defaults)
		UIFocusHelper.apply_cyber_focus(reset_button)

	if close_button:
		close_button.pressed.connect(close_menu)
		UIFocusHelper.apply_cyber_focus(close_button)

	_build_stats_ui()
	_setup_focus_chain()
	_switch_tab(0)

func _switch_tab(tab_idx: int) -> void:
	active_tab_idx = tab_idx
	if tab_idx == 0:
		if combat_content:
			combat_content.show()
		if bosses_content:
			bosses_content.hide()
		if gacha_content:
			gacha_content.hide()
		if tab_combat_btn:
			tab_combat_btn.modulate = Color(0.2, 1.0, 0.85, 1.0)
		if tab_bosses_btn:
			tab_bosses_btn.modulate = Color(0.6, 0.6, 0.6, 1.0)
		if tab_gacha_btn:
			tab_gacha_btn.modulate = Color(0.6, 0.6, 0.6, 1.0)
		if subtitle_label:
			subtitle_label.text = "PESTAÑA 1: PARÁMETROS, TRAMPAS Y ESTADÍSTICAS DE COMBATE"
			subtitle_label.add_theme_color_override("font_color", Color(0.65, 0.85, 1.0, 0.8))
	elif tab_idx == 1:
		if combat_content:
			combat_content.hide()
		if bosses_content:
			bosses_content.show()
		if gacha_content:
			gacha_content.hide()
		if tab_combat_btn:
			tab_combat_btn.modulate = Color(0.6, 0.6, 0.6, 1.0)
		if tab_bosses_btn:
			tab_bosses_btn.modulate = Color(1.0, 0.35, 0.65, 1.0)
		if tab_gacha_btn:
			tab_gacha_btn.modulate = Color(0.6, 0.6, 0.6, 1.0)
		if subtitle_label:
			subtitle_label.text = "PESTAÑA 2: TESTEO DIRECTO 1v1 CONTRA JEFES DE DOMINIO Y SOBERANO ESTELAR"
			subtitle_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.75, 1.0))
	else:
		if combat_content:
			combat_content.hide()
		if bosses_content:
			bosses_content.hide()
		if gacha_content:
			gacha_content.show()
		if tab_combat_btn:
			tab_combat_btn.modulate = Color(0.6, 0.6, 0.6, 1.0)
		if tab_bosses_btn:
			tab_bosses_btn.modulate = Color(0.6, 0.6, 0.6, 1.0)
		if tab_gacha_btn:
			tab_gacha_btn.modulate = Color(1.0, 0.85, 0.2, 1.0)
		_refresh_gacha_display()
		if subtitle_label:
			subtitle_label.text = "PESTAÑA 3: GACHA, FICHAS, POLVO ESTELAR Y PROGRESIÓN DE SKINS 3★"
			subtitle_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.3, 1.0))

func _refresh_gacha_display() -> void:
	var tokens: int = SaveManager.get_gacha_tokens()
	var bio: int = SaveManager.get_biomass()
	var unlocked_skins: Dictionary = SaveManager.get_unlocked_skins()
	var total_skins: Dictionary = CosmeticsManager.get_all_skins()

	if tokens_label:
		tokens_label.text = "🎟️ FICHAS GACHA: %d" % tokens
	if biomass_label:
		biomass_label.text = "✨ POLVO ESTELAR: %d" % bio
	if skins_unlocked_label:
		skins_unlocked_label.text = "🎨 SKINS: %d / %d" % [unlocked_skins.size(), total_skins.size()]

func open_menu(pilot_data: CharacterData = null) -> void:
	current_pilot_data = pilot_data
	is_open = true
	show()

	if infinite_hp_check:
		infinite_hp_check.set_pressed_no_signal(DebugManager.infinite_hp)
	if infinite_credits_check:
		infinite_credits_check.set_pressed_no_signal(DebugManager.infinite_credits)
	if infinite_consumables_check:
		infinite_consumables_check.set_pressed_no_signal(DebugManager.infinite_consumables)

	_refresh_stats_display()
	_refresh_gacha_display()

	if active_tab_idx == 0 and tab_combat_btn:
		tab_combat_btn.grab_focus()
	elif active_tab_idx == 1 and tab_gacha_btn:
		tab_gacha_btn.grab_focus()

func close_menu() -> void:
	if not is_open:
		return
	is_open = false
	hide()
	closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		var vp := get_viewport()
		if vp:
			vp.set_input_as_handled()
		close_menu()
		return
	var vp := get_viewport()
	if vp:
		vp.set_input_as_handled()

func _build_stats_ui() -> void:
	if not stats_container:
		return

	for child in stats_container.get_children():
		child.queue_free()
	_stat_controls.clear()

	for stat_name in DebugManager.STAT_CONFIGS.keys():
		var cfg: Dictionary = DebugManager.STAT_CONFIGS[stat_name]
		var row := HBoxContainer.new()
		row.name = "Row_" + String(stat_name)
		row.custom_minimum_size = Vector2(0, 36)
		row.add_theme_constant_override("separation", 16)

		# 1. Etiqueta con nombre
		var lbl := Label.new()
		lbl.text = cfg.name
		lbl.custom_minimum_size = Vector2(240, 32)
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0, 0.95))
		row.add_child(lbl)

		# 2. Slider horizontal
		var slider := HSlider.new()
		slider.custom_minimum_size = Vector2(360, 32)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.min_value = cfg.min
		slider.max_value = cfg.max
		slider.step = cfg.step
		slider.value = cfg.default
		UIFocusHelper.apply_cyber_focus(slider)
		row.add_child(slider)

		# 3. Input numérico LineEdit
		var line_edit := LineEdit.new()
		line_edit.custom_minimum_size = Vector2(120, 32)
		line_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
		line_edit.text = cfg.format % cfg.default
		UIFocusHelper.apply_cyber_focus(line_edit)
		row.add_child(line_edit)

		slider.value_changed.connect(func(val: float):
			line_edit.text = cfg.format % val
			DebugManager.set_stat_override(stat_name, val)
		)

		line_edit.text_submitted.connect(func(txt: String):
			_commit_input_value(stat_name, line_edit, slider, cfg)
		)

		line_edit.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventKey and ev.pressed and not ev.echo:
				if ev.keycode == KEY_SPACE or ev.keycode == KEY_ENTER or ev.keycode == KEY_KP_ENTER:
					_commit_input_value(stat_name, line_edit, slider, cfg)
					var vp := get_viewport()
					if vp:
						vp.set_input_as_handled()
		)

		stats_container.add_child(row)
		_stat_controls[stat_name] = {
			"slider": slider,
			"input": line_edit,
			"config": cfg
		}

func _commit_input_value(stat_name: StringName, line_edit: LineEdit, slider: HSlider, cfg: Dictionary) -> void:
	var val := line_edit.text.to_float()
	val = clampf(val, cfg.min, cfg.max)
	slider.value = val
	line_edit.text = cfg.format % val
	DebugManager.set_stat_override(stat_name, val)
	line_edit.release_focus()
	slider.grab_focus()

func _refresh_stats_display() -> void:
	for stat_name in _stat_controls.keys():
		var ctrl: Dictionary = _stat_controls[stat_name]
		var cfg: Dictionary = ctrl["config"]
		var slider: HSlider = ctrl["slider"]
		var line_edit: LineEdit = ctrl["input"]
		var default_val: float = float(cfg.get("default", 0.0))
		var current_val: float = DebugManager.get_stat_override(stat_name, default_val)

		slider.set_value_no_signal(current_val)
		line_edit.text = cfg.format % current_val

func _setup_focus_chain() -> void:
	if tab_combat_btn and tab_bosses_btn and tab_gacha_btn:
		tab_combat_btn.focus_neighbor_right = tab_bosses_btn.get_path()
		tab_bosses_btn.focus_neighbor_left = tab_combat_btn.get_path()
		tab_bosses_btn.focus_neighbor_right = tab_gacha_btn.get_path()
		tab_gacha_btn.focus_neighbor_left = tab_bosses_btn.get_path()
		if infinite_hp_check:
			tab_combat_btn.focus_neighbor_bottom = infinite_hp_check.get_path()
			tab_bosses_btn.focus_neighbor_bottom = test_hermit_btn.get_path() if test_hermit_btn else infinite_hp_check.get_path()
			tab_gacha_btn.focus_neighbor_bottom = infinite_hp_check.get_path()

	if test_hermit_btn and test_ash_clock_btn and test_broken_mirror_btn and test_overflow_vortex_btn and test_mothership_btn and test_astra_prime_btn:
		test_hermit_btn.focus_neighbor_top = tab_bosses_btn.get_path()
		test_ash_clock_btn.focus_neighbor_top = tab_bosses_btn.get_path()
		test_hermit_btn.focus_neighbor_right = test_ash_clock_btn.get_path()
		test_ash_clock_btn.focus_neighbor_left = test_hermit_btn.get_path()
		test_hermit_btn.focus_neighbor_bottom = test_broken_mirror_btn.get_path()
		test_ash_clock_btn.focus_neighbor_bottom = test_overflow_vortex_btn.get_path()

		test_broken_mirror_btn.focus_neighbor_top = test_hermit_btn.get_path()
		test_overflow_vortex_btn.focus_neighbor_top = test_ash_clock_btn.get_path()
		test_broken_mirror_btn.focus_neighbor_right = test_overflow_vortex_btn.get_path()
		test_overflow_vortex_btn.focus_neighbor_left = test_broken_mirror_btn.get_path()
		test_broken_mirror_btn.focus_neighbor_bottom = test_mothership_btn.get_path()
		test_overflow_vortex_btn.focus_neighbor_bottom = test_astra_prime_btn.get_path()

		test_mothership_btn.focus_neighbor_top = test_broken_mirror_btn.get_path()
		test_astra_prime_btn.focus_neighbor_top = test_overflow_vortex_btn.get_path()
		test_mothership_btn.focus_neighbor_right = test_astra_prime_btn.get_path()
		test_astra_prime_btn.focus_neighbor_left = test_mothership_btn.get_path()
		test_mothership_btn.focus_neighbor_bottom = close_button.get_path() if close_button else reset_button.get_path()
		test_astra_prime_btn.focus_neighbor_bottom = close_button.get_path() if close_button else reset_button.get_path()

	var stat_keys := DebugManager.STAT_CONFIGS.keys()
	if stat_keys.is_empty() or _stat_controls.is_empty():
		return

	var first_stat: StringName = stat_keys[0]
	var last_stat: StringName = stat_keys[-1]
	var first_ctrl: Dictionary = _stat_controls[first_stat]
	var last_ctrl: Dictionary = _stat_controls[last_stat]

	if infinite_hp_check:
		infinite_hp_check.focus_neighbor_top = tab_combat_btn.get_path() if tab_combat_btn else close_button.get_path()
		infinite_hp_check.focus_neighbor_bottom = first_ctrl.slider.get_path()
	if infinite_credits_check:
		infinite_credits_check.focus_neighbor_top = tab_combat_btn.get_path() if tab_combat_btn else close_button.get_path()
		infinite_credits_check.focus_neighbor_bottom = first_ctrl.slider.get_path()
	if infinite_consumables_check:
		infinite_consumables_check.focus_neighbor_top = tab_gacha_btn.get_path() if tab_gacha_btn else close_button.get_path()
		infinite_consumables_check.focus_neighbor_bottom = first_ctrl.input.get_path()

	for i in range(stat_keys.size()):
		var s_name: StringName = stat_keys[i]
		var ctrl: Dictionary = _stat_controls[s_name]
		var slider: HSlider = ctrl.slider
		var input: LineEdit = ctrl.input

		slider.focus_neighbor_right = input.get_path()
		input.focus_neighbor_left = slider.get_path()

		if i > 0:
			var prev_ctrl: Dictionary = _stat_controls[stat_keys[i - 1]]
			slider.focus_neighbor_top = prev_ctrl.slider.get_path()
			input.focus_neighbor_top = prev_ctrl.input.get_path()
		else:
			slider.focus_neighbor_top = infinite_hp_check.get_path()
			input.focus_neighbor_top = infinite_consumables_check.get_path()

		if i < stat_keys.size() - 1:
			var next_ctrl: Dictionary = _stat_controls[stat_keys[i + 1]]
			slider.focus_neighbor_bottom = next_ctrl.slider.get_path()
			input.focus_neighbor_bottom = next_ctrl.input.get_path()
		else:
			slider.focus_neighbor_bottom = reset_career_btn.get_path() if reset_career_btn else reset_button.get_path()
			input.focus_neighbor_bottom = set_bosses_9_btn.get_path() if set_bosses_9_btn else close_button.get_path()

# ── GACHA TAB ACTIONS ────────────────────────────────────────────────────────
func _on_add_tokens_10_pressed() -> void:
	SaveManager.add_gacha_tokens(10)
	_play_click_sfx()
	_refresh_gacha_display()
	if subtitle_label:
		subtitle_label.text = "✓ +10 FICHAS DE GACHA AÑADIDAS (TOTAL: %d)" % SaveManager.get_gacha_tokens()
		subtitle_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0))

func _on_add_tokens_50_pressed() -> void:
	SaveManager.add_gacha_tokens(50)
	_play_click_sfx()
	_refresh_gacha_display()
	if subtitle_label:
		subtitle_label.text = "✓ +50 FICHAS DE GACHA AÑADIDAS (TOTAL: %d)" % SaveManager.get_gacha_tokens()
		subtitle_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0))

func _on_reset_tokens_pressed() -> void:
	SaveManager.set_gacha_tokens(0)
	_play_click_sfx()
	_refresh_gacha_display()
	if subtitle_label:
		subtitle_label.text = "↺ FICHAS DE GACHA RESTABLECIDAS A 0"
		subtitle_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5, 1.0))

func _on_add_biomass_500_pressed() -> void:
	SaveManager.add_biomass(500)
	_play_click_sfx()
	_refresh_gacha_display()
	if subtitle_label:
		subtitle_label.text = "✓ +500 POLVO ESTELAR / BIOMASA SUMADOS (TOTAL: %d)" % SaveManager.get_biomass()
		subtitle_label.add_theme_color_override("font_color", Color(0.8, 0.4, 1.0, 1.0))

func _on_add_biomass_2000_pressed() -> void:
	SaveManager.add_biomass(2000)
	_play_click_sfx()
	_refresh_gacha_display()
	if subtitle_label:
		subtitle_label.text = "✓ +2000 POLVO ESTELAR / BIOMASA SUMADOS (TOTAL: %d)" % SaveManager.get_biomass()
		subtitle_label.add_theme_color_override("font_color", Color(0.8, 0.4, 1.0, 1.0))

func _on_reset_biomass_pressed() -> void:
	SaveManager.set_biomass(0)
	_play_click_sfx()
	_refresh_gacha_display()
	if subtitle_label:
		subtitle_label.text = "↺ POLVO ESTELAR / BIOMASA RESTABLECIDO A 0"
		subtitle_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5, 1.0))

func _on_unlock_all_1star_pressed() -> void:
	var count := SaveManager.unlock_all_skins(1)
	_play_click_sfx()
	_refresh_gacha_display()
	if subtitle_label:
		subtitle_label.text = "✓ ¡%d SKINS DESBLOQUEADAS AL NIVEL BASE 1★!" % count
		subtitle_label.add_theme_color_override("font_color", Color(0.2, 0.95, 1.0, 1.0))

func _on_unlock_all_3star_pressed() -> void:
	var count := SaveManager.unlock_all_skins(3)
	_play_click_sfx()
	_refresh_gacha_display()
	if subtitle_label:
		subtitle_label.text = "✓ ¡%d SKINS MEJORADAS AL MÁXIMO (3★ CON SHADER GLOW Y AURA)!" % count
		subtitle_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0))

func _on_lock_all_skins_pressed() -> void:
	SaveManager.lock_all_skins()
	_play_click_sfx()
	_refresh_gacha_display()
	if subtitle_label:
		subtitle_label.text = "↺ TODAS LAS SKINS BLOQUEADAS Y EQUIPAMIENTO REINICIADO"
		subtitle_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45, 1.0))

func _simulate_direct_pulls(count: int) -> void:
	var results_text: Array[String] = []
	for i in range(count):
		var raw_skin := CosmeticsManager.roll_random_skin()
		if raw_skin.is_empty():
			continue
		var sid: String = raw_skin.get("id", "")
		var upg := SaveManager.unlock_or_upgrade_skin(sid)
		var status_str := "NUEVA 1★" if upg.status == "new" else ("SUBE A %d★" % upg.new_stars if upg.status == "upgraded" else "+150 POLVO")
		results_text.append("%s [%s]" % [raw_skin.get("skin_name", sid), status_str])

	_play_click_sfx()
	_refresh_gacha_display()
	if subtitle_label:
		subtitle_label.text = "🎲 %d TIRADAS: %s" % [count, " | ".join(results_text.slice(0, 3))]
		subtitle_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.6, 1.0))

func _on_open_gacha_modal_pressed() -> void:
	_play_click_sfx()
	close_menu()
	var hub_world = get_tree().get_first_node_in_group("hub_world")
	if hub_world and "gacha_modal" in hub_world and hub_world.gacha_modal:
		hub_world.gacha_modal.open_gacha_modal()
	else:
		var modal := GachaModalScript.new()
		get_tree().root.add_child(modal)
		modal.open_gacha_modal()

func _on_spawn_slot_machine_pressed() -> void:
	_play_click_sfx()
	var mg = get_tree().get_first_node_in_group("main_game")
	if mg and is_instance_valid(mg) and "player" in mg and is_instance_valid(mg.player):
		mg.player.run_credits = maxi(int(mg.player.run_credits) + 25000, 25000)
		if "hud" in mg and mg.hud:
			mg.hud.update_credits(mg.player.run_credits)
		if "current_slot_machine" in mg and is_instance_valid(mg.current_slot_machine):
			mg.current_slot_machine.queue_free()
			mg.current_slot_machine = null
		if mg.has_method("_spawn_slot_machine"):
			mg._spawn_slot_machine(mg.player.global_position + Vector2(0, -35.0))
		close_menu()
		if subtitle_label:
			subtitle_label.text = "✓ MÁQUINA TRAGAMONEDAS SPAWNEADA SOBRE EL JUGADOR (+25.000 COINS)!"
			subtitle_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0))
	else:
		var debug_mgr = get_node_or_null("/root/DebugManager")
		if debug_mgr and debug_mgr.has_method("set_pending_slot_machine_test"):
			debug_mgr.set_pending_slot_machine_test(true)
		close_menu()
		get_tree().paused = false
		if not (get_tree().current_scene and "Test" in get_tree().current_scene.name):
			get_tree().change_scene_to_file("res://scenes/combat/main_game.tscn")

func _on_spawn_slot_chest_pressed() -> void:
	_play_click_sfx()
	close_menu()
	var mg = get_tree().get_first_node_in_group("main_game")
	if mg and "player" in mg and mg.player:
		var chest = SlotChestScript.new()
		chest.global_position = mg.player.global_position + Vector2(100, 0)
		chest.chest_opened.connect(mg._on_slot_machine_chest_opened)
		mg.add_child(chest)

func _play_click_sfx() -> void:
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("ui_click", 0.8, 1.0)

# ── COMBAT TAB ACTIONS ───────────────────────────────────────────────────────
func _on_simulate_10m_pressed() -> void:
	var cur_scene = get_tree().current_scene
	if cur_scene and "run_time_elapsed" in cur_scene:
		cur_scene.run_time_elapsed = 599.0
	else:
		SaveManager.unlock_pet(&"cosmo")
	_play_click_sfx()
	if subtitle_label:
		subtitle_label.text = "✓ 10 MINUTOS SIMULADOS. ¡PET SECRETO COSMO DESBLOQUEADO!"
		subtitle_label.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0, 1.0))

func _on_lock_cosmo_pressed() -> void:
	SaveManager.lock_pet(&"cosmo")
	_play_click_sfx()
	if subtitle_label:
		subtitle_label.text = "✓ PET COSMO BLOQUEADO (REQUERIRÁ SOBREVIVIR 10 MIN EN COMBATE)."
		subtitle_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.4, 1.0))

func _on_unlock_iris_pressed() -> void:
	SaveManager.unlock_navigator(&"iris")
	_play_click_sfx()
	if subtitle_label:
		subtitle_label.text = "✓ ¡NAVEGANTE SECRETA IRIS DESBLOQUEADA!"
		subtitle_label.add_theme_color_override("font_color", Color(0.9, 0.75, 1.0, 1.0))

func _on_lock_iris_pressed() -> void:
	SaveManager.lock_navigator(&"iris")
	_play_click_sfx()
	if subtitle_label:
		subtitle_label.text = "✓ NAVEGANTE IRIS BLOQUEADA (REQUIERE COMPLETAR UN FINAL)."
		subtitle_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.4, 1.0))

func _on_reset_career_pressed() -> void:
	SaveManager.reset_career_stats()
	_play_click_sfx()
	if subtitle_label:
		subtitle_label.text = "✓ DATOS DE CARRERA REINICIADOS. NYX BLOQUEADA (0 JEFES MATADOS)."
		subtitle_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.55, 1.0))

func _on_set_bosses_9_pressed() -> void:
	SaveManager.set_career_bosses_killed(9)
	_play_click_sfx()
	if subtitle_label:
		subtitle_label.text = "✓ JEFES MATADOS FIJADOS A 9. ¡EL PRÓXIMO JEFE DERROTADO DESBLOQUEARÁ A NYX!"
		subtitle_label.add_theme_color_override("font_color", Color(0.9, 0.45, 1.0, 1.0))

func reset_to_defaults() -> void:
	DebugManager.stat_overrides.clear()
	_refresh_stats_display()
	_play_click_sfx()

func _on_infinite_hp_toggled(toggled_on: bool) -> void:
	DebugManager.infinite_hp = toggled_on
	if toggled_on:
		DebugManager.is_enabled = true

func _on_infinite_credits_toggled(toggled_on: bool) -> void:
	DebugManager.infinite_credits = toggled_on
	if toggled_on:
		DebugManager.is_enabled = true

func _on_infinite_consumables_toggled(toggled_on: bool) -> void:
	DebugManager.infinite_consumables = toggled_on
	if toggled_on:
		DebugManager.is_enabled = true

func _on_jump_pacifist_pressed() -> void:
	_trigger_route_jump("pacifist")

func _on_jump_slayer_pressed() -> void:
	_trigger_route_jump("slayer")

func _on_jump_neutral_pressed() -> void:
	_trigger_route_jump("neutral")

func _trigger_route_jump(route: String) -> void:
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("ui_click", 0.0, 1.8)

	var mg = get_tree().get_first_node_in_group("main_game")
	if mg and mg.has_method("jump_to_wave_11"):
		mg.jump_to_wave_11(route)
		close_menu()
	else:
		DebugManager.set_pending_debug_route(route)
		close_menu()
		get_tree().paused = false
		if not (get_tree().current_scene and "Test" in get_tree().current_scene.name):
			get_tree().change_scene_to_file("res://scenes/combat/main_game.tscn")

func _on_spawn_rival_pressed() -> void:
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("ui_click", 0.0, 1.8)

	var mg = get_tree().get_first_node_in_group("main_game")
	if mg and mg.has_method("spawn_next_rival_pilot"):
		mg.spawn_next_rival_pilot()
		close_menu()
	else:
		close_menu()
		get_tree().paused = false
		if not (get_tree().current_scene and "Test" in get_tree().current_scene.name):
			get_tree().change_scene_to_file("res://scenes/combat/main_game.tscn")

func _on_test_planets_pressed() -> void:
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("ui_click", 0.0, 1.8)

	DebugManager.set_pending_planet_test(true)
	close_menu()
	get_tree().paused = false
	if not (get_tree().current_scene and "Test" in get_tree().current_scene.name):
		get_tree().change_scene_to_file("res://scenes/combat/main_game.tscn")

func _on_boss_test_pressed(boss_id: String) -> void:
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("ui_click", 0.0, 1.8)

	var mg = get_tree().get_first_node_in_group("main_game")
	if mg and mg.has_method("jump_to_boss"):
		mg.jump_to_boss(boss_id)
		close_menu()
	else:
		if current_pilot_data and "character_id" in current_pilot_data:
			SaveManager.set_selected_character(current_pilot_data.character_id)
		DebugManager.set_pending_debug_boss(boss_id)
		close_menu()
		get_tree().paused = false
		if not (get_tree().current_scene and "Test" in get_tree().current_scene.name):
			get_tree().change_scene_to_file("res://scenes/combat/main_game.tscn")

func _on_test_death_sequence_pressed() -> void:
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("ui_click", 0.0, 1.8)

	var mg = get_tree().get_first_node_in_group("main_game")
	if mg and mg.get("current_boss") != null and is_instance_valid(mg.current_boss):
		close_menu()
		mg.current_boss._die()
	elif mg and mg.has_method("jump_to_boss"):
		# Instanciar boss y detonar tras un instante
		mg.jump_to_boss("boss_mothership")
		close_menu()
		var tw := mg.create_tween()
		tw.tween_interval(0.25)
		tw.tween_callback(func():
			if mg.get("current_boss") != null and is_instance_valid(mg.current_boss):
				mg.current_boss._die()
		)
	else:
		# Fuera de combate (ej. Title Screen): Iniciar run con boss pendiente
		if current_pilot_data and "character_id" in current_pilot_data:
			SaveManager.set_selected_character(current_pilot_data.character_id)
		DebugManager.set_pending_debug_boss("boss_mothership")
		close_menu()
		get_tree().paused = false
		if not (get_tree().current_scene and "Test" in get_tree().current_scene.name):
			get_tree().change_scene_to_file("res://scenes/combat/main_game.tscn")

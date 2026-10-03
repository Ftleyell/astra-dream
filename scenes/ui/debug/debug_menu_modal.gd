class_name DebugMenuModal
extends CanvasLayer

## DebugMenuModal.gd
## Modal de depuración enfocado exclusivamente en PRE-GAME (Menú de Selección de Personajes).
## Administra metajuego, economía, gacha, desbloqueo de skins, compañeros y datos de guardado.
## Todo testeo de combate, spawns y cheats reside en IngameDebugModal (F1 en combate).

const CosmeticsManager = preload("res://core/systems/cosmetics_manager.gd")
const GachaModalScript = preload("res://scenes/ui/gacha/gacha_modal.gd")
const GachaPullCoordinatorScript = preload("res://scenes/ui/gacha/components/gacha_pull_coordinator.gd")

signal closed()

@onready var modal_panel: PanelContainer = get_node_or_null("CenterContainer/MainPanel") as PanelContainer
@onready var subtitle_label: Label = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/TitleBox/SubtitleLabel") as Label

# Tabs
@onready var tab_gacha_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/TabBarRow/TabGachaButton") as Button
@onready var tab_career_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/TabBarRow/TabCareerButton") as Button
@onready var gacha_content: VBoxContainer = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/GachaTabContent") as VBoxContainer
@onready var career_content: VBoxContainer = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/CareerTabContent") as VBoxContainer

# Gacha Tab Controls
@onready var tokens_label: Label = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/GachaTabContent/GachaStatsPanel/GachaStatsHBox/TokensLabel") as Label
@onready var biomass_label: Label = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/GachaTabContent/GachaStatsPanel/GachaStatsHBox/BiomassLabel") as Label
@onready var skins_unlocked_label: Label = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/GachaTabContent/GachaStatsPanel/GachaStatsHBox/SkinsUnlockedLabel") as Label

@onready var add_tokens_10_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/GachaTabContent/TokensRow/AddTokens10Btn") as Button
@onready var add_tokens_50_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/GachaTabContent/TokensRow/AddTokens50Btn") as Button
@onready var reset_tokens_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/GachaTabContent/TokensRow/ResetTokensBtn") as Button

@onready var add_biomass_500_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/GachaTabContent/BiomassRow/AddBiomass500Btn") as Button
@onready var add_biomass_2000_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/GachaTabContent/BiomassRow/AddBiomass2000Btn") as Button
@onready var reset_biomass_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/GachaTabContent/BiomassRow/ResetBiomassBtn") as Button

@onready var unlock_all_1star_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/GachaTabContent/SkinsRow/UnlockAll1StarBtn") as Button
@onready var unlock_all_3star_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/GachaTabContent/SkinsRow/UnlockAll3StarBtn") as Button
@onready var lock_all_skins_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/GachaTabContent/SkinsRow/LockAllSkinsBtn") as Button

@onready var test_pull_1_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/GachaTabContent/SimulationRow/TestPull1Btn") as Button
@onready var test_pull_5_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/GachaTabContent/SimulationRow/TestPull5Btn") as Button
@onready var test_pull_10_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/GachaTabContent/SimulationRow/TestPull10Btn") as Button
@onready var open_gacha_modal_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/GachaTabContent/SimulationRow/OpenGachaModalBtn") as Button

# Career / Companions Controls
@onready var lock_cosmo_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/CareerTabContent/PetsDebugRow/LockCosmoButton") as Button
@onready var simulate_10m_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/CareerTabContent/PetsDebugRow/Simulate10mButton") as Button
@onready var unlock_iris_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/CareerTabContent/NavigatorsDebugRow/UnlockIrisButton") as Button
@onready var lock_iris_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/CareerTabContent/NavigatorsDebugRow/LockIrisButton") as Button
@onready var set_bosses_9_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/CareerTabContent/CareerDebugRow/SetBosses9Button") as Button
@onready var reset_career_btn: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/CareerTabContent/CareerDebugRow/ResetCareerButton") as Button

# Bottom Actions
@onready var reset_button: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/ActionsRow/ResetButton") as Button
@onready var close_button: Button = get_node_or_null("CenterContainer/MainPanel/Margin/VBox/ActionsRow/CloseButton") as Button

var current_pilot_data: CharacterData = null
var is_open: bool = false
var active_tab_idx: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 120
	hide()

	# Tab Buttons
	if tab_gacha_btn:
		tab_gacha_btn.pressed.connect(func(): _switch_tab(0))
		UIFocusHelper.apply_cyber_focus(tab_gacha_btn)
	if tab_career_btn:
		tab_career_btn.pressed.connect(func(): _switch_tab(1))
		UIFocusHelper.apply_cyber_focus(tab_career_btn)

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

	# Career Tab Connects
	if lock_cosmo_btn:
		lock_cosmo_btn.pressed.connect(_on_lock_cosmo_pressed)
		UIFocusHelper.apply_cyber_focus(lock_cosmo_btn)
	if simulate_10m_btn:
		simulate_10m_btn.pressed.connect(_on_simulate_10m_pressed)
		UIFocusHelper.apply_cyber_focus(simulate_10m_btn)
	if unlock_iris_btn:
		unlock_iris_btn.pressed.connect(_on_unlock_iris_pressed)
		UIFocusHelper.apply_cyber_focus(unlock_iris_btn)
	if lock_iris_btn:
		lock_iris_btn.pressed.connect(_on_lock_iris_pressed)
		UIFocusHelper.apply_cyber_focus(lock_iris_btn)
	if set_bosses_9_btn:
		set_bosses_9_btn.pressed.connect(_on_set_bosses_9_pressed)
		UIFocusHelper.apply_cyber_focus(set_bosses_9_btn)
	if reset_career_btn:
		reset_career_btn.pressed.connect(_on_reset_career_pressed)
		UIFocusHelper.apply_cyber_focus(reset_career_btn)

	# Bottom Actions
	if reset_button:
		reset_button.pressed.connect(reset_to_defaults)
		UIFocusHelper.apply_cyber_focus(reset_button)
	if close_button:
		close_button.pressed.connect(close_menu)
		UIFocusHelper.apply_cyber_focus(close_button)

	_switch_tab(0)


func open_menu(pilot_data: CharacterData = null) -> void:
	current_pilot_data = pilot_data
	is_open = true
	show()
	_refresh_gacha_stats_labels()
	_switch_tab(0)


func close_menu() -> void:
	is_open = false
	hide()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		get_viewport().set_input_as_handled()
		close_menu()


func _switch_tab(tab_idx: int) -> void:
	active_tab_idx = tab_idx
	if tab_idx == 0:
		if gacha_content: gacha_content.show()
		if career_content: career_content.hide()
		if tab_gacha_btn: tab_gacha_btn.modulate = Color(1.0, 0.85, 0.2, 1.0)
		if tab_career_btn: tab_career_btn.modulate = Color(0.6, 0.6, 0.6, 1.0)
		if subtitle_label:
			subtitle_label.text = "PESTAÑA 1: GACHA, TOKENS DE DESPLIEGUE, BIOMASA Y SKINS"
			subtitle_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 0.85))
	else:
		if gacha_content: gacha_content.hide()
		if career_content: career_content.show()
		if tab_gacha_btn: tab_gacha_btn.modulate = Color(0.6, 0.6, 0.6, 1.0)
		if tab_career_btn: tab_career_btn.modulate = Color(0.2, 0.95, 1.0, 1.0)
		if subtitle_label:
			subtitle_label.text = "PESTAÑA 2: MASCOTAS, NAVEGANTES TÁCTICOS Y PROGRESO DE CARRERA"
			subtitle_label.add_theme_color_override("font_color", Color(0.2, 0.95, 1.0, 0.85))


func _refresh_gacha_stats_labels() -> void:
	if tokens_label:
		tokens_label.text = "🎟️ FICHAS GACHA: %d" % SaveManager.get_gacha_tokens()
	if biomass_label:
		biomass_label.text = "✨ POLVO ESTELAR: %d" % SaveManager.get_biomass()
	if skins_unlocked_label:
		var unlocked_cnt: int = SaveManager.get_unlocked_skins().size()
		var total_cnt: int = CosmeticsManager.get_all_skins().size()
		skins_unlocked_label.text = "🎨 SKINS DESBLOQUEADAS: %d / %d" % [unlocked_cnt, total_cnt]


# ─── GACHA HANDLERS ───────────────────────────────────────────────────────────

func _on_add_tokens_10_pressed() -> void:
	SaveManager.add_gacha_tokens(10)
	_refresh_gacha_stats_labels()

func _on_add_tokens_50_pressed() -> void:
	SaveManager.add_gacha_tokens(50)
	_refresh_gacha_stats_labels()

func _on_reset_tokens_pressed() -> void:
	SaveManager.set_gacha_tokens(0)
	_refresh_gacha_stats_labels()

func _on_add_biomass_500_pressed() -> void:
	SaveManager.add_biomass(500)
	_refresh_gacha_stats_labels()

func _on_add_biomass_2000_pressed() -> void:
	SaveManager.add_biomass(2000)
	_refresh_gacha_stats_labels()

func _on_reset_biomass_pressed() -> void:
	SaveManager.set_biomass(0)
	_refresh_gacha_stats_labels()

func _on_unlock_all_1star_pressed() -> void:
	SaveManager.unlock_all_skins(1)
	_refresh_gacha_stats_labels()

func _on_unlock_all_3star_pressed() -> void:
	SaveManager.unlock_all_skins(3)
	_refresh_gacha_stats_labels()

func _on_lock_all_skins_pressed() -> void:
	SaveManager.lock_all_skins()
	_refresh_gacha_stats_labels()

func _simulate_direct_pulls(count: int) -> void:
	SaveManager.add_gacha_tokens(count)
	var pull_coordinator = GachaPullCoordinatorScript.new()
	pull_coordinator.execute_pulls(count, "general")
	_refresh_gacha_stats_labels()

func _on_open_gacha_modal_pressed() -> void:
	var gacha_modal_inst = get_tree().root.find_child("GachaModal", true, false)
	if not gacha_modal_inst:
		var parent = get_parent()
		if parent:
			gacha_modal_inst = parent.get_node_or_null("GachaModal")
	if gacha_modal_inst and gacha_modal_inst.has_method("open_modal"):
		close_menu()
		gacha_modal_inst.open_modal()


# ─── CAREER & COMPANIONS HANDLERS ─────────────────────────────────────────────

func _on_lock_cosmo_pressed() -> void:
	SaveManager.lock_pet(&"cosmo")

func _on_simulate_10m_pressed() -> void:
	var cur_scene = get_tree().current_scene
	if cur_scene and "run_time_elapsed" in cur_scene:
		cur_scene.run_time_elapsed = 600.0
	SaveManager.unlock_pet(&"cosmo")

func _on_unlock_iris_pressed() -> void:
	SaveManager.unlock_navigator(&"iris")

func _on_lock_iris_pressed() -> void:
	SaveManager.lock_navigator(&"iris")

func _on_set_bosses_9_pressed() -> void:
	SaveManager.set_career_bosses_killed(9)

func _on_reset_career_pressed() -> void:
	SaveManager.reset_career_stats()
	_refresh_gacha_stats_labels()


func reset_to_defaults() -> void:
	_refresh_gacha_stats_labels()

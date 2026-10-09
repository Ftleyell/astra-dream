class_name CharacterSelectUI
extends Control

## ─── TABLE OF CONTENTS ──────────────────────────────────────────────────────
## VARIABLES & @ONREADY NODES      → L.30  - L.220
## _resolve_ability_node (util)    → L.222
## LIFECYCLE: _ready / _setup_*   → L.234 - L.445
## INPUT: _input / _has_any_modal → L.447 - L.475  [modal_router]
## INPUT: _unhandled_input        → L.476 - L.487  [speed_selector]
## ROSTER: _populate_roster       → L.488 - L.560
## ROSTER: _select_character      → L.561 - L.670  [display_manager]
## DISPLAY: abilities / telemetry → L.671 - L.705  [display_manager]
## MODALS: talents / banlist      → L.706 - L.727  [modal_router]
## MODALS: skins / pet / nav      → L.728 - L.820  [skin_coordinator]
## LAUNCH: committed / exit hub   → L.821 - L.840  [launch_controller]
## HERO PICKER & FOCUS MESH       → L.841 - L.875  [focus_router]
## SPEED & DEBUG & CLEANUP        → L.876 - L.922
## ─────────────────────────────────────────────────────────────────────────────


const CharacterPilotShowcase = preload("res://scenes/ui/character_select/components/character_pilot_showcase.gd")
const CharacterEquipmentCards = preload("res://scenes/ui/character_select/components/character_equipment_cards.gd")
const CharacterSpeedSelector = preload("res://scenes/ui/character_select/components/character_speed_selector.gd")
const CharacterSkinCoordinator = preload("res://scenes/ui/character_select/components/character_skin_coordinator.gd")
const CharacterFocusRouter = preload("res://scenes/ui/character_select/components/character_focus_router.gd")
const CharacterSelectLaunchController = preload("res://scenes/ui/character_select/components/character_select_launch_controller.gd")
const CharacterSelectDisplayManager = preload("res://scenes/ui/character_select/components/character_select_display_manager.gd")
const CharacterSelectModalRouter = preload("res://scenes/ui/character_select/components/character_select_modal_router.gd")

const CosmeticsManager = preload("res://core/systems/cosmetics_manager.gd")
const SkinSelectionModalScript = preload("res://scenes/ui/cosmetics/skin_selection_modal.gd")
const GachaModalScript = preload("res://scenes/ui/gacha/gacha_modal.gd")
const DebugMenuModalScript = preload("res://scenes/ui/debug/debug_menu_modal.gd")

# ==============================================================================
# CONFIGURACIÓN DE DEBUG (Gobernado centralmente, inactivo en producción)
# ==============================================================================
const DEBUG_MENU_AVAILABLE: bool = true

var is_debug_active: bool:
	get:
		return OS.is_debug_build() and DEBUG_MENU_AVAILABLE and (DebugManager.is_debug_enabled() if DebugManager else false)
# ==============================================================================

# Cabecera y Telemetría
@onready var back_button: Button = $MarginContainer/RootVBox/HeaderBar/BackButton
@onready var biomass_label: Label = get_node_or_null("MarginContainer/RootVBox/HeaderBar/TelemetryBox/BiomassLabel")
@onready var antimatter_label: Label = get_node_or_null("MarginContainer/RootVBox/HeaderBar/TelemetryBox/AntimatterLabel")
@onready var dark_matter_label: Label = get_node_or_null("MarginContainer/RootVBox/HeaderBar/TelemetryBox/DarkMatterLabel")

# Escaparate de la Heroína (Mitad Derecha)
@onready var fullbody_texture: TextureRect = $MarginContainer/RootVBox/MainWorkspace/RightShowcaseArea/FullbodyTexture
@onready var backlight_glow: TextureRect = $MarginContainer/RootVBox/MainWorkspace/RightShowcaseArea/BacklightGlow
@onready var pilot_button: Button = $MarginContainer/RootVBox/MainWorkspace/RightShowcaseArea/PilotButton
@onready var name_label: Label = $MarginContainer/RootVBox/MainWorkspace/RightShowcaseArea/HeroIdentityBox/NameLabel
@onready var title_label: Label = $MarginContainer/RootVBox/MainWorkspace/RightShowcaseArea/HeroIdentityBox/ClassTitleLabel
@onready var pilot_skin_btn: Button = $MarginContainer/RootVBox/MainWorkspace/RightShowcaseArea/HeroIdentityBox/PilotSkinButton

# Vista Principal Unificada (2 Columnas)
@onready var loadout_view: VBoxContainer = $MarginContainer/RootVBox/MainWorkspace/LeftCommandPanel/TabContentPanel/TabMargin/TwoColumnWorkspace/LoadoutView
@onready var abilities_view: VBoxContainer = $MarginContainer/RootVBox/MainWorkspace/RightShowcaseArea/AbilitiesView

# Tarjetas de Equipamiento (Columna Loadout)
@onready var ship_card: PanelContainer = $MarginContainer/RootVBox/MainWorkspace/LeftCommandPanel/TabContentPanel/TabMargin/TwoColumnWorkspace/LoadoutView/ChassisWeaponRow/ShipCard
@onready var ship_icon: TextureRect = $MarginContainer/RootVBox/MainWorkspace/LeftCommandPanel/TabContentPanel/TabMargin/TwoColumnWorkspace/LoadoutView/ChassisWeaponRow/ShipCard/ShipMargin/ShipBox/ShipIcon
@onready var ship_name: Label = $MarginContainer/RootVBox/MainWorkspace/LeftCommandPanel/TabContentPanel/TabMargin/TwoColumnWorkspace/LoadoutView/ChassisWeaponRow/ShipCard/ShipMargin/ShipBox/ShipLabelVBox/ShipName
@onready var ship_button: Button = $MarginContainer/RootVBox/MainWorkspace/LeftCommandPanel/TabContentPanel/TabMargin/TwoColumnWorkspace/LoadoutView/ChassisWeaponRow/ShipCard/ShipButton

@onready var weapon_card: PanelContainer = $MarginContainer/RootVBox/MainWorkspace/LeftCommandPanel/TabContentPanel/TabMargin/TwoColumnWorkspace/LoadoutView/ChassisWeaponRow/WeaponCard
@onready var weapon_icon: TextureRect = $MarginContainer/RootVBox/MainWorkspace/LeftCommandPanel/TabContentPanel/TabMargin/TwoColumnWorkspace/LoadoutView/ChassisWeaponRow/WeaponCard/WeaponMargin/WeaponBox/WeaponIcon
@onready var weapon_name: Label = $MarginContainer/RootVBox/MainWorkspace/LeftCommandPanel/TabContentPanel/TabMargin/TwoColumnWorkspace/LoadoutView/ChassisWeaponRow/WeaponCard/WeaponMargin/WeaponBox/WeaponLabelVBox/WeaponName
@onready var weapon_button: Button = $MarginContainer/RootVBox/MainWorkspace/LeftCommandPanel/TabContentPanel/TabMargin/TwoColumnWorkspace/LoadoutView/ChassisWeaponRow/WeaponCard/WeaponButton

@onready var pet_card: PanelContainer = $MarginContainer/RootVBox/MainWorkspace/LeftCommandPanel/TabContentPanel/TabMargin/TwoColumnWorkspace/LoadoutView/PetCard
@onready var pet_icon: TextureRect = $MarginContainer/RootVBox/MainWorkspace/LeftCommandPanel/TabContentPanel/TabMargin/TwoColumnWorkspace/LoadoutView/PetCard/PetMargin/PetBox/PetIcon
@onready var pet_name: Label = $MarginContainer/RootVBox/MainWorkspace/LeftCommandPanel/TabContentPanel/TabMargin/TwoColumnWorkspace/LoadoutView/PetCard/PetMargin/PetBox/PetLabelVBox/PetName
@onready var pet_desc: Label = $MarginContainer/RootVBox/MainWorkspace/LeftCommandPanel/TabContentPanel/TabMargin/TwoColumnWorkspace/LoadoutView/PetCard/PetMargin/PetBox/PetLabelVBox/PetDesc
@onready var pet_button: Button = $MarginContainer/RootVBox/MainWorkspace/LeftCommandPanel/TabContentPanel/TabMargin/TwoColumnWorkspace/LoadoutView/PetCard/PetButton

@onready var navigator_card: PanelContainer = $MarginContainer/RootVBox/MainWorkspace/LeftCommandPanel/TabContentPanel/TabMargin/TwoColumnWorkspace/LoadoutView/NavigatorCard
@onready var navigator_icon: TextureRect = $MarginContainer/RootVBox/MainWorkspace/LeftCommandPanel/TabContentPanel/TabMargin/TwoColumnWorkspace/LoadoutView/NavigatorCard/NavigatorMargin/NavigatorBox/NavigatorIcon
@onready var navigator_name: Label = $MarginContainer/RootVBox/MainWorkspace/LeftCommandPanel/TabContentPanel/TabMargin/TwoColumnWorkspace/LoadoutView/NavigatorCard/NavigatorMargin/NavigatorBox/NavigatorLabelVBox/NavigatorName
@onready var navigator_desc: Label = $MarginContainer/RootVBox/MainWorkspace/LeftCommandPanel/TabContentPanel/TabMargin/TwoColumnWorkspace/LoadoutView/NavigatorCard/NavigatorMargin/NavigatorBox/NavigatorLabelVBox/NavigatorDesc
@onready var navigator_button: Button = $MarginContainer/RootVBox/MainWorkspace/LeftCommandPanel/TabContentPanel/TabMargin/TwoColumnWorkspace/LoadoutView/NavigatorCard/NavigatorButton

# Controles de Talentos, Tomos y Velocidad
@onready var expand_talents_btn: Button = $MarginContainer/RootVBox/MainWorkspace/LeftCommandPanel/TabContentPanel/TabMargin/TwoColumnWorkspace/LoadoutView/TalentsCard/TalentsMargin/TalentsVBox/ExpandTalentsBtn
@onready var arsenal_banlist_btn: Button = get_node_or_null("MarginContainer/RootVBox/MainWorkspace/LeftCommandPanel/TabContentPanel/TabMargin/TwoColumnWorkspace/LoadoutView/TomesCard/TomesMargin/TomesVBox/ArsenalBanlistBtn")
@onready var tomes_pool_btn: Button = get_node_or_null("MarginContainer/RootVBox/MainWorkspace/LeftCommandPanel/TabContentPanel/TabMargin/TwoColumnWorkspace/LoadoutView/TomesCard/TomesMargin/TomesVBox/TomesActionsHBox/TomesPoolBtn")
@onready var loadout_button: Button = get_node_or_null("MarginContainer/RootVBox/MainWorkspace/LeftCommandPanel/TabContentPanel/TabMargin/TwoColumnWorkspace/LoadoutView/TomesCard/TomesMargin/TomesVBox/TomesActionsHBox/LoadoutButton")

@onready var speed_1x_btn: Button = $MarginContainer/RootVBox/MainWorkspace/LeftCommandPanel/TabContentPanel/TabMargin/TwoColumnWorkspace/LoadoutView/SpeedCard/SpeedMargin/SpeedVBox/SpeedRow/Speed1xBtn
@onready var speed_2x_btn: Button = $MarginContainer/RootVBox/MainWorkspace/LeftCommandPanel/TabContentPanel/TabMargin/TwoColumnWorkspace/LoadoutView/SpeedCard/SpeedMargin/SpeedVBox/SpeedRow/Speed2xBtn
@onready var speed_4x_btn: Button = $MarginContainer/RootVBox/MainWorkspace/LeftCommandPanel/TabContentPanel/TabMargin/TwoColumnWorkspace/LoadoutView/SpeedCard/SpeedMargin/SpeedVBox/SpeedRow/Speed4xBtn

# Bloques de Habilidades (Columna Habilidades)
@onready var weapon_block_icon: TextureRect = _resolve_ability_node("WeaponBlock/WeaponMargin/WeaponRow/WeaponBlockIcon") as TextureRect
@onready var weapon_block_tag: Label = _resolve_ability_node("WeaponBlock/WeaponMargin/WeaponRow/WeaponBlockVBox/WeaponBlockTag") as Label
@onready var weapon_block_title: Label = _resolve_ability_node("WeaponBlock/WeaponMargin/WeaponRow/WeaponBlockVBox/WeaponBlockTitle") as Label
@onready var weapon_block_desc: Label = _resolve_ability_node("WeaponBlock/WeaponMargin/WeaponRow/WeaponBlockVBox/WeaponBlockDesc") as Label

@onready var tactical_block_icon: TextureRect = _resolve_ability_node("TacticalBlock/TacticalMargin/TacticalRow/TacticalBlockIcon") as TextureRect
@onready var tactical_block_tag: Label = _resolve_ability_node("TacticalBlock/TacticalMargin/TacticalRow/TacticalBlockVBox/TacticalBlockTag") as Label
@onready var tactical_block_title: Label = _resolve_ability_node("TacticalBlock/TacticalMargin/TacticalRow/TacticalBlockVBox/TacticalBlockTitle") as Label
@onready var tactical_block_desc: Label = _resolve_ability_node("TacticalBlock/TacticalMargin/TacticalRow/TacticalBlockVBox/TacticalBlockDesc") as Label

@onready var dash_block_icon: TextureRect = _resolve_ability_node("DashBlock/DashMargin/DashRow/DashBlockIcon") as TextureRect
@onready var dash_block_tag: Label = _resolve_ability_node("DashBlock/DashMargin/DashRow/DashBlockVBox/DashBlockTag") as Label
@onready var dash_block_title: Label = _resolve_ability_node("DashBlock/DashMargin/DashRow/DashBlockVBox/DashBlockTitle") as Label
@onready var dash_block_desc: Label = _resolve_ability_node("DashBlock/DashMargin/DashRow/DashBlockVBox/DashBlockDesc") as Label

@onready var passive_block_icon: TextureRect = _resolve_ability_node("PassiveBlock/PassiveMargin/PassiveRow/PassiveBlockIcon") as TextureRect
@onready var passive_block_tag: Label = _resolve_ability_node("PassiveBlock/PassiveMargin/PassiveRow/PassiveBlockVBox/PassiveBlockTag") as Label
@onready var passive_block_title: Label = _resolve_ability_node("PassiveBlock/PassiveMargin/PassiveRow/PassiveBlockVBox/PassiveBlockTitle") as Label
@onready var passive_block_desc: Label = _resolve_ability_node("PassiveBlock/PassiveMargin/PassiveRow/PassiveBlockVBox/PassiveBlockDesc") as Label

var tab_loadout_btn: Button = null
var tab_abilities_btn: Button = null
var talents_metrics_label: Label = null
var favored_tome_desc: Label = null

# Barra de Mando Persistente
@onready var main_margin_container: MarginContainer = $MarginContainer
@onready var root_vbox: VBoxContainer = $MarginContainer/RootVBox
@onready var dock_container: PanelContainer = (get_node_or_null("DockContainer") as PanelContainer) if get_node_or_null("DockContainer") else (get_node_or_null("MarginContainer/RootVBox/DockContainer") as PanelContainer)
@onready var orbital_terminal: OrbitalIgnitionTerminal = (get_node_or_null("DockContainer/TerminalCenter/OrbitalIgnitionTerminal") as OrbitalIgnitionTerminal) if get_node_or_null("DockContainer/TerminalCenter/OrbitalIgnitionTerminal") else (get_node_or_null("MarginContainer/RootVBox/DockContainer/TerminalCenter/OrbitalIgnitionTerminal") as OrbitalIgnitionTerminal)
@onready var dock_margin: MarginContainer = (get_node_or_null("DockContainer/DockMargin") as MarginContainer) if get_node_or_null("DockContainer/DockMargin") else (get_node_or_null("MarginContainer/RootVBox/DockContainer/DockMargin") as MarginContainer)
@onready var char_list_container: HBoxContainer = (get_node_or_null("DockContainer/DockMargin/CharList") as HBoxContainer) if get_node_or_null("DockContainer/DockMargin/CharList") else (get_node_or_null("MarginContainer/RootVBox/DockContainer/DockMargin/CharList") as HBoxContainer)
@onready var dock_unified_button: Button = (get_node_or_null("DockContainer/DockUnifiedButton") as Button) if get_node_or_null("DockContainer/DockUnifiedButton") else (get_node_or_null("MarginContainer/RootVBox/DockContainer/DockUnifiedButton") as Button)

# Modales
@onready var debug_menu_modal = get_node_or_null("DebugMenuModal")
@onready var pet_selection_modal = get_node_or_null("PetSelectionModal")
@onready var navigator_selection_modal = get_node_or_null("NavigatorSelectionModal")
@onready var skin_selection_modal = get_node_or_null("SkinSelectionModal")
@onready var gacha_modal = get_node_or_null("GachaModal")
@onready var tome_selection_modal = get_node_or_null("TomeSelectionModal")
@onready var weapon_selection_modal = get_node_or_null("WeaponSelectionModal")
@onready var character_skill_tree_modal = get_node_or_null("CharacterSkillTreeModal")
@onready var cosmetic_carousel_modal = get_node_or_null("CosmeticCarouselModal")
@onready var hero_picker_modal = get_node_or_null("HeroPickerModal")
@onready var arsenal_banlist_modal = get_node_or_null("ArsenalBanlistModal")

var pilot_showcase: CharacterPilotShowcase = null
var equipment_cards: CharacterEquipmentCards = null
var speed_selector: CharacterSpeedSelector = null
var skin_coordinator: CharacterSkinCoordinator = null
var focus_router: CharacterFocusRouter = null
var launch_controller: CharacterSelectLaunchController = null
var display_manager: CharacterSelectDisplayManager = null
var modal_router: CharacterSelectModalRouter = null

var current_game_speed: float:
	get:
		return speed_selector.current_game_speed if speed_selector else 1.0
	set(val):
		if speed_selector:
			speed_selector.current_game_speed = val

var current_character_id: StringName = &"nova"
var roster_dict: Dictionary[StringName, CharacterData] = {}
var roster_ordered: Array[CharacterData] = []
var _last_focused_control: Control = null
var _current_tab_index: int = 0
var _dock_card_buttons: Dictionary[StringName, Button] = {}

# Backward-compatible accessors
var ship_skin_button: Button:
	get:
		return ship_button
var weapon_skin_button: Button:
	get:
		return weapon_button
var pet_skin_button: Button:
	get:
		return pet_button
var navigator_skin_button: Button:
	get:
		return navigator_button
var pilot_skin_button: Button:
	get:
		return pilot_skin_btn
var debug_button: Button:
	get:
		return null
var talents_view: Control:
	get:
		return loadout_view
var tomes_view: Control:
	get:
		return loadout_view
var stats_view: Control:
	get:
		return abilities_view
var tab_talents_btn: Button:
	get:
		return tab_abilities_btn
var tab_tomes_btn: Button:
	get:
		return tab_abilities_btn
var tab_stats_btn: Button:
	get:
		return tab_abilities_btn


func _resolve_ability_node(rel_path: String) -> Node:
	if abilities_view and abilities_view.has_node(rel_path):
		return abilities_view.get_node(rel_path)
	var path_a: String = "MarginContainer/RootVBox/MainWorkspace/RightShowcaseArea/AbilitiesView/" + rel_path
	if has_node(path_a):
		return get_node(path_a)
	var path_b: String = "AbilitiesView/" + rel_path
	if has_node(path_b):
		return get_node(path_b)
	return null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	pilot_showcase = CharacterPilotShowcase.new()
	equipment_cards = CharacterEquipmentCards.new()
	speed_selector = CharacterSpeedSelector.new()
	skin_coordinator = CharacterSkinCoordinator.new()
	focus_router = CharacterFocusRouter.new()
	launch_controller = CharacterSelectLaunchController.new()
	display_manager = CharacterSelectDisplayManager.new()
	modal_router = CharacterSelectModalRouter.new()

	_setup_subcomponents()
	_setup_tabs()
	_setup_signals()
	_setup_speed_buttons()

	roster_dict = CharacterData.load_roster()
	skin_coordinator.setup(
		cosmetic_carousel_modal,
		skin_selection_modal,
		gacha_modal,
		roster_dict,
		Callable(self, "_select_character"),
		Callable(self, "_save_current_focus"),
		Callable(self, "_restore_last_focus")
	)

	roster_ordered = roster_dict.values()
	roster_ordered.sort_custom(func(a: CharacterData, b: CharacterData):
		return a.sort_order < b.sort_order
	)

	_populate_roster()

	var saved_char: StringName = SaveManager.get_selected_character()
	if not saved_char.is_empty() and roster_dict.has(saved_char):
		_select_character(saved_char)
	else:
		_select_character(&"nova")

	_refresh_telemetry_ui()
	_update_ability_tags()
	_switch_tab(0)

	if dock_margin:
		dock_margin.visible = false
	if dock_unified_button:
		dock_unified_button.visible = false
	if dock_container:
		dock_container.visible = false
	if orbital_terminal:
		orbital_terminal.visible = false
	if back_button:
		back_button.text = "← [ESC] HUB"

	if dock_unified_button:
		dock_unified_button.pressed.connect(_on_dock_unified_button_pressed)
		var dock_focus_sb := StyleBoxFlat.new()
		dock_focus_sb.bg_color = Color(0, 0, 0, 0)
		dock_focus_sb.border_width_left = 2
		dock_focus_sb.border_width_top = 2
		dock_focus_sb.border_width_right = 2
		dock_focus_sb.border_width_bottom = 2
		dock_focus_sb.border_color = Color(0, 0.95, 1, 0.9)
		dock_focus_sb.set_corner_radius_all(10)
		dock_focus_sb.shadow_color = Color(0, 0.8, 1, 0.4)
		dock_focus_sb.shadow_size = 8
		dock_unified_button.add_theme_stylebox_override("focus", dock_focus_sb)

	if hero_picker_modal:
		hero_picker_modal.hero_confirmed.connect(_on_hero_confirmed)
		hero_picker_modal.hero_cancelled.connect(_on_hero_cancelled)
		if main_margin_container:
			main_margin_container.visible = false
		hero_picker_modal.open_picker(roster_ordered, current_character_id, true)


func _setup_subcomponents() -> void:
	if pilot_showcase:
		pilot_showcase.setup(
			fullbody_texture,
			backlight_glow,
			pilot_button,
			Callable(self, "_on_pilot_button_pressed")
		)

	if equipment_cards:
		equipment_cards.setup_ship_and_weapon(
			ship_card, ship_icon, ship_name, ship_button,
			Callable(self, "_on_ship_card_pressed"),
			weapon_card, weapon_icon, weapon_name, weapon_button,
			Callable(self, "_on_weapon_card_pressed")
		)
		equipment_cards.setup_companions(
			pet_card, pet_icon, pet_name, pet_desc, pet_button,
			Callable(self, "_on_pet_card_pressed"),
			navigator_card, navigator_icon, navigator_name, navigator_desc, navigator_button,
			Callable(self, "_on_navigator_card_pressed")
		)

	if display_manager:
		display_manager.setup_identity_and_telemetry(
			name_label, title_label, biomass_label, antimatter_label, dark_matter_label,
			expand_talents_btn, talents_metrics_label, loadout_button, orbital_terminal
		)
		display_manager.setup_abilities_blocks(
			weapon_block_icon, weapon_block_tag, weapon_block_title, weapon_block_desc,
			tactical_block_icon, tactical_block_tag, tactical_block_title, tactical_block_desc,
			dash_block_icon, dash_block_tag, dash_block_title, dash_block_desc,
			passive_block_icon, passive_block_tag, passive_block_title, passive_block_desc,
			favored_tome_desc
		)

	if modal_router:
		modal_router.setup_modals(
			debug_menu_modal, pet_selection_modal, navigator_selection_modal, skin_selection_modal,
			gacha_modal, tome_selection_modal, weapon_selection_modal, character_skill_tree_modal,
			cosmetic_carousel_modal, hero_picker_modal, arsenal_banlist_modal
		)


func _setup_tabs() -> void:
	if tab_loadout_btn:
		tab_loadout_btn.pressed.connect(func(): _switch_tab(0))
	if tab_abilities_btn:
		tab_abilities_btn.pressed.connect(func(): _switch_tab(1))


func _switch_tab(index: int) -> void:
	_current_tab_index = index
	if loadout_view:
		loadout_view.visible = true
	if abilities_view:
		abilities_view.visible = true


func _setup_signals() -> void:
	UIFocusHelper.apply_cyber_focus(back_button)
	back_button.pressed.connect(_on_back_pressed)
	if orbital_terminal:
		orbital_terminal.ignition_committed.connect(_on_launch_committed)
	if pilot_skin_btn:
		UIFocusHelper.apply_cyber_focus(pilot_skin_btn)
		pilot_skin_btn.pressed.connect(_on_skins_button_pressed)

	var settings_mgr: Node = get_node_or_null("/root/SettingsManager")
	if settings_mgr and settings_mgr.has_signal("settings_changed"):
		settings_mgr.settings_changed.connect(_update_ability_tags)

	if expand_talents_btn:
		UIFocusHelper.apply_cyber_focus(expand_talents_btn)
		expand_talents_btn.pressed.connect(_on_expand_talents_pressed)
	if arsenal_banlist_btn:
		UIFocusHelper.apply_cyber_focus(arsenal_banlist_btn)
		arsenal_banlist_btn.pressed.connect(_on_arsenal_banlist_pressed)
	if tomes_pool_btn:
		UIFocusHelper.apply_cyber_focus(tomes_pool_btn)
		tomes_pool_btn.pressed.connect(_on_tomes_pool_pressed)
	if loadout_button:
		UIFocusHelper.apply_cyber_focus(loadout_button)
		loadout_button.pressed.connect(_on_loadout_pressed)

	if pet_selection_modal:
		if pet_selection_modal.has_signal("pet_selected"):
			pet_selection_modal.pet_selected.connect(_on_pet_selected)
		if pet_selection_modal.has_signal("skin_equipped"):
			pet_selection_modal.skin_equipped.connect(_on_pet_skin_equipped)
		if pet_selection_modal.has_signal("closed"):
			pet_selection_modal.closed.connect(_on_pet_modal_closed)

	if navigator_selection_modal:
		if navigator_selection_modal.has_signal("navigator_selected"):
			navigator_selection_modal.navigator_selected.connect(_on_navigator_selected)
		if navigator_selection_modal.has_signal("skin_equipped"):
			navigator_selection_modal.skin_equipped.connect(_on_navigator_skin_equipped)
		if navigator_selection_modal.has_signal("closed"):
			navigator_selection_modal.closed.connect(_on_navigator_modal_closed)

	if debug_menu_modal and debug_menu_modal.has_signal("closed"):
		debug_menu_modal.closed.connect(_on_debug_modal_closed)

	if cosmetic_carousel_modal:
		if cosmetic_carousel_modal.has_signal("skin_modal_closed"):
			cosmetic_carousel_modal.skin_modal_closed.connect(_on_cosmetic_carousel_closed)
		if cosmetic_carousel_modal.has_signal("skin_selected"):
			cosmetic_carousel_modal.skin_selected.connect(_on_skin_selected)

	if skin_selection_modal:
		if skin_selection_modal.has_signal("skin_selected"):
			skin_selection_modal.skin_selected.connect(_on_skin_selected)
		if skin_selection_modal.has_signal("closed"):
			skin_selection_modal.closed.connect(_on_skin_modal_closed)
		if skin_selection_modal.has_signal("open_gacha_requested"):
			skin_selection_modal.open_gacha_requested.connect(_open_gacha_from_skins)

	if gacha_modal:
		if gacha_modal.has_signal("skin_equipped"):
			gacha_modal.skin_equipped.connect(_on_gacha_skin_equipped)
		if gacha_modal.has_signal("modal_closed"):
			gacha_modal.modal_closed.connect(_on_gacha_modal_closed)

	if tome_selection_modal and tome_selection_modal.has_signal("closed"):
		tome_selection_modal.closed.connect(_on_tome_modal_closed)

	if weapon_selection_modal and weapon_selection_modal.has_signal("closed"):
		weapon_selection_modal.closed.connect(_on_weapon_modal_closed)

	if arsenal_banlist_modal and arsenal_banlist_modal.has_signal("closed"):
		arsenal_banlist_modal.closed.connect(_on_arsenal_banlist_modal_closed)

	if character_skill_tree_modal and character_skill_tree_modal.has_signal("modal_closed"):
		character_skill_tree_modal.modal_closed.connect(_on_skill_tree_closed)
	elif character_skill_tree_modal and character_skill_tree_modal.has_signal("closed"):
		character_skill_tree_modal.closed.connect(_on_skill_tree_closed)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		if _has_any_modal_open():
			return
		get_viewport().set_input_as_handled()
		_on_back_pressed()
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			if _has_any_modal_open():
				return
			if orbital_terminal and orbital_terminal.is_visible_in_tree() and not orbital_terminal.disabled:
				get_viewport().set_input_as_handled()
				if orbital_terminal.has_method("_on_pressed"):
					orbital_terminal._on_pressed()
				else:
					_on_launch_committed()


func _has_any_modal_open() -> bool:
	if modal_router:
		return modal_router.has_any_modal_open()
	return false


func _unhandled_input(event: InputEvent) -> void:
	if _has_any_modal_open():
		return

	if is_debug_active and (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1):
		_on_debug_pressed()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		if speed_selector and speed_selector.handle_shortcut(event.keycode):
			get_viewport().set_input_as_handled()


func _populate_roster() -> void:
	for child in char_list_container.get_children():
		child.queue_free()
	_dock_card_buttons.clear()

	var first_btn: Button = null

	for char_data in roster_ordered:
		var cid: StringName = char_data.character_id
		var is_unlocked: bool = SaveManager.is_character_unlocked(cid)

		var card_btn := Button.new()
		card_btn.name = "PilotCard_%s" % cid
		card_btn.custom_minimum_size = Vector2(76, 76)
		card_btn.focus_mode = Control.FOCUS_NONE

		var card_style := StyleBoxFlat.new()
		card_style.bg_color = Color(0.025, 0.04, 0.07, 0.92)
		card_style.border_width_left = 2
		card_style.border_width_top = 2
		card_style.border_width_right = 2
		card_style.border_width_bottom = 2
		card_style.border_color = char_data.color if is_unlocked else Color(0.3, 0.35, 0.4, 0.5)
		card_style.set_corner_radius_all(6)
		card_style.content_margin_left = 4
		card_style.content_margin_top = 4
		card_style.content_margin_right = 4
		card_style.content_margin_bottom = 4
		card_btn.add_theme_stylebox_override("normal", card_style)
		card_btn.add_theme_stylebox_override("hover", card_style)
		card_btn.add_theme_stylebox_override("pressed", card_style)

		# Icono del avatar con expand_icon = true para encajar exactamente en el botón cuadrado
		card_btn.icon = char_data.get_avatar_texture()
		card_btn.expand_icon = true
		card_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card_btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		card_btn.tooltip_text = char_data.display_name.to_upper()
		card_btn.text = ""

		card_btn.pivot_offset = Vector2(38, 38)
		card_btn.pressed.connect(func():
			_select_character(cid)
			if hero_picker_modal:
				if main_margin_container:
					main_margin_container.visible = false
				hero_picker_modal.open_picker(roster_ordered, cid, false)
		)

		# Hover feedback: escala suave 1.08x centrada (sin perder fondo)
		card_btn.mouse_entered.connect(func():
			card_btn.pivot_offset = card_btn.size * 0.5
			var tw := card_btn.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(card_btn, "scale", Vector2(1.08, 1.08), 0.12)
		)
		card_btn.mouse_exited.connect(func():
			card_btn.pivot_offset = card_btn.size * 0.5
			var tw := card_btn.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(card_btn, "scale", Vector2(1.0, 1.0), 0.12)
		)

		UIFocusHelper.apply_cyber_focus(card_btn)
		char_list_container.add_child(card_btn)
		_dock_card_buttons[cid] = card_btn

		if not first_btn:
			first_btn = card_btn

	_setup_focus_mesh()

	# El foco inicial lo gestiona HeroPickerModal (o ship_button tras confirmar selección).


func _select_character(char_id: StringName) -> void:
	current_character_id = char_id
	SaveManager.set_selected_character(char_id)

	var data: CharacterData = roster_dict.get(char_id, null)
	if not data:
		roster_dict = CharacterData.load_roster()
		data = roster_dict.get(char_id, null)
	if not data:
		return

	# Cargar loadout específico de la heroína
	var loadout: Dictionary = SaveManager.get_character_loadout(char_id)
	if loadout.has("selected_pet") and not str(loadout["selected_pet"]).is_empty():
		SaveManager.set_selected_pet(StringName(str(loadout["selected_pet"])))
	if loadout.has("selected_navigator") and not str(loadout["selected_navigator"]).is_empty():
		SaveManager.set_selected_navigator(StringName(str(loadout["selected_navigator"])))

	var cur_pet_str: String = String(SaveManager.get_selected_pet()).to_lower()
	var pet_skin: String = str(loadout.get("equipped_pet_skin", ""))
	if not pet_skin.is_empty():
		SaveManager.equip_skin("pet:" + cur_pet_str, pet_skin)
	else:
		SaveManager.unequip_skin("pet:" + cur_pet_str)

	var cur_nav_str: String = String(SaveManager.get_selected_navigator()).to_lower()
	var nav_skin: String = str(loadout.get("equipped_navigator_skin", ""))
	if not nav_skin.is_empty():
		SaveManager.equip_skin("navigator:" + cur_nav_str, nav_skin)
	else:
		SaveManager.unequip_skin("navigator:" + cur_nav_str)

	var cid_str: String = String(char_id).to_lower()
	var ship_skin: String = str(loadout.get("equipped_ship_skin", loadout.get("ship_skin", "base")))
	if ship_skin.is_empty():
		ship_skin = "base"
	SaveManager.equip_skin("ship:" + cid_str, ship_skin)

	var weapon_skin: String = str(loadout.get("equipped_weapon_skin", loadout.get("weapon_skin", "base")))
	if weapon_skin.is_empty():
		weapon_skin = "base"
	SaveManager.equip_skin("weapon:" + cid_str, weapon_skin)

	var pilot_skin: String = str(loadout.get("equipped_pilot_skin", loadout.get("pilot_skin", "base")))
	if pilot_skin.is_empty():
		pilot_skin = "base"
	SaveManager.equip_skin("pilot:" + cid_str, pilot_skin)

	# Dossier táctico y habilidades
	if display_manager:
		display_manager.update_character_identity(data)
		display_manager.update_character_abilities(data)

	var is_unlocked: bool = SaveManager.is_character_unlocked(char_id)

	if equipment_cards:
		equipment_cards.update_equipment(data, char_id)
	if pilot_showcase:
		pilot_showcase.update_pilot_display(data, char_id, is_unlocked)

	# Actualizar resaltados en el dock inferior y estado de terminal
	if display_manager:
		display_manager.update_dock_highlights(char_id, _dock_card_buttons, roster_dict)
		display_manager.update_terminal_lock_state(is_unlocked)
		display_manager.refresh_telemetry_ui()
		display_manager.refresh_talents_summary(char_id)
		display_manager.update_ability_tags()

	_setup_focus_mesh()


func _get_action_key_text(act: StringName) -> String:
	return display_manager.get_action_key_text(act) if display_manager else "N/A"


func _update_ability_tags() -> void:
	if display_manager:
		display_manager.update_ability_tags()


func _refresh_telemetry_ui() -> void:
	if display_manager:
		display_manager.refresh_telemetry_ui()


func _refresh_talents_summary(char_id: StringName) -> void:
	if display_manager:
		display_manager.refresh_talents_summary(char_id)


func _on_expand_talents_pressed() -> void:
	if modal_router:
		modal_router.open_talents(current_character_id, get_viewport(), focus_router)


func _on_skill_tree_closed() -> void:
	_refresh_telemetry_ui()
	_refresh_talents_summary(current_character_id)
	_restore_last_focus()


func _on_arsenal_banlist_pressed(default_tab: int = 0) -> void:
	if modal_router:
		modal_router.open_arsenal_banlist(current_character_id, default_tab, get_viewport(), focus_router)


func _on_tomes_pool_pressed() -> void:
	if modal_router:
		modal_router.open_tomes_pool(current_character_id, get_viewport(), focus_router)


func _save_current_focus() -> void:
	if focus_router:
		focus_router.save_focus(get_viewport())


func _on_ship_card_pressed() -> void:
	if skin_coordinator:
		skin_coordinator.open_ship_customization(current_character_id)


func _on_ship_skin_pressed() -> void:
	_on_ship_card_pressed()


func _on_pilot_skin_pressed() -> void:
	_on_skins_button_pressed()


func _on_weapon_card_pressed() -> void:
	if skin_coordinator:
		skin_coordinator.open_weapon_customization(current_character_id)


func _on_pet_card_pressed() -> void:
	if focus_router:
		focus_router.set_last_focused(pet_button if pet_button else get_viewport().gui_get_focus_owner())
	if pet_selection_modal and pet_selection_modal.has_method("open_modal"):
		pet_selection_modal.open_modal()


func _on_navigator_card_pressed() -> void:
	if focus_router:
		focus_router.set_last_focused(navigator_button if navigator_button else get_viewport().gui_get_focus_owner())
	if navigator_selection_modal and navigator_selection_modal.has_method("open_modal"):
		navigator_selection_modal.open_modal()


func _on_pet_modal_closed() -> void:
	if equipment_cards:
		equipment_cards.refresh_pet_display(current_character_id)
	if focus_router:
		focus_router.restore_companion_modal_focus(pet_button, orbital_terminal)


func _on_navigator_modal_closed() -> void:
	if equipment_cards:
		equipment_cards.refresh_navigator_display(current_character_id)
	if focus_router:
		focus_router.restore_companion_modal_focus(navigator_button, orbital_terminal)


func _on_pet_selected(pet_id: StringName) -> void:
	if skin_coordinator:
		skin_coordinator.handle_pet_selected(pet_id, current_character_id)
	if equipment_cards:
		equipment_cards.refresh_pet_display(current_character_id)


func _on_pet_skin_equipped(_slot_key: String, skin_id: String) -> void:
	if skin_coordinator:
		skin_coordinator.handle_pet_skin_equipped(skin_id, current_character_id)
	if equipment_cards:
		equipment_cards.refresh_pet_display(current_character_id)


func _refresh_pet_display() -> void:
	if equipment_cards:
		equipment_cards.refresh_pet_display(&"")


func _refresh_navigator_display() -> void:
	if equipment_cards:
		equipment_cards.refresh_navigator_display(&"")


func _on_navigator_selected(nav_id: StringName) -> void:
	if skin_coordinator:
		skin_coordinator.handle_navigator_selected(nav_id, current_character_id)
	if equipment_cards:
		equipment_cards.refresh_navigator_display(current_character_id)


func _on_navigator_skin_equipped(_slot_key: String, skin_id: String) -> void:
	if skin_coordinator:
		skin_coordinator.handle_navigator_skin_equipped(skin_id, current_character_id)
	if equipment_cards:
		equipment_cards.refresh_navigator_display(current_character_id)


func _open_skin_modal(category: String, target_id: String, target_name: String, preview_texture: Texture2D = null) -> void:
	if not skin_selection_modal:
		return
	_save_current_focus()
	skin_selection_modal.open_skin_modal(category, target_id, target_name, preview_texture)


func _on_skins_button_pressed() -> void:
	if skin_coordinator:
		skin_coordinator.open_pilot_customization(current_character_id)


func _on_cosmetic_carousel_closed(category: String, _target_id: StringName, skin_id: String) -> void:
	if skin_coordinator:
		skin_coordinator.handle_cosmetic_carousel_closed(category, _target_id, skin_id, current_character_id)


func _open_gacha_from_skins() -> void:
	if skin_coordinator:
		skin_coordinator.open_gacha_from_skins()


func _on_skin_selected(slot_key: String, skin_id: String) -> void:
	if skin_coordinator:
		skin_coordinator.handle_skin_selected(slot_key, skin_id, current_character_id)


func _on_gacha_skin_equipped(slot_key: String, skin_id: String) -> void:
	_on_skin_selected(slot_key, skin_id)


func _on_skin_modal_closed() -> void:
	_restore_last_focus()
	_select_character(current_character_id)


func _on_gacha_modal_closed() -> void:
	_restore_last_focus()
	_select_character(current_character_id)


func _restore_last_focus() -> void:
	if focus_router:
		focus_router.restore_focus(pilot_button, orbital_terminal)


func _on_launch_committed() -> void:
	if launch_controller:
		launch_controller.commit_launch(current_character_id, get_tree())


func _on_loadout_pressed() -> void:
	if modal_router:
		modal_router.open_loadout(current_character_id, get_viewport(), focus_router)


func _on_arsenal_banlist_modal_closed() -> void:
	if modal_router:
		modal_router.restore_modal_closed_focus(arsenal_banlist_btn, focus_router, orbital_terminal)


func _on_weapon_modal_closed() -> void:
	if modal_router:
		modal_router.restore_modal_closed_focus(loadout_button, focus_router, orbital_terminal)


func _on_tome_modal_closed() -> void:
	if modal_router:
		modal_router.restore_modal_closed_focus(tomes_pool_btn, focus_router, orbital_terminal)


func _on_back_pressed() -> void:
	if hero_picker_modal and not hero_picker_modal.is_open:
		_on_dock_unified_button_pressed()
	else:
		_exit_to_hub()


func _exit_to_hub() -> void:
	if launch_controller:
		launch_controller.exit_to_hub(get_tree(), speed_selector)


func _setup_speed_buttons() -> void:
	if speed_selector:
		speed_selector.setup(speed_1x_btn, speed_2x_btn, speed_4x_btn)


func _setup_focus_mesh() -> void:
	if focus_router:
		focus_router.setup_focus_mesh(
			back_button, ship_button, weapon_button, pet_button, navigator_button,
			expand_talents_btn, arsenal_banlist_btn, tomes_pool_btn, loadout_button,
			speed_1x_btn, speed_2x_btn, speed_4x_btn, pilot_skin_btn, orbital_terminal
		)


func _on_dock_unified_button_pressed() -> void:
	if hero_picker_modal:
		if main_margin_container:
			main_margin_container.visible = false
		if abilities_view:
			abilities_view.visible = false
		if dock_container:
			dock_container.visible = false
		hero_picker_modal.open_picker(roster_ordered, current_character_id, false)


func _on_hero_confirmed(char_id: StringName) -> void:
	if hero_picker_modal and hero_picker_modal.is_open:
		hero_picker_modal.close_picker()
	if main_margin_container:
		main_margin_container.visible = true
	if abilities_view:
		abilities_view.visible = true
	if dock_container:
		dock_container.visible = true
	if dock_margin:
		dock_margin.visible = false
	if dock_unified_button:
		dock_unified_button.visible = false
	if orbital_terminal:
		orbital_terminal.visible = true
	_select_character(char_id)
	if ship_button and ship_button.is_inside_tree() and ship_button.is_visible_in_tree():
		ship_button.call_deferred("grab_focus")
	elif orbital_terminal and orbital_terminal.is_inside_tree() and orbital_terminal.is_visible_in_tree():
		orbital_terminal.call_deferred("grab_focus")


func _on_hero_cancelled() -> void:
	if hero_picker_modal and not hero_picker_modal.is_initial_entry:
		if main_margin_container:
			main_margin_container.visible = true
		if dock_container:
			dock_container.visible = true
		if orbital_terminal:
			orbital_terminal.visible = true
		return
	_exit_to_hub()


func _set_game_speed(speed: float) -> void:
	if speed_selector:
		speed_selector.set_game_speed(speed)


func _refresh_speed_buttons_ui() -> void:
	if speed_selector:
		speed_selector.refresh_ui()


func _on_debug_pressed() -> void:
	if not is_debug_active or not debug_menu_modal:
		return
	if modal_router:
		modal_router.open_debug(roster_dict.get(current_character_id, null), get_viewport(), focus_router)


func _on_debug_modal_closed() -> void:
	_restore_last_focus()


func _on_pilot_button_pressed() -> void:
	_on_skins_button_pressed()


func _exit_tree() -> void:
	if pilot_showcase and pilot_showcase.has_method("cleanup"):
		pilot_showcase.cleanup()

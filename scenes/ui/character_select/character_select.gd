class_name CharacterSelectUI
extends Control

## CharacterSelectUI.gd
## Controlador orquestador modular de la interfaz de Selección de Personajes.
## Delega presentación, cartas de equipamiento, modales, escaparate y navegación
## en sus componentes especializados correspondientes.

const CharacterPilotShowcase = preload("res://scenes/ui/character_select/components/character_pilot_showcase.gd")
const CharacterEquipmentCards = preload("res://scenes/ui/character_select/components/character_equipment_cards.gd")
const CharacterSpeedSelector = preload("res://scenes/ui/character_select/components/character_speed_selector.gd")
const CharacterSkinCoordinator = preload("res://scenes/ui/character_select/components/character_skin_coordinator.gd")
const CharacterFocusRouter = preload("res://scenes/ui/character_select/components/character_focus_router.gd")
const CharacterSelectLaunchController = preload("res://scenes/ui/character_select/components/character_select_launch_controller.gd")
const CharacterSelectDisplayManager = preload("res://scenes/ui/character_select/components/character_select_display_manager.gd")
const CharacterSelectModalRouter = preload("res://scenes/ui/character_select/components/character_select_modal_router.gd")
const CharacterSelectTabController = preload("res://scenes/ui/character_select/components/character_select_tab_controller.gd")
const CharacterRosterGridBuilder = preload("res://scenes/ui/character_select/components/character_roster_grid_builder.gd")

const DebugManagerScript = preload("res://core/autoloads/debug_manager.gd")

const DEBUG_MENU_AVAILABLE: bool = true

var is_debug_active: bool:
	get:
		var dm = Engine.get_singleton("DebugManager") if Engine.has_singleton("DebugManager") else get_node_or_null("/root/DebugManager")
		return OS.is_debug_build() and DEBUG_MENU_AVAILABLE and (dm.is_debug_enabled() if dm else false)

# Componentes especializados
var pilot_showcase: CharacterPilotShowcase = null
var equipment_cards: CharacterEquipmentCards = null
var speed_selector: CharacterSpeedSelector = null
var skin_coordinator: CharacterSkinCoordinator = null
var focus_router: CharacterFocusRouter = null
var launch_controller: CharacterSelectLaunchController = null
var display_manager: CharacterSelectDisplayManager = null
var modal_router: CharacterSelectModalRouter = null
var tab_controller: CharacterSelectTabController = null

# Nodos raíz / estructurales
@onready var main_margin_container: MarginContainer = $MarginContainer
@onready var root_vbox: VBoxContainer = $MarginContainer/RootVBox
@onready var back_button: Button = $MarginContainer/RootVBox/HeaderBar/BackButton
@onready var loadout_view: VBoxContainer = $MarginContainer/RootVBox/MainWorkspace/LeftCommandPanel/TabContentPanel/TabMargin/TwoColumnWorkspace/LoadoutView
@onready var abilities_view: VBoxContainer = $MarginContainer/RootVBox/MainWorkspace/RightShowcaseArea/AbilitiesView
@onready var dock_container: PanelContainer = (get_node_or_null("DockContainer") as PanelContainer) if get_node_or_null("DockContainer") else (get_node_or_null("MarginContainer/RootVBox/DockContainer") as PanelContainer)
@onready var orbital_terminal: OrbitalIgnitionTerminal = (get_node_or_null("DockContainer/TerminalCenter/OrbitalIgnitionTerminal") as OrbitalIgnitionTerminal) if get_node_or_null("DockContainer/TerminalCenter/OrbitalIgnitionTerminal") else (get_node_or_null("MarginContainer/RootVBox/DockContainer/TerminalCenter/OrbitalIgnitionTerminal") as OrbitalIgnitionTerminal)
@onready var dock_margin: MarginContainer = (get_node_or_null("DockContainer/DockMargin") as MarginContainer) if get_node_or_null("DockContainer/DockMargin") else (get_node_or_null("MarginContainer/RootVBox/DockContainer/DockMargin") as MarginContainer)
@onready var char_list_container: HBoxContainer = (get_node_or_null("DockContainer/DockMargin/CharList") as HBoxContainer) if get_node_or_null("DockContainer/DockMargin/CharList") else (get_node_or_null("MarginContainer/RootVBox/DockContainer/DockMargin/CharList") as HBoxContainer)
@onready var dock_unified_button: Button = (get_node_or_null("DockContainer/DockUnifiedButton") as Button) if get_node_or_null("DockContainer/DockUnifiedButton") else (get_node_or_null("MarginContainer/RootVBox/DockContainer/DockUnifiedButton") as Button)
@onready var pilot_skin_btn: Button = $MarginContainer/RootVBox/MainWorkspace/RightShowcaseArea/HeroIdentityBox/PilotSkinButton
@onready var arsenal_banlist_btn: Button = get_node_or_null("MarginContainer/RootVBox/MainWorkspace/LeftCommandPanel/TabContentPanel/TabMargin/TwoColumnWorkspace/LoadoutView/TomesCard/TomesMargin/TomesVBox/ArsenalBanlistBtn")
@onready var tomes_pool_btn: Button = get_node_or_null("MarginContainer/RootVBox/MainWorkspace/LeftCommandPanel/TabContentPanel/TabMargin/TwoColumnWorkspace/LoadoutView/TomesCard/TomesMargin/TomesVBox/TomesActionsHBox/TomesPoolBtn")

# Getters delegados hacia componentes para compatibilidad y tests
var name_label: Label:
	get:
		return display_manager.name_label if display_manager else null
var title_label: Label:
	get:
		return display_manager.title_label if display_manager else null
var biomass_label: Label:
	get:
		return display_manager.biomass_label if display_manager else null
var antimatter_label: Label:
	get:
		return display_manager.antimatter_label if display_manager else null
var dark_matter_label: Label:
	get:
		return display_manager.dark_matter_label if display_manager else null
var expand_talents_btn: Button:
	get:
		return display_manager.expand_talents_btn if display_manager else null
var loadout_button: Button:
	get:
		return display_manager.loadout_button if display_manager else null
var weapon_block_icon: TextureRect:
	get:
		return display_manager.weapon_block_icon if display_manager else null
var weapon_block_tag: Label:
	get:
		return display_manager.weapon_block_tag if display_manager else null
var weapon_block_title: Label:
	get:
		return display_manager.weapon_block_title if display_manager else null
var weapon_block_desc: Label:
	get:
		return display_manager.weapon_block_desc if display_manager else null
var tactical_block_icon: TextureRect:
	get:
		return display_manager.tactical_block_icon if display_manager else null
var tactical_block_tag: Label:
	get:
		return display_manager.tactical_block_tag if display_manager else null
var tactical_block_title: Label:
	get:
		return display_manager.tactical_block_title if display_manager else null
var tactical_block_desc: Label:
	get:
		return display_manager.tactical_block_desc if display_manager else null
var dash_block_icon: TextureRect:
	get:
		return display_manager.dash_block_icon if display_manager else null
var dash_block_tag: Label:
	get:
		return display_manager.dash_block_tag if display_manager else null
var dash_block_title: Label:
	get:
		return display_manager.dash_block_title if display_manager else null
var dash_block_desc: Label:
	get:
		return display_manager.dash_block_desc if display_manager else null
var passive_block_icon: TextureRect:
	get:
		return display_manager.passive_block_icon if display_manager else null
var passive_block_tag: Label:
	get:
		return display_manager.passive_block_tag if display_manager else null
var passive_block_title: Label:
	get:
		return display_manager.passive_block_title if display_manager else null
var passive_block_desc: Label:
	get:
		return display_manager.passive_block_desc if display_manager else null

var fullbody_texture: TextureRect:
	get:
		return pilot_showcase.fullbody_texture if pilot_showcase else null
var backlight_glow: TextureRect:
	get:
		return pilot_showcase.backlight_glow if pilot_showcase else null
var pilot_button: Button:
	get:
		return pilot_showcase.pilot_button if pilot_showcase else null

var ship_card: PanelContainer:
	get:
		return equipment_cards.ship_card if equipment_cards else null
var ship_icon: TextureRect:
	get:
		return equipment_cards.ship_icon if equipment_cards else null
var ship_name: Label:
	get:
		return equipment_cards.ship_name if equipment_cards else null
var ship_button: Button:
	get:
		return equipment_cards.ship_button if equipment_cards else null
var weapon_card: PanelContainer:
	get:
		return equipment_cards.weapon_card if equipment_cards else null
var weapon_icon: TextureRect:
	get:
		return equipment_cards.weapon_icon if equipment_cards else null
var weapon_name: Label:
	get:
		return equipment_cards.weapon_name if equipment_cards else null
var weapon_button: Button:
	get:
		return equipment_cards.weapon_button if equipment_cards else null
var pet_card: PanelContainer:
	get:
		return equipment_cards.pet_card if equipment_cards else null
var pet_icon: TextureRect:
	get:
		return equipment_cards.pet_icon if equipment_cards else null
var pet_name: Label:
	get:
		return equipment_cards.pet_name if equipment_cards else null
var pet_desc: Label:
	get:
		return equipment_cards.pet_desc if equipment_cards else null
var pet_button: Button:
	get:
		return equipment_cards.pet_button if equipment_cards else null
var navigator_card: PanelContainer:
	get:
		return equipment_cards.navigator_card if equipment_cards else null
var navigator_icon: TextureRect:
	get:
		return equipment_cards.navigator_icon if equipment_cards else null
var navigator_name: Label:
	get:
		return equipment_cards.navigator_name if equipment_cards else null
var navigator_desc: Label:
	get:
		return equipment_cards.navigator_desc if equipment_cards else null
var navigator_button: Button:
	get:
		return equipment_cards.navigator_button if equipment_cards else null

var speed_1x_btn: Button:
	get:
		return speed_selector.speed_1x_btn if speed_selector else null
var speed_2x_btn: Button:
	get:
		return speed_selector.speed_2x_btn if speed_selector else null
var speed_4x_btn: Button:
	get:
		return speed_selector.speed_4x_btn if speed_selector else null

var hero_picker_modal: Node:
	get:
		return modal_router.hero_picker_modal if modal_router else null
var character_skill_tree_modal: Node:
	get:
		return modal_router.character_skill_tree_modal if modal_router else null
var cosmetic_carousel_modal: Node:
	get:
		return modal_router.cosmetic_carousel_modal if modal_router else null
var gacha_modal: Node:
	get:
		return modal_router.gacha_modal if modal_router else null
var pet_selection_modal: Node:
	get:
		return modal_router.pet_selection_modal if modal_router else null
var navigator_selection_modal: Node:
	get:
		return modal_router.navigator_selection_modal if modal_router else null
var tome_selection_modal: Node:
	get:
		return modal_router.tome_selection_modal if modal_router else null
var weapon_selection_modal: Node:
	get:
		return modal_router.weapon_selection_modal if modal_router else null
var arsenal_banlist_modal: Node:
	get:
		return modal_router.arsenal_banlist_modal if modal_router else null
var debug_menu_modal: Node:
	get:
		return modal_router.debug_menu_modal if modal_router else null

# Propiedades de compatibilidad con versiones previas
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
var tab_loadout_btn: Button = null
var tab_abilities_btn: Button = null
var tab_talents_btn: Button:
	get:
		return tab_abilities_btn
var tab_tomes_btn: Button:
	get:
		return tab_abilities_btn
var tab_stats_btn: Button:
	get:
		return tab_abilities_btn
var talents_metrics_label: Label = null
var favored_tome_desc: Label = null

var current_game_speed: float:
	get: return speed_selector.current_game_speed if speed_selector else 1.0
	set(val):
		if speed_selector:
			speed_selector.current_game_speed = val

var current_character_id: StringName = &"nova"
var roster_dict: Dictionary[StringName, CharacterData] = {}
var roster_ordered: Array[CharacterData] = []
var _dock_card_buttons: Dictionary[StringName, Button] = {}


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
	tab_controller = CharacterSelectTabController.new()

	_init_components()
	_setup_signals()

	roster_dict = CharacterData.load_roster()
	skin_coordinator.setup_from_root(self, roster_dict, Callable(self, "_select_character"), Callable(self, "_save_current_focus"), Callable(self, "_restore_last_focus"))
	roster_ordered = roster_dict.values()
	roster_ordered.sort_custom(func(a: CharacterData, b: CharacterData): return a.sort_order < b.sort_order)

	_populate_roster()
	var saved_char: StringName = SaveManager.get_selected_character()
	_select_character(saved_char if not saved_char.is_empty() and roster_dict.has(saved_char) else &"nova")

	_update_ability_tags()
	_refresh_telemetry_ui()
	if tab_controller:
		tab_controller.setup(tab_loadout_btn, tab_abilities_btn, loadout_view, abilities_view)

	_configure_dock_and_initial_view()


func _init_components() -> void:
	pilot_showcase.setup_from_root(self, Callable(self, "_on_pilot_button_pressed"))
	equipment_cards.setup_from_root(self, Callable(self, "_on_ship_card_pressed"), Callable(self, "_on_weapon_card_pressed"), Callable(self, "_on_pet_card_pressed"), Callable(self, "_on_navigator_card_pressed"))
	display_manager.setup_from_root(self)
	speed_selector.setup_from_root(self)
	modal_router.setup_from_root(self)
	modal_router.connect_modal_signals(self)


func _configure_dock_and_initial_view() -> void:
	if dock_margin: dock_margin.visible = false
	if dock_unified_button:
		dock_unified_button.visible = false
		dock_unified_button.pressed.connect(_on_dock_unified_button_pressed)
	if dock_container: dock_container.visible = false
	if orbital_terminal: orbital_terminal.visible = false
	if back_button: back_button.text = "← [ESC] HUB"

	if hero_picker_modal:
		hero_picker_modal.hero_confirmed.connect(_on_hero_confirmed)
		hero_picker_modal.hero_cancelled.connect(_on_hero_cancelled)
		if main_margin_container: main_margin_container.visible = false
		hero_picker_modal.open_picker(roster_ordered, current_character_id, true)


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


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		if _has_any_modal_open(): return
		get_viewport().set_input_as_handled()
		_on_back_pressed()
	elif event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER):
		if _has_any_modal_open(): return
		if orbital_terminal and orbital_terminal.is_visible_in_tree() and not orbital_terminal.disabled:
			get_viewport().set_input_as_handled()
			if orbital_terminal.has_method("_on_pressed"): orbital_terminal._on_pressed()
			else: _on_launch_committed()


func _unhandled_input(event: InputEvent) -> void:
	if _has_any_modal_open(): return
	if is_debug_active and (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1):
		_on_debug_pressed()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		if speed_selector and speed_selector.handle_shortcut(event.keycode):
			get_viewport().set_input_as_handled()


func _has_any_modal_open() -> bool:
	return modal_router.has_any_modal_open() if modal_router else false


func _populate_roster() -> void:
	CharacterRosterGridBuilder.populate_roster(char_list_container, roster_ordered, _dock_card_buttons, func(cid: StringName) -> void:
		_select_character(cid)
		if hero_picker_modal:
			if main_margin_container: main_margin_container.visible = false
			hero_picker_modal.open_picker(roster_ordered, cid, false)
	)
	_setup_focus_mesh()


func _select_character(char_id: StringName) -> void:
	current_character_id = char_id
	SaveManager.set_selected_character(char_id)
	var data: CharacterData = roster_dict.get(char_id, null)
	if not data:
		roster_dict = CharacterData.load_roster()
		data = roster_dict.get(char_id, null)
	if not data: return

	skin_coordinator.apply_heroine_loadout(char_id)
	var is_unlocked: bool = SaveManager.is_character_unlocked(char_id)

	if display_manager:
		display_manager.update_character_identity(data)
		display_manager.update_character_abilities(data)
		display_manager.update_dock_highlights(char_id, _dock_card_buttons, roster_dict)
		display_manager.update_terminal_lock_state(is_unlocked)
		display_manager.refresh_telemetry_ui()
		display_manager.refresh_talents_summary(char_id)
		display_manager.update_ability_tags()

	if equipment_cards: equipment_cards.update_equipment(data, char_id)
	if pilot_showcase: pilot_showcase.update_pilot_display(data, char_id, is_unlocked)
	_setup_focus_mesh()


func _setup_focus_mesh() -> void:
	if focus_router:
		focus_router.setup_focus_mesh(back_button, ship_button, weapon_button, pet_button, navigator_button, expand_talents_btn, arsenal_banlist_btn, tomes_pool_btn, loadout_button, speed_1x_btn, speed_2x_btn, speed_4x_btn, pilot_skin_btn, orbital_terminal)


func _on_hero_confirmed(char_id: StringName) -> void:
	if hero_picker_modal and hero_picker_modal.is_open: hero_picker_modal.close_picker()
	if main_margin_container: main_margin_container.visible = true
	if abilities_view: abilities_view.visible = true
	if dock_container: dock_container.visible = true
	if dock_margin: dock_margin.visible = false
	if dock_unified_button: dock_unified_button.visible = false
	if orbital_terminal: orbital_terminal.visible = true
	_select_character(char_id)
	if ship_button and ship_button.is_inside_tree() and ship_button.is_visible_in_tree():
		ship_button.call_deferred("grab_focus")
	elif orbital_terminal and orbital_terminal.is_inside_tree() and orbital_terminal.is_visible_in_tree():
		orbital_terminal.call_deferred("grab_focus")


func _on_hero_cancelled() -> void:
	if hero_picker_modal and not hero_picker_modal.is_initial_entry:
		if main_margin_container: main_margin_container.visible = true
		if dock_container: dock_container.visible = true
		if orbital_terminal: orbital_terminal.visible = true
		return
	_exit_to_hub()


func _exit_to_hub() -> void:
	if launch_controller: launch_controller.exit_to_hub(get_tree(), speed_selector)


func _on_back_pressed() -> void: _exit_to_hub()
func _on_launch_committed() -> void: if launch_controller: launch_controller.commit_launch(current_character_id, get_tree())
func _update_ability_tags() -> void: if display_manager: display_manager.update_ability_tags()
func _refresh_telemetry_ui() -> void: if display_manager: display_manager.refresh_telemetry_ui()
func _save_current_focus() -> void: if focus_router: focus_router.save_focus(get_viewport())
func _restore_last_focus() -> void: if focus_router: focus_router.restore_focus(pilot_button, orbital_terminal)

func _on_expand_talents_pressed() -> void: if modal_router: modal_router.open_talents(current_character_id, get_viewport(), focus_router)
func _on_arsenal_banlist_pressed(default_tab: int = 0) -> void: if modal_router: modal_router.open_arsenal_banlist(current_character_id, default_tab, get_viewport(), focus_router)
func _on_tomes_pool_pressed() -> void: if modal_router: modal_router.open_tomes_pool(current_character_id, get_viewport(), focus_router)
func _on_loadout_pressed() -> void: if modal_router: modal_router.open_loadout(current_character_id, get_viewport(), focus_router)

func _on_ship_card_pressed() -> void: if skin_coordinator: skin_coordinator.open_ship_customization(current_character_id)
func _on_ship_skin_pressed() -> void: _on_ship_card_pressed()
func _on_weapon_card_pressed() -> void: if skin_coordinator: skin_coordinator.open_weapon_customization(current_character_id)
func _on_pilot_button_pressed() -> void: _on_skins_button_pressed()
func _on_pilot_skin_pressed() -> void: _on_skins_button_pressed()
func _on_skins_button_pressed() -> void: if skin_coordinator: skin_coordinator.open_pilot_customization(current_character_id)

func _on_pet_card_pressed() -> void:
	if focus_router: focus_router.set_last_focused(pet_button if pet_button else get_viewport().gui_get_focus_owner())
	if pet_selection_modal and pet_selection_modal.has_method("open_modal"): pet_selection_modal.open_modal()

func _on_navigator_card_pressed() -> void:
	if focus_router: focus_router.set_last_focused(navigator_button if navigator_button else get_viewport().gui_get_focus_owner())
	if navigator_selection_modal and navigator_selection_modal.has_method("open_modal"): navigator_selection_modal.open_modal()

func _on_pet_modal_closed() -> void:
	if equipment_cards: equipment_cards.refresh_pet_display(current_character_id)
	if focus_router: focus_router.restore_companion_modal_focus(pet_button, orbital_terminal)

func _on_navigator_modal_closed() -> void:
	if equipment_cards: equipment_cards.refresh_navigator_display(current_character_id)
	if focus_router: focus_router.restore_companion_modal_focus(navigator_button, orbital_terminal)

func _on_pet_selected(pet_id: StringName) -> void:
	if skin_coordinator: skin_coordinator.handle_pet_selected(pet_id, current_character_id)
	if equipment_cards: equipment_cards.refresh_pet_display(current_character_id)

func _on_pet_skin_equipped(_slot_key: String, skin_id: String) -> void:
	if skin_coordinator: skin_coordinator.handle_pet_skin_equipped(skin_id, current_character_id)
	if equipment_cards: equipment_cards.refresh_pet_display(current_character_id)

func _on_navigator_selected(nav_id: StringName) -> void:
	if skin_coordinator: skin_coordinator.handle_navigator_selected(nav_id, current_character_id)
	if equipment_cards: equipment_cards.refresh_navigator_display(current_character_id)

func _on_navigator_skin_equipped(_slot_key: String, skin_id: String) -> void:
	if skin_coordinator: skin_coordinator.handle_navigator_skin_equipped(skin_id, current_character_id)
	if equipment_cards: equipment_cards.refresh_navigator_display(current_character_id)

func _on_cosmetic_carousel_closed(category: String, _target_id: StringName, skin_id: String) -> void:
	if skin_coordinator: skin_coordinator.handle_cosmetic_carousel_closed(category, _target_id, skin_id, current_character_id)

func _on_skin_selected(slot_key: String, skin_id: String) -> void:
	if skin_coordinator: skin_coordinator.handle_skin_selected(slot_key, skin_id, current_character_id)

func _on_gacha_skin_equipped(slot_key: String, skin_id: String) -> void: _on_skin_selected(slot_key, skin_id)
func _on_gacha_modal_closed() -> void: _restore_last_focus(); _select_character(current_character_id)
func _on_skill_tree_closed() -> void: _refresh_telemetry_ui(); if display_manager: display_manager.refresh_talents_summary(current_character_id); _restore_last_focus()
func _on_arsenal_banlist_modal_closed() -> void: if modal_router: modal_router.restore_modal_closed_focus(arsenal_banlist_btn, focus_router, orbital_terminal)
func _on_weapon_modal_closed() -> void: if modal_router: modal_router.restore_modal_closed_focus(loadout_button, focus_router, orbital_terminal)
func _on_tome_modal_closed() -> void: if modal_router: modal_router.restore_modal_closed_focus(tomes_pool_btn, focus_router, orbital_terminal)
func _on_debug_modal_closed() -> void: _restore_last_focus()
func _on_debug_pressed() -> void: if is_debug_active and modal_router: modal_router.open_debug(roster_dict.get(current_character_id, null), get_viewport(), focus_router)
func _on_dock_unified_button_pressed() -> void:
	if hero_picker_modal:
		if main_margin_container: main_margin_container.visible = false
		if abilities_view: abilities_view.visible = false
		if dock_container: dock_container.visible = false
		hero_picker_modal.open_picker(roster_ordered, current_character_id, false)

func _exit_tree() -> void:
	if pilot_showcase and pilot_showcase.has_method("cleanup"):
		pilot_showcase.cleanup()

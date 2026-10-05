class_name CharacterSelectUI
extends Control

const CharacterPilotShowcase = preload("res://scenes/ui/character_select/components/character_pilot_showcase.gd")
const CharacterEquipmentCards = preload("res://scenes/ui/character_select/components/character_equipment_cards.gd")
const CharacterSpeedSelector = preload("res://scenes/ui/character_select/components/character_speed_selector.gd")

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
@onready var abilities_view: VBoxContainer = $MarginContainer/RootVBox/MainWorkspace/LeftCommandPanel/TabContentPanel/TabMargin/TwoColumnWorkspace/AbilitiesView

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
@onready var tomes_pool_btn: Button = $MarginContainer/RootVBox/MainWorkspace/LeftCommandPanel/TabContentPanel/TabMargin/TwoColumnWorkspace/LoadoutView/TomesCard/TomesMargin/TomesVBox/TomesActionsHBox/TomesPoolBtn
@onready var loadout_button: Button = $MarginContainer/RootVBox/MainWorkspace/LeftCommandPanel/TabContentPanel/TabMargin/TwoColumnWorkspace/LoadoutView/TomesCard/TomesMargin/TomesVBox/TomesActionsHBox/LoadoutButton

@onready var speed_1x_btn: Button = $MarginContainer/RootVBox/MainWorkspace/LeftCommandPanel/TabContentPanel/TabMargin/TwoColumnWorkspace/LoadoutView/SpeedCard/SpeedMargin/SpeedVBox/SpeedRow/Speed1xBtn
@onready var speed_2x_btn: Button = $MarginContainer/RootVBox/MainWorkspace/LeftCommandPanel/TabContentPanel/TabMargin/TwoColumnWorkspace/LoadoutView/SpeedCard/SpeedMargin/SpeedVBox/SpeedRow/Speed2xBtn
@onready var speed_4x_btn: Button = $MarginContainer/RootVBox/MainWorkspace/LeftCommandPanel/TabContentPanel/TabMargin/TwoColumnWorkspace/LoadoutView/SpeedCard/SpeedMargin/SpeedVBox/SpeedRow/Speed4xBtn

# Bloques de Habilidades (Columna Habilidades)
@onready var weapon_block_icon: TextureRect = $MarginContainer/RootVBox/MainWorkspace/LeftCommandPanel/TabContentPanel/TabMargin/TwoColumnWorkspace/AbilitiesView/WeaponBlock/WeaponMargin/WeaponRow/WeaponBlockIcon
@onready var weapon_block_tag: Label = $MarginContainer/RootVBox/MainWorkspace/LeftCommandPanel/TabContentPanel/TabMargin/TwoColumnWorkspace/AbilitiesView/WeaponBlock/WeaponMargin/WeaponRow/WeaponBlockVBox/WeaponBlockTag
@onready var weapon_block_title: Label = $MarginContainer/RootVBox/MainWorkspace/LeftCommandPanel/TabContentPanel/TabMargin/TwoColumnWorkspace/AbilitiesView/WeaponBlock/WeaponMargin/WeaponRow/WeaponBlockVBox/WeaponBlockTitle
@onready var weapon_block_desc: Label = $MarginContainer/RootVBox/MainWorkspace/LeftCommandPanel/TabContentPanel/TabMargin/TwoColumnWorkspace/AbilitiesView/WeaponBlock/WeaponMargin/WeaponRow/WeaponBlockVBox/WeaponBlockDesc

@onready var tactical_block_icon: TextureRect = $MarginContainer/RootVBox/MainWorkspace/LeftCommandPanel/TabContentPanel/TabMargin/TwoColumnWorkspace/AbilitiesView/TacticalBlock/TacticalMargin/TacticalRow/TacticalBlockIcon
@onready var tactical_block_tag: Label = $MarginContainer/RootVBox/MainWorkspace/LeftCommandPanel/TabContentPanel/TabMargin/TwoColumnWorkspace/AbilitiesView/TacticalBlock/TacticalMargin/TacticalRow/TacticalBlockVBox/TacticalBlockTag
@onready var tactical_block_title: Label = $MarginContainer/RootVBox/MainWorkspace/LeftCommandPanel/TabContentPanel/TabMargin/TwoColumnWorkspace/AbilitiesView/TacticalBlock/TacticalMargin/TacticalRow/TacticalBlockVBox/TacticalBlockTitle
@onready var tactical_block_desc: Label = $MarginContainer/RootVBox/MainWorkspace/LeftCommandPanel/TabContentPanel/TabMargin/TwoColumnWorkspace/AbilitiesView/TacticalBlock/TacticalMargin/TacticalRow/TacticalBlockVBox/TacticalBlockDesc

@onready var dash_block_icon: TextureRect = $MarginContainer/RootVBox/MainWorkspace/LeftCommandPanel/TabContentPanel/TabMargin/TwoColumnWorkspace/AbilitiesView/DashBlock/DashMargin/DashRow/DashBlockIcon
@onready var dash_block_tag: Label = $MarginContainer/RootVBox/MainWorkspace/LeftCommandPanel/TabContentPanel/TabMargin/TwoColumnWorkspace/AbilitiesView/DashBlock/DashMargin/DashRow/DashBlockVBox/DashBlockTag
@onready var dash_block_title: Label = $MarginContainer/RootVBox/MainWorkspace/LeftCommandPanel/TabContentPanel/TabMargin/TwoColumnWorkspace/AbilitiesView/DashBlock/DashMargin/DashRow/DashBlockVBox/DashBlockTitle
@onready var dash_block_desc: Label = $MarginContainer/RootVBox/MainWorkspace/LeftCommandPanel/TabContentPanel/TabMargin/TwoColumnWorkspace/AbilitiesView/DashBlock/DashMargin/DashRow/DashBlockVBox/DashBlockDesc

@onready var passive_block_icon: TextureRect = $MarginContainer/RootVBox/MainWorkspace/LeftCommandPanel/TabContentPanel/TabMargin/TwoColumnWorkspace/AbilitiesView/PassiveBlock/PassiveMargin/PassiveRow/PassiveBlockIcon
@onready var passive_block_tag: Label = $MarginContainer/RootVBox/MainWorkspace/LeftCommandPanel/TabContentPanel/TabMargin/TwoColumnWorkspace/AbilitiesView/PassiveBlock/PassiveMargin/PassiveRow/PassiveBlockVBox/PassiveBlockTag
@onready var passive_block_title: Label = $MarginContainer/RootVBox/MainWorkspace/LeftCommandPanel/TabContentPanel/TabMargin/TwoColumnWorkspace/AbilitiesView/PassiveBlock/PassiveMargin/PassiveRow/PassiveBlockVBox/PassiveBlockTitle
@onready var passive_block_desc: Label = $MarginContainer/RootVBox/MainWorkspace/LeftCommandPanel/TabContentPanel/TabMargin/TwoColumnWorkspace/AbilitiesView/PassiveBlock/PassiveMargin/PassiveRow/PassiveBlockVBox/PassiveBlockDesc

var tab_loadout_btn: Button = null
var tab_abilities_btn: Button = null
var talents_metrics_label: Label = null
var favored_tome_desc: Label = null

# Barra de Mando Persistente
@onready var launch_button: Button = $MarginContainer/RootVBox/MainWorkspace/LeftCommandPanel/CommandBar/LaunchButton

# Dock Inferior de Selección
@onready var char_list_container: HBoxContainer = $MarginContainer/RootVBox/DockContainer/DockMargin/CharList

# Modales
@onready var debug_menu_modal = get_node_or_null("DebugMenuModal")
@onready var pet_selection_modal = get_node_or_null("PetSelectionModal")
@onready var navigator_selection_modal = get_node_or_null("NavigatorSelectionModal")
@onready var skin_selection_modal = get_node_or_null("SkinSelectionModal")
@onready var gacha_modal = get_node_or_null("GachaModal")
@onready var tome_selection_modal = get_node_or_null("TomeSelectionModal")
@onready var character_skill_tree_modal = get_node_or_null("CharacterSkillTreeModal")

var pilot_showcase: CharacterPilotShowcase = null
var equipment_cards: CharacterEquipmentCards = null
var speed_selector: CharacterSpeedSelector = null

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


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	pilot_showcase = CharacterPilotShowcase.new()
	equipment_cards = CharacterEquipmentCards.new()
	speed_selector = CharacterSpeedSelector.new()

	_setup_subcomponents()
	_setup_tabs()
	_setup_signals()
	_setup_speed_buttons()

	roster_dict = CharacterData.load_roster()
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
	back_button.pressed.connect(_on_back_pressed)
	launch_button.pressed.connect(_on_launch_pressed)
	if pilot_skin_btn:
		pilot_skin_btn.pressed.connect(_on_skins_button_pressed)

	var settings_mgr: Node = get_node_or_null("/root/SettingsManager")
	if settings_mgr and settings_mgr.has_signal("settings_changed"):
		settings_mgr.settings_changed.connect(_update_ability_tags)

	if expand_talents_btn:
		expand_talents_btn.pressed.connect(_on_expand_talents_pressed)
	if tomes_pool_btn:
		tomes_pool_btn.pressed.connect(_on_tomes_pool_pressed)
	if loadout_button:
		loadout_button.pressed.connect(_on_loadout_pressed)

	if pet_selection_modal and pet_selection_modal.has_signal("pet_selected"):
		pet_selection_modal.pet_selected.connect(_on_pet_selected)
	if navigator_selection_modal and navigator_selection_modal.has_signal("navigator_selected"):
		navigator_selection_modal.navigator_selected.connect(_on_navigator_selected)

	if debug_menu_modal and debug_menu_modal.has_signal("closed"):
		debug_menu_modal.closed.connect(_on_debug_modal_closed)

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

	if character_skill_tree_modal and character_skill_tree_modal.has_signal("modal_closed"):
		character_skill_tree_modal.modal_closed.connect(_on_skill_tree_closed)
	elif character_skill_tree_modal and character_skill_tree_modal.has_signal("closed"):
		character_skill_tree_modal.closed.connect(_on_skill_tree_closed)


func _unhandled_input(event: InputEvent) -> void:
	if debug_menu_modal and debug_menu_modal.get("is_open"):
		return
	if pet_selection_modal and pet_selection_modal.get("is_open"):
		return
	if navigator_selection_modal and navigator_selection_modal.get("is_open"):
		return
	if skin_selection_modal and skin_selection_modal.get("is_open"):
		return
	if gacha_modal and gacha_modal.visible:
		return
	if tome_selection_modal and tome_selection_modal.get("is_open"):
		return
	if character_skill_tree_modal and character_skill_tree_modal.visible:
		return

	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		_on_launch_pressed()
		get_viewport().set_input_as_handled()
	elif is_debug_active and (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1):
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
		if not is_unlocked and cid == &"nyx":
			continue

		var card_btn := Button.new()
		card_btn.name = "PilotCard_%s" % cid
		card_btn.custom_minimum_size = Vector2(76, 76)
		card_btn.focus_mode = Control.FOCUS_ALL

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

		# Icono del avatar con expand_icon = true para encajar exactamente en el botón cuadrado
		card_btn.icon = char_data.get_avatar_texture()
		card_btn.expand_icon = true
		card_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card_btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		card_btn.tooltip_text = char_data.display_name.to_upper()
		card_btn.text = ""

		card_btn.pivot_offset = Vector2(38, 38)
		card_btn.pressed.connect(func(): _select_character(cid))
		card_btn.focus_entered.connect(func(): _select_character(cid))

		# Hover feedback: escala suave 1.08x centrada (sin alterar position.y para evitar desalineación)
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

	if first_btn:
		first_btn.grab_focus()


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

	# Dossier táctico sin emojis
	name_label.text = data.display_name.to_upper()
	name_label.modulate = data.color
	title_label.text = data.title

	# Actualizar bloques de la pestaña de Habilidades
	var kit: Dictionary = data.get_kit_dossier() if data.has_method("get_kit_dossier") else {}
	if not kit.is_empty():
		if weapon_block_title:
			weapon_block_title.text = kit.weapon_name
		if weapon_block_desc:
			weapon_block_desc.text = kit.weapon_desc
		if tactical_block_title:
			tactical_block_title.text = kit.tactical_name
		if tactical_block_desc:
			tactical_block_desc.text = kit.tactical_desc
		if dash_block_title:
			dash_block_title.text = kit.dash_name
		if dash_block_desc:
			dash_block_desc.text = kit.dash_desc
		if passive_block_title:
			passive_block_title.text = kit.passive_name
		if passive_block_desc:
			passive_block_desc.text = kit.passive_desc
		if favored_tome_desc:
			var f_tome: StringName = kit.get("favored_tome", &"")
			var p_desc: String = kit.get("passive_desc", "")
			favored_tome_desc.text = "%s — Sinergia: %s" % [String(f_tome), p_desc]

	if weapon_block_icon:
		weapon_block_icon.texture = data.get_weapon_texture()
	if tactical_block_icon:
		tactical_block_icon.texture = preload("res://assets/sprites/ui/laser_ability_icon.png")
	if dash_block_icon:
		dash_block_icon.texture = preload("res://assets/sprites/ui/dash_ability_icon.png")
	if passive_block_icon:
		passive_block_icon.texture = preload("res://assets/sprites/ui/biomass_dna_icon.png")

	_refresh_talents_summary(char_id)

	var is_unlocked: bool = SaveManager.is_character_unlocked(char_id)

	if equipment_cards:
		equipment_cards.update_equipment(data, char_id)
	if pilot_showcase:
		pilot_showcase.update_pilot_display(data, char_id, is_unlocked)

	# Actualizar resaltados en el dock inferior
	for cid: StringName in _dock_card_buttons.keys():
		var btn: Button = _dock_card_buttons[cid]
		var is_current := (cid == char_id)
		var c_data: CharacterData = roster_dict.get(cid, null)
		var c_unlocked := SaveManager.is_character_unlocked(cid)
		var sb := btn.get_theme_stylebox("normal")
		if sb is StyleBoxFlat:
			var dup := sb.duplicate() as StyleBoxFlat
			dup.border_width_left = 2
			dup.border_width_top = 2
			dup.border_width_right = 2
			dup.border_width_bottom = 2
			if is_current:
				dup.border_color = c_data.color if c_data else Color(0, 1, 0.85, 1)
				dup.bg_color = Color(0.04, 0.08, 0.12, 0.96)
			else:
				dup.border_color = (c_data.color * Color(1, 1, 1, 0.4) if c_unlocked else Color(0.2, 0.25, 0.3, 0.5)) if c_data else Color(0.2, 0.4, 0.6, 0.5)
				dup.bg_color = Color(0.025, 0.04, 0.07, 0.92)
			btn.add_theme_stylebox_override("normal", dup)

	# Estado de lanzamiento
	if not is_unlocked:
		launch_button.disabled = true
		launch_button.text = "PILOTO BLOQUEADA // REQUIERE AUTORIZACIÓN"
		if loadout_button:
			loadout_button.disabled = true
	else:
		launch_button.disabled = false
		launch_button.text = "DESPLEGAR // ASALTO ORBITAL [ENTER]"
		if loadout_button:
			loadout_button.disabled = false

	_refresh_telemetry_ui()
	_refresh_talents_summary(char_id)
	_update_ability_tags()


func _get_action_key_text(act: StringName) -> String:
	var events := InputMap.action_get_events(act)
	for ev in events:
		if ev is InputEventKey:
			var txt: String = ev.as_text_physical_keycode() if ev.physical_keycode != 0 else ev.as_text_keycode()
			return txt.to_upper()
		elif ev is InputEventMouseButton:
			match ev.button_index:
				MOUSE_BUTTON_LEFT: return "CLIC IZQ"
				MOUSE_BUTTON_RIGHT: return "CLIC DER"
				MOUSE_BUTTON_MIDDLE: return "CLIC CEN"
				_: return "RATÓN %d" % ev.button_index
	return "N/A"


func _update_ability_tags() -> void:
	if weapon_block_tag:
		weapon_block_tag.text = "[AUTO / PASIVO] // ARMA PRINCIPAL"
	if tactical_block_tag:
		tactical_block_tag.text = "[%s] // HABILIDAD TÁCTICA" % _get_action_key_text(&"fire_active")
	if dash_block_tag:
		dash_block_tag.text = "[%s] // PROPULSIÓN EVASIVA" % _get_action_key_text(&"dash")
	if passive_block_tag:
		passive_block_tag.text = "[INNATA] // AFINIDAD DE TOMO"


func _refresh_telemetry_ui() -> void:
	if biomass_label:
		biomass_label.text = "BIOMASA: %s" % String.num_int64(SaveManager.get_biomass())
	if antimatter_label:
		antimatter_label.text = "ANTIMATERIA: %s" % String.num_int64(SaveManager.get_antimatter())
	if dark_matter_label:
		dark_matter_label.text = "MATERIA OSCURA: %s" % String.num_int64(SaveManager.get_dark_matter())


func _refresh_talents_summary(char_id: StringName) -> void:
	var unlocked_nodes := SaveManager.get_character_unlocked_nodes(char_id)
	if expand_talents_btn:
		expand_talents_btn.text = "[ÁRBOL DE TALENTOS] (%d/24)" % unlocked_nodes.size()
	if talents_metrics_label:
		talents_metrics_label.text = "NODOS ACTIVOS: %d / 24 | BIOMASA DISPONIBLE: %s" % [
			unlocked_nodes.size(),
			String.num_int64(SaveManager.get_biomass())
		]


func _on_expand_talents_pressed() -> void:
	if character_skill_tree_modal and character_skill_tree_modal.has_method("open_for_character"):
		_last_focused_control = get_viewport().gui_get_focus_owner()
		character_skill_tree_modal.open_for_character(current_character_id)


func _on_skill_tree_closed() -> void:
	_refresh_telemetry_ui()
	_refresh_talents_summary(current_character_id)
	_restore_last_focus()


func _on_tomes_pool_pressed() -> void:
	if tome_selection_modal and tome_selection_modal.has_method("open_modal"):
		_last_focused_control = get_viewport().gui_get_focus_owner()
		tome_selection_modal.open_modal(current_character_id)


func _on_ship_card_pressed() -> void:
	var char_data: CharacterData = roster_dict.get(current_character_id, null)
	var char_name: String = char_data.display_name if char_data else "Exo-Traje"
	var preview_tex: Texture2D = char_data.get_ship_texture() if char_data else null
	_open_skin_modal("ship", String(current_character_id), "%s - Exo-Traje" % char_name, preview_tex)


func _on_ship_skin_pressed() -> void:
	_on_ship_card_pressed()


func _on_pilot_skin_pressed() -> void:
	_on_skins_button_pressed()


func _on_weapon_card_pressed() -> void:
	var char_data: CharacterData = roster_dict.get(current_character_id, null)
	var wpn_name: String = char_data.starting_weapon.weapon_name if char_data and char_data.starting_weapon else "Arma"
	var preview_tex: Texture2D = char_data.get_weapon_texture() if char_data else null
	_open_skin_modal("weapon", String(current_character_id), "%s - Armamento" % wpn_name, preview_tex)


func _on_pet_card_pressed() -> void:
	if pet_selection_modal and pet_selection_modal.has_method("open_modal"):
		_last_focused_control = get_viewport().gui_get_focus_owner()
		pet_selection_modal.open_modal()


func _on_navigator_card_pressed() -> void:
	if navigator_selection_modal and navigator_selection_modal.has_method("open_modal"):
		_last_focused_control = get_viewport().gui_get_focus_owner()
		navigator_selection_modal.open_modal()


func _on_pet_selected(pet_id: StringName) -> void:
	SaveManager.set_selected_pet(pet_id)
	# Guardar en el loadout de la heroína actual
	var loadout: Dictionary = SaveManager.get_character_loadout(current_character_id)
	loadout["selected_pet"] = String(pet_id)
	SaveManager.set_character_loadout(current_character_id, loadout)
	if equipment_cards:
		equipment_cards.refresh_pet_display(current_character_id)


func _on_navigator_selected(nav_id: StringName) -> void:
	SaveManager.set_selected_navigator(nav_id)
	# Guardar en el loadout de la heroína actual
	var loadout: Dictionary = SaveManager.get_character_loadout(current_character_id)
	loadout["selected_navigator"] = String(nav_id)
	SaveManager.set_character_loadout(current_character_id, loadout)
	if equipment_cards:
		equipment_cards.refresh_navigator_display(current_character_id)


func _open_skin_modal(category: String, target_id: String, target_name: String, preview_texture: Texture2D = null) -> void:
	if not skin_selection_modal:
		return
	_last_focused_control = get_viewport().gui_get_focus_owner()
	skin_selection_modal.open_skin_modal(category, target_id, target_name, preview_texture)


func _on_skins_button_pressed() -> void:
	var data: CharacterData = roster_dict.get(current_character_id, null)
	if data:
		var fb: Texture2D = data.get_selection_texture(false) if data.has_method("get_selection_texture") else data.get_fullbody_texture(false)
		if not fb:
			fb = data.get_portrait_texture()
		_open_skin_modal("pilot", String(current_character_id), data.display_name, fb)
	elif gacha_modal:
		_last_focused_control = get_viewport().gui_get_focus_owner()
		gacha_modal.open_gacha_modal()


func _open_gacha_from_skins() -> void:
	if not gacha_modal:
		return
	_last_focused_control = get_viewport().gui_get_focus_owner()
	gacha_modal.open_gacha_modal()
	gacha_modal._switch_tab(0)


func _on_skin_selected(_slot_key: String, _skin_id: String) -> void:
	_select_character(current_character_id)


func _on_gacha_skin_equipped(_slot_key: String, _skin_id: String) -> void:
	_select_character(current_character_id)


func _on_skin_modal_closed() -> void:
	_restore_last_focus()
	_select_character(current_character_id)


func _on_gacha_modal_closed() -> void:
	_restore_last_focus()
	_select_character(current_character_id)


func _restore_last_focus() -> void:
	if _last_focused_control and is_instance_valid(_last_focused_control) and _last_focused_control != pilot_button and _last_focused_control.is_inside_tree() and _last_focused_control.is_visible_in_tree():
		_last_focused_control.grab_focus()
	elif launch_button and launch_button.is_visible_in_tree():
		launch_button.grab_focus()


func _on_launch_pressed() -> void:
	if not SaveManager.is_character_unlocked(current_character_id):
		return
	SaveManager.set_selected_character(current_character_id)
	get_tree().call_deferred("change_scene_to_file", "res://scenes/combat/main_game.tscn")


func _on_loadout_pressed() -> void:
	get_tree().call_deferred("change_scene_to_file", "res://scenes/ui/hangar_banlist_ui.tscn")


func _on_tome_modal_closed() -> void:
	var target_focus: Control = null
	if tomes_pool_btn and tomes_pool_btn.is_visible_in_tree():
		target_focus = tomes_pool_btn
	elif _last_focused_control and is_instance_valid(_last_focused_control) and _last_focused_control.is_inside_tree() and _last_focused_control.is_visible_in_tree():
		target_focus = _last_focused_control
	elif launch_button and launch_button.is_visible_in_tree():
		target_focus = launch_button

	if target_focus:
		target_focus.grab_focus()


func _on_back_pressed() -> void:
	_set_game_speed(1.0)
	get_tree().call_deferred("change_scene_to_file", "res://scenes/ui/hub/hub_world.tscn")


func _setup_speed_buttons() -> void:
	if speed_selector:
		speed_selector.setup(speed_1x_btn, speed_2x_btn, speed_4x_btn)


func _set_game_speed(speed: float) -> void:
	if speed_selector:
		speed_selector.set_game_speed(speed)


func _refresh_speed_buttons_ui() -> void:
	if speed_selector:
		speed_selector.refresh_ui()


func _on_debug_pressed() -> void:
	if not is_debug_active or not debug_menu_modal:
		return
	_last_focused_control = get_viewport().gui_get_focus_owner()
	var char_data: CharacterData = roster_dict.get(current_character_id, null)
	debug_menu_modal.open_menu(char_data)


func _on_debug_modal_closed() -> void:
	_restore_last_focus()


func _on_pilot_button_pressed() -> void:
	_on_skins_button_pressed()

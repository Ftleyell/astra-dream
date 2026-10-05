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
# CONFIGURACIÓN DE DEBUG (Gobernado centralmente por DebugManager)
# ==============================================================================
const DEBUG_MENU_AVAILABLE: bool = true

var is_debug_active: bool:
	get:
		return DEBUG_MENU_AVAILABLE and (DebugManager.is_debug_enabled() if DebugManager else false)
# ==============================================================================

@onready var char_list_container: VBoxContainer = $MarginContainer/RootVBox/MainColumns/LeftPanel/CharScroll/CharList
@onready var name_label: Label = $MarginContainer/RootVBox/MainColumns/CenterPanel/DossierHeader/NameLabel
@onready var title_label: Label = $MarginContainer/RootVBox/MainColumns/CenterPanel/DossierHeader/ClassTitleLabel
@onready var desc_label: Label = $MarginContainer/RootVBox/MainColumns/CenterPanel/DescBox/DescLabel
@onready var stats_label: Label = $MarginContainer/RootVBox/MainColumns/CenterPanel/StatsBox/StatsLabel

@onready var ship_card: PanelContainer = get_node_or_null("MarginContainer/RootVBox/MainColumns/CenterPanel/EquipmentBox/EquipRow/ShipCard") as PanelContainer
@onready var ship_icon: TextureRect = $MarginContainer/RootVBox/MainColumns/CenterPanel/EquipmentBox/EquipRow/ShipCard/ShipBox/ShipIcon
@onready var ship_name: Label = $MarginContainer/RootVBox/MainColumns/CenterPanel/EquipmentBox/EquipRow/ShipCard/ShipBox/ShipLabelVBox/ShipName
@onready var ship_button: Button = get_node_or_null("MarginContainer/RootVBox/MainColumns/CenterPanel/EquipmentBox/EquipRow/ShipCard/ShipButton") as Button

@onready var weapon_card: PanelContainer = get_node_or_null("MarginContainer/RootVBox/MainColumns/CenterPanel/EquipmentBox/EquipRow/WeaponCard") as PanelContainer
@onready var weapon_icon: TextureRect = $MarginContainer/RootVBox/MainColumns/CenterPanel/EquipmentBox/EquipRow/WeaponCard/WeaponBox/WeaponIcon
@onready var weapon_name: Label = $MarginContainer/RootVBox/MainColumns/CenterPanel/EquipmentBox/EquipRow/WeaponCard/WeaponBox/WeaponLabelVBox/WeaponName
@onready var weapon_button: Button = get_node_or_null("MarginContainer/RootVBox/MainColumns/CenterPanel/EquipmentBox/EquipRow/WeaponCard/WeaponButton") as Button

@onready var pet_card: PanelContainer = get_node_or_null("MarginContainer/RootVBox/MainColumns/CenterPanel/PetCard") as PanelContainer
@onready var pet_icon: TextureRect = get_node_or_null("MarginContainer/RootVBox/MainColumns/CenterPanel/PetCard/PetBox/PetIcon") as TextureRect
@onready var pet_name: Label = get_node_or_null("MarginContainer/RootVBox/MainColumns/CenterPanel/PetCard/PetBox/PetLabelVBox/PetName") as Label
@onready var pet_desc: Label = get_node_or_null("MarginContainer/RootVBox/MainColumns/CenterPanel/PetCard/PetBox/PetLabelVBox/PetDesc") as Label
@onready var pet_button: Button = get_node_or_null("MarginContainer/RootVBox/MainColumns/CenterPanel/PetCard/PetButton") as Button
@onready var pet_selection_modal = get_node_or_null("PetSelectionModal")

@onready var navigator_card: PanelContainer = get_node_or_null("MarginContainer/RootVBox/MainColumns/CenterPanel/NavigatorCard") as PanelContainer
@onready var navigator_icon: TextureRect = get_node_or_null("MarginContainer/RootVBox/MainColumns/CenterPanel/NavigatorCard/NavigatorBox/NavigatorIcon") as TextureRect
@onready var navigator_name: Label = get_node_or_null("MarginContainer/RootVBox/MainColumns/CenterPanel/NavigatorCard/NavigatorBox/NavigatorLabelVBox/NavigatorName") as Label
@onready var navigator_desc: Label = get_node_or_null("MarginContainer/RootVBox/MainColumns/CenterPanel/NavigatorCard/NavigatorBox/NavigatorLabelVBox/NavigatorDesc") as Label
@onready var navigator_button: Button = get_node_or_null("MarginContainer/RootVBox/MainColumns/CenterPanel/NavigatorCard/NavigatorButton") as Button
@onready var navigator_selection_modal = get_node_or_null("NavigatorSelectionModal")

@onready var pilot_button: Button = get_node_or_null("MarginContainer/RootVBox/MainColumns/RightPanel/PilotButton") as Button
@onready var fullbody_texture: TextureRect = $MarginContainer/RootVBox/MainColumns/RightPanel/FullbodyTexture
@onready var backlight_glow: TextureRect = get_node_or_null("MarginContainer/RootVBox/MainColumns/RightPanel/BacklightGlow") as TextureRect

@onready var skin_selection_modal = get_node_or_null("SkinSelectionModal")
@onready var gacha_modal = get_node_or_null("GachaModal")
@onready var debug_menu_modal = get_node_or_null("DebugMenuModal")
@onready var tome_selection_modal = get_node_or_null("TomeSelectionModal")

@onready var launch_button: Button = $MarginContainer/RootVBox/MainColumns/CenterPanel/ActionsRow/LaunchButton
@onready var loadout_button: Button = $MarginContainer/RootVBox/MainColumns/CenterPanel/ActionsRow/LoadoutButton
@onready var debug_button: Button = get_node_or_null("MarginContainer/RootVBox/MainColumns/CenterPanel/ActionsRow/DebugButton") as Button
@onready var back_button: Button = $MarginContainer/RootVBox/HeaderBar/BackButton

@onready var speed_1x_btn: Button = get_node_or_null("MarginContainer/RootVBox/MainColumns/CenterPanel/SpeedRow/Speed1xBtn")
@onready var speed_2x_btn: Button = get_node_or_null("MarginContainer/RootVBox/MainColumns/CenterPanel/SpeedRow/Speed2xBtn")
@onready var speed_4x_btn: Button = get_node_or_null("MarginContainer/RootVBox/MainColumns/CenterPanel/SpeedRow/Speed4xBtn")

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
		return pilot_button
var skins_button: Button:
	get:
		return null

var characters_data: Dictionary:
	get:
		if roster_dict.is_empty():
			roster_dict = CharacterData.load_roster()
		var d := {}
		for k in roster_dict.keys():
			var c: CharacterData = roster_dict[k]
			if c:
				d[k] = {
					"name": c.display_name,
					"title": c.title,
					"desc": c.description,
					"stats": c.get_formatted_stats(),
					"color": c.color,
					"pts": c.pts
				}
		return d


func _ready() -> void:
	roster_ordered = CharacterData.load_roster_ordered()
	roster_dict = CharacterData.load_roster()

	_init_components()
	_populate_roster()

	var saved_char := SaveManager.get_selected_character()
	if roster_dict.has(saved_char) and SaveManager.is_character_unlocked(saved_char):
		_select_character(saved_char)
	elif not roster_ordered.is_empty():
		_select_character(roster_ordered[0].character_id)
	else:
		_select_character(&"nova")

	UIFocusHelper.apply_cyber_focus(launch_button)
	UIFocusHelper.apply_cyber_focus(loadout_button)
	UIFocusHelper.apply_cyber_focus(back_button)

	if debug_button:
		if is_debug_active:
			UIFocusHelper.apply_cyber_focus(debug_button)
			debug_button.pressed.connect(_on_debug_pressed)
		else:
			debug_button.queue_free()
			debug_button = null
			if debug_menu_modal:
				debug_menu_modal.queue_free()
				debug_menu_modal = null

	launch_button.pressed.connect(_on_launch_pressed)
	loadout_button.pressed.connect(_on_loadout_pressed)
	back_button.pressed.connect(_on_back_pressed)

	_connect_modal_signals()


func _init_components() -> void:
	pilot_showcase = CharacterPilotShowcase.new()
	pilot_showcase.setup(fullbody_texture, backlight_glow, pilot_button, Callable(self, "_on_pilot_skin_pressed"))

	equipment_cards = CharacterEquipmentCards.new()
	equipment_cards.setup_ship_and_weapon(
		ship_card, ship_icon, ship_name, ship_button, Callable(self, "_on_ship_skin_pressed"),
		weapon_card, weapon_icon, weapon_name, weapon_button, Callable(self, "_on_weapon_skin_pressed")
	)
	equipment_cards.setup_companions(
		pet_card, pet_icon, pet_name, pet_desc, pet_button, Callable(self, "_on_pet_card_pressed"),
		navigator_card, navigator_icon, navigator_name, navigator_desc, navigator_button, Callable(self, "_on_navigator_card_pressed")
	)

	speed_selector = CharacterSpeedSelector.new()
	speed_selector.setup(speed_1x_btn, speed_2x_btn, speed_4x_btn)

	var right_panel: Control = get_node_or_null("MarginContainer/RootVBox/MainColumns/RightPanel") as Control
	if right_panel:
		right_panel.mouse_filter = Control.MOUSE_FILTER_PASS


func _connect_modal_signals() -> void:
	if pet_selection_modal and pet_selection_modal.has_signal("pet_selected"):
		pet_selection_modal.pet_selected.connect(_on_pet_selected)
	if pet_selection_modal and pet_selection_modal.has_signal("skin_equipped"):
		pet_selection_modal.skin_equipped.connect(func(_slot, _sid): _refresh_pet_display())
	if pet_selection_modal and pet_selection_modal.has_signal("closed"):
		pet_selection_modal.closed.connect(_on_pet_modal_closed)

	if navigator_selection_modal and navigator_selection_modal.has_signal("navigator_selected"):
		navigator_selection_modal.navigator_selected.connect(_on_navigator_selected)
	if navigator_selection_modal and navigator_selection_modal.has_signal("skin_equipped"):
		navigator_selection_modal.skin_equipped.connect(func(_slot, _sid): _refresh_navigator_display())
	if navigator_selection_modal and navigator_selection_modal.has_signal("closed"):
		navigator_selection_modal.closed.connect(_on_navigator_modal_closed)

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

	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_C:
		_on_loadout_pressed()
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

	var first_btn: Button = null
	var prev_btn: Button = null

	for char_data in roster_ordered:
		var cid: StringName = char_data.character_id
		var is_unlocked: bool = SaveManager.is_character_unlocked(cid)
		# Personaje secreto (Nyx): no mostrar en la lista hasta desbloquearse
		if not is_unlocked and cid == &"nyx":
			continue
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(400, 84)
		if is_unlocked:
			btn.text = "   %s\n   %s" % [char_data.display_name.to_upper(), char_data.title]
		else:
			btn.text = "   🔒 %s\n   %s (BLOQUEADA)" % [char_data.display_name.to_upper(), char_data.title]
			btn.modulate = Color(0.65, 0.65, 0.75, 0.75)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(func():
			_select_character(cid)
		)
		btn.focus_entered.connect(func(): _select_character(cid))

		var icon_tex := char_data.get_portrait_texture()
		if icon_tex:
			btn.icon = icon_tex
			btn.expand_icon = true

		UIFocusHelper.apply_cyber_focus(btn)
		char_list_container.add_child(btn)

		if loadout_button:
			btn.focus_neighbor_right = loadout_button.get_path()

		if not first_btn:
			first_btn = btn

		if prev_btn:
			prev_btn.focus_neighbor_bottom = btn.get_path()
			btn.focus_neighbor_top = prev_btn.get_path()
		prev_btn = btn

	if prev_btn:
		prev_btn.focus_neighbor_bottom = first_btn.get_path()
		first_btn.focus_neighbor_top = prev_btn.get_path()

	_setup_action_row_navigation(first_btn)

	if first_btn:
		first_btn.grab_focus()


func _setup_action_row_navigation(first_btn: Button) -> void:
	loadout_button.focus_neighbor_left = first_btn.get_path() if first_btn else NodePath("")
	if debug_button and debug_button.visible:
		loadout_button.focus_neighbor_right = debug_button.get_path()
		debug_button.focus_neighbor_left = loadout_button.get_path()
		debug_button.focus_neighbor_right = launch_button.get_path()
		launch_button.focus_neighbor_left = debug_button.get_path()
	else:
		loadout_button.focus_neighbor_right = launch_button.get_path()
		launch_button.focus_neighbor_left = loadout_button.get_path()

	launch_button.focus_neighbor_top = back_button.get_path()
	back_button.focus_neighbor_bottom = launch_button.get_path()

	if pet_button:
		pet_button.focus_neighbor_left = first_btn.get_path() if first_btn else NodePath("")
		pet_button.focus_neighbor_top = launch_button.get_path()
		loadout_button.focus_neighbor_bottom = pet_button.get_path()
		if debug_button and debug_button.visible:
			debug_button.focus_neighbor_bottom = pet_button.get_path()
		launch_button.focus_neighbor_bottom = pet_button.get_path()

	if navigator_button:
		navigator_button.focus_neighbor_left = first_btn.get_path() if first_btn else NodePath("")
		if pet_button:
			pet_button.focus_neighbor_bottom = navigator_button.get_path()
			navigator_button.focus_neighbor_top = pet_button.get_path()
		else:
			navigator_button.focus_neighbor_top = launch_button.get_path()

	if pilot_button:
		pilot_button.focus_mode = Control.FOCUS_NONE


func _select_character(char_id: StringName) -> void:
	current_character_id = char_id
	SaveManager.set_selected_character(char_id)
	var data: CharacterData = roster_dict.get(char_id, null)
	if not data:
		roster_dict = CharacterData.load_roster()
		data = roster_dict.get(char_id, null)
	if not data:
		return

	# Dossier textual enriquecido
	name_label.text = data.display_name.to_upper()
	name_label.modulate = data.color
	title_label.text = data.title

	var kit: Dictionary = data.get_kit_dossier() if data.has_method("get_kit_dossier") else {}
	var dossier_text: String = ""
	if not kit.is_empty():
		dossier_text += "⚔️ ARMA INICIAL: %s\n%s\n\n" % [kit.weapon_name, kit.weapon_desc]
		dossier_text += "🎯 HABILIDAD TÁCTICA: %s\n%s\n\n" % [kit.tactical_name, kit.tactical_desc]
		dossier_text += "⚡ MANIOBRA DASH: %s\n%s\n\n" % [kit.dash_name, kit.dash_desc]
		dossier_text += "📖 CUALIDAD INNATA: %s\n%s\n\n" % [kit.passive_name, kit.passive_desc]
		dossier_text += "📝 PERFIL: %s" % data.description
	else:
		dossier_text = data.description

	desc_label.text = dossier_text
	stats_label.text = data.get_formatted_stats()

	var is_unlocked: bool = SaveManager.is_character_unlocked(char_id)

	# Delegar equipamiento y escaparate de piloto
	if equipment_cards:
		equipment_cards.update_equipment(data, char_id)
	if pilot_showcase:
		pilot_showcase.update_pilot_display(data, char_id, is_unlocked)

	if not is_unlocked:
		if launch_button:
			launch_button.disabled = true
			launch_button.text = "PILOTO BLOQUEADO"
		if loadout_button:
			loadout_button.disabled = true
		if char_id == &"nyx":
			var career := SaveManager.get_career_stats()
			var bosses := int(career.get("total_bosses_killed", 0))
			desc_label.text = "🔒 DESBLOQUEO DE CARRERA ESPACIAL:\nDerrota a 10 Jefes Titanes en combate para sincronizar a Nyx.\nProgreso de carrera: [ %d / 10 ] Jefes Eliminados.\n\n%s" % [bosses, dossier_text]
		else:
			desc_label.text = "🔒 PILOTO BLOQUEADA:\nRequiere desbloqueo en la campaña galáctica.\n\n%s" % dossier_text
	else:
		if launch_button:
			launch_button.disabled = false
			launch_button.text = "INICIAR RUN"
		if loadout_button:
			loadout_button.disabled = false


func _refresh_pet_display() -> void:
	if equipment_cards:
		equipment_cards.refresh_pet_display()


func _on_pet_card_pressed() -> void:
	if pet_selection_modal and pet_selection_modal.has_method("open_modal"):
		_last_focused_control = get_viewport().gui_get_focus_owner()
		pet_selection_modal.open_modal()


func _on_pet_selected(_pid: StringName) -> void:
	_refresh_pet_display()


func _refresh_navigator_display() -> void:
	if equipment_cards:
		equipment_cards.refresh_navigator_display()


func _on_navigator_card_pressed() -> void:
	if navigator_selection_modal and navigator_selection_modal.has_method("open_modal"):
		_last_focused_control = get_viewport().gui_get_focus_owner()
		navigator_selection_modal.open_modal()


func _on_navigator_selected(_nid: StringName) -> void:
	_refresh_navigator_display()


func _on_pet_modal_closed() -> void:
	var target_focus: Control = null
	if pet_button and pet_button.is_visible_in_tree():
		target_focus = pet_button
	elif _last_focused_control and is_instance_valid(_last_focused_control) and _last_focused_control.is_inside_tree() and _last_focused_control.is_visible_in_tree():
		target_focus = _last_focused_control
	elif launch_button and launch_button.is_visible_in_tree():
		target_focus = launch_button

	if target_focus:
		target_focus.grab_focus()


func _on_navigator_modal_closed() -> void:
	var target_focus: Control = null
	if navigator_button and navigator_button.is_visible_in_tree():
		target_focus = navigator_button
	elif _last_focused_control and is_instance_valid(_last_focused_control) and _last_focused_control.is_inside_tree() and _last_focused_control.is_visible_in_tree():
		target_focus = _last_focused_control
	elif launch_button and launch_button.is_visible_in_tree():
		target_focus = launch_button

	if target_focus:
		target_focus.grab_focus()


func _setup_card_hover_feedback(btn: Button, card: PanelContainer, glow_color: Color) -> void:
	if equipment_cards:
		equipment_cards.setup_card_hover_feedback(btn, card, glow_color)


func _open_skin_modal(category: String, target_id: String, display_title: String, default_tex: Texture2D) -> void:
	if not skin_selection_modal:
		return
	_last_focused_control = get_viewport().gui_get_focus_owner()
	skin_selection_modal.open_for_target(category, target_id, display_title, default_tex)


func _on_ship_skin_pressed() -> void:
	var data: CharacterData = roster_dict.get(current_character_id, null)
	if data:
		_open_skin_modal("ship", String(current_character_id), "%s Mark I" % data.display_name, data.get_ship_texture())


func _on_weapon_skin_pressed() -> void:
	var data: CharacterData = roster_dict.get(current_character_id, null)
	if data:
		_open_skin_modal("weapon", String(current_character_id), "Arma de %s" % data.display_name, data.get_weapon_texture())


func _on_pilot_skin_pressed() -> void:
	var data: CharacterData = roster_dict.get(current_character_id, null)
	if data:
		var fb := data.get_fullbody_texture(false)
		if not fb:
			fb = data.get_selection_texture(false) if data.has_method("get_selection_texture") else data.get_portrait_texture()
		_open_skin_modal("pilot", String(current_character_id), data.display_name, fb)


func _on_pet_skin_pressed() -> void:
	var sel_pid := SaveManager.get_selected_pet()
	const PetDataScript := preload("res://data/pets/pet_data.gd")
	var pet_res = PetDataScript.get_pet(sel_pid)
	if pet_res:
		_open_skin_modal("pet", String(sel_pid), pet_res.display_name, pet_res.get_icon_texture())


func _on_navigator_skin_pressed() -> void:
	var sel_nid := SaveManager.get_selected_navigator()
	const NavigatorDataScript := preload("res://data/navigators/navigator_data.gd")
	var nav_res = NavigatorDataScript.get_navigator(sel_nid)
	if nav_res:
		_open_skin_modal("navigator", String(sel_nid), nav_res.display_name, nav_res.get_portrait_texture())


func _on_skins_button_pressed() -> void:
	var data: CharacterData = roster_dict.get(current_character_id, null)
	if data:
		var fb := data.get_fullbody_texture(false)
		if not fb:
			fb = data.get_selection_texture(false) if data.has_method("get_selection_texture") else data.get_portrait_texture()
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
	if tome_selection_modal and tome_selection_modal.has_method("open_modal"):
		_last_focused_control = get_viewport().gui_get_focus_owner()
		tome_selection_modal.open_modal(current_character_id)
	else:
		get_tree().call_deferred("change_scene_to_file", "res://scenes/ui/hangar_banlist_ui.tscn")


func _on_tome_modal_closed() -> void:
	var target_focus: Control = null
	if loadout_button and loadout_button.is_visible_in_tree():
		target_focus = loadout_button
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
	var target_focus: Control = null
	if _last_focused_control and is_instance_valid(_last_focused_control) and _last_focused_control.is_inside_tree() and _last_focused_control.is_visible_in_tree():
		target_focus = _last_focused_control
	elif debug_button and debug_button.is_visible_in_tree():
		target_focus = debug_button
	elif launch_button and launch_button.is_visible_in_tree():
		target_focus = launch_button

	if target_focus:
		target_focus.grab_focus()
		var target_pos: Vector2 = target_focus.get_global_rect().get_center()
		get_viewport().warp_mouse(target_pos)


func _on_pilot_button_pressed() -> void:
	if pilot_showcase:
		pilot_showcase.on_button_pressed()


func _on_character_art_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_on_pilot_button_pressed()
		get_viewport().set_input_as_handled()


func _on_character_art_clicked() -> void:
	_on_pilot_button_pressed()

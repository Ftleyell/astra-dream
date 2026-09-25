class_name CharacterSelectUI
extends Control

@onready var char_list_container: VBoxContainer = $MarginContainer/RootVBox/MainColumns/LeftPanel/CharScroll/CharList
@onready var name_label: Label = $MarginContainer/RootVBox/MainColumns/CenterPanel/DossierHeader/NameLabel
@onready var title_label: Label = $MarginContainer/RootVBox/MainColumns/CenterPanel/DossierHeader/ClassTitleLabel
@onready var desc_label: Label = $MarginContainer/RootVBox/MainColumns/CenterPanel/DescBox/DescLabel
@onready var stats_label: Label = $MarginContainer/RootVBox/MainColumns/CenterPanel/StatsBox/StatsLabel

@onready var ship_icon: TextureRect = $MarginContainer/RootVBox/MainColumns/CenterPanel/EquipmentBox/EquipRow/ShipCard/ShipBox/ShipIcon
@onready var ship_name: Label = $MarginContainer/RootVBox/MainColumns/CenterPanel/EquipmentBox/EquipRow/ShipCard/ShipBox/ShipLabelVBox/ShipName
@onready var weapon_icon: TextureRect = $MarginContainer/RootVBox/MainColumns/CenterPanel/EquipmentBox/EquipRow/WeaponCard/WeaponBox/WeaponIcon
@onready var weapon_name: Label = $MarginContainer/RootVBox/MainColumns/CenterPanel/EquipmentBox/EquipRow/WeaponCard/WeaponBox/WeaponLabelVBox/WeaponName
@onready var pet_card: PanelContainer = get_node_or_null("MarginContainer/RootVBox/MainColumns/CenterPanel/PetCard") as PanelContainer
@onready var pet_icon: TextureRect = get_node_or_null("MarginContainer/RootVBox/MainColumns/CenterPanel/PetCard/PetBox/PetIcon") as TextureRect
@onready var pet_name: Label = get_node_or_null("MarginContainer/RootVBox/MainColumns/CenterPanel/PetCard/PetBox/PetLabelVBox/PetName") as Label
@onready var pet_desc: Label = get_node_or_null("MarginContainer/RootVBox/MainColumns/CenterPanel/PetCard/PetBox/PetLabelVBox/PetDesc") as Label
@onready var pet_button: Button = get_node_or_null("MarginContainer/RootVBox/MainColumns/CenterPanel/PetCard/PetButton") as Button
@onready var pet_selection_modal = get_node_or_null("PetSelectionModal")

# ==============================================================================
# CONFIGURACIÓN DE DEBUG (Comentar o cambiar a false para desactivar en builds)
# ==============================================================================
const DEBUG_MENU_AVAILABLE: bool = true
# ==============================================================================

const DebugMenuModalScript := preload("res://scenes/ui/debug/debug_menu_modal.gd")

@onready var launch_button: Button = $MarginContainer/RootVBox/MainColumns/CenterPanel/ActionsRow/LaunchButton
@onready var loadout_button: Button = $MarginContainer/RootVBox/MainColumns/CenterPanel/ActionsRow/LoadoutButton
@onready var debug_button: Button = get_node_or_null("MarginContainer/RootVBox/MainColumns/CenterPanel/ActionsRow/DebugButton") as Button
@onready var debug_menu_modal = get_node_or_null("DebugMenuModal")
@onready var back_button: Button = $MarginContainer/RootVBox/HeaderBar/BackButton
@onready var fullbody_texture: TextureRect = $MarginContainer/RootVBox/MainColumns/RightPanel/FullbodyTexture

@onready var speed_1x_btn: Button = get_node_or_null("MarginContainer/RootVBox/MainColumns/CenterPanel/SpeedRow/Speed1xBtn")
@onready var speed_2x_btn: Button = get_node_or_null("MarginContainer/RootVBox/MainColumns/CenterPanel/SpeedRow/Speed2xBtn")
@onready var speed_4x_btn: Button = get_node_or_null("MarginContainer/RootVBox/MainColumns/CenterPanel/SpeedRow/Speed4xBtn")
var current_game_speed: float = 1.0

var current_character_id: StringName = &"nova"
var roster_dict: Dictionary[StringName, CharacterData] = {}
var roster_ordered: Array[CharacterData] = []
var _last_focused_control: Control = null

# Backward-compatible accessor for any caller referencing characters_data
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
		if DEBUG_MENU_AVAILABLE:
			UIFocusHelper.apply_cyber_focus(debug_button)
			debug_button.pressed.connect(_on_debug_pressed)
		else:
			debug_button.visible = false

	launch_button.pressed.connect(_on_launch_pressed)
	loadout_button.pressed.connect(_on_loadout_pressed)
	back_button.pressed.connect(_on_back_pressed)
	_setup_speed_buttons()

	if fullbody_texture:
		fullbody_texture.mouse_filter = Control.MOUSE_FILTER_STOP
		fullbody_texture.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		fullbody_texture.gui_input.connect(_on_character_art_gui_input)

	var right_panel: Control = get_node_or_null("MarginContainer/RootVBox/MainColumns/RightPanel") as Control
	if right_panel:
		right_panel.mouse_filter = Control.MOUSE_FILTER_STOP
		right_panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		right_panel.gui_input.connect(_on_character_art_gui_input)

	if pet_button:
		UIFocusHelper.apply_cyber_focus(pet_button)
		pet_button.pressed.connect(_on_pet_card_pressed)

	if pet_selection_modal and pet_selection_modal.has_signal("pet_selected"):
		pet_selection_modal.pet_selected.connect(_on_pet_selected)

	_refresh_pet_display()

	if debug_menu_modal and debug_menu_modal.has_signal("closed"):
		debug_menu_modal.closed.connect(_on_debug_modal_closed)

func _unhandled_input(event: InputEvent) -> void:
	if debug_menu_modal and debug_menu_modal.get("is_open"):
		return
	if pet_selection_modal and pet_selection_modal.get("is_open"):
		return

	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_C:
		_on_loadout_pressed()
		get_viewport().set_input_as_handled()
	elif DEBUG_MENU_AVAILABLE and (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1):
		_on_debug_pressed()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_1:
			_set_game_speed(1.0)
		elif event.keycode == KEY_2:
			_set_game_speed(2.0)
		elif event.keycode == KEY_3:
			_set_game_speed(4.0)

func _on_character_art_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_on_character_art_clicked()
		get_viewport().set_input_as_handled()

func _on_character_art_clicked() -> void:
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx(&"ui_click")

	# Animación elástica en el arte del personaje
	if fullbody_texture:
		fullbody_texture.pivot_offset = fullbody_texture.size * 0.5
		var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(fullbody_texture, "scale", Vector2(1.04, 1.04), 0.08)
		tw.tween_property(fullbody_texture, "scale", Vector2(1.0, 1.0), 0.12)

	# Mover foco del UI y cursor del ratón hacia el botón de Iniciar Run
	if launch_button and launch_button.is_visible_in_tree():
		launch_button.grab_focus()
		var target_pos: Vector2 = launch_button.get_global_rect().get_center()
		get_viewport().warp_mouse(target_pos)
		var tw_btn := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw_btn.tween_property(launch_button, "scale", Vector2(1.06, 1.06), 0.08)
		tw_btn.tween_property(launch_button, "scale", Vector2(1.0, 1.0), 0.12)

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
			if current_character_id == cid:
				_on_character_art_clicked()
			else:
				_select_character(cid)
		)
		btn.focus_entered.connect(func(): _select_character(cid))

		var icon_tex := char_data.get_portrait_texture()
		if icon_tex:
			btn.icon = icon_tex
			btn.expand_icon = true

		UIFocusHelper.apply_cyber_focus(btn)
		char_list_container.add_child(btn)

		# Navegación horizontal WASD: presionar D/derecha va a los botones de acción
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

	# Cadena de navegación horizontal y vertical en ActionsRow
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

	if first_btn:
		first_btn.grab_focus()

func _on_debug_pressed() -> void:
	if not DEBUG_MENU_AVAILABLE or not debug_menu_modal:
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

func _select_character(char_id: StringName) -> void:
	current_character_id = char_id
	SaveManager.set_selected_character(char_id)
	var data: CharacterData = roster_dict.get(char_id, null)
	if not data:
		roster_dict = CharacterData.load_roster()
		data = roster_dict.get(char_id, null)
	if not data:
		return

	# Dossier textual
	name_label.text = data.display_name.to_upper()
	name_label.modulate = data.color
	title_label.text = data.title
	desc_label.text = data.description
	stats_label.text = data.get_formatted_stats()

	# Equipamiento Asignado (Nave y Arma)
	if ship_icon:
		ship_icon.texture = data.get_ship_texture()
	if ship_name:
		ship_name.text = "%s Mark I" % data.display_name

	if weapon_icon:
		weapon_icon.texture = data.get_weapon_texture()
	if weapon_name:
		if data.starting_weapon and not data.starting_weapon.weapon_name.is_empty():
			weapon_name.text = data.starting_weapon.weapon_name
		else:
			weapon_name.text = "Arma Especializada"

	# Escaparate Full Body
	if fullbody_texture:
		var fb_tex := data.get_fullbody_texture(false)
		if not fb_tex:
			fb_tex = data.get_fullbody_texture(true)
		if not fb_tex:
			fb_tex = data.get_portrait_texture()

		fullbody_texture.texture = fb_tex
		fullbody_texture.flip_h = true
		fullbody_texture.visible = (fb_tex != null)

	var is_unlocked := SaveManager.is_character_unlocked(char_id)
	if not is_unlocked:
		if launch_button:
			launch_button.disabled = true
			launch_button.text = "PILOTO BLOQUEADO"
		if loadout_button:
			loadout_button.disabled = true
		if char_id == &"nyx":
			var career := SaveManager.get_career_stats()
			var bosses := int(career.get("total_bosses_killed", 0))
			desc_label.text = "🔒 DESBLOQUEO DE CARRERA ESPACIAL:\nDerrota a 10 Jefes Titanes en combate para sincronizar a Nyx.\nProgreso de carrera: [ %d / 10 ] Jefes Eliminados.\n\n%s" % [bosses, data.description]
		if fullbody_texture:
			fullbody_texture.modulate = Color(0.2, 0.2, 0.3, 0.85)
	else:
		if launch_button:
			launch_button.disabled = false
			launch_button.text = "INICIAR RUN"
		if loadout_button:
			loadout_button.disabled = false
		if fullbody_texture:
			fullbody_texture.modulate = Color.WHITE

	_refresh_pet_display()

func _refresh_pet_display() -> void:
	var sel_pid := SaveManager.get_selected_pet()
	const PetDataScript := preload("res://data/pets/pet_data.gd")
	var pet_res = PetDataScript.get_pet(sel_pid)
	if pet_res:
		if pet_icon:
			pet_icon.texture = pet_res.icon
		if pet_name:
			pet_name.text = "%s — %s" % [pet_res.display_name.to_upper(), pet_res.title.to_upper()]
			pet_name.modulate = pet_res.theme_color
		if pet_desc:
			pet_desc.text = pet_res.power_description

func _on_pet_card_pressed() -> void:
	if pet_selection_modal and pet_selection_modal.has_method("open_modal"):
		_last_focused_control = get_viewport().gui_get_focus_owner()
		pet_selection_modal.open_modal()

func _on_pet_selected(_pid: StringName) -> void:
	_refresh_pet_display()

func _on_launch_pressed() -> void:
	if not SaveManager.is_character_unlocked(current_character_id):
		return
	SaveManager.set_selected_character(current_character_id)
	get_tree().call_deferred("change_scene_to_file", "res://scenes/combat/main_game.tscn")

func _on_loadout_pressed() -> void:
	get_tree().call_deferred("change_scene_to_file", "res://scenes/ui/hangar_banlist_ui.tscn")

func _on_back_pressed() -> void:
	get_tree().call_deferred("change_scene_to_file", "res://scenes/ui/hub/hub_world.tscn")

func _setup_speed_buttons() -> void:
	if not speed_1x_btn or not speed_2x_btn or not speed_4x_btn:
		return
	current_game_speed = SaveManager.get_game_speed()
	UIFocusHelper.apply_cyber_focus(speed_1x_btn)
	UIFocusHelper.apply_cyber_focus(speed_2x_btn)
	UIFocusHelper.apply_cyber_focus(speed_4x_btn)

	speed_1x_btn.pressed.connect(func(): _set_game_speed(1.0))
	speed_2x_btn.pressed.connect(func(): _set_game_speed(2.0))
	speed_4x_btn.pressed.connect(func(): _set_game_speed(4.0))

	_refresh_speed_buttons_ui()

func _set_game_speed(speed: float) -> void:
	current_game_speed = speed
	SaveManager.set_game_speed(speed)
	_refresh_speed_buttons_ui()

func _refresh_speed_buttons_ui() -> void:
	_style_speed_button(speed_1x_btn, is_equal_approx(current_game_speed, 1.0), "1x NORMAL")
	_style_speed_button(speed_2x_btn, is_equal_approx(current_game_speed, 2.0), "2x RÁPIDO")
	_style_speed_button(speed_4x_btn, is_equal_approx(current_game_speed, 4.0), "4x TURBO")

func _style_speed_button(btn: Button, is_active: bool, base_text: String) -> void:
	if not btn:
		return
	var sb := StyleBoxFlat.new()
	if is_active:
		btn.text = "● %s" % base_text
		sb.bg_color = Color(0.06, 0.22, 0.28, 1.0)
		sb.border_width_left = 3
		sb.border_width_top = 3
		sb.border_width_right = 3
		sb.border_width_bottom = 3
		sb.border_color = Color(0, 0.94, 1, 1)
		sb.shadow_color = Color(0, 0.94, 1, 0.35)
		sb.shadow_size = 4
		btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	else:
		btn.text = "○ %s" % base_text
		sb.bg_color = Color(0.04, 0.04, 0.06, 0.8)
		sb.border_width_left = 1
		sb.border_width_top = 1
		sb.border_width_right = 1
		sb.border_width_bottom = 1
		sb.border_color = Color(0.25, 0.28, 0.35, 1.0)
		btn.add_theme_color_override("font_color", Color(0.65, 0.7, 0.78, 1))

	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_right = 4
	sb.corner_radius_bottom_left = 4
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	btn.add_theme_stylebox_override("pressed", sb)


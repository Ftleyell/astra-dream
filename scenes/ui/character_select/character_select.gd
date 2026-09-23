class_name CharacterSelectUI
extends Control

const UIFocusHelper := preload("res://core/utils/ui_focus_helper.gd")

@onready var char_list_container: VBoxContainer = $MarginContainer/RootVBox/MainColumns/LeftPanel/CharScroll/CharList
@onready var name_label: Label = $MarginContainer/RootVBox/MainColumns/CenterPanel/DossierHeader/NameLabel
@onready var title_label: Label = $MarginContainer/RootVBox/MainColumns/CenterPanel/DossierHeader/ClassTitleLabel
@onready var desc_label: Label = $MarginContainer/RootVBox/MainColumns/CenterPanel/DescBox/DescLabel
@onready var stats_label: Label = $MarginContainer/RootVBox/MainColumns/CenterPanel/StatsBox/StatsLabel

@onready var ship_icon: TextureRect = $MarginContainer/RootVBox/MainColumns/CenterPanel/EquipmentBox/EquipRow/ShipCard/ShipBox/ShipIcon
@onready var ship_name: Label = $MarginContainer/RootVBox/MainColumns/CenterPanel/EquipmentBox/EquipRow/ShipCard/ShipBox/ShipLabelVBox/ShipName
@onready var weapon_icon: TextureRect = $MarginContainer/RootVBox/MainColumns/CenterPanel/EquipmentBox/EquipRow/WeaponCard/WeaponBox/WeaponIcon
@onready var weapon_name: Label = $MarginContainer/RootVBox/MainColumns/CenterPanel/EquipmentBox/EquipRow/WeaponCard/WeaponBox/WeaponLabelVBox/WeaponName

@onready var launch_button: Button = $MarginContainer/RootVBox/MainColumns/CenterPanel/ActionsRow/LaunchButton
@onready var loadout_button: Button = $MarginContainer/RootVBox/MainColumns/CenterPanel/ActionsRow/LoadoutButton
@onready var back_button: Button = $MarginContainer/RootVBox/HeaderBar/BackButton
@onready var fullbody_texture: TextureRect = $MarginContainer/RootVBox/MainColumns/RightPanel/FullbodyTexture

var current_character_id: StringName = &"nova"
var roster_dict: Dictionary[StringName, CharacterData] = {}
var roster_ordered: Array[CharacterData] = []

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
	if roster_dict.has(saved_char):
		_select_character(saved_char)
	elif not roster_ordered.is_empty():
		_select_character(roster_ordered[0].character_id)
	else:
		_select_character(&"nova")

	UIFocusHelper.apply_cyber_focus(launch_button)
	UIFocusHelper.apply_cyber_focus(loadout_button)
	UIFocusHelper.apply_cyber_focus(back_button)

	launch_button.pressed.connect(_on_launch_pressed)
	loadout_button.pressed.connect(_on_loadout_pressed)
	back_button.pressed.connect(_on_back_pressed)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_select") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE):
		_on_launch_pressed()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_C:
		_on_loadout_pressed()
		get_viewport().set_input_as_handled()

func _populate_roster() -> void:
	for child in char_list_container.get_children():
		child.queue_free()

	var first_btn: Button = null
	var prev_btn: Button = null

	for char_data in roster_ordered:
		var cid: StringName = char_data.character_id
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(400, 84)
		btn.text = "   %s\n   %s" % [char_data.display_name.to_upper(), char_data.title]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(func(): _select_character(cid))
		btn.focus_entered.connect(func(): _select_character(cid))

		var icon_tex := char_data.get_portrait_texture()
		if icon_tex:
			btn.icon = icon_tex
			btn.expand_icon = true

		UIFocusHelper.apply_cyber_focus(btn)
		char_list_container.add_child(btn)

		# Navegación horizontal WASD: presionar D/derecha va a LaunchButton
		if launch_button:
			btn.focus_neighbor_right = launch_button.get_path()

		if not first_btn:
			first_btn = btn

		if prev_btn:
			prev_btn.focus_neighbor_bottom = btn.get_path()
			btn.focus_neighbor_top = prev_btn.get_path()
		prev_btn = btn

	if prev_btn:
		prev_btn.focus_neighbor_bottom = first_btn.get_path()
		first_btn.focus_neighbor_top = prev_btn.get_path()

	launch_button.focus_neighbor_left = first_btn.get_path() if first_btn else NodePath("")
	launch_button.focus_neighbor_bottom = loadout_button.get_path()
	loadout_button.focus_neighbor_top = launch_button.get_path()
	loadout_button.focus_neighbor_left = first_btn.get_path() if first_btn else NodePath("")

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
		var fb_tex := data.get_fullbody_texture(true) # Invertida para mirar hacia el centro/izquierda
		if not fb_tex:
			fb_tex = data.get_fullbody_texture(false)
		if not fb_tex:
			fb_tex = data.get_portrait_texture()

		fullbody_texture.texture = fb_tex
		fullbody_texture.visible = (fb_tex != null)

func _on_launch_pressed() -> void:
	SaveManager.set_selected_character(current_character_id)
	get_tree().call_deferred("change_scene_to_file", "res://scenes/combat/main_game.tscn")

func _on_loadout_pressed() -> void:
	get_tree().call_deferred("change_scene_to_file", "res://scenes/ui/hangar_banlist_ui.tscn")

func _on_back_pressed() -> void:
	get_tree().call_deferred("change_scene_to_file", "res://scenes/ui/hub/hub_world.tscn")

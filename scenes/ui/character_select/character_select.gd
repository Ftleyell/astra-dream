class_name CharacterSelectUI
extends Control

const UIFocusHelper := preload("res://core/utils/ui_focus_helper.gd")

@onready var char_list_container: VBoxContainer = $MarginContainer/HBoxContainer/LeftPanel/CharScroll/CharList
@onready var portrait_emblem: Polygon2D = $MarginContainer/HBoxContainer/RightPanel/PortraitFrame/PortraitEmblem
@onready var portrait_texture: TextureRect = $MarginContainer/HBoxContainer/RightPanel/PortraitFrame/PortraitTexture
@onready var portrait_border: Panel = $MarginContainer/HBoxContainer/RightPanel/PortraitFrame
@onready var name_label: Label = $MarginContainer/HBoxContainer/RightPanel/InfoVBox/NameLabel
@onready var title_label: Label = $MarginContainer/HBoxContainer/RightPanel/InfoVBox/TitleLabel
@onready var desc_label: Label = $MarginContainer/HBoxContainer/RightPanel/InfoVBox/DescLabel
@onready var stats_label: Label = $MarginContainer/HBoxContainer/RightPanel/InfoVBox/StatsLabel
@onready var launch_button: Button = $MarginContainer/HBoxContainer/RightPanel/ActionsRow/LaunchButton
@onready var loadout_button: Button = $MarginContainer/HBoxContainer/RightPanel/ActionsRow/LoadoutButton
@onready var back_button: Button = $MarginContainer/HBoxContainer/LeftPanel/BackButton

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

	_populate_roster()
	_select_character(&"nova")

func _populate_roster() -> void:
	for child in char_list_container.get_children():
		child.queue_free()

	var first_btn: Button = null
	var prev_btn: Button = null

	for char_data in roster_ordered:
		var cid: StringName = char_data.character_id
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(280, 54)
		btn.text = "%s  —  %s" % [char_data.display_name, char_data.title]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(func(): _select_character(cid))
		btn.focus_entered.connect(func(): _select_character(cid))

		UIFocusHelper.apply_cyber_focus(btn)

		char_list_container.add_child(btn)

		# Enlace lateral con WASD: presionar D/derecha va a LaunchButton
		if launch_button:
			btn.focus_neighbor_right = launch_button.get_path()

		if not first_btn:
			first_btn = btn

		if prev_btn:
			prev_btn.focus_neighbor_bottom = btn.get_path()
			btn.focus_neighbor_top = prev_btn.get_path()
		prev_btn = btn



	if prev_btn:
		prev_btn.focus_neighbor_bottom = back_button.get_path()
		back_button.focus_neighbor_top = prev_btn.get_path()
		back_button.focus_neighbor_right = loadout_button.get_path()

	launch_button.focus_neighbor_left = first_btn.get_path() if first_btn else NodePath("")
	launch_button.focus_neighbor_bottom = loadout_button.get_path()
	loadout_button.focus_neighbor_top = launch_button.get_path()
	loadout_button.focus_neighbor_left = back_button.get_path()

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

	name_label.text = data.display_name
	name_label.modulate = data.color
	title_label.text = data.title
	desc_label.text = data.description
	stats_label.text = data.get_formatted_stats()

	# Carga de retrato ilustrado o fallback a silueta poligonal
	var tex: Texture2D = data.portrait_icon
	if not tex:
		var portrait_path := "res://assets/portraits/portrait_%s.png" % str(char_id).to_lower()
		if ResourceLoader.exists(portrait_path):
			tex = load(portrait_path) as Texture2D

	if tex:
		if portrait_texture:
			portrait_texture.texture = tex
			portrait_texture.visible = true
		if portrait_emblem:
			portrait_emblem.visible = false
	else:
		if portrait_texture:
			portrait_texture.visible = false
		if portrait_emblem:
			portrait_emblem.polygon = data.pts
			portrait_emblem.color = data.color
			portrait_emblem.visible = true

func _on_launch_pressed() -> void:
	SaveManager.set_selected_character(current_character_id)
	get_tree().change_scene_to_file("res://scenes/combat/main_game.tscn")

func _on_loadout_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/hangar_banlist_ui.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu/main_menu.tscn")

class_name MainMenu
extends Control

@onready var play_button: Button = $CenterContainer/VBoxContainer/ButtonsContainer/PlayButton
@onready var hub_button: Button = $CenterContainer/VBoxContainer/ButtonsContainer/HubButton
@onready var settings_button: Button = $CenterContainer/VBoxContainer/ButtonsContainer/SettingsButton
@onready var quit_button: Button = $CenterContainer/VBoxContainer/ButtonsContainer/QuitButton
@onready var settings_modal: SettingsModal = $SettingsModal

func _enter_tree() -> void:
	_wire_hub_button()

func _ready() -> void:
	_wire_hub_button()
	if play_button and not play_button.pressed.is_connected(_on_play_pressed):
		play_button.pressed.connect(_on_play_pressed)
	if settings_button and not settings_button.pressed.is_connected(_on_settings_pressed):
		settings_button.pressed.connect(_on_settings_pressed)
	if quit_button and not quit_button.pressed.is_connected(_on_quit_pressed):
		quit_button.pressed.connect(_on_quit_pressed)

	if play_button:
		UIFocusHelper.apply_cyber_focus(play_button)
	if hub_button:
		UIFocusHelper.apply_cyber_focus(hub_button)
	if settings_button:
		UIFocusHelper.apply_cyber_focus(settings_button)
	if quit_button:
		UIFocusHelper.apply_cyber_focus(quit_button)

	if play_button and is_inside_tree():
		play_button.grab_focus()


	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_music"):
		audio_mgr.play_music("menu")

func _wire_hub_button() -> void:
	var btn := hub_button
	if not btn:
		btn = get_node_or_null("CenterContainer/VBoxContainer/ButtonsContainer/HubButton")
	if btn and not btn.pressed.is_connected(_on_hub_pressed):
		btn.pressed.connect(_on_hub_pressed)

func _on_play_pressed() -> void:
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("ui_click")
	get_tree().change_scene_to_file("res://scenes/ui/character_select/character_select.tscn")

func _on_hub_pressed() -> void:
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("ui_click")
	get_tree().change_scene_to_file("res://scenes/ui/hub/hub_world.tscn")

func _on_settings_pressed() -> void:
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("ui_click")
	if settings_modal:
		settings_modal.open_settings()

func _on_quit_pressed() -> void:
	get_tree().quit()

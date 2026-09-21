class_name MainMenu
extends Control

@onready var play_button: Button = $CenterContainer/VBoxContainer/ButtonsContainer/PlayButton
@onready var settings_button: Button = $CenterContainer/VBoxContainer/ButtonsContainer/SettingsButton
@onready var quit_button: Button = $CenterContainer/VBoxContainer/ButtonsContainer/QuitButton
@onready var settings_modal: SettingsModal = $SettingsModal

func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	UIFocusHelper.apply_cyber_focus(play_button)
	UIFocusHelper.apply_cyber_focus(settings_button)
	UIFocusHelper.apply_cyber_focus(quit_button)

	play_button.grab_focus()

	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_music"):
		audio_mgr.play_music("menu")

func _on_play_pressed() -> void:
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("ui_click")
	get_tree().change_scene_to_file("res://scenes/ui/character_select/character_select.tscn")

func _on_settings_pressed() -> void:
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("ui_click")
	if settings_modal:
		settings_modal.open_settings()

func _on_quit_pressed() -> void:
	get_tree().quit()

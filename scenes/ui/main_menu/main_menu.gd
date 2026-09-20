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

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/character_select/character_select.tscn")

func _on_settings_pressed() -> void:
	if settings_modal:
		settings_modal.open_settings()

func _on_quit_pressed() -> void:
	get_tree().quit()

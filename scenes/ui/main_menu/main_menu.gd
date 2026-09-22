class_name MainMenu
extends Control

const UIFocusHelper := preload("res://core/utils/ui_focus_helper.gd")

@onready var continue_button: Button = get_node_or_null("CenterContainer/VBoxContainer/ButtonsContainer/ContinueButton")
@onready var play_button: Button = $CenterContainer/VBoxContainer/ButtonsContainer/PlayButton
@onready var hub_button: Button = $CenterContainer/VBoxContainer/ButtonsContainer/HubButton
@onready var highscores_button: Button = get_node_or_null("CenterContainer/VBoxContainer/ButtonsContainer/HighscoresButton")
@onready var settings_button: Button = $CenterContainer/VBoxContainer/ButtonsContainer/SettingsButton
@onready var quit_button: Button = $CenterContainer/VBoxContainer/ButtonsContainer/QuitButton
@onready var settings_modal: SettingsModal = $SettingsModal
@onready var highscores_modal: CanvasLayer = get_node_or_null("HighscoresModal")

func _enter_tree() -> void:
	_wire_hub_button()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false
	_wire_hub_button()

	# Configuración del botón de Continuar Run activa
	if continue_button:
		if SaveManager.has_active_run():
			var active_data := SaveManager.load_active_run()
			var wave: int = int(active_data.get("current_wave", 1))
			var pilot: String = str(active_data.get("pilot_name", "Piloto"))
			continue_button.text = "CONTINUAR RUN (%s - OLEADA %d)" % [pilot.to_upper(), wave]
			continue_button.show()
			UIFocusHelper.apply_cyber_focus(continue_button)
			if not continue_button.pressed.is_connected(_on_continue_pressed):
				continue_button.pressed.connect(_on_continue_pressed)
		else:
			continue_button.hide()

	if play_button and not play_button.pressed.is_connected(_on_play_pressed):
		play_button.pressed.connect(_on_play_pressed)
	if highscores_button and not highscores_button.pressed.is_connected(_on_highscores_pressed):
		highscores_button.pressed.connect(_on_highscores_pressed)
	if settings_button and not settings_button.pressed.is_connected(_on_settings_pressed):
		settings_button.pressed.connect(_on_settings_pressed)
	if quit_button and not quit_button.pressed.is_connected(_on_quit_pressed):
		quit_button.pressed.connect(_on_quit_pressed)

	if settings_modal and not settings_modal.closed.is_connected(_on_settings_closed):
		settings_modal.closed.connect(_on_settings_closed)
	if highscores_modal and not highscores_modal.closed.is_connected(_on_highscores_closed):
		highscores_modal.closed.connect(_on_highscores_closed)

	if play_button:
		UIFocusHelper.apply_cyber_focus(play_button)
	if hub_button:
		UIFocusHelper.apply_cyber_focus(hub_button)
	if highscores_button:
		UIFocusHelper.apply_cyber_focus(highscores_button)
	if settings_button:
		UIFocusHelper.apply_cyber_focus(settings_button)
	if quit_button:
		UIFocusHelper.apply_cyber_focus(quit_button)

	# Foco inicial inteligente: continuar run activa si existe, o jugar nueva run
	if continue_button and continue_button.visible:
		continue_button.grab_focus()
	elif play_button and is_inside_tree():
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

func _on_continue_pressed() -> void:
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("ui_click")
	SaveManager.is_resuming_run = true
	get_tree().change_scene_to_file("res://scenes/combat/main_game.tscn")

func _on_play_pressed() -> void:
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("ui_click")
	SaveManager.is_resuming_run = false
	get_tree().change_scene_to_file("res://scenes/ui/character_select/character_select.tscn")

func _on_hub_pressed() -> void:
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("ui_click")
	get_tree().change_scene_to_file("res://scenes/ui/hub/hub_world.tscn")

func _on_highscores_pressed() -> void:
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("ui_click")
	if highscores_modal:
		highscores_modal.open_highscores()

func _on_highscores_closed() -> void:
	if highscores_button:
		highscores_button.grab_focus()

func _on_settings_pressed() -> void:
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("ui_click")
	if settings_modal:
		settings_modal.open_settings()

func _on_settings_closed() -> void:
	if settings_button:
		settings_button.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if highscores_modal and highscores_modal.visible and event.is_action_pressed("ui_cancel"):
		highscores_modal.close_highscores()
		get_viewport().set_input_as_handled()
	elif settings_modal and settings_modal.visible and event.is_action_pressed("ui_cancel"):
		settings_modal.close_settings()
		get_viewport().set_input_as_handled()

func _on_quit_pressed() -> void:
	get_tree().quit()

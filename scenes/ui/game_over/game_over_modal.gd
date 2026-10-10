class_name GameOverModal
extends CanvasLayer

## GameOverModal.gd
## Pantalla de Fin de Partida (Game Over / Misión Fallida / Victoria Estelar).
## Orquestador liviano de ciclo de vida, navegación y señales de la pantalla final.

signal restart_requested()
signal hub_requested()
signal endless_requested()
signal closed()

@onready var panel: Panel = $Panel
@onready var backdrop: ColorRect = $Backdrop

# Header & Score
@onready var title_label: Label = $Panel/VBoxContainer/HeaderContainer/TitleLabel
@onready var pilot_label: Label = $Panel/VBoxContainer/HeaderContainer/PilotLabel
@onready var highscore_badge: PanelContainer = $Panel/VBoxContainer/HeaderContainer/HighscoreBadge
@onready var highscore_label: Label = $Panel/VBoxContainer/HeaderContainer/HighscoreBadge/HighscoreLabel
@onready var score_value_label: Label = $Panel/VBoxContainer/ScoreBanner/ScoreValueLabel

# Stats Labels
@onready var wave_val_label: Label = $Panel/VBoxContainer/MainContent/StatsPanel/StatsVBox/WaveRow/Val
@onready var time_val_label: Label = $Panel/VBoxContainer/MainContent/StatsPanel/StatsVBox/TimeRow/Val
@onready var bosses_val_label: Label = $Panel/VBoxContainer/MainContent/StatsPanel/StatsVBox/BossesRow/Val
@onready var kills_val_label: Label = $Panel/VBoxContainer/MainContent/StatsPanel/StatsVBox/KillsRow/Val

# Resource Labels
@onready var biomass_val_label: Label = $Panel/VBoxContainer/MainContent/StatsPanel/StatsVBox/BiomassRow/Val
@onready var dark_matter_val_label: Label = $Panel/VBoxContainer/MainContent/StatsPanel/StatsVBox/DarkMatterRow/Val
@onready var credits_val_label: Label = $Panel/VBoxContainer/MainContent/StatsPanel/StatsVBox/CreditsRow/Val

# Loadout Containers
@onready var arcanas_container: HFlowContainer = $Panel/VBoxContainer/MainContent/LoadoutPanel/LoadoutScroll/LoadoutVBox/ArcanasContainer
@onready var items_container: HFlowContainer = $Panel/VBoxContainer/MainContent/LoadoutPanel/LoadoutScroll/LoadoutVBox/ItemsContainer
@onready var weapons_container: HFlowContainer = $Panel/VBoxContainer/MainContent/LoadoutPanel/LoadoutScroll/LoadoutVBox/WeaponsContainer

# Action Buttons
@onready var endless_button: Button = $Panel/VBoxContainer/BottomBar/EndlessButton
@onready var restart_button: Button = $Panel/VBoxContainer/BottomBar/RestartButton
@onready var hub_button: Button = $Panel/VBoxContainer/BottomBar/HubButton

var is_active: bool = false
var is_victory_run: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 70
	hide()

	if endless_button:
		UIFocusHelper.apply_cyber_focus(endless_button)
		endless_button.pressed.connect(_on_endless_pressed)
	if restart_button:
		UIFocusHelper.apply_cyber_focus(restart_button)
		restart_button.pressed.connect(_on_restart_pressed)
	if hub_button:
		UIFocusHelper.apply_cyber_focus(hub_button)
		hub_button.pressed.connect(_on_hub_pressed)

func show_game_over(data: Dictionary) -> void:
	is_active = true
	is_victory_run = bool(data.get("victory", false))
	_populate_screen(data)

	if endless_button:
		endless_button.visible = is_victory_run

	show()

	var audio_mgr := get_node_or_null("/root/AudioManager") if is_inside_tree() else null
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("menu_open", 1.0, 1.0)

	if is_victory_run and endless_button and endless_button.is_visible_in_tree():
		endless_button.grab_focus()
	elif restart_button:
		restart_button.grab_focus()

func _populate_screen(data: Dictionary) -> void:
	var score: int = int(data.get("score", 0))
	if score_value_label:
		score_value_label.text = GameOverTelemetryFormatter.format_score_text(score)

	var is_victory: bool = bool(data.get("victory", false))
	var ending_title: String = str(data.get("ending_title", ""))

	if title_label:
		if is_victory:
			title_label.text = "★ ¡VICTORIA ESTELAR - INCURSIÓN CUMPLIDA! ★"
			title_label.modulate = Color(0.2, 1.0, 0.65, 1.0)
		else:
			title_label.text = "SEÑAL DE NAVE PERDIDA (GAME OVER)"
			title_label.modulate = Color(1.0, 0.25, 0.25, 1.0)

	_setup_highscore_badge(data, ending_title)

	var pilot_name: String = str(data.get("pilot_name", "Nova"))
	var epilogue_text: String = str(data.get("epilogue_text", ""))
	if pilot_label:
		pilot_label.text = GameOverTelemetryFormatter.format_pilot_title(pilot_name, epilogue_text)

	if wave_val_label:
		wave_val_label.text = GameOverTelemetryFormatter.format_wave_text(int(data.get("waves_survived", 1)))
	if time_val_label:
		time_val_label.text = str(data.get("time_formatted", "00:00"))
	if bosses_val_label:
		bosses_val_label.text = GameOverTelemetryFormatter.format_bosses_text(int(data.get("bosses_defeated", 0)))
	if kills_val_label:
		kills_val_label.text = GameOverTelemetryFormatter.format_kills_text(int(data.get("enemies_killed", 0)))

	if biomass_val_label:
		biomass_val_label.text = GameOverTelemetryFormatter.format_biomass_text(int(data.get("biomass_collected", 0)))
	if dark_matter_val_label:
		dark_matter_val_label.text = GameOverTelemetryFormatter.format_dark_matter_text(int(data.get("dark_matter_collected", 0)))
	if credits_val_label:
		credits_val_label.text = GameOverTelemetryFormatter.format_credits_text(int(data.get("credits_collected", 0)))

	GameOverLayoutBuilder.populate_arcanas(arcanas_container, data.get("arcanas", []))
	GameOverLayoutBuilder.populate_items(items_container, data.get("items", []))
	GameOverLayoutBuilder.populate_weapons(weapons_container, data.get("weapons", []))

func _setup_highscore_badge(data: Dictionary, ending_title: String) -> void:
	if not highscore_badge:
		return

	var is_new_record: bool = bool(data.get("is_new_highscore", false))
	var rank: int = int(data.get("rank", -1))

	if not ending_title.is_empty():
		highscore_badge.show()
		if highscore_label:
			highscore_label.text = "✦ %s ✦" % ending_title.to_upper()
			var e_type: String = str(data.get("ending_type", "neutral"))
			if e_type == "pacifist":
				highscore_label.modulate = Color(0.2, 0.95, 1.0, 1.0)
			elif e_type == "slayer":
				highscore_label.modulate = Color(1.0, 0.25, 0.35, 1.0)
			else:
				highscore_label.modulate = Color(1.0, 0.85, 0.2, 1.0)
	elif is_new_record:
		highscore_badge.show()
		if highscore_label:
			highscore_label.text = "★ ¡NUEVO RÉCORD HISTÓRICO - TOP #1! ★"
			highscore_label.modulate = Color(1.0, 0.85, 0.2, 1.0)
	elif rank > 0 and rank <= 10:
		highscore_badge.show()
		if highscore_label:
			highscore_label.text = "★ RÉCORD REGISTRADO EN EL TOP #%d ★" % rank
			highscore_label.modulate = Color(0.3, 0.9, 1.0, 1.0)
	else:
		highscore_badge.hide()

func _on_endless_pressed() -> void:
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("ui_click", 1.2, 1.0)
	hide()
	is_active = false
	endless_requested.emit()

func _on_restart_pressed() -> void:
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("ui_click", 1.1, 1.0)
	restart_requested.emit()

func _on_hub_pressed() -> void:
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("ui_click", 1.0, 1.0)
	hub_requested.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not visible or not is_active:
		return

	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_E and is_victory_run:
			_on_endless_pressed()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_R:
			_on_restart_pressed()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_H or event.keycode == KEY_ESCAPE:
			_on_hub_pressed()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_cancel"):
			_on_hub_pressed()
			get_viewport().set_input_as_handled()

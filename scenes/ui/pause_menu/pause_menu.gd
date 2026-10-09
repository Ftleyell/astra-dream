class_name PauseMenu
extends CanvasLayer

## PauseMenu — Astra Dream
## Menú de pausa orquestador, liviano y desacoplado (< 180 líneas).
## Delega inspección de build y configuraciones en componentes dedicados.

const BuildInspectorScript := preload("res://scenes/ui/pause_menu/components/pause_build_inspector.gd")
const HighscoresModalScript := preload("res://scenes/ui/highscores/highscores_modal.gd")

@export var player: Player

@onready var resume_button: Button = $Panel/VBoxContainer/BottomBar/ResumeButton
@onready var settings_button: Button = $Panel/VBoxContainer/BottomBar/SettingsButton
@onready var hitbox_toggle_button: Button = get_node_or_null("Panel/VBoxContainer/BottomBar/HitboxToggleButton")
@onready var highscores_button: Button = $Panel/VBoxContainer/BottomBar/HighscoresButton
@onready var save_quit_button: Button = $Panel/VBoxContainer/BottomBar/SaveQuitButton
@onready var restart_button: Button = $Panel/VBoxContainer/BottomBar/RestartButton
@onready var hub_button: Button = get_node_or_null("Panel/VBoxContainer/BottomBar/HubButton")
@onready var menu_button: Button = $Panel/VBoxContainer/BottomBar/MenuButton

@onready var stats_container: VBoxContainer = $Panel/VBoxContainer/ContentHBox/StatsColumn/StatsScroll/StatsList
@onready var items_container: VBoxContainer = $Panel/VBoxContainer/ContentHBox/ItemsColumn/ItemsScroll/ItemsList
@onready var upgrades_container: VBoxContainer = $Panel/VBoxContainer/ContentHBox/UpgradesColumn/UpgradesScroll/UpgradesList
@onready var settings_modal: SettingsModal = $SettingsModal
@onready var highscores_modal: CanvasLayer = $HighscoresModal

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()

	if settings_modal:
		settings_modal.closed.connect(func(): if visible and settings_button: settings_button.grab_focus())
	if highscores_modal:
		highscores_modal.closed.connect(func(): if visible and highscores_button: highscores_button.grab_focus())

	UIFocusHelper.apply_cyber_focus(resume_button)
	UIFocusHelper.apply_cyber_focus(settings_button)
	if hitbox_toggle_button:
		UIFocusHelper.apply_cyber_focus(hitbox_toggle_button)
		hitbox_toggle_button.pressed.connect(_on_hitbox_toggle_pressed)
		_update_hitbox_toggle_text()
	UIFocusHelper.apply_cyber_focus(highscores_button)
	UIFocusHelper.apply_cyber_focus(save_quit_button)
	UIFocusHelper.apply_cyber_focus(restart_button)
	if hub_button:
		UIFocusHelper.apply_cyber_focus(hub_button)
	UIFocusHelper.apply_cyber_focus(menu_button)

	resume_button.pressed.connect(resume_game)
	settings_button.pressed.connect(_on_settings_pressed)
	if highscores_button:
		highscores_button.pressed.connect(_on_highscores_pressed)
	if save_quit_button:
		save_quit_button.pressed.connect(_on_save_quit_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	if hub_button:
		hub_button.pressed.connect(_on_hub_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	_setup_button_navigation()

func _setup_button_navigation() -> void:
	var buttons: Array[Button] = [
		resume_button,
		settings_button,
		hitbox_toggle_button,
		highscores_button,
		save_quit_button,
		restart_button,
		hub_button,
		menu_button
	]
	var active: Array[Button] = []
	for b in buttons:
		if is_instance_valid(b) and b.visible:
			active.append(b)

	var count := active.size()
	if count <= 1:
		return

	for i in range(count):
		var btn := active[i]
		var prev_btn := active[(i - 1 + count) % count]
		var next_btn := active[(i + 1) % count]
		btn.focus_neighbor_left = prev_btn.get_path()
		btn.focus_neighbor_right = next_btn.get_path()
		btn.focus_neighbor_top = prev_btn.get_path()
		btn.focus_neighbor_bottom = next_btn.get_path()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if visible:
			if highscores_modal and highscores_modal.visible:
				highscores_modal.close_highscores()
			elif settings_modal and settings_modal.visible:
				settings_modal.close_settings()
			else:
				resume_game()
			get_viewport().set_input_as_handled()
		else:
			var dialogic = get_node_or_null("/root/Dialogic")
			var is_dialogic_running: bool = bool(dialogic and "current_timeline" in dialogic and dialogic.current_timeline != null)
			if is_dialogic_running:
				return

			var parent_game = get_parent()
			if parent_game:
				if parent_game.has_method("is_satellite_shop_active") and parent_game.is_satellite_shop_active():
					return
				if "is_briefing_active" in parent_game and parent_game.is_briefing_active:
					return
				if "is_cockpit_active" in parent_game and parent_game.is_cockpit_active:
					parent_game.is_cockpit_active = false
				if "is_rival_cinematic_active" in parent_game and parent_game.is_rival_cinematic_active:
					return
				if "is_boss_transmission_active" in parent_game and parent_game.is_boss_transmission_active:
					parent_game.is_boss_transmission_active = false
				if "is_victory_dialogue_active" in parent_game and parent_game.is_victory_dialogue_active:
					return
				if parent_game.has_method("is_any_cutscene_active") and parent_game.is_any_cutscene_active():
					return

			open_pause_menu()
			get_viewport().set_input_as_handled()
		return

	if visible and not get_viewport().gui_get_focus_owner():
		if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right") or event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down"):
			resume_button.grab_focus()
			get_viewport().set_input_as_handled()

func open_pause_menu() -> void:
	PauseArbitrator.acquire_pause(&"pause_menu")
	var hud: Node = get_tree().get_first_node_in_group("hud") if get_tree() else null
	if hud and hud.has_method("set_stats_dock_requested"):
		hud.set_stats_dock_requested(&"pause_menu", true)
	BuildInspectorScript.refresh_build_inspector(player, stats_container, items_container, upgrades_container)
	_update_hitbox_toggle_text()
	show()
	_setup_button_navigation()
	resume_button.grab_focus()

func restore_focus() -> void:
	if visible and resume_button and is_instance_valid(resume_button):
		resume_button.grab_focus()

func resume_game() -> void:
	if is_instance_valid(player) and player.has_method("suppress_bomb_input"):
		player.suppress_bomb_input(0.4)
	hide()
	var hud: Node = get_tree().get_first_node_in_group("hud") if get_tree() else null
	if hud and hud.has_method("set_stats_dock_requested"):
		hud.set_stats_dock_requested(&"pause_menu", false)
	var focused := get_viewport().gui_get_focus_owner()
	if focused:
		focused.release_focus()
	if settings_modal and settings_modal.visible:
		settings_modal.close_settings()
	if highscores_modal and highscores_modal.visible:
		highscores_modal.close_highscores()

	var parent_game = get_parent()
	if parent_game and parent_game.has_method("notify_menu_closed"):
		parent_game.notify_menu_closed(0.4)
	PauseArbitrator.release_pause(&"pause_menu")
	if parent_game and parent_game.has_method("restore_combat_modal_focus") and parent_game.has_method("is_any_combat_modal_active") and parent_game.is_any_combat_modal_active():
		parent_game.restore_combat_modal_focus()

func _on_settings_pressed() -> void:
	if settings_modal:
		settings_modal.open_settings()

func _on_hitbox_toggle_pressed() -> void:
	var mgr = get_node_or_null("/root/SettingsManager")
	if mgr and mgr.has_method("set_core_hitbox_always_visible") and mgr.has_method("is_core_hitbox_always_visible"):
		mgr.set_core_hitbox_always_visible(not mgr.is_core_hitbox_always_visible())
		_update_hitbox_toggle_text()
		var audio_mgr = get_node_or_null("/root/AudioManager")
		if audio_mgr and audio_mgr.has_method("play_sfx"):
			audio_mgr.play_sfx("ui_click")

func _update_hitbox_toggle_text() -> void:
	if not hitbox_toggle_button:
		return
	var mgr = get_node_or_null("/root/SettingsManager")
	var always: bool = mgr.is_core_hitbox_always_visible() if mgr and mgr.has_method("is_core_hitbox_always_visible") else false
	hitbox_toggle_button.text = "HITBOX: SIEMPRE" if always else "HITBOX: AUTO"

func _on_highscores_pressed() -> void:
	if highscores_modal:
		highscores_modal.open_highscores()

func _release_hud_dock() -> void:
	var hud: Node = get_tree().get_first_node_in_group("hud") if get_tree() else null
	if hud and hud.has_method("set_stats_dock_requested"):
		hud.set_stats_dock_requested(&"pause_menu", false)

func _on_save_quit_pressed() -> void:
	var main_game := get_parent() as MainGame
	if not main_game and get_tree():
		main_game = get_tree().current_scene as MainGame
	if main_game:
		main_game.set("is_exiting_run", true)
		if main_game.has_method("save_current_run_state"):
			main_game.save_current_run_state()

	hide()
	_release_hud_dock()
	PauseArbitrator.force_unpause_all()
	Engine.time_scale = 1.0
	SaveManager.set_game_speed(1.0)
	_transition_to_hub()

func _on_restart_pressed() -> void:
	var main_game: Node = get_parent()
	if not main_game and get_tree():
		main_game = get_tree().current_scene
	if main_game:
		main_game.set("is_exiting_run", true)

	hide()
	_release_hud_dock()
	PauseArbitrator.force_unpause_all()
	get_tree().reload_current_scene()

func _on_hub_pressed() -> void:
	var main_game: Node = get_parent()
	if not main_game and get_tree():
		main_game = get_tree().current_scene
	if main_game:
		main_game.set("is_exiting_run", true)

	hide()
	_release_hud_dock()
	PauseArbitrator.force_unpause_all()
	Engine.time_scale = 1.0
	SaveManager.set_game_speed(1.0)
	_transition_to_hub()

func _on_menu_pressed() -> void:
	var main_game: Node = get_parent()
	if not main_game and get_tree():
		main_game = get_tree().current_scene
	if main_game:
		main_game.set("is_exiting_run", true)

	hide()
	_release_hud_dock()
	PauseArbitrator.force_unpause_all()
	Engine.time_scale = 1.0
	SaveManager.set_game_speed(1.0)
	_transition_to_hub()

func _transition_to_hub() -> void:
	var st: SceneTransitionClass = get_node_or_null("/root/SceneTransition") as SceneTransitionClass
	if st and st.has_method("change_scene_to_file"):
		st.change_scene_to_file("res://scenes/ui/hub/hub_world.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/ui/hub/hub_world.tscn")

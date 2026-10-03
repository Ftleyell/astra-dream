class_name HubTerminalManager
extends Node

## Gestor modular de terminales e interactuables en el Hangar Espacial:
## Terminal de Misiones, Terminal de Récords (Highscores), Máquina de Gacha y Modales Asociados.

const GachaModalScript := preload("res://scenes/ui/gacha/gacha_modal.gd")

var hub: Node3D = null
var mission_interactable: HubInteractable3D = null
var highscores_interactable: HubInteractable3D = null
var gacha_interactable: HubInteractable3D = null

var mission_holo_core: MeshInstance3D = null
var highscores_trophy_holo: MeshInstance3D = null
var gacha_holo: MeshInstance3D = null

var mission_prompt_modal: PanelContainer = null
var prompt_info_label: Label = null
var btn_prompt_continue: Button = null
var btn_prompt_new_run: Button = null
var btn_prompt_cancel: Button = null

var highscores_modal: CanvasLayer = null
var gacha_modal: CanvasLayer = null

func setup(p_hub: Node3D) -> void:
	hub = p_hub
	_bind_scene_nodes()
	setup_terminals()
	setup_gacha_terminal()

func _bind_scene_nodes() -> void:
	if not is_instance_valid(hub):
		return
	mission_interactable = hub.get_node_or_null("Terminals/MissionTerminal/Interactable_Mission")
	highscores_interactable = hub.get_node_or_null("Terminals/HighScoresTerminal/Interactable_HighScores")
	mission_holo_core = hub.get_node_or_null("Terminals/MissionTerminal/HoloCore")
	highscores_trophy_holo = hub.get_node_or_null("Terminals/HighScoresTerminal/TrophyHolo")

	mission_prompt_modal = hub.get_node_or_null("HubUI/MissionPromptModal")
	prompt_info_label = hub.get_node_or_null("HubUI/MissionPromptModal/VBox/PromptInfo")
	btn_prompt_continue = hub.get_node_or_null("HubUI/MissionPromptModal/VBox/PromptButtons/ContinueRunButton")
	btn_prompt_new_run = hub.get_node_or_null("HubUI/MissionPromptModal/VBox/PromptButtons/NewRunButton")
	btn_prompt_cancel = hub.get_node_or_null("HubUI/MissionPromptModal/VBox/PromptButtons/CancelPromptButton")
	highscores_modal = hub.get_node_or_null("HubUI/HighscoresModal")

func setup_terminals() -> void:
	if mission_interactable:
		update_mission_terminal_label()
		if not mission_interactable.interacted.is_connected(_on_mission_interacted):
			mission_interactable.interacted.connect(_on_mission_interacted)

	if highscores_interactable:
		if not highscores_interactable.interacted.is_connected(_on_highscores_interacted):
			highscores_interactable.interacted.connect(_on_highscores_interacted)

	if btn_prompt_continue and not btn_prompt_continue.pressed.is_connected(_on_continue_run_confirmed):
		btn_prompt_continue.pressed.connect(_on_continue_run_confirmed)
	if btn_prompt_new_run and not btn_prompt_new_run.pressed.is_connected(_on_new_run_confirmed):
		btn_prompt_new_run.pressed.connect(_on_new_run_confirmed)
	if btn_prompt_cancel and not btn_prompt_cancel.pressed.is_connected(_on_prompt_cancelled):
		btn_prompt_cancel.pressed.connect(_on_prompt_cancelled)

func setup_gacha_terminal() -> void:
	if not is_instance_valid(hub):
		return
	var term_group := hub.get_node_or_null("Terminals")
	if not term_group:
		term_group = Node3D.new()
		term_group.name = "Terminals"
		hub.add_child(term_group)

	var gacha_term: Node3D = term_group.get_node_or_null("GachaTerminal")
	if not gacha_term:
		gacha_term = Node3D.new()
		gacha_term.name = "GachaTerminal"
		gacha_term.position = Vector3(0.0, 0.0, -6.5)
		term_group.add_child(gacha_term)

	gacha_holo = gacha_term.get_node_or_null("GachaCapsuleHolo")
	if not gacha_holo:
		gacha_holo = MeshInstance3D.new()
		gacha_holo.name = "GachaCapsuleHolo"
		gacha_holo.position = Vector3(0, 2.3, 0.1)
		var sphere := SphereMesh.new()
		sphere.radius = 0.38
		sphere.height = 0.76
		gacha_holo.mesh = sphere

		var h_mat := StandardMaterial3D.new()
		h_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		h_mat.albedo_color = Color(1.0, 0.84, 0.0, 0.8)
		h_mat.emission_enabled = true
		h_mat.emission = Color(1.0, 0.85, 0.2, 1.0)
		h_mat.emission_energy_multiplier = 2.0
		gacha_holo.material_override = h_mat
		gacha_term.add_child(gacha_holo)

	gacha_interactable = gacha_term.get_node_or_null("Interactable_Gacha")
	if not gacha_interactable:
		var inter_script = preload("res://scenes/ui/hub/hub_interactable_3d.gd")
		gacha_interactable = inter_script.new()
		gacha_interactable.name = "Interactable_Gacha"
		gacha_interactable.target_character_id = &"gacha"
		gacha_interactable.interaction_title = "🎰 Máquina de Gacha (Cosméticos)"
		gacha_interactable.interaction_radius = 2.8
		gacha_interactable.prompt_offset_y = 2.3
		gacha_term.add_child(gacha_interactable)
	if not gacha_interactable.interacted.is_connected(_on_gacha_interacted):
		gacha_interactable.interacted.connect(_on_gacha_interacted)

	var hub_ui := hub.get_node_or_null("HubUI")
	if hub_ui and not gacha_modal:
		gacha_modal = GachaModalScript.new()
		gacha_modal.name = "GachaModal"
		hub_ui.add_child(gacha_modal)
		gacha_modal.modal_closed.connect(_on_gacha_modal_closed)

func update_mission_terminal_label() -> void:
	if not mission_interactable or not mission_interactable.label_3d:
		return
	if SaveManager.has_active_run():
		var active_data := SaveManager.load_active_run()
		var wave: int = int(active_data.get("current_wave", 1))
		var pilot: String = str(active_data.get("pilot_name", "Piloto"))
		mission_interactable.label_3d.text = "[E] CONTINUAR RUN\n(%s - OLEADA %d)" % [pilot.to_upper(), wave]
	else:
		mission_interactable.label_3d.text = "[E] DESPLEGAR MISIÓN"

func _on_mission_interacted(_interactable: HubInteractable3D, _player: Node3D) -> void:
	if hub and hub.has_method("_play_sfx"):
		hub.call("_play_sfx", "ui_click")
	if SaveManager.has_active_run():
		show_mission_prompt()
	else:
		_start_new_run()

func show_mission_prompt() -> void:
	if not mission_prompt_modal:
		_start_new_run()
		return

	var active_data := SaveManager.load_active_run()
	var wave: int = int(active_data.get("current_wave", 1))
	var pilot: String = str(active_data.get("pilot_name", "Piloto"))
	if prompt_info_label:
		prompt_info_label.text = "Transmisión activa detectada:\nPiloto: %s  |  Oleada alcanzada: %d\n¿Deseas continuar la misión o comenzar una nueva?" % [pilot.to_upper(), wave]

	mission_prompt_modal.visible = true
	var pc = hub.get("player_controller")
	if pc:
		pc.set("is_movement_locked", true)
	if btn_prompt_continue:
		btn_prompt_continue.grab_focus()

func _on_continue_run_confirmed() -> void:
	if hub.get("_is_transitioning"):
		return
	hub.set("_is_transitioning", true)
	if hub.has_method("_play_sfx"):
		hub.call("_play_sfx", "ui_click")
	SaveManager.is_resuming_run = true
	hub.get_tree().change_scene_to_file("res://scenes/combat/main_game.tscn")

func _on_new_run_confirmed() -> void:
	if hub.get("_is_transitioning"):
		return
	hub.set("_is_transitioning", true)
	if hub.has_method("_play_sfx"):
		hub.call("_play_sfx", "ui_click")
	_start_new_run()

func _on_prompt_cancelled() -> void:
	if mission_prompt_modal:
		mission_prompt_modal.visible = false
	var pc = hub.get("player_controller")
	if pc:
		pc.set("is_movement_locked", false)

func _start_new_run() -> void:
	SaveManager.is_resuming_run = false
	hub.get_tree().change_scene_to_file("res://scenes/ui/character_select/character_select.tscn")

func _on_highscores_interacted(_interactable: HubInteractable3D, _player: Node3D) -> void:
	if hub and hub.has_method("_play_sfx"):
		hub.call("_play_sfx", "ui_click")
	if highscores_modal:
		var pc = hub.get("player_controller")
		if pc:
			pc.set("is_movement_locked", true)
		if highscores_modal.has_method("open_highscores"):
			highscores_modal.open_highscores()
		elif highscores_modal.has_method("show_modal"):
			highscores_modal.show_modal()
		else:
			highscores_modal.visible = true

func _on_gacha_interacted(_interactable: HubInteractable3D, _player: Node3D) -> void:
	if hub and hub.has_method("_play_sfx"):
		hub.call("_play_sfx", "ui_click")
	if gacha_modal:
		var pc = hub.get("player_controller")
		if pc:
			pc.set("is_movement_locked", true)
		gacha_modal.open_gacha_modal()

func _on_gacha_modal_closed() -> void:
	if hub and hub.has_method("_on_modal_closed"):
		hub.call("_on_modal_closed")

func process_terminal_holos(delta: float, idle_time: float) -> void:
	if mission_holo_core and is_instance_valid(mission_holo_core):
		mission_holo_core.rotation.y += delta * 1.5
		mission_holo_core.position.y = 2.3 + sin(idle_time * 2.5) * 0.08
	if highscores_trophy_holo and is_instance_valid(highscores_trophy_holo):
		highscores_trophy_holo.rotation.y += delta * 2.0
		highscores_trophy_holo.position.y = 2.3 + sin(idle_time * 2.0) * 0.06
	if gacha_holo and is_instance_valid(gacha_holo):
		gacha_holo.rotation.y += delta * 2.5
		gacha_holo.position.y = 2.2 + sin(idle_time * 2.8) * 0.08

func is_modal_active() -> bool:
	if gacha_modal and is_instance_valid(gacha_modal) and gacha_modal.visible:
		return true
	if highscores_modal and is_instance_valid(highscores_modal) and highscores_modal.visible:
		return true
	if mission_prompt_modal and is_instance_valid(mission_prompt_modal) and mission_prompt_modal.visible:
		return true
	return false

func handle_esc_input() -> bool:
	if gacha_modal and is_instance_valid(gacha_modal) and gacha_modal.visible:
		if gacha_modal.has_method("close_modal"):
			gacha_modal.close_modal()
		else:
			gacha_modal._on_close_pressed()
		return true
	if highscores_modal and is_instance_valid(highscores_modal) and highscores_modal.visible:
		if highscores_modal.has_method("close_modal"):
			highscores_modal.close_modal()
		elif highscores_modal.has_method("hide"):
			highscores_modal.hide()
			if hub and hub.has_method("_on_modal_closed"):
				hub.call("_on_modal_closed")
		return true
	if mission_prompt_modal and is_instance_valid(mission_prompt_modal) and mission_prompt_modal.visible:
		_on_prompt_cancelled()
		return true
	return false

class_name HubTerminalManager
extends Node

## Gestor modular de terminales interactuables [E] en el Hangar Espacial:
## Misiones (continuar / nueva run), Gacha de skins, Sala de Trofeos y Highscores.

signal start_run_requested(is_new_run: bool)
signal modal_opened()
signal modal_closed()
signal dark_matter_updated(amount: int)

var hub: Node3D = null

func setup(p_hub: Node3D) -> void:
	hub = p_hub

func setup_all_terminals() -> void:
	if not is_instance_valid(hub):
		return
	setup_mission_terminal()
	setup_gacha_terminal()
	setup_highscores_terminal()
	setup_trophy_room()

func setup_mission_terminal() -> void:
	var mission_term: Node3D = hub.get_node_or_null("Terminals/MissionTerminal")
	if not mission_term:
		return
	var inter: HubInteractable3D = mission_term.get_node_or_null("HubInteractable3D") as HubInteractable3D
	if not inter:
		inter = HubInteractable3D.new()
		inter.name = "HubInteractable3D"
		inter.prompt_action = "DESPLEGAR"
		inter.interaction_distance = 2.4
		mission_term.add_child(inter)
	if not inter.interacted.is_connected(_on_mission_interacted):
		inter.interacted.connect(_on_mission_interacted)

func _on_mission_interacted(_interactable: HubInteractable3D, _player: Node3D) -> void:
	if hub and hub.has_method("_show_mission_prompt"):
		hub.call("_show_mission_prompt")

func setup_gacha_terminal() -> void:
	var claw_node: Node3D = hub.get_node_or_null("SpaceParallax/claw-machine2")
	var target_parent: Node3D = claw_node if claw_node else hub.get_node_or_null("Terminals/GachaTerminal")
	if not target_parent:
		return
	var inter: HubInteractable3D = target_parent.get_node_or_null("HubInteractable3D") as HubInteractable3D
	if not inter:
		inter = HubInteractable3D.new()
		inter.name = "HubInteractable3D"
		inter.prompt_action = "MÁQUINA GACHA"
		inter.interaction_distance = 2.6
		target_parent.add_child(inter)
	if not inter.interacted.is_connected(_on_gacha_interacted):
		inter.interacted.connect(_on_gacha_interacted)

func _on_gacha_interacted(_interactable: HubInteractable3D, _player: Node3D) -> void:
	if hub and hub.has_method("_on_gacha_terminal_interacted"):
		hub.call("_on_gacha_terminal_interacted", _interactable, _player)

func setup_highscores_terminal() -> void:
	var highscores_term: Node3D = hub.get_node_or_null("Terminals/HighScoresTerminal")
	if not highscores_term:
		return
	var inter: HubInteractable3D = highscores_term.get_node_or_null("HubInteractable3D") as HubInteractable3D
	if not inter:
		inter = HubInteractable3D.new()
		inter.name = "HubInteractable3D"
		inter.prompt_action = "HISTORIAL"
		inter.interaction_distance = 2.4
		highscores_term.add_child(inter)
	if not inter.interacted.is_connected(_on_highscores_interacted):
		inter.interacted.connect(_on_highscores_interacted)

func _on_highscores_interacted(_interactable: HubInteractable3D, _player: Node3D) -> void:
	if hub and hub.has_method("_on_highscores_terminal_interacted"):
		hub.call("_on_highscores_terminal_interacted", _interactable, _player)

func setup_trophy_room() -> void:
	if hub and hub.has_method("_setup_trophy_room"):
		hub.call("_setup_trophy_room")

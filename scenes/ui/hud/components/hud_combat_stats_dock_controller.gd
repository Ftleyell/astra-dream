class_name HUDCombatStatsDockController
extends RefCounted

## HUDCombatStatsDockController.gd
## Subcontrolador modular para la gestión del panel lateral de estadísticas de combate en tiempo real (TAB y modales).
## Extraído de GameHUD como parte de la Fase 4 del Plan de Erradicación de Monolitos.

const CombatStatsDock = preload("res://scenes/ui/hud/components/combat_stats_dock.gd")

var combat_stats_dock: CombatStatsDock = null
var stats_dock_layer: CanvasLayer = null

func setup_combat_stats_dock(hud: CanvasLayer) -> void:
	if combat_stats_dock or not hud:
		return
	stats_dock_layer = CanvasLayer.new()
	stats_dock_layer.name = "StatsDockLayer"
	stats_dock_layer.layer = 130
	stats_dock_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	hud.add_child(stats_dock_layer)

	combat_stats_dock = CombatStatsDock.new()
	combat_stats_dock.name = "CombatStatsDock"
	combat_stats_dock.process_mode = Node.PROCESS_MODE_ALWAYS
	combat_stats_dock.position = Vector2(24.0, 240.0)
	combat_stats_dock.visible = false
	stats_dock_layer.add_child(combat_stats_dock)

func handle_input(hud: CanvasLayer, player: Player, event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_TAB:
			if not combat_stats_dock:
				setup_combat_stats_dock(hud)
			var target_player: Player = player
			if not is_instance_valid(target_player) and hud.get_tree():
				target_player = hud.get_tree().get_first_node_in_group("player") as Player
			if is_instance_valid(combat_stats_dock) and is_instance_valid(target_player):
				combat_stats_dock.toggle_tab_dock(target_player)
				hud.get_viewport().set_input_as_handled()

func set_stats_dock_requested(hud: CanvasLayer, player: Player, requester_id: StringName, requested: bool) -> void:
	if not combat_stats_dock:
		setup_combat_stats_dock(hud)
	if is_instance_valid(combat_stats_dock):
		var target_player: Player = player
		if not is_instance_valid(target_player) and hud.get_tree():
			target_player = hud.get_tree().get_first_node_in_group("player") as Player
		combat_stats_dock.set_dock_requested(requester_id, requested, target_player)

func refresh_if_visible(player: Player) -> void:
	if is_instance_valid(combat_stats_dock) and combat_stats_dock.visible and is_instance_valid(player):
		combat_stats_dock.refresh_stats(player)

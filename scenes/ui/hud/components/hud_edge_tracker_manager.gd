class_name HUDEdgeTrackerManager
extends RefCounted

## HUDEdgeTrackerManager.gd
## Administrador centralizado de indicadores perimetrales en los bordes de la pantalla (Edge Trackers):
## - Satélite activo (SatelliteEdgeIndicator).
## - Arcanas / cartas en campo (ArcanaEdgeIndicator).
## - Jefes y colosos (BossEdgeIndicator).
## - Cofres de recompensa (ChestEdgeIndicator).

var satellite_tracker: SatelliteEdgeIndicator = null
var arcana_tracker: ArcanaEdgeIndicator = null
var boss_tracker: Control = null
var chest_tracker: Control = null

func setup(elements: Dictionary) -> void:
	satellite_tracker = elements.get("satellite_tracker") as SatelliteEdgeIndicator
	arcana_tracker = elements.get("arcana_tracker") as ArcanaEdgeIndicator
	boss_tracker = elements.get("boss_tracker") as Control
	chest_tracker = elements.get("chest_tracker") as Control

func set_player(player: Player) -> void:
	if not is_instance_valid(player):
		return
	if is_instance_valid(satellite_tracker) and satellite_tracker.has_method("set_player"):
		satellite_tracker.set_player(player)
	if is_instance_valid(arcana_tracker) and arcana_tracker.has_method("set_player"):
		arcana_tracker.set_player(player)
	if is_instance_valid(boss_tracker):
		if boss_tracker.has_method("set_player"):
			boss_tracker.set_player(player)
		elif "player" in boss_tracker:
			boss_tracker.player = player
	if is_instance_valid(chest_tracker) and chest_tracker.has_method("set_player"):
		chest_tracker.set_player(player)

func track_satellite(target_pos: Vector2, index: int, player: Player = null) -> void:
	if is_instance_valid(satellite_tracker):
		if is_instance_valid(player) and satellite_tracker.has_method("set_player"):
			satellite_tracker.set_player(player)
		satellite_tracker.set_target(target_pos, index)

func clear_satellite_tracking() -> void:
	if is_instance_valid(satellite_tracker):
		satellite_tracker.clear_target()

func track_boss(target: Node2D, title: String = "JEFE", player: Player = null) -> void:
	if is_instance_valid(boss_tracker):
		if is_instance_valid(player):
			if boss_tracker.has_method("set_player"):
				boss_tracker.set_player(player)
			elif "player" in boss_tracker:
				boss_tracker.player = player
		boss_tracker.set_target_node(target, title)

func clear_boss_tracking() -> void:
	if is_instance_valid(boss_tracker):
		boss_tracker.clear_target()

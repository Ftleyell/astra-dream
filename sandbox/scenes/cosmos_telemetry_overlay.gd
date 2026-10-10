class_name CosmosTelemetryOverlay
extends CanvasLayer

## Overlay de depuración e instrumentación técnica para Cosmos Engine.
## Muestra telemetría en vivo: Posición absoluta, velocidad, celda galáctica, shifts de origen y FPS.

@export var cosmos_root: CosmosRoot
@export var vessel: PlayerVessel
@export var camera: CosmosCamera2D

@onready var label_telemetry: Label = $PanelContainer/MarginContainer/LabelTelemetry

func _ready() -> void:
	layer = 120

func _process(_delta: float) -> void:
	if label_telemetry == null:
		return

	var fps: float = Engine.get_frames_per_second()
	var local_pos: Vector2 = vessel.global_position if vessel != null else Vector2.ZERO
	var abs_pos: Vector2 = cosmos_root.get_absolute_position(local_pos) if cosmos_root != null else local_pos
	var speed: float = vessel.get_current_speed() if vessel != null else 0.0
	var shift_count: int = cosmos_root.get_origin_shift_count() if cosmos_root != null else 0
	var zoom_lvl: Vector2 = camera.zoom if camera != null else Vector2.ONE
	var time_val: float = cosmos_root.get_global_time() if cosmos_root != null else 0.0

	# Calcular celda galáctica de referencia (usando grid tamaño 60000)
	var cell_x: int = int(floor(abs_pos.x / 60000.0))
	var cell_y: int = int(floor(abs_pos.y / 60000.0))

	var text: String = "=== COSMOS ENGINE TELEMETRY ===\n"
	text += "Pilot: %s\n" % (vessel.get_character_display_name() if vessel != null and vessel.has_method("get_character_display_name") else "Vanguard")
	text += "FPS: %.1f\n" % fps
	text += "Global Cosmic Time: %.2f s\n" % time_val
	text += "Local Pos: (%.1f, %.1f)\n" % [local_pos.x, local_pos.y]
	text += "Absolute World Pos: (%.1f, %.1f)\n" % [abs_pos.x, abs_pos.y]
	text += "Speed: %.1f px/s\n" % speed
	text += "Galactic Macro Cell: [%d, %d]\n" % [cell_x, cell_y]
	text += "Origin Shifts Triggered: %d\n" % shift_count
	text += "Camera Zoom: %.2fx\n" % zoom_lvl.x
	text += "Controls: WASD (Thrust), SHIFT (Boost), Mouse Wheel (+/- Zoom)\n"
	text += "Character Switch: TAB / E (Next Hero), Q (Prev Hero)"

	label_telemetry.text = text

class_name SandboxTelemetryHud
extends CanvasLayer

## SandboxTelemetryHud
## HUD minimalista de telemetría de rendimiento y navegación para el sandbox espacial.
## Muestra FPS, coordenadas lógicas 64-bit, origen flotante, sector actual y métricas de render.

@onready var _panel: PanelContainer = $PanelContainer
@onready var _label_metrics: Label = $PanelContainer/MarginContainer/VBoxContainer/MetricsLabel
@onready var _label_controls: Label = $PanelContainer/MarginContainer/VBoxContainer/ControlsLabel

var _tracker: FloatingOriginTracker
var _streamer: CosmicSectorStreamer
var _ship: SandboxShip
var _debris: CosmicDebrisInstancer
var _celestial: CosmicCelestialRenderer

var _update_timer: float = 0.0
const UPDATE_INTERVAL: float = 0.1 # 10 Hz para evitar saturación de UI


func setup(
	tracker: FloatingOriginTracker,
	streamer: CosmicSectorStreamer,
	ship: SandboxShip,
	debris: CosmicDebrisInstancer,
	celestial: CosmicCelestialRenderer
) -> void:
	_tracker = tracker
	_streamer = streamer
	_ship = ship
	_debris = debris
	_celestial = celestial


func _process(delta: float) -> void:
	_update_timer += delta
	if _update_timer < UPDATE_INTERVAL:
		return
	_update_timer = 0.0
	_refresh_display()


func _refresh_display() -> void:
	if not is_instance_valid(_label_metrics):
		return

	var fps: float = Engine.get_frames_per_second()
	var draw_calls: int = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME) as int
	var video_mem_mb: float = float(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)) / (1024.0 * 1024.0)

	var log_pos: Vector2 = _tracker.get_logical_position() if _tracker != null else Vector2.ZERO
	var origin: Vector2 = _tracker.get_origin() if _tracker != null else Vector2.ZERO
	var local_pos: Vector2 = _ship.global_position if is_instance_valid(_ship) else Vector2.ZERO
	var ship_speed: float = _ship.velocity.length() if is_instance_valid(_ship) else 0.0

	var cur_sector: Vector2i = _streamer.get_current_center_sector() if _streamer != null else Vector2i.ZERO
	var active_sectors: int = _streamer.get_active_sector_count() if _streamer != null else 0
	var active_systems: int = _celestial.get_active_systems_count() if is_instance_valid(_celestial) else 0
	var debris_count: int = _debris.get_instance_count() if is_instance_valid(_debris) else 0

	var text: String = ""
	text += "=== SANDBOX COSMIC TELEMETRY ===\n"
	text += "FPS: %d  |  Draw Calls: %d  |  VRAM: %.1f MB\n" % [int(fps), draw_calls, video_mem_mb]
	text += "--------------------------------\n"
	text += "Logical Pos: (%.1f, %.1f)\n" % [log_pos.x, log_pos.y]
	text += "Floating Origin: (%.1f, %.1f)\n" % [origin.x, origin.y]
	text += "Local Actor Pos: (%.1f, %.1f) | Speed: %.1f u/s\n" % [local_pos.x, local_pos.y, ship_speed]
	text += "--------------------------------\n"
	text += "Sector Coords: [%d, %d] (Active Sectors: %d)\n" % [cur_sector.x, cur_sector.y, active_sectors]
	text += "Active Celestial Systems: %d\n" % active_systems
	text += "GPU Debris Count (1 Call): %d\n" % debris_count

	_label_metrics.text = text

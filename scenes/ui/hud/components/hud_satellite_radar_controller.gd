class_name HUDSatelliteRadarController
extends RefCounted

## HUDSatelliteRadarController.gd
## Controlador especializado en la lógica de radar y estado temporal de oleadas del HUD:
## - Formateo del timer de oleada y pre-ronda.
## - Detección euclidiana de posición del satélite relativo al jugador y flechas de orientación.
## - Seguimiento de distancia recorrida hacia el próximo satélite de la oleada.

var timer_label: Label = null
var satellite_radar_label: Label = null

var run_time: float = 0.0
var active_satellite_pos: Vector2 = Vector2.ZERO
var has_satellite: bool = false
var satellite_index: int = 1
var current_wave: int = 1
var wave_time_left: float = 60.0
var wave_satellites_spawned: int = 0
var max_wave_satellites: int = 3
var current_travel_dist: float = 0.0
var required_travel_dist: float = 600.0
var is_pre_round_active: bool = false
var pre_round_time_left: float = 30.0

func setup_from_root(root: CanvasLayer) -> void:
	if not root:
		return
	setup({
		"timer_label": root.find_child("TimerLabel", true, false),
		"satellite_radar_label": root.find_child("SatelliteRadarLabel", true, false)
	})

func setup(elements: Dictionary) -> void:
	timer_label = elements.get("timer_label") as Label
	satellite_radar_label = elements.get("satellite_radar_label") as Label

func update_pre_round_status(time_left: float) -> void:
	is_pre_round_active = true
	pre_round_time_left = time_left

func update_wave_status(wave: int, time_left: float, satellites_spawned: int, max_satellites: int) -> void:
	is_pre_round_active = false
	current_wave = wave
	wave_time_left = time_left
	wave_satellites_spawned = satellites_spawned
	max_wave_satellites = max_satellites

func update_satellite_travel_dist(current_d: float, req_d: float) -> void:
	current_travel_dist = current_d
	required_travel_dist = req_d

func set_active_satellite(pos: Vector2, index: int) -> void:
	active_satellite_pos = pos
	satellite_index = index
	has_satellite = true

func clear_satellite() -> void:
	has_satellite = false

func process_frame(delta: float, player: Node2D) -> void:
	run_time += delta
	_update_timer_label()
	_update_radar_label(player)

func _update_timer_label() -> void:
	if not is_instance_valid(timer_label):
		return
	if is_pre_round_active:
		var s: int = int(ceil(maxf(0.0, pre_round_time_left)))
		timer_label.text = "PRE-RONDA [00:%02d] | FASE DE DESPLIEGUE" % s
		timer_label.add_theme_color_override("font_color", Color(0.2, 0.95, 1.0))
	else:
		timer_label.remove_theme_color_override("font_color")
		var wave_m: int = int(float(wave_time_left) / 60.0)
		var wave_s: int = int(wave_time_left) % 60
		timer_label.text = "Oleada %d [%02d:%02d] | Satélites: %d/%d" % [current_wave, wave_m, wave_s, wave_satellites_spawned, max_wave_satellites]

func _update_radar_label(player: Node2D) -> void:
	if not is_instance_valid(satellite_radar_label):
		return
	if has_satellite and is_instance_valid(player):
		var dist: float = player.global_position.distance_to(active_satellite_pos)
		var dir: Vector2 = (active_satellite_pos - player.global_position).normalized()
		var arrow: String = "↑"
		if abs(dir.x) > abs(dir.y):
			arrow = "→" if dir.x > 0 else "←"
		else:
			arrow = "↓" if dir.y > 0 else "↑"
		satellite_radar_label.text = "Satélite #%d: %d m [%s]" % [satellite_index, int(dist), arrow]
	else:
		if wave_satellites_spawned < max_wave_satellites:
			satellite_radar_label.text = "Buscando satélite: %d / %d m" % [int(current_travel_dist), int(required_travel_dist)]
		else:
			satellite_radar_label.text = "Satélites de oleada agotados. Resiste hasta la prox. oleada"

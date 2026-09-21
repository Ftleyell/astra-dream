class_name GameHUD
extends CanvasLayer

@export var player: Player

@onready var health_bar: ProgressBar = $MarginContainer/VBoxContainer/TopRow/HealthBar
@onready var health_label: Label = $MarginContainer/VBoxContainer/TopRow/HealthLabel
@onready var bomb_label: Label = $MarginContainer/VBoxContainer/TopRow/BombLabel
@onready var laser_cd_label: Label = $MarginContainer/VBoxContainer/TopRow/LaserCDLabel
@onready var credits_label: Label = $MarginContainer/VBoxContainer/TopRow/CreditsLabel
@onready var timer_label: Label = $MarginContainer/VBoxContainer/TopRow/TimerLabel
@onready var satellite_radar_label: Label = $MarginContainer/VBoxContainer/BottomRow/SatelliteRadarLabel
@onready var exp_bar: ProgressBar = $MarginContainer/VBoxContainer/BottomRow/ExpBar
@onready var level_label: Label = $MarginContainer/VBoxContainer/BottomRow/LevelLabel

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

func _ready() -> void:
	if player:
		player.health_changed.connect(_on_health_changed)
		player.bomb_used.connect(_on_bomb_used)
		_on_health_changed(player.current_health, player.stats.get_stat(&"max_health"))
		_on_bomb_used(player.bomb_count)

		var weapon_ctrl := player.get_node_or_null("WeaponController") as WeaponController
		if weapon_ctrl:
			weapon_ctrl.laser_cooldown_updated.connect(update_laser_cooldown)

func _process(delta: float) -> void:
	run_time += delta
	var wave_m: int = int(wave_time_left) / 60
	var wave_s: int = int(wave_time_left) % 60
	timer_label.text = "Oleada %d [%02d:%02d] | Satélites: %d/%d" % [current_wave, wave_m, wave_s, wave_satellites_spawned, max_wave_satellites]

	if has_satellite and player:
		var dist: float = player.global_position.distance_to(active_satellite_pos)
		var dir := (active_satellite_pos - player.global_position).normalized()
		var arrow := "↑"
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

func update_wave_status(wave: int, time_left: float, satellites_spawned: int, max_satellites: int) -> void:
	current_wave = wave
	wave_time_left = time_left
	wave_satellites_spawned = satellites_spawned
	max_wave_satellites = max_satellites

func update_satellite_travel_dist(current_d: float, req_d: float) -> void:
	current_travel_dist = current_d
	required_travel_dist = req_d

func clear_satellite() -> void:
	has_satellite = false

func update_laser_cooldown(current: float, max_val: float) -> void:
	if not laser_cd_label:
		return
	if current <= 0.0:
		laser_cd_label.text = "Láser: [LISTO]"
		laser_cd_label.modulate = Color(0.2, 1.0, 1.0, 1.0)
	else:
		laser_cd_label.text = "Láser: [%.1fs]" % current
		laser_cd_label.modulate = Color(1.0, 0.7, 0.2, 1.0)

func set_active_satellite(pos: Vector2, index: int) -> void:
	active_satellite_pos = pos
	satellite_index = index
	has_satellite = true

func update_credits(amount: int) -> void:
	credits_label.text = "Créditos: %d C" % amount

func update_exp(current: float, max_val: float, level: int) -> void:
	exp_bar.max_value = max_val
	exp_bar.value = current
	level_label.text = "NV. %d" % level

func _on_health_changed(current: float, max_val: float) -> void:
	health_bar.max_value = max_val
	health_bar.value = current
	health_label.text = "%d / %d" % [int(current), int(max_val)]

func _on_bomb_used(remaining: int) -> void:
	bomb_label.text = "Bombas: %d" % remaining

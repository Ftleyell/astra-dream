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
	var minutes: int = int(run_time) / 60
	var seconds: int = int(run_time) % 60
	var threat: float = 1.0 + (run_time * 0.02)
	timer_label.text = "%02d:%02d | Amenaza: %.1fx" % [minutes, seconds, threat]

	if has_satellite and player:
		var dist: float = player.global_position.distance_to(active_satellite_pos)
		var dir := (active_satellite_pos - player.global_position).normalized()
		var arrow := "↑"
		if abs(dir.x) > abs(dir.y):
			arrow = "→" if dir.x > 0 else "←"
		else:
			arrow = "↓" if dir.y > 0 else "↑"
		satellite_radar_label.text = "Satélite #%d: %d m [%s]" % [satellite_index, int(dist), arrow]

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

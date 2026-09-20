class_name OverheadHealthBar
extends Node2D

@export var player: Player

@onready var health_bar: ProgressBar = $ProgressBar
@onready var percent_label: Label = $PercentLabel

func _ready() -> void:
	if not player:
		player = get_parent() as Player

	if player:
		player.health_changed.connect(_on_health_changed)
		_update_display(player.current_health, player.stats.get_stat(&"max_health"))

func _on_health_changed(current: float, max_val: float) -> void:
	_update_display(current, max_val)

func _update_display(current: float, max_val: float) -> void:
	if not health_bar or not percent_label:
		return

	max_val = maxf(1.0, max_val)
	var ratio: float = clampf(current / max_val, 0.0, 1.0)
	var pct: int = int(ratio * 100.0)

	health_bar.max_value = max_val
	health_bar.value = current
	percent_label.text = "%d%%" % pct

	# Color reactivo según porcentaje
	var col := Color(0.2, 0.9, 0.5, 0.95)
	if ratio <= 0.25:
		col = Color(1.0, 0.25, 0.35, 1.0)
	elif ratio <= 0.5:
		col = Color(1.0, 0.75, 0.2, 1.0)

	percent_label.modulate = col
	health_bar.modulate = col

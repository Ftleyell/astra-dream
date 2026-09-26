class_name EnemyMicroFlock
extends "res://scenes/combat/enemies/enemy_base.gd"

## Micro-dron ágil de bandada espacial:
## Aparece en formaciones geométricas masivas (cuñas, arcos o enjambres),
## tiene baja salud, alta velocidad y avanza con inercia coordinada.

var flock_seed: float = 0.0

func _init() -> void:
	enemy_id = &"enemy_micro_flock"
	max_health = 12.0
	move_speed = 380.0
	contact_damage = 6.0
	exp_reward = 6.0
	credits_reward = 1
	contact_radius = 14.0

func _ready_custom() -> void:
	flock_seed = randf() * 100.0

func _update_behavior(_delta: float) -> void:
	var to_player := (player.global_position - global_position)
	var dist := to_player.length()
	var dir := to_player / maxf(1.0, dist)

	# Ligera oscilación lateral para movimiento orgánico de bandada
	var lateral := Vector2(-dir.y, dir.x)
	var wave_offset := lateral * sin((float(Time.get_ticks_msec()) * 0.006) + flock_seed) * 40.0

	velocity = (dir * move_speed) + wave_offset
	rotation = dir.angle()
	move_and_slide()

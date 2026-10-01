class_name EnemyDrone
extends "res://scenes/combat/enemies/enemy_base.gd"

## Drone estándar de enjambre: rápido, persecución frontal básica y daño por colisión.

func _init() -> void:
	enemy_id = &"enemy_drone"
	max_health = 30.0
	move_speed = 160.0
	contact_damage = 10.0
	exp_reward = 15.0
	credits_reward = 1
	contact_radius = 22.0


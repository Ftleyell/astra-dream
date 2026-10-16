class_name EnemyDrone
extends "res://scenes/combat/enemies/enemy_base.gd"

## Drone estándar de enjambre: rápido, persecución frontal básica y daño por colisión.

const DEFAULT_DRONE_DATA: EnemyData = preload("res://data/enemies/enemy_drone.tres")

func _init() -> void:
	enemy_data = DEFAULT_DRONE_DATA
	_apply_enemy_data()

func _apply_enemy_data() -> void:
	if enemy_data == null or enemy_data == DEFAULT_ENEMY_DATA:
		enemy_data = DEFAULT_DRONE_DATA
	super._apply_enemy_data()



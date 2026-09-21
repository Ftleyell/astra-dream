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

func _ready_custom() -> void:
	var visual: Node = get_node_or_null("Visual")
	var drone_tex_path := "res://assets/enemies/enemy_drone.png"
	if ResourceLoader.exists(drone_tex_path):
		var tex := load(drone_tex_path) as Texture2D
		if tex:
			var spr := Sprite2D.new()
			spr.name = "DroneSprite"
			spr.texture = tex
			spr.scale = Vector2(0.4, 0.4)
			add_child(spr)
			move_child(spr, 0)
			if visual:
				visual.visible = false

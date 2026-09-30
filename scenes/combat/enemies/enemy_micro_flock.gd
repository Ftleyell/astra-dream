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
	var visual: Node = get_node_or_null("Visual")
	var core_glow: Node = get_node_or_null("CoreGlow")
	var tex_path := "res://assets/sprites/enemies/enemy_micro_flock.png"
	if ResourceLoader.exists(tex_path):
		var tex := load(tex_path) as Texture2D
		if tex:
			var spr := Sprite2D.new()
			spr.name = "FlockSprite"
			spr.texture = tex
			spr.scale = Vector2(0.035, 0.035)
			add_child(spr)
			move_child(spr, 0)
			sprite = spr
			if visual:
				visual.visible = false
			if core_glow:
				core_glow.visible = false

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

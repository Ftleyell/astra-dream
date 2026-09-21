class_name EnemyTank
extends "res://scenes/combat/enemies/enemy_base.gd"

## Crucero Tanque blindado: nave pesada con gran reserva de salud que actúa como
## muro protector absorbiendo disparos del jugador y empujando implacablemente.

func _init() -> void:
	enemy_id = &"enemy_tank"
	max_health = 180.0
	move_speed = 85.0
	contact_damage = 25.0
	exp_reward = 75.0
	credits_reward = 8
	contact_radius = 34.0
	contact_interval = 0.8

func _ready_custom() -> void:
	var tex_path := "res://assets/enemies/enemy_tank.png"
	if ResourceLoader.exists(tex_path):
		var tex := load(tex_path) as Texture2D
		if tex and sprite:
			sprite.texture = tex
			sprite.scale = Vector2(0.45, 0.45)

func _update_behavior(delta: float) -> void:
	# Avance pesado constante hacia la posición del jugador con giro amortiguado
	var target_dir := (player.global_position - global_position).normalized()
	var current_dir := Vector2.RIGHT.rotated(rotation)
	var new_dir := current_dir.lerp(target_dir, delta * 2.2).normalized()
	velocity = new_dir * move_speed
	rotation = new_dir.angle()
	move_and_slide()

func _on_die_extra() -> void:
	# Al morir su reactor pesado genera sacudida cinematográfica
	var cam := get_viewport().get_camera_2d()
	if cam and cam.has_method("add_trauma"):
		cam.add_trauma(0.35)

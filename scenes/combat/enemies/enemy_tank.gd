class_name EnemyTank
extends "res://scenes/combat/enemies/enemy_base.gd"

## Crucero Tanque blindado: nave pesada con gran reserva de salud que actúa como
## muro protector absorbiendo disparos del jugador y empujando implacablemente.

const DEFAULT_TANK_DATA: EnemyData = preload("res://data/enemies/enemy_tank.tres")

func _init() -> void:
	enemy_data = DEFAULT_TANK_DATA
	_apply_enemy_data()

func _apply_enemy_data() -> void:
	if enemy_data == null or enemy_data == DEFAULT_ENEMY_DATA:
		enemy_data = DEFAULT_TANK_DATA
	super._apply_enemy_data()

func _ready_custom() -> void:
	var tex_path := "res://assets/sprites/enemies/enemy_tank.png"
	if ResourceLoader.exists(tex_path):
		var tex := load(tex_path) as Texture2D
		if tex and sprite:
			sprite.texture = tex
			sprite.scale = Vector2(0.08, 0.08)

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

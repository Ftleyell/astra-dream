class_name EnemyKamikaze
extends "res://scenes/combat/enemies/enemy_base.gd"

## Kamikaze de asalto: nave ágil que entra en sobrecarga y embiste a gran velocidad
## cuando se acerca al jugador, generando una micro-explosión al detonar.

const DEFAULT_KAMIKAZE_DATA: EnemyData = preload("res://data/enemies/enemy_kamikaze.tres")

@export var dive_distance: float = 260.0
@export var dive_speed: float = 360.0

var is_diving: bool = false
var dive_dir: Vector2 = Vector2.ZERO

func _init() -> void:
	enemy_data = DEFAULT_KAMIKAZE_DATA
	_apply_enemy_data()

func _apply_enemy_data() -> void:
	if enemy_data == null or enemy_data == DEFAULT_ENEMY_DATA:
		enemy_data = DEFAULT_KAMIKAZE_DATA
	super._apply_enemy_data()
	if enemy_data != null:
		dive_distance = enemy_data.dive_distance
		dive_speed = enemy_data.dive_speed

func _ready_custom() -> void:
	var tex_path: String = "res://assets/sprites/enemies/enemy_kamikaze.png"
	if ResourceLoader.exists(tex_path):
		var tex: Texture2D = load(tex_path) as Texture2D
		if tex and sprite:
			sprite.texture = tex
			sprite.scale = Vector2(0.05, 0.05)
	_reset_pool_state()

func _reset_pool_state() -> void:
	is_diving = false
	dive_dir = Vector2.ZERO

func _update_behavior(delta: float) -> void:
	var dist_to_player := global_position.distance_to(player.global_position)

	# Transición a modo embestida / turbo
	if not is_diving and dist_to_player <= dive_distance:
		is_diving = true
		dive_dir = (player.global_position - global_position).normalized()
		# Feedback visual de sobrecarga
		var tw := create_tween()
		tw.tween_property(self, "modulate", Color(1.8, 0.4, 0.2, 1.0), 0.1)

	if is_diving:
		# Embestida a alta velocidad con leve ajuste direccional
		var target_dir := (player.global_position - global_position).normalized()
		dive_dir = dive_dir.lerp(target_dir, delta * 3.5).normalized()
		velocity = dive_dir * dive_speed
		rotation = dive_dir.angle()
	else:
		# Persecución veloz estándar
		var dir := (player.global_position - global_position).normalized()
		velocity = dir * move_speed
		rotation = dir.angle()

	move_and_slide()

func _on_contact_with_player() -> void:
	super._on_contact_with_player()
	# Al impactar al jugador se auto-destruye detonando su reactor
	_die()

func _on_die_extra() -> void:
	# Micro-explosión y sacudida si estaba en rango de detonación
	if is_diving or (is_instance_valid(player) and global_position.distance_to(player.global_position) < 80.0):
		var cam := get_viewport().get_camera_2d()
		if cam and cam.has_method("add_trauma"):
			cam.add_trauma(0.25)
